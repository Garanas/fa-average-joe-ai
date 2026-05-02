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

    ---@class JoeDebugCreateBaseAtLocationData
    ---@field Location Vector
    ---@field ArmyIndex number

    --- Creates a base at `Location` for the focus army's brain, without requiring any selected units. Uses the builder pattern so registration is an explicit step (`AssignBrain`) rather than a side effect.
    ---@param data JoeDebugCreateBaseAtLocationData
    Callbacks.JoeDebugCreateBaseAtLocation = function(data)
        local brain = GetArmyBrain(data.ArmyIndex) --[[@as JoeBrain]]
        if not brain then
            print("No brain for army index:", data.ArmyIndex)
            return
        end

        JoeBaseBuilder.Build(brain, data.Location)
            :End()
    end

    ---@class JoeDebugToggleBrainChunkVisualizationData
    ---@field ArmyIndex number

    --- Toggles the brain-level chunk visualization for the focus army. Independent from any per-base toggle.
    ---@param data JoeDebugToggleBrainChunkVisualizationData
    Callbacks.JoeDebugToggleBrainChunkVisualization = function(data)
        local brain = GetArmyBrain(data.ArmyIndex) --[[@as JoeBrain]]
        if not brain or not brain.ChunkComponent then
            print("No brain or chunk component for army index:", data.ArmyIndex)
            return
        end

        if brain.ChunkComponent.Debug then
            brain.ChunkComponent:DisableDebug()
        else
            brain.ChunkComponent:EnableDebug()
        end
    end

    ---@class JoeDebugToggleBaseChunkVisualizationData
    ---@field ArmyIndex number
    ---@field Location Vector

    --- Toggles the per-base chunk visualization for whichever base owns the section under `Location`. The mouse position is resolved to a section (Land first, Water as fallback), then to its owning base via `brain.ChunkComponent.Sections`.
    ---@param data JoeDebugToggleBaseChunkVisualizationData
    Callbacks.JoeDebugToggleBaseChunkVisualization = function(data)
        local brain = GetArmyBrain(data.ArmyIndex) --[[@as JoeBrain]]
        if not brain or not brain.ChunkComponent then
            print("No brain or chunk component for army index:", data.ArmyIndex)
            return
        end

        local section = brain.ChunkComponent:FindSection("Land", data.Location)
                     or brain.ChunkComponent:FindSection("Water", data.Location)
        if not section then
            print("No section under cursor")
            return
        end

        local base = brain.ChunkComponent:GetOwner(section.Identifier)
        if not base then
            print("Section under cursor is not claimed by any base")
            return
        end

        if base.ChunkComponent.Debug then
            base.ChunkComponent:DisableDebug()
        else
            base.ChunkComponent:EnableDebug()
        end
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