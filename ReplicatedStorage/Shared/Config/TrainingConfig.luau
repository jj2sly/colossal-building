--!strict
-- CHARACTER TRAINING (Strength + Speed). Replaces the purchased Carry Capacity / Walk Speed
-- upgrades: these stats are earned by actively training at the Training Yard, never bought.
--
-- Persistent value per stat is TRAINING POINTS (a single number). Level is derived:
--   cost to go from level L to L+1 = round(CostBase * CostGrowth ^ L)   (so each level takes longer)
--   effect(level) is defined per stat below and always capped by MaxLevel.
-- Everything the server and the UI need (formulas, caps, anti-abuse numbers) is in this file.
local TrainingConfig = {}

TrainingConfig.Stats = {
	Strength = {
		Id = "Strength",
		DisplayName = "Strength",
		Icon = "dumbbell",
		Description = "Bench press, crate lifting, beam carrying and hauling. Raises how much you can carry (and your vehicle's cargo).",
		MaxLevel = 100,
		-- LINEAR carry: Base + PerLevel * level  ->  12 at level 0, 62 at 50, 112 at 100. Vehicles multiply the player's carry,
		-- so Strength stays useful forever (Formulas.CarryCapacity).
		Base = 12,
		PerLevel = 1.0,
		Station = "Strength",
		EffectLabel = "Carry",
	},
	Speed = {
		Id = "Speed",
		DisplayName = "Speed",
		Icon = "chevrons",
		Description = "Treadmill, the race track and travelling on foot. Raises your walk speed.",
		MaxLevel = 100,
		-- LINEAR walk speed: Base + MaxBonus * level / MaxLevel  ->  18 at level 0, 27.5 at 50, 37 at 100 (Power 1 = linear).
		Base = 18,
		MaxBonus = 19,
		Power = 1,
		Station = "Speed",
		EffectLabel = "Speed",
	},
} :: { [string]: any }

-- XP CURVE. Cost to go from level L to L+1 = linear interpolation of CurveAnchors (level -> XP for that level), so every
-- band feels different and the whole curve is one table to retune. Cumulative XP and dedicated time at ~35 XP/min:
--   level 10  ~0.6k  (~17 min: the introduction)      level 25 ~2.6k (~1.2 h: early game)
--   level 50  ~9.3k  (~4.5 h: midgame)                  level 75 ~21k  (~10 h)
--   level 100 ~36k   (~17 h per stat dedicated; natural XP, Master Builder +5%/rank and the 50% kept on reset cut this a lot)
TrainingConfig.CurveAnchors = {
	{ Level = 0, Cost = 40 },
	{ Level = 10, Cost = 80 },
	{ Level = 25, Cost = 180 },
	{ Level = 50, Cost = 360 },
	{ Level = 75, Cost = 540 },
	{ Level = 100, Cost = 720 },
}

-- NATURAL XP: a SMALL trickle from normal play (never fatiguing, never from vehicles). Dedicated training stays several
-- times faster. Awarded by TrainingService; all values are per-second / per-stud / per-unit starting numbers.
TrainingConfig.Natural = {
	Strength = {
		MinLoadFraction = 0.30, -- carry at least this share of your capacity to count as "hauling"
		CarryXPPerSecond = 0.09, -- at a full load, while moving on foot (scaled by load fraction)
		DeliverXPPerUnit = 0.03, -- per unit delivered on foot at the build site
		MaxPerMinute = 8, -- ~1/5 of dedicated training; a 2 h session of normal play is worth roughly level 10-13 from scratch
	},
	Speed = {
		XPPerStud = 0.005, -- ~5.4 XP/min walking at base speed (a treadmill gives 18, the race track ~33)
		MinStep = 40, -- XP is only awarded for a chunk once you are at least this far (straight line) from where it started,
		-- so pacing in circles or wiggling in place earns nothing
		MaxPerMinute = 8,
	},
}

-- MASTER BUILDER: permanent training XP bonus per rank (stacks; rank 10 = +50%).
TrainingConfig.MasterBuilderXPPerRank = 0.05

-- MILESTONES: a notification (and optional title / cosmetic) the first time a stat level is reached. Level 100 is special.
TrainingConfig.Milestones = {
	Strength = {
		[10] = { Text = "Strength 10: Warming Up" },
		[25] = { Text = "Strength 25: Hauler", Title = "Hauler" },
		[50] = { Text = "Strength 50: Powerhouse", Title = "Powerhouse" },
		[75] = { Text = "Strength 75: Titan", Title = "Titan" },
		[100] = { Text = "STRENGTH 100: MAX!", Title = "Colossus", Cosmetic = { Category = "CarryEffect", Item = "EmberGlow" }, Big = true },
	},
	Speed = {
		[10] = { Text = "Speed 10: Quick Feet" },
		[25] = { Text = "Speed 25: Sprinter", Title = "Sprinter" },
		[50] = { Text = "Speed 50: Blur", Title = "Blur" },
		[75] = { Text = "Speed 75: Bolt", Title = "Bolt" },
		[100] = { Text = "SPEED 100: MAX!", Title = "Lightning", Cosmetic = { Category = "Trail", Item = "StarTrail" }, Big = true },
	},
} :: { [string]: { [number]: { Text: string, Title: string?, Cosmetic: { Category: string, Item: string }?, Big: boolean? } } }

