local NavUtils = import("/lua/sim/navutils.lua")

local StandardBrain = import("/lua/aibrain.lua").AIBrain
local StandardBrainOnCreateAI = StandardBrain.OnCreateAI

---@class JoeBrain: AIBrain
---@field GridReclaim AIGridReclaim
---@field GridRecon AIGridRecon
---@field GridPresence AIGridPresence
JoeBrain = Class(StandardBrain) {
    ---@param self JoeBrain
    OnCreateAI = function(self)
        StandardBrainOnCreateAI(self, 'NoPlan')

        NavUtils.Generate()

        -- requires these data structures to understand the game
        self.GridReclaim = import("/lua/ai/gridreclaim.lua").Setup(self)
        self.GridRecon = import("/lua/ai/gridrecon.lua").Setup(self)
        self.GridPresence = import("/lua/ai/gridpresence.lua").Setup(self)
    end,
}
