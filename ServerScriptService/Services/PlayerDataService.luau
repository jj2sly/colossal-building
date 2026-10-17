--!strict
-- Server-authoritative persistent player data.
--
-- * Versioned schema (SCHEMA_VERSION + Migrate) with defaults filled in for new fields.
-- * Loads with retries. If loading fails, the player plays on defaults but their
--   profile is flagged SaveBlocked so we NEVER overwrite real saved data with defaults.
-- * Lightweight session lock: a profile written by another live server in the last
--   LOCK_TTL seconds is retried before being taken over.
-- * In Studio without API access, falls back to an in-memory mock store so testing
--   still works (the Output explains why nothing persists).
--
-- Persisted: Coins, upgrades, worker, vehicles, Build Index, stats, Master Builder rank
-- and permanent unlocks. NOT persisted: Server Luck, build progress, events (live only).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local Signal = require(Shared.Util.Signal)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local WorkerConfig = require(Shared.Config.WorkerConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local GameConfig = require(Shared.Config.GameConfig)
local TrainingConfig = require(Shared.Config.TrainingConfig)

local SCHEMA_VERSION = 2
local STORE_NAME = "MegaBuild_PlayerData_v1"
local AUTOSAVE_INTERVAL = 120
local LOCK_TTL = 300
local LOAD_RETRIES = 4

type Profile = {
	Data: any,
	Loaded: boolean,
	SaveBlocked: boolean,
	Dirty: boolean,
	SyncQueued: boolean,
	CoinsQueued: boolean,
	LightSyncQueued: boolean,
}

local PlayerDataService = {}
PlayerDataService.Loaded = Signal.new() -- (player, data)

local profiles: { [Player]: Profile } = {}
local store: DataStore? = nil
local mockStore: { [string]: any } = {}
local useMock = false
local simulateLoadFailure = false -- dev-only test switch (see SetSimulateLoadFailure)

local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in t do
		c[k] = deepCopy(v)
	end
	return c
end

local function defaults(): any
	local upgrades = {}
	for id in UpgradeConfig.Upgrades do
		upgrades[id] = 0
	end
	return {
		Version = SCHEMA_VERSION,
		Coins = EconomyConfig.StartingCoins,
		Upgrades = upgrades,
		Training = { Strength = 0, Speed = 0 },
		TrainingMilestones = {}, -- "Strength10" ... claimed level milestones (TrainingConfig.Milestones)
		Worker = { Unlocked = false, Type = WorkerConfig.DefaultType, Tier = WorkerConfig.DefaultTier, Assignment = "Auto", Enabled = true, Level = 0, OwnedTypes = { [WorkerConfig.DefaultType] = true }, Owned = {}, Tokens = 0, CrateCount = 0, Outfit = WorkerConfig.DefaultOutfit },
		Vehicles = { Owned = {}, Equipped = nil },
		BuildIndex = {},
		ForgottenComplete = false, -- permanent flag: all six Forgotten recorded (never replicated)
		ForgottenArchive = {}, -- Forgotten records (own discoveries only): id -> { Discovered, Id, Tier, Name, TimesCompleted, BestContributionPct, FastestCompletion, FirstAt }
		MasterArchive = {}, -- Master Project records: id -> { Discovered, TimesCompleted, BestContributionPct, FastestCompletion }
		Stats = {
			BuildsCompleted = 0,
			LifetimeResources = 0,
			LifetimeContribution = 0,
			LifetimeRepairs = 0,
			CoinsEarned = 0,
			MVPCount = 0,
			CompletedByRarity = {},
		},
		EquippedTitle = "",
		MasterBuilder = { Rank = 0, LastAdvancedAt = 0 },
		Unlocks = {},
		Badges = {},
		Titles = {},
		-- cosmetic ownership by category: Cosmetics.<Category>[id] = true (WorkerOutfit is live; the others are granted and stored,
		-- their equip hooks are future work). Equipped holds the selected id per category.
		Cosmetics = { WorkerOutfit = {}, Trail = {}, VehicleSkin = {}, CarryEffect = {}, ContributionEffect = {} },
		Equipped = {},
		Milestones = {}, -- claimed Index milestone ids (IndexConfig)
		DropLog = {}, -- personal rare drops found (DropConfig): id -> count
		Purchases = { Passes = {}, Receipts = {} }, -- MonetizationConfig: owned passes + processed receipt ids (duplicate protection)
		Boosts = {}, -- running personal boosts: Kind -> { Amount, Until }
		Daily = { LastClaimDay = 0, Claims = 0, LastSeenDay = 0 }, -- DailyConfig: UTC day numbers, claim count drives the 7-day cycle
		Achievements = {},
		Tutorial = { Done = false },
	}
end

-- Fill missing keys from defaults (recursively) so new schema fields appear safely.
local function reconcile(data: any, template: any)
	for k, v in template do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
end

local function migrate(data: any): any
	-- v2: Carry Capacity / Walk Speed upgrades became Strength / Speed training. Convert any bought
	-- levels into starting training points so nobody loses progress, then drop the old keys.
	if (data.Version or 1) < 2 then
		data.Training = data.Training or { Strength = 0, Speed = 0 }
		for legacyId, map in TrainingConfig.Legacy do
			local lvl = data.Upgrades and data.Upgrades[legacyId]
			if type(lvl) == "number" and lvl > 0 then
				local stat = TrainingConfig.Stats[map.Stat]
				local target = math.min(stat.MaxLevel, math.floor(lvl * map.LevelsPer))
				data.Training[map.Stat] = math.max(data.Training[map.Stat] or 0, TrainingConfig.PointsFor(map.Stat, target))
			end
		end
	end
	if data.Upgrades then
		for legacyId in TrainingConfig.Legacy do
			data.Upgrades[legacyId] = nil
		end
	end
	data.Version = SCHEMA_VERSION
	return data
end

local function keyFor(player: Player): string
	return "u_" .. player.UserId
end

local function setupStore()
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
		-- Probe: in Studio without "Enable Studio Access to API Services" this errors.
		local probeOk, err = pcall(function()
			(result :: DataStore):GetAsync("__probe")
		end)
		if not probeOk then
			if RunService:IsStudio() then
				useMock = true
				warn("[PlayerData] DataStore unavailable in Studio (" .. tostring(err) .. "). Using in-memory mock; data won't persist between test sessions.")
			else
				warn("[PlayerData] DataStore probe failed: " .. tostring(err))
			end
		end
	else
		useMock = RunService:IsStudio()
		warn("[PlayerData] GetDataStore failed: " .. tostring(result))
	end
end

-- Returns data or nil + error. Applies the session lock.
local function loadRaw(player: Player): (any, string?)
	if simulateLoadFailure then
		return nil, "simulated load failure"
	end
	local key = keyFor(player)
	if useMock then
		return deepCopy(mockStore[key]), nil
	end
	if not store then
		return nil, "no store"
	end
	local loaded: any = nil
	local lockedByOther = false
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key, function(old)
			old = old or nil
			lockedByOther = false
			if old and old.Session and old.Session.JobId ~= game.JobId and os.time() - (old.Session.Time or 0) < LOCK_TTL then
				lockedByOther = true
				loaded = old
				return nil -- don't write; we'll retry
			end
			local d = old or defaults()
			d.Session = { JobId = game.JobId, Time = os.time() }
			loaded = d
			return d
		end)
	end)
	if not ok then
		return nil, tostring(err)
	end
	if lockedByOther then
		return nil, "locked"
	end
	return loaded, nil
