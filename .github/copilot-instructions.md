# Copilot Instructions for fa-joe-ai

## Project Overview
- **Purpose:** Implements "Average Joe AI" for Supreme Commander: Forged Alliance Forever (FAF), focusing on thematic AI behavior.
- **Structure:**
  - `lua/AI/`: Main AI logic (e.g., `JoeBrain.lua`)
  - `lua/Concepts/`: Core data structures (e.g., `JoeBaseChunkTemplate.lua`)
  - `lua/Shared/`: Cross-cutting utilities (e.g., `BaseChunkManager.lua`)
  - `hook/`: Game engine hooks and overrides

## Key Architectural Patterns
- **AI Brains:** Extend `AIBrain` (see `JoeBrain.lua`). Use composition for grid-based features (`GridReclaim`, `GridRecon`, `GridPresence`).
- **Base Chunk Templates:** Defined in `JoeBaseChunkTemplate.lua` and managed via `BaseChunkManager.lua`. Templates describe base layouts and are used for build planning.
- **Serialization:** Use `SerializeTable`/`SerializeValue` from `Utils.lua` for converting Lua tables to strings/files.
- **Hooks:** Place engine overrides in `hook/` (e.g., `simInit.lua`, `aibrains/`).

## Project-Specific Conventions
- **Type Annotations:** Use EmmyLua-style comments for type hints (e.g., `---@class`, `---@param`).
- **Class Definitions:** Use `ClassSimple` or `Class` for OOP patterns.
- **Error Handling:** Defensive checks (e.g., size bounds in `CreateTemplate`).

## Indenting and formatting
- Use 4 spaces for indentation.
- Convert all tabs to spaces.

## Naming conventions
- Use `CamelCase` for class names (e.g., `JoeBrain`).
- Use `CamelCase` for table keys (e.g., `self.Templates`)
- Use `CamelCase` for function names (e.g., `CreateTemplate`, `FindTemplate`).
- Use `pascalCase` for local variables and parameters (e.g., `createTemplate`)

---

**Feedback Requested:**
- Are any architectural details, workflows, or conventions unclear or missing?
- Should more examples or explanations be added for specific files or patterns?
