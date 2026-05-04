local Util = require("util")

local MENU_ITEM_H = 22
local MENU_SEPARATOR_H = 8
local MENU_W = 200

---@alias LoveMenuItem { label: string?, hint: string?, action: string?, separator: boolean? }

---@type LoveMenuItem[]
local FILE_MENU = {
    { label = "New",        hint = "Ctrl+N",       action = "new" },
    { label = "Load...",    hint = "Ctrl+O",       action = "load" },
    { separator = true },
    { label = "Save",       hint = "Ctrl+S",       action = "save" },
    { label = "Save As...", hint = "Ctrl+Shift+S", action = "saveAs" },
}

---@class LoveTopBar : LoveComponent
---@field ctx LoveAppContext
---@field menuOpen boolean
---@field fileButtonRect table?
---@field menuItemRects table[]
local LoveTopBar = {}
LoveTopBar.__index = LoveTopBar

---@param ctx LoveAppContext
---@return LoveTopBar
function LoveTopBar.new(ctx)
    return setmetatable({
        ctx = ctx,
        menuOpen = false,
        fileButtonRect = nil,
        menuItemRects = {},
    }, LoveTopBar)
end

function LoveTopBar:_drawMenu(originX, originY)
    local total = 0
    for _, item in ipairs(FILE_MENU) do
        total = total + (item.separator and MENU_SEPARATOR_H or MENU_ITEM_H)
    end
    love.graphics.setColor(0.20, 0.20, 0.26)
    love.graphics.rectangle("fill", originX, originY, MENU_W, total)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", originX, originY, MENU_W, total)

    self.menuItemRects = {}
    local y = originY
    for _, item in ipairs(FILE_MENU) do
        if item.separator then
            love.graphics.setColor(0.30, 0.30, 0.36)
            love.graphics.line(originX + 8, y + math.floor(MENU_SEPARATOR_H / 2),
                originX + MENU_W - 8, y + math.floor(MENU_SEPARATOR_H / 2))
            y = y + MENU_SEPARATOR_H
        else
            love.graphics.setColor(1, 1, 1)
            love.graphics.print(item.label, originX + 8, y + 4)
            if item.hint then
                love.graphics.setColor(0.6, 0.6, 0.7)
                love.graphics.printf(item.hint, originX, y + 4, MENU_W - 8, "right")
            end
            table.insert(self.menuItemRects, {
                x1 = originX, y1 = y, x2 = originX + MENU_W, y2 = y + MENU_ITEM_H,
                action = item.action,
            })
            y = y + MENU_ITEM_H
        end
    end
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
        self:_drawMenu(rect.x + 4, rect.y + rect.h)
    else
        self.menuItemRects = {}
    end
end

function LoveTopBar:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    if self.menuOpen then
        for _, r in ipairs(self.menuItemRects) do
            if Util.pointInRect(r, mx, my) then
                local fn = self.ctx.actions[r.action]
                if fn then fn() end
                self.menuOpen = false
                return true
            end
        end
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
