--!nonstrict
-- EDIT-TIME GENERATOR for the expanded build roster (same convention as TemplateBuilder,
-- see docs/BUILD_AUTHORING.md). Footprints stay inside a 30-stud radius so the Giant
-- modifier (x1.25) still fits the platform.
-- Run: require(game.ServerStorage.DevTools.TemplateBuilder2:Clone()).BuildAll()
local ServerStorage = game:GetService("ServerStorage")

local TB = {}

------------------------------------------------------------------ helpers
local function P(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material?, attrs: { [string]: any }?): BasePart
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
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
	p.Material = material or Enum.Material.SmoothPlastic
	for k, v in attrs or {} do
		p:SetAttribute(k, v)
	end
	p.Parent = parent
	return p
end

-- vertical cylinder centered at pos
local function C(parent: Instance, height: number, diameter: number, pos: Vector3, color: Color3, material: Enum.Material?, attrs: { [string]: any }?): BasePart
	local p = P(parent, Vector3.new(height, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material, attrs)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- box split into horizontal slices (rises layer by layer)
local function sliced(parent: Instance, center: CFrame, size: Vector3, slices: number, color: Color3, material: Enum.Material?, attrs: { [string]: any }?)
	local h = size.Y / slices
	for i = 0, slices - 1 do
		P(parent, Vector3.new(size.X, h, size.Z), center * CFrame.new(0, -size.Y / 2 + h * (i + 0.5), 0), color, material, attrs)
	end
end

-- blocks arranged around a circle, each facing the center
local function ring(parent: Instance, radius: number, count: number, size: Vector3, y: number, color: Color3, material: Enum.Material?, attrs: { [string]: any }?, offset: number?)
	for i = 0, count - 1 do
		local a = (i + (offset or 0)) / count * math.pi * 2
		local pos = Vector3.new(math.cos(a) * radius, y, math.sin(a) * radius)
		P(parent, size, CFrame.lookAt(pos, Vector3.new(0, y, 0)), color, material, attrs)
	end
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

local function effectsFolder(m: Model): Folder
	local f = Instance.new("Folder")
	f.Name = "Effects"
	f.Parent = m
	return f
end

local function fire(part: BasePart, size: number)
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = 10
	f.Parent = part
end

local RGB = Color3.fromRGB
local M = Enum.Material

------------------------------------------------------------------ COMMON: Block Buddy Statue
function TB.BlockBuddyStatue(): Model
	local m = newTemplate("BlockBuddyStatue")
	local stone = RGB(150, 150, 150)
	local skin = RGB(245, 205, 50)
	local shirt = RGB(40, 120, 220)
	local pants = RGB(80, 170, 70)
	-- 1 Pedestal
	local s1 = stage(m, 1)
	sliced(s1, CFrame.new(0, 2.5, 0), Vector3.new(26, 5, 18), 2, stone, M.Concrete)
	P(s1, Vector3.new(27, 1, 19), CFrame.new(0, 5.5, 0), RGB(120, 120, 125), M.Slate, { Accent = true })
	local plaque = P(s1, Vector3.new(10, 3, 0.4), CFrame.new(0, 2.6, -9.2), RGB(200, 160, 60), M.Metal, { Accent = true })
	local _ = plaque
	-- 2 Legs
	local s2 = stage(m, 2)
	for _, x in { -3.6, 3.6 } do
		sliced(s2, CFrame.new(x, 13, 0), Vector3.new(7, 14, 7), 3, pants, M.SmoothPlastic)
		P(s2, Vector3.new(7.4, 2, 8.4), CFrame.new(x, 7, -0.6), RGB(90, 60, 40), M.SmoothPlastic) -- boots
	end
	-- 3 Torso
	local s3 = stage(m, 3)
	sliced(s3, CFrame.new(0, 27, 0), Vector3.new(14.4, 14, 7), 3, shirt, M.SmoothPlastic)
	P(s3, Vector3.new(14.6, 1.6, 7.2), CFrame.new(0, 20.6, 0), RGB(60, 40, 30), M.SmoothPlastic, { Accent = true }) -- belt
	P(s3, Vector3.new(3, 4, 0.4), CFrame.new(-3.5, 28, -3.6), RGB(250, 160, 40), M.SmoothPlastic) -- tool pocket
	-- 4 Arms (one waving)
	local s4 = stage(m, 4)
	sliced(s4, CFrame.new(-10.8, 27, 0), Vector3.new(7, 14, 7), 2, skin, M.SmoothPlastic)
	local raised = CFrame.new(10.8, 33, 0) * CFrame.Angles(0, 0, math.rad(-35))
	sliced(s4, raised, Vector3.new(7, 14, 7), 2, skin, M.SmoothPlastic)
	-- 5 Head + hard hat + face
	local s5 = stage(m, 5)
	sliced(s5, CFrame.new(0, 38, 0), Vector3.new(8, 8, 8), 2, skin, M.SmoothPlastic)
	P(s5, Vector3.new(1.2, 1.6, 0.3), CFrame.new(-1.6, 39, -4.1), RGB(20, 20, 20))
	P(s5, Vector3.new(1.2, 1.6, 0.3), CFrame.new(1.6, 39, -4.1), RGB(20, 20, 20))
	P(s5, Vector3.new(4, 0.6, 0.3), CFrame.new(0, 36.4, -4.1), RGB(20, 20, 20))
	P(s5, Vector3.new(0.8, 0.8, 0.3), CFrame.new(-2.2, 36.9, -4.1), RGB(20, 20, 20))
	P(s5, Vector3.new(0.8, 0.8, 0.3), CFrame.new(2.2, 36.9, -4.1), RGB(20, 20, 20))
	P(s5, Vector3.new(10, 1, 10), CFrame.new(0, 42.5, -0.5), RGB(255, 140, 20), M.SmoothPlastic, { Accent = true })
	P(s5, Vector3.new(8.4, 3, 8.4), CFrame.new(0, 44.5, 0), RGB(255, 140, 20), M.SmoothPlastic, { Accent = true })
	return m
end

------------------------------------------------------------------ COMMON: Wooden Watchtower
function TB.Watchtower(): Model
	local m = newTemplate("Watchtower")
	local wood = RGB(150, 100, 55)
	local dark = RGB(105, 70, 40)
	local stone = RGB(140, 140, 140)
	-- 1 Footings
	local s1 = stage(m, 1)
	for _, x in { -7, 7 } do
		for _, z in { -7, 7 } do
			P(s1, Vector3.new(4.5, 3, 4.5), CFrame.new(x, 1.5, z), stone, M.Cobblestone)
		end
	end
	P(s1, Vector3.new(20, 0.8, 20), CFrame.new(0, 0.4, 0), RGB(120, 95, 70), M.Ground)
	-- 2 Stilts + braces
	local s2 = stage(m, 2)
	for _, x in { -7, 7 } do
		for _, z in { -7, 7 } do
			sliced(s2, CFrame.new(x, 15, z), Vector3.new(2, 24, 2), 3, wood, M.Wood)
		end
	end
	for _, y in { 9, 19 } do
		for _, side in { { 0, -7, 0 }, { 0, 7, 0 }, { -7, 0, 90 }, { 7, 0, 90 } } do
			local cf = CFrame.new(side[1], y, side[2]) * CFrame.Angles(0, math.rad(side[3]), 0)
			P(s2, Vector3.new(19, 0.8, 0.8), cf * CFrame.Angles(0, 0, math.rad(32)), dark, M.Wood)
			P(s2, Vector3.new(19, 0.8, 0.8), cf * CFrame.Angles(0, 0, math.rad(-32)), dark, M.Wood)
		end
	end
	-- 3 Platform
	local s3 = stage(m, 3)
	for i = -4, 4 do
		P(s3, Vector3.new(2, 1, 20), CFrame.new(i * 2.2, 27.5, 0), if i % 2 == 0 then wood else dark, M.WoodPlanks)
	end
	-- 4 Railing + ladder
	local s4 = stage(m, 4)
	for _, side in { -9.6, 9.6 } do
		P(s4, Vector3.new(20, 0.6, 0.6), CFrame.new(0, 31, side), wood, M.Wood, { Accent = true })
		P(s4, Vector3.new(0.6, 0.6, 20), CFrame.new(side, 31, 0), wood, M.Wood, { Accent = true })
		for k = -2, 2 do
			P(s4, Vector3.new(0.5, 3.5, 0.5), CFrame.new(k * 4.6, 29.7, side), dark, M.Wood)
			P(s4, Vector3.new(0.5, 3.5, 0.5), CFrame.new(side, 29.7, k * 4.6), dark, M.Wood)
		end
	end
	for _, x in { -1.6, 1.6 } do
		P(s4, Vector3.new(0.5, 28, 0.5), CFrame.new(x, 14, -10.4), wood, M.Wood)
	end
	for y = 2, 26, 2.5 do
		P(s4, Vector3.new(3.6, 0.4, 0.5), CFrame.new(0, y, -10.4), dark, M.Wood)
	end
	-- 5 Roof + flag + lantern
	local s5 = stage(m, 5)
	for _, x in { -8.5, 8.5 } do
		for _, z in { -8.5, 8.5 } do
			P(s5, Vector3.new(0.8, 8, 0.8), CFrame.new(x, 32, z), dark, M.Wood)
		end
	end
	for i = 0, 4 do
		local w = 23 - i * 4.5
		P(s5, Vector3.new(w, 1.2, w), CFrame.new(0, 36.6 + i * 1.2, 0), RGB(170, 60, 40), M.WoodPlanks)
	end
	P(s5, Vector3.new(0.4, 9, 0.4), CFrame.new(0, 46, 0), dark, M.Wood)
	P(s5, Vector3.new(0.2, 3, 5), CFrame.new(0, 49, 2.6), RGB(240, 200, 40), M.Fabric, { Accent = true })
	local lantern = P(s5, Vector3.new(1.2, 1.6, 1.2), CFrame.new(0, 34, 0), RGB(255, 210, 120), M.Neon)
	local l = Instance.new("PointLight")
	l.Range = 20
	l.Color = lantern.Color
	l.Parent = lantern
	return m
end

------------------------------------------------------------------ UNCOMMON: Pirate Ship
function TB.PirateShip(): Model
	local m = newTemplate("PirateShip")
	local hull = RGB(110, 70, 40)
	local hull2 = RGB(135, 90, 50)
	local trim = RGB(220, 180, 60)
	local L = 46 -- length along Z
	-- 1 Keel + cradle
	local s1 = stage(m, 1)
	for _, z in { -14, 0, 14 } do
		P(s1, Vector3.new(14, 3, 3), CFrame.new(0, 1.5, z), RGB(130, 130, 130), M.Concrete)
	end
	P(s1, Vector3.new(2.5, 3, L), CFrame.new(0, 4, 0), RGB(80, 50, 30), M.Wood)
	-- 2 Hull: widening layers of planks, pointed bow at -Z
	local s2 = stage(m, 2)
	for i = 0, 4 do
		local y = 5.5 + i * 2.4
		local half = 3 + i * 1.7
		local len = L - 10 + i * 2
		local color = if i % 2 == 0 then hull else hull2
		for _, x in { -half, half } do
			P(s2, Vector3.new(1.2, 2.4, len), CFrame.new(x, y, 3), color, M.WoodPlanks)
		end
		P(s2, Vector3.new(half * 2 + 1.2, 2.4, 1.2), CFrame.new(0, y, 3 + len / 2), color, M.WoodPlanks) -- stern
		-- bow wedges
		W(s2, Vector3.new(1.2, 2.4, 8), CFrame.new(-half / 2, y, 3 - len / 2 - 3.6) * CFrame.Angles(0, math.rad(-25), 0), color, M.WoodPlanks)
		W(s2, Vector3.new(1.2, 2.4, 8), CFrame.new(half / 2, y, 3 - len / 2 - 3.6) * CFrame.Angles(0, math.rad(25), 0), color, M.WoodPlanks)
	end
	for _, x in { -9.8, 9.8 } do
		P(s2, Vector3.new(1.4, 1.2, L - 2), CFrame.new(x, 17.9, 4), trim, M.Wood, { Accent = true }) -- gunwale rails
	end
	-- 3 Deck + cabin
	local s3 = stage(m, 3)
	for i = -3, 3 do
		P(s3, Vector3.new(2.4, 0.8, L - 6), CFrame.new(i * 2.5, 16.6, 4), if i % 2 == 0 then hull2 else RGB(150, 105, 60), M.WoodPlanks)
	end
	sliced(s3, CFrame.new(0, 21, 20), Vector3.new(16, 8, 9), 2, hull, M.WoodPlanks)
	P(s3, Vector3.new(17, 1, 10), CFrame.new(0, 25.5, 20), trim, M.Wood, { Accent = true })
	-- 4 Masts
	local s4 = stage(m, 4)
	for _, z in { -8, 8 } do
		for k = 0, 2 do
			C(s4, 10, 1.6, Vector3.new(0, 22 + k * 10, z), RGB(95, 65, 40), M.Wood)
		end
		P(s4, Vector3.new(16, 0.8, 0.8), CFrame.new(0, 36, z), RGB(95, 65, 40), M.Wood)
		P(s4, Vector3.new(12, 0.8, 0.8), CFrame.new(0, 46, z), RGB(95, 65, 40), M.Wood)
	end
	-- 5 Sails
	local s5 = stage(m, 5)
	for _, z in { -8, 8 } do
		P(s5, Vector3.new(15, 9, 0.4), CFrame.new(0, 31, z - 0.8), RGB(240, 235, 220), M.Fabric)
		P(s5, Vector3.new(11, 8, 0.4), CFrame.new(0, 41.5, z - 0.8), RGB(240, 235, 220), M.Fabric)
	end
	-- 6 Cannons + flag + figurehead
	local s6 = stage(m, 6)
	for _, z in { -8, 0, 8 } do
		for _, x in { -1, 1 } do
			local barrel = P(s6, Vector3.new(4, 1.4, 1.4), CFrame.new(x * 11, 13, z), RGB(30, 30, 35), M.Metal)
			barrel.Shape = Enum.PartType.Cylinder
		end
	end
	P(s6, Vector3.new(0.4, 5, 0.4), CFrame.new(0, 54, -8), RGB(95, 65, 40), M.Wood)
	P(s6, Vector3.new(0.2, 3.4, 5), CFrame.new(0, 55, -5.4), RGB(25, 25, 25), M.Fabric)
	P(s6, Vector3.new(0.3, 1.2, 1.2), CFrame.new(0.1, 55.2, -5.4), RGB(240, 240, 240), M.Fabric)
	P(s6, Vector3.new(2, 3, 5), CFrame.new(0, 14, -26), trim, M.Metal, { Accent = true })
	return m
end

------------------------------------------------------------------ UNCOMMON: Giant Arcade Machine
function TB.ArcadeMachine(): Model
	local m = newTemplate("ArcadeMachine")
	local body = RGB(110, 50, 190)
	local side = RGB(80, 30, 150)
	local black = RGB(25, 25, 30)
	local off = RGB(60, 60, 80)
	-- 1 Base
	local s1 = stage(m, 1)
	sliced(s1, CFrame.new(0, 2, 0), Vector3.new(28, 4, 20), 2, black, M.SmoothPlastic)
	-- 2 Cabinet body
	local s2 = stage(m, 2)
	for _, x in { -12, 12 } do
		sliced(s2, CFrame.new(x, 24, 0), Vector3.new(3, 40, 20), 5, side, M.SmoothPlastic)
	end
	sliced(s2, CFrame.new(0, 24, 8.5), Vector3.new(21, 40, 3), 4, body, M.SmoothPlastic)
	P(s2, Vector3.new(21, 14, 2), CFrame.new(0, 11, -9), body, M.SmoothPlastic)
	P(s2, Vector3.new(4, 2, 0.4), CFrame.new(0, 8, -10.1), RGB(220, 180, 40), M.Metal, { Accent = true }) -- coin slot
	-- 3 Control panel
	local s3 = stage(m, 3)
	P(s3, Vector3.new(21, 2, 9), CFrame.new(0, 19, -9) * CFrame.Angles(math.rad(-15), 0, 0), black, M.SmoothPlastic)
	C(s3, 3, 1, Vector3.new(-5, 21.5, -10), RGB(40, 40, 40), M.Metal)
	P(s3, Vector3.new(2.2, 2.2, 2.2), CFrame.new(-5, 23.5, -10), RGB(230, 40, 40), M.SmoothPlastic)
	for i, color in { RGB(255, 60, 60), RGB(60, 200, 255), RGB(255, 220, 40), RGB(80, 230, 90) } do
		local b = C(s3, 0.6, 2, Vector3.new(1 + i * 2.6, 20.6, -9.6), color, M.Neon)
		local _ = b
	end
	-- 4 Screen
	local s4 = stage(m, 4)
	P(s4, Vector3.new(21, 16, 1), CFrame.new(0, 30, -1) * CFrame.Angles(math.rad(-8), 0, 0), black, M.SmoothPlastic)
	P(s4, Vector3.new(17, 12, 0.4), CFrame.new(0, 30, -1.8) * CFrame.Angles(math.rad(-8), 0, 0), off, M.SmoothPlastic, { PowerLight = true })
	P(s4, Vector3.new(21, 10, 12), CFrame.new(0, 43, 2), body, M.SmoothPlastic)
	-- 5 Marquee + lights
	local s5 = stage(m, 5)
	P(s5, Vector3.new(24, 7, 3), CFrame.new(0, 45, -4.5), black, M.SmoothPlastic)
	P(s5, Vector3.new(21, 5, 0.4), CFrame.new(0, 45, -6.1), off, M.SmoothPlastic, { PowerLight = true })
	for k = 0, 9 do
		P(s5, Vector3.new(1, 1, 1), CFrame.new(-11.5, 6 + k * 4, -10.3), off, M.SmoothPlastic, { PowerLight = true })
		P(s5, Vector3.new(1, 1, 1), CFrame.new(11.5, 6 + k * 4, -10.3), off, M.SmoothPlastic, { PowerLight = true })
	end
	P(s5, Vector3.new(26, 1.4, 22), CFrame.new(0, 49.2, 0), RGB(255, 200, 60), M.SmoothPlastic, { Accent = true })
	return m
end

------------------------------------------------------------------ RARE: Castle Gate
function TB.CastleGate(): Model
	local m = newTemplate("CastleGate")
	local stone = RGB(165, 160, 150)
	local dark = RGB(120, 115, 110)
	local wood = RGB(110, 75, 45)
	-- 1 Foundations
	local s1 = stage(m, 1)
	for x = -2, 2 do
		P(s1, Vector3.new(11.6, 3, 16), CFrame.new(x * 11.6, 1.5, 0), dark, M.Cobblestone)
	end
	-- 2 Towers
	local s2 = stage(m, 2)
	for _, x in { -21, 21 } do
		sliced(s2, CFrame.new(x, 19, 0), Vector3.new(13, 32, 13), 6, stone, M.Brick)
	end
	-- 3 Gate wall with arch opening (built along X)
	local s3 = stage(m, 3)
	for row = 0, 5 do
		for col = -3, 3 do
			local x = col * 4.2
			local y = 5 + row * 4
			local inArch = math.abs(x) < 7 and y < 19
			if not inArch then
				P(s3, Vector3.new(4.2, 4, 6), CFrame.new(x, y, 0), if (row + col) % 2 == 0 then stone else dark, M.Brick)
			end
		end
	end
	for i = -2, 2 do
		P(s3, Vector3.new(3, 2, 6.4), CFrame.new(i * 2.8, 19 + (2 - math.abs(i)) * 0.6, 0), dark, M.Slate, { Accent = true }) -- arch keystones
	end
	-- 4 Battlements
	local s4 = stage(m, 4)
	for col = -7, 7 do
		if col % 2 == 0 then
			P(s4, Vector3.new(2.6, 3, 6.6), CFrame.new(col * 2.4, 28.5, 0), stone, M.Brick)
		end
	end
	for _, x in { -21, 21 } do
		for _, dx in { -5, 0, 5 } do
			for _, dz in { -5, 5 } do
				P(s4, Vector3.new(2.6, 3, 2.6), CFrame.new(x + dx, 36.5, dz), stone, M.Brick)
			end
		end
		P(s4, Vector3.new(14, 1, 14), CFrame.new(x, 35.5, 0), dark, M.Slate, { Accent = true })
	end
	-- 5 Portcullis + doors
	local s5 = stage(m, 5)
	for i = -2, 2 do
		P(s5, Vector3.new(0.6, 14, 0.6), CFrame.new(i * 2.6, 10, -1.5), RGB(60, 60, 65), M.Metal)
	end
	for y = 5, 15, 3.4 do
		P(s5, Vector3.new(12, 0.6, 0.6), CFrame.new(0, y, -1.5), RGB(60, 60, 65), M.Metal)
	end
	for _, x in { -3.4, 3.4 } do
		P(s5, Vector3.new(6.4, 13, 1), CFrame.new(x, 9.5, 1.8), wood, M.WoodPlanks)
	end
	-- 6 Banners + torches
	local s6 = stage(m, 6)
	for _, x in { -21, 21 } do
		P(s6, Vector3.new(6, 14, 0.3), CFrame.new(x, 22, -6.7), RGB(190, 40, 40), M.Fabric, { Accent = true })
		P(s6, Vector3.new(2.4, 2.4, 0.4), CFrame.new(x, 24, -6.9), RGB(240, 200, 60), M.Fabric)
		P(s6, Vector3.new(0.4, 6, 0.4), CFrame.new(x, 42, 0), wood, M.Wood)
		P(s6, Vector3.new(0.2, 3, 4.5), CFrame.new(x, 43.5, 2.4), RGB(40, 90, 200), M.Fabric)
	end
	for _, x in { -8.5, 8.5 } do
		local t = P(s6, Vector3.new(1, 2, 1), CFrame.new(x, 15, -3.6), RGB(60, 50, 40), M.Metal)
		fire(t, 3)
	end
	return m
end

------------------------------------------------------------------ EPIC: UFO
function TB.UFO(): Model
	local m = newTemplate("UFO")
	local hull = RGB(190, 198, 210)
	local dark = RGB(90, 96, 110)
	local off = RGB(70, 80, 95)
	-- 1 Landing legs
	local s1 = stage(m, 1)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local foot = Vector3.new(math.cos(a) * 20, 0.75, math.sin(a) * 20)
		P(s1, Vector3.new(6, 1.5, 6), CFrame.new(foot), dark, M.DiamondPlate)
		local top = Vector3.new(math.cos(a) * 12, 13, math.sin(a) * 12)
		local mid = (foot + top) / 2
		P(s1, Vector3.new(1.6, (top - foot).Magnitude, 1.6), CFrame.lookAt(mid, top) * CFrame.Angles(math.rad(90), 0, 0), RGB(150, 155, 165), M.Metal)
	end
	-- 2 Lower hull
	local s2 = stage(m, 2)
	C(s2, 3, 22, Vector3.new(0, 12.5, 0), dark, M.Metal)
	C(s2, 3, 32, Vector3.new(0, 15.5, 0), hull, M.Metal)
	C(s2, 1.5, 8, Vector3.new(0, 10.5, 0), off, M.SmoothPlastic, { PowerLight = true }) -- tractor beam emitter
	-- 3 Saucer ring
	local s3 = stage(m, 3)
	C(s3, 2.5, 50, Vector3.new(0, 18.2, 0), hull, M.Metal)
	ring(s3, 24.5, 16, Vector3.new(9, 2, 2.5), 18.2, dark, M.Metal, { Accent = true })
	-- 4 Upper hull
	local s4 = stage(m, 4)
	C(s4, 3, 38, Vector3.new(0, 21, 0), hull, M.Metal)
	C(s4, 3, 28, Vector3.new(0, 24, 0), hull, M.Metal)
	ring(s4, 17, 12, Vector3.new(4, 1.2, 1), 22.6, dark, M.Metal)
	-- 5 Dome
	local s5 = stage(m, 5)
	local dome = P(s5, Vector3.new(20, 20, 20), CFrame.new(0, 26, 0), RGB(140, 220, 255), M.Glass)
	dome.Shape = Enum.PartType.Ball
	dome.Transparency = 0.35
	P(s5, Vector3.new(3, 3, 3), CFrame.new(0, 27, 0), RGB(90, 220, 90), M.SmoothPlastic) -- pilot
	P(s5, Vector3.new(1, 1, 0.3), CFrame.new(-0.7, 27.6, -1.55), RGB(10, 10, 10))
	P(s5, Vector3.new(1, 1, 0.3), CFrame.new(0.7, 27.6, -1.55), RGB(10, 10, 10))
	-- 6 Lights
	local s6 = stage(m, 6)
	ring(s6, 24.8, 16, Vector3.new(2, 1.4, 1.4), 18.2, off, M.SmoothPlastic, { PowerLight = true }, 0.5)
	ring(s6, 15.5, 8, Vector3.new(1.4, 1.4, 1.4), 25.8, off, M.SmoothPlastic, { PowerLight = true }, 0.5)
	return m
end

------------------------------------------------------------------ EPIC: Colosseum Arena
function TB.Colosseum(): Model
	local m = newTemplate("Colosseum")
	local stone = RGB(215, 195, 160)
	local dark = RGB(180, 160, 125)
	local sand = RGB(225, 205, 150)
	-- 1 Arena floor
	local s1 = stage(m, 1)
	C(s1, 1.5, 58, Vector3.new(0, 0.75, 0), dark, M.Limestone)
	C(s1, 1, 26, Vector3.new(0, 1.8, 0), sand, M.Sand)
	-- 2..4 tiers of arches (pillar + lintel around the ring)
	local count = 20
	for tier = 1, 3 do
		local s = stage(m, tier + 1)
		local y0 = 1.5 + (tier - 1) * 8
		local r = 27 - (tier - 1) * 0.6
		for i = 0, count - 1 do
			local a = i / count * math.pi * 2
			local pos = Vector3.new(math.cos(a) * r, y0 + 3.5, math.sin(a) * r)
			P(s, Vector3.new(2.6, 7, 2.6), CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0)), stone, M.Limestone)
		end
		ring(s, r, count, Vector3.new(8.8, 1.6, 2.8), y0 + 7.8, dark, M.Limestone, nil, 0.5)
		-- seating steps inside
		ring(s, r - 4 - tier * 2.6, count, Vector3.new(7.5, 2, 3), y0 + 1, stone, M.Limestone, nil, 0.5)
	end
	-- 5 Top wall (outer attic)
	local s5 = stage(m, 5)
	ring(s5, 25.6, count, Vector3.new(8.6, 4, 2.4), 27.6, stone, M.Limestone, { Accent = true }, 0.5)
	ring(s5, 25.6, count, Vector3.new(1.6, 6, 2.6), 28.6, dark, M.Limestone)
	-- 6 Banners + center statue
	local s6 = stage(m, 6)
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		local pos = Vector3.new(math.cos(a) * 26, 33, math.sin(a) * 26)
		P(s6, Vector3.new(0.4, 6, 0.4), CFrame.new(pos), RGB(100, 70, 40), M.Wood)
		P(s6, Vector3.new(0.2, 2.6, 3.6), CFrame.new(pos + Vector3.new(0, 1.6, 0)) * CFrame.Angles(0, -a, 0) * CFrame.new(0, 0, 1.9), if i % 2 == 0 then RGB(190, 40, 40) else RGB(240, 190, 40), M.Fabric)
	end
	sliced(s6, CFrame.new(0, 4.3, 0), Vector3.new(4, 4, 4), 1, dark, M.Marble)
	P(s6, Vector3.new(2.6, 6, 2.6), CFrame.new(0, 9.3, 0), RGB(230, 190, 60), M.Metal, { Accent = true })
	return m
