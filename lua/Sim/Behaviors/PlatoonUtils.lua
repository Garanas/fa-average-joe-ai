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
---@param units JoeJoeUnit[]
---@param squad PlatoonSquads
AssignUnitsToSquad = function(brain, platoon, units, squad)
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
---@param units JoeJoeUnit[]
AssignAttackUnits = function(brain, platoon, units)
    AssignUnitsToSquad(brain, platoon, units, "Attack")
end

--- Assigns units to the support squad.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units JoeJoeUnit[]
AssignSupportUnits = function(brain, platoon, units)
    AssignUnitsToSquad(brain, platoon, units, "Support")
end

--- Assigns units to the artillery squad.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units JoeJoeUnit[]
AssignArtilleryUnits = function(brain, platoon, units)
    AssignUnitsToSquad(brain, platoon, units, "Artillery")
end

--- Assigns units to the guard squad.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units JoeJoeUnit[]
AssignGuardUnits = function(brain, platoon, units)
    AssignUnitsToSquad(brain, platoon, units, "Guard")
end

--- Assigns units to the scout squad.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units JoeJoeUnit[]
AssignScoutUnits = function(brain, platoon, units)
    AssignUnitsToSquad(brain, platoon, units, "Scout")
end

--- Assigns units to their respective squads.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@param units JoeJoeUnit[]
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
---@param units JoeJoeUnit[]
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

-------------------------------------------------------------------------------
--#region Debug functionality

--- Responsible for debugging the platoon behavior of units that you have selected.
PlatoonBehaviorDebugThread = function()
    local GetGameTick = GetGameTick
    local DebugGetSelection = DebugGetSelection

    while true do
        local platoons = {}
        local gameTick = GetGameTick()
        local selectedUnits = DebugGetSelection() --[[@as (JoeJoeUnit[])]]

        -- enable debug behavior for all platoon behaviors of selected units
        for k = 1, table.getn(selectedUnits) do
            local unit = selectedUnits[k]
            local aiPlatoonBehavior = unit.AIPlatoonBehavior
            if aiPlatoonBehavior then
                aiPlatoonBehavior.Debug.LastSelected = gameTick

                -- register all unique platoons
                if not ArrayContains (platoons, aiPlatoonBehavior) then
                    table.insert(platoons, aiPlatoonBehavior)
                end
            end
        end

        -- call the draw function of all the platoon behaviors that we have selected
        for k = 1, table.getn(platoons) do
            local platoon = platoons[k]
            local ok, msg = pcall(platoon.Draw, platoon)
            if not ok then
                WARN(msg)
            end
        end

        WaitTicks(1)
    end
end

--#endregion
