local M = {}

local IS_WINDOWS = package.config:sub(1, 1) == "\\"

local function getUpvalue(fn, name)
    local i = 1
    while true do
        local n, v = debug.getupvalue(fn, i)
        if not n then return nil end
        if n == name then return v end
        i = i + 1
    end
end

local function readAll(path)
    local f, err = io.open(path, "rb")
    if not f then return nil, err end
    local data = f:read("*a")
    f:close()
    return data
end

-- MapToEntityCategories is a `local` in JoeBuildingIdentifiers.lua; pull it
-- through the closure of MapToMetadata, the global function that closes over it.
function M.loadIdentifiers(shim)
    local idEnv = shim.import("/mods/fa-joe-ai/lua/Shared/BaseChunks/JoeBuildingIdentifiers.lua")
    local metadata = getUpvalue(idEnv.MapToMetadata, "MapToEntityCategories")
    if not metadata then
        error("loader: could not extract MapToEntityCategories")
    end
    return metadata
end

local function listSubdirectories(path)
    local out = {}
    local cmd
    if IS_WINDOWS then
        cmd = string.format('dir /ad /b "%s" 2>nul', (path:gsub("/", "\\")))
    else
        cmd = string.format('ls -d "%s"/*/ 2>/dev/null', path)
    end
    local p = io.popen(cmd)
    if not p then return out end
    for line in p:lines() do
        line = line:gsub("[\r\n]+$", "")
        local name = line:match("([^/\\]+)/?$")
        if name and name ~= "" and name ~= "." and name ~= ".." then
            table.insert(out, name)
        end
    end
    p:close()
    return out
end

local function listLuaFiles(path)
    local out = {}
    local cmd
    if IS_WINDOWS then
        cmd = string.format('dir /b "%s\\*.lua" 2>nul', (path:gsub("/", "\\")))
    else
        cmd = string.format('ls -1 "%s"/*.lua 2>/dev/null', path)
    end
    local p = io.popen(cmd)
    if not p then return out end
    for line in p:lines() do
        line = line:gsub("[\r\n]+$", "")
        local name = line:match("([^/\\]+%.lua)$")
        if name then table.insert(out, name) end
    end
    p:close()
    return out
end

function M.discoverChunks(modRoot)
    local base = modRoot .. "/lua/Shared/BaseChunks"
    local out = {}
    for _, fac in ipairs(listSubdirectories(base)) do
        local subPath = base .. "/" .. fac
        for _, file in ipairs(listLuaFiles(subPath)) do
            table.insert(out, {
                faction = fac,
                file = file,
                fsPath = subPath .. "/" .. file,
            })
        end
    end
    table.sort(out, function(a, b)
        if a.faction ~= b.faction then return a.faction < b.faction end
        return a.file < b.file
    end)
    return out
end

function M.loadChunk(shim, fsPath)
    local source, err = readAll(fsPath)
    if not source then return nil, err end
    local chunk, loadErr = loadstring(source, fsPath)
    if not chunk then return nil, loadErr end
    local env = setmetatable({}, { __index = shim.env })
    setfenv(chunk, env)
    local ok, runErr = pcall(chunk)
    if not ok then return nil, runErr end
    if type(env.Template) ~= "table" then
        return nil, "no Template global in " .. fsPath
    end
    return env.Template
end

return M
