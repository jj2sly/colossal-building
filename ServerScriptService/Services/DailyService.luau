--!strict
-- DAILY REWARD + WELCOME BACK (see DailyConfig). Server-authoritative: the claim day is derived from os.time() here,
-- never from the client. Buffs are short-lived player attributes read by UpgradeService.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local DailyConfig = require(Shared.Config.DailyConfig)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)

local DailyService = {}
local S: any

function DailyService.Init(registry)
	S = registry
end

local function grantBuff(player: Player, buff: any)
	local key = buff.Key
	local untilT = os.time() + buff.Minutes * 60
	-- a fresh buff never shortens or weakens a stronger one that is still running
	local curUntil = player:GetAttribute("Buff" .. key .. "Until")
	local curAmount = player:GetAttribute("Buff" .. key) or 0
	if type(curUntil) == "number" and curUntil > os.time() then
		untilT = math.max(untilT, curUntil)
		buff = { Amount = math.max(buff.Amount, curAmount) }
	end
	player:SetAttribute("Buff" .. key, buff.Amount)
	player:SetAttribute("Buff" .. key .. "Until", untilT)
end

local function applyReward(player: Player, reward: any): string
	local parts = {}
	if reward.Coins then
		-- VIP Builder: a small bonus on the Coin part of the daily reward
		S.PlayerDataService.AddCoins(player, math.floor(reward.Coins * (1 + S.BoostService.DailyCoinBonus(player)) + 0.5))
	end
	if reward.Buff then
		grantBuff(player, reward.Buff)
	end
	if reward.Cosmetic then
		local isNew = S.CosmeticService.Grant(player, reward.Cosmetic.Category, reward.Cosmetic.Item, "daily")
		if not isNew then
			S.PlayerDataService.AddCoins(player, DailyConfig.DuplicateCoins)
			table.insert(parts, string.format("(%s owned: +%d Coins)", CosmeticConfig.Name(reward.Cosmetic.Category, reward.Cosmetic.Item), DailyConfig.DuplicateCoins))
		end
	end
	return table.concat(parts, " ")
end

-- Is a claim available right now? Returns (available, slot).
function DailyService.Status(player: Player): (boolean, number)
	local d = S.PlayerDataService.Get(player)
	if not d then
		return false, 1
	end
	return DailyConfig.DayNumber() > (d.Daily.LastClaimDay or 0), DailyConfig.Slot(d.Daily.Claims or 0)
end

function DailyService.Claim(player: Player): (boolean, any)
	local d = S.PlayerDataService.Get(player)
	if not d then
		return false, "Data not loaded"
	end
	local today = DailyConfig.DayNumber()
	if today <= (d.Daily.LastClaimDay or 0) then
		return false, "Already claimed today"
	end
	local slot = DailyConfig.Slot(d.Daily.Claims or 0)
	local reward = DailyConfig.Cycle[slot]
	d.Daily.LastClaimDay = today
	d.Daily.Claims = (d.Daily.Claims or 0) + 1
	local extra = applyReward(player, reward)
	S.PlayerDataService.MarkDirty(player)
	S.PlayerDataService.Sync(player)
	Net.Event("Notify"):FireClient(player, "Success", "Daily reward: " .. reward.Text .. (if extra ~= "" then " " .. extra else ""), 5)
	return true, { Slot = slot, Text = reward.Text }
end

local function welcomeBack(player: Player)
	local d = S.PlayerDataService.Get(player)
	if not d then
		return
	end
	local today = DailyConfig.DayNumber()
	local last = d.Daily.LastSeenDay or 0
	d.Daily.LastSeenDay = today
	S.PlayerDataService.MarkDirty(player, true)
	local r = DailyConfig.Return
	if last > 0 and today - last >= r.MinDaysAway then
		S.PlayerDataService.AddCoins(player, r.Coins)
		grantBuff(player, r.Buff)
		Net.Event("Notify"):FireClient(player, "Success", string.format("%s! +%d Coins and +%d Luck for %d min", r.Text, r.Coins, r.Buff.Amount, r.Buff.Minutes), 6)
	end
end

function DailyService.Start()
	local limiter = Net.RateLimiter(0.5, 2)
	Net.Function("DailyClaim").OnServerInvoke = function(player)
		if not limiter(player) then
			return false, "Slow down"
		end
		return DailyService.Claim(player)
	end
	S.PlayerDataService.Loaded:Connect(function(player)
		welcomeBack(player)
		if DailyService.Status(player) then
			Net.Event("Notify"):FireClient(player, "Info", "Your daily reward is ready (Rewards menu)", 5)
		end
	end)
	local _ = Players
end

return DailyService
