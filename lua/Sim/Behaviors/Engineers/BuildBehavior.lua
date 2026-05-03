local AIPlatoonBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBehavior.lua").AIPlatoonBehavior

local ReclaimBuilder = import("/mods/fa-joe-ai/lua/sim/ReclaimBuilder.lua")
local ReclaimUtils = import("/mods/fa-joe-ai/lua/sim/ReclaimUtils.lua")
local Orders = import("/mods/fa-joe-ai/lua/Sim/Utils/Orders.lua")
local JoeBuildingIdentifierModule = import("/mods/fa-joe-ai/lua/Shared/BaseChunks/JoeBuildingIdentifiers.lua")

--- Resolves a `JoeBuildingIdentifier` plus an engineer to a concrete UnitId for that engineer's faction. Returns nil if no faction-specific blueprint exists for the identifier.
---@param identifier JoeBuildingIdentifier
---@param engineer JoeUnit
---@return UnitId?
local function ResolveUnitIdForBuilder(identifier, engineer)
    local category = JoeBuildingIdentifierModule.MapToCategoryForBuilder(identifier, engineer)
    return EntityCategoryGetUnitList(category)[1]
end

--- Picks the candidate build site closest to the engineer's current XZ position. Engineer-specific selection policy: shorter travel = sooner construction. The base returns *candidates*; this behavior decides among them. Other behaviors (e.g. a future ACU build behavior) will want a different policy — keep selection logic per-behavior rather than baking it into the base.
---@param sites JoeBuildSite[]
---@param engineer JoeUnit
---@return JoeBuildSite
local function SelectBuildSite(sites, engineer)
    local ex, _, ez = engineer:GetPositionXYZ()

    local best = sites[1]
    local dx = best.Point[1] - ex
    local dz = best.Point[2] - ez
    local bestDistSq = dx * dx + dz * dz

    for k = 2, table.getn(sites) do
        local site = sites[k]
        local sx = site.Point[1] - ex
        local sz = site.Point[2] - ez
        local distSq = sx * sx + sz * sz
        if distSq < bestDistSq then
            best = site
            bestDistSq = distSq
        end
    end

    return best
end

--- Read-only input parameters supplied by the platoon builder before `Start` runs.
---@class AIBuildBehaviorInput : AIPlatoonBehaviorInput

--- Per-build-behavior runtime state. Stashed on `self.BehaviorState` so a state's `Main` can read what previous states resolved without recomputing. Fields populated as the behavior progresses; the optional ones are nil between jobs.
---@class AIBuildBehaviorState
---@field Engineer JoeUnit          # The platoon's primary engineer (the queue claimer).
---@field Base JoeBase              # The base whose `BuildQueueComponent` we're draining.
---@field Job? JoeBuildJob          # The currently-claimed job. Nil when in `WaitForJob`.
---@field Site? JoeBuildSite        # The resolved build site for the current job.
---@field UnitId? UnitId            # The faction-specific unit id resolved from the job's identifier.

