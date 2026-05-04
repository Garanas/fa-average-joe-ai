local Shim = require("shim")
local Loader = require("loader")
local Serializer = require("serializer")
local History = require("history")
local SelectionHistory = require("selection_history")
local Hotkeys = require("hotkeys")
local FileDialog = require("file_dialog")
local ImportGroup = require("commands.ImportGroup")
local ResizeChunk = require("commands.ResizeChunk")
local ReconfigureChunk = require("commands.ReconfigureChunk")
local Snapshot = require("commands.group_snapshot")
local ChunkCache = require("chunk_cache")

local TopBar = require("components.TopBar")
local Sidebar = require("components.Sidebar")
local GroupsPanel = require("components.GroupsPanel")
local ChunkCanvas = require("components.ChunkCanvas")
local StatusBar = require("components.StatusBar")
local Timeline = require("components.Timeline")
local HotkeyDialog = require("components.HotkeyDialog")
local NewChunkDialog = require("components.NewChunkDialog")

local TOPBAR_H = 24
local SIDEBAR_W = 240
local GROUPS_W = 140
local STATUSBAR_H = 28
local TIMELINE_H = 76

local SUPPORTED_SIZES = { 4, 8, 16, 32, 64, 128 }

---@param size integer
---@param direction integer  # +1 for next-larger, -1 for next-smaller
---@return integer?
local function adjacentSupportedSize(size, direction)
    if direction > 0 then
        for _, s in ipairs(SUPPORTED_SIZES) do
            if s > size then return s end
        end
    else
        for i = #SUPPORTED_SIZES, 1, -1 do
            if SUPPORTED_SIZES[i] < size then return SUPPORTED_SIZES[i] end
        end
    end
    return nil
end

---@type LoveState
local state = {
    shim = nil,
    modRoot = nil,
    chunks = {},
    currentPath = nil,
    loadedTemplate = nil,
    loadError = nil,
    identifiers = nil,
    fonts = {},
    history = nil,
    selection = {},
    selectionHistory = SelectionHistory.new(),
    chunkFilter = { faction = nil, size = nil },
    dialogOpen = nil,
    saveStatus = nil,
}

---@return LoveChunkEntry[]
local function filteredChunks()
    local f = state.chunkFilter
    if (not f.faction) and (not f.size) then return state.chunks end
    local out = {}
    for _, e in ipairs(state.chunks) do
        if (not f.faction or e.faction == f.faction)
            and (not f.size or e.size == f.size) then
            table.insert(out, e)
        end
    end
    return out
end

---@type LoveChunkCanvas?  -- forward declaration; assigned after components are built
local canvas

---@type LoveNewChunkDialog?  -- forward declaration; assigned with the rest of the components
local newChunkDialog

local function parentDir(p)
    p = p:gsub("[/\\]+$", "")
    return p:match("^(.*)[/\\][^/\\]+$") or p
end

local function isDirty()
    if not state.loadedTemplate then return false end
    if not state.currentPath then return true end
    return state.history and state.history:isDirty() or false
end

local function discardCheck()
    if not isDirty() then return end
    if state.currentPath then
        print("Discarding unsaved changes in " .. state.currentPath)
    else
        print("Discarding new (unsaved) chunk")
    end
end

local function loadChunkByPath(path)
    discardCheck()
    state.currentPath = path
    state.history = History.new()
    state.selection = {}
    state.selectionHistory = SelectionHistory.new()
    state.saveStatus = nil
    local tmpl, err = Loader.loadChunk(state.shim, path)
    state.loadedTemplate = tmpl
    state.loadError = err
    if err then print("Load error for " .. path .. ": " .. tostring(err)) end
    if canvas then canvas:onChunkChange() end
end

local function selectChunk(i)
    local entry = state.chunks[i]
    if not entry then return end
    loadChunkByPath(entry.fsPath)
end

local function newChunk()
    state.dialogOpen = "newchunk"
end

---@return string  # filesystem path that's safe to use as a default dir for dialogs
local function defaultDialogDir()
    if state.currentPath then
        return parentDir(state.currentPath)
    end
    if state.modRoot then
        return state.modRoot .. "/lua/Shared/BaseChunks"
    end
    return "."
end

