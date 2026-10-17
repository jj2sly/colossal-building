--!strict
-- Carried resource stacks, drawn LOCALLY by every client for every player from the
-- replicated Carry_<Res> attributes. Nothing is replicated per resource unit.
--
-- Visual tiers: one block per UNITS_PER_BLOCK units up to MAX_BLOCKS; beyond that the
-- blocks themselves grow, so higher Carry Capacity visibly means a bigger stack.
-- Blocks are split between resources by share. Each resource GRADE has its own look
-- (ResourceConfig.Look): Sticks are a tied bundle, Logs a bound stack, Timber heavy banded logs,
-- Rubble loose rocks, Stone Blocks neat cubes, Boulders spheres, Scrap bent plates, Metal Beams
-- flanged beams, Heavy Steel striped ingots, Batteries/Power Cells glowing cylinders, Energy Cores orbs.
-- With a vehicle, the stack sits in the vehicle's cargo bed instead of on the back.
-- Auras (CarryFXConfig): a resource-identity emitter for the dominant family plus a mutation layer that reuses the
-- resource's motion in the tier's colours; both scale with fill, amount and grade, and are culled by distance/budget.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)
local CosmeticConfig = require(ReplicatedStorage.Shared.Config.CosmeticConfig)
local MutationConfig = require(ReplicatedStorage.Shared.Config.MutationConfig)
local CarryFXConfig = require(ReplicatedStorage.Shared.Config.CarryFXConfig)

local CarryVisualController = {}

local UNITS_PER_BLOCK = 5
local MAX_BLOCKS = 10
local signatures: { [Player]: string } = {}

local Block, Cyl, Ball = Enum.PartType.Block, Enum.PartType.Cylinder, Enum.PartType.Ball

-- MUTATED blocks keep their shape but wear their tier: Golden = polished gold metal, Diamond = pale crystal glass, Prismatic = soft
-- colour-shifting pastel (one shared 8 Hz loop recolours every prismatic block that exists; it idles when there are none).
local TIER_MATERIAL = { Golden = Enum.Material.Metal, Diamond = Enum.Material.Glass, Prismatic = Enum.Material.SmoothPlastic }
local prismParts: { BasePart } = {}
local prismRunning = false
local function startPrismLoop()
	if prismRunning then
		return
	end
	prismRunning = true
	task.spawn(function()
		while #prismParts > 0 do
			local h = (os.clock() * 0.25) % 1
			for i = #prismParts, 1, -1 do
				local p = prismParts[i]
				if p.Parent then
					p.Color = Color3.fromHSV((h + i * 0.07) % 1, 0.55, 1)
				else
					table.remove(prismParts, i)
				end
			end
			task.wait(0.125)
		end
		prismRunning = false
	end)
end

-- "Res=g,d,p;Res=g,d,p" (ResourceService CarryMut) -> { Res = { golden, diamond, prismatic } }
local function parseMut(str: any): { [string]: { number } }
	local out = {}
	if type(str) == "string" then
		for res, g, d, pr in string.gmatch(str, "(%w+)=(%d+),(%d+),(%d+)") do
			out[res] = { tonumber(g) or 0, tonumber(d) or 0, tonumber(pr) or 0 }
		end
	end
	return out
end

