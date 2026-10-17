--!nonstrict
-- EDIT-TIME GENERATOR for the first MASTER PROJECT: the Orbital Station (ServerStorage.BuildTemplates.OrbitalStation).
-- Same convention as the other generators (docs/BUILD_AUTHORING.md): Stage_01 .. Stage_10 Models, PowerLight parts light up on
-- completion, named groups (RingLower, RingUpper, SolarL, SolarR, Dish) that the OrbitalActivation spectacle animates on the client.
-- Run: require(game.ServerStorage.DevTools.TemplateBuilder4:Clone()).BuildAll()
local ServerStorage = game:GetService("ServerStorage")

local TB = {}
local RGB = Color3.fromRGB
local M = Enum.Material
local V = Vector3.new

local function P(parent, size, cf, color, material, attrs)
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

-- vertical cylinder centred at pos
local function C(parent, height, diameter, pos, color, material, attrs)
	local p = P(parent, V(height, diameter, diameter), CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90)), color, material, attrs)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- cylinder whose axis points along `dir`, centred at pos
local function CD(parent, length, diameter, pos, dir, color, material, attrs)
	local p = P(parent, V(length, diameter, diameter), CFrame.lookAt(pos, pos + dir) * CFrame.Angles(0, math.rad(90), 0), color, material, attrs)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function bar(parent, a, b, t, color, material, attrs)
	return P(parent, V(t, t, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material, attrs)
end

local function ball(parent, d, pos, color, material, attrs)
	local p = P(parent, V(d, d, d), CFrame.new(pos), color, material, attrs)
	p.Shape = Enum.PartType.Ball
	return p
end

local function stage(m, i)
	local s = Instance.new("Model")
	s.Name = string.format("Stage_%02d", i)
	s.Parent = m
	return s
end

local function group(parent, name)
	local g = Instance.new("Model")
	g.Name = name
	g.Parent = parent
	return g
end

local HULL, DARK, STEEL, ORANGE, GOLD = RGB(214, 220, 232), RGB(60, 66, 82), RGB(150, 158, 174), RGB(255, 132, 52), RGB(240, 190, 60)
local OFF, SOLAR, SOLAR2 = RGB(70, 82, 100), RGB(26, 50, 112), RGB(70, 110, 190)

function TB.OrbitalStation()
	local folder = ServerStorage:FindFirstChild("BuildTemplates")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "BuildTemplates"
		folder.Parent = ServerStorage
	end
	local old = folder:FindFirstChild("OrbitalStation")
	if old then
		old:Destroy()
	end
	local m = Instance.new("Model")
	m.Name = "OrbitalStation"
	m.Parent = folder

	-- 1 LAUNCH BASE: a round pad with hazard markings and four gantry towers
	local s1 = stage(m, 1)
	C(s1, 3, 74, V(0, 1.5, 0), RGB(150, 152, 160), M.Concrete)
	C(s1, 0.6, 52, V(0, 3.2, 0), DARK, M.DiamondPlate)
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		P(s1, V(7, 0.4, 1.6), CFrame.lookAt(V(math.cos(a) * 33, 3.1, math.sin(a) * 33), V(0, 3.1, 0)), if i % 2 == 0 then GOLD else DARK, M.SmoothPlastic, { Accent = true })
	end
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			local x, z = sx * 24, sz * 24
			for _, dx in { -1.6, 1.6 } do
				for _, dz in { -1.6, 1.6 } do
					P(s1, V(1.1, 26, 1.1), CFrame.new(x + dx, 16, z + dz), STEEL, M.Metal)
				end
			end
			for y = 8, 24, 8 do
				P(s1, V(4.6, 0.7, 4.6), CFrame.new(x, y, z), DARK, M.DiamondPlate)
			end
			P(s1, V(6, 1, 6), CFrame.new(x, 29.5, z), ORANGE, M.Metal, { Accent = true })
		end
	end

	-- 2 CENTRAL CORE: a tall banded tower rising from the pad
	local s2 = stage(m, 2)
	C(s2, 12, 18, V(0, 9, 0), HULL, M.Metal)
	C(s2, 28, 13, V(0, 29, 0), HULL, M.Metal)
	C(s2, 16, 10.5, V(0, 51, 0), HULL, M.Metal)
	for _, y in { 4.5, 16, 24, 33, 42 } do
		C(s2, 1.4, 14.4, V(0, y, 0), if y == 24 then ORANGE else DARK, M.Metal, if y == 24 then { Accent = true } else nil)
	end
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		P(s2, V(1.4, 20, 1.4), CFrame.new(math.cos(a) * 7.4, 29, math.sin(a) * 7.4), STEEL, M.Metal)
	end

	-- 3 LOWER RING: a wide habitat ring around the core on six spokes
	local s3 = stage(m, 3)
	local lower = group(s3, "RingLower")
	for i = 0, 27 do
		local a = i / 28 * math.pi * 2
		P(lower, V(6.9, 4.2, 5.4), CFrame.lookAt(V(math.cos(a) * 29, 26, math.sin(a) * 29), V(0, 26, 0)), HULL, M.Metal)
		P(lower, V(6.9, 0.8, 6.2), CFrame.lookAt(V(math.cos(a) * 29, 28.4, math.sin(a) * 29), V(0, 28.4, 0)), if i % 7 == 0 then ORANGE else DARK, M.Metal, if i % 7 == 0 then { Accent = true } else nil)
	end
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		bar(s3, V(math.cos(a) * 6.5, 26, math.sin(a) * 6.5), V(math.cos(a) * 27, 26, math.sin(a) * 27), 2.4, STEEL, M.Metal)
	end

	-- 4 UPPER RING: a smaller, higher ring that counter-rotates
	local s4 = stage(m, 4)
	local upper = group(s4, "RingUpper")
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		P(upper, V(6.4, 3.4, 4.4), CFrame.lookAt(V(math.cos(a) * 22, 43, math.sin(a) * 22), V(0, 43, 0)), STEEL, M.Metal)
		P(upper, V(6.4, 0.7, 5.2), CFrame.lookAt(V(math.cos(a) * 22, 45, math.sin(a) * 22), V(0, 45, 0)), if i % 6 == 0 then ORANGE else HULL, M.Metal, if i % 6 == 0 then { Accent = true } else nil)
	end
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + math.pi / 6
		bar(s4, V(math.cos(a) * 6, 43, math.sin(a) * 6), V(math.cos(a) * 20.5, 43, math.sin(a) * 20.5), 2, STEEL, M.Metal)
	end

	-- 5 DOCKING ARMS: four long arms reaching out above the rings, each ending in a docking collar
	local s5 = stage(m, 5)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local d = V(math.cos(a), 0, math.sin(a))
		bar(s5, V(d.X * 5, 52, d.Z * 5), V(d.X * 38, 52, d.Z * 38), 3.2, HULL, M.Metal)
		bar(s5, V(d.X * 10, 49.5, d.Z * 10), V(d.X * 34, 52, d.Z * 34), 1.4, STEEL, M.Metal)
		CD(s5, 9, 9, V(d.X * 40, 52, d.Z * 40), d, DARK, M.Metal)
		CD(s5, 1.4, 11, V(d.X * 44.8, 52, d.Z * 44.8), d, ORANGE, M.Metal, { Accent = true })
		ball(s5, 7.5, V(d.X * 33, 55.5, d.Z * 33), HULL, M.Metal)
	end

	-- 6 POWER MODULES: six fuel-cell capsules around the lower ring (their caps light up when the station powers on)
	local s6 = stage(m, 6)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + math.pi / 6
		local x, z = math.cos(a) * 34.5, math.sin(a) * 34.5
		C(s6, 15, 5.6, V(x, 26, z), DARK, M.Metal)
		C(s6, 1.2, 6.2, V(x, 19, z), ORANGE, M.Metal, { Accent = true })
		C(s6, 1.2, 6.2, V(x, 33, z), ORANGE, M.Metal, { Accent = true })
		C(s6, 1, 4, V(x, 34.2, z), OFF, M.SmoothPlastic, { PowerLight = true })
		bar(s6, V(math.cos(a) * 31, 26, math.sin(a) * 31), V(x, 26, z), 1.4, STEEL, M.Metal)
	end

	-- 7 SOLAR ARRAYS (SolarL / SolarR): long booms with three big panels each
	local s7 = stage(m, 7)
	for _, sx in { -1, 1 } do
		local g = group(s7, if sx < 0 then "SolarL" else "SolarR")
		bar(g, V(sx * 8, 47, 0), V(sx * 66, 47, 0), 2, STEEL, M.Metal)
		for i = 0, 2 do
			local x = sx * (21 + i * 17)
			P(g, V(15.4, 0.7, 24), CFrame.new(x, 47, 0), SOLAR, M.SmoothPlastic)
			P(g, V(15.8, 0.9, 1), CFrame.new(x, 47, 12.3), HULL, M.Metal)
			P(g, V(15.8, 0.9, 1), CFrame.new(x, 47, -12.3), HULL, M.Metal)
			for k = -1, 1 do
				P(g, V(0.4, 0.85, 23.2), CFrame.new(x + k * 5, 47.05, 0), SOLAR2, M.SmoothPlastic)
			end
			for k = -2, 2 do
				P(g, V(15, 0.8, 0.3), CFrame.new(x, 47.06, k * 4.6), SOLAR2, M.SmoothPlastic)
			end
		end
		P(g, V(3, 3, 3), CFrame.new(sx * 66, 47, 0), ORANGE, M.Metal, { Accent = true })
	end

	-- 8 COMMAND MODULE: a deck and a big glass dome on top of the core
	local s8 = stage(m, 8)
	C(s8, 4, 22, V(0, 61, 0), HULL, M.Metal)
	C(s8, 1.2, 24, V(0, 63.2, 0), ORANGE, M.Metal, { Accent = true })
	C(s8, 9, 17, V(0, 68, 0), DARK, M.Metal)
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		P(s8, V(3.6, 4, 0.6), CFrame.lookAt(V(math.cos(a) * 8.6, 68, math.sin(a) * 8.6), V(0, 68, 0)), RGB(150, 214, 255), M.Glass, nil).Transparency = 0.25
	end
	local dome = ball(s8, 18, V(0, 74, 0), RGB(140, 214, 255), M.Glass)
	dome.Transparency = 0.4
	C(s8, 1.4, 10, V(0, 78.6, 0), STEEL, M.Metal)

	-- 9 ANTENNA & DISH: a tall mast, a tilting dish (Dish) and beacon tips
	local s9 = stage(m, 9)
	C(s9, 24, 1.6, V(0, 91, 0), STEEL, M.Metal)
	local dish = group(s9, "Dish")
	local dishAt = V(0, 86, 0)
	CD(dish, 1.2, 15, dishAt + V(0, 0, 0), V(0.5, 1, -0.4).Unit, HULL, M.Metal)
	CD(dish, 6, 1, dishAt + V(0.35, 3.2, -0.3), V(0.5, 1, -0.4).Unit, STEEL, M.Metal)
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		bar(s9, V(0, 80, 0), V(math.cos(a) * 9, 98, math.sin(a) * 9), 0.5, STEEL, M.Metal)
		ball(s9, 1.6, V(math.cos(a) * 9, 98, math.sin(a) * 9), OFF, M.SmoothPlastic, { PowerLight = true })
	end
	ball(s9, 2.4, V(0, 103.8, 0), OFF, M.SmoothPlastic, { PowerLight = true })

	-- 10 ACTIVATION: every light panel: ring lamps, core strips, docking collars, thruster nozzles under the pad
	local s10 = stage(m, 10)
	for i = 0, 27 do
		local a = i / 28 * math.pi * 2
		P(lower, V(2.4, 1.2, 0.6), CFrame.lookAt(V(math.cos(a) * 26.7, 26, math.sin(a) * 26.7), V(0, 26, 0)), OFF, M.SmoothPlastic, { PowerLight = true })
	end
	for i = 0, 23 do
		local a = i / 24 * math.pi * 2
		P(upper, V(2.2, 1.1, 0.6), CFrame.lookAt(V(math.cos(a) * 19.9, 43, math.sin(a) * 19.9), V(0, 43, 0)), OFF, M.SmoothPlastic, { PowerLight = true })
	end
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		P(s10, V(1, 22, 0.5), CFrame.lookAt(V(math.cos(a) * 6.4, 29, math.sin(a) * 6.4), V(0, 29, 0)), OFF, M.SmoothPlastic, { PowerLight = true })
		local b = k / 4 * math.pi * 2 + math.pi / 4
		CD(s10, 0.8, 7.4, V(math.cos(b) * 45.6, 52, math.sin(b) * 45.6), V(math.cos(b), 0, math.sin(b)), OFF, M.SmoothPlastic, { PowerLight = true })
		P(s10, V(3.4, 1.4, 3.4), CFrame.new(math.cos(b) * 26, 1.2, math.sin(b) * 26), OFF, M.SmoothPlastic, { PowerLight = true })
	end
	C(s10, 1, 12, V(0, 79.6, 0), OFF, M.SmoothPlastic, { PowerLight = true })
	m.WorldPivot = CFrame.new(0, 0, 0)
	return m
end

function TB.BuildAll()
	local m = TB.OrbitalStation()
	local n, maxR, top = 0, 0, 0
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			n += 1
			maxR = math.max(maxR, V(d.Position.X, 0, d.Position.Z).Magnitude + math.max(d.Size.X, d.Size.Z) / 2)
			top = math.max(top, d.Position.Y + d.Size.Y / 2)
		end
	end
	local stages = 0
	for _, c in m:GetChildren() do
		if c.Name:match("^Stage_") then
			stages += 1
		end
	end
	return string.format("OrbitalStation=%d parts, %d stages, r=%.0f h=%.0f", n, stages, maxR, top)
end

return TB
