--- Toggles the brain-level chunk visualization for the focus army.
function Handle()

    ---@type JoeDebugToggleBrainChunkVisualizationData
    local data = {
        ArmyIndex = GetFocusArmy(),
    }

    SimCallback({ Func = "JoeDebugToggleBrainChunkVisualization", Args = data }, false)
end
