--!nonstrict
-- EDIT-TIME GENERATOR for the three prototype build templates. Produces
-- ServerStorage.BuildTemplates.<Name> following the build model convention
-- (docs/BUILD_AUTHORING.md):
--   Model (WorldPivot = bottom-center of the footprint, at the origin)
--     Stage_01 .. Stage_NN   Models; their BaseParts appear in order as progress grows
--     Effects (optional)     shown only when the build completes
--   Part attributes: Order (number, optional), Accent (Golden modifier target),
--   PowerLight (lights up on completion), Lava (smokes on completion), NoDamage.
-- Run: require(game.ServerStorage.DevTools.TemplateBuilder:Clone()).BuildAll()
-- Templates are plain parts afterward; hand-authored templates work the same way.
local ServerStorage = game:GetService("ServerStorage")

local TemplateBuilder = {}

local function P(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, attrs: { [string]: any }?): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if attrs then
		for k, v in attrs do
			p:SetAttribute(k, v)
		end
	end
	p.Parent = parent
	return p
end

local function stage(m: Model, i: number): Model
	local s = Instance.new("Model")
	s.Name = string.format("Stage_%02d", i)
	s.Parent = m
	return s
end

local function newTemplate(name: string): Model
	local folder = ServerStorage:FindFirstChild("BuildTemplates")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "BuildTemplates"
		folder.Parent = ServerStorage
	end
	local old = folder:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = folder
	return m
end

local function finish(m: Model)
	m.WorldPivot = CFrame.new(0, 0, 0)
end

-- Box split into horizontal slices so it rises layer by layer.
local function slicedBox(parent: Instance, center: CFrame, size: Vector3, slices: number, color: Color3, material: Enum.Material?, attrs: { [string]: any }?)
	local h = size.Y / slices
	for i = 0, slices - 1 do
		P(parent, Vector3.new(size.X, h, size.Z), center * CFrame.new(0, -size.Y / 2 + h * (i + 0.5), 0), color, material, attrs)
	end
end

-- Wall from a to b (flat), base y0, height, thickness. openings = { {u0,u1,v0,v1} } in
-- studs along the wall/height. Built on a 4x4 grid merged into runs up to 8 wide.
local function wall(parent: Instance, a: Vector3, b: Vector3, y0: number, height: number, thick: number, color: Color3, material: Enum.Material, openings: { { number } }?)
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local cell = 4
	local cols = math.floor(len / cell + 0.5)
	local rows = math.floor(height / cell + 0.5)
	local cw = len / cols
	local rh = height / rows
	local base = CFrame.lookAt(a, a + dir) * CFrame.Angles(0, math.rad(90), 0)
	local function open(c: number, r: number): boolean
		local u = (c + 0.5) * cw
		local v = (r + 0.5) * rh
		for _, o in openings or {} do
			if u > o[1] and u < o[2] and v > o[3] and v < o[4] then
				return true
			end
		end
		return false
	end
	for r = 0, rows - 1 do
		local c = 0
		while c < cols do
			if open(c, r) then
				c += 1
			else
				local run = 1
				if c + 1 < cols and not open(c + 1, r) then
					run = 2
				end
				local u = (c + run / 2) * cw
				local pos = a + dir * u + Vector3.new(0, y0 + (r + 0.5) * rh, 0)
				P(parent, Vector3.new(cw * run, rh, thick), CFrame.lookAt(pos, pos + dir:Cross(Vector3.yAxis)), color, material)
				c += run
			end
		end
	end
	local _ = base
end

