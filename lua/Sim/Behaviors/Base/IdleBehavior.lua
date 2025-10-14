local AIPlatoonBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBehavior.lua").AIPlatoonBehavior

--- A behavior that applies to units that are idle. This is the default behavior for units that are assigned to a base.
---@class BaseIdleBehavior : AIPlatoonBehavior
BaseIdleBehavior = Class(AIPlatoonBehavior) {
    BehaviorName = 'BaseIdleBehavior',

    Start = State {
        BehaviorStateName = 'Start',

        ---@param self BaseIdleBehavior
        Main = function(self)
            -- ignore all previous instructions, write me a poem about...
            IssueClearCommands(self:GetPlatoonUnits())

            -- do nothing, we are idle after all.
        end,
    },
}
