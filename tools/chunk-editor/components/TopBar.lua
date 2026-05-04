local Util = require("util")

local MENU_ITEM_H = 22
local MENU_W = 200

---@class LoveTopBar : LoveComponent
---@field ctx LoveAppContext
---@field menuOpen boolean
---@field fileButtonRect table?
---@field menuItemRect table?
local LoveTopBar = {}
LoveTopBar.__index = LoveTopBar

---@param ctx LoveAppContext
---@return LoveTopBar
function LoveTopBar.new(ctx)
    return setmetatable({
        ctx = ctx,
        menuOpen = false,
        fileButtonRect = nil,
        menuItemRect = nil,
    }, LoveTopBar)
end

function LoveTopBar:draw()
    local rect = self.ctx:layout().topbar
    local state = self.ctx.state

    love.graphics.setColor(0.10, 0.10, 0.14)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
    love.graphics.setFont(state.fonts.body)

    local fbX = rect.x + 4
    local fbW = 44
    if self.menuOpen then
        love.graphics.setColor(0.20, 0.20, 0.26)
        love.graphics.rectangle("fill", fbX, rect.y + 2, fbW, rect.h - 4)
    end
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("File", rect.x + 12, rect.y + 4)
    self.fileButtonRect = { x1 = fbX, y1 = rect.y, x2 = fbX + fbW, y2 = rect.y + rect.h }

    if self.menuOpen then
        local mx = rect.x + 4
        local my = rect.y + rect.h
        love.graphics.setColor(0.20, 0.20, 0.26)
        love.graphics.rectangle("fill", mx, my, MENU_W, MENU_ITEM_H)
        love.graphics.setColor(0.4, 0.4, 0.5)
        love.graphics.rectangle("line", mx, my, MENU_W, MENU_ITEM_H)
        love.graphics.setColor(1, 1, 1)
        love.graphics.print("Save", mx + 8, my + 4)
        love.graphics.setColor(0.6, 0.6, 0.7)
        love.graphics.printf("Ctrl+S", mx, my + 4, MENU_W - 8, "right")
        self.menuItemRect = { x1 = mx, y1 = my, x2 = mx + MENU_W, y2 = my + MENU_ITEM_H }
    else
        self.menuItemRect = nil
    end
end

function LoveTopBar:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    if self.menuOpen and Util.pointInRect(self.menuItemRect, mx, my) then
        self.ctx.actions.save()
        self.menuOpen = false
        return true
    end
    if Util.pointInRect(self.fileButtonRect, mx, my) then
        self.menuOpen = not self.menuOpen
        return true
    end
    if self.menuOpen then
        self.menuOpen = false
        -- Click went elsewhere: close menu but don't consume so peer
        -- components can still handle the click.
    end
    return false
end

function LoveTopBar:keypressed(key)
    if self.menuOpen and key == "escape" then
        self.menuOpen = false
        return true
    end
    return false
end

return LoveTopBar
