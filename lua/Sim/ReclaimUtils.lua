local VectorUtils = import("/mods/fa-joe-ai/lua/Shared/VectorUtils.lua")

-- upvalue scope for performance
local TableGetn = table.getn
local TableSetn = table.setn

local MathMin = math.min

local IssueMove = IssueMove
local IssueReclaim = IssueReclaim

--- Retrieves the first prop with a mass value that is equivalent or greater than (>=) the threshold.
---@param cell AIGridReclaimCell
---@param threshold number
---@return Prop?
FirstPropOfCell = function(cell, threshold)
    for _, prop in cell.Reclaim do
        if prop.MaxMassReclaim >= threshold then
            return prop
        end
    end

    return nil
end

--- Construct an array of all props in a given area.
---@param px number         # in world coordinates
---@param pz number         # in world coordinates
---@param radius number     # in world coordinates
---@return Prop[]
FindPropsInArea = function(px, pz, radius)
    local props = GetReclaimablesInRect(px - radius, pz - radius, px + radius, pz + radius)
    if not props then
        return {}
    end

    local free = 1
    for k = 1, TableGetn(props) do
        local prop = props[k]
        props[k] = nil

        if prop.IsProp then
            props[free] = prop
            free = free + 1
        end
    end

    TableSetn(props, free - 1)
    return props
end

---@param units Unit[]
---@param props Prop[]
IssueReclaimAtDistance = function(units, props, distance)
    -- table to re-use for move orders
    local target = {0, 0, 0}
    local ox, _, oz = units[1]:GetPositionXYZ()

    for k = 1, table.getn(props) do
        local prop = props[k]
        local blueprint = prop:GetBlueprint()

        -- we want to reclaim tree groups from a distance
        if prop.IsTreeGroup then
            local tx, _, tz = prop:GetPositionXYZ()
            local mx, mz = VectorUtils.PointCloseToXZ(ox, oz, tx, tz, distance + MathMin(blueprint.SizeX, blueprint.SizeZ))

            target[1] = mx
            target[2] = GetSurfaceHeight(mx, mz)
            target[3] = mz
            IssueMove(units, target)
        end

        IssueReclaim(units, prop)
    end

end
