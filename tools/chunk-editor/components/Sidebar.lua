local SIDEBAR_ROW_H = 18

---@class LoveSidebar : LoveComponent
---@field ctx LoveAppContext
---@field rowYs table<integer, number>
local LoveSidebar = {}
LoveSidebar.__index = LoveSidebar

---@param ctx LoveAppContext
---@return LoveSidebar
function LoveSidebar.new(ctx)
    return setmetatable({
        ctx = ctx,
        rowYs = {},
    }, LoveSidebar)
end

function LoveSidebar:draw()
    local rect = self.ctx:layout().sidebar
    local state = self.ctx.state

    love.graphics.setColor(0.13, 0.13, 0.16)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
    love.graphics.setFont(state.fonts.body)

    self.rowYs = {}
    local y = rect.y + 4
    local prevFaction = nil
    local dirty = self.ctx:isDirty()
    local maxY = rect.y + rect.h
    for i, entry in ipairs(state.chunks) do
        if entry.faction ~= prevFaction then
            love.graphics.setColor(0.6, 0.7, 0.9)
            love.graphics.print(entry.faction, rect.x + 8, y)
            y = y + SIDEBAR_ROW_H
            prevFaction = entry.faction
        end
        self.rowYs[i] = y
        local selected = (entry.fsPath == state.currentPath)
        if selected then
            love.graphics.setColor(0.25, 0.45, 0.75)
            love.graphics.rectangle("fill", rect.x, y - 2, rect.w, SIDEBAR_ROW_H)
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0.85, 0.85, 0.85)
        end
        local label = entry.file
        if selected and dirty then
            label = "* " .. label
        end
        love.graphics.print(label, rect.x + 16, y)
        y = y + SIDEBAR_ROW_H
        if y > maxY then break end
    end
end

function LoveSidebar:mousepressed(mx, my, button)
    if button ~= 1 then return false end
    local rect = self.ctx:layout().sidebar
    if mx < rect.x or mx >= rect.x + rect.w then return false end
    if my < rect.y or my >= rect.y + rect.h then return false end

    for i, ry in pairs(self.rowYs) do
        if my >= ry - 2 and my < ry - 2 + SIDEBAR_ROW_H then
            self.ctx.actions.selectChunk(i)
            return true
        end
    end
    return false
end

return LoveSidebar
