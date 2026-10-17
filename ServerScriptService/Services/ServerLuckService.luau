--!strict
-- Live-server Server Luck (0..100). Grows as builds complete (amount per rarity in
-- RarityConfig.ServerLuckGain) and is never persisted: it dies with the server.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)

local ServerLuckService = {}
local S: any
local luck = 0
local MAX = EconomyConfig.ServerLuck.Max

function ServerLuckService.Init(registry)
	S = registry
end

local function publishState()
	local st = EconomyConfig.ServerState(luck)
	S.StateService.Set("ServerState", st.Id)
	S.StateService.Set("ServerStateName", st.Name)
end

function ServerLuckService.Start()
	S.StateService.Set("ServerLuck", luck)
	publishState()
end

-- Current named state ("Fresh Site" ... "Legendary Site").
function ServerLuckService.State(): any
	return (EconomyConfig.ServerState(luck))
end

-- Small secondary perk multiplier of the current state (1 = none). See EconomyConfig.ServerStates.
function ServerLuckService.Perk(name: string): number
	local st = EconomyConfig.ServerState(luck)
	return st.Perks[name] or 1
end

function ServerLuckService.Get(): number
	return luck
end

function ServerLuckService.Set(value: number)
	luck = math.clamp(value, 0, MAX)
	-- (a tier-up is presented by each client's AmbienceController when ServerState changes: banner, chime, world pulse)
	S.StateService.Set("ServerLuck", math.floor(luck * 10 + 0.5) / 10)
	publishState()
end

-- BALANCE v0.1: every completed build gives a flat EconomyConfig.ServerLuck.GainPerBuild, capped at Max.
-- (`rarityId` is kept for callers/telemetry; the gain no longer depends on it.)
function ServerLuckService.AddForRarity(_rarityId: string): number
	local before = luck
	ServerLuckService.Set(luck + EconomyConfig.ServerLuck.GainPerBuild)
	return luck - before
end

return ServerLuckService
