local Snapshot = require("commands.group_snapshot")

---@class LoveImportGroupCommand : LoveCommand
---@field slot integer
---@field sourceLabel string
---@field beforeSlots table<integer, LoveBaseChunkGroup|false>
---@field afterSlots table<integer, LoveBaseChunkGroup|false>
local LoveImportGroupCommand = {}
LoveImportGroupCommand.__index = LoveImportGroupCommand

---@param slot integer
---@param sourceLabel string
---@param beforeSlots table<integer, LoveBaseChunkGroup|false>
---@param afterSlots table<integer, LoveBaseChunkGroup|false>
---@return LoveImportGroupCommand
function LoveImportGroupCommand.new(slot, sourceLabel, beforeSlots, afterSlots)
    return setmetatable({
        slot = slot,
        sourceLabel = sourceLabel,
        beforeSlots = beforeSlots,
        afterSlots = afterSlots,
    }, LoveImportGroupCommand)
end

---@param template LoveBaseChunk
function LoveImportGroupCommand:apply(template)
    Snapshot.restoreSlots(template, self.afterSlots)
end

---@param template LoveBaseChunk
function LoveImportGroupCommand:undo(template)
    Snapshot.restoreSlots(template, self.beforeSlots)
end

---@return string
function LoveImportGroupCommand:describe()
    return string.format("Import '%s' to group %d", self.sourceLabel, self.slot)
end

return LoveImportGroupCommand
