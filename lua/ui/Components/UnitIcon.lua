local Group = import("/lua/maui/group.lua").Group
local LazyVar = import("/lua/lazyvar.lua")

local UIUtil = import("/lua/ui/uiutil.lua")
local LayoutHelpers = import("/lua/maui/layouthelpers.lua")

local ValidBackgroundIcons = {
    land = true,
    air = true,
    sea = true,
    amph = true
}

--- A basic unit icon with the corresponding background (land/air/naval/amphibious).
---@class UIUnitIcon: Group
---@field UnitIcon Bitmap
---@field Background Bitmap
---@field UnitId LazyVar<UnitId>
UnitIcon = ClassUI(Group) {

    ---@param self UIUnitIcon
    ---@param parent Control
    __init = function(self, parent)
        Group.__init(self, parent)

        self.UnitIcon = UIUtil.CreateBitmap(self, UIUtil.UIFile('/widgets/faction-icons-alpha_bmp/observer_ico.dds'))
        self.Background = UIUtil.CreateBitmapColor(self, '00000000')

        self.UnitId = LazyVar.Create("")
        self.UnitId.OnDirty = function(faction)
            self:Update(faction())
        end

        self:Update(self.UnitId())
    end,

    ---@param self UIUnitIcon
    ---@param parent Control
    __post_init = function(self, parent)

        LayoutHelpers.LayoutFor(self)
            :Width(32)
            :Height(32)
            :Over(parent, 0)
            :End()

        LayoutHelpers.LayoutFor(self.Background)
            :Fill(self)
            :DisableHitTest(true)
            :End()

        LayoutHelpers.LayoutFor(self.UnitIcon)
            :Fill(self)
            :DisableHitTest(true)
            :Over(self.Background, 1)
            :End()
    end,

    --- Get the path to the icon of a unit.
    ---@param self UIUnitIcon
    ---@param unitId UnitId
    ---@return FileName
    GetUnitPath = function(self, unitId)
        return '/icons/units/' .. tostring(unitId) .. '_icon.dds'
    end,

    --- Get the type of background for a unit.
    ---@param self UIUnitIcon
    ---@param unitId UnitId
    ---@return string
    GetUnitBackgroundType = function(self, unitId)
        local blueprint = __blueprints[unitId]
        if not blueprint then
            return "land"
        end

        local blueprintGeneralIcon = blueprint.General.Icon
        if not ValidBackgroundIcons[blueprintGeneralIcon] then
            return "land"
        end

        return blueprintGeneralIcon
    end,

    --- Get the path to the background of a unit.
    ---@param self UIUnitIcon
    ---@param unitId UnitIdFB
    ---@return FileName
    GetUnitBackgroundPath = function(self, unitId)
        return '/icons/units/' .. tostring(self:GetUnitBackgroundType(unitId)) .. '_up.dds'
    end,

    ---@param self UIUnitIcon
    ---@param unitId UnitId
    Update = function(self, unitId)
        if not unitId or unitId == "" then
            self.UnitIcon:SetTexture(UIUtil.UIFile('/widgets/faction-icons-alpha_bmp/observer_ico.dds'))
            self.Background:SetSolidColor('00000000')
            return
        end

        self.UnitIcon:SetTexture(UIUtil.UIFile(self:GetUnitPath(unitId)))
        self.Background:SetTexture(UIUtil.UIFile(self:GetUnitBackgroundPath(unitId)))
    end,
}
