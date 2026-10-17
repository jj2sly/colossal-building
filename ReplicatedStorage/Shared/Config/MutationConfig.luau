--!strict
-- RESOURCE MUTATIONS + GRADE VALUES. Everything here is a starting value meant to be tuned.
--
-- GRADE VALUE: higher grades of a family pay more Coins per unit (on top of counting more toward a build via
-- ResourceConfig.Equivalent) and add a small contribution bonus, so a premium grade is worth hauling even when a
-- build would also accept the basic one. A higher grade still satisfies every lower-grade requirement.
--
-- MUTATIONS: the server periodically (randomised interval, never a fixed timer) turns a PILE of any resource grade
-- Golden, Diamond or Prismatic. A pile is a few of that resource's world nodes sharing ONE finite reserve. Each
-- player gathers a personal allowance at full yield; past it they may keep gathering while the reserve lasts, but
-- at a reduced yield. Mutated units keep their identity while carried and pay their Coin multiplier when delivered,
-- even if the active build does not need that material. Server Luck raises both the chance of a mutation and the
-- chance of better tiers.
local MutationConfig = {}

MutationConfig.Enabled = true

-- Coin value per delivered unit by resource grade (1 = basic). Contribution bonus is added on top of the points.
MutationConfig.GradeCoinMultiplier = { [1] = 1.0, [2] = 1.5, [3] = 2.25 }
MutationConfig.GradeContributionBonus = { [1] = 0, [2] = 0.05, [3] = 0.10 }

export type Tier = {
	Id: string,
	Order: number,
	DisplayName: string,
	BuildMult: number, -- counts this many times toward build progress / contribution points
	CoinMult: number, -- Coins per unit multiplier
	Color: Color3,
	Color2: Color3,
	Announce: string, -- "Soft" | "Loud" | "Epic"
	Beam: boolean,
}

MutationConfig.Tiers = {
	Normal = { Id = "Normal", Order = 0, DisplayName = "Normal", BuildMult = 1, CoinMult = 1, Color = Color3.new(1, 1, 1), Color2 = Color3.new(1, 1, 1), Announce = "None", Beam = false },
	-- Golden is the frequent treat: no sky beam (it would fire every minute), just its glowing pile and a quiet one-line banner
	Golden = { Id = "Golden", Order = 1, DisplayName = "Golden", BuildMult = 2, CoinMult = 3, Color = Color3.fromRGB(255, 196, 56), Color2 = Color3.fromRGB(255, 236, 150), Announce = "Soft", Beam = false },
	Diamond = { Id = "Diamond", Order = 2, DisplayName = "Diamond", BuildMult = 4, CoinMult = 7, Color = Color3.fromRGB(140, 232, 255), Color2 = Color3.fromRGB(245, 253, 255), Announce = "Loud", Beam = true },
	Prismatic = { Id = "Prismatic", Order = 3, DisplayName = "Prismatic", BuildMult = 8, CoinMult = 15, Color = Color3.fromRGB(255, 130, 220), Color2 = Color3.fromRGB(150, 255, 230), Announce = "Epic", Beam = true },
} :: { [string]: Tier }

MutationConfig.Order = { "Golden", "Diamond", "Prismatic" } -- mutated tiers, lowest to best

