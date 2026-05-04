local Util = require("util")

local SIDEBAR_ROW_H = 18
local IMPORT_BTN_SIZE = 14
local PILL_H = 16
local PILL_GAP = 4
local PILL_PAD_X = 6
local PILL_ROW_GAP = 4
local FILTER_PADDING = 6

---@class LoveSidebarPillRect
---@field x1 number
---@field y1 number
---@field x2 number
---@field y2 number
---@field kind string  # "faction" | "size"
---@field value any?   # nil = "All"; otherwise the string/integer to match

---@class LoveSidebar : LoveComponent
---@field ctx LoveAppContext
---@field rowYs table<integer, table>      # values are { y = number, fsPath = string }
---@field importRects table<integer, table>
---@field pillRects LoveSidebarPillRect[]
local LoveSidebar = {}
LoveSidebar.__index = LoveSidebar

---@param ctx LoveAppContext
---@return LoveSidebar
function LoveSidebar.new(ctx)
    return setmetatable({
        ctx = ctx,
        rowYs = {},
        importRects = {},
        pillRects = {},
    }, LoveSidebar)
end

local function uniqueFactions(entries)
    local seen, list = {}, {}
    for _, e in ipairs(entries) do
        if e.faction and not seen[e.faction] then
            seen[e.faction] = true
            table.insert(list, e.faction)
        end
    end
    table.sort(list)
    return list
end

local function uniqueSizes(entries)
    local seen, list = {}, {}
    for _, e in ipairs(entries) do
        if e.size and not seen[e.size] then
            seen[e.size] = true
            table.insert(list, e.size)
        end
    end
    table.sort(list)
    return list
end

--- Renders a row of single-select toggle pills. Returns the y-coord just
--- below the row.
---@param self LoveSidebar
---@param items { label: string, value: any }[]
---@param selectedValue any?
---@param kind string  # "faction" | "size"
---@param x number
---@param y number
---@param fontSmall any
---@return number nextY
local function drawPillRow(self, items, selectedValue, kind, x, y, fontSmall)
    love.graphics.setFont(fontSmall)
    local cx = x
    for _, item in ipairs(items) do
        local labelW = fontSmall:getWidth(item.label)
        local pillW = labelW + PILL_PAD_X * 2
        local active = (item.value == selectedValue)
        if active then
            love.graphics.setColor(0.30, 0.50, 0.80)
        else
            love.graphics.setColor(0.20, 0.20, 0.26)
        end
        love.graphics.rectangle("fill", cx, y, pillW, PILL_H)
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("line", cx, y, pillW, PILL_H)
        if active then
            love.graphics.setColor(1, 1, 1)
        else
            love.graphics.setColor(0.7, 0.7, 0.75)
        end
        love.graphics.printf(item.label, cx, y + 2, pillW, "center")
        table.insert(self.pillRects, {
            x1 = cx, y1 = y, x2 = cx + pillW, y2 = y + PILL_H,
            kind = kind, value = item.value,
        })
        cx = cx + pillW + PILL_GAP
    end
    return y + PILL_H + PILL_ROW_GAP
end

function LoveSidebar:draw()
    local rect = self.ctx:layout().sidebar
    local state = self.ctx.state

    love.graphics.setColor(0.13, 0.13, 0.16)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)

    self.rowYs = {}
    self.importRects = {}
    self.pillRects = {}

    local fontSmall = state.fonts.small
    local fontBody = state.fonts.body
    local filter = state.chunkFilter or { faction = nil, size = nil }
    local pillX = rect.x + FILTER_PADDING
    ---@type number
    local y = rect.y + FILTER_PADDING

    -- Faction pills
    local factionItems = { { label = "All", value = nil } }
    for _, f in ipairs(uniqueFactions(state.chunks)) do
        table.insert(factionItems, { label = f, value = f })
    end
    y = drawPillRow(self, factionItems, filter.faction, "faction", pillX, y, fontSmall)

    -- Size pills
    local sizeItems = { { label = "All", value = nil } }
    for _, s in ipairs(uniqueSizes(state.chunks)) do
        table.insert(sizeItems, { label = tostring(s), value = s })
    end
    y = drawPillRow(self, sizeItems, filter.size, "size", pillX, y, fontSmall)

    -- Divider between filter strip and chunk list
    love.graphics.setColor(0.30, 0.30, 0.36)
    love.graphics.line(rect.x + 8, y + 1, rect.x + rect.w - 8, y + 1)
    y = y + 6

    love.graphics.setFont(fontBody)
    local prevFaction = nil
    local dirty = self.ctx:isDirty()
    local maxY = rect.y + rect.h
    local canImport = state.loadedTemplate ~= nil

    local visible = self.ctx:filteredChunks()
    for i, entry in ipairs(visible) do
        if entry.faction ~= prevFaction then
            love.graphics.setColor(0.6, 0.7, 0.9)
            love.graphics.print(entry.faction, rect.x + 8, y)
            y = y + SIDEBAR_ROW_H
            prevFaction = entry.faction
        end
        self.rowYs[i] = { y = y, fsPath = entry.fsPath }
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
                fsPath = entry.fsPath,
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

    -- Filter pills first.
    for _, pill in ipairs(self.pillRects) do
        if Util.pointInRect(pill, mx, my) then
            local filter = self.ctx.state.chunkFilter
            filter[pill.kind] = pill.value
            return true
        end
    end

    -- Import buttons take priority over the row-load click.
    for _, btnRect in pairs(self.importRects) do
        if Util.pointInRect(btnRect, mx, my) then
            self.ctx.actions.importChunk(btnRect.fsPath)
            return true
        end
    end

    for _, row in pairs(self.rowYs) do
        if my >= row.y - 2 and my < row.y - 2 + SIDEBAR_ROW_H then
            self.ctx.actions.loadPath(row.fsPath)
            return true
        end
    end
    return false
end

return LoveSidebar
