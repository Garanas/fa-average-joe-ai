-- Browser-style back/forward history for selection states. Mirrors the
-- shape of `history.lua`, but stores values (selection sets) rather than
-- commands — Tab/Shift+Tab walk this stack just like Ctrl+Y/Ctrl+Z walk the
-- command history.

---@class LoveSelectionHistory
---@field states table<string, boolean>[]
---@field cursor integer
local M = {}
M.__index = M

local function copySelection(sel)
    local copy = {}
    for k, v in pairs(sel) do copy[k] = v end
    return copy
end

local function selectionsEqual(a, b)
    for k in pairs(a) do if not b[k] then return false end end
    for k in pairs(b) do if not a[k] then return false end end
    return true
end

---@return LoveSelectionHistory
function M.new()
    return setmetatable({
        states = { {} },
        cursor = 1,
    }, M)
end

---@param selection table<string, boolean>
function M:push(selection)
    for i = #self.states, self.cursor + 1, -1 do
        self.states[i] = nil
    end
    local current = self.states[self.cursor]
    if current and selectionsEqual(current, selection) then return end
    table.insert(self.states, copySelection(selection))
    self.cursor = #self.states
end

---@return table<string, boolean>?
function M:back()
    if self.cursor <= 1 then return nil end
    self.cursor = self.cursor - 1
    return copySelection(self.states[self.cursor])
end

---@return table<string, boolean>?
function M:forward()
    if self.cursor >= #self.states then return nil end
    self.cursor = self.cursor + 1
    return copySelection(self.states[self.cursor])
end

---@param targetCursor integer
---@return table<string, boolean>?
function M:jumpTo(targetCursor)
    if targetCursor < 1 or targetCursor > #self.states then return nil end
    self.cursor = targetCursor
    return copySelection(self.states[self.cursor])
end

return M
