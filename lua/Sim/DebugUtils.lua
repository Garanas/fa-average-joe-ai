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
                    if not ArrayContains (instances, base) then
                        table.insert(instances, base)
                    end
                end
            end

            local behavior = joeData.Behavior
            if behavior and behavior.Debug then
                behavior.Debug.LastSelected = gameTick

                -- register all unique behaviors
                if behavior.Draw then
                    if not ArrayContains (instances, behavior) then
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
