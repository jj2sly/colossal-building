--!strict
-- CARRY + DELIVERY VFX tuning. Purely visual: nothing here touches carry capacity, deposit rates, values or mutations.
-- Read by CarryVisualController (auras on carried stacks) and DepositFXController (delivery motes + impacts).
--
-- Every look is TWO layers:
--   1. RESOURCE identity, keyed by ResourceConfig Family (Wood, Stone, Metal, PowerCell, StarMetal, AncientTimber).
--   2. MUTATION identity, keyed by MutationConfig tier (Golden, Diamond, Prismatic), layered OVER the resource:
--      the mutation layer borrows the resource's motion (rise / fall / drift, speed, gravity) and only changes colour,
--      sparkle and strength, so a Prismatic Heavy Steel load still throws Metal-style sparks, just prismatic ones.
-- Burst names (Burst / Accent) are the existing pooled Cine.burst kinds also used by gathering (GatherController),
-- so gathering and delivering a resource speak the same visual language.
--
-- Studio pass: everything numeric below is a starting value. Rates are particles/sec, sizes in studs.
local CarryFXConfig = {}

CarryFXConfig.Enabled = true

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

export type Aura = {
	Texture: string,
	Color: { Color3 }, -- 1-3 colours across the particle's life
	Rate: number, -- particles/sec at full intensity (intensity 1)
	Life: { number }, -- { min, max } seconds
	Speed: { number },
	Size: number,
	Gravity: number, -- Y acceleration: negative falls (chips, grit, sparks), positive rises (charge, embers)
	Drag: number,
	Light: number, -- LightEmission
	Spread: number, -- degrees
	Transparency: number, -- starting transparency (fades to 1)
	Glow: Color3?, -- optional PointLight colour once intensity passes LightAt
}

export type Family = {
	Burst: string, -- Cine.burst kind at the impact point
	Accent: string?, -- second Cine.burst kind (dust under a heavy drop, sparks under steel...)
	AccentScale: number,
	MoteMaterial: Enum.Material, -- the little pieces that fly from the hauler to the build
	MoteShape: Enum.PartType,
	MoteArc: number, -- arc height multiplier (heavy stone flies low and fast, power floats high)
	MoteSpeed: number, -- flight-time multiplier (<1 = quicker)
	RingColor: Color3?, -- impact ring tint (nil = no ring for this family below mutated/huge deliveries)
	Aura: Aura, -- carry aura while hauling (resource identity layer)
}

