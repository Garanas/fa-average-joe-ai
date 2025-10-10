local BoundingBoxUtils = import("/mods/fa-joe-ai/lua/Shared/BoundingBoxUtils.lua")
local VectorUtils = import("/mods/fa-joe-ai/lua/Shared/VectorUtils.lua")
local DebugUtils = import("/mods/fa-joe-ai/lua/Sim/DebugUtils.lua")

--- Clears the area of friendly or neutral mobile units that are idle.
---@param army number           # the army that we're clearing the area for.
---@param lx number             # in world coordinates
---@param lz number             # in world coordinates
---@param sideLength number     # in world coordinates
IssueClearArea = function(army, lx, lz, sideLength)
    local x0 = lx - sideLength
    local z0 = lz - sideLength
    local x1 = lx + sideLength
    local z1 = lz + sideLength
    local entities = GetReclaimablesInRect(x0, z0, x1, z1)

    if entities then
        for k = 1, table.getn(entities) do
            local entity = entities[k]
            if EntityCategoryContains(categories.MOBILE, entity) then
                local unit = entity --[[@as JoeUnit]]

                -- do not move enemy units
                if not IsEnemy(army, unit.Army) then

                    -- only move idle units
                    if unit:IsIdleState() then
                        local lx, _, lz = unit:GetPositionXYZ()
                        -- take into account size of unit
                        local offset = math.max(unit.Blueprint.SizeX or 1, unit.Blueprint.SizeZ or 1)

                        -- air units need to more especially far away
                        if EntityCategoryContains(categories.AIR, unit) then
                            offset = 5 + 2 * offset
                        end

                        -- compute a point that is far away enough
                        local tx, tz = BoundingBoxUtils.ToPointOutside(lx, lz, x0, z0, x1, z1, offset)

                        -- use navigator to move the unit, this makes it feel more natural
                        local navigator = unit:GetNavigator()
                        navigator:SetGoal(VectorUtils.FromXZ(tx, tz))

                        DebugUtils.DrawLinePopXZ(lx, lz, tx, tz, 'ffffff')
                    end
                end
            end
        end
    end
end
