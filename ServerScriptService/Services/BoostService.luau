--!strict
-- BOOSTS (personal + server-wide) and pass bonuses. The ONLY place gameplay systems ask "does this player / this server have a
-- paid or temporary bonus?". Everything is read from MonetizationConfig and every bonus is small and capped.
--
--   Personal boosts (developer products): stored in PlayerData.Boosts[kind] = { Amount, Until } (absolute os.time), mirrored to
--   player attributes Buff<Kind> / Buff<Kind>Until. Luck and Gather share the attributes the daily reward uses, so the stronger of
--   two sources applies (never both added). Re-buying the same kind extends the time up to MaxMinutes; it never raises the amount.
--   Server boosts: one slot per boost id in memory, published to GameState (SB_<id> = expiry) so every client shows the timer.
--   FULL VALUE: a purchase always adds its full Minutes. The store refuses to open checkout when that would push the boost past
--   MaxMinutes (BoostService.CanBuy), so the cap holds for normal buying; a receipt that arrives anyway (two buyers racing for the
--   same server boost, or a retried receipt) is still granted in full rather than charging for nothing.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)

local BoostService = {}
local S: any

local serverBoosts: { [string]: { Until: number, Buyer: string } } = {}

function BoostService.Init(registry)
	S = registry
end

------------------------------------------------------------------ pass bonuses
local function passBonus(player: Player, field: string): number
	local total = 0
	local d = S.PlayerDataService.Get(player)
	if not d then
		return 0
	end
	for key, pass in MonetizationConfig.Passes do
		if d.Purchases.Passes[key] then
			total += (pass :: any)[field] or 0
		end
	end
	return total
end

function BoostService.HasPass(player: Player, key: string): boolean
	local d = S.PlayerDataService.Get(player)
	return d ~= nil and d.Purchases.Passes[key] == true
end

function BoostService.DailyCoinBonus(player: Player): number
	return passBonus(player, "DailyCoinBonus")
end

function BoostService.CargoBonus(player: Player): number
	return passBonus(player, "CargoBonus")
end

------------------------------------------------------------------ server boosts
local function serverActive(id: string): boolean
	local b = serverBoosts[id]
	return b ~= nil and b.Until > os.time()
end

local function serverSum(field: string): number
	local total = 0
	for id, def in MonetizationConfig.ServerBoosts do
		if serverActive(id) then
			total += (def :: any)[field] or 0
		end
	end
	return total
end

-- Gather / deposit multipliers from the Toolkit pass and Builder Rush, capped (see MonetizationConfig.Caps).
function BoostService.PaidGatherMult(player: Player): number
	return math.min(MonetizationConfig.Caps.PaidGatherMultiplier, (1 + passBonus(player, "GatherBonus")) * (1 + serverSum("GatherBonus")))
end

function BoostService.PaidDepositMult(player: Player): number
	return math.min(MonetizationConfig.Caps.PaidDepositMultiplier, (1 + passBonus(player, "DepositBonus")) * (1 + serverSum("DepositBonus")))
end

-- Server Luck points added to RARITY ROLLS only (never to build unlock thresholds); the roll value stays <= the cap.
function BoostService.ServerLuckBonus(): number
	return serverSum("LuckBonus")
end

-- Multiplier on completion Coins from Golden Shift.
function BoostService.ServerRewardMult(): number
	return 1 + serverSum("RewardBonus")
end

function BoostService.ServerRemaining(id: string): number
	local b = serverBoosts[id]
	return if b then math.max(0, b.Until - os.time()) else 0
end

local function publish(id: string)
	local b = serverBoosts[id]
	S.StateService.Set("SB_" .. id, if b then b.Until else 0)
	S.StateService.Set("SB_" .. id .. "_By", if b then b.Buyer else "")
end

function BoostService.StartServerBoost(player: Player?, id: string): (boolean, string)
	local def = MonetizationConfig.ServerBoosts[id]
	if not def then
		return false, "Unknown boost"
	end
	local now = os.time()
	local cur = serverBoosts[id]
	local base = if cur and cur.Until > now then cur.Until else now
	local untilT = base + def.Minutes * 60 -- full purchased time (the MaxMinutes cap is enforced before checkout, see CanBuy)
	local buyer = if player then player.DisplayName else "Someone"
	serverBoosts[id] = { Until = untilT, Buyer = if cur and cur.Until > now then cur.Buyer else buyer }
	publish(id)
	Net.Event("Notify"):FireAllClients("Success", string.format("%s started %s! %s", buyer, def.Name, def.Description), 6)
	return true, def.Name
