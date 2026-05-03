local AIPlatoonBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBehavior.lua").AIPlatoonBehavior

--- Read-only input parameters supplied by the platoon builder before `Start` runs.
---@class AIAssistBehaviorInput : AIPlatoonBehaviorInput

--- Per-assist-behavior runtime state. Stashed on `self.BehaviorState` so a state's `Main` can read what previous states resolved without recomputing.
---@class AIAssistBehaviorState
---@field Engineer JoeUnit          # The Support engineer this behavior assists with.
---@field Base JoeBase              # The base whose `BuildQueueComponent` we're watching.
---@field Job? JoeBuildJob          # The currently-assisted job. Nil when in `WaitForTarget`.

--- Engineer behavior that piggy-backs on someone else's build. The platoon's Support engineer never claims a job itself — it watches the base's `BuildQueueComponent` for `Building`-state jobs that still have assistant capacity, joins as an assistant, and `IssueGuard`s the claimer engineer so the engine takes care of helping with construction.
---
--- When the assisted job ends (the unit was completed, destroyed, or the job otherwise leaves `Building` state) the assistant leaves and looks for a new target. The factory-assist case will be handled by an upcoming structure manager — for now the assist behavior is purely build-job-shaped.
---@class AIAssistBehavior : AIPlatoonBehavior
---@field PlatoonBehaviorInput AIAssistBehaviorInput
---@field BehaviorState AIAssistBehaviorState
AssistBehavior = Class(AIPlatoonBehavior) {
    BehaviorName = 'AssistBehavior',

    --- Cadence at which the `Assist` state polls the assisted job's state. Lower = react faster to the job ending; higher = cheaper.
    AssistPollInterval = 20,

    -----------------------------------------------------------------------------
    -- Bootstrap

    Start = State {
        BehaviorStateName = 'Start',
        BehaviorStateColor = 'ffffff',

        ---@param self AIAssistBehavior
        Main = function(self)
            local supportSquad = self:GetSquadUnits('Support')
            local engineer = supportSquad[1] --[[@as JoeUnit]]
            if not engineer or not engineer.JoeData or not engineer.JoeData.Base then
                self:Warn('Support engineer has no base assigned')
                self:ChangeState(self.Error)
                return
            end

            self.BehaviorState.Engineer = engineer
            self.BehaviorState.Base = engineer.JoeData.Base

            IssueClearCommands(supportSquad)
            self:ChangeState(self.FindTarget)
        end,
    },

    -----------------------------------------------------------------------------
    -- Main loop: find a target, assist, leave, repeat

    FindTarget = State {
        BehaviorStateName = 'FindTarget',
        BehaviorStateColor = '88ddff',

        ---@param self AIAssistBehavior
        Main = function(self)
            local engineer = self.BehaviorState.Engineer
            local base = self.BehaviorState.Base
            local job = base.BuildQueueComponent:FindAssistTarget()

            if not job then
                self:ChangeState(self.WaitForTarget)
                return
            end

            -- Race protection: another assistant may have just filled the slot.
            if not base.BuildQueueComponent:JoinAsAssistant(job, engineer) then
                self:ChangeState(self.WaitForTarget)
                return
            end

            self.BehaviorState.Job = job
            self:ChangeState(self.Assist)
        end,
    },

    WaitForTarget = State {
        BehaviorStateName = 'WaitForTarget',
        BehaviorStateColor = '444488',

        ---@param self AIAssistBehavior
        Main = function(self)
            WaitTicks(50)
            self:ChangeState(self.FindTarget)
        end,
    },

    Assist = State {
        BehaviorStateName = 'Assist',
        BehaviorStateColor = '44ff88',

        ---@param self AIAssistBehavior
        Main = function(self)
            local job = self.BehaviorState.Job
            local supportSquad = self:GetSquadUnits('Support')
            local claimer = job.Engineers[1]

            if (not claimer) or IsDestroyed(claimer) then
                self:ChangeState(self.LeaveAssist)
                return
            end

            -- Guard the claimer; the engine handles the actual assist of whatever
            -- the claimer is doing (build or otherwise) without further input.
            IssueGuard(supportSquad, claimer)

            -- Poll the job's state to detect end-of-assist conditions.
            while true do
                WaitTicks(self.AssistPollInterval)

                if job.State ~= 'Building' and job.State ~= 'Claimed' then
                    -- job left active (Built / Failed / re-queued)
                    self:ChangeState(self.LeaveAssist)
                    return
                end

                if (not job.Unit) or IsDestroyed(job.Unit) then
                    self:ChangeState(self.LeaveAssist)
                    return
                end

                if (not claimer) or IsDestroyed(claimer) then
                    self:ChangeState(self.LeaveAssist)
                    return
                end
            end
        end,
    },

    LeaveAssist = State {
        BehaviorStateName = 'LeaveAssist',
        BehaviorStateColor = '888888',

        ---@param self AIAssistBehavior
        Main = function(self)
            local job = self.BehaviorState.Job
            local engineer = self.BehaviorState.Engineer
            local base = self.BehaviorState.Base

            if job and engineer then
                base.BuildQueueComponent:LeaveJob(job, engineer)
            end

            IssueClearCommands(self:GetPlatoonUnits())
            self.BehaviorState.Job = nil
            self:ChangeState(self.FindTarget)
        end,
    },
}
