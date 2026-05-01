# fa-joe-ai

The "Average Joe AI" mod for Supreme Commander: Forged Alliance Forever (FAF). Implements a thematic AI built on FAF's `AIBrain` extension surface.

## Layout

- [`lua/Sim/`](lua/Sim/) — sim-side code. `JoeBrain.lua` is the entry point; platoon behaviors live in `Sim/Behaviors/`; grid systems and utilities sit alongside.
- [`lua/Shared/`](lua/Shared/) — modules used by both sim and ui. Includes the base-chunks system.
- [`lua/ui/`](lua/ui/) — UI-side dialogs and components.
- [`hook/`](hook/) — engine overrides (e.g. `simInit.lua`, `aibrains/index.lua`, keymap hooks).
- [`vendor/`](vendor/) — read-only clones of upstream repos (e.g. `FAForever/fa`) for context. Gitignored.

## Nested CLAUDE.md docs

These load automatically when working in the relevant subtree — read them first when touching that area:

- [`lua/Sim/CLAUDE.md`](lua/Sim/CLAUDE.md) — Lua performance patterns for hot paths (per-tick sim, per-frame UI, generators): upvalue scoping, iteration, table reuse, profiling, common pitfalls.
- [`lua/Sim/Behaviors/CLAUDE.md`](lua/Sim/Behaviors/CLAUDE.md) — platoon behavior state machines: brain/base composition, state transitions, trash-bag lifecycle, squads, the fluent builder.
- [`lua/Shared/BaseChunks/CLAUDE.md`](lua/Shared/BaseChunks/CLAUDE.md) — base chunks: faction-agnostic building identifiers, on-disk (`JoeBaseChunk`) vs runtime (`JoeLoadedBaseChunk`) types, authoring workflow.

## Architectural patterns

- **AI brains** extend `AIBrain`. [`lua/Sim/JoeBrain.lua`](lua/Sim/JoeBrain.lua) composes grid-based features (`GridReclaim`, `GridRecon`, `GridPresence`).
- **Platoon behaviors** are goal-oriented state machines attached to platoons, owned and re-tasked by either a base manager (base-local platoons) or the brain (army-level / map-roaming forces). Details in [`lua/Sim/Behaviors/CLAUDE.md`](lua/Sim/Behaviors/CLAUDE.md).
- **Base chunks** are hand-authored, faction-agnostic blueprints for pieces of a base, tiled into the flat regions identified by the navigational mesh. Details in [`lua/Shared/BaseChunks/CLAUDE.md`](lua/Shared/BaseChunks/CLAUDE.md).
- **Hooks** in [`hook/`](hook/) override engine functions to inject mod behavior at well-defined seams (`simInit`, `aibrains/index`, sim callbacks, keymap).
- **Serialization** — `SerializeTable` / `SerializeValue` from [`lua/Utils.lua`](lua/Utils.lua) convert Lua tables back to source code (used to save base-chunk templates).

## Conventions

### Lua dialect
The engine runs a pre-5.1 Lua dialect. The `#` length operator does **not** exist — use `table.getn(t)` for tables and `string.len(s)` for strings. Localise both at module top per the perf conventions in [`lua/Sim/CLAUDE.md`](lua/Sim/CLAUDE.md):
```lua
local TableGetn = table.getn
local StringLen = string.len
```

### Formatting
- 4 spaces for indentation. No tabs.

### Naming
- **Classes** — CamelCase: `JoeBrain`, `JoeBaseChunkLoader`, `AIPlatoonBehavior`.
- **Functions** — CamelCase: `CreateTemplate`, `ChangeState`, `MapToCategory`.
- **Table keys / fields** — CamelCase: `self.Templates`, `self.BehaviorState`.
- **Local variables and parameters** — camelCase: `unitId`, `supportSquad`, `engineer`.

### Type annotations
- EmmyLua-style: `---@class`, `---@field`, `---@param`, `---@return`, `---@type`, `---@alias`.
- Mod-specific aliases (`JoeUnit`, `JoeBrain`, `JoeBuildingIdentifier`, …) are defined alongside the code that owns them. Reuse existing aliases instead of inventing parallel ones.

### Class systems
- `Class()` — full classes with metatable inheritance and lifecycle hooks (`OnCreate` / `OnDestroy`). Use for engine-integrated objects: units, platoons, behaviors.
- `ClassSimple()` — plain data classes without engine machinery. Use for managers, registries, value objects (e.g. [`JoeBaseChunkLoader`](lua/Shared/BaseChunks/JoeBaseChunkLoader.lua)).
- `ClassUI()` — UI controls extending maui types (`Bitmap`, `Group`, `Window`, …).

### Error handling
- Validate at module/system seams (public function inputs, file loads). Internal callers in trusted code paths don't need re-validation — `CreateTemplate`'s size/type bounds belong at that boundary, not on every internal helper.
