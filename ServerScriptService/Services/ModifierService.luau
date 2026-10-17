--!strict
-- Build modifiers (Golden, Giant, ...). Rolls modifiers independently of rarity,
-- combines their multipliers, and applies visual treatments to the build model.
-- New modifier = ModifierConfig entry + (optional) Visuals[<Visual>] function here.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ModifierConfig = require(Shared.Config.ModifierConfig)
local Formulas = require(Shared.Formulas)

local ModifierService = {}

local GOLD = Color3.fromRGB(255, 200, 50)

-- Visual treatments. Each receives the full build model before it's split into stages.
local Visuals: { [string]: (Model, any) -> () } = {}

function Visuals.Gold(model: Model)
	-- Parts flagged Accent=true in the template become gold; if a template has none,
	-- every 4th part is used so the treatment always shows.
	local accents = {}
	local all = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(all, d)
			if d:GetAttribute("Accent") then
				table.insert(accents, d)
			end
		end
	end
	if #accents == 0 then
		for i = 1, #all, 4 do
			table.insert(accents, all[i])
		end
	end
	for i, p in accents do
		p.Color = GOLD
		if p.Material ~= Enum.Material.Neon then
			p.Material = Enum.Material.Foil
		end
		p.Reflectance = 0.15
		if i % 6 == 0 then
			local s = Instance.new("Sparkles")
			s.SparkleColor = GOLD
			s.Parent = p
		end
	end
end

local function visibleParts(model: Model): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Transparency < 1 then
			table.insert(out, d)
		end
	end
	return out
end

-- Weathered stone: desaturate toward sandstone, rough materials, a little moss.
function Visuals.Aged(model: Model)
	local sand = Color3.fromRGB(170, 158, 128)
	local moss = Color3.fromRGB(96, 124, 70)
	for i, p in visibleParts(model) do
		if p.Material ~= Enum.Material.Neon and p.Material ~= Enum.Material.Glass then
			local h, sat, v = p.Color:ToHSV()
			p.Color = Color3.fromHSV(h, sat * 0.35, v * 0.9):Lerp(if i % 7 == 0 then moss else sand, 0.45)
			p.Material = if i % 3 == 0 then Enum.Material.Cobblestone else Enum.Material.Slate
			p.Reflectance = 0
		end
	end
end

-- Corruption: darkened purple tint with glowing veins on some pieces.
function Visuals.Corrupt(model: Model)
	local dark = Color3.fromRGB(40, 20, 55)
	local glow = Color3.fromRGB(190, 70, 255)
	for i, p in visibleParts(model) do
		if i % 6 == 0 then
			p.Color = glow
			p.Material = Enum.Material.Neon
			p:SetAttribute("NoDamage", true)
		elseif p.Material ~= Enum.Material.Neon then
			p.Color = p.Color:Lerp(dark, 0.55)
		end
		if i % 18 == 0 then
			local s = Instance.new("Sparkles")
			s.SparkleColor = glow
			s.Parent = p
		end
	end
end

function Visuals.Scale(model: Model, def: any)
	model:ScaleTo(model:GetScale() * def.ModelScale)
end

-- `chanceMult` scales every modifier chance (Server State perk).
function ModifierService.Roll(eligible: { string }, serverLuck: number, rng: Random?, chanceMult: number?): { string }
	local rand = rng or Random.new()
	local out = {}
	for _, id in ModifierConfig.Order do
		if #out >= ModifierConfig.MaxModifiersPerBuild then
			break
		end
		if table.find(eligible, id) and rand:NextNumber() < Formulas.ModifierChance(id, serverLuck) * (chanceMult or 1) then
			table.insert(out, id)
		end
	end
	return out
end

function ModifierService.Multipliers(mods: { string }): (number, number)
	local req, reward = 1, 1
	for _, id in mods do
		local m = ModifierConfig.Modifiers[id]
		if m then
			req *= m.RequirementMultiplier
			reward *= m.RewardMultiplier
		end
	end
	return req, reward
end

function ModifierService.ApplyVisuals(model: Model, mods: { string })
	for _, id in mods do
		local m = ModifierConfig.Modifiers[id]
		local fn = m and Visuals[m.Visual]
		if fn then
			fn(model, m)
		end
	end
end

-- Combined event-interval multiplier (Corrupted builds have more events).
function ModifierService.EventIntervalMultiplier(mods: { string }): number
	local m = 1
	for _, id in mods do
		local def = ModifierConfig.Modifiers[id]
		if def then
			m *= def.EventIntervalMultiplier
		end
	end
	return m
end

function ModifierService.LuckyBonusChanceAdd(mods: { string }): number
	local add = 0
	for _, id in mods do
		local def = ModifierConfig.Modifiers[id]
		if def then
			add += def.LuckyBonusChanceAdd
		end
	end
	return add
end

-- "GOLDEN GIANT" prefix for titles, in configured display order.
function ModifierService.Prefix(mods: { string }): string
	local parts = {}
	for _, id in ModifierConfig.Order do
		if table.find(mods, id) then
			table.insert(parts, ModifierConfig.Modifiers[id].DisplayName)
		end
	end
	return table.concat(parts, " ")
end

return ModifierService
