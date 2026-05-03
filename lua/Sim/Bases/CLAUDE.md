# Bases

A **base** is a goal-defined unit of territory + structures + assigned engineers, tied to a single nav-mesh layer (Land or Water) and to a single brain. The brain holds many bases; each base owns a piece of the map and a slice of the army's economic/defensive output.

## Role: model

The base is the **model** layer of the AI (see the model/controller philosophy in the [top-level CLAUDE.md](../../../CLAUDE.md)): it answers "what is the current state of this piece of the map?" — claimed leaves, build sites with their reservation/blocked flags, queued/active/complete build jobs, engineer assignments. It validates its own data periodically via `JoeBase.TickThread`.

In the long-term shape the base **does not make policy decisions**: what to build, where to expand, who to dispatch are decided by `JoeBrain` (army scope) or platoon behaviors (unit scope). Some controller-shaped work still lives here (engineer recycling, idle assignment) and will migrate upward over time.

If you find yourself reaching for a method like `JoeBase:DecideWhatToBuild`, that belongs on the brain. If you find yourself scoring build candidates inside the base, that belongs on the consuming behavior — different unit types want different policies (an ACU isn't an engineer). The base returns *state*; controllers decide what to do with it.

## Files in this tree

- [`JoeBase.lua`](JoeBase.lua) — the base class. Holds component refs, the trash bag, and the **coordinator methods** (see below).
- [`JoeBaseBuilder.lua`](JoeBaseBuilder.lua) — fluent builder for constructing a base, assigning units, and registering it with the brain (`AssignBrain`). Mirrors the platoon builder pattern in `Sim/Behaviors/PlatoonBuilder.lua`.
- [`Components/`](Components/) — per-aspect data holders. Each component is pure storage; `JoeBase` is the only place where they're combined.

## The coordinator pattern

`JoeBase` is the **only** place where:

1. Components talk to other components.
2. The base talks to its brain.

Components themselves are kept dumb on purpose — they store data and expose accessors, nothing more. Cross-component invariants and brain mirroring live in `JoeBase`. This makes:

- Components independently testable (no sibling mocks).
- Brain ↔ base traffic grep-able (`self.Brain.X` only ever appears in `JoeBase`).
- Cross-cutting operations (e.g. "claim leaf + drop attached build sites + cascade on retreat") have one obvious home.

The cost is some boilerplate — every multi-component operation gets a `JoeBase` method that mostly forwards. Worth it.

### Example: leaf claims

The unit of claim is a `NavLeaf`, not a `NavSection` — multiple bases can share a single underlying section by claiming different leaves inside it. `JoeBaseChunkComponent:ClaimLeaf` is **pure storage** — it just writes to `self.Leaves`. The brain mirror happens in `JoeBase:ClaimLeaf`:

```lua
ClaimLeaf = function(self, leafId)
    if self.Brain.ChunkComponent:IsClaimed(leafId) then return false end
    self.ChunkComponent:ClaimLeaf(leafId)
    self.Brain.ChunkComponent:ClaimLeaf(leafId, self)
    return true
end
```

Three layers, same name: `JoeBase:ClaimLeaf` (coordinator), `JoeBaseChunkComponent:ClaimLeaf` (this-base storage), `JoeBrainChunkComponent:ClaimLeaf` (brain union). They're the same operation viewed at three scopes — calling them all `ClaimLeaf` makes the symmetry explicit. Method dispatch (`:`) keeps them disambiguated by receiver type.

Same shape for `ReleaseLeaf`, `ReleaseAllLeaves`. If you find yourself reaching for `self.Brain.X` from inside a component, that's the smell — the operation belongs on `JoeBase`.

## Lifecycle

| Stage | What happens |
|---|---|
| **Build** | `JoeBaseBuilder.Build(brain, location)` calls `JoeBase(brain, location)` and registers the base via `brain:AddBase(base)`. The base's chunk component infers its layer from the location. |
| **Live** | The base claims leaves, assigns engineer behaviors, and grows. The trash bag (`self.Trash`) tracks anything thread-shaped that should die with the base. |
| **Retreat** | `base:Retreat()` destroys the trash (kills threads), releases every claimed leaf (mirroring each release to the brain and dropping attached build sites), and removes the base from `brain.Bases`. After this call the base is unreachable through the brain. |

Order in `Retreat` matters: kill threads *first* so they can't observe inconsistent state during data cleanup, *then* release leaves, *then* unregister.

## Future base subtypes

There's only `JoeBase` today, but the structure is meant to host subtypes — e.g. main base vs. expansion vs. defensive outpost — that share the coordinator pattern and component slots but differ in policy (which behaviors to run, how aggressively to claim, etc.). When that lands, the convention is: **subclass `JoeBase`, override behaviour-shaped methods, keep the component contracts identical**.

## Conventions

1. **No cross-component calls inside a component.** If `JoeBaseChunkComponent` needs to coordinate with `JoeBaseBuildSiteComponent`, the call lives on `JoeBase`.
2. **No `self.Brain.X` inside a component.** Brain-talking is a `JoeBase` responsibility.
3. **Trash everything thread-shaped.** Forked threads that should die with the base go in `self.Trash`. `Retreat` cleans them up uniformly.
4. **Don't self-register.** Bases are registered with the brain by their builder (`AssignBrain`), not from `__init`.
