--!nonstrict
-- PASS 21E: the big Training Pad. Replaces the old pavilion frame / middle race track / two benches / three-to-five treadmills with ONE bigger pad:
--
--   * a wide concrete pad (west of the spawn hub, clear of the hill to the south) with the RACE TRACK running around its whole edge
--   * north band: the beam lane (west) and crate lane (east), moved here from the old frame (tags and Lane attributes untouched)
--   * middle row: FIVE themed bench presses (west) and FIVE themed treadmills (east), levels 1..5 (Starter, Steel, Gold, Hacker, Cosmic)
--
-- Every machine is a LEVEL (attribute Level on the tagged part). The rank gate and XP multiplier per level live in TrainingConfig
-- (Treadmill.Tiers / Bench.Tiers); level 1 needs no Master Builder rank. Re-runnable: it removes what it built before and rebuilds it.
--
-- Part names the client relies on: Belt / Pad (tagged), Ridge (scrolling belt), Glow (neon pulse), RunFX / RunSpeed (emitters, off until used),
-- TierLight, Barbell (model with Bar). Gates: tag "TrainingGate" + GateIndex on the banner, in lap order.
local V = Vector3.new
local M = Enum.Material
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")


-- layout (world coordinates)
local PAD_X0, PAD_X1, PAD_Z0, PAD_Z1 = -300, -92, 128, 262
local LOOP_X0, LOOP_X1, LOOP_Z0, LOOP_Z1 = -294, -98, 134, 256
local ROW_Z = 210
local TREAD_X0, TREAD_STEP = -180, 16
local BENCH_X0, BENCH_STEP, BENCH_Z = -276, 18, 205
local LANE_Z = 160
local BEAM_STACK_X, CRATE_STACK_X = -276, -176

local THEMES = {
	{ frame = Color3.fromRGB(176, 120, 66), mat = M.WoodPlanks, trim = Color3.fromRGB(110, 70, 36), icon = "chevrons" },
	{ frame = Color3.fromRGB(126, 140, 164), mat = M.Metal, trim = Color3.fromRGB(70, 80, 100), icon = "bolt" },
	{ frame = Color3.fromRGB(238, 188, 56), mat = M.Metal, trim = Color3.fromRGB(150, 104, 24), icon = "coin" },
	{ frame = Color3.fromRGB(30, 34, 44), mat = M.Metal, trim = Color3.fromRGB(190, 44, 56), icon = "bolt" },
	{ frame = Color3.fromRGB(96, 56, 186), mat = M.SmoothPlastic, trim = Color3.fromRGB(52, 28, 110), icon = "star" },
}
local DARK = Color3.fromRGB(34, 38, 48)
local STEEL = Color3.fromRGB(84, 94, 116)
local RACE = Color3.fromRGB(222, 74, 66)

local function mk(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = M.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function tint(c: Color3, t: number): Color3
	return if t >= 0 then c:Lerp(Color3.new(1, 1, 1), t) else c:Lerp(Color3.new(0, 0, 0), -t)
end

local function label(part: BasePart, face: Enum.NormalId, text: string, color: Color3, size: number?)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 50
	g.LightInfluence = 0
	g.Parent = part
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Size = UDim2.fromScale(1, 1)
	l.Font = Enum.Font.BuilderSansExtraBold
	l.TextScaled = true
	l.TextColor3 = color
	l.Text = text
	l.Parent = g
	local c = Instance.new("UITextSizeConstraint")
	c.MaxTextSize = size or 70
	c.Parent = l
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(8, 10, 16)
	s.Thickness = 3
	s.Parent = l
end

local function addFX(belt: BasePart, neon: Color3)
	local light = Instance.new("PointLight")
	light.Name = "TierLight"
	light.Color = neon
	light.Range = 16
	light.Brightness = 0.5
	light.Parent = belt
	for _, spec in { { "RunFX", "rbxasset://textures/particles/sparkles_main.dds", 40 }, { "RunSpeed", "rbxasset://textures/particles/smoke_main.dds", 14 } } do
		local em = Instance.new("ParticleEmitter")
		em.Name = spec[1]
		em.Texture = spec[2]
		em.Color = ColorSequence.new(neon, neon:Lerp(Color3.new(1, 1, 1), 0.5))
		em.LightEmission = 1
		em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, if spec[1] == "RunFX" then 0.45 else 1.4), NumberSequenceKeypoint.new(1, 0) })
		em.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
		em.Lifetime = NumberRange.new(0.5, if spec[1] == "RunFX" then 1.1 else 0.7)
		em.Speed = NumberRange.new(if spec[1] == "RunFX" then 6 else 2, if spec[1] == "RunFX" then 12 else 5)
		em.SpreadAngle = Vector2.new(if spec[1] == "RunFX" then 35 else 12, 35)
		em.Acceleration = if spec[1] == "RunFX" then V(0, 8, 0) else V(0, 0, 14)
		em.Rate = spec[3]
		em.Enabled = false
		em.Parent = belt
	end
