--!nonstrict
-- EDIT-TIME GENERATOR (not used at runtime). Builds Workspace.World: the central build
-- site, the four resource zones, shop/garage/worker/spawn areas, paths, signs, props and
-- lighting. Run from the command bar:
--   require(game.ServerStorage.DevTools.WorldBuilder:Clone()).Build()
-- Re-running replaces Workspace.World. After generation the geometry is ordinary
-- parts you can hand-edit in Studio (don't re-run if you've hand-edited it).
--
-- Layout: ONE continuous, irregular world built around the giant build at the origin. The spawn sits on a small town
--   square directly SOUTH of the build (looking north at it); the Upgrade Workshop, Worker Office, Vehicle Garage and Build
--   Index Archive line the square; the Training Yard sits off to the west of it. Level 1 resources hug the plaza; four curving,
--   branching roads lead beside and behind the build to grander Tier 2 and Tier 3 destinations that hide behind ridges, a
--   creek, tree lines, quarry walls, a cliff and a mountain. The ground is Roblox Terrain (grass + painted roads and biome
--   floors); buildings, landmarks and resource nodes are parts. Spots come from Shared/Config/ResourceSpotConfig.
local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local ServerStorage = game:GetService("ServerStorage")

local WorldBuilder = {}

local rng = Random.new(1234)

-- Spots (location, tier, bonuses) come from ResourceSpotConfig: edit them there and rebuild.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ResourceSpotConfig = require(ReplicatedStorage.Shared.Config.ResourceSpotConfig)
local RES_LABEL = { Wood = "WOOD", Stone = "STONE", Metal = "METAL", PowerCell = "POWER CELLS" }
local RES_COLOR = { Wood = Color3.fromRGB(120, 220, 90), Stone = Color3.fromRGB(200, 205, 215), Metal = Color3.fromRGB(150, 200, 255), PowerCell = Color3.fromRGB(80, 230, 255) }
local curSpotId = ""
local curResId = ""
local ResourceConfig = require(ReplicatedStorage.Shared.Config.ResourceConfig)
local function famOf(resId: string): string
	return ResourceConfig.Resources[resId].Family
end
-- the Training Yard sits right beside the spawn square (west side); TRAIN_TERRAIN_KEEPOUT is where it used to be and stays
-- as a terrain keep-out so the locked hills and landforms generate exactly as before
local TRAIN_CENTER = Vector3.new(-112, 0, 128)
local TRAIN_TERRAIN_KEEPOUT = Vector3.new(-186, 0, 104)
local world: Folder

local function P(parent: Instance, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent
	return f
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Text on a part face.
local function surfaceText(part: BasePart, face: Enum.NormalId, text: string, color: Color3?, bg: Color3?)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
	g.LightInfluence = 0.2
	g.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = if bg then 0 else 1
	l.BackgroundColor3 = bg or Color3.new()
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color or Color3.new(1, 1, 1)
	l.Text = text
	l.Parent = g
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0.05, 0)
	pad.PaddingRight = UDim.new(0.05, 0)
	pad.PaddingTop = UDim.new(0.08, 0)
	pad.PaddingBottom = UDim.new(0.08, 0)
	pad.Parent = l
end

-- Floating label readable from far away.
local function billboard(part: BasePart, text: string, color: Color3, sizeStuds: number, offsetY: number)
	local b = Instance.new("BillboardGui")
	b.Size = UDim2.fromScale(sizeStuds, sizeStuds * 0.28)
	b.StudsOffsetWorldSpace = Vector3.new(0, offsetY, 0)
	b.MaxDistance = 1800
	b.LightInfluence = 0
	b.Parent = part
	local l = Instance.new("TextLabel")
	l.Size = UDim2.fromScale(1, 1)
	l.BackgroundTransparency = 1
	l.Font = Enum.Font.FredokaOne
	l.TextScaled = true
	l.TextColor3 = color
	l.TextStrokeTransparency = 0
	l.TextStrokeColor3 = Color3.fromRGB(20, 20, 30)
	l.Text = text
	l.Parent = b
end

------------------------------------------------------------------- STYLE KIT (art pass)
-- Polished-simulator look: saturated but controlled palette, chunky proportions, every solid gets a lighter top cap and a
-- darker foot ("bevel" for free), colour-blocked trim, round shapes where they read better (balls, cylinders).
local C = {
	Orange = Color3.fromRGB(255, 138, 31),
	Yellow = Color3.fromRGB(255, 205, 60),
	Navy = Color3.fromRGB(30, 38, 64),
	Slate = Color3.fromRGB(62, 74, 104),
	White = Color3.fromRGB(246, 247, 250),
	Sky = Color3.fromRGB(72, 172, 255),
	Teal = Color3.fromRGB(48, 200, 190),
	Red = Color3.fromRGB(235, 70, 70),
	Green = Color3.fromRGB(96, 200, 90),
	Purple = Color3.fromRGB(150, 100, 235),
	Cream = Color3.fromRGB(250, 236, 200),
	Wood = Color3.fromRGB(176, 120, 66),
}

local function tint(c: Color3, t: number): Color3
	return if t >= 0 then c:Lerp(Color3.new(1, 1, 1), t) else c:Lerp(Color3.new(0, 0, 0), -t)
end

-- Chunky block: body + lighter top cap + darker foot. Returns the body (tag / collide this one).
local function chunk(parent: Instance, cf: CFrame, size: Vector3, color: Color3, mat: Enum.Material?, name: string?): Part
	local body = P(parent, { Name = name or "Chunk", Size = size, CFrame = cf, Color = color, Material = mat or Enum.Material.SmoothPlastic })
	if size.Y >= 0.8 then
		P(parent, { Name = "Cap", Size = Vector3.new(size.X * 0.96, 0.16, size.Z * 0.96), CFrame = cf * CFrame.new(0, size.Y / 2, 0), Color = tint(color, 0.22), CanCollide = false, CanQuery = false })
		P(parent, { Name = "Foot", Size = Vector3.new(size.X * 1.04, 0.22, size.Z * 1.04), CFrame = cf * CFrame.new(0, -size.Y / 2 + 0.11, 0), Color = tint(color, -0.3), CanCollide = false, CanQuery = false })
	end
	return body
end

-- Upright cylinder (diameter x height) centred at cf.
local function column(parent: Instance, cf: CFrame, diameter: number, height: number, color: Color3, mat: Enum.Material?, name: string?): Part
	return P(parent, { Name = name or "Column", Shape = Enum.PartType.Cylinder, Size = Vector3.new(height, diameter, diameter), CFrame = cf * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = mat or Enum.Material.SmoothPlastic })
end

local function ball(parent: Instance, pos: Vector3, diameter: number, color: Color3, mat: Enum.Material?, name: string?): Part
	return P(parent, { Name = name or "Ball", Shape = Enum.PartType.Ball, Size = Vector3.one * diameter, Position = pos, Color = color, Material = mat or Enum.Material.SmoothPlastic })
end

------------------------------------------------------------------- shared helpers
------------------------------------------------------------------- shared helpers
local function ground(parent: Instance, center: Vector3, size: Vector3, color: Color3, material: Enum.Material, name: string?)
	return P(parent, { Name = name or "Ground", Size = size, Position = center + Vector3.new(0, size.Y / 2 - 0.45, 0), Color = color, Material = material })
end

local function lamp(parent: Instance, pos: Vector3)
	-- a slim street lamp with a warm, low glow (it supports the scene; it is never a focal point)
	local m = model(parent, "Lamp")
	local iron = Color3.fromRGB(58, 64, 80)
	column(m, CFrame.new(pos + Vector3.new(0, 0.3, 0)), 1.5, 0.6, iron, Enum.Material.Metal, "Base")
	column(m, CFrame.new(pos + Vector3.new(0, 1.1, 0)), 0.9, 1.0, iron, Enum.Material.Metal, "Collar")
	column(m, CFrame.new(pos + Vector3.new(0, 5.3, 0)), 0.45, 8.4, iron, Enum.Material.Metal, "Pole")
	column(m, CFrame.new(pos + Vector3.new(0, 9.65, 0)), 1.9, 0.35, iron, Enum.Material.Metal, "Shade")
	column(m, CFrame.new(pos + Vector3.new(0, 9.95, 0)), 1.0, 0.3, iron, Enum.Material.Metal, "ShadeTop")
	ball(m, pos + Vector3.new(0, 10.25, 0), 0.4, iron, Enum.Material.Metal, "Finial")
	local bulb = ball(m, pos + Vector3.new(0, 9.25, 0), 0.9, Color3.fromRGB(255, 220, 170), Enum.Material.SmoothPlastic)
	bulb.CanCollide = false
	local light = Instance.new("PointLight")
	light.Range = 14
	light.Brightness = 0.5
	light.Shadows = false
	light.Color = Color3.fromRGB(255, 200, 140)
	light.Parent = bulb
end

-- gather-node clearings: positions collected by tag(), applied once after every zone exists (ReplaceMaterial keeps the ground
-- level; only the material changes, so the tall Studio grass blades disappear around nodes)
local clearings: { Vector3 } = {}
local function applyClearings()
	for _, p in clearings do
		local r = Region3.new(p - Vector3.new(7, 6, 7), p + Vector3.new(7, 2, 7)):ExpandToGrid(4)
		workspace.Terrain:ReplaceMaterial(r, 4, Enum.Material.Grass, Enum.Material.LeafyGrass)
	end
	table.clear(clearings)
end

local function tag(inst: Instance, _family: string)
	if inst:IsA("BasePart") then
		table.insert(clearings, Vector3.new(inst.Position.X, 0, inst.Position.Z))
	end
	-- the node gathers the GRADE of the spot being built (ResourceSpotConfig.Resource), not the family name
	inst:SetAttribute("ResourceId", curResId)
	inst:SetAttribute("SpotId", curSpotId)
	CollectionService:AddTag(inst, "ResourceNode")
end

