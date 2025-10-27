local JoeBaseChunkTemplate = import("/mods/fa-joe-ai/lua/Shared/BaseChunks/JoeBaseChunkTemplate.lua")

--- Creates a base chunk template from the currently selected units. This function only runs in the UI and is supposed to be called from a hotkey.
function Handle(size)
    local units = GetSelectedUnits()
    local template = JoeBaseChunkTemplate.CreateTemplate(units, size)

    -- copy the template to the clipboard
    local stringified = JoeBaseChunkTemplate.SerializeTemplate(template)
    CopyToClipboard(stringified)
    print("Template copied to clipboard")

    -- preview the template on screen
    JoeBaseChunkTemplate.PreviewTemplate(template)
end
