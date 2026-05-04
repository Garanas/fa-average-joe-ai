-- Single-membership control-group assignment. Selected buildings move from
-- their current group(s) into the destination slot. Snapshots both the
-- before- and after-shapes of every affected slot so undo is exact.

local function deepCopyLocations(locs)
    local copy = {}
    for id, list in pairs(locs) do
        local listCopy = {}
        for k = 1, #list do
            local loc = list[k]
            listCopy[k] = { loc[1], loc[2], loc[3] }
        end
        copy[id] = listCopy
    end
    return copy
end

local function deepCopyGroup(group)
    if not group then return nil end
    return {
        Name = group.Name,
        Locations = deepCopyLocations(group.Locations or {}),
    }
end

---@class LoveAssignGroupCommand : LoveCommand
---@field destSlot integer
---@field beforeSlots table<integer, LoveBaseChunkGroup|false>  # snapshot per affected slot; false = "didn't exist"
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

local function restoreSlots(template, snapshot)
    template.Groups = template.Groups or {}
    for slot, snap in pairs(snapshot) do
        if snap == false then
            template.Groups[slot] = nil
        else
            template.Groups[slot] = deepCopyGroup(snap)
        end
    end
end

---@param template LoveBaseChunk
function LoveAssignGroupCommand:apply(template)
    restoreSlots(template, self.afterSlots)
end

---@param template LoveBaseChunk
function LoveAssignGroupCommand:undo(template)
    restoreSlots(template, self.beforeSlots)
end

---@return string
function LoveAssignGroupCommand:describe()
    return string.format("Assign to group %d", self.destSlot)
end

return LoveAssignGroupCommand
