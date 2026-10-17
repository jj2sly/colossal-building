--!strict
-- One Worker per player (not a pet army). Stats are multiplied by the owner's
-- Worker Efficiency upgrade. Workers are deliberately weaker than an active player.
--
-- Workers are Roblox characters (an R15 rig dressed by an OUTFIT), a member of the player's construction crew.
--
-- WORKER TYPES: small specialties on top of the shared base stats. A type may be better at one material family
-- (shorter gather time, bigger load) and/or hauls more at a speed cost. Specialties are deliberately modest.
-- The first type (Builder / General Laborer) is the 500 Coin hire; other types are bought once with `Price`
-- (they are NOT stacked: still ONE active Worker). Types and prices are provisional.
--
-- WORKER OUTFITS are cosmetic. `Standard` is free; each type's own outfit is granted with the type; rare outfits
-- are granted by build drops, Index milestones and Master Builder rewards (see DropConfig / IndexConfig) through
-- CosmeticService into PlayerData.Cosmetics.WorkerOutfit.
local WorkerConfig = {}

export type WorkerType = {
	Id: string,
	DisplayName: string,
	Description: string,
	UnlockPrice: number, -- the 500 Coin hire (default type only)
	Price: number, -- one-time purchase for non-default types
	CarryAmount: number,
	MoveSpeed: number, -- studs/sec (players start at 16). BALANCE: about a quarter of an active player at base, about half at max Worker Efficiency
	GatherTime: number, -- seconds per load at the zone
	DepositTime: number,
	BodyColor: Color3,
	Outfit: string, -- default outfit id
	Specialty: { Family: string, CarryBonus: number, GatherFactor: number }?, -- bonus when working this material family
	CarryBonus: number, -- general carry bonus (Hauler)
	SpeedFactor: number, -- general speed factor (Hauler is slower)
	MaxGrade: number, -- highest resource grade this Worker can haul (3 = everything)
}

local function base(id: string, name: string, desc: string, outfit: string, color: Color3): WorkerType
	return {
		Id = id, DisplayName = name, Description = desc,
		UnlockPrice = 500, Price = 1500,
		CarryAmount = 12, MoveSpeed = 16, GatherTime = 3, DepositTime = 1,
		BodyColor = color, Outfit = outfit, Specialty = nil, CarryBonus = 0, SpeedFactor = 1, MaxGrade = 2,
	}
end

local types: { [string]: WorkerType } = {}
types.Builder = base("Builder", "General Laborer", "Reliable all-rounder. Hauls any basic or refined material.", "Standard", Color3.fromRGB(255, 196, 40))
types.Builder.Price = 0

types.Lumber = base("Lumber", "Lumber Worker", "A little faster and stronger on Wood-family materials.", "Lumber", Color3.fromRGB(170, 70, 50))
types.Lumber.Specialty = { Family = "Wood", CarryBonus = 0.15, GatherFactor = 0.85 }

types.Quarry = base("Quarry", "Quarry Worker", "A little faster and stronger on Stone-family materials.", "Quarry", Color3.fromRGB(150, 150, 160))
types.Quarry.Specialty = { Family = "Stone", CarryBonus = 0.15, GatherFactor = 0.85 }

types.Welder = base("Welder", "Metal Worker", "A little faster and stronger on Metal-family materials.", "Welding", Color3.fromRGB(70, 90, 120))
types.Welder.Specialty = { Family = "Metal", CarryBonus = 0.15, GatherFactor = 0.85 }

types.Technician = base("Technician", "Technician", "A little faster and stronger on Power-family materials.", "Technician", Color3.fromRGB(60, 150, 190))
types.Technician.Specialty = { Family = "PowerCell", CarryBonus = 0.15, GatherFactor = 0.85 }

