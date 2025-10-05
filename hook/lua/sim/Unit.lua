-- Hooks into: https://github.com/FAForever/fa/blob/develop/lua/sim/Unit.lua

do
    local OldUnit = Unit

    ---@class JoeUnit : Unit
    ---@field AIPlatoonBehavior? AIPlatoonBehavior
    Unit = Class(OldUnit) {
        ---@param self JoeUnit
        ---@param platoon AIPlatoonBehavior
        OnAssignedToPlatoon = function(self, platoon)
            self.AIPlatoonBehavior = platoon
        end,
    }
end
