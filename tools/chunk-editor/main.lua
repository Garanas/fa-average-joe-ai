-- sumneko-lua doesn't narrow `state.X` field accesses after `if state.X then`,
-- only locals. Refactoring every guarded site into a local cache would add a
-- lot of noise; the runtime guards are exhaustive, so suppress the diagnostic.
---@diagnostic disable: need-check-nil

local Shim = require("shim")
local Loader = require("loader")
local Serializer = require("serializer")
local History = require("history")
local Hotkeys = require("hotkeys")
local MoveBuilding = require("commands.MoveBuilding")

local TOPBAR_H = 24
local SIDEBAR_W = 240
local STATUSBAR_H = 28
local TIMELINE_H = 44
local SIDEBAR_ROW_H = 18
local MENU_ITEM_H = 22
local MENU_W = 200

---@class LoveDragState
---@field identifier LoveBuildingIdentifier
---@field index integer
---@field dragOffsetX number
---@field dragOffsetZ number
---@field fromX integer
---@field fromZ integer

---@class LoveState
---@field shim LoveShim?
---@field modRoot string?
---@field chunks LoveChunkEntry[]
---@field selectedIndex integer?
---@field loadedTemplate LoveBaseChunk?
---@field loadError string?
---@field identifiers table<LoveBuildingIdentifier, LoveBuildingMetadata>?
---@field fonts table<string, any>
---@field sidebarRowYs table<integer, number>
---@field rects table[]
---@field dragging LoveDragState?
---@field history LoveHistory?
---@field menuOpen string?
---@field dialogOpen string?
---@field saveStatus string?
---@field timelineRects table[]
---@field timelineButtonRect table?
---@field dialogRect table?
---@field dialogCloseRect table?
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
    rects = {},
    dragging = nil,
    history = nil,
    menuOpen = nil,
    dialogOpen = nil,
    saveStatus = nil,
    timelineRects = {},
    timelineButtonRect = nil,
    dialogRect = nil,
    dialogCloseRect = nil,
}

local function pointInRect(rect, mx, my)
    return rect and mx >= rect.x1 and mx < rect.x2 and my >= rect.y1 and my < rect.y2 or false
end

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

local function isDirty()
    return state.history and state.history:isDirty() or false
end

local function selectChunk(i)
    if isDirty() and state.selectedIndex then
        local prev = state.chunks[state.selectedIndex]
        if prev then print("Discarding unsaved changes in " .. prev.file) end
    end
    state.selectedIndex = i
    state.dragging = nil
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

local bindings = Hotkeys.bindings(state, saveCurrentChunk)

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

local function chunkArea()
    local w, h = love.graphics.getDimensions()
    return SIDEBAR_W + 16, TOPBAR_H + 16,
        w - SIDEBAR_W - 32,
        h - TOPBAR_H - STATUSBAR_H - TIMELINE_H - 32
end

local function chunkOriginAndPpu(tmpl)
    local areaX, areaY, areaW, areaH = chunkArea()
    local size = tmpl.Size or 16
    local ppu = math.floor(math.min(areaW / size, areaH / size))
    if ppu < 1 then ppu = 1 end
    local chunkPx = size * ppu
    local ox = areaX + math.floor((areaW - chunkPx) / 2)
    local oy = areaY + math.floor((areaH - chunkPx) / 2)
    return ox, oy, ppu, chunkPx
end

local function chunkXZFromMouse(tmpl, mx, my)
    local ox, oy, ppu = chunkOriginAndPpu(tmpl)
    return (mx - ox) / ppu, (my - oy) / ppu
end

local function drawSidebar(w, h)
    love.graphics.setColor(0.13, 0.13, 0.16)
    love.graphics.rectangle("fill", 0, TOPBAR_H, SIDEBAR_W,
        h - TOPBAR_H - STATUSBAR_H - TIMELINE_H)
    love.graphics.setFont(state.fonts.body)

    state.sidebarRowYs = {}
    local y = TOPBAR_H + 4
    local prevFaction = nil
    local dirty = isDirty()
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
        local label = entry.file
        if i == state.selectedIndex and dirty then
            label = "* " .. label
        end
        love.graphics.print(label, 16, y)
        y = y + SIDEBAR_ROW_H
        if y > h - STATUSBAR_H - TIMELINE_H then break end
    end
end

