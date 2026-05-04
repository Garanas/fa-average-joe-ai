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

---@param state LoveState
---@param save fun()
---@return LoveHotkeyBinding[]
function M.bindings(state, save)
    local function undo()
        if state.history and state.loadedTemplate then
            state.history:undo(state.loadedTemplate)
            state.saveStatus = nil
        end
    end
    local function redo()
        if state.history and state.loadedTemplate then
            state.history:redo(state.loadedTemplate)
            state.saveStatus = nil
        end
    end
    return {
        { keys = "ctrl+s",       name = "Save", fn = save },
        { keys = "ctrl+z",       name = "Undo", fn = undo },
        { keys = "ctrl+y",       name = "Redo", fn = redo },
        { keys = "ctrl+shift+z", name = "Redo", fn = redo },
    }
end

return M
