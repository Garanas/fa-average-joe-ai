# Joe AI Chunk Editor

A Love2D viewer for the base-chunk templates in [`lua/Shared/BaseChunks/`](../../lua/Shared/BaseChunks/).

## Run

From the repo root:

    love tools/chunk-editor

## Controls

- Click a chunk in the sidebar — load and render it.
- Up / Down — cycle through chunks.
- Esc — quit.

## How it loads mod files

Love2D's `love.filesystem` is sandboxed and its mount semantics shifted across versions, so the editor uses plain Lua `io.open` for reads and `io.popen` (`dir`/`ls`) for directory enumeration — works regardless of Love version. Chunk files are evaluated under a small env-shim that stubs out the engine's `import` and `categories` globals (see [shim.lua](shim.lua)). Identifier metadata (`Color`, `SizeX`, `SizeZ`) is extracted from [`JoeBuildingIdentifiers.lua`](../../lua/Shared/BaseChunks/JoeBuildingIdentifiers.lua) by walking the upvalues of `MapToMetadata`.

## Status

Viewer only — no editing yet. Coordinates render as `(X, Y)` rectangles sized by the identifier's `SizeX/SizeZ`; the half-cell engine offset is **not** applied here, matching the on-disk convention. Pre-existing tooling (`SerializeValue` in [`lua/Utils.lua`](../../lua/Utils.lua)) is the intended write-back path when editing lands.

## Files

- [conf.lua](conf.lua) — Love2D window config.
- [main.lua](main.lua) — entrypoint, sidebar, render loop, input.
- [shim.lua](shim.lua) — engine-global stubs and `import` resolver.
- [loader.lua](loader.lua) — identifier-metadata extraction and chunk-file loading.
