
-- upvalue scope for performance
local TableInsert = table.insert
local TableSetn = table.setn
local TableGetn = table.getn

---@param a Entity | { SortInPlaceByDistanceXZ: number }
---@param b Entity | { SortInPlaceByDistanceXZ: number }
---@return boolean
local function SortByDistanceLambda(a, b)
    return a.SortInPlaceByDistanceXZ < b.SortInPlaceByDistanceXZ
end

---@overload fun (entities: Prop[], ox: number, oz: number): Prop[]
---@overload fun (entities: Unit[], ox: number, oz: number): Unit[]
---@param entities Entity[]
---@param ox number
---@param oz number
SortInPlaceByDistanceXZ = function(entities, ox, oz)
    -- compute the distance of each entity from the origin
    for k = 1, TableGetn(entities) do
        local entity = entities[k]
        local px, _, pz = entity:GetPositionXYZ()
        entity.SortInPlaceByDistanceXZ = (px - ox) * (px - ox) + (pz - oz) * (pz - oz)
    end

    -- sort in place
    table.sort(entities, SortByDistanceLambda)

    -- remove the temporary field
    for k = 1, TableGetn(entities) do
        entities[k].SortInPlaceByDistanceXZ = nil
    end
end

---@overload fun (entities: Prop[], origin: Vector): Prop[]
---@overload fun (entities: Unit[], origin: Vector): Unit[]
---@param entities Entity[]
---@param origin Vector
SortInPlaceByDistance = function(entities, origin)
    return SortInPlaceByDistanceXZ(entities, origin[1], origin[3])
end