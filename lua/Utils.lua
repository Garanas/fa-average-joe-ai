local TableGetn = table.getn
local TableEmpty = table.empty
local TableInsert = table.insert
local TableConcat = table.concat

local StringFormat = string.format

--- Escapes a string for valid Lua syntax
---@param str string
---@return string
local function EscapeString(str)
    str = string.gsub(str, "\\", "\\\\")
    str = string.gsub(str, "\"", "\\\"")
    str = string.gsub(str, "\n", "\\n")
    str = string.gsub(str, "\r", "\\r")
    return "\"" .. str .. "\""
end

--- Determines whether a key is a valid Lua identifier
---@param str string
---@return string
local function IsIdentifier(str)
    return type(str) == "string" and string.match(str, "^[A-Za-z_][A-Za-z0-9_]*$")
end

--- Recursively converts a table to a Lua-compatible string.
--- @param tbl table
--- @param indent string
--- @return string
function SerializeTable(tbl, indent)
    indent = indent or ""
    local lines = {}
    TableInsert(lines, "{\r\n")

    local innerIndent = indent .. "  "

    -- First serialize array part
    for i = 1, TableGetn(tbl) do
        local v = tbl[i]
        local value = SerializeValue(v, innerIndent)
        TableInsert(lines, StringFormat("%s%s,\r\n", innerIndent, value))
    end

    -- Then serialize hash part
    for k, v in pairs(tbl) do
        if type(k) ~= "number" or k < 1 or k > TableGetn(tbl) then
            local key
            if IsIdentifier(k) then
                key = k
            else
                key = "[" .. EscapeString(tostring(k)) .. "]"
            end
            local value = SerializeValue(v, innerIndent)
            TableInsert(lines, StringFormat("%s%s = %s,\r\n", innerIndent, key, value))
        end
    end

    TableInsert(lines, indent .. "}")
    return TableConcat(lines, "")
end

--- Serializes any Lua value into a Lua-compatible string.
--- @param val any
--- @param indent? string
function SerializeValue(val, indent)
    indent = indent or ""

    local t = type(val)
    if t == "string" then
        return EscapeString(val)
    elseif t == "number" or t == "boolean" then
        return tostring(val)
    elseif t == "table" then
        return SerializeTable(val, indent)
    else
        return "\"<unsupported:" .. t .. ">\""
    end
end