-- TRAINING STATIONS. Two kinds of progression:
--   PASSIVE / CONVENIENT: hands-off, lower XP per minute (Treadmill = Speed, Bench Press = Strength).
--   ACTIVE: real gameplay, clearly better XP per minute (Race Track = Speed, Crate Lift / Beam Carry = Strength).
-- All rates are provisional starting values (nothing here was benchmarked). Typical XP per minute before stamina:
--   Treadmill 18  ->  Race Track about 31 typical (about 1.7x) up to the 36 cap for tight laps (2.0x)
--   Bench Press 14 ->  Crate Lift about 28-30, Beam Carry about 30 (about 2.1x)
-- Every XP award still goes through stamina and the per-minute ceiling below, and only the server awards XP.

-- Passive sessions: step on / lie down, the character is held in place and trained automatically.
TrainingConfig.Treadmill = {
	Stat = "Speed",
	Radius = 12, -- must be this close to the machine to start (and stay)
	TickSeconds = 3,
	XPPerTick = 0.9, -- 18 XP/min
	BlockWithVehicle = true,
	Label = "Treadmill",
	-- Placeholder animation settings (procedural limb swing). Set AnimationId to an authored run animation to replace it.
	AnimationId = nil :: string?,
	RunCycleHz = 2.4,
	-- (Pass 21C) TREADMILL LEVELS: each treadmill carries a Level attribute (1..3); Level N needs Master Builder rank Rank. Without rank 1 no
	-- treadmill can be used. XPMult scales the passive XP (stamina and the per-minute ceiling still apply). Provisional numbers.
	-- (Pass 21D) five themed levels: Starter, Steel, Gold, Hacker, Cosmic. Color = neon accent, Label = the "xN SPEED" tag.
	-- (Pass 21E) level 1 is FREE (rank 0); every further level needs one more Master Builder rank.
	Tiers = {
		{ Rank = 0, XPMult = 1, Name = "Starter Treadmill", Label = "x1 SPEED", Color = Color3.fromRGB(255, 176, 64) },
		{ Rank = 1, XPMult = 1.35, Name = "Steel Treadmill", Label = "x1.35 SPEED", Color = Color3.fromRGB(96, 206, 255) },
		{ Rank = 2, XPMult = 1.7, Name = "Gold Treadmill", Label = "x1.7 SPEED", Color = Color3.fromRGB(255, 220, 90) },
		{ Rank = 3, XPMult = 2.15, Name = "Hacker Treadmill", Label = "x2.15 SPEED", Color = Color3.fromRGB(84, 255, 132) },
		{ Rank = 4, XPMult = 2.7, Name = "Cosmic Treadmill", Label = "x2.7 SPEED", Color = Color3.fromRGB(238, 124, 255) },
	} :: { { Rank: number, XPMult: number, Name: string, Label: string, Color: Color3 } },
}

TrainingConfig.Bench = {
	Stat = "Strength",
	Radius = 12,
	TickSeconds = 3,
	XPPerTick = 0.7, -- 14 XP/min
	BlockWithVehicle = true,
	Label = "Bench Press",
	AnimationId = nil :: string?, -- authored bench-press animation goes here later
	RepSeconds = 2.2, -- one press cycle (visual only; XP is time based)
	-- (Pass 21E) five bench levels, same rule as the treadmills: level 1 free, each further level one more Master Builder rank.
	Tiers = {
		{ Rank = 0, XPMult = 1, Name = "Starter Bench", Label = "x1 STRENGTH", Color = Color3.fromRGB(255, 176, 64) },
		{ Rank = 1, XPMult = 1.35, Name = "Steel Bench", Label = "x1.35 STRENGTH", Color = Color3.fromRGB(96, 206, 255) },
		{ Rank = 2, XPMult = 1.7, Name = "Gold Bench", Label = "x1.7 STRENGTH", Color = Color3.fromRGB(255, 220, 90) },
		{ Rank = 3, XPMult = 2.15, Name = "Hacker Bench", Label = "x2.15 STRENGTH", Color = Color3.fromRGB(84, 255, 132) },
		{ Rank = 4, XPMult = 2.7, Name = "Cosmic Bench", Label = "x2.7 STRENGTH", Color = Color3.fromRGB(238, 124, 255) },
	} :: { { Rank: number, XPMult: number, Name: string, Label: string, Color: Color3 } },
}

