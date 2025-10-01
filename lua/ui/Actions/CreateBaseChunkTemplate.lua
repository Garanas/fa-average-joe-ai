local AIBaseChunkTemplate = import("/mods/fa-joe-ai/lua/Shared/AIBaseChunkTemplate.lua")

--- Creates a base chunk template from the currently selected units. This function only runs in the UI and is supposed to be called from a hotkey.
function Handle(size)
    local units = GetSelectedUnits()
    local template = AIBaseChunkTemplate.CreateTemplate(units, size)

    -- copy the template to the clipboard
    local stringified = AIBaseChunkTemplate.SerializeTemplate(template)
    CopyToClipboard(stringified)
    print("Template copied to clipboard")

    -- preview the template on screen
    AIBaseChunkTemplate.PreviewTemplate(template)
end