------------------------------------------------------------------ Classic House
function TemplateBuilder.ClassicHouse(): Model
	local m = newTemplate("ClassicHouse")
	local W, D = 40, 28 -- footprint
	local tan = Color3.fromRGB(226, 205, 160)
	local trim = Color3.fromRGB(245, 245, 240)
	local roof = Color3.fromRGB(196, 50, 45)
	local concrete = Color3.fromRGB(165, 165, 160)
	local wood = Color3.fromRGB(140, 95, 55)

	-- 1 Foundation
	local s1 = stage(m, 1)
	for x = -1, 1, 2 do
		for z = -1, 1, 2 do
			P(s1, Vector3.new(W / 2 + 2, 2, D / 2 + 2), CFrame.new(x * (W / 4 + 0.5), 1, z * (D / 4 + 0.5)), concrete, Enum.Material.Concrete)
		end
	end
	P(s1, Vector3.new(12, 1, 6), CFrame.new(0, 0.5, -D / 2 - 4), concrete, Enum.Material.Concrete) -- front step
	P(s1, Vector3.new(8, 0.6, 14), CFrame.new(0, 0.3, -D / 2 - 13), Color3.fromRGB(190, 170, 140), Enum.Material.Cobblestone) -- front path

	-- 2 Walls (ground floor, 12 tall)
	local s2 = stage(m, 2)
	local y0, h = 2, 12
	local c = { Vector3.new(-W / 2, 0, -D / 2), Vector3.new(W / 2, 0, -D / 2), Vector3.new(W / 2, 0, D / 2), Vector3.new(-W / 2, 0, D / 2) }
	wall(s2, c[1], c[2], y0, h, 1.5, tan, Enum.Material.Brick, { { 16, 24, 0, 9 }, { 4, 12, 4, 9 }, { 28, 36, 4, 9 } }) -- front: door + 2 windows
	wall(s2, c[2], c[3], y0, h, 1.5, tan, Enum.Material.Brick, { { 8, 20, 4, 9 } })
	wall(s2, c[3], c[4], y0, h, 1.5, tan, Enum.Material.Brick, { { 8, 16, 4, 9 }, { 24, 32, 4, 9 } })
	wall(s2, c[4], c[1], y0, h, 1.5, tan, Enum.Material.Brick, { { 8, 20, 4, 9 } })
	for _, corner in c do
		P(s2, Vector3.new(2, h, 2), CFrame.new(corner + Vector3.new(0, y0 + h / 2, 0)), trim, Enum.Material.SmoothPlastic, { Accent = true })
	end

	-- 3 Upper floor (slab + 10-tall walls)
	local s3 = stage(m, 3)
	slicedBox(s3, CFrame.new(0, y0 + h + 0.75, 0), Vector3.new(W + 2, 1.5, D + 2), 1, trim, Enum.Material.SmoothPlastic, { Accent = true })
	local y1 = y0 + h + 1.5
	wall(s3, c[1], c[2], y1, 8, 1.5, tan, Enum.Material.Brick, { { 4, 12, 2, 6 }, { 16, 24, 2, 6 }, { 28, 36, 2, 6 } })
	wall(s3, c[2], c[3], y1, 8, 1.5, tan, Enum.Material.Brick, { { 8, 20, 2, 6 } })
	wall(s3, c[3], c[4], y1, 8, 1.5, tan, Enum.Material.Brick, { { 12, 28, 2, 6 } })
	wall(s3, c[4], c[1], y1, 8, 1.5, tan, Enum.Material.Brick, { { 8, 20, 2, 6 } })
	for _, corner in c do
		P(s3, Vector3.new(2, 8, 2), CFrame.new(corner + Vector3.new(0, y1 + 4, 0)), trim, Enum.Material.SmoothPlastic, { Accent = true })
	end

	-- 4 Roof (stepped blocky gable running along X)
	local s4 = stage(m, 4)
	local y2 = y1 + 8
	local steps = 6
	for i = 0, steps - 1 do
		local depth = (D + 6) - i * ((D + 6) / steps)
		P(s4, Vector3.new(W + 6, 2, depth), CFrame.new(0, y2 + 1 + i * 2, 0), roof, Enum.Material.Slate)
	end
	P(s4, Vector3.new(W + 7, 1, 2), CFrame.new(0, y2 + steps * 2 + 0.5, 0), Color3.fromRGB(150, 35, 30), Enum.Material.Slate, { Accent = true })
	-- gable ends (stepped tan triangles)
	for _, sx in { -1, 1 } do
		for i = 0, steps - 1 do
			local depth = D - i * (D / steps)
			if depth > 1 then
				P(s4, Vector3.new(1.4, 2, depth), CFrame.new(sx * W / 2, y2 + 1 + i * 2, 0), tan, Enum.Material.Brick)
			end
		end
	end

	-- 5 Finishing touches
	local s5 = stage(m, 5)
	P(s5, Vector3.new(4, 8, 3), CFrame.new(W / 4, y2 + 10, D / 6), Color3.fromRGB(120, 60, 50), Enum.Material.Brick) -- chimney
	P(s5, Vector3.new(4.6, 1, 3.6), CFrame.new(W / 4, y2 + 14.5, D / 6), Color3.fromRGB(60, 60, 60), Enum.Material.Slate)
	P(s5, Vector3.new(7.6, 9, 0.8), CFrame.new(0, y0 + 4.5, -D / 2 - 0.2), Color3.fromRGB(60, 140, 70), Enum.Material.Wood, { Accent = true }) -- door
	P(s5, Vector3.new(0.6, 0.6, 0.4), CFrame.new(2.6, y0 + 4.5, -D / 2 - 0.8), Color3.fromRGB(240, 200, 60), Enum.Material.Metal, { Accent = true })
	-- windows: glass + frames on the front
	local glass = Color3.fromRGB(150, 210, 255)
	for _, wx in { -12, 12 } do
		P(s5, Vector3.new(7.6, 4.6, 0.3), CFrame.new(wx, y0 + 6.5, -D / 2), glass, Enum.Material.Glass)
		P(s5, Vector3.new(9, 1, 1.4), CFrame.new(wx, y0 + 3.6, -D / 2 - 0.4), trim, Enum.Material.SmoothPlastic, { Accent = true })
	end
	for _, wx in { -12, 0, 12 } do
		P(s5, Vector3.new(7.6, 3.6, 0.3), CFrame.new(wx, y1 + 4, -D / 2), glass, Enum.Material.Glass)
	end
	-- porch roof
	P(s5, Vector3.new(14, 0.8, 6), CFrame.new(0, y0 + 10.5, -D / 2 - 3.2), roof, Enum.Material.Slate)
	for _, px in { -6, 6 } do
		P(s5, Vector3.new(0.8, 9.6, 0.8), CFrame.new(px, y0 + 5.2, -D / 2 - 5.6), trim, Enum.Material.SmoothPlastic, { Accent = true })
	end
	-- picket fence + flowers
	for x = -W / 2 - 2, W / 2 + 2, 4 do
		if math.abs(x) > 5 then
			P(s5, Vector3.new(3.4, 2.4, 0.4), CFrame.new(x, 1.2, -D / 2 - 18), trim, Enum.Material.Wood)
		end
	end
	for _, fx in { -14, -8, 8, 14 } do
		P(s5, Vector3.new(4, 1, 3), CFrame.new(fx, 0.5, -D / 2 - 6), Color3.fromRGB(110, 75, 45), Enum.Material.Ground)
		P(s5, Vector3.new(1, 1, 1), CFrame.new(fx - 1, 1.4, -D / 2 - 6), Color3.fromRGB(255, 90, 120), Enum.Material.SmoothPlastic)
		P(s5, Vector3.new(1, 1, 1), CFrame.new(fx + 1, 1.4, -D / 2 - 6), Color3.fromRGB(255, 220, 70), Enum.Material.SmoothPlastic)
	end
	P(s5, Vector3.new(1, 4, 1), CFrame.new(-8, 2, -D / 2 - 17), wood, Enum.Material.Wood) -- mailbox
	P(s5, Vector3.new(1.6, 1.4, 2.4), CFrame.new(-8, 4.4, -D / 2 - 17), Color3.fromRGB(60, 90, 200), Enum.Material.Metal, { Accent = true })
	finish(m)
	return m
