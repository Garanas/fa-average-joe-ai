# Platoon behaviors

Platoon behaviors are goal-oriented state machines attached to FAF platoons. Each behavior owns a small slice of the unit-level decision space — "build the next thing in this base's queue", "reclaim wrecks in this area", "scout the unexplored corner of the map."

## The shape of a behavior

A behavior is a class with three properties: a state name, a set of state functions, and a trash bag for cleanup.

```lua
---@class EngineerBuildBehavior : AIPlatoonBehavior
EngineerBuildBehavior = Class(AIPlatoonBehavior) {

    BehaviorName = "EngineerBuild",

    Start = State {
        StateName = "Start",
        Main = function(self) ... end,
    },

    Building = State {
        StateName = "Building",
        Main = function(self) ... end,
    },

    Finished = State {
        StateName = "Finished",
        Main = function(self) ... end,
    },
}
```

States are transitioned via `self:ChangeState(self.Building)`. The fluent builder pattern means a state can chain into another without intermediate cleanup.

## Composition over conditionals

A behavior does not "decide" what to do — it follows orders from its owner. Behaviors that work for a base read the base's queues. Behaviors that work for the brain read the brain's roaming targets.

This is why we don't have one mega-behavior that handles every engineer task. We have:

- `EngineerBuildBehavior` — pick a build job, go build it.
- `EngineerReclaimBehavior` — pick a reclaim cluster, work it down.
- `EngineerAssistBehavior` — find a stalled builder, accelerate it.
- `EngineerIdleBehavior` — sit at the rally point waiting for orders.

The owning component (base or brain) picks which behavior the platoon runs by re-tasking it. Switching is cheap: the trash bag cleans up, the new behavior starts fresh.

## Trash bag lifecycle

Each behavior creates a `TrashBag` in `OnCreate` and disposes of it in `OnDestroy`. Anything that needs to be cancelled when the behavior ends — repeating threads, callbacks, forked work — is added to the bag. The behavior never has to remember what it scheduled; the bag handles cleanup uniformly.
