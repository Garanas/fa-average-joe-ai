---@class LoveStatusBar : LoveComponent
---@field ctx LoveAppContext
local LoveStatusBar = {}
LoveStatusBar.__index = LoveStatusBar

---@param ctx LoveAppContext
---@return LoveStatusBar
function LoveStatusBar.new(ctx)
    return setmetatable({ ctx = ctx }, LoveStatusBar)
end

function LoveStatusBar:draw()
    local rect = self.ctx:layout().statusbar
    local state = self.ctx.state

    love.graphics.setColor(0.10, 0.10, 0.14)
    love.graphics.rectangle("fill", rect.x, rect.y, rect.w, rect.h)
    love.graphics.setFont(state.fonts.body)
    love.graphics.setColor(0.9, 0.9, 0.9)

    local txt
    local tmpl = state.loadedTemplate
    if tmpl then
        local nIdent = 0
        for _ in pairs(tmpl.Locations or {}) do nIdent = nIdent + 1 end
        local dirty = self.ctx:isDirty()
        local pathHint = state.currentPath and (state.currentPath:match("[^/\\]+$") or "?") or "(unsaved)"
        txt = string.format("%s%s  |  %s  |  %s  |  %dx%d  |  %d identifiers",
            dirty and "* " or "",
            tostring(tmpl.Name or "?"), tostring(tmpl.Faction or "?"),
            pathHint, tmpl.Size or 0, tmpl.Size or 0, nIdent)
    elseif state.loadError then
        txt = "Load error (see console)"
    else
        txt = "No chunk selected"
    end
    if state.mouseChunk then
        txt = txt .. string.format("  |  (%d, %d)", state.mouseChunk.x, state.mouseChunk.z)
    end
    love.graphics.print(txt, rect.x + 8, rect.y + 6)

    if state.saveStatus then
        local color = state.saveStatus:find("^Saved") and { 0.6, 1.0, 0.6 } or { 1.0, 0.6, 0.6 }
        love.graphics.setColor(color[1], color[2], color[3])
        love.graphics.printf(state.saveStatus, rect.x, rect.y + 6, rect.w - 12, "right")
    end
end

return LoveStatusBar
