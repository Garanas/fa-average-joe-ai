local PlatoonUtils = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonUtils.lua")

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

    --- Starts the behavior of a platoon.
    ---@param self AIPlatoonBuilder
    StartBehavior = function(self)
        PlatoonUtils.StartPlatoon(self.Platoon)
        return self
    end,

    ---@param self AIPlatoonBuilder
    ---@param units JoeUnit[]
    ---@return AIPlatoonBuilder
    AssignUnits = function(self, units)
        PlatoonUtils.AssignUnits(self.Brain, self.Platoon, units)
        return self
    end,

    --- Assigns units to the attack squad.
    ---@param self AIPlatoonBuilder
    ---@param units JoeUnit[]
    AssignAttackUnits = function(self, units)
        PlatoonUtils.AssignAttackUnits(self.Brain, self.Platoon, units)
        return self
    end,

    --- Assigns units to the support squad.
    ---@param self AIPlatoonBuilder
    ---@param units JoeUnit[]
    ---@return AIPlatoonBuilder
    AssignSupportUnits = function(self, units)
        PlatoonUtils.AssignSupportUnits(self.Brain, self.Platoon, units)
        return self
    end,

    --- Assigns units to the artillery squad.
    ---@param self AIPlatoonBuilder
    ---@param units JoeUnit[]
    ---@return AIPlatoonBuilder
    AssignArtilleryUnits = function(self, units)
        PlatoonUtils.AssignArtilleryUnits(self.Brain, self.Platoon, units)
        return self
    end,

    --- Assigns units to the guard squad.
    ---@param self AIPlatoonBuilder
    ---@param units JoeUnit[]
    ---@return AIPlatoonBuilder
    AssignGuardUnits = function(self, units)
        PlatoonUtils.AssignGuardUnits(self.Brain, self.Platoon, units)
        return self
    end,

    --- Assigns units to the scout squad.
    ---@param self AIPlatoonBuilder
    ---@param units JoeUnit[]
    ---@return AIPlatoonBuilder
    AssignScoutUnits = function(self, units)
        PlatoonUtils.AssignScoutUnits(self.Brain, self.Platoon, units)
        return self
    end,

    ---@param self AIPlatoonBuilder
    ---@return AIPlatoonBehavior
    End = function(self)
        -- TODO: basic validation
        return self.Platoon
    end,
}

--- Builds a platoon from scratch.
---@param brain JoeBrain
---@return AIPlatoonBuilder
Build = function(brain, behavior)
    local platoon = PlatoonUtils.CreatePlatoonWithBehavior(brain, behavior)
    return PlatoonBuilder(brain, platoon)
end

--- Extends an existing platoon.
---@param brain JoeBrain
---@param platoon AIPlatoonBehavior
---@return AIPlatoonBuilder
Extend = function(brain, platoon)
    return PlatoonBuilder(brain, platoon)
end
