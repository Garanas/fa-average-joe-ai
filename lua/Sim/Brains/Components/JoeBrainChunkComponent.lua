local NavGenerator = import("/lua/sim/navgenerator.lua")
local Shared = import("/lua/shared/navgenerator.lua")

local TableInsert = table.insert
local TableGetn = table.getn

--- Manages the brain-level view of claimed nav-mesh leaves, plus the BFS queries that locate new claimable area.
---
--- The brain's claim set is *the union of every base's claim set*. Bases are the only writers; the brain mirrors via `ClaimLeaf` / `ReleaseLeaf`. Each leaf's value here is the owning `JoeBase` reference — fast `IsClaimed` lookup, plus we know who owns it without scanning all bases.
---
--- Leaf identifiers are globally unique across nav layers (they share a counter), so a single `Leaves` table holds claims on Land, Water, etc. without collision; the layer is resolved per-query when walking the mesh.
---@class JoeBrainChunkComponent
---@field Brain JoeBrain
---@field Leaves table<NavLeafIdentifier, JoeBase>
JoeBrainChunkComponent = ClassSimple {

    ---@param self JoeBrainChunkComponent
    ---@param brain JoeBrain
    __init = function(self, brain)
        self.Brain = brain
        self.Leaves = {}
    end,

    -----------------------------------------------------------------------------
    --#region Mirror from base claims

    --- Called by `JoeBase:ClaimLeaf` (the coordinator) to mirror the claim into the brain set. Same name as the base-side method on purpose — they're the same operation at two layers.
    ---@param self JoeBrainChunkComponent
    ---@param leafId NavLeafIdentifier
    ---@param base JoeBase
    ClaimLeaf = function(self, leafId, base)
        self.Leaves[leafId] = base
    end,

    --- Called by `JoeBase:ReleaseLeaf` (or `JoeBase:ReleaseAllLeaves`) to mirror the release.
    --- Defensively only clears if the requesting base is the current owner — guards against an out-of-order release accidentally clearing another base's claim.
    ---@param self JoeBrainChunkComponent
    ---@param leafId NavLeafIdentifier
    ---@param base JoeBase
    ReleaseLeaf = function(self, leafId, base)
        if self.Leaves[leafId] == base then
            self.Leaves[leafId] = nil
        end
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Lookups

    ---@param self JoeBrainChunkComponent
    ---@param leafId NavLeafIdentifier
    ---@return boolean
    IsClaimed = function(self, leafId)
        return self.Leaves[leafId] ~= nil
    end,

    --- Returns the base that owns the leaf, or nil if unclaimed.
    ---@param self JoeBrainChunkComponent
    ---@param leafId NavLeafIdentifier
    ---@return JoeBase?
    GetOwner = function(self, leafId)
        return self.Leaves[leafId]
    end,

    --- Looks up the NavLeaf that contains a position on the given layer. Thin wrapper over `NavGrid:FindLeaf`.
    ---@param self JoeBrainChunkComponent
    ---@param layer NavLayers
    ---@param position Vector
    ---@return NavLeaf?
    FindLeaf = function(self, layer, position)
        local grid = NavGenerator.NavGrids[layer]
        if not grid then
            return nil
        end
        return grid:FindLeaf(position)
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Queries

    --- Grows outward from the seed position by walking leaf neighbors (`leaf[k]`), skipping leaves that are unpathable, smaller than `minLeafSize`, or already claimed by a base other than `excludeBase`. Stops when accumulated leaf area meets `areaTarget`. The caller decides whether to actually claim the result.
    ---
    --- `areaTarget` is in raw squared world units — e.g. one 16×16 leaf contributes 256.
    ---@param self JoeBrainChunkComponent
    ---@param layer NavLayers
    ---@param seedPosition Vector
    ---@param areaTarget number
    ---@param minLeafSize number
    ---@param excludeBase? JoeBase
    ---@return NavLeaf[]
    ---@return number    # total accumulated area (raw squared units)
    FindClaimableArea = function(self, layer, seedPosition, areaTarget, minLeafSize, excludeBase)
        local seedLeaf = self:FindLeaf(layer, seedPosition)
        if not seedLeaf then
            return {}, 0
        end

        local NavLeaves = NavGenerator.NavLeaves
        local accepted = {}
        local seen = { [seedLeaf.Identifier] = true }
        local queue = { seedLeaf }
        local head = 1
        local tail = 1
        local accumulated = 0

        while head <= tail and accumulated < areaTarget do
            local leaf = queue[head]
            head = head + 1

            if leaf.Label > 0
                and leaf.Size >= minLeafSize
                and not self:IsBlockingForQuery(leaf.Identifier, excludeBase)
            then
                TableInsert(accepted, leaf)
                accumulated = accumulated + leaf.Size * leaf.Size

                -- leaf neighbours are integer-indexed entries on the leaf table (NavGenerator populates these during mesh build)
                for k = 1, TableGetn(leaf) do
                    local neighborId = leaf[k]
                    if not seen[neighborId] then
                        seen[neighborId] = true
                        tail = tail + 1
                        queue[tail] = NavLeaves[neighborId]
                    end
                end
            end
        end

        return accepted, accumulated
    end,

    --- Like `FindClaimableArea` but biased toward `targetPosition` — leaves nearer the target are visited first (best-first by squared distance from leaf center). Useful when extending a base toward a known objective.
    ---@param self JoeBrainChunkComponent
    ---@param layer NavLayers
    ---@param seedPosition Vector
    ---@param targetPosition Vector
    ---@param areaTarget number
    ---@param minLeafSize number
    ---@param excludeBase? JoeBase
    ---@return NavLeaf[]
    ---@return number
    FindClaimableAreaToward = function(self, layer, seedPosition, targetPosition, areaTarget, minLeafSize, excludeBase)
        local seedLeaf = self:FindLeaf(layer, seedPosition)
        if not seedLeaf then
            return {}, 0
        end

        local NavLeaves = NavGenerator.NavLeaves
        local tx = targetPosition[1]
        local tz = targetPosition[3]

        local function priority(leaf)
            local dx = leaf.px - tx
            local dz = leaf.pz - tz
            return dx * dx + dz * dz
        end

        -- Linear-scan priority queue. Frontier sizes are small in practice; promote to NavDatastructures.NavHeap if profiling says otherwise.
        local frontier = { seedLeaf }
        local frontierCount = 1
        local accepted = {}
        local seen = { [seedLeaf.Identifier] = true }
        local accumulated = 0

        while frontierCount > 0 and accumulated < areaTarget do
            local bestIdx = 1
            local bestPriority = priority(frontier[1])
            for k = 2, frontierCount do
                local p = priority(frontier[k])
                if p < bestPriority then
                    bestPriority = p
                    bestIdx = k
                end
            end

            local leaf = frontier[bestIdx]
            frontier[bestIdx] = frontier[frontierCount]
            frontier[frontierCount] = nil
            frontierCount = frontierCount - 1

            if leaf.Label > 0
                and leaf.Size >= minLeafSize
                and not self:IsBlockingForQuery(leaf.Identifier, excludeBase)
            then
                TableInsert(accepted, leaf)
                accumulated = accumulated + leaf.Size * leaf.Size

                for k = 1, TableGetn(leaf) do
                    local neighborId = leaf[k]
                    if not seen[neighborId] then
                        seen[neighborId] = true
                        frontierCount = frontierCount + 1
                        frontier[frontierCount] = NavLeaves[neighborId]
                    end
                end
            end
        end

        return accepted, accumulated
    end,

    --- True if the leaf is claimed by *some other* base — i.e. it should block expansion. A leaf claimed by `excludeBase` is treated as free so the base can re-extend over its own territory.
    ---@param self JoeBrainChunkComponent
    ---@param leafId NavLeafIdentifier
    ---@param excludeBase? JoeBase
    ---@return boolean
    IsBlockingForQuery = function(self, leafId, excludeBase)
        local owner = self.Leaves[leafId]
        if not owner then
            return false
        end
        return owner ~= excludeBase
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Debug visualization

    --- Draws each claimed leaf, color-coded by the owning base's index in `brain.Bases`. Owners are derived per-tick (cheap) so newly-added bases pick up a stable color without extra bookkeeping. Pure render — caller (`JoeBrain:Draw`) decides cadence.
    ---@param self JoeBrainChunkComponent
    Draw = function(self)
        local bases = self.Brain.Bases
        if not bases then
            return
        end

        -- map base reference -> color (index in brain.Bases drives the LabelToColor hash)
        local baseColors = {}
        for k = 1, TableGetn(bases) do
            baseColors[bases[k]] = Shared.LabelToColor(k)
        end

        local NavLeaves = NavGenerator.NavLeaves
        for leafId, owningBase in self.Leaves do
            local leaf = NavLeaves[leafId]
            if leaf then
                local color = baseColors[owningBase] or 'ffffff'
                local h = 0.5 * leaf.Size
                NavGenerator.DrawSquare(leaf.px - h, leaf.pz - h, leaf.Size, color, 0.1)
            end
        end
    end,

    --#endregion
}

--- Creates the brain's chunk component. Mirrors the `Setup(brain)` pattern used by `GridReclaim`, `GridRecon`, and `GridPresence`.
---@param brain JoeBrain
---@return JoeBrainChunkComponent
function Setup(brain)
    return JoeBrainChunkComponent(brain)
end
