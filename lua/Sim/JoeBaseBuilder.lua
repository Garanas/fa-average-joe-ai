local ReclaimUtils = import("/mods/fa-joe-ai/lua/sim/ReclaimUtils.lua")
local EntityUtils = import("/mods/fa-joe-ai/lua/sim/EntityUtils.lua")
local JoeBase = import("/mods/fa-joe-ai/lua/Sim/JoeBase.lua").JoeBase

local TableGetn = table.getn
local TableSetn = table.setn
local TableInsert = table.insert

--- Builder pattern to interact with a base.
---@class JoeBaseBuilder
---@field Base JoeBase
JoeBaseBuilder = ClassSimple {

    ---@param self JoeBaseBuilder
    ---@param base JoeBase
    __init = function(self, base)
        self.Base = base
    end,

    AddUnits = function(self, units)

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
    return JoeBaseBuilder(base)
end

---@param base JoeBrain
---@return JoeBaseBuilder
Extend = function(base)
    return JoeBaseBuilder(base)
end
