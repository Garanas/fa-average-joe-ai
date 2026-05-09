local DebugUtils = import("/mods/fa-joe-ai/lua/Sim/Utils/DebugUtils.lua")
local JoeBuildingIdentifierModule = import("/mods/fa-joe-ai/lua/Shared/BaseChunks/JoeBuildingIdentifiers.lua")

local TableInsert = table.insert
local TableGetn = table.getn
local TableSetn = table.setn

--- Per-state colors used to draw the inner reservation indicator on a `JoeBuildSite`. States not in this table render no inner outline — currently `Free`, so empty sites stay visually clean.
---@type table<string, Color>
local StateColors = {
    Claimed  = '000000',
    Blocked  = 'ff0000',
    Building = 'ffaa00',
    Built    = '00ff00',
    Lost     = '888888',
}

--- A single build site for one structure. The site is the materialised result of mapping a base-chunk template onto a leaf: the template's `Locations` contribute one site per entry. The unit-derived states (`Lost`/`Building`/`Built`) are not stored — they are computed from `Unit` on demand. The two reservation flags (`Claimed`/`Blocked`) are stored.
---@class JoeBuildSite
---@field Point JoeBaseChunkLocation         # World-space {X, Z, orientation}, same shape as the chunk-template's location triples.
---@field Identifier JoeBuildingIdentifier   # The faction-agnostic role from the chunk template (e.g. "T1LandFactory").
---@field Unit? JoeUnit                      # The concrete unit, once one is assigned/built. nil until then.
---@field Leaf NavLeaf                       # The leaf this site belongs to (used for cascade-on-release).
---@field Claimed boolean                    # Transient reservation set by `ConstructionQueueComponent:RegisterBuildSite` and cleared on `RegisterUnit` or `FailJob`. Prevents two engineers from picking the same site between job claim and unit spawn.
---@field Blocked boolean                    # Sticky flag set by engineer behaviors that gave up on the site (terrain formations, persistent obstruction). Stays until `Unblock` or leaf release.
JoeBuildSite = ClassSimple {

    ---@param self JoeBuildSite
    ---@param point JoeBaseChunkLocation
    ---@param identifier JoeBuildingIdentifier
    ---@param leaf NavLeaf
    __init = function(self, point, identifier, leaf)
        self.Point = point
        self.Identifier = identifier
        self.Leaf = leaf
        self.Unit = nil
        self.Claimed = false
        self.Blocked = false
    end,

    -----------------------------------------------------------------------------
    --#region State predicates

    ---@param self JoeBuildSite
    ---@return boolean
    IsFree = function(self)
        return self.Unit == nil and not self.Claimed and not self.Blocked
    end,

    ---@param self JoeBuildSite
    ---@return boolean
    IsClaimed = function(self)
        return self.Claimed
    end,

    ---@param self JoeBuildSite
    ---@return boolean
    IsBlocked = function(self)
        return self.Blocked
    end,

    ---@param self JoeBuildSite
    ---@return boolean
    IsLost = function(self)
        return self.Unit ~= nil and IsDestroyed(self.Unit)
    end,

    ---@param self JoeBuildSite
    ---@return boolean
    IsBuilding = function(self)
        local unit = self.Unit
        return unit ~= nil
            and not IsDestroyed(unit)
            and unit:GetFractionComplete() < 1.0
    end,

    ---@param self JoeBuildSite
    ---@return boolean
    IsBuilt = function(self)
        local unit = self.Unit
        return unit ~= nil
            and not IsDestroyed(unit)
            and unit:GetFractionComplete() >= 1.0
    end,

    --- Returns the current state as a string. Unit-derived states (`Lost`/`Building`/`Built`) take priority when a unit is assigned; otherwise the reservation flags decide between `Blocked`, `Claimed`, and `Free`.
    ---@param self JoeBuildSite
    ---@return 'Free' | 'Lost' | 'Building' | 'Built' | 'Blocked' | 'Claimed'
    GetState = function(self)
        local unit = self.Unit
        if unit ~= nil then
            if IsDestroyed(unit) then
                return 'Lost'
            end
            if unit:GetFractionComplete() < 1.0 then
                return 'Building'
            end
            return 'Built'
        end
        if self.Blocked then
            return 'Blocked'
        end
        if self.Claimed then
            return 'Claimed'
        end
        return 'Free'
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region State mutators

    --- Marks the site as not buildable. Sticky: stays until `Unblock` or section release. Engineer behaviors call this when a build attempt fails for persistent reasons (terrain, obstruction) — transient interruptions should re-queue the job, not block the site.
    ---@param self JoeBuildSite
    Block = function(self)
        self.Blocked = true
    end,

    --- Clears the block flag. Use sparingly — a blocked site is usually blocked for the rest of the section's life.
    ---@param self JoeBuildSite
    Unblock = function(self)
        self.Blocked = false
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Debug visualization

    --- Draws the site's expected footprint as an outlined rectangle, color-coded by the building identifier. The rectangle is centered on `Point` with `SizeX`/`SizeZ` pulled from the identifier metadata, plus a small inset so adjacent sites stay visually separable. A nested half-size square overlays the current `GetState()`, colored by the `StateColors` table at the top of the file.
    ---@param self JoeBuildSite
    Draw = function(self)
        local metadata = JoeBuildingIdentifierModule.MapToMetadata(self.Identifier)
        local cx = self.Point[1]
        local cz = self.Point[2]
        local hx = 0.5 * metadata.SizeX
        local hz = 0.5 * metadata.SizeZ

        -- outer outline: footprint, identifier color
        DebugUtils.DrawSquareXZ(cx - hx, cz - hz, cx + hx, cz + hz, metadata.Color, 0.1)

        -- inner outline: state indicator. States missing from `StateColors` (currently `Free`) draw no inner outline.
        local innerColor = StateColors[self:GetState()]
        if innerColor then
            DebugUtils.DrawSquareXZ(cx - 0.5 * hx, cz - 0.5 * hz, cx + 0.5 * hx, cz + 0.5 * hz, innerColor)
        end
    end,

    --#endregion
}

