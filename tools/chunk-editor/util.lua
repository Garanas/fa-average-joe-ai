local M = {}

---@param rect table?
---@param mx number
---@param my number
---@return boolean
function M.pointInRect(rect, mx, my)
    return rect ~= nil
        and mx >= rect.x1 and mx < rect.x2
        and my >= rect.y1 and my < rect.y2
end

--- Effective faction of a chunk entry. Prefers the loaded template's
--- `Faction` field; falls back to the parent folder name only if the
--- template hasn't loaded yet (or had a load error).
---@param entry LoveChunkEntry
---@return string
function M.entryFaction(entry)
    return entry.templateFaction or entry.faction or "Unknown"
end

---@param hex string?
---@return number r
---@return number g
---@return number b
function M.hexColor(hex)
    if not hex or #hex < 6 then return 0.5, 0.5, 0.5 end
    local r = (tonumber(hex:sub(1, 2), 16) or 128) / 255
    local g = (tonumber(hex:sub(3, 4), 16) or 128) / 255
    local b = (tonumber(hex:sub(5, 6), 16) or 128) / 255
    return r, g, b
end

return M