-- Active carry tasks: pick up at one marked point, deliver to the other. Heavier = slower.
TrainingConfig.Crate = {
	Stat = "Strength",
	Radius = 10, -- reach for the pickup / drop prompts
	XP = 3.2, -- per delivered crate
	CarrySpeedFactor = 0.65, -- of your normal walk speed while carrying
	MinTravelSpeedFactor = 1.3, -- server rejects a delivery faster than distance / (walk speed x this)
	Label = "Crate Lift",
}

TrainingConfig.Beam = {
	Stat = "Strength",
	Radius = 10,
	XP = 7.5,
	CarrySpeedFactor = 0.5,
	MinTravelSpeedFactor = 1.3,
	Label = "Beam Carry",
}

-- Race track: pass the gates in order. Each full lap pays once. THE BEST Speed method.
TrainingConfig.Run = {
	GateRadius = 9,
	-- (Pass 21E) the track runs round the whole pad, so a lap pays by DISTANCE: XPPerStud x the loop's length (measured from the gates).
	-- Old loop: 8 XP for ~184 studs (0.043 per stud). Now ~640 studs for ~29 XP: longer trip, more XP, a little better per minute.
	XPPerStud = 0.045,
	XPPerLap = 8, -- fallback only (fewer than 3 gates)
	MaxSpeedFactor = 1.3, -- a lap faster than this multiple of your walk speed is rejected (teleport/exploit)
	LapTimeout = 120, -- seconds to finish a lap once started (the loop is ~3.5x longer)
	BlockWithVehicle = true, -- vehicles trivialise laps; park first
}

-- Shared stamina: every rep/lap makes you tired; tired = less XP. Recovers over time, so long
-- grind sessions pay far less per minute than short, focused ones.
TrainingConfig.Stamina = {
	GainPerRep = 0.02,
	GainPerLap = 0.06,
	RecoveryPerSecond = 0.008,
	MinMultiplier = 0.25,
	-- hard ceiling per rolling minute, whatever the other rules allow
	MaxXPPerMinute = { Strength = 60, Speed = 60 }, -- raised from 40 so the higher machine levels and the long lap can pay out
}

-- Old purchasable upgrades converted into training on first load (nobody loses progress).
-- Legacy level * LevelsPer => starting training level (clamped to MaxLevel).
TrainingConfig.Legacy = {
	CarryCapacity = { Stat = "Strength", LevelsPer = 1.4 },
	WalkSpeed = { Stat = "Speed", LevelsPer = 1.6 },
}

-- Points needed to go from `level` to `level + 1` (interpolated from CurveAnchors, same curve for every stat).
function TrainingConfig.Cost(_statId: string, level: number): number
	local a = TrainingConfig.CurveAnchors
	level = math.max(0, level)
	for k = 1, #a - 1 do
		if level <= a[k + 1].Level then
			local t = (level - a[k].Level) / (a[k + 1].Level - a[k].Level)
			return math.floor(a[k].Cost + (a[k + 1].Cost - a[k].Cost) * t + 0.5)
		end
	end
	return a[#a].Cost
end

-- Total points required to be at `level`.
function TrainingConfig.PointsFor(statId: string, level: number): number
	local total = 0
	for l = 0, math.clamp(level, 0, TrainingConfig.Stats[statId].MaxLevel) - 1 do
		total += TrainingConfig.Cost(statId, l)
	end
	return total
end

-- (level, pointsIntoLevel, pointsNeeded) for a points total. At MaxLevel needed = 0.
function TrainingConfig.Progress(statId: string, points: number): (number, number, number)
	local s = TrainingConfig.Stats[statId]
	local level, rest = 0, math.max(0, points)
	while level < s.MaxLevel do
		local cost = TrainingConfig.Cost(statId, level)
		if rest < cost then
			return level, rest, cost
		end
		rest -= cost
		level += 1
	end
	return s.MaxLevel, 0, 0
end

function TrainingConfig.Level(statId: string, points: number): number
	local level = TrainingConfig.Progress(statId, points)
	return level
end

-- The stat's real-world effect at a level (carry capacity for Strength, walk speed for Speed).
function TrainingConfig.Effect(statId: string, level: number): number
	local s = TrainingConfig.Stats[statId]
	level = math.clamp(level, 0, s.MaxLevel)
	if statId == "Strength" then
		return s.Base + s.PerLevel * level
	end
	return s.Base + s.MaxBonus * (level / s.MaxLevel) ^ s.Power
end

return TrainingConfig
