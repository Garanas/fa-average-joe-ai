local NavUtils = import("/lua/sim/navutils.lua")
local NavGenerator = import("/lua/sim/navgenerator.lua")
local Shared = import("/lua/shared/navgenerator.lua")

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

--- A claim made by a single base on a single nav-mesh leaf. Carries per-leaf state the base wants to track (e.g. has a chunk template been applied here yet). Each pathable leaf hosts at most one template, so `Chunkified` is naturally per-leaf.
---@class JoeBaseLeafClaim
---@field Leaf NavLeaf
---@field Chunkified boolean

--- Per-base view of which nav-mesh leaves this base owns. Pure storage — `JoeBase` coordinates conflict checks against the brain's union view and mirrors successful claims back. Multiple bases can share a single underlying `NavSection` by claiming different leaves inside it; the section concept never appears here.
---@class JoeBaseChunkComponent
---@field Base JoeBase
---@field Layer NavLayers
---@field Leaves table<NavLeafIdentifier, JoeBaseLeafClaim>
JoeBaseChunkComponent = ClassSimple {

    --- Default minimum side length (in world units) of a leaf this base will accept as a claim. Smaller leaves (tiny pathable strips between unpathable terrain) are skipped by `JoeBase:ClaimAdjacentLeaf` so the base picks up usefully-sized building plots. Per-instance overridable.
    MinClaimSize = 16,

    ---@param self JoeBaseChunkComponent
    ---@param base JoeBase
    __init = function(self, base)
        self.Base = base
        self.Layer = InferLayer(base.Location) or "Land"
        self.Leaves = {}
    end,

    -----------------------------------------------------------------------------
    --#region Claims (pure storage — JoeBase coordinates conflict checks and brain mirroring)

    --- Records a claim on the given leaf. Pure storage; the caller (`JoeBase:ClaimLeaf`) is responsible for checking conflicts against the brain's union view and mirroring successful claims back.
    ---@param self JoeBaseChunkComponent
    ---@param leafId NavLeafIdentifier
    ClaimLeaf = function(self, leafId)
        local leaf = NavGenerator.NavLeaves[leafId]
        if not leaf then
            return
        end

        ---@type JoeBaseLeafClaim
        self.Leaves[leafId] = {
            Leaf = leaf,
            Chunkified = false,
        }
    end,

    --- Releases the claim on a single leaf. Pure storage; the caller mirrors the release to the brain.
    ---@param self JoeBaseChunkComponent
    ---@param leafId NavLeafIdentifier
    ReleaseLeaf = function(self, leafId)
        self.Leaves[leafId] = nil
    end,

    --- Clears every claim. Pure storage; the caller is expected to mirror each release to the brain *before* calling this so the union stays in sync.
    ---@param self JoeBaseChunkComponent
    ReleaseAllLeaves = function(self)
        self.Leaves = {}
    end,

    ---@param self JoeBaseChunkComponent
    ---@param leafId NavLeafIdentifier
    ---@return boolean
    IsClaimed = function(self, leafId)
        return self.Leaves[leafId] ~= nil
    end,

    ---@param self JoeBaseChunkComponent
    ---@param leafId NavLeafIdentifier
    ---@return JoeBaseLeafClaim?
    GetClaim = function(self, leafId)
        return self.Leaves[leafId]
    end,

    --- Marks a leaf claim as having had a chunk template applied to it. One template per leaf, so this is a simple flag flip.
    ---@param self JoeBaseChunkComponent
    ---@param leafId NavLeafIdentifier
    MarkChunkified = function(self, leafId)
        local claim = self.Leaves[leafId]
        if claim then
            claim.Chunkified = true
        end
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Debug logging

    --- Dumps the component's claim list to the log, one line per leaf, prefixed with the base id via `JoeBase:Log`. Cheap to call ad-hoc; not cheap enough to call per tick.
    ---@param self JoeBaseChunkComponent
    LogState = function(self)
        local base = self.Base
        local count = 0
        for _, _ in self.Leaves do
            count = count + 1
        end
        base:Log(string.format("ChunkComponent: layer=%s minClaim=%d leaves=%d",
            self.Layer, self.MinClaimSize, count))
        for leafId, claim in self.Leaves do
            local leaf = claim.Leaf
            base:Log(string.format("  leaf #%d size=%d at=(%.1f, %.1f) chunkified=%s",
                leafId, leaf.Size, leaf.px, leaf.pz, tostring(claim.Chunkified)))
        end
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Debug visualization

    --- Draws every claimed leaf, brighter when chunkified. Pure render — caller decides cadence (typically `JoeBase:Draw`).
    ---@param self JoeBaseChunkComponent
    Draw = function(self)
        local layerColor = Shared.LayerColors[self.Layer] or 'ffffff'

        for _, claim in self.Leaves do
            local leaf = claim.Leaf
            local color = claim.Chunkified and 'ffffff' or layerColor
            local h = 0.5 * leaf.Size
            NavGenerator.DrawSquare(leaf.px - h, leaf.pz - h, leaf.Size, color, 0.2)
        end
    end,

    --#endregion
}
