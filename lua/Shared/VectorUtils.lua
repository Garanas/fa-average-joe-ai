--- Constructs a vector from an x and z coordinate, populating the y coordinate with the surface height.
---@param x number
---@param z number
---@return Vector
FromXZ = function(x, z)
    return { x, GetSurfaceHeight(x, z), z }
end

--- Computes a location that is `distance` away from target in the direction of the origin.
---
--- A practical use is the location you'll want the engineer to move to in order to build a structure at maximum build distance. In this example the origin would be the location of the engineer. The target would be the structure that you want to build. The distance is the build distance of the engineer + the footprint size of the structure.
---@param ox number     # x coordinate of the origin in world coordinates
---@param oz number     # z coordinate of the origin in world coordinates
---@param tx number     # x coordinate of the target in world coordinates
---@param tz number     # z coordinate of the target in world coordinates
---@param distance number   # how close we want to get to the second point
---@return number
---@return number
PointCloseToXZ = function(ox, oz, tx, tz, distance)
    -- compute direction and distance to the target.
    local dx = tx - ox
    local dz = tz - oz
    local length = math.sqrt(dx * dx + dz * dz)

    -- if we're already close enough then just return the origin.
    if length < distance then
        return ox, oz
    end

    -- compute the point that we're interested in
    local factor = 1 - distance / length
    return ox + dx * factor, oz + dz * factor
end

--- For more information see `PointCloseToXZ`.
---@param point1 Vector
---@param point2 Vector
---@param distance number
---@return number
---@return number
PointCloseTo = function(point1, point2, distance)
    return PointCloseToXZ(point1[1], point1[3], point2[1], point2[3], distance)
end