---@param payload LoveNewChunkPayload
local function createNewChunk(payload)
    if not payload or not payload.name or payload.name == "" then return end

    ---@type LoveBaseChunk
    local tmpl = {
        Name = payload.name,
        Faction = payload.faction or "UEF",
        Size = payload.size or 16,
        Units = {},
        Groups = { [1] = { Name = "default", Locations = {} } },
    }

    local defaultName = (payload.name or "untitled"):gsub("%s+", "_") .. ".lua"
    local path = FileDialog.saveFile(defaultDialogDir(), defaultName)
    if not path then return end

    -- Write the empty template to disk first, then load it as the current
    -- chunk so the editor treats it like any other on-disk chunk.
    local source = Serializer.serializeTemplate(tmpl)
    local f, err = io.open(path, "wb")
    if not f then
        state.saveStatus = "Save failed: " .. tostring(err)
        print(state.saveStatus)
        return
    end
    f:write(source)
    f:close()

    discardCheck()
    state.currentPath = path
    state.history = History.new()
    state.selection = {}
    state.selectionHistory = SelectionHistory.new()
    state.loadedTemplate = tmpl
    state.loadError = nil
    state.saveStatus = "Created"
    print("Created " .. path)

    if state.chunkCache then state.chunkCache:rebuild() end
    if canvas then canvas:onChunkChange() end
end

local function loadAction()
    local path = FileDialog.openFile(defaultDialogDir())
    if not path then return end
    loadChunkByPath(path)
end

--- Pick a chunk file (or use the supplied path), flatten all of its groups
--- into a single Locations dict, and drop it as a new group into the lowest
--- empty slot of the currently-loaded chunk.
---@param path string?  # if nil, prompts via the file dialog
local function importChunkAction(path)
    local current = state.loadedTemplate
    if not current then
        state.saveStatus = "Import failed: no chunk loaded"
        print(state.saveStatus)
        return
    end

    if not path then
        path = FileDialog.openFile(defaultDialogDir())
        if not path then return end
    end

    local imported, err = Loader.loadChunk(state.shim, path)
    if err or not imported then
        state.saveStatus = "Import failed: " .. tostring(err or "unknown")
        print(state.saveStatus)
        return
    end

    if imported.Size > current.Size then
        state.saveStatus = string.format(
            "Import failed: source is %dx%d, larger than the current %dx%d chunk",
            imported.Size, imported.Size, current.Size, current.Size)
        print(state.saveStatus)
        return
    end

    -- Flatten all of the imported template's groups into one Locations dict.
    local flat = {}
    local count = 0
    for _, group in pairs(imported.Groups or {}) do
        for id, locs in pairs(group.Locations or {}) do
            flat[id] = flat[id] or {}
            for _, loc in ipairs(locs) do
                table.insert(flat[id], { loc[1], loc[2], loc[3] })
                count = count + 1
            end
        end
    end
    if count == 0 then
        state.saveStatus = "Import failed: source has no buildings"
        print(state.saveStatus)
        return
    end

    -- Find the lowest empty slot.
    current.Groups = current.Groups or {}
    local destSlot
    for slot = 1, 10 do
        if not current.Groups[slot] then
            destSlot = slot
            break
        end
    end
    if not destSlot then
        state.saveStatus = "Import failed: all 10 group slots are in use"
        print(state.saveStatus)
        return
    end

    local sourceLabel = imported.Name or path:match("([^/\\]+)%.lua$") or "imported"

    local beforeSlots = { [destSlot] = false }
    local afterSlots = {
        [destSlot] = { Name = sourceLabel, Locations = flat },
    }
    local cmd = ImportGroup.new(destSlot, sourceLabel, beforeSlots, afterSlots)
    state.history:apply(current, cmd)
    if canvas then canvas:selectGroup(destSlot) end
    state.saveStatus = string.format("Imported '%s' to slot %d", sourceLabel, destSlot)
    print(state.saveStatus)
end

local function writeTemplateTo(path)
    local tmpl = state.loadedTemplate
    if not tmpl then return false end
    local source = Serializer.serializeTemplate(tmpl)
    local f, err = io.open(path, "wb")
    if not f then
        state.saveStatus = "Save failed: " .. tostring(err)
        print(state.saveStatus)
        return false
    end
    f:write(source)
    f:close()
    return true
end

