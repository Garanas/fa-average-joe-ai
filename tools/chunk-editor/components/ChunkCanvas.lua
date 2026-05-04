---@diagnostic disable: need-check-nil

local Util = require("util")
local MoveBuilding = require("commands.MoveBuilding")
local Composite = require("commands.Composite")

local ZOOM_WHEEL = 1.15
local ZOOM_HOTKEY = 1.25
local ZOOM_MIN = 0.1
local ZOOM_MAX = 16
local KEY_PAN_STEP = 30

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
---@field selection table<string, boolean>
---@field camera LoveCameraState
local LoveChunkCanvas = {}
LoveChunkCanvas.__index = LoveChunkCanvas

local function selectionKey(identifier, index)
    return identifier .. "|" .. tostring(index)
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
        selection = {},
        camera = { offsetX = nil, offsetY = nil, zoom = nil },
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

function LoveChunkCanvas:zoomInCenter()
    self:zoomAtCenter(ZOOM_HOTKEY)
end

function LoveChunkCanvas:zoomOutCenter()
    self:zoomAtCenter(1 / ZOOM_HOTKEY)
end

function LoveChunkCanvas:reset()
    self.camera = { offsetX = nil, offsetY = nil, zoom = nil }
end

function LoveChunkCanvas:onChunkChange()
    self:reset()
    self.selection = {}
    self.dragging = nil
    self.panning = nil
    self.selectionBox = nil
end

function LoveChunkCanvas:_panBy(dx, dy)
    local g = self:_geometry()
    self.camera.offsetX = g.ox + dx
    self.camera.offsetY = g.oy + dy
end

---@return LoveDragItem[]
function LoveChunkCanvas:_buildDragItemsFromSelection(tmpl)
    local items = {}
    for key in pairs(self.selection) do
        local id, idxStr = key:match("^(.-)|(%d+)$")
        local idx = tonumber(idxStr)
        if id and idx and tmpl.Locations[id] and tmpl.Locations[id][idx] then
            local loc = tmpl.Locations[id][idx]
            table.insert(items, {
                identifier = id, index = idx, fromX = loc[1], fromZ = loc[2],
            })
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

    -- Fast lookup of which rects are currently being dragged.
    local draggingSet = {}
    if self.dragging and self.dragging.template == tmpl then
        for _, it in ipairs(self.dragging.items) do
            draggingSet[selectionKey(it.identifier, it.index)] = true
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

    love.graphics.setFont(state.fonts.small)
    for identifier, locations in pairs(tmpl.Locations or {}) do
        local meta = (state.identifiers or {})[identifier] or {}
        local r, gC, b = Util.hexColor(meta.Color)
        local sx = meta.SizeX or 1
        local sz = meta.SizeZ or 1
        local anchorOffsetX = (sx % 2 == 0) and (1 - sx / 2) or 0
        local anchorOffsetZ = (sz % 2 == 0) and (1 - sz / 2) or 0
        for index, loc in ipairs(locations) do
            local x = g.ox + (loc[1] + anchorOffsetX) * g.ppu
            local y = g.oy + (loc[2] + anchorOffsetZ) * g.ppu
            local rw = sx * g.ppu
            local rh = sz * g.ppu
            local key = selectionKey(identifier, index)
            local isDragged = draggingSet[key]
            local isSelected = self.selection[key]

            love.graphics.setColor(r, gC, b, isDragged and 0.7 or 0.85)
            love.graphics.rectangle("fill", x, y, rw, rh)

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
                love.graphics.setColor(0, 0, 0, 0.6)
                love.graphics.rectangle("line", x, y, rw, rh)
            end
            if rw >= 36 and rh >= 14 then
                love.graphics.setColor(0, 0, 0)
                love.graphics.printf(identifier, x, y + math.floor(rh / 2) - 6, rw, "center")
            end

            table.insert(self.rects, {
                x1 = x, y1 = y, x2 = x + rw, y2 = y + rh,
                identifier = identifier, index = index,
            })
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
end

