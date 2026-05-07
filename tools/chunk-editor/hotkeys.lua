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
        { group = "File",      keys = "ctrl+n",       name = "New",                 fn = actions.new },
        { group = "File",      keys = "ctrl+o",       name = "Load",                fn = actions.load },
        { group = "File",      keys = "ctrl+i",       name = "Import",              fn = actions.importChunk },
        { group = "File",      keys = "ctrl+r",       name = "Reconfigure chunk",   fn = actions.reconfigureChunk },
        { group = "File",      keys = "ctrl+s",       name = "Save",                fn = actions.save },
        { group = "File",      keys = "ctrl+shift+s", name = "Save As",             fn = actions.saveAs },
        { group = "History",   keys = "ctrl+z",       name = "Undo",                fn = actions.undo },
        { group = "History",   keys = "ctrl+y",       name = "Redo",                fn = actions.redo },
        { group = "History",   keys = "ctrl+shift+z", name = "Redo",                fn = actions.redo },
        { group = "View",      keys = "ctrl+up",      name = "Zoom in",             fn = actions.zoomIn },
        { group = "View",      keys = "ctrl+down",    name = "Zoom out",            fn = actions.zoomOut },
        { group = "View",      keys = "home",         name = "Recenter",            fn = actions.recenter },
        { group = "Selection", keys = "tab",          name = "Next selection",      fn = actions.nextSelection },
        { group = "Selection", keys = "shift+tab",    name = "Previous selection",  fn = actions.prevSelection },
        { group = "Editing",   keys = "delete",       name = "Delete selection",    fn = actions.deleteSelected },
        { group = "Editing",   keys = "insert",       name = "Duplicate selection", fn = actions.duplicateSelected },
        { group = "Editing",   keys = "ctrl+e",       name = "Detect overlaps",     fn = actions.detectOverlaps },
        { group = "Translate", keys = "left",         name = "Translate left",      fn = function() actions.translateSelection(-1, 0) end },
        { group = "Translate", keys = "right",        name = "Translate right",     fn = function() actions.translateSelection(1, 0) end },
        { group = "Translate", keys = "up",           name = "Translate up",        fn = function() actions.translateSelection(0, -1) end },
        { group = "Translate", keys = "down",         name = "Translate down",      fn = function() actions.translateSelection(0, 1) end },
        { group = "Translate", keys = "shift+left",   name = "Translate left x4",   fn = function() actions.translateSelection(-4, 0) end },
        { group = "Translate", keys = "shift+right",  name = "Translate right x4",  fn = function() actions.translateSelection(4, 0) end },
        { group = "Translate", keys = "shift+up",     name = "Translate up x4",     fn = function() actions.translateSelection(0, -4) end },
        { group = "Translate", keys = "shift+down",   name = "Translate down x4",   fn = function() actions.translateSelection(0, 4) end },
        { group = "Mirror",    keys = "ctrl+shift+x", name = "Mirror across X axis", fn = function() actions.mirrorSelection("x") end },
        { group = "Mirror",    keys = "ctrl+shift+y", name = "Mirror across Y axis", fn = function() actions.mirrorSelection("y") end },
        { group = "Mirror",    keys = "ctrl+shift+b", name = "Mirror across both",   fn = function() actions.mirrorSelection("xy") end },
    }

    -- Control-group bindings: Ctrl+1..9, Ctrl+0 assign; 1..9, 0 select. Slot 10 = "0" key.
    for slot = 1, 10 do
        local key = (slot == 10) and "0" or tostring(slot)
        local capturedSlot = slot
        table.insert(bindings, {
            group = "Groups",
            keys = "ctrl+" .. key,
            name = "Assign group " .. slot,
            fn = function() actions.assignGroup(capturedSlot) end,
        })
        table.insert(bindings, {
            group = "Groups",
            keys = key,
            name = "Select group " .. slot,
            fn = function() actions.selectGroup(capturedSlot) end,
        })
    end

    return bindings
end

return M