end

local function saveRaw(player: Player, profile: Profile, release: boolean): boolean
	if profile.SaveBlocked or not profile.Loaded then
		return false
	end
	local key = keyFor(player)
	local snapshot = deepCopy(profile.Data)
	if useMock then
		mockStore[key] = snapshot
		return true
	end
	if not store then
		return false
	end
	local ok, err = pcall(function()
		(store :: DataStore):UpdateAsync(key, function(old)
			-- Refuse to overwrite if another server has taken the session.
			if old and old.Session and old.Session.JobId ~= game.JobId and os.time() - (old.Session.Time or 0) < LOCK_TTL then
				return nil
			end
			snapshot.Session = if release then nil else { JobId = game.JobId, Time = os.time() }
			return snapshot
		end)
	end)
	if not ok then
		warn("[PlayerData] save failed for", player.Name, err)
	end
	return ok
end

-- A player who left while their profile was loading: loadRaw already stamped this server's session lock, and nothing will
-- save (and release) it, so clear it now or their next server sees the profile as locked for LOCK_TTL and blocks saving.
local function releaseLock(player: Player)
	if useMock or not store then
		return
	end
	pcall(function()
		(store :: DataStore):UpdateAsync(keyFor(player), function(old)
			if old and old.Session and old.Session.JobId == game.JobId then
				old.Session = nil
				return old
			end
			return nil
		end)
	end)
