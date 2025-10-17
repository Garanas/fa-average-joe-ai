-- Hooks into: https://github.com/FAForever/fa/blob/develop/lua/SimCallbacks.lua

do

    local PlatoonBuilderUtils = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonUtils.lua")
    local PlatoonBuilderModule = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBuilder.lua")

    local JoeBaseBuilder = import("/mods/fa-joe-ai/lua/Sim/JoeBaseBuilder.lua")
    local EntityUtils = import("/mods/fa-joe-ai/lua/sim/EntityUtils.lua")

    ---@class JoeDebugCreatePlatoonData
    ---@field BehaviorName string 
    ---@field BehaviorInput? AIPlatoonBehaviorInput

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

        -- assertion
        local behavior = PlatoonBuilderUtils.PlatoonBehaviors[data.BehaviorName]
        if not behavior then
            print("Unknown behavior: " .. data.BehaviorName)
            return
        end

        local platoon = PlatoonBuilderModule.Build(brain, behavior)
            :AssignUnits(units)
            :StartBehavior(data.BehaviorInput)
            :End()
    end

    ---@class JoeDebugCreateBaseData
    ---@field Location Vector

    ---@param data JoeDebugCreateBaseData
    ---@param units JoeUnit[]
    Callbacks.JoeDebugCreateBase = function(data, units)
        -- assertion
        if table.empty(units) then
            print("No units to apply to platoon")
            return
        end

        local brain = units[1]:GetAIBrain() --[[@as JoeBrain]]
        local base = JoeBaseBuilder.Build(brain, data.Location)
            :AssignUnits(units)
            :End()
    end

    ---@class JoeDebugAssignReclaimBehaviorData
    ---@field Location Vector

    ---@param data JoeDebugAssignReclaimBehaviorData
    ---@param units JoeUnit[]
    Callbacks.JoeDebugAssignReclaimBehavior = function(data, units)
        -- assertion
        if table.empty(units) then
            print("No units to apply to platoon")
            return
        end

        -- assertion
        local base = units[1].JoeData.Base
        if not base then
            print("Unit is not part of a base")
            return
        end

        -- find candidates and sort them
        local candidates = base:FindEngineersToReclaim()
        if table.empty(candidates) then
            print("No available engineers to reclaim")
            return
        end

        EntityUtils.SortInPlaceByDistance(candidates, data.Location)
        local engineer = candidates[1]

        base:AssignReclaimBehavior(engineer, data.Location)
    end
end