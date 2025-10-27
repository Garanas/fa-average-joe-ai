--- These are the identifiers that we use to identify building types in base chunks. We can map these to other interesting properties, such as entity categories.
---@alias JoeBuildingIdentifier
--- -- Energy Structures
--- | 'T1EnergyProduction'
--- | 'T1HydroCarbon'
--- | 'T2EnergyProduction'
--- | 'T3EnergyProduction'
--- | 'EnergyStorage'
---
--- -- Mass Structures
--- | 'T1Resource'
--- | 'T1MassCreation'
--- | 'T2Resource'
--- | 'T3Resource'
--- | 'T3MassCreation'
--- | 'T3MassExtraction'
--- | 'MassStorage'
---
--- -- Land Factory Structures
--- | 'T1LandFactory'
--- | 'T2LandFactory'
--- | 'T2SupportLandFactory'
--- | 'T3LandFactory'
--- | 'T3SupportLandFactory'
--- | 'T3QuantumGate'
---
--- -- Air Factory Structures
--- | 'T1AirFactory'
--- | 'T2AirFactory'
--- | 'T2SupportAirFactory'
--- | 'T3AirFactory'
--- | 'T3SupportAirFactory'
--- | 'T2AirStagingPlatform'
---
--- -- Sea Factory Structures
--- | 'T1SeaFactory'
--- | 'T2SeaFactory'
--- | 'T2SupportSeaFactory'
--- | 'T3SeaFactory'
--- | 'T3SupportSeaFactory'
---
--- -- Defense Structures
--- | 'Wall'
--- | 'T1GroundDefense'
--- | 'T2GroundDefense'
--- | 'T3GroundDefense'
--- | 'T1AADefense'
--- | 'T2AADefense'
--- | 'T3AADefense'
--- | 'T1NavalDefense'
--- | 'T2NavalDefense'
--- | 'T2ShieldDefense'
--- | 'T3ShieldDefense'
--- | 'T2MissileDefense'
---
--- -- Intelligence Structures
--- | 'T1Radar'
--- | 'T2Radar'
--- | 'T3Radar'
--- | 'T2RadarJammer'
--- | 'T1Sonar'
--- | 'T2Sonar'
--- | 'T3Sonar'
---
--- -- Artillery Structures
--- | 'T2Artillery'
--- | 'T3Artillery'
--- | 'T4Artillery'
---
--- -- Strategic Missile Structures
--- | 'T2StrategicMissile'
--- | 'T3StrategicMissile'
--- | 'T3StrategicMissileDefense'
---
--- -- Experimental Structures
--- | 'T4LandExperimental1'
--- | 'T4LandExperimental2'
--- | 'T4AirExperimental1'
--- | 'T4SeaExperimental1'
--- | 'T4SatelliteExperimental'
---
--- -- Misc / Support Structures
--- | '1x1Concrete'
--- | '2x2Concrete'
--- | 'T2EngineerSupport'

