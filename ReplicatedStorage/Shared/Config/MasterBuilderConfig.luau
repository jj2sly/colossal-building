--!strict
-- MASTER BUILDER (long-term prestige): 10 ranks. Advancing resets Coins, purchased upgrades, Worker progression and
-- vehicles, and keeps the Build Index, achievements, titles, cosmetics, the rank itself and half of Strength / Speed
-- levels. Permanent unlocks (see Milestones) survive every reset, which is how the reset pain fades at higher ranks.
--
-- Everything here is DATA. Requirements(rank, data) turns a rank definition into display/validation rows; to add a new
-- kind of requirement add one `add(...)` line in Requirements. Ranks are a modest curve (each rank asks roughly 25-35%
-- more than the last), not an exponential one.
local MasterBuilderConfig = {}

MasterBuilderConfig.Enabled = true

MasterBuilderConfig.ResetsFields = { "Coins", "Upgrades", "Worker", "Vehicles" }
MasterBuilderConfig.PreservesFields = { "BuildIndex", "Badges", "Titles", "EquippedTitle", "Cosmetics", "Achievements", "Stats", "Training (half)", "MasterBuilder", "MasterArchive", "ForgottenArchive", "Unlocks" }

-- RANK REQUIREMENTS (final table). Index = rank being reached. Fields:
--   MinBuildsCompleted      Stats.BuildsCompleted
--   MinTotalUpgradeLevels   sum of purchased upgrade levels (UpgradeConfig.TotalMaxLevels() = 75)
--   MinStrengthLevel / MinSpeedLevel   trained levels
--   MinIndexCount           distinct permanent builds discovered (of the 40 in the Build Index)
--   MinMasterCompletions    total Master Project completions (PlayerData.MasterArchive TimesCompleted)
--   MinUniqueMasterProjects distinct Master Projects completed (data-ready: with one Master Project the top rank needs a second one to exist)
MasterBuilderConfig.Ranks = {
	{
		Title = "Master Builder I",
		MinBuildsCompleted = 30,
		MinTotalUpgradeLevels = 40,
		MinStrengthLevel = 6,
		MinSpeedLevel = 6,
		MinIndexCount = 12,
	},
	{
		Title = "Master Builder II",
		MinBuildsCompleted = 45,
		MinTotalUpgradeLevels = 44,
		MinStrengthLevel = 8,
		MinSpeedLevel = 8,
		MinIndexCount = 16,
	},
	{
		Title = "Master Builder III",
		MinBuildsCompleted = 65,
		MinTotalUpgradeLevels = 48,
		MinStrengthLevel = 10,
		MinSpeedLevel = 10,
		MinIndexCount = 20,
	},
	{
		Title = "Master Builder IV",
		MinBuildsCompleted = 90,
		MinTotalUpgradeLevels = 52,
		MinStrengthLevel = 12,
		MinSpeedLevel = 11,
		MinIndexCount = 24,
	},
	{
		Title = "Master Builder V",
		MinBuildsCompleted = 120,
		MinTotalUpgradeLevels = 56,
		MinStrengthLevel = 14,
		MinSpeedLevel = 13,
		MinIndexCount = 28,
	},
	{
		Title = "Master Builder VI",
		MinBuildsCompleted = 150,
		MinTotalUpgradeLevels = 60,
		MinStrengthLevel = 16,
		MinSpeedLevel = 15,
		MinIndexCount = 32,
	},
	{
		Title = "Master Builder VII",
		MinBuildsCompleted = 185,
		MinTotalUpgradeLevels = 64,
		MinStrengthLevel = 18,
		MinSpeedLevel = 17,
		MinIndexCount = 35,
	},
	{
		Title = "Master Builder VIII",
		MinBuildsCompleted = 220,
		MinTotalUpgradeLevels = 68,
		MinStrengthLevel = 20,
		MinSpeedLevel = 18,
		MinIndexCount = 37,
		MinMasterCompletions = 1,
	},
	{
		Title = "Master Builder IX",
		MinBuildsCompleted = 250,
		MinTotalUpgradeLevels = 72,
		MinStrengthLevel = 22,
		MinSpeedLevel = 20,
		MinIndexCount = 39,
		MinMasterCompletions = 3,
	},
	{
		Title = "Grand Master Builder",
		MinBuildsCompleted = 280,
		MinTotalUpgradeLevels = 75,
		MinStrengthLevel = 23,
		MinSpeedLevel = 21,
		MinIndexCount = 40,
		MinMasterCompletions = 6,
		MinUniqueMasterProjects = 2,
	},
}

