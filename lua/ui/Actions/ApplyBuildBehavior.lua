--- Applies the build behavior to a selection of units.
function Handle(unitId)

    local commandMode = import("/lua/ui/game/commandmode.lua").GetCommandMode()

    ---@type AIBuildBehaviorInput
    local BehaviorInput = {
        Location = GetMouseWorldPos(),
        UnitId = commandMode[2].name or unitId
    }

    ---@type JoeDebugCreatePlatoonData
    local data = {
        BehaviorName = "BuildBehavior",
        BehaviorInput = BehaviorInput
    }

    SimCallback({ Func = "JoeDebugCreatePlatoon", Args = data }, true)
end
