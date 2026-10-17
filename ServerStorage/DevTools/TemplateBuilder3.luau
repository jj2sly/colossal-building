--!nonstrict
-- EDIT-TIME GENERATOR, quality pass for the five showcase builds (replaces their versions in TemplateBuilder /
-- TemplateBuilder2): Giant Robot, Volcano Temple, UFO, Pirate Ship, Dragon Citadel. Same convention as the other
-- generators (docs/BUILD_AUTHORING.md). Front = -Z here; BuildService turns every build to face the spawn.
--
-- Each stage adds a big, readable change from a distance (base -> frame -> main body -> secondary -> detail -> finish).
-- Moving parts for the completion spectacles are grouped in named Models inside their stage (ArmL, ArmR, Head,
-- WingL, WingR, Cannon) so SpectacleController can animate them without hard-coded positions.
-- Run: require(game.ServerStorage.DevTools.TemplateBuilder3:Clone()).BuildAll()
local ServerStorage = game:GetService("ServerStorage")

local TB = {}
local RGB = Color3.fromRGB
local M = Enum.Material
local V = Vector3.new

local function P(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, attrs: { [string]: any }?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	for k, v in attrs or {} do
		p:SetAttribute(k, v)
	end
	p.Parent = parent
	return p
end

local function W(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, attrs: { [string]: any }?): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or M.SmoothPlastic
	for k, v in attrs or {} do
		p:SetAttribute(k, v)
	end
	p.Parent = parent
	return p
end

-- vertical cylinder centred at pos
local function C(parent: Instance, height: number, diameter: number, pos: Vector3, color: Color3, material: Enum.Material?, attrs: { [string]: any }?): BasePart
	local p = P(parent, V(height, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material, attrs)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- cylinder along X (wheels, barrels)
local function CX(parent: Instance, length: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material?, attrs: { [string]: any }?): BasePart
	local p = P(parent, V(length, diameter, diameter), cf, color, material, attrs)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent: Instance, d: number, pos: Vector3, color: Color3, material: Enum.Material?, attrs: { [string]: any }?): BasePart
	local p = P(parent, V(d, d, d), CFrame.new(pos), color, material, attrs)
	p.Shape = Enum.PartType.Ball
	return p
end

-- square bar from a to b
local function bar(parent: Instance, a: Vector3, b: Vector3, t: number, color: Color3, material: Enum.Material?, attrs: { [string]: any }?): BasePart
	return P(parent, V(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material, attrs)
end

local function sliced(parent: Instance, center: CFrame, size: Vector3, slices: number, color: Color3, material: Enum.Material?, attrs: { [string]: any }?)
	local h = size.Y / slices
	for i = 0, slices - 1 do
		P(parent, V(size.X, h, size.Z), center * CFrame.new(0, -size.Y / 2 + h * (i + 0.5), 0), color, material, attrs)
	end
end

-- flat triangle a-b-c from two wedges (wing membranes, sails)
local function tri(parent: Instance, a: Vector3, b: Vector3, c: Vector3, thick: number, color: Color3, material: Enum.Material?, attrs: { [string]: any }?)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))
	W(parent, V(thick, height, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), color, material, attrs)
	W(parent, V(thick, height, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), color, material, attrs)
end

local function ring(parent: Instance, radius: number, count: number, size: Vector3, y: number, color: Color3, material: Enum.Material?, attrs: { [string]: any }?, offset: number?)
	for i = 0, count - 1 do
		local a = (i + (offset or 0)) / count * math.pi * 2
		local pos = V(math.cos(a) * radius, y, math.sin(a) * radius)
		P(parent, size, CFrame.lookAt(pos, V(0, y, 0)), color, material, attrs)
	end
end

-- octagonal slab (two crossed squares): reads round from every side with few parts
local function octo(parent: Instance, width: number, height: number, pos: Vector3, color: Color3, material: Enum.Material?, attrs: { [string]: any }?)
	P(parent, V(width, height, width * 0.42), CFrame.new(pos), color, material, attrs)
	P(parent, V(width * 0.42, height, width), CFrame.new(pos), color, material, attrs)
	P(parent, V(width * 0.72, height, width * 0.72), CFrame.new(pos) * CFrame.Angles(0, math.rad(45), 0), color, material, attrs)
end

local function stage(m: Model, i: number): Model
	local s = Instance.new("Model")
	s.Name = string.format("Stage_%02d", i)
	s.Parent = m
	return s
end

local function group(parent: Instance, name: string): Model
	local g = Instance.new("Model")
	g.Name = name
	g.Parent = parent
	return g
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

local function effects(m: Model): Folder
	local f = Instance.new("Folder")
	f.Name = "Effects"
	f.Parent = m
	return f
end

local function glowPoint(parent: Instance, pos: Vector3, color: Color3, range: number, brightness: number): BasePart
	local g = P(parent, V(1, 1, 1), CFrame.new(pos), color, M.SmoothPlastic, { NoDamage = true })
	g.Transparency = 1
	g.CanCollide = false
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = g
	return g
end

local function fire(part: BasePart, size: number)
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = 9
	f.Parent = part
end

