--!strict
-- Cosmetic catalogue: everything a player can OWN that is not power. Ownership lives in
-- PlayerData.Cosmetics[Category][Id] = true (Titles use PlayerData.Titles[name] = true); the selected item per category
-- lives in PlayerData.Equipped[Category] and is mirrored to player attributes (CosTrail / CosSkin / CosCarry / CosContrib)
-- so every client can draw it.
--
-- Categories (all live):
--   WorkerOutfit        dresses your Worker (WorkerConfig.Outfits is the source of truth for the look)
--   Title               shown above your head (Build Index -> Achievements tab equips them)
--   Trail               a light ribbon behind your character (CosmeticVisualController)
--   VehicleSkin         recolours your vehicle when it spawns (VehicleService)
--   CarryEffect         a glow + gentle sparkles on the carried stack (CarryVisualController, ONE light + ONE emitter)
--   ContributionEffect  a short burst at the build site when you deliver (BuildFXController, client side)
--
-- Rewards (DropConfig personal drops, IndexConfig milestones, MasterBuilderConfig ranks, SeasonConfig events, daily
-- rewards) only name (Category, Id) pairs from this catalogue, so a new cosmetic = one entry here + its reward line.
-- Visual fields per category:
--   Trail:              Color (start), Color2 (end), Width, Life (seconds), Glow (0..1 light emission)
--   VehicleSkin:        Body (replaces the vehicle's main colour), Accent (replaces its second colour), Material?
--   CarryEffect:        Glow (light colour), Spark (particle colour), Rate (sparkles/second, keep tiny)
--   ContributionEffect: Color, Color2, Count (particles per delivery burst), Style
local CosmeticConfig = {}

export type Entry = { Name: string, Rarity: string, Description: string, [string]: any }

local function c(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

CosmeticConfig.Catalog = {
	Trail = {
		SawdustTrail = { Name = "Sawdust Trail", Rarity = "Rare", Description = "A puff of sawdust follows your steps.", Color = c(214, 170, 104), Color2 = c(150, 110, 64), Width = 0.7, Life = 0.55, Glow = 0 },
		HazardTrail = { Name = "Hazard Stripe Trail", Rarity = "Epic", Description = "Yellow-and-black caution stripes.", Color = c(255, 204, 36), Color2 = c(50, 50, 56), Width = 0.8, Life = 0.6, Glow = 0.1 },
		LavaTrail = { Name = "Lava Trail", Rarity = "Legendary", Description = "Glowing embers from a Volcano Temple build.", Color = c(255, 140, 40), Color2 = c(190, 40, 20), Width = 0.9, Life = 0.7, Glow = 0.6 },
		StarTrail = { Name = "Stardust Trail", Rarity = "Legendary", Description = "Cosmic sparkles from a UFO sighting.", Color = c(150, 220, 255), Color2 = c(170, 110, 255), Width = 0.8, Life = 0.8, Glow = 0.7 },
		BlueprintTrail = { Name = "Blueprint Trail", Rarity = "Rare", Description = "Master Builder II: a faint blueprint-blue line.", Color = c(96, 170, 240), Color2 = c(30, 70, 140), Width = 0.6, Life = 0.6, Glow = 0.3 },
		VIPTrail = { Name = "VIP Gold Trail", Rarity = "Rare", Description = "VIP Builder: a slim gold shimmer.", Color = c(255, 214, 96), Color2 = c(255, 244, 200), Width = 0.5, Life = 0.5, Glow = 0.4, Paid = "VIPBuilder" },
		RainbowTrail = { Name = "Rainbow Trail", Rarity = "Epic", Description = "Effects Pack: a pink-to-cyan ribbon.", Color = c(255, 100, 170), Color2 = c(90, 220, 255), Width = 0.8, Life = 0.7, Glow = 0.5, Paid = "EffectsPack" },
		OrbitalTrail = { Name = "Orbital Trail", Rarity = "Mythic", Description = "Soft stars orbit your steps. A rare drop from the Orbital Station Master Project.", Color = c(150, 200, 255), Color2 = c(220, 190, 255), Width = 0.55, Life = 0.9, Glow = 0.5, Sparkles = true },
		LanternTrail = { Name = "Lantern Trail", Rarity = "Epic", Description = "Lantern Festival exclusive: warm paper-lantern light.", Color = c(255, 196, 90), Color2 = c(255, 90, 60), Width = 0.8, Life = 0.7, Glow = 0.6 },
	},
	VehicleSkin = {
		SafetyOrange = { Name = "Safety Orange", Rarity = "Rare", Description = "High-visibility paint with a spinning amber roof beacon.", Body = c(255, 120, 24), Accent = c(250, 244, 220), Reflectance = 0.08, AccentMaterial = Enum.Material.Neon },
		GoldenHaul = { Name = "Golden Haul", Rarity = "Legendary", Description = "Polished gold plate that glints as you drive, on a warm gold underglow.", Body = c(238, 190, 56), Accent = c(52, 46, 40), Material = Enum.Material.Metal, Reflectance = 0.3, AccentMaterial = Enum.Material.Metal },
		NeonRacer = { Name = "Neon Racer", Rarity = "Epic", Description = "Vehicle Paint Pack: electric blue with glowing hot pink trim and underglow.", Body = c(30, 110, 255), Accent = c(255, 70, 160), Reflectance = 0.05, AccentMaterial = Enum.Material.Neon, Paid = "VehiclePack" },
		CandyStripe = { Name = "Candy Stripe", Rarity = "Epic", Description = "Vehicle Paint Pack: glossy peppermint stripes with sugar sparkles.", Body = c(225, 40, 60), Accent = c(250, 250, 250), Reflectance = 0.06, Stripes = true, Paid = "VehiclePack" },
		MidnightBlack = { Name = "Midnight Black", Rarity = "Epic", Description = "Vehicle Paint Pack: mirror-gloss black, silver trim and xenon headlight beams.", Body = c(24, 26, 34), Accent = c(190, 198, 212), Material = Enum.Material.SmoothPlastic, Reflectance = 0.12, AccentMaterial = Enum.Material.Metal, Paid = "VehiclePack" },
		DragonScale = { Name = "Dragon Scale", Rarity = "Mythic", Description = "Scaled green-black hide, glowing eyes and a breath of green embers.", Body = c(40, 96, 56), Accent = c(24, 26, 30), Material = Enum.Material.Slate, AccentMaterial = Enum.Material.Basalt },
		MasterChrome = { Name = "Master Chrome", Rarity = "Legendary", Description = "Master Builder VIII: mirror chrome with gold trim, gold glints and underglow.", Body = c(176, 184, 198), Accent = c(240, 182, 36), Material = Enum.Material.Metal, Reflectance = 0.35, AccentMaterial = Enum.Material.Metal },
	},
	CarryEffect = {
		GoldDust = { Name = "Gold Dust", Rarity = "Epic", Description = "Your carried stack sparkles gold.", Glow = c(255, 210, 90), Spark = c(255, 224, 120), Rate = 5 },
		EmberGlow = { Name = "Ember Glow", Rarity = "Legendary", Description = "Your carried stack glows like embers.", Glow = c(255, 120, 40), Spark = c(255, 150, 60), Rate = 6 },
		NeonGlow = { Name = "Neon Glow", Rarity = "Epic", Description = "Effects Pack: your stack glows electric green.", Glow = c(80, 255, 150), Spark = c(150, 255, 200), Rate = 5, Paid = "EffectsPack" },
		PrestigeAura = { Name = "Prestige Aura", Rarity = "Mythic", Description = "Master Builder IX: a pulsing white-blue aura.", Glow = c(150, 210, 255), Spark = c(230, 245, 255), Rate = 7 },
	},
	ContributionEffect = {
		GoldenSparks = { Name = "Golden Sparks", Rarity = "Epic", Description = "Sparks fly from every delivery you make.", Color = c(255, 214, 80), Color2 = c(255, 150, 40), Count = 14, Style = "Sparks" },
		RobotBolts = { Name = "Robot Bolts", Rarity = "Legendary", Description = "Blue bolts crackle when you deliver.", Color = c(110, 200, 255), Color2 = c(60, 110, 255), Count = 12, Style = "Bolts" },
		ConfettiBurst = { Name = "Confetti Burst", Rarity = "Epic", Description = "Effects Pack: a pop of confetti on delivery.", Color = c(255, 120, 200), Color2 = c(120, 230, 255), Count = 16, Style = "Firework", Paid = "EffectsPack" },
		BlueprintBurst = { Name = "Blueprint Burst", Rarity = "Epic", Description = "Master Builder IV: a puff of blueprint lines.", Color = c(120, 190, 255), Color2 = c(255, 255, 255), Count = 12, Style = "Sparks" },
		FireworkBurst = { Name = "Firework Burst", Rarity = "Legendary", Description = "100 builds: a rainbow pop on every delivery.", Color = c(255, 90, 120), Color2 = c(120, 220, 255), Count = 18, Style = "Firework" },
		GrandBurst = { Name = "Grand Burst", Rarity = "Mythic", Description = "Grand Master Builder: a golden-white starburst.", Color = c(255, 236, 150), Color2 = c(255, 255, 255), Count = 22, Style = "Firework" },
	},
}

function CosmeticConfig.Name(category: string, id: string): string
	if category == "Title" then
		return id
	elseif category == "WorkerOutfit" then
		local WorkerConfig = require(script.Parent.WorkerConfig)
		local o = WorkerConfig.Outfits[id]
		return if o then o.DisplayName else id
	end
	local cat = (CosmeticConfig.Catalog :: any)[category]
	local e = cat and cat[id]
	return if e then e.Name else id
end

function CosmeticConfig.Rarity(category: string, id: string): string
	if category == "WorkerOutfit" then
		local WorkerConfig = require(script.Parent.WorkerConfig)
		local o = WorkerConfig.Outfits[id]
		return if o then o.Rarity else "Common"
	end
	local cat = (CosmeticConfig.Catalog :: any)[category]
	local e = cat and cat[id]
	return if e then e.Rarity else "Common"
end

function CosmeticConfig.Get(category: string, id: string): Entry?
	local cat = (CosmeticConfig.Catalog :: any)[category]
	return cat and cat[id]
end

-- Categories a player equips from the Collection menu, with the player attribute that mirrors the selection.
CosmeticConfig.Equippable = {
	{ Category = "Trail", Label = "Trails", Attribute = "CosTrail" },
	{ Category = "VehicleSkin", Label = "Vehicle Skins", Attribute = "CosSkin" },
	{ Category = "CarryEffect", Label = "Carry Effects", Attribute = "CosCarry" },
	{ Category = "ContributionEffect", Label = "Delivery Effects", Attribute = "CosContrib" },
}

return CosmeticConfig