-- Minimum days between advancements so it can't be rapidly cycled (0 = off).
MasterBuilderConfig.CooldownDays = 1

-- Modest permanent bonuses PER RANK (prestige is mostly titles/cosmetics, not power).
MasterBuilderConfig.PerRankBonus = {
	CarryEffectiveness = 0.02, -- +2% base carrying
	GatherEffectiveness = 0.01, -- +1% gather speed
	PersonalLuck = 1, -- +1 personal Luck point
	WorkerEffectiveness = 0.02, -- +2% Worker efficiency
}

function MasterBuilderConfig.Bonus(rank: number, key: string): number
	return (MasterBuilderConfig.PerRankBonus :: any)[key] * math.max(0, rank)
end

-- PERMANENT UNLOCKS / REWARDS, keyed by the rank reached. Fields (all optional):
--   Text        one line shown in the Master Builder menu
--   Title       a title granted (PlayerData.Titles)
--   Cosmetics   { { Category, Item } } granted through CosmeticService (see CosmeticConfig)
--   Vehicle     a vehicle id that is owned permanently: it survives every future reset
--   Worker      true = the basic Worker stays unlocked through resets
--   MasterProject true = future hook: access to Master Projects (see MasterProjects below)
export type Milestone = {
	Text: string,
	Title: string?,
	Cosmetics: { { Category: string, Item: string } }?,
	Vehicle: string?, -- a Master Builder vehicle id (MasterBuilderConfig.MasterVehicles): permanent, never purchasable
	Flag: string?, -- a persistent unlock flag in PlayerData.Unlocks (hook for later cosmetic / title art)
	Worker: boolean?,
	MasterProject: boolean?,
}
-- The four permanent Master Builder vehicles. DATA ONLY for now (no models): they live in PlayerData.MasterBuilder.Vehicles, which a
-- prestige never clears, and they are not in VehicleConfig so they can never be bought.
MasterBuilderConfig.MasterVehicles = {
	BuilderBuggy = { Rank = 1, DisplayName = "Builder Buggy" },
	SiteRunner = { Rank = 4, DisplayName = "Site Runner" },
	MasterHauler = { Rank = 7, DisplayName = "Master Hauler" },
	TitanCarrier = { Rank = 10, DisplayName = "Titan Carrier" },
} :: { [string]: { Rank: number, DisplayName: string } }
MasterBuilderConfig.Milestones = {
	[1] = { Text = "Builder Buggy, Star Metal access, Expert Worker tier", Title = "Master Builder", Vehicle = "BuilderBuggy", Flag = "MB_Rank1" },
	[2] = { Text = "Cosmetic unlock: Blueprint Trail", Cosmetics = { { Category = "Trail", Item = "BlueprintTrail" } }, Flag = "MB_Cosmetic2" },
	[3] = { Text = "Ancient Timber access, Master Worker tier", Flag = "MB_Rank3" },
	[4] = { Text = "Site Runner is yours permanently, Blueprint Burst effect", Vehicle = "SiteRunner", Cosmetics = { { Category = "ContributionEffect", Item = "BlueprintBurst" } }, Flag = "MB_Cosmetic4" },
	[5] = { Text = "Cosmetic unlock", Flag = "MB_Cosmetic5" },
	[6] = { Text = "Cosmetic unlock: Master Builder Crew outfit", Cosmetics = { { Category = "WorkerOutfit", Item = "MasterCrew" } }, Flag = "MB_Cosmetic6" },
	[7] = { Text = "Master Hauler is yours permanently", Vehicle = "MasterHauler", Flag = "MB_Rank7" },
	[8] = { Text = "High-rank cosmetic unlock: Master Chrome", Cosmetics = { { Category = "VehicleSkin", Item = "MasterChrome" } }, Flag = "MB_HighCosmetic8" },
	[9] = { Text = "High-rank cosmetic unlock: Prestige Aura", Cosmetics = { { Category = "CarryEffect", Item = "PrestigeAura" } }, Flag = "MB_HighCosmetic9" },
	[10] = {
		Text = "Titan Carrier, title: Grand Master Builder, Grand Burst effect, Master Project access",
		Title = "Grand Master Builder",
		Vehicle = "TitanCarrier",
		Cosmetics = { { Category = "ContributionEffect", Item = "GrandBurst" } },
		Flag = "MB_Final",
		MasterProject = true,
	},
} :: { [number]: Milestone }