--- Resize the chunk to the next supported size in the given direction.
--- Shrinking drops any building whose anchor lands outside the new bounds;
--- the removed buildings are restored on undo.
---@param direction integer  # +1 = expand, -1 = shrink
local function resizeChunk(direction)
    local tmpl = state.loadedTemplate
    if not tmpl then return end

    local oldSize = tmpl.Size or 16
    local newSize = adjacentSupportedSize(oldSize, direction)
    if not newSize then
        state.saveStatus = string.format("Cannot %s past %dx%d",
            direction > 0 and "expand" or "shrink", oldSize, oldSize)
        print(state.saveStatus)
        return
    end

    local groups = tmpl.Groups or {}

    -- Snapshot every existing slot so undo restores the full template.
    local affectedSlots = {}
    for slot in pairs(groups) do affectedSlots[slot] = true end

    local beforeSlots = {}
    for slot in pairs(affectedSlots) do
        beforeSlots[slot] = Snapshot.deepCopyGroup(groups[slot])
    end

    local afterSlots = {}
    local removedCount = 0
    for slot in pairs(affectedSlots) do
        local copy = Snapshot.deepCopyGroup(groups[slot])
        if copy then
            local newLocs = {}
            for id, locs in pairs(copy.Locations or {}) do
                local kept = {}
                for _, loc in ipairs(locs) do
                    if loc[1] < newSize and loc[2] < newSize then
                        table.insert(kept, loc)
                    else
                        removedCount = removedCount + 1
                    end
                end
                if #kept > 0 then newLocs[id] = kept end
            end
            copy.Locations = newLocs
            if Snapshot.isGroupEmpty(copy) then
                afterSlots[slot] = false
            else
                afterSlots[slot] = copy
            end
        else
            afterSlots[slot] = false
        end
    end

    local cmd = ResizeChunk.new(oldSize, newSize, beforeSlots, afterSlots, removedCount)
    state.history:apply(tmpl, cmd)
    if canvas then
        canvas:validateSelection()
        canvas:reset()
    end
    if removedCount > 0 then
        state.saveStatus = string.format("%s to %dx%d (removed %d out-of-bounds)",
            direction > 0 and "Expanded" or "Shrunk", newSize, newSize, removedCount)
    else
        state.saveStatus = string.format("%s to %dx%d",
            direction > 0 and "Expanded" or "Shrunk", newSize, newSize)
    end
    print(state.saveStatus)
end

local function expandChunkAction() resizeChunk(1) end
local function shrinkChunkAction() resizeChunk(-1) end

--- Open the New Chunk dialog in edit mode, prefilled from the current chunk.
local function reconfigureChunkAction()
    local tmpl = state.loadedTemplate
    if not tmpl or not newChunkDialog then return end
    newChunkDialog:openForEdit(tmpl.Name or "Untitled", tmpl.Faction or "UEF", tmpl.Size or 16)
    state.dialogOpen = "newchunk"
end

--- Apply the dialog payload to the loaded chunk: rename, retag faction, and
--- (if the size changed) drop any out-of-bounds buildings. Bundled into a
--- single ReconfigureChunk command so undo restores the whole previous shape.
---@param payload LoveNewChunkPayload
local function applyReconfigureAction(payload)
    local tmpl = state.loadedTemplate
    if not tmpl or not payload then return end

    local oldName = tmpl.Name or ""
    local oldFaction = tmpl.Faction or "UEF"
    local oldSize = tmpl.Size or 16
    local newName = payload.name or oldName
    local newFaction = payload.faction or oldFaction
    local newSize = payload.size or oldSize

    if newName == oldName and newFaction == oldFaction and newSize == oldSize then
        state.saveStatus = "No changes"
        return
    end

    local groups = tmpl.Groups or {}
    local affectedSlots = {}
    for slot in pairs(groups) do affectedSlots[slot] = true end

    local beforeSlots = {}
    for slot in pairs(affectedSlots) do
        beforeSlots[slot] = Snapshot.deepCopyGroup(groups[slot])
    end

    local afterSlots = {}
    local removedCount = 0
    for slot in pairs(affectedSlots) do
        local copy = Snapshot.deepCopyGroup(groups[slot])
        if copy then
            local newLocs = {}
            for id, locs in pairs(copy.Locations or {}) do
                local kept = {}
                for _, loc in ipairs(locs) do
                    if loc[1] < newSize and loc[2] < newSize then
                        table.insert(kept, loc)
                    else
                        removedCount = removedCount + 1
                    end
                end
                if #kept > 0 then newLocs[id] = kept end
            end
            copy.Locations = newLocs
            if Snapshot.isGroupEmpty(copy) then
                afterSlots[slot] = false
            else
                afterSlots[slot] = copy
            end
        else
            afterSlots[slot] = false
        end
    end

    local cmd = ReconfigureChunk.new(
        oldName, newName, oldFaction, newFaction, oldSize, newSize,
        beforeSlots, afterSlots, removedCount)
    state.history:apply(tmpl, cmd)
    if canvas then
        canvas:validateSelection()
        if newSize ~= oldSize then canvas:reset() end
    end
    if removedCount > 0 then
        state.saveStatus = string.format("Reconfigured (removed %d out-of-bounds)", removedCount)
    else
        state.saveStatus = "Reconfigured"
    end
    print(state.saveStatus)
