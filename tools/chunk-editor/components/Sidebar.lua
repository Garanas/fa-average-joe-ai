local Util = require("util")

local SIDEBAR_ROW_H = 18
local IMPORT_BTN_SIZE = 14

---@class LoveSidebar : LoveComponent
---@field ctx LoveAppContext
---@field rowYs table<integer, number>
---@field importRects table<integer, table>
local LoveSidebar = {}
LoveSidebar.__index = LoveSidebar

---@param ctx LoveAppContext
---@return LoveSidebar
function LoveSidebar.new(ctx)
    return setmetatable({
        ctx = ctx,
        rowYs = {},
        importRects = {},
    }, LoveSidebar)
end

function LoveSidebar:draw()
    local rect = self.ctx:layout().sidebar
    local state = self.ctx.state

    love.graphics.setColor(0.13, 0.13, 0.16)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
    love.graphics.setFont(state.fonts.body)

    self.rowYs = {}
    self.importRects = {}
    local y = rect.y + 4
    local prevFaction = nil
    local dirty = self.ctx:isDirty()
    local maxY = rect.y + rect.h
    local canImport = state.loadedTemplate ~= nil
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

        -- Quick-import button on the right edge of every row except the
        -- currently-loaded one (importing into yourself isn't useful).
        if canImport and not selected then
            local btnX = rect.x + rect.w - IMPORT_BTN_SIZE - 4
            local btnY = y + math.floor((SIDEBAR_ROW_H - IMPORT_BTN_SIZE) / 2) - 1
            love.graphics.setColor(0.30, 0.30, 0.42)
            love.graphics.rectangle("fill", btnX, btnY, IMPORT_BTN_SIZE, IMPORT_BTN_SIZE)
            love.graphics.setColor(0.4, 0.4, 0.5)
            love.graphics.rectangle("line", btnX, btnY, IMPORT_BTN_SIZE, IMPORT_BTN_SIZE)
            love.graphics.setColor(0.95, 0.95, 0.95)
            love.graphics.printf("+", btnX, btnY - 2, IMPORT_BTN_SIZE, "center")
            self.importRects[i] = {
                x1 = btnX, y1 = btnY,
                x2 = btnX + IMPORT_BTN_SIZE, y2 = btnY + IMPORT_BTN_SIZE,
            }
        end

        y = y + SIDEBAR_ROW_H
        if y > maxY then break end
    end
end

function LoveSidebar:mousepressed(mx, my, button)
    if button ~= 1 then return false end
    local rect = self.ctx:layout().sidebar
    if mx < rect.x or mx >= rect.x + rect.w then return false end
    if my < rect.y or my >= rect.y + rect.h then return false end

    -- Import buttons take priority over the row-load click.
    for i, btnRect in pairs(self.importRects) do
        if Util.pointInRect(btnRect, mx, my) then
            local entry = self.ctx.state.chunks[i]
            if entry then
                self.ctx.actions.importChunk(entry.fsPath)
            end
            return true
        end
    end

    for i, ry in pairs(self.rowYs) do
        if my >= ry - 2 and my < ry - 2 + SIDEBAR_ROW_H then
            self.ctx.actions.selectChunk(i)
            return true
        end
    end
    return false
end

return LoveSidebar
