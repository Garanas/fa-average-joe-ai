--- Returns whether the two axis-aligned bounding boxes overlap.
---@param ax0 number        # x0 of area A in world coordinates
---@param az0 number        # z0 of area A in world coordinates
---@param ax1 number        # x1 of area A in world coordinates
---@param az1 number        # z1 of area A in world coordinates
---@param bx0 number        # x0 of area B in world coordinates
---@param bz0 number        # z0 of area B in world coordinates
---@param bx1 number        # x1 of area B in world coordinates
---@param bz1 number        # z1 of area B in world coordinates
---@return boolean
Overlap = function(ax0, az0, ax1, az1, bx0, bz0, bx1, bz1)
    -- Ensure the coordinates are ordered properly
    if ax0 > ax1 then ax0, ax1 = ax1, ax0 end
    if az0 > az1 then az0, az1 = az1, az0 end
    if bx0 > bx1 then bx0, bx1 = bx1, bx0 end
    if bz0 > bz1 then bz0, bz1 = bz1, bz0 end

    -- Check for non-overlap along either axis
    if ax1 <= bx0 or bx1 <= ax0 then
        return false
    end

    if az1 <= bz0 or bz1 <= az0 then
        return false
    end

    return true
end

--- Returns whether the first bounding box is inside the second bounding box.
---@param ax0 number        # x0 of area A in world coordinates
---@param az0 number        # z0 of area A in world coordinates
---@param ax1 number        # x1 of area A in world coordinates
---@param az1 number        # z1 of area A in world coordinates
---@param bx0 number        # x0 of area B in world coordinates
---@param bz0 number        # z0 of area B in world coordinates
---@param bx1 number        # x1 of area B in world coordinates
---@param bz1 number        # z1 of area B in world coordinates
---@return boolean
Inside = function(ax0, az0, ax1, az1, bx0, bz0, bx1, bz1)
    return ax0 >= bx0 and az0 >= bz0 and ax1 <= bx1 and az1 <= bz1
end

--- Computes a point outside the bounding box by moving away from its center.
--- The returned point is offset outward from the box by (half side length + offset).
---@param lx number
---@param lz number
---@param x0 number
---@param z0 number
---@param x1 number
---@param z1 number
---@param offset number|nil
---@return number   # x coordinate of the point
---@return number   # z coordinate of the point
ToPointOutside = function(lx, lz, x0, z0, x1, z1, offset)
    offset = offset or 0

    -- Normalize coordinates
    if x0 > x1 then x0, x1 = x1, x0 end
    if z0 > z1 then z0, z1 = z1, z0 end

    -- Compute box center and half-size
    local cx = (x0 + x1) * 0.5
    local cz = (z0 + z1) * 0.5
    local hx = (x1 - x0) * 0.5
    local hz = (z1 - z0) * 0.5

    -- Direction from center to point
    local dx = lx - cx
    local dz = lz - cz

    -- Handle the case where the point is exactly at the center
    if dx == 0 and dz == 0 then
        -- Move straight up by default
        return cx, cz + hz + offset
    end

    -- Normalize direction
    local len = math.sqrt(dx * dx + dz * dz)
    dx = dx / len
    dz = dz / len

    -- Compute how far we must go to reach outside the box
    local sideLength = 4 * math.max(hx, hz)
    local radius = sideLength + offset

    -- Return the point outside
    local ox = cx + dx * radius
    local oz = cz + dz * radius
    return ox, oz
end
