--!strict
-- BALANCE v0.1 - Permanent Coin upgrades. Value(level) = Start + PerLevel * level.
-- Price(level -> level+1) = round(BasePrice * PriceGrowth ^ level)  (= Base * 1.38^(nextLevel-1)).
-- Every system reads values through UpgradeConfig.Value so formulas live only here.
-- Strength (carry) and Speed (walk) are NOT purchasable: they are trained (see TrainingConfig).
export type Upgrade = {
	Id: string,
	DisplayName: string,
	Description: string,
	Order: number,
	Start: number,
	PerLevel: number,
	MaxLevel: number,
	BasePrice: number,
	PriceGrowth: number,
	Format: string, -- "int" | "mult" | "pct" for UI
	Icon: string,
}

local UpgradeConfig = {}

UpgradeConfig.Upgrades = {
	GatherSpeed = {
		Id = "GatherSpeed", DisplayName = "Gather Speed", Order = 1,
		Description = "Gather resources faster (+5% per level).",
		Start = 1, PerLevel = 0.05, MaxLevel = 15, BasePrice = 50, PriceGrowth = 1.38,
		Format = "mult", Icon = "pickaxe",
	},
	DepositSpeed = {
		Id = "DepositSpeed", DisplayName = "Deposit Speed", Order = 2,
		Description = "Unload faster at the build site (+6% per level).",
		Start = 1, PerLevel = 0.06, MaxLevel = 15, BasePrice = 50, PriceGrowth = 1.38,
		Format = "mult", Icon = "tray",
	},
	Luck = {
		Id = "Luck", DisplayName = "Luck", Order = 3,
		Description = "+2 personal Luck per level: better odds on bonus rewards and a small, capped nudge to build rarity.",
		Start = 0, PerLevel = 2, MaxLevel = 15, BasePrice = 100, PriceGrowth = 1.38,
		Format = "int", Icon = "clover",
	},
	WorkerEfficiency = {
		Id = "WorkerEfficiency", DisplayName = "Worker Efficiency", Order = 4,
		Description = "Your Worker hauls more, walks faster and gathers quicker (about +5% throughput per level).",
		Start = 1, PerLevel = 0.05, MaxLevel = 15, BasePrice = 125, PriceGrowth = 1.38,
		Format = "mult", Icon = "hardhat",
	},
	VehicleCapacity = {
		Id = "VehicleCapacity", DisplayName = "Vehicle Capacity", Order = 5,
		Description = "Vehicles hold more cargo (+7% per level).",
		Start = 1, PerLevel = 0.07, MaxLevel = 15, BasePrice = 100, PriceGrowth = 1.38,
		Format = "mult", Icon = "cart",
	},
} :: { [string]: Upgrade }

function UpgradeConfig.Value(id: string, level: number): number
	local u = UpgradeConfig.Upgrades[id]
	if not u then
		return 0
	end
	return u.Start + u.PerLevel * math.clamp(level, 0, u.MaxLevel)
end

-- Rounded to a "clean" price: nearest 5 above 100, nearest 1 below.
function UpgradeConfig.Price(id: string, level: number): number?
	local u = UpgradeConfig.Upgrades[id]
	if not u or level >= u.MaxLevel then
		return nil
	end
	local raw = u.BasePrice * u.PriceGrowth ^ level
	if raw >= 100 then
		return math.floor(raw / 5 + 0.5) * 5
	end
	return math.floor(raw + 0.5)
end

function UpgradeConfig.TotalMaxLevels(): number
	local n = 0
	for _, u in UpgradeConfig.Upgrades do
		n += u.MaxLevel
	end
	return n
end

function UpgradeConfig.FormatValue(id: string, value: number): string
	local u = UpgradeConfig.Upgrades[id]
	if not u then
		return tostring(value)
	end
	if u.Format == "mult" then
		return string.format("x%.2f", value)
	elseif u.Format == "pct" then
		return string.format("%d%%", math.floor(value + 0.5))
	end
	return tostring(math.floor(value * 10 + 0.5) / 10)
end

return UpgradeConfig
