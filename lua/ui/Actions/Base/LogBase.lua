--- Logs the full state of the base under the cursor and draws it for 100 ticks.
function Handle()

    ---@type JoeDebugLogBaseData
    local data = {
        Location = GetMouseWorldPos(),
        ArmyIndex = GetFocusArmy(),
    }

    SimCallback({ Func = "JoeDebugLogBase", Args = data }, true)
end
