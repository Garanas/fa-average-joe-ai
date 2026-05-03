# Base chunks

A **base chunk** is a small, hand-authored, faction-specific blueprint for a piece of a base — a square arrangement of structures that fits inside a region of flat ground. Chunks come in five fixed sizes: **4×4, 8×8, 16×16, 32×32, 64x64, 128×128**. Larger areas are not supported as a single chunk; the planner subdivides them into smaller chunks instead.

The base layout pipeline runs in two stages:

1. **Navigational mesh chunks** — the nav-mesh already partitions the map by traversability. Those partitions tell us *where* flat, build-suitable ground exists.
2. **Base chunks** — once we have a flat region, we tile it with chunks from this directory to decide *what* gets built where. Each chunk encodes a specific composition (e.g. "T1 power array", "T1 land factories with AA & walls").

This directory holds the chunk templates plus the building-identifier abstraction that lets templates be reused across factions.

## Files in this tree

- [JoeLoadedBaseChunk.lua](JoeLoadedBaseChunk.lua) — type definitions, template authoring (`CreateTemplate`), serialization (`SerializeTemplate`), and the debug preview path (`ToBuildTemplate` / `PreviewTemplate`).
- [JoeBuildingIdentifiers.lua](JoeBuildingIdentifiers.lua) — the `JoeBuildingIdentifier` alias (a faction-agnostic catalog of structure roles like `T1LandFactory`, `Wall`, `T2Artillery`), the identifier → entity-category map, and the mapping-order priority list used to assign one identifier to each unit.
- [JoeBaseChunkLoader.lua](JoeBaseChunkLoader.lua) — runtime registry. `CreateDefaultJoeBaseChunkLoader()` loads the curated set of chunks the AI uses.
- `UEF/`, future `Aeon/` / `Cybran/` / `Seraphim/` — generated chunk files, one per chunk, named `<role>_<size>x<size>_<index>.lua`.

## Building identifiers: the faction-agnostic layer

A chunk doesn't reference faction-specific unit IDs directly. Instead, every location is tagged with a `JoeBuildingIdentifier` — a string label like `T1LandFactory` or `Wall` that names a *role*. At build time the AI resolves identifier → entity-category → faction-specific unit ID:

```
identifier "T1LandFactory"
  → categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1
  → ueb0101  (UEF)  /  uab0101  (Aeon)  /  ...
```

This is what makes a UEF-authored chunk reusable across factions: the *positions* are faction-agnostic, only the unit IDs cached in the file's `Units` list are UEF-specific (and they're informational — the loader doesn't depend on them).

`MapToCategoryForBuilder` extends this by intersecting the category with the engineer's faction, which is what gets fed into `EntityCategoryGetUnitList` to pick the actual unit to build.

### The `MappingOrder` priority list

