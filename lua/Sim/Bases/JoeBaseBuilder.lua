local PlatoonBuilderUtils = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonUtils.lua")
local PlatoonBuilderModule = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBuilder.lua")

local ReclaimUtils = import("/mods/fa-joe-ai/lua/sim/ReclaimUtils.lua")
local EntityUtils = import("/mods/fa-joe-ai/lua/Sim/Utils/EntityUtils.lua")
local JoeBase = import("/mods/fa-joe-ai/lua/Sim/Bases/JoeBase.lua").JoeBase

local TableGetn = table.getn
local TableSetn = table.setn

local TableInsert = table.insert
local TableRemove = table.remove
--- Builder pattern to interact with a base.
---@class JoeBaseBuilder
---@field Base JoeBase
JoeBaseBuilder = ClassSimple {

    ---@param self JoeBaseBuilder
    ---@param base JoeBase
    __init = function(self, base)
        self.Base = base
    end,

    --- Routes each unit to the right base bucket using the same split as `JoeBrain:OnUnitStopBeingBuilt`:
    ---   * **Structure** → `JoeBase:AssignStructure` (StructureManager).
    ---   * **Engineer** → `JoeBase:AssignEngineer` (IdleBehavior platoon, `Unassigned` squad).
    ---   * **Other mobile unit** → currently dropped into the IdleBehavior platoon as a fallback so manual assignments (the debug callbacks call this) don't silently lose units. The brain's parallel dispatch is a no-op TODO; once that's decided, both sites converge on the same policy.
    ---@param self JoeBaseBuilder
    ---@param units JoeUnit[]
    ---@return JoeBaseBuilder
    AssignUnits = function(self, units)
        local base = self.Base
        local brain = base.Brain

        -- add all units to the idle behavior by default, the base can pick it up from there
        brain:AssignUnitsToPlatoon(base.IdleBehavior, units, "Unassigned", "None")

        -- let all units know that they are assigned
        for k = 1, table.getn(units) do
            local unit = units[k]
            unit:OnAssignedToBase(base)
        end

        return self
    end,

    ---@param self JoeBaseBuilder
    ---@return JoeBase
    End = function(self)
        return self.Base
    end,
}

--- Wraps a builder around a base from a set of units and a location.
---@param brain JoeBrain
---@param location Vector
---@return JoeBaseBuilder
Build = function(brain, location)
    local base = JoeBase(brain, location)
    base.Brain:AddBase(base)
    return JoeBaseBuilder(base)
end

---@param base JoeBase
---@return JoeBaseBuilder
Extend = function(base)
    return JoeBaseBuilder(base)
end
