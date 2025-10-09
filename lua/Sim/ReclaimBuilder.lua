local ReclaimUtils = import("/mods/fa-joe-ai/lua/sim/ReclaimUtils.lua")
local EntityUtils = import("/mods/fa-joe-ai/lua/sim/EntityUtils.lua")

local TableGetn = table.getn
local TableSetn = table.setn
local TableInsert = table.insert

--- Builder pattern to manipulate props.
---@class ReclaimBuilder
---@field Entities Prop[]
ReclaimBuilder = ClassSimple {

    ---@param self ReclaimBuilder
    ---@param props Prop[]
    __init = function(self, props)
        self.Entities = props
    end,

    --- Filters the props in-place by mass value. All props with a mass value that is less than (>) the threshold are removed.
    ---@param self ReclaimBuilder
    ---@param threshold number
    ---@return ReclaimBuilder
    ReduceByMassValue = function(self, threshold)
        -- local scope for performance
        local props = self.Entities

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
        self.Entities = props

        return self
    end,

    --- Filters the props in-place by whether they obstruct build orders. All props that do not obstruct build orders are removed.
    ---@param self ReclaimBuilder
    ---@return ReclaimBuilder
    ReduceToBuildObstructing = function(self)
        -- local scope for performance
        local props = self.Entities

        local free = 1
        for k = 1, TableGetn(props) do
            local prop = props[k]
            props[k] = nil

            if prop.Blueprint.CategoriesHash["OBSTRUCTSBUILDING"] then
                props[free] = prop
                free = free + 1
            end
        end

        TableSetn(props, free - 1)
        self.Entities = props

        return self
    end,

    ---@param self ReclaimBuilder
    ---@param ox number
    ---@param oz number
    ---@return ReclaimBuilder
    SortByDistanceXZ = function(self, ox, oz)
        EntityUtils.SortInPlaceByDistanceXZ(self.Entities, ox, oz)
        return self
    end,

    ---@param self ReclaimBuilder
    ---@param origin Vector
    ---@return ReclaimBuilder
    SortByDistance = function(self, origin)
        return self:SortByDistanceXZ(origin[1], origin[3])
    end,

    ---@param self ReclaimBuilder
    ---@return Prop[]
    End = function(self)
        return self.Entities
    end,
}

--- Wraps a builder around all props in the given area.
---@param px number         # in world coordinates
---@param pz number         # in world coordinates
---@param radius number     # in world coordinates
---@return ReclaimBuilder
FromArea = function(px, pz, radius)
    return ReclaimBuilder(ReclaimUtils.FindPropsInArea(px, pz, radius))
end

--- Wraps a builder around a shallow copy of the props of the reclaim cell.
---@param cell AIGridReclaimCell
---@return ReclaimBuilder
FromCell = function(cell)
    local shallowCopy = {}
    for _, prop in cell.Reclaim do
        TableInsert(shallowCopy, prop)
    end

    return ReclaimBuilder(shallowCopy)
end

--- Wraps a builder around a shallow copy of the array of props.
---@param props Prop[]
---@return ReclaimBuilder
FromArray = function(props)
    local shallowCopy = {}
    for _, prop in props do
        TableInsert(shallowCopy, prop)
    end

    return ReclaimBuilder(shallowCopy)
end
