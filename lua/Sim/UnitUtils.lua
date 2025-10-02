local ArrayContains = import("/mods/fa-joe-ai/lua/Shared/TableUtils.lua").ArrayContains

-- Upvalue scope for performance
local TableInsert = table.insert
local TableSetn = table.setn
local TableGetn = table.getn

--- Reduces a list of units to a list of unique blueprint identifiers.
---@param units Unit[]
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
---@param units Unit[]
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
---@param units Unit[]
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