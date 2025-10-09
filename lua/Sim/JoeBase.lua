
local PlatoonBuilderUtils = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonUtils.lua")
local PlatoonBuilderModule = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBuilder.lua")

--- A base describes an area where Joe will manage engineers to build infrastructure such as factories or power generators.
---
--- 
---@class JoeBase
---@field Engineers table<EntityId, JoeUnit>
---@field Brain JoeBrain
---@field Location Vector
JoeBase = ClassSimple {

    ---@param self JoeBase
    ---@param brain JoeBrain
    __init = function(self, brain, center)
        self.Brain = brain
        self.Location = center

        self.Engineers = {}
    end,

    --#region Engineers

    ---@param self JoeBase
    ---@param engineer JoeUnit
    AssignEngineer = function(self, engineer)
        self.Engineers[engineer.EntityId] = engineer
        engineer:OnAssignedToBase(self)

        PlatoonBuilderModule.Build(self.Brain, PlatoonBuilderUtils.PlatoonBehaviors.ReclaimBehavior)
    end,

    ---@param self JoeBase
    ---@param engineers JoeUnit[]
    AssignEngineers = function(self, engineers)
        for _, engineer in engineers do
            self:AssignEngineer(engineer)
        end
    end,

    --#endregion

    --#region Factories

    --#endregion

    --#region Other structures

    --#endregion
}
