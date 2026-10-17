--!strict
-- Completion rewards. Cooperative first: everyone above a modest participation
-- threshold gets a strong base reward; contribution adds a capped bonus, then small
-- rank bonuses (Top 25%, Top 10, Top 3, MVP). Friend bonus and personal-Luck
-- "Lucky Bonus" multiply on top. AFK players (below threshold) get nothing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Formulas = require(Shared.Formulas)

local RewardService = {}
local S: any

export type Result = {
	Player: Player,
	Points: number,
	Eligible: boolean,
	Rank: number?,
	Coins: number,
	Lucky: boolean,
	FriendBonus: number,
	Share: number,
}

function RewardService.Init(registry)
	S = registry
end

function RewardService.Threshold(standings: { { player: Player, points: number } }): number
	local c = EconomyConfig.Completion
	local sum, n = 0, 0
	for _, e in standings do
		if e.points > 0 then
			sum += e.points
			n += 1
		end
	end
	local avg = if n > 0 then sum / n else 0
	return math.max(c.MinPoints, avg * c.ParticipationShareOfAverage)
end

-- Base participant payout for a build: BasePayout[rarity] x modifier reward multipliers.
function RewardService.BasePayout(def: any, modifiers: { string }): number
	local _, modReward = S.ModifierService.Multipliers(modifiers)
	local table_ = EconomyConfig.Completion.BasePayout
	return (table_[def.Rarity] or table_.Common) * def.RewardMultiplier * modReward
end

-- Reward multiplier shown to players (reveal/vote cards): payout relative to a plain Common build.
function RewardService.Multiplier(def: any, modifiers: { string }): number
	return RewardService.BasePayout(def, modifiers) / EconomyConfig.Completion.BasePayout.Common
end

-- Contribution bonus for a rank: the single highest tier that applies (bonuses never stack).
-- Position tiers (MVP, Top 3) use a fixed rank; percentile tiers (Top 10%, Top 25%) use a share of the eligible players.
function RewardService.RankBonus(rank: number, eligibleCount: number): (number, string)
	for _, rule in EconomyConfig.Completion.Bonuses do
		if rule.Rank and rank <= rule.Rank then
			return rule.Bonus, rule.Id
		elseif rule.TopFraction and rank <= math.max(1, math.ceil(eligibleCount * rule.TopFraction)) then
			return rule.Bonus, rule.Id
		end
	end
	return 0, "Participant"
end

-- Extension point: functions called as hook(player, def, modifiers) when a player wins a Lucky
-- Bonus roll, for future cosmetic / title / special-reward rolls. Not used for Coin multiplication.
RewardService.LuckHooks = {} :: { (Player, any, { string }) -> () }

function RewardService.Compute(def: any, modifiers: { string }): { Result }
	local standings = S.ContributionService.Standings()
	local total = math.max(1, S.ContributionService.Total())
	local threshold = RewardService.Threshold(standings)
	local base = RewardService.BasePayout(def, modifiers)
	local eligibleCount = 0
	for _, e in standings do
		if e.points >= threshold then
			eligibleCount += 1
		end
	end
	local rng = Random.new()
	local luckyAdd = S.ModifierService.LuckyBonusChanceAdd(modifiers)
	local results = {}
	local rank = 0
	for _, e in standings do
		local eligible = e.points >= threshold
		local r: Result = {
			Player = e.player,
			Points = e.points,
			Eligible = eligible,
			Rank = nil,
			Coins = 0,
			Lucky = false,
			FriendBonus = 0,
			Share = e.points / total,
		}
		if eligible then
			rank += 1
			r.Rank = rank
			local bonus = RewardService.RankBonus(rank, eligibleCount)
			r.FriendBonus = S.FriendService.GetBonus(e.player)
			local coins = base * (1 + bonus) * (1 + r.FriendBonus)
			-- Lucky Bonus: a separate roll worth a flat share of the BASE payout (not a multiplier on the total)
			local luck = S.UpgradeService.PersonalLuck(e.player)
			if rng:NextNumber() < Formulas.LuckyBonusChance(luck) + luckyAdd then
				r.Lucky = true
				coins += base * EconomyConfig.LuckyBonus.PercentOfBase
				for _, hook in RewardService.LuckHooks do
					task.spawn(hook, e.player, def, modifiers)
				end
			end
			coins *= 1 + S.BuildIndexService.Bonus(e.player, "BuildReward") -- "all Legendaries" Index bonus
			coins *= S.BoostService.Mult(e.player, "Coins") * S.BoostService.ServerRewardMult() -- Double Coins (personal) and Golden Shift (server-wide)
			r.Coins = math.floor(coins + 0.5)
		end
		table.insert(results, r)
	end
	return results
end

function RewardService.Apply(results: { Result })
	for _, r in results do
		if r.Coins > 0 and r.Player.Parent then
			S.PlayerDataService.AddCoins(r.Player, r.Coins)
			S.TelemetryService.Record("Reward", r.Player, r.Coins)
			-- (LifetimeContribution is credited per deposit in BuildService.Deposit; r.Points is the sum of those same points)
		end
	end
end

return RewardService