function LoveChunkCanvas:mousepressed(mx, my, button)
    local layout = self.ctx:layout().canvas
    if mx < layout.x or mx >= layout.x + layout.w then return false end
    if my < layout.y or my >= layout.y + layout.h then return false end

    if button == 2 then
        local g = self:_geometry()
        self.panning = {
            startMouseX = mx,
            startMouseY = my,
            startOx = g.ox,
            startOy = g.oy,
        }
        return true
    end

    if button ~= 1 then return false end

    local shift = love.keyboard.isDown("lshift") or love.keyboard.isDown("rshift")
    local alt = love.keyboard.isDown("lalt") or love.keyboard.isDown("ralt")

    local rect = self:_buildingAt(mx, my)

    if rect then
        local key = selectionKey(rect.identifier, rect.index)
        if shift then
            self.selection[key] = true
            return true
        end
        if alt then
            self.selection[key] = nil
            return true
        end

        local tmpl = self.ctx.state.loadedTemplate
        if not tmpl then return false end

        -- Plain click: ensure clicked building is the selected set, then drag all selected.
        if not self.selection[key] then
            self.selection = {}
            self.selection[key] = true
        end

        local items = self:_buildDragItemsFromSelection(tmpl)
        if #items == 0 then return false end

        local primary
        for _, it in ipairs(items) do
            if it.identifier == rect.identifier and it.index == rect.index then
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

    -- Empty-canvas left-click: start a selection box. Shift held → additive.
    self.selectionBox = {
        startMouseX = mx,
        startMouseY = my,
        currentX = mx,
        currentY = my,
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
            local loc = tmpl.Locations[it.identifier][it.index]
            loc[1] = math.floor(it.fromX + actualDX)
            loc[2] = math.floor(it.fromZ + actualDZ)
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
            local loc = tmpl.Locations[it.identifier][it.index]
            local toX, toZ = loc[1], loc[2]
            if toX ~= it.fromX or toZ ~= it.fromZ then
                loc[1], loc[2] = it.fromX, it.fromZ
                table.insert(moved, {
                    identifier = it.identifier, index = it.index,
                    fromX = it.fromX, fromZ = it.fromZ,
                    toX = toX, toZ = toZ,
                })
            end
        end

        local cmd
        if #moved == 1 then
            local m = moved[1]
            cmd = MoveBuilding.new(m.identifier, m.index, m.fromX, m.fromZ, m.toX, m.toZ)
        elseif #moved > 1 then
            local subs = {}
            for _, m in ipairs(moved) do
                table.insert(subs, MoveBuilding.new(m.identifier, m.index, m.fromX, m.fromZ, m.toX, m.toZ))
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
            self.selection = {}
        end
        for _, r in ipairs(self.rects) do
            if r.x1 < x2 and r.x2 > x1 and r.y1 < y2 and r.y2 > y1 then
                self.selection[selectionKey(r.identifier, r.index)] = true
            end
        end
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
                    local loc = tmpl.Locations[it.identifier][it.index]
                    loc[1] = it.fromX
                    loc[2] = it.fromZ
                end
            end
            self.dragging = nil
            return true
        end
        if self.selectionBox then
            self.selectionBox = nil
            return true
        end
        if next(self.selection) then
            self.selection = {}
            return true
        end
        return false
    end

    -- Don't shadow ctrl-modified arrows; let hotkey dispatch handle them.
    local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
    if ctrl then return false end
    if self.ctx.state.currentPath then return false end

    if key == "up"    then self:_panBy(0, KEY_PAN_STEP)  return true end
    if key == "down"  then self:_panBy(0, -KEY_PAN_STEP) return true end
    if key == "left"  then self:_panBy(KEY_PAN_STEP, 0)  return true end
    if key == "right" then self:_panBy(-KEY_PAN_STEP, 0) return true end
    return false
end

return LoveChunkCanvas
