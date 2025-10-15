
--- A list of all known platoon behaviors.
PlatoonBehaviors = {
    -- debug behavior
    ErrorBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Debug/ErrorBehavior.lua").ErrorBehavior,
    NullBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Debug/NullBehavior.lua").NullBehavior,
    WanderBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Debug/WanderBehavior.lua").WanderBehavior,
    PingPongBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Debug/PingPongBehavior.lua").PingPongBehavior,

    -- engineer behavior
    ReclaimBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Engineers/ReclaimBehavior.lua").ReclaimBehavior,
    BuildBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Engineers/BuildBehavior.lua").BuildBehavior,

    -- base behavior
    Base = {
        IdleBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/Base/IdleBehavior.lua").BaseIdleBehavior
    }
}