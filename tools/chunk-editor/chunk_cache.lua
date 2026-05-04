-- Loads every discovered chunk so callers can filter / display by the
-- chunk's actual fields (Size, Faction, building count, identifier set).
-- Polls the directory periodically for adds and deletes; modifications are
-- caught when the user reloads the chunk through the editor.

local Loader = require("loader")

local POLL_INTERVAL = 2.0  -- seconds

---@class LoveChunkCache
---@field shim LoveShim
---@field modRoot string
---@field entries LoveChunkEntry[]
---@field _byPath table<string, LoveChunkEntry>
---@field _accumulator number
local M = {}
M.__index = M

---@param shim LoveShim
---@param modRoot string
---@return LoveChunkCache
function M.new(shim, modRoot)
    return setmetatable({
        shim = shim,
        modRoot = modRoot,
        entries = {},
        _byPath = {},
        _accumulator = 0,
    }, M)
end

---@param template LoveBaseChunk?
local function summarize(template)
    if not template then return {} end
    local groupCount = 0
    local buildingCount = 0
    local identifiers = {}
    for _, group in pairs(template.Groups or {}) do
        groupCount = groupCount + 1
        for id, locs in pairs(group.Locations or {}) do
            identifiers[id] = true
            buildingCount = buildingCount + #locs
        end
    end
    return {
        size = template.Size,
        templateFaction = template.Faction,
        name = template.Name,
        groupCount = groupCount,
        buildingCount = buildingCount,
        identifiers = identifiers,
    }
end

---@param faction string
---@param file string
---@param fsPath string
---@return LoveChunkEntry
function M:_loadEntry(faction, file, fsPath)
    local template, err = Loader.loadChunk(self.shim, fsPath)
    ---@type LoveChunkEntry
    local entry = {
        faction = faction, file = file, fsPath = fsPath,
        error = err,
    }
    if template then
        local s = summarize(template)
        entry.size = s.size
        entry.templateFaction = s.templateFaction
        entry.name = s.name
        entry.groupCount = s.groupCount
        entry.buildingCount = s.buildingCount
        entry.identifiers = s.identifiers
    end
    return entry
end

local function sortEntries(list)
    table.sort(list, function(a, b)
        if a.faction ~= b.faction then return a.faction < b.faction end
        return a.file < b.file
    end)
end

local function replaceInPlace(target, source)
    for i = #target, 1, -1 do target[i] = nil end
    for i, v in ipairs(source) do target[i] = v end
end

--- Full rescan: discover every chunk file and (re)load it. Mutates
--- `self.entries` in place so external aliases stay valid.
function M:rebuild()
    local discovered = Loader.discoverChunks(self.modRoot)
    self._byPath = {}
    local list = {}
    for _, raw in ipairs(discovered) do
        local entry = self:_loadEntry(raw.faction, raw.file, raw.fsPath)
        table.insert(list, entry)
        self._byPath[entry.fsPath] = entry
    end
    sortEntries(list)
    replaceInPlace(self.entries, list)
end

--- Cheap periodic check. Picks up new files and deletions; modifications
--- are NOT detected (the cache loses freshness for an externally-edited
--- file until the user reloads it).
---@param dt number
---@return boolean changed
function M:poll(dt)
    self._accumulator = self._accumulator + (dt or 0)
    if self._accumulator < POLL_INTERVAL then return false end
    self._accumulator = 0

    local discovered = Loader.discoverChunks(self.modRoot)
    local seen = {}
    local changed = false

    for _, raw in ipairs(discovered) do
        seen[raw.fsPath] = true
        if not self._byPath[raw.fsPath] then
            local entry = self:_loadEntry(raw.faction, raw.file, raw.fsPath)
            self._byPath[entry.fsPath] = entry
            changed = true
        end
    end

    for path in pairs(self._byPath) do
        if not seen[path] then
            self._byPath[path] = nil
            changed = true
        end
    end

    if changed then
        local list = {}
        for _, e in pairs(self._byPath) do table.insert(list, e) end
        sortEntries(list)
        replaceInPlace(self.entries, list)
    end
    return changed
end

--- Drop and reload a single entry by path. Use when the editor itself
--- writes a chunk file and wants the cache to reflect the new content
--- without waiting for the next poll.
---@param fsPath string
function M:invalidate(fsPath)
    local existing = self._byPath[fsPath]
    if not existing then return end
    local fresh = self:_loadEntry(existing.faction, existing.file, fsPath)
    self._byPath[fsPath] = fresh
    for i, e in ipairs(self.entries) do
        if e.fsPath == fsPath then
            self.entries[i] = fresh
            return
        end
    end
end

return M
