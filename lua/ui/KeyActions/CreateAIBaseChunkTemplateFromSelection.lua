local AIBaseChunkTemplate = import("/mods/fa-joe-ai/lua/Concepts/AIBaseChunkTemplate.lua")
local Utils = import("/mods/fa-joe-ai/lua/Utils.lua")

--- Creates a base chunk template from the currently selected units. This function only runs in the UI and is supposed to be called from a hotkey.
function CreateTemplateFromSelection()
    local units = GetSelectedUnits()
    local template = AIBaseChunkTemplate.CreateTemplate(units, 32)

    -- copy the template to the clipboard
    local stringified = Utils.SerializeValue(template)
    CopyToClipboard(stringified)
    print("Template copied to clipboard")

    -- preview the template on screen
    AIBaseChunkTemplate.PreviewTemplate(template)
end
