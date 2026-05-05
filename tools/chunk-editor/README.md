# Joe AI Chunk Editor

A Love2D editor for the base-chunk templates in [`lua/Shared/BaseChunks/`](../../lua/Shared/BaseChunks/). Visual placement and editing of buildings inside a chunk, with the same on-disk format the in-game `CreateTemplate` produces.

## Run

From the repo root:

    love tools/chunk-editor

## Folder mapping

The editor reads from and writes to `lua/Shared/BaseChunks/<Faction>/<chunk>.lua` directly:

- The sidebar lists every `.lua` file under `lua/Shared/BaseChunks/<Faction>/` — one row per chunk, grouped by faction (`Aeon`, `Cybran`, `Seraphim`, `UEF`).
- Loading a row reads the file, evaluates it under [shim.lua](shim.lua), and pulls out the `Template` global.
- Saving writes the in-memory template back to its source file using [serializer.lua](serializer.lua), preserving the same Lua-source format the in-game tools emit.
- "New" / "Save As" prompt for a path. By default they suggest the BaseChunks tree so newly-authored chunks land next to the existing ones.

Identifier metadata (color, footprint size, skirt size, skirt offset) is extracted from [`JoeBuildingIdentifiers.lua`](../../lua/Shared/BaseChunks/JoeBuildingIdentifiers.lua) at load time by walking the upvalues of `MapToMetadata`. New identifiers added there appear in the editor automatically.

## UI overview

| Pane | What it shows / does |
|---|---|
| **Top bar** | Two menus: **File** (new / load / import / reconfigure / save / save-as / expand / shrink) and **Build sites** (a masonry-laid catalog of every building identifier, click to add at the chunk centre). |
| **Sidebar** | All discovered chunks grouped by faction, with optional faction/size filters. Click to load. |
| **Groups panel** | The 10 control-group slots (1–9, 0). Click a slot to select its contents; the slot count and per-group totals are visible. |
| **Canvas** | The chunk grid with placed buildings. Click to select, drag to move, right-click to pan, wheel to zoom. Skirt and footprint of each building are drawn distinctly. |
| **Timeline** | Linear command history (every undoable action). Click to jump to that point. |
| **Status bar** | Last action, current cursor cell, dirty/saved indicator. |

## Hotkeys

### File

| Combo | Action |
|---|---|
| `Ctrl+N` | New — opens the "New chunk" dialog (name / faction / size). On Create, picks a save path and writes an empty template. |
| `Ctrl+O` | Load… — open a chunk file via the native file dialog. |
| `Ctrl+I` | Import… — flatten another chunk's groups into a new group inside the loaded chunk. |
| `Ctrl+R` | Reconfigure chunk — opens the dialog in edit mode, prefilled. Apply renames the chunk, retags faction, and resizes (drops out-of-bounds buildings on shrink). |
| `Ctrl+S` | Save — writes to the loaded chunk's source path. |
| `Ctrl+Shift+S` | Save As… — pick a path. Updates the sidebar after writing. |

### History

| Combo | Action |
|---|---|
| `Ctrl+Z` | Undo |
| `Ctrl+Y` / `Ctrl+Shift+Z` | Redo |

### View

| Combo | Action |
|---|---|
| `Ctrl+Up` / `Ctrl+Down` | Zoom in / out at the canvas centre |
| `Home` | Recenter — reset camera to fit the whole chunk |

### Selection