end

------------------------------------------------------------------ LEGENDARY: Mega Fortress Wall
function TB.MegaFortress(): Model
	local m = newTemplate("MegaFortress")
	local stone = RGB(150, 140, 125)
	local dark = RGB(110, 102, 92)
	local earth = RGB(120, 95, 65)
	local wallZ = -4
	-- 1 Earthworks
	local s1 = stage(m, 1)
	for x = -2, 2 do
		P(s1, Vector3.new(12, 3, 16), CFrame.new(x * 12, 1.5, wallZ), earth, M.Ground)
	end
	-- 2 Wall base
	local s2 = stage(m, 2)
	for x = -6, 6 do
		P(s2, Vector3.new(4.4, 6, 10), CFrame.new(x * 4.4, 6, wallZ), if x % 2 == 0 then stone else dark, M.Cobblestone)
	end
	-- 3 Wall rise
	local s3 = stage(m, 3)
	for row = 0, 1 do
		for x = -6, 6 do
			P(s3, Vector3.new(4.4, 6, 9), CFrame.new(x * 4.4, 12 + row * 6, wallZ), if (x + row) % 2 == 0 then dark else stone, M.Cobblestone)
		end
	end
	P(s3, Vector3.new(57, 1, 11), CFrame.new(0, 21.5, wallZ), dark, M.Slate)
	-- 4 Watchtowers (ends + middle)
	local s4 = stage(m, 4)
	for _, x in { -26, 0, 26 } do
		sliced(s4, CFrame.new(x, 17, wallZ), Vector3.new(11, 28, 11), 5, stone, M.Brick)
		P(s4, Vector3.new(12.4, 1.2, 12.4), CFrame.new(x, 31.6, wallZ), dark, M.Slate, { Accent = true })
	end
	-- 5 Battlements on wall and towers
	local s5 = stage(m, 5)
	for x = -12, 12 do
		if x % 2 == 0 and math.abs(x * 2.1) > 6 and math.abs(x * 2.1) < 21 then
			P(s5, Vector3.new(2.2, 2.6, 1.4), CFrame.new(x * 2.1, 23.3, wallZ - 4.8), stone, M.Brick)
			P(s5, Vector3.new(2.2, 2.6, 1.4), CFrame.new(x * 2.1, 23.3, wallZ + 4.8), stone, M.Brick)
		end
	end
	for _, x in { -26, 0, 26 } do
		for _, dx in { -4.5, 0, 4.5 } do
			for _, dz in { -4.5, 4.5 } do
				P(s5, Vector3.new(2.2, 2.6, 2.2), CFrame.new(x + dx, 33.5, wallZ + dz), stone, M.Brick)
			end
		end
	end
	-- 6 Keep behind the wall
	local s6 = stage(m, 6)
	sliced(s6, CFrame.new(0, 13, 14), Vector3.new(18, 22, 12), 4, stone, M.Brick)
	for i = 0, 3 do
		local w = 20 - i * 4.5
		P(s6, Vector3.new(w, 2, 14 - i * 3), CFrame.new(0, 25 + i * 2, 14), RGB(150, 50, 40), M.Slate)
	end
	P(s6, Vector3.new(4, 6, 0.6), CFrame.new(0, 5, 7.8), RGB(90, 60, 35), M.WoodPlanks)
	-- 7 Beacons + banners
	local s7 = stage(m, 7)
	for _, x in { -26, 0, 26 } do
		local bowl = P(s7, Vector3.new(4, 1.6, 4), CFrame.new(x, 35.6, wallZ), RGB(60, 55, 50), M.Metal)
		fire(bowl, 7)
		local glow = P(s7, Vector3.new(2.4, 1.2, 2.4), CFrame.new(x, 36.8, wallZ), RGB(255, 140, 40), M.Neon, { Lava = true, NoDamage = true })
		local _ = glow
		P(s7, Vector3.new(5, 12, 0.3), CFrame.new(x, 24, wallZ - 5.7), RGB(200, 160, 40), M.Fabric, { Accent = true })
	end
	return m
