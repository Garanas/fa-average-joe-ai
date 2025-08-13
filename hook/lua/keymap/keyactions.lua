-- Hooks into: https://github.com/FAForever/fa/blob/develop/lua/keymap/keyactions.lua

do
    local keyCategory = 'ai'
    local modKeyActions = {}

    modKeyActions['average_joe_ai_create_chunk_template_4'] = {
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/KeyActions/CreateAIBaseChunkTemplateFromSelection.lua").CreateTemplateFromSelection(4)',
        category = keyCategory,
    }

    modKeyActions['average_joe_ai_create_chunk_template_8'] = {
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/KeyActions/CreateAIBaseChunkTemplateFromSelection.lua").CreateTemplateFromSelection(8)',
        category = keyCategory,
    }

    modKeyActions['average_joe_ai_create_chunk_template_16'] = {
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/KeyActions/CreateAIBaseChunkTemplateFromSelection.lua").CreateTemplateFromSelection(16)',
        category = keyCategory,
    }

    modKeyActions['average_joe_ai_create_chunk_template_32'] = {
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/KeyActions/CreateAIBaseChunkTemplateFromSelection.lua").CreateTemplateFromSelection(32)',
        category = keyCategory,
    }

    modKeyActions['average_joe_ai_create_chunk_template_64'] = {
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/KeyActions/CreateAIBaseChunkTemplateFromSelection.lua").CreateTemplateFromSelection(64)',
        category = keyCategory,
    }

    modKeyActions['average_joe_ai_create_chunk_template_128'] = {
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/KeyActions/CreateAIBaseChunkTemplateFromSelection.lua").CreateTemplateFromSelection(128)',
        category = keyCategory,
    }

    -- keyActions is a globally defined table in keyactions.lua
    keyActions = table.combine(keyActions, modKeyActions)
end
