--!strict
-- MONETIZATION FOUNDATION. Every product / pass id, duration, multiplier, cap and cosmetic entitlement lives here and
-- nowhere else (scripts read this table; no id is hard-coded elsewhere).
--
-- PHILOSOPHY (enforced by FreeFirstReport below and by the dev command FreeFirstCheck):
--   * Paid items are convenience, cosmetics, server-wide fun and OPTIONAL short acceleration. Nothing here gates a build,
--     a resource grade, a Worker, a vehicle, the Build Index, Master Builder or any cosmetic that can be EARNED.
--   * Paid cosmetics are only obtainable through packs; earned/drop/milestone cosmetics never overlap with them.
--   * All bonuses are small and capped. Boosts never stack with themselves: re-buying extends the SAME boost up to MaxMinutes.
--   * Purchases are validated on the server (PurchaseService). Real ids are placeholders (0) until the passes/products exist
--     on Roblox: with id 0 the Store shows "Coming soon" in live servers and a clearly marked DEV SIMULATION in Studio only.
local MonetizationConfig = {}

-- Paid items cannot be bought with id 0 outside Studio; flip this off to hide dev simulation even in Studio.
MonetizationConfig.DevSimulation = true

-- ---------------------------------------------------------------------------------------------- game passes (one-time)
export type Pass = {
	Key: string,
	PassId: number, -- Roblox game pass id (0 = placeholder, replace when created)
	Name: string,
	Description: string,
	Category: string, -- "Passes" | "Cosmetics" (which Store tab shows it)
	Benefits: { string }, -- bullet lines for the Store
	Grants: { { Category: string, Item: string } }?, -- cosmetics granted (and re-granted on join; idempotent)
	DailyCoinBonus: number?, -- fraction added to the Coin part of the daily reward
	GatherBonus: number?, -- fraction of gather speed
	DepositBonus: number?, -- fraction of deposit speed
	CargoBonus: number?, -- fraction of base carry capacity
}

MonetizationConfig.Passes = {
	VIPBuilder = {
		Key = "VIPBuilder", PassId = 0, Name = "VIP Builder", Category = "Passes",
		Description = "Support the game and stand out. Cosmetic status plus a small daily bonus.",
		Benefits = { "VIP Builder title", "VIP Crew Worker outfit", "Gold VIP trail", "+10% Coins on the daily reward" },
		Grants = { { Category = "Title", Item = "VIP Builder" }, { Category = "WorkerOutfit", Item = "VIPCrew" }, { Category = "Trail", Item = "VIPTrail" } },
		DailyCoinBonus = 0.10,
	},
	BuildersToolkit = {
		Key = "BuildersToolkit", PassId = 0, Name = "Builder's Toolkit", Category = "Passes",
		Description = "Small, permanent convenience. Never required to progress.",
		Benefits = { "+5% gather speed", "+10% deposit speed", "+5% carry capacity" },
		GatherBonus = 0.05, DepositBonus = 0.10, CargoBonus = 0.05,
	},
	VehiclePack = {
		Key = "VehiclePack", PassId = 0, Name = "Vehicle Paint Pack", Category = "Cosmetics",
		Description = "Three cosmetic vehicle skins for any vehicle you own. No stat changes.",
		Benefits = { "Neon Racer skin", "Candy Stripe skin", "Midnight Black skin" },
		Grants = { { Category = "VehicleSkin", Item = "NeonRacer" }, { Category = "VehicleSkin", Item = "CandyStripe" }, { Category = "VehicleSkin", Item = "MidnightBlack" } },
	},
	WorkerPack = {
		Key = "WorkerPack", PassId = 0, Name = "Worker Outfit Pack", Category = "Cosmetics",
		Description = "Three cosmetic Worker outfits. Worker efficiency never changes.",
		Benefits = { "Neon Crew", "Frost Crew", "Retro Crew" },
		Grants = { { Category = "WorkerOutfit", Item = "NeonCrew" }, { Category = "WorkerOutfit", Item = "FrostCrew" }, { Category = "WorkerOutfit", Item = "RetroCrew" } },
	},
	EffectsPack = {
		Key = "EffectsPack", PassId = 0, Name = "Effects Pack", Category = "Cosmetics",
		Description = "A trail, a carry-stack effect and a delivery effect. Purely visual.",
		Benefits = { "Rainbow Trail", "Neon Glow carry effect", "Confetti delivery effect" },
		Grants = { { Category = "Trail", Item = "RainbowTrail" }, { Category = "CarryEffect", Item = "NeonGlow" }, { Category = "ContributionEffect", Item = "ConfettiBurst" } },
	},
} :: { [string]: Pass }

