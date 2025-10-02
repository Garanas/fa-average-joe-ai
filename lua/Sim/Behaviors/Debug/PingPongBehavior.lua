local AIPlatoonBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBehavior.lua").AIPlatoonBehavior

--- A behavior used for debugging, testing and development.
---@class AIPingPongBehavior : AIPlatoonBehavior
PingPongBehavior = Class(AIPlatoonBehavior) {
    BehaviorName = 'WanderBehavior',

    Start = State {
        BehaviorStateName = 'Start',

        ---@param self AIPingPongBehavior
        Main = function(self)
            self:ChangeState(self.Ping)
            return
        end,
    },

    Ping = State {
        BehaviorStateName = 'Ping',

        ---@param self AIPingPongBehavior
        Main = function(self)
            WaitTicks(20)
            self:ChangeState(self.Pong)
            return
        end,
    },

    Pong = State {
        BehaviorStateName = 'Pong',

        ---@param self AIPingPongBehavior
        Main = function(self)
            WaitTicks(20)
            self:ChangeState(self.Ping)
            return
        end,
    }
}
