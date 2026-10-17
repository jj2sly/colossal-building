--!strict
-- Developer tools. Only authorized users can run commands: anyone in Studio while
-- GameConfig.Dev.Enabled is on, or UserIds in GameConfig.Dev.AdminUserIds in live
-- servers. Every command is validated server-side; the client panel is just buttons.
-- To disable completely for production: set GameConfig.Dev.Enabled = false and keep
-- AdminUserIds empty.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local BuildConfig = require(Shared.Config.BuildConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local ModifierConfig = require(Shared.Config.ModifierConfig)
local EventConfig = require(Shared.Config.EventConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local TrainingConfig = require(Shared.Config.TrainingConfig)
local ResourceSpotConfig = require(Shared.Config.ResourceSpotConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local VehicleConfig = require(Shared.Config.VehicleConfig)
local MasterBuilderConfig = require(Shared.Config.MasterBuilderConfig)
local SecretResourceConfig = require(Shared.Config.SecretResourceConfig)
local Formulas = require(Shared.Formulas)

local DebugService = {}
local S: any

local function authorized(player: Player): boolean
	if GameConfig.IsDev() then
		return true
	end
	return table.find(GameConfig.Dev.AdminUserIds, player.UserId) ~= nil
end

local function reply(player: Player, text: string)
	Net.Event("Notify"):FireClient(player, "Debug", text)
end

local Commands: { [string]: (Player, any) -> string? } = {}

Commands.ForceBuild = function(_p, id)
	if type(id) ~= "string" or not BuildConfig.Get(id) then
		return "unknown build"
	end
	S.SelectionService.Force("BuildId", id)
	S.GameLoopService.Restart()
	return "forcing " .. id
end
Commands.ForceRarity = function(_p, r)
	if type(r) ~= "string" or not RarityConfig.Tiers[r] then
		return "unknown rarity"
	end
	S.SelectionService.Force("Rarity", r)
	return "next roll forced to " .. r .. " (if builds exist)"
end
Commands.ForceModifier = function(_p, m)
	if m == "None" then
		S.SelectionService.Force("Modifiers", {})
		return "next build: no modifiers"
	end
	if type(m) ~= "string" or (m ~= "Both" and not ModifierConfig.Modifiers[m]) then
		return "unknown modifier"
	end
	S.SelectionService.Force("Modifiers", if m == "Both" then { "Golden", "Giant" } else { m })
	return "next build modifier: " .. m
end
Commands.AddCoins = function(p, n)
	if type(n) ~= "number" or n ~= n then
		return "bad amount"
	end
	S.PlayerDataService.AddCoins(p, math.clamp(n, -1e9, 1e9))
	return "coins added"
end
Commands.SetUpgrade = function(p, args)
	if type(args) ~= "table" or type(args.Id) ~= "string" or type(args.Level) ~= "number" or not UpgradeConfig.Upgrades[args.Id] then
		return "bad args"
	end
	S.UpgradeService.SetLevel(p, args.Id, args.Level)
	return args.Id .. " -> " .. args.Level
end
Commands.MaxUpgrades = function(p)
	for id, u in UpgradeConfig.Upgrades do
		S.UpgradeService.SetLevel(p, id, u.MaxLevel)
	end
	return "all upgrades maxed"
end
Commands.AddTraining = function(p, args)
	if type(args) ~= "table" or type(args.Stat) ~= "string" or type(args.Points) ~= "number" or not TrainingConfig.Stats[args.Stat] then
		return "bad args (Stat, Points)"
	end
	S.TrainingService.AddPoints(p, args.Stat, args.Points)
	return args.Stat .. " level " .. S.TrainingService.Level(p, args.Stat)
end
Commands.SetTrainingLevel = function(p, args)
	if type(args) ~= "table" or type(args.Stat) ~= "string" or type(args.Level) ~= "number" or not TrainingConfig.Stats[args.Stat] then
		return "bad args (Stat, Level)"
	end
	local d = S.PlayerDataService.Get(p)
	if not d then
		return "no data"
	end
	d.Training[args.Stat] = 0
	S.TrainingService.AddPoints(p, args.Stat, TrainingConfig.PointsFor(args.Stat, args.Level))
	return args.Stat .. " level " .. S.TrainingService.Level(p, args.Stat)
end
-- Marks builds as discovered (all of them when no id). For Index preview testing on TEST profiles.
Commands.DiscoverBuild = function(p, id)
	local d = S.PlayerDataService.Get(p)
	if not d then
		return "no data"
	end
	local n = 0
	for bid in BuildConfig.Builds do
		if id == nil or id == bid then
			d.BuildIndex[bid] = { Discovered = true, TimesCompleted = 1, BestContributionPct = 12.5, FastestCompletion = 300, Modifiers = {}, HighestReward = 1000, FirstCompletedAt = os.time() }
			n += 1
		end
	end
	S.PlayerDataService.MarkDirty(p)
	return "discovered " .. n
end
-- ---------------------------------------------------------------- balance tools (dev only)
Commands.BalanceReport = function(p)
	return S.TelemetryService.Report(p)
end
Commands.ModelReport = function()
	return S.TelemetryService.ModelReport()
end
Commands.TelemetryReset = function(p)
	S.TelemetryService.Reset(p)
	return "telemetry window reset"
end
-- Monte Carlo of the rarity roll at 0 / 50 / 100 Server Luck (all rarities available), N rolls each.
Commands.SimulateRarity = function(_p, n)
	local N = math.clamp(if type(n) == "number" then n else 20000, 1000, 200000)
	local rng = Random.new(7)
	local lines = { string.format("== RARITY DISTRIBUTION (%d rolls each, no personal Luck) ==", N) }
	for _, luck in { 0, 25, 50, 75, 100 } do
		local weights = Formulas.RarityWeights(luck, nil)
		local total = 0
		for _, w in weights do
			total += w.weight
		end
		local counts = {}
		for _ = 1, N do
			local pick = rng:NextNumber() * total
			for _, w in weights do
				pick -= w.weight
				if pick <= 0 then
					counts[w.id] = (counts[w.id] or 0) + 1
					break
				end
			end
		end
		local parts = {}
		for _, w in weights do
			table.insert(parts, string.format("%s %.1f%%", w.id, (counts[w.id] or 0) / N * 100))
		end
		table.insert(lines, string.format("Luck %3d: %s", luck, table.concat(parts, "  ")))
	end
	local eff = {}
	for _, avg in { 0, 10, 20, 30, 60 } do
		table.insert(eff, string.format("avg personal Luck %d -> +%.1f", avg, Formulas.EffectiveLuck(0, avg)))
	end
	table.insert(lines, "Personal Luck influence on the roll (cap +10): " .. table.concat(eff, ", "))
	return table.concat(lines, "\n")
end
-- Completion payout table: rarity x modifiers x rank bonus.
Commands.RewardTable = function()
	local c = EconomyConfig.Completion
	local lines = { "== COMPLETION PAYOUTS (base x modifiers, before friend bonus; rank bonus is ONE highest, not stacked) ==" }
	local mods = { {}, { "Ancient" }, { "Corrupted" }, { "Giant" }, { "Golden" }, { "Golden", "Giant" } }
	for _, rid in RarityConfig.Order do
		local row = { string.format("%-9s", rid) }
		for _, m in mods do
			local _, mr = S.ModifierService.Multipliers(m)
			table.insert(row, string.format("%s %.0f", if #m == 0 then "None" else table.concat(m, "+"), c.BasePayout[rid] * mr))
		end
		table.insert(lines, table.concat(row, " | "))
	end
	local b = {}
	for _, rule in c.Bonuses do
		table.insert(b, string.format("%s +%d%%", rule.Id, rule.Bonus * 100))
	end
	table.insert(lines, "Contribution bonuses (only the highest applies): Participant +0%, " .. table.concat(b, ", "))
	local dep = {}
	for _, rid in RarityConfig.Order do
		dep[#dep + 1] = string.format("%s x%.2f", rid, 1 + EconomyConfig.DepositRarityShare * (RarityConfig.Tiers[rid].RewardMultiplier - 1))
	end
	table.insert(lines, "Deposit earnings rarity factor (25% of the bonus): " .. table.concat(dep, ", "))
	return table.concat(lines, "\n")
end
-- Applies a Master Builder advancement to a COPY of your data (force=true ignores requirements) and reports it.
Commands.SimulateMasterBuilder = function(p, force)
	local d = S.PlayerDataService.Get(p)
	if not d then
		return "no data"
	end
	local copy = table.clone(d)
	copy.Upgrades = table.clone(d.Upgrades)
	copy.Training = table.clone(d.Training)
	copy.MasterBuilder = table.clone(d.MasterBuilder)
	copy.Stats = d.Stats
	copy.BuildIndex = d.BuildIndex
	local before = string.format("Coins %d, Strength L%d, Speed L%d, upgrades %d levels, rank %d", d.Coins, TrainingConfig.Level("Strength", d.Training.Strength), TrainingConfig.Level("Speed", d.Training.Speed), (function() local n = 0 for _, v in d.Upgrades do n += v end return n end)(), d.MasterBuilder.Rank or 0)
	local rank = MasterBuilderConfig.Ranks[(copy.MasterBuilder.Rank or 0) + 1]
	local lines = { "Rank 1 requirements now:" }
	if rank then
		for _, row in MasterBuilderConfig.Requirements(rank, d) do
			table.insert(lines, string.format("  %s%-34s %s / %s", if row.Done then "[x] " else "[ ] ", row.Label, tostring(math.floor(row.Have)), tostring(row.Need)))
		end
	end
	if force == true then
		copy.MasterBuilder.LastAdvancedAt = 0
		-- pretend the requirements are met so the reset itself can be inspected
		local saved = MasterBuilderConfig.Ranks[(copy.MasterBuilder.Rank or 0) + 1]
		local orig = table.clone(saved)
		for k, v in saved do
			if type(v) == "number" and string.sub(k, 1, 3) == "Min" or k == "CoinCost" then
				(saved :: any)[k] = 0
			end
		end
		(saved :: any).MinDiscoveredByRarity = {}
		local ok, why = MasterBuilderConfig.Advance(copy)
		for k, v in orig do
			(saved :: any)[k] = v
		end
		table.insert(lines, string.format("Advance (forced): %s %s", tostring(ok), why))
	else
		local ok, why = MasterBuilderConfig.Advance(copy)
		table.insert(lines, string.format("Advance: %s (%s)", tostring(ok), why))
	end
	table.insert(lines, "BEFORE: " .. before)
	table.insert(lines, string.format("AFTER (copy): Coins %d, Strength L%d, Speed L%d, rank %d, worker unlocked %s, vehicles owned %d", copy.Coins, TrainingConfig.Level("Strength", copy.Training.Strength), TrainingConfig.Level("Speed", copy.Training.Speed), copy.MasterBuilder.Rank or 0, tostring(copy.Worker.Unlocked), (function() local n = 0 for _ in copy.Vehicles.Owned do n += 1 end return n end)()))
	return table.concat(lines, "\n")
end
Commands.GrantVehicles = function(p)
	for id in VehicleConfig.Vehicles do
		S.VehicleService.Grant(p, id)
	end
	return "all vehicles granted"
end
Commands.EquipVehicle = function(p, id)
	if id == "None" then
		S.VehicleService.Equip(p, nil)
		return "parked"
	end
	if type(id) ~= "string" or not VehicleConfig.Vehicles[id] then
		return "unknown vehicle"
	end
	S.VehicleService.Grant(p, id)
	local ok, msg = S.VehicleService.Equip(p, id)
	return tostring(ok) .. " " .. tostring(msg)
end
Commands.SpotInfo = function()
	local lines = {}
	for _, sp in ResourceSpotConfig.List() do
		table.insert(lines, string.format("%-15s %-9s tier %d  at (%d, %d)  value x%.2f  speed x%.2f  dist from ring %d", sp.Id, sp.Resource, sp.Tier, sp.Position.X, sp.Position.Z, sp.YieldMultiplier, sp.GatherSpeedMultiplier, ResourceSpotConfig.DistanceFromRing(sp)))
	end
	return table.concat(lines, "\n")
end
Commands.ResetUpgrades = function(p)
	for id in UpgradeConfig.Upgrades do
		S.UpgradeService.SetLevel(p, id, 0)
	end
	return "upgrades reset"
end
Commands.AddResources = function(_p, fraction)
	local a = S.BuildService.Get()
	if not a then
		return "no active build"
	end
	local f = if type(fraction) == "number" then math.clamp(fraction, 0, 1) else 0.25
	local target = math.min(1, (S.StateService.Get("Progress") or 0) + f)
	S.BuildService.FillTo(target)
	return string.format("filled to %d%%", target * 100)
end
Commands.FillCarry = function(p)
	local needed = S.BuildService.Needed()
	local res = next(needed) or "Wood"
	S.ResourceService.Give(p, res, 1e6)
	return "filled carry with " .. res
end
Commands.CompleteStage = function()
	S.BuildService.CompleteNextStage()
	return "next stage filled"
end
-- colossal site check: where the active build sits, its activation point, and (with "fill") fill up to just past it
Commands.ColossalCheck = function(_p, arg)
	local ColossalConfig = require(Shared.Config.ColossalConfig)
	local a = S.BuildService.Get()
	if not a then
		return "no active build"
	end
	if arg == "fill" and a.activateAt then
		S.BuildService.FillTo(math.min(1, a.activateAt + 0.02))
		task.wait(1)
	end
	local piv = a.model:GetPivot()
	local _, size = a.model:GetBoundingBox()
	local sp = a.def.CompletionSpectacle and require(Shared.Config.SpectacleConfig).Spectacles[a.def.CompletionSpectacle]
	return string.format("%s (%s) pivot (%.1f, %.1f, %.1f) | bbox %.0f x %.0f x %.0f | activateAt %s activated %s | reveal budget %d | spectacle %.1fs reset %.1fs",
		a.def.Id, a.def.Rarity, piv.X, piv.Y, piv.Z, size.X, size.Y, size.Z, tostring(a.activateAt), tostring(a.activated) .. " milestone " .. tostring(a.milestone) .. " fallback " .. tostring((a :: any).secretFallback == true), a.revealBudget,
		ColossalConfig.SpectacleSeconds(a.def, sp and sp.Duration), ColossalConfig.ResetSeconds(a.def))
end
Commands.CompleteBuild = function()
	S.GameLoopService.ForceComplete()
	return "completing build"
end
Commands.TriggerEvent = function(_p, id)
	if type(id) ~= "string" or not EventConfig.Events[id] then
		return "unknown event"
	end
	return if S.EventService.Trigger(id) then "event " .. id else "event can't start now"
end
Commands.StopEvent = function()
	S.EventService.StopCurrent()
	return "event stopped"
end
Commands.DamageSection = function()
	local n = S.BuildService.DamageSections(1, 0.12, 2500)
	return if #n > 0 then "damaged section " .. n[1] else "no completed section to damage"
end
Commands.RepairAll = function()
	S.BuildService.RepairAll()
	return "repaired"
end
Commands.ResetBuild = function()
	S.GameLoopService.Restart()
	return "build reset"
end
Commands.SkipPhase = function()
	S.GameLoopService.Skip()
	return "skipping"
end
Commands.SetServerLuck = function(_p, n)
	if type(n) ~= "number" or n ~= n then
		return "bad value"
	end
	S.ServerLuckService.Set(n)
	return "server luck " .. n
end
Commands.SetMilestone = function(_p, n)
	if type(n) ~= "number" then
		return "bad value"
	end
	S.StateService.Set("MilestoneCount", math.clamp(math.floor(n), 0, 100))
	return "milestone count " .. n
end
Commands.ToggleFast = function()
	GameConfig.Dev.FastPresentation = not GameConfig.Dev.FastPresentation
	return "fast presentation: " .. tostring(GameConfig.Dev.FastPresentation)
end
Commands.SetFriends = function(_p, n)
	S.FriendService.SetOverride(if type(n) == "number" and n >= 0 then n else nil)
	return "friend override " .. tostring(n)
end
Commands.ResetData = function(p)
	local d = S.PlayerDataService.Get(p)
	if not d then
		return "no data"
	end
	d.Coins = 0
	for id in UpgradeConfig.Upgrades do
		d.Upgrades[id] = 0
	end
	d.BuildIndex = {}
	d.Stats = { BuildsCompleted = 0, LifetimeResources = 0, LifetimeContribution = 0, LifetimeRepairs = 0, CoinsEarned = 0, MVPCount = 0, CompletedByRarity = {} }
	d.Achievements = {}
	d.Titles = {}
	d.EquippedTitle = ""
	d.MasterBuilder = { Rank = 0, LastAdvancedAt = 0 }
	d.Training = { Strength = 0, Speed = 0 }
	d.Tutorial = { Done = false }
	d.Vehicles = { Owned = {}, Equipped = nil }
	d.Cosmetics = { WorkerOutfit = {}, Trail = {}, VehicleSkin = {}, CarryEffect = {}, ContributionEffect = {} }
	d.Equipped = {}
	d.Milestones = {}
	d.DropLog = {}
	d.Daily = { LastClaimDay = 0, Claims = 0, LastSeenDay = 0 }
	d.Purchases = { Passes = {}, Receipts = {} }
	d.Boosts = {}
	for _, kind in { "Coins", "Luck", "Gather", "Training" } do
		p:SetAttribute("Buff" .. kind, nil)
		p:SetAttribute("Buff" .. kind .. "Until", nil)
	end
	for _, key in { "VIPBuilder", "BuildersToolkit", "VehiclePack", "WorkerPack", "EffectsPack" } do
		p:SetAttribute("Pass_" .. key, nil)
	end
	S.CosmeticService.Refresh(p)
	p:SetAttribute("MasterRank", 0)
	d.MasterArchive = {}
	d.ForgottenArchive = {}
	d.ForgottenComplete = false
	if d.MasterBuilder then
		d.MasterBuilder.Vehicles = {}
	end
	for r = 1, 10 do
		local m = MasterBuilderConfig.Milestones[r]
		if m and m.Flag and d.Unlocks then
			d.Unlocks[m.Flag] = nil
		end
	end
	for _, k in { "Title_KeeperOfLostBuilds", "ForgottenAura", "ForgottenVehicleSkin", "ForgottenDeliveryEffect" } do
		if d.Unlocks then
			d.Unlocks[k] = nil
		end
	end
	d.TrainingMilestones = {}
	d.Worker = { Unlocked = false, Type = "Builder", Tier = "Basic", Assignment = "Auto", Enabled = true, Level = 0, OwnedTypes = { Builder = true }, Owned = {}, Tokens = 0, CrateCount = 0, PityCount = 0, Outfit = "Standard" }
	S.WorkerService.Despawn(p)
	d.Vehicles = { Owned = {}, Equipped = nil }
	S.VehicleService.Equip(p, nil)
	S.PlayerDataService.MarkDirty(p)
	S.UpgradeService.RefreshMovement(p)
	S.ResourceService.RefreshCapacity(p)
	return "data reset"
end
-- Link player `a` (command sender) with the player whose UserId is `arg` as friends.
Commands.LinkFriends = function(p, userId)
	local other = if type(userId) == "number" then Players:GetPlayerByUserId(userId) else nil
	if not other or other == p then
		return "bad player"
	end
	S.FriendService.DebugLink(p, other)
	return "linked " .. p.Name .. " <-> " .. other.Name
end
-- Sets a GameConfig.Timings entry on the server's own copy of the config.
Commands.SetTiming = function(_p, args)
	if type(args) ~= "table" or type(args.Name) ~= "string" or type(args.Value) ~= "number" or GameConfig.Timings[args.Name] == nil then
		return "bad args"
	end
	GameConfig.Timings[args.Name] = math.clamp(args.Value, 0, 600)
	return args.Name .. " = " .. GameConfig.Timings[args.Name]
end
-- Foundation-data test only: Master Builder advancement itself is not implemented.
-- ONE compact Master Builder test command (admin/Studio only): sets requirement data without grinding and can advance for real.
-- args = { Builds=, IndexCount=, MPDone=, MPUnique=, Upgrades=, Strength=, Speed=, Coins=, Advance=true, Report=true }
Commands.MBTest = function(p, args)
	local d = S.PlayerDataService.Get(p)
	if not d or type(args) ~= "table" then
		return "bad args"
	end
	if args.Builds then
		d.Stats.BuildsCompleted = args.Builds
	end
	if args.IndexCount then
		local n = 0
		for _, b in BuildConfig.IndexOrder({}) do
			d.BuildIndex[b.Id] = d.BuildIndex[b.Id] or {}
			d.BuildIndex[b.Id].Discovered = n < args.IndexCount
			n += 1
		end
	end
	if args.MPDone then
		d.MasterArchive = {}
		for i = 1, args.MPUnique or 1 do
			d.MasterArchive["TestProject" .. i] = { Discovered = true, TimesCompleted = if i == 1 then math.max(0, args.MPDone - ((args.MPUnique or 1) - 1)) else 1, BestContributionPct = 0, FastestCompletion = 100 }
		end
	end
	if args.Upgrades then
		local left = args.Upgrades
		for id, u in UpgradeConfig.Upgrades do
			local lv = math.min(u.MaxLevel, left)
			d.Upgrades[id] = lv
			left -= lv
		end
	end
	if args.Strength then
		d.Training.Strength = TrainingConfig.PointsFor("Strength", args.Strength)
	end
	if args.Speed then
		d.Training.Speed = TrainingConfig.PointsFor("Speed", args.Speed)
	end
	if args.Coins then
		d.Coins = args.Coins
	end
	local lines = {}
	if args.Advance then
		local ok, res = S.MasterBuilderService.Advance(p, true)
		table.insert(lines, "advance: " .. tostring(ok) .. " " .. (if ok then "rank " .. tostring(res.Rank) else tostring(res)))
	end
	local rank = MasterBuilderConfig.Ranks[(d.MasterBuilder.Rank or 0) + 1]
	if rank then
		local unmet = {}
		for _, row in MasterBuilderConfig.Requirements(rank, d) do
			if not row.Done then
				table.insert(unmet, string.format("%s %d/%d", row.Label, math.floor(row.Have), row.Need))
			end
		end
		table.insert(lines, "next rank unmet: " .. (if #unmet > 0 then table.concat(unmet, "; ") else "none (all met)"))
	end
	local veh = {}
	for id in d.MasterBuilder.Vehicles or {} do
		table.insert(veh, id)
	end
	table.sort(veh)
	table.insert(lines, string.format("rank %d | coins %d | Str L%d Spd L%d | upgrade levels %d | MB vehicles [%s] | owned normal vehicles %d | archive %s | secrets SM=%s AT=%s",
		d.MasterBuilder.Rank or 0, math.floor(d.Coins), TrainingConfig.Level("Strength", d.Training.Strength), TrainingConfig.Level("Speed", d.Training.Speed),
		(function() local n = 0 for _, v in d.Upgrades do n += v end return n end)(), table.concat(veh, ","), (function() local n = 0 for _ in d.Vehicles.Owned do n += 1 end return n end)(),
		tostring(next(d.ForgottenArchive or {}) ~= nil) .. "/" .. tostring(next(d.BuildIndex or {}) ~= nil),
		tostring(SecretResourceConfig.CanAccess("StarMetal", d)), tostring(SecretResourceConfig.CanAccess("AncientTimber", d))))
	return table.concat(lines, "\n")
end
Commands.SetMasterBuilderRank = function(p, rank)
	local d = S.PlayerDataService.Get(p)
	if not d or type(rank) ~= "number" then
		return "bad args"
	end
	d.MasterBuilder.Rank = math.clamp(math.floor(rank), 0, 10)
	d.MasterBuilder.LastAdvancedAt = os.time()
	S.PlayerDataService.MarkDirty(p)
	return "rank " .. d.MasterBuilder.Rank
end
Commands.DataInfo = function(p)
	local d = S.PlayerDataService.Get(p)
	return string.format("mock=%s coins=%s loaded=%s strengthXP=%.1f speedXP=%.1f", tostring(S.PlayerDataService.IsMock()), d and tostring(math.floor(d.Coins)) or "nil", tostring(S.PlayerDataService.IsLoaded(p)), d and d.Training.Strength or 0, d and d.Training.Speed or 0)
end
Commands.SimulateLoadFailure = function(_p, on)
	S.PlayerDataService.SetSimulateLoadFailure(on == true)
	return "simulate load failure = " .. tostring(on == true)
end
-- Reads what is actually stored (not memory) for a userId; compact summary string.
Commands.ReadStored = function(_p, userId)
	if type(userId) ~= "number" then
		return "bad id"
	end
	local data, err = S.PlayerDataService.DebugReadStored(userId)
	if data == nil then
		return "no stored data (" .. tostring(err) .. ")"
	end
	local up = {}
	for k, v in data.Upgrades or {} do
		if v > 0 then
			table.insert(up, k .. "=" .. v)
		end
	end
	table.sort(up)
	local idx = {}
	for k, e in data.BuildIndex or {} do
		table.insert(idx, k .. "x" .. tostring(e.TimesCompleted))
	end
	table.sort(idx)
	local ach = {}
	for k in data.Achievements or {} do
		table.insert(ach, k)
	end
	table.sort(ach)
	local owned = {}
	for k in (data.Vehicles and data.Vehicles.Owned) or {} do
		table.insert(owned, k)
	end
	return string.format(
		"v%s coins=%s up[%s] worker=%s veh=%s/eq=%s idx[%s] ach[%s] title=%q mb=%s stats.builds=%s serverLuck=%s session=%s",
		tostring(data.Version), tostring(math.floor(data.Coins or 0)), table.concat(up, ","),
		tostring(data.Worker and data.Worker.Unlocked), table.concat(owned, ","), tostring(data.Vehicles and data.Vehicles.Equipped),
		table.concat(idx, ","), table.concat(ach, ","), data.EquippedTitle or "",
		tostring(data.MasterBuilder and data.MasterBuilder.Rank), tostring(data.Stats and data.Stats.BuildsCompleted),
		tostring(data.ServerLuck), tostring(data.Session ~= nil)
	)
end
Commands.ReloadData = function(p)
	return S.PlayerDataService.DebugReload(p)
end
Commands.SaveNow = function(p)
	S.PlayerDataService.SaveNow(p)
	return "saved"
end

Commands.Teleport = function(p, target)
	local char = p.Character
	if not char then
		return "no character"
	end
	local pos
	if target == "Site" then
		pos = Vector3.new(0, 4, -50)
	elseif type(target) == "string" then
		local zone = workspace.World.Zones:FindFirstChild(target)
		pos = zone and zone.GatherPoint.Position + Vector3.new(0, 2, 0)
	elseif typeof(target) == "Vector3" then
		pos = target
	end
	if not pos then
		return "bad target"
	end
	char:PivotTo(CFrame.new(pos))
	return "teleported"
end
-- Gather once from the nearest node of a resource (teleports next to it first).
Commands.TestGather = function(p, resId)
	local best, bestD = nil, math.huge
	local char = p.Character
	if not char then
		return "no character"
	end
	for _, node in game:GetService("CollectionService"):GetTagged("ResourceNode") do
		if node:GetAttribute("ResourceId") == resId then
			local d = (node.Position - char:GetPivot().Position).Magnitude
			if d < bestD then
				best, bestD = node, d
			end
		end
	end
	if not best then
		return "no node"
	end
	if bestD > 8 then
		char:PivotTo(CFrame.new(best.Position + Vector3.new(0, 0, best.Size.Z / 2 + 3)))
	end
	S.ResourceService.HandleGather(p, best)
	return "carry " .. tostring(p:GetAttribute("CarryTotal")) .. "/" .. tostring(p:GetAttribute("CarryCap"))
end
-- Gathers once from a specific node (automated balance tests drive real routes with this).
Commands.GatherNode = function(p, node)
	if typeof(node) ~= "Instance" or not node:IsA("BasePart") or not game:GetService("CollectionService"):HasTag(node, "ResourceNode") then
		return "bad node"
	end
	S.ResourceService.HandleGather(p, node)
	return "ok"
end
-- Replays a completion spectacle for everyone (debug): arg = SpectacleConfig id.
Commands.PlaySpectacle = function(_p, id)
	local SpectacleConfig = require(Shared.Config.SpectacleConfig)
	if type(id) ~= "string" or not SpectacleConfig.Spectacles[id] then
		return "unknown spectacle"
	end
	Net.Event("Spectacle"):FireAllClients({ Id = id, Position = GameConfig.Site.Center })
	return "playing " .. id
end
-- Rolls the personal rare-drop table for you as if you had just completed a build. arg: { Build, Modifiers, Force }.
Commands.RollDrops = function(p, args)
	args = if type(args) == "table" then args else {}
	local def = BuildConfig.Get(args.Build or "GiantRobot")
	if not def then
		return "unknown build"
	end
	local found = S.DropService.Roll(p, def, args.Modifiers or {}, args.Force == true)
	local names = {}
	for _, f in found do
		table.insert(names, f.Name .. (if f.Duplicate then " (dup)" else ""))
	end
	return string.format("%s: %d drop(s) %s", def.Id, #found, table.concat(names, ", "))
end
-- Records a completion in the Build Index without playing a round. arg: { Build, Modifiers }.
Commands.RecordCompletion = function(p, args)
	args = if type(args) == "table" then args else {}
	local def = BuildConfig.Get(args.Build or "GiantRobot")
	if not def then
		return "unknown build"
	end
	S.BuildIndexService.Record(p, { BuildId = def.Id, Modifiers = args.Modifiers or {}, ContributionPct = 0.1, CompletionSeconds = 60, Reward = 100, IsMVP = false })
	local d = S.PlayerDataService.Get(p)
	local e = d and d.BuildIndex[def.Id]
	local have = {}
	for v in (e and e.Modifiers or {}) do
		table.insert(have, v)
	end
	table.sort(have)
	return string.format("%s variants: %s", def.Id, table.concat(have, ", "))
end
-- Index milestone progress for you.
Commands.MilestoneInfo = function(p)
	local IndexConfig = require(Shared.Config.IndexConfig)
	local d = S.PlayerDataService.Get(p)
	if not d then
		return "no data"
	end
	local builds = {}
	for _, b in BuildConfig.Builds do
		table.insert(builds, { Id = b.Id, Rarity = b.Rarity, EligibleModifiers = b.EligibleModifiers })
	end
	local lines = {}
	for _, m in IndexConfig.Milestones do
		local done, have, need = IndexConfig.Progress(m, d, builds)
		table.insert(lines, string.format("%-18s %d/%d %s%s", m.Id, have, need, if done then "DONE" else "", if d.Milestones[m.Id] then " (claimed)" else ""))
	end
	return table.concat(lines, "\n")
end
-- Server identity: shows the current named state and its perks.
Commands.ServerStateInfo = function()
	local st = S.ServerLuckService.State()
	return string.format("Server Luck %.0f -> %s (modifier chance x%.2f, drop chance x%.2f)", S.ServerLuckService.Get(), st.Name, st.Perks.ModifierChance, st.Perks.DropChance)
end
-- Quick worker customisation tests.
Commands.SetWorkerType = function(p, id)
	local d = S.PlayerDataService.Get(p)
	if d and type(id) == "string" then
		d.Worker.OwnedTypes[id] = true
	end
	local ok, msg = S.WorkerService.SetType(p, tostring(id))
	return tostring(ok) .. " " .. msg
end
Commands.GrantCosmetic = function(p, args)
	if type(args) ~= "table" then
		return "bad args (Category, Item)"
	end
	return tostring(S.CosmeticService.Grant(p, tostring(args.Category), tostring(args.Item), "debug"))
end
Commands.GrantAllResources = function(p, id)
	if type(id) ~= "string" or not ResourceConfig.Resources[id] then
		return "unknown resource"
	end
	S.ResourceService.Give(p, id, 1e6)
	return "carrying " .. id .. " x" .. tostring(p:GetAttribute("CarryTotal"))
end
-- ---------------------------------------------------------------- retention smoke-test helpers (dev only)
-- Raises this player's data just enough to satisfy the NEXT Master Builder rank (never lowers anything).
Commands.MBForceEligible = function(p)
	local d = S.PlayerDataService.Get(p)
	if not d then
		return "no data"
	end
	local rank = MasterBuilderConfig.Ranks[(d.MasterBuilder.Rank or 0) + 1]
	if not rank then
		return "max rank"
	end
	local BuildConfigLocal = BuildConfig
	d.Coins = math.max(d.Coins, rank.CoinCost or 0)
	d.Stats.BuildsCompleted = math.max(d.Stats.BuildsCompleted, rank.MinBuildsCompleted or 0)
	d.Stats.LifetimeResources = math.max(d.Stats.LifetimeResources, rank.MinLifetimeResources or 0)
	d.Stats.LifetimeContribution = math.max(d.Stats.LifetimeContribution, rank.MinLifetimeContribution or 0)
	local needLevels = rank.MinTotalUpgradeLevels or 0
	local have = 0
	for _, v in d.Upgrades do
		have += v
	end
	for id, u in UpgradeConfig.Upgrades do
		if have >= needLevels then
			break
		end
		local add = math.min(u.MaxLevel - d.Upgrades[id], needLevels - have)
		d.Upgrades[id] += add
		have += add
	end
	d.Training.Strength = math.max(d.Training.Strength, TrainingConfig.PointsFor("Strength", rank.MinStrengthLevel or 0))
	d.Training.Speed = math.max(d.Training.Speed, TrainingConfig.PointsFor("Speed", rank.MinSpeedLevel or 0))
	for _, b in BuildConfigLocal.Builds do
		if b.Enabled and b.Season == nil and not b.Forgotten then
			local e = d.BuildIndex[b.Id]
			if not e then
				d.BuildIndex[b.Id] = { Discovered = true, TimesCompleted = 1, BestContributionPct = 0, Modifiers = { Normal = true }, HighestReward = 0 }
			end
		end
	end
	d.MasterBuilder.LastAdvancedAt = 0
	S.PlayerDataService.MarkDirty(p)
	S.PlayerDataService.Sync(p)
	local rows = MasterBuilderConfig.Requirements(rank, d)
	local missing = {}
	for _, r in rows do
		if not r.Done then
			table.insert(missing, r.Label)
		end
	end
	return if #missing == 0 then "eligible for " .. rank.Title else "still missing: " .. table.concat(missing, ", ")
end
Commands.MBAdvance = function(p)
	local ok, payload = S.MasterBuilderService.Advance(p, true)
	return tostring(ok) .. " " .. (if type(payload) == "table" then payload.Title .. " | " .. table.concat(payload.Rewards, " | ") else tostring(payload))
end
Commands.ClaimDaily = function(p)
	local ok, r = S.DailyService.Claim(p)
	return tostring(ok) .. " " .. (if type(r) == "table" then r.Text else tostring(r))
end
Commands.ResetDaily = function(p)
	local d = S.PlayerDataService.Get(p)
	if d then
		d.Daily.LastClaimDay = 0
		d.Daily.LastSeenDay = 0
	end
	return "daily reset"
end
Commands.SetSeason = function(_p, args)
	local SeasonConfig = require(Shared.Config.SeasonConfig)
	if type(args) ~= "table" or not SeasonConfig.Seasons[args.Id] then
		return "bad args (Id, State)"
	end
	SeasonConfig.Seasons[args.Id].State = tostring(args.State)
	return args.Id .. " = " .. SeasonConfig.StateOf(args.Id)
end
Commands.BoardInfo = function(p)
	S.PlayerDataService.Get(p)
	S.StatsBoardService.Touch(p)
	S.StatsBoardService.Refresh()
	local lines = {}
	for _, b in S.StatsBoardService.Get() do
		table.insert(lines, string.format("%s (%s): %d entries, top %s", b.Title, if b.Global then "global" else "this server", #b.Entries, if b.Entries[1] then tostring(b.Entries[1].v) else "-"))
	end
	return table.concat(lines, " | ")
end
Commands.EquipCosmetic = function(p, args)
	if type(args) ~= "table" then
		return "bad args (Category, Item)"
	end
	local ok, msg = S.CosmeticService.Equip(p, tostring(args.Category), args.Item)
	return tostring(ok) .. " " .. msg
end
Commands.RetentionInfo = function(p)
	local d = S.PlayerDataService.Get(p)
	if not d then
		return "no data"
	end
	local function keys(t: any): string
		local out = {}
		for k, v in t do
			if v then
				table.insert(out, tostring(k))
			end
		end
		table.sort(out)
		return table.concat(out, ",")
	end
	local eq = {}
	for k, v in d.Equipped do
		table.insert(eq, k .. "=" .. tostring(v))
	end
	table.sort(eq)
	return string.format("rank=%d coins=%d strengthLvl=%d speedLvl=%d upgrades=%d vehicles=[%s] workerUnlocked=%s titles=[%s] equipped=[%s] dailyClaims=%d luckBuff=%s mbMilestonesTitle=%s", d.MasterBuilder.Rank, d.Coins, TrainingConfig.Level("Strength", d.Training.Strength), TrainingConfig.Level("Speed", d.Training.Speed), (function() local n = 0 for _, v in d.Upgrades do n += v end return n end)(), keys(d.Vehicles.Owned), tostring(d.Worker.Unlocked), keys(d.Titles), table.concat(eq, ";"), d.Daily.Claims, tostring(S.UpgradeService.Buff(p, "Luck")), tostring(d.Titles["Master Builder"]))
end
-- ---------------------------------------------------------------- monetization smoke-test helpers (dev only)
-- Pass entitlement through the real grant path (Studio only: PurchaseService.Simulate refuses outside dev).
Commands.SimPass = function(p, key)
	local ok, msg = S.PurchaseService.Simulate(p, "Pass", tostring(key))
	return tostring(ok) .. " " .. msg
end
-- Product through the real receipt path. args = { Kind = "Boost" | "ServerBoost", Key = "...", PurchaseId = "..." }
-- Repeat the same PurchaseId to test duplicate-receipt protection.
Commands.SimProduct = function(p, args)
	if type(args) ~= "table" then
		return "bad args (Kind, Key, PurchaseId?)"
	end
	local ok, msg = S.PurchaseService.Simulate(p, tostring(args.Kind), tostring(args.Key), if args.PurchaseId then tostring(args.PurchaseId) else nil)
	return tostring(ok) .. " " .. msg
end
Commands.BoostInfo = function(p)
	local MonetizationConfig = require(Shared.Config.MonetizationConfig)
	local parts = {}
	for _, kind in { "Coins", "Luck", "Gather", "Training" } do
		table.insert(parts, string.format("%s x%s (%ds)", kind, tostring(p:GetAttribute("Buff" .. kind)), S.BoostService.Remaining(p, kind)))
	end
	for id in MonetizationConfig.ServerBoosts do
		table.insert(parts, string.format("%s %ds", id, S.BoostService.ServerRemaining(id)))
	end
	local d = S.PlayerDataService.Get(p)
	local passes = {}
	for k in d.Purchases.Passes do
		table.insert(passes, k)
	end
	local receipts = 0
	for _ in d.Purchases.Receipts do
		receipts += 1
	end
	return string.format("%s | passes=[%s] receipts=%d paidGather=x%.2f paidDeposit=x%.2f cargoBonus=%.2f dailyBonus=%.2f serverLuckBonus=%d rewardMult=%.2f", table.concat(parts, "; "), table.concat(passes, ","), receipts, S.BoostService.PaidGatherMult(p), S.BoostService.PaidDepositMult(p), S.BoostService.CargoBonus(p), S.BoostService.DailyCoinBonus(p), S.BoostService.ServerLuckBonus(), S.BoostService.ServerRewardMult())
end
-- FREE-FIRST DESIGN CHECK: data-level proof that paid items do not gate or replace progression.
Commands.FreeFirstCheck = function()
	local MonetizationConfig = require(Shared.Config.MonetizationConfig)
	local CosmeticConfig = require(Shared.Config.CosmeticConfig)
	local DropConfig = require(Shared.Config.DropConfig)
	local IndexConfig = require(Shared.Config.IndexConfig)
	local DailyConfig = require(Shared.Config.DailyConfig)
	local WorkerConfig = require(Shared.Config.WorkerConfig)
	local lines = {}
	local problems = MonetizationConfig.FreeFirstReport()
	table.insert(lines, if #problems == 0 then "rules: OK (no paid cosmetic in any free reward; all bonuses/durations within caps)" else "RULE PROBLEMS: " .. table.concat(problems, "; "))
	-- no gameplay config references monetization or a paid flag
	local gated = 0
	for _, b in BuildConfig.Builds do
		if (b :: any).Paid or (b :: any).Gamepass then
			gated += 1
		end
	end
	for _, r in ResourceConfig.Resources do
		if (r :: any).Paid or (r :: any).Gamepass then
			gated += 1
		end
	end
	for _, v in VehicleConfig.Vehicles do
		if (v :: any).Paid or (v :: any).Gamepass then
			gated += 1
		end
	end
	table.insert(lines, string.format("gated builds/resources/vehicles: %d (builds %d, resource ids %d, vehicles %d all free)", gated, (function() local n = 0 for _ in BuildConfig.Builds do n += 1 end return n end)(), (function() local n = 0 for _ in ResourceConfig.Resources do n += 1 end return n end)(), (function() local n = 0 for _ in VehicleConfig.Vehicles do n += 1 end return n end)()))
	-- every NON-paid cosmetic must have a free route (drop, milestone, Master Builder rank, daily, free Worker outfit)
	local free: { [string]: string } = {}
	for _, dr in DropConfig.Drops do
		free[dr.Category .. "/" .. dr.Item] = "drop"
	end
	for _, m in IndexConfig.Milestones do
		free[m.Reward.Category .. "/" .. m.Reward.Item] = "index"
	end
	for _, m in MasterBuilderConfig.Milestones do
		for _, c in m.Cosmetics or {} do
			free[c.Category .. "/" .. c.Item] = "masterbuilder"
		end
	end
	for _, r in DailyConfig.Cycle do
		if r.Cosmetic then
			free[r.Cosmetic.Category .. "/" .. r.Cosmetic.Item] = "daily"
		end
	end
	for id, o in WorkerConfig.Outfits do
		if o.Source == "Free" or string.find(o.Source, "Worker") then
			free["WorkerOutfit/" .. id] = "worker type"
		end
	end
	local unreachable = {}
	local paidCount = 0
	for cat, items in CosmeticConfig.Catalog do
		for id, e in items do
			if (e :: any).Paid then
				paidCount += 1
			elseif not free[cat .. "/" .. id] then
				table.insert(unreachable, cat .. "/" .. id)
			end
		end
	end
	table.insert(lines, string.format("paid cosmetics: %d (packs only). Non-paid cosmetics without a free route: %s", paidCount, if #unreachable == 0 then "none" else table.concat(unreachable, ", ")))
	table.insert(lines, string.format("Master Builder enabled=%s, ranks=%d, all requirements are gameplay stats (no purchase field)", tostring(MasterBuilderConfig.Enabled), #MasterBuilderConfig.Ranks))
	return table.concat(lines, "\n")
end
-- FOUNDATION PASS TOOLS ------------------------------------------------------------------------------------------------
-- ForceMutation { Res = "Wood", Tier = "Golden" }: spawns a mutated pile now (ignores the phase and the roll chance).
Commands.ForceMutation = function(_, args)
	if type(args) ~= "table" or type(args.Res) ~= "string" or type(args.Tier) ~= "string" then
		return "bad args (Res, Tier)"
	end
	local pile = S.MutationService.Spawn(args.Res, args.Tier)
	return if pile then string.format("pile %s: %s %s (%d nodes, reserve %d)", pile.id, args.Tier, args.Res, #pile.nodes, pile.reserve) else "could not spawn (no nodes / bad ids)"
end
Commands.ClearMutations = function()
	S.MutationService.Clear()
	return "mutations cleared"
end
Commands.MutationOdds = function(_, luck)
	local l = if type(luck) == "number" then luck else S.ServerLuckService.Get()
	local MutationConfig = require(Shared.Config.MutationConfig)
	local parts = {}
	for _, e in MutationConfig.TierOdds(l) do
		table.insert(parts, string.format("%s %.1f%%", e.id, e.p * 100))
	end
	return string.format("luck %d: roll chance %.0f%% | %s", l, MutationConfig.ChanceAt(l) * 100, table.concat(parts, ", "))
end
-- Max levels, current effects, carry and speed in one line.
Commands.TrainingInfo = function(p)
	local d = S.PlayerDataService.Get(p)
	local hum = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
	return string.format("MaxLevel S=%d V=%d | Strength %d (%.0f pts) carry %d cap %s | Speed %d (%.0f pts) walk %.1f | MB rank %d xp bonus +%d%%",
		TrainingConfig.Stats.Strength.MaxLevel, TrainingConfig.Stats.Speed.MaxLevel,
		S.TrainingService.Level(p, "Strength"), d.Training.Strength, Formulas.BaseCarry(d.Training.Strength), tostring(p:GetAttribute("CarryCap")),
		S.TrainingService.Level(p, "Speed"), d.Training.Speed, hum and hum.WalkSpeed or 0,
		d.MasterBuilder.Rank, MasterBuilderConfig.TrainingXPBonus(d.MasterBuilder.Rank) * 100)
end
-- What a Master Builder reset would keep, without doing it.
Commands.MBResetPreview = function(p)
	local d = S.PlayerDataService.Get(p)
	local parts = {}
	for statId in TrainingConfig.Stats do
		local level = TrainingConfig.Level(statId, d.Training[statId] or 0)
		table.insert(parts, string.format("%s %d -> %d", statId, level, math.floor(level * MasterBuilderConfig.TrainingRetention)))
	end
	return table.concat(parts, " | ")
end
Commands.OpenWorkerCrate = function(p)
	local ok, r = S.WorkerService.OpenCrate(p)
	if not ok then
		return tostring(r)
	end
	return string.format("%s %s%s (paid %d)", r.Tier, r.Type, if r.New then " NEW" else " duplicate +" .. r.Tokens .. " tokens", r.Spent)
end
-- MASTER PROJECT / SECRET TOOLS ----------------------------------------------------------------------------------------
-- ForceMasterProject: the NEXT build selection starts the Orbital Station (single use, dev only). Use SkipPhase to move on.
Commands.ForceMasterProject = function(_, id)
	local MasterProjectConfig = require(Shared.Config.MasterProjectConfig)
	local mpc: any = MasterProjectConfig
	mpc.ForceNext = if type(id) == "string" then id else "OrbitalStation"
	return "next selection will be the Master Project " .. tostring(mpc.ForceNext)
end
-- FORGOTTEN FRAMEWORK dev commands (no Forgotten structure exists yet)
Commands.ForgottenDiscover = function(p, id)
	return S.ForgottenService.DevDiscover(p, if type(id) == "string" then id else nil)
end
Commands.ForgottenInfo = function(p)
	local d = S.PlayerDataService.Get(p)
	local n = 0
	for _ in (d and d.ForgottenArchive) or {} do
		n += 1
	end
	local normal = 0
	for _, b in BuildConfig.Eligible(nil, 100) do
		if b.Forgotten then
			normal += 1
		end
	end
	local eligible = S.ForgottenService.EligibleForgotten()
	return string.format("own records %d | forgotten builds in normal pool %d | startable now %s | entries registered: %d | archive-complete flag %s, aura %s", n, normal, tostring(eligible ~= nil), #S.ForgottenService.Entries, tostring(d and d.ForgottenComplete), tostring(d and d.Unlocks and d.Unlocks.ForgottenAura))
end
-- test the completion path (what BuildIndexService.Record does for an eligible contributor) without depositing
Commands.ForgottenComplete = function(p, id)
	local e = S.ForgottenService.ByBuild(if type(id) == "string" then id else "")
	if not e then
		return "unknown forgotten build"
	end
	local isNew = S.ForgottenService.Record(p, e, { ContributionPct = 0.123, CompletionSeconds = 95 })
	local rec = S.PlayerDataService.Get(p).ForgottenArchive[e.Id]
	return string.format("record new=%s completed=%d best=%.1f fastest=%s", tostring(isNew), rec.TimesCompleted, rec.BestContributionPct, tostring(rec.FastestCompletion))
end
Commands.ClearForced = function()
	for _, k in { "BuildId", "Rarity", "Modifiers" } do
		S.SelectionService.Force(k, nil)
	end
	return "forced build / rarity / modifier overrides cleared"
end
-- ONE compact status command: chance / pressure / pity / eligible opaque ids. Optional table arg sets the session counters
-- ({ Normal=, Since=, Pity=, Earthquake= }) for cheap logic tests. Admin/Studio only (all Debug commands are).
Commands.ForgottenStatus = function(_p, args)
	local c = S.ForgottenService.Counters
	if type(args) == "table" then
		for _, k in { "Normal", "Since", "Pity" } do
			if type(args[k]) == "number" then
				c[k] = args[k]
			end
		end
		if args.Earthquake ~= nil then
			c.Earthquake = args.Earthquake == true
		end
	end
	local extra = ""
	if type(args) == "table" then
		if args.FallbackSeconds then
			S.ForgottenService.Config.SecretFallbackSeconds = args.FallbackSeconds -- test hook for the zero-gatherer failsafe
		end
		if args.ClearRecords then
			S.PlayerDataService.Get(_p).ForgottenArchive = {}
			S.ForgottenService.ClearPending()
		end
		if args.LateJoin then
			S.ForgottenService.OnLateJoin(_p)
		end
		if args.Contribute then
			extra = extra .. " | contributed " .. tostring(S.BuildService.Deposit(_p, args.Contribute, 5, "Player"))
		end
		if args.Needs then
			local act = S.BuildService.Get()
			local t = {}
			if act then
				for r, n in act.need do
					table.insert(t, r .. "=" .. n)
				end
			end
			table.sort(t)
			extra = extra .. " | active " .. (act and act.def.Id or "none") .. " fallback " .. tostring(act and act.secretFallback) .. " needs " .. table.concat(t, ",")
		end
		extra = extra .. string.format(" | pending reward %s coins %d", tostring(S.ForgottenService.Pending[_p] ~= nil), math.floor(S.PlayerDataService.Get(_p).Coins))
	end
	local rolled = extra
	if type(args) == "table" and args.Roll then
		local e = S.ForgottenService.RollNatural()
		rolled = extra .. " | roll: " .. (if e then e.Id else "none")
	end
	local chance, parts = S.ForgottenService.Chance()
	local ids = {}
	for _, e in S.ForgottenService.EligibleEntries() do
		table.insert(ids, e.Id)
	end
	return string.format("normal %d since %d pity %d quake %s | chance %.3f%% (base %.2f luck %.3f pressure %.2f) | eligible: %s", c.Normal, c.Since, c.Pity, tostring(c.Earthquake), chance, parts.Base, parts.Luck, parts.Pressure, table.concat(ids, ",")) .. rolled
end
Commands.ForgottenForce = function(_p, id)
	S.ForgottenService.ForceNext = if type(id) == "string" then id else nil
	return "next selection will be Forgotten " .. tostring(S.ForgottenService.ForceNext)
end
-- masking check: none of the registered Forgotten builds may be in any normal list (pool, vote, Legacy, Index) or the replicated previews
Commands.ForgottenMaskCheck = function()
	local hits = {}
	local function scan(list, what)
		for _, b in list do
			if b.Forgotten then
				table.insert(hits, what .. ":" .. b.Id)
			end
		end
	end
	scan(BuildConfig.Eligible(nil, 1e9), "pool")
	for _, r in { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" } do
		scan(BuildConfig.Eligible(r, 1e9), "pool" .. r)
	end
	local idx = BuildConfig.IndexOrder({})
	scan(idx, "index")
	local previews = game:GetService("ReplicatedStorage"):FindFirstChild("BuildPreviews")
	for _, e in S.ForgottenService.Entries do
		if previews and previews:FindFirstChild(e.Build) then
			table.insert(hits, "preview:" .. e.Build)
		end
	end
	return string.format("forgotten registered %d | leaks into normal lists/previews: %d %s | pools %s | index size %d", #S.ForgottenService.Entries, #hits, table.concat(hits, ","), BuildConfig.PoolSummary(), #idx)
end
Commands.MasterProjectEligibility = function()
	local ok, p = pcall(S.MasterBuilderService.EligibleMasterProject)
	local ctx = S.MasterBuilderService.MasterProjectContext()
	return string.format("eligible=%s (%s) | luck %.0f builds %d combinedRank %d masters %d starMetalHolder %s", tostring(ok and p ~= nil), tostring(ok and p and p.Id or p), ctx.ServerLuck, ctx.BuildCount, ctx.CombinedRank, ctx.MasterPlayers, tostring(ctx.Secrets.StarMetal == true))
end
Commands.SecretCheck = function(p)
	local SecretResourceConfig = require(Shared.Config.SecretResourceConfig)
	local d = S.PlayerDataService.Get(p)
	local parts = {}
	for id in SecretResourceConfig.Secrets do
		table.insert(parts, id .. "=" .. tostring(SecretResourceConfig.CanAccess(id, d)))
	end
	table.sort(parts)
	return string.format("MB rank %d | %s", d.MasterBuilder.Rank, table.concat(parts, ", "))
end
Commands.SpawnSecretCache = function(p, id)
	local secret = if type(id) == "string" then id else "StarMetal"
	local hrp = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hrp then
		return "no character"
	end
	local nodes = S.SecretResourceService.SpawnCache(secret, hrp.Position + hrp.CFrame.LookVector * 14 - Vector3.new(0, 2.5, 0), 3, 60)
	return string.format("%d %s cache nodes for 60 s", #nodes, secret)
end
-- Records a fake Orbital Station completion for this player (tests the Master Archive without a full run).
Commands.RecordMasterProject = function(p)
	local isNew = S.BuildIndexService.Record(p, { BuildId = "OrbitalStation", Modifiers = {}, ContributionPct = 0.123, CompletionSeconds = 754, Reward = 0, IsMVP = false })
	return "recorded (new=" .. tostring(isNew) .. ")"
end
Commands.ArchiveInfo = function(p)
	local d = S.PlayerDataService.Get(p)
	local parts = {}
	for id, m in d.MasterArchive or {} do
		table.insert(parts, string.format("%s x%d best %.1f%% fastest %ss", id, m.TimesCompleted, m.BestContributionPct, tostring(m.FastestCompletion)))
	end
	return if #parts > 0 then table.concat(parts, " | ") else "Master Archive empty"
end
Commands.Summary = function(p)
	local gs = S.StateService.Folder()
	local parts = {}
	for k, v in gs:GetAttributes() do
		if v ~= 0 and v ~= "" then
			table.insert(parts, k .. "=" .. tostring(v))
		end
	end
	table.sort(parts)
	local pa = {}
	for k, v in p:GetAttributes() do
		table.insert(pa, k .. "=" .. tostring(v))
	end
	table.sort(pa)
	local d = S.PlayerDataService.Get(p)
	local up = {}
	if d then
		for k, v in d.Upgrades do
			if v > 0 then
				table.insert(up, k .. "=" .. v)
			end
		end
	end
	return table.concat(parts, " ") .. "\nPLAYER " .. table.concat(pa, " ") .. "\nUPGRADES " .. table.concat(up, " ")
end

function DebugService.Init(registry)
	S = registry
end

-- Server-side entry point (also used by automated tests via execute_luau).
function DebugService.Run(player: Player, cmd: string, arg: any): string
	local fn = Commands[cmd]
	if not fn then
		return "unknown command"
	end
	local ok, result = pcall(fn, player, arg)
	return if ok then tostring(result or "ok") else "error: " .. tostring(result)
end

function DebugService.Start()
	local function mark(p: Player)
		p:SetAttribute("IsDebugUser", authorized(p))
	end
	Players.PlayerAdded:Connect(mark)
	for _, p in Players:GetPlayers() do
		mark(p)
	end
	local limiter = Net.RateLimiter(5, 10)
	Net.Event("DebugCommand").OnServerEvent:Connect(function(player, cmd, arg)
		if not authorized(player) or type(cmd) ~= "string" or not limiter(player) then
			return
		end
		local result = DebugService.Run(player, cmd, arg)
		if string.find(result, "\n", 1, true) or #result > 140 then
			Net.Event("DebugReport"):FireClient(player, cmd .. "\n" .. result)
		else
			reply(player, cmd .. ": " .. result)
		end
	end)
	-- Dev-only bridge so Studio command-bar / MCP test scripts (a separate Luau VM)
	-- can drive the game: ServerStorage.MB_DebugBridge:Invoke(cmd, arg, userId?)
	if GameConfig.IsDev() then
		local bridge = Instance.new("BindableFunction")
		bridge.Name = "MB_DebugBridge"
		bridge.OnInvoke = function(cmd, arg, userId)
			local p = if userId then Players:GetPlayerByUserId(userId) else Players:GetPlayers()[1]
			if not p then
				return "no player"
			end
			return DebugService.Run(p, cmd, arg)
		end
		bridge.Parent = game:GetService("ServerStorage")
	end
end

return DebugService
