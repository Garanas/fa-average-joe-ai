-- Hooks into: https://github.com/FAForever/fa/blob/develop/lua/keymap/keydescriptions.lua

do
    local HotkeysModule = import("/mods/fa-joe-ai/lua/ui/hotkeys.lua")

    for k = 1, table.getn(HotkeysModule.Keys) do
        local hotkey = HotkeysModule.Keys[k]

        -- keyDescriptions is a globally defined table in keydescriptions.lua
        keyDescriptions[hotkey.key] = hotkey.name
    end
end
