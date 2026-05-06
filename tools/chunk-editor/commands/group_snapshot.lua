-- Shared snapshot/restore helpers for commands that mutate the structure of
-- `template.Groups` (assign, delete, duplicate, ...). Each command captures
-- a `before` and `after` map of {slot -> group-copy | false}, where `false`
-- means "this slot was empty/missing".

local M = {}

---@param locs table<LoveBuildingIdentifier, LoveBaseChunkLocation[]>
function M.deepCopyLocations(locs)
    local copy = {}
    for id, list in pairs(locs) do
        local listCopy = {}
        for k = 1, #list do
            local loc = list[k]
            listCopy[k] = { loc[1], loc[2], loc[3] }
        end
        copy[id] = listCopy
    end
    return copy
end

---@param group LoveBaseChunkGroup?
---@return LoveBaseChunkGroup|false  # `false` is the sentinel for "didn't exist"
function M.deepCopyGroup(group)
    if not group then return false end
    return {
        Name = group.Name,
        Locations = M.deepCopyLocations(group.Locations or {}),
    }
end

---@param group LoveBaseChunkGroup?
---@return boolean
function M.isGroupEmpty(group)
    if not group or not group.Locations then return true end
    for _, locs in pairs(group.Locations) do
        if #locs > 0 then return false end
    end
    return true
end

---@param template LoveBaseChunk
---@param snapshot table<integer, LoveBaseChunkGroup|false>
function M.restoreSlots(template, snapshot)
    template.Groups = template.Groups or {}
    for slot, snap in pairs(snapshot) do
        if snap == false then
            template.Groups[slot] = nil
        else
            template.Groups[slot] = M.deepCopyGroup(snap)
        end
    end
end

return M