end

------------------------------------------------------------------ MYTHIC: Dragon Citadel
function TB.DragonCitadel(): Model
	local m = newTemplate("DragonCitadel")
	local rock = RGB(70, 60, 62)
	local stone = RGB(105, 95, 110)
	local dark = RGB(55, 48, 60)
	local scale = RGB(150, 30, 40)
	local belly = RGB(220, 150, 60)
	local off = RGB(90, 70, 70)
	-- 1 Crag
	local s1 = stage(m, 1)
	for i = 0, 9 do
		local a = i / 10 * math.pi * 2
		P(s1, Vector3.new(14, 6, 10), CFrame.new(math.cos(a) * 20, 3, math.sin(a) * 20) * CFrame.Angles(0, -a, math.rad(6)), rock, M.Basalt)
	end
	C(s1, 6, 34, Vector3.new(0, 3, 0), rock, M.Basalt)
	-- 2 Citadel walls
	local s2 = stage(m, 2)
	ring(s2, 22, 18, Vector3.new(8.2, 8, 3), 10, stone, M.Brick)
	ring(s2, 22, 18, Vector3.new(2.4, 2.4, 3.4), 15.2, dark, M.Brick, { Accent = true }, 0.25)
	-- 3 Corner towers
	local s3 = stage(m, 3)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local x, z = math.cos(a) * 22, math.sin(a) * 22
		sliced(s3, CFrame.new(x, 17, z), Vector3.new(8, 22, 8), 4, stone, M.Brick)
	end
	-- 4 Spires (stepped cones) + central keep
	local s4 = stage(m, 4)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local x, z = math.cos(a) * 22, math.sin(a) * 22
		for k = 0, 3 do
			local w = 9 - k * 2
			P(s4, Vector3.new(w, 3, w), CFrame.new(x, 29.5 + k * 3, z), RGB(70, 40, 110), M.Slate, { Accent = k == 3 })
		end
	end
	sliced(s4, CFrame.new(0, 18, 0), Vector3.new(18, 24, 18), 4, dark, M.Brick)
	P(s4, Vector3.new(20, 1.5, 20), CFrame.new(0, 30.75, 0), stone, M.Slate)
	-- 5 Dragon body perched on the keep
	local s5 = stage(m, 5)
	sliced(s5, CFrame.new(0, 36, 2), Vector3.new(10, 9, 18), 3, scale, M.SmoothPlastic)
	P(s5, Vector3.new(8, 3, 14), CFrame.new(0, 33, 1), belly, M.SmoothPlastic)
	for _, x in { -4, 4 } do
		for _, z in { -5, 8 } do
			P(s5, Vector3.new(3, 6, 3), CFrame.new(x, 33, z), scale, M.SmoothPlastic)
		end
	end
	-- tail curling behind
	for k = 1, 6 do
		local s = 5 - k * 0.6
		P(s5, Vector3.new(s, s, 4), CFrame.new(math.sin(k * 0.5) * 5, 35 - k * 0.6, 11 + k * 3.4), scale, M.SmoothPlastic)
	end
	-- 6 Wings
	local s6 = stage(m, 6)
	for _, sx in { -1, 1 } do
		for k = 0, 2 do
			local cf = CFrame.new(sx * (9 + k * 5), 42 + k * 3, 2 - k * 1.5) * CFrame.Angles(0, 0, math.rad(sx * (20 + k * 10)))
			W(s6, Vector3.new(1, 10 - k * 1.5, 14 - k * 2), cf, if k % 2 == 0 then scale else RGB(120, 25, 35), M.SmoothPlastic)
		end
		P(s6, Vector3.new(16, 1.2, 1.2), CFrame.new(sx * 13, 46, 2) * CFrame.Angles(0, 0, math.rad(sx * 30)), RGB(90, 20, 25), M.SmoothPlastic)
	end
	-- 7 Neck + head
	local s7 = stage(m, 7)
	for k = 1, 4 do
		P(s7, Vector3.new(5, 5, 4), CFrame.new(0, 39 + k * 2.8, -6 - k * 2), scale, M.SmoothPlastic)
	end
	sliced(s7, CFrame.new(0, 52, -17), Vector3.new(8, 6, 10), 2, scale, M.SmoothPlastic)
	P(s7, Vector3.new(6, 2.6, 6), CFrame.new(0, 50, -23), scale, M.SmoothPlastic) -- snout
	for _, x in { -2.6, 2.6 } do
		P(s7, Vector3.new(1.4, 1, 0.4), CFrame.new(x, 53.4, -22.1), off, M.SmoothPlastic, { PowerLight = true }) -- eyes
		W(s7, Vector3.new(1, 4, 3), CFrame.new(x, 56.5, -15) * CFrame.Angles(math.rad(-20), 0, 0), RGB(240, 230, 210), M.SmoothPlastic) -- horns
	end
	-- 8 Dragonfire braziers
	local s8 = stage(m, 8)
	for i = 0, 3 do
		local a = i / 4 * math.pi * 2 + math.pi / 4
		local x, z = math.cos(a) * 22, math.sin(a) * 22
		local b = P(s8, Vector3.new(3, 1.6, 3), CFrame.new(x, 41.5, z), RGB(40, 35, 35), M.Metal)
		fire(b, 8)
		P(s8, Vector3.new(2, 1, 2), CFrame.new(x, 42.6, z), RGB(255, 120, 30), M.Neon, { Lava = true, NoDamage = true })
	end
	P(s8, Vector3.new(3, 3, 3), CFrame.new(0, 49.5, -26.5), RGB(255, 130, 40), M.Neon, { Lava = true, NoDamage = true }) -- breath
	local fx = effectsFolder(m)
	local flame = P(fx, Vector3.new(2, 2, 2), CFrame.new(0, 49.5, -28), RGB(255, 130, 40), M.Neon, { NoDamage = true })
	flame.Transparency = 1
	flame.CanCollide = false
	local e = Instance.new("ParticleEmitter")
	e.Color = ColorSequence.new(RGB(255, 200, 60), RGB(255, 60, 20))
	e.LightEmission = 1
	e.Size = NumberSequence.new(2, 5)
	e.Transparency = NumberSequence.new(0.1, 1)
	e.Speed = NumberRange.new(25, 35)
	e.SpreadAngle = Vector2.new(12, 12)
	e.Lifetime = NumberRange.new(0.6, 0.9)
	e.Rate = 60
	e.EmissionDirection = Enum.NormalId.Front
	e.Parent = flame
	local light = Instance.new("PointLight")
	light.Color = RGB(255, 140, 40)
	light.Range = 40
	light.Brightness = 3
	light.Parent = flame
	return m
end

-- (colossal) PirateShip is generated by TemplateBuilderColossal now
TB.Names = { "BlockBuddyStatue", "Watchtower", "CastleGate", "UFO", "Colosseum", "MegaFortress", "DragonCitadel" }

function TB.BuildAll(): string
	local out = {}
	for _, name in TB.Names do
		local m = TB[name]()
		m.WorldPivot = CFrame.new()
		local n, maxR, top = 0, 0, 0
		for _, d in m:GetDescendants() do
			if d:IsA("BasePart") then
				n += 1
				local flat = Vector3.new(d.Position.X, 0, d.Position.Z).Magnitude + math.max(d.Size.X, d.Size.Z) / 2
				maxR = math.max(maxR, flat)
				top = math.max(top, d.Position.Y + d.Size.Y / 2)
			end
		end
		table.insert(out, string.format("%s=%d parts r=%.0f h=%.0f", name, n, maxR, top))
	end
	return table.concat(out, "\n")
end

return TB