end

local function medallion(tm: Model, icon: string, at: Vector3, neon: Color3)
	local function P(props)
		return mk(tm, props)
	end
	P({ Name = "IconPlate", Shape = Enum.PartType.Cylinder, Size = V(0.5, 2.6, 2.6), CFrame = CFrame.new(at) * CFrame.Angles(0, math.rad(90), 0), Color = DARK })
	if icon == "bolt" then
		P({ Name = "Glow", Size = V(0.7, 1.5, 0.5), CFrame = CFrame.new(at + V(0.2, 0.45, 0.3)) * CFrame.Angles(0, 0, math.rad(-22)), Color = neon, Material = M.Neon, CanCollide = false })
		P({ Name = "Glow", Size = V(0.7, 1.5, 0.5), CFrame = CFrame.new(at + V(-0.2, -0.45, 0.3)) * CFrame.Angles(0, 0, math.rad(-22)), Color = neon, Material = M.Neon, CanCollide = false })
	elseif icon == "coin" then
		P({ Name = "Glow", Shape = Enum.PartType.Cylinder, Size = V(0.6, 1.8, 1.8), CFrame = CFrame.new(at + V(0, 0, 0.3)) * CFrame.Angles(0, math.rad(90), 0), Color = neon, Material = M.Neon, CanCollide = false })
	elseif icon == "star" then
		P({ Name = "Glow", Size = V(1.6, 1.6, 0.5), CFrame = CFrame.new(at + V(0, 0, 0.3)), Color = neon, Material = M.Neon, CanCollide = false })
		P({ Name = "Glow", Size = V(1.6, 1.6, 0.5), CFrame = CFrame.new(at + V(0, 0, 0.3)) * CFrame.Angles(0, 0, math.rad(45)), Color = neon, Material = M.Neon, CanCollide = false })
	else
		for k = -1, 1, 2 do
			P({ Name = "Glow", Size = V(1.4, 0.35, 0.5), CFrame = CFrame.new(at + V(0, k * 0.5, 0.3)) * CFrame.Angles(0, 0, math.rad(k * 20)), Color = neon, Material = M.Neon, CanCollide = false })
		end
	end
end