types.Hauler = base("Hauler", "Hauler", "Carries bigger loads of anything, but walks a little slower. Can haul premium grades.", "Hauler", Color3.fromRGB(230, 120, 40))
types.Hauler.CarryBonus = 0.20
types.Hauler.SpeedFactor = 0.9
types.Hauler.MaxGrade = 3

-- WORKER TIERS: a Worker works at a share of YOUR potential (your Strength carry, walk speed and gather speed), so it
-- keeps up as you train. The type (Lumber, Quarry...) is only a specialty on top of the tier.
export type Tier = { Id: string, DisplayName: string, Share: number, Color: Color3, CrateWeight: number, TokenValue: number, ForgeCost: number? }
WorkerConfig.Tiers = {
	Basic = { Id = "Basic", DisplayName = "Basic", Share = 0.50, Color = Color3.fromRGB(190, 196, 206), CrateWeight = 60, TokenValue = 1, ForgeCost = nil },
	Skilled = { Id = "Skilled", DisplayName = "Skilled", Share = 0.60, Color = Color3.fromRGB(96, 214, 110), CrateWeight = 28, TokenValue = 3, ForgeCost = 10 },
	Expert = { Id = "Expert", DisplayName = "Expert", Share = 0.70, Color = Color3.fromRGB(70, 150, 255), CrateWeight = 10, TokenValue = 8, ForgeCost = 30 },
	Master = { Id = "Master", DisplayName = "Master", Share = 0.80, Color = Color3.fromRGB(255, 176, 32), CrateWeight = 2, TokenValue = 20, ForgeCost = 80 },
} :: { [string]: Tier }
WorkerConfig.TierOrder = { "Basic", "Skilled", "Expert", "Master" }
WorkerConfig.DefaultTier = "Basic"

-- WORKER CRATES (Coins only): each opening rolls one (type, tier) Worker from the tiers the player has unlocked.
-- Tier availability is gated by Master Builder rank. A roll you already own turns into Worker Tokens (TokenValue of its
-- tier) instead of being wasted; tokens can Forge the equipped Worker up a tier (ForgeCost) or be used by later systems.
-- PITY: after `Threshold` crates without a tier of `GuaranteeTier` or better, the next roll is guaranteed that tier (if unlocked).
WorkerConfig.Crate = { Price = 900, PriceGrowth = 1.12, MaxPrice = 6000, Pity = { Threshold = 12, GuaranteeTier = "Skilled" } }
-- FIRST HIRE: your very first recruit is a cheap, guaranteed Basic General Laborer so every new player meets Workers in their first
-- few minutes (the onboarding objective points at it). Later recruits are the normal random crates above.
WorkerConfig.FirstHirePrice = 150
-- Floors so a fresh Basic Worker is useful ("he's helping while I work") without beating you: at Strength 0 you carry 12 at
-- 18 studs/s, the Basic Worker 8 at 14 (about 45% of your output); a Skilled Worker overtakes these floors after a few levels.
WorkerConfig.MinMoveSpeed = 14
WorkerConfig.MinCarry = 8
WorkerConfig.CrateTierMinRank = { Basic = 0, Skilled = 0, Expert = 1, Master = 3 }

-- Worker stats from the owner's CURRENT stats: carry = player carry x Share (x type bonuses), speed = player walk speed x
-- Share, gather time falls with Share and the owner's Gather Speed. Returns (carryAmount, moveSpeed, gatherTime).
function WorkerConfig.Scaled(def: any, tierId: string?, playerCarry: number, playerSpeed: number, gatherSpeed: number, efficiency: number): (number, number, number)
	local tier = WorkerConfig.Tiers[tierId or WorkerConfig.DefaultTier] or WorkerConfig.Tiers.Basic
	local f = 1 + (efficiency - 1) * 0.5
	local carry = math.max(WorkerConfig.MinCarry, math.floor(playerCarry * tier.Share * f))
	local speed = math.max(WorkerConfig.MinMoveSpeed, playerSpeed * tier.Share) * f
	local gather = def.GatherTime * (0.5 / tier.Share) / math.max(0.5, gatherSpeed) / f
	return carry, speed, gather