end

local function saveAsAction()
    if not state.loadedTemplate then return end
    local defaultName
    if state.currentPath then
        defaultName = state.currentPath:match("[^/\\]+$")
    else
        defaultName = (state.loadedTemplate.Name or "untitled"):gsub("%s+", "_") .. ".lua"
    end
    local path = FileDialog.saveFile(defaultDialogDir(), defaultName)
    if not path then return end
    if not writeTemplateTo(path) then return end
    state.currentPath = path
    if state.history then state.history:markSaved() end
    state.saveStatus = "Saved"
    print("Saved " .. path)
    -- Refresh the cache so a chunk saved into the BaseChunks tree appears in the sidebar.
    if state.chunkCache then state.chunkCache:rebuild() end
end

local function saveAction()
    if not state.loadedTemplate then return end
    if not state.currentPath then
        saveAsAction()
        return
    end
    if not writeTemplateTo(state.currentPath) then return end
    if state.history then state.history:markSaved() end
    state.saveStatus = "Saved"
    print("Saved " .. state.currentPath)
end

---@type LoveActions
local actions = {
    selectChunk = selectChunk,
    loadPath = loadChunkByPath,
    new = newChunk,
    createNewChunk = createNewChunk,
    load = loadAction,
    importChunk = importChunkAction,
    save = saveAction,
    saveAs = saveAsAction,
    expandChunk = expandChunkAction,
    shrinkChunk = shrinkChunkAction,
    reconfigureChunk = reconfigureChunkAction,
    applyReconfigure = applyReconfigureAction,
    undo = function()
        if state.history and state.loadedTemplate then
            state.history:undo(state.loadedTemplate)
            if canvas then canvas:validateSelection() end
            state.saveStatus = nil
        end
    end,
    redo = function()
        if state.history and state.loadedTemplate then
            state.history:redo(state.loadedTemplate)
            if canvas then canvas:validateSelection() end
            state.saveStatus = nil
        end
    end,
    recenter = function() if canvas then canvas:reset() end end,
    zoomIn = function() if canvas then canvas:zoomInCenter() end end,
    zoomOut = function() if canvas then canvas:zoomOutCenter() end end,
    nextSelection = function() if canvas then canvas:nextSelection() end end,
    prevSelection = function() if canvas then canvas:prevSelection() end end,
    assignGroup = function(slot) if canvas then canvas:assignSelectionToGroup(slot) end end,
    selectGroup = function(slot) if canvas then canvas:selectGroup(slot) end end,
    deleteSelected = function() if canvas then canvas:deleteSelection() end end,
    duplicateSelected = function() if canvas then canvas:duplicateSelection() end end,
    translateSelection = function(dx, dz) if canvas then canvas:translateSelection(dx, dz) end end,
    addBuilding = function(id) if canvas then canvas:addBuilding(id) end end,
}

local bindings = Hotkeys.bindings(actions)

