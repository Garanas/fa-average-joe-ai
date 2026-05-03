local TableInsert = table.insert
local TableGetn = table.getn
local TableRemove = table.remove

--- A predicate consulted periodically to decide whether a pending job should be temporarily skipped. Receives the brain, the owning base, and the job; returns true to delay.
---@alias JoeBuildJobDelayPredicate fun(brain: JoeBrain, base: JoeBase, job: JoeBuildJob): boolean

--- An immutable description of *what* should be built. Callers construct one of these and push it into a base's queue. Held verbatim on the resulting `JoeBuildJob` as `job.Spec` so consumers (build / assist behaviors) can inspect the request without reaching into runtime fields.
---
--- One identifier per job — batching multiple identifiers complicates re-queueing (only some structures destroyed) and assist mechanics (which sub-build are we helping?). Push N jobs to build N walls.
---@class JoeBuildJobSpec
---@field Identifier JoeBuildingIdentifier       # The single structure role to build.
---@field LocationHint? Vector                   # Preferred world position; the build planner may bias toward this.
---@field Priority? number                       # Higher = sooner. Nil treated as 0.
---@field MaxAssistants? number                  # Per-job cap on engineers who may join via `JoinAsAssistant`. Nil falls back to the component default.
---@field DelayPredicate? JoeBuildJobDelayPredicate  # Periodic check; true means skip for now.

---@alias JoeBuildJobState
---| 'Pending'     # In the queue, no engineer claimed yet.
---| 'Claimed'     # Engineer claimed but hasn't started construction.
---| 'Building'    # Construction has begun; `Unit` is live.
---| 'Built'       # Structure has finished construction.
---| 'Failed'      # Engineer / build aborted, not requeued.

--- The runtime record for one queued build. Wraps the immutable `Spec` with the assignment state the queue mutates as the job progresses. Assistants read `Spec` + `Unit`; the build behavior owns the rest.
---
--- `Engineers` holds every engineer working the job. By convention `Engineers[1]` is the claimer; entries `[2..n]` are assistants joined via `JoinAsAssistant`. The queue does not promote on claimer death — see `FailJob`.
---@class JoeBuildJob
---@field Spec JoeBuildJobSpec
---@field State JoeBuildJobState
---@field Engineers JoeUnit[]                # [1] claimer, [2..n] assistants.
---@field BuildSite? JoeBuildSite            # The resolved build site for this job's structure.
---@field Unit? JoeUnit                      # The structure once `OnStartBuild` fired. Stays set after `Built` so the validation poll can detect destruction.
---@field Delayed boolean                    # Last-evaluated `DelayPredicate` result. `ClaimJob` skips delayed jobs.

