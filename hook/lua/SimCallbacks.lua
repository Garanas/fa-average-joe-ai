-- Hooks into: https://github.com/FAForever/fa/blob/develop/lua/SimCallbacks.lua

do
    local OldDoCallback = DoCallback

    --- Wraps the engine's DoCallback so any callback whose name contains "JoeDebug" announces itself in the log. Lets the per-callback bodies stay free of print boilerplate.
    DoCallback = function(name, data, units)
        if string.find(name, "JoeDebug", 1, true) then
            print(name)
        end
        return OldDoCallback(name, data, units)
    end
end

do

    local PlatoonBuilderUtils = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonUtils.lua")
    local PlatoonBuilderModule = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBuilder.lua")

    local JoeBaseBuilder = import("/mods/fa-joe-ai/lua/Sim/Bases/JoeBaseBuilder.lua")
    local EntityUtils = import("/mods/fa-joe-ai/lua/Sim/Utils/EntityUtils.lua")

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

    --- Creates a base at `Location` for the focus army's brain. Any selected units are assigned to the base as its initial units; an empty selection still creates the base with no starting units.
    ---@param data JoeDebugCreateBaseAtLocationData
    ---@param units JoeUnit[]
    Callbacks.JoeDebugCreateBaseAtLocation = function(data, units)
        local brain = GetArmyBrain(data.ArmyIndex) --[[@as JoeBrain]]
        if not brain then
            print("No brain for army index:", data.ArmyIndex)
            return
        end

        local builder = JoeBaseBuilder.Build(brain, data.Location)
        if not table.empty(units) then
            builder:AssignUnits(units)
        end
        builder:End()
    end

    ---@class JoeDebugToggleBrainChunkVisualizationData
    ---@field ArmyIndex number

    --- Toggles the brain-level draw thread for the focus army. The thread renders every brain component that exposes a `Draw` method (currently just chunks).
    ---@param data JoeDebugToggleBrainChunkVisualizationData
    Callbacks.JoeDebugToggleBrainChunkVisualization = function(data)
        local brain = GetArmyBrain(data.ArmyIndex) --[[@as JoeBrain]]
        if not brain then
            print("No brain for army index:", data.ArmyIndex)
            return
        end

        if brain.Debug then
            brain:DisableDebug()
        else
            brain:EnableDebug()
        end
    end

    ---@class JoeDebugAddLeafToBaseData
    ---@field Location Vector

    --- Adds the leaf under `Location` to the base that the selected units belong to. The base's layer determines which grid is queried; layer-mismatched clicks (e.g. clicking on water with a land base selected) are reported and ignored.
    ---@param data JoeDebugAddLeafToBaseData
    ---@param units JoeUnit[]
    Callbacks.JoeDebugAddLeafToBase = function(data, units)
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
        local leaf = brain.ChunkComponent:FindLeaf(layer, data.Location)
        if not leaf then
            print("No leaf under cursor on layer:", layer)
            return
        end

        if brain.ChunkComponent:IsClaimed(leaf.Identifier) then
            local owner = brain.ChunkComponent:GetOwner(leaf.Identifier)
            if owner == base then
                print("Leaf is already claimed by this base")
            else
                print("Leaf is already claimed by another base")
            end
            return
        end

        base:ClaimLeaf(leaf.Identifier)
    end

    ---@class JoeDebugAcquireBuildSitesForBaseData
    ---@field UnitId UnitId

    --- Exercises `JoeBase:AcquireBuildSitesForUnit` for the selected engineer's base and reports the result. Does *not* issue any build order — the purpose is to verify that the find-or-create flow returns a sensible list (or correctly returns empty when it can't satisfy the request).
    ---@param data JoeDebugAcquireBuildSitesForBaseData
    ---@param units JoeUnit[]
    Callbacks.JoeDebugAcquireBuildSitesForBase = function(data, units)
        if table.empty(units) then
            print("No engineer selected")
            return
        end

        local engineer = units[1]
        local base = engineer.JoeData.Base
        if not base then
            print("Selected engineer is not part of a base")
            return
        end

        local sites = base:AcquireBuildSitesForUnit(data.UnitId)
        local count = table.getn(sites)
        if count == 0 then
            print("AcquireBuildSitesForUnit:", data.UnitId, "-> no sites available")
            return
        end

        local first = sites[1]
        print(
            "AcquireBuildSitesForUnit:", data.UnitId,
            "-> sites:", count,
            "first at:", first.Point[1], first.Point[2]
        )
    end

    ---@class JoeDebugAssignUnitsToBaseData
    ---@field Location Vector
    ---@field ArmyIndex number

    --- Assigns the selected units to whichever base is at `Location`. Two ways the base is found, in this order:
    ---   1. **Unit-wise** — any unit within a small box around `Location` whose `JoeData.Base` is non-nil; that unit's base wins.
    ---   2. **Section-wise** — fallback to the section under `Location` (Land first, Water as fallback) and use its owning base.
    --- If neither resolves, the assignment is reported and skipped.
    ---@param data JoeDebugAssignUnitsToBaseData
    ---@param units JoeUnit[]
    Callbacks.JoeDebugAssignUnitsToBase = function(data, units)
        if table.empty(units) then
            print("No units selected")
            return
        end

        local lx = data.Location[1]
        local lz = data.Location[3]

        -- 1. unit under mouse -> that unit's base
        local base = nil
        local nearby = GetUnitsInRect(lx - 2, lz - 2, lx + 2, lz + 2)
        if nearby then
            for k = 1, table.getn(nearby) do
                local entity = nearby[k] --[[@as JoeUnit]]
                if entity.JoeData and entity.JoeData.Base then
                    base = entity.JoeData.Base
                    break
                end
            end
        end

        -- 2. fallback: leaf under mouse -> its owning base
        if not base then
            local brain = GetArmyBrain(data.ArmyIndex) --[[@as JoeBrain]]
            if brain and brain.ChunkComponent then
                local leaf = brain.ChunkComponent:FindLeaf("Land", data.Location)
                          or brain.ChunkComponent:FindLeaf("Water", data.Location)
                if leaf then
                    base = brain.ChunkComponent:GetOwner(leaf.Identifier)
                end
            end
        end

        if not base then
            print("No base under cursor (no unit with a base, no claimed leaf)")
            return
        end

        JoeBaseBuilder.Extend(base):AssignUnits(units):End()
    end

    local JoeBuildingIdentifierModule = import("/mods/fa-joe-ai/lua/Shared/BaseChunks/JoeBuildingIdentifiers.lua")

    ---@class JoeDebugPushBuildJobData
    ---@field UnitId UnitId
    ---@field LocationHint? Vector

    --- Pushes a build job onto the queue of the selected engineer's base. The unit id (from the active build command mode) is resolved to a `JoeBuildingIdentifier` and stored on the spec's `Identifier` field. If `LocationHint` is provided, it's attached to the spec verbatim.
    ---@param data JoeDebugPushBuildJobData
    ---@param units JoeUnit[]
    Callbacks.JoeDebugPushBuildJob = function(data, units)
        if table.empty(units) then
            print("No engineer selected")
            return
        end

        local engineer = units[1]
        local base = engineer.JoeData.Base
        if not base then
            print("Selected engineer is not part of a base")
            return
        end

        local identifier = JoeBuildingIdentifierModule.MapToIdentifier(data.UnitId)

        ---@type JoeConstructionJobSpec
        local spec = {
            Identifier = identifier,
            LocationHint = data.LocationHint,
        }

        base.ConstructionQueueComponent:PushJob(spec)
        print(
            "PushBuildJob:", data.UnitId,
            "->", identifier,
            data.LocationHint and "(with hint)" or "(no hint)",
            "; queue size:", table.getn(base.ConstructionQueueComponent.Pending)
        )
    end

    ---@class JoeDebugPushProductionJobData
    ---@field Location Vector
    ---@field ArmyIndex number

    --- Pushes one production job per selected unit onto the production queue of the base under the cursor. Each job's `UnitId` is the selected unit's own blueprint id, so the rule is "make more of what's selected." Base is resolved via the same two-step lookup as `JoeDebugAssignUnitsToBase` — unit-under-cursor first, leaf-under-cursor as fallback.
    ---@param data JoeDebugPushProductionJobData
    ---@param units JoeUnit[]
    Callbacks.JoeDebugPushProductionJob = function(data, units)
        if table.empty(units) then
            print("No units selected")
            return
        end

        local lx = data.Location[1]
        local lz = data.Location[3]

        -- 1. unit under mouse -> that unit's base
        local base = nil
        local nearby = GetUnitsInRect(lx - 2, lz - 2, lx + 2, lz + 2)
        if nearby then
            for k = 1, table.getn(nearby) do
                local entity = nearby[k] --[[@as JoeUnit]]
                if entity.JoeData and entity.JoeData.Base then
                    base = entity.JoeData.Base
                    break
                end
            end
        end

        -- 2. fallback: leaf under mouse -> its owning base
        if not base then
            local brain = GetArmyBrain(data.ArmyIndex) --[[@as JoeBrain]]
            if brain and brain.ChunkComponent then
                local leaf = brain.ChunkComponent:FindLeaf("Land", data.Location)
                          or brain.ChunkComponent:FindLeaf("Water", data.Location)
                if leaf then
                    base = brain.ChunkComponent:GetOwner(leaf.Identifier)
                end
            end
        end

        if not base then
            print("No base under cursor (no unit with a base, no claimed leaf)")
            return
        end

        for k = 1, table.getn(units) do
            local unit = units[k]
            ---@type JoeProductionJobSpec
            local spec = {
                Category = categories[unit:GetUnitId()],
                TechPreference = categories.ALLUNITS,
                LocationHint = data.Location,
            }
            base.ProductionQueueComponent:PushJob(spec)
        end

        print(
            "PushProductionJob: queued", table.getn(units),
            "; queue size:", table.getn(base.ProductionQueueComponent.Pending)
        )
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