-- Which tier (or nil) each block of `blocks` shows: the best tiers first, proportional to the mutated share of that resource.
local function assignTiers(player: Player, blocks: { string }): ({ string? }, string?)
	local out: { string? } = {}
	local best: string? = nil
	for res, counts in parseMut(player:GetAttribute("CarryMut")) do
		local idxs = {}
		for i, id in blocks do
			if id == res then
				table.insert(idxs, i)
			end
		end
		local mutUnits = counts[1] + counts[2] + counts[3]
		local have = math.max(1, player:GetAttribute("Carry_" .. res) or 1)
		if #idxs > 0 and mutUnits > 0 then
			local left = math.min(#idxs, math.max(1, math.ceil(#idxs * mutUnits / have)))
			local total = left
			local k = 1
			for _, entry in { { "Prismatic", counts[3] }, { "Diamond", counts[2] }, { "Golden", counts[1] } } do
				if entry[2] > 0 and left > 0 then
					local nb = math.min(left, math.max(1, math.floor(total * entry[2] / mutUnits + 0.5)))
					for _ = 1, nb do
						out[idxs[k]] = entry[1]
						k += 1
						left -= 1
					end
					if not best or MutationConfig.Tiers[entry[1]].Order > MutationConfig.Tiers[best].Order then
						best = entry[1]
					end
				end
			end
		end
	end
	return out, best
end

-- One carried "block" per few units, built from 1-2 parts. No part is ever created per unit.
local function buildBlock(model: Model, anchor: BasePart, cf: CFrame, res: any, size: Vector3, mutTier: string?)
	local tierDef = mutTier and MutationConfig.Tiers[mutTier]
	local function mk(shape: Enum.PartType, sz: Vector3, off: CFrame, color: Color3, mat: Enum.Material)
		if tierDef then
			-- keep the block's own shading but wear the tier (accent parts, like ropes and straps, tint the same way)
			color = color:Lerp(tierDef.Color, 0.72)
			mat = TIER_MATERIAL[tierDef.Id] or mat
		end
		local p = Instance.new("Part")
		p.Name = "Block"
		p.Shape = shape
		p.Size = sz
		p.Color = color
		p.Material = mat
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = false
		p.CFrame = cf * off
		local w = Instance.new("WeldConstraint")
		w.Part0 = anchor
		w.Part1 = p
		w.Parent = p
		if tierDef and tierDef.Id == "Diamond" then
			p.Transparency = 0.12
			p.Reflectance = 0.25
		elseif tierDef and tierDef.Id == "Golden" then
			p.Reflectance = 0.2
		elseif tierDef and tierDef.Id == "Prismatic" then
			table.insert(prismParts, p)
			startPrismLoop()
		end
		p.Parent = model
	end
	local c, m, look = res.Color, res.Material, res.Look
	local rope, dark = Color3.fromRGB(240, 210, 130), Color3.fromRGB(40, 40, 50)
	local white = Color3.fromRGB(246, 247, 250)
	if look == "Bundle" then
		-- sticks tied with bright rope and a green sprig
		mk(Block, size, CFrame.new(), c, m)
		mk(Block, Vector3.new(size.X * 0.16, size.Y * 1.22, size.Z * 1.22), CFrame.new(size.X * 0.22, 0, 0), rope, Enum.Material.Fabric)
		mk(Block, Vector3.new(size.X * 0.14, size.Y * 1.22, size.Z * 1.22), CFrame.new(-size.X * 0.22, 0, 0), rope, Enum.Material.Fabric)
		mk(Ball, Vector3.new(0.5, 0.35, 0.5), CFrame.new(0, size.Y * 0.62, 0), Color3.fromRGB(96, 200, 90), Enum.Material.Grass)
	elseif look == "Logs" or look == "Timber" then
		-- cut logs with pale end rings and iron straps
		mk(Cyl, size, CFrame.new(), c, m)
		for _, sx in { -1, 1 } do
			mk(Cyl, Vector3.new(0.12, size.Y * 0.8, size.Z * 0.8), CFrame.new(sx * size.X * 0.5, 0, 0), Color3.fromRGB(236, 200, 150), Enum.Material.Wood)
			mk(Cyl, Vector3.new(size.X * 0.1, size.Y * 1.1, size.Z * 1.1), CFrame.new(sx * size.X * 0.24, 0, 0), dark, Enum.Material.Metal)
		end
	elseif look == "StarMetal" then
		-- dark meteoric metal with a cool glass inlay and a pale seam
		mk(Block, size, CFrame.Angles(0, 0.25, 0.08), c, Enum.Material.Metal)
		mk(Block, Vector3.new(size.X * 0.7, size.Y * 0.22, size.Z * 0.5), CFrame.new(0, size.Y * 0.5, 0), Color3.fromRGB(120, 200, 255), Enum.Material.Glass)
		mk(Block, Vector3.new(size.X * 1.02, size.Y * 0.1, size.Z * 0.14), CFrame.new(0, -size.Y * 0.1, size.Z * 0.3), Color3.fromRGB(190, 220, 255), Enum.Material.Neon)
	elseif look == "AncientWood" then
		-- an aged log with gold bands and a moss patch
		mk(Cyl, size, CFrame.new(), c, m)
		for _, sx in { -1, 1 } do
			mk(Cyl, Vector3.new(0.12, size.Y * 0.8, size.Z * 0.8), CFrame.new(sx * size.X * 0.5, 0, 0), Color3.fromRGB(176, 140, 88), Enum.Material.Wood)
			mk(Cyl, Vector3.new(size.X * 0.09, size.Y * 1.1, size.Z * 1.1), CFrame.new(sx * size.X * 0.26, 0, 0), Color3.fromRGB(214, 176, 70), Enum.Material.Metal)
		end
		mk(Block, Vector3.new(size.X * 0.5, 0.2, size.Z * 0.7), CFrame.new(0, size.Y * 0.46, 0), Color3.fromRGB(96, 150, 72), Enum.Material.Grass)
	elseif look == "Rubble" then
		mk(Block, size, CFrame.Angles(0, 0.4, 0.1), c, m)
		mk(Block, size * 0.55, CFrame.new(size.X * 0.25, size.Y * 0.45, 0) * CFrame.Angles(0.5, 0.2, 0.3), c:Lerp(white, 0.2), m)
		mk(Block, Vector3.new(0.28, 0.7, 0.28), CFrame.new(-size.X * 0.2, size.Y * 0.6, size.Z * 0.2) * CFrame.Angles(0.3, 0.5, 0.2), Color3.fromRGB(72, 172, 255), Enum.Material.Neon)
	elseif look == "Blocks" then
		mk(Block, size, CFrame.new(), c, m)
		mk(Block, Vector3.new(size.X * 1.02, size.Y * 0.14, size.Z * 1.02), CFrame.new(0, size.Y * 0.5, 0), c:Lerp(white, 0.35), Enum.Material.Concrete)
		mk(Block, Vector3.new(size.X * 1.02, size.Y * 0.1, size.Z * 1.02), CFrame.new(0, -size.Y * 0.04, 0), c:Lerp(dark, 0.25), Enum.Material.Concrete)
	elseif look == "Boulder" then
		mk(Ball, size, CFrame.new(), c, m)
		mk(Ball, size * 0.5, CFrame.new(0, size.Y * 0.4, 0), Color3.fromRGB(110, 190, 90), Enum.Material.Grass)
		mk(Block, Vector3.new(0.3, 0.9, 0.3), CFrame.new(size.X * 0.4, size.Y * 0.2, -size.Z * 0.3) * CFrame.Angles(0.4, 0.5, 0.3), Color3.fromRGB(180, 120, 255), Enum.Material.Neon)
	elseif look == "Core" then
		mk(Ball, size, CFrame.new(), c, m)
		mk(Cyl, Vector3.new(0.14, size.Y * 1.55, size.Z * 1.55), CFrame.Angles(0, 0, math.rad(60)), white, Enum.Material.Neon)
	elseif look == "Scrap" then
		mk(Block, size, CFrame.Angles(0, 0.3, 0.12), c, m)
		mk(Block, Vector3.new(size.X * 0.7, size.Y * 0.8, size.Z * 0.6), CFrame.new(0, size.Y * 0.5, 0) * CFrame.Angles(0.3, 0.9, 0), Color3.fromRGB(255, 140, 50), Enum.Material.CorrodedMetal)
		mk(Cyl, Vector3.new(0.3, size.Y * 0.9, size.Y * 0.9), CFrame.new(size.X * 0.3, size.Y * 0.35, size.Z * 0.2) * CFrame.Angles(0, 0.4, 0), Color3.fromRGB(190, 196, 208), Enum.Material.Metal)
	elseif look == "Beams" then
		mk(Block, size, CFrame.new(), c, m)
		mk(Block, Vector3.new(size.X, size.Y * 0.4, size.Z * 2.4), CFrame.new(0, size.Y * 0.5, 0), c:Lerp(white, 0.2), m)
		for _, sx in { -1, 1 } do
			mk(Block, Vector3.new(size.X * 0.12, size.Y * 1.5, size.Z * 2.5), CFrame.new(sx * size.X * 0.5, 0, 0), dark, Enum.Material.Metal)
		end
	elseif look == "Steel" then
		mk(Block, size, CFrame.new(), c, m)
		mk(Block, Vector3.new(size.X * 0.22, size.Y * 1.04, size.Z * 1.04), CFrame.new(), Color3.fromRGB(255, 130, 40), Enum.Material.SmoothPlastic)
		mk(Block, Vector3.new(size.X * 1.02, size.Y * 0.14, size.Z * 1.02), CFrame.new(0, size.Y * 0.5, 0), c:Lerp(white, 0.3), Enum.Material.Metal)
	elseif look == "Battery" or look == "Cell" then
		mk(Cyl, size, CFrame.Angles(0, 0, math.rad(90)), c, m)
		mk(Cyl, Vector3.new(size.Y * 0.2, size.X * 0.55, size.Z * 0.55), CFrame.new(0, size.Y * 0.5, 0) * CFrame.Angles(0, 0, math.rad(90)), white, Enum.Material.Metal)
		mk(Cyl, Vector3.new(size.Y * 0.16, size.X * 1.08, size.Z * 1.08), CFrame.new(0, 0, 0) * CFrame.Angles(0, 0, math.rad(90)), dark, Enum.Material.SmoothPlastic)
	else
		mk(Block, size, CFrame.new(), c, m)
	end
end

-- CARRY AURAS ----------------------------------------------------------------------------------------------------------
-- One resource emitter (+ optional glow) and at most one mutation emitter per stack. Their rates are set from the stack's
-- intensity on every carry change, and a low-rate loop switches them off for far stacks and beyond the MaxAuras budget.
type AuraState = {
	anchor: BasePart?,
	family: string,
	grade: number,
	secret: boolean,
	tier: string?,
	res: ParticleEmitter?,
	mut: ParticleEmitter?,
	glow: PointLight?,
	intensity: number?,
	mutIntensity: number?,
	visible: boolean?,
	resAllowed: boolean?,
}
local auras: { [Player]: AuraState } = {}
local SMOKE_TEX = "rbxasset://textures/particles/smoke_main.dds"
local SPARK_TEX = "rbxasset://textures/particles/sparkles_main.dds"

local function colorSeq(list: { Color3 }): ColorSequence
	if #list == 1 then
		return ColorSequence.new(list[1])
	elseif #list == 2 then
		return ColorSequence.new(list[1], list[2])
	end
	local kps = {}
	for i, c in list do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#list - 1), c))
	end
	return ColorSequence.new(kps)
end

-- An emitter with the RESOURCE's motion. With `mut`, the mutation layer: same motion, the tier's colours/size/light.
local function makeEmitter(a: CarryFXConfig.Aura, mut: CarryFXConfig.Mutation?, parent: BasePart): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Name = if mut then "MB_MutAura" else "MB_ResAura"
	-- a smoky resource (Stone grit) still sparkles in its mutation layer: tinted smoke just reads as mud
	e.Texture = if mut and a.Texture == SMOKE_TEX then SPARK_TEX else a.Texture
	e.Color = colorSeq(if mut then mut.Colors else a.Color)
	local size = a.Size * (if mut then mut.SizeMult else 1)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, if mut then math.min(a.Transparency, 0.2) else a.Transparency), NumberSequenceKeypoint.new(1, 1) })
	e.LightEmission = math.min(1, a.Light + (if mut then mut.LightAdd else 0))
	e.Lifetime = NumberRange.new(a.Life[1], a.Life[2])
	e.Speed = NumberRange.new(a.Speed[1], a.Speed[2])
	e.Acceleration = Vector3.new(0, a.Gravity, 0)
	e.Drag = a.Drag
	e.SpreadAngle = Vector2.new(a.Spread, a.Spread)
	e.RotSpeed = NumberRange.new(-90, 90)
	e.Rate = 0
	e.Parent = parent
	return e
