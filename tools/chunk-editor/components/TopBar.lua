local Util = require("util")

local MENU_ITEM_H = 22
local MENU_SEPARATOR_H = 8
local MENU_W = 200

-- Build sites popup: a 3-column masonry of group blocks. Each block has a
-- header + its items; greedy column-packing keeps the columns roughly equal
-- in height.
local BS_COLUMNS = 3
local BS_ITEM_W = 180
local BS_ITEM_H = 18
local BS_HEADER_H = 24
local BS_GROUP_GAP = 6
local BS_PADDING = 6
local BS_SWATCH = 10

---@alias LoveMenuItem { label: string?, hint: string?, action: string?, separator: boolean? }

---@type LoveMenuItem[]
local FILE_MENU = {
    { label = "New",        hint = "Ctrl+N",       action = "new" },
    { label = "Load...",    hint = "Ctrl+O",       action = "load" },
    { label = "Import...",  hint = "Ctrl+I",       action = "importChunk" },
    { separator = true },
    { label = "Save",       hint = "Ctrl+S",       action = "save" },
    { label = "Save As...", hint = "Ctrl+Shift+S", action = "saveAs" },
    { separator = true },
    { label = "Expand",     action = "expandChunk" },
    { label = "Shrink",     action = "shrinkChunk" },
}

---@class LoveTopBar : LoveComponent
---@field ctx LoveAppContext
---@field menuOpen string?            # nil | "file" | "buildsites"
---@field fileButtonRect table?
---@field buildSitesButtonRect table?
---@field menuItemRects table[]       # active menu's clickable rects
local LoveTopBar = {}
LoveTopBar.__index = LoveTopBar

---@param ctx LoveAppContext
---@return LoveTopBar
function LoveTopBar.new(ctx)
    return setmetatable({
        ctx = ctx,
        menuOpen = nil,
        fileButtonRect = nil,
        buildSitesButtonRect = nil,
        menuItemRects = {},
    }, LoveTopBar)
end

local function hexColor(hex)
    return Util.hexColor(hex)
end

function LoveTopBar:_drawFileMenu(originX, originY)
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

--- Buckets identifiers by their `Group` field, sorts the items in each
--- bucket alphabetically, and returns both the buckets and the alphabetical
--- list of group names.
local function bucketByGroup(identifiers)
    local buckets = {}
    for id, meta in pairs(identifiers or {}) do
        local groupName = meta.Group or "Other"
        buckets[groupName] = buckets[groupName] or {}
        table.insert(buckets[groupName], id)
    end
    for _, list in pairs(buckets) do
        table.sort(list)
    end
    local names = {}
    for name in pairs(buckets) do table.insert(names, name) end
    table.sort(names)
    return buckets, names
end

--- Greedy bin-packing: assign each group to the currently-shortest column.
--- Stable for a given group ordering, so the layout doesn't jitter between
--- frames.
local function packIntoColumns(buckets, groupNames, numColumns)
    local columns = {}
    for i = 1, numColumns do columns[i] = { entries = {}, height = 0 } end
    for _, name in ipairs(groupNames) do
        local items = buckets[name]
        local h = BS_HEADER_H + #items * BS_ITEM_H + BS_GROUP_GAP
        local shortest = 1
        for i = 2, numColumns do
            if columns[i].height < columns[shortest].height then shortest = i end
        end
        table.insert(columns[shortest].entries, { name = name, items = items })
        columns[shortest].height = columns[shortest].height + h
    end
    return columns
end

