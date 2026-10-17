--!strict
-- Rarity ladder. Rarity belongs to the BUILD; these values drive selection frequency,
-- requirement scale, rewards, presentation and Server Luck growth.
--
-- BALANCE v0.1: odds come from the LuckCurve below (piecewise-linear interpolation between anchor
-- tables, then renormalised over the rarities that currently have builds). `Weight` is the 0-luck
-- table; LuckShift is unused. Server Luck can never "add to Mythic": it slides the whole table.
export type Rarity = {
	Id: string,
	Order: number,
	DisplayName: string,
	Color: Color3,
	Weight: number,
	LuckShift: number,
	RewardMultiplier: number,
	TargetMinutes: { number },
	ServerLuckGain: number, -- added to Server Luck when a build of this rarity completes
	RevealIntensity: number, -- 1..5, scales reveal effects
	IndexEffect: string?, -- special Build Index treatment: "Sheen" | "Aura"
}

local RarityConfig = {}

RarityConfig.Order = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythic" }

RarityConfig.Tiers = {
	Common = {
		Id = "Common", Order = 1, DisplayName = "COMMON",
		Color = Color3.fromRGB(196, 202, 210),
		Weight = 50, LuckShift = 0, RewardMultiplier = 1.0,
		TargetMinutes = { 3, 5 }, ServerLuckGain = 4, RevealIntensity = 1,
	},
	Uncommon = {
		Id = "Uncommon", Order = 2, DisplayName = "UNCOMMON",
		Color = Color3.fromRGB(96, 214, 110),
		Weight = 26, LuckShift = 0, RewardMultiplier = 1.25,
		TargetMinutes = { 4, 6 }, ServerLuckGain = 4, RevealIntensity = 2,
	},
	Rare = {
		Id = "Rare", Order = 3, DisplayName = "RARE",
		Color = Color3.fromRGB(70, 150, 255),
		Weight = 14, LuckShift = 0, RewardMultiplier = 1.65,
		TargetMinutes = { 5, 8 }, ServerLuckGain = 4, RevealIntensity = 3,
	},
	Epic = {
		Id = "Epic", Order = 4, DisplayName = "EPIC",
		Color = Color3.fromRGB(176, 92, 255),
		Weight = 6, LuckShift = 0, RewardMultiplier = 2.2,
		TargetMinutes = { 7, 10 }, ServerLuckGain = 4, RevealIntensity = 3,
	},
	Legendary = {
		Id = "Legendary", Order = 5, DisplayName = "LEGENDARY",
		Color = Color3.fromRGB(232, 208, 150), -- champagne gold: prestigious, clearly paler than the construction amber
		Weight = 3, LuckShift = 0, RewardMultiplier = 3.1,
		TargetMinutes = { 9, 13 }, ServerLuckGain = 4, RevealIntensity = 4, IndexEffect = "Sheen",
	},
	Mythic = {
		Id = "Mythic", Order = 6, DisplayName = "MYTHIC",
		Color = Color3.fromRGB(255, 70, 120),
		Weight = 1, LuckShift = 0, RewardMultiplier = 4.5,
		TargetMinutes = { 12, 15 }, ServerLuckGain = 4, RevealIntensity = 5, IndexEffect = "Aura",
	},
} :: { [string]: Rarity }

