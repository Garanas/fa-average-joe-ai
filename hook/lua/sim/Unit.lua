-- Hooks into: https://github.com/FAForever/fa/blob/develop/lua/sim/Unit.lua

do
    local OldUnit = Unit

    ---@class JoeUnitData
    ---@field Behavior? AIPlatoonBehavior       # If defined, represents a handle to the behavior that the unit is a part of.
    ---@field Base? JoeBase                     # If defined, represents a handle to the base that the unit is a part of.

    ---@class JoeUnit : Unit
    ---@field JoeData JoeUnitData
    Unit = Class(OldUnit) {


        ---@param self JoeUnit
        OnCreate = function(self)
            OldUnit.OnCreate(self)

            self.JoeData = {}
        end,

        --- Called by the behavior builder when this unit is assigned to a behavior.
        ---@param self JoeUnit
        ---@param platoon AIPlatoonBehavior
        OnAssignedToPlatoon = function(self, platoon)
            self.JoeData.Behavior = platoon
        end,

        --- Called by the base builder when this unit is assigned to a base.
        ---@param self JoeUnit
        ---@param base JoeBase
        OnAssignedToBase = function(self, base)
            self.JoeData.Base = base
        end,
    }
end
