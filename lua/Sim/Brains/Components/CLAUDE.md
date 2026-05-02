# Brain components

Per-brain components are **pure data holders** with narrow scope. They store one aspect of brain state and expose accessors. Orchestration and cross-component traffic live in [`JoeBrain`](../JoeBrain.lua) (see [`../CLAUDE.md`](../CLAUDE.md)). Same discipline as [`Bases/Components/`](../../Bases/Components/CLAUDE.md).

## Files in this tree

- [`JoeBrainChunkComponent.lua`](JoeBrainChunkComponent.lua) — the brain's union view of claimed sections (`Sections[sectionId] → JoeBase`). Populated by bases via `ClaimSection` / `ReleaseSection` (same names as the corresponding `JoeBase` coordinator methods that call them). Hosts the BFS queries `FindClaimableArea` and `FindClaimableAreaToward` because they're brain-scope (need to consider all bases under the brain).

## Difference from base components

The brain's chunk component is *slightly* less pure than its base counterpart — it carries the queries (`FindClaimableArea`, `FindSection`, `IsBlockingForQuery`). That's defensible: those queries need access to the full union, which only this component has. They also don't reach back across to bases except via the read-only `excludeBase` parameter.

If a query needs to combine data from multiple brain components, that's a `JoeBrain` method, not a component method.

## Draw cadence lives on the brain

Components expose a pure `Draw(self)` method — they do not run their own draw threads. `JoeBrain:EnableDebug` / `DisableDebug` flip the brain-level draw flag and fork/kill a single `DrawLoop` thread that calls `JoeBrain:Draw`, which in turn delegates to each component's `Draw`. Adding a new brain component with a debug visualization means: implement `Draw` on the component, then call it from `JoeBrain:Draw`. No new thread, no new toggle.

## What a brain component looks like

```lua
---@class JoeBrainFooComponent
---@field Brain JoeBrain
---@field Items table<Key, Value>
JoeBrainFooComponent = ClassSimple {
    __init = function(self, brain)
        self.Brain = brain
        self.Items = {}
    end,

    -- Pure storage + brain-scope queries that only this component can answer.
    Add = function(self, key, value) self.Items[key] = value end,
    Get = function(self, key)        return self.Items[key] end,
    -- ...
}

--- Setup function matching the GridReclaim / GridRecon convention.
---@param brain JoeBrain
---@return JoeBrainFooComponent
function Setup(brain)
    return JoeBrainFooComponent(brain)
end
```

The `Setup(brain)` module export pattern matches the existing FAF grid components (`GridReclaim`, `GridRecon`, `GridPresence`) so the wire-up in `JoeBrain.OnCreateAI` reads consistently.

## Pitfalls

1. **Iterating bases from inside a brain component** is a gentle smell. It's sometimes necessary (e.g. drawing all bases' colors), but think first whether the operation belongs on `JoeBrain` instead.
2. **Mutation from outside.** Bases mutate brain components only through methods explicitly intended as mirror points (`ClaimSection`, `ReleaseSection` on the brain component, called from the matching `JoeBase` coordinator methods). Don't let other callers mutate `Sections` directly.
3. **No forked threads in components.** Visualization and polling threads belong on `JoeBrain` (debug draw) or are forked by the action that needs them. A component owning a thread couples it to the component's lifetime in confusing ways — `JoeBrain:DisableDebug` killing the thread is more legible.
