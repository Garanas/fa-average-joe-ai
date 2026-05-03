--- Reads the unit id from the active build command mode and asks the selected engineer's base to acquire build sites for it. Used to test the find-or-create flow — does not issue an actual build order.
function Handle()
    local commandModeModule = import("/lua/ui/game/commandmode.lua")
    local mode = commandModeModule.GetCommandMode()

    if not mode or mode[1] ~= "build" or not mode[2] or not mode[2].name then
        print("Not in build command mode")
        return
    end

    ---@type JoeDebugAcquireBuildSitesForBaseData
    local data = {
        UnitId = mode[2].name,
    }

    SimCallback({ Func = "JoeDebugAcquireBuildSitesForBase", Args = data }, true)
end