end

local function destroyAura(a: AuraState)
	-- the instances live inside MB_Stack and go with it; only drop the references
	a.res, a.mut, a.glow, a.anchor = nil, nil, nil, nil
end

-- The family the aura shows: a secret resource wins (endgame loads always read as such), else the family with the most units.
local function dominantFamily(player: Player): (string, number, boolean)
	local units: { [string]: number } = {}
	local grades: { [string]: number } = {}
	local secretFam: string? = nil
	for _, id in ResourceConfig.Order do
		local n = player:GetAttribute("Carry_" .. id) or 0
		local r = ResourceConfig.Resources[id]
		if n > 0 and r then
			units[r.Family] = (units[r.Family] or 0) + n
			grades[r.Family] = math.max(grades[r.Family] or 1, r.Grade)
			if r.Secret and not secretFam then
				secretFam = r.Family
			end
		end
	end
	if secretFam then
		return secretFam, grades[secretFam] or 1, true
	end
	local best, bestN = CarryFXConfig.DefaultFamily, -1
	for fam, n in units do
		if n > bestN then
			best, bestN = fam, n
		end
	end
	return best, grades[best] or 1, false
end

-- Mutated share of the whole load, from the replicated CarryMut string.
local function mutatedShare(player: Player, total: number): number
	if total <= 0 then
		return 0
	end
	local m = 0
	for _, c in parseMut(player:GetAttribute("CarryMut")) do
		m += c[1] + c[2] + c[3]
	end
	return math.clamp(m / total, 0, 1)
