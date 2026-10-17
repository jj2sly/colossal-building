--!strict
-- Resource definitions. Gathering, carrying, depositing and UI all read from here;
-- there is ONE gathering implementation for every resource.
--
-- RESOURCE GRADES: every material family has up to three grades (1 = basic, 2 = refined, 3 = premium).
-- Each grade is its own resource id so it can be gathered, carried, displayed and requested separately.
-- Grade 1 keeps the original family id (Wood, Stone, Metal, PowerCell), so old builds and saves keep working.
--
--   Requirement rule: a build requirement on id X is satisfied by X or any HIGHER grade of the same family,
--   so a requirement on "Wood" accepts Sticks, Logs and Timber, while a requirement on "Timber" accepts only Timber.
--   A delivered unit counts `Equivalent` units (a Log counts more than a Stick) toward the requirement.
--
-- To add a resource: add an entry here (Family + Grade), add a spot in ResourceSpotConfig, then reference it
-- in BuildConfig requirements. The world builder, carry visuals, tracker and Workers pick it up from data.
export type Resource = {
	Id: string,
	Family: string, -- material family: Wood | Stone | Metal | PowerCell
	Grade: number, -- 1..3
	DisplayName: string, -- the item itself ("Logs")
	FamilyName: string, -- the family ("Wood"), used when a requirement accepts any grade
	Order: number,
	Color: Color3,
	Material: Enum.Material,
	Zone: string, -- spot id in Workspace.World.Zones where it is gathered
	GatherTime: number, -- seconds per gather action at Gather Speed 1.0
	YieldPerGather: number, -- units per gather action
	Equivalent: number, -- how many grade-1 units one delivered unit counts as (build progress, contribution, Coins)
	Value: number, -- contribution points per counted unit
	CoinsPerUnit: number, -- instant Coins per counted unit (BALANCE: Wood .60, Stone .75, Metal 1.00, Power Cells 1.30)
	StackBlockSize: Vector3, -- carried-stack block size (visual)
	Look: string, -- carried-stack look handled by CarryVisualController
	Icon: string, -- placeholder glyph until real icons exist
	Secret: string?, -- SecretResourceConfig id: only players who unlocked it can gather this resource
}

local ResourceConfig = {}

-- Requirement / UI order: grade 1 of every family first, then grade 2, then grade 3.
ResourceConfig.Order = {
	"Wood", "Stone", "Metal", "PowerCell",
	"Logs", "StoneBlocks", "MetalBeams", "Cells",
	"Timber", "Boulders", "HeavySteel", "EnergyCore",
	"StarMetal", "AncientTimber", -- secret endgame resources (own families; never required by Common-Mythic builds)
}
ResourceConfig.Families = { "Wood", "Stone", "Metal", "PowerCell" }

local WOOD, STONE, METAL, POWER = "Wood", "Stone", "Metal", "PowerCell"

