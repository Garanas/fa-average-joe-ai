local Snapshot = require("commands.group_snapshot")

---@class LoveReconfigureChunkCommand : LoveCommand
---@field oldName string
---@field newName string
---@field oldFaction string
---@field newFaction string
---@field oldSize integer
---@field newSize integer
---@field beforeSlots table<integer, LoveBaseChunkGroup|false>
---@field afterSlots table<integer, LoveBaseChunkGroup|false>
---@field removedCount integer
local LoveReconfigureChunkCommand = {}
LoveReconfigureChunkCommand.__index = LoveReconfigureChunkCommand

---@param oldName string
---@param newName string
---@param oldFaction string
---@param newFaction string
---@param oldSize integer
---@param newSize integer
---@param beforeSlots table<integer, LoveBaseChunkGroup|false>
---@param afterSlots table<integer, LoveBaseChunkGroup|false>
---@param removedCount integer
---@return LoveReconfigureChunkCommand
function LoveReconfigureChunkCommand.new(oldName, newName, oldFaction, newFaction,
                                          oldSize, newSize, beforeSlots, afterSlots, removedCount)
    return setmetatable({
        oldName = oldName,
        newName = newName,
        oldFaction = oldFaction,
        newFaction = newFaction,
        oldSize = oldSize,
        newSize = newSize,
        beforeSlots = beforeSlots,
        afterSlots = afterSlots,
        removedCount = removedCount,
    }, LoveReconfigureChunkCommand)
end

---@param template LoveBaseChunk
function LoveReconfigureChunkCommand:apply(template)
    template.Name = self.newName
    template.Faction = self.newFaction
    template.Size = self.newSize
    Snapshot.restoreSlots(template, self.afterSlots)
end

---@param template LoveBaseChunk
function LoveReconfigureChunkCommand:undo(template)
    template.Name = self.oldName
    template.Faction = self.oldFaction
    template.Size = self.oldSize
    Snapshot.restoreSlots(template, self.beforeSlots)
end

---@return string
function LoveReconfigureChunkCommand:describe()
    if self.removedCount > 0 then
        return string.format("Reconfigure chunk (removed %d)", self.removedCount)
    end
    return "Reconfigure chunk"
end

return LoveReconfigureChunkCommand