end

-- Rates follow the CURRENT intensity; `visible` / `resAllowed` come from the culling loop.
local function applyAura(a: AuraState)
	local fam = CarryFXConfig.Family(a.family)
	local cfg = CarryFXConfig.Carry
	local vis = a.visible ~= false
	local i = a.intensity or 0
	local showRes = vis and a.resAllowed ~= false and i >= (if a.secret then 0 else cfg.MinIntensity)
	if a.res then
		a.res.Rate = if showRes then fam.Aura.Rate * i else 0
	end
	if a.glow then
		a.glow.Enabled = showRes and (a.secret or i >= cfg.LightAt) -- secret loads always carry their soft light
	end
	if a.mut and a.tier then
		local mdef = CarryFXConfig.Mutations[a.tier]
		a.mut.Rate = if vis and mdef then fam.Aura.Rate * mdef.RateMult * (a.mutIntensity or 0) else 0
	end
end

local function refreshIntensity(player: Player)
	local a = auras[player]
	if not a then
		return
	end
	local total = player:GetAttribute("CarryTotal") or 0
	local cap = player:GetAttribute("CarryCap") or 0
	local family, grade, secret = dominantFamily(player)
	a.family, a.grade, a.secret = family, grade, secret
	a.intensity = CarryFXConfig.CarryIntensity(total, cap, grade, secret)
	local cfg = CarryFXConfig.Carry
	a.mutIntensity = math.max(cfg.MutShareFloor, mutatedShare(player, total)) * math.max(cfg.MutMinIntensity, a.intensity)
	applyAura(a)
