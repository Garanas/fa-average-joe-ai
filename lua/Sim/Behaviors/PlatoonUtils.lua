local ArrayContains = import("/mods/fa-joe-ai/lua/Shared/TableUtils.lua").ArrayContains

local ConstructionCategories = (categories.MOBILE * categories.LAND) + (categories.COMMAND + categories.CONSTRUCTION + categories.ENGINEER)
local ScoutCategories = (categories.LAND + categories.MOBILE) * categories.SCOUT

--- A list of all known platoon behaviors.
PlatoonBehaviors = {
    -- debug behavior
    ErrorBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Debug/ErrorBehavior.lua").ErrorBehavior,
    NullBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Debug/NullBehavior.lua").NullBehavior,
    WanderBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Debug/WanderBehavior.lua").WanderBehavior,
    PingPongBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Debug/PingPongBehavior.lua").PingPongBehavior,

    -- engineer behavior
    ReclaimBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Engineers/ReclaimBehavior.lua").ReclaimBehavior,
    BuildBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Engineers/BuildBehavior.lua").BuildBehavior,

    -- base behavior
    Base = {
        IdleBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Base/IdleBehavior.lua").BaseIdleBehavior
    }
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

--- Assigns units to the specified squad. Updates the platoon reference of units.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units JoeUnit[]
---@param squad PlatoonSquads
AssignUnitsToSquad = function(brain, platoon, units, squad)
    -- assertions
    if table.empty(units) then
        return
    end

    brain:AssignUnitsToPlatoon(platoon, units, squad, 'None')

    -- inform the unit of the event
    for k = 1, table.getn(units) do
        local unit = units[k]
        unit:OnAssignedToPlatoon(platoon)
    end
end

--- Assigns units to the attack squad.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units JoeUnit[]
AssignAttackUnits = function(brain, platoon, units)
    AssignUnitsToSquad(brain, platoon, units, "Attack")
end

--- Assigns units to the support squad.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units JoeUnit[]
AssignSupportUnits = function(brain, platoon, units)
    AssignUnitsToSquad(brain, platoon, units, "Support")
end

--- Assigns units to the artillery squad.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units JoeUnit[]
AssignArtilleryUnits = function(brain, platoon, units)
    AssignUnitsToSquad(brain, platoon, units, "Artillery")
end

--- Assigns units to the guard squad.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units JoeUnit[]
AssignGuardUnits = function(brain, platoon, units)
    AssignUnitsToSquad(brain, platoon, units, "Guard")
end

--- Assigns units to the scout squad.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units JoeUnit[]
AssignScoutUnits = function(brain, platoon, units)
    AssignUnitsToSquad(brain, platoon, units, "Scout")
end

--- Assigns units to their respective squads.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units JoeUnit[]
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
---@param units JoeUnit[]
CreatePlatoon = function(brain, platoon, units)
    local platoon = CreatePlatoonWithBehavior(brain, platoon)
    AssignUnits(brain, platoon, units)
    return platoon
end

--- Starts the behavior of a platoon.
---@param platoon AIPlatoonBehavior
---@param input? AIPlatoonBehaviorInput
StartPlatoon = function(platoon, input)
    platoon.PlatoonBehaviorInput = input or {}
    platoon:ChangeState(platoon.Start)
end

---@param platoon AIPlatoonBehavior
AssignInput = function(platoon, input)
    platoon.PlatoonBehaviorInput = input
end
