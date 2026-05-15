local AIPlatoonBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBehavior.lua").AIPlatoonBehavior

local TableGetn = table.getn

--- Resolves a `JoeProductionJobSpec` plus a factory to a concrete UnitId for that factory. Intersects `Spec.Category * categories[<factory's FactionCategory>] * categories[<factory's TechCategory>]` and returns the first matching blueprint, or nil if no blueprint satisfies the intersection. The tier filter is the *factory's* `TechCategory`, not `Spec.TechPreference` — preference influences ordering (see `AcquireJob`), not the concrete blueprint we actually build. Mirrors `ResolveUnitIdForBuilder` in [Engineers/BuildBehavior.lua](../Engineers/BuildBehavior.lua) — same role-shaped→blueprint-shaped resolution, but the spec describes a unit category instead of a building identifier.
---@param spec JoeProductionJobSpec
---@param factory JoeUnit
---@return UnitId?
local function ResolveUnitIdForFactory(spec, factory)
    local blueprint = factory:GetBlueprint()
    local factionCategory = categories[blueprint.FactionCategory] or categories.ALLUNITS
    local techCategory = categories[blueprint.TechCategory] or categories.ALLUNITS
    local resolved = spec.Category * factionCategory * techCategory
    return EntityCategoryGetUnitList(resolved)[1]
end

--- Read-only input parameters supplied by the platoon builder before `Start` runs.
---@class AIFactoryBehaviorInput : AIPlatoonBehaviorInput

--- Per-factory-behavior runtime state. Stashed on `self.BehaviorState` so a state's `Main` can read what previous states resolved without recomputing.
---@class AIFactoryBehaviorState
---@field Factory JoeUnit                  # The factory unit producing for this platoon.
---@field Base JoeBase                     # The base whose `ProductionQueueComponent` we're draining.
---@field Job? JoeProductionJob            # The currently-claimed job. Nil when in `WaitForJob`.
---@field UnitId? UnitId                   # The faction-specific unit id resolved from the job's spec.
---@field EligibleCache? JoeProductionJob[]  # Scratch table reused across `AcquireJob` iterations so `CollectEligibleFor` doesn't allocate a fresh eligible list on every poll. Allocated on first call.

--- Queue-driven factory behavior. The platoon's factory loops through jobs from the base's `ProductionQueueComponent`, claiming and producing one unit at a time. The platoon stays alive between jobs; an empty (or unsatisfiable) queue parks it in `WaitForJob`.
---
--- Job selection runs in two stages:
---  * eligibility — `CollectEligibleFor` returns jobs whose `Spec.Category` resolves to ≥1 unit when intersected with the factory's faction and tech tier; faction- or tier-incompatible specs (e.g. an Aeon-only category while only a Cybran factory is available) stay pending.
---  * preference — this behavior picks the eligible job whose `Spec.TechPreference` equals the factory's own `TechCategory` if one exists, otherwise the first eligible job. Preference influences ordering, never eligibility — a TECH2 spec is still built by a T1 factory (at T1) if nothing better is available.
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
            local queue = base.ProductionQueueComponent

            -- Ask the queue for everything we *could* build. Eligibility (faction + tech intersection) is the queue's job; preference ordering is ours.
            local eligible = queue:CollectEligibleFor(factory, self.BehaviorState.EligibleCache)
            self.BehaviorState.EligibleCache = eligible

            local eligibleCount = TableGetn(eligible)
            if eligibleCount == 0 then
                self:ChangeState(self.WaitForJob)
                return
            end

            -- Preference: prefer jobs whose TechPreference matches the factory's own TechCategory (e.g. a T2 factory facing both a TECH1 and a TECH2 spec picks TECH2). Anything unmatched falls back to the first eligible job, so a tier mismatch never strands work.
            local factoryTech = factory:GetBlueprint().TechCategory
            local pick = eligible[1]
            if pick.Spec.TechPreference ~= factoryTech then
                for k = 2, eligibleCount do
                    local candidate = eligible[k]
                    if candidate.Spec.TechPreference == factoryTech then
                        pick = candidate
                        break
                    end
                end
            end

            local job = queue:ClaimJob(pick, factory)
            if not job then
                -- Raced with another factory between collect and claim — fall back to waiting; the next poll will re-collect.
                self:ChangeState(self.WaitForJob)
                return
            end

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
