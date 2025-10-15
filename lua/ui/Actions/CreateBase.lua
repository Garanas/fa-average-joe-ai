--- Creates a new base instance with the selected units as the initial units of the base.
function Handle()

    ---@type JoeDebugCreateBaseData
    local data = {
        Location = GetMouseWorldPos(),
    }

    SimCallback({ Func = "JoeDebugCreateBase", Args = data }, true)
end
