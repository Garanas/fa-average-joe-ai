---@diagnostic disable: need-check-nil

local Util = require("util")
local MoveBuilding = require("commands.MoveBuilding")
local Composite = require("commands.Composite")
local AssignGroup = require("commands.AssignGroup")
local DeleteBuildings = require("commands.DeleteBuildings")
local InsertBuildings = require("commands.InsertBuildings")

local ZOOM_WHEEL = 1.15
local ZOOM_HOTKEY = 1.25
local ZOOM_MIN = 0.1
local ZOOM_MAX = 16

---@class LoveCameraState
---@field offsetX number?
---@field offsetY number?
---@field zoom number?

---@class LovePanState
---@field startMouseX number
---@field startMouseY number
---@field startOx number
---@field startOy number

---@class LoveDragItem
---@field slot integer
---@field identifier LoveBuildingIdentifier
---@field index integer
---@field fromX integer
---@field fromZ integer

---@class LoveDragState
---@field items LoveDragItem[]
---@field primaryFromX integer
---@field primaryFromZ integer
---@field dragOffsetX number
---@field dragOffsetZ number
---@field template LoveBaseChunk

---@class LoveSelectionBoxState
---@field startMouseX number
---@field startMouseY number
---@field currentX number
---@field currentY number
---@field additive boolean

---@class LoveChunkCanvas : LoveComponent
---@field ctx LoveAppContext
---@field rects table[]
---@field dragging LoveDragState?
---@field panning LovePanState?
---@field selectionBox LoveSelectionBoxState?
---@field camera LoveCameraState
local LoveChunkCanvas = {}
LoveChunkCanvas.__index = LoveChunkCanvas

local function selectionKey(slot, identifier, index)
    return tostring(slot) .. "|" .. identifier .. "|" .. tostring(index)
end

local function parseSelectionKey(key)
    local s, id, idxStr = key:match("^(%d+)|(.-)|(%d+)$")
    return tonumber(s), id, tonumber(idxStr)
end

local function getLocation(tmpl, slot, identifier, index)
    local g = tmpl.Groups and tmpl.Groups[slot]
    local locs = g and g.Locations and g.Locations[identifier]
    return locs and locs[index]
end

--- Pure transform of a single saved (x, z) coord around the supplied pivot.
--- Used by both the in-place transform (selection-centre pivot) and the
--- duplicate transform (chunk-centre pivot). Names refer to the *coord* that
--- changes, not the math axis of reflection — `flip-x` swaps left/right
--- (X coord flips, Z stays); `flip-z` swaps top/bottom (Z coord flips).
--- Rotation is in screen space: +X is right, +Z is down, so `rotate-cw`
--- visually rotates clockwise.
---@param transform "flip-x" | "flip-z" | "rotate-cw" | "rotate-ccw"
---@param pivotX number
---@param pivotZ number
---@param x number
---@param z number
---@return number newX, number newZ
local function applyTransform(transform, pivotX, pivotZ, x, z)
    if transform == "flip-x" then
        return 2 * pivotX - x, z
    elseif transform == "flip-z" then
        return x, 2 * pivotZ - z
    elseif transform == "rotate-cw" then
        return pivotX - (z - pivotZ), pivotZ + (x - pivotX)
    elseif transform == "rotate-ccw" then
        return pivotX + (z - pivotZ), pivotZ - (x - pivotX)
    end
    return x, z
end

local function selectionBboxCentre(items)
    local minX, maxX = math.huge, -math.huge
    local minZ, maxZ = math.huge, -math.huge
    for _, it in ipairs(items) do
        if it.fromX < minX then minX = it.fromX end
        if it.fromX > maxX then maxX = it.fromX end
        if it.fromZ < minZ then minZ = it.fromZ end
        if it.fromZ > maxZ then maxZ = it.fromZ end
    end
    return (minX + maxX) / 2, (minZ + maxZ) / 2
end

---@param ctx LoveAppContext
---@return LoveChunkCanvas
function LoveChunkCanvas.new(ctx)
    return setmetatable({
        ctx = ctx,
        rects = {},
        dragging = nil,
        panning = nil,
        selectionBox = nil,
        camera = { offsetX = nil, offsetY = nil, zoom = nil },
        lastClickKey = nil,
        lastClickTime = 0,
    }, LoveChunkCanvas)
end

function LoveChunkCanvas:_baseFit()
    local rect = self.ctx:layout().canvas
    local tmpl = self.ctx.state.loadedTemplate
    local size = (tmpl and tmpl.Size) or 16
    local areaW, areaH = rect.w - 32, rect.h - 32
    local fit = math.min(areaW / size, areaH / size)
    if fit < 1 then fit = 1 end
    local chunkPxBase = size * fit
    return fit,
        rect.x + 16 + (areaW - chunkPxBase) / 2,
        rect.y + 16 + (areaH - chunkPxBase) / 2,
        size
end

function LoveChunkCanvas:_geometry()
    local fit, baseOx, baseOy, size = self:_baseFit()
    local zoom = self.camera.zoom or 1.0
    local ppu = fit * zoom
    return {
        ppu = ppu,
        ox = self.camera.offsetX or baseOx,
        oy = self.camera.offsetY or baseOy,
        chunkPx = size * ppu,
        size = size,
        baseFitPpu = fit,
    }
end

function LoveChunkCanvas:_chunkXZFromMouse(mx, my)
    local g = self:_geometry()
    return (mx - g.ox) / g.ppu, (my - g.oy) / g.ppu
end

function LoveChunkCanvas:_buildingAt(mx, my)
    for i = #self.rects, 1, -1 do
        local r = self.rects[i]
        if mx >= r.x1 and mx < r.x2 and my >= r.y1 and my < r.y2 then
            return r
        end
    end
    return nil
end

