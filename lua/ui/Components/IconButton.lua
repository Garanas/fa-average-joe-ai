local UIUtil = import("/lua/ui/uiutil.lua")
local LayoutHelpers = import("/lua/maui/layouthelpers.lua")

local Button = import("/lua/maui/button.lua").Button

---@class UIIconButton: Button
---@field Icon Bitmap
IconButton = ClassUI(Button) {

    ---@param self UIIconButton
    ---@param parent Control
    ---@param icon FileName
    __init = function(self, parent, icon)
        local normal = UIUtil.SkinnableFile("/dialogs/check-box_btn/radio-d_btn_up.dds")
        local highlight = UIUtil.SkinnableFile("/dialogs/check-box_btn/radio-d_btn_over.dds")
        local disabled = UIUtil.SkinnableFile("/dialogs/check-box_btn/radio-d_btn_dis.dds")
        local active = UIUtil.SkinnableFile("/dialogs/check-box_btn/radio-d_btn_down.dds")

        Button.__init(self, parent, normal, active, highlight, disabled, "UI_Tab_Click_01", "UI_Tab_Rollover_01")

        self.Icon = UIUtil.CreateBitmap(self, icon)
    end,

    ---@param self UIIconButton
    ---@param parent Control
    __post_init = function(self, parent)
        LayoutHelpers.LayoutFor(self)
            :Width(32)
            :Height(32)
            :Over(parent, 10)
            :End()

        LayoutHelpers.LayoutFor(self.Icon)
            :AtCenterIn(self)
            :Width(12)
            :Height(12)
            :Over(self, 10)
            :DisableHitTest(true)
            :End()
    end,
}
