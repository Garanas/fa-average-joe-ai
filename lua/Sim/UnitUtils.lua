local ArrayContains = import("/mods/fa-joe-ai/lua/Shared/TableUtils.lua").ArrayContains
local MapUtils = import("/mods/fa-joe-ai/lua/Sim/MapUtils.lua")
local BoundingBoxUtils = import("/mods/fa-joe-ai/lua/Shared/BoundingBoxUtils.lua")

-- Upvalue scope for performance
local TableInsert = table.insert
local TableSetn = table.setn
local TableGetn = table.getn

--- Reduces a list of units to a list of unique blueprint identifiers.
---@param units JoeUnit[]
---@param cache? UnitId[]       # Does not reset the content of the cache. Use table.getn to iterate it.
---@return UnitId[]
GetUniqueUnitIds = function(units, cache)
    cache = cache or {}
    TableSetn(cache, 0)

    for k = 1, TableGetn(units) do
        local unit = units[k]
        local unitId = unit:GetUnitId()

        if not ArrayContains(cache, unitId) then
            TableInsert(cache, unit:GetUnitId())
        end
    end

    return cache
end

--- Reduces a list of units to the most restrictive navigational layer.
---@param units JoeUnit[]
---@return NavLayers
GetRestrictingNavigationalLayer = function(units)
    -- TODO: use a cache?
    local unitIds = GetUniqueUnitIds(units)

    -- by default, we assume the least restrictive navigational layer
    local layer = 'Air'

    for _, unitId in unitIds do
        local blueprint = __blueprints[unitId]
        local mType = blueprint.Physics.MotionType

        -- something could be amphibious, but it's not the most restrictive layer
        if (mType == 'RULEUMT_AmphibiousFloating' or mType == 'RULEUMT_Hover' or mType == 'RULEUMT_Amphibious') then
            layer = 'Amphibious'
        elseif (mType == 'RULEUMT_Water' or mType == 'RULEUMT_SurfacingSub') then
            -- nothing more restrictive
            return 'Water'
        elseif (mType == 'RULEUMT_Biped' or mType == 'RULEUMT_Land') then
            -- nothing more restrictive
            return 'Land'
        end
    end

    return layer
end

---@param self AIPlatoonBehavior
---@param units JoeUnit[]
---@param origin Vector
---@param waypoint Vector
---@param formation? UnitFormations # Defaults to 'GrowthFormation'
---@return SimCommand
IssueFormMoveToWaypoint = function(self, units, origin, waypoint, formation)
    formation = formation or 'GrowthFormation'

    -- compute normalized direction
    local dx = waypoint[1] - origin[1]
    local dz = waypoint[3] - origin[3]
    local di = 1 / math.sqrt(dx * dx + dz * dz)
    dx = di * dx
    dz = di * dz

    -- compute radians
    local rads = math.acos(dz)
    if dx < 0 then
        rads = 2 * 3.14159 - rads
    end

    -- convert to degrees
    local degrees = 57.2958279 * rads

    return IssueFormMove(units, waypoint, formation, degrees)
end

--- Validates whether a given unit type can be built at a given location for the given brain.
---@param brain JoeBrain
---@param location Vector
---@param unitId UnitId
ValidateBuildSite = function(brain, location, unitId)
    -- we can't built unknown blueprints
    local blueprint = __blueprints[unitId]
    if not blueprint then
        return false
    end

    -- local value for performance
    local lx, lz = location[1], location[3]
    local fsx, fsz = 0.5 * (blueprint.Physics.SkirtSizeX or 1), 0.5 * (blueprint.Physics.SkirtSizeZ or 1)

    -- can't built too close to map border
    if not MapUtils.IsBuildSiteInArea(lx, lz, fsx, fsz) then
        return false
    end

    -- engine checks for resources, terrain height and occupation grid. Unfortunately the latter appears to hallucinate for (support) factories on occasion.
    if not brain:CanBuildStructureAt(unitId, location) then
        return false
    end

    -- find nearby entities that may block the construction
    local ax0 = math.floor(lx) - fsx + 0.5
    local az0 = math.floor(lz) - fsz + 0.5
    local ax1 = math.floor(lx) + fsx + 0.5
    local az1 = math.floor(lz) + fsz + 0.5
    local entities = GetReclaimablesInRect(ax0 - 4, az0 - 4, ax1 + 4, az1 + 4)


    -- manually check that there are no overlapping structures with the build site. Unfortunately, the use
    -- of `CanBuildStructureAt` above only works ~95% of the time. There are edge cases with (support) factories
    -- where the engine function fails. Therefore we have to check for overlapping structures here.

    if entities then
        for k = 1, table.getn(entities) do
            local entity = entities[k]
            if EntityCategoryContains(categories.STRUCTURE, entity) then
                local bpx, _, bpz = entity:GetPositionXYZ()
                local blueprint = entity:GetBlueprint()
                local bfpx, bfpz = 0.5 * (blueprint.Physics.SkirtSizeX or 1), 0.5 * (blueprint.Physics.SkirtSizeZ or 1)

                local bx0 = bpx - bfpx
                local bz0 = bpz - bfpz
                local bx1 = bpx + bfpx
                local bz1 = bpz + bfpz

                -- can't build on top of other structures
                if BoundingBoxUtils.Overlap(
                    ax0, az0, ax1, az1,
                    bx0, bz0, bx1, bz1
                )
                then
                    return false
                end
            end
        end
    end

    return true
end
