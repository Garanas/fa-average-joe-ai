---@meta

-- Editor-local mirror of the on-disk chunk schema. Love-prefixed so it sits
-- in its own namespace, independent of the mod's annotations.

---@alias LoveBuildingIdentifier string

---@class LoveBaseChunkLocation
---@field [1] integer  # X (in-chunk, saved-coord convention)
---@field [2] integer  # Z (in-chunk, saved-coord convention)
---@field [3] integer  # orientation (currently unused, always 0)

---@class LoveBaseChunk
---@field Name string
---@field Size integer
---@field Faction string
---@field Units string[]
---@field Locations table<LoveBuildingIdentifier, LoveBaseChunkLocation[]>

---@class LoveBuildingMetadata
---@field Color string  # 6-char hex, no leading '#'
---@field SizeX integer
---@field SizeZ integer
---@field Category any  # opaque engine entity-category; black-holed in shim

---@class LoveCommand
---@field apply fun(self: LoveCommand, template: LoveBaseChunk)
---@field undo fun(self: LoveCommand, template: LoveBaseChunk)
---@field describe? fun(self: LoveCommand): string

---@class LoveChunkEntry
---@field faction string
---@field file string
---@field fsPath string

---@class LoveHotkeyBinding
---@field keys string  # normalized combo: "ctrl+z", "ctrl+shift+z", "ctrl+s"
---@field name string  # human-readable name (future help UI)
---@field fn fun()
