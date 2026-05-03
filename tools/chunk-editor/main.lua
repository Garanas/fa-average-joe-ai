local Shim = require("shim")
local Loader = require("loader")

local SIDEBAR_W = 240
local STATUSBAR_H = 28
local SIDEBAR_ROW_H = 18

local state = {
    shim = nil,
    modRoot = nil,
    chunks = {},
    selectedIndex = nil,
    loadedTemplate = nil,
    loadError = nil,
    identifiers = nil,
    fonts = {},
    sidebarRowYs = {},
}

local function parentDir(p)
    p = p:gsub("[/\\]+$", "")
    return p:match("^(.*)[/\\][^/\\]+$") or p
end

local function hexColor(hex)
    if not hex or #hex < 6 then return 0.5, 0.5, 0.5 end
    local r = (tonumber(hex:sub(1, 2), 16) or 128) / 255
    local g = (tonumber(hex:sub(3, 4), 16) or 128) / 255
    local b = (tonumber(hex:sub(5, 6), 16) or 128) / 255
    return r, g, b
end

local function selectChunk(i)
    state.selectedIndex = i
    local entry = state.chunks[i]
    if not entry then return end
    local tmpl, err = Loader.loadChunk(state.shim, entry.fsPath)
    state.loadedTemplate = tmpl
    state.loadError = err
    if err then print("Load error for " .. entry.fsPath .. ": " .. tostring(err)) end
end

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

local function drawSidebar(w, h)
    love.graphics.setColor(0.13, 0.13, 0.16)
    love.graphics.rectangle("fill", 0, 0, SIDEBAR_W, h)
    love.graphics.setFont(state.fonts.body)

    state.sidebarRowYs = {}
    local y = 4
    local prevFaction = nil
    for i, entry in ipairs(state.chunks) do
        if entry.faction ~= prevFaction then
            love.graphics.setColor(0.6, 0.7, 0.9)
            love.graphics.print(entry.faction, 8, y)
            y = y + SIDEBAR_ROW_H
            prevFaction = entry.faction
        end
        state.sidebarRowYs[i] = y
        if i == state.selectedIndex then
            love.graphics.setColor(0.25, 0.45, 0.75)
            love.graphics.rectangle("fill", 0, y - 2, SIDEBAR_W, SIDEBAR_ROW_H)
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0.85, 0.85, 0.85)
        end
        love.graphics.print(entry.file, 16, y)
        y = y + SIDEBAR_ROW_H
        if y > h - STATUSBAR_H then break end
    end
end

local function drawChunk(w, h)
    local areaX, areaY = SIDEBAR_W + 16, 16
    local areaW, areaH = w - SIDEBAR_W - 32, h - STATUSBAR_H - 32

    if state.loadError then
        love.graphics.setColor(1, 0.5, 0.5)
        love.graphics.setFont(state.fonts.body)
        love.graphics.printf("Load error: " .. tostring(state.loadError), areaX, areaY, areaW)
        return
    end

    local tmpl = state.loadedTemplate
    if not tmpl then return end

    local size = tmpl.Size or 16
    local ppu = math.floor(math.min(areaW / size, areaH / size))
    if ppu < 1 then ppu = 1 end
    local chunkPx = size * ppu
    local ox = areaX + math.floor((areaW - chunkPx) / 2)
    local oy = areaY + math.floor((areaH - chunkPx) / 2)

    love.graphics.setColor(0.18, 0.18, 0.22)
    love.graphics.rectangle("fill", ox, oy, chunkPx, chunkPx)

    love.graphics.setColor(0.25, 0.25, 0.30)
    for i = 0, size do
        love.graphics.line(ox + i * ppu, oy, ox + i * ppu, oy + chunkPx)
        love.graphics.line(ox, oy + i * ppu, ox + chunkPx, oy + i * ppu)
    end

    love.graphics.setFont(state.fonts.small)
    for identifier, locations in pairs(tmpl.Locations or {}) do
        local meta = state.identifiers[identifier] or {}
        local r, g, b = hexColor(meta.Color)
        local sx = meta.SizeX or 1
        local sz = meta.SizeZ or 1
        -- Saved coord is the engine anchor: top-left for odd footprints, but
        -- offset by size/2 - 1 for even ones. Reverse that so we draw the
        -- actual on-grid footprint.
        local anchorOffsetX = (sx % 2 == 0) and (1 - sx / 2) or 0
        local anchorOffsetZ = (sz % 2 == 0) and (1 - sz / 2) or 0
        for _, loc in ipairs(locations) do
            local x = ox + (loc[1] + anchorOffsetX) * ppu
            local y = oy + (loc[2] + anchorOffsetZ) * ppu
            local rw = sx * ppu
            local rh = sz * ppu
            love.graphics.setColor(r, g, b, 0.85)
            love.graphics.rectangle("fill", x, y, rw, rh)
            love.graphics.setColor(0, 0, 0, 0.6)
            love.graphics.rectangle("line", x, y, rw, rh)
            if rw >= 36 and rh >= 14 then
                love.graphics.setColor(0, 0, 0)
                love.graphics.printf(identifier, x, y + math.floor(rh / 2) - 6, rw, "center")
            end
        end
    end
end

local function drawStatus(w, h)
    love.graphics.setColor(0.10, 0.10, 0.14)
    love.graphics.rectangle("fill", 0, h - STATUSBAR_H, w, STATUSBAR_H)
    love.graphics.setFont(state.fonts.body)
    love.graphics.setColor(0.9, 0.9, 0.9)
    local txt
    local tmpl = state.loadedTemplate
    if tmpl then
        local nIdent = 0
        for _ in pairs(tmpl.Locations or {}) do nIdent = nIdent + 1 end
        txt = string.format("%s  |  %s  |  %dx%d  |  %d identifiers",
            tostring(tmpl.Name or "?"), tostring(tmpl.Faction or "?"),
            tmpl.Size or 0, tmpl.Size or 0, nIdent)
    elseif state.loadError then
        txt = "Load error (see console)"
    else
        txt = "No chunk selected"
    end
    love.graphics.print(txt, 8, h - STATUSBAR_H + 6)
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    drawSidebar(w, h)
    drawChunk(w, h)
    drawStatus(w, h)
end

function love.mousepressed(mx, my, button)
    if button == 1 and mx < SIDEBAR_W then
        for i, ry in pairs(state.sidebarRowYs) do
            if my >= ry - 2 and my < ry - 2 + SIDEBAR_ROW_H then
                selectChunk(i)
                return
            end
        end
    end
end

function love.keypressed(key)
    if key == "down" and state.selectedIndex and state.selectedIndex < #state.chunks then
        selectChunk(state.selectedIndex + 1)
    elseif key == "up" and state.selectedIndex and state.selectedIndex > 1 then
        selectChunk(state.selectedIndex - 1)
    elseif key == "escape" then
        love.event.quit()
    end
end
