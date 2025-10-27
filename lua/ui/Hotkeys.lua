---@class JoeHotkey
---@field category string
---@field key string
---@field name string
---@field action string



KeyCategories = {
    BaseChunks = {
        Key = "JoeAIBaseChunks",
        Name = "Joe AI - base chunk functionality",
    },
    Base = {
        Key = "JoeAIBase",
        Name = "Joe AI - base functionality",
    },
    Behavior = {
        Key = "JoeAIBehavior",
        Name = "Joe AI - behavior functionality",
    }
}

---@type JoeHotkey[]
local BaseChunkKeys = {
    {
        category = KeyCategories.BaseChunks.Key,
        key = 'average_joe_ai_dialog_toggle',
        name = 'Joe AI - Toggle base chunk dialog',
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/ToggleBaseChunkDialog.lua").Handle()',
    },
    {
        category = KeyCategories.BaseChunks.Key,
        key = 'average_joe_ai_create_chunk_template_4',
        name = 'Joe AI - Create AI base chunk template (004x004)',
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/CreateBaseChunkTemplate.lua").Handle(4)',
    },
    {
        category = KeyCategories.BaseChunks.Key,
        key = 'average_joe_ai_create_chunk_template_8',
        name = 'Joe AI - Create AI base chunk template (008x008)',
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/CreateBaseChunkTemplate.lua").Handle(8)',
    },
    {
        category = KeyCategories.BaseChunks.Key,
        key = 'average_joe_ai_create_chunk_template_16',
        name = 'Joe AI - Create AI base chunk template (016x016)',
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/CreateBaseChunkTemplate.lua").Handle(16)',
    },
    {
        category = KeyCategories.BaseChunks.Key,
        key = 'average_joe_ai_create_chunk_template_32',
        name = 'Joe AI - Create AI base chunk template (032x032)',
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/CreateBaseChunkTemplate.lua").Handle(32)',
    },
    {
        category = KeyCategories.BaseChunks.Key,
        key = 'average_joe_ai_create_chunk_template_64',
        name = 'Joe AI - Create AI base chunk template (064x064)',
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/CreateBaseChunkTemplate.lua").Handle(64)',
    },
    {
        category = KeyCategories.BaseChunks.Key,
        key = 'average_joe_ai_create_chunk_template_128',
        name = 'Joe AI - Create AI base chunk template (128x128)',
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/CreateBaseChunkTemplate.lua").Handle(128)',
    },
}

---@type JoeHotkey[]
local BehaviorHotkeys = {
    {
        category = KeyCategories.Behavior.Key,
        key = 'average_joe_ai_apply_error_behavior',
        name = 'Joe AI - Apply error behavior to selected units',
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/ApplyParameterFreeBehavior.lua").Handle("ErrorBehavior")',
    },
    {
        category = KeyCategories.Behavior.Key,
        key = 'average_joe_ai_apply_null_behavior',
        name = 'Joe AI - Apply null behavior to selected units',
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/ApplyParameterFreeBehavior.lua").Handle("NullBehavior")',
    },
    {
        category = KeyCategories.Behavior.Key,
        key = 'average_joe_ai_apply_wander_behavior',
        name = 'Joe AI - Apply wander behavior to selected units',
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/ApplyParameterFreeBehavior.lua").Handle("WanderBehavior")',
    },
    {
        category = KeyCategories.Behavior.Key,
        key = 'average_joe_ai_apply_ping_pong_behavior',
        name = 'Joe AI - Apply ping pong behavior to selected units',
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/ApplyParameterFreeBehavior.lua").Handle("PingPongBehavior")',
    },
    {
        category = KeyCategories.Behavior.Key,
        key = 'average_joe_ai_apply_reclaim_behavior',
        name = 'Joe AI - Apply engineer reclaim behavior to selected units',
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/ApplyReclaimBehavior.lua").Handle()',
    },
}

---@type JoeHotkey[]
local BaseHotkeys = {
    {
        category = KeyCategories.Base.Key,
        key = 'average_joe_ai_create_base_at_location',
        name = 'Joe AI - Create AI base at location',
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/CreateBase.lua").Handle()',
    },
    {
        category = KeyCategories.Base.Key,
        key = 'average_joe_ai_assign_reclaim_behavior_base',
        name = 'Joe AI - Assign reclaim behavior to selected engineers in base',
        action = 'UI_Lua import("/mods/fa-joe-ai/lua/ui/Actions/Base/AssignReclaimBehavior.lua").Handle()',
    },
}

---@type JoeHotkey[]
Keys = table.concatenate(BaseChunkKeys, BaseHotkeys, BehaviorHotkeys)
