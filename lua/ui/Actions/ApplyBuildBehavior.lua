--- Applies the build behavior to a selection of units.
function Handle(unitId)

    ---@type AIBuildBehaviorInput
    local BehaviorInput = {
        Location = GetMouseWorldPos(),
        UnitId = unitId
    }

    ---@type JoeDebugCreatePlatoonData
    local data = {
        BehaviorName = "BuildBehavior",
        BehaviorInput = BehaviorInput
    }

    SimCallback({ Func = "JoeDebugCreatePlatoon", Args = data }, true)
end
