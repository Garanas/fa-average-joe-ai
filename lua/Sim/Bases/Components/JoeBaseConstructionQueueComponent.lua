local TableInsert = table.insert
local TableGetn = table.getn
local TableRemove = table.remove

local IsDestroyed = IsDestroyed

--- A predicate consulted periodically to decide whether a pending job should be temporarily skipped. Receives the brain, the owning base, and the job; returns true to delay.
---@alias JoeConstructionJobDelayPredicate fun(brain: JoeBrain, base: JoeBase, job: JoeConstructionJob): boolean

--- An immutable description of *what* should be built. Callers construct one of these and push it into a base's queue. Held verbatim on the resulting `JoeConstructionJob` as `job.Spec` so consumers (build / assist behaviors) can inspect the request without reaching into runtime fields.
---
--- One identifier per job — batching multiple identifiers complicates re-queueing (only some structures destroyed) and assist mechanics (which sub-build are we helping?). Push N jobs to build N walls.
---@class JoeConstructionJobSpec
---@field Identifier JoeBuildingIdentifier       # The single structure role to build.
---@field LocationHint? Vector                   # Preferred world position; the build planner may bias toward this.
---@field Priority? number                       # Higher = sooner. Nil treated as 0.
---@field MaxAssistants? number                  # Per-job cap on engineers who may join via `JoinAsAssistant`. Nil falls back to the component default.
---@field DelayPredicate? JoeConstructionJobDelayPredicate  # Periodic check; true means skip for now.

---@alias JoeConstructionJobState
---| 'Pending'     # In the queue, no engineer claimed yet.
---| 'Claimed'     # Engineer claimed but hasn't started construction.
---| 'Building'    # Construction has begun; `Unit` is live.
---| 'Built'       # Structure has finished construction.
---| 'Failed'      # Engineer / build aborted, not requeued.

--- The runtime record for one queued construction job. Wraps the immutable `Spec` with the assignment state the queue mutates as the job progresses. Assistants read `Spec` + `Unit`; the build behavior owns the rest.
---
--- `Engineers` holds every engineer working the job. By convention `Engineers[1]` is the claimer; entries `[2..n]` are assistants joined via `JoinAsAssistant`. The queue does not promote on claimer death — see `FailJob`.
---@class JoeConstructionJob
---@field Spec JoeConstructionJobSpec
---@field State JoeConstructionJobState
---@field Engineers JoeUnit[]                # [1] claimer, [2..n] assistants.
---@field BuildSite? JoeBuildSite            # The resolved build site for this job's structure.
---@field Unit? JoeUnit                      # The structure once `OnStartBuild` fired. Stays set after `Built` so the validation poll can detect destruction.
---@field Delayed boolean                    # Last-evaluated `DelayPredicate` result. `ClaimJob` skips delayed jobs.

