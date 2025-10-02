-- upvalue scope for performance
local TableInsert = table.insert
local TableSetn = table.setn
local TableGetn = table.getn

--- Optimized version to determine if array section of the table contains a specific entry.
---@param t table
---@param entry any
---@return boolean
ArrayContains = function(t, entry)
    for k = 1, TableGetn(t) do
        if t[k] == entry then
            return true
        end
    end

    return false
end