-- RESOURCE IDENTITY ----------------------------------------------------------------------------------------------------
CarryFXConfig.Families = {
	-- woody / natural: wood chips, a stray leaf, warm sawdust drifting down
	Wood = {
		Burst = "Wood", Accent = "Leaf", AccentScale = 0.8,
		MoteMaterial = Enum.Material.Wood, MoteShape = Enum.PartType.Block, MoteArc = 1, MoteSpeed = 1,
		RingColor = nil,
		Aura = {
			Texture = SPARK, Color = { Color3.fromRGB(205, 150, 92), Color3.fromRGB(150, 190, 90) },
			Rate = 3, Life = { 0.9, 1.5 }, Speed = { 0.4, 1.4 }, Size = 0.32, Gravity = -6, Drag = 1.5,
			Light = 0, Spread = 70, Transparency = 0.25,
		},
	},
	-- heavy / geological: grit falling off the load, dust on the drop, a heavier ring
	Stone = {
		Burst = "Stone", Accent = "Dust", AccentScale = 0.55,
		MoteMaterial = Enum.Material.Slate, MoteShape = Enum.PartType.Block, MoteArc = 0.55, MoteSpeed = 0.85,
		RingColor = Color3.fromRGB(214, 200, 176),
		Aura = {
			Texture = SMOKE, Color = { Color3.fromRGB(196, 188, 176), Color3.fromRGB(150, 144, 138) },
			Rate = 2.5, Life = { 0.6, 1.0 }, Speed = { 0.2, 0.8 }, Size = 0.55, Gravity = -10, Drag = 2,
			Light = 0, Spread = 40, Transparency = 0.45,
		},
	},
	-- industrial: small hot sparks shed from the load, a shower on delivery
	Metal = {
		Burst = "Metal", Accent = "Spark", AccentScale = 0.5,
		MoteMaterial = Enum.Material.Metal, MoteShape = Enum.PartType.Block, MoteArc = 0.8, MoteSpeed = 0.9,
		RingColor = Color3.fromRGB(255, 176, 90),
		Aura = {
			Texture = SPARK, Color = { Color3.fromRGB(255, 226, 150), Color3.fromRGB(255, 140, 50) },
			Rate = 3.5, Life = { 0.25, 0.5 }, Speed = { 3, 7 }, Size = 0.18, Gravity = -35, Drag = 1,
			Light = 0.9, Spread = 60, Transparency = 0.05, Glow = Color3.fromRGB(255, 170, 90),
		},
	},
	-- energised: charged motes rising and crackling, an electric pulse ring
	PowerCell = {
		Burst = "Power", Accent = "Spark", AccentScale = 0.3,
		MoteMaterial = Enum.Material.Neon, MoteShape = Enum.PartType.Ball, MoteArc = 1.5, MoteSpeed = 1.15,
		RingColor = Color3.fromRGB(130, 240, 255),
		Aura = {
			Texture = SPARK, Color = { Color3.fromRGB(150, 245, 255), Color3.fromRGB(110, 210, 255), Color3.fromRGB(230, 255, 255) },
			Rate = 4, Life = { 0.4, 0.8 }, Speed = { 0.8, 2.4 }, Size = 0.3, Gravity = 5, Drag = 2,
			Light = 1, Spread = 180, Transparency = 0.1, Glow = Color3.fromRGB(120, 230, 255),
		},
	},
	-- SECRET: meteoric. Cold starlight orbiting the load, a cosmic impact (the existing "Cosmic" kind)
	StarMetal = {
		Burst = "Cosmic", Accent = "Spark", AccentScale = 0.4,
		MoteMaterial = Enum.Material.Neon, MoteShape = Enum.PartType.Block, MoteArc = 1.8, MoteSpeed = 1.2,
		RingColor = Color3.fromRGB(150, 200, 255),
		Aura = {
			Texture = SPARK, Color = { Color3.fromRGB(130, 190, 255), Color3.fromRGB(220, 235, 255), Color3.fromRGB(170, 140, 255) },
			Rate = 6, Life = { 1.2, 2.0 }, Speed = { 0.5, 2 }, Size = 0.4, Gravity = 0.5, Drag = 1.5,
			Light = 0.6, Spread = 180, Transparency = 0.3, Glow = Color3.fromRGB(130, 190, 255),
		},
	},
	-- SECRET: ancient grove. Warm golden pollen and drifting leaves (the existing "Ancient" kind)
	AncientTimber = {
		Burst = "Ancient", Accent = "Leaf", AccentScale = 1.4,
		MoteMaterial = Enum.Material.Wood, MoteShape = Enum.PartType.Cylinder, MoteArc = 1.3, MoteSpeed = 1.25,
		RingColor = Color3.fromRGB(255, 214, 130),
		Aura = {
			Texture = SPARK, Color = { Color3.fromRGB(255, 208, 120), Color3.fromRGB(170, 230, 130) },
			Rate = 5, Life = { 1.4, 2.4 }, Speed = { 0.3, 1.2 }, Size = 0.38, Gravity = 0.8, Drag = 1.5,
			Light = 0.4, Spread = 180, Transparency = 0.35, Glow = Color3.fromRGB(255, 208, 120),
		},
	},
} :: { [string]: Family }

CarryFXConfig.DefaultFamily = "Wood" -- fallback for a resource family with no entry above

-- MUTATION IDENTITY (layered over the resource) -------------------------------------------------------------------------
export type Mutation = {
	Burst: string, -- existing Cine.burst kind (Gold / Diamond / Prismatic)
	BurstScale: number, -- at the impact, multiplied by the delivery's amount scale
	Colors: { Color3 }, -- colours the mutation layer paints onto the resource's motion
	Hue: boolean, -- colours cycle (Prismatic only)
	RateMult: number, -- mutation-layer rate as a multiple of the resource aura's full Rate
	SizeMult: number,
	LightAdd: number, -- added to the resource aura's LightEmission (capped at 1)
	MoteGlow: boolean, -- delivered motes glow neon in the tier colour
	Ring: boolean, -- always draw an impact ring for this tier
	RingScale: number,
	Flash: number, -- impact PointLight brightness (0 = none)
}

CarryFXConfig.Mutations = {
	-- gold energy and sparkle over the resource: warmer, brighter, a little more of it
	Golden = {
		Burst = "Gold", BurstScale = 0.6,
		Colors = { Color3.fromRGB(255, 214, 90), Color3.fromRGB(255, 246, 190) }, Hue = false,
		RateMult = 1.6, SizeMult = 1.1, LightAdd = 0.5, MoteGlow = true, Ring = false, RingScale = 1, Flash = 0,
	},
	-- sharp, clean, crystalline: fewer but crisper, cooler and brighter particles, plus a clean ring on delivery
	Diamond = {
		Burst = "Diamond", BurstScale = 0.7,
		Colors = { Color3.fromRGB(245, 253, 255), Color3.fromRGB(140, 232, 255) }, Hue = false,
		RateMult = 2.2, SizeMult = 0.8, LightAdd = 0.8, MoteGlow = true, Ring = true, RingScale = 1.1, Flash = 1.5,
	},
	-- the rarest presentation: the resource's motion in shifting pastel hues, strongest rate, ring and flash
	Prismatic = {
		Burst = "Prismatic", BurstScale = 0.8,
		Colors = { Color3.fromRGB(255, 150, 230), Color3.fromRGB(150, 255, 230), Color3.fromRGB(255, 240, 150) }, Hue = true,
		RateMult = 3.5, SizeMult = 1.25, LightAdd = 1, MoteGlow = true, Ring = true, RingScale = 1.4, Flash = 2.5,
	},
} :: { [string]: Mutation }

