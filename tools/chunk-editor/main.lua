local Shim = require("shim")
local Loader = require("loader")
local Serializer = require("serializer")
local History = require("history")
local Hotkeys = require("hotkeys")

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
    selectedIndex = nil,
    loadedTemplate = nil,
    loadError = nil,
    identifiers = nil,
    fonts = {},
    history = nil,
    dialogOpen = nil,
    saveStatus = nil,
}

local function parentDir(p)
    p = p:gsub("[/\\]+$", "")
    return p:match("^(.*)[/\\][^/\\]+$") or p
end

local function selectChunk(i)
    if state.history and state.history:isDirty() and state.selectedIndex then
        local prev = state.chunks[state.selectedIndex]
        if prev then print("Discarding unsaved changes in " .. prev.file) end
    end
    state.selectedIndex = i
    state.saveStatus = nil
    state.history = History.new()
    local entry = state.chunks[i]
    if not entry then return end
    local tmpl, err = Loader.loadChunk(state.shim, entry.fsPath)
    state.loadedTemplate = tmpl
    state.loadError = err
    if err then print("Load error for " .. entry.fsPath .. ": " .. tostring(err)) end
end

local function saveCurrentChunk()
    local entry = state.chunks[state.selectedIndex]
    local tmpl = state.loadedTemplate
    if not entry or not tmpl then return end
    local source = Serializer.serializeTemplate(tmpl)
    local f, err = io.open(entry.fsPath, "wb")
    if not f then
        state.saveStatus = "Save failed: " .. tostring(err)
        print(state.saveStatus)
        return
    end
    f:write(source)
    f:close()
    if state.history then state.history:markSaved() end
    state.saveStatus = "Saved"
    print("Saved " .. entry.fsPath)
end

---@type LoveActions
local actions = {
    selectChunk = selectChunk,
    save = saveCurrentChunk,
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
}

-- Order is draw-bottom to draw-top. Input dispatches in reverse.
---@type LoveComponent[]
local components = {
    Sidebar.new(ctx),
    ChunkCanvas.new(ctx),
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

    if key == "down" and state.selectedIndex and state.selectedIndex < #state.chunks then
        selectChunk(state.selectedIndex + 1)
    elseif key == "up" and state.selectedIndex and state.selectedIndex > 1 then
        selectChunk(state.selectedIndex - 1)
    elseif key == "escape" then
        love.event.quit()
    end
end