function LoveTopBar:_drawBuildSitesMenu(originX, originY)
    local state = self.ctx.state
    local buckets, groupNames = bucketByGroup(state.identifiers)
    local columns = packIntoColumns(buckets, groupNames, BS_COLUMNS)

    local maxColH = 0
    for _, col in ipairs(columns) do
        if col.height > maxColH then maxColH = col.height end
    end
    local totalW = BS_COLUMNS * BS_ITEM_W
    local totalH = maxColH + BS_PADDING * 2

    love.graphics.setColor(0.20, 0.20, 0.26)
    love.graphics.rectangle("fill", originX, originY, totalW, totalH)
    love.graphics.setColor(0.4, 0.4, 0.5)
    love.graphics.rectangle("line", originX, originY, totalW, totalH)

    self.menuItemRects = {}
    for colIdx, col in ipairs(columns) do
        local colX = originX + (colIdx - 1) * BS_ITEM_W
        local y = originY + BS_PADDING
        for _, entry in ipairs(col.entries) do
            -- Header bar + group name (slightly larger font).
            love.graphics.setColor(0.30, 0.30, 0.40)
            love.graphics.rectangle("fill", colX + 4, y, BS_ITEM_W - 8, BS_HEADER_H)
            love.graphics.setColor(0.95, 0.95, 0.95)
            love.graphics.setFont(state.fonts.body)
            love.graphics.print(entry.name, colX + 8, y + 5)
            y = y + BS_HEADER_H

            love.graphics.setFont(state.fonts.small)
            for _, id in ipairs(entry.items) do
                local meta = state.identifiers[id] or {}
                local r, g, b = hexColor(meta.Color)
                local swatchY = y + math.floor((BS_ITEM_H - BS_SWATCH) / 2)
                love.graphics.setColor(r, g, b, 0.9)
                love.graphics.rectangle("fill", colX + 8, swatchY, BS_SWATCH, BS_SWATCH)
                love.graphics.setColor(0, 0, 0, 0.6)
                love.graphics.rectangle("line", colX + 8, swatchY, BS_SWATCH, BS_SWATCH)
                love.graphics.setColor(0.95, 0.95, 0.95)
                love.graphics.print(id, colX + 8 + BS_SWATCH + 6, y + 2)

                table.insert(self.menuItemRects, {
                    x1 = colX, y1 = y, x2 = colX + BS_ITEM_W, y2 = y + BS_ITEM_H,
                    identifier = id,
                })
                y = y + BS_ITEM_H
            end
            y = y + BS_GROUP_GAP
        end
    end
end

function LoveTopBar:draw()
    local rect = self.ctx:layout().topbar
    local state = self.ctx.state

    love.graphics.setColor(0.10, 0.10, 0.14)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
    love.graphics.setFont(state.fonts.body)

    -- File button
    local fbX = rect.x + 4
    local fbW = 44
    if self.menuOpen == "file" then
        love.graphics.setColor(0.20, 0.20, 0.26)
        love.graphics.rectangle("fill", fbX, rect.y + 2, fbW, rect.h - 4)
    end
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("File", rect.x + 12, rect.y + 4)
    self.fileButtonRect = { x1 = fbX, y1 = rect.y, x2 = fbX + fbW, y2 = rect.y + rect.h }

    -- Build sites button (next to File)
    local bsX = fbX + fbW + 4
    local bsW = 90
    if self.menuOpen == "buildsites" then
        love.graphics.setColor(0.20, 0.20, 0.26)
        love.graphics.rectangle("fill", bsX, rect.y + 2, bsW, rect.h - 4)
    end
    love.graphics.setColor(0.9, 0.9, 0.9)
    love.graphics.print("Build sites", bsX + 8, rect.y + 4)
    self.buildSitesButtonRect = { x1 = bsX, y1 = rect.y, x2 = bsX + bsW, y2 = rect.y + rect.h }

    if self.menuOpen == "file" then
        self:_drawFileMenu(fbX, rect.y + rect.h)
    elseif self.menuOpen == "buildsites" then
        self:_drawBuildSitesMenu(bsX, rect.y + rect.h)
    else
        self.menuItemRects = {}
    end
end

function LoveTopBar:mousepressed(mx, my, button)
    if button ~= 1 then return false end

    if self.menuOpen then
        for _, r in ipairs(self.menuItemRects) do
            if Util.pointInRect(r, mx, my) then
                if r.action then
                    local fn = self.ctx.actions[r.action]
                    if fn then fn() end
                    self.menuOpen = nil
                elseif r.identifier then
                    self.ctx.actions.addBuilding(r.identifier)
                    -- keep build-sites menu open: lets the user place several in a row
                end
                return true
            end
        end
    end

    if Util.pointInRect(self.fileButtonRect, mx, my) then
        self.menuOpen = (self.menuOpen == "file") and nil or "file"
        return true
    end
    if Util.pointInRect(self.buildSitesButtonRect, mx, my) then
        self.menuOpen = (self.menuOpen == "buildsites") and nil or "buildsites"
        return true
    end

    if self.menuOpen then
        self.menuOpen = nil
        -- Click went elsewhere: close menu but don't consume so peer
        -- components can still handle the click.
    end
    return false
end

function LoveTopBar:keypressed(key)
    if self.menuOpen and key == "escape" then
        self.menuOpen = nil
        return true
    end
    return false
end

return LoveTopBar
