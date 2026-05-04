local Util = require("util")
local MoveBuilding = require("commands.MoveBuilding")

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
local LoveChunkCanvas = {}
LoveChunkCanvas.__index = LoveChunkCanvas

---@param ctx LoveAppContext
---@return LoveChunkCanvas
function LoveChunkCanvas.new(ctx)
    return setmetatable({
        ctx = ctx,
        rects = {},
        dragging = nil,
    }, LoveChunkCanvas)
end

function LoveChunkCanvas:_geometry()
    local rect = self.ctx:layout().canvas
    local tmpl = self.ctx.state.loadedTemplate
    if not tmpl then return nil end
    local size = tmpl.Size or 16
    local areaW, areaH = rect.w - 32, rect.h - 32
    local ppu = math.floor(math.min(areaW / size, areaH / size))
    if ppu < 1 then ppu = 1 end
    local chunkPx = size * ppu
    local ox = rect.x + 16 + math.floor((areaW - chunkPx) / 2)
    local oy = rect.y + 16 + math.floor((areaH - chunkPx) / 2)
    return { ox = ox, oy = oy, ppu = ppu, chunkPx = chunkPx, size = size }
end

function LoveChunkCanvas:_chunkXZFromMouse(mx, my)
    local g = self:_geometry()
    if not g then return 0, 0 end
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

    local g = self:_geometry()
    if not g then return end

    -- Drop a stale drag if the loaded chunk changed since drag-start.
    if self.dragging and self.dragging.template ~= tmpl then
        self.dragging = nil
    end

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
end

function LoveChunkCanvas:mousepressed(mx, my, button)
    if button ~= 1 then return false end
    local layout = self.ctx:layout().canvas
    if mx < layout.x or mx >= layout.x + layout.w then return false end
    if my < layout.y or my >= layout.y + layout.h then return false end

    local rect = self:_buildingAt(mx, my)
    if not rect then return false end

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

function LoveChunkCanvas:mousemoved(mx, my)
    if not self.dragging then return false end
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

function LoveChunkCanvas:mousereleased(_, _, button)
    if button ~= 1 or not self.dragging then return false end
    local d = self.dragging
    self.dragging = nil
    local state = self.ctx.state
    local tmpl = state.loadedTemplate
    if not tmpl or d.template ~= tmpl then return true end

    local loc = tmpl.Locations[d.identifier][d.index]
    local toX, toZ = loc[1], loc[2]
    if toX ~= d.fromX or toZ ~= d.fromZ then
        -- Revert the live preview so apply() is the only path that writes the new coord.
        loc[1], loc[2] = d.fromX, d.fromZ
        local cmd = MoveBuilding.new(d.identifier, d.index, d.fromX, d.fromZ, toX, toZ)
        state.history:apply(tmpl, cmd)
        state.saveStatus = nil
    end
    return true
end

return LoveChunkCanvas
