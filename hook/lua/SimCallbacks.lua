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

    ---@class JoeDebugAddSectionToBaseData
    ---@field Location Vector

    --- Adds the section under `Location` to the base that the selected units belong to. The base's layer determines which grid is queried; layer-mismatched clicks (e.g. clicking on water with a land base selected) are reported and ignored.
    ---@param data JoeDebugAddSectionToBaseData
    ---@param units JoeUnit[]
    Callbacks.JoeDebugAddSectionToBase = function(data, units)
        -- assertion
        if table.empty(units) then
            print("No units to identify the base")
            return
        end

        -- assertion
        local base = units[1].JoeData.Base
        if not base then
            print("Selected unit is not part of a base")
            return
        end

        local brain = base.Brain --[[@as JoeBrain]]
        local layer = base.ChunkComponent.Layer
        local section = brain.ChunkComponent:FindSection(layer, data.Location)
        if not section then
            print("No section under cursor on layer:", layer)
            return
        end

        if brain.ChunkComponent:IsClaimed(section.Identifier) then
            local owner = brain.ChunkComponent:GetOwner(section.Identifier)
            if owner == base then
                print("Section is already claimed by this base")
            else
                print("Section is already claimed by another base")
            end
            return
        end

        base.ChunkComponent:Claim(section.Identifier)
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