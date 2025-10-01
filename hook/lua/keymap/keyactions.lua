-- Hooks into: https://github.com/FAForever/fa/blob/develop/lua/keymap/keyactions.lua

do
    local keyCategory = 'ai'
    local modKeyActions = {}

    modKeyActions['average_joe_ai_create_chunk_template_4'] = {
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/CreateBaseChunkTemplate.lua").Handle(4)',
        category = keyCategory,
    }

    modKeyActions['average_joe_ai_create_chunk_template_8'] = {
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/CreateBaseChunkTemplate.lua").Handle(8)',
        category = keyCategory,
    }

    modKeyActions['average_joe_ai_create_chunk_template_16'] = {
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/CreateBaseChunkTemplate.lua").Handle(16)',
        category = keyCategory,
    }

    modKeyActions['average_joe_ai_create_chunk_template_32'] = {
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/CreateBaseChunkTemplate.lua").Handle(32)',
        category = keyCategory,
    }

    modKeyActions['average_joe_ai_create_chunk_template_64'] = {
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/CreateBaseChunkTemplate.lua").Handle(64)',
        category = keyCategory,
    }

    modKeyActions['average_joe_ai_create_chunk_template_128'] = {
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/CreateBaseChunkTemplate.lua").Handle(128)',
        category = keyCategory,
    }

    modKeyActions['average_joe_ai_toggle_base_chunk_dialog'] = {
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/ToggleBaseChunkDialog.lua").Handle()',
        category = keyCategory,
    }

    -- keyActions is a globally defined table in keyactions.lua
    keyActions = table.combine(keyActions, modKeyActions)
end
