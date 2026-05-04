local Util = require("util")

---@class LoveTimeline : LoveComponent
---@field ctx LoveAppContext
---@field chipRects table[]
---@field buttonRect table?
local LoveTimeline = {}
LoveTimeline.__index = LoveTimeline

---@param ctx LoveAppContext
---@return LoveTimeline
function LoveTimeline.new(ctx)
    return setmetatable({
        ctx = ctx,
        chipRects = {},
        buttonRect = nil,
    }, LoveTimeline)
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

    self.chipRects = {}
    local hist = state.history
    if not hist or #hist.commands == 0 then
        love.graphics.setColor(0.45, 0.45, 0.55)
        love.graphics.setFont(state.fonts.small)
        love.graphics.printf("No commands", rect.x, rect.y + 16, chipAreaW, "center")
        return
    end

    local chipW, gap = 200, 6
    local centerX = rect.x + math.floor(chipAreaW / 2)
    local chipY = rect.y + 4
    local chipH = rect.h - 8

    love.graphics.setScissor(rect.x, rect.y, chipAreaW, rect.h)
    love.graphics.setFont(state.fonts.small)
    for i, cmd in ipairs(hist.commands) do
        local offset = i - hist.cursor
        local cx = centerX + offset * (chipW + gap)
        local x = math.floor(cx - chipW / 2)
        if not (x + chipW < rect.x or x > rect.x + chipAreaW) then
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

            table.insert(self.chipRects, {
                x1 = x, y1 = chipY, x2 = x + chipW, y2 = chipY + chipH,
                index = i,
            })
        end
    end
    love.graphics.setScissor()
end

function LoveTimeline:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    if Util.pointInRect(self.buttonRect, mx, my) then
        local state = self.ctx.state
        state.dialogOpen = (state.dialogOpen == "hotkeys") and nil or "hotkeys"
        return true
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
