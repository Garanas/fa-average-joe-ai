
local TableInsert = table.insert
local TableGetn = table.getn

local error = error
local warn = WARN
local pcall = pcall

--- Builds a flat identifier→locations dict from a grouped chunk template. The runtime collapses groups at load time so consumers don't have to care about grouping.
---@param template JoeBaseChunk
---@return table<JoeBuildingIdentifier, JoeBaseChunkLocation[]>
local function FlattenGroups(template)
    local flat = {}
    for _, group in template.Groups or {} do
        for identifier, locs in group.Locations or {} do
            local bucket = flat[identifier]
            if not bucket then
                bucket = {}
                flat[identifier] = bucket
            end
            for k = 1, TableGetn(locs) do
                TableInsert(bucket, locs[k])
            end
        end
    end
    return flat
end

--- Responsible for managing the base chunk templates that are loaded from files.
---@class JoeBaseChunkLoader
---@field Templates JoeLoadedBaseChunk[] # List of base chunk templates managed by this instance.
JoeBaseChunkLoader = ClassSimple {

    ---@param self JoeBaseChunkLoader
    __init = function(self)
        self.Templates = {}
    end,

    --- Adds a base chunk template to the manager. The template should already have its loader fields (`Source`, `SourceField`) attached.
    ---@param self JoeBaseChunkLoader
    ---@param template JoeLoadedBaseChunk
    AddTemplate = function(self, template)
        TableInsert(self.Templates, template)
    end,

    --- Returns all loaded templates of the given size that contain at least one location for the given building identifier.
    ---@param self JoeBaseChunkLoader
    ---@param identifier JoeBuildingIdentifier
    ---@param size number
    ---@param cache? JoeLoadedBaseChunk[]    # optional table to reuse; cleared before being filled.
    ---@return JoeLoadedBaseChunk[]
    FindTemplates = function(self, identifier, size, cache)
        cache = cache or {}
        for _, template in self.Templates do
            if template.Size == size and template.Locations[identifier] then
                TableInsert(cache, template)
            end
        end
        return cache
    end,

    --- Loads a base chunk from a file and registers it as a template.
    ---@param self JoeBaseChunkLoader
    ---@param file string
    ---@param field? string     # defaults to "Template"
    LoadTemplate = function(self, file, field)
        field = field or "Template"

        local succeeded, templateModule = pcall(import, file)
        if not succeeded then
            error("Failed to load template from file: " .. tostring(templateModule))
        end

        local template = templateModule[field] --[[@as JoeBaseChunk?]]
        if not template then
            error("Field '" .. tostring(field) .. "' not found in template file: " .. tostring(file))
        end

        -- migrate pre-Groups chunk files: wrap their flat Locations into a single default group
        if (not template.Groups) and template.Locations then
            template.Groups = {
                [1] = { Name = "default", Locations = template.Locations },
            }
            template.Locations = nil
        end

        -- promote the on-disk JoeBaseChunk to a runtime JoeLoadedBaseChunk by stamping loader fields
        local runtimeTemplate = template --[[@as JoeLoadedBaseChunk]]
        runtimeTemplate.Source = file
        runtimeTemplate.SourceField = field
        -- collapse all groups into a single flat dict so consumers can ignore grouping
        runtimeTemplate.Locations = FlattenGroups(template)

        self:AddTemplate(runtimeTemplate)
    end,
}

--- Creates the default instance with all the default templates loaded. These templates are used by JoeBrain to build bases.
---@return JoeBaseChunkLoader
CreateDefaultJoeBaseChunkLoader = function()
    local baseChunkManager = JoeBaseChunkLoader() --[[@as JoeBaseChunkLoader]]

    local ok, msg = pcall(
        function()
            -- Load templates from files in a deterministic manner. We can not load in all templates using a glob.
            -- baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/Shared/BaseChunks/UEF/air_16x16_01.lua")
            -- baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/Shared/BaseChunks/UEF/power_08x08_01.lua")
            -- baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/Shared/BaseChunks/UEF/power_16x16_01.lua")
            -- baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/Shared/BaseChunks/UEF/power_16x16_02.lua")
            baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/Shared/BaseChunks/UEF/special_08x08_01.lua")
            baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/Shared/BaseChunks/UEF/special_08x08_02.lua")
            -- baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/Shared/BaseChunks/UEF/special_16x16_01.lua")
            -- baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/Shared/BaseChunks/UEF/land_16x16_01.lua")
            -- baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/Shared/BaseChunks/UEF/land_16x16_02.lua")
            -- baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/Shared/BaseChunks/UEF/land_32x32_01.lua")
            -- baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/Shared/BaseChunks/UEF/land_32x32_02.lua")
            -- baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/Shared/BaseChunks/UEF/random_32x32_01.lua")
              baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/Shared/BaseChunks/UEF/Large_UEF_base_Chunk_222.lua")
              baseChunkManager:LoadTemplate("/mods/fa-joe-ai/lua/Shared/BaseChunks/UEF/test-template-chunk-editor.lua")
        end
    )

    if not ok then
        WARN("Failed to load default base chunk templates: " .. tostring(msg))
    end

    return baseChunkManager
end