function LoveChunkCanvas:_zoomAt(mx, my, factor)
    local g = self:_geometry()
    local worldX = (mx - g.ox) / g.ppu
    local worldY = (my - g.oy) / g.ppu
    local newZoom = (self.camera.zoom or 1.0) * factor
    if newZoom < ZOOM_MIN then newZoom = ZOOM_MIN end
    if newZoom > ZOOM_MAX then newZoom = ZOOM_MAX end
    local newPpu = g.baseFitPpu * newZoom
    self.camera.zoom = newZoom
    self.camera.offsetX = mx - worldX * newPpu
    self.camera.offsetY = my - worldY * newPpu
end

function LoveChunkCanvas:zoomAtCenter(factor)
    local layout = self.ctx:layout().canvas
    self:_zoomAt(layout.x + layout.w / 2, layout.y + layout.h / 2, factor)
end

function LoveChunkCanvas:zoomInCenter() self:zoomAtCenter(ZOOM_HOTKEY) end
function LoveChunkCanvas:zoomOutCenter() self:zoomAtCenter(1 / ZOOM_HOTKEY) end

function LoveChunkCanvas:reset()
    self.camera = { offsetX = nil, offsetY = nil, zoom = nil }
end

function LoveChunkCanvas:onChunkChange()
    self:reset()
    self.dragging = nil
    self.panning = nil
    self.selectionBox = nil
end

function LoveChunkCanvas:nextSelection()
    local s = self.ctx.state.selectionHistory:forward()
    if s then self.ctx.state.selection = s end
end

function LoveChunkCanvas:prevSelection()
    local s = self.ctx.state.selectionHistory:back()
    if s then self.ctx.state.selection = s end
end

--- Drop selection keys whose (slot, identifier, index) no longer exist in the template.
--- Useful after undo/redo of a structural command (AssignGroup) that may have shifted indices.
function LoveChunkCanvas:validateSelection()
    local tmpl = self.ctx.state.loadedTemplate
    if not tmpl then
        self.ctx.state.selection = {}
        return
    end
    local newSel = {}
    for key in pairs(self.ctx.state.selection) do
        local slot, id, idx = parseSelectionKey(key)
        if slot and id and idx and getLocation(tmpl, slot, id, idx) then
            newSel[key] = true
        end
    end
    self.ctx.state.selection = newSel
end

---@return LoveDragItem[]
function LoveChunkCanvas:_buildDragItemsFromSelection(tmpl)
    local items = {}
    for key in pairs(self.ctx.state.selection) do
        local slot, id, idx = parseSelectionKey(key)
        if slot and id and idx then
            local loc = getLocation(tmpl, slot, id, idx)
            if loc then
                table.insert(items, {
                    slot = slot, identifier = id, index = idx,
                    fromX = loc[1], fromZ = loc[2],
                })
            end
        end
    end
    return items
end

