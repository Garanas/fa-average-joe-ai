-- upvalue scope for performance
local TableGetn = table.getn
local TableSetn = table.setn

--- Retrieves the first prop with a mass value that is equivalent or greater than (>=) the threshold.
---@param cell AIGridReclaimCell
---@param threshold number
---@return Prop?
FirstProp = function(cell, threshold)
    for _, prop in cell.Reclaim do
        if prop.MaxMassReclaim >= threshold then
            return prop
        end
    end

    return nil
end

--- Builds an array of all props with sufficient mass value in the given area.
---@param px number         # x world coordinate
---@param pz number         # z world coordinate
---@param radius number     # in ogrids
---@param threshold number  
FindPropsInArea = function(px, pz, radius, threshold)
    DrawCircle({ px, GetSurfaceHeight(px, pz), pz}, radius, 'ffffff')
    local props = GetReclaimablesInRect(px - radius, pz - radius, px + radius, pz + radius)
    if not props then
        return {}
    end

    -- re-use the table we received by the engine to filter information
    local free = 1
    for k = 1, TableGetn(props) do
        local prop = props[k]
        props[k] = nil
        if prop.MaxMassReclaim >= threshold then
            props[free] = prop
            free = free + 1
        end
    end

    TableSetn(props, free - 1)
    return props
end