local function buildTreadmill(yard: Instance, i: number, tier, th, base: Vector3)
	local neon = tier.Color
	local tm = Instance.new("Model")
	tm.Name = "Treadmill"
	tm.Parent = yard
	local function P(props)
		return mk(tm, props)
	end
	P({ Name = "Deck", Size = V(7, 0.6, 14), Position = base + V(0, 0.3, 0), Color = th.trim, Material = M.Metal })
	local belt = P({ Name = "Belt", Size = V(5, 0.8, 11), Position = base + V(0, 0.7, 0), Color = DARK })
	belt:SetAttribute("Level", i)
	CollectionService:AddTag(belt, "TrainingTreadmill")
	for k = 0, 5 do
		P({ Name = "Ridge", Size = V(4.4, 0.1, 0.5), Position = base + V(0, 1.15, -5 + k * 2), Color = neon:Lerp(DARK, 0.55), Material = M.Neon, CanCollide = false, CanQuery = false, CanTouch = false })
	end
	for _, sx in { -2.6, 2.6 } do
		P({ Name = "Glow", Size = V(0.28, 0.12, 11), Position = base + V(sx, 1.12, 0), Color = neon, Material = M.Neon, CanCollide = false, CanQuery = false, CanTouch = false })
	end
	for _, sx in { -3.2, 3.2 } do
		P({ Name = "Side", Size = V(1.1, 1.4, 12.2), Position = base + V(sx, 1.1, 0.4), Color = th.frame, Material = th.mat })
		P({ Name = "Glow", Size = V(0.4, 0.14, 12.2), Position = base + V(sx, 1.86, 0.4), Color = neon, Material = M.Neon, CanCollide = false, CanQuery = false, CanTouch = false })
		P({ Name = "ConsolePost", Size = V(0.9, 7, 0.9), Position = base + V(sx, 3.8, -6), Color = th.frame, Material = th.mat })
		P({ Name = "Glow", Size = V(0.3, 6.6, 0.3), Position = base + V(sx, 3.8, -5.5), Color = neon, Material = M.Neon, CanCollide = false, CanQuery = false, CanTouch = false })
	end
	local banner = P({ Name = "Banner", Size = V(8.4, 2.2, 1), Position = base + V(0, 8.2, -6), Color = th.frame:Lerp(DARK, 0.35) })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		label(banner, face, string.upper(tier.Name), neon:Lerp(Color3.new(1, 1, 1), 0.2), 64)
	end
	P({ Name = "BannerTrim", Size = V(8.8, 0.35, 1.2), Position = base + V(0, 9.45, -6), Color = th.trim, Material = M.Metal })
	P({ Name = "Glow", Size = V(8.6, 0.2, 1.1), Position = base + V(0, 7.0, -6), Color = neon, Material = M.Neon, CanCollide = false, CanQuery = false, CanTouch = false })
	local tag = P({ Name = "SpeedTag", Size = V(4.6, 1.5, 0.5), Position = base + V(0, 5.9, -6.2), Color = DARK, CanCollide = false })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		label(tag, face, tier.Label, neon, 60)
	end
	medallion(tm, th.icon, base + V(0, 10.9, -6), neon)
	P({ Name = "Mat", Size = V(5.6, 0.14, 2.2), Position = base + V(0, 0.68, 7.4), Color = neon, Material = M.Neon, Transparency = 0.25, CanCollide = false, CanQuery = false, CanTouch = false })
	P({ Name = "MatEdge", Size = V(6.2, 0.1, 2.8), Position = base + V(0, 0.55, 7.4), Color = th.trim, Material = M.Metal, CanCollide = false, CanQuery = false, CanTouch = false })
	if i == 3 then
		for _, sx in { -4.6, 4.6 } do
			for k = 0, 2 do
				P({ Name = "Coin", Shape = Enum.PartType.Cylinder, Size = V(0.3, 1.5, 1.5), CFrame = CFrame.new(base + V(sx, 0.4 + k * 0.32, 4.2)) * CFrame.Angles(0, 0, math.rad(90)), Color = neon, Material = M.Metal, CanCollide = false })
			end
		end
	elseif i == 4 then
		for k = 0, 3 do
			P({ Name = "Glow", Size = V(0.2, 0.9 + (k % 2) * 0.6, 0.2), Position = base + V(-4.6 + k * 0.5, 1.2, 2), Color = neon, Material = M.Neon, CanCollide = false, CanQuery = false })
			P({ Name = "Glow", Size = V(0.2, 0.9 + ((k + 1) % 2) * 0.6, 0.2), Position = base + V(3.1 + k * 0.5, 1.2, -1), Color = neon, Material = M.Neon, CanCollide = false, CanQuery = false })
		end
	elseif i == 5 then
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2
			P({ Name = "Glow", Shape = Enum.PartType.Ball, Size = V(0.7, 0.7, 0.7) * (0.8 + (k % 3) * 0.25), Position = base + V(math.cos(a) * 5.2, 5 + math.sin(a * 2) * 0.8 + k * 0.3, -3 + math.sin(a) * 3), Color = neon, Material = M.Neon, CanCollide = false, CanQuery = false })
		end
	end
	addFX(belt, neon)
end

