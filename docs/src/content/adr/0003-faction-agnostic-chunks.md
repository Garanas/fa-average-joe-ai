# ADR 0003: Faction-agnostic base chunks

## Status

Accepted — 2026-03-04.

## Context

Base chunks are hand-authored blueprints for pieces of a base, tiled into flat regions of the navigational mesh. A naive first cut wrote the chunk as a list of concrete blueprint ids — `ueb1101`, `ueb1103`, and so on. That meant every chunk had to be authored four times, once per faction.

We did this once. It was awful: the four copies drifted within a sprint, and the cybran-only player tester noticed that the "T2 power adjacency" chunk had different power placements per faction by accident.

## Decision

Chunks reference **building identifiers**, not blueprint ids. An identifier names *what* the building is (`T2_Power`, `T3_HQ`, `Wall_Section`, `Point_Defense`) without committing to *which faction* provides it. At load time, `JoeBaseChunkLoader` resolves identifiers against the building owner's faction.

```lua
-- A chunk file
return {
    leaves = { ... },
    buildings = {
        { id = JBI.T3_HQ,         position = { 0,  0 } },
        { id = JBI.T2_Power,      position = { 6,  0 } },
        { id = JBI.T2_Power,      position = { 6,  3 } },
        { id = JBI.Wall_Section,  position = { 9,  0 } },
    },
}
```

## Consequences

- **One chunk authored, four factions covered.** Editing the chunk in the in-game editor edits all four faction renderings at once.
- **The identifier table is the long part.** `JoeBuildingIdentifiers` is now ~200 lines of `T1_Land_Factory = "..."` and similar. Worth it — every consumer reads from one source.
- **Some buildings have no cross-faction analog.** Shields, for example — only Aeon and Seraphim have hover-T1 PD with the same footprint. We annotate identifiers with their footprint in `JoeBuildingFootprints` and skip chunks that reference a faction-missing identifier.

See [`lua/Shared/BaseChunks/CLAUDE.md`](https://github.com/Garanas/fa-joe-ai/blob/main/lua/Shared/BaseChunks/CLAUDE.md) for the authoring workflow.