end

local function applyPublicAttributes(player: Player, data: any)
	player:SetAttribute("Coins", math.floor(data.Coins))
	local ls = player:FindFirstChild("leaderstats")
	local coins = ls and ls:FindFirstChild("Coins")
	if coins then
		(coins :: IntValue).Value = math.floor(data.Coins)
	end
end

local function makeLeaderstats(player: Player)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Parent = ls
	local built = Instance.new("IntValue")
	built.Name = "Built"
	built.Parent = ls
	ls.Parent = player
end

local function onPlayerAdded(player: Player)
	makeLeaderstats(player)
	local profile: Profile = { Data = defaults(), Loaded = false, SaveBlocked = false, Dirty = false, SyncQueued = false, CoinsQueued = false, LightSyncQueued = false }
	profiles[player] = profile

	local data, err = nil, nil
	for attempt = 1, LOAD_RETRIES do
		data, err = loadRaw(player)
		if data ~= nil or (err == nil and useMock) then
			break
		end
		if not player.Parent then
			break
		end
		task.wait(attempt * 1.5)
	end
	if not player.Parent then
		if data ~= nil then
			releaseLock(player)
		end
		profiles[player] = nil
		return
	end
	if err ~= nil and data == nil then
		-- Could not load: play on defaults but never save over the real profile.
		profile.SaveBlocked = true
		warn("[PlayerData] load failed for", player.Name, err, "- saving disabled this session")
		Net.Event("Notify"):FireClient(player, "Error", "Your data couldn't load. Progress this session won't save. Try rejoining later.")
	elseif data ~= nil then
		data.Session = nil
		reconcile(data, defaults())
		profile.Data = migrate(data)
	end
	profile.Loaded = true
	player:SetAttribute("DataLoaded", true)
	applyPublicAttributes(player, profile.Data)
	PlayerDataService.Loaded:Fire(player, profile.Data)
	PlayerDataService.Sync(player)
end

function PlayerDataService.Init()
	setupStore()
end

function PlayerDataService.Start()
	local syncLimiter = Net.RateLimiter(0.5, 2)
	Net.Event("RequestSync").OnServerEvent:Connect(function(player)
		if syncLimiter(player) and PlayerDataService.IsLoaded(player) then
			PlayerDataService.Sync(player)
		end
	end)
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		local profile = profiles[player]
		if profile then
			saveRaw(player, profile, true)
			profiles[player] = nil
		end
	end)
	game:BindToClose(function()
		local threads = 0
		for player, profile in profiles do
			threads += 1
			task.spawn(function()
				saveRaw(player, profile, true)
				threads -= 1
			end)
		end
		local t = os.clock()
		while threads > 0 and os.clock() - t < 25 do
			task.wait(0.1)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player, profile in profiles do
				if profile.Dirty then
					profile.Dirty = false
					task.spawn(function()
						if not saveRaw(player, profile, false) and not profile.SaveBlocked and profiles[player] == profile then
							profile.Dirty = true -- retry on the next autosave instead of silently dropping the changes
						end
					end)
				end
			end
		end
	end)
end

function PlayerDataService.Get(player: Player): any?
	local p = profiles[player]
	return p and p.Loaded and p.Data or nil
end

function PlayerDataService.IsLoaded(player: Player): boolean
	local p = profiles[player]
	return p ~= nil and p.Loaded
end

