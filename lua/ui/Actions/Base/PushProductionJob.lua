--- Pushes one production job per currently-selected unit onto the queue of the base under the mouse cursor. Each job uses the selected unit's blueprint id verbatim, so the rule is "make more of what's selected."
function Handle()

    ---@type JoeDebugPushProductionJobData
    local data = {
        Location = GetMouseWorldPos(),
        ArmyIndex = GetFocusArmy(),
    }

    SimCallback({ Func = "JoeDebugPushProductionJob", Args = data }, true)
end
