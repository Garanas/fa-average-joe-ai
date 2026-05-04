local Util = require("util")

local FACTIONS = { "UEF", "Aeon", "Cybran", "Seraphim" }
local SIZES = { 4, 8, 16, 32, 64, 128 }

local DW = 440
local PAD = 20
local ROW_GAP = 14
local LABEL_W = 70
local NAME_H = 26
local PILL_H = 24
local FACTION_W = 80
local SIZE_W = 50
local PILL_GAP = 6
local FOOTER_H = 40
local CLOSE_SZ = 22
local HEADER_H = 56

---@class LoveNewChunkDialog : LoveComponent
---@field ctx LoveAppContext
---@field name string
---@field faction string
---@field size integer
---@field dialogRect table?
---@field closeRect table?
---@field nameRect table?
---@field factionRects table[]
---@field sizeRects table[]
---@field cancelRect table?
---@field createRect table?
local LoveNewChunkDialog = {}
LoveNewChunkDialog.__index = LoveNewChunkDialog

---@param ctx LoveAppContext
---@return LoveNewChunkDialog
function LoveNewChunkDialog.new(ctx)
    return setmetatable({
        ctx = ctx,
        name = "Untitled",
        faction = "UEF",
        size = 16,
        dialogRect = nil,
        closeRect = nil,
        nameRect = nil,
        factionRects = {},
        sizeRects = {},
        cancelRect = nil,
        createRect = nil,
    }, LoveNewChunkDialog)
end

--- Reset to defaults so reopening the dialog after a cancel/create starts clean.
function LoveNewChunkDialog:reset()
    self.name = "Untitled"
    self.faction = "UEF"
    self.size = 16
end

local function isOpen(self)
    return self.ctx.state.dialogOpen == "newchunk"
end

local function clearRects(self)
    self.dialogRect = nil
    self.closeRect = nil
    self.nameRect = nil
    self.factionRects = {}
    self.sizeRects = {}
    self.cancelRect = nil
    self.createRect = nil
end

local function drawPill(x, y, w, h, label, selected, font)
    if selected then
        love.graphics.setColor(0.30, 0.50, 0.78)
    else
        love.graphics.setColor(0.22, 0.22, 0.28)
    end
    love.graphics.rectangle("fill", x, y, w, h)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", x, y, w, h)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.setFont(font)
    love.graphics.printf(label, x, y + math.floor((h - font:getHeight()) / 2), w, "center")
end

