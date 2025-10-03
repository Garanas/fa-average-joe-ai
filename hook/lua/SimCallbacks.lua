-- Hooks into: https://github.com/FAForever/fa/blob/develop/lua/SimCallbacks.lua

do

    local PlatoonBuilderUtils = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonUtils.lua")
    local PlatoonBuilderModule = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBuilder.lua")

    ---@class JoeDebugCreatePlatoonData
    ---@field BehaviorName string 

    ---@param data JoeDebugCreatePlatoonData
    ---@param units JoeUnit[]
    Callbacks.JoeDebugCreatePlatoon = function(data, units)
        -- assertion
        if table.empty(units) then
            print("No units to apply to platoon")
            return
        end

        -- assertion
        local brain = units[1]:GetAIBrain() --[[@as JoeBrain]]
        if not brain then
            print("Units (literally) have no brain to apply a platoon with")
            return
        end

        -- assertion
        local behavior = PlatoonBuilderUtils.PlatoonBehaviors[data.BehaviorName]
        if not behavior then
            print("Unknown behavior: " .. data.BehaviorName)
            return
        end

        local platoon = PlatoonBuilderModule.Build(brain, behavior)
            :AssignUnits(units)
            :StartBehavior()
            :End()
    end
end