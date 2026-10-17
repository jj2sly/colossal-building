--!strict
-- Persistent Build Index (collection book). Records each participant's completion:
-- discovery, times completed, best contribution %, fastest completion witnessed,
-- modifiers seen, highest reward and first completion time.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local BuildConfig = require(ReplicatedStorage.Shared.Config.BuildConfig)
local IndexConfig = require(ReplicatedStorage.Shared.Config.IndexConfig)
local CosmeticConfig = require(ReplicatedStorage.Shared.Config.CosmeticConfig)

local BuildIndexService = {}
local S: any

function BuildIndexService.Init(registry)
	S = registry
end

export type CompletionInfo = {
	BuildId: string,
	Modifiers: { string },
	ContributionPct: number,
	CompletionSeconds: number,
	Reward: number,
	IsMVP: boolean,
}

-- Returns true if this was a new discovery for the player.
function BuildIndexService.Record(player: Player, info: CompletionInfo): boolean
	local d = S.PlayerDataService.Get(player)
	if not d then
		return false
	end
	local pdef = BuildConfig.Get(info.BuildId)
	S.LaunchTelemetryService.Milestone(player, "FirstCompletion") -- every completion (regular, Master, Forgotten) is recorded here
	if pdef and pdef.Forgotten then
		-- FORGOTTEN ARCHIVE: separate from the Index and the Master Archive; the first completion IS the personal discovery
		local entry = S.ForgottenService.ByBuild(info.BuildId)
		return entry ~= nil and S.ForgottenService.Record(player, entry, info)
	end
	if pdef and pdef.MasterProject then
		-- MASTER ARCHIVE: separate from the Common-Mythic Index (own record, no rarity stats, no variants)
		d.MasterArchive = d.MasterArchive or {}
		local m = d.MasterArchive[info.BuildId]
		local new = m == nil
		if not m then
			m = { Discovered = true, TimesCompleted = 0, BestContributionPct = 0, FastestCompletion = nil, FirstCompletedAt = os.time() }
			d.MasterArchive[info.BuildId] = m
		end
		m.TimesCompleted += 1
		m.BestContributionPct = math.max(m.BestContributionPct, math.floor(info.ContributionPct * 1000) / 10)
		local secs = math.floor(info.CompletionSeconds)
		if m.FastestCompletion == nil or secs < m.FastestCompletion then
			m.FastestCompletion = secs
		end
		d.Stats.BuildsCompleted += 1 -- progression credit (Master Builder requirements count it)
		S.PlayerDataService.MarkDirty(player)
		S.AchievementService.Check(player)
		if new then
			Net.Event("Notify"):FireClient(player, "Success", "MASTER ARCHIVE: " .. (pdef.DisplayName) .. " recorded!", 6)
		end
		return new
	end
	local entry = d.BuildIndex[info.BuildId]
	local isNew = entry == nil or not entry.Discovered
	if not entry then
		entry = {
			Discovered = true,
			TimesCompleted = 0,
			BestContributionPct = 0,
			FastestCompletion = nil,
			Modifiers = {},
			HighestReward = 0,
			FirstCompletedAt = nil,
		}
		d.BuildIndex[info.BuildId] = entry
	end
	entry.Discovered = true
	entry.TimesCompleted += 1
	entry.BestContributionPct = math.max(entry.BestContributionPct, math.floor(info.ContributionPct * 1000) / 10)
	local secs = math.floor(info.CompletionSeconds)
	if entry.FastestCompletion == nil or secs < entry.FastestCompletion then
		entry.FastestCompletion = secs
	end
	-- per-build VARIANTS: Normal (no modifier) plus each modifier this completion carried
	if #info.Modifiers == 0 then
		entry.Modifiers.Normal = true
	end
	for _, m in info.Modifiers do
		entry.Modifiers[m] = true
	end
	entry.HighestReward = math.max(entry.HighestReward, math.floor(info.Reward))
	entry.FirstCompletedAt = entry.FirstCompletedAt or os.time()
	d.Stats.BuildsCompleted += 1
	local def = BuildConfig.Get(info.BuildId)
	if def then
		d.Stats.CompletedByRarity[def.Rarity] = (d.Stats.CompletedByRarity[def.Rarity] or 0) + 1
	end
	if info.IsMVP then
		d.Stats.MVPCount += 1
	end
	S.PlayerDataService.MarkDirty(player)
	S.AchievementService.Check(player)
	BuildIndexService.CheckMilestones(player)
	S.StatsBoardService.Touch(player)
	if isNew then
		S.LaunchTelemetryService.Milestone(player, "FirstIndexDiscovery")
		Net.Event("Discovery"):FireClient(player, info.BuildId)
	end
	return isNew
end

-- Sum of the permanent rarity-completion bonuses of one kind the player has earned (0 when none). See IndexConfig.RarityBonuses.
function BuildIndexService.Bonus(player: Player, kind: string): number
	local d = S.PlayerDataService.Get(player)
	if not d or not d.Milestones then
		return 0
	end
	local total = 0
	for id, b in IndexConfig.RarityBonuses do
		if b.Kind == kind and d.Milestones[id] then
			total += b.Value
		end
	end
	return total
end

-- Enabled builds as plain tables for IndexConfig.Progress.
local function enabledBuilds(): { any }
	local out = {}
	for _, b in BuildConfig.Builds do
		if b.Enabled and b.Season == nil and not b.MasterProject and not b.Forgotten then
			table.insert(out, { Id = b.Id, Rarity = b.Rarity, EligibleModifiers = b.EligibleModifiers })
		end
	end
	return out
end

-- Grants every newly reached Index milestone reward once (claimed ids persist in PlayerData.Milestones).
function BuildIndexService.CheckMilestones(player: Player)
	local d = S.PlayerDataService.Get(player)
	if not d then
		return
	end
	local builds = enabledBuilds()
	for _, m in IndexConfig.Milestones do
		if not d.Milestones[m.Id] then
			local done = IndexConfig.Progress(m, d, builds)
			if done then
				d.Milestones[m.Id] = true
				S.CosmeticService.Grant(player, m.Reward.Category, m.Reward.Item, "milestone")
				local perk = IndexConfig.RarityBonuses[m.Id]
				Net.Event("Notify"):FireClient(player, "Success", string.format("Index milestone: %s! Reward: %s%s", m.Name, CosmeticConfig.Name(m.Reward.Category, m.Reward.Item), if perk then " + " .. perk.Text else ""), 5)
				if perk and perk.Kind == "Luck" then
					S.ResourceService.RefreshCapacity(player)
				end
				S.PlayerDataService.MarkDirty(player)
			end
		end
	end
end

return BuildIndexService