end

WorkerConfig.Types = types
WorkerConfig.TypeOrder = { "Builder", "Lumber", "Quarry", "Welder", "Technician", "Hauler" }
WorkerConfig.DefaultType = "Builder"
WorkerConfig.Assignments = { "Auto", "Wood", "Stone", "Metal", "PowerCell" }

-- Carry / speed / gather multipliers for a type working a given material family.
function WorkerConfig.Modifiers(def: WorkerType, family: string?): (number, number, number)
	local carry, gather = 1 + def.CarryBonus, 1
	local sp = def.Specialty
	if sp and family == sp.Family then
		carry += sp.CarryBonus
		gather = sp.GatherFactor
	end
	return carry, def.SpeedFactor, gather
end

------------------------------------------------------------------ outfits
export type Outfit = {
	Id: string,
	DisplayName: string,
	Rarity: string, -- Common | Rare | Epic | Legendary | Mythic (display only)
	Shirt: Color3,
	Pants: Color3,
	Skin: Color3,
	Hat: string, -- HardHat | Cap | Headband | WeldMask | Headset | CrownHat
	HatColor: Color3,
	Accent: Color3, -- sleeve / badge / pack accent colour
	Tool: string, -- role tool: Hammer | Axe | Pickaxe | Torch | Tablet | Backpack
	Vest: Color3?, -- optional hi-vis vest
	Source: string, -- where it comes from (documentation + UI)
}

local function outfit(id: string, name: string, rarity: string, shirt: Color3, pants: Color3, hat: string, hatColor: Color3, vest: Color3?, source: string): Outfit
	return { Id = id, DisplayName = name, Rarity = rarity, Shirt = shirt, Pants = pants, Skin = Color3.fromRGB(240, 200, 150), Hat = hat, HatColor = hatColor, Accent = hatColor, Tool = "Hammer", Vest = vest, Source = source }
end

