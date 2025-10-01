

local UIUtil = import("/lua/ui/uiutil.lua")
local LayoutHelpers = import("/lua/maui/layouthelpers.lua")

local Window = import("/lua/maui/window.lua").Window
local Edit = import("/lua/maui/edit.lua").Edit
local Group = import("/lua/maui/group.lua").Group
local BaseChunkDialogRow = import("/mods/fa-joe-ai/lua/ui/Dialogs/BaseChunkDialogRow.lua").BaseChunkDialogRow

local LazyVar = import("/lua/lazyvar.lua")

--- A basic faction icon with the corresponding background color of the faction.
---@class UIBaseChunkDialogScrollArea: Group
---@field Rows UIBaseChunkDialogRow[]
---@field ScrollArea Bitmap
---@field ScrollTopIndex LazyVar        # of type integer
---@field ActiveTemplates LazyVar       # of type AILoadedBaseChunkTemplate[]
---@field ActiveTemplatesCount LazyVar  # of type integer
BaseChunkDialogScrollArea = ClassUI(Group) {

    TemplateRowHeight = LazyVar.Create(32),
    TemplateRowGap = LazyVar.Create(2),


    ---@param self UIBaseChunkDialogScrollArea
    ---@param parent Control
    __init = function(self, parent)
        Group.__init(self, parent)
        self.Rows = {}
        self.Scroll = UIUtil.CreateVertScrollbarFor(self, 5)
        self.ScrollTopIndex = LazyVar.Create(1)
        self.ActiveTemplates = LazyVar.Create({})
        self.ActiveTemplatesCount = LazyVar.Create(0)
        self.ActiveTemplatesCount:Set(
            function()
                return table.getn(self.ActiveTemplates())
            end
        )

        self.ScrollArea = UIUtil.CreateBitmapColor(self, '33ffffff')

        self.ActiveTemplates.OnDirty = function()
            self:PopulateRows()
        end

    end,

    ---@param self UIBaseChunkDialogScrollArea
    ---@param parent Control
    __post_init = function(self, parent)
        -- provide some initial size, or everything burns
        LayoutHelpers.LayoutFor(self)
            :Width(300)
            :Height(300)
            :End()

        LayoutHelpers.LayoutFor(self.Scroll)
            :Over(self, 10)
            :End()

        LayoutHelpers.LayoutFor(self.ScrollArea)
            :Fill(self)
            :End()
    end,


    ---@param self UIBaseChunkDialogScrollArea
    PopulateRows = function(self)
        -- hide all rows by default
        for _, row in self.Rows do
            row:Hide()
        end

        local startIndex = self.ScrollTopIndex()
        local activeTemplates = self.ActiveTemplates()
        local activeTemplatesCount = self.ActiveTemplatesCount()

        for k = startIndex, activeTemplatesCount do
            local rowIndex = k - startIndex
            local row = self.Rows[rowIndex]
            if row then
                row:Show()

                local template = activeTemplates[k]
                row:Update(template)
            end
        end
    end,

    ---@param self UIBaseChunkDialogScrollArea
    CreateRows = function(self)
        local templateRowHeight = self.TemplateRowHeight()
        local templateRowGap = self.TemplateRowGap()
        local TemplateAreaHeight = self.Height()
        local instances = math.floor(TemplateAreaHeight / (templateRowHeight + templateRowGap))

        for k = 1, instances do
            local row = BaseChunkDialogRow(self)

            LayoutHelpers.LayoutFor(row)
                :AtLeftIn(self)
                :AtRightIn(self)
                :Height(templateRowHeight)
                :AtTopIn(self, (k - 1) * (templateRowHeight + 2))
                :End()

            self.Rows[k] = row
        end

        self:PopulateRows()
    end,

    ---@param self UIBaseChunkDialogScrollArea
    ReCreateRows = function(self)
        for _, row in self.Rows do
            row:Destroy()
        end

        self.Rows = {}
        self:CreateRows()
    end,

   --#region Scroll functionality

    --- Called by the engine (via the scroll component) each frame to determine the scroll bar properties.
    ---@param self UIBaseChunkDialogScrollArea
    ---@param axis "Vert" | "Horz"
    ---@return integer  # minimum range
    ---@return integer  # maximum range
    ---@return integer  # top item
    ---@return integer  # maximum scroll range
    GetScrollValues = function(self, axis)
        local currentTop = self.ScrollTopIndex()
        local numberOfItems = self.ActiveTemplatesCount()
        local numberOfRows = table.getn(self.Rows)

        local firstItem = 1
        local lastItem = numberOfItems
        local currentTopItem = currentTop
        local maximumTopItem = math.min(currentTop + numberOfRows, numberOfItems)

        return firstItem, lastItem, currentTopItem, maximumTopItem
    end,

    --- Called by the engine (via the scroll component) when we scroll using the mouse wheel, the scroll bar or the buttons.
    ---@param self UIBaseChunkDialogScrollArea
    ---@param axis "Vert" | "Horz"
    ---@param delta integer  # positive or negative
    ScrollLines = function(self, axis, delta)
        self:ScrollSetTop(axis, self.ScrollTopIndex() + math.floor(delta))
    end,

    --- Called by the engine (via the scroll component) when we use page up/page down keys
    ---@param self UIBaseChunkDialogScrollArea
    ---@param axis "Vert" | "Horz"
    ---@param delta integer  # positive or negative
    ScrollPages = function(self, axis, delta)
        self:ScrollSetTop(axis, self.ScrollTopIndex() + math.floor(delta) * table.getn(self.Rows))
    end,

    ---@param self UIBaseChunkDialogScrollArea
    ---@param axis "Vert" | "Horz"
    ---@param top integer  # top item
    ScrollSetTop = function(self, axis, top)
        local numberOfItems = self.ActiveTemplatesCount()
        local numberOfRows = table.getn(self.Rows)
        local newTop = math.max(math.min(numberOfItems - numberOfRows, math.floor(top)), 1)
        if newTop == self.ScrollTopIndex() then
            return
        end

        self.ScrollTopIndex:Set(newTop)
        self:PopulateRows()
    end,

    ---@param self UIBaseChunkDialogScrollArea
    ---@param axis "Vert" | "Horz"
    IsScrollable = function(self, axis)
        return true
    end,

    ---@param self UIBaseChunkDialogScrollArea
    ---@param axis "Vert" | "Horz"
    ScrollToBottom = function(self, axis)
    end,

    --#endregion

}