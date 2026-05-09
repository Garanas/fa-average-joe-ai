local PlatoonBuilderUtils = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonUtils.lua")
local PlatoonBuilderModule = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBuilder.lua")

local TableUtils = import("/mods/fa-joe-ai/lua/Shared/TableUtils.lua")

local JoeBaseChunkComponent = import("/mods/fa-joe-ai/lua/Sim/Bases/Components/JoeBaseChunkComponent.lua").JoeBaseChunkComponent
local JoeBaseBuildSiteComponent = import("/mods/fa-joe-ai/lua/Sim/Bases/Components/JoeBaseBuildSiteComponent.lua").JoeBaseBuildSiteComponent
local JoeBaseConstructionQueueComponent = import("/mods/fa-joe-ai/lua/Sim/Bases/Components/JoeBaseConstructionQueueComponent.lua").JoeBaseConstructionQueueComponent
local JoeBaseProductionQueueComponent = import("/mods/fa-joe-ai/lua/Sim/Bases/Components/JoeBaseProductionQueueComponent.lua").JoeBaseProductionQueueComponent

local JoeBuildingIdentifierModule = import("/mods/fa-joe-ai/lua/Shared/BaseChunks/JoeBuildingIdentifiers.lua")

-- upvalue for performance
local TableInsert = table.insert
local TableGetn = table.getn

--- Data structure for storing information used to debug this base. This information may not be synchronized between players. Any field in this table should not be used for the behavior itself!
---@class JoeBaseDebugData
---@field LastSelected number       # Indicates the last tick that one or more units of this base was selected. Can be used as a cheap indication when to log debug information.

---@class JoeBaseEngineers
---@field Reclaiming AIReclaimBehavior[]
---@field Assisting BaseIdleBehavior[]          # TODO: not implemented yet
---@field Building BaseIdleBehavior[]           # TODO: not implemented yet
---@field Repairing BaseIdleBehavior[]          # TODO: not implemented yet
---@field Patrolling BaseIdleBehavior[]         # TODO: not implemented yet

