local TableInsert = table.insert
local TableGetn = table.getn
local TableRemove = table.remove

local IsDestroyed = IsDestroyed

local JoeBuildingIdentifierModule = import("/mods/fa-joe-ai/lua/Shared/BaseChunks/JoeBuildingIdentifiers.lua")

--- Per-base storage of finished structures owned by this base. Pure storage — `JoeBase` coordinates the assignment (calling `OnAssignedToBase` so the unit's `JoeData.Base` mirror stays in sync) and any future cross-component side-effects (build-site state, queue-completion mirroring).
---
--- Today this is a flat list. Likely future evolution: index by `JoeBuildingIdentifier` for cheap lookups (e.g. "all my T1 mexes"), and an `OnDestroy` hook to auto-remove on death. Both are deferred — the v1 contract is "the base knows which structures are assigned to it."
---@class JoeBaseStructureManagerComponent
---@field Base JoeBase
---@field Structures JoeUnit[]
JoeBaseStructureManagerComponent = ClassSimple {

    ---@param self JoeBaseStructureManagerComponent
    ---@param base JoeBase
    __init = function(self, base)
        self.Base = base
        self.Structures = {}
    end,

    --- Adds `structure` to the list. Pure storage; the caller (`JoeBase:AssignStructure`) handles the `OnAssignedToBase` mirror.
    ---@param self JoeBaseStructureManagerComponent
    ---@param structure JoeUnit
    AddStructure = function(self, structure)
        TableInsert(self.Structures, structure)
    end,

    --- Removes `structure`. Linear scan. Returns true if a removal happened.
    ---@param self JoeBaseStructureManagerComponent
    ---@param structure JoeUnit
    ---@return boolean
    RemoveStructure = function(self, structure)
        local structures = self.Structures
        for k = 1, TableGetn(structures) do
            if structures[k] == structure then
                TableRemove(structures, k)
                return true
            end
        end
        return false
    end,

    --- Predicate: is `structure` registered with this base?
    ---@param self JoeBaseStructureManagerComponent
    ---@param structure JoeUnit
    ---@return boolean
    Has = function(self, structure)
        local structures = self.Structures
        for k = 1, TableGetn(structures) do
            if structures[k] == structure then
                return true
            end
        end
        return false
    end,

    -----------------------------------------------------------------------------
    --#region Debug logging

    --- Dumps the list to the log, one line per structure with its identifier and destroyed flag, prefixed with the base id via `JoeBase:Log`. Cheap to call ad-hoc; not cheap enough to call per tick.
    ---@param self JoeBaseStructureManagerComponent
    LogState = function(self)
        local base = self.Base
        local structures = self.Structures
        local n = TableGetn(structures)
        base:Log(string.format("StructureManager: structures=%d", n))
        for k = 1, n do
            local structure = structures[k]
            local destroyed = IsDestroyed(structure)
            local identifier = "?"
            if not destroyed then
                identifier = tostring(JoeBuildingIdentifierModule.MapToIdentifier(structure:GetUnitId()))
            end
            base:Log(string.format("  structure[%d] id=%s destroyed=%s",
                k, identifier, tostring(destroyed)))
        end
    end,

    --#endregion
}