-- Store ordering
MonetizationConfig.PassOrder = { "VIPBuilder", "BuildersToolkit", "VehiclePack", "WorkerPack", "EffectsPack" }

-- ----------------------------------------------------------------------------- personal boosts (developer products)
-- Kind decides what the boost changes (see BoostService): Coins = multiplier on EARNED Coins, Training = multiplier on
-- training XP (the per-minute XP ceiling still applies), Luck = personal Luck points, Gather = fraction of gather speed.
export type Boost = {
	Key: string,
	ProductId: number,
	Name: string,
	Description: string,
	Kind: string,
	Amount: number,
	Minutes: number, -- added per purchase
	MaxMinutes: number, -- remaining time can never exceed this (no infinite stacking)
}

MonetizationConfig.Boosts = {
	CoinBoost = { Key = "CoinBoost", ProductId = 0, Name = "Double Coins", Description = "2x Coins you earn.", Kind = "Coins", Amount = 2, Minutes = 30, MaxMinutes = 90 },
	LuckBoost = { Key = "LuckBoost", ProductId = 0, Name = "Lucky Streak", Description = "+8 personal Luck.", Kind = "Luck", Amount = 8, Minutes = 30, MaxMinutes = 90 },
	GatherBoost = { Key = "GatherBoost", ProductId = 0, Name = "Quick Hands", Description = "+25% gather speed.", Kind = "Gather", Amount = 0.25, Minutes = 30, MaxMinutes = 90 },
	TrainingBoost = { Key = "TrainingBoost", ProductId = 0, Name = "Training Focus", Description = "1.5x training XP (daily XP caps still apply).", Kind = "Training", Amount = 1.5, Minutes = 30, MaxMinutes = 90 },
} :: { [string]: Boost }
MonetizationConfig.BoostOrder = { "CoinBoost", "LuckBoost", "GatherBoost", "TrainingBoost" }

-- ------------------------------------------------------------------------------------------------ server-wide boosts
-- Everyone in the server benefits while one is active; one of each id at a time (buying again extends it up to MaxMinutes).
-- LuckBonus raises the Server Luck used for rarity ROLLS only: it can never unlock a build early, and the effective value
-- is capped at 100, so it cannot guarantee a rare build.
export type ServerBoost = {
	Key: string,
	ProductId: number,
	Name: string,
	Description: string,
	Minutes: number,
	MaxMinutes: number,
	GatherBonus: number?,
	DepositBonus: number?,
	LuckBonus: number?, -- Server Luck points
	RewardBonus: number?, -- fraction on completion Coins
}

MonetizationConfig.ServerBoosts = {
	BuilderRush = { Key = "BuilderRush", ProductId = 0, Name = "Builder Rush", Description = "Everyone gathers and deposits 25% faster.", Minutes = 10, MaxMinutes = 30, GatherBonus = 0.25, DepositBonus = 0.25 },
	LuckySite = { Key = "LuckySite", ProductId = 0, Name = "Lucky Site", Description = "A modest Server Luck bump for rarity rolls.", Minutes = 10, MaxMinutes = 30, LuckBonus = 8 },
	GoldenShift = { Key = "GoldenShift", ProductId = 0, Name = "Golden Shift", Description = "Everyone earns 15% more Coins when a build completes.", Minutes = 10, MaxMinutes = 30, RewardBonus = 0.15 },
} :: { [string]: ServerBoost }
MonetizationConfig.ServerBoostOrder = { "BuilderRush", "LuckySite", "GoldenShift" }

