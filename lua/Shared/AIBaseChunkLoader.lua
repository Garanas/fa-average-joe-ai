---@class AIBaseChunkManager
---@field Templates AIBaseChunkTemplate[] # List of base chunk templates managed by this instance.
AIBaseChunkManager = ClassSimple {

    ---@param self AIBaseChunkManager
    __init = function(self)
        self.Templates = {}
    end,

    --- Adds a base chunk template to the manager.
    ---@param self AIBaseChunkManager
    ---@param template AIBaseChunkTemplate
    AddTemplate = function(self, template)
        table.insert(self.Templates, template)
    end,

    --- Loads a base chunk template from a file.
    ---@param self AIBaseChunkManager
    ---@param file string
    ---@param field? string     # defaults to "Template"
    LoadTemplate = function(self, file, field)
        field = field or "Template"

        local templateModule, msg = pcall(import, file)
        if not templateModule then
            error("Failed to load template from file: " .. msg)
        end

        local template = templateModule[field]
        if not template then
            error("Field '" .. field .. "' not found in template file: " .. file)
        end

        self:LoadTemplate(template)
    end,

    ---@param self AIBaseChunkManager
    ---@param categories EntityCategory
    FindTemplate = function(self, categories)
        error("Not implemented yet")
    end,
}

--- Creates the default instance with all the default templates loaded.
---@return AIBaseChunkManager
CreateDefaultAIBaseChunkManager = function()
    local baseChunkManager = AIBaseChunkManager() --[[@as AIBaseChunkManager]]

    -- Load templates from files or other sources if needed
    baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/AI/BaseChunks/UEF/Tech1/32x32_01.lua", "Template")

    return baseChunkManager
end
