local Shim = require("shim")
local Loader = require("loader")
local Serializer = require("serializer")
local History = require("history")
local Hotkeys = require("hotkeys")
local FileDialog = require("file_dialog")

local TopBar = require("components.TopBar")
local Sidebar = require("components.Sidebar")
local ChunkCanvas = require("components.ChunkCanvas")
local StatusBar = require("components.StatusBar")
local Timeline = require("components.Timeline")
local HotkeyDialog = require("components.HotkeyDialog")

local TOPBAR_H = 24
local SIDEBAR_W = 240
local STATUSBAR_H = 28
local TIMELINE_H = 44

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
    dialogOpen = nil,
    saveStatus = nil,
}

---@type LoveChunkCanvas?  -- forward declaration; assigned after components are built
local canvas

local function parentDir(p)
    p = p:gsub("[/\\]+$", "")
    return p:match("^(.*)[/\\][^/\\]+$") or p
end

---@return integer?
local function findIndexForCurrentPath()
    if not state.currentPath then return nil end
    for i, e in ipairs(state.chunks) do
        if e.fsPath == state.currentPath then return i end
    end
    return nil
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
    state.saveStatus = nil
    local tmpl, err = Loader.loadChunk(state.shim, path)
    state.loadedTemplate = tmpl
    state.loadError = err
    if err then print("Load error for " .. path .. ": " .. tostring(err)) end
    if canvas then canvas:reset() end
end

local function selectChunk(i)
    local entry = state.chunks[i]
    if not entry then return end
    loadChunkByPath(entry.fsPath)
end

---@return LoveBaseChunk
local function makeNewTemplate()
    local sourceTmpl = state.loadedTemplate
    return {
        Name = "Untitled",
        Faction = (sourceTmpl and sourceTmpl.Faction) or "UEF",
        Size = (sourceTmpl and sourceTmpl.Size) or 16,
        Units = {},
        Locations = {},
    }
end

local function newChunk()
    discardCheck()
    state.currentPath = nil
    state.history = History.new()
    state.loadedTemplate = makeNewTemplate()
    state.loadError = nil
    state.saveStatus = nil
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

local function loadAction()
    local path = FileDialog.openFile(defaultDialogDir())
    if not path then return end
    loadChunkByPath(path)
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
    -- Re-discover so a chunk saved into the BaseChunks tree appears in the sidebar.
    if state.modRoot then
        state.chunks = Loader.discoverChunks(state.modRoot)
    end
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
    new = newChunk,
    load = loadAction,
    save = saveAction,
    saveAs = saveAsAction,
    undo = function()
        if state.history and state.loadedTemplate then
            state.history:undo(state.loadedTemplate)
            state.saveStatus = nil
        end
    end,
    redo = function()
        if state.history and state.loadedTemplate then
            state.history:redo(state.loadedTemplate)
            state.saveStatus = nil
        end
    end,
    recenter = function() if canvas then canvas:reset() end end,
    zoomIn = function() if canvas then canvas:zoomInCenter() end end,
    zoomOut = function() if canvas then canvas:zoomOutCenter() end end,
}

local bindings = Hotkeys.bindings(actions)

---@return LoveLayout
local function computeLayout()
    local w, h = love.graphics.getDimensions()
    local mainBottom = h - STATUSBAR_H - TIMELINE_H
    return {
        viewport = { x = 0, y = 0, w = w, h = h },
        topbar = { x = 0, y = 0, w = w, h = TOPBAR_H },
        sidebar = { x = 0, y = TOPBAR_H, w = SIDEBAR_W, h = mainBottom - TOPBAR_H },
        canvas = { x = SIDEBAR_W, y = TOPBAR_H, w = w - SIDEBAR_W, h = mainBottom - TOPBAR_H },
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
}

canvas = ChunkCanvas.new(ctx)

---@type LoveComponent[]
local components = {
    Sidebar.new(ctx),
    canvas,
    StatusBar.new(ctx),
    Timeline.new(ctx),
    TopBar.new(ctx),
    HotkeyDialog.new(ctx),
}

function love.load()
    local source = love.filesystem.getSource()
    local modRoot = parentDir(parentDir(source))
    print("Source:   " .. source)
    print("Mod root: " .. modRoot)

    state.modRoot = modRoot
    state.shim = Shim.create(modRoot)
    state.identifiers = Loader.loadIdentifiers(state.shim)
    state.chunks = Loader.discoverChunks(modRoot)

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

    if key == "down" then
        local cur = findIndexForCurrentPath()
        if cur and cur < #state.chunks then
            selectChunk(cur + 1)
        elseif not cur and #state.chunks > 0 then
            selectChunk(1)
        end
    elseif key == "up" then
        local cur = findIndexForCurrentPath()
        if cur and cur > 1 then
            selectChunk(cur - 1)
        end
    elseif key == "escape" then
        love.event.quit()
    end
end
