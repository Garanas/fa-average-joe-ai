--- Responsible for managing the base chunk templates that are loaded from files.
---@class AIBaseChunkLoader
---@field Templates AILoadedBaseChunkTemplate[] # List of base chunk templates managed by this instance.
AIBaseChunkLoader = ClassSimple {

    ---@param self AIBaseChunkLoader
    __init = function(self)
        self.Templates = {}
    end,

    --- Adds a base chunk template to the manager.
    ---@param self AIBaseChunkLoader
    ---@param template AIBaseChunkTemplate
    AddTemplate = function(self, template)
        table.insert(self.Templates, template)
    end,

    --- Loads a base chunk template from a file.
    ---@param self AIBaseChunkLoader
    ---@param file string
    ---@param field? string     # defaults to "Template"
    LoadTemplate = function(self, file, field)
        field = field or "Template"

        local succeeded, templateModule = pcall(import, file)
        if not succeeded then
            error("Failed to load template from file: " .. tostring(templateModule))
        end

        local template = templateModule[field] --[[@as AILoadedBaseChunkTemplate?]]
        if not template then
            error("Field '" .. tostring(field) .. "' not found in template file: " .. tostring(file))
        end

        -- add information that we can only compute during runtime
        template.Source = file
        template.SourceField = field

        self:AddTemplate(template)
    end,

    --- Finds all templates that meet the given criteria.
    ---@param self AIBaseChunkLoader
    ---@param categories EntityCategory
    ---@param cache? AIBaseChunkTemplate[] # Optional cache to reduce allocations
    ---@return AIBaseChunkTemplate[]
    FindTemplateByCategory = function(self, categories, cache)
        cache = cache or {}

        error("Not implemented yet")

        return cache
    end,
}

--- Creates the default instance with all the default templates loaded. These templates are used by JoeBrain to build bases.
---@return AIBaseChunkLoader
CreateDefaultAIBaseChunkLoader = function()
    local baseChunkManager = AIBaseChunkLoader() --[[@as AIBaseChunkLoader]]

    local ok, msg = pcall(
        function()
            -- Load templates from files or other sources if needed
            baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/AI/BaseChunks/UEF/air_16x16_01.lua")
            baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/AI/BaseChunks/UEF/air_32x32_01.lua")
            baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/AI/BaseChunks/UEF/power_08x08_01.lua")
            baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/AI/BaseChunks/UEF/special_08x08_01.lua")
            baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/AI/BaseChunks/UEF/special_08x08_02.lua")
            baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/AI/BaseChunks/UEF/special_16x16_01.lua")
            baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/AI/BaseChunks/UEF/special_16x16_02.lua")
            baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/AI/BaseChunks/UEF/special_16x16_03.lua")
            baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/AI/BaseChunks/UEF/land_16x16_01.lua")
            baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/AI/BaseChunks/UEF/land_16x16_02.lua")
            baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/AI/BaseChunks/UEF/land_32x32_01.lua")
            baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/AI/BaseChunks/UEF/land_32x32_02.lua")
            baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/AI/BaseChunks/UEF/land_32x32_03.lua")
        end
    )

    if not ok then
        WARN("Failed to load default base chunk templates: " .. tostring(msg))
    end

    return baseChunkManager
end
