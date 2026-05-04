---@class LoveMoveBuildingCommand : LoveCommand
---@field identifier LoveBuildingIdentifier
---@field index integer
---@field fromX integer
---@field fromZ integer
---@field toX integer
---@field toZ integer
local LoveMoveBuildingCommand = {}
LoveMoveBuildingCommand.__index = LoveMoveBuildingCommand

---@param identifier LoveBuildingIdentifier
---@param index integer
---@param fromX integer
---@param fromZ integer
---@param toX integer
---@param toZ integer
---@return LoveMoveBuildingCommand
function LoveMoveBuildingCommand.new(identifier, index, fromX, fromZ, toX, toZ)
    return setmetatable({
        identifier = identifier,
        index = index,
        fromX = fromX,
        fromZ = fromZ,
        toX = toX,
        toZ = toZ,
    }, LoveMoveBuildingCommand)
end

---@param template LoveBaseChunk
function LoveMoveBuildingCommand:apply(template)
    local loc = template.Locations[self.identifier][self.index]
    loc[1] = self.toX
    loc[2] = self.toZ
end

---@param template LoveBaseChunk
function LoveMoveBuildingCommand:undo(template)
    local loc = template.Locations[self.identifier][self.index]
    loc[1] = self.fromX
    loc[2] = self.fromZ
end

---@return string
function LoveMoveBuildingCommand:describe()
    return string.format("Move %s  (%d,%d) %s (%d,%d)",
        self.identifier, self.fromX, self.fromZ, "->", self.toX, self.toZ)
end

return LoveMoveBuildingCommand
