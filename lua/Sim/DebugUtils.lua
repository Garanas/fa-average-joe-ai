local ArrayContains = import("/mods/fa-joe-ai/lua/Shared/TableUtils.lua").ArrayContains

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

--- Returns the four corners of an oriented bounding box in 2D (XZ-plane),
--- with optional inset (positive shrinks, negative expands).
--- Order: front-left, front-right, back-right, back-left.
---@param unit JoeUnit
---@param inset? number
---@return number x1 X coordinate of front-left corner
---@return number z1 Z coordinate of front-left corner
---@return number x2 Z coordinate of front-right corner
---@return number z2 Z coordinate of front-right corner
---@return number x3 X coordinate of back-right corner
---@return number z3 Z coordinate of back-right corner
---@return number x4 X coordinate of back-left corner
---@return number z4 Z coordinate of back-left corner
function GetOrientedBoundingBox(unit, inset)
    local bp = unit:GetBlueprint()
    local width  = bp.SizeZ or 1  -- side-to-side along X
    local length = bp.SizeX or 1  -- forward along Z

    local heading = unit:GetHeading()
    local ux, _, uz = unit:GetPositionXYZ()
    local insetVal = (inset or 0) - 1

    local hx = width * 0.5 - insetVal
    local hz = length * 0.5 - insetVal
    if hx < 0 then hx = 0 end
    if hz < 0 then hz = 0 end

    local cosH = math.sin(heading)
    local sinH = math.cos(heading)

    -- Corners: front-left, front-right, back-right, back-left
    local x1 = ux + (-hx) * cosH - ( hz) * sinH
    local z1 = uz + (-hx) * sinH + ( hz) * cosH

    local x2 = ux + ( hx) * cosH - ( hz) * sinH
    local z2 = uz + ( hx) * sinH + ( hz) * cosH

    local x3 = ux + ( hx) * cosH - (-hz) * sinH
    local z3 = uz + ( hx) * sinH + (-hz) * cosH

    local x4 = ux + (-hx) * cosH - (-hz) * sinH
    local z4 = uz + (-hx) * sinH + (-hz) * cosH

    return x1, z1, x2, z2, x3, z3, x4, z4
end

--- Draws an orientated bounding box at the unit for one tick.
---@param unit JoeUnit
---@param color Color
---@param inset? number
DrawUnit = function(unit, color, inset)
    -- get blueprint properties
    local unitBlueprint = unit:GetBlueprint()
    local sx = unitBlueprint.SizeX or 1
    local sz = unitBlueprint.SizeZ or 1

    -- get unit properties
    local heading = unit:GetHeading()
    local ux, uy, uz = unit:GetPositionXYZ()

    -- compute orientated bounding box
    local x1, z1, x2, z2, x3, z3, x4, z4 = GetOrientedBoundingBox(unit, inset)

    DrawLineXZ(x1, z1, x2, z2, color)
    DrawLineXZ(x2, z2, x3, z3, color)
    DrawLineXZ(x3, z3, x4, z4, color)
    DrawLineXZ(x4, z4, x1, z1, color)
end

--- Draws an orientated bounding box for each unit in a set of units for one tick.
---@param units JoeUnit[]
---@param color Color
---@param inset? number
DrawUnits = function(units, color, inset)
    for k = 1, table.getn(units) do
        local unit = units[k]
        DrawUnit(unit, color, inset)
    end
end

--- Responsible for debugging whatever the player has selected.
DebugSelectionThread = function()
    local GetGameTick = GetGameTick
    local DebugGetSelection = DebugGetSelection

    while true do
        local instances = {}
        local gameTick = GetGameTick()
        local selectedUnits = DebugGetSelection() --[[@as (JoeUnit[])]]

        -- enable debug behavior for all platoon behaviors of selected units
        for k = 1, table.getn(selectedUnits) do
            local unit = selectedUnits[k]
            local joeData = unit.JoeData

            local base = joeData.Base
            if base and base.Debug then
                base.Debug.LastSelected = gameTick

                -- register all unique base instances
                if base.Draw then
                    if not ArrayContains(instances, base) then
                        table.insert(instances, base)
                    end
                end
            end

            local behavior = joeData.Behavior
            if behavior and behavior.Debug and (not IsDestroyed(behavior)) then
                behavior.Debug.LastSelected = gameTick

                -- register all unique behaviors
                if behavior.Draw then
                    if not ArrayContains(instances, behavior) then
                        table.insert(instances, behavior)
                    end
                end
            end
        end

        -- call the draw function of all the platoon behaviors that we have selected
        for k = 1, table.getn(instances) do
            local instance = instances[k]
            local ok, msg = pcall(instance.Draw, instance)
            if not ok then
                WARN(msg)
            end
        end

        WaitTicks(1)
    end
end

--#endregion
