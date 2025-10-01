
local UIUtil = import("/lua/ui/uiutil.lua")
local LayoutHelpers = import("/lua/maui/layouthelpers.lua")

local LazyVar = import("/lua/lazyvar.lua")

local Bitmap = import("/lua/maui/bitmap.lua").Bitmap
local IconButton = import("/mods/fa-joe-ai/lua/ui/Components/IconButton.lua").IconButton
local FactionIcon = import("/mods/fa-joe-ai/lua/ui/Components/FactionIcon.lua").FactionIcon

---@class UIBaseChunkDialogRow : Bitmap
---@field Template? AILoadedBaseChunkTemplate
---@field Name Text
---@field FactionIcon UIFactionIcon
---@field ToFileButton Button
---@field ToTemplateButton Button
---@field UnitIcons UIUnitIcon[] | TrashBag
BaseChunkDialogRow = ClassUI(Bitmap) {

    ---@param self UIBaseChunkDialogRow
    ---@param parent Control
    __init = function(self, parent)
        Bitmap.__init(self, parent)

        self.FactionIcon = FactionIcon(self)

        self.ToFileButton = IconButton(self, UIUtil.UIFile("/mods/fa-joe-ai/textures/icons/copy-template-source.png"))
        self.ToFileButton.OnClick = function(button, modifiers)
            if self.Template then
                local source = string.gsub(self.Template.Source, "^/mods/[^/]+/", "")
                CopyToClipboard(source)
                print("Template source path copied to clipboard!")
            end
        end

        self.ToTemplateButton = IconButton(self, UIUtil.UIFile("/mods/fa-joe-ai/textures/icons/to-build-template.png"))
        self.ToTemplateButton.OnClick = function(button, modifiers)
            local AIBaseChunkTemplateModule = import("/mods/fa-joe-ai/lua/Shared/BaseChunks/AIBaseChunkTemplate.lua")
            if self.Template then
                AIBaseChunkTemplateModule.PreviewTemplate(self.Template)
                print("Template preview!")
            end
        end

        self.Name = UIUtil.CreateText(self, "Unknown", 12, UIUtil.bodyFont)
        self.UnitIcons = TrashBag()
    end,

    ---@param self UIBaseChunkDialogRow
    ---@param parent Control
    __post_init = function(self, parent)
        self:SetSolidColor('33ffffff')

        LayoutHelpers.LayoutFor(self.ToFileButton)
            :AtLeftIn(self)
            :AtVerticalCenterIn(self)
            :End()

        LayoutHelpers.LayoutFor(self.ToTemplateButton)
            :RightOf(self.ToFileButton)
            :AtVerticalCenterIn(self)
            :End()

     LayoutHelpers.LayoutFor(self.FactionIcon)
            :RightOf(self.ToTemplateButton)
            :AtVerticalCenterIn(self)
            :End()

        LayoutHelpers.LayoutFor(self.Name)
            :RightOf(self.FactionIcon, 5)
            :AtVerticalCenterIn(self)
            :Font(UIUtil.bodyFont, 12)
            :End()
    end,

    ---@param self UIBaseChunkDialogRow
    ---@param template AILoadedBaseChunkTemplate
    Update = function(self, template)
        self.Template = template

        self.Name:SetText(template.Name or "Unnamed template")

        self:UpdateUnitIcons(template.Units)

        self.FactionIcon.Faction:Set(template.Faction)
    end,


    ---@param self UIBaseChunkDialogRow
    ---@param unitIds UnitId[]
    UpdateUnitIcons = function(self, unitIds)
        -- feature: consistent order
        table.sort(unitIds)

        -- hide all existing unit icons
        for _, icon in self.UnitIcons do
            icon:Hide()
        end

        -- figure out the unit icons
        for k = 1, table.getn(unitIds) do
            local unitId = unitIds[k]
            local unitIcon = self.UnitIcons[k]
            if not unitIcon then
                unitIcon = import("/mods/fa-joe-ai/lua/ui/Components/UnitIcon.lua").UnitIcon(self)
                self.UnitIcons[k] = unitIcon

                LayoutHelpers.LayoutFor(unitIcon)
                    :AtRightIn(self, 5 + (k - 1) * self.Height())
                    :AtVerticalCenterIn(self)
                    :DisableHitTest(true)
                    :Width(self.Height)
                    :Height(self.Height)
                    :End()
            end

            unitIcon.UnitId:Set(unitId)
            unitIcon:Show()
        end
    end,

}