--- Queue-driven build behavior. The platoon's engineers loop through jobs from the base's `BuildQueueComponent`, claiming and building one structure at a time. The platoon stays alive between jobs; an empty queue parks it in `WaitForJob`.
---
--- There is no dedicated "Support" squad — engineers in the platoon (any squad) participate in the build via `GetPlatoonUnits`. Other engineers are free to assist via the separate `AssistBehavior`.
---
--- Engineer events: `OnStartBuild` registers the unit with the queue (so assistants and the validation poll can see it); `OnStopBuild` either completes or re-queues the job depending on the unit's state.
---@class AIBuildBehavior : AIPlatoonBehavior
---@field PlatoonBehaviorInput AIBuildBehaviorInput
---@field BehaviorState AIBuildBehaviorState
BuildBehavior = Class(AIPlatoonBehavior) {
    BehaviorName = 'BuildBehavior',

    -----------------------------------------------------------------------------
    -- Bootstrap

    Start = State {
        BehaviorStateName = 'Start',
        BehaviorStateColor = 'ffffff',

        ---@param self AIBuildBehavior
        Main = function(self)
            local engineers = self:GetPlatoonUnits()
            local engineer = engineers[1] --[[@as JoeUnit]]
            if not engineer or not engineer.JoeData or not engineer.JoeData.Base then
                self:Warn('Engineer has no base assigned')
                self:ChangeState(self.Error)
                return
            end

            self.BehaviorState.Engineer = engineer
            self.BehaviorState.Base = engineer.JoeData.Base

            IssueClearCommands(engineers)
            self:ChangeState(self.AcquireJob)
        end,
    },

    -----------------------------------------------------------------------------
    -- Main loop: claim → site → build → loop

    AcquireJob = State {
        BehaviorStateName = 'AcquireJob',
        BehaviorStateColor = '88ddff',

        ---@param self AIBuildBehavior
        Main = function(self)
            local engineer = self.BehaviorState.Engineer
            local base = self.BehaviorState.Base

            local job = base.BuildQueueComponent:ClaimJob(engineer)

            if not job then
                self:ChangeState(self.WaitForJob)
                return
            end

            self.BehaviorState.Job = job
            self:ChangeState(self.AcquireSite)
        end,
    },

    WaitForJob = State {
        BehaviorStateName = 'WaitForJob',
        BehaviorStateColor = '444488',

        ---@param self AIBuildBehavior
        Main = function(self)
            WaitTicks(50)
            self:ChangeState(self.AcquireJob)
        end,
    },

    AcquireSite = State {
        BehaviorStateName = 'AcquireSite',
        BehaviorStateColor = 'ffaa00',

        ---@param self AIBuildBehavior
        Main = function(self)
            -- Job is non-nil here: we only enter this state via AcquireJob's success path.
            local job = self.BehaviorState.Job --[[@as JoeBuildJob]]
            local base = self.BehaviorState.Base
            local engineer = self.BehaviorState.Engineer
            local brain = self:GetBrain()

            -- resolve the faction-specific structure once for this engineer; we need it to sanity-check the site below
            local unitId = ResolveUnitIdForBuilder(job.Spec.Identifier, engineer)
            if not unitId then
                self:Warn('No faction-specific unit for ' .. tostring(job.Spec.Identifier))
                base.BuildQueueComponent:FailJob(job, false)
                self:ChangeState(self.AcquireJob)
                return
            end

            local blueprint = __blueprints[unitId]
            if not blueprint then
                self:Warn('No blueprint for ' .. tostring(unitId))
                base.BuildQueueComponent:FailJob(job, false)
                self:ChangeState(self.AcquireJob)
                return
            end

            self.BehaviorState.UnitId = unitId

            -- TODO: thread job.Spec.LocationHint through so the BFS biases toward it.
            local sites = base:AcquireBuildSitesForIdentifier(job.Spec.Identifier)
            if table.empty(sites) then
                self:Warn('No build site for ' .. tostring(job.Spec.Identifier))
                base.BuildQueueComponent:FailJob(job, false)
                self:ChangeState(self.AcquireJob)
                return
            end

            -- pick the most preferred candidate, then sanity-check it. If the engine refuses (terrain, occupation grid), disable the site and try again — `AcquireBuildSitesForIdentifier` will skip blocked sites on the next call, so the next iteration picks a different candidate. The full overlap pass in `UnitUtils.ValidateBuildSite` runs later in the build flow.
            local site = SelectBuildSite(sites, engineer)
            local location = { site.Point[1], 0, site.Point[2] }
            if not brain:CanBuildStructureAt(unitId, location) then
                site:Block()
                self:ChangeState(self.AcquireSite)
                return
            end

            base.BuildQueueComponent:RegisterBuildSite(job, site)
            self.BehaviorState.Site = site

            self:ChangeState(self.ClearBuildSite)
        end,
    },

    ClearBuildSite = State {
        BehaviorStateName = 'ClearBuildSite',
        BehaviorStateColor = 'ff8800',

        ---@param self AIBuildBehavior
        Main = function(self)
            -- Site and UnitId are non-nil here: AcquireSite resolved them before transitioning in.
            local site = self.BehaviorState.Site --[[@as JoeBuildSite]]
            local engineer = self.BehaviorState.Engineer
            local unitId = self.BehaviorState.UnitId --[[@as UnitId]]
            local blueprint = __blueprints[unitId]

            local tx = site.Point[1]
            local tz = site.Point[2]
            local sideLength = 0.5 * math.max(blueprint.SizeX, blueprint.SizeZ)

            -- clear obstructing reclaim props near the build site
            local ox, _, oz = engineer:GetPositionXYZ()
            local props = ReclaimBuilder.FromArea(tx, tz, sideLength)
                :ReduceToBuildObstructing()
                :SortByDistanceXZ(ox, oz)
                :End()
            local engineers = self:GetPlatoonUnits()
            ReclaimUtils.IssueReclaimAtDistance(engineers, props, 5)

            -- shoo away any friendly mobile units sitting on the build site
            Orders.IssueClearArea(engineer.Army --[[@as number]], tx, tz, sideLength)

            -- issue the actual build order
            local target = { tx, GetSurfaceHeight(tx, tz), tz }
            IssueBuildAllMobile(engineers, target, unitId, {})

            self:ChangeState(self.WaitForConstruction)
        end,
    },

    WaitForConstruction = State {
        BehaviorStateName = 'WaitForConstruction',
        BehaviorStateColor = '00ff88',

        ---@param self AIBuildBehavior
        Main = function(self)
            -- engineer events drive the transitions; just sleep
            WaitTicks(10)
        end,

        --- Fires when the engineer begins constructing a target. Hook the live unit into the queue so assistants and the validation poll can find it.
        ---@param self AIBuildBehavior
        ---@param unit JoeUnit
        ---@param target Unit
        ---@param order string
        OnStartBuild = function(self, unit, target, order)
            -- Job is non-nil while in WaitForConstruction.
            local job = self.BehaviorState.Job --[[@as JoeBuildJob]]
            local base = self.BehaviorState.Base
            base.BuildQueueComponent:RegisterUnit(job, target --[[@as JoeUnit]])
        end,

        --- Fires when the engineer stops building (success, interruption, or target lost). Distinguish the cases via the target's fraction-complete and destroyed flags.
        ---@param self AIBuildBehavior
        ---@param unit JoeUnit
        ---@param target Unit
        ---@param order string
        OnStopBuild = function(self, unit, target, order)
            -- Job is non-nil while in WaitForConstruction.
            local job = self.BehaviorState.Job --[[@as JoeBuildJob]]
            local base = self.BehaviorState.Base

            if (not target) or IsDestroyed(target) or target.Dead then
                self:Warn('Build target destroyed mid-construction')
                base.BuildQueueComponent:FailJob(job, true)
                self:ChangeState(self.AcquireJob)
                return
            end

            if target:GetFractionComplete() < 1.0 then
                self:Log('Build interrupted (fraction < 1)')
                base.BuildQueueComponent:FailJob(job, true)
                self:ChangeState(self.AcquireJob)
                return
            end

            base.BuildQueueComponent:CompleteJob(job)
            self:ChangeState(self.AcquireJob)
        end,
    },
}
