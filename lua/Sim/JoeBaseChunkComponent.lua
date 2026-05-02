local NavUtils = import("/lua/sim/navutils.lua")
local NavGenerator = import("/lua/sim/navgenerator.lua")
local Shared = import("/lua/shared/navgenerator.lua")

local TableGetn = table.getn

--- Determines the most natural layer for a base centered at the given position. Tests pathability on Land first, then Water.
---@param position Vector
---@return NavLayers?
local function InferLayer(position)
    if NavUtils.GetLabel("Land", position) then
        return "Land"
    end
    if NavUtils.GetLabel("Water", position) then
        return "Water"
    end
    return nil
end

--- A claim made by a single base on a single nav section. Carries per-section state that the base wants to track (e.g. has it been broken down into chunks/templates yet).
---@class JoeBaseSectionClaim
---@field Section NavSection
---@field Chunkified boolean

---@class JoeBaseChunkComponent
---@field Base JoeBase
---@field Layer NavLayers
---@field Sections table<NavSectionIdentifier, JoeBaseSectionClaim>
JoeBaseChunkComponent = ClassSimple {

    ---@param self JoeBaseChunkComponent
    ---@param base JoeBase
    __init = function(self, base)
        self.Base = base
        self.Layer = InferLayer(base.Location) or "Land"
        self.Sections = {}
    end,

    -----------------------------------------------------------------------------
    --#region Claims

    --- Records a claim on the given section. Mirrors the claim to the brain so the brain's set always reflects the union of all bases.
    ---@param self JoeBaseChunkComponent
    ---@param sectionId NavSectionIdentifier
    Claim = function(self, sectionId)
        local section = NavGenerator.NavSections[sectionId]
        if not section then
            return
        end

        ---@type JoeBaseSectionClaim
        self.Sections[sectionId] = {
            Section = section,
            Chunkified = false,
        }

        self.Base.Brain.ChunkComponent:NoteBaseClaim(sectionId, self.Base)
    end,

    --- Releases the claim on a single section. Mirrors to the brain.
    ---@param self JoeBaseChunkComponent
    ---@param sectionId NavSectionIdentifier
    Release = function(self, sectionId)
        if not self.Sections[sectionId] then
            return
        end
        self.Sections[sectionId] = nil
        self.Base.Brain.ChunkComponent:NoteBaseRelease(sectionId, self.Base)
    end,

    --- Releases every claim. Used when the base retreats from an expansion.
    ---@param self JoeBaseChunkComponent
    ReleaseAll = function(self)
        local brainComponent = self.Base.Brain.ChunkComponent
        for sectionId, _ in self.Sections do
            brainComponent:NoteBaseRelease(sectionId, self.Base)
        end
        self.Sections = {}
    end,

    ---@param self JoeBaseChunkComponent
    ---@param sectionId NavSectionIdentifier
    ---@return boolean
    IsClaimed = function(self, sectionId)
        return self.Sections[sectionId] ~= nil
    end,

    ---@param self JoeBaseChunkComponent
    ---@param sectionId NavSectionIdentifier
    ---@return JoeBaseSectionClaim?
    GetClaim = function(self, sectionId)
        return self.Sections[sectionId]
    end,

    --- Marks a claim as having been broken down into chunks/templates.
    ---@param self JoeBaseChunkComponent
    ---@param sectionId NavSectionIdentifier
    MarkChunkified = function(self, sectionId)
        local claim = self.Sections[sectionId]
        if claim then
            claim.Chunkified = true
        end
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Debug visualization

    --- Draws every claimed section's leaves, brighter when the claim is chunkified. Pure render — caller decides when to invoke (e.g. from `JoeBase:Draw`).
    ---@param self JoeBaseChunkComponent
    Draw = function(self)
        local layerColor = Shared.LayerColors[self.Layer] or 'ffffff'

        for _, claim in self.Sections do
            local section = claim.Section
            local color = claim.Chunkified and 'ffffff' or layerColor

            local leaves = section.Leaves
            for k = 1, TableGetn(leaves) do
                local leaf = leaves[k]
                local h = 0.5 * leaf.Size
                NavGenerator.DrawSquare(leaf.px - h, leaf.pz - h, leaf.Size, color, 0.2)
            end
        end
    end,

    --#endregion
}
