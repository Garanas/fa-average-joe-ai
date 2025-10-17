local UnitCache = {}

---@class AIPlatoonBuilder
---@field Brain JoeBrain
---@field Platoon AIPlatoonBehavior
PlatoonBuilder = Class() {
    ---@param self AIPlatoonBuilder
    ---@param brain JoeBrain
    ---@param platoon AIPlatoonBehavior
    __init = function(self, brain, platoon)
        self.Brain = brain
        self.Platoon = platoon
    end,

    --- Starts the behavior of a platoon using the specific input as parameters.
    ---@param self AIPlatoonBuilder
    ---@param input? AIPlatoonBehaviorInput
    StartBehavior = function(self, input)
        local platoon = self.Platoon
        platoon.PlatoonBehaviorInput = input or {}
        platoon:ChangeState(platoon.Start)
        return self
    end,

    --- General assignment of units. This is a convenience function that assigns units to specific squads.
    ---@param self AIPlatoonBuilder
    ---@param units JoeUnit[]
    ---@return AIPlatoonBuilder
    AssignUnits = function(self, units)
        -- TODO: do proper filtering? Should this function even exist?
        self:AssignSupportUnits(units)
        self:AssignArtilleryUnits({})
        self:AssignGuardUnits({})
        self:AssignScoutUnits({})
        self:AssignAttackUnits({})

        return self
    end,

    --- Assigns units to the specified squad. Updates the platoon reference of units.
    ---@param self AIPlatoonBuilder
    ---@param squad PlatoonSquads
    ---@param units JoeUnit[]
    ---@return AIPlatoonBuilder
    AssignUnitsToSquad = function(self, units, squad)
        local brain = self.Brain
        local platoon = self.Platoon

        -- assertions
        if table.empty(units) then
            return self
        end

        brain:AssignUnitsToPlatoon(platoon, units, squad, 'None')

        -- inform the unit of the event
        for k = 1, table.getn(units) do
            local unit = units[k]
            unit:OnAssignedToPlatoon(platoon)
        end

        return self
    end,

    --- Assigns units to the attack squad.
    ---@param self AIPlatoonBuilder
    ---@param units JoeUnit[]
    AssignAttackUnits = function(self, units)
        return self:AssignUnitsToSquad(units, "Attack")
    end,

    --- Assigns units to the support squad.
    ---@param self AIPlatoonBuilder
    ---@param units JoeUnit[]
    ---@return AIPlatoonBuilder
    AssignSupportUnits = function(self, units)
        return self:AssignUnitsToSquad(units, "Support")
    end,

    --- Assigns units to the artillery squad.
    ---@param self AIPlatoonBuilder
    ---@param units JoeUnit[]
    ---@return AIPlatoonBuilder
    AssignArtilleryUnits = function(self, units)
        return self:AssignUnitsToSquad(units, "Artillery")
    end,

    --- Assigns units to the guard squad.
    ---@param self AIPlatoonBuilder
    ---@param units JoeUnit[]
    ---@return AIPlatoonBuilder
    AssignGuardUnits = function(self, units)
        return self:AssignUnitsToSquad(units, "Guard")
    end,

    --- Assigns units to the scout squad.
    ---@param self AIPlatoonBuilder
    ---@param units JoeUnit[]
    ---@return AIPlatoonBuilder
    AssignScoutUnits = function(self, units)
        return self:AssignUnitsToSquad(units, "Scout")
    end,

    --- Assigns the unit to the attack squad.
    ---@param self AIPlatoonBuilder
    ---@param unit JoeUnit
    ---@return AIPlatoonBuilder
    AssignAttackUnit = function(self, unit)
        UnitCache[1] = unit
        return self:AssignAttackUnits(UnitCache)
    end,

    --- Assigns the unit to the support squad.
    ---@param self AIPlatoonBuilder
    ---@param unit JoeUnit
    ---@return AIPlatoonBuilder
    AssignSupportUnit = function(self, unit)
        UnitCache[1] = unit
        return self:AssignSupportUnits(UnitCache)
    end,

    --- Assigns the unit to the artillery squad.
    ---@param self AIPlatoonBuilder
    ---@param unit JoeUnit
    ---@return AIPlatoonBuilder
    AssignArtilleryUnit = function(self, unit)
        UnitCache[1] = unit
        return self:AssignArtilleryUnits(UnitCache)
    end,

    --- Assigns the unit to the guard squad.
    ---@param self AIPlatoonBuilder
    ---@param unit JoeUnit
    ---@return AIPlatoonBuilder
    AssignGuardUnit = function(self, unit)
        UnitCache[1] = unit
        return self:AssignGuardUnits(UnitCache)
    end,

    --- Assigns the unit to the scout squad.
    ---@param self AIPlatoonBuilder
    ---@param unit JoeUnit
    ---@return AIPlatoonBuilder
    AssignScoutUnit = function(self, unit)
        UnitCache[1] = unit
        return self:AssignScoutUnits(UnitCache)
    end,

    ---@param self AIPlatoonBuilder
    ---@return AIPlatoonBehavior
    End = function(self)
        return self.Platoon
    end,
}

--- Builds a platoon from scratch.
---@param brain JoeBrain
---@return AIPlatoonBuilder
Build = function(brain, behavior)
    local platoon = brain:MakePlatoon("", "") --[[@as AIPlatoonBehavior]]
    setmetatable(platoon, behavior)

    -- initialize state of the behavior
    platoon:OnCreate()
    return PlatoonBuilder(brain, platoon)
end

--- Extends an existing platoon.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@return AIPlatoonBuilder
Extend = function(brain, platoon)
    return PlatoonBuilder(brain, platoon)
end
