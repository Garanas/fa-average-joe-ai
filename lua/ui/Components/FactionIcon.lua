
local Group = import("/lua/maui/group.lua").Group
local LazyVar = import("/lua/lazyvar.lua")

local UIUtil = import("/lua/ui/uiutil.lua")
local LayoutHelpers = import("/lua/maui/layouthelpers.lua")

--- A basic faction icon with the corresponding background color of the faction.
---@class UIFactionIcon: Group
---@field FactionIcon Bitmap
---@field Background Bitmap
---@field Faction LazyVar<FactionCategory>
FactionIcon = ClassUI(Group) {

    ---@param self UIFactionIcon
    ---@param parent Control
    __init = function(self, parent)
        Group.__init(self, parent)

        self.FactionIcon = UIUtil.CreateBitmap(self, UIUtil.UIFile('/widgets/faction-icons-alpha_bmp/observer_ico.dds'))
        self.Background = UIUtil.CreateBitmapColor(self, '00000000')

        self.Faction = LazyVar.Create("")
        self.Faction.OnDirty = function(faction)
            self:Update(faction())
        end

        self:Update(self.Faction())
    end,

    ---@param self UIFactionIcon
    ---@param parent Control
    __post_init = function(self, parent)

        LayoutHelpers.LayoutFor(self)
            :Width(24)
            :Height(24)
            :Over(parent, 0)
            :End()

        LayoutHelpers.LayoutFor(self.Background)
            :Fill(self)
            :DisableHitTest(true)
            :End()

        LayoutHelpers.LayoutFor(self.FactionIcon)
            :Fill(self)
            :DisableHitTest(true)
            :Over(self.Background, 1)
            :End()
    end,

    ---@param self UIFactionIcon
    ---@param faction FactionCategory
    Update = function(self, faction)
        local factionsModule = import("/lua/factions.lua")
        for _, factionData in factionsModule.Factions do
            if factionData.Category == faction then
                self.FactionIcon:SetTexture(UIUtil.UIFile(factionData.Icon))
                self.Background:SetSolidColor(factionData.loadingColor)
                return
            end
        end

        -- default to observer icon
        self.FactionIcon:SetTexture(UIUtil.UIFile('/widgets/faction-icons-alpha_bmp/observer_ico.dds'))
    end,
}
