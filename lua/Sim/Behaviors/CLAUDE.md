# Platoon behaviors

Every AI behavior in this mod is a **goal-oriented state machine** attached to a platoon. One behavior = one goal: build a structure, reclaim an area, attack a target. The behavior owns every sub-tactic required to reach that goal end-to-end — an attack behavior also navigates to its target, evades dangerous regions, falls back when outmatched, and engages; an engineer build behavior also navigates, clears the build site of obstructions, and steers around threat. **Goal cohesion is the unit; tactics are not their own behaviors.** Some incidental side-jobs woven into a main behavior are fine; the line you don't cross is decomposing one goal into multiple chained behaviors.

Two callers compose behaviors above this layer:

- **Base** — owns base-specific platoons: local construction, reclaim, defense. Decides how many engineers it needs in each category and re-tasks units as local conditions change.
- **Brain** — army-level: forces roaming the map, strategic decisions, and cross-base requests (e.g. "send an engineer to expand to that location").

Behaviors aren't aware of which level owns them. They take input, run to `Completed` (or `Error`), and let the caller re-task whatever's left.

## Role: controller (unit-level)

Behaviors are the **unit-level controllers** in the model/controller framing (see the [top-level CLAUDE.md](../../../CLAUDE.md)). They read the model — mostly the owning base's components — to decide tactical things (which candidate build site is closest, which path to take, when to abandon a job) and they mutate the model to keep it accurate (claim a build site via `RegisterBuildSite`, mark one blocked via `JoeBuildSite:Block`, register a unit on a job via `RegisterUnit`).

**Selection policies that depend on the unit type live in the behavior, not on the base.** An ACU treats danger differently from a T1 engineer; a reclaim engineer prioritises mass density; a future repair behavior will care about damaged-unit proximity. The base returns the unfiltered candidate list; each behavior picks among them with its own logic. See `SelectBuildSite` in [Engineers/BuildBehavior.lua](Engineers/BuildBehavior.lua) for the current example — engineer-specific "closest wins."

## Files in this tree

- [PlatoonBehavior.lua](PlatoonBehavior.lua) — the base class `AIPlatoonBehavior`. Defines `OnCreate`/`OnDestroy`, the `Start`/`Completed`/`Error` states, the `ChangeState` engine, the trash-bag lifecycle, debug helpers, and default no-op overrides for every engine event the platoon receives.
- [PlatoonBuilder.lua](PlatoonBuilder.lua) — fluent builder for constructing a platoon, assigning units to squads, and starting a behavior with input.
- [PlatoonUtils.lua](PlatoonUtils.lua) — the **registry**. Every behavior must be listed here.
- `Base/`, `Debug/`, `Engineers/` — behaviors organized by purpose-domain.

## Anatomy of a behavior

A behavior is a `Class(AIPlatoonBehavior)` whose fields are mostly `State { ... }` tables. See [Engineers/BuildBehavior.lua](Engineers/BuildBehavior.lua) for the canonical example.

```lua
local AIPlatoonBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBehavior.lua").AIPlatoonBehavior

---@class AIFooBehaviorInput : AIPlatoonBehaviorInput
---@field Target Vector

---@class AIFooBehavior : AIPlatoonBehavior
---@field PlatoonBehaviorInput AIFooBehaviorInput
FooBehavior = Class(AIPlatoonBehavior) {
    BehaviorName = 'FooBehavior',

    Start = State {
        BehaviorStateName = 'Start',
        Main = function(self)
            self:ChangeState(self.DoAThing)
            return
        end,
    },

    DoAThing = State {
        BehaviorStateName = 'DoAThing',
        BehaviorStateColor = 'ffaa00',
        Main = function(self)
            -- work; transition out via ChangeState or via an event handler below
        end,

        ---@param self AIFooBehavior
        OnSomeEvent = function(self, ...)
            self:ChangeState(self.Completed)
        end,
    },
}
```

`Start`, `Completed`, and `Error` are inherited from the base. Override what you need; leave the rest. The base `Start` immediately transitions to `Error`, so every concrete behavior must override it.

### Naming conventions

- File: `FooBehavior.lua`. Exported global: `FooBehavior`. Class annotation: `AIFooBehavior`. Input annotation: `AIFooBehaviorInput`.
- `BehaviorName` is a string used in logs.
- `BehaviorStateName` and `BehaviorStateColor` are per-state and used by debug drawing.

## How states work

