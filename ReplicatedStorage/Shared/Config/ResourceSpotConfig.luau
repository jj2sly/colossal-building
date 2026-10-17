--!strict
-- RESOURCE SPOTS. Each core resource can be gathered at several world locations ("spots").
-- Tier 1 spots are the close, beginner-friendly zones; higher tiers sit farther out and gather
-- better. Everything about a spot lives here (location, bonuses, labels): the world builder,
-- gathering, the HUD signs and the balance telemetry all read this table, nothing else hardcodes
-- far-zone bonuses.
--
-- WHY farther is better (and why it is not always optimal): carry capacity is the real limit on a
-- trip, so a bonus only pays when the player is fast enough (Speed training) or hauls enough
-- (Strength / vehicles) that gathering time, not walking time, dominates the trip. New players
-- with small loads do best at the near spots; strong, fast or vehicle players do better farther out.
--
--   Resource                the RESOURCE GRADE gathered here (ResourceConfig id: Sticks/Logs/Timber, Rubble/Stone Blocks/...)
--   YieldMultiplier         DERIVED from ResourceConfig[Resource].Equivalent (do not set it here): each unit carried from
--                           this spot counts this many grade-1 units when delivered. Capacity is the real limit on a trip,
--                           so a better grade is what makes a farther trip worth it.
--   GatherSpeedMultiplier   shortens the hold time of every node in the spot
--   RespawnMultiplier       reserved: nodes do not deplete yet, kept so spots can define it later
--   RecommendedLevel        suggested Speed level (shown on the signs); never enforced
--   Tier                    1 = near (grade 1), 2 = far (grade 2), 3 = far-far (grade 3)
export type Spot = {
	Id: string, -- also the folder name in Workspace.World.Zones
	Resource: string, -- ResourceConfig id
	DisplayName: string,
	Position: Vector3, -- centre of the spot (Y = ground height there)
	Tier: number,
	YieldMultiplier: number,
	GatherSpeedMultiplier: number,
	RespawnMultiplier: number,
	RecommendedLevel: number,
	NodeDensity: number, -- 1 = standard, >1 = denser nodes (world builder)
	Enabled: boolean,
	Secret: string?, -- hidden endgame area: only players who unlocked this secret can gather here
	-- (colossal site) Tier 1 spots moved outward when the build site grew. The world builder generates the zone at
	-- Position - GenOffset (so its node layout and random stream are unchanged) and then shifts the whole zone by GenOffset.
	GenOffset: Vector3?,
}

local ResourceConfig = require(script.Parent.ResourceConfig)
local ColossalConfig = require(script.Parent.ColossalConfig)

local ResourceSpotConfig = {}