end

-- Distance culling + budget: the nearest MaxAuras stacks keep their resource layer; mutation layers stay within range.
local function startCulling()
	local acc = 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		acc += dt
		if acc < 1 / CarryFXConfig.Carry.UpdateHz then
			return
		end
		acc = 0
		local cam = workspace.CurrentCamera
		if not cam then
			return
		end
		local camPos = cam.CFrame.Position
		local list = {}
		for p, a in auras do
			if a.anchor and a.anchor.Parent then
				local d = (a.anchor.Position - camPos).Magnitude
				a.visible = d <= CarryFXConfig.Carry.CullDistance
				if a.visible then
					table.insert(list, { a = a, d = if p == Players.LocalPlayer then -1 else d })
				end
			else
				auras[p] = nil
			end
		end
		table.sort(list, function(x, y)
			return x.d < y.d
		end)
		for i, e in list do
			e.a.resAllowed = i <= CarryFXConfig.Carry.MaxAuras
		end
		for _, a in auras do
			applyAura(a)
		end
	end)
end

local function allocate(player: Player): ({ string }, number)
	local total = player:GetAttribute("CarryTotal") or 0
	if total <= 0 then
		return {}, 1
	end
	local blocks = math.clamp(math.ceil(total / UNITS_PER_BLOCK), 1, MAX_BLOCKS)
	-- grow block size past the block cap: 1x at 50 units, ~2.2x at 400+
	local scale = 1 + math.clamp((total - UNITS_PER_BLOCK * MAX_BLOCKS) / 300, 0, 1.2)
	-- largest-remainder split of blocks across resources
	local shares = {}
	for _, id in ResourceConfig.Order do
		local n = player:GetAttribute("Carry_" .. id) or 0
		if n > 0 then
			local exact = n / total * blocks
			table.insert(shares, { id = id, count = math.floor(exact), rem = exact - math.floor(exact) })
		end
	end
	local assigned = 0
	for _, s in shares do
		assigned += s.count
	end
	table.sort(shares, function(a, b)
		return a.rem > b.rem
	end)
	local i = 1
	while assigned < blocks and #shares > 0 do
		shares[(i - 1) % #shares + 1].count += 1
		assigned += 1
		i += 1
	end
	local list = {}
	for _, id in ResourceConfig.Order do
		for _, s in shares do
			if s.id == id then
				for _ = 1, s.count do
					table.insert(list, id)
				end
			end
		end
	end
	return list, math.floor(scale * 10 + 0.5) / 10
end

local function clear(char: Model)
	local old = char:FindFirstChild("MB_Stack")
	if old then
		old:Destroy()
	end
end

local function rebuild(player: Player)
	local char = player.Character
	if not char then
		return
	end
	local blocks, scale = allocate(player)
	-- while driving, the load shows in the vehicle's bed (workspace.MB_Vehicles/<userId>), never on the body
	local vFolder = workspace:FindFirstChild("MB_Vehicles")
	local vehicle = if player:GetAttribute("Driving") and vFolder then vFolder:FindFirstChild(tostring(player.UserId)) else nil
	local sig = table.concat(blocks, ",") .. "|" .. scale .. "|" .. tostring(vehicle) .. "|" .. tostring(player:GetAttribute("CosCarry")) .. "|" .. tostring(player:GetAttribute("CarryMut"))
	if signatures[player] == sig and (#blocks == 0 or char:FindFirstChild("MB_Stack")) then
		refreshIntensity(player) -- same blocks, but fill/amount may have moved (CarryCap, partial deposit)
		return
	end
	clear(char)
	auras[player] = nil
	if #blocks == 0 then
		signatures[player] = sig
		return
	end
	local model = Instance.new("Model")
	model.Name = "MB_Stack"
	local anchorPart: BasePart?
	local base: CFrame
	local cargo = vehicle and vehicle:FindFirstChild("Cargo", true) :: Attachment?
	if cargo then
		anchorPart = cargo.Parent :: BasePart
		base = cargo.WorldCFrame
	else
		local torso = (char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")) :: BasePart?
		if not torso then
			return -- not loaded yet; signature stays unset so the next call retries
		end
		anchorPart = torso
		base = torso.CFrame * CFrame.new(0, -torso.Size.Y / 2 + 0.3, torso.Size.Z / 2 + 0.1)
	end
	local tiers, bestTier = assignTiers(player, blocks)
	local y = 0
	-- vehicle beds publish their floor size; the load is spread over it in a grid (rows x columns per layer)
	local bedW = cargo and tonumber(cargo:GetAttribute("BedWidth"))
	local bedL = cargo and tonumber(cargo:GetAttribute("BedLength"))
	local cell = Vector3.zero
	if cargo then
		for _, id in blocks do
			local s = ResourceConfig.Resources[id].StackBlockSize * scale
			cell = Vector3.new(math.max(cell.X, s.X), math.max(cell.Y, s.Y), math.max(cell.Z, s.Z))
		end
	end
	-- shrink oversized blocks so a row always fits across the bed
	local fit = if bedW and cell.X > bedW then bedW / cell.X else 1
	cell *= fit
	local cols = if bedW then math.max(1, math.floor(bedW / cell.X)) else 3
	local rows = if bedL then math.max(1, math.floor(bedL / cell.Z)) else 1
	for i, id in blocks do
		local res = ResourceConfig.Resources[id]
		local size = res.StackBlockSize * scale
		local offset
		if cargo then
			size *= fit
			local k = i - 1
			local col = k % cols
			local row = (k // cols) % rows
			local layer = k // (cols * rows)
			local twist = math.rad(((i * 37) % 9) - 4) -- a few degrees either way, so it looks loaded by hand
			offset = CFrame.new((col - (cols - 1) / 2) * cell.X, size.Y / 2 + layer * cell.Y, (row - (rows - 1) / 2) * cell.Z) * CFrame.Angles(0, twist, 0)
		else
			-- stacked on the back, slight alternating twist for a hand-stacked look
			offset = CFrame.new(0, y + size.Y / 2, size.Z / 2) * CFrame.Angles(0, math.rad(if i % 2 == 0 then 6 else -6), 0)
			y += size.Y
		end
		buildBlock(model, anchorPart :: BasePart, base * offset, res, size, tiers[i])
	end
	-- two-layer aura (CarryFXConfig): the RESOURCE identity of the dominant family, plus the MUTATION layer painted onto
	-- that same motion. Emitters are created once per stack; their rates follow intensity (fill, amount, grade) without a rebuild.
	local first = model:FindFirstChildWhichIsA("BasePart", true)
	local family, grade, secret = dominantFamily(player)
	local aura = auras[player]
	if aura then
		destroyAura(aura)
	end
	aura = { anchor = first, family = family, grade = grade, secret = secret, tier = bestTier }
	auras[player] = aura
	if first and CarryFXConfig.Enabled then
		local fam = CarryFXConfig.Family(family)
		aura.res = makeEmitter(fam.Aura, nil, first)
		if fam.Aura.Glow then
			local gl = Instance.new("PointLight")
			gl.Color = fam.Aura.Glow
			gl.Range = CarryFXConfig.Carry.LightRange
			gl.Brightness = CarryFXConfig.Carry.LightBrightness
			gl.Shadows = false
			gl.Enabled = false
			gl.Parent = first
			aura.glow = gl
		end
		if bestTier and CarryFXConfig.Mutations[bestTier] then
			aura.mut = makeEmitter(fam.Aura, CarryFXConfig.Mutations[bestTier], first)
		end
	end
	-- a mutated stack glows so you can recognise it from across the map: ONE soft light and ONE outline for the whole stack
	if bestTier then
		local tdef = MutationConfig.Tiers[bestTier]
		if first then
			local light = Instance.new("PointLight")
			light.Color = tdef.Color
			light.Range = if bestTier == "Prismatic" then 16 elseif bestTier == "Diamond" then 13 else 10
			light.Brightness = if bestTier == "Golden" then 0.7 else 1.0
			light.Shadows = false
			light.Parent = first
			local em = aura.mut -- the mutation layer (nil if CarryFXConfig is disabled)
			-- Diamond / Prismatic loads also get a soft outline so a hauler is recognisable from across the map (rare, so cheap)
			if bestTier ~= "Golden" then
				local hl = Instance.new("Highlight")
				hl.FillColor = tdef.Color
				hl.OutlineColor = tdef.Color2
				hl.FillTransparency = 0.7
				hl.OutlineTransparency = 0.2
				hl.DepthMode = Enum.HighlightDepthMode.Occluded
				hl.Parent = model
				-- Prismatic loads slowly shift hue (outline + light), so they never read as Diamond from across the map
				if bestTier == "Prismatic" then
					task.spawn(function()
						while hl.Parent and light.Parent do
							local h = os.clock() * 0.18
							hl.OutlineColor = Color3.fromHSV(h % 1, 0.55, 1)
							hl.FillColor = Color3.fromHSV((h + 0.3) % 1, 0.4, 1)
							light.Color = Color3.fromHSV(h % 1, 0.45, 1)
							if em and em.Parent then
								-- the resource's own motion keeps flowing; only its pastel hue drifts
								em.Color = ColorSequence.new(Color3.fromHSV(h % 1, 0.45, 1), Color3.fromHSV((h + 0.35) % 1, 0.35, 1))
							end
							task.wait(0.1)
						end
					end)
				end
			end
		end
	end
	-- equipped carry effect: ONE light and ONE sparkle emitter for the whole stack (never one per unit)
	local fxId = player:GetAttribute("CosCarry")
	local fx = if type(fxId) == "string" then CosmeticConfig.Get("CarryEffect", fxId) else nil
	local top = model:FindFirstChildWhichIsA("BasePart", true)
	if fx and top then
		local light = Instance.new("PointLight")
		light.Color = fx.Glow
		light.Brightness = 0.9
		light.Range = 9
		light.Parent = top
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(fx.Spark)
		e.LightEmission = 0.7
		e.Rate = fx.Rate
		e.Lifetime = NumberRange.new(0.6, 1.1)
		e.Speed = NumberRange.new(1, 3)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		e.Parent = top
	end
	model.Parent = char
	signatures[player] = sig
	refreshIntensity(player)
end

local function watch(player: Player)
	local function hookChar(char: Model)
		signatures[player] = nil
		task.spawn(function()
			-- wait for the body to exist before attaching the stack
			if char:WaitForChild("HumanoidRootPart", 10) then
				local _ = char:FindFirstChild("UpperTorso") or char:WaitForChild("Torso", 2) or char:WaitForChild("UpperTorso", 5)
				rebuild(player)
			end
		end)
		player:GetAttributeChangedSignal("Driving"):Connect(function()
			signatures[player] = nil
			task.delay(0.15, rebuild, player)
		end)
	end
	-- CarryTotal and Carry_<Res> change together on every gather/deposit tick; coalesce them
	-- into one rebuild per frame per player
	local queued = false
	player.AttributeChanged:Connect(function(attr)
		if (attr == "CarryTotal" or string.sub(attr, 1, 6) == "Carry_" or attr == "CosCarry" or attr == "CarryMut" or attr == "CarryCap") and not queued then
			queued = true
			task.defer(function()
				queued = false
				rebuild(player)
			end)
		end
	end)
	player.CharacterAdded:Connect(hookChar)
	if player.Character then
		hookChar(player.Character)
	end
end

function CarryVisualController.Start()
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		signatures[p] = nil
		auras[p] = nil
	end)
	startCulling()
end

return CarryVisualController
