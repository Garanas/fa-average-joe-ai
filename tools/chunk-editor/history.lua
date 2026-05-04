-- Undo/redo command history. Each command must implement `apply(template)` and
-- `undo(template)`; `describe()` is optional and used by the timeline bar.

---@class LoveHistory
---@field commands LoveCommand[]
---@field cursor integer        # index of last-applied command (0 = empty)
---@field savedCursor integer   # cursor at the most recent save
local LoveHistory = {}
LoveHistory.__index = LoveHistory

---@return LoveHistory
function LoveHistory.new()
    return setmetatable({
        commands = {},
        cursor = 0,
        savedCursor = 0,
    }, LoveHistory)
end

---@param template LoveBaseChunk
---@param command LoveCommand
function LoveHistory:apply(template, command)
    for i = #self.commands, self.cursor + 1, -1 do
        self.commands[i] = nil
    end
    command:apply(template)
    self.cursor = self.cursor + 1
    self.commands[self.cursor] = command
end

---@param template LoveBaseChunk
---@return boolean wasUndone
function LoveHistory:undo(template)
    if self.cursor == 0 then return false end
    self.commands[self.cursor]:undo(template)
    self.cursor = self.cursor - 1
    return true
end

---@param template LoveBaseChunk
---@return boolean wasRedone
function LoveHistory:redo(template)
    if self.cursor >= #self.commands then return false end
    self.cursor = self.cursor + 1
    self.commands[self.cursor]:apply(template)
    return true
end

---@param template LoveBaseChunk
---@param targetCursor integer
---@return boolean ok
function LoveHistory:jumpTo(template, targetCursor)
    if targetCursor < 0 or targetCursor > #self.commands then return false end
    while self.cursor < targetCursor do
        if not self:redo(template) then break end
    end
    while self.cursor > targetCursor do
        if not self:undo(template) then break end
    end
    return true
end

function LoveHistory:markSaved()
    self.savedCursor = self.cursor
end

---@return boolean
function LoveHistory:isDirty()
    return self.cursor ~= self.savedCursor
end

return LoveHistory