function LoveChunkCanvas:draw()
    local layout = self.ctx:layout().canvas
    local state = self.ctx.state
    self.rects = {}

    if state.loadError then
        love.graphics.setColor(1, 0.5, 0.5)
        love.graphics.setFont(state.fonts.body)
        love.graphics.printf("Load error: " .. tostring(state.loadError),
            layout.x + 16, layout.y + 16, layout.w - 32)
        return
    end

    local tmpl = state.loadedTemplate
    if not tmpl then return end

    if self.dragging and self.dragging.template ~= tmpl then
        self.dragging = nil
    end

    local g = self:_geometry()

    local draggingSet = {}
    if self.dragging and self.dragging.template == tmpl then
        for _, it in ipairs(self.dragging.items) do
            draggingSet[selectionKey(it.slot, it.identifier, it.index)] = true
        end
    end

    love.graphics.setScissor(layout.x, layout.y, layout.w, layout.h)

    love.graphics.setColor(0.18, 0.18, 0.22)
    love.graphics.rectangle("fill", g.ox, g.oy, g.chunkPx, g.chunkPx)

    love.graphics.setColor(0.25, 0.25, 0.30)
    for i = 0, g.size do
        love.graphics.line(g.ox + i * g.ppu, g.oy, g.ox + i * g.ppu, g.oy + g.chunkPx)
        love.graphics.line(g.ox, g.oy + i * g.ppu, g.ox + g.chunkPx, g.oy + i * g.ppu)
    end

    -- 16-cell major grid (blue-ish). Interior only — boundary lines stay
    -- neutral so the chunk edge isn't recoloured.
    love.graphics.setColor(0.35, 0.55, 0.85)
    for i = 16, g.size - 1, 16 do
        local lx = g.ox + i * g.ppu
        local ly = g.oy + i * g.ppu
        love.graphics.line(lx, g.oy, lx, g.oy + g.chunkPx)
        love.graphics.line(g.ox, ly, g.ox + g.chunkPx, ly)
    end

    -- 32-cell major grid (dark red). Drawn after blue so it wins where they
    -- coincide (every 32-line is also a 16-line).
    love.graphics.setColor(0.55, 0.20, 0.20)
    for i = 32, g.size - 1, 32 do
        local lx = g.ox + i * g.ppu
        local ly = g.oy + i * g.ppu
        love.graphics.line(lx, g.oy, lx, g.oy + g.chunkPx)
        love.graphics.line(g.ox, ly, g.ox + g.chunkPx, ly)
    end

    love.graphics.setFont(state.fonts.small)
    for slot, group in pairs(tmpl.Groups or {}) do
        for identifier, locations in pairs(group.Locations or {}) do
            local meta = (state.identifiers or {})[identifier] or {}
            local r, gC, b = Util.hexColor(meta.Color)
            local sx = meta.SizeX or 1
            local sz = meta.SizeZ or 1
            local fpX = meta.FootprintX or 1
            local fpZ = meta.FootprintZ or 1
            -- Saved coord = world-center − 0.5 (matches the engine's UI build
            -- template convention and what `unit:GetPosition()` reports after
            -- the −0.5 normalisation in `GetLocations`). Skirt TL = footprint
            -- TL + SkirtOffset; footprint TL = worldCenter − footprintSize/2
            --   = (saved + 0.5) − footprintSize/2.
            local skirtOffsetX = (meta.SkirtOffsetX or 0) + 0.5 - fpX / 2
            local skirtOffsetZ = (meta.SkirtOffsetZ or 0) + 0.5 - fpZ / 2
            local fpAnchorX = 0.5 - fpX / 2
            local fpAnchorZ = 0.5 - fpZ / 2
            for index, loc in ipairs(locations) do
                local x = g.ox + (loc[1] + skirtOffsetX) * g.ppu
                local y = g.oy + (loc[2] + skirtOffsetZ) * g.ppu
                local rw = sx * g.ppu
                local rh = sz * g.ppu
                local fpPx = g.ox + (loc[1] + fpAnchorX) * g.ppu
                local fpPy = g.oy + (loc[2] + fpAnchorZ) * g.ppu
                local fpPw = fpX * g.ppu
                local fpPh = fpZ * g.ppu
                local key = selectionKey(slot, identifier, index)
                local isDragged = draggingSet[key]
                local isSelected = state.selection[key]

                -- Skirt: the engine's keep-out box. Drawn translucent.
                love.graphics.setColor(r, gC, b, isDragged and 0.20 or 0.30)
                love.graphics.rectangle("fill", x, y, rw, rh)

                -- Footprint: the cells the building physically occupies.
                -- Drawn opaque on top of the skirt to mark the actual
                -- structure outline.
                love.graphics.setColor(r, gC, b, isDragged and 0.55 or 0.75)
                love.graphics.rectangle("fill", fpPx, fpPy, fpPw, fpPh)
                love.graphics.setColor(0, 0, 0, 0.5)
                love.graphics.rectangle("line", fpPx, fpPy, fpPw, fpPh)

                if isDragged then
                    love.graphics.setColor(1, 1, 0)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", x, y, rw, rh)
                    love.graphics.setLineWidth(1)
                elseif isSelected then
                    love.graphics.setColor(0.4, 0.95, 1.0)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle("line", x, y, rw, rh)
                    love.graphics.setLineWidth(1)
                else
                    love.graphics.setColor(0, 0, 0, 0.45)
                    love.graphics.rectangle("line", x, y, rw, rh)
                end
                if rw >= 36 and rh >= 14 then
                    love.graphics.setColor(0, 0, 0)
                    love.graphics.printf(identifier, x, y + math.floor(rh / 2) - 6, rw, "center")
                end

                -- Debug: black dot at the saved coordinate. With the saved =
                -- worldCenter − 0.5 convention, this lands on the cell-corner
                -- at the upper-left of the central cell.
                local anchorPx = g.ox + loc[1] * g.ppu
                local anchorPy = g.oy + loc[2] * g.ppu
                local anchorR = math.max(2, math.floor(g.ppu * 0.12))
                love.graphics.setColor(0, 0, 0, 0.9)
                love.graphics.circle("fill", anchorPx, anchorPy, anchorR)

                table.insert(self.rects, {
                    x1 = x, y1 = y, x2 = x + rw, y2 = y + rh,
                    slot = slot, identifier = identifier, index = index,
                })
            end
        end
    end

    if self.selectionBox then
        local sb = self.selectionBox
        local x1 = math.min(sb.startMouseX, sb.currentX)
        local y1 = math.min(sb.startMouseY, sb.currentY)
        local x2 = math.max(sb.startMouseX, sb.currentX)
        local y2 = math.max(sb.startMouseY, sb.currentY)
        love.graphics.setColor(0.4, 0.7, 1.0, 0.18)
        love.graphics.rectangle("fill", x1, y1, x2 - x1, y2 - y1)
        love.graphics.setColor(0.4, 0.7, 1.0, 0.9)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x1, y1, x2 - x1, y2 - y1)
    end

    love.graphics.setScissor()

    -- Publish the under-cursor chunk cell so other components (status bar)
    -- can show it without owning the canvas's geometry.
    local mx, my = love.mouse.getPosition()
    if mx >= layout.x and mx < layout.x + layout.w
        and my >= layout.y and my < layout.y + layout.h then
        local cx = (mx - g.ox) / g.ppu
        local cz = (my - g.oy) / g.ppu
        if cx >= 0 and cz >= 0 and cx < g.size and cz < g.size then
            state.mouseChunk = { x = math.floor(cx), z = math.floor(cz) }
        else
            state.mouseChunk = nil
        end
    else
        state.mouseChunk = nil
    end
end

function LoveChunkCanvas:mousepressed(mx, my, button)
    local layout = self.ctx:layout().canvas
    if mx < layout.x or mx >= layout.x + layout.w then return false end
    if my < layout.y or my >= layout.y + layout.h then return false end

    if button == 2 then
        local g = self:_geometry()
        self.panning = {
            startMouseX = mx, startMouseY = my,
            startOx = g.ox, startOy = g.oy,
        }
        return true
    end

    if button ~= 1 then return false end

    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
    local alt = love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")

    local rect = self:_buildingAt(mx, my)

    if rect then
        local key = selectionKey(rect.slot, rect.identifier, rect.index)

        -- Shift + double-click: a second shift-left-click on the same
        -- building within the threshold expands the selection to every
        -- transitively edge-adjacent skirt. Doesn't start a drag.
        local now = love.timer.getTime()
        if shift and not alt
            and self.lastClickKey == key
            and (now - self.lastClickTime) < 0.4
        then
            self:selectAdjacent(rect.slot, rect.identifier, rect.index)
            self.lastClickKey = nil
            self.lastClickTime = 0
            return true
        end
        self.lastClickKey = key
        self.lastClickTime = now

        if shift then
            self.ctx.state.selection[key] = true
            self.ctx.state.selectionHistory:push(self.ctx.state.selection)
            return true
        end
        if alt then
            self.ctx.state.selection[key] = nil
            self.ctx.state.selectionHistory:push(self.ctx.state.selection)
            return true
        end

        local tmpl = self.ctx.state.loadedTemplate
        if not tmpl then return false end

        if not self.ctx.state.selection[key] then
            self.ctx.state.selection = {}
            self.ctx.state.selection[key] = true
            self.ctx.state.selectionHistory:push(self.ctx.state.selection)
        end

        local items = self:_buildDragItemsFromSelection(tmpl)
        if #items == 0 then return false end

        local primary
        for _, it in ipairs(items) do
            if it.slot == rect.slot and it.identifier == rect.identifier and it.index == rect.index then
                primary = it
                break
            end
        end
        if not primary then return false end

        local cx, cz = self:_chunkXZFromMouse(mx, my)
        self.dragging = {
            items = items,
            primaryFromX = primary.fromX,
            primaryFromZ = primary.fromZ,
            dragOffsetX = cx - primary.fromX,
            dragOffsetZ = cz - primary.fromZ,
            template = tmpl,
        }
        return true
    end

    self.selectionBox = {
        startMouseX = mx, startMouseY = my,
        currentX = mx, currentY = my,
        additive = shift,
    }
    return true
