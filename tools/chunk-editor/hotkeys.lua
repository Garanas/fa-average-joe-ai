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
    return {
        { keys = "ctrl+s",       name = "Save", fn = actions.save },
        { keys = "ctrl+z",       name = "Undo", fn = actions.undo },
        { keys = "ctrl+y",       name = "Redo", fn = actions.redo },
        { keys = "ctrl+shift+z", name = "Redo", fn = actions.redo },
    }
end

return M