`MapToIdentifier(unitId)` walks [`MappingOrder`](JoeBuildingIdentifiers.lua#L176) and returns the first identifier whose entity category contains the unit. **The order matters.** Many units satisfy multiple identifiers — a T1 mass extractor counts as a `STRUCTURE`, a T1 building, *and* a thing that produces resources, so it could match `T1Resource`, `T1EnergyProduction` (it produces a small amount of energy in some mods), or others.

The list is sorted **most-restrictive first, least-restrictive last**. Resource extractors come before energy production because some extractors trickle a small amount of energy. Storage and basic energy production sit at the bottom because many buildings have incidental storage/production. If you add a new identifier, slot it where its specificity belongs — adding it at the top will swallow units that should match later entries; adding it at the bottom will let earlier entries swallow it.

### Caching

`MappedUnits` caches the unit-ID → identifier resolution. This is safe because unit categories don't change at runtime. **Don't add an identifier or change the order while the game is running** — cached entries from before the change will still be served.

## Template structure (on-disk format)

A chunk file exports a global `Template` table conforming to `JoeBaseChunk`:

```lua
---@type JoeBaseChunk
Template = {
    Name = "Power - 01",
    Faction = "UEF",
    Size = 8,
    Units = { "ueb5101", "ueb1101" },   -- informational; faction-specific unit IDs
    Locations = {
        T1EnergyProduction = {
            { 5, 2, 0 },                 -- {X, Z, orientation}
            { 2, 2, 0 },
            ...
        },
        Wall = {
            { 7, 3, 0 },
            ...
        },
    },
}
```

- **`Size`** is the side length in world units. Must be one of 4, 8, 16, 32, 128.
- **`Locations`** is keyed by `JoeBuildingIdentifier`, valued by an array of `JoeBaseChunkLocation` triples — `{ X, Z, orientation }`. Coordinates are *in-chunk*, in the range `[0, Size)`. The third entry is reserved for orientation but **currently unused**.
- **`Units`** is a flat list of unique faction-specific unit IDs that appear in the chunk. It exists to make entity-category interactions cheaper — it is *not* used to drive placement.
- **`Faction`** identifies the faction the chunk was authored for. The chunk can still be cross-built (the identifier layer handles that), but this field carries the authoring intent.

### The `-0.5` half-cell adjustment

Supreme Commander offsets buildings by 0.5 in world space (a 1×1 footprint sitting on integer coordinates is actually centered at `x.5`). Authoring code in `GetLocations` (see [JoeLoadedBaseChunk.lua:79-86](JoeLoadedBaseChunk.lua#L79-L86)) subtracts 0.5 from both axes to keep saved offsets clean. The reverse adjustment lives in `TemplateAxisOffset` ([L150-L152](JoeLoadedBaseChunk.lua#L150-L152)), which restores the 0.5 only for buildings with odd footprint dimensions during preview. Don't try to "fix" coordinates that look 0.5-off in saved files — that's the convention.

## Loader

[`JoeBaseChunkLoader`](JoeBaseChunkLoader.lua) is a flat registry of loaded templates. `LoadTemplate(file, field)` imports a chunk file, pulls out the `Template` global (override via `field`), stamps `Source` and `SourceField` onto it for traceability, and adds it to the registry.

`CreateDefaultJoeBaseChunkLoader()` builds the canonical instance with every shipped chunk file pre-registered. The whole load is wrapped in `pcall` so a single broken chunk file warns rather than crashes the AI. **Add new chunks here** — the registry is the only discovery surface.

## Authoring a new chunk

1. **Place the buildings in-game** as a normal player would.
2. **Capture the layout** with `JoeLoadedBaseChunk.CreateTemplate(units, size)`. `units` is a list of `JoeUnit` (or `UserUnit`) handles for the structures you want included; `size` is one of the supported chunk sizes.
3. **Serialize** via `JoeLoadedBaseChunk.SerializeTemplate(template)` — returns Lua source code.
4. **Save** to `<Faction>/<role>_<size>x<size>_<index>.lua` (e.g. `UEF/land_32x32_03.lua`). Naming convention: lowercase `<role>` (e.g. `power`, `land`, `air`, `special`, `random`), zero-padded size, `_NN` index.
5. **Register** the new file in `CreateDefaultJoeBaseChunkLoader` in [JoeBaseChunkLoader.lua](JoeBaseChunkLoader.lua).
6. **Verify visually** with `PreviewTemplate(template)` — snaps the chunk into the build cursor as a UI build template so you can drop it on the map and confirm the layout matches what you authored.

## Debug & visual verification

`ToBuildTemplate(template)` converts a `JoeBaseChunk` into the `UIBuildTemplate` shape the engine's command mode understands. Useful both for `PreviewTemplate` and for any future tooling that wants to render a chunk in the UI. Note the offset-normalization at [L192-L200](JoeLoadedBaseChunk.lua#L192-L200) — it shifts the whole template so the first building lands at `(0, 0)` regardless of where it was authored.

## Disk vs runtime: `JoeBaseChunk` vs `JoeLoadedBaseChunk`

The two type aliases describe the same data at two stages of its life:

- **`JoeBaseChunk`** — the shape that lives in a chunk file. Has `Name`, `Size`, `Faction`, `Units`, `Locations`. This is what `CreateTemplate` produces and `SerializeTemplate` writes out.
- **`JoeLoadedBaseChunk : JoeBaseChunk`** — the runtime form, after the loader has stamped on `Source` (file path) and `SourceField` (field name in the file, default `"Template"`). Use this anywhere you need to point back at the file the chunk came from.

`Locations` always uses positional `JoeBaseChunkLocation` triples (`{ X, Z, orientation }`). There is no named-field shape — if you encounter `OffsetX` / `OffsetY` somewhere, that's a leftover from before the refactor and should be ported.

## Conventions and pitfalls

1. **Adding a new building identifier requires three edits.** Add the alias to the `JoeBuildingIdentifier` doc comment, the entry to `MapToEntityCategories`, *and* a slot in `MappingOrder` at the right specificity level. Forgetting any of these is silent — `MapToCategory` will throw at runtime, `MapToIdentifier` will throw, or the unit will be miscategorized.
2. **Order matters in `MappingOrder`.** Most-restrictive identifiers first; least-restrictive (incidental energy/storage) last. Don't append blindly to the end.
3. **Identifier resolution is cached.** Don't mutate the mapping after the game has started.
4. **Coordinates are in-chunk offsets, not world coordinates.** They live in `[0, Size)`. The `0.5` adjustment is intentional and matches engine conventions.
5. **Orientation is reserved but unused.** The third element of every location triple is `0` and the AI ignores it. Don't read it as a real value yet — when orientation lands, every existing chunk needs reviewing.
6. **`Size` is asserted to be `1..256`** in `CreateTemplate`, but the **only sizes supported by the planner are 4, 8, 16, 32, 128.** The assertion is a soft guard — don't author other sizes even though the function won't reject them.
7. **Chunks are faction-agnostic in *position* but faction-tagged in `Faction` and `Units`.** Cross-faction reuse works through the identifier layer; don't try to make `Faction` mean something it doesn't.
8. **Register every new chunk in `CreateDefaultJoeBaseChunkLoader`.** Files not listed there are not discovered.
