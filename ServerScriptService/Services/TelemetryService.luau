--!strict
-- DEV-ONLY balance telemetry. Records what players actually earn/deliver/train so the numbers in
-- the config files can be tuned from measurements instead of theory. Only active when
-- GameConfig.IsDev() (Studio with Dev.Enabled); in live servers Record() returns immediately and
-- the report command is rejected by DebugService's authorisation. Nothing here is persisted.
--
--   Record(kind, player, ...)   called by the gameplay services (see call sites)
--   Report(player)              multi-line text for the debug panel
--   Reset(player?)              start a fresh measurement window
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local GameConfig = require(Shared.Config.GameConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local ResourceSpotConfig = require(Shared.Config.ResourceSpotConfig)
local TrainingConfig = require(Shared.Config.TrainingConfig)
local VehicleConfig = require(Shared.Config.VehicleConfig)
local WorkerConfig = require(Shared.Config.WorkerConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local MasterBuilderConfig = require(Shared.Config.MasterBuilderConfig)
local Formulas = require(Shared.Formulas)
local BalanceModel = require(Shared.BalanceModel)

local TelemetryService = {}
local S: any

type SpotStat = { gathered: number, delivered: number, effective: number, cycleSum: number, cycleN: number }
type Tel = {
	t0: number,
	coinsDeposit: number,
	coinsReward: number,
	unitsPlayer: number,
	unitsWorker: number,
	effPlayer: number,
	points: number,
	vehicleUnits: { [string]: number },
	vehicleSeconds: { [string]: number },
	footUnits: number,
	footSeconds: number,
	xp: { [string]: number },
	spots: { [string]: SpotStat },
	lastSpot: string?,
	lastTick: number,
	tripStart: number,
}
type Completion = { rarity: string, modifiers: string, seconds: number, eligible: number, base: number, top: number, avg: number }

local tel: { [Player]: Tel } = {}
local completions: { Completion } = {}

local function enabled(): boolean
	return GameConfig.IsDev()
end

local function fresh(): Tel
	return {
		t0 = os.clock(), coinsDeposit = 0, coinsReward = 0, unitsPlayer = 0, unitsWorker = 0, effPlayer = 0, points = 0,
		vehicleUnits = {}, vehicleSeconds = {}, footUnits = 0, footSeconds = 0, xp = {}, spots = {}, lastSpot = nil, lastTick = 0, tripStart = 0,
	}
end

local function get(player: Player): Tel
	local t = tel[player]
	if not t then
		t = fresh()
		tel[player] = t
	end
	return t
end

local function spotStat(t: Tel, id: string): SpotStat
	local s = t.spots[id]
	if not s then
		s = { gathered = 0, delivered = 0, effective = 0, cycleSum = 0, cycleN = 0 }
		t.spots[id] = s
	end
	return s
end

function TelemetryService.Init(registry)
	S = registry
end

function TelemetryService.Reset(player: Player?)
	if player then
		tel[player] = fresh()
	else
		table.clear(tel)
		table.clear(completions)
	end
end

-- kinds:
--   "Gather"   (player, units, spotId)
--   "Deposit"  (player, carrierUnits, source, coins, points, resId, effectiveUnits)
--   "Train"    (player, statId, xp)
--   "Reward"   (player, coins)
--   "Complete" (nil, def, modifiers, seconds, results)
function TelemetryService.Record(kind: string, player: Player?, a: any?, b: any?, c: any?, d: any?, e: any?, f: any?)
	if not enabled() then
		return
	end
	if kind == "Complete" then
		local def, mods, seconds, results = a, b, c, d
		local eligible, sum, top, n = 0, 0, 0, 0
		for _, r in results do
			if r.Eligible then
				eligible += 1
				sum += r.Coins
				top = math.max(top, r.Coins)
				n += 1
			end
		end
		table.insert(completions, {
			rarity = def.Rarity, modifiers = table.concat(mods, "+"), seconds = seconds, eligible = eligible,
			base = S.RewardService.BasePayout(def, mods), top = top, avg = if n > 0 then sum / n else 0,
		})
		if #completions > 60 then
			table.remove(completions, 1)
		end
		return
	end
	if not player then
		return
	end
	local t = get(player)
	if kind == "Gather" then
		local units, spotId = a :: number, b :: string
		spotStat(t, spotId).gathered += units
		t.lastSpot = spotId
	elseif kind == "Deposit" then
		local units, source, coins, points, resId, eff = a :: number, b :: string, c :: number, d :: number, e :: string, f :: number
		t.coinsDeposit += coins
		t.points += points
		if source == "Worker" then
			t.unitsWorker += units
			return
		end
		t.unitsPlayer += units
		t.effPlayer += eff or units
		local veh = player:GetAttribute("Vehicle")
		if veh then
			t.vehicleUnits[veh] = (t.vehicleUnits[veh] or 0) + units
		else
			t.footUnits += units
		end
		-- trip timing: a delivery is a burst of ticks; the first tick of each burst marks one trip
		local now = os.clock()
		if now - t.lastTick > 3 then
			local spotId = t.lastSpot
			if spotId and t.tripStart > 0 and now - t.tripStart < 400 then
				local s = spotStat(t, spotId)
				s.cycleSum += now - t.tripStart
				s.cycleN += 1
			end
			t.tripStart = now
		end
		t.lastTick = now
		if t.lastSpot then
			local s = spotStat(t, t.lastSpot)
			s.delivered += units
			s.effective += eff or units
		end
	elseif kind == "Train" then
		local statId, xp = a :: string, b :: number
		t.xp[statId] = (t.xp[statId] or 0) + xp
	elseif kind == "Reward" then
		t.coinsReward += a :: number
	end
end

function TelemetryService.Start()
	Players.PlayerRemoving:Connect(function(p)
		tel[p] = nil
	end)
	-- time-at-vehicle accounting for resources/minute per vehicle
	task.spawn(function()
		while true do
			task.wait(2)
			if enabled() then
				for p, t in tel do
					local veh = p:GetAttribute("Vehicle")
					if veh then
						t.vehicleSeconds[veh] = (t.vehicleSeconds[veh] or 0) + 2
					else
						t.footSeconds += 2
					end
				end
			end
		end
	end)
end

------------------------------------------------------------------ report
local function fmt(n: number): string
	if n >= 1000 then
		return string.format("%.1fk", n / 1000)
	end
	return string.format("%.1f", n)
end

local function hours(minutes: number): string
	if minutes ~= minutes or minutes == math.huge then
		return "n/a"
	end
	if minutes < 90 then
		return string.format("%.0f min", minutes)
	end
	return string.format("%.1f h", minutes / 60)
end

function TelemetryService.Report(player: Player): string
	local t = get(player)
	local d = S.PlayerDataService.Get(player)
	local mins = math.max(1 / 6, (os.clock() - t.t0) / 60)
	local lines = {}
	local function add(s: string)
		table.insert(lines, s)
	end
	local coinsMin = (t.coinsDeposit + t.coinsReward) / mins
	local unitsMin = t.unitsPlayer / mins
	add(string.format("== BALANCE v0.1 SESSION REPORT  (%.1f min measured) ==", mins))
	add(string.format("Coins/min %s  (deposit %s/min, completion rewards %s total)", fmt(coinsMin), fmt(t.coinsDeposit / mins), fmt(t.coinsReward)))
	add(string.format("Resources/min: you %s (effective %s)  worker %s  | contribution/min %s", fmt(unitsMin), fmt(t.effPlayer / mins), fmt(t.unitsWorker / mins), fmt(t.points / mins)))
	if t.unitsWorker > 0 and t.unitsPlayer > 0 then
		add(string.format("Worker throughput = %.0f%% of your own (target 25-30%% base, 45-50%% max)", t.unitsWorker / t.unitsPlayer * 100))
	end
	local footRate = if t.footSeconds > 20 then t.footUnits / (t.footSeconds / 60) else nil
	add("Delivery rate on foot: " .. (if footRate then fmt(footRate) .. " u/min" else "(not enough on-foot time)"))
	for id, secs in t.vehicleSeconds do
		if secs > 20 then
			add(string.format("Delivery rate with %s: %s u/min  (%d s equipped)", id, fmt((t.vehicleUnits[id] or 0) / (secs / 60)), secs))
		end
	end
	add(string.format("Training XP/min: Strength %s  Speed %s", fmt((t.xp.Strength or 0) / mins), fmt((t.xp.Speed or 0) / mins)))
	-- spots
	for id, s in t.spots do
		local sp = ResourceSpotConfig.Get(id)
		if sp and s.cycleN > 0 then
			add(string.format("Spot %-15s tier %d: trip %.1fs avg (%d trips), %.1f units/trip, effective %.1f/trip, %.0f u/min", sp.DisplayName, sp.Tier, s.cycleSum / s.cycleN, s.cycleN, s.delivered / math.max(1, s.cycleN), s.effective / math.max(1, s.cycleN), s.delivered / (s.cycleSum / 60)))
		end
	end
	-- current state
	local luck = S.ServerLuckService.Get()
	local eff = S.SelectionService.EffectiveLuck()
	local w = RarityConfig.WeightsAt(eff)
	local cand = S.SelectionService.CandidateRarities()
	local total = 0
	for id, v in w do
		if cand[id] then
			total += v
		end
	end
	local parts = {}
	for _, id in RarityConfig.Order do
		if cand[id] then
			table.insert(parts, string.format("%s %.1f%%", id, w[id] / total * 100))
		end
	end
	add(string.format("Server Luck %.1f (effective %.1f) -> %s", luck, eff, table.concat(parts, "  ")))
	-- completions
	if #completions > 0 then
		local byR: { [string]: { n: number, avg: number, base: number, top: number, secs: number } } = {}
		for _, c in completions do
			local r = byR[c.rarity] or { n = 0, avg = 0, base = 0, top = 0, secs = 0 }
			r.n += 1
			r.avg += c.avg
			r.base += c.base
			r.top += c.top
			r.secs += c.seconds
			byR[c.rarity] = r
		end
		add("Completions (this server run):")
		for _, id in RarityConfig.Order do
			local r = byR[id]
			if r then
				add(string.format("  %-9s x%d  avg build %.0fs  base payout %.0f  avg paid %.0f  top paid %.0f", id, r.n, r.secs / r.n, r.base / r.n, r.avg / r.n, r.top / r.n))
			end
		end
	end
	-- projections from MEASURED rates (falls back to the analytic model when nothing was measured yet)
	local lvlS = if d then TrainingConfig.Level("Strength", d.Training.Strength or 0) else 0
	local lvlV = if d then TrainingConfig.Level("Speed", d.Training.Speed or 0) else 0
	local profile = { Strength = lvlS, Speed = lvlV, Vehicle = player:GetAttribute("Vehicle"), GatherLevel = if d then d.Upgrades.GatherSpeed else 0, DepositLevel = if d then d.Upgrades.DepositSpeed else 0, VehicleCapLevel = if d then d.Upgrades.VehicleCapacity else 0 }
	local modelCoins = BalanceModel.Trip(profile, ResourceSpotConfig.Primary("Wood") :: any).CoinsPerMin
	local cpm = if coinsMin > 0.5 then coinsMin else modelCoins
	add(string.format("Pacing (using %s Coins/min%s):", fmt(cpm), if coinsMin > 0.5 then " measured" else " from model"))
	for _, v in VehicleConfig.Vehicles do
		add(string.format("  afford %-12s (%s): ~%s from zero", v.DisplayName, fmt(v.Price), hours(v.Price / cpm)))
	end
	local wk = WorkerConfig.Types[WorkerConfig.DefaultType]
	add(string.format("  afford Worker (%d): ~%s", wk.UnlockPrice, hours(wk.UnlockPrice / cpm)))
	local sxp, vxp = (t.xp.Strength or 0) / mins, (t.xp.Speed or 0) / mins
	local xpCap = TrainingConfig.Stamina.MaxXPPerMinute
	local assumed = sxp < 1 or vxp < 1
	if sxp < 1 then
		sxp = xpCap.Strength * 0.9
	end
	if vxp < 1 then
		vxp = xpCap.Speed * 0.9
	end
	if assumed then
		add(string.format("  (training rates not measured yet: assuming 90%% of the XP cap = %.0f Strength / %.0f Speed XP/min; lift or run to measure)", sxp, vxp))
	end
	for _, lv in { 1, 5, 10, 15, 25 } do
		add(string.format("  Strength lvl %d: %s of lifting   Speed lvl %d: %s of running", lv, hours(TrainingConfig.PointsFor("Strength", lv) / math.max(0.01, sxp)), lv, hours(TrainingConfig.PointsFor("Speed", lv) / math.max(0.01, vxp))))
	end
	local r1 = MasterBuilderConfig.Ranks[1]
	local resMin = math.max(0.01, t.unitsPlayer / mins)
	local avgBuild = 6
	if #completions > 0 then
		local sum = 0
		for _, c in completions do
			sum += c.seconds
		end
		avgBuild = sum / #completions / 60
	end
	local limits = {
		{ "Coins", r1.CoinCost / cpm },
		{ "Resources", r1.MinLifetimeResources / resMin },
		{ "Builds", r1.MinBuildsCompleted * avgBuild },
		{ "Strength", TrainingConfig.PointsFor("Strength", r1.MinStrengthLevel) / math.max(0.01, sxp) },
		{ "Speed", TrainingConfig.PointsFor("Speed", r1.MinSpeedLevel) / math.max(0.01, vxp) },
	}
	table.sort(limits, function(x, y)
		return (x[2] :: number) > (y[2] :: number)
	end)
	add(string.format("Master Builder I (if rates held): limited by %s ~%s | Coins %s, resources %s, builds %s", limits[1][1], hours(limits[1][2] :: number), hours(limits[4][2] :: number), hours(limits[3][2] :: number), hours(limits[2][2] :: number)))
	return table.concat(lines, "\n")
end

-- Analytic tables (no play needed): units/min per archetype and spot, plus worker comparison.
function TelemetryService.ModelReport(): string
	local lines = { "== ANALYTIC MODEL (BalanceModel): units/min delivered ==" }
	for _, res in ResourceConfig.Families do
		table.insert(lines, BalanceModel.Table(res))
	end
	table.insert(lines, "-- Worker vs Active (Str10 Spd10, no vehicle) at the beginner spot --")
	local active = BalanceModel.Archetypes[3].Profile
	for _, res in ResourceConfig.Families do
		local near = ResourceSpotConfig.Primary(res)
		if near then
			local human = BalanceModel.Trip(active, near).UnitsPerMin
			local w0 = BalanceModel.Worker(0, res)
			local w15 = BalanceModel.Worker(15, res)
			table.insert(lines, string.format("  %-9s human %.0f u/m | worker base %.0f (%.0f%%)  max %.0f (%.0f%%)", res, human, w0, w0 / human * 100, w15, w15 / human * 100))
		end
	end
	return table.concat(lines, "\n")
end

return TelemetryService