--- Per-base build-job queue. Holds three arrays:
---  * `Pending`  — unclaimed jobs, available to any engineer's build behavior.
---  * `Active`   — claimed jobs whose engineers are en route, building, or assisting-eligible.
---  * `Complete` — finished jobs (every identifier built, units alive). The validation poll re-queues entries whose units have since been destroyed.
---
--- A forked validation thread runs every `PollInterval` ticks (default 10) and refreshes delays on `Pending` plus re-queues destroyed-unit entries from `Complete`. Mutate `PollInterval` per instance to adjust cadence.
---@class JoeBaseBuildQueueComponent
---@field Base JoeBase
---@field Pending JoeBuildJob[]
---@field Active JoeBuildJob[]
---@field Complete JoeBuildJob[]
---@field PollInterval number
JoeBaseBuildQueueComponent = ClassSimple {

    --- Default cap on assistants per job. A spec may override via `MaxAssistants`. The cap counts only assistants — the claimer is always allowed.
    DefaultMaxAssistants = 3,

    --- Default poll cadence (in ticks) for the validation thread. Per-instance override: `self.PollInterval = N` after construction to retune. Lower for more responsive re-queue, higher for less work.
    PollInterval = 10,

    ---@param self JoeBaseBuildQueueComponent
    ---@param base JoeBase
    __init = function(self, base)
        self.Base = base
        self.Pending = {}
        self.Active = {}
        self.Complete = {}

        -- Validation thread lives in the base's trash so `Retreat` cleans it up.
        base.Trash:Add(ForkThread(self.PollLoop, self))
    end,

    -----------------------------------------------------------------------------
    --#region Pushing jobs

    --- Wraps a spec in a fresh `JoeBuildJob` and adds it to `Pending`. Callers don't construct `JoeBuildJob` directly — pass a spec, get the live job back if you need a handle on it.
    ---@param self JoeBaseBuildQueueComponent
    ---@param spec JoeBuildJobSpec
    ---@return JoeBuildJob
    PushJob = function(self, spec)
        ---@type JoeBuildJob
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
    ---@param self JoeBaseBuildQueueComponent
    ---@param engineer JoeUnit
    ---@param predicate? fun(job: JoeBuildJob, engineer: JoeUnit): boolean
    ---@return JoeBuildJob?
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

    --- Records the build site the engineer chose for the *current* structure. Called once the build behavior has resolved a site via `JoeBase:AcquireBuildSitesForUnit` for the next identifier in the list.
    ---@param self JoeBaseBuildQueueComponent
    ---@param job JoeBuildJob
    ---@param buildSite JoeBuildSite
    RegisterBuildSite = function(self, job, buildSite)
        job.BuildSite = buildSite
    end,

    --- Transitions the job into `Building` state with the actual structure unit. Called from the build behavior's `OnStartBuild` event handler. Also wires the unit back to the build site so site state-predicates (`IsBuilding`, `IsBuilt`) reflect reality.
    ---@param self JoeBaseBuildQueueComponent
    ---@param job JoeBuildJob
    ---@param unit JoeUnit
    RegisterUnit = function(self, job, unit)
        job.State = 'Building'
        job.Unit = unit
        if job.BuildSite then
            job.BuildSite.Unit = unit
        end
    end,

    --- Marks the job's structure as fully built. State transitions to `Built`, the job moves from `Active` to `Complete`. `Unit` is left in place so the validation poll can detect destruction later. Called from the build behavior's `OnStopBuild` when the structure finishes.
    ---@param self JoeBaseBuildQueueComponent
    ---@param job JoeBuildJob
    CompleteJob = function(self, job)
        job.State = 'Built'
        self:RemoveFromActive(job)
        TableInsert(self.Complete, job)
    end,

    --- Marks the job failed. If `requeue` is true, the spec is recycled into a fresh pending job (engineer / site / unit refs cleared). Otherwise the job moves to `Failed` and is dropped.
    ---@param self JoeBaseBuildQueueComponent
    ---@param job JoeBuildJob
    ---@param requeue boolean
    FailJob = function(self, job, requeue)
        self:RemoveFromActive(job)

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

    --- Returns the first active job in `Building` state with a live unit and assistant capacity remaining. Optional predicate filters further. Returning the job does *not* register the assistant — call `JoinAsAssistant` after.
    ---@param self JoeBaseBuildQueueComponent
    ---@param predicate? fun(job: JoeBuildJob): boolean
    ---@return JoeBuildJob?
    FindAssistTarget = function(self, predicate)
        local active = self.Active
        for k = 1, TableGetn(active) do
            local job = active[k]
            if job.State == 'Building'
                and job.Unit
                and not IsDestroyed(job.Unit)
                and self:GetAssistantCount(job) < self:GetMaxAssistants(job)
                and ((not predicate) or predicate(job))
            then
                return job
            end
        end
        return nil
    end,

    --- Adds `engineer` to the job's engineer list as an assistant. Returns false if the job is already at its assistant cap.
    ---@param self JoeBaseBuildQueueComponent
    ---@param job JoeBuildJob
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
    ---@param self JoeBaseBuildQueueComponent
    ---@param job JoeBuildJob
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
    --#region Delay re-evaluation

    --- Walks every pending job and refreshes its `Delayed` flag by calling the spec's `DelayPredicate` (if any). Jobs without a predicate are always considered not-delayed. Call periodically — e.g. from a base-level scheduler thread — so changing brain/base conditions actually unblock or pause queued work.
    ---@param self JoeBaseBuildQueueComponent
    RefreshDelays = function(self)
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

    --#endregion

    -----------------------------------------------------------------------------
    --#region Accessors

    --- Returns the engineer that originally claimed the job, or nil if the job has no engineers (e.g. just-failed-and-being-cleared).
    ---@param self JoeBaseBuildQueueComponent
    ---@param job JoeBuildJob
    ---@return JoeUnit?
    GetClaimer = function(self, job)
        return job.Engineers[1]
    end,

    --- Returns how many assistants are currently registered on the job. The claimer is excluded from the count.
    ---@param self JoeBaseBuildQueueComponent
    ---@param job JoeBuildJob
    ---@return number
    GetAssistantCount = function(self, job)
        local n = TableGetn(job.Engineers)
        if n == 0 then
            return 0
        end
        return n - 1
    end,

    --- Returns the assistant cap that applies to the job — its spec override if set, else the component default.
    ---@param self JoeBaseBuildQueueComponent
    ---@param job JoeBuildJob
    ---@return number
    GetMaxAssistants = function(self, job)
        return job.Spec.MaxAssistants or self.DefaultMaxAssistants
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Validation poll

    --- Forked thread that wakes every `PollInterval` ticks and runs `Validate`. Forked into the base's trash from `__init` so `Retreat` cleans it up.
    ---@param self JoeBaseBuildQueueComponent
    PollLoop = function(self)
        while true do
            WaitTicks(self.PollInterval)
            self:Validate()
        end
    end,

    --- One pass of validation: refresh delays on pending jobs, then re-queue completed jobs whose units have been destroyed. Called from `PollLoop`; can also be triggered manually.
    ---@param self JoeBaseBuildQueueComponent
    Validate = function(self)
        self:RefreshDelays()
        self:RequeueDestroyedComplete()
    end,

    --- Walks `Complete` in reverse and pops out jobs whose built unit is now destroyed, resetting their state and pushing them back onto `Pending`. Iterating in reverse keeps `TableRemove`'s shifting from breaking the index. Priority of the re-queued job is left at default — caller policy can refine later.
    ---@param self JoeBaseBuildQueueComponent
    RequeueDestroyedComplete = function(self)
        local complete = self.Complete
        for k = TableGetn(complete), 1, -1 do
            local job = complete[k]
            local unit = job.Unit

            if (not unit) or IsDestroyed(unit) then
                TableRemove(complete, k)

                -- reset runtime state and requeue
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
    ---@param self JoeBaseBuildQueueComponent
    ---@param job JoeBuildJob
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
