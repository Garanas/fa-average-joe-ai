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

--- High-level grouping for an identifier, used to bucket identifiers in UI lists.
---@alias JoeBuildingIdentifierGroup
--- | 'Energy'
--- | 'Mass'
--- | 'LandFactory'
--- | 'AirFactory'
--- | 'SeaFactory'
--- | 'Defense'
--- | 'Intel'
--- | 'Artillery'
--- | 'StrategicMissile'
--- | 'Experimental'
--- | 'Support'

--- Per-identifier metadata. Each entry holds the entity category for unit-id resolution plus a debug color, the expected skirt size, and the skirt's offset from the unit's anchor point. The skirt is the keep-out rectangle the engine reserves around the structure on the build grid; offsets are sourced from each unit's `Physics.SkirtOffsetX/Z` blueprint and listed in `units.md`. For naval factories the skirt offset varies by faction (e.g. UEF -7/-1 vs Aeon -6/-2); the metadata records the most common value (-6/-2).
---@class JoeBuildingIdentifierMetadata
---@field Group JoeBuildingIdentifierGroup  # High-level grouping used by UI lists.
---@field Category EntityCategory           # The entity category that selects matching unit IDs.
---@field Color Color                       # Hex color used by debug-draw helpers.
---@field SizeX number                      # Expected skirt size X (in build cells).
---@field SizeZ number                      # Expected skirt size Z (in build cells).
---@field SkirtOffsetX number               # Offset of the skirt rectangle from the unit anchor on the X axis.
---@field SkirtOffsetZ number               # Offset of the skirt rectangle from the unit anchor on the Z axis.

