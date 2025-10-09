-- Hooks into: https://github.com/FAForever/fa/blob/develop/lua/sim/Unit.lua

do
    local OldUnit = Unit

    ---@class JoeUnit : Unit
    ---@field JoePlatoonBehavior? AIPlatoonBehavior     # The behavior that this unit is a part of
    ---@field JoeBase? AIJoeBase                        # The base that this unit is a part of
    Unit = Class(OldUnit) {

        ---@param self JoeUnit
        ---@param platoon AIPlatoonBehavior
        OnAssignedToPlatoon = function(self, platoon)
            self.JoePlatoonBehavior = platoon
        end,

        OnAssignedToBase = function(self, base)
        end,
    }
end