end

function LoveChunkCanvas:mousemoved(mx, my)
    if self.dragging then
        local tmpl = self.ctx.state.loadedTemplate
        if not tmpl or self.dragging.template ~= tmpl then
            self.dragging = nil
            return false
        end
        local cx, cz = self:_chunkXZFromMouse(mx, my)
        local desiredPrimaryX = math.floor(cx - self.dragging.dragOffsetX + 0.5)
        local desiredPrimaryZ = math.floor(cz - self.dragging.dragOffsetZ + 0.5)
        local desiredDX = desiredPrimaryX - self.dragging.primaryFromX
        local desiredDZ = desiredPrimaryZ - self.dragging.primaryFromZ

        local size = tmpl.Size or 16
        local minDX, maxDX = -math.huge, math.huge
        local minDZ, maxDZ = -math.huge, math.huge
        for _, it in ipairs(self.dragging.items) do
            local thisMaxX = (size - 1) - it.fromX
            local thisMinX = -it.fromX
            if thisMaxX < maxDX then maxDX = thisMaxX end
            if thisMinX > minDX then minDX = thisMinX end
            local thisMaxZ = (size - 1) - it.fromZ
            local thisMinZ = -it.fromZ
            if thisMaxZ < maxDZ then maxDZ = thisMaxZ end
            if thisMinZ > minDZ then minDZ = thisMinZ end
        end
        local actualDX = math.max(minDX, math.min(maxDX, desiredDX))
        local actualDZ = math.max(minDZ, math.min(maxDZ, desiredDZ))

        for _, it in ipairs(self.dragging.items) do
            local loc = getLocation(tmpl, it.slot, it.identifier, it.index)
            if loc then
                loc[1] = math.floor(it.fromX + actualDX)
                loc[2] = math.floor(it.fromZ + actualDZ)
            end
        end
        return true
    end
    if self.panning then
        self.camera.offsetX = self.panning.startOx + (mx - self.panning.startMouseX)
        self.camera.offsetY = self.panning.startOy + (my - self.panning.startMouseY)
        return true
    end
    if self.selectionBox then
        self.selectionBox.currentX = mx
        self.selectionBox.currentY = my
        return true
    end
    return false
end

function LoveChunkCanvas:mousereleased(mx, my, button)
    if button == 2 and self.panning then
        self.panning = nil
        return true
    end
    if button ~= 1 then return false end

    if self.dragging then
        local d = self.dragging
        self.dragging = nil
        local state = self.ctx.state
        local tmpl = state.loadedTemplate
        if not tmpl or d.template ~= tmpl then return true end

        local moved = {}
        for _, it in ipairs(d.items) do
            local loc = getLocation(tmpl, it.slot, it.identifier, it.index)
            if loc then
                local toX, toZ = loc[1], loc[2]
                if toX ~= it.fromX or toZ ~= it.fromZ then
                    loc[1], loc[2] = it.fromX, it.fromZ
                    table.insert(moved, {
                        slot = it.slot, identifier = it.identifier, index = it.index,
                        fromX = it.fromX, fromZ = it.fromZ,
                        toX = toX, toZ = toZ,
                    })
                end
            end
        end

        local cmd
        if #moved == 1 then
            local m = moved[1]
            cmd = MoveBuilding.new(m.slot, m.identifier, m.index, m.fromX, m.fromZ, m.toX, m.toZ)
        elseif #moved > 1 then
            local subs = {}
            for _, m in ipairs(moved) do
                table.insert(subs, MoveBuilding.new(m.slot, m.identifier, m.index, m.fromX, m.fromZ, m.toX, m.toZ))
            end
            cmd = Composite.new(subs)
        end
        if cmd then
            state.history:apply(tmpl, cmd)
            state.saveStatus = nil
        end
        return true
    end

    if self.selectionBox then
        local sb = self.selectionBox
        self.selectionBox = nil
        local x1 = math.min(sb.startMouseX, mx)
        local y1 = math.min(sb.startMouseY, my)
        local x2 = math.max(sb.startMouseX, mx)
        local y2 = math.max(sb.startMouseY, my)
        if not sb.additive then
            self.ctx.state.selection = {}
        end
        for _, r in ipairs(self.rects) do
            if r.x1 < x2 and r.x2 > x1 and r.y1 < y2 and r.y2 > y1 then
                self.ctx.state.selection[selectionKey(r.slot, r.identifier, r.index)] = true
            end
        end
        self.ctx.state.selectionHistory:push(self.ctx.state.selection)
        return true
    end

    return false
end