------------------------------------------------------------------ Giant Robot (Legendary)
function TB.GiantRobot(): Model
	local m = newTemplate("GiantRobot")
	local steel, dark, paint = RGB(176, 182, 194), RGB(52, 56, 68), RGB(34, 104, 222)
	local yellow, red, off = RGB(252, 196, 40), RGB(222, 52, 52), RGB(70, 80, 95)
	local concrete = RGB(150, 150, 146)
	-- 1 FOOTINGS: plinth and two big armoured feet
	local s1 = stage(m, 1)
	P(s1, V(40, 2, 36), CFrame.new(0, 1, 0), concrete, M.Concrete)
	P(s1, V(41, 0.6, 37), CFrame.new(0, 2.2, 0), yellow, M.SmoothPlastic, { Accent = true })
	for _, sx in { -1, 1 } do
		local x = sx * 10
		sliced(s1, CFrame.new(x, 5, -1.5), V(14, 5, 21), 2, dark, M.DiamondPlate)
		P(s1, V(14.6, 3.4, 5.5), CFrame.new(x, 4.2, -12.4), yellow, M.Metal, { Accent = true }) -- toe cap
		P(s1, V(12, 3.5, 3), CFrame.new(x, 4.2, 9.6), dark, M.Metal) -- heel
		P(s1, V(9.5, 3, 9.5), CFrame.new(x, 9, 0), steel, M.Metal) -- ankle
	end
	-- 2 LEGS: chunky shins with armour plates, knees, blue thighs
	local s2 = stage(m, 2)
	for _, sx in { -1, 1 } do
		local x = sx * 10
		sliced(s2, CFrame.new(x, 17.5, 0), V(10.5, 14, 10.5), 3, steel, M.Metal)
		P(s2, V(11.4, 11, 1.4), CFrame.new(x, 17.5, -5.9), paint, M.SmoothPlastic)
		P(s2, V(3.6, 7, 0.6), CFrame.new(x, 17.5, -6.8), yellow, M.Metal, { Accent = true })
		P(s2, V(12.4, 5, 12.4), CFrame.new(x, 27, 0), dark, M.DiamondPlate) -- knee
		P(s2, V(7.5, 4.4, 1.8), CFrame.new(x, 27, -6.8), yellow, M.Metal, { Accent = true }) -- kneecap
		sliced(s2, CFrame.new(x, 36, 0), V(12, 13, 12), 3, paint, M.SmoothPlastic)
		P(s2, V(1, 10, 6), CFrame.new(x + sx * 6.2, 36, 0), yellow, M.Metal) -- thigh stripe
		bar(s2, V(x + sx * 5.8, 12, 3.6), V(x + sx * 5.8, 24, 3.6), 1.6, RGB(210, 212, 220), M.Metal) -- piston
	end
	-- 3 HIPS: pelvis block, yellow belt, hip joints
	local s3 = stage(m, 3)
	sliced(s3, CFrame.new(0, 45, 0), V(28, 6, 13), 2, dark, M.DiamondPlate)
	P(s3, V(29, 1.8, 13.8), CFrame.new(0, 48.6, 0), yellow, M.Metal, { Accent = true })
	P(s3, V(9, 7, 2), CFrame.new(0, 44, -7), steel, M.Metal)
	for _, sx in { -1, 1 } do
		CX(s3, 3, 7, CFrame.new(sx * 14.6, 45, 0), paint, M.SmoothPlastic)
	end
	-- 4 TORSO: abdomen, big blue chest with steel pecs, reactor core, collar, backpack with thrusters
	local s4 = stage(m, 4)
	sliced(s4, CFrame.new(0, 53, 0), V(20, 6, 12), 2, steel, M.Metal)
	for k = 0, 2 do
		P(s4, V(20.6, 0.5, 12.6), CFrame.new(0, 50.6 + k * 1.6, 0), dark, M.Metal)
	end
	sliced(s4, CFrame.new(0, 65, 0), V(32, 18, 17), 3, paint, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		P(s4, V(13, 8, 2), CFrame.new(sx * 7.6, 67.5, -9) * CFrame.Angles(math.rad(-6), math.rad(sx * -8), 0), steel, M.Metal)
		for k = 0, 3 do
			P(s4, V(5, 0.7, 1), CFrame.new(sx * 12, 58 + k * 1.4, -8.8), dark, M.Metal) -- vents
		end
	end
	P(s4, V(10, 10, 1.6), CFrame.new(0, 61, -8.9), dark, M.Metal)
	P(s4, V(11.4, 1.2, 2), CFrame.new(0, 66.6, -9), yellow, M.Metal, { Accent = true })
	P(s4, V(7.5, 7.5, 1), CFrame.new(0, 61, -9.9), off, M.SmoothPlastic, { PowerLight = true }) -- reactor core
	P(s4, V(5, 1.6, 1), CFrame.new(0, 72, -9), yellow, M.Metal, { Accent = true }) -- emblem
	P(s4, V(18, 3, 14), CFrame.new(0, 75.5, 0), dark, M.DiamondPlate) -- collar
	P(s4, V(16, 16, 7), CFrame.new(0, 65, 11.8), dark, M.DiamondPlate) -- backpack
	for _, tx in { -4.5, 4.5 } do
		C(s4, 5, 4, V(tx, 55, 13), steel, M.Metal)
	end
	-- 5 ARMS (ArmL / ArmR groups): pauldrons, upper arm, elbow, armoured forearm, open hand
	local s5 = stage(m, 5)
	for _, sx in { -1, 1 } do
		local g = group(s5, if sx < 0 then "ArmL" else "ArmR")
		local x = sx * 23.5
		P(g, V(14, 10, 15), CFrame.new(x, 70.5, 0), yellow, M.Metal, { Accent = true }) -- pauldron
		P(g, V(15.4, 2.4, 16.4), CFrame.new(x, 76.6, 0), paint, M.SmoothPlastic)
		P(g, V(1.8, 1.8, 0.6), CFrame.new(x, 70.5, -7.8), off, M.SmoothPlastic, { PowerLight = true })
		sliced(g, CFrame.new(x, 59, 0), V(9, 13, 9), 3, steel, M.Metal) -- upper arm
		P(g, V(10.6, 3.6, 10.6), CFrame.new(x, 51, 0), dark, M.DiamondPlate) -- elbow
		sliced(g, CFrame.new(x, 43, -0.5), V(11.5, 13, 11.5), 3, paint, M.SmoothPlastic) -- forearm
		P(g, V(1.2, 9, 7), CFrame.new(x + sx * 6.2, 43, -0.5), yellow, M.Metal, { Accent = true })
		P(g, V(12, 1.8, 12), CFrame.new(x, 35.7, -0.5), dark, M.Metal) -- wrist
		P(g, V(10, 5.5, 8.5), CFrame.new(x, 32.2, -0.5), dark, M.DiamondPlate) -- palm
		for k = -1, 1 do
			P(g, V(2.6, 4.6, 2.6), CFrame.new(x + k * 3.2, 27.6, -2.5), steel, M.Metal) -- fingers
		end
		P(g, V(2.4, 4, 2.4), CFrame.new(x - sx * 5.8, 30.8, -2.5), steel, M.Metal) -- thumb
	end
	-- 6 HEAD (Head group): neck, helmet, faceplate with eyes and grille, ear discs, crest and antenna
	local s6 = stage(m, 6)
	local head = group(s6, "Head")
	P(head, V(9, 3, 9), CFrame.new(0, 78.5, 0), dark, M.DiamondPlate)
	sliced(head, CFrame.new(0, 87, 0), V(20, 14, 17), 3, steel, M.Metal)
	P(head, V(17, 9, 1.2), CFrame.new(0, 86.4, -9), dark, M.Metal)
	for _, ex in { -4.4, 4.4 } do
		P(head, V(4.6, 2.4, 0.8), CFrame.new(ex, 88.2, -9.8), off, M.SmoothPlastic, { PowerLight = true }) -- eyes
	end
	for k = 0, 2 do
		P(head, V(8, 0.6, 0.6), CFrame.new(0, 83 + k * 1.1, -9.8), steel, M.Metal) -- mouth grille
	end
	for _, sx in { -1, 1 } do
		CX(head, 2.4, 8, CFrame.new(sx * 11, 87, 0), paint, M.SmoothPlastic, { Accent = true })
	end
	P(head, V(4, 5, 14), CFrame.new(0, 96.2, 0.5), paint, M.SmoothPlastic, { Accent = true }) -- crest
	P(head, V(20.8, 1.6, 17.8), CFrame.new(0, 94.4, 0), red, M.SmoothPlastic)
	C(head, 6, 0.9, V(6, 98, 3), steel, M.Metal)
	-- 7 POWER UP: antenna tip, chest light strip, foot lights, thruster glows
	local s7 = stage(m, 7)
	ball(s7, 2.4, V(6, 101.8, 3), off, M.SmoothPlastic, { PowerLight = true })
	for k = 0, 4 do
		P(s7, V(1.6, 1.6, 0.6), CFrame.new(-6.4 + k * 3.2, 70.5, -9.3), off, M.SmoothPlastic, { PowerLight = true })
	end
	for _, sx in { -1, 1 } do
		P(s7, V(12, 0.8, 0.8), CFrame.new(sx * 10, 3, -15.4), off, M.SmoothPlastic, { PowerLight = true })
		P(s7, V(3.4, 1, 3.4), CFrame.new(sx * 4.5, 52, 13), off, M.SmoothPlastic, { PowerLight = true })
	end
	return m
end

------------------------------------------------------------------ Volcano Temple (Rare)
function TB.VolcanoTemple(): Model
	local m = newTemplate("VolcanoTemple")
	local basalt, stone, darkStone = RGB(52, 48, 50), RGB(214, 190, 146), RGB(150, 126, 96)
	local rock, rock2, lava, gold = RGB(96, 66, 54), RGB(74, 52, 46), RGB(255, 112, 24), RGB(230, 180, 60)
	-- 1 TEMPLE TERRACE: a broad basalt disc, a wide sandstone terrace and grand front stairs
	local s1 = stage(m, 1)
	C(s1, 3, 56, V(0, 1.5, 0), basalt, M.Basalt)
	ring(s1, 26.5, 20, V(8.6, 1.4, 3), 3.4, RGB(84, 78, 76), M.Basalt)
	octo(s1, 52, 5, V(0, 5.5, 0), darkStone, M.Limestone)
	octo(s1, 50, 0.8, V(0, 8.4, 0), stone, M.Limestone)
	for i = 0, 3 do
		local h = (i + 1) * 1.3
		P(s1, V(18 - i * 1.2, h, 1.6), CFrame.new(0, 3 + h / 2, -30.4 + i * 1.5), stone, M.Limestone)
	end
	-- 2 LOWER CONE / 3 UPPER CONE: eight shrinking octagonal rock tiers make one broad, readable cone
	local widths = { 50, 45, 40, 35, 30, 26, 22, 18, 15 }
	local th = 7
	local y0 = 8.8
	local s2 = stage(m, 2)
	local s3 = stage(m, 3)
	local y = y0
	for i, w in widths do
		octo(if i <= 5 then s2 else s3, w, th, V(0, y + th / 2, 0), if i % 2 == 0 then rock2 else rock, M.Rock)
		y += th
	end
	local top = y
	-- crater: a ring of jagged basalt teeth around the summit
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		P(s3, V(4.6, 5 + (k % 3) * 1.4, 3.2), CFrame.new(math.cos(a) * 6.6, top + 2.5, math.sin(a) * 6.6) * CFrame.Angles(0, -a + math.rad(90), math.rad((k % 2) * 8 - 4)), basalt, M.Basalt)
	end
	-- a few big rock shoulders break the stepped outline
	for _, a in { 0.9, 2.3, 3.9, 5.4 } do
		local r = 21
		W(s2, V(11, 13, 12), CFrame.lookAt(V(math.cos(a) * r, 17, math.sin(a) * r), V(0, 17, 0)) * CFrame.Angles(0, math.pi, 0), basalt, M.Basalt)
	end
	-- 4 TEMPLE FACADE: a columned temple set into the front slope, flanked by tall brazier pillars
	local s4 = stage(m, 4)
	local fz = -24
	P(s4, V(24, 2, 10), CFrame.new(0, 9.8, fz), darkStone, M.Limestone)
	P(s4, V(9, 10, 0.6), CFrame.new(0, 15.8, -25.3), RGB(34, 24, 22), M.Slate) -- dark doorway
	for _, cx in { -8, -2.7, 2.7, 8 } do
		sliced(s4, CFrame.new(cx, 15.8, fz - 3), V(2.4, 10, 2.4), 2, stone, M.Limestone)
		P(s4, V(3.2, 1, 3.2), CFrame.new(cx, 21.3, fz - 3), gold, M.Metal, { Accent = true })
	end
	P(s4, V(23, 1.8, 8), CFrame.new(0, 22.7, fz - 2), stone, M.Limestone)
	P(s4, V(17, 1.8, 6), CFrame.new(0, 24.5, fz - 2), darkStone, M.Limestone, { Accent = true })
	P(s4, V(9, 1.8, 4), CFrame.new(0, 26.3, fz - 2), stone, M.Limestone)
	for _, sx in { -1, 1 } do
		sliced(s4, CFrame.new(sx * 15, 15, -27), V(3.6, 12, 3.6), 2, stone, M.Limestone)
		P(s4, V(5.4, 1.6, 5.4), CFrame.new(sx * 15, 21.8, -27), gold, M.Metal, { Accent = true })
	end
	-- 5 LAVA FLOWS: two rivers framing the temple and one down the back, spilling from the crater
	local s5 = stage(m, 5)
	for _, a in { 3.6, 5.8, 1.6 } do
		for j, w in widths do
			local r = w * 0.47
			local pos = V(math.cos(a) * r, y0 + (j - 0.5) * th, math.sin(a) * r)
			P(s5, V(2.6, th + 0.4, 1), CFrame.lookAt(pos, V(0, pos.Y, 0)), lava, M.Neon, { Lava = true, NoDamage = true })
		end
		P(s5, V(2.6, 1, 6), CFrame.new(math.cos(a) * 8, top - 1, math.sin(a) * 8) * CFrame.Angles(0, -a + math.rad(90), math.rad(-35)), lava, M.Neon, { Lava = true, NoDamage = true })
	end
	C(s5, 1.2, 11, V(0, top + 1.4, 0), lava, M.Neon, { Lava = true, NoDamage = true })
	-- 6 ERUPTION READY: the idol wakes, the braziers light and a lava moat rings the base
	local s6 = stage(m, 6)
	P(s6, V(4.6, 6.5, 1.2), CFrame.new(0, 14.1, -25.9), gold, M.Metal, { Accent = true })
	local core = P(s6, V(2, 2, 0.6), CFrame.new(0, 15.4, -26.6), RGB(90, 230, 255), M.Neon)
	local l = Instance.new("PointLight")
	l.Color = core.Color
	l.Range = 14
	l.Parent = core
	for _, sx in { -1, 1 } do
		local b = P(s6, V(3.4, 1.4, 3.4), CFrame.new(sx * 15, 23.3, -27), RGB(60, 58, 62), M.Metal)
		fire(b, 6)
	end
	ring(s6, 27.2, 24, V(7.4, 0.4, 1.4), 3.2, lava, M.Neon, { Lava = true, NoDamage = true })
	local fx = effects(m)
	local glow = glowPoint(fx, V(0, top + 5, 0), lava, 48, 3)
	local embers = Instance.new("ParticleEmitter")
	embers.Color = ColorSequence.new(lava)
	embers.LightEmission = 1
	embers.Size = NumberSequence.new(0.6, 0)
	embers.Speed = NumberRange.new(8, 16)
	embers.SpreadAngle = Vector2.new(25, 25)
	embers.Rate = 22
	embers.Lifetime = NumberRange.new(1.5, 2.5)
	embers.Acceleration = V(0, -6, 0)
	embers.Parent = glow
	return m
end

------------------------------------------------------------------ UFO (Epic)
function TB.UFO(): Model
	local m = newTemplate("UFO")
	local hull, dark, teal = RGB(196, 204, 216), RGB(86, 92, 108), RGB(40, 200, 214)
	local purple, off, yellow = RGB(120, 76, 214), RGB(70, 80, 95), RGB(250, 200, 50)
	-- 1 LANDING LEGS: a hazard-ringed pad, four splayed legs with feet, a boarding ramp
	local s1 = stage(m, 1)
	C(s1, 1.4, 46, V(0, 0.7, 0), RGB(150, 152, 158), M.Concrete)
	ring(s1, 22, 18, V(6.6, 0.3, 1.6), 1.55, yellow, M.SmoothPlastic, { Accent = true })
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local foot = V(math.cos(a) * 19, 2, math.sin(a) * 19)
		P(s1, V(6, 1.4, 6), CFrame.new(foot.X, 2, foot.Z), dark, M.DiamondPlate)
		bar(s1, foot + V(0, 0.5, 0), V(math.cos(a) * 11, 21, math.sin(a) * 11), 2.4, RGB(160, 166, 176), M.Metal)
		C(s1, 4, 3.4, V(math.cos(a) * 15.6, 10, math.sin(a) * 15.6), dark, M.Metal) -- leg joint
		bar(s1, foot + V(0, 0.5, 0), V(math.cos(a) * 15.6, 10, math.sin(a) * 15.6), 1.4, yellow, M.Metal, { Accent = true }) -- strut
	end
	P(s1, V(7, 0.8, 22), CFrame.new(0, 8.6, -15) * CFrame.Angles(math.rad(-27), 0, 0), RGB(170, 174, 182), M.DiamondPlate) -- boarding ramp
	-- 2 LOWER HULL: a deep stepped underside with a few big lights and the tractor-beam emitter
	local s2 = stage(m, 2)
	C(s2, 3, 26, V(0, 11.5, 0), dark, M.Metal)
	C(s2, 3, 40, V(0, 14.5, 0), hull, M.Metal)
	ring(s2, 16.5, 8, V(2.6, 0.8, 2.6), 12.7, off, M.SmoothPlastic, { PowerLight = true })
	C(s2, 1.5, 10, V(0, 9.4, 0), off, M.SmoothPlastic, { PowerLight = true })
	-- 3 SAUCER RING: the broad disc with a thick teal band and a dark lip
	local s3 = stage(m, 3)
	C(s3, 3, 60, V(0, 17.5, 0), hull, M.Metal)
	ring(s3, 29.6, 20, V(9.6, 2.6, 2), 17.5, teal, M.SmoothPlastic, { Accent = true })
	ring(s3, 28, 24, V(7.6, 0.8, 1.6), 19.3, dark, M.Metal, nil, 0.5)
	-- 4 UPPER HULL: stepped top, vents and four purple fins
	local s4 = stage(m, 4)
	C(s4, 3, 46, V(0, 20.5, 0), hull, M.Metal)
	C(s4, 3, 34, V(0, 23.5, 0), hull, M.Metal)
	ring(s4, 20, 12, V(4.6, 1.2, 1.2), 22.3, dark, M.Metal)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local p = V(math.cos(a) * 15.5, 28.5, math.sin(a) * 15.5)
		W(s4, V(1.6, 7, 9), CFrame.lookAt(p, V(0, 28.5, 0)) * CFrame.Angles(0, math.pi, 0), purple, M.SmoothPlastic, { Accent = true })
	end
	-- 5 DOME: a big glass dome, a waving green pilot, antenna mast
	local s5 = stage(m, 5)
	local dome = ball(s5, 25, V(0, 25, 0), RGB(120, 210, 255), M.Glass)
	dome.Transparency = 0.3
	C(s5, 1.2, 26, V(0, 25.4, 0), teal, M.SmoothPlastic, { Accent = true })
	P(s5, V(4.4, 4.4, 4.4), CFrame.new(0, 28.2, 0), RGB(90, 220, 90), M.SmoothPlastic)
	for _, ex in { -1.1, 1.1 } do
		P(s5, V(1.3, 1.6, 0.3), CFrame.new(ex, 29, -2.25), RGB(10, 10, 10))
	end
	C(s5, 6, 0.9, V(0, 40.5, 0), RGB(200, 204, 212), M.Metal)
	-- 6 LIGHTS: a dozen big rim lights, upper ring, fin beacons, antenna tip
	local s6 = stage(m, 6)
	ring(s6, 30.6, 12, V(2.8, 1.8, 1.4), 17.5, off, M.SmoothPlastic, { PowerLight = true }, 0.5)
	ring(s6, 18.6, 8, V(1.8, 1.4, 1.8), 22.6, off, M.SmoothPlastic, { PowerLight = true }, 0.5)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		ball(s6, 1.8, V(math.cos(a) * 15.5, 32.4, math.sin(a) * 15.5), off, M.SmoothPlastic, { PowerLight = true })
	end
	ball(s6, 2.2, V(0, 44.4, 0), off, M.SmoothPlastic, { PowerLight = true })
	-- the craft stands tall on its landing legs so the lower hull and the beam emitter read from the spawn
	for i = 2, 6 do
		for _, d in m[string.format("Stage_%02d", i)]:GetDescendants() do
			if d:IsA("BasePart") then
				d.CFrame += V(0, 8, 0)
			end
		end
	end
	return m
end

------------------------------------------------------------------ Pirate Ship (Uncommon)
-- Built along Z (bow at -Z), yards braced, then turned 55 degrees so from the spawn both the long hull and the sails read.
function TB.PirateShip(): Model
	local m = newTemplate("PirateShip")
	local hullA, hullB, darkWood = RGB(122, 76, 42), RGB(146, 94, 52), RGB(78, 48, 28)
	local gold, sail, black = RGB(232, 184, 60), RGB(244, 238, 222), RGB(28, 28, 32)
	local off = RGB(90, 70, 50)
	-- 1 KEEL: cradle blocks, keel and rudder
	local s1 = stage(m, 1)
	for _, z in { -13, 0, 13 } do
		P(s1, V(14, 3, 3), CFrame.new(0, 1.5, z), RGB(140, 140, 140), M.Concrete)
	end
	P(s1, V(2.6, 3, 46), CFrame.new(0, 4.5, 0), darkWood, M.Wood)
	P(s1, V(1.2, 9, 4), CFrame.new(0, 8, 24), darkWood, M.Wood) -- rudder
	-- 2 HULL: five widening tiers, a pointed bow, a dark gun-port band and a gold top stripe
	local s2 = stage(m, 2)
	for i = 0, 4 do
		local yy = 6.6 + i * 2.6
		local w = 6 + i * 2.4
		local len = 32 + i * 3.5
		local col = if i == 3 then RGB(52, 36, 26) else (if i % 2 == 0 then hullA else hullB)
		P(s2, V(w, 2.6, len), CFrame.new(0, yy, 1), col, M.WoodPlanks)
		P(s2, V(w * 0.62, 2.6, 4), CFrame.new(0, yy, 1 - len / 2 - 2), col, M.WoodPlanks)
		P(s2, V(w * 0.28, 2.6, 3), CFrame.new(0, yy, 1 - len / 2 - 5.5), col, M.WoodPlanks)
	end
	for _, sx in { -1, 1 } do
		for k = 0, 3 do
			P(s2, V(0.4, 1.6, 2), CFrame.new(sx * 7.75, 14.4, -12 + k * 8), black, M.SmoothPlastic) -- gun ports
		end
	end
	P(s2, V(16.4, 1, 47), CFrame.new(0, 18.6, 1), gold, M.Wood, { Accent = true })
	-- 3 DECK & CABIN: deck planks, gold rails, forecastle, tall stern castle with lit windows
	local s3 = stage(m, 3)
	P(s3, V(15.2, 0.8, 44), CFrame.new(0, 19.5, 1), RGB(176, 124, 72), M.WoodPlanks)
	for _, sx in { -1, 1 } do
		P(s3, V(0.8, 1.4, 40), CFrame.new(sx * 7.6, 20.6, 0), gold, M.Wood, { Accent = true })
	end
	P(s3, V(14, 3, 8), CFrame.new(0, 21.4, -17), hullB, M.WoodPlanks) -- forecastle
	sliced(s3, CFrame.new(0, 24, 17.5), V(16, 8, 11), 2, hullA, M.WoodPlanks) -- stern castle
	P(s3, V(16.8, 1, 11.8), CFrame.new(0, 28.5, 17.5), gold, M.Wood, { Accent = true })
	for _, wx in { -4.5, 0, 4.5 } do
		P(s3, V(2.6, 2.6, 0.5), CFrame.new(wx, 24.5, 23.1), off, M.SmoothPlastic, { PowerLight = true }) -- stern windows
	end
	for _, sx in { -1, 1 } do
		P(s3, V(0.5, 2.4, 2.4), CFrame.new(sx * 8.1, 24.5, 17.5), off, M.SmoothPlastic, { PowerLight = true })
	end
	-- 4 MASTS: fore, main and mizzen with yards and a crow's nest
	local s4 = stage(m, 4)
	local masts = { { z = -10, h = 30, base = 20 }, { z = 2, h = 38, base = 20 }, { z = 16, h = 22, base = 29 } }
	-- yards are braced round so the sails still face the spawn after the hull is turned broadside-ish
	local brace = CFrame.Angles(0, math.rad(-28), 0)
	for _, ms in masts do
		C(s4, ms.h, 2.2, V(0, ms.base + ms.h / 2, ms.z), darkWood, M.Wood)
		P(s4, V(23, 1, 1), CFrame.new(0, ms.base + ms.h * 0.47, ms.z) * brace, darkWood, M.Wood)
		P(s4, V(18, 1, 1), CFrame.new(0, ms.base + ms.h * 0.84, ms.z) * brace, darkWood, M.Wood)
	end
	C(s4, 2, 5.4, V(0, 50, 2), darkWood, M.Wood)
	bar(s4, V(0, 18.5, -26), V(0, 23, -32), 1.2, darkWood, M.Wood) -- bowsprit
	-- 5 SAILS: big billowing square sails with a gold hem, and a jib
	local s5 = stage(m, 5)
	for _, ms in masts do
		for k, frac in { 0.28, 0.66 } do
			local w = if k == 1 then 22 else 17
			local h = ms.h * 0.37
			local at = CFrame.new(0, ms.base + ms.h * frac, ms.z) * brace
			P(s5, V(w, h, 0.5), at * CFrame.new(0, 0, -0.9), sail, M.Fabric)
			P(s5, V(w * 0.72, h * 0.74, 0.6), at * CFrame.new(0, -h * 0.05, -1.6), sail, M.Fabric)
			P(s5, V(w + 0.2, 0.6, 0.7), at * CFrame.new(0, -h / 2, -0.9), gold, M.Fabric, { Accent = true })
		end
	end
	W(s5, V(0.4, 13, 10), CFrame.new(0, 28, -22) * CFrame.Angles(0, math.pi, 0), sail, M.Fabric)
	-- 6 CANNONS & FLAG: four cannons a side (Cannon groups), the Jolly Roger, figurehead, stern lanterns, ship's wheel
	local s6 = stage(m, 6)
	for _, sx in { -1, 1 } do
		for k = 0, 3 do
			local g = group(s6, "Cannon")
			local z = -12 + k * 8
			P(g, V(2.4, 1.2, 2.2), CFrame.new(sx * 6.2, 20.5, z), darkWood, M.Wood)
			CX(g, 5, 1.6, CFrame.new(sx * 8.4, 21.4, z), black, M.Metal)
		end
	end
	P(s6, V(0.3, 6, 9), CFrame.new(0, 62, 6.4), black, M.Fabric) -- flag
	P(s6, V(0.4, 2.2, 2.2), CFrame.new(0, 62.6, 6), RGB(240, 240, 236), M.SmoothPlastic) -- skull
	for _, d in { -1, 1 } do
		P(s6, V(0.4, 0.6, 5), CFrame.new(0, 60.4, 6) * CFrame.Angles(math.rad(d * 35), 0, 0), RGB(240, 240, 236), M.SmoothPlastic) -- crossbones
	end
	C(s6, 3, 0.4, V(0, 58.5, 2), darkWood, M.Wood)
	P(s6, V(2.4, 4, 4), CFrame.new(0, 17.5, -28.5), gold, M.Metal, { Accent = true }) -- figurehead
	for _, sx in { -1, 1 } do
		P(s6, V(1.4, 2.2, 1.4), CFrame.new(sx * 7.4, 30.4, 22.6), off, M.SmoothPlastic, { PowerLight = true })
	end
	CX(s6, 0.6, 4, CFrame.new(0, 31.2, 13.5) * CFrame.Angles(0, math.rad(90), 0), gold, M.Wood)
	-- turn the whole ship so the long hull reads from the spawn; the braced sails still face it
	local turn = CFrame.Angles(0, math.rad(55), 0)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CFrame = turn * d.CFrame
		end
	end
	return m
end

------------------------------------------------------------------ Dragon Citadel (Mythic)
function TB.DragonCitadel(): Model
	local m = newTemplate("DragonCitadel")
	local rock, stone, dark = RGB(58, 54, 60), RGB(104, 100, 116), RGB(66, 62, 78)
	local roof, scale, scale2 = RGB(92, 52, 150), RGB(196, 34, 44), RGB(140, 22, 34)
	local belly, bone, gold, off = RGB(236, 162, 64), RGB(240, 228, 206), RGB(232, 184, 60), RGB(90, 70, 70)
	-- 1 CRAG: dark rock base
	local s1 = stage(m, 1)
	C(s1, 5, 42, V(0, 2.5, 0), rock, M.Basalt)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		P(s1, V(13, 6, 9), CFrame.new(math.cos(a) * 21, 3, math.sin(a) * 21) * CFrame.Angles(0, -a, math.rad(7)), rock, M.Basalt)
	end
	-- 2 CITADEL WALLS: a ring wall with battlements and a gate
	local s2 = stage(m, 2)
	ring(s2, 22, 18, V(8.2, 10, 3), 10, stone, M.Slate)
	ring(s2, 22, 18, V(2.6, 2.4, 3.4), 16.2, dark, M.Slate, { Accent = true }, 0.25)
	P(s2, V(9, 9, 1.2), CFrame.new(0, 9.5, -23.8), RGB(96, 64, 40), M.WoodPlanks) -- gate
	P(s2, V(11, 1.4, 1.6), CFrame.new(0, 14.5, -24), gold, M.Metal, { Accent = true })
	-- 3 TOWERS: four round-ish towers with glowing window slits
	local s3 = stage(m, 3)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local x, z = math.cos(a) * 22, math.sin(a) * 22
		for k = 0, 2 do
			octo(s3, 10, 6.5, V(x, 8.25 + k * 6.5, z), stone, M.Slate)
		end
		local out = V(x, 0, z).Unit
		P(s3, V(1.4, 3.4, 0.6), CFrame.lookAt(V(x, 18, z) + out * 5, V(x, 18, z) + out * 6), off, M.SmoothPlastic, { PowerLight = true })
	end
	-- 4 SPIRES & KEEP: purple stepped spires on the towers, a tall central keep with banners
	local s4 = stage(m, 4)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local x, z = math.cos(a) * 22, math.sin(a) * 22
		for k = 0, 3 do
			local w = 11 - k * 2.4
			P(s4, V(w, 3, w), CFrame.new(x, 27 + k * 3, z), roof, M.Slate, { Accent = k == 3 })
		end
		C(s4, 3, 0.8, V(x, 39.5, z), gold, M.Metal)
	end
	sliced(s4, CFrame.new(0, 21, 0), V(20, 30, 20), 5, dark, M.Slate)
	P(s4, V(22, 1.6, 22), CFrame.new(0, 36.8, 0), stone, M.Slate)
	for _, bx in { -6, 6 } do
		P(s4, V(4, 12, 0.4), CFrame.new(bx, 26, -10.3), roof, M.Fabric, { Accent = true })
		P(s4, V(4.4, 0.6, 0.6), CFrame.new(bx, 32.2, -10.4), gold, M.Metal)
	end
	-- 5 DRAGON BODY: a big red dragon crouched on the keep, gold belly, legs, spine plates, curling tail
	local s5 = stage(m, 5)
	sliced(s5, CFrame.new(0, 46, 3), V(17, 15, 24), 3, scale, M.SmoothPlastic)
	P(s5, V(13.5, 4.6, 21), CFrame.new(0, 40.6, 1.5), belly, M.SmoothPlastic)
	P(s5, V(13, 10, 7), CFrame.new(0, 47, -10) * CFrame.Angles(math.rad(-18), 0, 0), scale, M.SmoothPlastic) -- chest
	P(s5, V(9.5, 7, 2), CFrame.new(0, 45.5, -13.6) * CFrame.Angles(math.rad(-18), 0, 0), belly, M.SmoothPlastic)
	for _, x in { -8, 8 } do
		for _, z in { -6, 11 } do
			P(s5, V(5.4, 9, 6), CFrame.new(x, 41.8, z), scale2, M.SmoothPlastic)
			P(s5, V(6, 1.6, 7), CFrame.new(x, 38, z - 0.8), scale2, M.SmoothPlastic)
		end
	end
	for k = 0, 5 do
		W(s5, V(1.4, 3.8, 4), CFrame.new(0, 55.4, -5 + k * 3.8), bone, M.SmoothPlastic)
	end
	for k = 1, 8 do
		local s = 6 - k * 0.55
		P(s5, V(s, s, 3.6), CFrame.new(math.sin(k * 0.7) * 9, 44 - k * 1.3, 13 + k * 1.8) * CFrame.Angles(0, math.sin(k * 0.7) * 0.8, 0), if k % 2 == 0 then scale2 else scale, M.SmoothPlastic)
	end
	W(s5, V(1.2, 4, 4), CFrame.new(math.sin(8.4) * 9, 34, 28) * CFrame.Angles(0, math.pi, 0), bone, M.SmoothPlastic) -- tail spike
	-- 6 WINGS (WingL / WingR): long bone spars with big membranes
	local s6 = stage(m, 6)
	for _, sx in { -1, 1 } do
		local g = group(s6, if sx < 0 then "WingL" else "WingR")
		-- a bat-wing fan spread flat towards the spawn: arm spar to the wrist, three fingers, scalloped membranes
		local root = V(sx * 8, 50, 3)
		local wrist = V(sx * 20, 73, 6)
		local tips = { V(sx * 32, 67, 8), V(sx * 30, 53, 8), V(sx * 21, 44, 6) }
		bar(g, root, wrist, 2.6, scale2, M.SmoothPlastic)
		local prev = nil
		for k, t in tips do
			bar(g, wrist, t, 1.4, scale2, M.SmoothPlastic)
			if prev then
				tri(g, wrist, prev, t, 0.6, if k % 2 == 0 then RGB(170, 32, 44) else RGB(130, 24, 36), M.SmoothPlastic)
			end
			prev = t
		end
		tri(g, wrist, tips[3], root, 0.6, RGB(150, 28, 40), M.SmoothPlastic)
		ball(g, 3.4, wrist, bone, M.SmoothPlastic)
		W(g, V(1.2, 4, 3), CFrame.new(wrist + V(0, 2.6, 0)), bone, M.SmoothPlastic) -- wrist claw
	end
	-- 7 HEAD (Head group): long neck rising forward, horned head, glowing eyes, open jaw
	local s7 = stage(m, 7)
	local head = group(s7, "Head")
	for k = 1, 5 do
		P(head, V(7.6 - k * 0.3, 7, 5.6), CFrame.new(0, 49 + k * 3.4, -8 - k * 2.2) * CFrame.Angles(math.rad(-25), 0, 0), if k % 2 == 0 then scale2 else scale, M.SmoothPlastic)
	end
	sliced(head, CFrame.new(0, 70, -21), V(13, 8.5, 12), 2, scale, M.SmoothPlastic)
	for _, sx in { -1, 1 } do
		W(head, V(1.4, 5, 6), CFrame.new(sx * 7.4, 70, -19) * CFrame.Angles(0, math.pi, math.rad(sx * -20)), bone, M.SmoothPlastic) -- cheek frills
	end
	P(head, V(9, 4, 8), CFrame.new(0, 68.4, -29), scale, M.SmoothPlastic) -- snout
	P(head, V(8, 2, 7.4), CFrame.new(0, 65.2, -28) * CFrame.Angles(math.rad(12), 0, 0), scale2, M.SmoothPlastic) -- jaw
	for _, x in { -3.4, 3.4 } do
		P(head, V(2.4, 1.5, 0.5), CFrame.new(x, 71.8, -27.1), off, M.SmoothPlastic, { PowerLight = true }) -- eyes
		W(head, V(1.8, 9, 5), CFrame.new(x * 1.5, 77, -17.5) * CFrame.Angles(math.rad(-30), 0, math.rad(x * -4)), bone, M.SmoothPlastic) -- horns
		P(head, V(1, 1.4, 1), CFrame.new(x * 0.5, 66.6, -32.6), bone, M.SmoothPlastic) -- fangs
	end
	-- 8 DRAGONFIRE: braziers on the spires' bases and a glowing breath at the jaw
	local s8 = stage(m, 8)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local x, z = math.cos(a) * 22, math.sin(a) * 22
		local b = P(s8, V(3, 1.6, 3), CFrame.new(x, 41.8, z), RGB(40, 35, 35), M.Metal)
		fire(b, 7)
		P(s8, V(2, 1, 2), CFrame.new(x, 43, z), RGB(255, 120, 30), M.Neon, { Lava = true, NoDamage = true })
	end
	P(s8, V(3.6, 2.6, 2), CFrame.new(0, 66.6, -31.6), RGB(255, 130, 40), M.Neon, { Lava = true, NoDamage = true })
	local fx = effects(m)
	local flame = glowPoint(fx, V(0, 66.6, -33), RGB(255, 140, 40), 40, 3)
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(RGB(255, 200, 60), RGB(255, 60, 20))
	e.LightEmission = 1
	e.Size = NumberSequence.new(2, 5)
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Speed = NumberRange.new(20, 28)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Lifetime = NumberRange.new(0.5, 0.8)
	e.Rate = 30
	e.EmissionDirection = Enum.NormalId.Front
	e.Parent = flame
	local _ = gold
	return m
end

TB.Names = { "GiantRobot", "VolcanoTemple", "UFO", "PirateShip", "DragonCitadel" }

function TB.BuildAll(): string
	local out = {}
	for _, name in TB.Names do
		local m = TB[name]()
		m.WorldPivot = CFrame.new()
		local n, maxR, top = 0, 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
				local flat = V(d.Position.X, 0, d.Position.Z).Magnitude + math.max(d.Size.X, d.Size.Z) / 2
				maxR = math.max(maxR, flat)
				top = math.max(top, d.Position.Y + d.Size.Y / 2)
			end
		end
		local stages = 0
		for _, c in m:GetChildren() do
			if c.Name:match("^Stage_") then
				stages += 1
			end
		end
		table.insert(out, string.format("%s=%d parts, %d stages, r=%.0f h=%.0f", name, n, stages, maxR, top))
	end
	return table.concat(out, "\n")
end

return TB
