-- Hooks into: https://github.com/FAForever/fa/blob/develop/lua/keymap/keycategories.lua
do

    local HotkeysModule = import("/mods/fa-joe-ai/lua/ui/hotkeys.lua")

    -- keyCategories is a globally defined table in keycategories.lua
    keyCategories[HotkeysModule.KeyCategories.Base.Key] = HotkeysModule.KeyCategories.Base.Name
    keyCategories[HotkeysModule.KeyCategories.BaseChunks.Key] = HotkeysModule.KeyCategories.BaseChunks.Name
    keyCategories[HotkeysModule.KeyCategories.Behavior.Key] = HotkeysModule.KeyCategories.Behavior.Name


    -- keyCategoryOrder is a globally defined table in keycategories.lua
    table.insert(keyCategoryOrder, HotkeysModule.KeyCategories.Base.Key)
    table.insert(keyCategoryOrder, HotkeysModule.KeyCategories.BaseChunks.Key)
    table.insert(keyCategoryOrder, HotkeysModule.KeyCategories.Behavior.Key)
end