---@return LoveLayout
local function computeLayout()
    local w, h = love.graphics.getDimensions()
    local mainBottom = h - STATUSBAR_H - TIMELINE_H
    local centerH = mainBottom - TOPBAR_H
    return {
        viewport = { x = 0, y = 0, w = w, h = h },
        topbar = { x = 0, y = 0, w = w, h = TOPBAR_H },
        sidebar = { x = 0, y = TOPBAR_H, w = SIDEBAR_W, h = centerH },
        groups = { x = SIDEBAR_W, y = TOPBAR_H, w = GROUPS_W, h = centerH },
        canvas = { x = SIDEBAR_W + GROUPS_W, y = TOPBAR_H, w = w - SIDEBAR_W - GROUPS_W, h = centerH },
        statusbar = { x = 0, y = mainBottom, w = w, h = STATUSBAR_H },
        timeline = { x = 0, y = h - TIMELINE_H, w = w, h = TIMELINE_H },
    }
end

---@type LoveAppContext
local ctx = {
    state = state,
    actions = actions,
    bindings = bindings,
    layout = function(_) return computeLayout() end,
    isDirty = function(_) return isDirty() end,
    filteredChunks = function(_) return filteredChunks() end,
}

canvas = ChunkCanvas.new(ctx)
newChunkDialog = NewChunkDialog.new(ctx)

---@type LoveComponent[]
local components = {
    Sidebar.new(ctx),
    GroupsPanel.new(ctx),
    canvas,
    StatusBar.new(ctx),
    Timeline.new(ctx),
    TopBar.new(ctx),
    HotkeyDialog.new(ctx),
    newChunkDialog,
}

function love.load()
    local source = love.filesystem.getSource()
    local modRoot = parentDir(parentDir(source))
    print("Source:   " .. source)
    print("Mod root: " .. modRoot)

    state.modRoot = modRoot
    state.shim = Shim.create(modRoot)
    state.identifiers = Loader.loadIdentifiers(state.shim)
    state.chunkCache = ChunkCache.new(state.shim, modRoot)
    state.chunkCache:rebuild()
    state.chunks = state.chunkCache.entries

    state.fonts.small = love.graphics.newFont(10)
    state.fonts.body = love.graphics.newFont(12)
    state.fonts.title = love.graphics.newFont(16)

    print(string.format("Discovered %d chunks, %d identifiers",
        #state.chunks,
        (function() local n = 0 for _ in pairs(state.identifiers) do n = n + 1 end return n end)()))

    if #state.chunks > 0 then
        selectChunk(1)
    end
end

function love.update(dt)
    if state.chunkCache then
        state.chunkCache:poll(dt)
    end
end

function love.draw()
    for _, c in ipairs(components) do
        c:draw()
    end
end

function love.mousepressed(mx, my, button)
    for i = #components, 1, -1 do
        local c = components[i]
        if c.mousepressed and c:mousepressed(mx, my, button) then return end
    end
end

function love.mousereleased(mx, my, button)
    for i = #components, 1, -1 do
        local c = components[i]
        if c.mousereleased and c:mousereleased(mx, my, button) then return end
    end
end

function love.mousemoved(mx, my)
    for i = #components, 1, -1 do
        local c = components[i]
        if c.mousemoved and c:mousemoved(mx, my) then return end
    end
end

function love.wheelmoved(x, y)
    local mx, my = love.mouse.getPosition()
    for i = #components, 1, -1 do
        local c = components[i]
        if c.wheelmoved and c:wheelmoved(x, y, mx, my) then return end
    end
end

function love.textinput(text)
    for i = #components, 1, -1 do
        local c = components[i]
        if c.textinput and c:textinput(text) then return end
    end
end

function love.keypressed(key)
    for i = #components, 1, -1 do
        local c = components[i]
        if c.keypressed and c:keypressed(key) then return end
    end

    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
    local alt = love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")
    local combo = Hotkeys.normalize(key, ctrl, shift, alt)
    if Hotkeys.dispatch(bindings, combo) then return end

    if key == "down" or key == "up" then
        local visible = filteredChunks()
        local curIdx
        for i, e in ipairs(visible) do
            if e.fsPath == state.currentPath then curIdx = i; break end
        end
        if key == "down" then
            if curIdx and curIdx < #visible then
                loadChunkByPath(visible[curIdx + 1].fsPath)
            elseif not curIdx and #visible > 0 then
                loadChunkByPath(visible[1].fsPath)
            end
        else
            if curIdx and curIdx > 1 then
                loadChunkByPath(visible[curIdx - 1].fsPath)
            end
        end
    elseif key == "escape" then
        love.event.quit()
    end
end
