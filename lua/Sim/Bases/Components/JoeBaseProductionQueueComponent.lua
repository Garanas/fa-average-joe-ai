local TableInsert = table.insert
local TableGetn = table.getn
local TableRemove = table.remove
local TableSetn = table.setn

local IsDestroyed = IsDestroyed

--- A predicate consulted periodically to decide whether a pending job should be temporarily skipped. Receives the brain, the owning base, and the job; returns true to delay.
---@alias JoeProductionJobDelayPredicate fun(brain: JoeBrain, base: JoeBase, job: JoeProductionJob): boolean

--- An immutable description of *what* should be produced. Callers construct one of these and push it into a base's production queue. Held verbatim on the resulting `JoeProductionJob` as `job.Spec` so consumers (factory behaviors) can inspect the request without reaching into runtime fields.
---
--- The spec is **role-shaped, not blueprint-shaped**: callers describe the unit they want as a category (e.g. `categories.MOBILE * categories.LAND * categories.DIRECTFIRE`) plus a preferred tech tier (the `TechCategory` string the factory's own blueprint would carry). Two stages process the spec:
---  * eligibility — `CollectEligibleFor` intersects `Spec.Category` with the factory's `FactionCategory` and `TechCategory`; the job is eligible iff that intersection has ≥1 buildable unit.
---  * preference — the factory behavior sorts eligible jobs so those whose `TechPreference` equals the factory's own `TechCategory` come first. A T2 factory presented with a TECH1 and a TECH2 spec will pick the TECH2 one. A T1 factory presented with only a TECH2 spec will still build it — at T1 — so a job doesn't sit forever if no matching-tier factory exists.
---
--- One unit per job — a quantity field would complicate re-queueing (only some units lost) and factory-claim mechanics (which sub-build are we tracking?). Push N jobs to produce N units.
---@class JoeProductionJobSpec
---@field Category EntityCategory                # Selects matching unit blueprints. Intersected with the producing factory's faction and tech for eligibility.
---@field TechPreference TechCategory            # Preferred tech tier as the `TechCategory` string (e.g. `'TECH1'`, `'TECH2'`). Compared verbatim against the factory's blueprint `TechCategory` for preference ordering; *not* a hard filter — see the class comment.
---@field LocationHint? Vector                   # Preferred world position; the factory selector may bias toward factories near this point.
---@field Priority? number                       # Higher = sooner. Nil treated as 0.
---@field DelayPredicate? JoeProductionJobDelayPredicate  # Periodic check; true means skip for now.

---@alias JoeProductionJobState
---| 'Pending'     # In the queue, no factory claimed yet.
---| 'Claimed'     # Factory claimed but hasn't started producing yet.
---| 'Building'    # Production has begun; `Unit` is live.
---| 'Built'       # Unit has finished production.
---| 'Failed'      # Factory / production aborted, not requeued.

--- The runtime record for one queued production job. Wraps the immutable `Spec` with the assignment state the queue mutates as the job progresses. The factory behavior owns most field writes.
---
--- Production has a single producer (the claiming factory) — there is no assistant slot here. Engine-side factory-assist (engineers helping a factory) is a different mechanic and is not tracked through this queue.
---@class JoeProductionJob
---@field Spec JoeProductionJobSpec
---@field State JoeProductionJobState
---@field Factory? JoeUnit                   # The factory that claimed the job. Set on `ClaimJob`, cleared on requeue.
---@field Unit? JoeUnit                      # The produced unit once `OnStartBuild` fired. Stays set after `Built` so the validation poll can detect destruction.
---@field Delayed boolean                    # Last-evaluated `DelayPredicate` result. `ClaimJob` skips delayed jobs.

--- Per-base production-job queue. Factories drain it: each job is a single mobile unit (engineer, tank, gunship, …) to be produced by one factory. Holds three arrays:
---  * `Pending`  — unclaimed jobs, available to any factory's behavior.
---  * `Active`   — claimed jobs whose factory is en route to producing or actively producing.
---  * `Complete` — finished jobs (unit produced and alive).
---
--- The component is pure storage. Periodic validation is driven by `JoeBase` via the per-state `ValidatePending` / `ValidateClaimed` / `ValidateBuilding` / `ValidateBuilt` methods.
---@class JoeBaseProductionQueueComponent
---@field Base JoeBase
---@field Pending JoeProductionJob[]
---@field Active JoeProductionJob[]
---@field Complete JoeProductionJob[]
JoeBaseProductionQueueComponent = ClassSimple {

    ---@param self JoeBaseProductionQueueComponent
    ---@param base JoeBase
    __init = function(self, base)
        self.Base = base
        self.Pending = {}
        self.Active = {}
        self.Complete = {}
    end,

    -----------------------------------------------------------------------------
    --#region Pushing jobs

    --- Wraps a spec in a fresh `JoeProductionJob` and adds it to `Pending`. Callers don't construct `JoeProductionJob` directly — pass a spec, get the live job back if you need a handle on it.
    ---@param self JoeBaseProductionQueueComponent
    ---@param spec JoeProductionJobSpec
    ---@return JoeProductionJob
    PushJob = function(self, spec)
        ---@type JoeProductionJob
        local job = {
            Spec = spec,
            State = 'Pending',
            Delayed = false,
        }
        TableInsert(self.Pending, job)
        return job
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Claiming and tracking (factory behavior)

    --- Collects every non-delayed pending job the `factory` can actually build into `cache`. Eligibility is purely a category intersection: `Spec.Category * categories[factory.FactionCategory] * categories[factory.TechCategory]` must resolve to ≥1 unit. The cache is cleared first and returned for chaining (caller-supplied-cache convention — see `Sim/CLAUDE.md` §3.2). Pass a reused table to avoid allocations on hot paths; pass nil to allocate a fresh one.
    ---
    --- Eligibility only — selection (which of the eligible jobs to claim) and tech-preference ordering live in the consuming behavior. `Spec.TechPreference` is intentionally *not* consulted here: a job tagged `TECH2` is still eligible for a T1 factory, so it doesn't sit forever if no matching-tier factory exists.
    ---@param self JoeBaseProductionQueueComponent
    ---@param factory JoeUnit
    ---@param cache? JoeProductionJob[]
    ---@return JoeProductionJob[]
    CollectEligibleFor = function(self, factory, cache)
        cache = cache or {}
        TableSetn(cache, 0)

        local blueprint = factory:GetBlueprint()
        local factionCategory = categories[blueprint.FactionCategory] or categories.ALLUNITS
        local techCategory = categories[blueprint.TechCategory] or categories.ALLUNITS
        local factoryFilter = factionCategory * techCategory

        local pending = self.Pending
        for k = 1, TableGetn(pending) do
            local job = pending[k]
            if not job.Delayed and EntityCategoryGetUnitList(job.Spec.Category * factoryFilter)[1] then
                TableInsert(cache, job)
            end
        end

        return cache
    end,

    --- Claims a specific `job` for `factory`. Pure state management: moves the job from `Pending` to `Active`, transitions it to `Claimed`, and records the factory. Returns the job on success; returns nil if the job was no longer in `Pending` (e.g. another factory claimed it between the caller's `CollectEligibleFor` and this call).
    ---
    --- Selection — which job out of the eligible set — lives in the factory behavior. This method only mutates internal state.
    ---@param self JoeBaseProductionQueueComponent
    ---@param job JoeProductionJob
    ---@param factory JoeUnit
    ---@return JoeProductionJob?
    ClaimJob = function(self, job, factory)
        local pending = self.Pending
        for k = 1, TableGetn(pending) do
            if pending[k] == job then
                TableRemove(pending, k)
                job.State = 'Claimed'
                job.Factory = factory
                TableInsert(self.Active, job)
                return job
            end
        end
        return nil
    end,

    --- Transitions the job into `Building` state with the actual produced unit. Called from the factory behavior's `OnStartBuild` event handler.
    ---@param self JoeBaseProductionQueueComponent
    ---@param job JoeProductionJob
    ---@param unit JoeUnit
    RegisterUnit = function(self, job, unit)
        job.State = 'Building'
        job.Unit = unit
    end,

    --- Marks the job's unit as fully produced. State transitions to `Built`, the job moves from `Active` to `Complete`. `Unit` is left in place so the validation poll can detect destruction later. Called from the factory behavior's `OnStopBuild` when the unit finishes.
    ---@param self JoeBaseProductionQueueComponent
    ---@param job JoeProductionJob
    CompleteJob = function(self, job)
        job.State = 'Built'
        self:RemoveFromActive(job)
        TableInsert(self.Complete, job)
    end,

    --- Marks the job failed. If `requeue` is true, the spec is recycled into a fresh pending job (factory / unit refs cleared). Otherwise the job moves to `Failed` and is dropped.
    ---@param self JoeBaseProductionQueueComponent
    ---@param job JoeProductionJob
    ---@param requeue boolean
    FailJob = function(self, job, requeue)
        self:RemoveFromActive(job)

        if requeue then
            job.State = 'Pending'
            job.Factory = nil
            job.Unit = nil
            TableInsert(self.Pending, job)
        else
            job.State = 'Failed'
        end
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Accessors

    --- Returns the factory that currently holds the job, or nil if none is registered (e.g. just-failed-and-being-cleared).
    ---@param self JoeBaseProductionQueueComponent
    ---@param job JoeProductionJob
    ---@return JoeUnit?
    GetFactory = function(self, job)
        return job.Factory
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Debug logging

    --- Dumps the queue contents to the log, one line per job across pending/active/complete, prefixed with the base id via `JoeBase:Log`. Cheap to call ad-hoc; not cheap enough to call per tick.
    ---@param self JoeBaseProductionQueueComponent
    LogState = function(self)
        local base = self.Base
        local pending = self.Pending
        local active = self.Active
        local complete = self.Complete
        base:Log(string.format("ProductionQueue: pending=%d active=%d complete=%d",
            TableGetn(pending), TableGetn(active), TableGetn(complete)))
        for k = 1, TableGetn(pending) do
            local job = pending[k]
            base:Log(string.format("  pending[%d] category=%s tech=%s priority=%s delayed=%s",
                k, tostring(job.Spec.Category), tostring(job.Spec.TechPreference),
                tostring(job.Spec.Priority or 0), tostring(job.Delayed)))
        end
        for k = 1, TableGetn(active) do
            local job = active[k]
            local unitId = (job.Unit and job.Unit:GetUnitId()) or "?"
            base:Log(string.format("  active[%d] state=%s factory=%s unit=%s",
                k, job.State, tostring(job.Factory), tostring(unitId)))
        end
        for k = 1, TableGetn(complete) do
            local job = complete[k]
            local unitId = (job.Unit and job.Unit:GetUnitId()) or "?"
            base:Log(string.format("  complete[%d] unit=%s", k, tostring(unitId)))
        end
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Per-state validation
    -- These methods are pure-storage maintenance: each handles the invariants of a single job state. `JoeBase` orchestrates the order in which they run from its own polling loop.

    --- Walks `Pending` and refreshes each job's `Delayed` flag by re-evaluating the spec's `DelayPredicate` (jobs without a predicate are always not-delayed). Lets brain/base condition changes unblock or pause queued work without callers having to push/pop jobs.
    ---@param self JoeBaseProductionQueueComponent
    ValidatePending = function(self)
        local brain = self.Base.Brain
        local pending = self.Pending
        for k = 1, TableGetn(pending) do
            local job = pending[k]
            local predicate = job.Spec.DelayPredicate
            if predicate then
                job.Delayed = predicate(brain, self.Base, job)
            else
                job.Delayed = false
            end
        end
    end,

    --- Walks `Active` in reverse and fails (with requeue) any job in `Claimed` state whose factory is gone. The job's spec returns to `Pending`; another factory can pick it up. Reverse iteration keeps `FailJob`'s `RemoveFromActive` from breaking the index.
    ---@param self JoeBaseProductionQueueComponent
    ValidateClaimed = function(self)
        local active = self.Active
        for k = TableGetn(active), 1, -1 do
            local job = active[k]
            if job.State == 'Claimed' then
                local factory = job.Factory
                if (not factory) or IsDestroyed(factory) then
                    self:FailJob(job, true)
                end
            end
        end
    end,

    --- Walks `Active` in reverse and fails (with requeue) any job in `Building` state whose unit has been destroyed mid-production (e.g. the factory was destroyed and the unit died with it). Reverse iteration keeps `FailJob`'s `RemoveFromActive` from breaking the index.
    ---@param self JoeBaseProductionQueueComponent
    ValidateBuilding = function(self)
        local active = self.Active
        for k = TableGetn(active), 1, -1 do
            local job = active[k]
            if job.State == 'Building' then
                local unit = job.Unit
                if (not unit) or IsDestroyed(unit) then
                    self:FailJob(job, true)
                end
            end
        end
    end,

    --- Walks `Complete` in reverse and re-queues any entry whose finished unit has since been destroyed. Reverse iteration keeps `TableRemove`'s shifting from breaking the index.
    ---@param self JoeBaseProductionQueueComponent
    ValidateBuilt = function(self)
        local complete = self.Complete
        for k = TableGetn(complete), 1, -1 do
            local job = complete[k]
            local unit = job.Unit

            if (not unit) or IsDestroyed(unit) then
                TableRemove(complete, k)

                -- reset runtime state and requeue
                job.State = 'Pending'
                job.Factory = nil
                job.Unit = nil
                job.Delayed = false
                TableInsert(self.Pending, job)
            end
        end
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Internal helpers

    --- Linear-scan removal from `Active`. Keep private; callers go through `CompleteJob` / `FailJob` so the state field stays consistent with list membership.
    ---@param self JoeBaseProductionQueueComponent
    ---@param job JoeProductionJob
    RemoveFromActive = function(self, job)
        local active = self.Active
        for k = 1, TableGetn(active) do
            if active[k] == job then
                TableRemove(active, k)
                return
            end
        end
    end,

    --#endregion
}