end

------------------------------------------------------------------ personal boosts
local function mirror(player: Player, kind: string, amount: number?, untilT: number?)
	player:SetAttribute("Buff" .. kind, amount)
	player:SetAttribute("Buff" .. kind .. "Until", untilT)
end

-- Remaining seconds of a personal boost kind.
function BoostService.Remaining(player: Player, kind: string): number
	local untilT = player:GetAttribute("Buff" .. kind .. "Until")
	return if type(untilT) == "number" then math.max(0, untilT - os.time()) else 0
end

-- Current multiplier for Coins / Training (1 = none).
function BoostService.Mult(player: Player, kind: string): number
	if BoostService.Remaining(player, kind) > 0 then
		return player:GetAttribute("Buff" .. kind) or 1
	end
	return 1
end

function BoostService.StartPersonalBoost(player: Player, key: string): (boolean, string)
	local def = MonetizationConfig.Boosts[key]
	local d = S.PlayerDataService.Get(player)
	if not def or not d then
		return false, "Unavailable"
	end
	local now = os.time()
	local cur = d.Boosts[def.Kind]
	local base = if cur and cur.Until > now then cur.Until else now
	local untilT = base + def.Minutes * 60 -- full purchased time (the MaxMinutes cap is enforced before checkout, see CanBuy)
	-- never replace a stronger source of the same kind (e.g. a daily buff) with a weaker one
	local amount = def.Amount
	local existing = player:GetAttribute("Buff" .. def.Kind)
	if type(existing) == "number" and BoostService.Remaining(player, def.Kind) > 0 then
		amount = math.max(amount, existing)
		untilT = math.max(untilT, now + BoostService.Remaining(player, def.Kind))
	end
	d.Boosts[def.Kind] = { Amount = def.Amount, Until = untilT }
	mirror(player, def.Kind, amount, untilT)
	S.PlayerDataService.MarkDirty(player)
	if def.Kind == "Luck" then
		S.UpgradeService.RefreshMovement(player)
	end
	return true, def.Name
end

-- May the store open checkout for this boost? Only when the purchase can add its FULL time without passing MaxMinutes,
-- so nobody pays for a boost that is already (nearly) at its cap. kind = "Boost" | "ServerBoost".
function BoostService.CanBuy(player: Player, kind: string, key: string): (boolean, string?)
	local now = os.time()
	if kind == "ServerBoost" then
		local def = MonetizationConfig.ServerBoosts[key]
		if not def then
			return false, "Unknown item"
		end
		local remaining = BoostService.ServerRemaining(key)
		if remaining + def.Minutes * 60 > def.MaxMinutes * 60 then
			return false, string.format("%s is already near its %d-minute limit. Try again in %d min.", def.Name, def.MaxMinutes, math.ceil((remaining + def.Minutes * 60 - def.MaxMinutes * 60) / 60))
		end
	elseif kind == "Boost" then
		local def = MonetizationConfig.Boosts[key]
		local d = S.PlayerDataService.Get(player)
		if not def or not d then
			return false, "Unavailable"
		end
		local cur = d.Boosts[def.Kind]
		local remaining = if type(cur) == "table" and cur.Until and cur.Until > now then cur.Until - now else 0
		if remaining + def.Minutes * 60 > def.MaxMinutes * 60 then
			return false, string.format("%s is already near its %d-minute limit. Try again in %d min.", def.Name, def.MaxMinutes, math.ceil((remaining + def.Minutes * 60 - def.MaxMinutes * 60) / 60))
		end
	end
	return true, nil
end

-- Re-applies saved, still-running personal boosts after a (re)join.
function BoostService.Restore(player: Player)
	local d = S.PlayerDataService.Get(player)
	if not d then
		return
	end
	local now = os.time()
	for kind, b in d.Boosts do
		if type(b) == "table" and b.Until and b.Until > now then
			mirror(player, kind, b.Amount, b.Until)
		else
			d.Boosts[kind] = nil
		end
	end
end

function BoostService.Start()
	S.PlayerDataService.Loaded:Connect(function(player)
		BoostService.Restore(player)
	end)
	-- expire server boosts
	task.spawn(function()
		while true do
			task.wait(5)
			local now = os.time()
			for id, b in serverBoosts do
				if b.Until <= now then
					serverBoosts[id] = nil
					publish(id)
					local def = MonetizationConfig.ServerBoosts[id]
					Net.Event("Notify"):FireAllClients("Info", (if def then def.Name else id) .. " has ended.", 4)
				end
			end
		end
	end)
	local _ = Players
end

return BoostService