function LoveNewChunkDialog:draw()
    if not isOpen(self) then
        clearRects(self)
        return
    end

    local viewport = self.ctx:layout().viewport
    local w, h = viewport.w, viewport.h
    local state = self.ctx.state

    love.graphics.setColor(0, 0, 0, 0.55)
    love.graphics.rectangle("fill", 0, 0, w, h)

    local body = HEADER_H
        + NAME_H + ROW_GAP
        + PILL_H + ROW_GAP   -- faction row (label + buttons share the row)
        + PILL_H + ROW_GAP   -- size row
        + FOOTER_H
    local dh = body + 16
    local dx = math.floor((w - DW) / 2)
    local dy = math.floor((h - dh) / 2)

    love.graphics.setColor(0.16, 0.16, 0.20)
    love.graphics.rectangle("fill", dx, dy, DW, dh)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", dx, dy, DW, dh)

    -- Header: title + close button
    love.graphics.setFont(state.fonts.title)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.print("New Chunk", dx + 16, dy + 14)

    local closeX = dx + DW - CLOSE_SZ - 6
    local closeY = dy + 8
    love.graphics.setColor(0.30, 0.30, 0.36)
    love.graphics.rectangle("fill", closeX, closeY, CLOSE_SZ, CLOSE_SZ)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", closeX, closeY, CLOSE_SZ, CLOSE_SZ)
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.setFont(state.fonts.body)
    love.graphics.printf("X", closeX, closeY + 4, CLOSE_SZ, "center")

    love.graphics.setColor(0.30, 0.30, 0.36)
    love.graphics.line(dx + 16, dy + HEADER_H - 10, dx + DW - 16, dy + HEADER_H - 10)

    local rowY = dy + HEADER_H

    -- Name row
    love.graphics.setFont(state.fonts.body)
    love.graphics.setColor(0.85, 0.85, 0.90)
    love.graphics.print("Name:", dx + PAD, rowY + math.floor((NAME_H - state.fonts.body:getHeight()) / 2))

    local nameX = dx + PAD + LABEL_W
    local nameW = DW - PAD * 2 - LABEL_W
    love.graphics.setColor(0.10, 0.10, 0.14)
    love.graphics.rectangle("fill", nameX, rowY, nameW, NAME_H)
    love.graphics.setColor(0.4, 0.4, 0.6)
    love.graphics.rectangle("line", nameX, rowY, nameW, NAME_H)

    love.graphics.setColor(0.95, 0.95, 0.95)
    local cursor = (math.floor(love.timer.getTime() * 2) % 2 == 0) and "|" or " "
    love.graphics.print(self.name .. cursor, nameX + 6, rowY + math.floor((NAME_H - state.fonts.body:getHeight()) / 2))
    self.nameRect = { x1 = nameX, y1 = rowY, x2 = nameX + nameW, y2 = rowY + NAME_H }

    rowY = rowY + NAME_H + ROW_GAP

    -- Faction row
    love.graphics.setColor(0.85, 0.85, 0.90)
    love.graphics.print("Faction:", dx + PAD, rowY + math.floor((PILL_H - state.fonts.body:getHeight()) / 2))

    self.factionRects = {}
    local fx = dx + PAD + LABEL_W
    for _, fac in ipairs(FACTIONS) do
        drawPill(fx, rowY, FACTION_W, PILL_H, fac, self.faction == fac, state.fonts.body)
        table.insert(self.factionRects, {
            x1 = fx, y1 = rowY, x2 = fx + FACTION_W, y2 = rowY + PILL_H,
            faction = fac,
        })
        fx = fx + FACTION_W + PILL_GAP
    end

    rowY = rowY + PILL_H + ROW_GAP

    -- Size row
    love.graphics.setColor(0.85, 0.85, 0.90)
    love.graphics.print("Size:", dx + PAD, rowY + math.floor((PILL_H - state.fonts.body:getHeight()) / 2))

    self.sizeRects = {}
    local sx = dx + PAD + LABEL_W
    for _, sz in ipairs(SIZES) do
        drawPill(sx, rowY, SIZE_W, PILL_H, tostring(sz), self.size == sz, state.fonts.body)
        table.insert(self.sizeRects, {
            x1 = sx, y1 = rowY, x2 = sx + SIZE_W, y2 = rowY + PILL_H,
            size = sz,
        })
        sx = sx + SIZE_W + PILL_GAP
    end

    rowY = rowY + PILL_H + ROW_GAP

    -- Footer: Cancel + Create
    local btnW, btnH = 90, 26
    local createX = dx + DW - PAD - btnW
    local cancelX = createX - btnW - 8
    local btnY = rowY + math.floor((FOOTER_H - btnH) / 2)

    drawPill(cancelX, btnY, btnW, btnH, "Cancel", false, state.fonts.body)
    self.cancelRect = { x1 = cancelX, y1 = btnY, x2 = cancelX + btnW, y2 = btnY + btnH }

    -- Create has a stronger highlight when name is non-empty.
    local canCreate = self.name and self.name ~= ""
    if canCreate then
        love.graphics.setColor(0.22, 0.55, 0.32)
    else
        love.graphics.setColor(0.18, 0.30, 0.20)
    end
    love.graphics.rectangle("fill", createX, btnY, btnW, btnH)
    love.graphics.setColor(0.4, 0.5, 0.4)
    love.graphics.rectangle("line", createX, btnY, btnW, btnH)
    love.graphics.setColor(0.95, 0.95, 0.95)
    love.graphics.printf("Create", createX, btnY + math.floor((btnH - state.fonts.body:getHeight()) / 2), btnW, "center")
    self.createRect = { x1 = createX, y1 = btnY, x2 = createX + btnW, y2 = btnY + btnH }

    self.dialogRect = { x1 = dx, y1 = dy, x2 = dx + DW, y2 = dy + dh }
    self.closeRect = { x1 = closeX, y1 = closeY, x2 = closeX + CLOSE_SZ, y2 = closeY + CLOSE_SZ }
end

function LoveNewChunkDialog:_submit()
    if not self.name or self.name == "" then return end
    local payload = { name = self.name, faction = self.faction, size = self.size }
    self.ctx.state.dialogOpen = nil
    if self.ctx.actions.createNewChunk then
        self.ctx.actions.createNewChunk(payload)
    end
    self:reset()
end

function LoveNewChunkDialog:_cancel()
    self.ctx.state.dialogOpen = nil
    self:reset()
end

function LoveNewChunkDialog:mousepressed(mx, my, button)
    if not isOpen(self) then return false end
    if button ~= 1 then return true end

    if Util.pointInRect(self.closeRect, mx, my) then
        self:_cancel()
        return true
    end
    if Util.pointInRect(self.cancelRect, mx, my) then
        self:_cancel()
        return true
    end
    if Util.pointInRect(self.createRect, mx, my) then
        self:_submit()
        return true
    end
    for _, r in ipairs(self.factionRects) do
        if Util.pointInRect(r, mx, my) then
            self.faction = r.faction
            return true
        end
    end
    for _, r in ipairs(self.sizeRects) do
        if Util.pointInRect(r, mx, my) then
            self.size = r.size
            return true
        end
    end
    if not Util.pointInRect(self.dialogRect, mx, my) then
        self:_cancel()
    end
    return true
end

function LoveNewChunkDialog:keypressed(key)
    if not isOpen(self) then return false end
    if key == "escape" then
        self:_cancel()
        return true
    end
    if key == "return" or key == "kpenter" then
        self:_submit()
        return true
    end
    if key == "backspace" then
        if self.name and #self.name > 0 then
            -- Drop one UTF-8 codepoint (good enough; names are ASCII in practice).
            local b = self.name:byte(#self.name) or 0
            local n = 1
            if b >= 0x80 and b < 0xC0 then
                while n < #self.name do
                    local prev = self.name:byte(#self.name - n) or 0
                    n = n + 1
                    if prev >= 0xC0 then break end
                end
            end
            self.name = self.name:sub(1, #self.name - n)
        end
        return true
    end
    return true
end

function LoveNewChunkDialog:textinput(text)
    if not isOpen(self) then return false end
    self.name = (self.name or "") .. text
    return true
end

return LoveNewChunkDialog
