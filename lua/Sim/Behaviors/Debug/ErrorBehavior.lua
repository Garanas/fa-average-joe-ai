local AIPlatoonBehavior = import("/mods/fa-joe-ai/lua/Sim/Behaviors/PlatoonBehavior.lua").AIPlatoonBehavior

--- A behavior used for debugging, testing and development.
---@class AIErrorBehavior : AIPlatoonBehavior
ErrorBehavior = Class(AIPlatoonBehavior) {
    BehaviorName = 'ErrorBehavior',
}
