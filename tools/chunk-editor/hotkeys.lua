-- Hotkey dispatch. Bindings are declared once via `bindings(state, save)` and
-- matched by a normalized combo string ("ctrl+z", "ctrl+shift+z", ...).

local M = {}

---@param key string
---@param ctrl boolean
---@param shift boolean
---@param alt boolean
---@return string
function M.normalize(key, ctrl, shift, alt)
    local parts = {}
    if ctrl then table.insert(parts, "ctrl") end
    if alt then table.insert(parts, "alt") end
    if shift then table.insert(parts, "shift") end
    table.insert(parts, key)
    return table.concat(parts, "+")
end

---@param bindings LoveHotkeyBinding[]
---@param combo string
---@return boolean handled
function M.dispatch(bindings, combo)
    for _, b in ipairs(bindings) do
        if b.keys == combo then
            b.fn()
            return true
        end
    end
    return false
end

---@param actions LoveActions
---@return LoveHotkeyBinding[]
function M.bindings(actions)
    local bindings = {
        { keys = "ctrl+n",       name = "New",                fn = actions.new },
        { keys = "ctrl+o",       name = "Load",               fn = actions.load },
        { keys = "ctrl+i",       name = "Import",             fn = actions.importChunk },
        { keys = "ctrl+s",       name = "Save",               fn = actions.save },
        { keys = "ctrl+shift+s", name = "Save As",            fn = actions.saveAs },
        { keys = "ctrl+z",       name = "Undo",               fn = actions.undo },
        { keys = "ctrl+y",       name = "Redo",               fn = actions.redo },
        { keys = "ctrl+shift+z", name = "Redo",               fn = actions.redo },
        { keys = "ctrl+up",      name = "Zoom in",            fn = actions.zoomIn },
        { keys = "ctrl+down",    name = "Zoom out",           fn = actions.zoomOut },
        { keys = "home",         name = "Recenter",           fn = actions.recenter },
        { keys = "tab",          name = "Next selection",     fn = actions.nextSelection },
        { keys = "shift+tab",    name = "Previous selection", fn = actions.prevSelection },
        { keys = "delete",       name = "Delete selection",   fn = actions.deleteSelected },
        { keys = "insert",       name = "Duplicate selection", fn = actions.duplicateSelected },
    }

    -- Control-group bindings: Ctrl+1..9, Ctrl+0 assign; 1..9, 0 select. Slot 10 = "0" key.
    for slot = 1, 10 do
        local key = (slot == 10) and "0" or tostring(slot)
        local capturedSlot = slot
        table.insert(bindings, {
            keys = "ctrl+" .. key,
            name = "Assign group " .. slot,
            fn = function() actions.assignGroup(capturedSlot) end,
        })
        table.insert(bindings, {
            keys = key,
            name = "Select group " .. slot,
            fn = function() actions.selectGroup(capturedSlot) end,
        })
    end

    return bindings
end

return M
