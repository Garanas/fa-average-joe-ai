local TableInsert = table.insert
local TableGetn = table.getn

--- A single build site for one structure. The site is the materialised result of mapping a base-chunk template onto a section: the template's `Locations` contribute one site per entry. State is *not* stored — it is derived from the assigned `Unit` on demand.
---@class JoeBuildSite
---@field Point JoeBaseChunkLocation         # World-space {X, Z, orientation}, same shape as the chunk-template's location triples.
---@field Identifier JoeBuildingIdentifier   # The faction-agnostic role from the chunk template (e.g. "T1LandFactory").
---@field Unit? JoeUnit                      # The concrete unit, once one is assigned/built. nil until then.
---@field Section NavSection                 # The section this site belongs to (used for cascade-on-release).
JoeBuildSite = ClassSimple {

    ---@param self JoeBuildSite
    ---@param point JoeBaseChunkLocation
    ---@param identifier JoeBuildingIdentifier
    ---@param section NavSection
    __init = function(self, point, identifier, section)
        self.Point = point
        self.Identifier = identifier
        self.Section = section
        self.Unit = nil
    end,

    -----------------------------------------------------------------------------
    --#region State predicates (computed from `Unit`)

    ---@param self JoeBuildSite
    ---@return boolean
    IsFree = function(self)
        return self.Unit == nil
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

    --- Returns the current state as a string. Treat this as a derived property — it always reflects the live state of the assigned unit.
    ---@param self JoeBuildSite
    ---@return 'Free' | 'Lost' | 'Building' | 'Built'
    GetState = function(self)
        local unit = self.Unit
        if unit == nil then
            return 'Free'
        end
        if IsDestroyed(unit) then
            return 'Lost'
        end
        if unit:GetFractionComplete() < 1.0 then
            return 'Building'
        end
        return 'Built'
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

    --- Materialises every `Locations` entry of the given template as a build site, anchored on the section's center. Returns the array of newly-added sites so the caller can act on them immediately.
    ---@param self JoeBaseBuildSiteComponent
    ---@param template JoeBaseChunk
    ---@param section NavSection
    ---@return JoeBuildSite[]
    MapTemplate = function(self, template, section)
        -- center the template on the section's centroid
        local size = template.Size
        local anchorX = section.Center[1] - 0.5 * size
        local anchorZ = section.Center[3] - 0.5 * size

        local newSites = {}
        for identifier, locations in template.Locations do
            for k = 1, TableGetn(locations) do
                local loc = locations[k]
                ---@type JoeBaseChunkLocation
                local worldPoint = {
                    anchorX + loc[1],
                    anchorZ + loc[2],
                    loc[3],
                }

                local site = JoeBuildSite(worldPoint, identifier, section)
                TableInsert(self.Sites, site)
                TableInsert(newSites, site)
            end
        end

        return newSites
    end,

    --#endregion

    -----------------------------------------------------------------------------
    --#region Queries and storage operations

    --- Returns the first free site matching `identifier`, or nil. Linear scan — fine for the prototype's site counts; revisit if a base ever has thousands of sites.
    ---@param self JoeBaseBuildSiteComponent
    ---@param identifier JoeBuildingIdentifier
    ---@return JoeBuildSite?
    FindFreeFor = function(self, identifier)
        local sites = self.Sites
        for k = 1, TableGetn(sites) do
            local site = sites[k]
            if site.Identifier == identifier and site:IsFree() then
                return site
            end
        end
        return nil
    end,

    --- Returns every site whose `Section.Identifier` matches. Useful for "show me what's planned for this section" tooling and for cascade-on-release.
    ---@param self JoeBaseBuildSiteComponent
    ---@param sectionId NavSectionIdentifier
    ---@return JoeBuildSite[]
    GetSitesBySection = function(self, sectionId)
        local result = {}
        local sites = self.Sites
        for k = 1, TableGetn(sites) do
            local site = sites[k]
            if site.Section.Identifier == sectionId then
                TableInsert(result, site)
            end
        end
        return result
    end,

    --- Drops every site whose section matches. Called by `JoeBase:ReleaseSection` so released territory takes its sites with it.
    ---@param self JoeBaseBuildSiteComponent
    ---@param sectionId NavSectionIdentifier
    ReleaseSitesFromSection = function(self, sectionId)
        local sites = self.Sites
        local total = TableGetn(sites)
        local head = 1

        for k = 1, total do
            local site = sites[k]
            sites[k] = nil
            if site.Section.Identifier ~= sectionId then
                sites[head] = site
                head = head + 1
            end
        end
    end,

    --#endregion
}
