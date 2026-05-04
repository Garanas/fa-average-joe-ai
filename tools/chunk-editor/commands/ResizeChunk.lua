local Snapshot = require("commands.group_snapshot")

---@class LoveResizeChunkCommand : LoveCommand
---@field oldSize integer
---@field newSize integer
---@field beforeSlots table<integer, LoveBaseChunkGroup|false>
---@field afterSlots table<integer, LoveBaseChunkGroup|false>
---@field removedCount integer
local LoveResizeChunkCommand = {}
LoveResizeChunkCommand.__index = LoveResizeChunkCommand

---@param oldSize integer
---@param newSize integer
---@param beforeSlots table<integer, LoveBaseChunkGroup|false>
---@param afterSlots table<integer, LoveBaseChunkGroup|false>
---@param removedCount integer
---@return LoveResizeChunkCommand
function LoveResizeChunkCommand.new(oldSize, newSize, beforeSlots, afterSlots, removedCount)
    return setmetatable({
        oldSize = oldSize,
        newSize = newSize,
        beforeSlots = beforeSlots,
        afterSlots = afterSlots,
        removedCount = removedCount,
    }, LoveResizeChunkCommand)
end

---@param template LoveBaseChunk
function LoveResizeChunkCommand:apply(template)
    template.Size = self.newSize
    Snapshot.restoreSlots(template, self.afterSlots)
end

---@param template LoveBaseChunk
function LoveResizeChunkCommand:undo(template)
    template.Size = self.oldSize
    Snapshot.restoreSlots(template, self.beforeSlots)
end

---@return string
function LoveResizeChunkCommand:describe()
    local verb = self.newSize > self.oldSize and "Expand" or "Shrink"
    if self.removedCount > 0 then
        return string.format("%s to %dx%d (removed %d)",
            verb, self.newSize, self.newSize, self.removedCount)
    end
    return string.format("%s to %dx%d", verb, self.newSize, self.newSize)
end

return LoveResizeChunkCommand
