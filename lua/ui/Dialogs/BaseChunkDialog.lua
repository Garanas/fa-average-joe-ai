
local UIUtil = import("/lua/ui/uiutil.lua")
local LayoutHelpers = import("/lua/maui/layouthelpers.lua")

local Window = import("/lua/maui/window.lua").Window
local Edit = import("/lua/maui/edit.lua").Edit
local Group = import("/lua/maui/group.lua").Group
local BaseChunkDialogRow = import("/mods/fa-joe-ai/lua/ui/Dialogs/BaseChunkDialogRow.lua").BaseChunkDialogRow
local BaseChunkDialogScrollArea = import("/mods/fa-joe-ai/lua/ui/Dialogs/BaseChunkDialogScrollArea.lua").BaseChunkDialogScrollArea

local LazyVar = import("/lua/lazyvar.lua")

local WindowTextures = {
    tl = UIUtil.UIFile('/game/mini-map-brd/mini-map_brd_ul.dds'),
    tr = UIUtil.UIFile('/game/mini-map-brd/mini-map_brd_ur.dds'),
    tm = UIUtil.UIFile('/game/mini-map-brd/mini-map_brd_horz_um.dds'),
    ml = UIUtil.UIFile('/game/mini-map-brd/mini-map_brd_vert_l.dds'),
    m = UIUtil.UIFile('/game/mini-map-brd/mini-map_brd_m.dds'),
    mr = UIUtil.UIFile('/game/mini-map-brd/mini-map_brd_vert_r.dds'),
    bl = UIUtil.UIFile('/game/mini-map-brd/mini-map_brd_ll.dds'),
    bm = UIUtil.UIFile('/game/mini-map-brd/mini-map_brd_lm.dds'),
    br = UIUtil.UIFile('/game/mini-map-brd/mini-map_brd_lr.dds'),
    borderColor = 'ff415055',
}

---@class UIBaseChunkDialog : Window
---@field ConfigurationArea Bitmap
---@field Search Edit
---@field SearchLabel Text
---@field ScrollArea UIBaseChunkDialogScrollArea
---@field BaseChunkManager AIBaseChunkLoader
BaseChunkDialog = ClassUI(Window) {

    ---@param self UIBaseChunkDialog
    ---@param parent Control
    __init = function(self, parent)
        -- named fields for the window class
        local title = "Base Chunk Dialog"
        local icon = false
        local pin = false
        local config = true
        local lockSize = false
        local lockPosition = false
        local identifier = "BaseChunkDialog01"
        local defaultPosition = {
            Left = 10,
            Top = 300,
            Right = 410,
            Bottom = 625
        }

        Window.__init(self, parent, title, icon, pin, config, lockSize, lockPosition, identifier, defaultPosition)
        self:ApplyWindowTextures(WindowTextures)

        --#region Search functionality

        self.ConfigurationArea = UIUtil.CreateBitmapColor(self, '33ffffff')
        self.SearchLabel = UIUtil.CreateText(self.ConfigurationArea, "Search:", 12, UIUtil.bodyFont)
        self.Search = Edit(self.ConfigurationArea)

        --#endregion

        self.ScrollArea = BaseChunkDialogScrollArea(self)

         -- load the base chunk templates
        self:ReloadBaseChunkTemplates()
    end,

    ---@param self UIBaseChunkDialog
    ---@param parent Control
    __post_init = function(self, parent)
        LayoutHelpers.LayoutFor(self.ConfigurationArea)
            :AtTopIn(self.ClientGroup, 5)
            :AtLeftIn(self.ClientGroup, 10)
            :AtRightIn(self.ClientGroup, 10)
            :Height(30)
            :End()

        LayoutHelpers.LayoutFor(self.SearchLabel)
            :AtTopIn(self.ConfigurationArea, 5)
            :AtLeftIn(self.ConfigurationArea, 5)
            :Font(UIUtil.bodyFont, 12)
            :Hide()
            :Over(self, 10)
            :End()

        LayoutHelpers.LayoutFor(self.Search)
            :RightOf(self.SearchLabel, 5)
            :AtRightIn(self.ConfigurationArea, 5)
            :Height(20)
            :Font(UIUtil.bodyFont, 12)
            :Hide()
            :Over(self, 10)
            :End()

        LayoutHelpers.LayoutFor(self.ScrollArea)
            :Fill(self.ClientGroup)
            :AtRightIn(self.ClientGroup, 45)
            :Below(self.ConfigurationArea, 10)
            :ResetHeight()
            :End()

        self.ScrollArea:CreateRows()
    end,

    ---@param self UIBaseChunkDialog
    ReloadBaseChunkTemplates = function(self)
        self.BaseChunkManager = import("/mods/fa-joe-ai/lua/Shared/AIBaseChunkLoader.lua").CreateDefaultAIBaseChunkLoader()

        self.ScrollArea.ActiveTemplates:Set(self.BaseChunkManager.Templates)
        print(string.format("Loaded %d base chunk templates", table.getn(self.BaseChunkManager.Templates)))
    end,

    --#region Window functionality

    ---@param self UIBaseChunkDialog
    OnClose = function(self)
        self:Hide()
    end,

    ---@param self UIBaseChunkDialog
    OnConfigClick = function(self)
        self:ReloadBaseChunkTemplates()
    end,

    ---@param self UIBaseChunkDialog
    OnResizeSet = function(self)
        self.ScrollArea:ReCreateRows()
    end,

    --#endregion

    --#region Control functionality

    ---@param self UIBaseChunkDialog
    Show = function(self)
        Window.Show(self)

        self.ScrollArea:ReCreateRows()
    end,

    --#endregion
}

---@type UIBaseChunkDialog | false
local Instance = false

--- Toggles the base chunk dialog.
ToggleBaseChunkDialog = function()
    if Instance then
        if (Instance:IsHidden()) then
            Instance:Show()
        else
            Instance:Hide()
        end
    else
        Instance = BaseChunkDialog(GetFrame(0))
    end
end

-------------------------------------------------------------------------------
--#region Debugging

--- Called by the module manager when this module is reloaded
---@param newModule any
function __moduleinfo.OnReload(newModule)

    -- feature: hot reload

    if Instance then
        local isHidden = Instance:IsHidden()
        Instance:Destroy()
        Instance = false

        if not isHidden then
            -- if it wasn't hidden, then we recreate it. Make sure we don't error out in this process
            local ok, msg = pcall(newModule.ToggleBaseChunkDialog)
            if not ok then
                WARN("Error recreating BaseChunkDialog: " .. tostring(msg))
            end
        end
    end
end

--- Called by the module manager when this module becomes dirty
function __moduleinfo.OnDirty()

    -- feature: hot reload

    local modulePath = __moduleinfo.name
    ForkThread(
        function()
            import(modulePath)

        end
    )
end

--#endregion
