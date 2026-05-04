---@class LoveCompositeCommand : LoveCommand
---@field commands LoveCommand[]
local M = {}
M.__index = M

---@param commands LoveCommand[]
---@return LoveCompositeCommand
function M.new(commands)
    return setmetatable({ commands = commands }, M)
end

---@param template LoveBaseChunk
function M:apply(template)
    for _, c in ipairs(self.commands) do c:apply(template) end
end

---@param template LoveBaseChunk
function M:undo(template)
    for i = #self.commands, 1, -1 do
        self.commands[i]:undo(template)
    end
end

---@return string
function M:describe()
    local n = #self.commands
    if n == 0 then return "(empty)" end
    if n == 1 then
        return self.commands[1].describe and self.commands[1]:describe() or "(unnamed)"
    end
    return string.format("%d operations", n)
end

return M
