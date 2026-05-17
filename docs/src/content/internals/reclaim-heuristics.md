# Reclaim heuristics

`GridReclaim` is the brain-level view of what's worth reclaiming on the map. It doesn't decide *which engineer* goes where — that's the platoon behavior's job — but it does answer the question "if I had one engineer to spare, where should they go?"

## Cells, not units

The grid bucket size matches the map's reclaim cluster size — about 12 leaves. Per cell we store:

- The estimated total mass currently inside the cell.
- A staleness counter (how many ticks since we last refreshed this cell).
- A *contested* flag — has an enemy unit been observed in or adjacent to this cell recently?

Storing per-cell summaries instead of per-wreck records keeps memory bounded. A 20km map has ~6500 cells; per-wreck would be tens of thousands of records on a heavy-combat replay.

## Scoring

When a behavior asks for "the best reclaim cell within range," the score is:

```
score = mass * proximity_bonus * (1 - contested_penalty) * staleness_decay
```

The four factors do specific work:

1. **`mass`** — the cell's stored estimate. Cells under 50 mass are ignored.
2. **`proximity_bonus`** — `1 / (1 + travel_time)`. Engineers are slow; nearby cells beat far ones even when far ones are richer.
3. **`contested_penalty`** — 0 if no enemy nearby, ramps to ~0.8 if multiple sightings within the last 10 seconds.
4. **`staleness_decay`** — confidence drop. A cell we haven't looked at in 60s gets multiplied by `0.6`; we will probably revisit and find the mass is gone.

## Refresh policy

The grid does not poll. Cells are refreshed when:

- An engineer reclaiming in the cell reports completion (cell mass goes down, fresh confidence).
- A platoon moving through the cell observes wrecks and emits a "saw mass here" signal.
- The contested flag flips (we have a recon update).

Otherwise cells decay through the staleness factor. This is enough for our use case — perfect knowledge of the reclaim map is wasted compute if no engineer is available to act on it.
