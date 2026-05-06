local Snapshot = require("commands.group_snapshot")

---@class LoveDeleteBuildingsCommand : LoveCommand
---@field count integer
---@field beforeSlots table<integer, LoveBaseChunkGroup|false>
---@field afterSlots table<integer, LoveBaseChunkGroup|false>
local LoveDeleteBuildingsCommand = {}
LoveDeleteBuildingsCommand.__index = LoveDeleteBuildingsCommand

---@param count integer
---@param beforeSlots table<integer, LoveBaseChunkGroup|false>
---@param afterSlots table<integer, LoveBaseChunkGroup|false>
---@return LoveDeleteBuildingsCommand
function LoveDeleteBuildingsCommand.new(count, beforeSlots, afterSlots)
    return setmetatable({
        count = count,
        beforeSlots = beforeSlots,
        afterSlots = afterSlots,
    }, LoveDeleteBuildingsCommand)
end

---@param template LoveBaseChunk
function LoveDeleteBuildingsCommand:apply(template)
    Snapshot.restoreSlots(template, self.afterSlots)
end

---@param template LoveBaseChunk
function LoveDeleteBuildingsCommand:undo(template)
    Snapshot.restoreSlots(template, self.beforeSlots)
end

---@return string
function LoveDeleteBuildingsCommand:describe()
    if self.count == 1 then return "Delete 1 building" end
    return string.format("Delete %d buildings", self.count)
end

return LoveDeleteBuildingsCommand
