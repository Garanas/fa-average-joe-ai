
--- Applies the reclaim behavior to a selection of units.
function Handle()

    ---@type AIReclaimBehaviorInput
    local BehaviorInput = {
        Location = GetMouseWorldPos()
    }

    ---@type JoeDebugCreatePlatoonData
    local data = {
        BehaviorName = "ReclaimBehavior",
        BehaviorInput = BehaviorInput
    }

    SimCallback({ Func = "JoeDebugCreatePlatoon", Args = data }, true)
end