-- CARRY INTENSITY --------------------------------------------------------------------------------------------------------
-- intensity (0..Max) = (FillWeight * fill + AmountWeight * amountScale) * GradeMult[grade]
--   fill        = CarryTotal / CarryCap
--   amountScale = log2(1 + CarryTotal / AmountRef) / log2(1 + AmountCap / AmountRef)   (0..1, so huge vehicle loads saturate)
-- The resource aura only appears above MinIntensity, so a half-full basic load stays clean.
CarryFXConfig.Carry = {
	FillWeight = 0.65,
	AmountWeight = 0.35,
	AmountRef = 20,
	AmountCap = 400,
	GradeMult = { [1] = 0.55, [2] = 0.85, [3] = 1.15 },
	SecretMult = 1.4, -- Star Metal / Ancient Timber always shimmer (they are endgame)
	SecretMinIntensity = 0.35,
	MinIntensity = 0.4, -- below this a NORMAL load has no resource aura at all (a full basic starter load sits just above)
	Max = 1.5,
	LightAt = 0.9, -- resource glow light appears above this intensity (families with Glow only)
	LightRange = 7,
	LightBrightness = 0.35,
	-- the mutation layer scales with the MUTATED share of the load (a single Golden unit in a big load is a hint, not a fountain)
	-- mutation layer strength = max(MutShareFloor, mutatedShare) * max(MutMinIntensity, intensity)
	MutShareFloor = 0.5,
	MutMinIntensity = 0.5,
	-- distance + budget (25 players: worst case is every hauler on screen at once)
	CullDistance = 220, -- studs from the camera; beyond this auras switch off
	MaxAuras = 12, -- nearest N stacks keep their resource aura; mutation layers always survive culling within range
	UpdateHz = 4,
}

-- DELIVERY ---------------------------------------------------------------------------------------------------------------
-- A delivery = the drop in a player's Carry_<Res> attributes while they stand in the deposit zone (the server already
-- replicates these to everyone, so nothing new crosses the network). Drops are pooled per player for Window seconds.
CarryFXConfig.Deposit = {
	Window = 0.3,
	AmountRef = 10, -- amountScale = clamp(log2(1 + amount / AmountRef) / log2(1 + AmountCap / AmountRef), 0.15, 1)
	AmountCap = 300,
	GradeMult = { [1] = 0.8, [2] = 1.0, [3] = 1.25 },
	SecretMult = 1.4,
	-- impact point: on the deck rim toward the hauler
	ImpactRadius = 84,
	ImpactHeight = 2,
	BurstScale = 1.1, -- resource burst at amountScale 1
	RingSize = 14, -- studs at amountScale 1 (family RingColor only draws when amountScale >= RingAt)
	RingAt = 0.55,
	RingSeconds = 0.7,
	-- motes: small pooled parts that arc from the hauler to the impact point
	Motes = { Min = 2, Max = 9, MutatedExtra = 3, Size = 0.6, FlightTime = 0.55, ArcHeight = 10, Pool = 64 },
	FlashRange = 18,
	FlashSeconds = 0.35,
	-- crowd protection (25 players depositing at once)
	CullDistance = 320, -- other players' deliveries beyond this distance are skipped entirely
	MaxPerSecond = 6, -- other players' delivery effects per second (your own always play)
	RemoteScale = 0.6, -- other players' deliveries are drawn at this fraction of their size
	MaxRings = 6,
}

local function log2(x: number): number
	return math.log(x) / math.log(2)
end

-- Carry intensity for a stack (see CarryFXConfig.Carry). `grade` is the best grade of the dominant family.
function CarryFXConfig.CarryIntensity(total: number, cap: number, grade: number, secret: boolean): number
	local c = CarryFXConfig.Carry
	if total <= 0 then
		return 0
	end
	local fill = if cap > 0 then math.clamp(total / cap, 0, 1) else 1
	local amount = math.clamp(log2(1 + total / c.AmountRef) / log2(1 + c.AmountCap / c.AmountRef), 0, 1)
	local i = (c.FillWeight * fill + c.AmountWeight * amount) * (c.GradeMult[grade] or 1)
	if secret then
		i = math.max(c.SecretMinIntensity, i * c.SecretMult)
	end
	return math.clamp(i, 0, c.Max)
end

-- Size of one delivery (0.15..~1.75): amount on a log curve, times grade and secret multipliers.
function CarryFXConfig.DepositScale(amount: number, grade: number, secret: boolean): number
	local d = CarryFXConfig.Deposit
	local s = math.clamp(log2(1 + amount / d.AmountRef) / log2(1 + d.AmountCap / d.AmountRef), 0.15, 1)
	return s * (d.GradeMult[grade] or 1) * (if secret then d.SecretMult else 1)
end

function CarryFXConfig.Family(family: string?): Family
	return CarryFXConfig.Families[family or ""] or CarryFXConfig.Families[CarryFXConfig.DefaultFamily]
end

return CarryFXConfig
