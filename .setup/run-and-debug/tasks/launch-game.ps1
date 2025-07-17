$mapSelection = $env:MAP_SELECTION

# Extract scenario path from "Name - /path"
if ($mapSelection -match " - (.+)$") {
    $mapPath = $matches[1]
} else {
    Write-Host "Invalid map selection format. Expected 'Name - /path'."
    exit 1
}

# Path to the game executable
$exePath = "C:\ProgramData\FAForever\bin\ForgedAlliance.exe"

# Build argument list
$args = @(
    "/init", "init_local_development.lua",
    "/nobugreport",
    "/EnableDiskWatch",

    "/log", "C:\ProgramData\FAForever\bin\logs\game.log",
    "/showlog",

    # Seed to use for randomness
    "/seed", "1",

    # Enable cheats
    "/cheats",

    # Indicates to the engine that we want to quickly start a scenario, skipping the lobby.
    "/scenario", $mapPath,

    # Indicates to the startup sequence that we want to observe as a player. You start with the focus army set to a bot.
    "/observe",

    # List of all available (sim) mods. There should be no spaces.
    # Format: "/gamemods", "mod_id:mod_name"

    "/gamemods", "joe-ai-01:AverageJoeAI"

    # Bot configuration. There should be no spaces.
    # Format: "/gameais", "1:ai_name", "2:ai_name"

    "/gameais", "1:joe_ai", "2:joe_ai",

    # Lobby option configuration. There should be no spaces.
    # Format: "/gameoptions", "option_key:option_value"

    "/gameoptions", "PrebuiltUnits:On"
)

Write-Host "Launching map: $mapPath against AI: $aiSelection"
Start-Process -FilePath $exePath -ArgumentList $args
