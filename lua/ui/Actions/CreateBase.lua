--- Creates a new base instance with the selected units as the initial units of the base.
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

    SimCallback({ Func = "JoeDebugCreateBase", Args = data }, true)
end