function LoveChunkCanvas:wheelmoved(_, y, mx, my)
    if y == 0 then return false end
    local layout = self.ctx:layout().canvas
    if mx < layout.x or mx >= layout.x + layout.w then return false end
    if my < layout.y or my >= layout.y + layout.h then return false end
    local factor = (y > 0) and ZOOM_WHEEL or (1 / ZOOM_WHEEL)
    self:_zoomAt(mx, my, factor)
    return true
end

function LoveChunkCanvas:keypressed(key)
    if key == "escape" then
        if self.dragging then
            local tmpl = self.ctx.state.loadedTemplate
            if tmpl and self.dragging.template == tmpl then
                for _, it in ipairs(self.dragging.items) do
                    local loc = getLocation(tmpl, it.slot, it.identifier, it.index)
                    if loc then
                        loc[1] = it.fromX
                        loc[2] = it.fromZ
                    end
                end
            end
            self.dragging = nil
            return true
        end
        if self.selectionBox then
            self.selectionBox = nil
            return true
        end
        if next(self.ctx.state.selection) then
            self.ctx.state.selection = {}
            self.ctx.state.selectionHistory:push(self.ctx.state.selection)
            return true
        end
        return false
    end

    return false
end

local function deepCopyLocations(locs)
    local copy = {}
    for id, list in pairs(locs) do
        local listCopy = {}
        for k = 1, #list do
            local loc = list[k]
            listCopy[k] = { loc[1], loc[2], loc[3] }
        end
        copy[id] = listCopy
    end
    return copy
end

local function deepCopyGroup(group)
    if not group then return false end
    return {
        Name = group.Name,
        Locations = deepCopyLocations(group.Locations or {}),
    }
end

local function isGroupEmpty(group)
    if not group or not group.Locations then return true end
    for _, locs in pairs(group.Locations) do
        if #locs > 0 then return false end
    end
    return true
end

--- Take the current selection and move it into `slot`. Buildings already in
--- `slot` stay; buildings in other groups leave their old group. After the
--- move, the selection is the full contents of `slot`.
---@param slot integer
function LoveChunkCanvas:assignSelectionToGroup(slot)
    local state = self.ctx.state
    local tmpl = state.loadedTemplate
    if not tmpl or not next(state.selection) then return end

    -- Resolve the selected keys into concrete location records.
    -- Skip items already in the destination slot — they're staying put.
    local moveItems = {}
    for key in pairs(state.selection) do
        local s, id, idx = parseSelectionKey(key)
        if s and id and idx and s ~= slot then
            local loc = getLocation(tmpl, s, id, idx)
            if loc then
                table.insert(moveItems, {
                    sourceSlot = s, identifier = id, index = idx,
                    location = { loc[1], loc[2], loc[3] },
                })
            end
        end
    end

    -- Determine which slots are touched (sources + destination).
    local affectedSlots = { [slot] = true }
    for _, it in ipairs(moveItems) do
        affectedSlots[it.sourceSlot] = true
    end

    -- Snapshot before-state.
    local beforeSlots = {}
    for s in pairs(affectedSlots) do
        beforeSlots[s] = deepCopyGroup(tmpl.Groups and tmpl.Groups[s])
    end

    -- Build after-state by deep-copying then mutating.
    local afterSlots = {}
    for s in pairs(affectedSlots) do
        afterSlots[s] = deepCopyGroup(tmpl.Groups and tmpl.Groups[s])
    end

    -- Remove items from sources. Group by (slot, identifier) and remove
    -- highest indices first so lower ones don't shift mid-removal.
    local removals = {}
    for _, it in ipairs(moveItems) do
        removals[it.sourceSlot] = removals[it.sourceSlot] or {}
        local byId = removals[it.sourceSlot]
        byId[it.identifier] = byId[it.identifier] or {}
        table.insert(byId[it.identifier], it.index)
    end
    for s, byId in pairs(removals) do
        local grp = afterSlots[s]
        if grp then
            for id, indices in pairs(byId) do
                table.sort(indices, function(a, b) return a > b end)
                local locs = grp.Locations[id]
                if locs then
                    for _, idx in ipairs(indices) do
                        table.remove(locs, idx)
                    end
                    if #locs == 0 then grp.Locations[id] = nil end
                end
            end
        end
    end

    -- Append moved items to destination.
    if not afterSlots[slot] then
        afterSlots[slot] = { Name = "Group " .. slot, Locations = {} }
    end
    for _, it in ipairs(moveItems) do
        afterSlots[slot].Locations[it.identifier] = afterSlots[slot].Locations[it.identifier] or {}
        table.insert(afterSlots[slot].Locations[it.identifier], it.location)
    end

    -- Drop now-empty source groups.
    for s, grp in pairs(afterSlots) do
        if s ~= slot and grp and isGroupEmpty(grp) then
            afterSlots[s] = false
        end
    end

    -- No-op if nothing changed (e.g. all selected items already in dest slot).
    if #moveItems == 0 then return end

    local cmd = AssignGroup.new(slot, beforeSlots, afterSlots)
    state.history:apply(tmpl, cmd)
    state.saveStatus = nil

    -- Selection becomes the full contents of the destination slot.
    local newSel = {}
    local destLocs = (tmpl.Groups[slot] and tmpl.Groups[slot].Locations) or {}
    for id, locs in pairs(destLocs) do
        for idx = 1, #locs do
            newSel[selectionKey(slot, id, idx)] = true
        end
    end
    state.selection = newSel
    state.selectionHistory:push(newSel)
end

--- Two skirt rectangles share an edge — i.e. one rect's edge lies on the
--- other's, with the projections on the perpendicular axis overlapping. Pure
--- corner contact doesn't count (diagonal walls don't form a continuous
--- wall). Buildings whose skirt offsets don't align (e.g. wall + power gen)
--- can never satisfy this — there's always a half-cell gap, matching the
--- engine.
local function skirtsEdgeAdjacent(ax1, az1, ax2, az2, bx1, bz1, bx2, bz2)
    local xTouch = (ax2 == bx1) or (ax1 == bx2)
    local zOverlap = (az1 < bz2) and (bz1 < az2)
    if xTouch and zOverlap then return true end
    local zTouch = (az2 == bz1) or (az1 == bz2)
    local xOverlap = (ax1 < bx2) and (bx1 < ax2)
    return zTouch and xOverlap
