--- Toggles the per-base chunk visualization for whichever base owns the section under the mouse cursor.
function Handle()

    ---@type JoeDebugToggleBaseChunkVisualizationData
    local data = {
        ArmyIndex = GetFocusArmy(),
        Location = GetMouseWorldPos(),
    }

    SimCallback({ Func = "JoeDebugToggleBaseChunkVisualization", Args = data }, false)
end
