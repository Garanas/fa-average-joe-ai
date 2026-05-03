--- Creates a new base at the mouse cursor for the focus army's brain. Any currently selected units are sent along and assigned to the base as its initial units.
function Handle()

    ---@type JoeDebugCreateBaseAtLocationData
    local data = {
        Location = GetMouseWorldPos(),
        ArmyIndex = GetFocusArmy(),
    }

    SimCallback({ Func = "JoeDebugCreateBaseAtLocation", Args = data }, true)
end
