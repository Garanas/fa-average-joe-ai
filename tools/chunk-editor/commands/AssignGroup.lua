local Snapshot = require("commands.group_snapshot")

---@class LoveAssignGroupCommand : LoveCommand
---@field destSlot integer
---@field beforeSlots table<integer, LoveBaseChunkGroup|false>
---@field afterSlots table<integer, LoveBaseChunkGroup|false>
local LoveAssignGroupCommand = {}
LoveAssignGroupCommand.__index = LoveAssignGroupCommand

---@param destSlot integer
---@param beforeSlots table<integer, LoveBaseChunkGroup|false>
---@param afterSlots table<integer, LoveBaseChunkGroup|false>
---@return LoveAssignGroupCommand
function LoveAssignGroupCommand.new(destSlot, beforeSlots, afterSlots)
    return setmetatable({
        destSlot = destSlot,
        beforeSlots = beforeSlots,
        afterSlots = afterSlots,
    }, LoveAssignGroupCommand)
end

---@param template LoveBaseChunk
function LoveAssignGroupCommand:apply(template)
    Snapshot.restoreSlots(template, self.afterSlots)
end

---@param template LoveBaseChunk
function LoveAssignGroupCommand:undo(template)
    Snapshot.restoreSlots(template, self.beforeSlots)
end

---@return string
function LoveAssignGroupCommand:describe()
    return string.format("Assign to group %d", self.destSlot)
end

return LoveAssignGroupCommand
