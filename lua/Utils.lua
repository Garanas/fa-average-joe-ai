local TableGetn = table.getn
local TableEmpty = table.empty
local TableInsert = table.insert
local TableConcat = table.concat

local StringFormat = string.format
local StringLen = string.len

--- Tables whose compact form is at most this many characters are written on a single line; longer ones expand across multiple lines.
local MaxInlineLength = 80

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

--- Determines whether a value is a valid Lua identifier (i.e. a string usable as an unquoted table key).
---@param str any
---@return string?
local function IsIdentifier(str)
    return type(str) == "string" and string.match(str, "^[A-Za-z_][A-Za-z0-9_]*$") or nil
end

--- Recursively converts a table to a Lua-compatible string. Tables whose compact form fits within `MaxInlineLength` are inlined on a single line; longer tables expand across multiple lines.
---@param tbl table
---@param indent? string
---@return string
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
    local serialized = TableConcat(lines, "")

    -- attempt to inline it
    if (STR_Utf8Len(serialized) <= MaxInlineLength) then
        local inlined = serialized:gsub("%s+", " ")
        return inlined
    else
        return serialized
    end
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
