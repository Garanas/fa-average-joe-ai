local AIPlatoonBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBehavior.lua").AIPlatoonBehavior

--- A behavior used for debugging, testing and development.
---@class AIWanderBehavior : AIPlatoonBehavior
WanderBehavior = Class(AIPlatoonBehavior) {
    BehaviorName = 'WanderBehavior',

    Start = State {
        BehaviorStateName = 'Start',

        ---@param self AIWanderBehavior
        Main = function(self)
            self:ChangeState(self.Wander)
            return
        end,
    },


    Wander = State {
        BehaviorStateName = 'Wander',

        ---@param self AIWanderBehavior
        Main = function(self)
            ---@param unit Unit
            local function WanderThread(unit)
                while not IsDestroyed(unit) do
                    local ox, oy, oz = unit:GetPositionXYZ()

                    -- determine a random offset
                    local offset = {
                        ox + 10 * Random() - 5,
                        oy,
                        oz + 10 * Random() - 5,
                    }

                    local navigator = unit:GetNavigator()
                    navigator:SetGoal(offset)

                    WaitTicks(40 + math.floor(5 * Random()))
                end
            end

            -- make all units wander around
            local units = self:GetPlatoonUnits()
            for k = 1, table.getn(units) do
                self.BehaviorStateTrash:Add(
                    ForkThread(
                        WanderThread, units[k]
                    )
                )
            end

            WaitTicks(150)
            self:ChangeState(self.Idle)
            return
        end,
    },

    Idle = State{
        BehaviorStateName = 'Idle',

        ---@param self AIWanderBehavior
        Main = function(self)
            WaitTicks(150)

            self:ChangeState(self.Wander)
            return
        end,
    }
}
