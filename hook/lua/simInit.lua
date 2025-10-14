--@meta
-- Hooks into: https://github.com/FAForever/fa/blob/develop/lua/simInit.lua

do
    local OldBeginSession = BeginSession
    BeginSession = function()
        OldBeginSession()

        -- Allows us to debug platoon behaviors by selecting units
        local DebugSelectionThread = import("/mods/fa-joe-ai/lua/Sim/DebugUtils.lua").DebugSelectionThread
        ForkThread(DebugSelectionThread)
    end

    local PositionCache = {}

    ---@param units Unit[]
    ---@param lx number     # in world coordinates
    ---@param lz number     # in world coordinates
    _G.IssuePatrolXZ = function(units, lx, lz)
        PositionCache[1] = lx
        PositionCache[2] = GetSurfaceHeight(lx, lz)
        PositionCache[3] = lz
        IssuePatrol(units, PositionCache)
    end
end