local function gatherPoint(parent: Instance, pos: Vector3)
	P(parent, { Name = "GatherPoint", Size = Vector3.new(2, 1, 2), Position = pos + Vector3.new(0, 3, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
end

local function aura(parent: Instance, pos: Vector3, color: Color3, rate: number?)
	local a = P(parent, { Name = "Aura", Size = Vector3.one, Position = pos, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(color, tint(color, 0.6))
	e.LightEmission = 0.5
	e.Rate = rate or 5
	e.Lifetime = NumberRange.new(2.5, 4)
	e.Speed = NumberRange.new(1, 2.5)
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 0) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
	e.Shape = Enum.ParticleEmitterShape.Cylinder
	e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.Parent = a
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = 18
	l.Brightness = 0.5
	l.Shadows = false
	l.Parent = a
	return a
end

local function disc(parent: Instance, center: Vector3, diameter: number, topY: number, color: Color3, mat: Enum.Material, name: string?, thickness: number?): Part
	local h = thickness or 0.6
	return P(parent, { Name = name or "Disc", Shape = Enum.PartType.Cylinder, Size = Vector3.new(h, diameter, diameter), CFrame = CFrame.new(center.X, topY - h / 2, center.Z) * CFrame.Angles(0, 0, math.rad(90)), Color = color, Material = mat })
end

local function nicecrate(parent: Instance, pos: Vector3, size: Vector3, color: Color3, yaw: number): Part
	local cf = CFrame.new(pos + Vector3.new(0, size.Y / 2, 0)) * CFrame.Angles(0, yaw, 0)
	local body = chunk(parent, cf, size, color, Enum.Material.SmoothPlastic, "Crate")
	for _, s in { -1, 1 } do
		P(parent, { Name = "Strap", Size = Vector3.new(size.X * 1.03, size.Y * 1.03, size.Z * 0.16), CFrame = cf * CFrame.new(0, 0, s * size.Z * 0.28), Color = tint(color, -0.35), CanCollide = false })
	end
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			P(parent, { Name = "Corner", Size = Vector3.new(size.X * 0.14, size.Y * 1.04, size.Z * 0.14), CFrame = cf * CFrame.new(cx * size.X * 0.46, 0, cz * size.Z * 0.46), Color = C.White, CanCollide = false })
		end
	end
	return body
end

local CRATE_COLORS = { Color3.fromRGB(255, 150, 50), Color3.fromRGB(48, 200, 190), Color3.fromRGB(235, 70, 70), Color3.fromRGB(72, 172, 255), Color3.fromRGB(255, 205, 60) }











-- per-family look: accent colour and plaza paving
local THEME = {
	Wood = { post = Color3.fromRGB(150, 98, 56), rail = C.Cream, accent = C.Green, plaza = Color3.fromRGB(198, 160, 108) },
	Stone = { post = Color3.fromRGB(128, 124, 132), rail = C.White, accent = C.Sky, plaza = Color3.fromRGB(214, 208, 196) },
	Metal = { post = Color3.fromRGB(70, 80, 102), rail = C.Yellow, accent = C.Orange, plaza = Color3.fromRGB(136, 142, 156) },
	PowerCell = { post = C.Slate, rail = C.White, accent = C.Teal, plaza = Color3.fromRGB(196, 210, 220) },
}

------------------------------------------------------------------- map data
-- ONE continuous world. The spawn sits on a small town square directly in front of (south of) the giant build; four curving
-- roads branch away BESIDE and BEHIND the build into progressively grander destinations that hide behind ridges, a creek,
-- tree lines, quarry walls and a mountain. Coordinates in studs; the build site is the origin, forward (from spawn) is -Z.
local V = Vector3.new
local M = Enum.Material
local SPAWN = V(0, 0, 104)

-- Road splines (control points; Catmull-Rom through them). Width in studs. Dirt = sandy path, no curb or dashes.
local ROADS = {
	{ Name = "TimberRoad", Width = 18, Dashes = true, Points = { V(-54, 0, -16), V(-84, 0, -30), V(-126, 0, -36), V(-170, 0, -40), V(-214, 0, -38), V(-262, 0, -44), V(-306, 0, -54), V(-340, 0, -70), V(-362, 0, -126), V(-388, 0, -192), V(-418, 0, -252), V(-440, 0, -300) } },
	{ Name = "SteelRoad", Width = 18, Dashes = true, Points = { V(-36, 0, -44), V(-62, 0, -82), V(-92, 0, -128), V(-120, 0, -175), V(-152, 0, -232), V(-196, 0, -286), V(-235, 0, -320), V(-252, 0, -382), V(-238, 0, -440), V(-204, 0, -480), V(-172, 0, -498) } },
	{ Name = "PowerRoad", Width = 18, Dashes = true, Points = { V(24, 0, -50), V(52, 0, -92), V(92, 0, -134), V(135, 0, -160), V(178, 0, -212), V(222, 0, -266), V(240, 0, -300), V(222, 0, -360), V(184, 0, -420), V(152, 0, -466), V(134, 0, -500) } },
	{ Name = "StoneRoad", Width = 18, Dashes = true, Points = { V(54, 0, 18), V(88, 0, 36), V(138, 0, 34), V(186, 0, 6), V(205, 0, -30), V(262, 0, -34), V(340, 0, -30), V(372, 0, -88), V(386, 0, -156), V(392, 0, -212), V(394, 0, -252) } },
	{ Name = "YardPath", Width = 10, Dirt = true, Points = { V(-34, 0, 112), V(-48, 0, 113), V(-63, 0, 114) } },
	{ Name = "GaragePath", Width = 10, Dirt = true, Points = { V(66, 0, 94), V(76, 0, 70), V(88, 0, 42) } },
}
local CREEK = { V(-166, 0, -6), V(-170, 0, -40), V(-177, 0, -80), V(-186, 0, -120), V(-193, 0, -150) }
local PONDS = { { P = V(-165, 0, 10), R = 17 }, { P = V(-194, 0, -153), R = 14 } }
local ZONE_R = { 30, 44, 60 } -- ground radius per tier
local ROAD_TOP = 0.42 -- (pass 2) top of the raised road body (parts); the shoulder step sits at 0.2

-- filled in by Build(): road samples { p, hw } and keep-out circles { p, r } used to keep hills / trees / nodes clear
local roadSamples: { any } = {}
local keepOut: { any } = {}
local decorF: Folder

local Terrain = workspace.Terrain

------------------------------------------------------------------- helpers
local function catmull(p0: Vector3, p1: Vector3, p2: Vector3, p3: Vector3, t: number): Vector3
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (p2 - p0) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (3 * p1 - p0 - 3 * p2 + p3) * t3)
end

-- Catmull-Rom through the control points, resampled to roughly `spacing` studs.
local function splinePoints(pts: { Vector3 }, spacing: number): { Vector3 }
	local dense = {}
	local n = #pts
	for i = 1, n - 1 do
		local p0 = pts[math.max(1, i - 1)]
		local p1, p2 = pts[i], pts[i + 1]
		local p3 = pts[math.min(n, i + 2)]
		local steps = math.max(2, math.ceil((p2 - p1).Magnitude / 1.5))
		for s = 0, steps - 1 do
			table.insert(dense, catmull(p0, p1, p2, p3, s / steps))
		end
	end
	table.insert(dense, pts[n])
	local out = { dense[1] }
	local acc = 0
	for i = 2, #dense do
		acc += (dense[i] - dense[i - 1]).Magnitude
		if acc >= spacing then
			table.insert(out, dense[i])
			acc = 0
		end
	end
	if (out[#out] - dense[#dense]).Magnitude > 1 then
		table.insert(out, dense[#dense])
	end
	return out
end

local function flatDist(a: Vector3, b: Vector3): number
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

-- true when a circle of radius r at p stays off every road (plus margin)
local function roadClear(p: Vector3, r: number, margin: number?): boolean
	local m = margin or 3
	for _, s in roadSamples do
		if flatDist(p, s.p) < r + s.hw + m then
			return false
		end
	end
	return true
end

-- true when a circle stays off roads AND every keep-out area (hub, yard, zones, water, landforms)
local function clearOf(p: Vector3, r: number, margin: number?): boolean
	local m = margin or 4
	if not roadClear(p, r, m) then
		return false
	end
	for _, k in keepOut do
		if flatDist(p, k.p) < r + k.r + m then
			return false
		end
	end
	return true
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Terrain }
local function groundAt(x: number, z: number): number
	local hit = workspace:Raycast(V(x, 300, z), V(0, -400, 0), groundParams)
	return if hit then hit.Position.Y else 0
end

-- n points inside a zone, off the roads, away from `avoid` circles and `spacing` apart
local function spots(c: Vector3, n: number, rMin: number, rMax: number, spacing: number, rad: number, avoid: { any }?): { Vector3 }
	local pts = {}
	local tries = 0
	while #pts < n and tries < 1500 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber(rMin * rMin, rMax * rMax))
		local p = c + V(math.cos(a) * r, 0, math.sin(a) * r)
		local ok = roadClear(p, rad)
		if ok and avoid then
			for _, q in avoid do
				if flatDist(p, q[1]) < q[2] + rad then
					ok = false
					break
				end
			end
		end
		if ok then
			for _, q in pts do
				if flatDist(p, q) < spacing then
					ok = false
					break
				end
			end
		end
		if ok then
			table.insert(pts, p)
		end
	end
	return pts
end

local function B(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, collide: boolean?): Part
	return P(parent, { Name = name, Size = size, CFrame = cf, Color = color, Material = mat or M.SmoothPlastic, CanCollide = collide ~= false })
end

-- a vertical cylinder whose BASE sits at pos
local function post(parent: Instance, pos: Vector3, diameter: number, height: number, color: Color3, mat: Enum.Material?, name: string?): Part
	return column(parent, CFrame.new(pos + V(0, height / 2, 0)), diameter, height, color, mat, name)
end

local function soft(part: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = part
end

local function smoke(parent: Instance, pos: Vector3, color: Color3, rate: number, size: number)
	local a = P(parent, { Name = "SmokeEmitter", Size = Vector3.one, Position = pos, Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 2.6) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(5, 8)
	e.Rate = rate
	e.Speed = NumberRange.new(3, 5)
	e.Acceleration = V(1.2, 0.6, 0)
	e.SpreadAngle = Vector2.new(10, 10)
	e.RotSpeed = NumberRange.new(-15, 15)
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = a
end

local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Anchored = true
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = mat or M.SmoothPlastic
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = parent
	return w
end

-- gable roof: two sloped slabs meeting at a ridge along local X, plus triangular gable ends. `cf` = centre of the eaves line.
local function gableRoof(parent: Instance, cf: CFrame, w: number, d: number, pitch: number, color: Color3, gableColor: Color3)
	local a = math.rad(pitch)
	local half = d / 2
	local rise = half * math.tan(a)
	for _, s in { -1, 1 } do
		B(parent, "Roof", V(w, 0.8, half / math.cos(a) + 0.8), cf * CFrame.new(0, rise / 2 + 0.35, s * half / 2) * CFrame.Angles(s * a, 0, 0), color)
	end
	-- gable triangles at both ends (a WedgePart is tall at +Z, so the back half is turned around)
	for _, sx in { -1, 1 } do
		wedge(parent, "Gable", V(0.8, rise, half), cf * CFrame.new(sx * (w / 2 - 1.2), rise / 2, -half / 2), gableColor)
		wedge(parent, "Gable", V(0.8, rise, half), cf * CFrame.new(sx * (w / 2 - 1.2), rise / 2, half / 2) * CFrame.Angles(0, math.pi, 0), gableColor)
	end
end

------------------------------------------------------------------- terrain
local function setTerrainColors()
	local colors = {
		[M.LeafyGrass] = Color3.fromRGB(110, 194, 80),
		[M.Grass] = Color3.fromRGB(80, 164, 70),
		[M.Ground] = Color3.fromRGB(142, 112, 86),
		[M.Sand] = Color3.fromRGB(232, 210, 158),
		[M.Rock] = Color3.fromRGB(164, 152, 140),
		[M.Slate] = Color3.fromRGB(98, 96, 106),
		[M.Mud] = Color3.fromRGB(128, 104, 86),
		[M.Concrete] = Color3.fromRGB(180, 182, 190),
		[M.Pavement] = Color3.fromRGB(186, 192, 202),
		[M.Basalt] = Color3.fromRGB(66, 62, 64),
		[M.Salt] = Color3.fromRGB(212, 218, 230),
		[M.Asphalt] = Color3.fromRGB(78, 82, 98),
		[M.Limestone] = Color3.fromRGB(214, 206, 186),
		[M.Cobblestone] = Color3.fromRGB(146, 140, 130),
		[M.CrackedLava] = Color3.fromRGB(150, 74, 40),
		[M.Glacier] = Color3.fromRGB(130, 176, 226),
		[M.Snow] = Color3.fromRGB(240, 244, 250),
		[M.Sandstone] = Color3.fromRGB(222, 196, 146),
	}
	for mat, col in colors do
		Terrain:SetMaterialColor(mat, col)
	end
	Terrain.WaterColor = Color3.fromRGB(56, 172, 226)
	Terrain.WaterTransparency = 0.35
	Terrain.WaterReflectance = 0.5
	Terrain.WaterWaveSize = 0.08
	Terrain.WaterWaveSpeed = 6
	pcall(function()
		(Terrain :: any).Decoration = false
	end)
end

-- TERRAIN NOTE: Roblox terrain cells are 4 studs; a cell column filled to height h renders its surface at h + 2, so the flat
-- ground (surface y = 0) is written directly as voxels: full cells below -4 and a HALF-full top cell (-4..0). Ground
-- materials (biome floors, roads, curbs, beaches) are painted into a 2D map first and written with that top layer, so
-- painting never raises the ground. Hills, rock walls and the mountain are added afterwards; water is carved last.
local MAP_MIN, MAP_MAX = V(-760, 0, -840), V(760, 0, 480)
local CELL = 4
local paintMap: { [number]: { [number]: Enum.Material } } = {}

local function paintDisc(center: Vector3, radius: number, mat: Enum.Material)
	local x0 = math.floor((center.X - radius - MAP_MIN.X) / CELL)
	local x1 = math.ceil((center.X + radius - MAP_MIN.X) / CELL)
	local z0 = math.floor((center.Z - radius - MAP_MIN.Z) / CELL)
	local z1 = math.ceil((center.Z + radius - MAP_MIN.Z) / CELL)
	local r2 = radius * radius
	for ix = x0, x1 do
		local cx = MAP_MIN.X + ix * CELL + CELL / 2 - center.X
		for iz = z0, z1 do
			local cz = MAP_MIN.Z + iz * CELL + CELL / 2 - center.Z
			if cx * cx + cz * cz <= r2 then
				local col = paintMap[ix]
				if not col then
					col = {}
					paintMap[ix] = col
				end
				col[iz] = mat
			end
		end
	end
end

-- an irregular patch of ground material (never a perfect circle)
local function blob(center: Vector3, radius: number, mat: Enum.Material)
	paintDisc(center, radius * 0.78, mat)
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local d = radius * rng:NextNumber(0.3, 0.55)
		paintDisc(center + V(math.cos(a) * d, 0, math.sin(a) * d), radius * rng:NextNumber(0.38, 0.52), mat)
	end
end

-- write the whole flat ground (surface y = 0) with the painted top layer, tile by tile
local function writeBase()
	Terrain:Clear()
	local nx = (MAP_MAX.X - MAP_MIN.X) / CELL
	local nz = (MAP_MAX.Z - MAP_MIN.Z) / CELL
	local TILE = 64
	for tx = 0, nx - 1, TILE do
		for tz = 0, nz - 1, TILE do
			local sx = math.min(TILE, nx - tx)
			local sz = math.min(TILE, nz - tz)
			local mats, occs = {}, {}
			for ix = 1, sx do
				local mcol, ocol = {}, {}
				local pcol = paintMap[tx + ix - 1]
				for iy = 1, 6 do
					local mrow, orow = {}, {}
					for iz = 1, sz do
						if iy < 6 then
							mrow[iz] = M.LeafyGrass
							orow[iz] = 1
						else
							mrow[iz] = (pcol and pcol[tz + iz - 1]) or M.LeafyGrass
							orow[iz] = 0.5
						end
					end
					mcol[iy] = mrow
					ocol[iy] = orow
				end
				mats[ix] = mcol
				occs[ix] = ocol
			end
			local lo = V(MAP_MIN.X + tx * CELL, -24, MAP_MIN.Z + tz * CELL)
			Terrain:WriteVoxels(Region3.new(lo, lo + V(sx * CELL, 24, sz * CELL)), CELL, mats, occs)
		end
	end
end

-- After landforms and hills: wherever the ground is exposed again (canyon floor, hill fringes) put back the flat half-full
-- ground cell with its painted material, so carved areas sit exactly at y = 0 and roads / biome floors stay painted.
local function restoreGround()
	local nx = (MAP_MAX.X - MAP_MIN.X) / CELL
	local nz = (MAP_MAX.Z - MAP_MIN.Z) / CELL
	local TILE = 64
	for tx = 0, nx - 1, TILE do
		for tz = 0, nz - 1, TILE do
			local sx = math.min(TILE, nx - tx)
			local sz = math.min(TILE, nz - tz)
			local lo = V(MAP_MIN.X + tx * CELL, -4, MAP_MIN.Z + tz * CELL)
			local region = Region3.new(lo, lo + V(sx * CELL, 8, sz * CELL))
			local mats, occs = Terrain:ReadVoxels(region, CELL)
			local changed = false
			for ix = 1, sx do
				local pcol = paintMap[tx + ix - 1]
				for iz = 1, sz do
					if occs[ix][2][iz] < 0.3 then
						occs[ix][2][iz] = 0
						occs[ix][1][iz] = 0.5
						mats[ix][1][iz] = (pcol and pcol[tz + iz - 1]) or M.LeafyGrass
						changed = true
					end
				end
			end
			if changed then
				Terrain:WriteVoxels(region, CELL, mats, occs)
			end
		end
	end
end

-- (art reset pass 2) LANDFORM: every hill is a faceted, stylized landform instead of a sphere cap. An 8-sided frustum (a small
-- plateau and planar slopes) that is asymmetric: one long, gentle face and one short, steep face, the steep face of the larger
-- grass hills exposed as a rock cut, and one chunky shelf stepped into the gentle side. Nothing reaches past `foot` (the same
-- footprint the old dome had), and it is deterministic from position (no rng), so every caller keeps its random stream.
local LF_TAN = math.tan(math.pi / 8)
local function frustum(pos: Vector3, foot: number, height: number, yaw: number, lean: number, mat: Enum.Material, cutMat: Enum.Material?)
	local H = math.max(2, height - 2) -- terrain renders ~2 studs above the filled volume
	local top = foot * 0.28
	local s = foot * 0.12 * lean -- the plateau sits off-centre toward the steep side
	local steep = V(math.cos(yaw), 0, math.sin(yaw))
	local c = pos + steep * s
	local runSteep = foot * (1 - 0.35 * lean) - top - s
	local runGentle = foot - top + s
	for k = 0, 1 do
		Terrain:FillBlock(CFrame.new(c.X, H / 2 - 1, c.Z) * CFrame.Angles(0, yaw + k * math.pi / 4, 0), V(top * 2, H + 2, top * 2), mat)
	end
	for k = 0, 7 do
		local a = yaw + k * math.pi / 4
		local d = V(math.cos(a), 0, math.sin(a))
		local cs = math.cos(a - yaw)
		local run = math.max(2, (runSteep + runGentle) / 2 + (runSteep - runGentle) / 2 * cs)
		local width = (top + run * 0.55) * LF_TAN * 4.2
		local wc = c + d * (top + run / 2) + V(0, H / 2 - 1, 0)
		Terrain:FillWedge(CFrame.lookAt(wc, wc + d), V(width, H + 2, run), if cutMat and k == 0 then cutMat else mat)
	end
end

local function landform(pos: Vector3, foot: number, height: number, mat: Enum.Material?)
	local m = mat or M.LeafyGrass
	local n1 = math.noise(pos.X / 71.3, pos.Z / 71.3, 5.1)
	local n2 = math.noise(pos.X / 43.7, pos.Z / 43.7, 6.3)
	local yaw = n1 * 7 + pos.X * 0.013
	local lean = math.clamp(0.55 + n2 * 0.5, 0.2, 1)
	local cut = nil
	if (m == M.LeafyGrass or m == M.Grass) and foot >= 34 and height >= 16 and n2 > -0.1 then
		cut = M.Rock
	end
	frustum(pos, foot, height, yaw, lean, m, cut)
	if foot > 30 and height > 10 then
		-- a shelf on the gentle side: a flat step at half height with its own short drop (reads as one deliberate terrace)
		local back = V(-math.cos(yaw), 0, -math.sin(yaw))
		local H = math.max(2, height * 0.5 - 2)
		local sc = pos + back * foot * 0.58
		local cf = CFrame.lookAt(V(sc.X, H / 2 - 1, sc.Z), V(sc.X, H / 2 - 1, sc.Z) + back)
		Terrain:FillBlock(cf, V(foot * 0.62, H + 2, foot * 0.26), m)
		Terrain:FillWedge(cf * CFrame.new(0, 0, -foot * 0.23), V(foot * 0.62, H + 2, foot * 0.2), m)
	end
end

-- `foot` = radius where it meets the ground, `height` above ground
local function hill(pos: Vector3, foot: number, height: number, mat: Enum.Material?)
	landform(pos, foot, height, mat)
end

-- `skipDraw`: reserve the footprint (keep-out) without raising terrain (pass 2 drops the small rolling bumps and opens saddles)
local function tryHill(pos: Vector3, foot: number, height: number, mat: Enum.Material?, skipDraw: boolean?): boolean
	if clearOf(pos, foot, 6) then
		if not skipDraw then
			hill(pos, foot, height, mat)
		end
		table.insert(keepOut, { p = pos, r = foot * 0.55 })
		return true
	end
	return false
end

------------------------------------------------------------------- HIDDEN ENDGAME AREAS: terrain (ring of hills with one gap, painted floor)
-- Two small pockets on the far east / west edges of the valley (ResourceSpotConfig spots with `Secret`): a rock-walled meteor crater
-- and an ancient grove behind grassy ridges. They use their OWN random streams, so the locked valley layout is untouched.
local function secretSpots(): { any }
	local out = {}
	for _, spot in ResourceSpotConfig.List() do
		if spot.Secret then
			table.insert(out, spot)
		end
	end
	return out
end

local function paintSecret()
	for _, spot in secretSpots() do
		if spot.Id == "StarCrater" then
			paintDisc(spot.Position, 42, M.Basalt)
			paintDisc(spot.Position, 15, M.Slate)
		else
			paintDisc(spot.Position, 42, M.Grass)
			paintDisc(spot.Position + V(8, 0, -6), 12, M.Mud)
		end
	end
end

-- the crater bowl and its walls are dark rock everywhere (terrain blending left grass patches on the slopes)
local function scorchCrater()
	for _, spot in secretSpots() do
		if spot.Id == "StarCrater" then
			local c, R = spot.Position, 66
			for dx = -R, R - 8, 8 do
				local mid = dx + 4
				local hw = math.sqrt(math.max(0, R * R - mid * mid))
				if hw > 4 then
					local r = Region3.new(V(c.X + dx, -40, c.Z - hw), V(c.X + dx + 8, 100, c.Z + hw)):ExpandToGrid(4)
					for _, mat in { M.Grass, M.LeafyGrass, M.Ground, M.Mud, M.Sand } do
						workspace.Terrain:ReplaceMaterial(r, 4, mat, M.Basalt)
					end
				end
			end
		end
	end
end

local function secretHills()
	local srng = Random.new(9001)
	for _, spot in secretSpots() do
		local c = spot.Position
		-- the gap faces the middle of the valley, so the pocket is found by walking toward the map edge
		local gap = math.atan2(-60 - c.Z, 0 - c.X)
		local rock = spot.Id == "StarCrater"
		for k = 0, 17 do
			local a = k / 18 * math.pi * 2 + srng:NextNumber(-0.07, 0.07)
			local d = math.abs((a - gap + math.pi) % (math.pi * 2) - math.pi)
			if d > 0.55 then
				local pos = c + V(math.cos(a) * 68, 0, math.sin(a) * 68)
				local foot = srng:NextNumber(20, 27)
				local height = if rock then srng:NextNumber(28, 42) else srng:NextNumber(18, 28)
				hill(pos, foot, height, if rock then M.Basalt else M.LeafyGrass)
			end
		end
		table.insert(keepOut, { p = c, r = 90 })
	end
end

-- ground paint for everything that is known up front: biome floors, beaches, creek banks, curbs, roads
local ZONE_MAT = {
	Forest = M.Grass, LumberCamp = M.Ground, TimberStand = M.Grass,
	Quarry = M.Sand, DeepQuarry = M.Sand, BoulderField = M.Sand,
	Mine = M.Mud, IndustrialYard = M.Concrete, SteelWorks = M.Basalt,
	Energy = M.Pavement, ReactorYard = M.Pavement, CoreVault = M.Salt,
	StarCrater = M.Basalt, AncientGrove = M.Grass,
}
local function paintGround()
	paintMap = {}
	for _, spot in ResourceSpotConfig.List() do
		if not spot.Secret then -- (the hidden areas are painted deterministically in paintSecret so the random stream is untouched)
			blob(spot.Position, ZONE_R[spot.Tier], ZONE_MAT[spot.Id] or M.Ground)
			if ZONE_MAT[spot.Id] == M.Grass then
				-- keep the tall grass to a natural fringe: the working middle is short grass so nodes and players stay visible
				paintDisc(spot.Position, ZONE_R[spot.Tier] * 0.62, M.LeafyGrass)
			end
		end
	end
	paintSecret()
	for _, pond in PONDS do
		paintDisc(pond.P, pond.R + 5, M.Sand)
	end
	-- the Training Yard floor: a rounded rectangle of the same warm dirt as the paths, so it reads as part of the hub
	local yx0, yx1 = TRAIN_CENTER.X - 50, TRAIN_CENTER.X + 50
	local yz0, yz1 = TRAIN_CENTER.Z - 63, TRAIN_CENTER.Z + 63
	local corner = 16
	for x = yx0, yx1, 4 do
		for z = yz0, yz1, 4 do
			local cx = math.clamp(x, yx0 + corner, yx1 - corner)
			local cz = math.clamp(z, yz0 + corner, yz1 - corner)
			if (x - cx) ^ 2 + (z - cz) ^ 2 <= corner * corner then
				paintDisc(V(x, 0, z), 2.9, M.Sandstone)
			end
		end
	end
	for _, p in splinePoints(CREEK, 3) do
		paintDisc(p, 8.5, M.Sand)
	end
	for _, road in ROADS do
		if not road.Dirt then
			for _, p in road.Samples do
				paintDisc(p, road.Width / 2 + 1.6, M.Limestone)
			end
		end
	end
	for _, road in ROADS do
		for _, p in road.Samples do
			paintDisc(p, road.Width / 2, if road.Dirt then M.Sandstone else M.Asphalt)
		end
	end
end

-- big landforms that make the far destinations: the excavation mountain (with a canyon cut into it), the steel-mine cliff,
-- and the rock rim of the quarry
local function landforms()
	-- MOUNTAIN EXCAVATION: rock masses, then a canyon carved out of them down to the flat ground
	-- (pass 2) faceted masses (same footprints as the old sphere caps): broad planes and shelves, not a dome
	landform(V(452, 0, -326), 106, 56, M.Rock)
	landform(V(510, 0, -404), 80, 46, M.Slate)
	landform(V(380, 0, -360), 57, 30, M.Rock)
	local zc = V(394, 0, -252)
	local dir = (V(364, 0, -194) - zc).Unit
	local cc = zc + dir * 35
	-- carving from y = -2 leaves the half-full ground cell, so the canyon floor sits exactly at y = 0
	Terrain:FillBlock(CFrame.lookAt(V(cc.X, 44, cc.Z), V(cc.X, 44, cc.Z) + dir), V(120, 92, 190), M.Air)
	-- HEAVY STEEL MINE: a dark cliff wall behind the yard
	Terrain:FillBlock(CFrame.new(-172, 20, -588), V(200, 70, 60), M.Basalt)
	for _, b in { { V(-110, 6, -600), 44 }, { V(-236, 2, -596), 48 }, { V(-172, 34, -612), 56 }, { V(-60, -10, -590), 40 }, { V(-290, -14, -585), 44 } } do
		Terrain:FillBall(b[1], b[2], M.Basalt) -- (the cliff ledges above rest on these masses; reshaped with the mine in Pass 3)
	end
	-- ENERGY REACTOR: a ring of rocky outcrops around the reactor yard
	local rc = V(134, 0, -500)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2 + 0.3
		local p = rc + V(math.cos(a) * 70, 0, math.sin(a) * 70)
		if roadClear(p, 16, 6) then
			local foot, height = rng:NextNumber(14, 20), rng:NextNumber(14, 24)
			-- (pass 2) the reactor approach stays controlled: every other outcrop, a little broader
			if i % 2 == 0 then
				hill(p, math.min(foot * 1.2, 21), height, M.Slate)
			end
		end
	end
	-- QUARRY: a broken ring of rock walls (gaps wherever the road passes through)
	local qc = V(340, 0, -30)
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2 + rng:NextNumber(-0.06, 0.06)
		local r = rng:NextNumber(50, 56)
		local p = qc + V(math.cos(a) * r, 0, math.sin(a) * r)
		local foot = rng:NextNumber(11, 16)
		if roadClear(p, foot, 6) then
			hill(p, foot, rng:NextNumber(14, 22), M.Rock)
		end
	end
end

local function hills()
	-- sight-line ridges: behind the build, between the near and far destinations, around the far ones
	local explicit = {
		{ -20, -200, 58, 24 }, { 50, -206, 52, 22 }, { -72, -190, 40, 18 }, { 196, 74, 48, 22 }, { 200, -104, 50, 24 },
		{ -262, -168, 50, 26 }, { -430, -140, 52, 24 }, { -40, -420, 70, 30 }, { 62, -432, 56, 26 }, { 262, -332, 60, 30 },
		{ 286, -176, 44, 22 }, { -252, -420, 60, 30 }, { -336, -470, 70, 34 }, { 300, -470, 60, 30 }, { -20, -560, 72, 32 },
		{ 230, -560, 70, 34 }, { -470, -330, 60, 30 }, { -300, 60, 56, 22 }, { 300, 120, 60, 26 }, { 160, 180, 50, 18 },
		{ -140, 230, 56, 20 }, { 40, 250, 64, 22 }, { 420, 40, 60, 28 }, { -420, 120, 64, 26 },
	}
	for _, h in explicit do
		tryHill(V(h[1], 0, h[2]), h[3], h[4])
	end
	-- a few more rolling hills in the outer ring (never near the hub, so the spawn view stays open)
	local placed = 0
	for _ = 1, 160 do
		if placed >= 30 then
			break
		end
		local p = V(rng:NextNumber(-520, 540), 0, rng:NextNumber(-640, 260))
		if flatDist(p, V(0, 0, 30)) > 190 then
			local foot = rng:NextNumber(28, 52)
			-- (pass 2) fewer, larger terrain decisions: the small rolling bumps keep their footprint but are not raised
			if tryHill(p, foot, foot * rng:NextNumber(0.32, 0.5), nil, foot < 42) then
				placed += 1
			end
		end
	end
	-- the map border: a ring of big hills so the world reads as a valley; (pass 2) broken by open saddles (low noise) so the
	-- edge reads as broad ridges with gaps, never one continuous wall
	local function border(x: number, z: number)
		local foot = rng:NextNumber(70, 105)
		local p = V(x + rng:NextNumber(-15, 15), 0, z + rng:NextNumber(-15, 15))
		local saddle = math.noise(x / 260, z / 260, 7.7) < -0.22
		tryHill(p, foot, foot * rng:NextNumber(0.4, 0.6), nil, saddle)
	end
	for x = -560, 580, 62 do
		border(x, -690)
		border(x, 300)
	end
	for z = -690, 300, 62 do
		border(-580, z)
		border(600, z)
	end
	secretHills()
end

-- HORIZON: the playable valley sits inside a wider landscape so no view ends at a terrain edge or a bare sky band. A flat
-- grass apron continues past the map on every side and a broken ring of hazy mountains closes the horizon. All of it
-- stays outside MAP_MIN..MAP_MAX, so nothing here touches the locked layout.
-- a triangular ridge of terrain on the ground at `base`, running along `axis`: L long, H high, D deep (reads as a peak/ridge,
-- not a dome, and costs far fewer cells than a ball)
local function prism(base: Vector3, axis: Vector3, L: number, H: number, D: number, mat: Enum.Material)
	local n = V(-axis.Z, 0, axis.X)
	for _, sd in { -1, 1 } do
		local pos = base + V(0, H / 2, 0) + n * sd * D / 4
		Terrain:FillWedge(CFrame.lookAt(pos, pos + n * sd), V(L, H, D / 2), mat)
	end
end

-- a pyramid-like peak: two crossing gable ridges (four faces meeting at a summit point instead of a flat ridge line)
local function peakAt(base: Vector3, yaw: number, W: number, H: number, mat: Enum.Material)
	local t = V(math.cos(yaw), 0, math.sin(yaw))
	prism(base, t, W * 0.55, H, W, mat)
	prism(base, V(-t.Z, 0, t.X), W * 0.55, H, W, mat)
end

-- one background mountain: a high summit with lower, uneven peaks on its shoulders (broad peak + saddles, asymmetric)
local function mountain(p: Vector3, a: number, sc: number, mat: Enum.Material, r: Random)
	local t = V(-math.sin(a), 0, math.cos(a))
	local H = r:NextNumber(170, 240) * sc
	local W = 300 * sc
	local yaw = r:NextNumber(0, math.pi)
	peakAt(p, yaw, W, H, mat)
	for _, sd in { -1, 1 } do
		local k = r:NextNumber(0.45, 0.8)
		peakAt(p + t * sd * W * r:NextNumber(0.55, 0.8), yaw + r:NextNumber(-0.5, 0.5), W * (0.6 + k * 0.3), H * k, mat)
	end
end

-- horizon character by direction (from the hub): north tall and rocky, east rocky, south low and green, west a forested ridge
local function horizonLook(a: number): (number, Enum.Material)
	local x, z = math.cos(a), math.sin(a)
	if z < -0.6 then
		return 1.15, M.Slate
	elseif z > 0.6 then
		return 0.55, M.LeafyGrass
	elseif x < -0.6 then
		return 0.8, M.Grass
	end
	return 1, M.Rock
end

local function distantLands()
	local OUT_MIN, OUT_MAX = V(-1240, 0, -1320), V(1240, 0, 960)
	local function apron(x0: number, x1: number, z0: number, z1: number)
		-- filled to y = -2, which renders flush with the map's ground at y = 0
		local STEP = 512
		for x = x0, x1 - 1, STEP do
			for z = z0, z1 - 1, STEP do
				local sx, sz = math.min(STEP, x1 - x), math.min(STEP, z1 - z)
				Terrain:FillBlock(CFrame.new(x + sx / 2, -13, z + sz / 2), V(sx, 22, sz), M.LeafyGrass)
			end
		end
	end
	apron(OUT_MIN.X, OUT_MAX.X, OUT_MIN.Z, MAP_MIN.Z)
	apron(OUT_MIN.X, OUT_MAX.X, MAP_MAX.Z, OUT_MAX.Z)
	apron(OUT_MIN.X, MAP_MIN.X, MAP_MIN.Z, MAP_MAX.Z)
	apron(MAP_MAX.X, OUT_MAX.X, MAP_MIN.Z, MAP_MAX.Z)
	-- its own random stream, so the hills, zones and trees of the locked layout keep their exact positions
	local hr = Random.new(4242)
	local c = V(0, 0, -180)
	local n = 26
	for i = 0, n - 1 do
		local a = (i + hr:NextNumber(-0.25, 0.25)) / n * math.pi * 2
		local p = c + V(math.cos(a) * 1080, 0, math.sin(a) * 1000)
		local r = hr:NextNumber(125, 165)
		-- faceted ridges with uneven heights (broad peaks, saddles, asymmetric shoulders) instead of round domes
		local hs, hm = horizonLook(a)
		mountain(V(p.X, -16, p.Z), a, r / 150 * hr:NextNumber(0.8, 1.2) * hs, hm, hr)
		-- a lower grassy shoulder in front, so each mountain rises out of the plain instead of standing on it
		local inward = (c - p).Unit
		local q = p + inward * r * 0.75 + V(-inward.Z, 0, inward.X) * hr:NextNumber(-60, 60)
		Terrain:FillBall(V(q.X, -r * 0.55, q.Z), r * 0.8, M.LeafyGrass)
	end
end

-- ponds and the creek are carved out of the ground and filled with water (surface 1 stud below the ground)
local function water()
	for _, pond in PONDS do
		local c, r = pond.P, pond.R
		Terrain:FillCylinder(CFrame.new(c.X, -2, c.Z), 12, r, M.Air)
		Terrain:FillCylinder(CFrame.new(c.X, -5.5, c.Z), 5, r - 0.5, M.Water)
	end
	local pts = splinePoints(CREEK, 3)
	for _, p in pts do
		Terrain:FillCylinder(CFrame.new(p.X, -3, p.Z), 14, 5.5, M.Air)
	end
	for _, p in pts do
		Terrain:FillCylinder(CFrame.new(p.X, -6.5, p.Z), 7, 5, M.Water)
	end
end

------------------------------------------------------------------- roads (props on top of the painted terrain roads)
local function roads()
	local paths = world:FindFirstChild("Paths") or folder(world, "Paths")
	-- dashed centre line on the main roads (thin, non-colliding)
	-- (pass 2) chunkier, sparser dashes on top of the raised road body; none on the plaza or the bridge
	for _, road in ROADS do
		if road.Dashes then
			local s = road.Samples
			for i = 3, #s - 2, 6 do
				local a, b = s[i], s[i + 1]
				local mid = (a + b) / 2
				if mid.Magnitude > 62 and flatDist(mid, V(-170, 0, -40)) > 14 then
					local y = ROAD_TOP + 0.04
					P(paths, { Name = "Dash", Size = V(0.9, 0.08, 6), CFrame = CFrame.lookAt(mid + V(0, y, 0), b + V(0, y, 0)), Color = Color3.fromRGB(236, 196, 84), Material = M.SmoothPlastic, CanCollide = false, CanQuery = false, CanTouch = false })
				end
			end
		end
	end
	-- the Timber Road crosses the creek: a flush wooden deck over the water with rails on both sides
	local cross = V(-170, 0, -40)
	local best, bi = math.huge, 1
	local timber = ROADS[1].Samples
	for i, p in timber do
		local d = flatDist(p, cross)
		if d < best then
			best, bi = d, i
		end
	end
	local a, b = timber[math.max(1, bi - 1)], timber[math.min(#timber, bi + 1)]
	local cf = CFrame.lookAt(timber[bi], timber[bi] + (b - a).Unit)
	local wood = Color3.fromRGB(150, 100, 60)
	B(paths, "BridgeDeck", V(ROADS[1].Width + 2, 1.6, 18), cf * CFrame.new(0, -0.82, 0), Color3.fromRGB(128, 86, 54), M.WoodPlanks)
	for _, sx in { -1, 1 } do
		local x = sx * (ROADS[1].Width / 2 + 2)
		B(paths, "BridgeRail", V(0.9, 0.9, 24), cf * CFrame.new(x, 2.8, 0), wood, M.WoodPlanks)
		B(paths, "BridgeRail", V(0.7, 0.7, 24), cf * CFrame.new(x, 1.5, 0), wood, M.WoodPlanks)
		for zz = -11, 11, 5.5 do
			B(paths, "BridgePost", V(1.2, 3.6, 1.2), cf * CFrame.new(x, 1.6, zz), tint(wood, -0.15), M.Wood)
		end
	end
	-- (pass 2 lamp decision) no roadside lamps: the valley is a daylight world and reads clearly without them. The only lamps are
	-- the pair framing the hub's spawn side (buildHub), one design.
end

------------------------------------------------------------------- decor trees
local function decorTree(parent: Instance, pos: Vector3, kind: string, s: number)
	local m = model(parent, "Tree")
	if kind == "pine" then
		local g = Color3.fromRGB(50, 128, 72):Lerp(Color3.fromRGB(74, 160, 84), rng:NextNumber())
		post(m, pos, 1.5 * s, 5 * s, Color3.fromRGB(112, 76, 48), M.Wood, "Trunk")
		for i, t in { { 8.6, 4.2 }, { 6.6, 7.2 }, { 4.6, 10 }, { 2.4, 12.4 } } do
			post(m, pos + V(0, t[2] * s, 0), t[1] * s, 3 * s, tint(g, (i - 1) * 0.05), M.SmoothPlastic, "Tier").CanCollide = false
		end
	else
		local g = Color3.fromRGB(96, 192, 78):Lerp(Color3.fromRGB(128, 210, 90), rng:NextNumber())
		local h = 6 * s
		post(m, pos, 1.7 * s, h, Color3.fromRGB(126, 86, 54), M.Wood, "Trunk")
		ball(m, pos + V(0, h + 3 * s, 0), 9.5 * s, g, M.SmoothPlastic, "Leaves").CanCollide = false
		ball(m, pos + V(2.4 * s, h + 1.2 * s, 1 * s), 6 * s, tint(g, -0.07), M.SmoothPlastic, "Leaves").CanCollide = false
	end
end

local function forest(center: Vector3, rMin: number, rMax: number, count: number, kind: string, sMin: number, sMax: number, spacing: number)
	local placed = {}
	local tries = 0
	while #placed < count and tries < count * 30 do
		tries += 1
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(rMin, rMax)
		local p = V(center.X + math.cos(a) * r, 0, center.Z + math.sin(a) * r)
		local s = rng:NextNumber(sMin, sMax)
		if clearOf(p, 3 * s, 2) then
			local ok = true
			for _, q in placed do
				if flatDist(p, q) < spacing * s then
					ok = false
					break
				end
			end
			if ok then
				table.insert(placed, p)
				decorTree(decorF, V(p.X, groundAt(p.X, p.Z), p.Z), if kind == "mixed" then (if rng:NextNumber() < 0.5 then "pine" else "round") else kind, s)
			end
		end
	end
end

------------------------------------------------------------------- resource destinations
-- Every tier is its own destination with its own landmark, and each tier is visibly grander than the one before:
--   Wood   Stick Grove (young trees)        -> Logging Camp (sawmill cabin, log piles)   -> Redwood Forest (giant redwoods)
--   Stone  Rock Field (rubble)              -> Quarry (rock-walled bowl, derrick crane) -> Mountain Excavation (canyon, excavator)
--   Metal  Scrap Yard (magnet crane)        -> Foundry (hall + smokestacks, furnace)    -> Heavy Steel Mine (cliff portal, gantry)
--   Power  Battery Depot (racks, transformer)-> Power Plant (cooling towers, steam)       -> Energy Reactor (plateau, glowing core)
-- Gather nodes are always short parts at ground level (prompts sit on them); tall scenery is never the node itself.

local function zone(spot, mat: Enum.Material, radius: number, auraColor: Color3): (Model, Folder, Vector3)
	curSpotId = spot.Id
	curResId = spot.Resource
	local c = spot.Position
	local zonesF = world:FindFirstChild("Zones") or folder(world, "Zones")
	local z = model(zonesF, spot.Id)
	z:SetAttribute("SpotId", spot.Id)
	local _ = { mat, radius } -- the floor is painted up front (paintGround)
	gatherPoint(z, c)
	aura(z, c + V(0, 3, 0), auraColor, 4)
	return z, folder(z, "Nodes"), c
end

local function facing(at: Vector3, c: Vector3): CFrame
	return CFrame.lookAt(at, V(c.X, at.Y, c.Z))
end

-- a soft ground glow under every Tier 1 node so a new player spots them instantly (no outline, no text)
local function glowSpot(parent: Instance, p: Vector3, color: Color3, d: number)
	-- a soft shimmering pad under every Tier 1 node (ForceField material animates gently on the client) with a faint rim
	local function disc(name: string, dia: number, y: number, tr: number)
		P(parent, { Name = name, Shape = Enum.PartType.Cylinder, Size = V(0.12, dia, dia), CFrame = CFrame.new(p + V(0, y, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = tint(color, 0.2), Material = M.ForceField, Transparency = tr, CanCollide = false, CanQuery = false, CanTouch = false })
	end
	disc("NodeGlow", d, 0.08, 0.1)
	disc("NodeGlowRim", d + 1.6, 0.06, 0.55)
end

------------------------------------------------------------------- WOOD
-- STICKS: a tied bundle of sticks lying on the ground (the young trees around it are scenery)
local function stickBundle(nodes: Instance, p: Vector3, yaw: number)
	local b = model(nodes, "StickBundle")
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	local wood = Color3.fromRGB(186, 134, 80)
	local node
	for i, o in { V(0, 0.55, -0.85), V(0.3, 0.55, 0), V(-0.25, 0.55, 0.85), V(0.2, 1.3, -0.45), V(-0.3, 1.3, 0.45), V(0.1, 2.0, 0) } do
		local stick = P(b, { Name = "Stick", Shape = Enum.PartType.Cylinder, Size = V(7.4, 1.15, 1.15), CFrame = cf * CFrame.new(o * 1.2), Color = tint(wood, (i % 3 - 1) * 0.07), Material = M.Wood })
		if i == 2 then
			node = stick
		end
	end
	for _, x in { -1.7, 1.7 } do
		P(b, { Name = "Band", Shape = Enum.PartType.Cylinder, Size = V(0.5, 3.5, 3.5), CFrame = cf * CFrame.new(x * 1.2, 1.4, 0), Color = Color3.fromRGB(232, 196, 112), Material = M.Fabric, CanCollide = false })
	end
	tag(node, "Wood")
end

local function buildStickGrove(spot)
	local z, nodes, c = zone(spot, M.LeafyGrass, ZONE_R[1], Color3.fromRGB(170, 240, 120))
	local lm = spots(c, 1, 4, 14, 0, 5)[1] or c
	-- chopping stump with an axe stuck in it
	post(z, lm, 6, 2.8, Color3.fromRGB(140, 96, 58), M.Wood, "Stump")
	post(z, lm + V(0, 2.8, 0), 5.2, 0.15, Color3.fromRGB(230, 196, 146), M.Wood, "Rings")
	local acf = CFrame.new(lm + V(0.4, 2.9, 0)) * CFrame.Angles(0, 0, math.rad(-22))
	B(z, "AxeHandle", V(0.5, 5, 0.5), acf * CFrame.new(0, 2.5, 0), Color3.fromRGB(190, 132, 78), M.Wood)
	B(z, "AxeHead", V(0.4, 1.6, 2.4), acf * CFrame.new(0, 0.4, 0), Color3.fromRGB(214, 220, 228), M.Metal)
	local avoid = { { lm, 5 } }
	for _, p in spots(c, math.floor(8 * spot.NodeDensity), 6, 26, 8, 3.5, avoid) do
		glowSpot(nodes, p, Color3.fromRGB(150, 220, 100), 8.5)
		stickBundle(nodes, p, rng:NextNumber(0, math.pi))
		table.insert(avoid, { p, 4 })
	end
	-- fallen branches and small stumps (scenery: an approachable, picked-over grove)
	for i, p in spots(c, 6, 6, 26, 6, 2, avoid) do
		if i % 2 == 0 then
			post(z, p, 2.8, 1.4, Color3.fromRGB(150, 104, 62), M.Wood, "SmallStump")
			post(z, p + V(0, 1.4, 0), 2.3, 0.1, Color3.fromRGB(226, 190, 138), M.Wood, "StumpRings")
		else
			local yaw = rng:NextNumber(0, math.pi)
			P(z, { Name = "FallenBranch", Shape = Enum.PartType.Cylinder, Size = V(6.5, 0.8, 0.8), CFrame = CFrame.new(p + V(0, 0.4, 0)) * CFrame.Angles(0, yaw, 0.05), Color = Color3.fromRGB(140, 96, 58), Material = M.Wood, CanCollide = false })
			P(z, { Name = "Twig", Shape = Enum.PartType.Cylinder, Size = V(2.4, 0.4, 0.4), CFrame = CFrame.new(p + V(0, 0.6, 0)) * CFrame.Angles(0, yaw + 0.7, 0.3) * CFrame.new(1.2, 0, 0), Color = Color3.fromRGB(150, 104, 62), Material = M.Wood, CanCollide = false })
		end
		table.insert(avoid, { p, 2 })
	end
	-- young trees between the bundles (scenery only)
	for _, p in spots(c, 5, 8, 28, 9, 2.5, avoid) do
		local h = rng:NextNumber(7, 9.5)
		local tree = model(z, "YoungTree")
		post(tree, p, 1.8, h, Color3.fromRGB(150, 104, 62), M.Wood, "Trunk")
		local g = Color3.fromRGB(130, 216, 98):Lerp(Color3.fromRGB(100, 198, 86), rng:NextNumber())
		ball(tree, p + V(0, h + 2.2, 0), 8, g, M.SmoothPlastic, "Leaves").CanCollide = false
		ball(tree, p + V(1.8, h + 0.6, 0.8), 5, tint(g, -0.06), M.SmoothPlastic, "Leaves").CanCollide = false
	end
end

local function pineNode(nodes: Instance, p: Vector3, s: number)
	local t = model(nodes, "Pine")
	local base = post(t, p, 3 * s, 6, Color3.fromRGB(128, 84, 50), M.Wood, "Trunk")
	tag(base, "Wood")
	post(t, p + V(0, 6, 0), 2.4 * s, 10 * s, Color3.fromRGB(120, 80, 48), M.Wood, "UpperTrunk")
	local g = Color3.fromRGB(46, 120, 68)
	for i, tier in { { 12, 8 }, { 9.4, 11.5 }, { 6.6, 15 }, { 3.4, 18.2 } } do
		post(t, p + V(0, tier[2] * s, 0), tier[1] * s, 3.6 * s, tint(g, (i - 1) * 0.05), M.SmoothPlastic, "Tier").CanCollide = false
	end
end

local function buildLoggingCamp(spot)
	local z, nodes, c = zone(spot, M.Ground, ZONE_R[2], Color3.fromRGB(255, 200, 120))
	local lm = spots(c, 1, 18, 28, 0, 13)[1] or c
	local cf = facing(lm, c)
	-- sawmill cabin with a red gable roof, a stone chimney and a big saw bench beside it
	local wall = Color3.fromRGB(156, 102, 60)
	B(z, "Deck", V(20, 0.8, 15), cf * CFrame.new(0, 0.4, 0), Color3.fromRGB(116, 80, 50), M.WoodPlanks)
	B(z, "Cabin", V(15, 8, 10), cf * CFrame.new(0, 4.8, 1), wall, M.WoodPlanks)
	gableRoof(z, cf * CFrame.new(0, 8.8, 1), 17, 12, 30, Color3.fromRGB(198, 64, 52), wall)
	B(z, "Door", V(3, 5, 0.3), cf * CFrame.new(-3, 3.3, -4.1), Color3.fromRGB(96, 64, 40))
	B(z, "Window", V(3.4, 2.4, 0.3), cf * CFrame.new(3, 5, -4.1), Color3.fromRGB(255, 222, 150))
	B(z, "Chimney", V(2.4, 8, 2.4), cf * CFrame.new(5, 11, 3), Color3.fromRGB(150, 146, 140), M.Slate)
	B(z, "SawTable", V(4, 3, 12), cf * CFrame.new(-13, 1.5, -1), Color3.fromRGB(132, 92, 56), M.WoodPlanks)
	P(z, { Name = "SawBlade", Shape = Enum.PartType.Cylinder, Size = V(0.4, 9, 9), CFrame = cf * CFrame.new(-13, 5.4, -1), Color = Color3.fromRGB(218, 224, 234), Material = M.Metal, CanCollide = false })
	-- a big stacked log yard behind the cabin (scenery): reads "logging" from the road
	-- a tall log wall (scenery): pale cut ends facing the road read "logging" from far away
	for row = 0, 3 do
		for k = 0, 6 - row do
			local lcf = cf * CFrame.new(-8.7 + k * 2.9 + row * 1.45, 1.45 + row * 2.55, 13) * CFrame.Angles(0, math.rad(90), 0)
			P(z, { Name = "YardLog", Shape = Enum.PartType.Cylinder, Size = V(14, 2.8, 2.8), CFrame = lcf, Color = tint(Color3.fromRGB(150, 98, 54), ((k + row) % 2) * 0.06), Material = M.Wood })
			P(z, { Name = "YardLogEnd", Shape = Enum.PartType.Cylinder, Size = V(0.15, 2.5, 2.5), CFrame = lcf * CFrame.new(-7.05, 0, 0), Color = Color3.fromRGB(236, 200, 146), Material = M.Wood, CanCollide = false })
		end
	end
	-- timber A-frame crane hoisting a log over the yard
	local wood = Color3.fromRGB(120, 84, 52)
	for _, sz in { -4, 4 } do
		for _, sx in { -1, 1 } do
			local foot = (cf * CFrame.new(12 + sx * 3.4, 0, 8 + sz)).Position
			local top = (cf * CFrame.new(12, 17, 8 + sz)).Position
			B(z, "CraneLeg", V(1.2, 1.2, (top - foot).Magnitude), CFrame.lookAt((foot + top) / 2, top), wood, M.Wood)
		end
	end
	B(z, "CraneBeam", V(1.4, 1.4, 22), cf * CFrame.new(12, 17.4, 2), wood, M.Wood)
	B(z, "CraneRope", V(0.25, 6, 0.25), cf * CFrame.new(12, 14.2, -7), Color3.fromRGB(60, 50, 40), M.SmoothPlastic, false)
	P(z, { Name = "HoistLog", Shape = Enum.PartType.Cylinder, Size = V(10, 2.6, 2.6), CFrame = cf * CFrame.new(12, 10.4, -7), Color = Color3.fromRGB(150, 98, 54), Material = M.Wood, CanCollide = false })
	local avoid = { { lm, 17 } }
	-- felled log piles (the bottom log is the node) and a few tall pines
	for _, p in spots(c, math.floor(5 * spot.NodeDensity), 8, 38, 11, 5, avoid) do
		local pile = model(nodes, "LogPile")
		local base = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		local first
		for i, o in { V(-1.3, 1.25, 0), V(1.3, 1.25, 0), V(0, 3.3, 0) } do
			local lcf = base * CFrame.new(o) * CFrame.Angles(0, math.rad(90), 0)
			local log = P(pile, { Name = "Log", Shape = Enum.PartType.Cylinder, Size = V(9, 2.5, 2.5), CFrame = lcf, Color = tint(Color3.fromRGB(150, 98, 54), (i % 2) * 0.06), Material = M.Wood })
			-- pale cut ends with a darker heart so they read as logs from any angle
			for _, e in { -4.55, 4.55 } do
				P(pile, { Name = "LogEnd", Shape = Enum.PartType.Cylinder, Size = V(0.15, 2.2, 2.2), CFrame = lcf * CFrame.new(e, 0, 0), Color = Color3.fromRGB(236, 200, 146), Material = M.Wood, CanCollide = false })
				P(pile, { Name = "LogHeart", Shape = Enum.PartType.Cylinder, Size = V(0.2, 0.8, 0.8), CFrame = lcf * CFrame.new(e, 0, 0), Color = Color3.fromRGB(184, 128, 76), Material = M.Wood, CanCollide = false })
			end
			first = first or log
		end
		tag(first, "Wood")
		table.insert(avoid, { p, 6 })
	end
	for _, p in spots(c, 3, 12, 38, 12, 6, avoid) do
		pineNode(nodes, p, 1)
	end
	forest(c, 50, 82, 26, "pine", 1.1, 1.6, 6)
end

local function buildRedwoods(spot)
	local z, nodes, c = zone(spot, M.LeafyGrass, ZONE_R[3], Color3.fromRGB(255, 214, 120))
	aura(z, c + V(0, 16, 0), Color3.fromRGB(255, 222, 150), 10)
	-- a fallen giant (scenery) with its root plate
	local lm = spots(c, 1, 22, 42, 0, 24)[1] or c
	local yaw = rng:NextNumber(0, math.pi)
	local lcf = CFrame.new(lm + V(0, 4, 0)) * CFrame.Angles(0, yaw, 0)
	B(z, "FallenRedwood", V(54, 10, 10), lcf * CFrame.new(0, 1, 0), Color3.fromRGB(150, 74, 46), M.Wood).Shape = Enum.PartType.Cylinder
	B(z, "RootPlate", V(2.4, 19, 19), lcf * CFrame.new(27, 3, 0), Color3.fromRGB(120, 82, 52), M.Wood).Shape = Enum.PartType.Cylinder
	local avoid = { { lm, 25 } }
	local trees = spots(c, math.floor(5 * spot.NodeDensity), 10, 52, 27, 6, avoid)
	for _, p in trees do
		local h = rng:NextNumber(70, 92) * 1.3 -- true giants: the tallest things in the valley after the builds
		local t = model(z, "Redwood")
		local bark = Color3.fromRGB(158, 74, 46)
		post(t, p, 14, 10, tint(bark, -0.08), M.Wood, "Trunk")
		post(t, p + V(0, 10, 0), 11, h - 10, bark, M.Wood, "UpperTrunk")
		table.insert(avoid, { p, 9 })
		for i = 0, 4 do
			local a = i * math.pi * 2 / 5 + 0.4
			local rp = p + V(math.cos(a) * 7.4, 2, math.sin(a) * 7.4)
			B(t, "Root", V(3.6, 4.4, 8), CFrame.lookAt(rp, p + V(0, 3.4, 0)), tint(bark, -0.12), M.Wood)
		end
		local g = Color3.fromRGB(46, 128, 66)
		ball(t, p + V(0, h + 4, 0), 34, g, M.SmoothPlastic, "Crown").CanCollide = false
		ball(t, p + V(10, h - 8, 5), 25, tint(g, 0.06), M.SmoothPlastic, "Crown").CanCollide = false
		ball(t, p + V(-9, h - 13, -6), 22, tint(g, -0.05), M.SmoothPlastic, "Crown").CanCollide = false
		ball(t, p + V(4, h * 0.62, -3), 16, tint(g, 0.1), M.SmoothPlastic, "Crown").CanCollide = false
	end
	-- TIMBER: heavy milled beams, strapped and branded, stacked at the feet of the giants (these are the nodes)
	for _, p in spots(c, #trees, 8, 52, 12, 6, avoid) do
		local st = model(nodes, "TimberStack")
		local cf = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		local wood = Color3.fromRGB(180, 98, 54)
		for _, sz in { -3.2, 3.2 } do
			B(st, "Sleeper", V(6.2, 0.6, 1.2), cf * CFrame.new(0, 0.3, sz), Color3.fromRGB(70, 60, 54), M.Wood)
		end
		local first
		for i = 0, 2 do
			local beam = chunk(st, cf * CFrame.new(-1.95 + i * 1.95, 1.5, 0), V(1.85, 1.8, 10), tint(wood, (i % 2) * 0.05), M.WoodPlanks, "Timber")
			first = first or beam
		end
		for i = 0, 1 do
			chunk(st, cf * CFrame.new(-0.98 + i * 1.95, 3.3, 0), V(1.85, 1.8, 10), tint(wood, 0.04 - i * 0.05), M.WoodPlanks, "Timber")
		end
		for _, sz in { -2.8, 2.8 } do
			B(st, "Strap", V(6.2, 4.3, 0.35), cf * CFrame.new(0, 2.3, sz), Color3.fromRGB(56, 60, 70), M.Metal, false)
		end
		B(st, "Brand", V(1.2, 0.9, 0.12), cf * CFrame.new(0, 1.5, -5.05), Color3.fromRGB(240, 196, 80), M.SmoothPlastic, false)
		tag(first, "Wood")
	end
	-- warm light filtering through the giants (dramatic but soft)
	local sun = P(z, { Name = "CanopyLight", Size = V(1, 1, 1), Position = c + V(0, 40, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local sl = Instance.new("PointLight")
	sl.Color = Color3.fromRGB(255, 214, 150)
	sl.Range = 60
	sl.Brightness = 0.6
	sl.Shadows = false
	sl.Parent = sun
	forest(c, 66, 108, 26, "round", 1.7, 2.4, 6)
	forest(c, 70, 110, 10, "pine", 1.6, 2.1, 6)
end

------------------------------------------------------------------- STONE
-- RUBBLE: one tilted broken slab with sharp chunks scattered around it
local function rubble(nodes: Instance, p: Vector3, s: number, color: Color3)
	local rock = model(nodes, "Rubble")
	local yaw = rng:NextNumber(0, 6)
	local main = chunk(rock, CFrame.new(p + V(0, s * 0.36, 0)) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), yaw, math.rad(rng:NextNumber(-12, 12))), V(s * 1.1, s * 0.72, s * 0.9), tint(color, rng:NextNumber(-0.05, 0.05)), M.Slate, "Rubble")
	for k = 1, 3 do
		local a = yaw + k * 2.1
		local cs = s * rng:NextNumber(0.3, 0.42)
		local q = p + V(math.cos(a) * s * 0.75, cs * 0.35, math.sin(a) * s * 0.75)
		chunk(rock, CFrame.new(q) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, 6), rng:NextNumber(-0.6, 0.6)), V(cs * 1.2, cs * 0.8, cs), tint(color, 0.08), M.Slate, "Chip").CanCollide = false
	end
	tag(main, "Stone")
end

local function buildRockField(spot)
	local z, nodes, c = zone(spot, M.Sand, ZONE_R[1], Color3.fromRGB(190, 220, 255))
	local res = ResourceConfig.Resources[spot.Resource]
	local lm = spots(c, 1, 4, 14, 0, 6)[1] or c
	local cf = facing(lm, c)
	-- a little pile of cut blocks with a pickaxe
	for i, o in { V(-2.2, 1.5, 0), V(2.2, 1.5, 0), V(0, 4.3, 0) } do
		chunk(z, cf * CFrame.new(o) * CFrame.Angles(0, math.rad(i * 9), 0), V(4, 2.8, 4), Color3.fromRGB(214, 198, 172), M.Brick, "CutBlock")
	end
	B(z, "PickHandle", V(0.5, 6, 0.5), cf * CFrame.new(5, 3, 0) * CFrame.Angles(0, 0, math.rad(-14)), Color3.fromRGB(176, 120, 66), M.Wood)
	B(z, "PickHead", V(0.6, 0.7, 4.4), cf * CFrame.new(5.7, 6, 0) * CFrame.Angles(0, 0, math.rad(-14)), Color3.fromRGB(214, 220, 228), M.Metal)
	for _, p in spots(c, math.floor(8 * spot.NodeDensity), 6, 26, 8, 3.5, { { lm, 7 } }) do
		glowSpot(nodes, p, Color3.fromRGB(200, 214, 236), 9)
		rubble(nodes, p, rng:NextNumber(4.8, 6), res.Color)
	end
end

local function buildQuarry(spot)
	local z, nodes, c = zone(spot, M.Sand, ZONE_R[2], Color3.fromRGB(255, 230, 170))
	local res = ResourceConfig.Resources[spot.Resource]
	local lm = spots(c, 1, 22, 32, 0, 9)[1] or c
	local cf = facing(lm, c)
	-- wooden derrick crane lifting a huge cut block
	local wood = Color3.fromRGB(176, 124, 72)
	B(z, "DerrickBase", V(7, 1.2, 7), cf * CFrame.new(0, 0.6, 0), Color3.fromRGB(110, 106, 118), M.Concrete)
	B(z, "Mast", V(1.6, 28, 1.6), cf * CFrame.new(0, 15, 0), wood, M.Wood)
	local boomRoot = cf * CFrame.new(0, 5, 0) * CFrame.Angles(math.rad(52), 0, 0)
	B(z, "Boom", V(1.3, 1.3, 26), boomRoot * CFrame.new(0, 0, -13), wood, M.Wood)
	local tip = (boomRoot * CFrame.new(0, 0, -26)).Position
	local mastTop = (cf * CFrame.new(0, 29, 0)).Position
	B(z, "GuyRope", V(0.25, 0.25, (tip - mastTop).Magnitude), CFrame.lookAt((tip + mastTop) / 2, tip), Color3.fromRGB(60, 50, 40), M.SmoothPlastic, false)
	local blockPos = V(tip.X, math.max(c.Y + 6, tip.Y - 12), tip.Z)
	B(z, "Rope", V(0.25, tip.Y - blockPos.Y - 3, 0.25), CFrame.new((tip + blockPos + V(0, 3, 0)) / 2), Color3.fromRGB(60, 50, 40), M.SmoothPlastic, false)
	chunk(z, CFrame.new(blockPos), V(6, 5, 6), Color3.fromRGB(222, 204, 176), M.Brick, "HangingBlock")
	-- STONE BLOCKS: clean, square-cut blocks in a neat little stack (two below, one on top)
	local placed = {}
	for _, p in spots(c, math.floor(6 * spot.NodeDensity), 8, 36, 10, 5, { { lm, 10 } }) do
		table.insert(placed, p)
		local rock = model(nodes, "BlockStack")
		local s = rng:NextNumber(3.8, 4.4)
		local base = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		local main = chunk(rock, base * CFrame.new(-s * 0.52, s * 0.45, 0), V(s, s * 0.9, s), res.Color, M.Concrete, "Block")
		chunk(rock, base * CFrame.new(s * 0.52, s * 0.45, 0), V(s, s * 0.9, s), tint(res.Color, -0.05), M.Concrete, "Block")
		chunk(rock, base * CFrame.new(0, s * 1.35, 0), V(s, s * 0.9, s), tint(res.Color, 0.07), M.Concrete, "Block")
		tag(main, "Stone")
	end
	-- a terraced, freshly cut rock face behind the derrick (scenery; skipped where it would cover a node)
	local face = Color3.fromRGB(214, 192, 158)
	for i, b in { { 0, 15, 22, 34 }, { 0, 10, 16, 30 }, { 0, 5.5, 11, 26 } } do
		local wcf = cf * CFrame.new(b[1], b[2] / 2, b[3])
		local clear = true
		for _, q in placed do
			if (V(q.X, 0, q.Z) - V(wcf.X, 0, wcf.Z)).Magnitude < b[4] / 2 + 4 then
				clear = false
			end
		end
		if clear then
			B(z, "CutFace", V(b[4], b[2], 5), wcf, tint(face, (i % 2) * 0.05), M.Sandstone)
			B(z, "CutLine", V(b[4] + 0.2, 0.4, 5.2), wcf * CFrame.new(0, b[2] / 2 - 2, 0), tint(face, -0.12), M.Sandstone, false)
		end
	end
end

local function excavator(parent: Instance, cf: CFrame)
	local Y, D = Color3.fromRGB(255, 196, 30), Color3.fromRGB(48, 50, 58)
	for _, sx in { -5.2, 5.2 } do
		B(parent, "Track", V(3.4, 3.6, 18), cf * CFrame.new(sx, 1.8, 0), D)
	end
	P(parent, { Name = "Turntable", Shape = Enum.PartType.Cylinder, Size = V(1.2, 10, 10), CFrame = cf * CFrame.new(0, 4.2, 0) * CFrame.Angles(0, 0, math.rad(90)), Color = D, Material = M.SmoothPlastic })
	B(parent, "Body", V(11, 6, 12), cf * CFrame.new(0, 7.8, 2), Y)
	B(parent, "Counterweight", V(11, 4, 3), cf * CFrame.new(0, 7, 9.4), D)
	B(parent, "Cab", V(5, 6, 5), cf * CFrame.new(-3, 13.8, -2), Y)
	P(parent, { Name = "CabGlass", Size = V(4.4, 3.2, 0.3), CFrame = cf * CFrame.new(-3, 14.4, -4.6), Color = Color3.fromRGB(150, 210, 245), Material = M.Glass, Transparency = 0.3 })
	local pivot = cf * CFrame.new(2.5, 9, -3) * CFrame.Angles(math.rad(38), 0, 0)
	B(parent, "Boom", V(2.6, 2.6, 22), pivot * CFrame.new(0, 0, -11), Y)
	local tip = (pivot * CFrame.new(0, 0, -22)).Position
	local bucketPos = (cf * CFrame.new(2.5, 2.6, -26)).Position
	B(parent, "Stick", V(2.2, 2.2, (tip - bucketPos).Magnitude), CFrame.lookAt((tip + bucketPos) / 2, tip), Y)
	B(parent, "Bucket", V(6, 4, 5), CFrame.new(bucketPos) * cf.Rotation, D)
end

local function buildMountain(spot)
	local z, nodes, c = zone(spot, M.Sand, ZONE_R[3], Color3.fromRGB(200, 220, 255))
	local res = ResourceConfig.Resources[spot.Resource]
	local lm = spots(c, 1, 24, 40, 0, 16)[1] or c
	excavator(z, facing(lm, c))
	for _, p in spots(c, math.floor(5 * spot.NodeDensity) + 1, 8, 48, 18, 7, { { lm, 18 } }) do
		local rock = model(nodes, "Boulder")
		local s = rng:NextNumber(9, 12)
		-- MASSIVE BOULDERS: three overlapping faceted blocks (never a sphere) plus broken chunks at the foot
		local col = tint(res.Color, rng:NextNumber(-0.05, 0.06))
		local yaw0 = rng:NextNumber(0, math.pi)
		local main = P(rock, { Name = "Boulder", Size = V(s * 1.05, s * 0.72, s * 0.9), CFrame = CFrame.new(p + V(0, s * 0.34, 0)) * CFrame.Angles(0.12, yaw0, -0.08), Color = col, Material = res.Material })
		P(rock, { Name = "BoulderFace", Size = V(s * 0.8, s * 0.6, s * 0.75), CFrame = CFrame.new(p + V(s * 0.12, s * 0.62, -s * 0.05)) * CFrame.Angles(-0.25, yaw0 + 0.7, 0.3), Color = tint(col, 0.06), Material = res.Material })
		P(rock, { Name = "BoulderFace", Size = V(s * 0.7, s * 0.55, s * 0.6), CFrame = CFrame.new(p + V(-s * 0.25, s * 0.42, s * 0.2)) * CFrame.Angles(0.3, yaw0 - 0.5, 0.2), Color = tint(col, -0.05), Material = res.Material })
		for k = 1, 3 do
			local a = yaw0 + k * 2.2
			local cs = s * rng:NextNumber(0.18, 0.26)
			P(rock, { Name = "Chip", Size = V(cs * 1.3, cs, cs * 1.1), CFrame = CFrame.new(p + V(math.cos(a) * s * 0.75, cs * 0.4, math.sin(a) * s * 0.75)) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), a, rng:NextNumber(-0.5, 0.5)), Color = tint(col, 0.08), Material = res.Material, CanCollide = false })
		end
		-- BOULDERS are valuable: a few pale-teal crystal veins break through the surface
		local yaw = rng:NextNumber(0, 6)
		for k = 1, 3 do
			local a = yaw + k * 2.1
			local cp = p + V(math.cos(a) * s * 0.42, s * 0.5, math.sin(a) * s * 0.42)
			B(rock, "Crystal", V(1.5, 4.4, 1.5), CFrame.new(cp) * CFrame.Angles(math.sin(a) * 0.7, a, -math.cos(a) * 0.7), Color3.fromRGB(130, 224, 232), M.SmoothPlastic, false)
		end
		tag(main, "Stone")
	end
end

------------------------------------------------------------------- METAL
-- SCRAP: a low heap of mixed metal pieces: a rusty barrel, a gear, a pipe and a bent coloured panel
local function scrapPile(nodes: Instance, p: Vector3, color: Color3)
	-- SCRAP: a heap of mixed junk metal (no single block): crushed sheet plates, a bent girder, short pipes, a small gear, an old
	-- machine housing and one painted panel, all grey-steel with a little rust so it reads METAL from across the yard
	local pile = model(nodes, "ScrapPile")
	local cf = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6), 0)
	local grey, dark, rust = Color3.fromRGB(150, 156, 168), Color3.fromRGB(96, 102, 116), Color3.fromRGB(176, 104, 62)
	local core = P(pile, { Name = "CrushedPlates", Size = V(5.4, 1.2, 4.4), CFrame = cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, 0.04), Color = dark, Material = M.Metal })
	P(pile, { Name = "Plate", Size = V(4.6, 0.35, 3.6), CFrame = cf * CFrame.new(0.3, 1.45, 0.2) * CFrame.Angles(0.12, 0.3, -0.18), Color = grey, Material = M.Metal, CanCollide = false })
	P(pile, { Name = "Plate", Size = V(3.8, 0.35, 2.8), CFrame = cf * CFrame.new(-0.6, 1.95, -0.3) * CFrame.Angles(-0.2, -0.5, 0.22), Color = tint(grey, 0.08), Material = M.Metal, CanCollide = false })
	-- bent girder: two beam halves meeting at an angle
	P(pile, { Name = "Girder", Size = V(0.6, 0.9, 3.6), CFrame = cf * CFrame.new(1.6, 2.3, -0.4) * CFrame.Angles(0.45, 0.2, 0), Color = rust, Material = M.CorrodedMetal, CanCollide = false })
	P(pile, { Name = "Girder", Size = V(0.6, 0.9, 2.8), CFrame = cf * CFrame.new(1.6, 2.6, 1.8) * CFrame.Angles(-0.35, 0.2, 0), Color = rust, Material = M.CorrodedMetal, CanCollide = false })
	-- short pipes
	P(pile, { Name = "Pipe", Shape = Enum.PartType.Cylinder, Size = V(3.6, 0.9, 0.9), CFrame = cf * CFrame.new(-1.5, 2.4, 1.2) * CFrame.Angles(0, 0.4, 0.25), Color = Color3.fromRGB(124, 132, 148), Material = M.Metal, CanCollide = false })
	P(pile, { Name = "Pipe", Shape = Enum.PartType.Cylinder, Size = V(2.4, 0.7, 0.7), CFrame = cf * CFrame.new(0.2, 2.6, -1.6) * CFrame.Angles(0, -0.8, -0.3), Color = Color3.fromRGB(110, 118, 132), Material = M.Metal, CanCollide = false })
	-- old machine housing with a small gear on its side
	P(pile, { Name = "Housing", Size = V(1.8, 1.4, 1.6), CFrame = cf * CFrame.new(-1.6, 2.7, -1.0) * CFrame.Angles(0.2, 0.6, 0.15), Color = Color3.fromRGB(86, 120, 98), Material = M.Metal, CanCollide = false })
	P(pile, { Name = "Gear", Shape = Enum.PartType.Cylinder, Size = V(0.4, 1.8, 1.8), CFrame = cf * CFrame.new(-0.6, 2.9, -1.0) * CFrame.Angles(0.2, 0.6, 0.15), Color = Color3.fromRGB(176, 182, 194), Material = M.Metal, CanCollide = false })
	B(pile, "Panel", V(2.4, 0.25, 1.6), cf * CFrame.new(0.9, 2.3, 1.0) * CFrame.Angles(0.5, 0.4, 0.3), Color3.fromRGB(70, 112, 184), M.SmoothPlastic, false)
	tag(core, "Metal")
end

local function buildScrapYard(spot)
	local z, nodes, c = zone(spot, M.Mud, ZONE_R[1], Color3.fromRGB(255, 180, 110))
	local res = ResourceConfig.Resources[spot.Resource]
	local lm = spots(c, 1, 6, 16, 0, 7)[1] or c
	local cf = facing(lm, c)
	-- magnet crane over a stack of crushed cars
	local yellow = Color3.fromRGB(255, 196, 40)
	B(z, "CraneBase", V(4, 1, 4), cf * CFrame.new(0, 0.5, 0), Color3.fromRGB(70, 74, 86))
	B(z, "CraneTower", V(1.8, 16, 1.8), cf * CFrame.new(0, 9, 0), yellow)
	B(z, "CraneArm", V(1.4, 1.4, 14), cf * CFrame.new(0, 16.4, -6), yellow)
	B(z, "Cable", V(0.25, 6, 0.25), cf * CFrame.new(0, 13, -12), Color3.fromRGB(40, 40, 46), M.SmoothPlastic, false)
	P(z, { Name = "Magnet", Shape = Enum.PartType.Cylinder, Size = V(1.4, 5, 5), CFrame = cf * CFrame.new(0, 9.4, -12) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(56, 58, 66), Material = M.Metal })
	for i, col in { Color3.fromRGB(214, 70, 64), Color3.fromRGB(70, 130, 214), Color3.fromRGB(90, 180, 90) } do
		B(z, "CrushedCar", V(6, 1.5, 3.6), cf * CFrame.new(0, i * 1.5 - 0.7, -12) * CFrame.Angles(0, math.rad(i * 8), 0), col)
	end
	for _, p in spots(c, math.floor(8 * spot.NodeDensity), 6, 26, 8, 3.5, { { lm, 9 } }) do
		glowSpot(nodes, p, Color3.fromRGB(255, 170, 110), 9)
		scrapPile(nodes, p, res.Color)
	end
end

local function buildFoundry(spot)
	local z, nodes, c = zone(spot, M.Concrete, ZONE_R[2], Color3.fromRGB(255, 170, 90))
	local res = ResourceConfig.Resources[spot.Resource]
	local lm = spots(c, 1, 20, 30, 0, 16)[1] or c
	local cf = facing(lm, c)
	-- brick foundry hall with two smokestacks and a glowing furnace mouth
	local brick = Color3.fromRGB(184, 78, 60)
	B(z, "Hall", V(28, 14, 16), cf * CFrame.new(0, 7, 3), brick, M.Brick)
	gableRoof(z, cf * CFrame.new(0, 14, 3), 30, 18, 22, Color3.fromRGB(70, 74, 86), brick)
	local mouth = B(z, "FurnaceMouth", V(7, 6, 0.6), cf * CFrame.new(-6, 3.4, -5.1), Color3.fromRGB(255, 136, 40))
	soft(mouth, Color3.fromRGB(255, 150, 60), 22, 1.6)
	B(z, "FurnaceHood", V(9, 1.2, 2.4), cf * CFrame.new(-6, 7, -5.6), Color3.fromRGB(70, 74, 86))
	B(z, "Door", V(6, 8, 0.6), cf * CFrame.new(7, 4.3, -5.1), Color3.fromRGB(70, 74, 86))
	-- clerestory windows glowing with furnace heat, and steel trusses on the front
	for k = -2, 2 do
		B(z, "HotWindow", V(3.6, 2, 0.3), cf * CFrame.new(k * 5, 11, -5.1), Color3.fromRGB(255, 150, 60), M.Neon, false)
	end
	for _, sx in { -13.4, 13.4 } do
		B(z, "Truss", V(1.2, 14, 1.2), cf * CFrame.new(sx, 7, -5.4), Color3.fromRGB(70, 74, 86), M.Metal)
	end
	-- molten metal: a short glowing pour channel from the furnace and a hanging ladle
	B(z, "PourChannel", V(2.2, 0.6, 7), cf * CFrame.new(-6, 0.35, -9), Color3.fromRGB(70, 74, 86), M.Metal)
	local melt = B(z, "Molten", V(1.4, 0.2, 6.8), cf * CFrame.new(-6, 0.7, -9), Color3.fromRGB(255, 150, 50), M.Neon, false)
	melt.Transparency = 0.15
	P(z, { Name = "Ladle", Shape = Enum.PartType.Cylinder, Size = V(2.6, 3.4, 3.4), CFrame = cf * CFrame.new(-6, 3.4, -13) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(56, 58, 66), Material = M.Metal })
	for i, sx in { -9, 9 } do
		local h = 40 + i * 6
		local stack = post(z, (cf * CFrame.new(sx, 0, 10)).Position, 5, h, brick, M.Brick, "Smokestack")
		post(z, (cf * CFrame.new(sx, h - 4, 10)).Position, 5.4, 1.4, C.White, M.SmoothPlastic, "StackBand")
		post(z, (cf * CFrame.new(sx, h - 7, 10)).Position, 5.4, 1.4, Color3.fromRGB(220, 60, 50), M.SmoothPlastic, "StackBand")
		smoke(z, stack.Position + V(0, h / 2 + 1, 0), Color3.fromRGB(170, 170, 176), 3, 4)
	end
	for _, p in spots(c, math.floor(5 * spot.NodeDensity), 8, 38, 10, 5, { { lm, 19 } }) do
		-- METAL BEAMS: real I-beams (web + two flanges) stacked on two dark sleepers
		local pile = model(nodes, "BeamStack")
		local base = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		for _, sz in { -3, 3 } do
			B(pile, "Sleeper", V(5.6, 0.6, 1.2), base * CFrame.new(0, 0.3, sz), Color3.fromRGB(64, 68, 80), M.Metal)
		end
		local first
		for q, o in { V(-1.6, 1.4, 0), V(0, 1.4, 0), V(1.6, 1.4, 0), V(-0.8, 3.0, 0), V(0.8, 3.0, 0) } do
			local bcf = base * CFrame.new(o)
			local web = B(pile, "BeamWeb", V(0.4, 1.1, 9), bcf, res.Color, M.Metal)
			B(pile, "BeamFlange", V(1.4, 0.25, 9), bcf * CFrame.new(0, 0.66, 0), tint(res.Color, 0.08), M.Metal)
			B(pile, "BeamFlange", V(1.4, 0.25, 9), bcf * CFrame.new(0, -0.66, 0), tint(res.Color, -0.06), M.Metal)
			if q == 2 then
				first = web
			end
		end
		tag(first, "Metal")
	end
end

local function buildSteelMine(spot)
	local z, nodes, c = zone(spot, M.Basalt, ZONE_R[3], Color3.fromRGB(255, 170, 90))
	local res = ResourceConfig.Resources[spot.Resource]
	-- the mine portal set into the cliff behind the yard (the cliff is terrain, see landforms)
	local portal = V(c.X, c.Y, -556)
	local pcf = CFrame.lookAt(portal, portal + V(0, 0, 1))
	local steel, orange = Color3.fromRGB(62, 66, 78), Color3.fromRGB(255, 126, 36)
	-- open the cliff face in front of the portal (the terrain had grown over the mouth) and give it a rocky apron, not lawn
	workspace.Terrain:FillBlock(pcf * CFrame.new(0, 18.5, 0), V(36, 32, 14), M.Air)
	local apron = Region3.new(V(portal.X - 26, -12, portal.Z - 4), V(portal.X + 26, 40, portal.Z + 40)):ExpandToGrid(4)
	for _, mat in { M.Grass, M.LeafyGrass } do
		workspace.Terrain:ReplaceMaterial(apron, 4, mat, M.Basalt)
	end
	-- a big portal scaled to the cliff: dark mouth, heavy steel frame, an orange header with hazard stripes, timber shoring
	B(z, "TunnelDark", V(38, 32, 2), pcf * CFrame.new(0, 16, 1.5), Color3.fromRGB(22, 20, 24))
	-- the far end of the tunnel, warmly lit (reads as depth, not a flat dark wall), and a pale concrete lip around the mouth
	B(z, "TunnelBack", V(16, 13, 0.3), pcf * CFrame.new(0, 7, 0.4), Color3.fromRGB(126, 86, 52), M.SmoothPlastic, false)
	B(z, "TunnelBackInner", V(9, 8, 0.3), pcf * CFrame.new(0, 5, 0.2), Color3.fromRGB(176, 124, 70), M.SmoothPlastic, false)
	for _, sx in { -1, 1 } do
		B(z, "PortalTrim", V(1.6, 33, 0.6), pcf * CFrame.new(sx * 18.4, 16.5, -0.2), Color3.fromRGB(206, 204, 196), M.Concrete, false)
	end
	B(z, "PortalTrim", V(38.4, 1.6, 0.6), pcf * CFrame.new(0, 32.4, -0.2), Color3.fromRGB(206, 204, 196), M.Concrete, false)
	for _, sx in { -21, 21 } do
		B(z, "PortalLeg", V(5, 38, 5), pcf * CFrame.new(sx, 19, -0.6), Color3.fromRGB(150, 156, 170), M.Metal)
		B(z, "PortalFoot", V(8, 2, 8), pcf * CFrame.new(sx, 1, -0.6), Color3.fromRGB(40, 42, 50), M.Metal)
		for _, y in { 8, 18, 28 } do
			B(z, "Shoring", V(1.2, 1.2, 4), pcf * CFrame.new(sx * 0.82, y, 0.2), Color3.fromRGB(120, 86, 56), M.Wood)
		end
	end
	B(z, "PortalBeam", V(48, 6, 5), pcf * CFrame.new(0, 40, -0.6), orange)
	-- warm work lights deep in the tunnel so the mouth reads as an opening, not a dark wall
	soft(B(z, "TunnelGlow", V(2, 2, 2), pcf * CFrame.new(0, 10, 6), Color3.fromRGB(255, 190, 110), M.Neon, false), Color3.fromRGB(255, 170, 90), 30, 1.4)
	for k = -4, 4 do
		B(z, "Hazard", V(2.6, 6.1, 0.2), pcf * CFrame.new(k * 5.2, 40, -3.2) * CFrame.Angles(0, 0, math.rad(35)), Color3.fromRGB(34, 34, 40), M.SmoothPlastic, false)
	end
	for _, sx in { -1.8, 1.8 } do
		B(z, "Rail", V(0.5, 0.35, 40), pcf * CFrame.new(sx * 1.4, 0.2, -18), Color3.fromRGB(160, 164, 178), M.Metal)
	end
	for _, sx in { -9, 9 } do
		local l = B(z, "PortalLamp", V(1.6, 1.6, 1.6), pcf * CFrame.new(sx * 1.6, 34, -3), Color3.fromRGB(255, 200, 120))
		soft(l, Color3.fromRGB(255, 180, 100), 20, 1.2)
	end
	-- gantry crane spanning the yard
	local gcf = CFrame.lookAt(c, c + V(1, 0, 0)) * CFrame.new(0, 0, 8)
	for _, sz in { -22, 22 } do
		for _, sx in { -3, 3 } do
			B(z, "GantryLeg", V(2, 26, 2), gcf * CFrame.new(sx, 13, sz), orange)
		end
		B(z, "GantryFoot", V(10, 1.6, 3), gcf * CFrame.new(0, 0.8, sz), steel)
	end
	B(z, "GantryBeam", V(8, 3, 48), gcf * CFrame.new(0, 27.5, 0), orange)
	B(z, "Trolley", V(5, 3, 5), gcf * CFrame.new(0, 24.5, 6), steel)
	B(z, "HoistCable", V(0.3, 10, 0.3), gcf * CFrame.new(0, 18, 6), Color3.fromRGB(40, 40, 46), M.SmoothPlastic, false)
	chunk(z, gcf * CFrame.new(0, 12, 6), V(4, 2, 7), tint(res.Color, 0.05), M.Metal, "HangingIngot")
	local avoid = { { (gcf * CFrame.new(0, 0, -22)).Position, 7 }, { (gcf * CFrame.new(0, 0, 22)).Position, 7 }, { portal, 16 } }
	for _, p in spots(c, math.floor(5 * spot.NodeDensity) + 1, 10, 50, 13, 6, avoid) do
		-- HEAVY STEEL: polished blue-steel ingots with a gold mill stamp, stacked three high on a dark pallet
		local pile = model(nodes, "Ingots")
		local base = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		B(pile, "Pallet", V(7.6, 0.5, 6.4), base * CFrame.new(0, 0.25, 0), Color3.fromRGB(46, 48, 58), M.Metal)
		local steel = Color3.fromRGB(104, 128, 168)
		local gold = Color3.fromRGB(236, 186, 70)
		local first
		for q, o in { V(-1.8, 1.5, 0), V(1.8, 1.5, 0), V(0, 3.5, 0) } do
			local ing = chunk(pile, base * CFrame.new(o), V(3.3, 2, 5.8), tint(steel, (q - 2) * 0.05), M.Metal, "Ingot")
			B(pile, "Stamp", V(1.6, 0.9, 0.12), base * CFrame.new(o + V(0, 0, -2.95)), gold, M.SmoothPlastic, false)
			first = first or ing
		end
		tag(first, "Metal")
	end
end

------------------------------------------------------------------- POWER
-- BATTERIES: three chunky classic batteries (dark body, coloured label band, copper tip) on a low rack
local function batteryRack(nodes: Instance, p: Vector3, label: Color3)
	local gen = model(nodes, "BatteryRack")
	local yaw = rng:NextNumber(0, math.pi)
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	local body = chunk(gen, cf * CFrame.new(0, 0.6, 0), V(5.6, 1.2, 3), Color3.fromRGB(70, 78, 98), M.Metal, "Rack")
	for k = -1, 1 do
		local bp = (cf * CFrame.new(k * 1.8, 1.2, 0)).Position
		post(gen, bp, 1.6, 3.2, Color3.fromRGB(44, 48, 58), M.SmoothPlastic, "BatteryBody").CanCollide = false
		post(gen, bp + V(0, 0.9, 0), 1.66, 1.2, label, M.SmoothPlastic, "BatteryLabel").CanCollide = false
		post(gen, bp + V(0, 3.2, 0), 0.6, 0.45, Color3.fromRGB(228, 160, 86), M.Metal, "BatteryTip").CanCollide = false
	end
	tag(body, "PowerCell")
end

-- POWER CELLS: tall glass cells with a bright core, held in a steel frame
local function cellRack(nodes: Instance, p: Vector3, cell: Color3)
	local gen = model(nodes, "CellRack")
	local yaw = rng:NextNumber(0, math.pi)
	local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
	local steel = Color3.fromRGB(70, 82, 110)
	local body = chunk(gen, cf * CFrame.new(0, 0.7, 0), V(5.8, 1.4, 3.2), steel, M.Metal, "Rack")
	B(gen, "FrameTop", V(5.8, 0.5, 3.2), cf * CFrame.new(0, 6, 0), steel, M.Metal, false)
	for _, sx in { -2.65, 2.65 } do
		B(gen, "FramePost", V(0.5, 4.4, 0.5), cf * CFrame.new(sx, 3.6, 0), steel, M.Metal, false)
	end
	for k = -1, 1 do
		local bp = (cf * CFrame.new(k * 1.7, 1.4, 0)).Position
		post(gen, bp, 1.5, 4.4, Color3.fromRGB(210, 244, 255), M.Glass, "CellGlass").Transparency = 0.5
		post(gen, bp + V(0, 0.4, 0), 0.75, 3.6, cell, M.SmoothPlastic, "CellCore").CanCollide = false
	end
	tag(body, "PowerCell")
end

local function buildBatteryDepot(spot)
	local z, nodes, c = zone(spot, M.Pavement, ZONE_R[1], Color3.fromRGB(120, 255, 150))
	local res = ResourceConfig.Resources[spot.Resource]
	local lm = spots(c, 1, 4, 14, 0, 6)[1] or c
	local cf = facing(lm, c)
	-- transformer box with insulators and a utility pole
	chunk(z, cf * CFrame.new(0, 2.6, 0), V(6, 5.2, 4), Color3.fromRGB(150, 160, 176), M.Metal, "Transformer")
	for _, sx in { -1.8, 0, 1.8 } do
		post(z, (cf * CFrame.new(sx, 5.2, 0)).Position, 0.7, 1.6, Color3.fromRGB(240, 240, 244), M.SmoothPlastic, "Insulator")
	end
	B(z, "Bolt", V(0.4, 2.2, 1), cf * CFrame.new(0, 2.8, -2.1) * CFrame.Angles(0, 0, math.rad(20)), Color3.fromRGB(255, 220, 60))
	post(z, (cf * CFrame.new(6, 0, 2)).Position, 1, 16, Color3.fromRGB(130, 96, 64), M.Wood, "Pole")
	B(z, "CrossArm", V(5, 0.6, 0.6), cf * CFrame.new(6, 14.6, 2), Color3.fromRGB(130, 96, 64), M.Wood)
	-- a compact generator with an exhaust and a fat cable to the transformer
	chunk(z, cf * CFrame.new(-7, 1.6, 1), V(5, 3.2, 3.4), Color3.fromRGB(90, 170, 100), M.Metal, "Generator")
	post(z, (cf * CFrame.new(-8.4, 3.2, 1.8)).Position, 0.6, 2, Color3.fromRGB(60, 62, 70), M.Metal, "Exhaust")
	local ca, cb = (cf * CFrame.new(-4.5, 0.35, 1)).Position, (cf * CFrame.new(-3, 0.35, 0)).Position
	B(z, "Cable", V(0.4, 0.4, (cb - ca).Magnitude + 0.4), CFrame.lookAt((ca + cb) / 2, cb), Color3.fromRGB(30, 30, 36), M.SmoothPlastic, false)
	for _, p in spots(c, math.floor(7 * spot.NodeDensity), 6, 26, 8, 3.5, { { lm, 8 } }) do
		glowSpot(nodes, p, Color3.fromRGB(130, 255, 160), 8.5)
		batteryRack(nodes, p, res.Color)
	end
end

local function coolingTower(parent: Instance, base: Vector3, s: number)
	local white = Color3.fromRGB(236, 238, 242)
	post(parent, base, 24 * s, 10 * s, white, M.Concrete, "Tower")
	post(parent, base + V(0, 10 * s, 0), 19 * s, 14 * s, tint(white, -0.03), M.Concrete, "Tower")
	post(parent, base + V(0, 24 * s, 0), 21 * s, 10 * s, white, M.Concrete, "Tower")
	post(parent, base + V(0, 31 * s, 0), 21.4 * s, 2 * s, Color3.fromRGB(220, 70, 60), M.SmoothPlastic, "TowerBand")
	smoke(parent, base + V(0, 35 * s, 0), Color3.fromRGB(240, 240, 246), 4, 7 * s)
end

local function buildPowerPlant(spot)
	local z, nodes, c = zone(spot, M.Pavement, ZONE_R[2], Color3.fromRGB(110, 230, 255))
	local res = ResourceConfig.Resources[spot.Resource]
	local lm = spots(c, 1, 24, 32, 0, 18)[1] or c
	local cf = facing(lm, c)
	coolingTower(z, (cf * CFrame.new(-9, 0, 6)).Position, 1)
	coolingTower(z, (cf * CFrame.new(13, 0, 10)).Position, 0.85)
	-- turbine hall with a cyan stripe
	B(z, "TurbineHall", V(16, 9, 10), cf * CFrame.new(2, 4.5, -10), Color3.fromRGB(196, 206, 222), M.Concrete)
	B(z, "HallStripe", V(16.2, 1.2, 10.2), cf * CFrame.new(2, 7.4, -10), res.Color)
	B(z, "HallRoof", V(17, 0.8, 11), cf * CFrame.new(2, 9.4, -10), Color3.fromRGB(70, 80, 100))
	-- one transmission pylon
	local pyl = (cf * CFrame.new(-26, 0, -12)).Position
	B(z, "Pylon", V(1.6, 30, 1.6), CFrame.new(pyl + V(0, 15, 0)), Color3.fromRGB(120, 128, 142), M.Metal)
	for k, w in { 12, 9 } do
		B(z, "PylonArm", V(w, 0.8, 0.8), cf.Rotation + pyl + V(0, 22 + k * 4, 0), Color3.fromRGB(120, 128, 142), M.Metal)
	end
	-- a second pylon carries the lines to the hall, and a transformer bank sits beside it
	local pyl2 = (cf * CFrame.new(-18, 0, 12)).Position
	B(z, "Pylon", V(1.6, 30, 1.6), CFrame.new(pyl2 + V(0, 15, 0)), Color3.fromRGB(120, 128, 142), M.Metal)
	for k, w in { 12, 9 } do
		B(z, "PylonArm", V(w, 0.8, 0.8), cf.Rotation + pyl2 + V(0, 22 + k * 4, 0), Color3.fromRGB(120, 128, 142), M.Metal)
	end
	for _, ox in { -5, 5 } do
		local a, b = (cf.Rotation + pyl + V(0, 26, 0)) * V(ox, -0.6, 0), (cf.Rotation + pyl2 + V(0, 26, 0)) * V(ox, -0.6, 0)
		B(z, "Line", V(0.25, 0.25, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), Color3.fromRGB(40, 42, 50), M.SmoothPlastic, false)
	end
	for k = -1, 1 do
		local tcf = cf * CFrame.new(-6 + k * 5, 0, -19)
		B(z, "TransformerBank", V(4, 5, 3.4), tcf * CFrame.new(0, 2.5, 0), Color3.fromRGB(150, 160, 176), M.Metal)
		B(z, "TransformerFins", V(4.2, 3, 0.4), tcf * CFrame.new(0, 2.5, -1.9), Color3.fromRGB(110, 118, 132), M.Metal, false)
		for _, ix in { -1.2, 1.2 } do
			post(z, (tcf * CFrame.new(ix, 5, 0)).Position, 0.6, 1.8, Color3.fromRGB(240, 240, 244), M.SmoothPlastic, "Insulator")
		end
	end
	for _, p in spots(c, math.floor(5 * spot.NodeDensity), 8, 38, 10, 5, { { lm, 24 }, { pyl, 4 } }) do
		cellRack(nodes, p, res.Color)
	end
end

local function buildReactor(spot)
	local z, nodes, c = zone(spot, M.Salt, ZONE_R[3], Color3.fromRGB(200, 140, 255))
	local res = ResourceConfig.Resources[spot.Resource]
	local lm = spots(c, 1, 18, 28, 0, 18)[1] or c
	-- the reactor: a white ring of pillars around a floating glowing core with two halo rings
	local white, teal = Color3.fromRGB(240, 242, 248), Color3.fromRGB(90, 230, 230)
	disc(z, lm, 32, lm.Y + 1.2, white, M.SmoothPlastic, "ReactorBase", 1.2)
	disc(z, lm, 24, lm.Y + 1.5, Color3.fromRGB(120, 90, 200), M.SmoothPlastic, "ReactorInlay", 0.4)
	for i = 0, 5 do
		local a = i / 6 * math.pi * 2
		local pp = lm + V(math.cos(a) * 13, 1.2, math.sin(a) * 13)
		post(z, pp, 2.6, 30, white, M.SmoothPlastic, "Pillar")
		ball(z, pp + V(0, 30.8, 0), 3.2, res.Color, M.SmoothPlastic, "PillarCap")
		-- a crown ring ties the pillars into one frame around the core
		local b2 = lm + V(math.cos(a + math.pi / 3) * 13, 1.2, math.sin(a + math.pi / 3) * 13)
		local from, to = pp + V(0, 28.6, 0), b2 + V(0, 28.6, 0)
		B(z, "CrownRing", V(1.6, 1.4, (to - from).Magnitude + 1.6), CFrame.lookAt((from + to) / 2, to), white, M.SmoothPlastic, false)
	end
	local core = ball(z, lm + V(0, 17, 0), 12, res.Color, M.SmoothPlastic, "Core")
	core.CanCollide = false
	soft(core, res.Color, 40, 1)
	aura(z, lm + V(0, 17, 0), res.Color, 10)
	for _, ring in { { 11, 11 }, { 23, 9 } } do
		for k = 0, 15 do
			local a = k / 16 * math.pi * 2
			local p = lm + V(math.cos(a) * ring[2], ring[1], math.sin(a) * ring[2])
			B(z, "Halo", V(1, 0.8, 2 * math.pi * ring[2] / 16 + 0.2), CFrame.lookAt(p, p + V(-math.sin(a), 0, math.cos(a))), teal, M.SmoothPlastic, false)
		end
	end
	-- four energy pylons feeding the core (white masts with a soft cyan cap and a thin conduit)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local pp = lm + V(math.cos(a) * 22, 0, math.sin(a) * 22)
		post(z, pp, 3.2, 1.2, Color3.fromRGB(70, 80, 100), M.Metal, "PylonFoot")
		post(z, pp + V(0, 1.2, 0), 1.6, 22, white, M.SmoothPlastic, "PylonMast")
		local cap = ball(z, pp + V(0, 24.4, 0), 3, teal, M.SmoothPlastic, "PylonCap")
		cap.CanCollide = false
		soft(cap, teal, 10, 0.5)
		local from, to = pp + V(0, 22, 0), lm + V(0, 17, 0)
		B(z, "Conduit", V(0.3, 0.3, (to - from).Magnitude), CFrame.lookAt((from + to) / 2, to), Color3.fromRGB(150, 236, 240), M.SmoothPlastic, false).Transparency = 0.35
	end
	-- energy core pods
	for _, p in spots(c, math.floor(5 * spot.NodeDensity) + 1, 10, 50, 14, 5, { { lm, 18 } }) do
		-- ENERGY CORES: a glowing orb floating in a halo above a white pod (the most impressive power node)
		local pod = model(nodes, "CorePod")
		local base = chunk(pod, CFrame.new(p + V(0, 1.2, 0)), V(4.6, 2.4, 4.6), white, M.SmoothPlastic, "PodBase")
		post(pod, p + V(0, 2.4, 0), 3.2, 0.3, tint(res.Color, -0.2), M.SmoothPlastic, "PodInlay").CanCollide = false
		local orb = ball(pod, p + V(0, 5, 0), 3.8, res.Color, M.SmoothPlastic, "PodCore")
		orb.CanCollide = false
		soft(orb, res.Color, 12, 0.7)
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			local hp = p + V(math.cos(a) * 2.8, 5, math.sin(a) * 2.8)
			B(pod, "PodHalo", V(0.35, 0.35, 2.3), CFrame.lookAt(hp, hp + V(-math.sin(a), 0, math.cos(a))), teal, M.SmoothPlastic, false)
		end
		for _, sx in { -1.9, 1.9 } do
			post(pod, p + V(sx, 2.4, 0), 0.5, 3.4, teal, M.SmoothPlastic, "PodFin").CanCollide = false
		end
		tag(base, "PowerCell")
	end
end

------------------------------------------------------------------- HIDDEN ENDGAME AREAS: contents
local function secretNode(part: BasePart, spot: any)
	tag(part, "Secret")
	part:SetAttribute("SecretId", spot.Secret)
end

-- STAR CRATER: dark rock bowl, a cluster of cool crystals at its heart, scattered meteor fragments with glowing seams and the
-- Star Metal ore (dark metal with crystal shards). Quiet, cool, slightly mysterious.
local function buildStarCrater(spot)
	local z, nodes, c = zone(spot, M.Basalt, 40, Color3.fromRGB(110, 170, 255))
	local res = ResourceConfig.Resources[spot.Resource]
	local saved = rng
	rng = Random.new(31337)
	local dark, cyan = Color3.fromRGB(44, 46, 60), Color3.fromRGB(120, 200, 255)
	-- crater rim: low dark boulders around the heart
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local p = c + V(math.cos(a) * 12.5, 0, math.sin(a) * 12.5)
		chunk(z, CFrame.new(p + V(0, 1.4, 0)) * CFrame.Angles(0, -a, math.rad(rng:NextNumber(-8, 8))), V(rng:NextNumber(4, 6), rng:NextNumber(2.6, 4), rng:NextNumber(3.5, 5)), dark, M.Basalt, "Rim")
	end
	-- the heart: leaning crystal spires and one soft light
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2 + 0.4
		local h = rng:NextNumber(7, 15)
		local base = c + V(math.cos(a) * 3.2, 0, math.sin(a) * 3.2)
		local lean = CFrame.Angles(math.cos(a) * 0.22, 0, -math.sin(a) * 0.22)
		P(z, { Name = "HeartCrystal", Size = V(2.2, h, 2.2), CFrame = CFrame.new(base + V(0, h / 2, 0)) * lean * CFrame.Angles(0, a, 0), Color = tint(cyan, i % 2 * 0.15), Material = M.Glass, Transparency = 0.2, CanCollide = false })
	end
	-- entrance framing: two tall leaning dark spires either side of the gap, with a faint crystal growing from each
	local gapA = math.atan2(-60 - c.Z, 0 - c.X)
	for _, side in { -1, 1 } do
		local a = gapA + side * 0.42
		local gp = c + V(math.cos(a) * 58, 0, math.sin(a) * 58)
		P(z, { Name = "GateSpire", Size = V(7, 30, 7), CFrame = CFrame.new(gp + V(0, 13, 0)) * CFrame.Angles(0, a, side * 0.18), Color = Color3.fromRGB(38, 40, 52), Material = M.Basalt })
		P(z, { Name = "GateCrystal", Size = V(1.4, 6, 1.4), CFrame = CFrame.new(gp + V(-math.cos(a) * 3.6, 14, -math.sin(a) * 3.6)) * CFrame.Angles(0.3, a, side * 0.4), Color = cyan, Material = M.Glass, Transparency = 0.2, CanCollide = false })
	end
	-- drifting star motes over the crater floor (one emitter for the whole area)
	local motes = P(z, { Name = "StarMotes", Size = V(60, 1, 60), Position = c + V(0, 6, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local me = Instance.new("ParticleEmitter")
	me.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	me.Color = ColorSequence.new(Color3.fromRGB(170, 210, 255), Color3.fromRGB(230, 220, 255))
	me.LightEmission = 0.6
	me.Rate = 6
	me.Lifetime = NumberRange.new(4, 7)
	me.Speed = NumberRange.new(0.3, 1)
	me.Acceleration = V(0, 0.6, 0)
	me.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	me.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	me.Shape = Enum.ParticleEmitterShape.Box
	me.Parent = motes
	local core = ball(z, c + V(0, 3.5, 0), 4.5, Color3.fromRGB(150, 215, 255), M.Neon, "HeartGlow")
	core.Transparency = 0.45
	core.CanCollide = false
	local l = Instance.new("PointLight")
	l.Color = cyan
	l.Range = 26
	l.Brightness = 0.8
	l.Shadows = false
	l.Parent = core
	-- meteor fragments: charred rock with a thin glowing seam
	for _, p in spots(c, 9, 16, 36, 7, 3) do
		local s = rng:NextNumber(3, 5.5)
		local cf = CFrame.new(p + V(0, s * 0.4, 0)) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), rng:NextNumber(0, math.pi), rng:NextNumber(-0.2, 0.2))
		chunk(z, cf, V(s, s * 0.8, s * 1.2), Color3.fromRGB(34, 34, 44), M.Slate, "Meteor")
		B(z, "Seam", V(0.3, s * 0.55, s * 0.7), cf * CFrame.new(s * 0.3, 0.1, 0), cyan, M.Neon, false).Transparency = 0.35
	end
	-- STAR METAL ORE: a dark metallic lump with three crystal shards; gentle cool glow on the ground
	for _, p in spots(c, math.floor(8 * spot.NodeDensity), 14, 34, 9, 4) do
		local ore = model(nodes, "StarMetalOre")
		local yaw = rng:NextNumber(0, math.pi * 2)
		local cf = CFrame.new(p) * CFrame.Angles(0, yaw, 0)
		local node = chunk(ore, cf * CFrame.new(0, 1.7, 0), V(4.4, 3.4, 4.2), res.Color, M.Metal, "Ore")
		secretNode(node, spot)
		for k = 1, 3 do
			P(ore, { Name = "Shard", Size = V(0.9, 3.2 + k * 0.6, 0.9), CFrame = cf * CFrame.new(math.cos(k * 2.1) * 1.6, 3 + k * 0.3, math.sin(k * 2.1) * 1.4) * CFrame.Angles(0.3 * k, k, 0.25), Color = cyan, Material = M.Glass, Transparency = 0.15, CanCollide = false })
		end
		P(ore, { Name = "OreGlow", Shape = Enum.PartType.Cylinder, Size = V(0.12, 9, 9), CFrame = CFrame.new(p + V(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(130, 190, 255), Material = M.ForceField, Transparency = 0.35, CanCollide = false, CanQuery = false, CanTouch = false })
		local pl = Instance.new("PointLight")
		pl.Color = cyan
		pl.Range = 9
		pl.Brightness = 0.6
		pl.Shadows = false
		pl.Parent = node
	end
	rng = saved
end

-- ANCIENT GROVE: huge old trees with flared roots and mossy rocks, warm golden motes in the canopy, aged log stacks as the ore.
local function ancientTree(parent: Instance, base: Vector3, s: number, inward: Vector3?, rootLen: number?)
	local trunk = Color3.fromRGB(128, 96, 64) -- aged bark: warm and readable, not a dark silhouette
	post(parent, base - V(0, 1, 0), 12 * s, 46 * s, trunk, M.Wood, "AncientTrunk")
	post(parent, base - V(0, 1, 0), 16 * s, 6 * s, tint(trunk, -0.06), M.Wood, "TrunkFlare")
	for i = 1, 7 do
		local a = i / 7 * math.pi * 2 + base.X
		local d = V(math.cos(a), 0, math.sin(a))
		-- huge buttress roots: a tall fin out of the trunk diving into the ground (none pointing into the grove's open middle)
		if inward and d:Dot(V(inward.X - base.X, 0, inward.Z - base.Z).Unit) > 0.2 then
			continue
		end
		local r0, r1 = base + d * 6 * s + V(0, 4 * s, 0), base + d * (rootLen or 17) * s + V(0, -1.5, 0)
		B(parent, "Root", V(3.4 * s, 4.2 * s, (r1 - r0).Magnitude), CFrame.lookAt((r0 + r1) / 2, r1), trunk, M.Wood)
	end
	local moss, leaf = Color3.fromRGB(88, 138, 68), Color3.fromRGB(62, 112, 62)
	ball(parent, base + V(0, 50 * s, 0), 32 * s, leaf, M.Grass, "Canopy").CanCollide = false
	ball(parent, base + V(9 * s, 44 * s, 4 * s), 22 * s, moss, M.Grass, "Canopy").CanCollide = false
	ball(parent, base + V(-8 * s, 46 * s, -5 * s), 24 * s, leaf, M.Grass, "Canopy").CanCollide = false
	-- a few warm motes hanging in the leaves (soft, translucent)
	for k = 1, 3 do
		local m = ball(parent, base + V(math.cos(k * 2.3) * 10 * s, (42 + k * 3) * s, math.sin(k * 2.3) * 10 * s), 2.2, Color3.fromRGB(255, 214, 130), M.Neon, "Mote")
		m.Transparency = 0.4
		m.CanCollide = false
	end
end

local function buildAncientGrove(spot)
	local z, nodes, c = zone(spot, M.Grass, 40, Color3.fromRGB(255, 214, 130))
	local res = ResourceConfig.Resources[spot.Resource]
	local saved = rng
	rng = Random.new(41414)
	local gold = Color3.fromRGB(255, 208, 120)
	-- a wide ring of giants against the walls (none in the entrance gap) around ONE elder tree: the middle stays open
	local gap = math.atan2(-60 - c.Z, 0 - c.X)
	for i = 0, 6 do
		local a = i / 7 * math.pi * 2 + 0.3
		local s = rng:NextNumber(0.9, 1.15)
		local d = math.abs((a - gap + math.pi) % (math.pi * 2) - math.pi)
		if d > 0.6 then
			ancientTree(z, c + V(math.cos(a) * 50, 0, math.sin(a) * 50), s, c)
		end
	end
	ancientTree(z, c + V(-6, 0, 4), 1.4, nil, 13) -- the elder tree at the heart, with a warm light in its crown
	local crown = ball(z, c + V(-6, 57, 4), 3, gold, M.Neon, "ElderGlow")
	crown.Transparency = 0.5
	crown.CanCollide = false
	local l = Instance.new("PointLight")
	l.Color = gold
	l.Range = 40
	l.Brightness = 0.9
	l.Shadows = false
	l.Parent = crown
	-- warm floating motes under the canopy (one emitter) and a moss carpet around the elder tree
	local motes = P(z, { Name = "GroveMotes", Size = V(60, 1, 60), Position = c + V(0, 8, 0), Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false })
	local me = Instance.new("ParticleEmitter")
	me.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	me.Color = ColorSequence.new(gold, Color3.fromRGB(190, 240, 140))
	me.LightEmission = 0.5
	me.Rate = 5
	me.Lifetime = NumberRange.new(4, 7)
	me.Speed = NumberRange.new(0.2, 0.8)
	me.Acceleration = V(0, 0.4, 0)
	me.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 0) })
	me.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	me.Shape = Enum.ParticleEmitterShape.Box
	me.Parent = motes
	P(z, { Name = "MossCarpet", Shape = Enum.PartType.Cylinder, Size = V(0.2, 44, 44), CFrame = CFrame.new(c + V(-6, 0.1, 4)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(96, 150, 72), Material = M.Grass, CanCollide = false, CanQuery = false })
	-- mossy rocks and a few glowing mushrooms between the roots
	for _, p in spots(c, 5, 22, 40, 8, 2.5) do
		local s = rng:NextNumber(2.5, 4.5)
		chunk(z, CFrame.new(p + V(0, s * 0.35, 0)) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), V(s, s * 0.7, s * 1.1), Color3.fromRGB(110, 110, 100), M.Slate, "MossRock")
		B(z, "Moss", V(s * 0.9, 0.5, s * 1.0), CFrame.new(p + V(0, s * 0.72, 0)), Color3.fromRGB(86, 140, 70), M.Grass, false)
	end
	for _, p in spots(c, 3, 20, 36, 8, 1.5) do
		post(z, p, 0.7, 2.2, Color3.fromRGB(236, 224, 196), M.SmoothPlastic, "MushStem").CanCollide = false
		local cap = ball(z, p + V(0, 2.4, 0), 2.6, Color3.fromRGB(255, 196, 110), M.SmoothPlastic, "MushCap")
		cap.CanCollide = false
	end
	-- ANCIENT TIMBER: a pyramid of aged logs bound with gold, a mossy top and a faint warm glow
	local groveNodes = {}
	for _, p in spots(c, math.floor(8 * spot.NodeDensity), 12, 32, 9, 4.5) do
		local stack = model(nodes, "AncientLogStack")
		local cf = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0)
		local node = column(stack, cf * CFrame.new(-1.2, 1.1, 0) * CFrame.Angles(0, 0, math.rad(90)), 2.2, 6.4, res.Color, M.Wood, "AgedLog")
		node.CFrame = cf * CFrame.new(-1.2, 1.1, 0) * CFrame.Angles(math.rad(90), 0, 0) * CFrame.Angles(0, 0, math.rad(90)) -- lying along Z
		column(stack, cf * CFrame.new(1.2, 1.1, 0), 2.2, 6.4, tint(res.Color, -0.15), M.Wood, "AgedLog").CFrame = cf * CFrame.new(1.2, 1.1, 0) * CFrame.Angles(math.rad(90), 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		column(stack, cf * CFrame.new(0, 3.0, 0), 2.2, 6.4, tint(res.Color, 0.08), M.Wood, "AgedLog").CFrame = cf * CFrame.new(0, 3.0, 0) * CFrame.Angles(math.rad(90), 0, 0) * CFrame.Angles(0, 0, math.rad(90))
		for _, zz in { -1.6, 1.6 } do
			B(stack, "GoldBand", V(5.2, 4.6, 0.35), cf * CFrame.new(0, 2.1, zz), Color3.fromRGB(236, 196, 84), M.Metal, false)
		end
		B(stack, "MossTop", V(3.2, 0.5, 5), cf * CFrame.new(0, 4.2, 0), Color3.fromRGB(96, 150, 72), M.Grass, false)
		secretNode(node, spot)
		table.insert(groveNodes, stack)
		P(stack, { Name = "LogGlow", Shape = Enum.PartType.Cylinder, Size = V(0.12, 9, 9), CFrame = CFrame.new(p + V(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color = gold, Material = M.ForceField, Transparency = 0.4, CanCollide = false, CanQuery = false, CanTouch = false })
	end
	-- breathing room: no root may cover or crowd an Ancient Timber stack
	for _, stack in groveNodes do
		local scf, ssize = stack:GetBoundingBox()
		for _, part in workspace:GetPartBoundsInBox(scf, ssize + V(1.5, 1, 1.5)) do
			if part.Name == "Root" and part:IsDescendantOf(z) then
				part:Destroy()
			end
		end
	end
	-- perimeter layers: smaller trees against the walls (never in the entrance gap)
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2 + rng:NextNumber(-0.12, 0.12)
		local d = math.abs((a - gap + math.pi) % (math.pi * 2) - math.pi)
		local r = rng:NextNumber(52, 60)
		local s = rng:NextNumber(1.2, 1.8)
		if d > 0.7 then
			local p = c + V(math.cos(a) * r, 0, math.sin(a) * r)
			decorTree(z, V(p.X, groundAt(p.X, p.Z), p.Z), "round", s)
		end
	end
	-- the perimeter trees take the grove's deep, aged greens (not the bright valley green)
	for _, t in z:GetChildren() do
		if t.Name == "Tree" then
			for _, lf in t:GetChildren() do
				if lf.Name == "Leaves" then
					lf.Color = Color3.fromRGB(62, 112, 62):Lerp(Color3.fromRGB(88, 138, 68), rng:NextNumber())
				end
			end
		end
	end
	rng = saved
end

local ZONE_BUILDERS = {
	Forest = buildStickGrove,
	LumberCamp = buildLoggingCamp,
	TimberStand = buildRedwoods,
	Quarry = buildRockField,
	DeepQuarry = buildQuarry,
	BoulderField = buildMountain,
	Mine = buildScrapYard,
	IndustrialYard = buildFoundry,
	SteelWorks = buildSteelMine,
	Energy = buildBatteryDepot,
	ReactorYard = buildPowerPlant,
	CoreVault = buildReactor,
	StarCrater = buildStarCrater,
	AncientGrove = buildAncientGrove,
}

------------------------------------------------------------------- training yard (west of the town square)
local function buildTrainingYard()
	local c = TRAIN_CENTER
	local areas = world:FindFirstChild("Areas") or folder(world, "Areas")
	local yard = model(areas, "TrainingYard")
	local STR, SPD, RACE = Color3.fromRGB(255, 140, 52), Color3.fromRGB(72, 166, 238), Color3.fromRGB(222, 74, 66)
	local STEEL = Color3.fromRGB(84, 94, 116)
	local RUBBER = Color3.fromRGB(48, 52, 62)
	local YELLOW = Color3.fromRGB(255, 204, 60)

	local function mat(center: Vector3, size: Vector3, color: Color3)
		P(yard, { Name = "ZoneMat", Size = size, Position = center + Vector3.new(0, 0.34, 0), Color = tint(color, 0.45), Material = Enum.Material.Concrete, CanCollide = false, CanQuery = false })
	end
	mat(c + Vector3.new(-36, 0, 3), Vector3.new(18, 0.1, 40), STR)
	mat(c + Vector3.new(10, 0, 44), Vector3.new(48, 0.1, 20), SPD)

	-- STRENGTH: two padded bench presses on rubber mats; the Barbell model is lifted by TrainingController
	for i = 0, 1 do
		local base = c + Vector3.new(-36, 0, -9 + i * 24)
		local bench = model(yard, "BenchPress")
		P(bench, { Name = "FloorMat", Size = Vector3.new(9, 0.16, 11.5), Position = base + Vector3.new(0, 0.46, 0.8), Color = RUBBER, CanCollide = false, CanQuery = false })
		chunk(bench, CFrame.new(base + Vector3.new(0, 0.35, 0)), Vector3.new(2.2, 0.7, 6.2), STEEL, Enum.Material.Metal, "Frame")
		for _, sz in { -2.6, 2.6 } do
			chunk(bench, CFrame.new(base + Vector3.new(0, 0.3, sz)), Vector3.new(3.4, 0.6, 0.9), STEEL, Enum.Material.Metal, "Foot")
		end
		local pad = P(bench, { Name = "Pad", Size = Vector3.new(3.2, 1.2, 7), Position = base + Vector3.new(0, 0.9, 0), Color = STR, Material = Enum.Material.SmoothPlastic })
		CollectionService:AddTag(pad, "TrainingBench")
		P(bench, { Name = "PadPiping", Size = Vector3.new(3.36, 0.22, 7.16), Position = base + Vector3.new(0, 0.42, 0), Color = Color3.fromRGB(250, 246, 240), CanCollide = false })
		for _, sx in { -2.6, 2.6 } do
			chunk(bench, CFrame.new(base + Vector3.new(sx, 2.8, 2.0)), Vector3.new(0.9, 4.8, 0.9), STEEL, Enum.Material.Metal, "Upright")
			P(bench, { Name = "Hook", Size = Vector3.new(1.3, 0.45, 1.2), Position = base + Vector3.new(sx * 0.9, 5.0, 2.0), Color = YELLOW })
		end
		local bar = model(bench, "Barbell")
		local barPart = P(bar, { Name = "Bar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(8.8, 0.45, 0.45), CFrame = CFrame.new(base + Vector3.new(0, 5.2, 2.0)), Color = Color3.fromRGB(214, 218, 226), Material = Enum.Material.Metal, CanCollide = false })
		for _, sx in { -1, 1 } do
			P(bar, { Name = "Plate", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.6, 3.8, 3.8), CFrame = CFrame.new(base + Vector3.new(sx * 3.1, 5.2, 2.0)), Color = Color3.fromRGB(40, 46, 62), Material = Enum.Material.SmoothPlastic, CanCollide = false })
			P(bar, { Name = "Plate", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.5, 2.8, 2.8), CFrame = CFrame.new(base + Vector3.new(sx * 3.65, 5.2, 2.0)), Color = STR, Material = Enum.Material.SmoothPlastic, CanCollide = false })
			P(bar, { Name = "Collar", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.35, 1, 1), CFrame = CFrame.new(base + Vector3.new(sx * 4.05, 5.2, 2.0)), Color = STEEL, Material = Enum.Material.Metal, CanCollide = false })
		end
		bar.PrimaryPart = barPart
	end

	-- crate + beam activities: wooden pallets you lift from, yellow-framed pallets you drop on
	local function frame(parent: Instance, pos: Vector3, size: Vector3)
		local y = size.Y + 0.32
		for _, sx in { -1, 1 } do
			P(parent, { Name = "DropLine", Size = Vector3.new(0.5, 0.08, size.Z + 1), Position = pos + Vector3.new(sx * (size.X / 2 + 0.25), y, 0), Color = YELLOW, CanCollide = false, CanQuery = false })
			P(parent, { Name = "DropLine", Size = Vector3.new(size.X + 1, 0.08, 0.5), Position = pos + Vector3.new(0, y, sx * (size.Z / 2 + 0.25)), Color = YELLOW, CanCollide = false, CanQuery = false })
		end
	end
	local function padMark(parent: Instance, name: string, pos: Vector3, size: Vector3, tagName: string, color: Color3, material: Enum.Material)
		local d = P(parent, { Name = name, Size = size, Position = pos + Vector3.new(0, size.Y / 2 + 0.3, 0), Color = color, Material = material })
		d:SetAttribute("Lane", 1)
		CollectionService:AddTag(d, tagName)
		return d
	end
	local WOOD = Color3.fromRGB(190, 142, 88)
	local crates = model(yard, "CrateLane")
	local cp = c + Vector3.new(-30, 0, -40)
	padMark(crates, "CrateStackBase", cp, Vector3.new(8, 0.6, 8), "CrateStack", WOOD, Enum.Material.WoodPlanks)
	for k, off in { Vector3.new(-1.8, 0, 0), Vector3.new(1.8, 0, 0), Vector3.new(0, 2.7, 0) } do
		nicecrate(crates, cp + off + Vector3.new(0, 0.9 + (if off.Y > 0 then 0.5 else 0), 0), Vector3.new(3.2, 2.6, 3.2), tint(STR, -0.05 * k), math.rad(k * 7))
	end
	local cdp = c + Vector3.new(10, 0, -40)
	padMark(crates, "CratePalletBase", cdp, Vector3.new(9, 0.6, 9), "CratePallet", WOOD, Enum.Material.WoodPlanks)
	frame(crates, cdp, Vector3.new(9, 0.6, 9))
	local beams = model(yard, "BeamLane")
	local bp = c + Vector3.new(-42, 0, -55)
	padMark(beams, "BeamStackBase", bp, Vector3.new(7, 0.6, 15), "BeamStack", STEEL, Enum.Material.Metal)
	for k = 0, 1 do
		local bcf = CFrame.new(bp + Vector3.new(-1.3 + k * 2.6, 1.6, 0))
		P(beams, { Name = "BeamWeb", Size = Vector3.new(0.4, 1.1, 12.4), CFrame = bcf, Color = YELLOW, Material = Enum.Material.Metal })
		for _, fy in { -0.66, 0.66 } do
			P(beams, { Name = "BeamFlange", Size = Vector3.new(1.5, 0.25, 12.4), CFrame = bcf * CFrame.new(0, fy, 0), Color = tint(YELLOW, -0.08), Material = Enum.Material.Metal })
		end
	end
	local bdp = c + Vector3.new(30, 0, -55)
	padMark(beams, "BeamPalletBase", bdp, Vector3.new(7, 0.6, 15), "BeamPallet", STEEL, Enum.Material.Metal)
	frame(beams, bdp, Vector3.new(7, 0.6, 15))

	-- SPEED: three treadmills (deck, belt with ridges that scroll while running, rails, angled console)
	for i = 0, 2 do
		local base = c + Vector3.new(-6 + i * 16, 0, 44)
		local tm = model(yard, "Treadmill")
		chunk(tm, CFrame.new(base + Vector3.new(0, 0.3, 0)), Vector3.new(6.6, 0.6, 13), RUBBER, Enum.Material.SmoothPlastic, "Deck")
		local belt = P(tm, { Name = "Belt", Size = Vector3.new(5, 0.8, 11), Position = base + Vector3.new(0, 0.7, 0), Color = Color3.fromRGB(46, 50, 62), Material = Enum.Material.SmoothPlastic })
		CollectionService:AddTag(belt, "TrainingTreadmill")
		belt:SetAttribute("Level", i + 1) -- treadmill level 1..3 (Master Builder rank gate, TrainingConfig.Treadmill.Tiers)
		for k = 0, 5 do
			P(tm, { Name = "Ridge", Size = Vector3.new(4.4, 0.1, 0.5), Position = base + Vector3.new(0, 1.15, -5 + k * 2), Color = Color3.fromRGB(92, 100, 118), CanCollide = false, CanQuery = false, CanTouch = false })
		end
		for _, sx in { -3.1, 3.1 } do
			chunk(tm, CFrame.new(base + Vector3.new(sx, 1.1, 0.4)), Vector3.new(1.1, 1.4, 12.2), SPD, Enum.Material.SmoothPlastic, "Side")
			P(tm, { Name = "ConsolePost", Size = Vector3.new(0.6, 4.4, 0.6), Position = base + Vector3.new(sx * 0.75, 3, -5.9), Color = STEEL, Material = Enum.Material.Metal })
		end
		local head = chunk(tm, CFrame.new(base + Vector3.new(0, 5.4, -6.1)) * CFrame.Angles(math.rad(-22), 0, 0), Vector3.new(5.4, 1.8, 1.1), SPD, Enum.Material.SmoothPlastic, "Console")
		P(tm, { Name = "Screen", Size = Vector3.new(4.2, 1.2, 0.12), CFrame = head.CFrame * CFrame.new(0, 0.05, 0.56), Color = Color3.fromRGB(140, 226, 255), CanCollide = false })
		P(tm, { Name = "Handle", Shape = Enum.PartType.Cylinder, Size = Vector3.new(5, 0.4, 0.4), CFrame = CFrame.new(base + Vector3.new(0, 4.4, -5.2)), Color = C.White, Material = Enum.Material.Metal, CanCollide = false })
	end

	-- RACE: one lap loop with white edge lines (gate order matters: gate 1 is the start/finish)
	local tc = c + Vector3.new(16, 0, 0)
	local hx, hz = 26, 20
	local A, B2, C2, D = tc + Vector3.new(-hx, 0, -hz), tc + Vector3.new(hx, 0, -hz), tc + Vector3.new(hx, 0, hz), tc + Vector3.new(-hx, 0, hz)
	local track = folder(yard, "Track")
	for _, leg in { { A, B2 }, { B2, C2 }, { C2, D }, { D, A } } do
		local mid = (leg[1] + leg[2]) / 2
		local len = (leg[2] - leg[1]).Magnitude
		local cf = CFrame.lookAt(Vector3.new(mid.X, 0.3, mid.Z), Vector3.new(leg[2].X, 0.3, leg[2].Z))
		P(track, { Name = "TrackStrip", Size = Vector3.new(10, 0.3, len + 10), CFrame = cf, Color = tint(RACE, 0.2), Material = Enum.Material.Concrete, CanQuery = false })
		for _, sx in { -4.6, 4.6 } do
			P(track, { Name = "TrackEdge", Size = Vector3.new(0.4, 0.06, len - 10), CFrame = cf * CFrame.new(sx, 0.17, 0), Color = Color3.fromRGB(250, 246, 240), CanCollide = false, CanQuery = false, CanTouch = false })
		end
	end
	local gateList = { { A, Vector3.new(0, 0, 1) }, { B2, Vector3.new(1, 0, 0) }, { C2, Vector3.new(0, 0, 1) }, { D, Vector3.new(1, 0, 0) } }
	for i, g in gateList do
		local pos, across = g[1], g[2]
		local gm = model(track, "Gate" .. i)
		for _, k in { -5.6, 5.6 } do
			local foot = pos + across * k
			column(gm, CFrame.new(foot + Vector3.new(0, 0.3, 0)), 2.6, 0.6, STEEL, Enum.Material.Metal, "PostBase")
			column(gm, CFrame.new(foot + Vector3.new(0, 5.3, 0)), 1.5, 10, Color3.fromRGB(236, 238, 244), Enum.Material.SmoothPlastic, "Post")
		end
		local bs = if across.X ~= 0 then Vector3.new(12.6, 2.6, 1.4) else Vector3.new(1.4, 2.6, 12.6)
		local banner = P(gm, { Name = "GateBanner", Size = bs, Position = pos + Vector3.new(0, 9.6, 0), Color = if i == 1 then C.White else RACE, Material = Enum.Material.SmoothPlastic })
		banner:SetAttribute("GateIndex", i)
		CollectionService:AddTag(banner, "TrainingGate")
		local trim = if across.X ~= 0 then Vector3.new(12.8, 0.4, 1.5) else Vector3.new(1.5, 0.4, 12.8)
		for _, ty in { -1.35, 1.35 } do
			P(gm, { Name = "BannerTrim", Size = trim, Position = pos + Vector3.new(0, 9.6 + ty, 0), Color = if i == 1 then Color3.fromRGB(40, 44, 54) else tint(RACE, -0.3), CanCollide = false })
		end
	end
end

local function setupLighting()
	-- warm sunset, tuned so pale surfaces (plaza, platform) are bright but never blown out
	Lighting.ClockTime = 16.7
	Lighting.GeographicLatitude = 30
	-- (art reset) clean warm daylight: warm sun, slightly cool natural shadows, restrained bloom
	Lighting.Brightness = 2.5
	Lighting.Ambient = Color3.fromRGB(112, 118, 128)
	Lighting.OutdoorAmbient = Color3.fromRGB(148, 154, 168)
	Lighting.ColorShift_Top = Color3.fromRGB(255, 216, 172)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.22
	Lighting.GlobalShadows = true
	local function ensure(class: string, name: string): Instance
		local e = Lighting:FindFirstChild(name)
		if not e then
			e = Instance.new(class)
			e.Name = name
			e.Parent = Lighting
		end
		return e
	end
	-- a cool, pale distance haze that matches the sky at the horizon: the far mountains (distantLands) fade into it and
	-- there is no pink or grey band where the terrain stops rendering
	local atm = ensure("Atmosphere", "Atmosphere") :: Atmosphere
	-- (presentation pass) a touch more aerial perspective so far destinations sit back in soft warm-blue haze, a gentle sun glare
	atm.Density = 0.26
	atm.Offset = 0.3
	atm.Color = Color3.fromRGB(204, 216, 232)
	atm.Decay = Color3.fromRGB(162, 182, 212)
	atm.Glare = 0.1
	atm.Haze = 0.9
	Lighting.ShadowSoftness = 0.35
	-- soft cumulus over the valley (Terrain clouds: one object, no parts); bright and inviting, never stormy
	local clouds = Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds")
	clouds.Cover = 0.52
	clouds.Density = 0.5
	clouds.Color = Color3.fromRGB(255, 251, 246)
	clouds.Parent = Terrain
	local cc = ensure("ColorCorrectionEffect", "MB_ColorCorrection") :: ColorCorrectionEffect
	cc.Saturation = 0.06
	cc.Contrast = 0.1
	cc.Brightness = 0
	cc.TintColor = Color3.fromRGB(255, 248, 240)
	local bloom = ensure("BloomEffect", "MB_Bloom") :: BloomEffect
	bloom.Intensity = 0.14
	bloom.Size = 20
	bloom.Threshold = 2.6
	local rays = ensure("SunRaysEffect", "MB_SunRays") :: SunRaysEffect
	rays.Intensity = 0.06
	rays.Spread = 0.6
	ensure("Sky", "Sky")
	-- duplicates from older Studio defaults: one bloom, one sun rays, no depth-of-field blur (it smeared the foreground)
	for _, name in { "Bloom", "SunRays", "DepthOfField" } do
		local e = Lighting:FindFirstChild(name)
		if e and e:IsA("PostEffect") then
			e.Enabled = false
		end
	end
end


------------------------------------------------------------------- build site
-- The giant build is the star: a raised platform in the middle of a warm, nearly flush plaza (low edges so vehicles roll
-- straight onto it). Nothing else stands in the hub.
local function buildSite()
	local site = folder(world, "BuildSite")
	-- warm, slightly muted plaza (never brighter than the build itself)
	disc(site, Vector3.zero, 119, 0.08, Color3.fromRGB(222, 138, 72), M.SmoothPlastic, "PlazaRim", 0.4)
	local ring = disc(site, Vector3.zero, 115, 0.12, Color3.fromRGB(218, 204, 178), M.Concrete, "DepositRing", 0.4)
	ring:SetAttribute("DepositZone", true)
	disc(site, Vector3.zero, 97, 0.16, Color3.fromRGB(204, 188, 160), M.Concrete, "PlazaInner", 0.3)
	-- the construction platform: dark steel skirt, amber trim, a mid-grey deck with an inset work surface
	disc(site, Vector3.zero, 84, 0.9, Color3.fromRGB(58, 62, 74), M.Metal, "PlatformSkirt", 1.2)
	disc(site, Vector3.zero, 81, 1.4, Color3.fromRGB(226, 168, 54), M.SmoothPlastic, "PlatformTrim", 0.8)
	disc(site, Vector3.zero, 78, 2, Color3.fromRGB(150, 154, 162), M.Concrete, "Platform", 2.4)
	disc(site, Vector3.zero, 70, 2.06, Color3.fromRGB(170, 172, 178), M.Concrete, "WorkDeck", 0.2)
	-- STAGE RING: 24 tiles around the deck edge; the client lights them up as stages complete (BuildFXController)
	local ringF = folder(site, "StageRing")
	for i = 1, 24 do
		local a = (i - 0.5) / 24 * math.pi * 2 - math.pi / 2
		local p = V(math.cos(a) * 37, 2.03, math.sin(a) * 37)
		local tile = P(ringF, { Name = "StageLight", Size = V(1.4, 0.14, 7.2), CFrame = CFrame.lookAt(p, p + V(-math.sin(a), 0, math.cos(a))), Color = Color3.fromRGB(64, 70, 84), Material = M.SmoothPlastic, CanCollide = false, CanQuery = false, CanTouch = false })
		tile:SetAttribute("Index", i)
	end
	-- four survey corner marks on the deck (restrained construction markings)
	for k = 0, 3 do
		local a = k * math.pi / 2 + math.pi / 4
		local p = V(math.cos(a) * 30, 2.12, math.sin(a) * 30)
		local cf = CFrame.lookAt(p, V(0, 2.12, 0))
		P(site, { Name = "SurveyMark", Size = V(4, 0.06, 0.5), CFrame = cf * CFrame.new(-1.75, 0, 0), Color = Color3.fromRGB(236, 236, 240), CanCollide = false, CanQuery = false })
		P(site, { Name = "SurveyMark", Size = V(0.5, 0.06, 4), CFrame = cf * CFrame.new(0, 0, 1.75), Color = Color3.fromRGB(236, 236, 240), CanCollide = false, CanQuery = false })
	end
	-- low rail + invisible barrier keeping players off the construction platform
	local barrierF = folder(site, "Barrier")
	local segs = 28
	for i = 0, segs - 1 do
		local a = (i + 0.5) / segs * math.pi * 2
		local r = 41.5
		local pos = V(math.cos(a) * r, 0, math.sin(a) * r)
		local cf = CFrame.lookAt(pos, Vector3.zero)
		local w = 2 * math.pi * r / segs + 0.4
		P(barrierF, { Name = "Rail", Size = V(w, 0.5, 0.5), CFrame = cf * CFrame.new(0, 2.4, 0), Color = Color3.fromRGB(228, 228, 232) })
		P(barrierF, { Name = "Post", Size = V(0.7, 2.5, 0.7), CFrame = cf * CFrame.new(w / 2, 1.25, 0), Color = Color3.fromRGB(226, 150, 70) })
		P(barrierF, { Name = "Wall", Size = V(w, 160, 1), CFrame = cf * CFrame.new(0, 80, 0), Transparency = 1, CanQuery = false })
	end
end

------------------------------------------------------------------- hub: town square, spawn and the four shops
-- A small simulator shop: low base, three walls, a wide open front under a lintel, a roof, ONE icon board over the opening
-- and a counter just inside that carries the ProximityPrompt. `front` = direction the open side faces.
local function shop(parentF: Instance, name: string, pos: Vector3, front: Vector3, w: number, d: number, h: number, wall: Color3, roofC: Color3, roofStyle: string, sign: string, panel: string, promptText: string): (Model, CFrame)
	local m = model(parentF, name)
	local cf = CFrame.lookAt(pos, pos + front)
	local y0 = 0.3
	local t = 1
	B(m, "Base", V(w + 3, 0.3, d + 3), cf * CFrame.new(0, 0.15, 0), tint(wall, -0.32))
	B(m, "WallBack", V(w, h, t), cf * CFrame.new(0, y0 + h / 2, d / 2 - t / 2), wall)
	for _, sx in { -1, 1 } do
		B(m, "WallSide", V(t, h, d), cf * CFrame.new(sx * (w / 2 - t / 2), y0 + h / 2, 0), wall)
		B(m, "FrontPier", V(w * 0.18, h, t + 0.2), cf * CFrame.new(sx * (w / 2 - w * 0.09), y0 + h / 2, -d / 2 + t / 2), tint(wall, -0.07))
	end
	B(m, "Lintel", V(w, h * 0.3, t + 0.2), cf * CFrame.new(0, y0 + h * 0.85, -d / 2 + t / 2), tint(wall, -0.07))
	-- a darker plinth and a cap along the walls, and one framed window in each side wall
	local plinth, cap = tint(wall, -0.28), tint(roofC, -0.12)
	B(m, "Plinth", V(w + 0.3, 0.9, t + 0.3), cf * CFrame.new(0, y0 + 0.45, d / 2 - t / 2), plinth)
	B(m, "WallCap", V(w + 0.3, 0.5, t + 0.3), cf * CFrame.new(0, y0 + h - 0.25, d / 2 - t / 2), cap)
	for _, sx in { -1, 1 } do
		B(m, "Plinth", V(t + 0.3, 0.9, d + 0.3), cf * CFrame.new(sx * (w / 2 - t / 2), y0 + 0.45, 0), plinth)
		B(m, "WallCap", V(t + 0.3, 0.5, d + 0.3), cf * CFrame.new(sx * (w / 2 - t / 2), y0 + h - 0.25, 0), cap)
		B(m, "WindowFrame", V(0.3, h * 0.36 + 0.6, d * 0.38 + 0.6), cf * CFrame.new(sx * (w / 2 + 0.02), y0 + h * 0.55, 0.6), Color3.fromRGB(246, 244, 240), M.SmoothPlastic, false)
		B(m, "Window", V(0.34, h * 0.36, d * 0.38), cf * CFrame.new(sx * (w / 2 + 0.04), y0 + h * 0.55, 0.6), Color3.fromRGB(150, 200, 230), M.SmoothPlastic, false)
	end
	B(m, "Floor", V(w - 2 * t, 0.1, d - t), cf * CFrame.new(0, y0 + 0.05, t / 2), tint(wall, 0.45), M.SmoothPlastic, false)
	local top = cf * CFrame.new(0, y0 + h, 0)
	if roofStyle == "gable" then
		gableRoof(m, top, w + 2, d + 2, 26, roofC, wall)
	else
		B(m, "RoofTrim", V(w + 2.4, 0.6, d + 2.4), top * CFrame.new(0, 0.3, 0), tint(roofC, -0.2))
		B(m, "Roof", V(w + 2, 0.8, d + 2), top * CFrame.new(0, 0.9, 0), roofC)
	end
	local counter = B(m, "Counter", V(w * 0.5, 3.2, 1.6), cf * CFrame.new(0, y0 + 1.6, -d / 2 + 3.4), tint(roofC, -0.1))
	B(m, "CounterTop", V(w * 0.5 + 0.4, 0.3, 2), cf * CFrame.new(0, y0 + 3.35, -d / 2 + 3.4), C.White)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = promptText
	prompt.ObjectText = string.gsub(sign, "^%S+%s+", "")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt:SetAttribute("OpensPanel", panel)
	prompt.Parent = counter
	local board = B(m, "Sign", V(math.min(w * 0.82, 13), 2.6, 0.4), cf * CFrame.new(0, y0 + h * 0.85, -d / 2 - 0.2), C.Navy)
	surfaceText(board, Enum.NormalId.Front, sign, C.White)
	return m, cf
end

local function buildHub()
	local hub = folder(world, "Hub")
	local areasF = world:FindFirstChild("Areas") or folder(world, "Areas")
	-- (pass 2) no giant square slab: the spawn stands on compacted ground (terrain, artReset2 hubGround) and ONE plated walkway
	-- runs straight from the spawn pad to the deposit ring, edged with dark-steel curb bands, nearly flush (vehicles roll over)
	B(hub, "Walkway", V(28, 0.24, 33), CFrame.new(0, 0, 76.5), Color3.fromRGB(150, 150, 154), M.DiamondPlate)
	for _, sx in { -1, 1 } do
		B(hub, "WalkwayCurb", V(1.4, 0.3, 33), CFrame.new(sx * 14.7, 0, 76.5), Color3.fromRGB(62, 68, 82), M.Metal)
	end
	disc(hub, SPAWN, 26, 0.2, Color3.fromRGB(226, 172, 60), M.SmoothPlastic, "SpawnRing", 0.3)
	disc(hub, SPAWN, 22, 0.22, Color3.fromRGB(230, 220, 200), M.SmoothPlastic, "SpawnPad", 0.3)
	local existing = workspace:FindFirstChildOfClass("SpawnLocation")
	local spawn = existing or Instance.new("SpawnLocation")
	spawn.Name = "SpawnLocation"
	spawn.Anchored = true
	spawn.Size = V(10, 1, 10)
	spawn.CFrame = CFrame.lookAt(SPAWN + V(0, -0.27, 0), V(0, -0.27, 0))
	spawn.Transparency = 1
	spawn.CanCollide = true
	spawn.Duration = 0
	spawn.Neutral = true
	for _, c in spawn:GetChildren() do
		if c:IsA("Decal") then
			c:Destroy()
		end
	end
	spawn.Parent = hub
	for _, x in { -33, 33 } do
		for _, zz in { 148 } do
			lamp(hub, V(x, 0, zz))
		end
	end

	-- (Pass 21O) the old Worker Post building and its apron are gone: crew and Workers are handled at the Builders Shop on the spawn deck
	-- (WorldBuilderSpawn21F); WorkerService idles Workers in front of that shop.
end

------------------------------------------------------------------- decor
local function decor()
	-- tree lines along the creek, around the hub's back and sides, and scattered groves in the open land
	for _, p in splinePoints(CREEK, 14) do
		forest(p, 12, 22, 2, "round", 1.1, 1.5, 6)
	end
	forest(V(0, 0, 200), 0, 80, 22, "round", 1.1, 1.6, 6)
	forest(V(-110, 0, 160), 0, 30, 6, "round", 1, 1.4, 6)
	forest(V(112, 0, 140), 0, 34, 7, "round", 1, 1.4, 6)
	forest(V(-280, 0, 120), 0, 60, 12, "mixed", 1.1, 1.6, 6)
	forest(V(160, 0, -110), 0, 50, 10, "mixed", 1.1, 1.6, 6)
	forest(V(-200, 0, -250), 0, 60, 12, "pine", 1.1, 1.6, 6)
	forest(V(20, 0, -230), 0, 60, 10, "round", 1.2, 1.7, 6)
	forest(V(250, 0, -250), 0, 70, 12, "mixed", 1.2, 1.8, 6)
	forest(V(0, 0, -470), 0, 90, 16, "pine", 1.3, 1.9, 6)
	forest(V(300, 0, 110), 0, 70, 12, "round", 1.2, 1.7, 6)
	forest(V(-420, 0, -50), 0, 70, 12, "pine", 1.2, 1.8, 6)
	-- the meadow where the Training Yard used to be
	forest(V(-205, 0, 104), 0, 42, 9, "mixed", 1.1, 1.6, 6)
end

------------------------------------------------------------------- ENVIRONMENT PASS (world quality)
-- Runs after every zone exists and before node clearings / roads. Everything here is terrain material, terrain shaping
-- off the roads, or a few grouped static props, and it uses its OWN random streams so the locked layout (spots, nodes,
-- trees, hills) generates exactly as before.
local GRASSY = { [M.LeafyGrass] = true, [M.Grass] = true }

-- edit the material of solid cells in a box; fn(x, y, z, mat) returns a new material or nil
local function terrainEdit(x0: number, z0: number, x1: number, z1: number, y0: number, y1: number, fn: (number, number, number, Enum.Material) -> Enum.Material?)
	local lo = V(math.floor(x0 / CELL) * CELL, math.floor(y0 / CELL) * CELL, math.floor(z0 / CELL) * CELL)
	local hi = V(math.ceil(x1 / CELL) * CELL, math.ceil(y1 / CELL) * CELL, math.ceil(z1 / CELL) * CELL)
	-- big areas go in tiles (ReadVoxels has a size cap)
	local TILE = 256
	for tx = lo.X, hi.X - 1, TILE do
		for tz = lo.Z, hi.Z - 1, TILE do
			local a = V(tx, lo.Y, tz)
			local b = V(math.min(tx + TILE, hi.X), hi.Y, math.min(tz + TILE, hi.Z))
			local region = Region3.new(a, b)
			local mats, occs = Terrain:ReadVoxels(region, CELL)
			local size = mats.Size
			local changed = false
			for ix = 1, size.X do
				local x = a.X + (ix - 0.5) * CELL
				for iy = 1, size.Y do
					local y = a.Y + (iy - 0.5) * CELL
					for iz = 1, size.Z do
						if occs[ix][iy][iz] > 0 then
							local z = a.Z + (iz - 0.5) * CELL
							local nm = fn(x, y, z, mats[ix][iy][iz])
							if nm and nm ~= mats[ix][iy][iz] then
								mats[ix][iy][iz] = nm
								changed = true
							end
						end
					end
				end
			end
			if changed then
				Terrain:WriteVoxels(region, CELL, mats, occs)
			end
		end
	end
end

-- weighted pick from a palette { {mat, weight}, ... } driven by a smooth noise value (patches ~`scale` studs across)
local function pickMat(palette: { any }, x: number, z: number, seed: number, scale: number?): Enum.Material
	local s = scale or 26
	local n = math.clamp(math.noise(x / s, z / s, seed) * 1.1 + 0.5, 0, 0.999)
	local total = 0
	for _, e in palette do
		total += e[2]
	end
	local acc = 0
	for _, e in palette do
		acc += e[2] / total
		if n < acc then
			return e[1]
		end
	end
	return palette[#palette][1]
end

-- an irregular, blended ground patch: `core` palette inside, `edge` palette in the outer band, ragged noisy rim, and only
-- cells whose material is in `over` (grass by default) are repainted, so roads, water and rock walls are never touched
local function groundMix(c: Vector3, radius: number, core: { any }, edge: { any }?, over: { [Enum.Material]: boolean }?, seed: number?, yTop: number?)
	local sd = seed or (c.X * 0.013 + c.Z * 0.007)
	local ov = over or GRASSY
	local R = radius * 1.35
	terrainEdit(c.X - R, c.Z - R, c.X + R, c.Z + R, -8, yTop or 40, function(x, _y, z, mat)
		if not ov[mat] then
			return nil
		end
		local d = math.sqrt((x - c.X) ^ 2 + (z - c.Z) ^ 2) / radius + math.noise(x / 26, z / 26, sd) * 0.5
		if d < 0.72 then
			return pickMat(core, x, z, sd + 3)
		elseif d < 1 and edge then
			return pickMat(edge, x, z, sd + 5, 16)
		end
		return nil
	end)
end

-- a ragged strip of ground along a segment (worn tracks, cable trenches, paths between roots)
local function groundLine(a: Vector3, b: Vector3, width: number, palette: { any }, over: { [Enum.Material]: boolean }?)
	local ov = over or GRASSY
	local dir = V(b.X - a.X, 0, b.Z - a.Z)
	local len = dir.Magnitude
	local u = dir / len
	terrainEdit(math.min(a.X, b.X) - width, math.min(a.Z, b.Z) - width, math.max(a.X, b.X) + width, math.max(a.Z, b.Z) + width, -8, 24, function(x, _y, z, mat)
		if not ov[mat] then
			return nil
		end
		local rel = V(x - a.X, 0, z - a.Z)
		local t = math.clamp(rel:Dot(u), 0, len)
		local d = (rel - u * t).Magnitude + math.noise(x / 9, z / 9, 2.2) * 2
		if d < width / 2 then
			return pickMat(palette, x, z, 9.1, 7)
		end
		return nil
	end)
end

local function union(...): { [Enum.Material]: boolean }
	local out = { [M.LeafyGrass] = true, [M.Grass] = true }
	for _, m in { ... } do
		out[m] = true
	end
	return out
end

-- ground identity per destination: radius (studs), core palette, edge palette, extra materials it may repaint
local ZONE_GROUND = {
	Forest = { 34, { { M.LeafyGrass, 0.55 }, { M.Ground, 0.25 }, { M.Grass, 0.2 } }, { { M.LeafyGrass, 0.7 }, { M.Ground, 0.3 } } },
	LumberCamp = { 58, { { M.Ground, 0.55 }, { M.Mud, 0.15 }, { M.Sandstone, 0.12 }, { M.LeafyGrass, 0.18 } }, { { M.LeafyGrass, 0.5 }, { M.Ground, 0.5 } }, { M.Ground } },
	TimberStand = { 78, { { M.Mud, 0.3 }, { M.Ground, 0.4 }, { M.Grass, 0.3 } }, { { M.Grass, 0.3 }, { M.LeafyGrass, 0.35 }, { M.Ground, 0.35 } } },
	Quarry = { 34, { { M.Sand, 0.35 }, { M.Rock, 0.25 }, { M.Cobblestone, 0.25 }, { M.LeafyGrass, 0.15 } }, { { M.LeafyGrass, 0.6 }, { M.Cobblestone, 0.2 }, { M.Sand, 0.2 } }, { M.Sand } },
	DeepQuarry = { 54, { { M.Sand, 0.4 }, { M.Sandstone, 0.3 }, { M.Rock, 0.2 }, { M.Cobblestone, 0.1 } }, { { M.Sand, 0.4 }, { M.LeafyGrass, 0.4 }, { M.Rock, 0.2 } }, { M.Sand } },
	BoulderField = { 70, { { M.Sand, 0.3 }, { M.Rock, 0.3 }, { M.Slate, 0.2 }, { M.Ground, 0.2 } }, { { M.Ground, 0.35 }, { M.Rock, 0.25 }, { M.LeafyGrass, 0.4 } }, { M.Sand } },
	Mine = { 36, { { M.Mud, 0.45 }, { M.Ground, 0.3 }, { M.Basalt, 0.25 } }, { { M.Ground, 0.5 }, { M.LeafyGrass, 0.5 } }, { M.Mud } },
	IndustrialYard = { 62, { { M.Basalt, 0.3 }, { M.Cobblestone, 0.3 }, { M.Mud, 0.25 }, { M.Concrete, 0.15 } }, { { M.Mud, 0.35 }, { M.LeafyGrass, 0.45 }, { M.Cobblestone, 0.2 } }, { M.Concrete } },
	SteelWorks = { 74, { { M.Basalt, 0.5 }, { M.Slate, 0.2 }, { M.Mud, 0.15 }, { M.Cobblestone, 0.15 } }, { { M.Mud, 0.35 }, { M.Slate, 0.15 }, { M.LeafyGrass, 0.5 } }, { M.Basalt } },
	Energy = { 34, { { M.Pavement, 0.5 }, { M.Concrete, 0.25 }, { M.Ground, 0.25 } }, { { M.LeafyGrass, 0.6 }, { M.Ground, 0.4 } }, { M.Pavement } },
	ReactorYard = { 58, { { M.Pavement, 0.4 }, { M.Concrete, 0.3 }, { M.Cobblestone, 0.3 } }, { { M.LeafyGrass, 0.5 }, { M.Cobblestone, 0.25 }, { M.Ground, 0.25 } }, { M.Pavement } },
	CoreVault = { 66, { { M.Salt, 0.55 }, { M.Pavement, 0.3 }, { M.Concrete, 0.15 } }, { { M.Slate, 0.3 }, { M.LeafyGrass, 0.5 }, { M.Pavement, 0.2 } }, { M.Salt } },
}

local function findPart(zoneId: string, name: string): BasePart?
	local z = world:FindFirstChild("Zones") and world.Zones:FindFirstChild(zoneId)
	return z and z:FindFirstChild(name, true) :: BasePart?
end

local function zoneGround()
	for _, spot in ResourceSpotConfig.List() do
		local g = ZONE_GROUND[spot.Id]
		if g then
			groundMix(spot.Position, g[1], g[2], g[3], union(table.unpack(g[4] or {})), spot.Position.X * 0.01 + 1.7)
		end
	end
	-- FOUNDRY: heat-darkened ground at the furnace and a faint warm glow where the pour channel runs out
	local mouth = findPart("IndustrialYard", "FurnaceMouth")
	if mouth then
		groundMix(mouth.Position, 12, { { M.Basalt, 0.7 }, { M.Slate, 0.3 } }, { { M.Basalt, 0.5 }, { M.Ground, 0.5 } }, union(M.Concrete, M.Cobblestone, M.Ground, M.Basalt), 4.4)
		local melt = findPart("IndustrialYard", "Molten")
		if melt then
			groundMix(melt.Position + melt.CFrame.LookVector * 0, 3.2, { { M.CrackedLava, 1 } }, nil, union(M.Concrete, M.Cobblestone, M.Ground, M.Basalt, M.Slate), 4.9)
		end
	end
	-- STEEL MINE: a worn haul track from the portal into the yard and darker rock at the cliff foot
	local tunnel = findPart("SteelWorks", "TunnelDark")
	if tunnel then
		local spot = V(-172, 0, -498)
		groundLine(V(tunnel.Position.X, 0, tunnel.Position.Z + 6), spot, 9, { { M.Mud, 0.55 }, { M.Ground, 0.45 } }, union(M.Basalt, M.Slate, M.Cobblestone))
		groundMix(V(tunnel.Position.X, 0, tunnel.Position.Z + 10), 30, { { M.Slate, 0.5 }, { M.Basalt, 0.5 } }, { { M.Basalt, 0.6 }, { M.Ground, 0.4 } }, union(M.Basalt, M.Ground, M.Cobblestone), 6.1)
	end
	-- POWER PLANT: a cable trench from the pylon pair to the turbine hall
	local pylons = {}
	local z = world.Zones:FindFirstChild("ReactorYard")
	if z then
		for _, d in z:GetChildren() do
			if d.Name == "Pylon" then
				table.insert(pylons, d.Position)
			end
		end
		local hall = z:FindFirstChild("TurbineHall")
		if #pylons >= 2 and hall then
			groundLine(pylons[1], pylons[2], 4, { { M.Cobblestone, 0.6 }, { M.Ground, 0.4 } }, union(M.Pavement, M.Concrete))
			groundLine(pylons[2], hall.Position, 4, { { M.Cobblestone, 0.6 }, { M.Ground, 0.4 } }, union(M.Pavement, M.Concrete))
		end
	end
end

-- faceted rock: an oriented block of terrain (reads as a stepped ledge instead of a smooth blob)
-- A ROCK MASS instead of one flat block: a main slab, a second plate leaning off it at another angle, a small embedded
-- chunk and an angled cap, with a related secondary material on one plate. Deterministic (noise from position), no rng.
local ROCK_ALT = { [M.Rock] = M.Slate, [M.Slate] = M.Rock, [M.Basalt] = M.Slate, [M.Sandstone] = M.Rock, [M.LeafyGrass] = M.Rock }
local function rockMass(cf: CFrame, size: Vector3, mat: Enum.Material)
	local p = cf.Position
	local n1 = math.noise(p.X / 13.7, p.Z / 13.7, 1.1)
	local n2 = math.noise(p.X / 9.3, p.Z / 9.3, 2.7)
	local alt = ROCK_ALT[mat] or mat
	-- main mass, slightly shorter, with a twist
	Terrain:FillBlock(cf * CFrame.Angles(n1 * 0.18, n2 * 0.3, n2 * 0.12), size * V(0.82, 0.86, 0.8), mat)
	-- a leaning plate on one side (different angle = a broken face, not a box)
	local side = if n1 > 0 then 1 else -1
	Terrain:FillBlock(cf * CFrame.new(side * size.X * 0.32, -size.Y * 0.12, size.Z * 0.12) * CFrame.Angles(0.2 + n2 * 0.2, side * 0.5, side * 0.22), size * V(0.55, 0.7, 0.6), alt)
	-- a small embedded chunk at the foot of the other side
	Terrain:FillBlock(cf * CFrame.new(-side * size.X * 0.36, -size.Y * 0.3, -size.Z * 0.1) * CFrame.Angles(n1 * 0.6, 0.9, n2 * 0.5), size * V(0.36, 0.38, 0.42), mat)
	-- an angled cap so the top is not a flat table
	local top = cf * CFrame.new(n2 * size.X * 0.15, size.Y * 0.36, 0)
	Terrain:FillWedge(top * CFrame.Angles(0, if n1 > 0 then 0 else math.pi, 0), size * V(0.7, 0.32, 0.6), mat)
end

-- rock outcrops on the edges of the stone and metal destinations: the biome starts before its floor does
local function outcrops()
	local orng = Random.new(5151)
	local list = { Quarry = M.Rock, DeepQuarry = M.Rock, BoulderField = M.Slate, Mine = M.Basalt, IndustrialYard = M.Slate, SteelWorks = M.Basalt, CoreVault = M.Slate }
	for _, spot in ResourceSpotConfig.List() do
		local mat = list[spot.Id]
		if mat then
			-- (pass 2) two large faceted rock masses per destination instead of four small round lumps
			local placed = 0
			for _ = 1, 40 do
				if placed >= 2 then
					break
				end
				local a = orng:NextNumber(0, math.pi * 2)
				local r = ZONE_R[spot.Tier] + orng:NextNumber(14, 26)
				local p = spot.Position + V(math.cos(a) * r, 0, math.sin(a) * r)
				local s = orng:NextNumber(9, 13)
				if clearOf(p, s + 2, 3) then
					rockMass(CFrame.new(p + V(0, s * 0.25, 0)) * CFrame.Angles(0, a, orng:NextNumber(-0.15, 0.15)), V(s * 1.6, s * 1.1, s * 1.2), mat)
					placed += 1
				end
			end
		end
	end
end

-- STAR CRATER and ANCIENT GROVE grounds, and the scorched land outside the crater
local function secretGround()
	for _, spot in secretSpots() do
		local c = spot.Position
		if spot.Id == "StarCrater" then
			-- scorched land fading out around the walls, then an alien floor inside: dark rock, slate scars, pale-blue crystal ground
			groundMix(c, 104, { { M.Basalt, 0.5 }, { M.Ground, 0.25 }, { M.Mud, 0.25 } }, { { M.Ground, 0.4 }, { M.Mud, 0.2 }, { M.LeafyGrass, 0.4 } }, nil, 8.8, 80)
			groundMix(c, 44, { { M.Basalt, 0.55 }, { M.Slate, 0.45 } }, { { M.Basalt, 0.7 }, { M.Slate, 0.3 } }, union(M.Basalt, M.Slate, M.Ground, M.Mud), 8.1, 6)
			groundMix(c, 11, { { M.Glacier, 0.6 }, { M.Slate, 0.4 } }, nil, union(M.Basalt, M.Slate), 8.3, 6)
		else
			groundMix(c, 46, { { M.Grass, 0.4 }, { M.Mud, 0.25 }, { M.Ground, 0.15 }, { M.LeafyGrass, 0.2 } }, { { M.Grass, 0.5 }, { M.LeafyGrass, 0.5 } }, union(M.Mud), 7.7, 6)
			-- a worn path in through the gap, between the roots, to the elder tree
			local gap = math.atan2(-60 - c.Z, 0 - c.X)
			local gd = V(math.cos(gap), 0, math.sin(gap))
			groundLine(c + gd * 80, c + gd * 30, 7, { { M.Ground, 0.6 }, { M.Mud, 0.4 } })
			groundLine(c + gd * 30, c + V(-6, 0, 4) + gd * 12, 6, { { M.Ground, 0.5 }, { M.Mud, 0.5 } }, union(M.Mud))
		end
	end
end

local function slab(p: Vector3, size: Vector3, yaw: number, tilt: number, mat: Enum.Material)
	rockMass(CFrame.new(p) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(tilt, 0, tilt * 0.5), size, mat)
end

-- cliffs: stepped ledges and slope breaks on the steel-mine cliff, crags on the excavation mountain, broken spires on the crater rim
local function cliffs()
	local crng = Random.new(6262)
	-- Steel Mine cliff face (z ~ -560): ledges at different heights either side of the portal
	for x = -262, -84, 22 do
		if math.abs(x + 172) > 30 then
			local h = crng:NextNumber(20, 46)
			slab(V(x + crng:NextNumber(-5, 5), h * 0.5 - 4, -555 - crng:NextNumber(0, 4)), V(crng:NextNumber(20, 28), h, 12), crng:NextNumber(-0.25, 0.25), crng:NextNumber(-0.12, 0.08), M.Basalt)
			slab(V(x + crng:NextNumber(-6, 6), 52 + crng:NextNumber(0, 8), -576), V(crng:NextNumber(18, 26), 12, 16), crng:NextNumber(-0.4, 0.4), 0.1, M.Basalt)
		end
	end
	-- portal shoulders: two heavy buttresses that frame the mouth
	for _, sx in { -1, 1 } do
		slab(V(-172 + sx * 34, 20, -554), V(16, 44, 14), sx * 0.18, 0, M.Basalt)
	end
	-- Excavation mountain: crags along the ridge (the canyon itself is untouched)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		local p = V(452 + math.cos(a) * crng:NextNumber(60, 100), 0, -326 + math.sin(a) * crng:NextNumber(60, 100))
		if flatDist(p, V(394, 0, -252)) > 92 and roadClear(p, 20, 8) then
			local top = groundAt(p.X, p.Z)
			if top > 12 then
				slab(V(p.X, top + 4, p.Z), V(crng:NextNumber(14, 22), crng:NextNumber(14, 26), crng:NextNumber(10, 16)), crng:NextNumber(0, math.pi), crng:NextNumber(-0.3, 0.3), if i % 2 == 0 then M.Slate else M.Rock)
			end
		end
	end
	-- Star Crater rim: dark broken spires on the wall ring (never in the entrance gap)
	for _, spot in secretSpots() do
		if spot.Id == "StarCrater" then
			local c = spot.Position
			local gap = math.atan2(-60 - c.Z, 0 - c.X)
			for k = 0, 13 do
				local a = k / 14 * math.pi * 2 + crng:NextNumber(-0.1, 0.1)
				local d = math.abs((a - gap + math.pi) % (math.pi * 2) - math.pi)
				if d > 0.7 then
					local p = c + V(math.cos(a) * crng:NextNumber(56, 66), 0, math.sin(a) * crng:NextNumber(56, 66))
					local top = groundAt(p.X, p.Z)
					slab(V(p.X, top + 3, p.Z), V(crng:NextNumber(6, 10), crng:NextNumber(12, 22), crng:NextNumber(6, 10)), a, crng:NextNumber(-0.35, 0.35), M.Basalt)
				end
			end
		end
	end
end

-- creek and ponds: bank rocks, a muddier bank, and a few wider pools (the water layout itself is unchanged)
local function waterside()
	local wrng = Random.new(7373)
	for _, pond in PONDS do
		groundMix(pond.P, pond.R + 9, { { M.Sand, 0.5 }, { M.Ground, 0.3 }, { M.Mud, 0.2 } }, { { M.LeafyGrass, 0.6 }, { M.Grass, 0.4 } }, union(M.Sand), pond.P.X * 0.02)
		for k = 0, 4 do
			local a = k / 5 * math.pi * 2 + wrng:NextNumber(-0.4, 0.4)
			local p = pond.P + V(math.cos(a) * (pond.R + 2.5), 0, math.sin(a) * (pond.R + 2.5))
			-- (pass 2) no pebble rocks around the ponds (the stream is consumed so the pools below stay put)
			local _ = roadClear(p, 3, 2) and wrng:NextNumber(1.8, 2.8)
		end
	end
	local pts = splinePoints(CREEK, 3)
	for i, p in pts do
		-- a couple of wider pools (away from the bridge)
		if (i == 9 or i == 30) and flatDist(p, V(-170, 0, -40)) > 20 then
			Terrain:FillCylinder(CFrame.new(p.X, -3, p.Z), 14, 7.5, M.Air)
			Terrain:FillCylinder(CFrame.new(p.X, -6.5, p.Z), 7, 7, M.Water)
		end
		if i % 7 == 3 and flatDist(p, V(-170, 0, -40)) > 16 then
			local side = if i % 2 == 0 then 1 else -1
			local n = (pts[math.min(#pts, i + 1)] - p)
			local _right = V(-n.Z, 0, n.X).Unit * side
			local _ = wrng:NextNumber(1.8, 2.4) -- (pass 2) no pebble rocks along the creek
		end
	end
	for k = 1, #pts, 4 do
		groundMix(pts[k], 11, { { M.Sand, 0.4 }, { M.Ground, 0.35 }, { M.Mud, 0.25 } }, { { M.Grass, 0.5 }, { M.LeafyGrass, 0.5 } }, union(M.Sand), 3.3 + k, 8)
	end
end

-- open fields: rare soft meadows of longer grass so the valley floor is never one flat texture (kept off roads and the hub)
local function meadows()
	-- cells near any road or destination stay short grass
	local blocked = {}
	local function block(p: Vector3, r: number)
		for x = p.X - r, p.X + r, CELL do
			for z = p.Z - r, p.Z + r, CELL do
				blocked[math.floor(x / CELL) .. "," .. math.floor(z / CELL)] = true
			end
		end
	end
	for _, s in roadSamples do
		block(s.p, s.hw + 16)
	end
	for _, spot in ResourceSpotConfig.List() do
		block(spot.Position, ZONE_R[spot.Tier] + 30)
	end
	terrainEdit(MAP_MIN.X, MAP_MIN.Z, MAP_MAX.X, MAP_MAX.Z, -8, 0, function(x, y, z, mat)
		if mat ~= M.LeafyGrass or y < -4 or blocked[math.floor(x / CELL) .. "," .. math.floor(z / CELL)] then
			return nil
		end
		local n = math.noise(x / 110, z / 110, 4.4) + math.noise(x / 31, z / 31, 4.9) * 0.35
		if n > 0.3 and (x * x + (z - 60) ^ 2) > 210 * 210 then
			return M.Grass
		end
		return nil
	end)
end

-- foliage: vary tree sizes, drop trees whose canopy hangs over a road, and add intentional clusters around the hub
local function foliage()
	local frng = Random.new(8484)
	-- keep the approach corridors into the two secret pockets open (a clear view through each gap)
	local corridors = {}
	for _, spot in secretSpots() do
		local c = spot.Position
		local gap = math.atan2(-60 - c.Z, 0 - c.X)
		local gd = V(math.cos(gap), 0, math.sin(gap))
		table.insert(corridors, { c + gd * 55, c + gd * 150 })
	end
	local function inCorridor(p: Vector3): boolean
		for _, cr in corridors do
			local a, b = cr[1], cr[2]
			local u = (b - a).Unit
			local t = math.clamp((p - a):Dot(u), 0, (b - a).Magnitude)
			if flatDist(p, a + u * t) < 14 then
				return true
			end
		end
		return false
	end
	for _, t in decorF:GetChildren() do
		if t:IsA("Model") and t.Name == "Tree" then
			local cf, size = t:GetBoundingBox()
			local base = cf.Position - V(0, size.Y / 2, 0)
			if not roadClear(base, size.X * 0.42, 0) or inCorridor(base) then
				t:Destroy()
			else
				t.WorldPivot = CFrame.new(base)
				t:ScaleTo(frng:NextNumber(0.78, 1.32))
			end
		end
	end
	-- clusters: a focal tree with a few smaller ones leaning off it, off the spawn -> build sight-line
	local groups = {
		{ V(-82, 0, 182), "round", 5 }, { V(96, 0, 196), "round", 4 }, { V(-150, 0, 34), "mixed", 4 }, { V(128, 0, 72), "round", 3 },
		{ V(-232, 0, 24), "pine", 5 }, { V(214, 0, -60), "mixed", 4 }, { V(-60, 0, -120), "pine", 4 }, { V(70, 0, -160), "round", 4 },
		{ V(-300, 0, -180), "pine", 5 }, { V(-20, 0, -330), "pine", 5 }, { V(240, 0, -400), "pine", 4 },
	}
	local saved = rng
	rng = frng
	for _, g in groups do
		local c, kind, n = g[1], g[2], g[3]
		if clearOf(c, 6, 2) then
			decorTree(decorF, V(c.X, groundAt(c.X, c.Z), c.Z), if kind == "mixed" then "pine" else kind, 2.1)
		end
		for k = 1, n do
			local a = frng:NextNumber(0, math.pi * 2)
			local r = frng:NextNumber(7, 16)
			local p = c + V(math.cos(a) * r, 0, math.sin(a) * r)
			local s = frng:NextNumber(0.9, 1.5)
			if clearOf(p, 3 * s, 2) then
				decorTree(decorF, V(p.X, groundAt(p.X, p.Z), p.Z), if kind == "mixed" then (if k % 2 == 0 then "pine" else "round") else kind, s)
			end
		end
		groundMix(c, 16, { { M.Grass, 0.5 }, { M.Ground, 0.2 }, { M.LeafyGrass, 0.3 } }, nil, nil, c.X * 0.03)
	end
	rng = saved
end

-- (pass 2) ONE road language: the raised road body (parts, artReset2) sits on a soft terrain shoulder whose material says where
-- you are: hub = clean short verge, Wood = warm dirt, Stone = dust and rock, Metal = dark worn ground, Power = a maintained
-- concrete edge. The old pale terrain curb is repainted so no stair-stepped cell edge shows past the road body.
local ROAD_FAMILY_SH = { TimberRoad = "Wood", StoneRoad = "Stone", SteelRoad = "Metal", PowerRoad = "Power", BackRoad = "Metal" }
local SHOULDER = {
	hub = { 2.5, { { M.Ground, 0.45 }, { M.LeafyGrass, 0.55 } } },
	Wood = { 4.5, { { M.Ground, 0.7 }, { M.Sandstone, 0.3 } } },
	Stone = { 5, { { M.Sand, 0.45 }, { M.Rock, 0.35 }, { M.Ground, 0.2 } } },
	Metal = { 5, { { M.Basalt, 0.4 }, { M.Ground, 0.35 }, { M.Slate, 0.25 } } },
	Power = { 3, { { M.Concrete, 1 } } },
}
local function roadShoulders()
	for _, road in ROADS do
		if not road.Dirt then
			local fam = ROAD_FAMILY_SH[road.Name] or "Metal"
			for _, p in road.Samples do
				local key = if flatDist(p, V(0, 0, 40)) < 150 then "hub" else fam
				local sh = SHOULDER[key]
				local inner = road.Width / 2 + 1.5
				local r = inner + sh[1] + math.max(0, math.noise(p.X / 30, p.Z / 30, 11) * 2)
				terrainEdit(p.X - r - 4, p.Z - r - 4, p.X + r + 4, p.Z + r + 4, -8, 6, function(x, _y, z, mat)
					local d = math.sqrt((x - p.X) ^ 2 + (z - p.Z) ^ 2)
					if mat == M.Limestone and d > road.Width / 2 then
						return pickMat(sh[2], x, z, 13, 9)
					end
					if d > r + math.noise(x / 7, z / 7, 12) * 1.2 then
						return nil
					end
					if GRASSY[mat] then
						return pickMat(sh[2], x, z, 13, 9)
					end
					return nil
				end)
			end
		end
	end
end

-- the wooden bridge: stone abutments under both deck ends, wing walls and bank rocks so it sits in the banks
local function bridgeAbutments()
	local paths = world:FindFirstChild("Paths")
	local deck = paths and paths:FindFirstChild("BridgeDeck") :: BasePart?
	if not deck then
		return
	end
	local cf = deck.CFrame
	local stone = Color3.fromRGB(128, 124, 120)
	for _, sz in { -1, 1 } do
		B(paths, "Abutment", V(ROADS[1].Width + 6, 5, 3.4), cf * CFrame.new(0, -2.6, sz * 10.2), stone, M.Slate)
		for _, sx in { -1, 1 } do
			B(paths, "WingWall", V(2.4, 3.2, 7), cf * CFrame.new(sx * (ROADS[1].Width / 2 + 3.6), -0.9, sz * 12.4) * CFrame.Angles(0, sx * sz * 0.35, 0), tint(stone, -0.06), M.Slate)
			local rp = (cf * CFrame.new(sx * (ROADS[1].Width / 2 + 5), 0, sz * 9)).Position
			Terrain:FillBall(V(rp.X, -1.6, rp.Z), 2.2, M.Rock)
		end
	end
end

-- SKYLINE: a farther, cooler range behind the near ring and one snow-capped landmark peak, all outside the playable map
-- (mountain() and prism() are defined with distantLands)
local function skyline()
	local srng = Random.new(4343)
	local c = V(0, 0, -180)
	for i = 0, 19 do
		local a = (i + srng:NextNumber(-0.3, 0.3)) / 20 * math.pi * 2
		local p = c + V(math.cos(a) * 1260, -14, math.sin(a) * 1190)
		local hs, hm = horizonLook(a)
		mountain(p, a, srng:NextNumber(0.95, 1.25) * (0.6 + hs * 0.4), if hm == M.LeafyGrass then M.Grass else M.Slate, srng)
	end
	-- the landmark peak behind the Steel Mine cliff (north), with a snow cap
	local peak = V(-640, -20, -1260)
	peakAt(peak, 0.3, 500, 430, M.Slate)
	peakAt(peak + V(0, 430 * 0.76, 0), 0.3, 500 * 0.24, 430 * 0.24, M.Snow)
	peakAt(peak + V(250, 0, 60), 0.9, 360, 260, M.Slate)
	peakAt(peak + V(-230, 0, 90), 0.1, 320, 210, M.Slate)
end

------------------------------------------------------------------- ROUTE COMPOSITION (map pass 2)
-- Every road is read as a sequence of views: OPEN stretches (nothing added), FRAMED stretches (a low asymmetric ridge, rock
-- ledge or tree group narrows the view on one side), and a GATEWAY just before each Tier 2/3 destination (both sides framed,
-- then the view opens onto the landmark = the reveal). Plus gentle road banking, per-family ground along each road, valley-wall
-- character per direction, secret-area approaches and creek banks. Own random streams only (the locked layout never shifts).
local ROAD_FAMILY = { TimberRoad = "Wood", StoneRoad = "Stone", SteelRoad = "Metal", PowerRoad = "Power", BackRoad = "Metal" }

-- an asymmetric ridge along `axis`: a main lobe, a lower shoulder and a saddle, optionally with an exposed rock ledge
local function ridge(c: Vector3, axis: Vector3, len: number, height: number, mat: Enum.Material, ledge: Enum.Material?, r: Random)
	local foot = len * 0.36
	-- (pass 2) one broad ridge: a main landform and one lower shoulder along the axis (no third bump)
	hill(c, foot, height, mat)
	hill(c + axis * len * 0.34, foot * 0.75, height * r:NextNumber(0.5, 0.7), mat)
	local _ = r:NextNumber(0.3, 0.45)
	if ledge then
		local side = V(-axis.Z, 0, axis.X) * (if r:NextNumber() < 0.5 then 1 else -1)
		local p = c + side * foot * 0.45 + V(0, height * 0.3, 0)
		rockMass(CFrame.lookAt(p, p + axis) * CFrame.Angles(r:NextNumber(-0.15, 0.15), 0, r:NextNumber(-0.25, 0.25)), V(foot * 0.9, height * 0.75, len * 0.4), ledge)
	end
end

-- true when nothing that matters (any road, zone, hub, water) is within `r` of p
local function freeFor(p: Vector3, r: number): boolean
	return clearOf(p, r, 4)
end

local plantList: { any } = {}
local function plantLater(p: Vector3, kind: string, s: number, leaf: Color3?)
	table.insert(plantList, { p, kind, s, leaf })
end

local function corridors()
	local cr = Random.new(7171)
	local tier23 = {}
	for _, spot in ResourceSpotConfig.List() do
		if spot.Tier >= 2 and not spot.Secret then
			table.insert(tier23, spot.Position)
		end
	end
	for ri, road in ROADS do
		local fam = ROAD_FAMILY[road.Name]
		if fam then
			local s = road.Samples
			local acc, lastSec = 0, -1
			for i = 2, #s - 1 do
				acc += (s[i] - s[i - 1]).Magnitude
				local sec = math.floor(acc / 56)
				if sec ~= lastSec then
					lastSec = sec
					local p = s[i]
					local dir = (s[i + 1] - s[i - 1]) * V(1, 0, 1)
					dir = if dir.Magnitude > 0 then dir.Unit else V(0, 0, 1)
					local n = V(-dir.Z, 0, dir.X)
					-- gateway: 70-150 studs before a Tier 2/3 destination, frame BOTH sides (then it opens = reveal)
					local gate = false
					for _, d in tier23 do
						local dd = flatDist(p, d)
						if dd > 80 and dd < 150 then
							gate = true
						end
					end
					local hubDist = flatDist(p, V(0, 0, 40))
					local framed = gate or (hubDist > 170 and math.noise(ri * 3.1, sec * 0.77, 2.2) > 0.05)
					if framed then
						local sides = if gate then { -1, 1 } else { if math.noise(ri, sec, 5.5) > 0 then 1 else -1 }
						for _, sd in sides do
							local off = road.Width / 2 + cr:NextNumber(24, 36)
							local c = p + n * sd * off + dir * cr:NextNumber(-10, 10)
							local len = cr:NextNumber(46, 70)
							local h = cr:NextNumber(7, 13) * (if gate then 1.25 else 1)
							if freeFor(c, len * 0.3) then
								local mat, ledge = M.LeafyGrass, nil
								if fam == "Stone" then
									mat, ledge = M.Rock, M.Slate
								elseif fam == "Metal" then
									mat, ledge = M.LeafyGrass, M.Basalt
								elseif fam == "Wood" then
									ledge = if cr:NextNumber() < 0.35 then M.Rock else nil
								end
								ridge(c, dir, len, h, mat, ledge, cr)
								table.insert(keepOut, { p = c, r = len * 0.3 })
								-- trees on the framing ridge (wood = groups of pines/rounds; metal = a few pines; power = none)
								local nTrees = if fam == "Wood" then cr:NextInteger(3, 6) elseif fam == "Metal" then cr:NextInteger(0, 2) elseif fam == "Stone" then cr:NextInteger(0, 1) else 0
								nTrees = if fam == "Stone" then 0 else nTrees -- (pass 2) bare rock country: no lone trees on stone ridges
								for _ = 1, nTrees do
									local tp = c + dir * cr:NextNumber(-len * 0.4, len * 0.4) + n * sd * cr:NextNumber(-4, 10)
									if roadClear(tp, 8, 4) then
										plantLater(tp, if fam == "Wood" and cr:NextNumber() < 0.5 then "round" else "pine", cr:NextNumber(1.2, 2.1))
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

-- ground character along each road between its destinations (the family's material creeps in as you travel)
local ROAD_GROUND = {
	Stone = { { M.Sand, 0.3 }, { M.Rock, 0.25 }, { M.Ground, 0.2 }, { M.LeafyGrass, 0.25 } },
	Metal = { { M.Mud, 0.3 }, { M.Cobblestone, 0.2 }, { M.Ground, 0.25 }, { M.LeafyGrass, 0.25 } },
	Power = { { M.LeafyGrass, 0.7 }, { M.Cobblestone, 0.2 }, { M.Pavement, 0.1 } }, -- short, controlled verges (no tall blades)
	Wood = { { M.LeafyGrass, 0.55 }, { M.Ground, 0.3 }, { M.Grass, 0.15 } },
}
local function roadGround()
	for _, road in ROADS do
		local fam = ROAD_FAMILY[road.Name]
		local pal = fam and ROAD_GROUND[fam]
		if pal then
			local s = road.Samples
			for i = 1, #s, 6 do
				local p = s[i]
				local hub = flatDist(p, V(0, 0, 40))
				if hub > 180 then
					-- deeper into the route = stronger family identity
					local k = math.clamp((hub - 180) / 260, 0, 1)
					groundMix(p, 18 + k * 14, pal, nil, nil, i * 0.37 + #road.Name)
				end
			end
		end
	end
end

-- deepest Stone: the mountain foot loses its lawn; excavation benches cut into the face beside the canyon
local function stoneDepth()
	groundMix(V(394, 0, -252), 125, { { M.Sand, 0.3 }, { M.Rock, 0.35 }, { M.Slate, 0.15 }, { M.Ground, 0.2 } }, { { M.Ground, 0.4 }, { M.Rock, 0.3 }, { M.LeafyGrass, 0.3 } }, nil, 3.9, 80)
	for k, b in { { V(470, 0, -262), 0.6 }, { V(452, 0, -228), 0.2 }, { V(330, 0, -300), -0.8 } } do
		local top = groundAt(b[1].X, b[1].Z)
		if top > 10 then
			for step = 0, 2 do
				local p = b[1] + V(0, top * (0.3 + step * 0.22), 0)
				Terrain:FillBlock(CFrame.new(p) * CFrame.Angles(0, b[2], 0), V(30 - step * 6, 5, 9 - step), if (k + step) % 2 == 0 then M.Sandstone else M.Rock)
			end
		end
	end
end

-- metal: the foundry and the mine sit on worked ground; a rocky gap frames the mine portal at the end of the steel road
local function metalDepth()
	groundMix(V(-235, 0, -320), 82, { { M.Mud, 0.3 }, { M.Basalt, 0.25 }, { M.Cobblestone, 0.25 }, { M.Ground, 0.2 } }, { { M.Ground, 0.45 }, { M.Mud, 0.25 }, { M.LeafyGrass, 0.3 } }, union(M.Concrete), 5.1)
	groundMix(V(-172, 0, -498), 92, { { M.Basalt, 0.45 }, { M.Slate, 0.2 }, { M.Mud, 0.2 }, { M.Cobblestone, 0.15 } }, { { M.Mud, 0.4 }, { M.Basalt, 0.3 }, { M.LeafyGrass, 0.3 } }, union(M.Basalt), 5.3)
	local mr = Random.new(9393)
	for _, sd in { -1, 1 } do
		local c = V(-162 + sd * 62, 0, -418)
		if roadClear(c, 28, 4) then
			ridge(c, V(0, 0, 1), 64, mr:NextNumber(18, 24), M.Basalt, M.Slate, mr)
		end
	end
end

-- power: a line of transmission pylons along the road from the plant to the reactor (one large silhouette, few parts)
local function powerLine()
	local road
	for _, r in ROADS do
		if r.Name == "PowerRoad" then
			road = r
		end
	end
	if not road then
		return
	end
	local zone = world.Zones:FindFirstChild("ReactorYard")
	local f = zone or world
	local steel = Color3.fromRGB(150, 158, 172)
	local tops = {}
	local s = road.Samples
	local acc = 0
	for i = 2, #s - 1 do
		acc += (s[i] - s[i - 1]).Magnitude
		local p = s[i]
		if p.Z < -290 and p.Z > -450 and acc > 46 then
			acc = 0
			local dir = (s[i + 1] - s[i - 1]).Unit
			local n = V(-dir.Z, 0, dir.X)
			local q = p + n * (road.Width / 2 + 16)
			local inZone = flatDist(q, V(134, 0, -500)) < ZONE_R[3] + 8 or flatDist(q, V(240, 0, -300)) < ZONE_R[2] + 8
			if not inZone and roadClear(q, 3, 4) then
				local base = V(q.X, groundAt(q.X, q.Z), q.Z)
				-- a lattice pylon: two leaning legs, a waist, a mast and two cross arms with insulators
				for _, sd in { -1, 1 } do
					local a, b = base + dir * sd * 3.2, base + V(0, 20, 0) + dir * sd * 0.9
					B(f, "PowerLinePylon", V(0.8, 0.8, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), steel, M.Metal)
				end
				B(f, "PowerLinePylon", V(0.9, 18, 0.9), CFrame.new(base + V(0, 27, 0)), steel, M.Metal)
				for k, w in { 14, 10 } do
					local arm = CFrame.lookAt(base + V(0, 26 + k * 5, 0), base + V(0, 26 + k * 5, 0) + n) * CFrame.Angles(0, math.rad(90), 0)
					B(f, "PowerLineArm", V(w, 0.7, 0.7), arm, steel, M.Metal)
				end
				table.insert(tops, { base + V(0, 35.4, 0), n })
			end
		end
	end
	for i = 1, #tops - 1 do
		for _, off in { -6, 6 } do
			local a = tops[i][1] + tops[i][2] * off
			local b = tops[i + 1][1] + tops[i + 1][2] * off
			B(f, "Line", V(0.22, 0.22, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), Color3.fromRGB(40, 42, 50), M.SmoothPlastic, false)
		end
	end
end

-- valley wall character per direction: rocky north, forested west, open/low south, rocky-forested east
local function valleyWall()
	local vr = Random.new(1212)
	-- north: exposed rock ledges and crags along the far wall
	for x = -520, 540, 70 do
		local p = V(x + vr:NextNumber(-20, 20), 0, -672 + vr:NextNumber(-20, 20))
		local top = groundAt(p.X, p.Z)
		if top > 8 then
			rockMass(CFrame.new(p + V(0, top * 0.55, 18)) * CFrame.Angles(vr:NextNumber(-0.2, 0.1), vr:NextNumber(-0.4, 0.4), vr:NextNumber(-0.2, 0.2)), V(vr:NextNumber(26, 40), top * 0.8, 14), if vr:NextNumber() < 0.5 then M.Rock else M.Slate)
		end
	end
	-- west and east: tree lines on the wall crests (west denser = forested ridge)
	for _, side in { { -590, 0.75 }, { 605, 0.35 } } do
		for z = -620, 260, 22 do
			if vr:NextNumber() < side[2] then
				local p = V(side[1] + vr:NextNumber(-35, 25) * (if side[1] < 0 then 1 else -1), 0, z + vr:NextNumber(-8, 8))
				local top = groundAt(p.X, p.Z)
				local nearSecret = false
				for _, sp in secretSpots() do
					if flatDist(p, sp.Position) < 140 then
						nearSecret = true -- no green trees peeking over the crater rim or crowding the grove walls
					end
				end
				if top > 4 and not nearSecret then
					plantLater(V(p.X, 0, p.Z), "pine", vr:NextNumber(1.8, 3))
				end
			end
		end
	end
	-- east: a few rock faces between the trees
	for z = -560, 220, 110 do
		local p = V(600 + vr:NextNumber(-20, 10), 0, z)
		local top = groundAt(p.X, p.Z)
		if top > 8 then
			rockMass(CFrame.new(p + V(-14, top * 0.5, 0)) * CFrame.Angles(0, vr:NextNumber(-0.4, 0.4), vr:NextNumber(-0.25, 0.1)), V(14, top * 0.7, vr:NextNumber(24, 36)), M.Rock)
		end
	end
	-- south: kept low and open (a few round trees only)
	for x = -400, 420, 130 do
		local p = V(x + vr:NextNumber(-30, 30), 0, 290 + vr:NextNumber(-10, 10))
		if groundAt(p.X, p.Z) > 3 then
			plantLater(p, "round", vr:NextNumber(1.6, 2.2))
		end
	end
end

-- secret approaches: the crater road darkens and hardens as you near the gap; the grove road grows older, larger trees
local function secretApproaches()
	local ar = Random.new(4646)
	for _, spot in secretSpots() do
		local c = spot.Position
		local gap = math.atan2(-60 - c.Z, 0 - c.X)
		local gd = V(math.cos(gap), 0, math.sin(gap))
		local side = V(-gd.Z, 0, gd.X)
		if spot.Id == "StarCrater" then
			groundLine(c + gd * 190, c + gd * 140, 44, { { M.LeafyGrass, 0.55 }, { M.Ground, 0.45 } })
			groundLine(c + gd * 140, c + gd * 100, 50, { { M.Ground, 0.4 }, { M.Mud, 0.3 }, { M.Basalt, 0.3 } }, union(M.Ground, M.Mud))
			groundLine(c + gd * 100, c + gd * 60, 56, { { M.Basalt, 0.6 }, { M.Slate, 0.25 }, { M.Mud, 0.15 } }, union(M.Ground, M.Mud, M.Basalt))
			-- dark rock appears, more and larger toward the entrance (flanking the walking line, never on it)
			for k = 0, 9 do
				local t = k / 9
				local along = 180 - t * 115
				local s = 2.5 + t * 5
				local q = c + gd * along + side * (if k % 2 == 0 then 1 else -1) * ar:NextNumber(14, 26)
				if roadClear(q, s + 2, 2) then
					Terrain:FillBall(V(q.X, -s * 0.3, q.Z), s, M.Basalt)
				end
			end
		else
			-- trees grow larger and older toward the grove; two great trees half-hide the entrance
			for k = 0, 7 do
				local t = k / 7
				local along = 175 - t * 100
				local q = c + gd * along + side * (if k % 2 == 0 then 1 else -1) * ar:NextNumber(16, 24)
				if roadClear(q, 6, 2) then
					plantLater(q, "round", 1.4 + t * 1.4, Color3.fromRGB(70, 128, 66):Lerp(Color3.fromRGB(62, 112, 62), t))
				end
			end
			for _, sd in { -1, 1 } do
				plantLater(c + gd * 64 + side * sd * 15, "round", 3.2, Color3.fromRGB(62, 112, 62))
			end
			groundLine(c + gd * 170, c + gd * 80, 30, { { M.LeafyGrass, 0.65 }, { M.Ground, 0.2 }, { M.Mud, 0.15 } }, union(M.Grass))
		end
	end
end

-- Star Crater: a half-buried meteor on the far side gives the bowl a focal point and depth (kept clear of every ore node)
local function craterFocal()
	for _, spot in secretSpots() do
		if spot.Id == "StarCrater" then
			local c = spot.Position
			local gap = math.atan2(-60 - c.Z, 0 - c.X)
			local nodes = CollectionService:GetTagged("ResourceNode")
			for _, da in { 0, 0.5, -0.5, 1, -1 } do
				local a = gap + math.pi + da
				local p = c + V(math.cos(a), 0, math.sin(a)) * 40
				local ok = true
				for _, nd in nodes do
					if nd:IsA("BasePart") and flatDist(nd.Position, p) < 16 then
						ok = false
					end
				end
				if ok then
					Terrain:FillBall(p + V(0, -2, 0), 10, M.Basalt)
					Terrain:FillBall(p + V(4, 3, -2), 6, M.Slate)
					local z = world.Zones:FindFirstChild("StarCrater")
					for k = 1, 3 do
						P(z, { Name = "MeteorCrystal", Size = V(2.2, 6 + k * 2, 2.2), CFrame = CFrame.new(p + V(math.cos(k * 2.1) * 4, 6 + k, math.sin(k * 2.1) * 4)) * CFrame.Angles(math.sin(k) * 0.4, k, math.cos(k) * 0.4), Color = Color3.fromRGB(120, 200, 255), Material = M.Glass, Transparency = 0.2, CanCollide = false })
					end
					break
				end
			end
		end
	end
end

-- creek: soft raised banks on alternating sides so the water reads as shaped by the land (bridge area left alone)
local function creekBanks()
	local pts = splinePoints(CREEK, 10)
	for i = 2, #pts - 1 do
		local p = pts[i]
		if flatDist(p, V(-170, 0, -40)) > 22 then
			local d = (pts[i + 1] - pts[i - 1]).Unit
			local n = V(-d.Z, 0, d.X) * (if i % 2 == 0 then 1 else -1)
			local q = p + n * 12
			if roadClear(q, 6, 2) then
				Terrain:FillBall(V(q.X, -4.6, q.Z), 6, M.LeafyGrass)
			end
		end
	end
end

-- the wooden bridge: two timber piers in the water under the deck (the deck itself is unchanged)
local function bridgePiers()
	local paths = world:FindFirstChild("Paths")
	local deck = paths and paths:FindFirstChild("BridgeDeck") :: BasePart?
	if not deck then
		return
	end
	for _, sx in { -1, 1 } do
		B(paths, "BridgePier", V(1.6, 6, 1.6), deck.CFrame * CFrame.new(sx * (ROADS[1].Width / 2 - 1), -4.4, 0), Color3.fromRGB(96, 64, 40), M.Wood)
	end
	B(paths, "BridgeBeam", V(ROADS[1].Width, 1.2, 1.4), deck.CFrame * CFrame.new(0, -1.9, 0), Color3.fromRGB(96, 64, 40), M.Wood)
end

-- Training Yard: tree groups at its outer corners so the yard reads as a clearing, not a pasted rectangle
local function trainingEdge()
	for _, p in { V(-176, 0, 58), V(-180, 0, 200), V(-112, 0, 212), V(-176, 0, 128) } do
		if roadClear(p, 6, 4) then
			plantLater(p, "round", 1.8)
			plantLater(p + V(-9, 0, 6), "pine", 1.5)
			plantLater(p + V(-5, 0, -9), "round", 1.3)
		end
	end
end

local function plantAll()
	task.wait(0.3)
	local saved = rng
	rng = Random.new(2323)
	for _, t in plantList do
		local p = t[1]
		decorTree(decorF, V(p.X, groundAt(p.X, p.Z), p.Z), t[2], t[3])
		if t[4] then
			local kids = decorF:GetChildren()
			local tree = kids[#kids]
			for _, lf in tree:GetChildren() do
				if lf.Name == "Leaves" or lf.Name == "Tier" then
					lf.Color = t[4]:Lerp(Color3.new(0, 0, 0), rng:NextNumber(0, 0.08))
				end
			end
		end
	end
	rng = saved
	table.clear(plantList)
	-- nothing green may poke over the Star Crater rim (the bowl reads alien from inside)
	for _, sp in secretSpots() do
		if sp.Id == "StarCrater" then
			for _, t in decorF:GetChildren() do
				if t:IsA("Model") and flatDist(t:GetPivot().Position, sp.Position) < 195 then
					t:Destroy()
				end
			end
		end
	end
end

local function routePass()
	corridors()
	-- (pass 2) no banking wedges: the road now has its own raised body and a soft shoulder (artReset2 roadBodies)
	roadGround()
	stoneDepth()
	metalDepth()
	valleyWall()
	secretApproaches()
	creekBanks()
end

------------------------------------------------------------------- SURFACE PASS (map pass 3: materials, ground, prop palette)
-- Terrain material work and a palette pass over the existing parts. No new geometry beyond a few terrain fills, so the part count
-- does not change. Deterministic (noise only), so the locked layout never moves.

-- terrain: the green hill on the mountain approach, pale Stick Grove ground, sawdust at the Logging Camp, worn industrial asphalt,
-- muddy water edges
local function surfaceTerrain()
	-- the mountain approach hills become dusty, rocky stone country (some green kept at their edges)
	for _, h in { { V(286, 0, -176), 64 }, { V(322, 0, -196), 70 }, { V(262, 0, -332), 66 }, { V(306, 0, -420), 58 } } do
		groundMix(h[1], h[2], { { M.Rock, 0.3 }, { M.Ground, 0.25 }, { M.Sand, 0.25 }, { M.Slate, 0.1 }, { M.LeafyGrass, 0.1 } }, { { M.Ground, 0.4 }, { M.LeafyGrass, 0.45 }, { M.Rock, 0.15 } }, nil, h[1].X * 0.01, 60)
	end
	-- Stick Grove: pale dirt breaking through a light lawn
	for _, spot in ResourceSpotConfig.List() do
		if spot.Id == "Forest" then
			groundMix(spot.Position, 30, { { M.LeafyGrass, 0.5 }, { M.Sand, 0.25 }, { M.Ground, 0.25 } }, nil, nil, 3.7)
		end
	end
	-- Logging Camp: sawdust around the saw bench and the log wall
	local camp = world.Zones:FindFirstChild("LumberCamp")
	for _, name in { "SawTable", "YardLog" } do
		local part = camp and camp:FindFirstChild(name, true) :: BasePart?
		if part then
			groundMix(part.Position, 13, { { M.Sandstone, 0.6 }, { M.Ground, 0.4 } }, nil, union(M.Ground, M.Mud), 4.2)
		end
	end
	-- industrial roads: darker worn patches in the asphalt (heavy traffic), subtle and low-frequency
	for _, road in ROADS do
		if road.Name == "SteelRoad" or road.Name == "BackRoad" then
			for i = 1, #road.Samples, 2 do
				local p = road.Samples[i]
				if flatDist(p, V(0, 0, 40)) > 160 then
					local r = road.Width / 2 - 1
					terrainEdit(p.X - r, p.Z - r, p.X + r, p.Z + r, -8, 2, function(x, _y, z, mat)
						if mat == M.Asphalt and math.noise(x / 22, z / 22, 7.7) > 0.4 then
							return M.Slate -- slightly paler, rougher worn patches (heavy haul traffic)
						end
						return nil
					end)
				end
			end
		end
	end
	-- the Steel Mine cliff is bare dark rock: no lawn left on its face or crest
	terrainEdit(-300, -660, -40, -545, 6, 120, function(_x, _y, _z, mat)
		if GRASSY[mat] then
			return M.Basalt
		end
		return nil
	end)
	-- water edges: mud and a little stone right at the water, grass only higher up the bank
	for _, pond in PONDS do
		groundMix(pond.P, pond.R + 4, { { M.Mud, 0.6 }, { M.Ground, 0.25 }, { M.Rock, 0.15 } }, nil, union(M.Sand, M.Ground), pond.P.Z * 0.03)
	end
	local pts = splinePoints(CREEK, 3)
	for k = 1, #pts, 3 do
		groundMix(pts[k], 11, { { M.Mud, 0.55 }, { M.Ground, 0.3 }, { M.Rock, 0.15 } }, { { M.Ground, 0.4 }, { M.LeafyGrass, 0.6 } }, union(M.Sand), 5.5 + k)
	end
end

-- prop palette: one controlled language per family (metal = dark steel / mid grey / warm accents; power = pale metal, dark framing,
-- restrained cyan; wood = warm, darker bark in the redwoods; platform = dark steel + readable deck)
local function hsv(c: Color3): (number, number, number)
	return c:ToHSV()
end

local function surfaceProps()
	local zones = world:FindFirstChild("Zones")
	if not zones then
		return
	end
	local METAL_ZONES = { Mine = true, IndustrialYard = true, SteelWorks = true }
	local POWER_ZONES = { Energy = true, ReactorYard = true, CoreVault = true }
	local metalMats = { [M.Metal] = true, [M.DiamondPlate] = true, [M.CorrodedMetal] = true }
	for _, z in zones:GetChildren() do
		local id = z.Name
		for _, d in z:GetDescendants() do
			if d:IsA("BasePart") and d.Material ~= M.Neon and d.Material ~= M.ForceField and d.Material ~= M.Glass then
				local h, sat, v = hsv(d.Color)
				if METAL_ZONES[id] and metalMats[d.Material] then
					-- no chrome-white steel: pale greys come down to a mid industrial grey
					if v > 0.75 and sat < 0.18 then
						d.Color = Color3.fromHSV(h, sat, 0.62)
					end
				elseif POWER_ZONES[id] then
					-- white plastic becomes pale brushed metal; big white bases become the darker structural frame
					if v > 0.88 and sat < 0.08 then
						if d.Name == "ReactorBase" then
							d.Color = Color3.fromRGB(72, 78, 94)
							d.Material = M.Metal
						else
							d.Color = Color3.fromRGB(210, 214, 222)
							d.Material = M.Metal
						end
					end
				end
			end
		end
	end
	-- metal beams: dark steel webs with a warm painted top flange (was solid saturated yellow); the node part keeps its tag
	local yard = zones:FindFirstChild("IndustrialYard")
	if yard then
		for _, d in yard:GetDescendants() do
			if d:IsA("BasePart") and d.Parent and d.Parent.Name == "BeamStack" then
				if d.Name == "BeamWeb" then
					d.Color = Color3.fromRGB(96, 102, 116)
				elseif d.Name == "BeamFlange" then
					d.Color = if d.Position.Y > d.Parent:GetPivot().Position.Y + 0.5 then Color3.fromRGB(214, 160, 62) else Color3.fromRGB(78, 84, 96)
				end
			end
		end
	end
	-- rock field rubble: from near-white to a dusty grey slate (still the lightest stone of the three tiers)
	local field = zones:FindFirstChild("Quarry")
	if field then
		for _, d in field:GetDescendants() do
			if d:IsA("BasePart") and d.Parent and d.Parent.Name == "Rubble" then
				d.Color = d.Color:Lerp(Color3.fromRGB(132, 130, 128), 0.45)
			end
		end
	end
	-- redwoods: darker, premium bark
	local tz = zones:FindFirstChild("TimberStand")
	if tz then
		for _, d in tz:GetDescendants() do
			if d:IsA("BasePart") and (d.Name == "Trunk" or d.Name == "UpperTrunk" or d.Name == "Root") and d.Parent and d.Parent.Name == "Redwood" then
				d.Color = d.Color:Lerp(Color3.fromRGB(86, 46, 34), 0.55)
			end
		end
	end
	-- bridge: a clear timber hierarchy (dark posts and piers, warm rails, a mid deck)
	local paths = world:FindFirstChild("Paths")
	if paths then
		for _, d in paths:GetChildren() do
			if d.Name == "BridgeDeck" then
				d.Color = Color3.fromRGB(124, 84, 54)
			elseif d.Name == "BridgeRail" then
				d.Color = Color3.fromRGB(164, 114, 70)
			elseif d.Name == "BridgePost" or d.Name == "BridgePier" or d.Name == "BridgeBeam" then
				d.Color = Color3.fromRGB(88, 58, 38)
			end
		end
	end
	-- build platform: dark structural steel skirt, a readable plated deck, warm trim (geometry unchanged)
	local site = world:FindFirstChild("BuildSite")
	if site then
		local deck = site:FindFirstChild("Platform") :: BasePart?
		if deck then
			deck.Color = Color3.fromRGB(122, 126, 136)
			deck.Material = M.DiamondPlate
		end
		local work = site:FindFirstChild("WorkDeck") :: BasePart?
		if work then
			work.Color = Color3.fromRGB(146, 148, 154)
		end
	end
end

local function surfacePass()
	surfaceTerrain()
	surfaceProps()
end

local art2, art3, art4 -- (passes 2, 3 and 4) ServerStorage.DevTools.WorldBuilderArt2 / Art3, set up in Build()
local function environmentPass()
	zoneGround()
	outcrops()
	secretGround()
	cliffs()
	waterside()
	-- (pass 2) no dotted dirt fringes around the hub: one composed hub ground instead (artReset2 hubGround)
	meadows()
	routePass()
	roadShoulders()
	art2.terrain()
end

------------------------------------------------------------------- ART RESET PASS 1 (strip-back, palette, lighting)
-- Toy Construction Valley: subtraction and consistency. Nothing here adds geometry. Removed art is PARKED (moved, not deleted)
-- into ServerStorage/ArtReset_Parked/<Category>; generated categories are refilled on every rebuild, the non-generated
-- _ForestOverhaul set lives in ArtReset_Parked/ForestOverhaul and is never cleared. Gameplay objects (tagged resource nodes,
-- gather points, spawn, platform, barrier, roads, prompts) are never parked.
local park, artReset -- (pass 1 section wrapped in do..end: the file is at the local-register limit)
do
	local ART = {
		Grass = Color3.fromRGB(110, 156, 74),
		Canopy = Color3.fromRGB(86, 150, 74),
		CanopyDark = Color3.fromRGB(64, 124, 64),
		Bark = Color3.fromRGB(106, 70, 44),
		RedwoodBark = Color3.fromRGB(122, 66, 46),
		PaleMetal = Color3.fromRGB(198, 202, 210),
		Steel = Color3.fromRGB(96, 102, 114),
		DarkSteel = Color3.fromRGB(62, 68, 82),
		OffWhite = Color3.fromRGB(226, 220, 206),
		Power = Color3.fromRGB(70, 190, 220),
	}

	local GENERATED_CATS = { "Trees", "Bushes", "Scatter", "VFX", "GroundDecor", "Misc" }
	local parkRoot: Folder
	local parkedCount = { Trees = 0, Bushes = 0, Scatter = 0, VFX = 0, GroundDecor = 0, Misc = 0 }

	local function parkFolder(cat: string): Folder
		local f = parkRoot:FindFirstChild(cat)
		if not f then
			f = Instance.new("Folder")
			f.Name = cat
			f.Parent = parkRoot
		end
		return f :: Folder
	end

	local function isGameplay(inst: Instance): boolean
		if CollectionService:HasTag(inst, "ResourceNode") then
			return true
		end
		for _, d in inst:GetDescendants() do
			if CollectionService:HasTag(d, "ResourceNode") or d:IsA("ProximityPrompt") or d:IsA("SpawnLocation") then
				return true
			end
		end
		return inst.Name == "GatherPoint"
	end

	function park(inst: Instance, cat: string)
		if isGameplay(inst) then
			return
		end
		inst.Parent = parkFolder(cat)
		parkedCount[cat] += 1
	end

	local function lerpTone(c: Color3, target: Color3, k: number): Color3
		return c:Lerp(target, k)
	end

	local function setupPark()
		parkRoot = ServerStorage:FindFirstChild("ArtReset_Parked") :: Folder
		if not parkRoot then
			parkRoot = Instance.new("Folder")
			parkRoot.Name = "ArtReset_Parked"
			parkRoot:SetAttribute("Note", "Art reset pass 1: environment art parked (moved, not deleted). Generated categories are refilled by WorldBuilder.Build(); ForestOverhaul holds the non-generated Workspace._ForestOverhaul set. Move items back into Workspace to restore.")
			parkRoot.Parent = ServerStorage
		end
		for _, cat in GENERATED_CATS do
			local f = parkRoot:FindFirstChild(cat)
			if f then
				f:Destroy() -- regenerated content only; the rebuild recreates whatever is parked here again
			end
		end
		-- the non-generated _ForestOverhaul set (a fourth tree style + flowers, ferns, bushes, logs, patches): parked whole, once
		local fo = workspace:FindFirstChild("_ForestOverhaul")
		if fo then
			local dest = parkFolder("ForestOverhaul")
			fo.Parent = dest
		end
	end

	-- TREES: one family (chunky round broadleaf + stepped pine, redwood and ancient variants built the same way), one canopy palette,
	-- fewer trees: isolated singles, trees crowding a road, and trees behind the build in the spawn sightline are parked
	local function treeReset()
		local trees = {}
		for _, t in decorF:GetChildren() do
			if t:IsA("Model") and t.Name == "Tree" then
				table.insert(trees, t)
			end
		end
		local pos = {}
		for i, t in trees do
			pos[i] = t:GetPivot().Position
		end
		for i, t in trees do
			local p = pos[i]
			local neighbours = 0
			for j, q in pos do
				if j ~= i and flatDist(p, q) < 24 then
					neighbours += 1
				end
			end
			local behindBuild = math.abs(p.X) < 70 and p.Z < -40 and p.Z > -300
			local nearHub = flatDist(p, V(0, 0, 100)) < 95
			local _, size = t:GetBoundingBox()
			local crowdsRoad = not roadClear(p, size.X * 0.5, 2)
			if neighbours == 0 or behindBuild or nearHub or crowdsRoad then
				park(t, "Trees")
			end
		end
		-- one palette and one material for every canopy and trunk that stays
		local srng = Random.new(777)
		for _, d in world:GetDescendants() do
			if d:IsA("BasePart") then
				local n = d.Name
				if n == "Leaves" or n == "Crown" or n == "Canopy" then
					d.Color = ART.Canopy:Lerp(ART.CanopyDark, srng:NextNumber(0, 0.5))
					d.Material = M.SmoothPlastic
				elseif n == "Tier" then
					d.Color = ART.CanopyDark:Lerp(ART.Canopy, srng:NextNumber(0, 0.35))
					d.Material = M.SmoothPlastic
				elseif (n == "Trunk" or n == "UpperTrunk" or n == "AncientTrunk" or n == "TrunkFlare" or n == "Root") and d.Material == M.Wood then
					local red = d.Parent and d.Parent.Name == "Redwood"
					d.Color = if red then ART.RedwoodBark else ART.Bark
				end
			end
		end
	end

	-- SCATTER / GROUND DECOR / AMBIENT VFX: everything that only adds noise
	local SCATTER = { SmallStump = true, StumpRings = true, FallenBranch = true, Twig = true, MossRock = true, Moss = true, MushStem = true, MushCap = true, Seam = true }
	local GROUNDDECOR = { MossCarpet = true }
	local VFXN = { NodeGlow = true, NodeGlowRim = true, OreGlow = true, LogGlow = true, Aura = true, StarMotes = true, GroveMotes = true, Mote = true, CanopyLight = true }
	local function stripBack()
		local meteors = {}
		for _, d in world:GetDescendants() do
			if d:IsA("BasePart") then
				local n = d.Name
				if SCATTER[n] then
					park(d, "Scatter")
				elseif GROUNDDECOR[n] then
					park(d, "GroundDecor")
				elseif VFXN[n] then
					park(d, "VFX")
				elseif n == "Meteor" then
					table.insert(meteors, d)
				end
			elseif d:IsA("Model") and d.Name == "Lamp" and d.Parent == decorF then
				park(d, "Misc") -- roadside lamps: lights used as decoration
			end
		end
		-- crater: keep the three largest meteor fragments only
		table.sort(meteors, function(a, b)
			return a.Size.Magnitude > b.Size.Magnitude
		end)
		for i, m in meteors do
			if i > 3 and m.Parent then
				park(m, "Scatter")
			end
		end
	end

	-- REACTOR + POWER: structure dark/neutral, colour only in the core and a few caps, one localized light
	local function powerReset()
		local zones = world:FindFirstChild("Zones")
		local vault = zones and zones:FindFirstChild("CoreVault")
		if vault then
			for _, d in vault:GetDescendants() do
				if d:IsA("BasePart") then
					local n = d.Name
					if n == "ReactorBase" then
						d.Color, d.Material = ART.DarkSteel, M.Metal
					elseif n == "ReactorInlay" then
						d.Color, d.Material = ART.Steel, M.Metal
					elseif n == "Pillar" or n == "PylonMast" or n == "CrownRing" then
						d.Color, d.Material = ART.PaleMetal, M.Metal
					elseif n == "PillarCap" or n == "PylonCap" then
						d.Color = ART.Steel -- cyan stays in the core and the pods only
					elseif n == "PodCore" then
						d.Color = ART.Power
					elseif n == "Core" then
						d.Color, d.Material = ART.Power, M.Neon
					elseif n == "Halo" or n == "PodHalo" or n == "PodFin" then
						d.Color = Color3.fromRGB(60, 160, 190)
					elseif n == "PodBase" then
						d.Color = ART.PaleMetal
					elseif n == "PodInlay" then
						d.Color = ART.DarkSteel
					end
				elseif d:IsA("PointLight") then
					local core = d.Parent and d.Parent.Name == "Core"
					d.Color = ART.Power
					d.Range = if core then 22 else math.min(d.Range, 8)
					d.Brightness = if core then 1.2 else math.min(d.Brightness, 0.35)
				end
			end
		end
		-- every other power light in the valley: smaller and dimmer (glow stays on the source)
		for _, id in { "ReactorYard", "Energy" } do
			local z = zones and zones:FindFirstChild(id)
			if z then
				for _, d in z:GetDescendants() do
					if d:IsA("PointLight") then
						d.Range = math.min(d.Range, 10)
						d.Brightness = math.min(d.Brightness, 0.5)
					end
				end
			end
		end
	end

	-- WHITE / PALE AUDIT + a few rainbow props: white becomes deliberate (off-white or pale metal), never default plastic white
	local function paletteReset()
		local zones = world:FindFirstChild("Zones")
		local power = { Energy = true, ReactorYard = true, CoreVault = true }
		for _, d in world:GetDescendants() do
			if d:IsA("BasePart") and d.Material ~= M.Neon and d.Material ~= M.Glass and d.Material ~= M.ForceField and d.Transparency < 0.5 then
				local h, s, v = d.Color:ToHSV()
				if v > 0.9 and s < 0.1 then
					local z = zones and d:FindFirstAncestorWhichIsA("Model")
					local inPower = false
					local anc = d.Parent
					while anc and anc ~= world do
						if power[anc.Name] then
							inPower = true
						end
						anc = anc.Parent
					end
					d.Color = if inPower or d.Material == M.Metal then ART.PaleMetal else ART.OffWhite
					local _ = z
				end
				local _ = h
			end
		end
		-- scrap yard crushed cars: from red/blue/green toy colours to one rusty family
		local mine = zones and zones:FindFirstChild("Mine")
		if mine then
			local k = 0
			for _, d in mine:GetDescendants() do
				if d:IsA("BasePart") and d.Name == "CrushedCar" then
					k += 1
					d.Color = ({ Color3.fromRGB(156, 92, 62), Color3.fromRGB(110, 116, 128), Color3.fromRGB(176, 128, 70) })[(k - 1) % 3 + 1]
				end
			end
		end
		local _ = lerpTone
	end

	-- TERRAIN: fewer, flatter materials. No grass blades (Grass -> LeafyGrass), mud/cobble blotches merge into plain earth;
	-- one palette for every terrain material
	local function terrainReset()
		terrainEdit(MAP_MIN.X - 40, MAP_MIN.Z - 40, MAP_MAX.X + 40, MAP_MAX.Z + 40, -40, 140, function(_x, _y, _z, mat)
			if mat == M.Grass then
				return M.LeafyGrass
			elseif mat == M.Mud or mat == M.Cobblestone then
				return M.Ground
			end
			return nil
		end)
		local colors = {
			[M.LeafyGrass] = ART.Grass,
			[M.Grass] = ART.Grass,
			[M.Ground] = Color3.fromRGB(150, 118, 86),
			[M.Sand] = Color3.fromRGB(214, 192, 146),
			[M.Sandstone] = Color3.fromRGB(196, 164, 118),
			[M.Rock] = Color3.fromRGB(150, 144, 136),
			[M.Slate] = Color3.fromRGB(112, 110, 116),
			[M.Basalt] = Color3.fromRGB(70, 68, 76),
			[M.Asphalt] = Color3.fromRGB(84, 86, 94),
			[M.Limestone] = Color3.fromRGB(200, 194, 180),
			[M.Pavement] = Color3.fromRGB(176, 180, 188),
			[M.Concrete] = Color3.fromRGB(150, 150, 152),
			[M.Salt] = Color3.fromRGB(168, 172, 182),
			[M.Mud] = Color3.fromRGB(150, 118, 86),
			[M.Cobblestone] = Color3.fromRGB(150, 118, 86),
		}
		for mat, col in colors do
			Terrain:SetMaterialColor(mat, col)
		end
	end

	function artReset(): string
		setupPark()
		treeReset()
		stripBack()
		powerReset()
		paletteReset()
		terrainReset()
		local parts = {}
		for k, v in parkedCount do
			table.insert(parts, k .. " " .. v)
		end
		return table.concat(parts, ", ")
	end

	------------------------------------------------------------------- build
end

function WorldBuilder.Build(): string
	local old = workspace:FindFirstChild("World")
	if old then
		local sp = old:FindFirstChildWhichIsA("SpawnLocation", true)
		if sp then
			sp.Parent = workspace
		end
		old:Destroy()
	end
	rng = Random.new(1234)
	world = Instance.new("Folder")
	world.Name = "World"
	world.Parent = workspace
	decorF = folder(world, "Scenery")
	art2 = require(ServerStorage.DevTools.WorldBuilderArt2:Clone())({
		world = world, decorF = decorF, ROADS = ROADS, ROAD_TOP = ROAD_TOP, ZONE_R = ZONE_R, SPAWN = SPAWN, TRAIN_CENTER = TRAIN_CENTER,
		ResourceSpotConfig = ResourceSpotConfig, GRASSY = GRASSY, landform = landform, clearOf = clearOf, roadClear = roadClear,
		flatDist = flatDist, groundAt = groundAt, terrainEdit = terrainEdit, plantLater = plantLater, folder = folder, P = P,
		park = park, tint = tint,
	})
	art3 = require(ServerStorage.DevTools.WorldBuilderArt3:Clone())({
		world = world, decorF = decorF, ROADS = ROADS, ROAD_TOP = ROAD_TOP, TRAIN_CENTER = TRAIN_CENTER, ResourceSpotConfig = ResourceSpotConfig,
		flatDist = flatDist, groundAt = groundAt, roadClear = roadClear, clearOf = clearOf, P = P, tint = tint, smoke = smoke,
		soft = soft, gableRoof = gableRoof, rockMass = rockMass, park = park,
	})
	art4 = require(ServerStorage.DevTools.WorldBuilderArt4:Clone())({
		world = world, decorF = decorF, ROADS = ROADS, ResourceSpotConfig = ResourceSpotConfig, flatDist = flatDist, groundAt = groundAt,
		roadClear = roadClear, P = P, tint = tint, smoke = smoke, soft = soft, rockMass = rockMass, park = park,
		terrainEdit = terrainEdit, GRASSY = GRASSY,
	})
	-- the old baseplate stays only as an invisible safety floor far below the terrain
	local bp = workspace:FindFirstChild("Baseplate") :: BasePart?
	if bp then
		bp.Transparency = 1
		bp.Size = V(1900, 4, 1900)
		bp.CFrame = CFrame.new(0, -60, 0)
		for _, c in bp:GetChildren() do
			if c:IsA("Texture") then
				c:Destroy()
			end
		end
	end

	-- 0. (colossal site) moved Tier 1 zones generate at their original spot (identical layout and random stream);
	-- WorldBuilderColossal shifts them out by GenOffset afterwards
	local genShifted = {}
	for _, spot in ResourceSpotConfig.List() do
		if spot.GenOffset then
			if not spot._GenApplied then -- (a build that errored part-way leaves it applied; never subtract twice)
				spot.Position -= spot.GenOffset
				spot._GenApplied = true
			end
			table.insert(genShifted, spot)
		end
	end
	-- 1. road splines
	roadSamples = {}
	for _, road in ROADS do
		road.Samples = splinePoints(road.Points, 4)
		for _, p in road.Samples do
			table.insert(roadSamples, { p = p, hw = road.Width / 2 })
		end
	end
	-- 2. keep-out areas (nothing random may land on these)
	keepOut = {
		{ p = V(0, 0, 0), r = 64 },
		{ p = V(0, 0, 106), r = 60 },
		{ p = V(-64, 0, 110), r = 16 },
		{ p = V(-62, 0, 140), r = 15 },
		{ p = V(66, 0, 110), r = 18 },
		{ p = V(63, 0, 142), r = 14 },
		{ p = TRAIN_TERRAIN_KEEPOUT, r = 86 },
		{ p = V(452, 0, -326), r = 108 },
		{ p = V(-172, 0, -590), r = 70 },
	}
	for _, spot in ResourceSpotConfig.List() do
		table.insert(keepOut, { p = spot.Position, r = ZONE_R[spot.Tier] + 6 })
	end
	for _, pond in PONDS do
		table.insert(keepOut, { p = pond.P, r = pond.R + 6 })
	end
	for _, p in splinePoints(CREEK, 6) do
		table.insert(keepOut, { p = p, r = 9 })
	end

	-- 3. terrain: paint map -> flat ground -> horizon -> landforms and hills -> water
	setTerrainColors()
	paintGround()
	writeBase()
	distantLands()
	skyline()
	landforms()
	hills()
	restoreGround()
	water()
	task.wait(0.3) -- let the new terrain reach physics so ground raycasts (tree placement) see it
	-- 4. resource destinations (ground paint + parts)
	for _, spot in ResourceSpotConfig.List() do
		local fn = ZONE_BUILDERS[spot.Id]
		if fn then
			fn(spot)
		end
	end
	environmentPass()
	applyClearings()
	scorchCrater()
	-- 5. roads over everything
	roads()
	bridgeAbutments()
	-- 6. hub, training, decor, light
	buildSite()
	buildHub()
	buildTrainingYard()
	-- trees: keep the new Training Yard clear and let the old yard ground fill in
	for i, k in keepOut do
		if k.p == TRAIN_TERRAIN_KEEPOUT then
			keepOut[i] = { p = TRAIN_CENTER, r = 72 }
		end
	end
	decor()
	foliage()
	powerLine()
	craterFocal()
	bridgePiers()
	trainingEdge()
	art2.plantClusters()
	plantAll()
	surfacePass()
	local parkedSummary = artReset()
	local pass2Summary = art2.finish()
	local pass3Summary = art3.finish()
	local pass4Summary = art4.finish()
	for _, spot in genShifted do
		spot.Position += spot.GenOffset
		spot._GenApplied = nil
	end
	local colossalSummary = require(ServerStorage.DevTools.WorldBuilderColossal:Clone())({
		world = world, decorF = decorF, ROADS = ROADS, P = P, park = park, flatDist = flatDist, terrainEdit = terrainEdit, GRASSY = GRASSY,
		ResourceSpotConfig = ResourceSpotConfig, CREEK = splinePoints(CREEK, 4), PONDS = PONDS, groundAt = groundAt,
	})
	-- Pass 14D: build-site presentation polish (deck composition, rim bastions, site crane, silo cluster); runs after the site exists
	local siteSummary = require(ServerStorage.DevTools.WorldBuilderSite14D:Clone())({ world = world })
	-- Pass 16B: zone identity + valley atmosphere (large forms in World.ZonePolish; never moves anything)
	local zoneSummary = require(ServerStorage.DevTools.WorldBuilderZones16B:Clone())({ world = world })
	-- Pass 19A: hub spacing + circulation (spawn cluster back, apron, vehicle lane, road reconnections); runs last on the finished world
	local hubSummary = require(ServerStorage.DevTools.WorldBuilderHub19A:Clone())({ world = world })
	-- Pass 20C: final map visual quality (terrain materials, road beds, zone approach identity, groves); never moves the layout
	local artSummary = require(ServerStorage.DevTools.WorldBuilderArt20C:Clone())({ world = world })
	-- Pass 21E: the big Training Pad (pad, perimeter race track, five themed benches + treadmills, lanes moved); rebuilds the yard
	local treadSummary = require(ServerStorage.DevTools.WorldBuilderTrainingPad21E:Clone())({ world = world })
	-- Pass 21F: a substantial spawn plaza around the (unchanged) spawn point
	local spawnSummary = require(ServerStorage.DevTools.WorldBuilderSpawn21F:Clone())({ world = world })
	-- Pass 21H: map presence (mountain ring, rolling hills, forests in the empty meadows)
	local terrainSummary = require(ServerStorage.DevTools.WorldBuilderTerrain21H:Clone())({ world = world })
	setupLighting()
	art3.atmosphere()
	workspace.StreamingEnabled = false

	local count = 0
	for _, d in world:GetDescendants() do
		if d:IsA("BasePart") then
			count += 1
		end
	end
	return "world built: " .. count .. " parts, terrain cells " .. Terrain:CountCells() .. " | parked: " .. parkedSummary .. " | pass 2: " .. pass2Summary .. " | pass 3: " .. pass3Summary .. " | pass 4: " .. pass4Summary .. " | colossal site: " .. colossalSummary .. " | " .. siteSummary .. " | " .. zoneSummary .. " | " .. hubSummary .. " | " .. artSummary .. " | " .. treadSummary .. " | " .. spawnSummary .. " | " .. terrainSummary
end

return WorldBuilder
