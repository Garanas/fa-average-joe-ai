-- upvalue scope for performance
local DrawCircle = DrawCircle
local DrawLine = DrawLine

local PositionCacheA = {}
local PositionCacheB = {}

--- Draws a circle for one tick.
---@param lx number     # in world coordinates
---@param lz number     # in world coordinates
---@param radius number
---@param color Color
DrawCircleXZ = function(lx, lz, radius, color)
    PositionCacheA[1] = lx
    PositionCacheA[2] = GetSurfaceHeight(lx, lz)
    PositionCacheA[3] = lz
    DrawCircle(PositionCacheA, radius, color)
end

--- Draws a line for one tick.
---@param lx1 number    # in world coordinates
---@param lz1 number    # in world coordinates
---@param lx2 number    # in world coordinates
---@param lz2 number    # in world coordinates
---@param color Color
DrawLineXZ = function(lx1, lz1, lx2, lz2, color)
    PositionCacheA[1] = lx1
    PositionCacheA[2] = GetSurfaceHeight(lx1, lz1)
    PositionCacheA[3] = lz1
    PositionCacheB[1] = lx2
    PositionCacheB[2] = GetSurfaceHeight(lx2, lz2)
    PositionCacheB[3] = lz2
    DrawLine(PositionCacheA, PositionCacheB, color)
end

--- Draws a square for one tick.
---@param lx1 number    # in world coordinates
---@param lz1 number    # in world coordinates
---@param lx2 number    # in world coordinates
---@param lz2 number    # in world coordinates
---@param color Color
---@param inset? number
DrawSquareXZ = function(lx1, lz1, lx2, lz2, color, inset)
    inset = inset or 0

    -- normalize coordinates (ensure lx1 < lx2, lz1 < lz2)
    if lx1 > lx2 then lx1, lx2 = lx2, lx1 end
    if lz1 > lz2 then lz1, lz2 = lz2, lz1 end

    -- apply inset
    lx1 = lx1 + inset
    lz1 = lz1 + inset
    lx2 = lx2 - inset
    lz2 = lz2 - inset

    -- skip drawing if nothing is left
    if lx1 >= lx2 or lz1 >= lz2 then
        return
    end

    DrawLineXZ(lx1, lz1, lx2, lz1, color)
    DrawLineXZ(lx2, lz1, lx2, lz2, color)
    DrawLineXZ(lx2, lz2, lx1, lz2, color)
    DrawLineXZ(lx1, lz2, lx1, lz1, color)
end

--- Draws a line with an indication for direction for one tick.
---@param lx1 number    # in world coordinates
---@param lz1 number    # in world coordinates
---@param lx2 number    # in world coordinates
---@param lz2 number    # in world coordinates
---@param color Color
DrawLinePopXZ = function(lx1, lz1, lx2, lz2, color)
    PositionCacheA[1] = lx1
    PositionCacheA[2] = GetSurfaceHeight(lx1, lz1)
    PositionCacheA[3] = lz1
    PositionCacheB[1] = lx2
    PositionCacheB[2] = GetSurfaceHeight(lx2, lz2)
    PositionCacheB[3] = lz2
    DrawLinePop(PositionCacheA, PositionCacheB, color)
end