-- Rarity weights (percent) at anchor Server Luck values. Add anchors to reshape the curve.
RarityConfig.LuckCurve = {
	{ Luck = 0, Weights = { Common = 50, Uncommon = 26, Rare = 14, Epic = 6, Legendary = 3, Mythic = 1 } },
	{ Luck = 25, Weights = { Common = 40, Uncommon = 26, Rare = 17, Epic = 9, Legendary = 5, Mythic = 1.8 } },
	{ Luck = 50, Weights = { Common = 27, Uncommon = 24, Rare = 22, Epic = 13, Legendary = 9, Mythic = 3.5 } },
	{ Luck = 75, Weights = { Common = 11, Uncommon = 15, Rare = 29, Epic = 24, Legendary = 15.5, Mythic = 5.5 } },
	-- maxed server: Commons nearly gone (2%, still huntable), Uncommons rare, Rare/Epic dominate, Legendary about 1 build in 4-5,
	-- Mythic 8% (8x a fresh server) so it is a highlight of a session, never routine
	{ Luck = 100, Weights = { Common = 2, Uncommon = 6, Rare = 30, Epic = 32, Legendary = 22, Mythic = 8 } },
} :: { { Luck: number, Weights: { [string]: number } } }

-- REVEAL LENGTH: multipliers on GameConfig.Timings RevealRoll (3.2 s) / RevealHold (4.5 s) per rarity. Totals at default timing:
-- Common ~2.5 s, Uncommon ~3.5 s, Rare ~4.5 s, Epic ~5.5 s (light overlay, never closes your menus), Legendary ~9 s and
-- Mythic ~9.5 s (full server moment). Nobody is ever frozen: it is an overlay only.
RarityConfig.RevealScale = {
	-- (Pass 21L) rolls are longer so every reveal has a suspense beat: Common ~2.8 s of roll, Mythic ~6.5 s
	Common = { Roll = 0.55, Hold = 0.33 },
	Uncommon = { Roll = 0.62, Hold = 0.47 },
	Rare = { Roll = 0.7, Hold = 0.6 },
	Epic = { Roll = 0.8, Hold = 0.73 },
	Legendary = { Roll = 1.2, Hold = 1.04 },
	Mythic = { Roll = 1.3, Hold = 1.09 },
} :: { [string]: { Roll: number, Hold: number } }

-- Interpolated weight table for an (effective) Server Luck value.
function RarityConfig.WeightsAt(luck: number): { [string]: number }
	local curve = RarityConfig.LuckCurve
	luck = math.clamp(luck, curve[1].Luck, curve[#curve].Luck)
	for i = 1, #curve - 1 do
		local a, b = curve[i], curve[i + 1]
		if luck <= b.Luck then
			local t = (luck - a.Luck) / math.max(1e-6, b.Luck - a.Luck)
			local out = {}
			for id, wa in a.Weights do
				out[id] = wa + ((b.Weights[id] or wa) - wa) * t
			end
			return out
		end
	end
	return table.clone(curve[#curve].Weights)
end

-- FORGOTTEN presentation record (display only). It is deliberately NOT in Tiers / Order / LuckCurve / RevealScale, so normal
-- selection, weights and the vote can never see it. Placeholder palette: Forgotten gets its own visual language later.
RarityConfig.ForgottenTier = {
	Id = "Forgotten", Order = 7, DisplayName = "FORGOTTEN",
	Color = Color3.fromRGB(190, 176, 150),
	Weight = 0, LuckShift = 0, RewardMultiplier = 6,
	TargetMinutes = { 15, 20 }, ServerLuckGain = 4, RevealIntensity = 5,
} :: any

-- HIDDEN presentation record: what a player who has NOT discovered the active Forgotten project sees in place of a tier ("???", neutral).
-- Not in Tiers / Order / pools, so it can never be rolled; it never names or hints the real tier.
RarityConfig.HiddenTier = {
	Id = "Hidden", Order = 6, DisplayName = "???",
	Color = Color3.fromRGB(150, 146, 138),
	Weight = 0, LuckShift = 0, RewardMultiplier = 4,
	TargetMinutes = { 15, 20 }, ServerLuckGain = 4, RevealIntensity = 5,
} :: any

function RarityConfig.Get(id: string): Rarity
	return RarityConfig.Tiers[id] or (if id == "Forgotten" then RarityConfig.ForgottenTier elseif id == "Hidden" then RarityConfig.HiddenTier else nil) or RarityConfig.Tiers.Common
end

return RarityConfig
