-- Hooks into: https://github.com/FAForever/fa/blob/develop/lua/simInit.lua

do
    local OldBeginSession = BeginSession
    BeginSession = function()
        OldBeginSession()

        -- Allows us to debug platoon behaviors by selecting units
        local PlatoonBehaviorDebugThread = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonUtils.lua").PlatoonBehaviorDebugThread
        ForkThread(PlatoonBehaviorDebugThread)
    end
end