--- Per-base construction-job queue. Engineers drain it: each job is a single structure to be built by an engineer (with optional assistants). Holds three arrays:
---  * `Pending`  — unclaimed jobs, available to any engineer's build behavior.
---  * `Active`   — claimed jobs whose engineers are en route, building, or assisting-eligible.
---  * `Complete` — finished jobs (every identifier built, units alive).
---
--- The component is pure storage. Periodic validation is driven by `JoeBase` via the per-state `ValidatePending` / `ValidateClaimed` / `ValidateBuilding` / `ValidateBuilt` methods.
---@class JoeBaseConstructionQueueComponent
---@field Base JoeBase
---@field Pending JoeConstructionJob[]
---@field Active JoeConstructionJob[]
---@field Complete JoeConstructionJob[]
JoeBaseConstructionQueueComponent = ClassSimple {

    --- Default cap on assistants per job. A spec may override via `MaxAssistants`. The cap counts only assistants — the claimer is always allowed.
    DefaultMaxAssistants = 3,

    ---@param self JoeBaseConstructionQueueComponent
    ---@param base JoeBase
    __init = function(self, base)
        self.Base = base
        self.Pending = {}
        self.Active = {}
        self.Complete = {}
    end,

    -----------------------------------------------------------------------------
    --#region Pushing jobs

    --- Wraps a spec in a fresh `JoeConstructionJob` and adds it to `Pending`. Callers don't construct `JoeConstructionJob` directly — pass a spec, get the live job back if you need a handle on it.
    ---@param self JoeBaseConstructionQueueComponent
    ---@param spec JoeConstructionJobSpec
    ---@return JoeConstructionJob
    PushJob = function(self, spec)
        ---@type JoeConstructionJob
        local job = {
            Spec = spec,
            State = 'Pending',
            Engineers = {},
            Delayed = false,
        }
        TableInsert(self.Pending, job)
        return job
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Claiming and tracking (build behavior)

    --- Claims the first eligible non-delayed pending job for `engineer`. The optional `predicate(job, engineer)` filters which jobs the engineer will take. Moves the job from `Pending` to `Active`, transitions to `Claimed`, and inserts the engineer as `Engineers[1]` (the claimer).
    ---@param self JoeBaseConstructionQueueComponent
    ---@param engineer JoeUnit
    ---@param predicate? fun(job: JoeConstructionJob, engineer: JoeUnit): boolean
    ---@return JoeConstructionJob?
    ClaimJob = function(self, engineer, predicate)
        local pending = self.Pending
        for k = 1, TableGetn(pending) do
            local job = pending[k]
            if not job.Delayed and ((not predicate) or predicate(job, engineer)) then
                TableRemove(pending, k)
                job.State = 'Claimed'
                TableInsert(job.Engineers, engineer)
                TableInsert(self.Active, job)
                return job
            end
        end
        return nil
    end,

    --- Records the build site the engineer chose for the *current* structure. Called once the build behavior has resolved a site via `JoeBase:AcquireBuildSitesForUnit` for the next identifier in the list. Marks the site as `Claimed` so other engineers won't pick it before the unit spawns.
    ---@param self JoeBaseConstructionQueueComponent
    ---@param job JoeConstructionJob
    ---@param buildSite JoeBuildSite
    RegisterBuildSite = function(self, job, buildSite)
        job.BuildSite = buildSite
        buildSite.Claimed = true
    end,

    --- Transitions the job into `Building` state with the actual structure unit. Called from the build behavior's `OnStartBuild` event handler. Also wires the unit back to the build site so site state-predicates (`IsBuilding`, `IsBuilt`) reflect reality, and clears the `Claimed` reservation now that `Unit` owns the slot.
    ---@param self JoeBaseConstructionQueueComponent
    ---@param job JoeConstructionJob
    ---@param unit JoeUnit
    RegisterUnit = function(self, job, unit)
        job.State = 'Building'
        job.Unit = unit
        if job.BuildSite then
            job.BuildSite.Unit = unit
            job.BuildSite.Claimed = false
        end
    end,

    --- Marks the job's structure as fully built. State transitions to `Built`, the job moves from `Active` to `Complete`. `Unit` is left in place so the validation poll can detect destruction later. Called from the build behavior's `OnStopBuild` when the structure finishes.
    ---@param self JoeBaseConstructionQueueComponent
    ---@param job JoeConstructionJob
    CompleteJob = function(self, job)
        job.State = 'Built'
        self:RemoveFromActive(job)
        TableInsert(self.Complete, job)
    end,

    --- Marks the job failed. If `requeue` is true, the spec is recycled into a fresh pending job (engineer / site / unit refs cleared). Otherwise the job moves to `Failed` and is dropped.
    ---@param self JoeBaseConstructionQueueComponent
    ---@param job JoeConstructionJob
    ---@param requeue boolean
    FailJob = function(self, job, requeue)
        self:RemoveFromActive(job)

        if job.BuildSite then
            job.BuildSite.Claimed = false
        end

        if requeue then
            job.State = 'Pending'
            job.Engineers = {}
            job.BuildSite = nil
            job.Unit = nil
            TableInsert(self.Pending, job)
        else
            job.State = 'Failed'
        end
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Assisting (assist behavior)

    --- Returns the first active job that is assistable: either `Building` with a live unit (assistants accelerate construction) or `Claimed` with a registered build site (assistants pre-position at the site before construction starts). Optional predicate filters further. Returning the job does *not* register the assistant — call `JoinAsAssistant` after.
    ---@param self JoeBaseConstructionQueueComponent
    ---@param predicate? fun(job: JoeConstructionJob): boolean
    ---@return JoeConstructionJob?
    FindAssistTarget = function(self, predicate)
        local active = self.Active
        for k = 1, TableGetn(active) do
            local job = active[k]

            -- 'Building' jobs need a live unit; 'Claimed' jobs need a registered build site (assistants pre-position there before construction starts).
            local assistable = false
            if job.State == 'Building' and job.Unit and not IsDestroyed(job.Unit) then
                assistable = true
            elseif job.State == 'Claimed' and job.BuildSite then
                assistable = true
            end

            if assistable
                and self:GetAssistantCount(job) < self:GetMaxAssistants(job)
                and ((not predicate) or predicate(job))
            then
                return job
            end
        end
        return nil
    end,

    --- Adds `engineer` to the job's engineer list as an assistant. Returns false if the job is already at its assistant cap.
    ---@param self JoeBaseConstructionQueueComponent
    ---@param job JoeConstructionJob
    ---@param engineer JoeUnit
    ---@return boolean
    JoinAsAssistant = function(self, job, engineer)
        if self:GetAssistantCount(job) >= self:GetMaxAssistants(job) then
            return false
        end
        TableInsert(job.Engineers, engineer)
        return true
    end,

    --- Removes `engineer` from the job's engineer list. Returns true if a removal happened. Use when an engineer abandons assisting (death, re-tasking).
    ---@param self JoeBaseConstructionQueueComponent
    ---@param job JoeConstructionJob
    ---@param engineer JoeUnit
    ---@return boolean
    LeaveJob = function(self, job, engineer)
        local engineers = job.Engineers
        for k = 1, TableGetn(engineers) do
            if engineers[k] == engineer then
                TableRemove(engineers, k)
                return true
            end
        end
        return false
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Accessors

    --- Returns the engineer that originally claimed the job, or nil if the job has no engineers (e.g. just-failed-and-being-cleared).
    ---@param self JoeBaseConstructionQueueComponent
    ---@param job JoeConstructionJob
    ---@return JoeUnit?
    GetClaimer = function(self, job)
        return job.Engineers[1]
    end,

    --- Returns how many assistants are currently registered on the job. The claimer is excluded from the count.
    ---@param self JoeBaseConstructionQueueComponent
    ---@param job JoeConstructionJob
    ---@return number
    GetAssistantCount = function(self, job)
        local n = TableGetn(job.Engineers)
        if n == 0 then
            return 0
        end
        return n - 1
    end,

    --- Returns the assistant cap that applies to the job — its spec override if set, else the component default.
    ---@param self JoeBaseConstructionQueueComponent
    ---@param job JoeConstructionJob
    ---@return number
    GetMaxAssistants = function(self, job)
        return job.Spec.MaxAssistants or self.DefaultMaxAssistants
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Debug logging

    --- Dumps the queue contents to the log, one line per job across pending/active/complete, prefixed with the base id via `JoeBase:Log`. Cheap to call ad-hoc; not cheap enough to call per tick.
    ---@param self JoeBaseConstructionQueueComponent
    LogState = function(self)
        local base = self.Base
        local pending = self.Pending
        local active = self.Active
        local complete = self.Complete
        base:Log(string.format("ConstructionQueue: pending=%d active=%d complete=%d",
            TableGetn(pending), TableGetn(active), TableGetn(complete)))
        for k = 1, TableGetn(pending) do
            local job = pending[k]
            base:Log(string.format("  pending[%d] id=%s priority=%s delayed=%s",
                k, tostring(job.Spec.Identifier), tostring(job.Spec.Priority or 0),
                tostring(job.Delayed)))
        end
        for k = 1, TableGetn(active) do
            local job = active[k]
            base:Log(string.format("  active[%d] id=%s state=%s engineers=%d",
                k, tostring(job.Spec.Identifier), job.State, TableGetn(job.Engineers)))
        end
        for k = 1, TableGetn(complete) do
            local job = complete[k]
            base:Log(string.format("  complete[%d] id=%s",
                k, tostring(job.Spec.Identifier)))
        end
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Per-state validation
    -- These methods are pure-storage maintenance: each handles the invariants of a single job state. `JoeBase` orchestrates the order in which they run from its own polling loop.

    --- Walks `Pending` and refreshes each job's `Delayed` flag by re-evaluating the spec's `DelayPredicate` (jobs without a predicate are always not-delayed). Lets brain/base condition changes unblock or pause queued work without callers having to push/pop jobs.
    ---@param self JoeBaseConstructionQueueComponent
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

    --- Walks `Active` in reverse and fails (with requeue) any job in `Claimed` state whose claimer engineer is gone. The job's spec returns to `Pending`; another engineer can pick it up. Reverse iteration keeps `FailJob`'s `RemoveFromActive` from breaking the index.
    ---@param self JoeBaseConstructionQueueComponent
    ValidateClaimed = function(self)
        local active = self.Active
        for k = TableGetn(active), 1, -1 do
            local job = active[k]
            if job.State == 'Claimed' then
                local claimer = job.Engineers[1]
                if (not claimer) or IsDestroyed(claimer) then
                    self:FailJob(job, true)
                end
            end
        end
    end,

    --- Walks `Active` in reverse and fails (with requeue) any job in `Building` state whose structure unit has been destroyed mid-construction. Reverse iteration keeps `FailJob`'s `RemoveFromActive` from breaking the index.
    ---@param self JoeBaseConstructionQueueComponent
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

    --- Walks `Complete` in reverse and re-queues any entry whose finished unit has since been destroyed (e.g. enemy fire took it down after `Built` transitioned). Reverse iteration keeps `TableRemove`'s shifting from breaking the index.
    ---@param self JoeBaseConstructionQueueComponent
    ValidateBuilt = function(self)
        local complete = self.Complete
        for k = TableGetn(complete), 1, -1 do
            local job = complete[k]
            local unit = job.Unit

            if (not unit) or IsDestroyed(unit) then
                TableRemove(complete, k)

                -- reset runtime state and requeue
                if job.BuildSite then
                    job.BuildSite.Claimed = false
                end
                job.State = 'Pending'
                job.Engineers = {}
                job.BuildSite = nil
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
    ---@param self JoeBaseConstructionQueueComponent
    ---@param job JoeConstructionJob
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