local function drawChunk()
    local areaX, areaY, areaW = chunkArea()
    state.rects = {}

    if state.loadError then
        love.graphics.setColor(1, 0.5, 0.5)
        love.graphics.setFont(state.fonts.body)
        love.graphics.printf("Load error: " .. tostring(state.loadError), areaX, areaY, areaW)
        return
    end

    local tmpl = state.loadedTemplate
    if not tmpl then return end

    local ox, oy, ppu, chunkPx = chunkOriginAndPpu(tmpl)
    local size = tmpl.Size or 16

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
        local anchorOffsetX = (sx % 2 == 0) and (1 - sx / 2) or 0
        local anchorOffsetZ = (sz % 2 == 0) and (1 - sz / 2) or 0
        for index, loc in ipairs(locations) do
            local x = ox + (loc[1] + anchorOffsetX) * ppu
            local y = oy + (loc[2] + anchorOffsetZ) * ppu
            local rw = sx * ppu
            local rh = sz * ppu
            local isDragged = state.dragging
                and state.dragging.identifier == identifier
                and state.dragging.index == index

            love.graphics.setColor(r, g, b, isDragged and 0.7 or 0.85)
            love.graphics.rectangle("fill", x, y, rw, rh)
            if isDragged then
                love.graphics.setColor(1, 1, 0)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", x, y, rw, rh)
                love.graphics.setLineWidth(1)
            else
                love.graphics.setColor(0, 0, 0, 0.6)
                love.graphics.rectangle("line", x, y, rw, rh)
            end
            if rw >= 36 and rh >= 14 then
                love.graphics.setColor(0, 0, 0)
                love.graphics.printf(identifier, x, y + math.floor(rh / 2) - 6, rw, "center")
            end

            table.insert(state.rects, {
                x1 = x, y1 = y, x2 = x + rw, y2 = y + rh,
                identifier = identifier, index = index,
            })
        end
    end
end

local function drawTopBar(w)
    love.graphics.setColor(0.10, 0.10, 0.14)
    love.graphics.rectangle("fill", 0, 0, w, TOPBAR_H)
    love.graphics.setFont(state.fonts.body)
    if state.menuOpen == "file" then
        love.graphics.setColor(0.20, 0.20, 0.26)
        love.graphics.rectangle("fill", 4, 2, 44, TOPBAR_H - 4)
    end
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("File", 12, 4)

    if state.menuOpen == "file" then
        local mx = 4
        local my = TOPBAR_H
        love.graphics.setColor(0.20, 0.20, 0.26)
        love.graphics.rectangle("fill", mx, my, MENU_W, MENU_ITEM_H)
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.rectangle("line", mx, my, MENU_W, MENU_ITEM_H)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Save", mx + 8, my + 4)
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.printf("Ctrl+S", mx, my + 4, MENU_W - 8, "right")
    end
end

local function drawStatus(w, h)
    local y0 = h - STATUSBAR_H - TIMELINE_H
    love.graphics.setColor(0.10, 0.10, 0.14)
    love.graphics.rectangle("fill", 0, y0, w, STATUSBAR_H)
    love.graphics.setFont(state.fonts.body)
    love.graphics.setColor(0.9, 0.9, 0.9)
    local txt
    local tmpl = state.loadedTemplate
    if tmpl then
        local nIdent = 0
        for _ in pairs(tmpl.Locations or {}) do nIdent = nIdent + 1 end
        txt = string.format("%s%s  |  %s  |  %dx%d  |  %d identifiers",
            isDirty() and "* " or "",
            tostring(tmpl.Name or "?"), tostring(tmpl.Faction or "?"),
            tmpl.Size or 0, tmpl.Size or 0, nIdent)
    elseif state.loadError then
        txt = "Load error (see console)"
    else
        txt = "No chunk selected"
    end
    love.graphics.print(txt, 8, y0 + 6)

    if state.saveStatus then
        local color = state.saveStatus:find("^Saved") and { 0.6, 1.0, 0.6 } or { 1.0, 0.6, 0.6 }
        love.graphics.setColor(color[1], color[2], color[3])
        love.graphics.printf(state.saveStatus, 0, y0 + 6, w - 12, "right")
    end
end