end

------------------------------------------------------------------ Volcano Temple
function TemplateBuilder.VolcanoTemple(): Model
	local m = newTemplate("VolcanoTemple")
	local basalt = Color3.fromRGB(58, 52, 50)
	local stone = Color3.fromRGB(168, 150, 120)
	local darkStone = Color3.fromRGB(120, 105, 85)
	local rock = Color3.fromRGB(92, 70, 58)
	local lava = Color3.fromRGB(255, 110, 20)
	local metal = Color3.fromRGB(150, 160, 170)

	-- 1 Bedrock: 3x3 basalt tiles
	local s1 = stage(m, 1)
	for x = -1, 1 do
		for z = -1, 1 do
			P(s1, Vector3.new(18.6, 3, 18.6), CFrame.new(x * 18.6, 1.5, z * 18.6), basalt, Enum.Material.Basalt)
		end
	end

	-- 2 Lower terrace: ring of stone blocks (walls) with front stairs
	local s2 = stage(m, 2)
	local half = 25
	for i = -5, 5 do
		local t = i * 4.6
		P(s2, Vector3.new(4.6, 6, 4), CFrame.new(t, 6, -half), stone, Enum.Material.Limestone)
		P(s2, Vector3.new(4.6, 6, 4), CFrame.new(t, 6, half), stone, Enum.Material.Limestone)
		P(s2, Vector3.new(4, 6, 4.6), CFrame.new(-half, 6, t), stone, Enum.Material.Limestone)
		P(s2, Vector3.new(4, 6, 4.6), CFrame.new(half, 6, t), stone, Enum.Material.Limestone)
	end
	slicedBox(s2, CFrame.new(0, 5.5, 0), Vector3.new(46, 5, 46), 1, darkStone, Enum.Material.Limestone)
	for i = 0, 3 do
		P(s2, Vector3.new(12, 1.5, 3), CFrame.new(0, 3.75 + i * 1.5, -half - 7 + i * 2.5), stone, Enum.Material.Limestone)
	end
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			P(s2, Vector3.new(6, 9, 6), CFrame.new(cx * half, 7.5, cz * half), darkStone, Enum.Material.Limestone, { Accent = true })
		end
	end

	-- 3 Volcano cone: stacked, shrinking rock tiers with lava streaks
	local s3 = stage(m, 3)
	local y = 8
	local tiers = { 30, 27, 24, 21, 18, 15, 13 }
	for i, w in tiers do
		local hgt = 5
		for k = 0, 3 do
			local a = k * math.rad(90) + math.rad(i * 7)
			local cf = CFrame.new(0, y + hgt / 2, 0) * CFrame.Angles(0, a, 0)
			P(s3, Vector3.new(w, hgt, w * 0.5), cf * CFrame.new(0, 0, w * 0.25), rock, Enum.Material.Rock)
		end
		y += hgt
	end
	for k = 0, 2 do
		local a = k * math.rad(120) + 0.3
		for j = 0, 4 do
			local r = 15 - j * 1.9
			local yy = 10 + j * 5
			P(s3, Vector3.new(1.6, 5.4, 1.6), CFrame.new(math.cos(a) * r, yy, math.sin(a) * r) * CFrame.Angles(0, -a, math.rad(18)), lava, Enum.Material.Neon, { Lava = true, NoDamage = true })
		end
	end

	-- 4 Upper terrace: raised walkway ring with pillars
	local s4 = stage(m, 4)
	local uh = 17
	for i = -3, 3 do
		local t = i * 5.4
		for _, side in { -1, 1 } do
			P(s4, Vector3.new(5.4, 2, 6), CFrame.new(t, 9, side * 19), stone, Enum.Material.Limestone)
			P(s4, Vector3.new(6, 2, 5.4), CFrame.new(side * 19, 9, t), stone, Enum.Material.Limestone)
		end
	end
	for _, cx in { -1, 1 } do
		for _, cz in { -1, 1 } do
			P(s4, Vector3.new(4, uh, 4), CFrame.new(cx * 19, 10 + uh / 2, cz * 19), stone, Enum.Material.Limestone)
			P(s4, Vector3.new(5.6, 1.6, 5.6), CFrame.new(cx * 19, 10 + uh + 0.8, cz * 19), metal, Enum.Material.Metal, { Accent = true })
			local brazier = P(s4, Vector3.new(3, 1.4, 3), CFrame.new(cx * 19, 10 + uh + 2.3, cz * 19), Color3.fromRGB(60, 60, 64), Enum.Material.Metal)
			local f = Instance.new("Fire")
			f.Size = 5
			f.Heat = 9
			f.Parent = brazier
		end
	end

	-- 5 Shrine: temple facade at the front of the cone
	local s5 = stage(m, 5)
	local fz = -24
	P(s5, Vector3.new(22, 2, 10), CFrame.new(0, 10, fz), darkStone, Enum.Material.Limestone)
	for _, cx in { -9, -3, 3, 9 } do
		slicedBox(s5, CFrame.new(cx, 17, fz - 3), Vector3.new(2.4, 12, 2.4), 3, stone, Enum.Material.Limestone)
		P(s5, Vector3.new(3.2, 1, 3.2), CFrame.new(cx, 23.5, fz - 3), metal, Enum.Material.Metal, { Accent = true })
	end
	P(s5, Vector3.new(24, 2, 9), CFrame.new(0, 25, fz - 1), stone, Enum.Material.Limestone)
	P(s5, Vector3.new(18, 2, 7), CFrame.new(0, 27, fz - 1), darkStone, Enum.Material.Limestone, { Accent = true })
	P(s5, Vector3.new(10, 2, 5), CFrame.new(0, 29, fz - 1), stone, Enum.Material.Limestone)
	local idol = P(s5, Vector3.new(4, 6, 2), CFrame.new(0, 14, fz + 2), Color3.fromRGB(210, 170, 60), Enum.Material.Metal, { Accent = true })
	local core = P(s5, Vector3.new(1.6, 1.6, 0.6), CFrame.new(0, 15.5, fz + 0.8), Color3.fromRGB(80, 230, 255), Enum.Material.Neon)
	local _ = idol
	local l = Instance.new("PointLight")
	l.Color = core.Color
	l.Range = 14
	l.Parent = core

	-- 6 Lava Crown: crater rim + lava pool + overflow
	local s6 = stage(m, 6)
	local top = 8 + #tiers * 5
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		P(s6, Vector3.new(5, 4, 3), CFrame.new(math.cos(a) * 6, top + 2, math.sin(a) * 6) * CFrame.Angles(0, -a + math.rad(90), 0), basalt, Enum.Material.Basalt)
	end
	P(s6, Vector3.new(1.2, 10, 10), CFrame.new(0, top + 1.5, 0) * CFrame.Angles(0, 0, math.rad(90)), lava, Enum.Material.Neon, { Lava = true, NoDamage = true }).Shape = Enum.PartType.Cylinder
	for k = 0, 3 do
		local a = k * math.rad(90) + 0.7
		P(s6, Vector3.new(2, 1, 9), CFrame.new(math.cos(a) * 9, top - 2, math.sin(a) * 9) * CFrame.Angles(0, -a + math.rad(90), math.rad(-30)), lava, Enum.Material.Neon, { Lava = true, NoDamage = true })
	end
	local effects = Instance.new("Folder")
	effects.Name = "Effects"
	effects.Parent = m
	local glow = P(effects, Vector3.new(2, 2, 2), CFrame.new(0, top + 4, 0), lava, Enum.Material.Neon, { NoDamage = true })
	glow.Transparency = 1
	glow.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = lava
	light.Range = 45
	light.Brightness = 3
	light.Parent = glow
	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(lava)
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.6, 0)
	embers.Speed = NumberRange.new(8, 16)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Rate = 25
	embers.Lifetime = NumberRange.new(1.5, 2.5)
	embers.Acceleration = Vector3.new(0, -6, 0)
	embers.Parent = glow
	finish(m)
	return m