-- ---------------------------------------------------------------------------------------------------------- caps
MonetizationConfig.Caps = {
	PaidGatherMultiplier = 1.5, -- Toolkit x Builder Rush can never exceed this
	PaidDepositMultiplier = 1.5,
	EffectiveServerLuck = 100,
	ReceiptHistory = 120, -- processed receipt ids kept per player (duplicate protection window)
}

-- ----------------------------------------------------------------------------------------------------- lookups
function MonetizationConfig.PassByProductId(passId: number): Pass?
	if passId <= 0 then
		return nil
	end
	for _, p in MonetizationConfig.Passes do
		if p.PassId == passId then
			return p
		end
	end
	return nil
end

function MonetizationConfig.ByProductId(productId: number): (string?, any?)
	if productId <= 0 then
		return nil, nil
	end
	for k, b in MonetizationConfig.Boosts do
		if b.ProductId == productId then
			return "Boost", b
		end
	end
	for k, b in MonetizationConfig.ServerBoosts do
		if b.ProductId == productId then
			return "ServerBoost", b
		end
	end
	return nil, nil
end

-- Which paid cosmetics exist (category, id) -> pass key.
function MonetizationConfig.PaidCosmetics(): { [string]: string }
	local map: { [string]: string } = {}
	for key, p in MonetizationConfig.Passes do
		for _, g in p.Grants or {} do
			map[g.Category .. "/" .. g.Item] = key
		end
	end
	return map
end

-- FREE-FIRST CHECK (pure data): returns a list of problems; empty means the monetization layer respects the design rules.
function MonetizationConfig.FreeFirstReport(): { string }
	local problems: { string } = {}
	local paid = MonetizationConfig.PaidCosmetics()
	local function checkFree(source: string, category: string, item: string)
		if paid[category .. "/" .. item] then
			table.insert(problems, string.format("%s rewards PAID cosmetic %s/%s", source, category, item))
		end
	end
	local script_ = script
	local Config = script_.Parent
	for _, d in require(Config.DropConfig).Drops do
		checkFree("DropConfig " .. d.Id, d.Category, d.Item)
	end
	for _, m in require(Config.IndexConfig).Milestones do
		checkFree("Index " .. m.Id, m.Reward.Category, m.Reward.Item)
	end
	for rank, m in require(Config.MasterBuilderConfig).Milestones do
		if m.Title then
			checkFree("MasterBuilder " .. rank, "Title", m.Title)
		end
		for _, c in m.Cosmetics or {} do
			checkFree("MasterBuilder " .. rank, c.Category, c.Item)
		end
	end
	for i, r in require(Config.DailyConfig).Cycle do
		if r.Cosmetic then
			checkFree("Daily " .. i, r.Cosmetic.Category, r.Cosmetic.Item)
		end
	end
	-- bonuses stay small
	for key, p in MonetizationConfig.Passes do
		if (p.GatherBonus or 0) > 0.1 or (p.DepositBonus or 0) > 0.15 or (p.CargoBonus or 0) > 0.1 or (p.DailyCoinBonus or 0) > 0.15 then
			table.insert(problems, "pass " .. key .. " bonus is too large")
		end
	end
	for key, b in MonetizationConfig.Boosts do
		if b.Minutes > b.MaxMinutes or b.MaxMinutes > 180 then
			table.insert(problems, "boost " .. key .. " duration cap is too long")
		end
	end
	for key, b in MonetizationConfig.ServerBoosts do
		if (b.LuckBonus or 0) > 12 or (b.GatherBonus or 0) > 0.3 or (b.RewardBonus or 0) > 0.2 or b.MaxMinutes > 60 then
			table.insert(problems, "server boost " .. key .. " is too strong")
		end
	end
	return problems
end

return MonetizationConfig
