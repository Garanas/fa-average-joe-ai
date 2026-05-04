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
---@field name string  # human-readable name
---@field fn fun()

---@class LoveLayoutRect
---@field x integer
---@field y integer
---@field w integer
---@field h integer

---@class LoveLayout
---@field viewport LoveLayoutRect
---@field topbar LoveLayoutRect
---@field sidebar LoveLayoutRect
---@field canvas LoveLayoutRect
---@field statusbar LoveLayoutRect
---@field timeline LoveLayoutRect

---@class LoveActions
---@field selectChunk fun(i: integer)
---@field save fun()
---@field undo fun()
---@field redo fun()

---@class LoveAppContext
---@field state LoveState
---@field actions LoveActions
---@field bindings LoveHotkeyBinding[]
---@field layout fun(self: LoveAppContext): LoveLayout

---@class LoveComponent
---@field draw fun(self: LoveComponent)
---@field mousepressed? fun(self: LoveComponent, mx: number, my: number, button: integer): boolean
---@field mousereleased? fun(self: LoveComponent, mx: number, my: number, button: integer): boolean
---@field mousemoved? fun(self: LoveComponent, mx: number, my: number): boolean
---@field keypressed? fun(self: LoveComponent, key: string): boolean

---@class LoveState
---@field shim LoveShim?
---@field modRoot string?
---@field chunks LoveChunkEntry[]
---@field selectedIndex integer?
---@field loadedTemplate LoveBaseChunk?
---@field loadError string?
---@field identifiers table<LoveBuildingIdentifier, LoveBuildingMetadata>?
---@field fonts table<string, any>
---@field history LoveHistory?
---@field dialogOpen string?
---@field saveStatus string?