ResourceConfig.Resources = {
	-- WOOD ---------------------------------------------------------------
	Wood = {
		Id = "Wood", Family = WOOD, Grade = 1, DisplayName = "Sticks", FamilyName = "Wood", Order = 1,
		Color = Color3.fromRGB(170, 120, 70), Material = Enum.Material.Wood,
		Zone = "Forest", GatherTime = 0.55, YieldPerGather = 4, Equivalent = 1,
		Value = 1, CoinsPerUnit = 0.60,
		StackBlockSize = Vector3.new(1.7, 0.5, 0.8), Look = "Bundle", Icon = "🌲",
	},
	Logs = {
		Id = "Logs", Family = WOOD, Grade = 2, DisplayName = "Logs", FamilyName = "Wood", Order = 2,
		Color = Color3.fromRGB(140, 90, 48), Material = Enum.Material.Wood,
		Zone = "LumberCamp", GatherTime = 0.55, YieldPerGather = 4, Equivalent = 1.30,
		Value = 1, CoinsPerUnit = 0.60,
		StackBlockSize = Vector3.new(2.3, 0.9, 1.1), Look = "Logs", Icon = "🪵",
	},
	Timber = {
		Id = "Timber", Family = WOOD, Grade = 3, DisplayName = "Timber", FamilyName = "Wood", Order = 3,
		Color = Color3.fromRGB(118, 74, 38), Material = Enum.Material.Wood,
		Zone = "TimberStand", GatherTime = 0.55, YieldPerGather = 4, Equivalent = 1.60,
		Value = 1, CoinsPerUnit = 0.60,
		StackBlockSize = Vector3.new(3.2, 1.3, 1.3), Look = "Timber", Icon = "🌳",
	},
	-- STONE --------------------------------------------------------------
	Stone = {
		Id = "Stone", Family = STONE, Grade = 1, DisplayName = "Rubble", FamilyName = "Stone", Order = 4,
		Color = Color3.fromRGB(164, 168, 182), Material = Enum.Material.Slate,
		Zone = "Quarry", GatherTime = 0.65, YieldPerGather = 4, Equivalent = 1,
		Value = 1, CoinsPerUnit = 0.75,
		StackBlockSize = Vector3.new(1.3, 0.7, 1.0), Look = "Rubble", Icon = "🧱",
	},
	StoneBlocks = {
		Id = "StoneBlocks", Family = STONE, Grade = 2, DisplayName = "Stone Blocks", FamilyName = "Stone", Order = 5,
		Color = Color3.fromRGB(214, 196, 168), Material = Enum.Material.Brick,
		Zone = "DeepQuarry", GatherTime = 0.65, YieldPerGather = 4, Equivalent = 1.32,
		Value = 1, CoinsPerUnit = 0.75,
		StackBlockSize = Vector3.new(1.5, 1.0, 1.5), Look = "Blocks", Icon = "🧱",
	},
	Boulders = {
		Id = "Boulders", Family = STONE, Grade = 3, DisplayName = "Boulders", FamilyName = "Stone", Order = 6,
		Color = Color3.fromRGB(116, 128, 150), Material = Enum.Material.Granite,
		Zone = "BoulderField", GatherTime = 0.65, YieldPerGather = 4, Equivalent = 1.65,
		Value = 1, CoinsPerUnit = 0.75,
		StackBlockSize = Vector3.new(2.2, 2.0, 2.2), Look = "Boulder", Icon = "🪨",
	},
	-- METAL --------------------------------------------------------------
	Metal = {
		Id = "Metal", Family = METAL, Grade = 1, DisplayName = "Scrap", FamilyName = "Metal", Order = 7,
		Color = Color3.fromRGB(150, 138, 130), Material = Enum.Material.CorrodedMetal,
		Zone = "Mine", GatherTime = 0.75, YieldPerGather = 3, Equivalent = 1,
		Value = 1.4, CoinsPerUnit = 1.00,
		StackBlockSize = Vector3.new(1.4, 0.5, 1.0), Look = "Scrap", Icon = "🔩",
	},
	MetalBeams = {
		Id = "MetalBeams", Family = METAL, Grade = 2, DisplayName = "Metal Beams", FamilyName = "Metal", Order = 8,
		Color = Color3.fromRGB(236, 184, 60), Material = Enum.Material.DiamondPlate,
		Zone = "IndustrialYard", GatherTime = 0.75, YieldPerGather = 3, Equivalent = 1.30,
		Value = 1.4, CoinsPerUnit = 1.00,
		StackBlockSize = Vector3.new(2.6, 0.4, 0.5), Look = "Beams", Icon = "🏗",
	},
	HeavySteel = {
		Id = "HeavySteel", Family = METAL, Grade = 3, DisplayName = "Heavy Steel", FamilyName = "Metal", Order = 9,
		Color = Color3.fromRGB(78, 98, 130), Material = Enum.Material.Metal,
		Zone = "SteelWorks", GatherTime = 0.75, YieldPerGather = 3, Equivalent = 1.55,
		Value = 1.4, CoinsPerUnit = 1.00,
		StackBlockSize = Vector3.new(2.0, 1.2, 1.4), Look = "Steel", Icon = "⚙",
	},
	-- POWER --------------------------------------------------------------
	PowerCell = {
		Id = "PowerCell", Family = POWER, Grade = 1, DisplayName = "Batteries", FamilyName = "Power", Order = 10,
		Color = Color3.fromRGB(110, 210, 120), Material = Enum.Material.Neon,
		Zone = "Energy", GatherTime = 0.9, YieldPerGather = 2, Equivalent = 1,
		Value = 2, CoinsPerUnit = 1.30,
		StackBlockSize = Vector3.new(0.7, 1.0, 0.7), Look = "Battery", Icon = "🔋",
	},
	Cells = {
		Id = "Cells", Family = POWER, Grade = 2, DisplayName = "Power Cells", FamilyName = "Power", Order = 11,
		Color = Color3.fromRGB(80, 230, 255), Material = Enum.Material.Neon,
		Zone = "ReactorYard", GatherTime = 0.9, YieldPerGather = 2, Equivalent = 1.25,
		Value = 2, CoinsPerUnit = 1.30,
		StackBlockSize = Vector3.new(1.0, 1.4, 1.0), Look = "Cell", Icon = "⚡",
	},
	EnergyCore = {
		Id = "EnergyCore", Family = POWER, Grade = 3, DisplayName = "Energy Cores", FamilyName = "Power", Order = 12,
		Color = Color3.fromRGB(190, 120, 255), Material = Enum.Material.Neon,
		Zone = "CoreVault", GatherTime = 0.9, YieldPerGather = 2, Equivalent = 1.45,
		Value = 2, CoinsPerUnit = 1.30,
		StackBlockSize = Vector3.new(1.5, 1.5, 1.5), Look = "Core", Icon = "🔮",
	},
	-- SECRET (Master Builder unlocks, see SecretResourceConfig). Own families: a requirement on StarMetal is only filled by Star Metal.
	StarMetal = {
		Id = "StarMetal", Family = "StarMetal", Grade = 1, DisplayName = "Star Metal", FamilyName = "Star Metal", Order = 13,
		Color = Color3.fromRGB(62, 70, 104), Material = Enum.Material.Metal,
		Zone = "StarCrater", GatherTime = 1.2, YieldPerGather = 2, Equivalent = 1,
		Value = 6, CoinsPerUnit = 3.5, -- strong Master Project contribution and Coins (grade-3 premium resources are ~1.4-1.9 Coins)
		StackBlockSize = Vector3.new(1.7, 0.9, 1.2), Look = "StarMetal", Icon = "☄", Secret = "StarMetal",
	},
	AncientTimber = {
		Id = "AncientTimber", Family = "AncientTimber", Grade = 1, DisplayName = "Ancient Timber", FamilyName = "Ancient Timber", Order = 14,
		Color = Color3.fromRGB(122, 94, 52), Material = Enum.Material.Wood,
		Zone = "AncientGrove", GatherTime = 1.1, YieldPerGather = 2, Equivalent = 1,
		Value = 5, CoinsPerUnit = 3.0,
		StackBlockSize = Vector3.new(2.6, 1.1, 1.1), Look = "AncientWood", Icon = "🌿", Secret = "AncientTimber",
	},
} :: { [string]: Resource }

