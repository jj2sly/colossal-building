--!strict
-- Chooses the next build: rarity roll (Server Luck + capped personal Luck), build within
-- that rarity, then modifiers. Only rarities that actually have eligible builds are
-- rolled, so missing content degrades gracefully. Debug overrides apply once.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local BuildConfig = require(Shared.Config.BuildConfig)
local GameConfig = require(Shared.Config.GameConfig)
local SeasonConfig = require(Shared.Config.SeasonConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Formulas = require(Shared.Formulas)
local Weighted = require(Shared.Util.Weighted)

export type Choice = { BuildId: string, Rarity: string, Modifiers: { string } }

local SelectionService = {}
local S: any
local rng = Random.new()
local lastBuildId: string? = nil
local forced: { BuildId: string?, Rarity: string?, Modifiers: { string }? } = {}

function SelectionService.Init(registry)
	S = registry
end

function SelectionService.Force(kind: string, value: any)
	(forced :: any)[kind] = value
end

-- any debug/admin forced selection (build, rarity or modifiers): the natural Forgotten check is skipped
function SelectionService.HasForced(): boolean
	return forced.BuildId ~= nil or forced.Rarity ~= nil or forced.Modifiers ~= nil
end

function SelectionService.HasForcedBuild(): boolean
	return forced.BuildId ~= nil
end

local function avgPersonalLuck(): number
	local sum, n = 0, 0
	for _, p in Players:GetPlayers() do
		sum += S.UpgradeService.Value(p, "Luck")
		n += 1
	end
	return if n > 0 then sum / n else 0
end

function SelectionService.EffectiveLuck(): number
	-- Lucky Site adds Server Luck points to rarity rolls only (capped); it never unlocks builds or guarantees anything
	local serverLuck = math.min(MonetizationConfig.Caps.EffectiveServerLuck, S.ServerLuckService.Get() + S.BoostService.ServerLuckBonus())
	return Formulas.EffectiveLuck(serverLuck, avgPersonalLuck())
end

-- Rarities that currently have at least one eligible build.
function SelectionService.CandidateRarities(): { [string]: boolean }
	local set = {}
	for _, b in BuildConfig.Eligible(nil, S.ServerLuckService.Get()) do
		set[b.Rarity] = true
	end
	return set
end

function SelectionService.RollRarity(): string
	local weights = Formulas.RarityWeights(SelectionService.EffectiveLuck(), SelectionService.CandidateRarities())
	local pick = Weighted.Pick(weights, function(e)
		return e.weight
	end, rng)
	return pick and pick.id or "Common"
end

local function pickBuild(rarity: string): any?
	local list = BuildConfig.Eligible(rarity, S.ServerLuckService.Get())
	if #list > 1 and lastBuildId then
		for i, b in list do
			if b.Id == lastBuildId then
				table.remove(list, i)
				break
			end
		end
	end
	return if #list > 0 then list[rng:NextInteger(1, #list)] else nil
end

function SelectionService.RollModifiers(def: any): { string }
	return S.ModifierService.Roll(def.EligibleModifiers, SelectionService.EffectiveLuck(), rng, S.ServerLuckService.Perk("ModifierChance"))
end

function SelectionService.Next(): Choice
	local def
	if forced.BuildId then
		def = BuildConfig.Get(forced.BuildId)
	end
	-- LEGACY activation: a small chance that a build from an ended event comes back (SeasonConfig.Legacy)
	if not def and not forced.Rarity and S.ServerLuckService.Get() >= SeasonConfig.Legacy.MinServerLuck and rng:NextNumber() < SeasonConfig.Legacy.ActivationChance then
		local legacy = BuildConfig.Legacy()
		if #legacy > 0 then
			def = legacy[rng:NextInteger(1, #legacy)]
		end
	end
	if not def then
		local rarity = forced.Rarity
		if rarity and next(BuildConfig.Eligible(rarity, math.huge)) == nil then
			rarity = nil -- forced rarity has no builds; fall back to a roll
		end
		def = pickBuild(rarity or SelectionService.RollRarity())
	end
	if not def then
		def = BuildConfig.Eligible(nil, math.huge)[1]
	end
	local mods = forced.Modifiers or SelectionService.RollModifiers(def)
	forced = {}
	lastBuildId = def.Id
	return { BuildId = def.Id, Rarity = def.Rarity, Modifiers = mods }
end

-- Vote round options: up to VoteOptionCount distinct builds from one rolled rarity.
-- If the tier has fewer builds, the vote simply has fewer options (never duplicates);
-- VotingService skips the vote entirely when only one option exists.
function SelectionService.VoteOptions(): { Choice }
	local rarity = forced.Rarity or SelectionService.RollRarity()
	local pool = Weighted.Shuffle(BuildConfig.Eligible(rarity, S.ServerLuckService.Get()), rng)
	local out = {}
	for i = 1, math.min(GameConfig.VoteOptionCount, #pool) do
		local def = pool[i]
		table.insert(out, { BuildId = def.Id, Rarity = def.Rarity, Modifiers = SelectionService.RollModifiers(def) })
	end
	forced.Rarity = nil
	return out
end

function SelectionService.SetLast(buildId: string)
	lastBuildId = buildId
end

return SelectionService