| Combo | Action |
|---|---|
| `Tab` / `Shift+Tab` | Walk forward/back through the selection-history stack (every selection change pushes a snapshot). |
| `Esc` | Cancel current drag, then dismiss any rubber-band, then clear selection. |
| Mouse: click / shift+click / alt+click | Select / add / remove a single building. |
| Mouse: drag in empty space | Rubber-band rectangle selection (additive with shift). |
| Mouse: shift+double-click | Flood-fill selection through edge-adjacent skirts (walls connect to walls, power gens to power gens; mismatched skirt offsets correctly don't connect). |

### Editing

| Combo | Action |
|---|---|
| `Delete` | Delete the selection. |
| `Insert` | Duplicate the selection one cell toward the chunk centre. |
| `Ctrl+E` | Detect overlaps — highlights any pair of skirts that overlap. |
| `←` `→` `↑` `↓` | Translate selection by 1 cell. Clamped so no selected building leaves the chunk. |
| `Shift+←` `→` `↑` `↓` | Translate selection by 4 cells. |

### Groups

| Combo | Action |
|---|---|
| `1`–`9`, `0` | Select the contents of group slot 1–10 (`0` = slot 10). |
| `Ctrl+1`–`9`, `Ctrl+0` | Move the current selection into group slot 1–10. After the move, the new selection is the full contents of that slot. |

The full hotkey list is also visible in-app via the `?` button (top-right corner of the canvas, opens the masonry-laid hotkey dialog).

## Implementation details

### Coordinate convention: `saved = worldCenter − 0.5`

Every location stored on disk follows the same convention: the X/Z values represent the building's **world centre minus 0.5**. This matches what `unit:GetPosition()` returns in-game after the `−0.5` normalisation in `GetLocations`, and matches what the engine's UI build templates expect.

For an integer-aligned save value:
- `worldCenter = saved + 0.5`
- `footprintTL = worldCenter − footprintSize/2 = (saved + 0.5) − footprintSize/2`
- `skirtTL = footprintTL + SkirtOffset` *(units.md's `Physics.SkirtOffsetX/Z` is measured from the footprint TL, not the centre)*

For a 1×1 wall (footprint 1, skirt 1, offset 0): `saved (3, 3)` → world centre `(3.5, 3.5)` → footprint TL `(3, 3)` → skirt TL `(3, 3)`. Wall fills cell (3, 3).

For a T1 land factory (footprint 5, skirt 8, offset −1.5): `saved (4, 4)` → world centre `(4.5, 4.5)` → footprint TL `(2, 2)` → skirt TL `(0.5, 0.5)`. Footprint covers cells (2..6) × (2..6), skirt covers (0.5..8.5) × (0.5..8.5).

### Two rectangles per building

The canvas renders two concentric rectangles for every placed building:

| Rect | What it is | How it's positioned | Visual |
|---|---|---|---|
| **Skirt** | The keep-out box the engine reserves around the unit. No other structure may overlap it. This is what governs adjacency and tiling. | TL = `loc + SkirtOffset + 0.5 − Footprint/2`. Width/height = `SizeX × SizeZ` (skirt size). | Translucent fill, thin dark outline. Selection / drag highlight goes around this rect. |
| **Footprint** | The cells the building physically occupies on the build grid. | TL = `loc + 0.5 − Footprint/2`. Width/height = `FootprintX × FootprintZ`. | Opaque fill in the same colour, dark thin outline. |

For 1×1 buildings (walls, T1 PD/AA/Naval Defense, sonars) where footprint == skirt, the two rectangles overlap exactly and look like a single solid building. For larger buildings — T1 power (1×1 inside 2×2), factory (5×5 inside 8×8), T2 SMD (2×2 inside 3×3), naval factories with their faction-asymmetric skirts — the inner footprint is clearly distinguishable from the surrounding keep-out box.

A small black dot at `(loc[1], loc[2])` marks the literal saved coordinate. With the world-centre−0.5 convention this lands on the cell-corner intersection at the upper-left of the central cell.

### Adjacency

Two buildings are considered **edge-adjacent** when their skirt rectangles share an edge (not just a corner) with their projections on the perpendicular axis overlapping. This is what `Shift+Double-click` flood-fills through.

Skirts whose offsets differ by a non-integer (e.g. wall offset `0` vs power-gen offset `−0.5`) can never share an edge cleanly — there's always a half-cell gap. That's the engine's actual behaviour: walls and power gens **cannot** be placed flush against each other, no matter how you arrange them. The flood-fill respects this: walls connect to walls, power gens connect to other 2×2-skirt buildings, but the two groups don't bridge.

### Game-side consumption

The editor's saved coords flow into the in-game pipeline at two seams:

1. **`ToBuildTemplate`** in [`JoeBaseChunkTemplate.lua`](../../lua/Shared/BaseChunks/JoeBaseChunkTemplate.lua) — converts the chunk to the engine's `UIBuildTemplate` for `PreviewTemplate`.
2. **`MapTemplate`** in [`Sim/Bases/Components/JoeBaseBuildSiteComponent.lua`](../../lua/Sim/Bases/Components/JoeBaseBuildSiteComponent.lua) — materialises the chunk as `JoeBuildSite`s on a nav-mesh leaf for engineers to consume.

Both paths are simple: they take each saved location and add `+ 0.5` on each axis to recover the world centre, then either feed it into the engine's build template (1) or compute a world position relative to the leaf's centre (2). No per-identifier offsets, no parity heuristics, no skirt-offset arithmetic — the editor has already done that work by storing the right value.

### Loader

Love2D's `love.filesystem` is sandboxed and its mount semantics shifted across versions, so the editor uses plain Lua `io.open` for reads and `io.popen` (`dir` / `ls`) for directory enumeration — works regardless of Love version. Chunk files are evaluated under a small env-shim ([shim.lua](shim.lua)) that stubs out the engine's `import` and `categories` globals.

### Pre-Groups migration

Some on-disk chunks predate the `Groups` table and have a flat top-level `Locations`. The loader migrates them on read into a single default group at slot 1 — the in-memory shape is always the new one regardless of source format.

### Group-slot densification

The serializer pads gaps in the `Groups` table with empty placeholder groups (`{ Name = "", Locations = {} }`) so the on-disk array part stays dense — without this, Lua's table serializer emits `<unsupported:nil>` between sparse slots. The loader strips placeholders on read so in-memory state stays sparse.

## Files

- [conf.lua](conf.lua) — Love2D window config.
- [main.lua](main.lua) — entrypoint, state, action wiring, top-level event dispatch.
- [shim.lua](shim.lua) — engine-global stubs and `import` resolver.
- [loader.lua](loader.lua) — identifier-metadata extraction and chunk-file loading.
- [serializer.lua](serializer.lua) — chunk-file write-back, including placeholder-group densification.
- [chunk_cache.lua](chunk_cache.lua) — caches parsed chunk metadata for the sidebar (size, faction, building counts, identifiers).
- [history.lua](history.lua) / [selection_history.lua](selection_history.lua) — undo/redo stacks.
- [hotkeys.lua](hotkeys.lua) — all key bindings, grouped for the hotkey dialog.
- [components/](components/) — UI widgets (sidebar, top bar, canvas, groups panel, timeline, status bar, dialogs).
- [commands/](commands/) — undoable commands (move / delete / insert / assign-group / import-group / resize / reconfigure).