-- MASTER PROJECTS: the real hooks now live in MasterProjectConfig (automatic trigger, no vote). This old list is unused.
-- (hook only, nothing uses it yet). Future endgame builds that need rare conditions. A project is
-- unlockable when the server meets MinServerLuck, the combined Master Builder ranks of the players present reach
-- MinCombinedRank, and at least one present player has MasterProject access (rank 10). Template/requirements to come.
MasterBuilderConfig.MasterProjects = {
	{ Id = "ColossalDragon", DisplayName = "Colossal Dragon", MinServerLuck = 80, MinCombinedRank = 40, Enabled = false },
	{ Id = "FloatingCity", DisplayName = "Floating City", MinServerLuck = 90, MinCombinedRank = 60, Enabled = false },
	{ Id = "WorldEngine", DisplayName = "World Engine", MinServerLuck = 95, MinCombinedRank = 80, Enabled = false },
}

-- Advancing keeps this share of Strength / Speed LEVELS: kept level = floor(level * TrainingRetention)  (20 -> 10, 50 -> 25,
-- 100 -> 50). The matching points are restored, so the next level starts from zero progress.
MasterBuilderConfig.TrainingRetention = 0.5

-- Permanent training recovery: every Master Builder rank adds this much Strength/Speed XP (stacking; see TrainingConfig).
MasterBuilderConfig.TrainingXPPerRank = 0.05

function MasterBuilderConfig.TrainingXPBonus(rank: number): number
	return MasterBuilderConfig.TrainingXPPerRank * math.max(0, rank)
end

-- Worker tiers a Master Builder rank unlocks for Worker Crates (WorkerConfig.CrateTierMinRank is the source; this is the lookup).
function MasterBuilderConfig.WorkerTierUnlocked(rank: number, tierId: string): boolean
	local WorkerConfig = require(script.Parent.WorkerConfig)
	return rank >= (WorkerConfig.CrateTierMinRank[tierId] or 0)
end

-- What the player owns permanently at `rank` (every milestone up to and including it).
function MasterBuilderConfig.Permanents(rank: number): ({ string }, boolean, boolean)
	local vehicles: { string } = {}
	local worker, project = false, false
	for r = 1, rank do
		local m = MasterBuilderConfig.Milestones[r]
		if m then
			if m.Vehicle then
				table.insert(vehicles, m.Vehicle)
			end
			worker = worker or m.Worker == true
			project = project or m.MasterProject == true
		end
	end
	return vehicles, worker, project
end

export type Row = { Label: string, Have: number, Need: number, Done: boolean }

-- Turns a rank definition + PlayerData-shaped table into requirement rows.
function MasterBuilderConfig.Requirements(rank: any, data: any): { Row }
	-- required lazily so this config has no load-order dependencies
	local BuildConfig = require(script.Parent.BuildConfig)
	local UpgradeConfig = require(script.Parent.UpgradeConfig)
	local TrainingConfig = require(script.Parent.TrainingConfig)
	local stats = data.Stats or {}
	local rows: { Row } = {}
	local function add(label: string, have: number, need: number?)
		if need and need > 0 then
			table.insert(rows, { Label = label, Have = have, Need = need, Done = have >= need })
		end
	end
	add("Builds completed", stats.BuildsCompleted or 0, rank.MinBuildsCompleted)
	local levels, maxed = 0, 0
	for id, u in UpgradeConfig.Upgrades do
		local lv = (data.Upgrades or {})[id] or 0
		levels += lv
		if lv >= u.MaxLevel then
			maxed += 1
		end
	end
	add("Total upgrade levels", levels, rank.MinTotalUpgradeLevels)
	local tr = data.Training or {}
	add("Strength level", TrainingConfig.Level("Strength", tr.Strength or 0), rank.MinStrengthLevel)
	add("Speed level", TrainingConfig.Level("Speed", tr.Speed or 0), rank.MinSpeedLevel)
	local permanentTotal, permanentFound = 0, 0
	for _, def in BuildConfig.Builds do
		if def.Enabled and def.Season == nil and not def.MasterProject and not def.Forgotten then
			permanentTotal += 1
			local e = (data.BuildIndex or {})[def.Id]
			if e and e.Discovered then
				permanentFound += 1
			end
		end
	end
	if rank.MinIndexCount then
		add("Build Index builds discovered", permanentFound, rank.MinIndexCount)
	end
	local mpDone, mpUnique = 0, 0
	for _, rec in data.MasterArchive or {} do
		local n = rec.TimesCompleted or 0
		if n > 0 then
			mpDone += n
			mpUnique += 1
		end
	end
	add("Master Project completions", mpDone, rank.MinMasterCompletions)
	add("Unique Master Projects completed", mpUnique, rank.MinUniqueMasterProjects)
	return rows
