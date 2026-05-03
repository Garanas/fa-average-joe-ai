# Brains

The **brain** is the army-level coordinator. One brain per AI. It owns:

- A roster of [bases](../Bases/CLAUDE.md) (`self.Bases`).
- Cross-cutting grids (`GridReclaim`, `GridRecon`, `GridPresence`) — engine-side data structures from `lua/ai/`.
- Per-brain components (this folder) for state that's army-wide rather than base-specific.
- Strategic-level decisions: which bases need more land, how to dispatch roaming forces, when to expand.

## Files in this tree

- [`JoeBrain.lua`](JoeBrain.lua) — the brain class. Extends FAF's `AIBrain`. Holds component refs and the base roster.
- [`Components/`](Components/) — per-aspect data holders (same convention as `Bases/Components/`).

## The same coordinator pattern

`JoeBrain` is to its components what `JoeBase` is to *its* components: the only place where cross-component traffic and cross-level traffic (with bases) lives.

Components in this folder are **pure storage**. They expose accessors and predicates; the brain owns orchestration. Same rule, applied symmetrically — see [`../Bases/CLAUDE.md`](../Bases/CLAUDE.md) for the full rationale.

## Brain ↔ base traffic

The base is the active party in claims:

- A base calls `self.Brain.ChunkComponent:ClaimLeaf(...)` — but only from inside a `JoeBase` method (e.g. `JoeBase:ClaimLeaf`), never from inside a base component. Both methods share the name on purpose: the base coordinator and the brain mirror are the same operation, just at two layers.
- The brain doesn't push state down into bases; bases pull from the brain.
- The brain uses `self.Bases` to iterate and collect (e.g. for the chunk visualization).

The mirror invariant — `brain.ChunkComponent.Leaves` is the union of all `base.ChunkComponent.Leaves` — is enforced by `JoeBase` doing the mirror in lockstep with its own claim writes.

## Lifecycle

| Stage | What happens |
|---|---|
| **Create** | `JoeBrain.OnCreateAI` initializes grids and components. `self.Bases = {}`. |
| **Live** | Bases register via `brain:AddBase(base)` (called by `JoeBaseBuilder:AssignBrain`). The brain's chunk component is mirrored as bases claim/release. |
| **Base retreats** | `base:Retreat()` calls `brain:RemoveBase(self)` to drop the base from the roster. |
| **Brain destroyed** | (engine-driven; no explicit teardown for the brain yet — bases would need to retreat individually if cleanup matters). |

## Future components

The brain will likely grow:

- A **threat / intel** component fed by `GridRecon` / `GridPresence`.
- An **expansion planner** that decides where to seed new bases.
- A **resource budget** component that prioritizes which base requests get fulfilled.

When those land, the rule is the same: pure storage in components, orchestration in `JoeBrain`.

## Conventions

1. **Read-mostly from outside the brain.** Other code asks the brain things; the brain doesn't push.
2. **No cross-component calls inside a brain component.** Use a `JoeBrain` method.
3. **Bases own the mirror.** When a base claims a leaf, the base notifies the brain; the brain doesn't crawl base components to reconstruct its view.
