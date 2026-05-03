--- Pushes a build job for the active build command mode's unit onto the selected engineer's base queue. No location hint — the base picks a build site freely.
function Handle()
    local commandModeModule = import("/lua/ui/game/commandmode.lua")
    local mode = commandModeModule.GetCommandMode()

    if not mode or mode[1] ~= "build" or not mode[2] or not mode[2].name then
        print("Not in build command mode")
        return
    end

    ---@type JoeDebugPushBuildJobData
    local data = {
        UnitId = mode[2].name,
    }

    SimCallback({ Func = "JoeDebugPushBuildJob", Args = data }, true)
end
