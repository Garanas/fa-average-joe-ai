local Snapshot = require("commands.group_snapshot")

---@class LoveInsertBuildingsCommand : LoveCommand
---@field count integer
---@field beforeSlots table<integer, LoveBaseChunkGroup|false>
---@field afterSlots table<integer, LoveBaseChunkGroup|false>
local LoveInsertBuildingsCommand = {}
LoveInsertBuildingsCommand.__index = LoveInsertBuildingsCommand

---@param count integer
---@param beforeSlots table<integer, LoveBaseChunkGroup|false>
---@param afterSlots table<integer, LoveBaseChunkGroup|false>
---@return LoveInsertBuildingsCommand
function LoveInsertBuildingsCommand.new(count, beforeSlots, afterSlots)
    return setmetatable({
        count = count,
        beforeSlots = beforeSlots,
        afterSlots = afterSlots,
    }, LoveInsertBuildingsCommand)
end

---@param template LoveBaseChunk
function LoveInsertBuildingsCommand:apply(template)
    Snapshot.restoreSlots(template, self.afterSlots)
end

---@param template LoveBaseChunk
function LoveInsertBuildingsCommand:undo(template)
    Snapshot.restoreSlots(template, self.beforeSlots)
end

---@return string
function LoveInsertBuildingsCommand:describe()
    if self.count == 1 then return "Duplicate 1 building" end
    return string.format("Duplicate %d buildings", self.count)
end

return LoveInsertBuildingsCommand