end

--- Replace the selection with everything transitively edge-adjacent to the
--- supplied building (BFS through skirt rectangles). The starter is
--- included in the result. Adjacency uses each identifier's `SkirtOffsetX/Z`
--- so wall + power gen pairs naturally don't connect (their skirts can't
--- align flush).
---@param slot integer
---@param identifier LoveBuildingIdentifier
---@param index integer
function LoveChunkCanvas:selectAdjacent(slot, identifier, index)
    local state = self.ctx.state
    local tmpl = state.loadedTemplate
    if not tmpl then return end

    -- Collect every building's skirt rect once, keyed by selection key for
    -- O(1) lookup during BFS.
    local items = {}
    for s, group in pairs(tmpl.Groups or {}) do
        for id, locs in pairs(group.Locations or {}) do
            local meta = (state.identifiers or {})[id] or {}
            local sx = meta.SizeX or 1
            local sz = meta.SizeZ or 1
            local ox = meta.SkirtOffsetX or 0
            local oz = meta.SkirtOffsetZ or 0
            for idx, loc in ipairs(locs) do
                local x1 = loc[1] + ox
                local z1 = loc[2] + oz
                table.insert(items, {
                    key = selectionKey(s, id, idx),
                    x1 = x1, z1 = z1, x2 = x1 + sx, z2 = z1 + sz,
                })
            end
        end
    end

    local startKey = selectionKey(slot, identifier, index)
    local visited = { [startKey] = true }
    local queue = { startKey }
    local byKey = {}
    for _, it in ipairs(items) do byKey[it.key] = it end

    -- Shrink-and-pop is O(n) per pop; for the typical chunk size this is
    -- fine. Switch to an index cursor if the chunks ever grow large.
    while #queue > 0 do
        local key = table.remove(queue, 1)
        local current = byKey[key]
        if current then
            for _, other in ipairs(items) do
                if not visited[other.key] then
                    if skirtsEdgeAdjacent(
                        current.x1, current.z1, current.x2, current.z2,
                        other.x1, other.z1, other.x2, other.z2
                    ) then
                        visited[other.key] = true
                        table.insert(queue, other.key)
                    end
                end
            end
        end
    end

    state.selection = visited
    state.selectionHistory:push(visited)
end

--- Replace the selection with every build site whose skirt overlaps another's
--- (interior intersection — edge-touching is fine). Useful as a "validate"
--- pass after editing to surface chunks the engine would refuse to place.
function LoveChunkCanvas:detectOverlaps()
    local state = self.ctx.state
    local tmpl = state.loadedTemplate
    if not tmpl then return end

    -- Collect every site's skirt rect in chunk-space using the same formula
    -- the canvas uses to render: skirtTL = loc + SkirtOffset + 0.5 - Footprint/2.
    -- (selectAdjacent's loc + SkirtOffset is wrong for odd footprints > 1
    -- like hydro / factories — different rect than what the user sees.)
    local items = {}
    for slot, group in pairs(tmpl.Groups or {}) do
        for id, locs in pairs(group.Locations or {}) do
            local meta = (state.identifiers or {})[id] or {}
            local fpX = meta.FootprintX or 1
            local fpZ = meta.FootprintZ or 1
            local sx = meta.SizeX or 1
            local sz = meta.SizeZ or 1
            local ox = (meta.SkirtOffsetX or 0) + 0.5 - fpX / 2
            local oz = (meta.SkirtOffsetZ or 0) + 0.5 - fpZ / 2
            for idx, loc in ipairs(locs) do
                local x1 = loc[1] + ox
                local z1 = loc[2] + oz
                table.insert(items, {
                    key = selectionKey(slot, id, idx),
                    x1 = x1, z1 = z1, x2 = x1 + sx, z2 = z1 + sz,
                })
            end
        end
    end

    -- Strict interior intersection with a tiny float epsilon so
    -- edge-touches (a.x2 == b.x1) don't get flagged as overlap.
    local EPS = 1e-9
    local overlap = {}
    for i = 1, #items do
        local a = items[i]
        for j = i + 1, #items do
            local b = items[j]
            if a.x1 + EPS < b.x2 and a.x2 > b.x1 + EPS
                and a.z1 + EPS < b.z2 and a.z2 > b.z1 + EPS then
                overlap[a.key] = true
                overlap[b.key] = true
            end
        end
    end

    state.selection = overlap
    state.selectionHistory:push(overlap)

    local n = 0
    for _ in pairs(overlap) do n = n + 1 end
    if n == 0 then
        state.saveStatus = "No overlapping sites"
    else
        state.saveStatus = string.format("%d overlapping site(s) selected", n)
    end
    print(state.saveStatus)
end

--- Replace selection with the contents of `slot`. No-op for empty slots.
---@param slot integer
function LoveChunkCanvas:selectGroup(slot)
    local state = self.ctx.state
    local tmpl = state.loadedTemplate
    if not tmpl then return end
    local group = tmpl.Groups and tmpl.Groups[slot]
    if not group or isGroupEmpty(group) then return end

    local newSel = {}
    for id, locs in pairs(group.Locations) do
        for idx = 1, #locs do
            newSel[selectionKey(slot, id, idx)] = true
        end
    end
    state.selection = newSel
    state.selectionHistory:push(newSel)
end

