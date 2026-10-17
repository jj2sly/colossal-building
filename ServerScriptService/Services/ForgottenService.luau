--!nonstrict
-- FORGOTTEN TIER FRAMEWORK (no Forgotten structures exist yet; F1-F6 will be plain entries in ForgottenService.Entries).
-- Forgotten is a hidden tier above Mythic, completely apart from the 40-build collection and the normal rarity pools:
--   * Entries live ONLY here (server). The client never receives a list, a count, a name or a preview; it only gets the
--     player's OWN discovered records (PlayerData.ForgottenArchive, synced as `ForgottenArchive`) and a one-off
--     "ForgottenDiscovered" effect when a record is first created.
--   * A Forgotten build is a BuildConfig entry with Forgotten = true. BuildConfig.Eligible / vote / Legacy / index lists all skip
--     Forgotten builds, so they can never enter the normal pool or the every-5-build vote; only this service can start one.
--   * Entry fields:
--       Id            "F1"
--       Tier          "F1".."F6" (display only)
--       Build         BuildConfig id of the structure (BuildConfig entry has Forgotten = true) — nil = framework/dev entry
--       Name          the real name (never replicated until personally discovered)
--       Enabled       bool
--       Unlock        { MinServerLuck, MinBuildCount, MinCombinedRank, MinMasterPlayers, Secret, EventId, Cooldown } (all optional;
--                     same meaning as MasterProjectConfig; Secret = a secret resource id the server must have unlocked)
--       FakeAs        optional rarity name to roll first ("Mythic") for the fake-out reveal: MYTHIC -> ??? -> FORGOTTEN
--       Discovery     optional first-discovery reward { Coins = n, Cosmetic = { Category, Item } }
--   * Reveal path (client): ??? -> FORGOTTEN STRUCTURE DISCOVERED -> build name (RevealController.ShowForgotten).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local BuildConfig = require(Shared.Config.BuildConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local SecretResourceConfig = require(Shared.Config.SecretResourceConfig)
local Formulas = require(Shared.Formulas)
local Players = game:GetService("Players")

local ForgottenService = {}
local S: any

-- IDENTITY MASKING: an entry's Id is an OPAQUE key (never "F1"); it is also the BuildConfig id and the template name. The full
-- BuildConfig definition (`Def`) is registered into the SERVER's BuildConfig.Builds at Init only, so the client's BuildConfig never
-- contains a Forgotten name, requirement, template or stage name. A player receives the real identity (Name, stage names,
-- activation points) only through ForgottenService.SendIdentity, after they personally hold a record.
local NO_MODS = {}
ForgottenService.Entries = {
	{
		Id = "Fg7a", Tier = "F1", Build = "Fg7a", Name = "Orbital Space Cannon", Enabled = true, FakeAs = "Mythic",
		Gate = { Weight = 1.00 }, -- no progression gate beyond the global Forgotten requirements; Mythic fake-out reveal
		Discovery = { Coins = 5000 },
		Def = {
			Id = "Fg7a", DisplayName = "Orbital Space Cannon", Rarity = "Forgotten",
			Description = "An ancient orbital cannon: an enormous angled barrel on a rotating base, with a charge chamber and two giant rings. It wakes in stages as it rises; finish it and it fires once into the sky.",
			Requirements = { Metal = 3000, MetalBeams = 6000, HeavySteel = 12000, PowerCell = 2500, Cells = 4500, EnergyCore = 11000, Stone = 1500, StoneBlocks = 3500, Boulders = 5400, Logs = 1000, StarMetal = 5600 },
			RewardMultiplier = 1, Template = "Fg7a", CompletionSpectacle = "Fg7aShow",
			StageNames = { "Buried Foundation", "Rotator Platform", "Rear Support", "Charge Chamber", "Lower Barrel", "Upper Barrel", "Ring I", "Ring II", "Power Banks", "Targeting Spine", "Star Metal Conduits", "Final Crown" },
			Thumbnail = "?", SpecialMechanic = nil, EligibleModifiers = NO_MODS,
			MinimumServerLuck = 0, Tags = { "SciFi", "Monument" }, EstimatedDifficulty = 10, Enabled = true, Forgotten = true,
			TemplateScale = 1, Yaw = 0, Footprint = { Width = 237, Depth = 162, Height = 221 }, ActivateAt = 0.25, Milestones = { 0.58, 0.68, 0.83, 0.91 },
		},
	},
	{
		Id = "Fg3c", Tier = "F2", Build = "Fg3c", Name = "World Engine", Enabled = true, FakeAs = nil,
		Gate = { Weight = 1.00, MinNormal = 8 },
		Discovery = { Coins = 5000 },
		Def = {
			Id = "Fg3c", DisplayName = "World Engine", Rarity = "Forgotten",
			Description = "A gigantic ancient engine: a central axle and core inside nested rings, gears and counterweights. It wakes in stages as it rises; finish it and every mechanism synchronises into one huge pulse.",
			Requirements = { Metal = 2500, MetalBeams = 5000, HeavySteel = 10000, PowerCell = 2500, Cells = 4500, EnergyCore = 10000, Stone = 2000, StoneBlocks = 5000, Boulders = 8900, StarMetal = 5600 },
			RewardMultiplier = 1, Template = "Fg3c", CompletionSpectacle = "Fg3cShow",
			StageNames = { "Foundation Vault", "Central Axle", "Outer Frame", "Gear I", "Gear II", "Vertical Ring", "Horizontal Ring", "Inner Mechanism", "Lower Core", "Upper Core", "Counterweights", "Star Metal Synchronizers", "Engine Crown" },
			Thumbnail = "?", SpecialMechanic = nil, EligibleModifiers = NO_MODS,
			MinimumServerLuck = 0, Tags = { "SciFi", "Mechanical", "Monument" }, EstimatedDifficulty = 10, Enabled = true, Forgotten = true,
			TemplateScale = 1, Yaw = 0, Footprint = { Width = 222, Depth = 196, Height = 265 }, ActivateAt = 0.17, Milestones = { 0.33, 0.56, 0.87, 0.94 },
		},
	},
	{
		Id = "Fg9e", Tier = "F3", Build = "Fg9e", Name = "Buried Titan", Enabled = true, FakeAs = nil,
		Gate = { Weight = 0.85, MinNormal = 10, Earthquake = true },
		Discovery = { Coins = 5000 },
		Def = {
			Id = "Fg9e", DisplayName = "Buried Titan", Rarity = "Forgotten",
			Description = "An ancient colossal construct, buried long ago. The crew excavates and reassembles what is rising from beneath the site; finish it and it wakes.",
			Requirements = { Metal = 2000, MetalBeams = 4500, HeavySteel = 8500, PowerCell = 2000, Cells = 3500, EnergyCore = 8900, Stone = 2500, StoneBlocks = 6500, Boulders = 12000, StarMetal = 5600 },
			RewardMultiplier = 1, Template = "Fg9e", CompletionSpectacle = "Fg9eShow",
			StageNames = { "Excavation Ring", "Buried Hand", "Second Arm", "Shoulders", "Upper Torso", "Chest Cavity", "Neck", "Head", "Crown / Helmet", "Star Metal Core", "Back Structures", "Final Excavation" },
			Thumbnail = "?", SpecialMechanic = nil, EligibleModifiers = NO_MODS,
			MinimumServerLuck = 0, Tags = { "Fantasy", "Monument" }, EstimatedDifficulty = 10, Enabled = true, Forgotten = true,
			TemplateScale = 0.8, Yaw = 0, Footprint = { Width = 230, Depth = 171, Height = 218 }, ActivateAt = 0.2, Milestones = { 0.52, 0.84, 0.92 },
		},
	},
	{
		Id = "Fg4b", Tier = "F4", Build = "Fg4b", Name = "Lost Sky Temple", Enabled = true, FakeAs = nil,
		Gate = { Weight = 0.70, MinNormal = 12, AnyPlayerSecret = "AncientTimber" },
		Discovery = { Coins = 5000 },
		Def = {
			Id = "Fg4b", DisplayName = "Lost Sky Temple", Rarity = "Forgotten",
			Description = "The broken remains of an ancient temple that cannot stay in the air. The crew raises its separated pieces; finish it and it wakes, still broken, still impossible.",
			Requirements = { Stone = 3000, StoneBlocks = 7000, Boulders = 11000, Logs = 4000, Timber = 6000, PowerCell = 1500, Cells = 3000, EnergyCore = 5000, Metal = 1500, MetalBeams = 3400, HeavySteel = 5000, AncientTimber = 5600 },
			RewardMultiplier = 1, Template = "Fg4b", CompletionSpectacle = "Fg4bShow",
			StageNames = { "Broken Central Platform", "Floating Wing I", "Floating Wing II", "Central Shrine", "Outer Pillars", "Upper Roof", "Floating Stone A", "Floating Stone B", "Suspended Relic", "Ancient Timber Bridges", "Sky Crown" },
			Thumbnail = "?", SpecialMechanic = nil, EligibleModifiers = NO_MODS,
			MinimumServerLuck = 0, Tags = { "Fantasy", "Monument" }, EstimatedDifficulty = 10, Enabled = true, Forgotten = true,
			TemplateScale = 0.82, Yaw = 0, Footprint = { Width = 284, Depth = 162, Height = 244 }, ActivateAt = 0.22, Milestones = { 0.46, 0.84, 0.92 },
		},
	},
	{
		Id = "Fg6d", Tier = "F5", Build = "Fg6d", Name = "Ancient Robloxian Colossus", Enabled = true, FakeAs = nil,
		Gate = { Weight = 0.85, MinNormal = 12, AnyPlayerSecret = "StarMetal" },
		Discovery = { Coins = 5000 },
		Def = {
			Id = "Fg6d", DisplayName = "Ancient Robloxian Colossus", Rarity = "Forgotten",
			Description = "A gigantic ceremonial monument in classic block-character proportions, studded and impossibly old. It wakes in stages as it rises; finish it and the ancient statue stirs.",
			Requirements = { Stone = 3500, StoneBlocks = 7000, Boulders = 10500, Metal = 2500, MetalBeams = 6000, HeavySteel = 9500, PowerCell = 1500, Cells = 3000, EnergyCore = 6900, StarMetal = 5600 },
			RewardMultiplier = 1, Template = "Fg6d", CompletionSpectacle = "Fg6dShow",
			StageNames = { "Studded Base", "Feet", "Legs", "Torso", "Left Arm", "Right Arm", "Head", "Helmet / Crown", "Back Monument", "Star Metal Heart", "Giant Studded Tool", "Ancient Finish" },
			Thumbnail = "?", SpecialMechanic = nil, EligibleModifiers = NO_MODS,
			MinimumServerLuck = 0, Tags = { "Fantasy", "Monument" }, EstimatedDifficulty = 10, Enabled = true, Forgotten = true,
			TemplateScale = 1, Yaw = 0, Footprint = { Width = 244, Depth = 148, Height = 295 }, ActivateAt = 0.3, Milestones = { 0.5, 0.86, 0.93 },
		},
	},
	{
		Id = "Fg8m", Tier = "F6", Build = "Fg8m", Name = "Impossible Machine", Enabled = true, FakeAs = "Mythic",
		Gate = { Weight = 0.55, MinNormal = 16, MinServerLuck = 40, AnyPlayerRecords = 2 },
		Discovery = { Coins = 5000 },
		Def = {
			Id = "Fg8m", DisplayName = "Impossible Machine", Rarity = "Forgotten",
			Description = "A machine whose geometry contradicts itself: overlapping rails, loops that cannot close, a core hung in an open void. It wakes out of step with itself; finish it and it settles into a slow impossible idle.",
			Requirements = { Metal = 3000, MetalBeams = 6500, HeavySteel = 10000, PowerCell = 2500, Cells = 4500, EnergyCore = 10000, Stone = 1500, StoneBlocks = 4000, Boulders = 8400, StarMetal = 5600 },
			RewardMultiplier = 1, Template = "Fg8m", CompletionSpectacle = "Fg8mShow",
			StageNames = { "Base Frame", "Outer Square Loop", "Circle I", "Vertical Rail", "Suspended Block", "Circle II", "Counterweight Tower", "Diagonal Frame", "Core", "Upper Mechanism", "Reverse Gear", "Floating Connector", "Final Loop", "Paradox Core" },
			Thumbnail = "?", SpecialMechanic = nil, EligibleModifiers = NO_MODS,
			MinimumServerLuck = 0, Tags = { "SciFi", "Mechanical", "Monument" }, EstimatedDifficulty = 10, Enabled = true, Forgotten = true,
			TemplateScale = 1, Yaw = 0, Footprint = { Width = 262, Depth = 213, Height = 261 }, ActivateAt = 0.25, Milestones = { 0.40, 0.55, 0.82, 0.93 },
		},
	},
}
-- Framework test entry (Studio / dev only): has no build, so it can be "discovered" through the debug bridge but never started.
local DEV_ENTRY = { Id = "F0", Tier = "F0", Name = "Test Forgotten", Enabled = false, Dev = true, FakeAs = "Mythic", Discovery = { Coins = 1000 } }

-- NATURAL ENCOUNTER TUNING (all numbers live here). Forgotten is NOT a RarityConfig tier: it only ever gets a chance to replace an ordinary
-- random Common-Mythic selection (never a vote, a Master Project or any forced/debug selection). Chance values are percentage points.
ForgottenService.Config = {
	MinNormalCompleted = 5, -- ordinary projects completed on this server before any encounter
	MinSinceLast = 5, -- ordinary projects completed since the previous Forgotten project
	BaseChance = 0.50,
	LuckBonusPerPoint = 0.015, -- per Server Luck point
	PressureStartsAfter = 8, -- ordinary projects since the previous encounter
	PressurePerProject = 0.10,
	PressureCap = 2.0,
	PityAt = 30, -- eligible ordinary selections without an encounter: force one
	UndiscoveredBias = 0.75, -- weight x (1 + bias x fraction of current players who have NOT discovered the entry)
	SecretFallbackSeconds = 90,
}
-- first-discovery rewards waiting for a first legitimate contribution to the SAME active project: player -> entry. Session memory only, cleared
-- when the project ends (forfeited, never carried to a later encounter) and when the player leaves.
ForgottenService.Pending = {} :: { [Player]: any }
-- server-session counters (never replicated)
ForgottenService.Counters = { Normal = 0, Since = 0, Pity = 0, Earthquake = false }

ForgottenService.ForceNext = nil :: string? -- dev override: start this entry next (single use, server runtime only)

function ForgottenService.Init(registry)
	S = registry
	-- server-only registration (this module is never required by the client)
	for _, e in ForgottenService.Entries do
		if e.Def then
			(BuildConfig.Builds :: any)[e.Build] = e.Def
		end
	end
end

-- The identity a discoverer may know: used by the client for the tracker title/stages/markers and the show lookup.
local function identityOf(e: any): any
	local d = e.Def or {}
	return { Key = e.Id, Name = e.Name, Tier = e.Tier, Rarity = "Forgotten", StageNames = d.StageNames, ActivateAt = d.ActivateAt, Milestones = d.Milestones }
end

-- Sends this player every identity they own (join) or one entry (discovery). Nothing is ever sent for an undiscovered entry.
function ForgottenService.SendIdentity(player: Player, id: string?)
	local d = S.PlayerDataService.Get(player)
	local arch = d and d.ForgottenArchive
	if not arch then
		return
	end
	for _, e in ForgottenService.Entries do
		if (id == nil or e.Id == id) and arch[e.Id] then
			Net.Event("Effect"):FireClient(player, "ForgottenIdentity", identityOf(e))
		end
	end
end

function ForgottenService.Start()
	-- soft-lock failsafe (never advertised): an active Forgotten project whose secret lines have NO eligible gatherer for 90 s continuously
	-- may satisfy the remaining secret lines with the matching Tier 3 resource, for that project only
	task.spawn(function()
		local idle = 0
		while true do
			task.wait(5)
			local a = S.BuildService.Get()
			if a and a.def and a.def.Forgotten and not a.secretFallback then
				local needSecret, anyGatherer = false, false
				for res, n in a.need do
					local r = ResourceConfig.Resources[res]
					if r and r.Secret and (a.have[res] or 0) < n then
						needSecret = true
						for _, pl in Players:GetPlayers() do
							local d = S.PlayerDataService.Get(pl)
							if d and SecretResourceConfig.CanAccess(r.Secret, d) then
								anyGatherer = true
							end
						end
					end
				end
				if needSecret and not anyGatherer then
					idle += 5
					if idle >= ForgottenService.Config.SecretFallbackSeconds then
						S.BuildService.EnableSecretFallback()
					end
				else
					idle = 0
				end
			else
				idle = 0
			end
		end
	end)
	-- a returning player gets the identities they already own once their client is up (never anything they have not discovered)
	S.PlayerDataService.Loaded:Connect(function(player)
		task.delay(4, function()
			if player.Parent then
				ForgottenService.SendIdentity(player)
				ForgottenService.OnLateJoin(player)
			end
		end)
	end)
	Players.PlayerRemoving:Connect(function(pl)
		ForgottenService.Pending[pl] = nil
	end)
end

local function find(id: string): any
	for _, e in ForgottenService.Entries do
		if e.Id == id then
			return e
		end
	end
	if GameConfig.IsDev() and id == DEV_ENTRY.Id then
		return DEV_ENTRY
	end
	return nil
end

function ForgottenService.ByBuild(buildId: string): any
	for _, e in ForgottenService.Entries do
		if e.Build == buildId then
			return e
		end
	end
	return nil
end

-- Same context shape as MasterBuilderService.MasterProjectContext() plus what Forgotten conditions need.
local function context(): any
	local ok, ctx = pcall(S.MasterBuilderService.MasterProjectContext)
	return if ok and ctx then ctx else { ServerLuck = S.ServerLuckService.Get(), BuildCount = 0, CombinedRank = 0, MasterPlayers = 0, Secrets = {} }
end

-- DEV/forced start only: the entry named by ForceNext (single use). Natural encounters go through RollNatural.
function ForgottenService.EligibleForgotten(): any
	if ForgottenService.ForceNext then
		local e = find(ForgottenService.ForceNext)
		if e and e.Build and BuildConfig.Get(e.Build) then
			local c = ForgottenService.Counters
			c.Since, c.Pity = 0, 0 -- a Forgotten project starting resets pressure and pity
			return e
		end
	end
	return nil
end

function ForgottenService.NoteNormalCompleted()
	local c = ForgottenService.Counters
	c.Normal += 1
	c.Since += 1
end

function ForgottenService.NoteEvent(id: string)
	if id == "Earthquake" then
		ForgottenService.Counters.Earthquake = true
	end
end

local function recordCount(player: Player): number
	local d = S.PlayerDataService.Get(player)
	local n = 0
	for _, rec in (d and d.ForgottenArchive) or {} do
		if rec.Discovered then
			n += 1
		end
	end
	return n
end

local function anyPlayerHasSecret(secret: string): boolean
	for _, pl in Players:GetPlayers() do
		local d = S.PlayerDataService.Get(pl)
		if d and SecretResourceConfig.CanAccess(secret, d) then
			return true
		end
	end
	return false
end

-- Entry gate check (server only; conditions are never sent to clients).
local function gatePasses(e: any): boolean
	local g, c = e.Gate or {}, ForgottenService.Counters
	if g.MinNormal and c.Normal < g.MinNormal then
		return false
	end
	if g.MinServerLuck and S.ServerLuckService.Get() < g.MinServerLuck then
		return false
	end
	if g.Earthquake and not c.Earthquake then
		return false
	end
	if g.AnyPlayerSecret and not anyPlayerHasSecret(g.AnyPlayerSecret) then
		return false
	end
	if g.AnyPlayerRecords then
		local ok = false
		for _, pl in Players:GetPlayers() do
			if recordCount(pl) >= g.AnyPlayerRecords then
				ok = true
				break
			end
		end
		if not ok then
			return false
		end
	end
	return true
end

function ForgottenService.EligibleEntries(): { any }
	local out = {}
	for _, e in ForgottenService.Entries do
		if e.Enabled and e.Build and BuildConfig.Get(e.Build) and gatePasses(e) then
			table.insert(out, e)
		end
	end
	return out
end

-- chance in percentage points, with its parts
function ForgottenService.Chance(): (number, any)
	local cfg, c = ForgottenService.Config, ForgottenService.Counters
	local luck = S.ServerLuckService.Get()
	local luckBonus = luck * cfg.LuckBonusPerPoint
	local pressure = math.clamp(math.max(0, c.Since - cfg.PressureStartsAfter) * cfg.PressurePerProject, 0, cfg.PressureCap)
	return cfg.BaseChance + luckBonus + pressure, { Base = cfg.BaseChance, Luck = luckBonus, Pressure = pressure }
end

local function effectiveWeight(e: any): number
	local pls = Players:GetPlayers()
	local undiscovered = 0
	for _, pl in pls do
		if not ForgottenService.Has(pl, e.Id) then
			undiscovered += 1
		end
	end
	local frac = if #pls > 0 then undiscovered / #pls else 0
	return ((e.Gate or {}).Weight or 1) * (1 + ForgottenService.Config.UndiscoveredBias * frac)
end

-- Called ONLY where the game would otherwise do an ordinary random Common-Mythic selection. Returns the entry or nil.
function ForgottenService.RollNatural(): any
	local cfg, c = ForgottenService.Config, ForgottenService.Counters
	if c.Normal < cfg.MinNormalCompleted or c.Since < cfg.MinSinceLast then
		return nil
	end
	local list = ForgottenService.EligibleEntries()
	if #list == 0 then
		return nil
	end
	c.Pity += 1 -- an eligible ordinary selection
	local hit = c.Pity >= cfg.PityAt
	if not hit then
		local chance = ForgottenService.Chance()
		hit = math.random() * 100 < chance
	end
	if not hit then
		return nil
	end
	local total = 0
	local ws = {}
	for i, e in list do
		ws[i] = effectiveWeight(e)
		total += ws[i]
	end
	local pick = math.random() * total
	local chosen = list[#list]
	for i, e in list do
		pick -= ws[i]
		if pick <= 0 then
			chosen = e
			break
		end
	end
	c.Since, c.Pity = 0, 0
	return chosen
end

-- Secret-resource lines at START: each scales by the number of players who can actually gather that secret (minimum 1). If NOBODY present
-- can gather it, the line is substituted for this project only with its Tier 3 stand-in (Heavy Steel for Star Metal, Timber for Ancient
-- Timber) so the project never opens with an impossible line. Returns (scales, substitutions). Generic over every Forgotten entry.
function ForgottenService.SecretPlan(def: any): ({ [string]: number }, { [string]: string })
	local scales, subs = {}, {}
	for res in def.Requirements do
		local r = ResourceConfig.Resources[res]
		if r and r.Secret then
			local n = 0
			for _, pl in Players:GetPlayers() do
				local d = S.PlayerDataService.Get(pl)
				if d and SecretResourceConfig.CanAccess(r.Secret, d) then
					n += 1
				end
			end
			local alt = S.BuildService.FallbackOf(res)
			if n == 0 and alt then
				subs[res] = alt
			else
				scales[res] = Formulas.RequirementScale(math.max(1, n))
			end
		end
	end
	return scales, subs
end

function ForgottenService.SecretScales(def: any): { [string]: number }
	local scales = ForgottenService.SecretPlan(def)
	return scales
end

function ForgottenService.Has(player: Player, id: string): boolean
	local d = S.PlayerDataService.Get(player)
	local rec = d and d.ForgottenArchive and d.ForgottenArchive[id]
	return rec ~= nil and rec.Discovered == true
end

-- Records a discovery (and, with `info`, a completion). A NEW record pays the 5,000-Coin first-discovery reward now, or - with
-- `deferReward` - leaves it pending until the player's first legitimate contribution to the active project.
function ForgottenService.Record(player: Player, entry: any, info: any?, play: boolean?, deferReward: boolean?): boolean
	local d = S.PlayerDataService.Get(player)
	if not d or not entry then
		return false
	end
	d.ForgottenArchive = d.ForgottenArchive or {}
	local rec = d.ForgottenArchive[entry.Id]
	local new = rec == nil
	if not rec then
		rec = { Discovered = true, Id = entry.Id, Tier = entry.Tier, Name = entry.Name, TimesCompleted = 0, BestContributionPct = 0, FastestCompletion = nil, FirstAt = os.time() }
		d.ForgottenArchive[entry.Id] = rec
	end
	if info then
		rec.TimesCompleted += 1
		rec.BestContributionPct = math.max(rec.BestContributionPct, math.floor((info.ContributionPct or 0) * 1000) / 10)
		local secs = math.floor(info.CompletionSeconds or 0)
		if rec.FastestCompletion == nil or secs < rec.FastestCompletion then
			rec.FastestCompletion = secs
		end
		d.Stats.BuildsCompleted += 1 -- same progression credit as a Master Project
	end
	S.PlayerDataService.MarkDirty(player)
	if new then
		S.LaunchTelemetryService.Event(player, "ForgottenDiscovery", ForgottenService.OwnCount(player))
		if deferReward then
			ForgottenService.Pending[player] = entry -- paid on the first qualifying contribution of this active project
		else
			ForgottenService.DiscoveryReward(player, entry)
		end
		ForgottenService.CheckArchiveComplete(player)
		ForgottenService.SendIdentity(player, entry.Id)
		if play then -- framework/dev: replay the discovery sequence without a build
			Net.Event("Effect"):FireClient(player, "ForgottenDiscovered", { Play = true, Name = entry.Name, FakeFrom = entry.FakeAs })
		end
		S.PlayerDataService.Sync(player)
	end
	return new
end

-- Reveal-time encounter for one player: records the discovery (once, reward deferred to a first contribution) and returns the per-player
-- Reveal payload (name known only from here on; `Repeat` = they had already discovered it).
function ForgottenService.Encounter(player: Player, entry: any): any
	local isNew = ForgottenService.Record(player, entry, nil, nil, true)
	if not isNew then
		ForgottenService.SendIdentity(player, entry.Id) -- (a new record already sent it) keeps a late-loading client in step
	end
	return { Name = entry.Name, Repeat = not isNew }
end

-- Called by BuildService on a player's accepted deposit / contribution to an active Forgotten project.
function ForgottenService.OnContribution(player: Player)
	local e = ForgottenService.Pending[player]
	if e then
		ForgottenService.Pending[player] = nil -- once: a second contribution never pays again
		ForgottenService.DiscoveryReward(player, e)
	end
end

function ForgottenService.ClearPending()
	table.clear(ForgottenService.Pending)
end

-- A player who loads in while a Forgotten project is already running: a known entry just gets its identity privately (the client then shows the
-- real tier and stage names); an undiscovered one is recorded through the normal encounter path (no fake-out replay) and gets a short
-- discovery moment with its reward pending. Until then they see only the neutral "???" plate.
function ForgottenService.OnLateJoin(player: Player)
	local a = S.BuildService.Get()
	if not (a and a.def and a.def.Forgotten) then
		return
	end
	local entry = ForgottenService.ByBuild(a.def.Id)
	if not entry or not player.Parent then
		return
	end
	local info = ForgottenService.Encounter(player, entry)
	if not info.Repeat then
		Net.Event("Reveal"):FireClient(player, { Forgotten = true, Rarity = "Forgotten", Title = "???", Name = entry.Name, Repeat = false, Late = true, Modifiers = {}, RewardMultiplier = 1, Requirements = {}, RollTime = 3, HoldTime = 4, Candidates = {} })
	end
end

-- All six unique structures recorded for the first time: permanent flags only (cosmetic art/effects come later). Never replicated as a total.
function ForgottenService.CheckArchiveComplete(player: Player)
	local d = S.PlayerDataService.Get(player)
	if not d or d.ForgottenComplete then
		return
	end
	local n = 0
	for _, e in ForgottenService.Entries do
		if d.ForgottenArchive and d.ForgottenArchive[e.Id] and d.ForgottenArchive[e.Id].Discovered then
			n += 1
		end
	end
	if n >= #ForgottenService.Entries and n > 0 then
		d.ForgottenComplete = true
		d.Unlocks = d.Unlocks or {}
		d.Unlocks.Title_KeeperOfLostBuilds = true -- title "Keeper of Lost Builds"
		d.Unlocks.ForgottenAura = true
		d.Unlocks.ForgottenVehicleSkin = true
		d.Unlocks.ForgottenDeliveryEffect = true
		S.PlayerDataService.MarkDirty(player)
	end
end

-- ONE-TIME DISCOVERY REWARD HOOK: data-driven (entry.Discovery); entries without one grant nothing. Extend here, not in UI code.
function ForgottenService.DiscoveryReward(player: Player, entry: any)
	local r = entry.Discovery
	if not r then
		return
	end
	if r.Coins then
		S.PlayerDataService.AddCoins(player, r.Coins)
	end
	if r.Cosmetic and S.CosmeticService and S.CosmeticService.Grant then
		pcall(S.CosmeticService.Grant, player, r.Cosmetic.Category, r.Cosmetic.Item)
	end
end

-- DEV: discover an entry for the calling player without a build (framework smoke test).
function ForgottenService.DevDiscover(player: Player, id: string?): string
	local e = find(id or DEV_ENTRY.Id)
	if not e then
		return "unknown forgotten id"
	end
	return if ForgottenService.Record(player, e, nil, true) then "discovered " .. e.Id else "already discovered " .. e.Id
end

-- What the normal systems may ask without learning anything: how many records THIS player owns (never the registry size).
function ForgottenService.OwnCount(player: Player): number
	local d = S.PlayerDataService.Get(player)
	local n = 0
	for _ in (d and d.ForgottenArchive) or {} do
		n += 1
	end
	return n
end

return ForgottenService