MutationConfig.Roll = {
	MinInterval = 45, -- seconds between rolls, uniformly random in [Min, Max]
	MaxInterval = 75,
	-- chance a roll produces a mutation at all: Base at Server Luck 0, rising linearly to AtMaxLuck at Server Luck 100
	ChanceBase = 0.55,
	ChanceAtMaxLuck = 0.9,
	-- relative tier weights, linearly interpolated between Server Luck 0 and 100.
	--   fresh server : Golden 95%, Diamond 5%, Prismatic 0.03% (with ~33 mutations/hour: ~1 Diamond every 40 min,
	--                  a Prismatic about once per 100 server-hours: you may never see one on a fresh server)
	--   maxed server : Golden 77.5%, Diamond 22%, Prismatic 0.6% (~54 mutations/hour: a Diamond every ~5 min,
	--                  a Prismatic roughly once every 3 hours: a real event even on a Legendary Site)
	TierWeights = {
		Golden = { Luck0 = 100, Luck100 = 78 },
		Diamond = { Luck0 = 5.3, Luck100 = 22 },
		Prismatic = { Luck0 = 0.03, Luck100 = 0.6 },
	},
	-- which grade gets mutated: weights by grade (basic piles are the most common so early players see them)
	GradeWeights = { [1] = 45, [2] = 33, [3] = 22 },
	MaxActive = 2, -- piles live at once (a roll while full is skipped)
	NodesPerPile = { 1, 3 }, -- random count of nodes (from the resource's spot) that share the reserve
	Lifetime = 90, -- seconds a pile lasts if its reserve is not emptied first
}

-- Shared reserve in UNITS (not gathers): Base + PerPlayer * players present, per tier.
MutationConfig.Reserve = {
	Golden = { Base = 120, PerPlayer = 14 },
	Diamond = { Base = 90, PerPlayer = 10 },
	Prismatic = { Base = 60, PerPlayer = 7 },
}
-- Personal full-yield allowance in units gathered from ONE pile; afterwards each gather yields ReducedYield of normal.
-- Allowance is sized so a starter (12-30 carry) fills up entirely at full yield, a Wheelbarrow/Hand Cart player gets one strong
-- load, and a Pickup/Dump Truck still benefits (big loads at the reduced yield) without emptying the pile alone.
MutationConfig.PersonalAllowance = { Golden = 40, Diamond = 30, Prismatic = 24 }
MutationConfig.ReducedYield = 0.4

-- Worker auto-redirect: only a pile of a grade the Worker can haul, and only while reserve remains.
MutationConfig.WorkerPriority = { Prismatic = 3, Diamond = 2, Golden = 1 }

-- Announcement text. Kept short; the place name comes from ResourceSpotConfig.
MutationConfig.Announce = {
	Golden = { Title = "Golden %s", Seconds = 2.5 },
	Diamond = { Title = "DIAMOND %s!", Seconds = 4 },
	Prismatic = { Title = "PRISMATIC %s!!", Seconds = 7 },
}
MutationConfig.BeamSeconds = 40 -- how long the world beam marks a new pile (the aura stays for its whole life)

function MutationConfig.Get(id: string?): Tier
	return MutationConfig.Tiers[id or "Normal"] or MutationConfig.Tiers.Normal
end

-- Mutation value after the "all Mythics" Index bonus: the part above 1x is scaled by (1 + bonus).
function MutationConfig.CoinFactor(tierId: string?, bonus: number?): number
	local t = MutationConfig.Get(tierId)
	return 1 + (t.CoinMult - 1) * (1 + (bonus or 0))
end

function MutationConfig.BuildFactor(tierId: string?, bonus: number?): number
	local t = MutationConfig.Get(tierId)
	return 1 + (t.BuildMult - 1) * (1 + (bonus or 0))
end

function MutationConfig.GradeCoin(grade: number): number
	return MutationConfig.GradeCoinMultiplier[grade] or 1
end

-- Chance that a roll creates a pile, and the tier weights, at an effective Server Luck (0..100).
function MutationConfig.ChanceAt(luck: number): number
	local r = MutationConfig.Roll
	return r.ChanceBase + (r.ChanceAtMaxLuck - r.ChanceBase) * math.clamp(luck / 100, 0, 1)
end

function MutationConfig.TierOdds(luck: number): { { id: string, p: number } }
	local t = math.clamp(luck / 100, 0, 1)
	local total, out = 0, {}
	for _, id in MutationConfig.Order do
		local w = MutationConfig.Roll.TierWeights[id]
		local v = w.Luck0 + (w.Luck100 - w.Luck0) * t
		total += v
		table.insert(out, { id = id, p = v })
	end
	for _, e in out do
		e.p /= total
	end
	return out
end

return MutationConfig
