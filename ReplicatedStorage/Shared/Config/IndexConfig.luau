--!strict
-- BUILD INDEX extras: per-build VARIANTS and collection MILESTONES.
--
-- VARIANTS. For every build the Index records which versions the player has COMPLETED:
-- Normal (no modifier) plus one per modifier (Golden, Giant, Ancient, Corrupted). The data is
-- PlayerData.BuildIndex[buildId].Modifiers[variantId] = true (so a Golden+Giant completion marks both).
-- Builds that cannot roll a modifier (EligibleModifiers) never show it as missing.
--
-- MILESTONES. Data-driven collection goals. When one is reached for the first time the player is granted its
-- Reward (CosmeticConfig category + id, or a Title) once; claimed ids persist in PlayerData.Milestones.
--   Kind = "AllRarity"          every enabled build of Rarity has been completed
--   Kind = "AllVariantsOnOne"   some single build has every variant it can roll completed
--   Kind = "TotalBuilds"        Stats.BuildsCompleted >= Count
--   Kind = "EntireIndex"        every enabled build has been completed
-- Limited-event builds (BuildConfig Season) never count toward these collections, so the permanent Index stays completable.
local IndexConfig = {}

IndexConfig.Variants = { "Normal", "Golden", "Giant", "Ancient", "Corrupted" }
IndexConfig.VariantNames = { Normal = "Normal", Golden = "Golden", Giant = "Giant", Ancient = "Ancient", Corrupted = "Corrupted" }

export type Milestone = {
	Id: string,
	Name: string,
	Description: string,
	Kind: string,
	Rarity: string?,
	Count: number?,
	Reward: { Category: string, Item: string },
}

IndexConfig.Milestones = {
	{ Id = "AllCommon", Name = "Common Collection", Description = "Complete every Common build.", Kind = "AllRarity", Rarity = "Common", Reward = { Category = "Trail", Item = "SawdustTrail" } },
	{ Id = "AllUncommon", Name = "Uncommon Collection", Description = "Complete every Uncommon build.", Kind = "AllRarity", Rarity = "Uncommon", Reward = { Category = "WorkerOutfit", Item = "SiteForeman" } },
	{ Id = "AllRare", Name = "Rare Collection", Description = "Complete every Rare build.", Kind = "AllRarity", Rarity = "Rare", Reward = { Category = "CarryEffect", Item = "GoldDust" } },
	{ Id = "AllEpic", Name = "Epic Collection", Description = "Complete every Epic build.", Kind = "AllRarity", Rarity = "Epic", Reward = { Category = "Trail", Item = "HazardTrail" } },
	{ Id = "AllLegendary", Name = "Legendary Collection", Description = "Complete every Legendary build.", Kind = "AllRarity", Rarity = "Legendary", Reward = { Category = "VehicleSkin", Item = "GoldenHaul" } },
	{ Id = "AllMythic", Name = "Mythic Collection", Description = "Complete every Mythic build.", Kind = "AllRarity", Rarity = "Mythic", Reward = { Category = "VehicleSkin", Item = "DragonScale" } },
	{ Id = "AllVariants", Name = "Every Variant", Description = "Complete every variant of one build.", Kind = "AllVariantsOnOne", Reward = { Category = "ContributionEffect", Item = "GoldenSparks" } },
	{ Id = "Builds25", Name = "25 Builds", Description = "Complete 25 builds in total.", Kind = "TotalBuilds", Count = 25, Reward = { Category = "Title", Item = "Seasoned Builder" } },
	{ Id = "Builds50", Name = "50 Builds", Description = "Complete 50 builds in total.", Kind = "TotalBuilds", Count = 50, Reward = { Category = "WorkerOutfit", Item = "IndexScout" } },
	{ Id = "Builds100", Name = "100 Builds", Description = "Complete 100 builds in total.", Kind = "TotalBuilds", Count = 100, Reward = { Category = "ContributionEffect", Item = "FireworkBurst" } },
	{ Id = "EntireIndex", Name = "Entire Index", Description = "Complete every build in the Index.", Kind = "EntireIndex", Reward = { Category = "WorkerOutfit", Item = "IndexArchitect" } },
} :: { Milestone }

-- RARITY COMPLETION BONUSES: finishing every build of a normal rarity permanently gives ONE small gameplay bonus (the cosmetic
-- is the matching milestone Reward above). No variants required. Keyed by milestone id; Value is a fraction (0.02 = +2%) except
-- Luck, which is whole personal-Luck points. BuildIndexService.Bonus(player, Kind) sums what is owned.
--   Coins            +% Coins from deliveries and completion payouts' deposits
--   Luck             + personal Luck points
--   ResourceValue    +% Coins and contribution points from delivered resources
--   WorkerEfficiency +% Worker efficiency
--   BuildReward      +% build-completion reward
--   MutationValue    +% to the bonus part of Golden/Diamond/Prismatic multipliers
IndexConfig.RarityBonuses = {
	AllCommon = { Kind = "Coins", Value = 0.02, Text = "+2% Coins" },
	AllUncommon = { Kind = "Luck", Value = 1, Text = "+1 Luck" },
	AllRare = { Kind = "ResourceValue", Value = 0.02, Text = "+2% resource value" },
	AllEpic = { Kind = "WorkerEfficiency", Value = 0.03, Text = "+3% Worker efficiency" },
	AllLegendary = { Kind = "BuildReward", Value = 0.03, Text = "+3% build rewards" },
	AllMythic = { Kind = "MutationValue", Value = 0.05, Text = "+5% mutation value" },
} :: { [string]: { Kind: string, Value: number, Text: string } }

-- Does the player's data satisfy a milestone? Returns (done, have, need) for progress displays.
-- `builds` is the list of ENABLED builds ({ Id, Rarity, EligibleModifiers }) so this module stays pure data + logic.
function IndexConfig.Progress(m: Milestone, data: any, builds: { any }): (boolean, number, number)
	local index = data.BuildIndex or {}
	local function completed(b: any): boolean
		local e = index[b.Id]
		return e ~= nil and (e.TimesCompleted or 0) > 0
	end
	if m.Kind == "AllRarity" then
		local have, need = 0, 0
		for _, b in builds do
			if b.Rarity == m.Rarity then
				need += 1
				if completed(b) then
					have += 1
				end
			end
		end
		return need > 0 and have >= need, have, need
	elseif m.Kind == "TotalBuilds" then
		local have = (data.Stats and data.Stats.BuildsCompleted) or 0
		return have >= (m.Count or 1), math.min(have, m.Count or 1), m.Count or 1
	elseif m.Kind == "EntireIndex" then
		local have, need = 0, #builds
		for _, b in builds do
			if completed(b) then
				have += 1
			end
		end
		return need > 0 and have >= need, have, need
	elseif m.Kind == "AllVariantsOnOne" then
		local best, bestNeed = 0, 1
		for _, b in builds do
			local e = index[b.Id]
			local want = { "Normal" }
			for _, mod in b.EligibleModifiers or {} do
				table.insert(want, mod)
			end
			local have = 0
			for _, v in want do
				if e and e.Modifiers and e.Modifiers[v] then
					have += 1
				end
			end
			if have == #want then
				return true, have, #want
			end
			if have > best then
				best, bestNeed = have, #want
			end
		end
		return false, best, bestNeed
	end
	return false, 0, 1
end

return IndexConfig