end

-- True when every requirement row is met.
function MasterBuilderConfig.Meets(rank: any, data: any): boolean
	for _, row in MasterBuilderConfig.Requirements(rank, data) do
		if not row.Done then
			return false
		end
	end
	return true
end

-- Seconds until the next advance is allowed (0 = now).
function MasterBuilderConfig.CooldownLeft(data: any): number
	local last = data.MasterBuilder.LastAdvancedAt or 0
	if last <= 0 or MasterBuilderConfig.CooldownDays <= 0 then
		return 0
	end
	return math.max(0, last + MasterBuilderConfig.CooldownDays * 86400 - os.time())
end

-- Makes sure every permanent unlock for the player's rank is present in the data (used after resets and on load).
function MasterBuilderConfig.ApplyPermanents(data: any)
	local rank = data.MasterBuilder.Rank or 0
	local vehicles, worker = MasterBuilderConfig.Permanents(rank)
	data.MasterBuilder.Vehicles = data.MasterBuilder.Vehicles or {}
	for _, id in vehicles do
		data.MasterBuilder.Vehicles[id] = true -- permanent, separate from the purchasable (and resettable) Vehicles.Owned
	end
	data.Unlocks = data.Unlocks or {}
	for r = 1, rank do
		local m = MasterBuilderConfig.Milestones[r]
		if m and m.Flag then
			data.Unlocks[m.Flag] = true
		end
	end
	if worker then
		data.Worker.Unlocked = true
	end
end

-- Applies a Master Builder advancement to PlayerData IN PLACE (pure data; MasterBuilderService decides when and grants
-- the cosmetics). Resets Coins, purchased upgrades, Worker and vehicles; keeps the Build Index, achievements, titles,
-- cosmetics and stats; keeps TrainingRetention of Strength/Speed LEVELS (rounded down); bumps the rank; then restores
-- the permanent unlocks. Returns (ok, reason).
function MasterBuilderConfig.Advance(data: any, ignoreCooldown: boolean?): (boolean, string)
	local nextRank = (data.MasterBuilder.Rank or 0) + 1
	local rank = MasterBuilderConfig.Ranks[nextRank]
	if not rank then
		return false, "max rank"
	end
	if not MasterBuilderConfig.Meets(rank, data) then
		return false, "requirements not met"
	end
	if not ignoreCooldown and MasterBuilderConfig.CooldownLeft(data) > 0 then
		return false, "cooldown"
	end
	local TrainingConfig = require(script.Parent.TrainingConfig)
	local UpgradeConfig = require(script.Parent.UpgradeConfig)
	local WorkerConfig = require(script.Parent.WorkerConfig)
	local EconomyConfig = require(script.Parent.EconomyConfig)
	data.Coins = EconomyConfig.StartingCoins
	for id in UpgradeConfig.Upgrades do
		data.Upgrades[id] = 0
	end
	local outfit = data.Worker.Outfit or WorkerConfig.DefaultOutfit
	-- the Worker collection (types and tiers) resets; Worker Tokens (duplicate currency) are permanent so nothing is wasted
	data.Worker = {
		Unlocked = false,
		Type = WorkerConfig.DefaultType,
		Tier = WorkerConfig.DefaultTier,
		Assignment = "Auto",
		Enabled = true,
		Level = 0,
		OwnedTypes = { [WorkerConfig.DefaultType] = true },
		Owned = {},
		Tokens = (data.Worker and data.Worker.Tokens) or 0,
		CrateCount = 0,
		Outfit = outfit,
	}
	data.Vehicles = { Owned = {}, Equipped = nil }
	for statId, def in TrainingConfig.Stats do
		local level = TrainingConfig.Level(statId, data.Training[statId] or 0)
		local kept = math.floor(level * MasterBuilderConfig.TrainingRetention)
		data.Training[statId] = TrainingConfig.PointsFor(statId, math.min(kept, def.MaxLevel))
	end
	data.MasterBuilder.Rank = nextRank
	data.MasterBuilder.LastAdvancedAt = os.time()
	MasterBuilderConfig.ApplyPermanents(data)
	return true, "advanced"
end

return MasterBuilderConfig
