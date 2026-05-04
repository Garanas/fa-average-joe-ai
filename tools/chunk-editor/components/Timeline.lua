local Util = require("util")

local CHIP_W = 200
local CHIP_GAP = 6
local ROW_GAP = 4

---@class LoveTimeline : LoveComponent
---@field ctx LoveAppContext
---@field chipRects table[]
---@field selectionChipRects table[]
---@field buttonRect table?
local LoveTimeline = {}
LoveTimeline.__index = LoveTimeline

---@param ctx LoveAppContext
---@return LoveTimeline
function LoveTimeline.new(ctx)
    return setmetatable({
        ctx = ctx,
        chipRects = {},
        selectionChipRects = {},
        buttonRect = nil,
    }, LoveTimeline)
end

local function selectionLabel(sel)
    local n = 0
    for _ in pairs(sel) do n = n + 1 end
    if n == 0 then return "(empty)" end
    if n == 1 then return "1 item" end
    return tostring(n) .. " items"
end

---@param rect LoveLayoutRect
---@param chipAreaW number
---@param rowY number
---@param rowH number
---@param items any[]            # entries to render
---@param cursor integer
---@param labelFn fun(item: any, index: integer): string
---@param pastColor number[]
---@param emptyMessage string
---@return table[]               # chip rects { x1, y1, x2, y2, index }
local function drawHistoryRow(rect, chipAreaW, rowY, rowH, items, cursor, labelFn, pastColor, emptyMessage, fonts)
    local rects = {}
    if #items == 0 then
        love.graphics.setColor(0.45, 0.45, 0.55)
        love.graphics.setFont(fonts.small)
        love.graphics.printf(emptyMessage, rect.x, rowY + math.floor(rowH / 2) - 6, chipAreaW, "center")
        return rects
    end

    local centerX = rect.x + math.floor(chipAreaW / 2)
    love.graphics.setFont(fonts.small)
    for i, item in ipairs(items) do
        local offset = i - cursor
        local cx = centerX + offset * (CHIP_W + CHIP_GAP)
        local x = math.floor(cx - CHIP_W / 2)
        if not (x + CHIP_W < rect.x or x > rect.x + chipAreaW) then
            if i <= cursor then
                love.graphics.setColor(pastColor[1], pastColor[2], pastColor[3])
            else
                love.graphics.setColor(0.30, 0.30, 0.34)
            end
            love.graphics.rectangle("fill", x, rowY, CHIP_W, rowH)

            if i == cursor then
                love.graphics.setColor(1.0, 0.85, 0.40)
                love.graphics.setLineWidth(2)
                love.graphics.rectangle("line", x, rowY, CHIP_W, rowH)
                love.graphics.setLineWidth(1)
            else
                love.graphics.setColor(0, 0, 0, 0.5)
                love.graphics.rectangle("line", x, rowY, CHIP_W, rowH)
            end

            love.graphics.setColor(0.95, 0.95, 0.95)
            love.graphics.printf(labelFn(item, i),
                x + 6, rowY + math.floor(rowH / 2) - 7, CHIP_W - 12, "center")

            table.insert(rects, {
                x1 = x, y1 = rowY, x2 = x + CHIP_W, y2 = rowY + rowH,
                index = i,
            })
        end
    end
    return rects
end

function LoveTimeline:draw()
    local rect = self.ctx:layout().timeline
    local state = self.ctx.state

    love.graphics.setColor(0.07, 0.07, 0.10)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)

    local btnW, btnPad = 90, 8
    local btnH = rect.h - 8
    local btnX = rect.x + rect.w - btnW - btnPad
    local btnY = rect.y + 4
    love.graphics.setColor(0.20, 0.20, 0.26)
    love.graphics.rectangle("fill", btnX, btnY, btnW, btnH)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", btnX, btnY, btnW, btnH)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.setFont(state.fonts.body)
    love.graphics.printf("Hotkeys", btnX, btnY + math.floor(btnH / 2) - 8, btnW, "center")
    self.buttonRect = { x1 = btnX, y1 = btnY, x2 = btnX + btnW, y2 = btnY + btnH }

    local chipAreaW = rect.w - btnW - btnPad * 2
    local rowH = math.floor((rect.h - 8 - ROW_GAP) / 2)
    local row1Y = rect.y + 4               -- top: selections
    local row2Y = row1Y + rowH + ROW_GAP   -- bottom: commands

    love.graphics.setScissor(rect.x, rect.y, chipAreaW, rect.h)

    local selH = state.selectionHistory
    self.selectionChipRects = drawHistoryRow(
        rect, chipAreaW, row1Y, rowH,
        selH and selH.states or {},
        selH and selH.cursor or 0,
        function(s) return selectionLabel(s) end,
        { 0.34, 0.20, 0.46 },  -- purple-ish so selection is visually distinct from commands
        "No selections",
        state.fonts)

    local cmdH = state.history
    self.chipRects = drawHistoryRow(
        rect, chipAreaW, row2Y, rowH,
        cmdH and cmdH.commands or {},
        cmdH and cmdH.cursor or 0,
        function(c) return (c.describe and c:describe()) or "(unnamed)" end,
        { 0.18, 0.30, 0.50 },
        "No commands",
        state.fonts)

    love.graphics.setScissor()
end

function LoveTimeline:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    if Util.pointInRect(self.buttonRect, mx, my) then
        local state = self.ctx.state
        state.dialogOpen = (state.dialogOpen == "hotkeys") and nil or "hotkeys"
        return true
    end

    for _, r in ipairs(self.selectionChipRects) do
        if Util.pointInRect(r, mx, my) then
            local state = self.ctx.state
            if state.selectionHistory then
                local s = state.selectionHistory:jumpTo(r.index)
                if s then state.selection = s end
            end
            return true
        end
    end

    for _, r in ipairs(self.chipRects) do
        if Util.pointInRect(r, mx, my) then
            local state = self.ctx.state
            if state.history and state.loadedTemplate then
                state.history:jumpTo(state.loadedTemplate, r.index)
                state.saveStatus = nil
            end
            return true
        end
    end
    return false
end

return LoveTimeline