function ResourceConfig.Get(id: string): Resource?
	return ResourceConfig.Resources[id]
end

-- Name shown for a REQUIREMENT on this id: grade 1 accepts any grade, so it reads as the family ("Wood").
function ResourceConfig.RequirementLabel(id: string): string
	local r = ResourceConfig.Resources[id]
	if not r then
		return id
	end
	if r.Grade == 1 then
		return r.FamilyName
	end
	return r.DisplayName
end

-- Does delivering `deliveredId` count toward a requirement on `requiredId`?  (same family, grade >= required grade)
function ResourceConfig.Satisfies(deliveredId: string, requiredId: string): boolean
	local d, r = ResourceConfig.Resources[deliveredId], ResourceConfig.Resources[requiredId]
	return d ~= nil and r ~= nil and d.Family == r.Family and d.Grade >= r.Grade
end

-- Requirement ids that delivering `deliveredId` can fill, strictest (highest grade) first.
function ResourceConfig.RequirementsFor(deliveredId: string): { string }
	local d = ResourceConfig.Resources[deliveredId]
	local out = {}
	if not d then
		return out
	end
	for _, id in ResourceConfig.Order do
		local r = ResourceConfig.Resources[id]
		if r.Family == d.Family and r.Grade <= d.Grade then
			table.insert(out, id)
		end
	end
	table.sort(out, function(a, b)
		return ResourceConfig.Resources[a].Grade > ResourceConfig.Resources[b].Grade
	end)
	return out
end

-- The grade-1 id of a family (what the tutorial and "any grade" requirements point at).
function ResourceConfig.Basic(family: string): string
	for _, id in ResourceConfig.Order do
		local r = ResourceConfig.Resources[id]
		if r.Family == family and r.Grade == 1 then
			return id
		end
	end
	return family
end

return ResourceConfig