local function drawTimeline(w, h)
    local y0 = h - TIMELINE_H
    love.graphics.setColor(0.07, 0.07, 0.10)
    love.graphics.rectangle("fill", 0, y0, w, TIMELINE_H)

    -- Hotkeys button (always visible, top-right of timeline bar)
    local btnW, btnPad = 90, 8
    local btnH = TIMELINE_H - 8
    local btnX = w - btnW - btnPad
    local btnY = y0 + 4
    love.graphics.setColor(0.20, 0.20, 0.26)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.setFont(state.fonts.body)
    love.graphics.printf("Hotkeys", btnX, btnY + math.floor(btnH / 2) - 8, btnW, "center")
    state.timelineButtonRect = { x1 = btnX, y1 = btnY, x2 = btnX + btnW, y2 = btnY + btnH }

    -- Chip area: clip to exclude the button column so chips don't draw over it.
    local chipAreaW = w - btnW - btnPad * 2

    state.timelineRects = {}
    local hist = state.history
    if not hist or #hist.commands == 0 then
        love.graphics.setColor(0.45, 0.45, 0.55)
        love.graphics.setFont(state.fonts.small)
        love.graphics.printf("No commands", 0, y0 + 16, chipAreaW, "center")
        return
    end

    local chipW, gap = 200, 6
    local centerX = math.floor(chipAreaW / 2)
    local chipY = y0 + 4
    local chipH = TIMELINE_H - 8

    love.graphics.setScissor(0, y0, chipAreaW, TIMELINE_H)
    love.graphics.setFont(state.fonts.small)
    for i, cmd in ipairs(hist.commands) do
        local offset = i - hist.cursor
        local cx = centerX + offset * (chipW + gap)
        local x = math.floor(cx - chipW / 2)
        if not (x + chipW < 0 or x > chipAreaW) then
            if i <= hist.cursor then
                love.graphics.setColor(0.18, 0.30, 0.50)
            else
                love.graphics.setColor(0.30, 0.30, 0.34)
            end
            love.graphics.rectangle("fill", x, chipY, chipW, chipH)

            if i == hist.cursor then
                love.graphics.setColor(1.0, 0.85, 0.40)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", x, chipY, chipW, chipH)
                love.graphics.setLineWidth(1)
            else
                love.graphics.setColor(0, 0, 0, 0.5)
                love.graphics.rectangle("line", x, chipY, chipW, chipH)
            end

            love.graphics.setColor(0.95, 0.95, 0.95)
            local label = (cmd.describe and cmd:describe()) or "(unnamed)"
            love.graphics.printf(label, x + 6, chipY + math.floor(chipH / 2) - 7, chipW - 12, "center")

            table.insert(state.timelineRects, {
                x1 = x, y1 = chipY, x2 = x + chipW, y2 = chipY + chipH,
                index = i,
            })
        end
    end
    love.graphics.setScissor()
end

