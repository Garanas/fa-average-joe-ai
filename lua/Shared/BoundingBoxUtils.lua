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
