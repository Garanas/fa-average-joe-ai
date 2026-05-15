# Build system refactor: from imperative to declarative

This week's biggest change wasn't a new feature — it was rewriting how engineers pick their next job.

## The old way

Each engineer ran a procedural `BuildLoop`:

```lua
while platoon:Alive() do
    if base:NeedsPower() then
        BuildAdjacent(platoon, "T1_Power")
    elseif base:NeedsMass() then
        BuildExtractor(platoon)
    elseif base:NeedsFactory() then
        BuildFactory(platoon)
    else
        Wait(2)
    end
end
```

It worked, but the priority chain was hard-coded into the loop. Adding a new building type meant editing a `elseif` branch *and* threading the new "do we need this?" predicate through `JoeBase`. Cross-base coordination was awkward because every engineer was making its own decision based on its own snapshot of the base.

## The new way

Engineers are dumb now. They run a state machine:

```
Idle  --has job--> Building  --done--> Idle
       \--no job--> Wait------/
```

The *job* is what's smart. The brain pushes intent ("I want a T2 land factory in your jurisdiction") down to the base. The base resolves intent into a concrete `BuildJob` and enqueues it. Engineers pull the next job off the queue, build it, and report done.

The priority logic — what to build next — lives in one place: `JoeBase:DispatchPlanner`. It looks at base state, recent decisions, and the brain's army-level goals, then enqueues jobs.

## Why this is better

- **One place to audit.** "Why did it build power instead of mass?" is now answered by reading `DispatchPlanner`, not by reconstructing what each engineer was seeing.
- **Engineers are interchangeable.** Any free engineer can take any job. Previously, an engineer mid-decision couldn't be redirected without race conditions.
- **Adding a building type is cheap.** Define the build job, add it to the planner's priority list, done.

## What's next

The planner is still using a hard-coded priority list. The next refactor will replace it with a scoring function so the AI can weigh "build T2 power" vs "build T2 PD" based on whether it's been raided recently. That's slated for v0.2 along with the Cybran stealth work.
