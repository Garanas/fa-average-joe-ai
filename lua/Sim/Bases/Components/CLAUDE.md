# Base components

Components are **pure data holders** with narrow scope. They carry one aspect of base state (claimed leaves, build sites, build jobs, economy plans, etc.) and expose accessors over it. They do **not** orchestrate, mirror to the brain, or call sibling components — that's [`JoeBase`](../JoeBase.lua)'s job (see [`../CLAUDE.md`](../CLAUDE.md)).

## Files in this tree

- [`JoeBaseChunkComponent.lua`](JoeBaseChunkComponent.lua) — claimed nav-mesh leaves for this base. Pure storage of `Leaves[leafId] → JoeBaseLeafClaim`. Layer is locked at construction (inferred from `base.Location`). Carries `MinClaimSize` (default 16) — the smallest leaf the base will accept as a claim.
- [`JoeBaseBuildSiteComponent.lua`](JoeBaseBuildSiteComponent.lua) — concrete build sites materialised by mapping a `JoeBaseChunk` template onto a leaf. Defines two classes in one file: `JoeBuildSite` (the per-slot record — `Point`, `Identifier`, `Unit`, `Leaf`, `Claimed`, `Blocked`) and `JoeBaseBuildSiteComponent` (the per-base list + queries). Build-site state is **not** stored — it's a derived property computed from the assigned `Unit` (`IsFree` / `IsBuilding` / `IsBuilt` / `IsLost` / `GetState`).
- [`JoeBaseConstructionQueueComponent.lua`](JoeBaseConstructionQueueComponent.lua) — three queues for the engineer-driven construction-job lifecycle: `Pending` (unclaimed), `Active` (engineer working), `Complete` (built, unit alive). `JoeConstructionJobSpec` is the immutable request — single `Identifier`, optional `LocationHint` / `Priority` / `MaxAssistants` / `DelayPredicate`. `JoeConstructionJob` wraps it with runtime state (engineers list, build site, unit, delayed flag). Lifecycle helpers `PushJob` / `ClaimJob` / `RegisterBuildSite` / `RegisterUnit` / `CompleteJob` / `FailJob`; assistant API `JoinAsAssistant` / `LeaveJob` / `FindAssistTarget`. Per-state validators (`ValidatePending` / `ValidateClaimed` / `ValidateBuilding` / `ValidateBuilt`) are orchestrated from `JoeBase.TickThread` — the component itself is pure storage.
- [`JoeBaseProductionQueueComponent.lua`](JoeBaseProductionQueueComponent.lua) — same lifecycle shape as the construction queue, but factory-driven: each job is a single mobile unit produced by one factory. `JoeProductionJobSpec` carries a `UnitId` (faction-specific blueprint), optional `LocationHint` / `Priority` / `DelayPredicate`. `JoeProductionJob` tracks the claiming `Factory` and the produced `Unit`. No build site (factories produce in their own internal queue) and no assistant slot (factory-assist by engineers is a different mechanic, not tracked here). Validators mirror the construction queue and are driven from the same place.
- [`JoeBaseStructureManagerComponent.lua`](JoeBaseStructureManagerComponent.lua) — flat list of finished structures owned by this base. Storage only — `JoeBase:AssignStructure` is the coordinator that adds to the list and mirrors the `OnAssignedToBase` call. `AddStructure` / `RemoveStructure` / `Has` / `LogState`. Future evolution: index by `JoeBuildingIdentifier` for cheap lookups, and an `OnDestroy` hook to auto-remove on death.

Future likely additions:

- `JoeBaseIntentsComponent` — long-lived, label-scoped intents the base is currently pursuing (input to the resolver controller that emits jobs into the two queues above).
- `JoeBaseEconomyComponent` — desired structure mix, current production rates, what the base wants next.

## What a component looks like

```lua
---@class JoeBaseFooComponent
---@field Base JoeBase
---@field Items table<Key, Value>
JoeBaseFooComponent = ClassSimple {
    __init = function(self, base)
        self.Base = base
        self.Items = {}
    end,

    -- Pure storage: store, retrieve, predicate. No orchestration.
    Add = function(self, key, value) self.Items[key] = value end,
    Remove = function(self, key)     self.Items[key] = nil end,
    Has = function(self, key)        return self.Items[key] ~= nil end,
    Get = function(self, key)        return self.Items[key] end,
}
```

Things a component **may** do:
- Hold data, expose accessors, predicates, iteration helpers.
- Render itself (`Draw`) — purely synchronously, called by `JoeBase:Draw`.
- Reference `self.Base` for read-only context (e.g. layer derived from `base.Location`).

Things a component **must not** do:
- Call methods on sibling components (`self.Base.OtherComponent:X(...)`).
- Reach into the brain (`self.Base.Brain.X`).
- Fork threads or stand up its own debug toggles — drawing cadence is decided by the base.

## Why this discipline

Bases will accumulate more components (build sites, economy, defense, …). Without this rule, every new component multiplies the number of cross-component pathways and the system becomes a graph instead of a tree. With it, every cross-cutting concern has exactly one home: `JoeBase`.

## Pitfalls

1. **The trap of "just one direct call to the brain"** — once the first component does it, every subsequent component will too. Resist; promote it to a `JoeBase` method.
2. **Render threads in components** — earlier `JoeBaseChunkComponent` had `EnableDebug` / `DrawLoop` / `DrawThread` machinery. We removed it because draw cadence belongs to `JoeBase:Draw` (which is gated externally). Components only expose `Draw(self)` as a pure render.
3. **Storing back-references that outlive the base** — components hold `self.Base`. Be careful that any data flowing from a component back out doesn't keep the base alive after `Retreat`. Currently this isn't an issue because `Retreat` doesn't try to nil out components, but worth keeping in mind.
