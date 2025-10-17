
local AIPlatoonMoho = moho.platoon_methods

-- upvalue scope for performance
local IsDestroyed = IsDestroyed

local TableGetn = table.getn

--- A social contract between the platoon behavior and who ownership over the platoon behavior. This is a read-only table to parameterize the behavior.
---@class AIPlatoonBehaviorInput    

--- Data structure for storing information used to debug this behavior. This information may not be synchronized between players. Any field in this table should not be used for the behavior itself!
---@class AIPlatoonBehaviorDebug
---@field LastSelected number       # Indicates the last tick that one or more units of this behavior was selected. Can be used as a trivial indication when to log debug information.

---@class AIPlatoonBehaviorState : State
---@field BehaviorStateName string      # Name of the state, primarily used for debugging purposes.
---@field BehaviorStateColor Color      # Color of the state, primarily used for debugging purposes.

--- Describes the behavior of a platoon with one or more units.
---@class AIPlatoonBehavior : moho.platoon_methods
---@field PlatoonBehaviorInput AIPlatoonBehaviorInput
---@field BehaviorState table               # State of the behavior that is running. 
---@field Debug AIPlatoonBehaviorDebug             # Debug information of this behavior. This information may not be synchronized between players. Any field in this table should not be used for the behavior itself!
---@field BehaviorTrash TrashBag            # Content is destroyed when the behavior is destroyed as a whole, includes the trash of a state
---@field BehaviorStateTrash TrashBag       # Content is destroyed when the state of the behavior is changed
AIPlatoonBehavior = Class(moho.platoon_methods) {

    BehaviorName = 'PlatoonBase',
    BehaviorStateName = 'Unknown',
    BehaviorStateColor = '000000',

    --- Called by the platoon builder when the behavior is created.
    ---@param self AIPlatoonBehavior
    OnCreate = function(self)
        self.BehaviorTrash = TrashBag()
        self.BehaviorStateTrash = self.BehaviorTrash:Add(TrashBag())
        self.BehaviorState = {}

        self.Debug = {
            LastSelected = 0
        }
    end,

    --- Called by the engine when the platoon is devoid of units.
    ---@param self AIPlatoonBehavior
    OnDestroy = function(self)
        self.BehaviorTrash:Destroy()
    end,

    -----------------------------------------------------------------
    -- Behavior states

    Start = State {

        BehaviorStateName = 'Start',
        BehaviorStateColor =  'ffffff',

        ---@param self AIPlatoonBehavior
        Main = function(self)
            self:ChangeState(self.Error)
        end,
    },

    Completed = State {
        BehaviorStateName = 'Completed',
        BehaviorStateColor =  '00ff00',

        ---@param self AIPlatoonBehavior
        Main = function(self)
            -- do nothing
        end,
    },

    Error = State {

        BehaviorStateName = 'Error',
        BehaviorStateColor =  'ff0000',

        ---@param self AIPlatoonBehavior
        Main = function(self)
            -- do nothing
        end,

        ---@param self AIPlatoonBehavior
        Draw = function(self)
            DrawCircle(self:GetPlatoonPosition(), 10, 'ff0000')
        end,
    },

    --- Changes the state of the platoon immediately. The current thread running the Main function of the old state is destroyed. This stops execution of the thread in its tracks. 
    ---@param self AIPlatoonBehavior
    ---@param state AIPlatoonBehaviorState
    ChangeState = function(self, state)

        -- A simplified version of the global `ChangeState`. It skips a few steps that are
        -- not used by the behavior system. We do not support `OnExitState` and `OnEnterState`. 

        -- In general, states work by manipulating the meta table of the behavior. It is in between 
        -- the actual table instance and the actual behavior meta table: 
        -- 
        -- instance table (of a behavior) -> state meta table -> behavior meta table

        -- assertion
        if IsDestroyed(self) then
            return
        end

        -- assertion
        if not (state.Main and state.BehaviorStateName) then
            return
        end

        if self:IsBeingDebugged() then
            self:Log(string.format('Switching to state %s', tostring(state.BehaviorStateName)))
        end

        -- Clear out the trash of the old state
        self.BehaviorStateTrash:Destroy()
        for k, _ in self.BehaviorState do
            self.BehaviorState[k] = nil
        end

        -- Switcheroo on the meta table
        setmetatable(self, state)

        -- Switcheroo on the main thread
        local oldMainThread = self.__mainthread
        self.__mainthread = ForkThread(state.Main, self)

        -- At the very end, kill the old main thread. This may be the thread that runs this
        -- function. Therefore this should always be done last.
        if oldMainThread then
            KillThread(oldMainThread)
        end
    end,

    -----------------------------------------------------------------
    --#region Brain events

    ---@param self AIPlatoonBehavior
    ---@param units JoeUnit[]
    OnUnitsAddedToAttackSquad = function(self, units)
        self:Warn('no support for units in attack squad')
    end,

    ---@param self AIPlatoonBehavior
    ---@param units JoeUnit[]
    OnUnitsAddedToScoutSquad = function(self, units)
        self:Warn('no support for units in scout squad')
    end,

    ---@param self AIPlatoonBehavior
    ---@param units JoeUnit[]
    OnUnitsAddedToArtillerySquad = function(self, units)
        self:Warn('no support for units in artillery squad')
    end,

    ---@param self AIPlatoonBehavior
    ---@param units JoeUnit[]
    OnUnitsAddedToSupportSquad = function(self, units)
        self:Warn('no support for units in support squad')
    end,

    ---@param self AIPlatoonBehavior
    ---@param units JoeUnit[]
    OnUnitsAddedToGuardSquad = function(self, units)
        self:Warn('no support for units in guard squad')
    end,

    --#endregion

    -----------------------------------------------------------------
    --#region Unit events

    --- Called as a unit of this platoon is killed.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    ---@param instigator Unit | Projectile | nil
    ---@param type DamageType
    ---@param overkillRatio number
    OnKilled = function(self, unit, instigator, type, overkillRatio)
    end,

    --- Called as a unit of this platoon starts building.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    ---@param target Unit
    ---@param order string
    OnStartBuild = function(self, unit, target, order)
    end,

    --- Called as a unit of this platoon stops building.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    ---@param target Unit
    OnStopBuild = function(self, unit, target)
    end,

    --- Called as a unit of this platoon starts repairing.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    ---@param target Unit
    OnStartRepair = function(self, unit, target)
    end,

    --- Called as a unit of this platoon stops repairing.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    ---@param target Unit
    OnStopRepair = function(self, unit, target)
    end,

    --- Called as a unit of this platoon starts reclaiming.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    ---@param target Unit | Prop
    OnStartReclaim = function(self, unit, target)
    end,

    --- Called as a unit of this platoon stops reclaiming.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    ---@param target Unit | Prop | nil      # is nil when the prop or unit is completely reclaimed
    OnStopReclaim = function(self, unit, target)
    end,

    --- Called as a unit of this platoon gains or loses health, fixed at intervals of 25%.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    ---@param new number
    ---@param old number
    OnHealthChanged = function(self, unit, new, old)
    end,

    --- Called as a unit of this platoon starts building a missile.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    ---@param weapon Weapon
    OnSiloBuildStart = function(self, unit, weapon)
    end,

    --- Called as a unit of this platoon stops building a missile.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    ---@param weapon Weapon
    OnSiloBuildEnd = function(self, unit, weapon)
    end,

    --- Called as a unit of this platoon starts working on an enhancement.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    ---@param work string
    OnWorkBegin = function(self, unit, work)
    end,

    --- Called as a unit of this platoon stops working on an enhancement.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    ---@param work string
    OnWorkEnd = function(self, unit, work)
    end,

    --- Called as a missile launched by a unit of this platoon is intercepted.
    ---@param self AIPlatoonBehavior
    ---@param target Vector
    ---@param defense Unit
    ---@param position Vector
    OnMissileIntercepted = function(self, unit, target, defense, position)
    end,

    --- Called as a missile launched by a unit of this platoon hits a shield.
    ---@param self AIPlatoonBehavior
    ---@param target Vector
    ---@param shield Unit
    ---@param position Vector
    OnMissileImpactShield = function(self, unit, target, shield, position)
    end,

    --- Called as a missile launched by a unit of this platoon impacts with the terrain.
    ---@param self AIPlatoonBehavior
    ---@param target Vector
    ---@param position Vector
    OnMissileImpactTerrain = function(self, unit, target, position)
    end,

    --- Called as a shield of a unit of this platoon is enabled.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    OnShieldEnabled = function(self, unit)
    end,

    --- Called as a shield of a unit of this platoon is disabled.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    OnShieldDisabled = function(self, unit)
    end,

    --- Called as a unit (with transport capabilities) of this platoon attached a unit to itself.
    ---@param self AIPlatoonBehavior
    ---@param transport Unit
    ---@param attachBone Bone
    ---@param attachedUnit Unit
    OnTransportAttach = function(self, transport, attachBone, attachedUnit)
    end,

    --- Called as a unit (with transport capabilities) of this platoon deattached a unit from itself.
    ---@param self AIPlatoonBehavior
    ---@param transport Unit
    ---@param attachBone Bone
    ---@param detachedUnit Unit
    OnTransportDetach = function(self, transport, attachBone, detachedUnit)
    end,

    --- Called as a unit (with transport capabilities) of this platoon aborts the a transport order.
    ---@param self AIPlatoonBehavior
    ---@param transport Unit
    OnTransportAborted = function(self, transport)
    end,

    --- Called as a unit (with transport capabilities) of this platoon initiates the a transport order.
    ---@param self AIPlatoonBehavior
    ---@param transport Unit
    OnTransportOrdered = function(self, transport)
    end,

    --- Called as a unit is killed while being transported by a unit (with transport capabilities) of this platoon.
    ---@param self AIPlatoonBehavior
    ---@param transport Unit
    OnAttachedKilled = function(self, transport, attached)
    end,

    --- Called as a unit (with transport capabilities) of this platoon is ready to load in units.
    ---@param self AIPlatoonBehavior
    ---@param transport Unit
    OnStartTransportLoading = function(self, transport)
    end,

    --- Called as a unit (with transport capabilities) of this platoon is done loading in units.
    ---@param self AIPlatoonBehavior
    ---@param transport Unit
    OnStopTransportLoading = function(self, transport)
    end,

    --- Called as a unit (with carrier capabilities) of this platoon has a change in storage.
    ---@see `OnAddToStorage` and `OnRemoveFromStorage` for the unit in question
    ---@param self AIPlatoonBehavior
    ---@param carrier Unit
    ---@param loading boolean
    OnStorageChange = function(self, carrier, loading)
    end,

    --- Called as a unit (with carrier capabilities) of this platoon adds a unit to its storage.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    ---@param carrier Unit
    OnAddToStorage = function(self, unit, carrier)
    end,

    --- Called as a unit (with carrier capabilities) of this platoon removes a unit from its storage.
    ---@param self AIPlatoonBehavior
    ---@param unit Unit
    ---@param carrier Unit
    OnRemoveFromStorage = function(self, unit, carrier)
    end,

    --#endregion

    -----------------------------------------------------------------
    --#region Overwritten functions

    --- Returns all units that are part of this platoon.
    ---@param self AIPlatoonBehavior
    ---@return JoeUnit[]   # Table of alive (non-destroyed) units
    ---@return number   # Number of units
    GetPlatoonUnits = function(self)

        -- this function is hooked because the cfunction returns units
        -- that are destroyed. We filter those out and return the remainder

        local units = AIPlatoonMoho.GetPlatoonUnits(self)

        -- populate the cache
        local head = 1
        for _, unit in units do
            if not IsDestroyed(unit) then
                units[head] = unit
                head = head + 1
            end
        end

        -- discard remaining elements of the cache
        local count = TableGetn(units)
        if count >= head then
            for k = head, count do
                units[k] = nil
            end
        end

        return units, head - 1
    end,

    --- Returns the position of the unit that is nearest to the center of the platoon.
    ---@param self AIPlatoonBehavior
    ---@return Vector?
    GetPlatoonPosition = function(self)
        if IsDestroyed(self) then
            return nil
        end

        -- retrieve average position
        local position = AIPlatoonMoho.GetPlatoonPosition(self)
        if not position then
            return nil
        end

        -- retrieve units
        local units, unitCount = self:GetPlatoonUnits()
        if unitCount == 0 then
            return nil
        end

        local px = position[1]
        local pz = position[3]

        -- try to find the unit closest to the center
        local nx, ny, nz, distance
        for k = 1, unitCount do
            local unit = units[k]
            local ux, uy, uz = unit:GetPositionXYZ()
            local dx = ux - px
            local dz = uz - pz
            local d = dx * dx + dz * dz

            if (not distance) or d < distance then
                nx = ux
                ny = uy
                nz = uz
                distance = d
            end
        end

        return { nx, ny, nz }
    end,

    ---------------------------------------------------------------------------
    --#region Debug functionality

    --- A utility function that determines whether this platoon is selected. The output of this function is not synchronized across clients and therefore should not be a condition for anything but logging and/or drawing!
    ---@param self AIPlatoonBehavior
    IsBeingDebugged = function(self)
        return self.Debug.LastSelected >= GetGameTick() - 1
    end,

    --- Formats the message to make it more convenient to understand.
    ---@param self AIPlatoonBehavior
    ---@param message string
    ---@return string
    FormatMessage = function(self, message)
        return string.format("[%s] %s (%s): %s", tostring(self), tostring(self.BehaviorName), tostring(self.BehaviorStateName), tostring(message))
    end,

    --- A utility function that logs a message to the console.
    ---@param self AIPlatoonBehavior
    Log = function(self, message)
        LOG(self:FormatMessage(message))
    end,

    --- A utility function that logs a warning to the console.
    ---@param self AIPlatoonBehavior
    Warn = function(self, message)
        WARN(self:FormatMessage(message))
    end,

    --- A utility function that draws the current status quo.
    ---@param self AIPlatoonBehavior
    Draw = function(self)
        local DebugUtils = import("/mods/fa-joe-ai/lua/Sim/DebugUtils.lua")

        -- draw behavior
        DebugUtils.DrawUnits(self:GetPlatoonUnits() or {}, self.BehaviorStateColor, 0)

        -- draw squads
        DebugUtils.DrawUnits(self:GetSquadUnits('Attack') or {}, 'ff0000', -0.1)
        DebugUtils.DrawUnits(self:GetSquadUnits('Artillery') or {}, '8B4513', -0.1)
        DebugUtils.DrawUnits(self:GetSquadUnits('Scout') or {}, '00ffff', -0.1)
        DebugUtils.DrawUnits(self:GetSquadUnits('Support') or {}, 'ffff00', -0.1)
        DebugUtils.DrawUnits(self:GetSquadUnits('Guard') or {}, '00ff00', -0.1)
        DebugUtils.DrawUnits(self:GetSquadUnits('Unassigned') or {}, '000000', -0.1)
    end,

    --#endregion
}