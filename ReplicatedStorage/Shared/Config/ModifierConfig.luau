--!strict
-- Build modifiers are independent from rarity ("LEGENDARY / GOLDEN GIANT ROBOT").
-- Each modifier only declares multipliers + a visual treatment id; ModifierService
-- applies them generically. Add a modifier by adding an entry here (and, if it needs a
-- new look, a Visuals.<Visual> function in ModifierService). Future ideas: Frozen,
-- Neon, Overgrown.
export type Modifier = {
	Id: string,
	DisplayName: string,
	Color: Color3,
	BaseChance: number, -- chance per build at 0 Server Luck
	ChancePerLuck: number, -- added per Server Luck point (0..100)
	MaxChance: number,
	RequirementMultiplier: number,
	RewardMultiplier: number,
	ModelScale: number,
	EventIntervalMultiplier: number, -- < 1 means events happen more often
	LuckyBonusChanceAdd: number, -- added to every player's Lucky Bonus chance
	Visual: string, -- visual treatment id
	Enabled: boolean,
}

local ModifierConfig = {}

ModifierConfig.MaxModifiersPerBuild = 2

ModifierConfig.Modifiers = {
	Golden = {
		Id = "Golden", DisplayName = "GOLDEN", Color = Color3.fromRGB(255, 205, 60),
		BaseChance = 0.05, ChancePerLuck = 0.0008, MaxChance = 0.14,
		RequirementMultiplier = 1.1, RewardMultiplier = 1.5, ModelScale = 1,
		EventIntervalMultiplier = 1, LuckyBonusChanceAdd = 0,
		Visual = "Gold", Enabled = true,
	},
	Giant = {
		Id = "Giant", DisplayName = "GIANT", Color = Color3.fromRGB(255, 120, 60),
		BaseChance = 0.08, ChancePerLuck = 0.0008, MaxChance = 0.18,
		RequirementMultiplier = 1.4, RewardMultiplier = 1.35, ModelScale = 1.25,
		EventIntervalMultiplier = 1, LuckyBonusChanceAdd = 0,
		Visual = "Scale", Enabled = true,
	},
	Ancient = {
		Id = "Ancient", DisplayName = "ANCIENT", Color = Color3.fromRGB(176, 160, 120),
		BaseChance = 0.06, ChancePerLuck = 0.0006, MaxChance = 0.14,
		RequirementMultiplier = 1.1, RewardMultiplier = 1.2, ModelScale = 1,
		EventIntervalMultiplier = 1, LuckyBonusChanceAdd = 0,
		Visual = "Aged", Enabled = true,
	},
	Corrupted = {
		Id = "Corrupted", DisplayName = "CORRUPTED", Color = Color3.fromRGB(170, 60, 230),
		BaseChance = 0.04, ChancePerLuck = 0.0006, MaxChance = 0.1,
		RequirementMultiplier = 1.15, RewardMultiplier = 1.3, ModelScale = 1,
		EventIntervalMultiplier = 0.7, -- more chaos
		LuckyBonusChanceAdd = 0.1, -- but better odds of a Lucky Bonus
		Visual = "Corrupt", Enabled = true,
	},
} :: { [string]: Modifier }

ModifierConfig.Order = { "Ancient", "Corrupted", "Golden", "Giant" } -- display order in titles

return ModifierConfig
