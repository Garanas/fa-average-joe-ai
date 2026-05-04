---@diagnostic disable: need-check-nil

local Util = require("util")
local MoveBuilding = require("commands.MoveBuilding")

local ZOOM_WHEEL = 1.15
local ZOOM_HOTKEY = 1.25
local ZOOM_MIN = 0.1
local ZOOM_MAX = 16
local KEY_PAN_STEP = 30

---@class LoveCameraState
---@field offsetX number?  # nil = use baseFit (auto-centered)
---@field offsetY number?
---@field zoom number?

---@class LovePanState
---@field startMouseX number
---@field startMouseY number
---@field startOx number
---@field startOy number

---@class LoveDragState
---@field identifier LoveBuildingIdentifier
---@field index integer
---@field dragOffsetX number
---@field dragOffsetZ number
---@field fromX integer
---@field fromZ integer
---@field template LoveBaseChunk

---@class LoveChunkCanvas : LoveComponent
---@field ctx LoveAppContext
---@field rects table[]
---@field dragging LoveDragState?
---@field panning LovePanState?
---@field camera LoveCameraState
local LoveChunkCanvas = {}
LoveChunkCanvas.__index = LoveChunkCanvas

---@param ctx LoveAppContext
---@return LoveChunkCanvas
function LoveChunkCanvas.new(ctx)
    return setmetatable({
        ctx = ctx,
        rects = {},
        dragging = nil,
        panning = nil,
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

function LoveChunkCanvas:_panBy(dx, dy)
    local g = self:_geometry()
    self.camera.offsetX = g.ox + dx
    self.camera.offsetY = g.oy + dy
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

    -- Clip rendering to the canvas area: zoom/pan can push the chunk off
    -- its allotted region, and we don't want it bleeding into the sidebar
    -- or top/bottom bars.
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
            local isDragged = self.dragging
                and self.dragging.identifier == identifier
                and self.dragging.index == index

            love.graphics.setColor(r, gC, b, isDragged and 0.7 or 0.85)
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

            table.insert(self.rects, {
                x1 = x, y1 = y, x2 = x + rw, y2 = y + rh,
                identifier = identifier, index = index,
            })
        end
    end

    love.graphics.setScissor()
end

function LoveChunkCanvas:mousepressed(mx, my, button)
    local layout = self.ctx:layout().canvas
    if mx < layout.x or mx >= layout.x + layout.w then return false end
    if my < layout.y or my >= layout.y + layout.h then return false end

    if button == 2 then
        -- Right-click anywhere in canvas → pan camera.
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

    local rect = self:_buildingAt(mx, my)
    if rect then
        local tmpl = self.ctx.state.loadedTemplate
        if not tmpl then return false end
        local cx, cz = self:_chunkXZFromMouse(mx, my)
        local loc = tmpl.Locations[rect.identifier][rect.index]
        self.dragging = {
            identifier = rect.identifier,
            index = rect.index,
            dragOffsetX = cx - loc[1],
            dragOffsetZ = cz - loc[2],
            fromX = loc[1],
            fromZ = loc[2],
            template = tmpl,
        }
        return true
    end

    -- Left-click on empty canvas: reserved for the upcoming selection box.
    return false
end

function LoveChunkCanvas:mousemoved(mx, my)
    if self.dragging then
        local tmpl = self.ctx.state.loadedTemplate
        if not tmpl or self.dragging.template ~= tmpl then
            self.dragging = nil
            return false
        end
        local cx, cz = self:_chunkXZFromMouse(mx, my)
        local newX = math.floor(cx - self.dragging.dragOffsetX + 0.5)
        local newZ = math.floor(cz - self.dragging.dragOffsetZ + 0.5)
        local size = tmpl.Size or 16
        if newX < 0 then newX = 0 end
        if newZ < 0 then newZ = 0 end
        if newX > size - 1 then newX = size - 1 end
        if newZ > size - 1 then newZ = size - 1 end
        local loc = tmpl.Locations[self.dragging.identifier][self.dragging.index]
        loc[1] = newX
        loc[2] = newZ
        return true
    end
    if self.panning then
        self.camera.offsetX = self.panning.startOx + (mx - self.panning.startMouseX)
        self.camera.offsetY = self.panning.startOy + (my - self.panning.startMouseY)
        return true
    end
    return false
end

function LoveChunkCanvas:mousereleased(_, _, button)
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

        local loc = tmpl.Locations[d.identifier][d.index]
        local toX, toZ = loc[1], loc[2]
        if toX ~= d.fromX or toZ ~= d.fromZ then
            loc[1], loc[2] = d.fromX, d.fromZ
            local cmd = MoveBuilding.new(d.identifier, d.index, d.fromX, d.fromZ, toX, toZ)
            state.history:apply(tmpl, cmd)
            state.saveStatus = nil
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
