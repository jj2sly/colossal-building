--!strict
-- BALANCE v0.1 - Coins + completion reward tuning. Coins are the only currency.
-- Numbers here are starting points; use the dev Balance Report (debug panel) to measure and retune.
local EconomyConfig = {}

EconomyConfig.StartingCoins = 0

-- Completion rewards. Every eligible participant gets the base payout for the build's rarity,
-- scaled by the modifier reward multipliers (ModifierConfig), then ONE contribution bonus
-- (the highest that applies, they never stack) as a percentage of that amount.
EconomyConfig.Completion = {
	BasePayout = { Common = 60, Uncommon = 90, Rare = 140, Epic = 220, Legendary = 350, Mythic = 550, Forgotten = 900 },
	-- CONTRIBUTION TIERS: the highest tier that applies is the ONLY bonus (they never stack).
	-- Position tiers use a fixed rank (MVP = 1st, Top 3); percentile tiers scale with the number of eligible
	-- participants so they stay meaningful on a 6-player and a 50-player server (always at least rank 1).
	-- Anyone eligible below the lowest tier is a plain Participant (+0%). Checked in order.
	Bonuses = {
		{ Id = "MVP", Rank = 1, Bonus = 0.50 },
		{ Id = "Top3", Rank = 3, Bonus = 0.35 },
		{ Id = "Top10Percent", TopFraction = 0.10, Bonus = 0.20 },
		{ Id = "Top25Percent", TopFraction = 0.25, Bonus = 0.10 },
	},
	-- Participation threshold: contribution must reach this share of the average participant
	-- contribution (and at least MinPoints). Keeps AFK players out without punishing casual play.
	ParticipationShareOfAverage = 0.15,
	MinPoints = 10,
}

-- Deposit earnings only feel a quarter of the rarity bonus (the rest is paid at completion):
-- per-unit Coins * (1 + DepositRarityShare * (RarityRewardMultiplier - 1)).
EconomyConfig.DepositRarityShare = 0.25

-- Repairs pay a little more per unit than construction.
EconomyConfig.RepairCoinMultiplier = 1.5

-- Server Luck: flat gain per completed build, capped.
EconomyConfig.ServerLuck = { GainPerBuild = 4, Max = 100 }

-- SERVER IDENTITY: named states for Server Luck (construction themed). Names and thresholds live here only.
-- Each state may give SMALL secondary perks (multipliers, 1 = none): ModifierChance scales every build modifier
-- roll, DropChance scales personal rare drops (DropConfig). They are deliberately tiny; Server Luck must not let
-- anyone speedrun the game. VoteQuality is reserved for milestone-vote quality (not wired yet).
EconomyConfig.ServerStates = {
	{ Id = "Fresh", Name = "Fresh Site", Min = 0, Perks = { ModifierChance = 1, DropChance = 1, VoteQuality = 1 } },
	{ Id = "Active", Name = "Active Site", Min = 20, Perks = { ModifierChance = 1.03, DropChance = 1.05, VoteQuality = 1 } },
	{ Id = "Booming", Name = "Booming Site", Min = 40, Perks = { ModifierChance = 1.06, DropChance = 1.10, VoteQuality = 1 } },
	{ Id = "Prime", Name = "Prime Site", Min = 60, Perks = { ModifierChance = 1.10, DropChance = 1.20, VoteQuality = 1 } },
	{ Id = "Elite", Name = "Elite Site", Min = 80, Perks = { ModifierChance = 1.15, DropChance = 1.30, VoteQuality = 1 } },
	{ Id = "Legendary", Name = "Legendary Site", Min = 95, Perks = { ModifierChance = 1.20, DropChance = 1.40, VoteQuality = 1 } },
}

-- The state for a Server Luck value: the highest state whose Min <= luck. Returns (state, index).
function EconomyConfig.ServerState(luck: number): (any, number)
	local best, idx = EconomyConfig.ServerStates[1], 1
	for i, st in EconomyConfig.ServerStates do
		if luck >= st.Min then
			best, idx = st, i
		end
	end
	return best, idx
end

-- Personal Luck: chance of a "Lucky Bonus" at completion. It is a bonus roll, NOT a Coin multiplier:
-- a lucky player gets an extra flat reward worth PercentOfBase of the base payout, plus hooks for
-- future cosmetic/title rolls (see RewardService.LuckHooks). Chance climbs with diminishing returns.
EconomyConfig.LuckyBonus = {
	BaseChance = 0.04,
	MaxExtraChance = 0.26,
	LuckScale = 25, -- chance = Base + MaxExtra * (1 - exp(-personalLuck / LuckScale))
	PercentOfBase = 0.5,
}

-- Friend bonus: +2% per friend in server, capped at +10%.
EconomyConfig.Friends = {
	BonusPerFriend = 0.02,
	MaxBonus = 0.10,
}

return EconomyConfig
