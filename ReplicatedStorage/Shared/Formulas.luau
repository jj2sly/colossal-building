--!strict
-- Shared formulas so server logic and client UI always agree. No state lives here.
local Config = script.Parent.Config
local GameConfig = require(Config.GameConfig)
local RarityConfig = require(Config.RarityConfig)
local ModifierConfig = require(Config.ModifierConfig)
local EconomyConfig = require(Config.EconomyConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local VehicleConfig = require(Config.VehicleConfig)
local TrainingConfig = require(Config.TrainingConfig)

local Formulas = {}

-- Personal Luck influence on server rarity is capped: the AVERAGE luck of players
-- present counts as at most this many Server Luck points, so one rich player can't
-- force rare builds.
Formulas.PersonalLuckInfluenceCap = 10

-- Server rarity luck = Server Luck + a diminishing, hard-capped contribution from the AVERAGE
-- personal Luck of the players present (never more than +10 whatever the server size or Luck).
function Formulas.EffectiveLuck(serverLuck: number, avgPersonalLuck: number): number
	local personal = Formulas.PersonalLuckInfluenceCap * (1 - math.exp(-math.max(0, avgPersonalLuck) / 20))
	return math.clamp(serverLuck + personal, 0, 100)
end

-- Rarity probabilities over the given candidate rarities (those that have builds).
function Formulas.RarityWeights(luck: number, candidates: { [string]: boolean }?): { { id: string, weight: number } }
	local out = {}
	local table_ = RarityConfig.WeightsAt(luck)
	for _, id in RarityConfig.Order do
		if candidates == nil or candidates[id] then
			table.insert(out, { id = id, weight = table_[id] or 0 })
		end
	end
	return out
end

function Formulas.ModifierChance(modifierId: string, serverLuck: number): number
	local m = ModifierConfig.Modifiers[modifierId]
	if not m or not m.Enabled then
		return 0
	end
	return math.min(m.MaxChance, m.BaseChance + m.ChancePerLuck * serverLuck)
end

-- Requirement scale for the number of active players (dev multiplier only in Studio).
function Formulas.RequirementScale(activePlayers: number): number
	local s = GameConfig.PlayerScaling
	local scale = math.clamp(activePlayers / s.ReferencePlayers, s.MinScale, s.MaxScale)
	if GameConfig.IsDev() then
		scale *= GameConfig.Dev.RequirementMultiplier
	end
	return scale
end

function Formulas.FriendBonus(friendCount: number): number
	local f = EconomyConfig.Friends
	return math.min(f.MaxBonus, friendCount * f.BonusPerFriend)
end

-- Base carry capacity from Strength training points.
function Formulas.BaseCarry(strengthPoints: number): number
	return TrainingConfig.Effect("Strength", TrainingConfig.Level("Strength", strengthPoints))
end

-- Base walk speed from Speed training points (before vehicles).
function Formulas.BaseSpeed(speedPoints: number): number
	return TrainingConfig.Effect("Speed", TrainingConfig.Level("Speed", speedPoints))
end

-- Total carry capacity: Strength base x vehicle cargo multiplier x Vehicle Capacity upgrade x event multiplier.
function Formulas.CarryCapacity(baseCarry: number, vehicleId: string?, vehicleCapLevel: number, eventMultiplier: number): number
	local base = baseCarry
	local v = vehicleId and VehicleConfig.Vehicles[vehicleId]
	if v then
		base = base * v.CargoMultiplier * UpgradeConfig.Value("VehicleCapacity", vehicleCapLevel)
	end
	return math.floor(base * eventMultiplier)
end

-- Walk speed while using a vehicle: the vehicle's own speed plus a share of the player's trained
-- bonus above the 18 stud/s start, so Speed training still matters on a vehicle without making
-- vehicles faster than a maxed runner by default.
function Formulas.VehicleSpeed(vehicleId: string, trainedSpeed: number): number
	local v = VehicleConfig.Vehicles[vehicleId]
	if not v then
		return trainedSpeed
	end
	return v.Speed + (v.SpeedShare or VehicleConfig.SpeedTrainingShare) * math.max(0, trainedSpeed - TrainingConfig.Stats.Speed.Base)
end

-- Worker stats from a base worker type and the owner's Worker Efficiency multiplier. Efficiency
-- is shared between carry, walking and gathering (each gets half of the bonus) so +5% efficiency
-- is roughly +5% x 1.5 throughput.
function Formulas.WorkerStats(def: any, efficiency: number): (number, number, number)
	local f = 1 + (efficiency - 1) * 0.5
	return math.max(1, math.floor(def.CarryAmount * f)), def.MoveSpeed * f, def.GatherTime / f
end

-- Chance of a Lucky Bonus roll for a player with `personalLuck` points: diminishing, capped.
function Formulas.LuckyBonusChance(personalLuck: number): number
	local l = EconomyConfig.LuckyBonus
	return math.min(0.6, l.BaseChance + l.MaxExtraChance * (1 - math.exp(-math.max(0, personalLuck) / l.LuckScale)))
end

return Formulas
