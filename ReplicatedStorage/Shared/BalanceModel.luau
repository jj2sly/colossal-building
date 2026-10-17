--!strict
-- Analytic gathering model used by the dev balance tools. It mirrors the real rules (carry
-- capacity, travel speed, spot bonuses, gather times) so a trip can be estimated for any
-- player profile WITHOUT playing for hours; the live telemetry then checks the model.
-- Nothing in gameplay reads this module.
local Config = script.Parent.Config
local ResourceConfig = require(Config.ResourceConfig)
local ResourceSpotConfig = require(Config.ResourceSpotConfig)
local UpgradeConfig = require(Config.UpgradeConfig)
local VehicleConfig = require(Config.VehicleConfig)
local WorkerConfig = require(Config.WorkerConfig)
local TrainingConfig = require(Config.TrainingConfig)
local Formulas = require(script.Parent.Formulas)

local BalanceModel = {}

-- Time costs the formula can't see: per-gather prompt latency, turning around, walking to the node.
BalanceModel.GatherOverhead = 0.25 -- seconds per gather action (prompt press + latency)
BalanceModel.TurnaroundOverhead = 2.0 -- seconds of dithering per trip (node pick, ring entry)
BalanceModel.DepositBaseRate = 45 -- units/sec at Deposit Speed x1 (DepositService.BASE_RATE)

export type Profile = {
	Strength: number, -- training level
	Speed: number, -- training level
	Vehicle: string?,
	GatherLevel: number?, -- upgrade levels
	DepositLevel: number?,
	VehicleCapLevel: number?,
}

function BalanceModel.Capacity(p: Profile): number
	local base = Formulas.BaseCarry(TrainingConfig.PointsFor("Strength", p.Strength))
	return Formulas.CarryCapacity(base, p.Vehicle, p.VehicleCapLevel or 0, 1)
end

function BalanceModel.TravelSpeed(p: Profile): number
	local trained = Formulas.BaseSpeed(TrainingConfig.PointsFor("Speed", p.Speed))
	if p.Vehicle then
		return Formulas.VehicleSpeed(p.Vehicle, trained)
	end
	return trained
end

export type Trip = { Capacity: number, TravelSeconds: number, GatherSeconds: number, DepositSeconds: number, CycleSeconds: number, UnitsPerMin: number, CoinsPerMin: number }

-- One full gather-and-deliver cycle at a spot for a player profile.
function BalanceModel.Trip(p: Profile, spot: ResourceSpotConfig.Spot): Trip
	local res = ResourceConfig.Resources[spot.Resource]
	local cap = BalanceModel.Capacity(p)
	local speed = BalanceModel.TravelSpeed(p)
	local gatherMult = UpgradeConfig.Value("GatherSpeed", p.GatherLevel or 0) * spot.GatherSpeedMultiplier
	local depositMult = UpgradeConfig.Value("DepositSpeed", p.DepositLevel or 0)
	local actions = math.ceil(cap / res.YieldPerGather)
	local gather = actions * (res.GatherTime / gatherMult + BalanceModel.GatherOverhead)
	local travel = 2 * ResourceSpotConfig.DistanceFromRing(spot) / speed
	local deposit = cap / (BalanceModel.DepositBaseRate * depositMult)
	local cycle = travel + gather + deposit + BalanceModel.TurnaroundOverhead
	-- units that reach the build per minute, counting spot richness (YieldMultiplier) as extra value
	local unitsPerMin = cap * spot.YieldMultiplier / cycle * 60
	return { Capacity = cap, TravelSeconds = travel, GatherSeconds = gather, DepositSeconds = deposit, CycleSeconds = cycle, UnitsPerMin = unitsPerMin, CoinsPerMin = unitsPerMin * res.CoinsPerUnit }
end

-- Worker throughput at a spot for a given Worker Efficiency level (workers use the beginner spot).
function BalanceModel.Worker(efficiencyLevel: number, resourceId: string): (number, number)
	local def = WorkerConfig.Types[WorkerConfig.DefaultType]
	local spot = ResourceSpotConfig.Primary(resourceId)
	local carry, speed, gather = Formulas.WorkerStats(def, UpgradeConfig.Value("WorkerEfficiency", efficiencyLevel))
	if not spot then
		return 0, 0
	end
	local cycle = 2 * ResourceSpotConfig.DistanceFromRing(spot) / speed + gather + def.DepositTime
	local perMin = carry / cycle * 60
	return perMin, perMin * ResourceConfig.Resources[resourceId].CoinsPerUnit
end

-- XP needed in total to reach a training level.
function BalanceModel.XPForLevel(statId: string, level: number): number
	return TrainingConfig.PointsFor(statId, level)
end

BalanceModel.Archetypes = {
	{ Name = "New (Str0 Spd0, no vehicle)", Profile = { Strength = 0, Speed = 0 } :: Profile },
	{ Name = "Early (Str5 Spd5 Wheelbarrow)", Profile = { Strength = 5, Speed = 5, Vehicle = "Wheelbarrow", GatherLevel = 2 } :: Profile },
	{ Name = "Active (Str10 Spd10, no vehicle)", Profile = { Strength = 10, Speed = 10, GatherLevel = 4, DepositLevel = 3 } :: Profile },
	{ Name = "Mid (Str10 Spd10 Utility Cart)", Profile = { Strength = 10, Speed = 10, Vehicle = "UtilityCart", GatherLevel = 5, DepositLevel = 4, VehicleCapLevel = 3 } :: Profile },
	{ Name = "Fast runner (Str5 Spd25, no vehicle)", Profile = { Strength = 5, Speed = 25, GatherLevel = 5, DepositLevel = 4 } :: Profile },
	{ Name = "Late (Str20 Spd20 Pickup)", Profile = { Strength = 20, Speed = 20, Vehicle = "Pickup", GatherLevel = 8, DepositLevel = 6, VehicleCapLevel = 6 } :: Profile },
	{ Name = "Hauler (Str20 Spd20 Dump Truck)", Profile = { Strength = 20, Speed = 20, Vehicle = "DumpTruck", GatherLevel = 8, DepositLevel = 6, VehicleCapLevel = 6 } :: Profile },
	{ Name = "Max (Str25 Spd25 Dump Truck)", Profile = { Strength = 25, Speed = 25, Vehicle = "DumpTruck", GatherLevel = 15, DepositLevel = 15, VehicleCapLevel = 15 } :: Profile },
}

-- Multi-line text table: units/min and coins/min per archetype for every spot of one resource.
function BalanceModel.Table(resourceId: string): string
	local lines = {}
	local spots = ResourceSpotConfig.ListFamily(resourceId)
	local header = string.format("%-38s", resourceId)
	for _, sp in spots do
		header ..= string.format(" | %-22s", sp.DisplayName .. " T" .. sp.Tier)
	end
	table.insert(lines, header)
	for _, a in BalanceModel.Archetypes do
		local row = string.format("%-38s", a.Name)
		local near: Trip? = nil
		for i, sp in spots do
			local t = BalanceModel.Trip(a.Profile, sp)
			if i == 1 then
				near = t
				row ..= string.format(" | %5.0f u/m %5.0f c/m   ", t.UnitsPerMin, t.CoinsPerMin)
			else
				row ..= string.format(" | %5.0f u/m %+4.0f%% far   ", t.UnitsPerMin, ((t.UnitsPerMin / (near :: Trip).UnitsPerMin) - 1) * 100)
			end
		end
		table.insert(lines, row)
	end
	return table.concat(lines, "\n")
end

return BalanceModel
