local AIPlatoonBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBehavior.lua").AIPlatoonBehavior

--- A behavior used for debugging, testing and development.
---@class AINullBehavior : AIPlatoonBehavior
NullBehavior = Class(AIPlatoonBehavior) {
    BehaviorName = 'NullBehavior',

    Start = State {
        BehaviorStateName = 'Start',

        ---@param self AINullBehavior
        Main = function(self)
            -- do nothing
        end,
    },
}
