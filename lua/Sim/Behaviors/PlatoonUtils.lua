local ConstructionCategories = (categories.MOBILE * categories.LAND) + (categories.COMMAND + categories.CONSTRUCTION + categories.ENGINEER)
local ScoutCategories = (categories.LAND + categories.MOBILE) * categories.SCOUT

--- A list of all known platoon behaviors.
PlatoonBehaviors = {
    -- debug behavior
    NullBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Debug/NullBehavior.lua").NullBehavior,
    WanderBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Debug/WanderBehavior.lua").WanderBehavior,

    -- engineer behavior
    EngineerReclaimBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Engineers/EngineerReclaimBehavior.lua").EngineerReclaimBehavior,
}

--- Creates an empty platoon with the specified behavior.
---@param brain JoeBrain
---@param behavior AIPlatoonBehavior
---@return AIPlatoonBehavior
CreatePlatoonWithBehavior = function(brain, behavior)
    local platoon = brain:MakePlatoon("", "") --[[@as AIPlatoonBehavior]]
    setmetatable(platoon, behavior)

    -- initialize state of the behavior
    platoon:OnCreate()
    return platoon
end

--- Assigns units to the attack squad.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units Unit[]
AssignAttackUnits = function(brain, platoon, units)
    brain:AssignUnitsToPlatoon(platoon, units, "Attack", 'None')
end

--- Assigns units to the support squad.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units Unit[]
AssignSupportUnits = function(brain, platoon, units)
    brain:AssignUnitsToPlatoon(platoon, units, "Support", 'None')
end

--- Assigns units to the artillery squad.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units Unit[]
AssignArtilleryUnits = function(brain, platoon, units)
    brain:AssignUnitsToPlatoon(platoon, units, "Artillery", 'None')
end

--- Assigns units to the guard squad.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units Unit[]
AssignGuardUnits = function(brain, platoon, units)
    brain:AssignUnitsToPlatoon(platoon, units, "Guard", 'None')
end

--- Assigns units to the scout squad.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units Unit[]
AssignScoutUnits = function(brain, platoon, units)
    brain:AssignUnitsToPlatoon(platoon, units, "Scout", 'None')
end

--- Assigns units to their respective squads.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units Unit[]
AssignUnits = function(brain, platoon, units)
    -- TODO: do proper filtering :))
    AssignSupportUnits(brain, platoon, units)
    AssignArtilleryUnits(brain, platoon, {})
    AssignGuardUnits(brain, platoon, {})
    AssignScoutUnits(brain, platoon, {})
    AssignAttackUnits(brain, platoon, {})
end

--- Creates a platoon and populates it with the specified units. The units are automatically assigned to their respective squads.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units Unit[]
CreatePlatoon = function(brain, platoon, units)
    local platoon = CreatePlatoonWithBehavior(brain, platoon)
    AssignUnits(brain, platoon, units)
    return platoon
end

--- Starts the behavior of a platoon.
---@param platoon AIPlatoonBehavior
StartPlatoon = function(platoon)
    platoon:ChangeState(platoon.Start)
end
