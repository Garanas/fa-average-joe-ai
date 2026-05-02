--- Creates a new base at the mouse cursor for the focus army's brain. The brain owns registration via `JoeBrain:CreateBaseAtLocation`.
function Handle()

    ---@type JoeDebugCreateBaseAtLocationData
    local data = {
        Location = GetMouseWorldPos(),
        ArmyIndex = GetFocusArmy(),
    }

    SimCallback({ Func = "JoeDebugCreateBaseAtLocation", Args = data }, false)
end