---@type table<JoeBuildingIdentifier, JoeBuildingIdentifierMetadata>
local MapToEntityCategories = {
    -- Energy Structures
    T1EnergyProduction = { Group = 'Energy', Category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH1, Color = 'ffff00', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
    T1HydroCarbon      = { Group = 'Energy', Category = categories.STRUCTURE * categories.HYDROCARBON * categories.TECH1, Color = 'ffdd00', SizeX = 6, SizeZ = 6, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T2EnergyProduction = { Group = 'Energy', Category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH2, Color = 'ffcc00', SizeX = 6, SizeZ = 6, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T3EnergyProduction = { Group = 'Energy', Category = categories.STRUCTURE * categories.ENERGYPRODUCTION * categories.TECH3, Color = 'ffaa00', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    EnergyStorage      = { Group = 'Energy', Category = categories.STRUCTURE * categories.ENERGYSTORAGE, Color = '888844', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },

    -- Mass Structures
    T1Resource     = { Group = 'Mass', Category = categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH1, Color = 'ff8800', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
    T2Resource     = { Group = 'Mass', Category = categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH2, Color = 'ff7700', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
    T3Resource     = { Group = 'Mass', Category = categories.STRUCTURE * categories.MASSEXTRACTION * categories.TECH3, Color = 'ff6600', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
    T1MassCreation = { Group = 'Mass', Category = categories.STRUCTURE * categories.MASSFABRICATION * categories.TECH2, Color = 'ffaa44', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
    T3MassCreation = { Group = 'Mass', Category = categories.STRUCTURE * categories.MASSFABRICATION * categories.TECH3, Color = 'ff9933', SizeX = 6, SizeZ = 6, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    MassStorage    = { Group = 'Mass', Category = categories.STRUCTURE * categories.MASSSTORAGE, Color = '884422', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },

    -- Land Factory Structures
    LandFactory          = { Group = 'LandFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.LAND, Color = '6699ff', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T1LandFactory        = { Group = 'LandFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH1, Color = '4488ff', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T2LandFactory        = { Group = 'LandFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2, Color = '3377ee', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T2SupportLandFactory = { Group = 'LandFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH2 * categories.SUPPORTFACTORY, Color = '5599ff', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T3LandFactory        = { Group = 'LandFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3, Color = '2266dd', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T3SupportLandFactory = { Group = 'LandFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 * categories.SUPPORTFACTORY, Color = '4488ee', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T3QuantumGate        = { Group = 'LandFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.LAND * categories.TECH3 * categories.GATE, Color = 'aa44ff', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },

    -- Air Factory Structures
    AirFactory           = { Group = 'AirFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.AIR, Color = '22eeff', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T1AirFactory         = { Group = 'AirFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH1, Color = '00ddff', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T2AirFactory         = { Group = 'AirFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH2, Color = '00ccee', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T2SupportAirFactory  = { Group = 'AirFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH2 * categories.SUPPORTFACTORY, Color = '22ddff', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T3AirFactory         = { Group = 'AirFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3, Color = '00bbee', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T3SupportAirFactory  = { Group = 'AirFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.AIR * categories.TECH3 * categories.SUPPORTFACTORY, Color = '44ccff', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T2AirStagingPlatform = { Group = 'AirFactory', Category = categories.STRUCTURE * categories.AIRSTAGINGPLATFORM, Color = '88ddff', SizeX = 6, SizeZ = 6, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },

    -- Sea Factory Structures (skirt offsets vary per faction; -6/-2 = Aeon/Cybran, Seraphim is -2/-2, UEF is -7/-1)
    NavalFactory        = { Group = 'SeaFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.NAVAL, Color = '3377ee', SizeX = 12, SizeZ = 14, SkirtOffsetX = -6, SkirtOffsetZ = -2 },
    T1SeaFactory        = { Group = 'SeaFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH1, Color = '2266dd', SizeX = 12, SizeZ = 14, SkirtOffsetX = -6, SkirtOffsetZ = -2 },
    T2SeaFactory        = { Group = 'SeaFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2, Color = '1155cc', SizeX = 12, SizeZ = 14, SkirtOffsetX = -6, SkirtOffsetZ = -2 },
    T2SupportSeaFactory = { Group = 'SeaFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH2 * categories.SUPPORTFACTORY, Color = '3377dd', SizeX = 12, SizeZ = 14, SkirtOffsetX = -6, SkirtOffsetZ = -2 },
    T3SeaFactory        = { Group = 'SeaFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3, Color = '0044bb', SizeX = 12, SizeZ = 14, SkirtOffsetX = -6, SkirtOffsetZ = -2 },
    T3SupportSeaFactory = { Group = 'SeaFactory', Category = categories.STRUCTURE * categories.FACTORY * categories.NAVAL * categories.TECH3 * categories.SUPPORTFACTORY, Color = '2266dd', SizeX = 12, SizeZ = 14, SkirtOffsetX = -6, SkirtOffsetZ = -2 },

    -- Defense Structures
    Wall             = { Group = 'Defense', Category = categories.STRUCTURE * categories.WALL, Color = '884422', SizeX = 1, SizeZ = 1, SkirtOffsetX = 0, SkirtOffsetZ = 0 },
    T1GroundDefense  = { Group = 'Defense', Category = categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH1, Color = 'ff3300', SizeX = 1, SizeZ = 1, SkirtOffsetX = 0, SkirtOffsetZ = 0 },
    T2GroundDefense  = { Group = 'Defense', Category = categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH2, Color = 'ee2200', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
    T3GroundDefense  = { Group = 'Defense', Category = categories.STRUCTURE * categories.DIRECTFIRE * categories.TECH3, Color = 'cc1100', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
    T1AADefense      = { Group = 'Defense', Category = categories.STRUCTURE * categories.ANTIAIR * categories.TECH1, Color = 'ff44ff', SizeX = 1, SizeZ = 1, SkirtOffsetX = 0, SkirtOffsetZ = 0 },
    T2AADefense      = { Group = 'Defense', Category = categories.STRUCTURE * categories.ANTIAIR * categories.TECH2, Color = 'ee22ee', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
    T3AADefense      = { Group = 'Defense', Category = categories.STRUCTURE * categories.ANTIAIR * categories.TECH3, Color = 'cc11cc', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
    T1NavalDefense   = { Group = 'Defense', Category = categories.STRUCTURE * categories.ANTINAVY * categories.TECH1, Color = '00aaaa', SizeX = 1, SizeZ = 1, SkirtOffsetX = 0, SkirtOffsetZ = 0 },
    T2NavalDefense   = { Group = 'Defense', Category = categories.STRUCTURE * categories.ANTINAVY * categories.TECH2, Color = '008888', SizeX = 3, SizeZ = 3, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
    T2ShieldDefense  = { Group = 'Defense', Category = categories.STRUCTURE * categories.SHIELD * categories.TECH2, Color = '44ff44', SizeX = 6, SizeZ = 6, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T3ShieldDefense  = { Group = 'Defense', Category = categories.STRUCTURE * categories.SHIELD * categories.TECH3, Color = '22dd22', SizeX = 6, SizeZ = 6, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T2MissileDefense = { Group = 'Defense', Category = categories.STRUCTURE * categories.ANTIMISSILE * categories.TECH2, Color = 'ff8888', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },

    -- Intelligence Structures
    T1Radar       = { Group = 'Intel', Category = categories.STRUCTURE * categories.RADAR * categories.TECH1, Color = 'ffffff', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
    T2Radar       = { Group = 'Intel', Category = categories.STRUCTURE * categories.RADAR * categories.TECH2, Color = 'eeeeee', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
    T3Radar       = { Group = 'Intel', Category = categories.STRUCTURE * categories.RADAR * categories.TECH3, Color = 'cccccc', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
    T2RadarJammer = { Group = 'Intel', Category = categories.STRUCTURE * categories.COUNTERINTELLIGENCE * categories.TECH2, Color = 'aaaaaa', SizeX = 6, SizeZ = 6, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T1Sonar       = { Group = 'Intel', Category = categories.STRUCTURE * categories.SONAR * categories.TECH1, Color = '88ddff', SizeX = 1, SizeZ = 1, SkirtOffsetX = 0, SkirtOffsetZ = 0 },
    T2Sonar       = { Group = 'Intel', Category = categories.STRUCTURE * categories.SONAR * categories.TECH2, Color = '66ccee', SizeX = 1, SizeZ = 1, SkirtOffsetX = 0, SkirtOffsetZ = 0 },
    T3Sonar       = { Group = 'Intel', Category = categories.STRUCTURE * categories.SONAR * categories.TECH3, Color = '44bbdd', SizeX = 1, SizeZ = 1, SkirtOffsetX = 0, SkirtOffsetZ = 0 },

    -- Artillery Structures
    T2Artillery = { Group = 'Artillery', Category = categories.STRUCTURE * categories.ARTILLERY * categories.TECH2, Color = 'aa1100', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
    T3Artillery = { Group = 'Artillery', Category = categories.STRUCTURE * categories.ARTILLERY * categories.TECH3, Color = '880000', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T4Artillery = { Group = 'Artillery', Category = categories.STRUCTURE * categories.ARTILLERY * categories.EXPERIMENTAL, Color = '660000', SizeX = 10, SizeZ = 10, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },

    -- Strategic Missile Structures
    T2StrategicMissile        = { Group = 'StrategicMissile', Category = categories.STRUCTURE * categories.SILO * categories.TECH2, Color = '444444', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
    T3StrategicMissile        = { Group = 'StrategicMissile', Category = categories.STRUCTURE * categories.SILO * categories.TECH3, Color = '222222', SizeX = 6, SizeZ = 6, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T3StrategicMissileDefense = { Group = 'StrategicMissile', Category = categories.STRUCTURE * categories.ANTIMISSILE * categories.SILO * categories.TECH3, Color = '999999', SizeX = 3, SizeZ = 3, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },

    -- Experimentals (mobile units, footprints are best-guess for planning)
    T4LandExperimental1     = { Group = 'Experimental', Category = categories.MOBILE * categories.LAND * categories.EXPERIMENTAL, Color = 'ff00aa', SizeX = 9, SizeZ = 9, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T4LandExperimental2     = { Group = 'Experimental', Category = categories.MOBILE * categories.LAND * categories.EXPERIMENTAL, Color = 'dd0099', SizeX = 9, SizeZ = 9, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T4AirExperimental1      = { Group = 'Experimental', Category = categories.MOBILE * categories.AIR * categories.EXPERIMENTAL, Color = 'cc44dd', SizeX = 8, SizeZ = 8, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T4SeaExperimental1      = { Group = 'Experimental', Category = categories.MOBILE * categories.NAVAL * categories.EXPERIMENTAL, Color = '8822aa', SizeX = 16, SizeZ = 16, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },
    T4SatelliteExperimental = { Group = 'Experimental', Category = categories.MOBILE * categories.SATELLITE * categories.EXPERIMENTAL, Color = 'aa44cc', SizeX = 2, SizeZ = 2, SkirtOffsetX = -1.5, SkirtOffsetZ = -1.5 },

    -- Misc / Support Structures
    T2EngineerSupport = { Group = 'Support', Category = categories.STRUCTURE * (categories.PODSTAGINGPLATFORM + categories.ENGINEERSTATION) * categories.TECH2, Color = '00aaaa', SizeX = 2, SizeZ = 2, SkirtOffsetX = -0.5, SkirtOffsetZ = -0.5 },
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