State transitions are implemented by a **metatable swap on the platoon** (see [PlatoonBehavior.lua:94-136](PlatoonBehavior.lua#L94-L136)). When `ChangeState(self, newState)` runs it:

1. Destroys `BehaviorStateTrash` (anything scoped to the leaving state).
2. Calls `setmetatable(self, newState)` — from this point on, dispatching `self:OnFoo(...)` hits `newState.OnFoo` if present, otherwise falls through to the base class no-op.
3. `ForkThread`s `state.Main(self)` as the new main coroutine.
4. **Kills the old main thread last** — because that thread might be the one calling `ChangeState`.

`self.BehaviorState` is **not** touched by `ChangeState` — values resolved by one state flow into the next. See "State storage" below.

Two consequences worth understanding:

- **Event handlers don't need wiring.** Any `On*` override on a state is dispatched automatically while that state is active. Define `OnStartBuild` only on the state that cares.
- **`Main` does not need to loop forever.** It can finish; the platoon stays in the state, dispatching events, until something calls `ChangeState`. See `WaitForConstruction` in [BuildBehavior.lua:92-133](Engineers/BuildBehavior.lua#L92-L133): `Main` waits 4 ticks and exits, then `OnStopBuild` drives the transition.

### `OnEnterState` / `OnExitState` are NOT supported

This is intentional — see the comment in [PlatoonBehavior.lua:96-97](PlatoonBehavior.lua#L96-L97). To get the same effect:

- **Entry work** → put it at the top of `Main`.
- **Exit cleanup** → register it on `BehaviorStateTrash` while the state is active.

## State storage: trash bags and `BehaviorState`

Three lifetimes are available on `self`:

| Field | Lifetime | Use for |
|---|---|---|
| `self.BehaviorTrash` | full behavior (cleared on `OnDestroy`) | observers/threads that should outlive state transitions |
| `self.BehaviorStateTrash` | current state only (cleared on every `ChangeState`) | watchdog threads, draw helpers, anything per-state that needs cleanup |
| `self.BehaviorState` | full behavior (persists across `ChangeState`) | all behavior runtime data — values resolved by one state flow into the next |

`BehaviorState` is the canonical home for behavior runtime data. Annotate it with an `AIXBehaviorState` class so the shape is discoverable (see [BuildBehavior.lua](Engineers/BuildBehavior.lua) for the pattern). Keep `self`-fields for engine and infrastructure (`BehaviorTrash`, `Debug`, etc.) — behavior data goes in `BehaviorState`. If a state truly needs a clean slate, reset specific fields explicitly (`self.BehaviorState.Job = nil`); there is no automatic clear.

## Input: the `PlatoonBehaviorInput` contract

Each behavior declares its own `AIXBehaviorInput` (extending `AIPlatoonBehaviorInput`) describing what the caller must provide. The builder writes it to `self.PlatoonBehaviorInput` once, before `Start` runs. **Treat it as read-only** — it's the social contract between caller and behavior. Mutate `self.BehaviorState` instead.

## Squads

Platoons split units across five engine-defined squads: `Support`, `Attack`, `Artillery`, `Guard`, `Scout`. The base implementations of `OnUnitsAddedToXSquad` (in [PlatoonBehavior.lua:142-170](PlatoonBehavior.lua#L142-L170)) emit warnings — override only the ones your behavior actually accepts.

By convention, engineer behaviors put engineers in the `Support` squad.

## Constructing and starting a behavior

Use the fluent builder in [PlatoonBuilder.lua](PlatoonBuilder.lua):

```lua
local PlatoonBuilder = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBuilder.lua")
local PlatoonBehaviors = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonUtils.lua").PlatoonBehaviors

PlatoonBuilder.Build(brain, PlatoonBehaviors.BuildBehavior)
    :AssignSupportUnit(engineer)
    :StartBehavior({ Location = location, UnitId = unitId })
    :End()
```

`Build` allocates a platoon and stamps the behavior class onto it via `setmetatable`. `StartBehavior` writes `PlatoonBehaviorInput` and transitions to `Start`. To re-task an existing platoon, use `PlatoonBuilder.Extend(brain, platoon)` instead.

## Registering a new behavior

Add an entry to [PlatoonUtils.lua](PlatoonUtils.lua) under the relevant section (`debug behavior`, `engineer behavior`, `base behavior`, …). Behaviors not in the registry won't be reachable through the conventional discovery paths.

## Debug & drawing

- `BehaviorStateColor` (per state) is consumed by the base `Draw` method to color the platoon and squad outlines on screen.
- `self:IsBeingDebugged()` returns true when a unit of the platoon was selected on the last tick. Gate verbose logs with this so they don't fire for every platoon every tick.
- `self:Log(msg)` and `self:Warn(msg)` prefix the message with platoon + state context.
- The `Error` state draws a red circle by default — leave that visual as the universal "something went wrong" signal.

## Conventions and pitfalls

1. **Always `return` after `ChangeState`.** `ChangeState` kills the calling thread, so today the lines after it are unreachable in practice. Writing `return` anyway makes intent explicit and survives changes to the threading model. See [BuildBehavior.lua:127-131](Engineers/BuildBehavior.lua#L127-L131) for an example of what *not* to do — a missing `return` between two `ChangeState` calls.
2. **Keep `BehaviorStateName` and the field name in sync.** A copy-paste mismatch (state declared as `WaitForConstruction` but named `'WaitForReclaim'`) is silent — debug logs will lie about which state you're in.
3. **Provide a way out of waiting states.** A state whose `Main` exits and relies on events (`OnStopBuild`, `OnKilled`, …) to drive transitions can deadlock if those events never fire. Stage a watchdog timer on `BehaviorStateTrash` for any wait that could hang.
4. **Don't write `OnEnterState` / `OnExitState`.** They will silently never run — see the section above for the supported alternatives.
5. **Don't trust units pulled from the engine.** `GetPlatoonUnits` is overridden to filter destroyed units ([PlatoonBehavior.lua:376-401](PlatoonBehavior.lua#L376-L401)) — prefer it over `AIPlatoonMoho.GetPlatoonUnits`. When iterating squad units, expect them to be killed mid-state.
6. **One behavior, one *goal* — but the goal includes its tactics.** A `BuildBehavior` properly contains states for navigating to the site, clearing obstructing reclaim, evading threat, and waiting on construction. What you should *not* do is overload one behavior with two unrelated goals — a flag that flips between "build a structure" and "reclaim a battlefield" is the symptom; split it. Composition happens at the brain/base level: it picks *which* goal-behavior to run, not how a behavior sequences its own tactics.
7. **Keep allocations out of hot paths.** This codebase is performance-conscious — note the TODOs around empty-table allocation in [BuildBehavior.lua:85](Engineers/BuildBehavior.lua#L85). Reuse cache tables (see `UnitCache` in [PlatoonBuilder.lua:1](PlatoonBuilder.lua#L1)) where it matters.
