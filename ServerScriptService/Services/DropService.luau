--!strict
-- PERSONAL RARE DROPS (foundation). DropService.Roll is called once per eligible participant when a build
-- completes; it rolls every DropConfig entry whose conditions the finished build meets and grants the cosmetic
-- through CosmeticService. Duplicates convert to Coins. Nothing here is shared between players.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local DropConfig = require(Shared.Config.DropConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local SeasonConfig = require(Shared.Config.SeasonConfig)

local DropService = {}
local S: any
local rng = Random.new()

function DropService.Init(registry)
	S = registry
end

-- Is this drop allowed to roll for this build? (rarity floor, build list, modifier list, event season)
local function eligible(drop: any, def: any, modifiers: { string }): boolean
	local order = DropConfig.RarityOrder
	if (order[def.Rarity] or 0) < (order[drop.MinRarity] or 0) then
		return false
	end
	if drop.Builds and not table.find(drop.Builds, def.Id) then
		return false
	end
	if drop.Modifiers then
		local ok = false
		for _, m in drop.Modifiers do
			if table.find(modifiers, m) then
				ok = true
			end
		end
		if not ok then
			return false
		end
	end
	if drop.EventSeason and SeasonConfig.StateOf(drop.EventSeason) ~= "Active" then
		return false
	end
	return true
end

function DropService.Chance(drop: any, player: Player): number
	local luck = S.UpgradeService.PersonalLuck(player)
	local c = drop.Chance * S.ServerLuckService.Perk("DropChance") * (1 + luck * DropConfig.LuckInfluence) * (1 + (drop.RankBonus or 0) * S.UpgradeService.MasterRank(player))
	return math.min(c, DropConfig.MaxChance)
end

-- Rolls the table for one player. `forceAll` (debug) skips the dice. Returns { { Id, Category, Item, Name, Duplicate } }.
function DropService.Roll(player: Player, def: any, modifiers: { string }, forceAll: boolean?): { any }
	local found = {}
	local d = S.PlayerDataService.Get(player)
	if not d then
		return found
	end
	for _, drop in DropConfig.Drops do
		if eligible(drop, def, modifiers) and (forceAll or rng:NextNumber() < DropService.Chance(drop, player)) then
			local isNew = S.CosmeticService.Grant(player, drop.Category, drop.Item, "drop")
			d.DropLog[drop.Id] = (d.DropLog[drop.Id] or 0) + 1
			local name = CosmeticConfig.Name(drop.Category, drop.Item)
			if not isNew then
				local coins = DropConfig.DuplicateCoins[CosmeticConfig.Rarity(drop.Category, drop.Item)] or 100
				S.PlayerDataService.AddCoins(player, coins)
				Net.Event("Notify"):FireClient(player, "Info", string.format("Rare drop again: %s (duplicate, +%d Coins)", name, coins), 4)
			else
				Net.Event("Notify"):FireClient(player, "Success", string.format("RARE DROP! %s", name), 5)
			end
			table.insert(found, { Id = drop.Id, Category = drop.Category, Item = drop.Item, Name = name, Duplicate = not isNew })
		end
	end
	if #found > 0 then
		S.PlayerDataService.MarkDirty(player)
	end
	return found
end

return DropService
