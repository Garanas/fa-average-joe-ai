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
---@field Bases JoeBase[]
JoeBrain = Class(StandardBrain) {
    ---@param self JoeBrain
    OnCreateAI = function(self)
        StandardBrainOnCreateAI(self, 'NoPlan')

        NavUtils.Generate()

        -- requires these data structures to understand the game
        self.GridReclaim = import("/lua/ai/gridreclaim.lua").Setup(self)
        self.GridRecon = import("/lua/ai/gridrecon.lua").Setup(self)
        self.GridPresence = import("/lua/ai/gridpresence.lua").Setup(self)
    end,

    ---------------------------------------------------------------------------
    --#region Base management

    ---@param self JoeBrain
    ---@param base JoeBase
    AddBase = function(self, base)
    end,


    ---@param self JoeBrain
    ---@param lx number     # in world coordinates
    ---@param lz number     # in world coordinates
    FindNearestBaseXZ = function(self, lx, lz)

    end,

    ---@param self JoeBrain
    ---@param location Vector
    FindNearestBase = function(self, location)

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
        -- for debugging
        LOG("OnUnitStartBeingBuilt")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param builder Unit
    ---@param layer Layer
    OnUnitStopBeingBuilt = function(self, unit, builder, layer)
        -- for debugging
        LOG("OnUnitStopBeingBuilt")

        local platoon = self:GetPlatoonUniquelyNamed("ArmyPool")
        LOG(table.getn(platoon:GetPlatoonUnits()))
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitDestroy = function(self, unit)
        LOG("OnUnitDestroy")
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

        LOG("OnUnitHealthChanged")
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

        LOG("OnUnitStopReclaim")
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

        LOG("OnUnitStartReclaim")
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

        LOG("OnUnitStartRepair")
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

        LOG("OnUnitStopRepair")
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

        LOG("OnUnitKilled")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param reclaimer Unit
    OnUnitReclaimed = function(self, unit, reclaimer)
        LOG("OnUnitReclaimed")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    OnUnitStartCapture = function(self, unit, target)
        LOG("OnUnitStartCapture")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    OnUnitStopCapture = function(self, unit, target)
        LOG("OnUnitStopCapture")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    OnUnitFailedCapture = function(self, unit, target)
        LOG("OnUnitFailedCapture")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param captor Unit
    OnUnitStartBeingCaptured = function(self, unit, captor)
        LOG("OnUnitStartBeingCaptured")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param captor Unit
    OnUnitStopBeingCaptured = function(self, unit, captor)
        LOG("OnUnitStopBeingCaptured")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param captor Unit
    OnUnitFailedBeingCaptured = function(self, unit, captor)
        LOG("OnUnitFailedBeingCaptured")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param weapon Weapon
    OnUnitSiloBuildStart = function(self, unit, weapon)
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnSiloBuildStart(unit, weapon)
        end

        LOG("OnUnitSiloBuildStart")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param weapon Weapon
    OnUnitSiloBuildEnd = function(self, unit, weapon)
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnSiloBuildEnd(unit, weapon)
        end

        LOG("OnUnitSiloBuildEnd")
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

        LOG("OnUnitStartBuild")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    ---@param order string
    OnUnitStopBuild = function(self, unit, target, order)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        LOG(aiPlatoon)
        if aiPlatoon then
            aiPlatoon:OnStopBuild(unit, target)
        end

        LOG("OnUnitStopBuild")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    ---@param old number
    ---@param new number
    OnUnitBuildProgress = function(self, unit, target, old, new)
        LOG("OnUnitBuildProgress")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitPaused = function(self, unit)
        LOG("OnUnitPaused")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitUnpaused = function(self, unit)
        LOG("OnUnitUnpaused")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param builder Unit
    ---@param old number
    ---@param new number
    OnUnitBeingBuiltProgress = function(self, unit, builder, old, new)
        LOG("OnUnitBeingBuiltProgress")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitFailedToBeBuilt = function(self, unit)
        LOG("OnUnitFailedToBeBuilt")
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

        LOG("OnUnitTransportAttach")
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

        LOG("OnUnitTransportDetach")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitTransportAborted = function(self, unit)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnTransportAborted(unit)
        end

        LOG("OnUnitTransportAborted")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitTransportOrdered = function(self, unit)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnTransportOrdered(unit)
        end

        LOG("OnUnitTransportOrdered")
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

        LOG("OnUnitAttachedKilled")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitStartTransportLoading = function(self, unit)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnStartTransportLoading(unit)
        end

        LOG("OnUnitStartTransportLoading")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitStopTransportLoading = function(self, unit)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnStopTransportLoading(unit)
        end

        LOG("OnUnitStopTransportLoading")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param transport Unit
    ---@param bone Bone
    OnUnitStartTransportBeamUp = function(self, unit, transport, bone)
        LOG("OnUnitStartTransportBeamUp")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitStoptransportBeamUp = function(self, unit)
        LOG("OnUnitStoptransportBeamUp")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param transport Unit
    ---@param bone Bone
    OnUnitAttachedToTransport = function(self, unit, transport, bone)
        LOG("OnUnitAttachedToTransport")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param transport Unit
    ---@param bone Bone
    OnUnitDetachedFromTransport = function(self, unit, transport, bone)
        LOG("OnUnitDetachedFromTransport")
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

        LOG("OnUnitAddToStorage")
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

        LOG("OnUnitRemoveFromStorage")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param teleporter any
    ---@param location Vector
    ---@param orientation Quaternion
    OnUnitTeleportUnit = function(self, unit, teleporter, location, orientation)
        LOG("OnUnitTeleportUnit")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitFailedTeleport = function(self, unit)
        LOG("OnUnitFailedTeleport")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitShieldEnabled = function(self, unit)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnShieldEnabled(unit)
        end

        LOG("OnUnitShieldEnabled")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitShieldDisabled = function(self, unit)
        -- awareness of event for AI
        local aiPlatoon = unit.JoeData.Behavior
        if aiPlatoon then
            aiPlatoon:OnShieldDisabled(unit)
        end

        LOG("OnUnitShieldDisabled")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitNukeArmed = function(self, unit)
        LOG("OnUnitNukeArmed")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitNukeLaunched = function(self, unit)
        LOG("OnUnitNukeLaunched")
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

        LOG("OnUnitWorkBegin")
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

        LOG("OnUnitWorkEnd")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param work any
    OnUnitWorkFail = function(self, unit, work)
        LOG("OnUnitWorkFail")
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

        LOG("OnUnitMissileImpactShield")
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

        LOG("OnUnitMissileImpactTerrain")
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

        LOG("OnUnitMissileIntercepted")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    OnUnitStartSacrifice = function(self, unit, target)
        LOG("OnUnitStartSacrifice")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    ---@param target Unit
    OnUnitStopSacrifice = function(self, unit, target)
        LOG("OnUnitStopSacrifice")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitConsumptionActive = function(self, unit)
        LOG("OnUnitConsumptionActive")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitConsumptionInActive = function(self, unit)
        LOG("OnUnitConsumptionInActive")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitProductionActive = function(self, unit)
        LOG("OnUnitProductionActive")
    end,

    ---@param self EasyAIBrain
    ---@param unit JoeUnit
    OnUnitProductionInActive = function(self, unit)
        LOG("OnUnitProductionInActive")
    end,

    --#endregion
    ---------------------------------------------------------------------------
}
