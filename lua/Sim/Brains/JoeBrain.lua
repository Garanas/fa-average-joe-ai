local NavUtils = import("/lua/sim/navutils.lua")

local StandardBrain = import("/lua/aibrain.lua").AIBrain
local StandardBrainOnCreateAI = StandardBrain.OnCreateAI

--- The current strategy of Joe. The strategy describes the additional mass and energy income and the structures that Joe wants to build in general.
---@class JoeStrategy
---@field AdditionalEnergy number                               # The additional power income that we want to have
---@field AdditionalMass number                                 # The additional mass income that we want to have
---@field StructuresToBuild UnitId[]                            # The infrastructure that we want to build
---@field StructuresUnderConstruction table<EntityId, Unit>     # The infrastructure that are currently under construction

--- The brain of Joe. The brain is responsible for managing the overall strategy. It describes the focus of Joe. The strategy is implemented by bases and/or behaviors.
---@class JoeBrain: AIBrain
---@field GridReclaim AIGridReclaim
---@field GridRecon AIGridRecon
---@field GridPresence AIGridPresence
---@field ChunkComponent JoeBrainChunkComponent
---@field ChunkLoader JoeBaseChunkLoader
---@field Bases JoeBase[]
---@field Debug boolean
---@field DrawThread? thread
JoeBrain = Class(StandardBrain) {

    Debug = false,

    ---@param self JoeBrain
    OnCreateAI = function(self)
        StandardBrainOnCreateAI(self, 'NoPlan')

        NavUtils.Generate()

        -- requires these data structures to understand the game
        self.GridReclaim = import("/lua/ai/gridreclaim.lua").Setup(self)
        self.GridRecon = import("/lua/ai/gridrecon.lua").Setup(self)
        self.GridPresence = import("/lua/ai/gridpresence.lua").Setup(self)
        self.ChunkComponent = import("/mods/fa-joe-ai/lua/Sim/Brains/Components/JoeBrainChunkComponent.lua").Setup(self)
        self.ChunkLoader = import("/mods/fa-joe-ai/lua/Shared/BaseChunks/JoeBaseChunkLoader.lua").CreateDefaultJoeBaseChunkLoader()

        self.Bases = {}
    end,

    ---------------------------------------------------------------------------
    --#region Base management

    ---@param self JoeBrain
    ---@param base JoeBase
    AddBase = function(self, base)
        table.insert(self.Bases, base)
    end,

    --- Removes a base from this brain's roster. Called by `JoeBase:Retreat` after the base has cleaned up its own state.
    ---@param self JoeBrain
    ---@param base JoeBase
    RemoveBase = function(self, base)
        local bases = self.Bases
        for k = 1, table.getn(bases) do
            if bases[k] == base then
                table.remove(bases, k)
                return
            end
        end
    end,


    --- Returns the base most relevant to the given XZ position. First checks whether the position falls inside an already-claimed nav section (Land first, Water as fallback) — if so, returns that section's owning base directly. Otherwise falls back to the base whose `Location` is closest in XZ. Returns nil if the brain has no bases and no claimed sections cover the position.
    ---@param self JoeBrain
    ---@param lx number     # in world coordinates
    ---@param lz number     # in world coordinates
    ---@return JoeBase?
    FindNearestBaseXZ = function(self, lx, lz)
        -- First try: is the position already inside a claimed section? Then we know the owner directly.
        local chunkComponent = self.ChunkComponent
        local position = { lx, 0, lz }
        local section = chunkComponent:FindSection("Land", position)
                     or chunkComponent:FindSection("Water", position)
        if section then
            local owner = chunkComponent:GetOwner(section.Identifier)
            if owner then
                return owner
            end
        end

        -- Fall back: nearest base by squared XZ distance to base.Location.
        local bases = self.Bases
        local nearest = nil
        local nearestDistSq

        for k = 1, table.getn(bases) do
            local base = bases[k]
            local pos = base.Location
            local dx = pos[1] - lx
            local dz = pos[3] - lz
            local distSq = dx * dx + dz * dz

            if (not nearestDistSq) or distSq < nearestDistSq then
                nearest = base
                nearestDistSq = distSq
            end
        end

        return nearest
    end,

    ---@param self JoeBrain
    ---@param location Vector
    ---@return JoeBase?
    FindNearestBase = function(self, location)
        return self:FindNearestBaseXZ(location[1], location[3])
    end,

    --#endregion
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    --#region Unit events

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param builder Unit
    ---@param layer Layer
    OnUnitStartBeingBuilt = function(self, unit, builder, layer)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param builder Unit
    ---@param layer Layer
    OnUnitStopBeingBuilt = function(self, unit, builder, layer)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitDestroy = function(self, unit)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param new number # 0.25 / 0.50 / 0.75 / 1.0
    ---@param old number # 0.25 / 0.50 / 0.75 / 1.0
    OnUnitHealthChanged = function(self, unit, new, old)
        -- pass the event to the platoon
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnHealthChanged(unit, new, old)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit | Prop | nil      # is nil when the prop or unit is completely reclaimed
    OnUnitStopReclaim = function(self, unit, target)
        -- pass the event to the platoon
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnStopReclaim(unit, target)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit | Prop
    OnUnitStartReclaim = function(self, unit, target)
        -- pass the event to the platoon
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnStartReclaim(unit, target)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    OnUnitStartRepair = function(self, unit, target)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnStartRepair(unit, target)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    OnUnitStopRepair = function(self, unit, target)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnStopRepair(unit, target)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param instigator Unit | Projectile | nil
    ---@param damageType DamageType
    ---@param overkillRatio number
    OnUnitKilled = function(self, unit, instigator, damageType, overkillRatio)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnKilled(unit, instigator, damageType, overkillRatio)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param reclaimer Unit
    OnUnitReclaimed = function(self, unit, reclaimer)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    OnUnitStartCapture = function(self, unit, target)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    OnUnitStopCapture = function(self, unit, target)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    OnUnitFailedCapture = function(self, unit, target)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param captor Unit
    OnUnitStartBeingCaptured = function(self, unit, captor)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param captor Unit
    OnUnitStopBeingCaptured = function(self, unit, captor)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param captor Unit
    OnUnitFailedBeingCaptured = function(self, unit, captor)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param weapon Weapon
    OnUnitSiloBuildStart = function(self, unit, weapon)
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnSiloBuildStart(unit, weapon)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param weapon Weapon
    OnUnitSiloBuildEnd = function(self, unit, weapon)
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnSiloBuildEnd(unit, weapon)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    ---@param order string
    OnUnitStartBuild = function(self, unit, target, order)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnStartBuild(unit, target, order)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    ---@param order string
    OnUnitStopBuild = function(self, unit, target, order)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnStopBuild(unit, target)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    ---@param old number
    ---@param new number
    OnUnitBuildProgress = function(self, unit, target, old, new)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitPaused = function(self, unit)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitUnpaused = function(self, unit)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param builder Unit
    ---@param old number
    ---@param new number
    OnUnitBeingBuiltProgress = function(self, unit, builder, old, new)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitFailedToBeBuilt = function(self, unit)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param attachBone Bone
    ---@param attachedUnit Unit
    OnUnitTransportAttach = function(self, unit, attachBone, attachedUnit)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnTransportAttach(unit, attachBone, attachedUnit)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param attachBone Bone
    ---@param detachedUnit Unit
    OnUnitTransportDetach = function(self, unit, attachBone, detachedUnit)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnTransportDetach(unit, attachBone, detachedUnit)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitTransportAborted = function(self, unit)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnTransportAborted(unit)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitTransportOrdered = function(self, unit)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnTransportOrdered(unit)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param attachedUnit Unit
    OnUnitAttachedKilled = function(self, unit, attachedUnit)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnAttachedKilled(unit)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitStartTransportLoading = function(self, unit)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnStartTransportLoading(unit)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitStopTransportLoading = function(self, unit)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnStopTransportLoading(unit)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param transport Unit
    ---@param bone Bone
    OnUnitStartTransportBeamUp = function(self, unit, transport, bone)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitStoptransportBeamUp = function(self, unit)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param transport Unit
    ---@param bone Bone
    OnUnitAttachedToTransport = function(self, unit, transport, bone)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param transport Unit
    ---@param bone Bone
    OnUnitDetachedFromTransport = function(self, unit, transport, bone)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param carrier Unit
    OnUnitAddToStorage = function(self, unit, carrier)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnAddToStorage(unit, carrier)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param carrier Unit
    OnUnitRemoveFromStorage = function(self, unit, carrier)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnRemoveFromStorage(unit, carrier)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param teleporter any
    ---@param location Vector
    ---@param orientation Quaternion
    OnUnitTeleportUnit = function(self, unit, teleporter, location, orientation)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitFailedTeleport = function(self, unit)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitShieldEnabled = function(self, unit)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnShieldEnabled(unit)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitShieldDisabled = function(self, unit)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnShieldDisabled(unit)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitNukeArmed = function(self, unit)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitNukeLaunched = function(self, unit)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param work any
    OnUnitWorkBegin = function(self, unit, work)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnWorkBegin(unit, work)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param work any
    OnUnitWorkEnd = function(self, unit, work)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnWorkEnd(unit, work)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param work any
    OnUnitWorkFail = function(self, unit, work)
    end,

    ---@param self EasyAIBrain
    ---@param target Vector
    ---@param shield Unit
    ---@param position Vector
    OnUnitMissileImpactShield = function(self, unit, target, shield, position)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnMissileImpactShield(unit, target, shield, position)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Vector
    ---@param position Vector
    OnUnitMissileImpactTerrain = function(self, unit, target, position)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnMissileImpactTerrain(unit, target, position)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Vector
    ---@param defense Unit
    ---@param position Vector
    OnUnitMissileIntercepted = function(self, unit, target, defense, position)

        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnMissileIntercepted(unit, target, defense, position)
        end
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    OnUnitStartSacrifice = function(self, unit, target)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    OnUnitStopSacrifice = function(self, unit, target)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitConsumptionActive = function(self, unit)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitConsumptionInActive = function(self, unit)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitProductionActive = function(self, unit)
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitProductionInActive = function(self, unit)
    end,

    --#endregion
    ---------------------------------------------------------------------------

    ---------------------------------------------------------------------------
    --#region Debug visualization

    --- Turns on the brain-level draw thread. Idempotent.
    ---@param self JoeBrain
    EnableDebug = function(self)
        if self.Debug then
            return
        end
        self.Debug = true
        self.DrawThread = ForkThread(self.DrawLoop, self)
    end,

    --- Turns off the brain-level draw thread. Idempotent.
    ---@param self JoeBrain
    DisableDebug = function(self)
        self.Debug = false
        if self.DrawThread then
            KillThread(self.DrawThread)
            self.DrawThread = nil
        end
    end,

    --- The forked thread that calls `Draw` once per tick while `Debug` is true.
    ---@param self JoeBrain
    DrawLoop = function(self)
        while self.Debug do
            self:Draw()
            WaitTicks(1)
        end
    end,

    --- Renders the brain's debug visualization. Currently delegates to `ChunkComponent:Draw`; future brain components add their own `Draw` calls here.
    ---@param self JoeBrain
    Draw = function(self)
        self.ChunkComponent:Draw()
    end,

    --#endregion
    ---------------------------------------------------------------------------
}