--- Per-base storage of `JoeBuildSite`s. Pure storage — `JoeBase` is the coordinator (e.g. cascading releases when a section is released).
---@class JoeBaseBuildSiteComponent
---@field Base JoeBase
---@field Sites JoeBuildSite[]
JoeBaseBuildSiteComponent = ClassSimple {

    ---@param self JoeBaseBuildSiteComponent
    ---@param base JoeBase
    __init = function(self, base)
        self.Base = base
        self.Sites = {}
    end,

    -----------------------------------------------------------------------------
    --#region Mapping templates onto sections

    --- Materialises every `Locations` entry of the given template as a build site, anchored on a specific nav-mesh leaf (centered on `leaf.px`/`leaf.pz`). The leaf is recorded on each new site for cascade-on-release. Returns the array of newly-added sites so the caller can act on them immediately.
    ---@param self JoeBaseBuildSiteComponent
    ---@param template JoeBaseChunk
    ---@param leaf NavLeaf
    ---@return JoeBuildSite[]
    MapTemplate = function(self, template, leaf)
        local size = template.Size
        local anchorX = leaf.px - 0.5 * size
        local anchorZ = leaf.pz - 0.5 * size

        local newSites = {}
        for identifier, locations in template.Locations do
            for k = 1, TableGetn(locations) do
                local loc = locations[k]
                -- Saved coords use the world-center − 0.5 convention; +0.5
                -- recovers the world center which is what the engine wants.
                ---@type JoeBaseChunkLocation
                local worldPoint = {
                    anchorX + loc[1] + 0.5,
                    anchorZ + loc[2] + 0.5,
                    loc[3],
                }

                local site = JoeBuildSite(worldPoint, identifier, leaf)
                TableInsert(self.Sites, site)
                TableInsert(newSites, site)
            end
        end

        return newSites
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Queries and storage operations

    --- Collects every free site matching `identifier` into `cache`. The cache is cleared first and returned for chaining. Pass a reused table to avoid allocations on hot paths; pass nil to allocate a fresh one. Linear scan — fine for the prototype's site counts. See `Sim/CLAUDE.md` §3.2 for the caller-supplied cache convention.
    ---@param self JoeBaseBuildSiteComponent
    ---@param identifier JoeBuildingIdentifier
    ---@param cache? JoeBuildSite[]
    ---@return JoeBuildSite[]
    CollectFreeFor = function(self, identifier, cache)
        cache = cache or {}
        TableSetn(cache, 0)

        local sites = self.Sites
        for k = 1, TableGetn(sites) do
            local site = sites[k]
            if site.Identifier == identifier and site:IsFree() then
                TableInsert(cache, site)
            end
        end

        return cache
    end,

    --- Collects every site whose owning leaf matches `leafId` into `cache`. Cleared first, returned for chaining. Same caller-supplied-cache convention as `CollectFreeFor` — see `Sim/CLAUDE.md` §3.2.
    ---@param self JoeBaseBuildSiteComponent
    ---@param leafId NavLeafIdentifier
    ---@param cache? JoeBuildSite[]
    ---@return JoeBuildSite[]
    GetSitesByLeaf = function(self, leafId, cache)
        cache = cache or {}
        TableSetn(cache, 0)

        local sites = self.Sites
        for k = 1, TableGetn(sites) do
            local site = sites[k]
            if site.Leaf.Identifier == leafId then
                TableInsert(cache, site)
            end
        end

        return cache
    end,

    --- Drops every site whose owning leaf matches `leafId`. Called by `JoeBase:ReleaseLeaf` so released territory takes its sites with it.
    ---@param self JoeBaseBuildSiteComponent
    ---@param leafId NavLeafIdentifier
    ReleaseSitesFromLeaf = function(self, leafId)
        local sites = self.Sites
        local total = TableGetn(sites)
        local head = 1

        for k = 1, total do
            local site = sites[k]
            sites[k] = nil
            if site.Leaf.Identifier ~= leafId then
                sites[head] = site
                head = head + 1
            end
        end
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Debug visualization

    --- Draws every build site this base owns. Pure render — caller decides cadence.
    ---@param self JoeBaseBuildSiteComponent
    Draw = function(self)
        local sites = self.Sites
        for k = 1, TableGetn(sites) do
            sites[k]:Draw()
        end
    end,

    --#endregion
}