local function buildBench(yard: Instance, i: number, tier, th, base: Vector3)
	local neon = tier.Color
	local bench = Instance.new("Model")
	bench.Name = "BenchPress"
	bench.Parent = yard
	local function P(props)
		return mk(bench, props)
	end
	P({ Name = "FloorMat", Size = V(9, 0.16, 11.5), Position = base + V(0, 0.46, 0.8), Color = th.trim:Lerp(DARK, 0.5), CanCollide = false, CanQuery = false })
	P({ Name = "Glow", Size = V(9.2, 0.1, 0.3), Position = base + V(0, 0.58, 6.7), Color = neon, Material = M.Neon, CanCollide = false, CanQuery = false, CanTouch = false })
	P({ Name = "Frame", Size = V(2.2, 0.7, 6.2), Position = base + V(0, 0.35, 0), Color = th.frame, Material = th.mat })
	for _, sz in { -2.6, 2.6 } do
		P({ Name = "Foot", Size = V(3.4, 0.6, 0.9), Position = base + V(0, 0.3, sz), Color = th.trim, Material = M.Metal })
	end
	local pad = P({ Name = "Pad", Size = V(3.2, 1.2, 7), Position = base + V(0, 0.9, 0), Color = th.frame:Lerp(DARK, 0.45) })
	pad:SetAttribute("Level", i)
	CollectionService:AddTag(pad, "TrainingBench")
	P({ Name = "PadPiping", Size = V(3.36, 0.22, 7.16), Position = base + V(0, 0.42, 0), Color = neon, Material = M.Neon, CanCollide = false })
	for _, sx in { -2.6, 2.6 } do
		P({ Name = "Upright", Size = V(0.9, 4.8, 0.9), Position = base + V(sx, 2.8, 2.0), Color = th.frame, Material = th.mat })
		P({ Name = "Hook", Size = V(1.3, 0.45, 1.2), Position = base + V(sx * 0.9, 5.0, 2.0), Color = neon, Material = M.Neon })
		P({ Name = "Glow", Size = V(0.3, 4.4, 0.3), Position = base + V(sx, 2.8, 2.55), Color = neon, Material = M.Neon, CanCollide = false, CanQuery = false, CanTouch = false })
	end
	local bar = Instance.new("Model")
	bar.Name = "Barbell"
	bar.Parent = bench
	local barPart = mk(bar, { Name = "Bar", Shape = Enum.PartType.Cylinder, Size = V(8.8, 0.45, 0.45), CFrame = CFrame.new(base + V(0, 5.2, 2.0)), Color = Color3.fromRGB(214, 218, 226), Material = M.Metal, CanCollide = false })
	for _, sx in { -1, 1 } do
		mk(bar, { Name = "Plate", Shape = Enum.PartType.Cylinder, Size = V(0.6, 3.8, 3.8), CFrame = CFrame.new(base + V(sx * 3.1, 5.2, 2.0)), Color = DARK, CanCollide = false })
		mk(bar, { Name = "Plate", Shape = Enum.PartType.Cylinder, Size = V(0.5, 2.8 + i * 0.12, 2.8 + i * 0.12), CFrame = CFrame.new(base + V(sx * 3.65, 5.2, 2.0)), Color = neon, Material = if i >= 2 then M.Neon else M.SmoothPlastic, CanCollide = false })
		mk(bar, { Name = "Collar", Shape = Enum.PartType.Cylinder, Size = V(0.35, 1, 1), CFrame = CFrame.new(base + V(sx * 4.05, 5.2, 2.0)), Color = STEEL, Material = M.Metal, CanCollide = false })
	end
	bar.PrimaryPart = barPart
	-- name banner on two posts behind the bench (readable from both sides) + a level tag
	for _, sx in { -3.2, 3.2 } do
		P({ Name = "SignPost", Size = V(0.7, 6.6, 0.7), Position = base + V(sx, 3.3, -5.4), Color = th.frame, Material = th.mat })
	end
	local banner = P({ Name = "Banner", Size = V(7.4, 1.9, 0.9), Position = base + V(0, 7.0, -5.4), Color = th.frame:Lerp(DARK, 0.35) })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		label(banner, face, string.upper(tier.Name), neon:Lerp(Color3.new(1, 1, 1), 0.2), 56)
	end
	local tag = P({ Name = "SpeedTag", Size = V(4.4, 1.3, 0.5), Position = base + V(0, 5.3, -5.5), Color = DARK, CanCollide = false })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		label(tag, face, tier.Label, neon, 56)
	end
	P({ Name = "Glow", Size = V(7.6, 0.2, 1), Position = base + V(0, 6.0, -5.4), Color = neon, Material = M.Neon, CanCollide = false, CanQuery = false, CanTouch = false })
	addFX(pad, neon)
end

local function lampPost(parent: Instance, pos: Vector3)
	mk(parent, { Name = "LampPost", Size = V(0.8, 12, 0.8), Position = pos + V(0, 6, 0), Color = STEEL, Material = M.Metal })
	local head = mk(parent, { Name = "LampHead", Size = V(2.2, 0.6, 2.2), Position = pos + V(0, 12.3, 0), Color = Color3.fromRGB(255, 232, 170), Material = M.Neon, CanCollide = false })
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 226, 160)
	l.Range = 26
	l.Brightness = 0.9
	l.Parent = head
end

