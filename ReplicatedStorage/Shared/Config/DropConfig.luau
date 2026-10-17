--!strict
-- PERSONAL RARE DROPS: when a build completes, every ELIGIBLE participant rolls the drop table independently
-- (one player's drop never gives anyone else the item). Drops are cosmetic (CosmeticConfig); no Robux, no power.
--
-- A drop entry:
--   Id              unique key (also used to count finds in PlayerData.DropLog)
--   Category/Item   what is granted (CosmeticConfig category + id)
--   MinRarity       lowest build rarity that can drop it (Legendary and Mythic by default)
--   Builds          optional list of build ids it can drop from (omit = any build of that rarity or higher)
--   Modifiers       optional list; it can only drop from a build that had one of these modifiers
--   Chance          base chance per participant per completed build (0..1)
--   RankBonus       optional: relative extra chance per Master Builder rank (0.1 = +10% per rank)
--   EventSeason     optional SeasonConfig id; EVENT-EXCLUSIVE drops only roll while that season is Active
--                   (after the event they never drop again, which keeps them exclusive)
--
-- Chance = Chance x ServerState DropChance perk x (1 + PersonalLuck x LuckInfluence), capped at MaxChance.
-- Duplicates: the item is not granted twice; the player gets DuplicateCoins instead (and the find is still logged).
-- Pity protection (guaranteed drop after N misses) is a later extension: Pity.Enabled / MissesForBonus are reserved.
local DropConfig = {}

DropConfig.RarityOrder = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5, Mythic = 6 }

DropConfig.LuckInfluence = 0.01 -- +1% of the chance per point of personal Luck (Luck upgrade: +2 per level)
DropConfig.MaxChance = 0.5
DropConfig.DuplicateCoins = { Common = 50, Uncommon = 100, Rare = 200, Epic = 400, Legendary = 800, Mythic = 1500 }
DropConfig.Pity = { Enabled = false, MissesForBonus = 25 }

DropConfig.Drops = {
	{ Id = "GoldenCrewOutfit", Category = "WorkerOutfit", Item = "GoldenCrew", MinRarity = "Legendary", Modifiers = { "Golden" }, Chance = 0.12 },
	{ Id = "LavaTrail", Category = "Trail", Item = "LavaTrail", MinRarity = "Rare", Builds = { "VolcanoTemple" }, Chance = 0.06 },
	{ Id = "StarTrail", Category = "Trail", Item = "StarTrail", MinRarity = "Epic", Builds = { "UFO" }, Chance = 0.06 },
	{ Id = "RobotBolts", Category = "ContributionEffect", Item = "RobotBolts", MinRarity = "Legendary", Builds = { "GiantRobot" }, Chance = 0.10 },
	{ Id = "EmberGlow", Category = "CarryEffect", Item = "EmberGlow", MinRarity = "Legendary", Chance = 0.04 },
	{ Id = "GoldenSparks", Category = "ContributionEffect", Item = "GoldenSparks", MinRarity = "Legendary", Modifiers = { "Golden" }, Chance = 0.06 },
	-- MASTER PROJECT prestige drop: rare for everyone, +10% (relative) per Master Builder rank
	{ Id = "OrbitalTrail", Category = "Trail", Item = "OrbitalTrail", MinRarity = "Mythic", Builds = { "OrbitalStation" }, Chance = 0.08, RankBonus = 0.1 },
	{ Id = "DragonScale", Category = "VehicleSkin", Item = "DragonScale", MinRarity = "Mythic", Chance = 0.25 },
	-- EVENT-EXCLUSIVE (only rolls while SeasonConfig LanternFestival is Active; never again once it ends)
	{ Id = "LanternTrail", Category = "Trail", Item = "LanternTrail", MinRarity = "Rare", Builds = { "LanternTower" }, Chance = 0.30, EventSeason = "LanternFestival" },
	{ Id = "SafetyOrange", Category = "VehicleSkin", Item = "SafetyOrange", MinRarity = "Rare", Chance = 0.08 },
	{ Id = "HazardTrail", Category = "Trail", Item = "HazardTrail", MinRarity = "Legendary", Chance = 0.05 },
}

return DropConfig
