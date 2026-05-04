local Util = require("util")

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

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local rowH = 24
    local headerH = 56
    local rowsH = math.max(1, #bindings) * rowH
    local dh = headerH + rowsH + 16
    local dw = 380
    local dx = math.floor((w - dw) / 2)
    local dy = math.floor((h - dh) / 2)

    love.graphics.setColor(0.16, 0.16, 0.20)
    love.graphics.rectangle("fill", dx, dy, dw, dh)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", dx, dy, dw, dh)

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

    local rowY = dy + headerH
    for _, b in ipairs(bindings) do
        love.graphics.setColor(0.7, 0.85, 1.0)
        love.graphics.print(b.keys, dx + 24, rowY)
        love.graphics.setColor(0.95, 0.95, 0.95)
        love.graphics.print(b.name, dx + 200, rowY)
        rowY = rowY + rowH
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
