--- Adds the leaf under the mouse cursor to the base that the selected units belong to.
function Handle()

    ---@type JoeDebugAddLeafToBaseData
    local data = {
        Location = GetMouseWorldPos(),
    }

    SimCallback({ Func = "JoeDebugAddLeafToBase", Args = data }, true)
end
