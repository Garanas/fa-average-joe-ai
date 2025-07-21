-- Hooks into: https://github.com/FAForever/fa/blob/develop/lua/keymap/keyactions.lua

do
    local keyCategory = 'ai'

    local keyActionsJoeAI = {
        ['average_joe_ai_create_chunk_template'] = {
            action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/KeyActions/CreateAIBaseChunkTemplateFromSelection.lua").CreateTemplateFromSelection()',
            category = keyCategory,
        },
    }

    -- keyActions is a globally defined table in keyactions.lua
    keyActions = table.combine(keyActions, keyActionsJoeAI)
end