--- Add a fresh instance of `identifier` at the chunk center, in the default
--- group (slot 1). The new building becomes the only selection so the user
--- can immediately drag it where they want.
---@param identifier LoveBuildingIdentifier
function LoveChunkCanvas:addBuilding(identifier)
    local state = self.ctx.state
    local tmpl = state.loadedTemplate
    if not tmpl then return end

    local size = tmpl.Size or 16
    local center = math.floor(size / 2)
    local slot = 1

    local beforeSlots = { [slot] = deepCopyGroup(tmpl.Groups and tmpl.Groups[slot]) }

    local afterCopy = deepCopyGroup(tmpl.Groups and tmpl.Groups[slot])
    if afterCopy == false then
        afterCopy = { Name = "default", Locations = {} }
    end
    afterCopy.Locations[identifier] = afterCopy.Locations[identifier] or {}
    table.insert(afterCopy.Locations[identifier], { center, center, 0 })

    local afterSlots = { [slot] = afterCopy }

    local cmd = InsertBuildings.new(1, beforeSlots, afterSlots)
    state.history:apply(tmpl, cmd)
    state.saveStatus = nil

    local newIdx = #tmpl.Groups[slot].Locations[identifier]
    state.selection = { [selectionKey(slot, identifier, newIdx)] = true }
    state.selectionHistory:push(state.selection)
end

