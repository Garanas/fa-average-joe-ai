-- Hooks into: https://github.com/FAForever/fa/blob/develop/lua/keymap/keydescriptions.lua

do
    local modKeyDescriptions = {}

    modKeyDescriptions['average_joe_ai_create_chunk_template_4'] = "Joe AI - Create AI base chunk template (004x004)"
    modKeyDescriptions['average_joe_ai_create_chunk_template_8'] = "Joe AI - Create AI base chunk template (008x008)"
    modKeyDescriptions['average_joe_ai_create_chunk_template_16'] = "Joe AI - Create AI base chunk template (016x016)"
    modKeyDescriptions['average_joe_ai_create_chunk_template_32'] = "Joe AI - Create AI base chunk template (032x032)"
    modKeyDescriptions['average_joe_ai_create_chunk_template_64'] = "Joe AI - Create AI base chunk template (064x064)"
    modKeyDescriptions['average_joe_ai_create_chunk_template_128'] = "Joe AI - Create AI base chunk template (128x128)"

    -- Actions is a globally defined table in keydescriptions.lua
    keyDescriptions = table.combine(keyDescriptions, modKeyDescriptions)
end