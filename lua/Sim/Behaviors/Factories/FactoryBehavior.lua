local AIPlatoonBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBehavior.lua").AIPlatoonBehavior

--- Resolves a `JoeProductionJobSpec` plus a factory to a concrete UnitId for that factory's faction. Intersects `Spec.Category * Spec.TechPreference * categories[<factory's faction>]` and returns the first matching blueprint, or nil if no blueprint satisfies the intersection. Mirrors `ResolveUnitIdForBuilder` in [Engineers/BuildBehavior.lua](../Engineers/BuildBehavior.lua) — the same role-shaped→blueprint-shaped resolution, but the spec describes a unit category instead of a building identifier.
---@param spec JoeProductionJobSpec
---@param factory JoeUnit
---@return UnitId?
local function ResolveUnitIdForFactory(spec, factory)
    local faction = factory:GetBlueprint().FactionCategory
    local factionCategory = categories[faction] or categories.ALLUNITS
    local resolved = spec.Category * spec.TechPreference * factionCategory
    return EntityCategoryGetUnitList(resolved)[1]
end

--- Read-only input parameters supplied by the platoon builder before `Start` runs.
---@class AIFactoryBehaviorInput : AIPlatoonBehaviorInput

--- Per-factory-behavior runtime state. Stashed on `self.BehaviorState` so a state's `Main` can read what previous states resolved without recomputing.
---@class AIFactoryBehaviorState
---@field Factory JoeUnit            # The factory unit producing for this platoon.
---@field Base JoeBase               # The base whose `ProductionQueueComponent` we're draining.
---@field Job? JoeProductionJob      # The currently-claimed job. Nil when in `WaitForJob`.
---@field UnitId? UnitId             # The faction-specific unit id resolved from the job's spec.

--- Queue-driven factory behavior. The platoon's factory loops through jobs from the base's `ProductionQueueComponent`, claiming and producing one unit at a time. The platoon stays alive between jobs; an empty (or unsatisfiable) queue parks it in `WaitForJob`.
---
--- Job claim is filtered by a faction-aware resolution check: the factory only claims jobs whose `Spec.Category * Spec.TechPreference * categories[<faction>]` resolves to at least one buildable blueprint, so faction-incompatible specs (e.g. an Aeon-only category sitting in the queue while only a Cybran factory is available) stay pending until something else can fulfil them.
---
--- Factory events: `OnStartBuild` registers the produced unit on the job; `OnStopBuild` either completes or re-queues the job depending on the unit's state.
---@class AIFactoryBehavior : AIPlatoonBehavior
---@field PlatoonBehaviorInput AIFactoryBehaviorInput
---@field BehaviorState AIFactoryBehaviorState
FactoryBehavior = Class(AIPlatoonBehavior) {
    BehaviorName = 'FactoryBehavior',

    -----------------------------------------------------------------------------
    -- Bootstrap

    Start = State {
        BehaviorStateName = 'Start',
        BehaviorStateColor = 'ffffff',

        ---@param self AIFactoryBehavior
        Main = function(self)
            local supportSquad = self:GetSquadUnits('Support')
            local factory = supportSquad[1] --[[@as JoeUnit]]
            if not factory or not factory.JoeData or not factory.JoeData.Base then
                self:Warn('Factory has no base assigned')
                self:ChangeState(self.Error)
                return
            end

            self.BehaviorState.Factory = factory
            self.BehaviorState.Base = factory.JoeData.Base

            IssueClearCommands(supportSquad)
            self:ChangeState(self.AcquireJob)
        end,
    },

    -----------------------------------------------------------------------------
    -- Main loop: claim → produce → loop

    AcquireJob = State {
        BehaviorStateName = 'AcquireJob',
        BehaviorStateColor = '88ddff',

        ---@param self AIFactoryBehavior
        Main = function(self)
            local factory = self.BehaviorState.Factory
            local base = self.BehaviorState.Base

            local job = base.ProductionQueueComponent:ClaimJob(factory, function(candidate, claimingFactory)
                return ResolveUnitIdForFactory(candidate.Spec, claimingFactory) ~= nil
            end)

            if not job then
                self:ChangeState(self.WaitForJob)
                return
            end

            -- Re-resolve so the produce state has the UnitId without re-running the predicate.
            self.BehaviorState.Job = job
            self.BehaviorState.UnitId = ResolveUnitIdForFactory(job.Spec, factory)
            self:ChangeState(self.Produce)
        end,
    },

    WaitForJob = State {
        BehaviorStateName = 'WaitForJob',
        BehaviorStateColor = '444488',

        ---@param self AIFactoryBehavior
        Main = function(self)
            WaitTicks(50)
            self:ChangeState(self.AcquireJob)
        end,
    },

    Produce = State {
        BehaviorStateName = 'Produce',
        BehaviorStateColor = 'ffaa00',

        ---@param self AIFactoryBehavior
        Main = function(self)
            -- Factory and UnitId are non-nil here: AcquireJob's success path resolved both before transitioning in.
            local factory = self.BehaviorState.Factory
            local unitId = self.BehaviorState.UnitId --[[@as UnitId]]

            IssueBuildFactory({ factory }, unitId, 1)
            self:ChangeState(self.WaitForCompletion)
        end,
    },

    WaitForCompletion = State {
        BehaviorStateName = 'WaitForCompletion',
        BehaviorStateColor = '00ff88',

        ---@param self AIFactoryBehavior
        Main = function(self)
            -- factory events drive the transitions; just sleep
            WaitTicks(10)
        end,

        --- Fires when the factory begins producing a unit. Hook the live unit into the queue so the validation poll can detect mid-production destruction.
        ---@param self AIFactoryBehavior
        ---@param unit JoeUnit
        ---@param target Unit
        ---@param order string
        OnStartBuild = function(self, unit, target, order)
            -- Job is non-nil while in WaitForCompletion.
            local job = self.BehaviorState.Job --[[@as JoeProductionJob]]
            local base = self.BehaviorState.Base
            base.ProductionQueueComponent:RegisterUnit(job, target --[[@as JoeUnit]])
        end,

        --- Fires when the factory stops producing (success, interruption, or target lost). Distinguish the cases via the target's fraction-complete and destroyed flags.
        ---@param self AIFactoryBehavior
        ---@param unit JoeUnit
        ---@param target Unit
        ---@param order string
        OnStopBuild = function(self, unit, target, order)
            -- Job is non-nil while in WaitForCompletion.
            local job = self.BehaviorState.Job --[[@as JoeProductionJob]]
            local base = self.BehaviorState.Base

            if (not target) or IsDestroyed(target) or target.Dead then
                self:Warn('Production target destroyed mid-production')
                base.ProductionQueueComponent:FailJob(job, true)
                self:ChangeState(self.AcquireJob)
                return
            end

            if target:GetFractionComplete() < 1.0 then
                self:Log('Production interrupted (fraction < 1)')
                base.ProductionQueueComponent:FailJob(job, true)
                self:ChangeState(self.AcquireJob)
                return
            end

            base.ProductionQueueComponent:CompleteJob(job)
            self:ChangeState(self.AcquireJob)
        end,
    },
}
