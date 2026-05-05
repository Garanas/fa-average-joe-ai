---@meta

-- Editor-local mirror of the on-disk chunk schema. Love-prefixed so it sits
-- in its own namespace, independent of the mod's annotations.

---@alias LoveBuildingIdentifier string

---@class LoveBaseChunkLocation
---@field [1] integer  # X (in-chunk, saved-coord convention)
---@field [2] integer  # Z (in-chunk, saved-coord convention)
---@field [3] integer  # orientation (currently unused, always 0)

---@class LoveBaseChunkGroup
---@field Name string
---@field Locations table<LoveBuildingIdentifier, LoveBaseChunkLocation[]>

---@class LoveBaseChunk
---@field Name string
---@field Size integer
---@field Faction string
---@field Units string[]
---@field Groups table<integer, LoveBaseChunkGroup>  # sparse, slots 1..10. Slot 10 = "0" hotkey.

---@class LoveBuildingMetadata
---@field Color string  # 6-char hex, no leading '#'
---@field FootprintX number  # cells the building physically occupies on the X axis; see units.md
---@field FootprintZ number
---@field SizeX integer  # skirt size X (keep-out rectangle the engine reserves)
---@field SizeZ integer
---@field SkirtOffsetX number  # offset of the skirt rectangle from the footprint TL on the X axis; see units.md
---@field SkirtOffsetZ number
---@field Category any  # opaque engine entity-category; black-holed in shim

---@class LoveCommand
---@field apply fun(self: LoveCommand, template: LoveBaseChunk)
---@field undo fun(self: LoveCommand, template: LoveBaseChunk)
---@field describe? fun(self: LoveCommand): string

---@class LoveChunkEntry
---@field faction string                              # parent folder name (e.g. "UEF")
---@field file string                                 # filename (e.g. "land_16x16_01.lua")
---@field fsPath string                               # absolute path
---@field name string?                                # template.Name (cached after load)
---@field size integer?                               # template.Size
---@field templateFaction string?                     # template.Faction (may differ from folder)
---@field buildingCount integer?
---@field groupCount integer?
---@field identifiers table<string, boolean>?        # set of identifiers used by the chunk
---@field error string?                               # populated if the chunk failed to load

---@class LoveHotkeyBinding
---@field keys string  # normalized combo: "ctrl+z", "ctrl+shift+z", "ctrl+s"
---@field name string  # human-readable name
---@field group string # bucket label used by the hotkey dialog's masonry layout
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
---@field groups LoveLayoutRect
---@field canvas LoveLayoutRect
---@field statusbar LoveLayoutRect
---@field timeline LoveLayoutRect

---@class LoveNewChunkPayload
---@field name string
---@field faction string
---@field size integer

---@class LoveActions
---@field selectChunk fun(i: integer)
---@field loadPath fun(path: string)
---@field new fun()
---@field createNewChunk fun(payload: LoveNewChunkPayload)
---@field load fun()
---@field importChunk fun(path: string?)
---@field save fun()
---@field saveAs fun()
---@field expandChunk fun()
---@field shrinkChunk fun()
---@field reconfigureChunk fun()
---@field applyReconfigure fun(payload: LoveNewChunkPayload)
---@field undo fun()
---@field redo fun()
---@field recenter fun()
---@field zoomIn fun()
---@field zoomOut fun()
---@field nextSelection fun()
---@field prevSelection fun()
---@field assignGroup fun(slot: integer)
---@field selectGroup fun(slot: integer)
---@field deleteSelected fun()
---@field duplicateSelected fun()
---@field translateSelection fun(dx: integer, dz: integer)
---@field addBuilding fun(identifier: LoveBuildingIdentifier)

---@class LoveChunkFilter
---@field faction string?  # nil = any faction
---@field size integer?    # nil = any size

---@class LoveAppContext
---@field state LoveState
---@field actions LoveActions
---@field bindings LoveHotkeyBinding[]
---@field layout fun(self: LoveAppContext): LoveLayout
---@field isDirty fun(self: LoveAppContext): boolean
---@field filteredChunks fun(self: LoveAppContext): LoveChunkEntry[]

---@class LoveComponent
---@field draw fun(self: LoveComponent)
---@field mousepressed? fun(self: LoveComponent, mx: number, my: number, button: integer): boolean
---@field mousereleased? fun(self: LoveComponent, mx: number, my: number, button: integer): boolean
---@field mousemoved? fun(self: LoveComponent, mx: number, my: number): boolean
---@field wheelmoved? fun(self: LoveComponent, x: number, y: number, mx: number, my: number): boolean
---@field keypressed? fun(self: LoveComponent, key: string): boolean
---@field textinput? fun(self: LoveComponent, text: string): boolean

---@class LoveState
---@field shim LoveShim?
---@field modRoot string?
---@field chunks LoveChunkEntry[]
---@field currentPath string?  # filesystem path of the loaded chunk; nil for an unsaved new chunk
---@field loadedTemplate LoveBaseChunk?
---@field loadError string?
---@field identifiers table<LoveBuildingIdentifier, LoveBuildingMetadata>?
---@field fonts table<string, any>
---@field history LoveHistory?
---@field selection table<string, boolean>
---@field selectionHistory LoveSelectionHistory
---@field chunkCache LoveChunkCache?
---@field chunkFilter LoveChunkFilter
---@field mouseChunk { x: integer, z: integer }?  # under-cursor cell when mouse is inside the chunk; nil otherwise
---@field dialogOpen string?
---@field saveStatus string?
