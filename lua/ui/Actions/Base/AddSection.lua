--- Adds the section under the mouse cursor to the base that the selected units belong to.
function Handle()

    ---@type JoeDebugAddSectionToBaseData
    local data = {
        Location = GetMouseWorldPos(),
    }

    SimCallback({ Func = "JoeDebugAddSectionToBase", Args = data }, true)
end
