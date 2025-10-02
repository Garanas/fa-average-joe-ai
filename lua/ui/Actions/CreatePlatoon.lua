
--- Applies the specified behavior to a selection of units
function Handle(behavior)
    ---@type JoeDebugCreatePlatoonData
    local data = {
        BehaviorName = behavior
    }

    SimCallback({ Func = "JoeDebugCreatePlatoon", Args = data }, true)
end