local function drawHotkeyDialog(w, h)
    if state.dialogOpen ~= "hotkeys" then
        state.dialogRect = nil
        state.dialogCloseRect = nil
        return
    end

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local rowH = 24
    local headerH = 56
    local rowsH = math.max(1, #bindings) * rowH
    local dh = headerH + rowsH + 16
    local dw = 380
    local dx = math.floor((w - dw) / 2)
    local dy = math.floor((h - dh) / 2)

    love.graphics.setColor(0.16, 0.16, 0.20)
    love.graphics.rectangle("fill", dx, dy, dw, dh)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", dx, dy, dw, dh)

    love.graphics.setFont(state.fonts.title)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.print("Hotkeys", dx + 16, dy + 14)

    local closeSz = 22
    local closeX = dx + dw - closeSz - 6
    local closeY = dy + 8
    love.graphics.setColor(0.30, 0.30, 0.36)
    love.graphics.rectangle("fill", closeX, closeY, closeSz, closeSz)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", closeX, closeY, closeSz, closeSz)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(state.fonts.body)
    love.graphics.printf("X", closeX, closeY + 4, closeSz, "center")

    love.graphics.setColor(0.30, 0.30, 0.36)
    love.graphics.line(dx + 16, dy + headerH - 10, dx + dw - 16, dy + headerH - 10)

    local rowY = dy + headerH
    for _, b in ipairs(bindings) do
        love.graphics.setColor(0.7, 0.85, 1.0)
        love.graphics.print(b.keys, dx + 24, rowY)
        love.graphics.setColor(0.95, 0.95, 0.95)
        love.graphics.print(b.name, dx + 200, rowY)
        rowY = rowY + rowH
    end

    state.dialogRect = { x1 = dx, y1 = dy, x2 = dx + dw, y2 = dy + dh }
    state.dialogCloseRect = { x1 = closeX, y1 = closeY, x2 = closeX + closeSz, y2 = closeY + closeSz }
end

function love.draw()
    local w, h = love.graphics.getDimensions()
    drawSidebar(w, h)
    drawChunk()
    drawStatus(w, h)
    drawTimeline(w, h)
    drawTopBar(w)
    drawHotkeyDialog(w, h)
end

local function pointInFileMenuItem(mx, my)
    if state.menuOpen ~= "file" then return false end
    return mx >= 4 and mx < 4 + MENU_W and my >= TOPBAR_H and my < TOPBAR_H + MENU_ITEM_H
end

local function pointInFileButton(mx, my)
    return mx >= 4 and mx < 48 and my < TOPBAR_H
end

local function buildingAt(mx, my)
    for i = #state.rects, 1, -1 do
        local r = state.rects[i]
        if mx >= r.x1 and mx < r.x2 and my >= r.y1 and my < r.y2 then
            return r
        end
    end
    return nil
end

local function timelineChipAt(mx, my)
    for _, r in ipairs(state.timelineRects) do
        if mx >= r.x1 and mx < r.x2 and my >= r.y1 and my < r.y2 then
            return r
        end
    end
    return nil
end

function love.mousepressed(mx, my, button)
    if button ~= 1 then return end

    if state.dialogOpen == "hotkeys" then
        if pointInRect(state.dialogCloseRect, mx, my) then
            state.dialogOpen = nil
        elseif not pointInRect(state.dialogRect, mx, my) then
            state.dialogOpen = nil
        end
        return
    end

    if pointInRect(state.timelineButtonRect, mx, my) then
        state.dialogOpen = (state.dialogOpen == "hotkeys") and nil or "hotkeys"
        state.menuOpen = nil
        return
    end

    if state.menuOpen == "file" and pointInFileMenuItem(mx, my) then
        saveCurrentChunk()
        state.menuOpen = nil
        return
    end
    if pointInFileButton(mx, my) then
        state.menuOpen = (state.menuOpen == "file") and nil or "file"
        return
    end
    if state.menuOpen then
        state.menuOpen = nil
    end

    local chip = timelineChipAt(mx, my)
    if chip and state.history and state.loadedTemplate then
        state.history:jumpTo(state.loadedTemplate, chip.index)
        state.saveStatus = nil
        return
    end

    if my >= TOPBAR_H and mx < SIDEBAR_W then
        for i, ry in pairs(state.sidebarRowYs) do
            if my >= ry - 2 and my < ry - 2 + SIDEBAR_ROW_H then
                selectChunk(i)
                return
            end
        end
        return
    end

    local rect = buildingAt(mx, my)
    if rect and state.loadedTemplate then
        local tmpl = state.loadedTemplate
        local cx, cz = chunkXZFromMouse(tmpl, mx, my)
        local loc = tmpl.Locations[rect.identifier][rect.index]
        state.dragging = {
            identifier = rect.identifier,
            index = rect.index,
            dragOffsetX = cx - loc[1],
            dragOffsetZ = cz - loc[2],
            fromX = loc[1],
            fromZ = loc[2],
        }
    end
end

function love.mousereleased(_, _, button)
    if button == 1 and state.dragging then
        local d = state.dragging
        state.dragging = nil
        local tmpl = state.loadedTemplate
        if tmpl then
            local loc = tmpl.Locations[d.identifier][d.index]
            local toX, toZ = loc[1], loc[2]
            if toX ~= d.fromX or toZ ~= d.fromZ then
                -- Revert the live-preview mutation so apply() is the only path
                -- that ever writes the new coord.
                loc[1], loc[2] = d.fromX, d.fromZ
                local cmd = MoveBuilding.new(d.identifier, d.index, d.fromX, d.fromZ, toX, toZ)
                state.history:apply(tmpl, cmd)
                state.saveStatus = nil
            end
        end
    end
end

function love.mousemoved(mx, my)
    if not state.dragging then return end
    local tmpl = state.loadedTemplate
    if not tmpl then return end
    local cx, cz = chunkXZFromMouse(tmpl, mx, my)
    local newX = math.floor(cx - state.dragging.dragOffsetX + 0.5)
    local newZ = math.floor(cz - state.dragging.dragOffsetZ + 0.5)
    local size = tmpl.Size or 16
    if newX < 0 then newX = 0 end
    if newZ < 0 then newZ = 0 end
    if newX > size - 1 then newX = size - 1 end
    if newZ > size - 1 then newZ = size - 1 end
    local loc = tmpl.Locations[state.dragging.identifier][state.dragging.index]
    loc[1] = newX
    loc[2] = newZ
end

function love.keypressed(key)
    if state.dialogOpen then
        if key == "escape" then state.dialogOpen = nil end
        return
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
        if state.menuOpen then
            state.menuOpen = nil
        else
            love.event.quit()
        end
    end
end
