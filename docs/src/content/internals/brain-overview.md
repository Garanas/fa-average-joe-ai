# Brain overview

`JoeBrain` is the army-level controller. It extends FAF's `AIBrain` and composes three grid-based features plus a roster of brain components.

## What the brain owns

The brain holds the *map-wide* picture and the *map-wide* decisions:

- Which areas are reclaimable and roughly how much mass each holds.
- Where enemy units have been seen recently, and how stale that sighting is.
- Which of our forces are *roaming* (not tied to a base) and where to send them next.
- The list of bases we have spun up, and which one a new mass extractor should belong to.

## What the brain does not own

The brain does not manage *base-local* state. Engineer assignments, build-site reservations, queued production jobs — those live on a `JoeBase`. The brain pushes intent down ("I want a T2 land factory in your jurisdiction") and the base figures out which engineer goes where.

This boundary is deliberate. See [ADR 0002](/docs/adr/0002-coordinator-pattern) for the reasoning.

## Composition

Roughly, brain construction looks like:

```lua
function JoeBrain:OnCreateAI(...)
    AIBrain.OnCreateAI(self, ...)

    self.GridReclaim  = GridReclaim.Setup(self)
    self.GridRecon    = GridRecon.Setup(self)
    self.GridPresence = GridPresence.Setup(self)

    self.Bases        = {}
    self.RoamingForce = {}

    self:ForkThread(self.TickThread)
end
```

Each grid is a separate module that exposes a `Setup(brain)` constructor returning a state object. The brain just glues them together.

## Tick cadence

The brain ticks every `1.0s` of game time. Per tick it:

1. Lets each grid update its own state (reclaim decays, recon ages, presence updates).
2. Walks the base list and asks each base for its tick.
3. Decides whether to spawn a new base, retreat an existing one, or redirect roaming forces.

Anything time-critical (per-frame UI, per-tick sim hot paths) lives elsewhere — see the perf notes in `lua/Sim/CLAUDE.md`.