local MapToEntityCategories = {
    -- Energy Structures
    T1EnergyProduction = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH1,
    T1HydroCarbon = categories.STRUCTURE * categories.HYDROCARBON * categories.TECH1,
    T2EnergyProduction = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH2,
    T3EnergyProduction = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3,
    EnergyStorage = categories.STRUCTURE * categories.ENERGYSTORAGE,

    -- Mass Structures
    T1Resource = categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH1,
    T2Resource = categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH2,
    T3Resource = categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH3,
    T1MassCreation = categories.STRUCTURE * categories.MASSFABRICATION * categories.TECH2,
    T3MassCreation = categories.STRUCTURE * categories.MASSFABRICATION * categories.TECH3,
    MassStorage = categories.STRUCTURE * categories.MASSSTORAGE,

    -- Land Factory Structures
    T1LandFactory = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1,
    T2LandFactory = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2,
    T2SupportLandFactory = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 * categories.SUPPORTFACTORY,
    T3LandFactory = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3,
    T3SupportLandFactory = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 * categories.SUPPORTFACTORY,
    T3QuantumGate = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 * categories.GATE,

    -- Air Factory Structures
    T1AirFactory = categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1,
    T2AirFactory = categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH2,
    T2SupportAirFactory = categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH2 * categories.SUPPORTFACTORY,
    T3AirFactory = categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3,
    T3SupportAirFactory = categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 * categories.SUPPORTFACTORY,
    T2AirStagingPlatform = categories.STRUCTURE * categories.AIRSTAGINGPLATFORM,

    -- Sea Factory Structures
    T1SeaFactory = categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH1,
    T2SeaFactory = categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2,
    T2SupportSeaFactory = categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2 * categories.SUPPORTFACTORY,
    T3SeaFactory = categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3,
    T3SupportSeaFactory = categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 * categories.SUPPORTFACTORY,

    -- Defense Structures
    Wall = categories.STRUCTURE * categories.WALL,
    T1GroundDefense = categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH1,
    T2GroundDefense = categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH2,
    T3GroundDefense = categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH3,
    T1AADefense = categories.STRUCTURE * categories.ANTIAIR * categories.TECH1,
    T2AADefense = categories.STRUCTURE * categories.ANTIAIR * categories.TECH2,
    T3AADefense = categories.STRUCTURE * categories.ANTIAIR * categories.TECH3,
    T1NavalDefense = categories.STRUCTURE * categories.ANTINAVY * categories.TECH1,
    T2NavalDefense = categories.STRUCTURE * categories.ANTINAVY * categories.TECH2,
    T2ShieldDefense = categories.STRUCTURE * categories.SHIELD * categories.TECH2,
    T3ShieldDefense = categories.STRUCTURE * categories.SHIELD * categories.TECH3,
    T2MissileDefense = categories.STRUCTURE * categories.ANTIMISSILE * categories.TECH2,

    -- Intelligence Structures
    T1Radar = categories.STRUCTURE * categories.RADAR * categories.TECH1,
    T2Radar = categories.STRUCTURE * categories.RADAR * categories.TECH2,
    T3Radar = categories.STRUCTURE * categories.RADAR * categories.TECH3,
    T2RadarJammer = categories.STRUCTURE * categories.COUNTERINTELLIGENCE * categories.TECH2,
    T1Sonar = categories.STRUCTURE * categories.SONAR * categories.TECH1,
    T2Sonar = categories.STRUCTURE * categories.SONAR * categories.TECH2,
    T3Sonar = categories.STRUCTURE * categories.SONAR * categories.TECH3,

    -- Artillery Structures
    T2Artillery = categories.STRUCTURE * categories.ARTILLERY * categories.TECH2,
    T3Artillery = categories.STRUCTURE * categories.ARTILLERY * categories.TECH3,
    T4Artillery = categories.STRUCTURE * categories.ARTILLERY * categories.EXPERIMENTAL,

    -- Strategic Missile Structures
    T2StrategicMissile = categories.STRUCTURE * categories.SILO * categories.TECH2,
    T3StrategicMissile = categories.STRUCTURE * categories.SILO * categories.TECH3,
    T3StrategicMissileDefense = categories.STRUCTURE * categories.ANTIMISSILE * categories.SILO * categories.TECH3,

    -- Experimentals
    T4LandExperimental1 = categories.MOBILE * categories.LAND * categories.EXPERIMENTAL,
    T4LandExperimental2 = categories.MOBILE * categories.LAND * categories.EXPERIMENTAL,
    T4AirExperimental1 = categories.MOBILE * categories.AIR * categories.EXPERIMENTAL,
    T4SeaExperimental1 = categories.MOBILE * categories.NAVAL * categories.EXPERIMENTAL,
    T4SatelliteExperimental = categories.MOBILE * categories.SATELLITE * categories.EXPERIMENTAL,

    -- Misc / Support Structures
    T2EngineerSupport = categories.STRUCTURE * (categories.PODSTAGINGPLATFORM + categories.ENGINEERSTATION) * categories.TECH2,
}

