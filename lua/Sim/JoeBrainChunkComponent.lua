local NavGenerator = import("/lua/sim/navgenerator.lua")
local Shared = import("/lua/shared/navgenerator.lua")

local TableInsert = table.insert
local TableGetn = table.getn

--- Manages the brain-level view of claimed nav-mesh sections, plus the queries that locate new claimable area.
---
--- The brain's claim set is *the union of every base's claim set*. Bases are the only writers; the brain mirrors via `NoteBaseClaim` / `NoteBaseRelease`. Each section's value here is the owning `JoeBase` reference — fast `IsClaimed` lookup, plus we know who owns it without scanning all bases.
---
--- Section identifiers are globally unique across nav layers (they share a counter), so a single `Sections` table holds claims on Land, Water, etc. without collision; the layer is resolved per-query when walking the mesh.
---@class JoeBrainChunkComponent
---@field Brain JoeBrain
---@field Sections table<NavSectionIdentifier, JoeBase>
---@field Debug boolean
---@field DrawThread? thread
JoeBrainChunkComponent = ClassSimple {

    Debug = false,

    ---@param self JoeBrainChunkComponent
    ---@param brain JoeBrain
    __init = function(self, brain)
        self.Brain = brain
        self.Sections = {}
    end,

    -----------------------------------------------------------------------------
    --#region Mirror from base claims

    --- Called by `JoeBaseChunkComponent:Claim` to mirror the claim into the brain set.
    ---@param self JoeBrainChunkComponent
    ---@param sectionId NavSectionIdentifier
    ---@param base JoeBase
    NoteBaseClaim = function(self, sectionId, base)
        self.Sections[sectionId] = base
    end,

    --- Called by `JoeBaseChunkComponent:Release` (or `ReleaseAll`) to mirror the release.
    --- Defensively only clears if the requesting base is the current owner — guards against an out-of-order release accidentally clearing another base's claim.
    ---@param self JoeBrainChunkComponent
    ---@param sectionId NavSectionIdentifier
    ---@param base JoeBase
    NoteBaseRelease = function(self, sectionId, base)
        if self.Sections[sectionId] == base then
            self.Sections[sectionId] = nil
        end
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Lookups

    ---@param self JoeBrainChunkComponent
    ---@param sectionId NavSectionIdentifier
    ---@return boolean
    IsClaimed = function(self, sectionId)
        return self.Sections[sectionId] ~= nil
    end,

    --- Returns the base that owns the section, or nil if unclaimed.
    ---@param self JoeBrainChunkComponent
    ---@param sectionId NavSectionIdentifier
    ---@return JoeBase?
    GetOwner = function(self, sectionId)
        return self.Sections[sectionId]
    end,

    --- Looks up the NavSection that contains a position on the given layer.
    ---@param self JoeBrainChunkComponent
    ---@param layer NavLayers
    ---@param position Vector
    ---@return NavSection?
    FindSection = function(self, layer, position)
        local grid = NavGenerator.NavGrids[layer]
        if not grid then
            return nil
        end

        local leaf = grid:FindLeaf(position)
        if not leaf then
            return nil
        end

        return NavGenerator.NavSections[leaf.Section]
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Queries

    --- Grows outward from the seed position by walking section neighbors, skipping sections already claimed (by any base under this brain), until the accumulated section area meets `areaTarget`. Sections claimed by `excludeBase` are *not* treated as occupied, which lets a base re-extend across its own existing territory. Returns the accepted sections and the total area covered. The caller decides whether to actually claim them.
    ---@param self JoeBrainChunkComponent
    ---@param layer NavLayers
    ---@param seedPosition Vector
    ---@param areaTarget number     # in normalized NavSection.Area units
    ---@param excludeBase? JoeBase
    ---@return NavSection[]
    ---@return number               # total accumulated area
    FindClaimableArea = function(self, layer, seedPosition, areaTarget, excludeBase)
        local seedSection = self:FindSection(layer, seedPosition)
        if not seedSection then
            return {}, 0
        end

        local NavSections = NavGenerator.NavSections
        local accepted = {}
        local seen = { [seedSection.Identifier] = true }
        local queue = { seedSection }
        local head = 1
        local tail = 1
        local accumulated = 0

        while head <= tail and accumulated < areaTarget do
            local section = queue[head]
            head = head + 1

            if not self:IsBlockingForQuery(section.Identifier, excludeBase) then
                TableInsert(accepted, section)
                accumulated = accumulated + section.Area

                local neighbors = section.Neighbors
                for k = 1, TableGetn(neighbors) do
                    local neighborId = neighbors[k]
                    if not seen[neighborId] then
                        seen[neighborId] = true
                        tail = tail + 1
                        queue[tail] = NavSections[neighborId]
                    end
                end
            end
        end

        return accepted, accumulated
    end,

    --- Like `FindClaimableArea` but biased toward `targetPosition` — sections nearer the target are visited first (best-first by squared distance from section center). Useful when extending an existing base toward a known objective.
    ---@param self JoeBrainChunkComponent
    ---@param layer NavLayers
    ---@param seedPosition Vector
    ---@param targetPosition Vector
    ---@param areaTarget number
    ---@param excludeBase? JoeBase
    ---@return NavSection[]
    ---@return number
    FindClaimableAreaToward = function(self, layer, seedPosition, targetPosition, areaTarget, excludeBase)
        local seedSection = self:FindSection(layer, seedPosition)
        if not seedSection then
            return {}, 0
        end

        local NavSections = NavGenerator.NavSections
        local tx = targetPosition[1]
        local tz = targetPosition[3]

        local function priority(section)
            local dx = section.Center[1] - tx
            local dz = section.Center[3] - tz
            return dx * dx + dz * dz
        end

        -- Linear-scan priority queue. Frontier sizes are small in practice; promote to NavDatastructures.NavHeap if profiling says otherwise.
        local frontier = { seedSection }
        local frontierCount = 1
        local accepted = {}
        local seen = { [seedSection.Identifier] = true }
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

            local section = frontier[bestIdx]
            frontier[bestIdx] = frontier[frontierCount]
            frontier[frontierCount] = nil
            frontierCount = frontierCount - 1

            if not self:IsBlockingForQuery(section.Identifier, excludeBase) then
                TableInsert(accepted, section)
                accumulated = accumulated + section.Area

                local neighbors = section.Neighbors
                for k = 1, TableGetn(neighbors) do
                    local neighborId = neighbors[k]
                    if not seen[neighborId] then
                        seen[neighborId] = true
                        frontierCount = frontierCount + 1
                        frontier[frontierCount] = NavSections[neighborId]
                    end
                end
            end
        end

        return accepted, accumulated
    end,

    --- True if the section is claimed by *some other* base — i.e. it should block expansion. A section claimed by `excludeBase` is treated as free so the base can re-extend over its own territory.
    ---@param self JoeBrainChunkComponent
    ---@param sectionId NavSectionIdentifier
    ---@param excludeBase? JoeBase
    ---@return boolean
    IsBlockingForQuery = function(self, sectionId, excludeBase)
        local owner = self.Sections[sectionId]
        if not owner then
            return false
        end
        return owner ~= excludeBase
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Debug visualization

    ---@param self JoeBrainChunkComponent
    EnableDebug = function(self)
        if self.Debug then
            return
        end
        self.Debug = true
        self.DrawThread = ForkThread(self.DrawLoop, self)
    end,

    ---@param self JoeBrainChunkComponent
    DisableDebug = function(self)
        self.Debug = false
        if self.DrawThread then
            KillThread(self.DrawThread)
            self.DrawThread = nil
        end
    end,

    ---@param self JoeBrainChunkComponent
    DrawLoop = function(self)
        while self.Debug do
            self:Draw()
            WaitTicks(1)
        end
    end,

    --- Draws each claimed section's leaves, color-coded by the owning base's index in `brain.Bases`. Owners are derived per-tick (cheap) so newly-added bases pick up a stable color without extra bookkeeping.
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

        for sectionId, owningBase in self.Sections do
            local section = NavGenerator.NavSections[sectionId]
            if section then
                local color = baseColors[owningBase] or 'ffffff'
                local leaves = section.Leaves
                for k = 1, TableGetn(leaves) do
                    local leaf = leaves[k]
                    local h = 0.5 * leaf.Size
                    NavGenerator.DrawSquare(leaf.px - h, leaf.pz - h, leaf.Size, color, 0.1)
                end
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