local function buildGate(track: Instance, idx: number, pos: Vector3, across: Vector3)
	local gm = Instance.new("Model")
	gm.Name = "Gate" .. idx
	gm.Parent = track
	for _, k in { -6.7, 6.7 } do
		local foot = pos + across * k
		mk(gm, { Name = "PostBase", Size = V(2.6, 0.6, 2.6), Position = foot + V(0, 0.3, 0), Color = STEEL, Material = M.Metal })
		mk(gm, { Name = "Post", Size = V(1.5, 10, 1.5), Position = foot + V(0, 5.3, 0), Color = Color3.fromRGB(236, 238, 244) })
	end
	local bs = if math.abs(across.X) > 0.5 then V(14.6, 2.6, 1.4) else V(1.4, 2.6, 14.6)
	local banner = mk(gm, { Name = "GateBanner", Size = bs, Position = pos + V(0, 9.6, 0), Color = RACE })
	banner:SetAttribute("GateIndex", idx)
	CollectionService:AddTag(banner, "TrainingGate")
	local trim = if math.abs(across.X) > 0.5 then V(14.8, 0.4, 1.5) else V(1.5, 0.4, 14.8)
	for _, ty in { -1.35, 1.35 } do
		mk(gm, { Name = "BannerTrim", Size = trim, Position = pos + V(0, 9.6 + ty, 0), Color = tint(RACE, -0.3), CanCollide = false })
	end
	-- (Pass 21F) a lap can start at ANY gate, so every gate says so
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right } do
		label(banner, face, "RACE  -  START ANYWHERE", Color3.new(1, 1, 1), 34)
	end
end