---@class JoeBase
---@field Trash TrashBag
---@field Debug JoeBaseDebugData
---@field Engineers JoeBaseEngineers
---@field Brain JoeBrain
---@field Location Vector
---@field IdleBehavior BaseIdleBehavior
---@field ChunkComponent JoeBaseChunkComponent
---@field BuildSiteComponent JoeBaseBuildSiteComponent
---@field ConstructionQueueComponent JoeBaseConstructionQueueComponent
---@field ProductionQueueComponent JoeBaseProductionQueueComponent
---@field Units JoeUnit[]
JoeBase = ClassSimple {

    ---@param self JoeBase
    ---@param brain JoeBrain
    __init = function(self, brain, center)
        self.Brain = brain
        self.Location = center
        self.Trash = TrashBag()
        self.Debug = {}

        self.Engineers = {
            Reclaiming = TableUtils.CreateWeakValueTable()
        }

        self.IdleBehavior = PlatoonBuilderModule.Build(self.Brain, PlatoonBuilderUtils.PlatoonBehaviors.Base.IdleBehavior):End() --[[@as BaseIdleBehavior]]

        self.ChunkComponent = JoeBaseChunkComponent(self)
        self.BuildSiteComponent = JoeBaseBuildSiteComponent(self)
        self.ConstructionQueueComponent = JoeBaseConstructionQueueComponent(self)
        self.ProductionQueueComponent = JoeBaseProductionQueueComponent(self)

        self.Trash:Add(ForkThread(self.TickThread, self))
    end,

    ---------------------------------------------------------------------------
    --#region Lifecycle and leaf claims (cross-component coordination)

    --- Records a claim on the given leaf for this base. Refuses if any base under this brain (including this one) already claims it. Mirrors successful claims to the brain so its union view stays in sync.
    ---@param self JoeBase
    ---@param leafId NavLeafIdentifier
    ---@return boolean    # true if the claim was recorded; false if already claimed
    ClaimLeaf = function(self, leafId)
        if self.Brain.ChunkComponent:IsClaimed(leafId) then
            return false
        end

        self.ChunkComponent:ClaimLeaf(leafId)
        self.Brain.ChunkComponent:ClaimLeaf(leafId, self)
        return true
    end,

    --- Releases this base's claim on a single leaf. Mirrors the release to the brain. Quietly returns false if the leaf wasn't claimed by this base.
    ---@param self JoeBase
    ---@param leafId NavLeafIdentifier
    ---@return boolean
    ReleaseLeaf = function(self, leafId)
        if not self.ChunkComponent:IsClaimed(leafId) then
            return false
        end

        self.BuildSiteComponent:ReleaseSitesFromLeaf(leafId)
        self.ChunkComponent:ReleaseLeaf(leafId)
        self.Brain.ChunkComponent:ReleaseLeaf(leafId, self)
        return true
    end,

    --- Releases every leaf this base claims. Iterates first to mirror each release to the brain (and drop attached build sites), then clears the component's storage.
    ---@param self JoeBase
    ReleaseAllLeaves = function(self)
        local brainComponent = self.Brain.ChunkComponent
        local buildSites = self.BuildSiteComponent
        for leafId, _ in self.ChunkComponent.Leaves do
            buildSites:ReleaseSitesFromLeaf(leafId)
            brainComponent:ReleaseLeaf(leafId, self)
        end
        self.ChunkComponent:ReleaseAllLeaves()
    end,

    --- Tears the base down: kills every thread/observer in the trash, releases every claimed leaf (mirroring to the brain), and removes the base from the brain's roster. After this call the base is no longer reachable through `brain.Bases`.
    ---@param self JoeBase
    Retreat = function(self)
        self.Trash:Destroy()
        self:ReleaseAllLeaves()
        self.Brain:RemoveBase(self)
    end,

    --#endregion
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    --#region Build-site planning (find-or-create flow)

    --- Ensures at least one free build site exists for the given identifier and returns every free site that matches. Order of attempts:
    ---
    ---  1. Existing free sites already mapped on this base.
    ---  2. A claimed-but-unchunkified leaf: find a template containing this identifier, apply it.
    ---  3. Claim a new (unclaimed) leaf adjacent to the base, then apply the template.
    ---
    --- Returns an empty list if every attempt fails. The cache table (if provided) is cleared and reused — pass it back on subsequent calls to avoid allocating.
    ---@param self JoeBase
    ---@param identifier JoeBuildingIdentifier
    ---@param cache? JoeBuildSite[]
    ---@return JoeBuildSite[]
    AcquireBuildSitesForIdentifier = function(self, identifier, cache)
        local buildSites = self.BuildSiteComponent

        -- 1. existing free sites. CollectFreeFor allocates if cache is nil and always returns the cache table — reassign so it's guaranteed non-nil from here on.
        cache = buildSites:CollectFreeFor(identifier, cache)
        if TableGetn(cache) > 0 then
            return cache
        end

        -- 2. claimed-but-unchunkified leaf
        local leaf = self:FindUnchunkifiedLeaf()
        if leaf and self:ApplyTemplateForLeaf(leaf, identifier) then
            return buildSites:CollectFreeFor(identifier, cache)
        end

        -- 3. claim a new leaf, then apply
        leaf = self:ClaimAdjacentLeaf()
        if leaf and self:ApplyTemplateForLeaf(leaf, identifier) then
            return buildSites:CollectFreeFor(identifier, cache)
        end

        -- 4. give up — cache is already empty from step 1
        return cache
    end,

    --- Resolves `unitId` to its `JoeBuildingIdentifier` and delegates to `AcquireBuildSitesForIdentifier`.
    ---@param self JoeBase
    ---@param unitId UnitId
    ---@param cache? JoeBuildSite[]
    ---@return JoeBuildSite[]
    AcquireBuildSitesForUnit = function(self, unitId, cache)
        local identifier = JoeBuildingIdentifierModule.MapToIdentifier(unitId)
        return self:AcquireBuildSitesForIdentifier(identifier, cache)
    end,

    --- Returns the first claimed leaf that has not yet had a template applied to it, or nil if every claimed leaf is already chunkified.
    ---@param self JoeBase
    ---@return NavLeaf?
    FindUnchunkifiedLeaf = function(self)
        for _, claim in self.ChunkComponent.Leaves do
            if not claim.Chunkified then
                return claim.Leaf
            end
        end
        return nil
    end,

    --- Picks a template that fits a single leaf, **size-first**: the largest fitting template wins. Templates whose `Size` exceeds `leaf.Size` are skipped. Among same-size candidates, identifier-bearing templates are preferred as a tie-break.
    ---@param self JoeBase
    ---@param leaf NavLeaf
    ---@param identifier JoeBuildingIdentifier
    ---@return JoeBaseChunk?
    ---@return boolean   # true if the chosen template contains the identifier
    FindTemplateForLeaf = function(self, leaf, identifier)
        local best = nil
        local bestSize = -1
        local bestHasIdentifier = false

        local templates = self.Brain.ChunkLoader.Templates
        for k = 1, TableGetn(templates) do
            local template = templates[k]
            if template.Size <= leaf.Size then
                local locations = template.Locations[identifier]
                local hasIdentifier = locations ~= nil and TableGetn(locations) > 0

                if template.Size > bestSize then
                    best = template
                    bestSize = template.Size
                    bestHasIdentifier = hasIdentifier
                elseif template.Size == bestSize and hasIdentifier and not bestHasIdentifier then
                    -- same size, prefer the one that contains the identifier
                    best = template
                    bestHasIdentifier = true
                end
            end
        end

        return best, bestHasIdentifier
    end,

    --- Picks a size-best-fit template for the given leaf and maps it. Marks the leaf chunkified iff a template was applied. Returns true when the chosen template actually contains a slot for `identifier` — that's what makes the leaf useful for the current query. False means either no template fits or the picked template was a fallback (no identifier match), and the orchestrator should try a different leaf.
    ---@param self JoeBase
    ---@param leaf NavLeaf
    ---@param identifier JoeBuildingIdentifier
    ---@return boolean
    ApplyTemplateForLeaf = function(self, leaf, identifier)
        if leaf.Label <= 0 then
            return false
        end

        local template, isMatch = self:FindTemplateForLeaf(leaf, identifier)
        if not template then
            return false
        end

        self.BuildSiteComponent:MapTemplate(template, leaf)
        self.ChunkComponent:MarkChunkified(leaf.Identifier)
        return isMatch
    end,

    --- Asks the brain for unclaimed nav-mesh leaves reachable from this base's location and claims the first one of sufficient size. Uses `ChunkComponent.MinClaimSize` (default 16) as the size floor and as the area target — one MinClaimSize×MinClaimSize leaf is enough. Returns the leaf claimed, or nil if no expansion was possible.
    ---@param self JoeBase
    ---@return NavLeaf?
    ClaimAdjacentLeaf = function(self)
        local chunkComponent = self.ChunkComponent
        local layer = chunkComponent.Layer
        local minSize = chunkComponent.MinClaimSize
        local areaTarget = minSize * minSize

        local leaves = self.Brain.ChunkComponent:FindClaimableArea(layer, self.Location, areaTarget, minSize, self)

        for k = 1, TableGetn(leaves) do
            local leaf = leaves[k]
            -- the BFS includes our own claims (so we can re-traverse) — skip those
            if not chunkComponent:IsClaimed(leaf.Identifier) then
                if self:ClaimLeaf(leaf.Identifier) then
                    return leaf
                end
            end
        end

        return nil
    end,

    --#endregion
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    --#region Functions to prioritize engineers

    --- Finds an available engineer to reclaim at the specified location.
    ---@param self JoeBase
    ---@return JoeUnit[]
    FindEngineersToReclaim = function(self)
        local candidates = {}

        local idleUnits = self.IdleBehavior:GetPlatoonUnits()
        local reclaimUnits = EntityCategoryFilterDown(categories.RECLAIM, idleUnits)
        for k = 1, table.getn(reclaimUnits) do
            local unit = reclaimUnits[k]
            TableInsert(candidates, unit)
        end

        -- TODO: add candidates of other type of behavior, such as patrolling and/or assisting.

        return candidates
    end,

    --#endregion
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    --#region Helper functions to assign engineer behaviors

    --- Assigns the reclaim behavior to the specified engineer.
    ---@param self JoeBase
    ---@param engineer JoeUnit
    ---@param location Vector
    AssignReclaimBehavior = function(self, engineer, location)
        local platoon = PlatoonBuilderModule.Build(self.Brain, PlatoonBuilderUtils.PlatoonBehaviors.ReclaimBehavior)
            :AssignSupportUnit(engineer)
            :StartBehavior({ Location = location })
            :End()

        TableInsert(self.Engineers.Reclaiming, platoon)
    end,

    --#endregion

    ---------------------------------------------------------------------------
    --#region Recycling of engineers

    --- Recycles reclaiming engineers back to the idle behavior because they have completed their task one way or another.
    ---@param self JoeBase
    ---@param behaviors AIReclaimBehavior[]
    RecycleReclaimingEngineers = function(self, behaviors)
        local idleBehaviorBuilder = PlatoonBuilderModule.Extend(self.Brain, self.IdleBehavior)
        for k = 1, table.getn(behaviors) do
            local behavior = behaviors[k]
            if not IsDestroyed(behavior) then
                local behaviorStateName = behavior.BehaviorStateName
                if behaviorStateName == "Completed" then
                    local units = behavior:GetPlatoonUnits()
                    idleBehaviorBuilder:AssignSupportUnits(units)
                elseif behaviorStateName == "Error" then
                    local units = behavior:GetPlatoonUnits()
                    idleBehaviorBuilder:AssignSupportUnits(units)

                    -- TODO: requires some logic to determine the cause of failure. This is to prevent endless loops. Maybe invalidate the input somehow? We'll have to figure it out!
                end
            end
        end
    end,

    --- Re-assigns the idle behavior to all engineers that have completed their tasks.
    ---@param self JoeBase
    RecycleEngineers = function(self)
        local engineers = self.Engineers
        self:RecycleReclaimingEngineers(engineers.Reclaiming)

        -- clear all nil or destroyed fields
        for _, behaviors in engineers do
            TableUtils.CompactArray(behaviors)
        end
    end,

    --- Periodic maintenance tick for this base: recycles engineer behaviors and runs component validation passes. Fired from `__init` into `self.Trash` so `Retreat` cleans it up.
    ---@param self JoeBase
    TickThread = function(self)
        while true do
            self:RecycleEngineers()
            self:ValidateQueues()

            WaitTicks(10)
        end
    end,

    --#endregion
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    --#region Periodic validation (cross-component coordination)

    --- Runs each per-state validator on both job queues. The base owns the orchestration order so cross-component reconciliation (e.g. site state vs. job state) can grow here when invariants stretch beyond a single component.
    ---@param self JoeBase
    ValidateQueues = function(self)
        local construction = self.ConstructionQueueComponent
        construction:ValidatePending()
        construction:ValidateClaimed()
        construction:ValidateBuilding()
        construction:ValidateBuilt()

        local production = self.ProductionQueueComponent
        production:ValidatePending()
        production:ValidateClaimed()
        production:ValidateBuilding()
        production:ValidateBuilt()
    end,

    --#endregion
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    --#region Debug functionality

    --- A utility function that determines whether this platoon is selected. The output of this function is not synchronized across clients and therefore should not be a condition for anything but logging and/or drawing!
    ---@param self JoeBase
    IsBeingDebugged = function(self)
        return self.Debug.LastSelected >= GetGameTick() - 1
    end,

    --- Formats the message to make it more convenient to understand.
    ---@param self JoeBase
    ---@param message string
    ---@return string
    FormatMessage = function(self, message)
        return string.format("[%s] base: %s", tostring(self), tostring(message))
    end,

    --- A utility function that logs a message to the console.
    ---@param self JoeBase
    Log = function(self, message)
        LOG(self:FormatMessage(message))
    end,

    --- A utility function that logs a warning to the console.
    ---@param self JoeBase
    Warn = function(self, message)
        WARN(self:FormatMessage(message))
    end,

    --- A utility function that draws the current status quo. Composes per-aspect draw helpers so they can also be invoked individually.
    ---@param self JoeBase
    Draw = function(self)
        DrawCircle(self.Location, 10, 'ffffff')
        DrawCircle(self.Location, 11, 'ffffff')
        DrawCircle(self.Location, 12, 'ffffff')

        local DebugUtils = import("/mods/fa-joe-ai/lua/Sim/Utils/DebugUtils.lua")
        local idleUnits = self.IdleBehavior:GetPlatoonUnits()
        DebugUtils.DrawUnits(idleUnits, 'ffffff', 0.1)

        self.ChunkComponent:Draw()
        self.BuildSiteComponent:Draw()
        self:DrawReclaimingEngineers()
    end,

    --- Draws the units of every reclaim behavior currently assigned to this base.
    ---@param self JoeBase
    DrawReclaimingEngineers = function(self)
        local DebugUtils = import("/mods/fa-joe-ai/lua/Sim/Utils/DebugUtils.lua")
        for k = 1, table.getn(self.Engineers.Reclaiming) do
            local behavior = self.Engineers.Reclaiming[k]
            if not IsDestroyed(behavior) then
                local reclaimingUnits = behavior:GetPlatoonUnits()
                DebugUtils.DrawUnits(reclaimingUnits, '00ff00', 0.1)
            end
        end
    end,

    --#endregion
}