--- Categories of units do not change during run time. It's safe to cache the results.
---@type table<UnitId, JoeBuildingIdentifier>
local MappedUnits = {}

--- The order in which to map units to building identifiers. This is important for cases where multiple identifiers could match a single unit.
---@type JoeBuildingIdentifier[]
local MappingOrder = {
    -- Most restrictive
    "T1Resource",
    "T2Resource",
    "T3Resource",
    "T1HydroCarbon",

    -- Strategic Missile Structures
    "T3StrategicMissileDefense",
    "T3StrategicMissile",
    "T2StrategicMissile",

    -- Experimental units
    "T4LandExperimental1",
    "T4LandExperimental2",
    "T4AirExperimental1",
    "T4SeaExperimental1",
    "T4SatelliteExperimental",

    -- Artillery
    "T2Artillery",
    "T3Artillery",
    "T4Artillery",

    -- Factories
    "T1LandFactory",
    "T2LandFactory",
    "T2SupportLandFactory",
    "T3LandFactory",
    "T3SupportLandFactory",
    "T3QuantumGate",

    "T1AirFactory",
    "T2AirFactory",
    "T2SupportAirFactory",
    "T3AirFactory",
    "T3SupportAirFactory",
    "T2AirStagingPlatform",

    "T1SeaFactory",
    "T2SeaFactory",
    "T2SupportSeaFactory",
    "T3SeaFactory",
    "T3SupportSeaFactory",

    -- Defenses
    "Wall",
    "T1GroundDefense",
    "T2GroundDefense",
    "T3GroundDefense",
    "T1AADefense",
    "T2AADefense",
    "T3AADefense",
    "T1NavalDefense",
    "T2NavalDefense",
    "T2ShieldDefense",
    "T3ShieldDefense",
    "T2MissileDefense",

    -- Intelligence
    "T1Radar",
    "T2Radar",
    "T3Radar",
    "T2RadarJammer",
    "T1Sonar",
    "T2Sonar",
    "T3Sonar",

    -- Various units may have a small amount of resource production, lowest priority
    "T1EnergyProduction",
    "T2EnergyProduction",
    "T3EnergyProduction",
    "T1MassCreation",
    "T3MassCreation",

    -- Various units may have a small amount of resource storage, lowest priority
    "EnergyStorage",
    "MassStorage",
}

--- Maps a building template to an entity category.
---@param identifier JoeBuildingIdentifier
---@return EntityCategory
function MapToCategory(identifier)
    local category = MapToEntityCategories[identifier]
    if not category then
        error('No entity category mapped for chunk identifier: ' .. tostring(identifier))
    end

    return category
end

--- Maps a building template to an entity category suitable for a specific engineer.
---@param identifier JoeBuildingIdentifier
---@param engineer JoeUnit
---@return EntityCategory
function MapToCategoryForBuilder(identifier, engineer)
    local category = MapToCategory(identifier)

    local blueprint = engineer:GetBlueprint()
    local faction = blueprint.FactionCategory

    return category * (categories[faction] or categories.ALLUNITS)
end

--- Maps a unit to a building identifier.
---@overload fun(unit: JoeUnit): JoeBuildingIdentifier
---@param unit UnitId
---@return JoeBuildingIdentifier
function MapToIdentifier(unit)
    local unitId = unit.UnitId
    if type(unit) == "string" then
        unitId = unit
    end

    -- try to use the cache
    if MappedUnits[unitId] then
        return MappedUnits[unitId]
    end

    -- find the correct identifier
    for _, identifier in MappingOrder do
        local category = MapToCategory(identifier)
        if EntityCategoryContains(category, unitId) then
            MappedUnits[unitId] = identifier
            return identifier
        end
    end

    error('No chunk identifier mapped for unit: ' .. tostring(unitId))
end