return function(ctx)
	local world = ctx.world
	-- (a rebuild from a Studio command passes a fresh TrainingConfig: require() caches the old one there)
	local TrainingConfig = ctx.TrainingConfig or require(ReplicatedStorage.Shared.Config.TrainingConfig)
	local yard = world.Areas:FindFirstChild("TrainingYard")
	if not yard then
		return "trainingPad21E: no TrainingYard"
	end

	-- 1. keep the crate and beam lanes (move them), remove everything else this pass owns
	local crateLane, beamLane = yard:FindFirstChild("CrateLane"), yard:FindFirstChild("BeamLane")
	local function moveLane(lane: Instance?, tagName: string, stackX: number)
		if not lane then
			return
		end
		for _, d in lane:GetDescendants() do
			if d:IsA("BasePart") and CollectionService:HasTag(d, tagName) then
				local delta = V(stackX - d.Position.X, 0, LANE_Z - d.Position.Z)
				lane:PivotTo(lane:GetPivot() + delta)
				return
			end
		end
	end
	moveLane(crateLane, "CrateStack", CRATE_STACK_X)
	moveLane(beamLane, "BeamStack", BEAM_STACK_X)
	for _, c in yard:GetChildren() do
		if c ~= crateLane and c ~= beamLane then
			c:Destroy()
		end
	end
	-- scenery that now stands on the pad (trees) is removed
	local scenery = world:FindFirstChild("Scenery")
	if scenery then
		for _, m in scenery:GetChildren() do
			local pos = if m:IsA("Model") then m:GetPivot().Position elseif m:IsA("BasePart") then m.Position else nil
			if pos and pos.X > PAD_X0 - 6 and pos.X < PAD_X1 + 6 and pos.Z > PAD_Z0 - 6 and pos.Z < PAD_Z1 + 6 then
				m:Destroy()
			end
		end
	end
	local pad = Instance.new("Folder")
	pad.Name = "TrainingPad"
	pad.Parent = yard

	-- 2. the pad: concrete slab, darker border, corner + side lamps
	local cx, cz = (PAD_X0 + PAD_X1) / 2, (PAD_Z0 + PAD_Z1) / 2
	mk(pad, { Name = "PadSlab", Size = V(PAD_X1 - PAD_X0, 0.3, PAD_Z1 - PAD_Z0), Position = V(cx, 0.15, cz), Color = Color3.fromRGB(150, 152, 160), Material = M.Concrete, CanQuery = false })
	for _, e in {
		{ V(PAD_X1 - PAD_X0, 0.34, 1.6), V(cx, 0.17, PAD_Z0 + 0.8) }, { V(PAD_X1 - PAD_X0, 0.34, 1.6), V(cx, 0.17, PAD_Z1 - 0.8) },
		{ V(1.6, 0.34, PAD_Z1 - PAD_Z0), V(PAD_X0 + 0.8, 0.17, cz) }, { V(1.6, 0.34, PAD_Z1 - PAD_Z0), V(PAD_X1 - 0.8, 0.17, cz) },
	} do
		mk(pad, { Name = "PadCurb", Size = e[1], Position = e[2], Color = Color3.fromRGB(84, 88, 98), Material = M.Concrete, CanQuery = false })
	end
	for _, x in { LOOP_X0 + 12, (LOOP_X0 + LOOP_X1) / 2, LOOP_X1 - 12 } do
		lampPost(pad, V(x, 0.3, LOOP_Z0 + 10))
		lampPost(pad, V(x, 0.3, LOOP_Z1 - 10))
	end
	for _, z in { 170, 195, 225 } do
		lampPost(pad, V(LOOP_X0 + 10, 0.3, z))
		lampPost(pad, V(LOOP_X1 - 10, 0.3, z))
	end
	-- zone mats under the two machine rows
	local benchW = BENCH_STEP * 4 + 14
	mk(pad, { Name = "ZoneMat", Size = V(benchW, 0.1, 30), Position = V(BENCH_X0 + BENCH_STEP * 2, 0.34, BENCH_Z + 3), Color = tint(Color3.fromRGB(255, 140, 52), 0.45), Material = M.Concrete, CanCollide = false, CanQuery = false })
	local treadW = TREAD_STEP * 4 + 14
	mk(pad, { Name = "ZoneMat", Size = V(treadW, 0.1, 28), Position = V(TREAD_X0 + TREAD_STEP * 2, 0.34, ROW_Z + 1), Color = tint(Color3.fromRGB(72, 166, 238), 0.45), Material = M.Concrete, CanCollide = false, CanQuery = false })

	-- 3. the race track around the whole pad
	local track = Instance.new("Folder")
	track.Name = "Track"
	track.Parent = pad
	local A, B, C, D = V(LOOP_X0, 0, LOOP_Z0), V(LOOP_X1, 0, LOOP_Z0), V(LOOP_X1, 0, LOOP_Z1), V(LOOP_X0, 0, LOOP_Z1)
	for _, leg in { { A, B }, { B, C }, { C, D }, { D, A } } do
		local mid = (leg[1] + leg[2]) / 2
		local len = (leg[2] - leg[1]).Magnitude
		local cf = CFrame.lookAt(V(mid.X, 0.45, mid.Z), V(leg[2].X, 0.45, leg[2].Z))
		mk(track, { Name = "TrackStrip", Size = V(10, 0.3, len + 10), CFrame = cf, Color = tint(RACE, 0.2), Material = M.Concrete, CanQuery = false })
		for _, sx in { -4.6, 4.6 } do
			mk(track, { Name = "TrackEdge", Size = V(0.4, 0.06, len - 10), CFrame = cf * CFrame.new(sx, 0.17, 0), Color = Color3.fromRGB(250, 246, 240), CanCollide = false, CanQuery = false, CanTouch = false })
		end
		-- dashed centre line
		local n = math.floor(len / 14)
		for k = 0, n - 1 do
			mk(track, { Name = "TrackDash", Size = V(0.4, 0.06, 6), CFrame = cf * CFrame.new(0, 0.17, -len / 2 + 7 + k * 14), Color = Color3.fromRGB(250, 246, 240), CanCollide = false, CanQuery = false, CanTouch = false })
		end
	end
	-- (Pass 21F) 12 gates, three per leg (24 studs in from each end and mid-leg): the posts stand just OUTSIDE the 10-stud strip, and none is
	-- at a corner (a corner gate's post used to land in the middle of the next leg). Any gate can start a lap; order is clockwise.
	local gateCount = 0
	for _, leg in { { A, B }, { B, C }, { C, D }, { D, A } } do
		local delta = leg[2] - leg[1]
		local len = delta.Magnitude
		local dir = delta.Unit
		local across = V(-dir.Z, 0, dir.X)
		for _, d in { 24, len / 2, len - 24 } do
			gateCount += 1
			buildGate(track, gateCount, leg[1] + dir * d, across)
		end
	end

	-- 4. machines
	local tt, bt = TrainingConfig.Treadmill.Tiers, TrainingConfig.Bench.Tiers
	for i = 1, #tt do
		buildTreadmill(pad, i, tt[i], THEMES[i], V(TREAD_X0 + (i - 1) * TREAD_STEP, 0, ROW_Z))
	end
	for i = 1, #bt do
		buildBench(pad, i, bt[i], THEMES[i], V(BENCH_X0 + (i - 1) * BENCH_STEP, 0, BENCH_Z))
	end
	return string.format("trainingPad21E: pad %dx%d, %d treadmills, %d benches, %d gates", PAD_X1 - PAD_X0, PAD_Z1 - PAD_Z0, #tt, #bt, gateCount)
end