ResourceSpotConfig.Spots = {
	-- WOOD: Sticks -> Logs -> Timber
	Forest = {
		Id = "Forest", Resource = "Wood", DisplayName = "Stick Grove", Position = Vector3.new(-215, 0, 55),
		Tier = 1, GatherSpeedMultiplier = 1, RespawnMultiplier = 1, RecommendedLevel = 0, NodeDensity = 1, Enabled = true,
	},
	LumberCamp = {
		Id = "LumberCamp", Resource = "Logs", DisplayName = "Logging Camp", Position = Vector3.new(-340, 0, -70),
		Tier = 2, GatherSpeedMultiplier = 1.25, RespawnMultiplier = 1, RecommendedLevel = 5, NodeDensity = 1.6, Enabled = true,
	},
	TimberStand = {
		Id = "TimberStand", Resource = "Timber", DisplayName = "Redwood Forest", Position = Vector3.new(-440, 0, -300),
		Tier = 3, GatherSpeedMultiplier = 1.3, RespawnMultiplier = 1, RecommendedLevel = 12, NodeDensity = 1.2, Enabled = true,
	},
	-- STONE: Rubble -> Stone Blocks -> Boulders
	Quarry = {
		Id = "Quarry", Resource = "Stone", DisplayName = "Rock Field", Position = Vector3.new(205, 0, -30),
		Tier = 1, GatherSpeedMultiplier = 1, RespawnMultiplier = 1, RecommendedLevel = 0, NodeDensity = 1, Enabled = true,
	},
	DeepQuarry = {
		Id = "DeepQuarry", Resource = "StoneBlocks", DisplayName = "Quarry", Position = Vector3.new(340, 0, -30),
		Tier = 2, GatherSpeedMultiplier = 1.25, RespawnMultiplier = 1, RecommendedLevel = 6, NodeDensity = 1.5, Enabled = true,
	},
	BoulderField = {
		Id = "BoulderField", Resource = "Boulders", DisplayName = "Mountain Excavation", Position = Vector3.new(394, 0, -252),
		Tier = 3, GatherSpeedMultiplier = 1.3, RespawnMultiplier = 1, RecommendedLevel = 14, NodeDensity = 1.1, Enabled = true,
	},
	-- METAL: Scrap -> Metal Beams -> Heavy Steel
	Mine = {
		Id = "Mine", Resource = "Metal", DisplayName = "Scrap Yard", Position = Vector3.new(-120, 0, -175),
		Tier = 1, GatherSpeedMultiplier = 1, RespawnMultiplier = 1, RecommendedLevel = 0, NodeDensity = 1, Enabled = true,
	},
	IndustrialYard = {
		Id = "IndustrialYard", Resource = "MetalBeams", DisplayName = "Foundry", Position = Vector3.new(-235, 0, -320),
		Tier = 2, GatherSpeedMultiplier = 1.2, RespawnMultiplier = 1, RecommendedLevel = 8, NodeDensity = 1.5, Enabled = true,
	},
	SteelWorks = {
		Id = "SteelWorks", Resource = "HeavySteel", DisplayName = "Heavy Steel Mine", Position = Vector3.new(-172, 0, -498),
		Tier = 3, GatherSpeedMultiplier = 1.25, RespawnMultiplier = 1, RecommendedLevel = 16, NodeDensity = 1.1, Enabled = true,
	},
	-- POWER: Batteries -> Power Cells -> Energy Cores
	Energy = {
		Id = "Energy", Resource = "PowerCell", DisplayName = "Battery Depot", Position = Vector3.new(135, 0, -160),
		Tier = 1, GatherSpeedMultiplier = 1, RespawnMultiplier = 1, RecommendedLevel = 0, NodeDensity = 1, Enabled = true,
	},
	ReactorYard = {
		Id = "ReactorYard", Resource = "Cells", DisplayName = "Power Plant", Position = Vector3.new(240, 0, -300),
		Tier = 2, GatherSpeedMultiplier = 1.2, RespawnMultiplier = 1, RecommendedLevel = 10, NodeDensity = 1.5, Enabled = true,
	},
	CoreVault = {
		Id = "CoreVault", Resource = "EnergyCore", DisplayName = "Energy Reactor", Position = Vector3.new(134, 0, -500),
		Tier = 3, GatherSpeedMultiplier = 1.25, RespawnMultiplier = 1, RecommendedLevel = 18, NodeDensity = 1.1, Enabled = true,
	},
	-- HIDDEN ENDGAME AREAS (SecretResourceConfig). Walled in by rock / ancient trees on the far east and west edges of the valley.
	StarCrater = {
		Id = "StarCrater", Resource = "StarMetal", DisplayName = "Star Crater", Position = Vector3.new(520, 0, -40),
		Tier = 3, GatherSpeedMultiplier = 1.2, RespawnMultiplier = 1, RecommendedLevel = 30, NodeDensity = 0.75, Enabled = true, Secret = "StarMetal",
	},
	AncientGrove = {
		Id = "AncientGrove", Resource = "AncientTimber", DisplayName = "Ancient Grove", Position = Vector3.new(-545, 0, 20),
		Tier = 3, GatherSpeedMultiplier = 1.2, RespawnMultiplier = 1, RecommendedLevel = 30, NodeDensity = 0.75, Enabled = true, Secret = "AncientTimber",
	},
} :: { [string]: any }

-- Derive the value bonus from the resource grade so there is a single source of truth.
for _, spot in ResourceSpotConfig.Spots do
	spot.YieldMultiplier = ResourceConfig.Resources[spot.Resource].Equivalent
end

-- Spots sorted by family, then tier. Pass a RESOURCE ID to get the spots that gather exactly it.
function ResourceSpotConfig.List(resourceId: string?): { Spot }
	local out = {}
	for _, s in ResourceSpotConfig.Spots do
		if s.Enabled and (resourceId == nil or s.Resource == resourceId) then
			table.insert(out, s)
		end
	end
	table.sort(out, function(a, b)
		local fa, fb = ResourceConfig.Resources[a.Resource].Family, ResourceConfig.Resources[b.Resource].Family
		if fa ~= fb then
			return fa < fb
		end
		return a.Tier < b.Tier
	end)
	return out
end

-- All spots of a material family (any grade), nearest tier first.
function ResourceSpotConfig.ListFamily(family: string): { Spot }
	local out = {}
	for _, s in ResourceSpotConfig.Spots do
		if s.Enabled and ResourceConfig.Resources[s.Resource].Family == family then
			table.insert(out, s)
		end
	end
	table.sort(out, function(a, b)
		return a.Tier < b.Tier
	end)
	return out
end

function ResourceSpotConfig.Get(id: string?): Spot?
	return id and ResourceSpotConfig.Spots[id] or nil
end

-- The beginner spot for a resource id (its own spot), or for a family id the tier 1 spot.
function ResourceSpotConfig.Primary(resourceId: string): Spot?
	local best: Spot? = nil
	for _, s in ResourceSpotConfig.Spots do
		if s.Enabled and s.Resource == resourceId and (best == nil or s.Tier < best.Tier) then
			best = s
		end
	end
	return best
end

-- Straight-line one-way walking distance from the edge of the build ring (the deposit edge) to a spot.
function ResourceSpotConfig.DistanceFromRing(spot: Spot, ringRadius: number?): number
	local flat = Vector3.new(spot.Position.X, 0, spot.Position.Z).Magnitude
	return math.max(0, flat - (ringRadius or ColossalConfig.Site.DepositRadius))
end

return ResourceSpotConfig
