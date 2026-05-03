-- Stand-in for the Supreme Commander engine globals that the mod's shared
-- modules touch at file-load time. The editor only reads identifier metadata
-- (Color, SizeX, SizeZ); the rest is no-op.

local M = {}

-- Any field access, multiplication, or addition on the result returns itself.
-- Lets `categories.STRUCTURE * categories.WALL` evaluate without exploding.
local function blackHole()
    local t = {}
    local mt = {}
    mt.__index = function() return t end
    mt.__mul = function() return t end
    mt.__add = function() return t end
    setmetatable(t, mt)
    return t
end

local function readAll(path)
    local f, err = io.open(path, "rb")
    if not f then return nil, err end
    local data = f:read("*a")
    f:close()
    return data
end

function M.create(modRoot)
    local cache = {}
    local env

    local function resolve(modPath)
        local prefix = "/mods/fa-joe-ai/"
        if modPath:sub(1, #prefix) == prefix then
            return modRoot .. "/" .. modPath:sub(#prefix + 1)
        end
        error("shim: cannot resolve path " .. tostring(modPath))
    end

    local function importFn(modPath)
        if cache[modPath] then return cache[modPath] end
        local fsPath = resolve(modPath)
        local source, readErr = readAll(fsPath)
        if not source then
            error("shim: read failed for " .. fsPath .. ": " .. tostring(readErr))
        end
        local chunk, loadErr = loadstring(source, fsPath)
        if not chunk then
            error("shim: load failed for " .. fsPath .. ": " .. tostring(loadErr))
        end
        local fileEnv = setmetatable({}, { __index = env })
        setfenv(chunk, fileEnv)
        chunk()
        cache[modPath] = fileEnv
        return fileEnv
    end

    env = setmetatable({
        categories = blackHole(),
        import = importFn,
        WARN = function() end,
        LOG = function() end,
        SPEW = function() end,
        EntityCategoryGetUnitList = function() return {} end,
        EntityCategoryContains = function() return false end,
    }, { __index = _G })

    return {
        env = env,
        import = importFn,
        modRoot = modRoot,
    }
end

return M
