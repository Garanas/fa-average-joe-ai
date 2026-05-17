# ADR 0002: Coordinator pattern for base components

## Status

Accepted — 2026-02-12.

## Context

A `JoeBase` is built out of components — claimed leaves, build sites, queued jobs, engineer assignments. Each component owns one slice of base state. Early on, components routinely reached sideways for data ("the engineer assignment component needs to know about claimed leaves") or upward into the owning brain ("which platoon owns this engineer?"). That worked, until the third or fourth time a small refactor required touching six call sites in three components.

The brain side had the same drift. Grid features (`GridReclaim`, `GridRecon`, `GridPresence`) were happy to be reached for from anywhere — bases asked them, behaviors asked them, the brain itself asked them, and the read patterns slowly diverged.

## Decision

There is exactly one place where components meet the outside world:

- **At the base scope:** `JoeBase` is the coordinator. Components do not call siblings and do not call the brain. The base reads from components, decides what to do with the combined state, and writes back.
- **At the army scope:** `JoeBrain` plays the same role for army-level components.

A component is **pure storage**: it answers "what is currently true" and accepts mutations from its coordinator. It does not answer "what should we do about it."

## Consequences

- **Predictable read path.** When debugging a stale field, you grep for `Base.<Field>` and see every reader and writer.
- **Easier component swaps.** A reclaim component can be replaced wholesale without auditing siblings.
- **Some duplication at the coordinator.** `JoeBase.TickThread` does some of the work that would otherwise live in components. We accept this — coordination *should* concentrate at the seam.

The rule is enforced by convention and code review. There is no engine-level mechanism preventing a component from reaching sideways; we just don't do it.
