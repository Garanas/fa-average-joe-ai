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
--- | 'MassStorage'
---
--- -- Land Factory Structures
--- | 'LandFactory'
--- | 'T1LandFactory'
--- | 'T2LandFactory'
--- | 'T2SupportLandFactory'
--- | 'T3LandFactory'
--- | 'T3SupportLandFactory'
--- | 'T3QuantumGate'
---
--- -- Air Factory Structures
--- | 'AirFactory'
--- | 'T1AirFactory'
--- | 'T2AirFactory'
--- | 'T2SupportAirFactory'
--- | 'T3AirFactory'
--- | 'T3SupportAirFactory'
--- | 'T2AirStagingPlatform'
---
--- -- Sea Factory Structures
--- | 'NavalFactory'
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
--- | 'T2EngineerSupport'

--- Per-identifier metadata. Each entry holds the entity category for unit-id resolution plus a debug color and an expected footprint size used by chunk planning and visualization.
---@class JoeBuildingIdentifierMetadata
---@field Category EntityCategory   # The entity category that selects matching unit IDs.
---@field Color Color               # Hex color used by debug-draw helpers.
---@field SizeX number              # Expected footprint X (in build cells).
---@field SizeZ number              # Expected footprint Z (in build cells).

---@type table<JoeBuildingIdentifier, JoeBuildingIdentifierMetadata>
local MapToEntityCategories = {
    -- Energy Structures
    T1EnergyProduction = { Category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH1, Color = 'ffff00', SizeX = 2, SizeZ = 2 },
    T1HydroCarbon      = { Category = categories.STRUCTURE * categories.HYDROCARBON * categories.TECH1, Color = 'ffdd00', SizeX = 6, SizeZ = 6 },
    T2EnergyProduction = { Category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH2, Color = 'ffcc00', SizeX = 6, SizeZ = 6 },
    T3EnergyProduction = { Category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3, Color = 'ffaa00', SizeX = 8, SizeZ = 8 },
    EnergyStorage      = { Category = categories.STRUCTURE * categories.ENERGYSTORAGE, Color = '888844', SizeX = 2, SizeZ = 2 },

    -- Mass Structures
    T1Resource     = { Category = categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH1, Color = 'ff8800', SizeX = 2, SizeZ = 2 },
    T2Resource     = { Category = categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH2, Color = 'ff7700', SizeX = 2, SizeZ = 2 },
    T3Resource     = { Category = categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH3, Color = 'ff6600', SizeX = 2, SizeZ = 2 },
    T1MassCreation = { Category = categories.STRUCTURE * categories.MASSFABRICATION * categories.TECH2, Color = 'ffaa44', SizeX = 2, SizeZ = 2 },
    T3MassCreation = { Category = categories.STRUCTURE * categories.MASSFABRICATION * categories.TECH3, Color = 'ff9933', SizeX = 6, SizeZ = 6 },
    MassStorage    = { Category = categories.STRUCTURE * categories.MASSSTORAGE, Color = '884422', SizeX = 2, SizeZ = 2 },

    -- Land Factory Structures
    LandFactory          = { Category = categories.STRUCTURE * categories.FACTORY * categories.LAND, Color = '6699ff', SizeX = 8, SizeZ = 8 },
    T1LandFactory        = { Category = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1, Color = '4488ff', SizeX = 8, SizeZ = 8 },
    T2LandFactory        = { Category = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2, Color = '3377ee', SizeX = 8, SizeZ = 8 },
    T2SupportLandFactory = { Category = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 * categories.SUPPORTFACTORY, Color = '5599ff', SizeX = 8, SizeZ = 8 },
    T3LandFactory        = { Category = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3, Color = '2266dd', SizeX = 8, SizeZ = 8 },
    T3SupportLandFactory = { Category = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 * categories.SUPPORTFACTORY, Color = '4488ee', SizeX = 8, SizeZ = 8 },
    T3QuantumGate        = { Category = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 * categories.GATE, Color = 'aa44ff', SizeX = 8, SizeZ = 8 },

    -- Air Factory Structures
    AirFactory           = { Category = categories.STRUCTURE * categories.FACTORY * categories.AIR, Color = '22eeff', SizeX = 8, SizeZ = 8 },
    T1AirFactory         = { Category = categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1, Color = '00ddff', SizeX = 8, SizeZ = 8 },
    T2AirFactory         = { Category = categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH2, Color = '00ccee', SizeX = 8, SizeZ = 8 },
    T2SupportAirFactory  = { Category = categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH2 * categories.SUPPORTFACTORY, Color = '22ddff', SizeX = 8, SizeZ = 8 },
    T3AirFactory         = { Category = categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3, Color = '00bbee', SizeX = 8, SizeZ = 8 },
    T3SupportAirFactory  = { Category = categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 * categories.SUPPORTFACTORY, Color = '44ccff', SizeX = 8, SizeZ = 8 },
    T2AirStagingPlatform = { Category = categories.STRUCTURE * categories.AIRSTAGINGPLATFORM, Color = '88ddff', SizeX = 6, SizeZ = 6 },

    -- Sea Factory Structures
    NavalFactory        = { Category = categories.STRUCTURE * categories.FACTORY * categories.NAVAL, Color = '3377ee', SizeX = 12, SizeZ = 14 },
    T1SeaFactory        = { Category = categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH1, Color = '2266dd', SizeX = 12, SizeZ = 14 },
    T2SeaFactory        = { Category = categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2, Color = '1155cc', SizeX = 12, SizeZ = 14 },
    T2SupportSeaFactory = { Category = categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2 * categories.SUPPORTFACTORY, Color = '3377dd', SizeX = 12, SizeZ = 14 },
    T3SeaFactory        = { Category = categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3, Color = '0044bb', SizeX = 12, SizeZ = 14 },
    T3SupportSeaFactory = { Category = categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 * categories.SUPPORTFACTORY, Color = '2266dd', SizeX = 12, SizeZ = 14 },

    -- Defense Structures
    Wall             = { Category = categories.STRUCTURE * categories.WALL, Color = '884422', SizeX = 1, SizeZ = 1 },
    T1GroundDefense  = { Category = categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH1, Color = 'ff3300', SizeX = 1, SizeZ = 1 },
    T2GroundDefense  = { Category = categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH2, Color = 'ee2200', SizeX = 2, SizeZ = 2 },
    T3GroundDefense  = { Category = categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH3, Color = 'cc1100', SizeX = 2, SizeZ = 2 },
    T1AADefense      = { Category = categories.STRUCTURE * categories.ANTIAIR * categories.TECH1, Color = 'ff44ff', SizeX = 1, SizeZ = 1 },
    T2AADefense      = { Category = categories.STRUCTURE * categories.ANTIAIR * categories.TECH2, Color = 'ee22ee', SizeX = 2, SizeZ = 2 },
    T3AADefense      = { Category = categories.STRUCTURE * categories.ANTIAIR * categories.TECH3, Color = 'cc11cc', SizeX = 2, SizeZ = 2 },
    T1NavalDefense   = { Category = categories.STRUCTURE * categories.ANTINAVY * categories.TECH1, Color = '00aaaa', SizeX = 1, SizeZ = 1 },
    T2NavalDefense   = { Category = categories.STRUCTURE * categories.ANTINAVY * categories.TECH2, Color = '008888', SizeX = 3, SizeZ = 3 },
    T2ShieldDefense  = { Category = categories.STRUCTURE * categories.SHIELD * categories.TECH2, Color = '44ff44', SizeX = 6, SizeZ = 6 },
    T3ShieldDefense  = { Category = categories.STRUCTURE * categories.SHIELD * categories.TECH3, Color = '22dd22', SizeX = 6, SizeZ = 6 },
    T2MissileDefense = { Category = categories.STRUCTURE * categories.ANTIMISSILE * categories.TECH2, Color = 'ff8888', SizeX = 2, SizeZ = 2 },

    -- Intelligence Structures
    T1Radar       = { Category = categories.STRUCTURE * categories.RADAR * categories.TECH1, Color = 'ffffff', SizeX = 2, SizeZ = 2 },
    T2Radar       = { Category = categories.STRUCTURE * categories.RADAR * categories.TECH2, Color = 'eeeeee', SizeX = 2, SizeZ = 2 },
    T3Radar       = { Category = categories.STRUCTURE * categories.RADAR * categories.TECH3, Color = 'cccccc', SizeX = 2, SizeZ = 2 },
    T2RadarJammer = { Category = categories.STRUCTURE * categories.COUNTERINTELLIGENCE * categories.TECH2, Color = 'aaaaaa', SizeX = 6, SizeZ = 6 },
    T1Sonar       = { Category = categories.STRUCTURE * categories.SONAR * categories.TECH1, Color = '88ddff', SizeX = 1, SizeZ = 1 },
    T2Sonar       = { Category = categories.STRUCTURE * categories.SONAR * categories.TECH2, Color = '66ccee', SizeX = 1, SizeZ = 1 },
    T3Sonar       = { Category = categories.STRUCTURE * categories.SONAR * categories.TECH3, Color = '44bbdd', SizeX = 1, SizeZ = 1 },

    -- Artillery Structures
    T2Artillery = { Category = categories.STRUCTURE * categories.ARTILLERY * categories.TECH2, Color = 'aa1100', SizeX = 2, SizeZ = 2 },
    T3Artillery = { Category = categories.STRUCTURE * categories.ARTILLERY * categories.TECH3, Color = '880000', SizeX = 8, SizeZ = 8 },
    T4Artillery = { Category = categories.STRUCTURE * categories.ARTILLERY * categories.EXPERIMENTAL, Color = '660000', SizeX = 10, SizeZ = 10 },

    -- Strategic Missile Structures
    T2StrategicMissile        = { Category = categories.STRUCTURE * categories.SILO * categories.TECH2, Color = '444444', SizeX = 2, SizeZ = 2 },
    T3StrategicMissile        = { Category = categories.STRUCTURE * categories.SILO * categories.TECH3, Color = '222222', SizeX = 6, SizeZ = 6 },
    T3StrategicMissileDefense = { Category = categories.STRUCTURE * categories.ANTIMISSILE * categories.SILO * categories.TECH3, Color = '999999', SizeX = 3, SizeZ = 3 },

    -- Experimentals (mobile units, footprints are best-guess for planning)
    T4LandExperimental1     = { Category = categories.MOBILE * categories.LAND * categories.EXPERIMENTAL, Color = 'ff00aa', SizeX = 9, SizeZ = 9 },
    T4LandExperimental2     = { Category = categories.MOBILE * categories.LAND * categories.EXPERIMENTAL, Color = 'dd0099', SizeX = 9, SizeZ = 9 },
    T4AirExperimental1      = { Category = categories.MOBILE * categories.AIR * categories.EXPERIMENTAL, Color = 'cc44dd', SizeX = 8, SizeZ = 8 },
    T4SeaExperimental1      = { Category = categories.MOBILE * categories.NAVAL * categories.EXPERIMENTAL, Color = '8822aa', SizeX = 16, SizeZ = 16 },
    T4SatelliteExperimental = { Category = categories.MOBILE * categories.SATELLITE * categories.EXPERIMENTAL, Color = 'aa44cc', SizeX = 2, SizeZ = 2 },

    -- Misc / Support Structures
    T2EngineerSupport = { Category = categories.STRUCTURE * (categories.PODSTAGINGPLATFORM + categories.ENGINEERSTATION) * categories.TECH2, Color = '00aaaa', SizeX = 2, SizeZ = 2 },
}

--- Categories of units do not change during run time. It's safe to cache the results.
---@type table<UnitId, JoeBuildingIdentifier>
local MappedUnits = {}

--- The order in which to map units to building identifiers. This is important for cases where multiple identifiers could match a single unit. Exposed at module scope so callers can iterate the canonical identifier set without duplicating it.
---@type JoeBuildingIdentifier[]
MappingOrder = {
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

    -- Misc / Support Structures
    "T2EngineerSupport",

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

--- Returns the full metadata record for a building identifier (category, color, footprint).
---@param identifier JoeBuildingIdentifier
---@return JoeBuildingIdentifierMetadata
function MapToMetadata(identifier)
    local entry = MapToEntityCategories[identifier]
    if not entry then
        error('No metadata mapped for chunk identifier: ' .. tostring(identifier))
    end

    return entry
end

--- Maps a building template to an entity category.
---@param identifier JoeBuildingIdentifier
---@return EntityCategory
function MapToCategory(identifier)
    return MapToMetadata(identifier).Category
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
