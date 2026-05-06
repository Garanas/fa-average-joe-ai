local Util = require("util")

local CARD_H = 32
local CARD_GAP = 2
local PADDING = 4
local BADGE_W = 24

---@class LoveGroupsPanel : LoveComponent
---@field ctx LoveAppContext
---@field cardRects table[]
local LoveGroupsPanel = {}
LoveGroupsPanel.__index = LoveGroupsPanel

---@param ctx LoveAppContext
---@return LoveGroupsPanel
function LoveGroupsPanel.new(ctx)
    return setmetatable({
        ctx = ctx,
        cardRects = {},
    }, LoveGroupsPanel)
end

local function slotKey(slot)
    return (slot == 10) and "0" or tostring(slot)
end

local function countItems(group)
    if not group or not group.Locations then return 0 end
    local n = 0
    for _, locs in pairs(group.Locations) do
        n = n + #locs
    end
    return n
end

function LoveGroupsPanel:draw()
    local rect = self.ctx:layout().groups
    local state = self.ctx.state

    love.graphics.setColor(0.10, 0.10, 0.13)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)

    self.cardRects = {}
    local tmpl = state.loadedTemplate
    local groups = (tmpl and tmpl.Groups) or {}

    local cardX = rect.x + PADDING
    local cardW = rect.w - 2 * PADDING
    local y = rect.y + PADDING

    for slot = 1, 10 do
        local group = groups[slot]
        local count = countItems(group)
        local empty = (count == 0)

        if empty then
            love.graphics.setColor(0.16, 0.16, 0.20)
        else
            love.graphics.setColor(0.22, 0.22, 0.28)
        end
        love.graphics.rectangle("fill", cardX, y, cardW, CARD_H)
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.rectangle("line", cardX, y, cardW, CARD_H)

        -- Slot badge
        love.graphics.setColor(0.30, 0.30, 0.42)
        love.graphics.rectangle("fill", cardX + 4, y + 4, BADGE_W, CARD_H - 8)
        love.graphics.setColor(0.95, 0.95, 0.95)
        love.graphics.setFont(state.fonts.body)
        love.graphics.printf(slotKey(slot), cardX + 4, y + 6, BADGE_W, "center")

        -- Name + count
        local labelX = cardX + 4 + BADGE_W + 6
        local labelW = cardX + cardW - labelX - 4
        local nameColor = empty and 0.45 or 0.95
        love.graphics.setFont(state.fonts.body)
        love.graphics.setColor(nameColor, nameColor, nameColor + 0.05)
        local name = group and group.Name or "(empty)"
        love.graphics.printf(name, labelX, y + 3, labelW, "left")

        local countColor = empty and 0.4 or 0.65
        love.graphics.setFont(state.fonts.small)
        love.graphics.setColor(countColor, countColor, countColor + 0.05)
        local countText = empty and "—" or (count == 1 and "1 item" or (count .. " items"))
        love.graphics.printf(countText, labelX, y + 18, labelW, "left")

        table.insert(self.cardRects, {
            x1 = cardX, y1 = y, x2 = cardX + cardW, y2 = y + CARD_H,
            slot = slot,
        })

        y = y + CARD_H + CARD_GAP
    end
end

function LoveGroupsPanel:mousepressed(mx, my, button)
    if button ~= 1 then return false end
    for _, r in ipairs(self.cardRects) do
        if Util.pointInRect(r, mx, my) then
            local ctrl = love.keyboard.isDown("lctrl") or love.keyboard.isDown("rctrl")
            if ctrl then
                self.ctx.actions.assignGroup(r.slot)
            else
                self.ctx.actions.selectGroup(r.slot)
            end
            return true
        end
    end
    return false
end

return LoveGroupsPanel
