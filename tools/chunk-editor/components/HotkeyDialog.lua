local Util = require("util")

-- Masonry layout: same approach as the Build Sites popup. Each group is a
-- block with a header and its items; greedy bin-packing puts each group into
-- the currently-shortest column so column heights stay roughly equal.
local HK_COLUMNS = 3
local HK_ITEM_W = 240
local HK_ITEM_H = 18
local HK_HEADER_H = 24
local HK_GROUP_GAP = 8
local HK_PADDING = 12
local HK_KEY_OFFSET = 8     -- x-offset within the column where the key text starts
local HK_NAME_OFFSET = 110  -- x-offset where the name text starts

---@class LoveHotkeyDialog : LoveComponent
---@field ctx LoveAppContext
---@field dialogRect table?
---@field closeRect table?
local LoveHotkeyDialog = {}
LoveHotkeyDialog.__index = LoveHotkeyDialog

---@param ctx LoveAppContext
---@return LoveHotkeyDialog
function LoveHotkeyDialog.new(ctx)
    return setmetatable({
        ctx = ctx,
        dialogRect = nil,
        closeRect = nil,
    }, LoveHotkeyDialog)
end

--- Bucket bindings by their `group` field, preserving the order each group
--- and binding was first declared. We don't sort because the curated order
--- in `hotkeys.lua` carries meaning (Save before Save As, Undo before Redo).
---@param bindings LoveHotkeyBinding[]
---@return table<string, LoveHotkeyBinding[]>, string[]
local function bucketByGroup(bindings)
    local buckets = {}
    local groupOrder = {}
    for _, b in ipairs(bindings) do
        local g = b.group or "Other"
        if not buckets[g] then
            buckets[g] = {}
            table.insert(groupOrder, g)
        end
        table.insert(buckets[g], b)
    end
    return buckets, groupOrder
end

--- Greedy bin-packing: assign each group to the currently-shortest column.
---@param buckets table<string, LoveHotkeyBinding[]>
---@param groupOrder string[]
---@param numColumns integer
---@return { entries: { name: string, items: LoveHotkeyBinding[] }[], height: integer }[]
local function packIntoColumns(buckets, groupOrder, numColumns)
    local columns = {}
    for i = 1, numColumns do columns[i] = { entries = {}, height = 0 } end
    for _, name in ipairs(groupOrder) do
        local items = buckets[name]
        local h = HK_HEADER_H + #items * HK_ITEM_H + HK_GROUP_GAP
        local shortest = 1
        for i = 2, numColumns do
            if columns[i].height < columns[shortest].height then shortest = i end
        end
        table.insert(columns[shortest].entries, { name = name, items = items })
        columns[shortest].height = columns[shortest].height + h
    end
    return columns
end

function LoveHotkeyDialog:draw()
    if self.ctx.state.dialogOpen ~= "hotkeys" then
        self.dialogRect = nil
        self.closeRect = nil
        return
    end

    local viewport = self.ctx:layout().viewport
    local w, h = viewport.w, viewport.h
    local state = self.ctx.state
    local bindings = self.ctx.bindings

    local buckets, groupOrder = bucketByGroup(bindings)
    local columns = packIntoColumns(buckets, groupOrder, HK_COLUMNS)

    local maxColH = 0
    for _, col in ipairs(columns) do
        if col.height > maxColH then maxColH = col.height end
    end

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local headerH = 56
    local contentW = HK_COLUMNS * HK_ITEM_W
    local dw = contentW + HK_PADDING * 2
    local dh = headerH + maxColH + HK_PADDING * 2
    local dx = math.floor((w - dw) / 2)
    local dy = math.floor((h - dh) / 2)

    love.graphics.setColor(0.16, 0.16, 0.20)
    love.graphics.rectangle("fill", dx, dy, dw, dh)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", dx, dy, dw, dh)

    -- Header: title + close button
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

    -- Columns
    local contentX = dx + HK_PADDING
    local contentY = dy + headerH
    for colIdx, col in ipairs(columns) do
        local colX = contentX + (colIdx - 1) * HK_ITEM_W
        local y = contentY
        for _, entry in ipairs(col.entries) do
            -- Group header bar.
            love.graphics.setColor(0.30, 0.30, 0.40)
            love.graphics.rectangle("fill", colX + 4, y, HK_ITEM_W - 8, HK_HEADER_H)
            love.graphics.setColor(0.95, 0.95, 0.95)
            love.graphics.setFont(state.fonts.body)
            love.graphics.print(entry.name, colX + 8, y + 5)
            y = y + HK_HEADER_H

            love.graphics.setFont(state.fonts.small)
            for _, b in ipairs(entry.items) do
                love.graphics.setColor(0.7, 0.85, 1.0)
                love.graphics.print(b.keys, colX + HK_KEY_OFFSET, y + 3)
                love.graphics.setColor(0.95, 0.95, 0.95)
                love.graphics.print(b.name, colX + HK_NAME_OFFSET, y + 3)
                y = y + HK_ITEM_H
            end
            y = y + HK_GROUP_GAP
        end
    end

    self.dialogRect = { x1 = dx, y1 = dy, x2 = dx + dw, y2 = dy + dh }
    self.closeRect = { x1 = closeX, y1 = closeY, x2 = closeX + closeSz, y2 = closeY + closeSz }
end

function LoveHotkeyDialog:mousepressed(mx, my, button)
    if self.ctx.state.dialogOpen ~= "hotkeys" then return false end
    if button ~= 1 then return true end
    if Util.pointInRect(self.closeRect, mx, my) then
        self.ctx.state.dialogOpen = nil
    elseif not Util.pointInRect(self.dialogRect, mx, my) then
        self.ctx.state.dialogOpen = nil
    end
    return true
end

function LoveHotkeyDialog:keypressed(key)
    if self.ctx.state.dialogOpen ~= "hotkeys" then return false end
    if key == "escape" then self.ctx.state.dialogOpen = nil end
    return true
end

return LoveHotkeyDialog
