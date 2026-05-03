--- Assigns the currently selected units to whichever base is at the mouse cursor. The base is identified either by a unit at the cursor (its `JoeData.Base`) or by the section the cursor is over.
function Handle()

    ---@type JoeDebugAssignUnitsToBaseData
    local data = {
        Location = GetMouseWorldPos(),
        ArmyIndex = GetFocusArmy(),
    }

    SimCallback({ Func = "JoeDebugAssignUnitsToBase", Args = data }, true)
end