--- Remove selected buildings. Selection is cleared after.
function LoveChunkCanvas:deleteSelection()
    local state = self.ctx.state
    local tmpl = state.loadedTemplate
    if not tmpl or not next(state.selection) then return end

    -- Resolve selection into concrete (slot, identifier, index) items.
    local items = {}
    for key in pairs(state.selection) do
        local s, id, idx = parseSelectionKey(key)
        if s and id and idx and getLocation(tmpl, s, id, idx) then
            table.insert(items, { slot = s, identifier = id, index = idx })
        end
    end
    if #items == 0 then return end

    local affectedSlots = {}
    for _, it in ipairs(items) do affectedSlots[it.slot] = true end

    local beforeSlots = {}
    for s in pairs(affectedSlots) do
        beforeSlots[s] = deepCopyGroup(tmpl.Groups and tmpl.Groups[s])
    end

    local afterSlots = {}
    for s in pairs(affectedSlots) do
        afterSlots[s] = deepCopyGroup(tmpl.Groups and tmpl.Groups[s])
    end

    -- Group removals by (slot, identifier); remove highest indices first.
    local removals = {}
    for _, it in ipairs(items) do
        removals[it.slot] = removals[it.slot] or {}
        removals[it.slot][it.identifier] = removals[it.slot][it.identifier] or {}
        table.insert(removals[it.slot][it.identifier], it.index)
    end
    for s, byId in pairs(removals) do
        local grp = afterSlots[s]
        if grp then
            for id, indices in pairs(byId) do
                table.sort(indices, function(a, b) return a > b end)
                local locs = grp.Locations[id]
                if locs then
                    for _, idx in ipairs(indices) do
                        table.remove(locs, idx)
                    end
                    if #locs == 0 then grp.Locations[id] = nil end
                end
            end
        end
    end

    -- Drop now-empty groups.
    for s, grp in pairs(afterSlots) do
        if grp and isGroupEmpty(grp) then
            afterSlots[s] = false
        end
    end

    local cmd = DeleteBuildings.new(#items, beforeSlots, afterSlots)
    state.history:apply(tmpl, cmd)
    state.saveStatus = nil

    state.selection = {}
    state.selectionHistory:push(state.selection)
end

--- Translate every selected building by `(dx, dz)` cells. The delta is
--- clamped so no selected building leaves the chunk — same logic as the
--- multi-drag path in `mousemoved`. No-op when there's no selection or the
--- clamped delta collapses to zero.
---@param dx integer
---@param dz integer
function LoveChunkCanvas:translateSelection(dx, dz)
    local state = self.ctx.state
    local tmpl = state.loadedTemplate
    if not tmpl or not next(state.selection) then return end

    local items = self:_buildDragItemsFromSelection(tmpl)
    if #items == 0 then return end

    local size = tmpl.Size or 16
    local minDX, maxDX = -math.huge, math.huge
    local minDZ, maxDZ = -math.huge, math.huge
    for _, it in ipairs(items) do
        local thisMaxX = (size - 1) - it.fromX
        local thisMinX = -it.fromX
        if thisMaxX < maxDX then maxDX = thisMaxX end
        if thisMinX > minDX then minDX = thisMinX end
        local thisMaxZ = (size - 1) - it.fromZ
        local thisMinZ = -it.fromZ
        if thisMaxZ < maxDZ then maxDZ = thisMaxZ end
        if thisMinZ > minDZ then minDZ = thisMinZ end
    end
    local actualDX = math.max(minDX, math.min(maxDX, dx))
    local actualDZ = math.max(minDZ, math.min(maxDZ, dz))
    if actualDX == 0 and actualDZ == 0 then return end

    local subs = {}
    for _, it in ipairs(items) do
        table.insert(subs, MoveBuilding.new(
            it.slot, it.identifier, it.index,
            it.fromX, it.fromZ,
            it.fromX + actualDX, it.fromZ + actualDZ
        ))
    end

    local cmd = (#subs == 1) and subs[1] or Composite.new(subs)
    state.history:apply(tmpl, cmd)
    state.saveStatus = nil
end

--- Drop the selected buildings with the largest footprint area. Useful for
--- quickly peeling factories or other oversized structures off a mixed
--- selection — e.g. select-all in a chunk, then `shrinkSelection` to leave
--- just the small stuff.
---
--- The metric is footprint area (`FootprintX * FootprintZ`); skirts are
--- ignored. If every selected building shares the same footprint area, the
--- whole selection is dropped (selection becomes empty). Identifiers without
--- metadata are treated as 1×1.
function LoveChunkCanvas:shrinkSelection()
    local state = self.ctx.state
    if not next(state.selection) then return end
    local idents = state.identifiers or {}

    local maxArea = 0
    for key in pairs(state.selection) do
        local _, id = parseSelectionKey(key)
        if id then
            local meta = idents[id] or {}
            local area = (meta.FootprintX or 1) * (meta.FootprintZ or 1)
            if area > maxArea then maxArea = area end
        end
    end

    local newSel = {}
    local dropped = 0
    for key in pairs(state.selection) do
        local _, id = parseSelectionKey(key)
        if id then
            local meta = idents[id] or {}
            local area = (meta.FootprintX or 1) * (meta.FootprintZ or 1)
            if area < maxArea then
                newSel[key] = true
            else
                dropped = dropped + 1
            end
        end
    end

    if dropped == 0 then return end
    state.selection = newSel
    state.selectionHistory:push(newSel)
end

--- Transform every selected building in place. `pivot` chooses the centre
--- of reflection / rotation:
---   "selection" (default) — centre of the selection's saved-coord bounding
---                            box. Pieces flip/rotate within the selection's
---                            envelope; the envelope itself stays put.
---   "chunk"               — geometric centre of the chunk. Useful for
---                            "fold the whole layout across the chunk".
---
--- `transform` is one of:
---   "flip-x"     — swap left/right (X flips, Z stays)
---   "flip-z"     — swap top/bottom (Z flips, X stays)
---   "rotate-cw"  — rotate 90° clockwise (visually, in screen space)
---   "rotate-ccw" — rotate 90° counter-clockwise
---
--- Buildings keep their group membership and selection keys; only saved
--- coords change. Emitted as a single `Composite` so the whole transform is
--- one undoable step.
---@param transform "flip-x" | "flip-z" | "rotate-cw" | "rotate-ccw"
---@param pivot? "selection" | "chunk"
function LoveChunkCanvas:transformSelection(transform, pivot)
    local state = self.ctx.state
    local tmpl = state.loadedTemplate
    if not tmpl or not next(state.selection) then return end

    local items = self:_buildDragItemsFromSelection(tmpl)
    if #items == 0 then return end

    local pivotX, pivotZ
    if pivot == "chunk" then
        local size = tmpl.Size or 16
        pivotX = (size - 1) / 2
        pivotZ = (size - 1) / 2
    else
        pivotX, pivotZ = selectionBboxCentre(items)
    end

    local subs = {}
    for _, it in ipairs(items) do
        local toX, toZ = applyTransform(transform, pivotX, pivotZ, it.fromX, it.fromZ)
        if toX ~= it.fromX or toZ ~= it.fromZ then
            table.insert(subs, MoveBuilding.new(
                it.slot, it.identifier, it.index,
                it.fromX, it.fromZ, toX, toZ
            ))
        end
    end
    if #subs == 0 then return end

    local cmd = (#subs == 1) and subs[1] or Composite.new(subs)
    state.history:apply(tmpl, cmd)
    state.saveStatus = nil
end

--- Duplicate selected buildings, offset by 1 unit toward chunk center on
--- both axes. The new copies stay in the same group as their originals;
--- selection becomes the copies.
function LoveChunkCanvas:duplicateSelection()
    local state = self.ctx.state
    local tmpl = state.loadedTemplate
    if not tmpl or not next(state.selection) then return end

    local size = tmpl.Size or 16
    local center = size / 2

    -- Resolve selection into copy specs with the shifted target position.
    local inserts = {}
    for key in pairs(state.selection) do
        local s, id, idx = parseSelectionKey(key)
        if s and id and idx then
            local loc = getLocation(tmpl, s, id, idx)
            if loc then
                local dx = (loc[1] < center) and 1 or -1
                local dz = (loc[2] < center) and 1 or -1
                local newX = loc[1] + dx
                local newZ = loc[2] + dz
                if newX < 0 then newX = 0 end
                if newZ < 0 then newZ = 0 end
                if newX > size - 1 then newX = size - 1 end
                if newZ > size - 1 then newZ = size - 1 end
                table.insert(inserts, {
                    slot = s, identifier = id,
                    location = { newX, newZ, loc[3] or 0 },
                })
            end
        end
    end
    if #inserts == 0 then return end

    local affectedSlots = {}
    for _, it in ipairs(inserts) do affectedSlots[it.slot] = true end

    local beforeSlots = {}
    for s in pairs(affectedSlots) do
        beforeSlots[s] = deepCopyGroup(tmpl.Groups and tmpl.Groups[s])
    end

    local afterSlots = {}
    for s in pairs(affectedSlots) do
        local copy = deepCopyGroup(tmpl.Groups and tmpl.Groups[s])
        if copy == false then
            copy = { Name = "Group " .. s, Locations = {} }
        end
        afterSlots[s] = copy
    end
    -- Append the copies to their respective slot/identifier buckets.
    for _, it in ipairs(inserts) do
        local grp = afterSlots[it.slot]
        grp.Locations[it.identifier] = grp.Locations[it.identifier] or {}
        table.insert(grp.Locations[it.identifier], it.location)
    end

    local cmd = InsertBuildings.new(#inserts, beforeSlots, afterSlots)
    state.history:apply(tmpl, cmd)
    state.saveStatus = nil

    -- Selection becomes the new copies. They're at the END of each (slot, id)
    -- bucket in the destination, so count appended-per-slot-id and pull the
    -- last N indices from the now-mutated template.
    local appendedPerSlotId = {}
    for _, it in ipairs(inserts) do
        appendedPerSlotId[it.slot] = appendedPerSlotId[it.slot] or {}
        appendedPerSlotId[it.slot][it.identifier] = (appendedPerSlotId[it.slot][it.identifier] or 0) + 1
    end
    local newSel = {}
    for slot, byId in pairs(appendedPerSlotId) do
        for id, count in pairs(byId) do
            local total = #(tmpl.Groups[slot].Locations[id] or {})
            for k = total - count + 1, total do
                newSel[selectionKey(slot, id, k)] = true
            end
        end
    end
    state.selection = newSel
    state.selectionHistory:push(newSel)
end

return LoveChunkCanvas
