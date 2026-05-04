-- Native open/save file dialogs via PowerShell. Windows-only for now —
-- returns nil on other platforms (callers fall back to whatever they like).

local M = {}

local IS_WINDOWS = package.config:sub(1, 1) == "\\"

local function tempScriptPath()
    local dir = os.getenv("TEMP") or os.getenv("TMP") or "."
    return dir .. "\\joe-chunk-editor-dialog.ps1"
end

local function runPowerShell(script)
    if not IS_WINDOWS then return nil end
    local path = tempScriptPath()
    local f = io.open(path, "wb")
    if not f then return nil end
    f:write(script)
    f:close()
    local cmd = string.format('powershell -NoProfile -ExecutionPolicy Bypass -File "%s"', path)
    local p = io.popen(cmd)
    if not p then return nil end
    local out = p:read("*a") or ""
    p:close()
    out = out:gsub("[\r\n]+$", "")
    if out == "" then return nil end
    return out
end

---@param defaultDir string?
---@return string?
function M.openFile(defaultDir)
    local initDir = defaultDir and defaultDir:gsub("/", "\\") or ""
    local script = string.format([[
Add-Type -AssemblyName System.Windows.Forms
$d = New-Object System.Windows.Forms.OpenFileDialog
$d.Filter = 'Lua files (*.lua)|*.lua|All files (*.*)|*.*'
$d.InitialDirectory = '%s'
if ($d.ShowDialog() -eq 'OK') { Write-Output $d.FileName }
]], initDir)
    return runPowerShell(script)
end

---@param defaultDir string?
---@param defaultName string?
---@return string?
function M.saveFile(defaultDir, defaultName)
    local initDir = defaultDir and defaultDir:gsub("/", "\\") or ""
    local fname = defaultName or "untitled.lua"
    local script = string.format([[
Add-Type -AssemblyName System.Windows.Forms
$d = New-Object System.Windows.Forms.SaveFileDialog
$d.Filter = 'Lua files (*.lua)|*.lua|All files (*.*)|*.*'
$d.DefaultExt = 'lua'
$d.AddExtension = $true
$d.InitialDirectory = '%s'
$d.FileName = '%s'
if ($d.ShowDialog() -eq 'OK') { Write-Output $d.FileName }
]], initDir, fname)
    return runPowerShell(script)
end

return M
