local BoundingBoxUtils = import("/mods/fa-joe-ai/lua/Shared/BoundingBoxUtils.lua")

local OffsetBuildableArea = 4

--- Returns the playable area in world coordinates.
---@return number   # x0 in world coordinates
---@return number   # z0 in world coordinates
---@return number   # x1 in world coordinates
---@return number   # z1 in world coordinates
GetPlayableArea = function()
    local playableRect = ScenarioInfo.MapData.PlayableRect
    if playableRect then
        return playableRect[1], playableRect[2], playableRect[3], playableRect[4]
    else
        return 0, 0, ScenarioInfo.size[1], ScenarioInfo.size[2]
    end
end

--- Returns the buildable area in world coordinates. Any build order that is (partially) outside of this area is invalid.
---@return number   # x0 in world coordinates
---@return number   # z0 in world coordinates
---@return number   # x1 in world coordinates
---@return number   # z1 in world coordinates
GetBuildableArea = function()
    local x0, z0, x1, z1 = GetPlayableArea()
    return x0 + OffsetBuildableArea, z0 + OffsetBuildableArea, x1 - OffsetBuildableArea, z1 - OffsetBuildableArea
end

--- Returns whether the build site
---@param px number     # center of build site, in world coordinates
---@param pz number     # center of build site, in world coordinates
---@param sx number     # usually blueprint.Footprint.SizeX
---@param sz number     # usually blueprint.Footprint.SizeZ
---@return boolean
IsBuildSiteInArea = function(px, pz, sx, sz)
    local x0, z0, x1, z1 = GetBuildableArea()
    return BoundingBoxUtils.Inside(px - 0.5 * sx, pz - 0.5 * sz, px + 0.5 * sx, pz + 0.5 * sz, x0, z0, x1, z1)
end
