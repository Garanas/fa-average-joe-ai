
local AIPlatoonMoho = moho.platoon_methods

-- upvalue scope for performance
local IsDestroyed = IsDestroyed

local TableGetn = table.getn

--- Data structure for storing information used to debug this behavior. This information may not be synchronized between players. Any field in this table should not be used for the behavior itself!
---@class AIPlatoonBehaviorDebug
---@field LastSelected number       # Indicates the last tick that one or more units of this behavior was selected. Can be used as a trivial indication when to log debug information.

---@class AIPlatoonBehaviorState : State
---@field BehaviorStateName string      # Name of the state, primarily used for debugging purposes.
---@field BehaviorStateColor Color      # Color of the state, primarily used for debugging purposes.

--- Describes the behavior of a platoon with one or more units.
---@class AIPlatoonBehavior : moho.platoon_methods
---@field Debug AIPlatoonBehaviorDebug             # Debug information of this behavior. This information may not be synchronized between players. Any field in this table should not be used for the behavior itself!
---@field BehaviorTrash TrashBag            # Content is destroyed when the behavior is destroyed as a whole, includes the trash of a state
---@field BehaviorStateTrash TrashBag       # Content is destroyed when the state of the behavior is changed
AIPlatoonBehavior = Class(moho.platoon_methods) {

    BehaviorName = 'PlatoonBase',
    BehaviorStateName = 'Unknown',
    BehaviorStateColor = 'ffffff',

    --- Called by the platoon builder when the behavior is created.
    ---@param self AIPlatoonBehavior
    OnCreate = function(self)
        self.BehaviorTrash = TrashBag()
        self.BehaviorStateTrash = self.BehaviorTrash:Add(TrashBag())

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

        ---@param self AIPlatoonBehavior
        Main = function(self)
            self:ChangeState(self.Error)
        end,
    },

    Error = State {

        BehaviorStateName = 'Error',

        ---@param self AIPlatoonBehavior
        Main = function(self)
            -- tell the developer that something went wrong
            while not IsDestroyed(self) do
                if GetFocusArmy() == self:GetBrain():GetArmyIndex() then
                    DrawCircle(self:GetPlatoonPosition(), 10, 'ff0000')
                end
                WaitTicks(2)
            end
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

        self:LogDebug(string.format('Changing state to: %s', tostring(state.BehaviorStateName)))

        -- Clear out the trash of the old state
        self.BehaviorStateTrash:Destroy()

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
    ---@param units Unit[]
    OnUnitsAddedToAttackSquad = function(self, units)
        self:LogWarning('no support for units in attack squad')
    end,

    ---@param self AIPlatoonBehavior
    ---@param units Unit[]
    OnUnitsAddedToScoutSquad = function(self, units)
        self:LogWarning('no support for units in scout squad')
    end,

    ---@param self AIPlatoonBehavior
    ---@param units Unit[]
    OnUnitsAddedToArtillerySquad = function(self, units)
        self:LogWarning('no support for units in artillery squad')
    end,

    ---@param self AIPlatoonBehavior
    ---@param units Unit[]
    OnUnitsAddedToSupportSquad = function(self, units)
        self:LogWarning('no support for units in support squad')
    end,

    ---@param self AIPlatoonBehavior
    ---@param units Unit[]
    OnUnitsAddedToGuardSquad = function(self, units)
        self:LogWarning('no support for units in guard squad')
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
    ---@return Unit[]   # Table of alive (non-destroyed) units
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

    ---@param self AIPlatoonBehavior
    LogDebug = function(self, message)
        self.DebugMessages = self.DebugMessages or { }
        table.insert(self.DebugMessages, string.format("%d - %s", GetGameTick(), message))
    end,

    ---@param self AIPlatoonBehavior
    LogWarning = function(self, message)
        self.DebugMessages = self.DebugMessages or { }
        table.insert(self.DebugMessages, string.format("%d - %s", GetGameTick(), message))
    end,

    ---@param self AIPlatoonBehavior
    ---@return AIPlatoonDebugInfo
    GetDebugInfo = function(self)
        local info = self.DebugInfo
        if not info then
            ---@type AIPlatoonDebugInfo
            info = { }
            self.DebugInfo = info
        end

        info.BehaviorName = self.BehaviorName
        info.BehaviorStateName = self.BehaviorStateName
        info.DebugMessages = self.DebugMessages
        table.sort(self.DebugMessages,
            function (a, b)
                return a > b
            end
        )

        return info
    end,

    ---@param self AIPlatoonBehavior
    Visualize = function(self)
    end,

    --#endregion
}