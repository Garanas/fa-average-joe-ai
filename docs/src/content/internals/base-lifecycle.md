# Base lifecycle

A `JoeBase` lives through four phases. Each phase has a clear entry condition and a single exit signal.

## Phases

1. **Spawning** — the base has been created but has no buildings yet. Engineers are en route, the build queue contains a T1 land factory and a couple of mass extractors. The base is not yet visible to the brain's force-allocation pass.
2. **Settling** — the first factory has finished. The base now produces engineers and accepts build jobs from the brain. Defences are scheduled.
3. **Operational** — the base has reached its baseline footprint (factory, power, mass, point defence, a wall ring). It contributes to army planning and can absorb additional jobs from the brain.
4. **Retreating** — the base is being abandoned. Engineers are recalled, build sites are cancelled, and the base is removed from the brain's list once cleanup finishes.

> A base never goes backwards. Once it leaves *Settling*, it cannot return — if the brain wants to "downgrade" a base, it retreats and re-spawns one.

## State transitions

The phase transitions are deterministic and side-effect-free:

```
Spawning  --first factory complete--> Settling
Settling  --baseline footprint met--> Operational
Operational --retreat signal-->        Retreating
Retreating  --cleanup complete-->     [removed]
```

## Retreat semantics

Retreat is *not* "stop building things." It is "give back what we claimed":

- Reservation flags on every build site are cleared.
- Active builds are cancelled.
- Engineers are released back to the brain's roaming pool.
- Claimed leaves on the navigational mesh are released so other bases can use them.

A base that's mid-retreat will refuse new jobs. The brain checks `base.IsRetreating` before pushing work.

## Coordinator responsibilities

Within each phase, `JoeBase.TickThread` does the coordination — it asks each component for state, decides what to do, and writes back. Components themselves never trigger phase changes; they only report what they observe.
