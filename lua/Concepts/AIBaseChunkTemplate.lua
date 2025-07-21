local TableGetn = table.getn
local TableEmpty = table.empty
local TableInsert = table.insert
local TableConcat = table.concat

local MathFloor = math.floor
local MathMin = math.min
local MathMax = math.max

local StringFormat = string.format

---@class AIBaseChunkLocation
---@field OffsetX number
---@field OffsetY number

--- A chunk of a base. Describes various locations for specific units.
---@class AIBaseChunkTemplate
--- All the units (read: structures) that are part of this chunk. This list exists to make it easier to interact with entity (unit) functions.
---@field Units UnitId[]
---@field Size number
---@field Locations table<UnitId, AIBaseChunkLocation>

---@param n number
---@param size number
---@return integer
function ToChunkCoordinates(n, size)
    return MathFloor(n / size)
end

--- Get all (non-unique) unit ids of a list of (user) units.
---@param units UserUnit[]
---@return UnitId[]
local function GetUniqueUnitIds(units)
    local unitIds = {}

    ---@param unit UserUnit
    for _, unit in units do
        local unitId = unit:GetUnitId()
        TableInsert(unitIds, unitId)
    end

    return unitIds
end

--- Get all build offsets of a list of (user) units.
---@param units UserUnit[]
---@param size number
---@return table<UnitId, AIBaseChunkLocation>
local function GetLocations(units, size)
    local locations = {}

    ---@param unit UserUnit
    for _, unit in units do
        local unitId = unit:GetUnitId()
        local blueprintPhysics = unit:GetBlueprint().Physics
        local position = unit:GetPosition()

        ---@type AIBaseChunkLocation
        local location = {
            OffsetX = position[1] - ToChunkCoordinates(position[1], size) * size,
            OffsetY = position[3] - ToChunkCoordinates(position[3], size) * size
        }

        locations[unitId] = locations[unitId] or {}
        TableInsert(locations[unitId], location)
    end

    return locations
end

--- Creates an a base chunk template that is used by AIs.
---@param units UserUnit[]
---@param size number
---@return AIBaseChunkTemplate
function CreateTemplate(units, size)

    -- defensive programming
    if size < 1 or size > 256 then
        error(string.format("Size should be between 1 and 256, but is %s", tostring(size)))
    end

    ---@type AIBaseChunkTemplate
    local template = {
        Size = size,
        Units = GetUniqueUnitIds(units),
        Locations = GetLocations(units, size),
    }

    return template;
end

-------------------------------------------------------------------------------
--#region Debug functionality

-- Functionality that is related to debugging.

--- Transforms a base chunk template into a build template that we all know and love.
---@param template AIBaseChunkTemplate
---@return UIBuildTemplate
function ToBuildTemplate(template)

    ---@type UIBuildTemplate
    local buildTemplate = {
        template.Size,
        template.Size,
    }

    local buildOrder = 1

    ---@param unitId UnitId
    ---@param locations AIBaseChunkLocation[]
    for unitId, locations in template.Locations do
        ---@param location AIBaseChunkLocation
        for _, location in locations do
            buildOrder = buildOrder + 1
            TableInsert(buildTemplate, { unitId, buildOrder, location.OffsetX, location.OffsetY })
        end
    end

    return buildTemplate
end

--- Creates a build template of the base chunk template that snaps to the size of the base chunk template.
---@param template AIBaseChunkTemplate
local PreviewTemplateThread = function(template)
    local commandModeModule = import("/lua/ui/game/commandmode.lua")

    -- determine offset that engine applies to build previews of templates
    local largestSkirtSize = -1000
    for _, unitId in template.Units do
        local blueprint = __blueprints[unitId]

        local skirtSizeX = blueprint.Physics.SkirtSizeX
        local skirtSizeZ = blueprint.Physics.SkirtSizeZ
        largestSkirtSize = math.max(largestSkirtSize, skirtSizeX, skirtSizeZ)
    end

    local offset = MathFloor(0.25 * largestSkirtSize)

    repeat
        -- create the build template
        local buildTemplate = ToBuildTemplate(template)

        -- adjust the offset of the build template to match the size
        local templateSize = template.Size
        local mouseWorldCoordinates = GetMouseWorldPos()
        local dx = mouseWorldCoordinates[1] - ToChunkCoordinates(mouseWorldCoordinates[1], templateSize) * templateSize
        local dy = mouseWorldCoordinates[3] - ToChunkCoordinates(mouseWorldCoordinates[3], templateSize) * templateSize

        for k = 3, TableGetn(buildTemplate) do
            local entry = buildTemplate[k]
            entry[3] = entry[3] - dx + offset
            entry[4] = entry[4] - dy + offset
        end

        -- start the command mode
        commandModeModule.StartCommandMode("build", { name = buildTemplate[3][1] })
        SetActiveBuildTemplate(buildTemplate)
        WaitFrames(1)
    until not commandModeModule.InCommandMode()

    -- at the end of it, clear the build template so that it does not persist
    ClearBuildTemplates()
end

--- Starts the command mode using the giving base chunk template. The template snaps to the template size.
---@param template AIBaseChunkTemplate
function PreviewTemplate(template)
    ForkThread(PreviewTemplateThread, template)
end

--- Stringifies a template to a Lua-compatible table that you can paste into a file.
---@param template AIBaseChunkTemplate
function StringifyTemplate(template)

    local lines = {}

    TableInsert(lines, "Template = {\r\n")
    TableInsert(lines, StringFormat("  Size = %d,\r\n", tostring(template.Size)))

    do
        TableInsert(lines, StringFormat("  Units = {\r\n", tostring(template.Size)))
        ---@param unit UnitId
        for _, unit in template.Units do
            TableInsert(lines, StringFormat("    \"%s\",\r\n", tostring(unit)))
        end
        TableInsert(lines, "  },\r\n")
    end

    do
        TableInsert(lines, StringFormat("  Locations = {\r\n", tostring(template.Size)))
        ---@param unitId UnitId
        ---@param locations AIBaseChunkLocation[]
        for unitId, locations in template.Locations do
            TableInsert(lines, StringFormat("    [\'%s\'] = {\r\n", tostring(unitId)))
            for _, building in locations do
                TableInsert(lines, StringFormat("      { OffsetX = %d, OffsetY = %d },\r\n", building.OffsetX, building.OffsetY))
            end

            TableInsert(lines, "    },\r\n")
        end
        TableInsert(lines, "  },\r\n")
    end

    TableInsert(lines, "}\r\n")

    return TableConcat(lines, "")
end