-- Mark data changed: schedules an autosave and a (coalesced) private sync to the client.
-- `light` = only Coins/lifetime stats moved (every deposit): the public Coins attribute still
-- updates within 0.3 s, but the ~2-4 KB private sync is held back to one per LIGHT_SYNC_INTERVAL
-- (at 50 depositing players the full sync every 0.3 s was the largest single traffic source).
local LIGHT_SYNC_INTERVAL = 3
function PlayerDataService.MarkDirty(player: Player, light: boolean?)
	local p = profiles[player]
	if not p then
		return
	end
	p.Dirty = true
	if light then
		if not p.CoinsQueued then
			p.CoinsQueued = true
			task.delay(0.3, function()
				p.CoinsQueued = false
				if profiles[player] == p then
					applyPublicAttributes(player, p.Data)
				end
			end)
		end
		if not p.LightSyncQueued then
			p.LightSyncQueued = true
			task.delay(LIGHT_SYNC_INTERVAL, function()
				p.LightSyncQueued = false
				if profiles[player] == p then
					PlayerDataService.Sync(player)
				end
			end)
		end
		return
	end
	-- Coalesce: the public Coins attribute and the private sync go out at most every
	-- 0.3 s per player, no matter how many deposits/purchases happen in between.
	if not p.SyncQueued then
		p.SyncQueued = true
		task.delay(0.3, function()
			p.SyncQueued = false
			if profiles[player] == p then
				applyPublicAttributes(player, p.Data)
				PlayerDataService.Sync(player)
			end
		end)
	end
end

function PlayerDataService.Sync(player: Player)
	local p = profiles[player]
	if not p then
		return
	end
	local d = p.Data
	Net.Event("PlayerSync"):FireClient(player, {
		Coins = d.Coins,
		Upgrades = d.Upgrades,
		Training = d.Training,
		Worker = d.Worker,
		Vehicles = d.Vehicles,
		BuildIndex = d.BuildIndex,
		MasterArchive = d.MasterArchive,
		ForgottenArchive = d.ForgottenArchive,
		Stats = d.Stats,
		MasterBuilder = d.MasterBuilder,
		Tutorial = d.Tutorial,
		Achievements = d.Achievements,
		Titles = d.Titles,
		EquippedTitle = d.EquippedTitle,
		Cosmetics = d.Cosmetics,
		Equipped = d.Equipped,
		Milestones = d.Milestones,
		Daily = d.Daily,
		Passes = d.Purchases.Passes,
		Boosts = d.Boosts,
		SaveBlocked = p.SaveBlocked,
	})
end

function PlayerDataService.AddCoins(player: Player, amount: number)
	local d = PlayerDataService.Get(player)
	if not d or amount == 0 then
		return
	end
	d.Coins = math.max(0, d.Coins + amount)
	if amount > 0 then
		d.Stats.CoinsEarned += amount
	end
	PlayerDataService.MarkDirty(player, true)
end

function PlayerDataService.TrySpend(player: Player, amount: number): boolean
	local d = PlayerDataService.Get(player)
	if not d or amount < 0 or d.Coins < amount then
		return false
	end
	d.Coins -= amount
	PlayerDataService.MarkDirty(player)
	return true
end

-- Test helper: save, then load the profile back from the store (real or mock) through
-- the normal reconcile/migrate path, replacing the in-memory copy. Proves round-trips.
function PlayerDataService.DebugReload(player: Player): string
	local p = profiles[player]
	if not p then
		return "no profile"
	end
	if not saveRaw(player, p, false) then
		return "save failed or blocked"
	end
	local data, err = loadRaw(player)
	if data == nil then
		return "load failed: " .. tostring(err)
	end
	data.Session = nil
	reconcile(data, defaults())
	p.Data = migrate(data)
	applyPublicAttributes(player, p.Data)
	PlayerDataService.Loaded:Fire(player, p.Data)
	PlayerDataService.Sync(player)
	return (if useMock then "mock" else "datastore") .. " round-trip ok, coins=" .. math.floor(p.Data.Coins)
end

function PlayerDataService.IsMock(): boolean
	return useMock
end

-- ---- dev/test helpers (reachable only through the gated DebugService) -----------------
function PlayerDataService.SetSimulateLoadFailure(value: boolean)
	if GameConfig.IsDev() then
		simulateLoadFailure = value
	end
end

-- Raw stored profile for a UserId (bypasses memory) so tests can verify what actually
-- persisted. Returns a table or nil + message.
function PlayerDataService.DebugReadStored(userId: number): (any, string?)
	if not GameConfig.IsDev() then
		return nil, "dev only"
	end
	local key = "u_" .. userId
	if useMock then
		return deepCopy(mockStore[key]), nil
	end
	if not store then
		return nil, "no store"
	end
	local ok, result = pcall(function()
		return (store :: DataStore):GetAsync(key)
	end)
	if not ok then
		return nil, tostring(result)
	end
	return result, nil
end

function PlayerDataService.SaveNow(player: Player)
	local p = profiles[player]
	if p then
		saveRaw(player, p, false)
	end
end

return PlayerDataService