WorkerConfig.Outfits = {
	Standard = outfit("Standard", "Standard Crew", "Common", Color3.fromRGB(210, 210, 215), Color3.fromRGB(60, 80, 130), "HardHat", Color3.fromRGB(255, 205, 40), Color3.fromRGB(255, 120, 30), "Free"),
	Lumber = outfit("Lumber", "Lumberjack", "Common", Color3.fromRGB(176, 52, 44), Color3.fromRGB(70, 60, 50), "Cap", Color3.fromRGB(90, 130, 70), nil, "Lumber Worker"),
	Quarry = outfit("Quarry", "Quarry Crew", "Common", Color3.fromRGB(140, 140, 150), Color3.fromRGB(86, 80, 70), "HardHat", Color3.fromRGB(235, 235, 235), Color3.fromRGB(240, 200, 40), "Quarry Worker"),
	Welding = outfit("Welding", "Welder", "Common", Color3.fromRGB(60, 74, 100), Color3.fromRGB(40, 44, 54), "WeldMask", Color3.fromRGB(70, 74, 82), nil, "Metal Worker"),
	Technician = outfit("Technician", "Technician", "Common", Color3.fromRGB(240, 240, 245), Color3.fromRGB(46, 90, 120), "Headset", Color3.fromRGB(60, 200, 230), Color3.fromRGB(80, 220, 255), "Technician"),
	Hauler = outfit("Hauler", "Hauler", "Common", Color3.fromRGB(226, 120, 40), Color3.fromRGB(50, 50, 56), "Cap", Color3.fromRGB(40, 40, 46), Color3.fromRGB(255, 120, 30), "Hauler"),
	GoldenCrew = outfit("GoldenCrew", "Golden Crew", "Epic", Color3.fromRGB(240, 196, 60), Color3.fromRGB(70, 56, 30), "HardHat", Color3.fromRGB(255, 232, 120), Color3.fromRGB(255, 255, 255), "Golden build drop"),
	SiteForeman = outfit("SiteForeman", "Site Foreman", "Rare", Color3.fromRGB(46, 80, 60), Color3.fromRGB(40, 40, 48), "HardHat", Color3.fromRGB(240, 240, 240), Color3.fromRGB(255, 190, 30), "Index milestone"),
	MasterCrew = outfit("MasterCrew", "Master Builder Crew", "Legendary", Color3.fromRGB(30, 30, 38), Color3.fromRGB(30, 30, 38), "CrownHat", Color3.fromRGB(255, 205, 40), Color3.fromRGB(255, 205, 40), "Master Builder (later)"),
	VIPCrew = outfit("VIPCrew", "VIP Crew", "Epic", Color3.fromRGB(30, 30, 40), Color3.fromRGB(30, 30, 40), "CrownHat", Color3.fromRGB(255, 214, 96), Color3.fromRGB(255, 214, 96), "VIP Builder pass"),
	NeonCrew = outfit("NeonCrew", "Neon Crew", "Epic", Color3.fromRGB(40, 40, 60), Color3.fromRGB(30, 30, 44), "Headset", Color3.fromRGB(90, 255, 170), Color3.fromRGB(90, 255, 170), "Worker Outfit Pack"),
	FrostCrew = outfit("FrostCrew", "Frost Crew", "Epic", Color3.fromRGB(200, 232, 250), Color3.fromRGB(70, 110, 160), "Cap", Color3.fromRGB(240, 250, 255), Color3.fromRGB(150, 210, 250), "Worker Outfit Pack"),
	RetroCrew = outfit("RetroCrew", "Retro Crew", "Epic", Color3.fromRGB(240, 130, 60), Color3.fromRGB(70, 50, 120), "Headband", Color3.fromRGB(255, 230, 90), Color3.fromRGB(70, 200, 200), "Worker Outfit Pack"),
	IndexScout = outfit("IndexScout", "Index Scout", "Epic", Color3.fromRGB(96, 70, 150), Color3.fromRGB(40, 40, 52), "Cap", Color3.fromRGB(240, 182, 36), Color3.fromRGB(240, 182, 36), "50 builds completed"),
	IndexArchitect = outfit("IndexArchitect", "Index Architect", "Legendary", Color3.fromRGB(236, 238, 244), Color3.fromRGB(30, 46, 90), "CrownHat", Color3.fromRGB(96, 190, 230), Color3.fromRGB(96, 190, 230), "Entire Index complete"),
}
-- role tools and accents (ART PASS): each outfit reads at a glance
local tools = { Standard = "Hammer", Lumber = "Axe", Quarry = "Pickaxe", Welding = "Torch", Technician = "Tablet", Hauler = "Backpack", GoldenCrew = "Hammer", SiteForeman = "Tablet", MasterCrew = "Hammer", IndexScout = "Tablet", IndexArchitect = "Tablet", VIPCrew = "Hammer", NeonCrew = "Tablet", FrostCrew = "Backpack", RetroCrew = "Hammer" }
for id, tool in tools do
	WorkerConfig.Outfits[id].Tool = tool
end
WorkerConfig.Outfits.Standard.Accent = Color3.fromRGB(255, 140, 40)
WorkerConfig.Outfits.Lumber.Accent = Color3.fromRGB(255, 190, 60)
WorkerConfig.Outfits.Quarry.Accent = Color3.fromRGB(255, 200, 40)
WorkerConfig.Outfits.Welding.Accent = Color3.fromRGB(255, 130, 40)
WorkerConfig.Outfits.Technician.Accent = Color3.fromRGB(80, 230, 255)
WorkerConfig.Outfits.Hauler.Accent = Color3.fromRGB(255, 140, 40)
WorkerConfig.DefaultOutfit = "Standard"

return WorkerConfig
