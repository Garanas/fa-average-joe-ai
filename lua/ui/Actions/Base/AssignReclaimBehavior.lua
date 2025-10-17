--- Applies the reclaim behavior to a selection of units.
function Handle()

    ---@type JoeDebugAssignReclaimBehaviorData
    local data = {
        Location = GetMouseWorldPos()
    }

    SimCallback({ Func = "JoeDebugAssignReclaimBehavior", Args = data }, true)
end