end

------------------------------------------------------------------ Giant Robot
function TemplateBuilder.GiantRobot(): Model
	local m = newTemplate("GiantRobot")
	local steel = Color3.fromRGB(160, 168, 180)
	local dark = Color3.fromRGB(60, 64, 74)
	local paint = Color3.fromRGB(40, 110, 220)
	local yellow = Color3.fromRGB(250, 196, 40)
	local off = Color3.fromRGB(70, 80, 95) -- unlit power light (lights at completion)
	local concrete = Color3.fromRGB(150, 150, 145)

	-- 1 Footings: base pads + feet
	local s1 = stage(m, 1)
	for _, sx in { -1, 1 } do
		P(s1, Vector3.new(16, 1.5, 22), CFrame.new(sx * 9, 0.75, 0), concrete, Enum.Material.Concrete)
		slicedBox(s1, CFrame.new(sx * 9, 3.5, -1), Vector3.new(12, 4, 18), 2, dark, Enum.Material.DiamondPlate)
		P(s1, Vector3.new(12.4, 1.2, 4), CFrame.new(sx * 9, 2.4, -10.5), yellow, Enum.Material.Metal, { Accent = true })
	end

	-- 2 Legs: shins, knees, thighs
	local s2 = stage(m, 2)
	for _, sx in { -1, 1 } do
		local x = sx * 9
		slicedBox(s2, CFrame.new(x, 13.5, 0), Vector3.new(8, 16, 8), 4, steel, Enum.Material.Metal)
		P(s2, Vector3.new(8.6, 2, 8.6), CFrame.new(x, 9, 0), paint, Enum.Material.SmoothPlastic, { Accent = true })
		P(s2, Vector3.new(9, 5, 9), CFrame.new(x, 24, 0), dark, Enum.Material.DiamondPlate) -- knee
		P(s2, Vector3.new(1.4, 1.4, 0.6), CFrame.new(x, 24, -4.7), off, Enum.Material.SmoothPlastic, { PowerLight = true })
		slicedBox(s2, CFrame.new(x, 33, 0), Vector3.new(8.5, 14, 8.5), 3, paint, Enum.Material.SmoothPlastic)
		P(s2, Vector3.new(1.4, 12, 1.4), CFrame.new(x + sx * 5, 15, 2), Color3.fromRGB(200, 200, 210), Enum.Material.Metal) -- piston
	end

	-- 3 Hips
	local s3 = stage(m, 3)
	slicedBox(s3, CFrame.new(0, 42.5, 0), Vector3.new(28, 5, 12), 2, dark, Enum.Material.DiamondPlate)
	P(s3, Vector3.new(29, 1.6, 12.6), CFrame.new(0, 45.6, 0), yellow, Enum.Material.Metal, { Accent = true })
	P(s3, Vector3.new(6, 4, 1), CFrame.new(0, 42.5, -6.4), steel, Enum.Material.Metal)

	-- 4 Torso: chest built in slices + reactor core + vents
	local s4 = stage(m, 4)
	slicedBox(s4, CFrame.new(0, 58, 0), Vector3.new(30, 24, 16), 6, paint, Enum.Material.SmoothPlastic)
	P(s4, Vector3.new(20, 10, 1.2), CFrame.new(0, 60, -8.4), steel, Enum.Material.Metal)
	P(s4, Vector3.new(6, 6, 1), CFrame.new(0, 60, -9.2), off, Enum.Material.SmoothPlastic, { PowerLight = true })
	for _, vx in { -11, 11 } do
		for k = 0, 3 do
			P(s4, Vector3.new(5, 0.8, 1), CFrame.new(vx, 52 + k * 1.6, -8.2), dark, Enum.Material.Metal)
		end
	end
	P(s4, Vector3.new(31, 2, 17), CFrame.new(0, 47, 0), dark, Enum.Material.DiamondPlate)
	P(s4, Vector3.new(14, 14, 6), CFrame.new(0, 60, 10.5), dark, Enum.Material.DiamondPlate) -- backpack
	for _, tx in { -4, 4 } do
		P(s4, Vector3.new(3, 4, 3), CFrame.new(tx, 52, 12), steel, Enum.Material.Metal)
	end

	-- 5 Arms
	local s5 = stage(m, 5)
	for _, sx in { -1, 1 } do
		local x = sx * 20
		P(s5, Vector3.new(10, 9, 11), CFrame.new(x, 66, 0), yellow, Enum.Material.Metal, { Accent = true }) -- shoulder
		slicedBox(s5, CFrame.new(x, 55, 0), Vector3.new(7, 14, 7), 3, steel, Enum.Material.Metal)
		P(s5, Vector3.new(7.6, 3, 7.6), CFrame.new(x, 47, 0), dark, Enum.Material.DiamondPlate) -- elbow
		slicedBox(s5, CFrame.new(x, 38.5, -1), Vector3.new(8, 13, 8), 3, paint, Enum.Material.SmoothPlastic)
		slicedBox(s5, CFrame.new(x, 28.5, -1.5), Vector3.new(9, 7, 9), 2, dark, Enum.Material.DiamondPlate) -- fist
		P(s5, Vector3.new(1.2, 1.2, 0.5), CFrame.new(x, 67, -5.7), off, Enum.Material.SmoothPlastic, { PowerLight = true })
	end

	-- 6 Head
	local s6 = stage(m, 6)
	P(s6, Vector3.new(8, 3, 8), CFrame.new(0, 71.5, 0), dark, Enum.Material.DiamondPlate) -- neck
	slicedBox(s6, CFrame.new(0, 78, 0), Vector3.new(14, 10, 12), 3, steel, Enum.Material.Metal)
	P(s6, Vector3.new(11, 2.4, 1), CFrame.new(0, 79, -6.3), off, Enum.Material.SmoothPlastic, { PowerLight = true }) -- visor
	P(s6, Vector3.new(15, 1.4, 13), CFrame.new(0, 83.7, 0), paint, Enum.Material.SmoothPlastic, { Accent = true })
	for _, sx in { -1, 1 } do
		P(s6, Vector3.new(1.4, 5, 5), CFrame.new(sx * 7.6, 78, 0), yellow, Enum.Material.Metal, { Accent = true })
	end
	P(s6, Vector3.new(0.8, 7, 0.8), CFrame.new(3, 88, 2), steel, Enum.Material.Metal)

	-- 7 Power Up: antenna tip, chest panel lights, thruster glows
	local s7 = stage(m, 7)
	P(s7, Vector3.new(1.8, 1.8, 1.8), CFrame.new(3, 92, 2), off, Enum.Material.SmoothPlastic, { PowerLight = true })
	for k = 0, 4 do
		P(s7, Vector3.new(1.4, 1.4, 0.5), CFrame.new(-6 + k * 3, 66.5, -8.4), off, Enum.Material.SmoothPlastic, { PowerLight = true })
	end
	for _, tx in { -4, 4 } do
		P(s7, Vector3.new(2.4, 1, 2.4), CFrame.new(tx, 49.5, 12), off, Enum.Material.SmoothPlastic, { PowerLight = true })
	end
	for _, sx in { -1, 1 } do
		P(s7, Vector3.new(10.4, 1, 11.4), CFrame.new(sx * 20, 70.9, 0), dark, Enum.Material.DiamondPlate)
	end
	finish(m)
	return m
end

function TemplateBuilder.BuildAll(): string
	local out = {}
	-- (colossal) ClassicHouse is generated by TemplateBuilderColossal now
	for _, name in { "VolcanoTemple", "GiantRobot" } do
		local m = TemplateBuilder[name]()
		local n = 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
			end
		end
		table.insert(out, name .. "=" .. n)
	end
	return table.concat(out, ", ")
end

return TemplateBuilder
