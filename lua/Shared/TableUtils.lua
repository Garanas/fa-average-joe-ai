-- upvalue scope for performance
local TableInsert = table.insert
local TableSetn = table.setn
local TableGetn = table.getn

--- Metatable to indicate that the value references to tables should not be taken into account by the garbage collection.
WeakValueTable = {
    __mode = "v"
}

--- Metatable to indicate that the key references to tables should not be taken into account by the garbage collection.
WeakKeyTable = {
    __mode = "k"
}

--- Metatable to indicate that the keys and values references to tables should not be taken into account by the garbage collection.
WeakTable = {
    __mode = "kv"
}

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
