-- Hooks into: https://github.com/FAForever/fa/blob/develop/lua/keymap/keyactions.lua

do
    local HotkeysModule = import("/mods/fa-joe-ai/lua/ui/hotkeys.lua")

    for k = 1, table.getn(HotkeysModule.Keys) do
        local hotkey = HotkeysModule.Keys[k]

        -- keyActions is a globally defined table in keyactions.lua
        keyActions[hotkey.key] = {
            action = hotkey.action,
            category = hotkey.category
        }
    end
end
