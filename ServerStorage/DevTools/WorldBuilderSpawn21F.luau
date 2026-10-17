--!nonstrict
-- PASS 21F: a substantial spawn plaza. The spawn point, the spawn pad / ring, the loading deck and every road are untouched; this builds
-- World.Hub.SpawnPlaza AROUND them so the spawn reads like the Training Pad does: a big tiled concrete plaza with a raised curb, a yellow
-- safety line, corner pylons and lamps, a welcome arch with the game name, direction signs, planters, benches and a floor emblem.
-- (Pass 21G) + two Trails-Shop style buildings on the loading deck (Builders = crew / Workers menu, Vehicles = Site Fleet menu; walk onto the
-- glowing mat to open the menu), two small "gate" arches replacing the direction signs, and a z-fighting fix (the old forecourt, its edge
-- lines and the overlapping end of the work path shared the plaza's surface height; they are removed / trimmed and the plaza sits above).
-- Re-runnable (it rebuilds its own folder). Layout: plaza X [-44, 44], Z [147, 193]; openings in the curb for the work path (west), the way
-- north to the build site, the loading-deck steps (south) and the worker station (east).
local V = Vector3.new
local M = Enum.Material
local CollectionService = game:GetService("CollectionService")

local X0, X1, Z0, Z1 = -44, 44, 147, 193
local CX, CZ = 0, 170
local AMBER = Color3.fromRGB(255, 194, 38)
local STEEL = Color3.fromRGB(84, 94, 116)
local DARK = Color3.fromRGB(34, 38, 48)
local CONCRETE_A, CONCRETE_B = Color3.fromRGB(178, 180, 188), Color3.fromRGB(160, 163, 172)
local CURB = Color3.fromRGB(96, 100, 112)

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

local function label(part: BasePart, face: Enum.NormalId, text: string, color: Color3, maxSize: number?)
	local g = Instance.new("SurfaceGui")
	g.Face = face
	g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	g.PixelsPerStud = 40
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
	c.MaxTextSize = maxSize or 80
	c.Parent = l
	local s = Instance.new("UIStroke")
	s.Color = Color3.fromRGB(8, 10, 16)
	s.Thickness = 3
	s.Parent = l
end

local function light(part: BasePart, color: Color3, range: number, brightness: number)
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = brightness
	l.Parent = part
end

local function lampPost(parent: Instance, pos: Vector3, flag: boolean?)
	mk(parent, { Name = "LampPost", Size = V(0.8, 12, 0.8), Position = pos + V(0, 6, 0), Color = STEEL, Material = M.Metal })
	mk(parent, { Name = "LampArm", Size = V(0.5, 0.5, 2.4), Position = pos + V(0, 11.6, 0), Color = STEEL, Material = M.Metal, CanCollide = false })
	local head = mk(parent, { Name = "LampHead", Size = V(2.2, 0.6, 2.2), Position = pos + V(0, 12.3, 0), Color = Color3.fromRGB(255, 232, 170), Material = M.Neon, CanCollide = false })
	light(head, Color3.fromRGB(255, 226, 160), 28, 0.9)
	if flag then
		-- an amber banner hanging from the post
		local b = mk(parent, { Name = "PostBanner", Size = V(0.2, 5.5, 2.2), Position = pos + V(1.4, 8, 0), Color = AMBER, CanCollide = false })
		mk(parent, { Name = "PostBannerStripe", Size = V(0.25, 0.5, 2.3), Position = pos + V(1.4, 5.5, 0), Color = DARK, CanCollide = false })
		label(b, Enum.NormalId.Right, "BUILD", DARK, 40)
		label(b, Enum.NormalId.Left, "BUILD", DARK, 40)
	end
end

local function pylon(parent: Instance, pos: Vector3)
	mk(parent, { Name = "PylonBase", Size = V(4.4, 1, 4.4), Position = pos + V(0, 0.5, 0), Color = DARK, Material = M.Metal })
	mk(parent, { Name = "Pylon", Size = V(3.2, 11, 3.2), Position = pos + V(0, 6.5, 0), Color = STEEL, Material = M.Metal })
	for _, y in { 4, 8.5 } do
		mk(parent, { Name = "PylonBand", Size = V(3.5, 0.6, 3.5), Position = pos + V(0, y, 0), Color = AMBER })
	end
	mk(parent, { Name = "PylonGlow", Size = V(0.5, 8, 0.5), Position = pos + V(0, 6, 1.7), Color = AMBER, Material = M.Neon, CanCollide = false })
	local cap = mk(parent, { Name = "PylonCap", Size = V(3.8, 0.7, 3.8), Position = pos + V(0, 12.3, 0), Color = DARK, Material = M.Metal })
	local top = mk(parent, { Name = "PylonLamp", Size = V(2.2, 1.4, 2.2), Position = pos + V(0, 13.2, 0), Color = AMBER, Material = M.Neon, CanCollide = false })
	light(top, AMBER, 30, 1.1)
	return cap
end

-- a small version of the welcome arch: two banded posts and a name banner. `alongZ` gates span the Z axis (they stand in a west / east opening).
local function smallGate(parent: Instance, center: Vector3, alongZ: boolean, width: number, text: string, sub: string)
	local H = 9
	local function at(s: number, y: number): Vector3
		return center + (if alongZ then V(0, y, s * width / 2) else V(s * width / 2, y, 0))
	end
	for _, s in { -1, 1 } do
		mk(parent, { Name = "GatePost", Size = V(1.5, H, 1.5), Position = at(s, H / 2), Color = STEEL, Material = M.Metal })
		mk(parent, { Name = "GateBase", Size = V(2.6, 0.8, 2.6), Position = at(s, 0.4), Color = DARK, Material = M.Metal })
		for _, y in { 3, 6.5 } do
			mk(parent, { Name = "GateBand", Size = V(1.8, 0.5, 1.8), Position = at(s, y), Color = AMBER })
		end
		mk(parent, { Name = "GateGlow", Size = if alongZ then V(0.3, H - 1, 0.3) else V(0.3, H - 1, 0.3), Position = at(s, H / 2 + 0.2) + (if alongZ then V(0.9, 0, 0) else V(0, 0, 0.9)), Color = AMBER, Material = M.Neon, CanCollide = false })
	end
	local len = width + 2
	local bsize = if alongZ then V(1.2, 2.8, len) else V(len, 2.8, 1.2)
	local banner = mk(parent, { Name = "GateBanner", Size = bsize, Position = center + V(0, H + 1.3, 0), Color = DARK })
	local faces = if alongZ then { Enum.NormalId.Left, Enum.NormalId.Right } else { Enum.NormalId.Front, Enum.NormalId.Back }
	for _, face in faces do
		label(banner, face, text, AMBER, 70)
	end
	for _, dy in { 1.55, -1.55 } do
		mk(parent, { Name = "GateTrim", Size = if alongZ then V(1.5, 0.4, len + 0.6) else V(len + 0.6, 0.4, 1.5), Position = center + V(0, H + 1.3 + dy, 0), Color = AMBER })
	end
	local ssize = if alongZ then V(0.4, 1.3, width * 0.7) else V(width * 0.7, 1.3, 0.4)
	local subBoard = mk(parent, { Name = "GateSub", Size = ssize, Position = center + V(0, H - 0.55, 0), Color = DARK, CanCollide = false })
	for _, face in faces do
		label(subBoard, face, sub, Color3.new(1, 1, 1), 40)
	end
end

-- TRAILS-SHOP STYLE STALL on the loading deck: a wooden frame with a name board over it, a striped awning, low rails either side of an open
-- front, a counter with props, and a glowing floor mat (tag "ShopMat", attribute Panel) that opens that menu when you walk onto it.
local WOOD, WOOD_DARK, WOOD_LIGHT = Color3.fromRGB(150, 104, 62), Color3.fromRGB(104, 70, 42), Color3.fromRGB(196, 150, 96)
local function shop(parent: Instance, center: Vector3, name: string, sub: string, panel: string, accent: Color3, props: string)
	local y0 = center.Y
	local function P(p)
		return mk(parent, p)
	end
	local function pos(x: number, y: number, z: number): Vector3
		return V(center.X + x, y0 + y, center.Z + z)
	end
	P({ Name = "ShopFloor", Size = V(14.4, 0.3, 8.6), Position = pos(0, 0.15, 0), Color = WOOD_LIGHT, Material = M.WoodPlanks })
	P({ Name = "ShopFloorTrim", Size = V(14.8, 0.2, 9), Position = pos(0, 0.05, 0), Color = WOOD_DARK, Material = M.Wood })
	-- frame
	for _, x in { -6.6, 6.6 } do
		for _, z in { -3.7, 3.7 } do
			P({ Name = "ShopPost", Size = V(1, 8.4, 1), Position = pos(x, 4.5, z), Color = WOOD, Material = M.Wood })
		end
		P({ Name = "ShopSideBeam", Size = V(1, 0.9, 8.4), Position = pos(x, 8.4, 0), Color = WOOD_DARK, Material = M.Wood })
	end
	for _, z in { -3.7, 3.7 } do
		P({ Name = "ShopBeam", Size = V(14.2, 0.9, 1), Position = pos(0, 8.4, z), Color = WOOD_DARK, Material = M.Wood })
	end
	-- striped awning over the front
	for k = 0, 6 do
		P({ Name = "Awning", Size = V(2.04, 0.35, 5.6), CFrame = CFrame.new(pos(-6.12 + k * 2.04, 8.3, -2.2)) * CFrame.Angles(math.rad(-10), 0, 0), Color = if k % 2 == 0 then accent else DARK, CanCollide = false })
	end
	-- name board on two risers
	for _, x in { -5.5, 5.5 } do
		P({ Name = "BoardRiser", Size = V(0.8, 2.4, 0.8), Position = pos(x, 9.9, -3.7), Color = WOOD, Material = M.Wood })
	end
	local board = P({ Name = "ShopBoard", Size = V(13.2, 3.2, 0.9), Position = pos(0, 11.4, -3.7), Color = DARK })
	P({ Name = "BoardTrim", Size = V(13.6, 0.35, 1.1), Position = pos(0, 13.15, -3.7), Color = accent })
	P({ Name = "BoardTrim", Size = V(13.6, 0.35, 1.1), Position = pos(0, 9.65, -3.7), Color = accent })
	P({ Name = "BoardGlow", Size = V(12.8, 0.18, 0.3), Position = pos(0, 9.5, -4.25), Color = accent, Material = M.Neon, CanCollide = false })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		label(board, face, name, accent:Lerp(Color3.new(1, 1, 1), 0.15), 90)
	end
	local subBoard = P({ Name = "ShopSub", Size = V(7.2, 1.2, 0.5), Position = pos(0, 8.9, -4.1), Color = DARK, CanCollide = false })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		label(subBoard, face, sub, Color3.new(1, 1, 1), 40)
	end
	-- low rails either side of the open front (like the reference's lower fence)
	for _, side in { -1, 1 } do
		for _, y in { 1.2, 2.3 } do
			P({ Name = "ShopRail", Size = V(4.6, 0.35, 0.5), Position = pos(side * 4.2, y, -3.9), Color = WOOD, Material = M.Wood })
		end
		for k = 0, 3 do
			P({ Name = "ShopPicket", Size = V(0.4, 2.4, 0.4), Position = pos(side * (2.4 + k * 1.2), 1.5, -3.9), Color = WOOD_DARK, Material = M.Wood })
		end
	end
	-- back wall + counter
	P({ Name = "ShopBackWall", Size = V(13, 6, 0.5), Position = pos(0, 3.3, 3.8), Color = WOOD_DARK, Material = M.WoodPlanks })
	P({ Name = "Counter", Size = V(8, 1.9, 1.6), Position = pos(0, 1.25, 2.0), Color = WOOD, Material = M.WoodPlanks })
	P({ Name = "CounterTop", Size = V(8.4, 0.3, 2), Position = pos(0, 2.35, 2.0), Color = WOOD_LIGHT, Material = M.WoodPlanks })
	local lampPart = P({ Name = "ShopLamp", Size = V(1.2, 0.4, 1.2), Position = pos(0, 7.7, 1.5), Color = Color3.fromRGB(255, 232, 170), Material = M.Neon, CanCollide = false })
	light(lampPart, Color3.fromRGB(255, 226, 160), 22, 1.0)
	if props == "builders" then
		-- hard hat, rolled plans, a small crate, a hammer
		P({ Name = "PropHat", Shape = Enum.PartType.Ball, Size = V(1.9, 1.9, 1.9), Position = pos(-2.4, 3.1, 2.0), Color = AMBER, CanCollide = false })
		P({ Name = "PropHatBrim", Shape = Enum.PartType.Cylinder, Size = V(0.2, 2.8, 2.8), CFrame = CFrame.new(pos(-2.4, 2.6, 2.0)) * CFrame.Angles(0, 0, math.rad(90)), Color = AMBER, CanCollide = false })
		P({ Name = "PropPlans", Shape = Enum.PartType.Cylinder, Size = V(3, 0.8, 0.8), CFrame = CFrame.new(pos(0.4, 2.9, 2.1)) * CFrame.Angles(0, math.rad(20), 0), Color = Color3.fromRGB(236, 228, 200), CanCollide = false })
		P({ Name = "PropCrate", Size = V(1.5, 1.5, 1.5), Position = pos(2.7, 3.2, 2.0), Color = WOOD, Material = M.WoodPlanks, CanCollide = false })
		P({ Name = "PropHammer", Size = V(0.3, 1.6, 0.3), CFrame = CFrame.new(pos(1.6, 2.8, 1.5)) * CFrame.Angles(0, 0, math.rad(70)), Color = WOOD_DARK, CanCollide = false })
		P({ Name = "PropHammerHead", Size = V(0.9, 0.5, 0.5), Position = pos(2.2, 3.4, 1.5), Color = STEEL, Material = M.Metal, CanCollide = false })
		for k = -1, 1 do
			P({ Name = "WallHat", Shape = Enum.PartType.Ball, Size = V(1.6, 1.6, 1.6), Position = pos(k * 3.6, 5.2, 3.4), Color = if k == 0 then AMBER else accent, CanCollide = false })
		end
	else
		-- a toy dump truck and a stack of wheels
		P({ Name = "PropTruckBody", Size = V(2.6, 0.9, 1.4), Position = pos(-1.8, 3.0, 2.0), Color = Color3.fromRGB(236, 150, 40), CanCollide = false })
		P({ Name = "PropTruckCab", Size = V(1.0, 1.1, 1.4), Position = pos(-0.5, 3.1, 2.0), Color = AMBER, CanCollide = false })
		for _, wx in { -2.6, -1.0, 0.0 } do
			for _, wz in { 1.3, 2.7 } do
				P({ Name = "PropWheel", Shape = Enum.PartType.Cylinder, Size = V(0.3, 0.8, 0.8), CFrame = CFrame.new(pos(wx, 2.65, wz)) * CFrame.Angles(math.rad(90), 0, 0), Color = DARK, CanCollide = false })
			end
		end
		for k = 0, 2 do
			P({ Name = "PropTyre", Shape = Enum.PartType.Cylinder, Size = V(0.9, 1.9, 1.9), CFrame = CFrame.new(pos(2.8, 2.9 + k * 0.9, 2.0)) * CFrame.Angles(0, 0, math.rad(90)), Color = Color3.fromRGB(46, 50, 60), CanCollide = false })
		end
		for k = -1, 1 do
			P({ Name = "WallWheel", Shape = Enum.PartType.Cylinder, Size = V(0.5, 3, 3), CFrame = CFrame.new(pos(k * 3.8, 5.0, 3.4)) * CFrame.Angles(0, math.rad(90), 0), Color = if k == 0 then accent else DARK, CanCollide = false })
		end
	end
	-- the walk-on mat that opens the menu
	local mat = P({ Name = "ShopMat", Size = V(8, 0.14, 2.6), Position = pos(0, 0.37, -5.9), Color = accent, Material = M.Neon, Transparency = 0.2, CanCollide = false, CanQuery = false, CanTouch = false })
	mat:SetAttribute("Panel", panel)
	CollectionService:AddTag(mat, "ShopMat")
	local matLabel = P({ Name = "ShopMatLabel", Size = V(2, 0.05, 7), CFrame = CFrame.new(pos(0, 0.45, -5.9)) * CFrame.Angles(0, math.rad(90), 0), Transparency = 1, CanCollide = false, CanQuery = false })
	label(matLabel, Enum.NormalId.Top, "STEP IN TO BROWSE", Color3.fromRGB(30, 34, 44), 50)
end

local function planter(parent: Instance, pos: Vector3)
	mk(parent, { Name = "PlanterBox", Size = V(6, 1.4, 6), Position = pos + V(0, 0.7, 0), Color = Color3.fromRGB(120, 96, 70), Material = M.Concrete })
	mk(parent, { Name = "PlanterSoil", Size = V(5.2, 0.3, 5.2), Position = pos + V(0, 1.45, 0), Color = Color3.fromRGB(70, 52, 38), CanCollide = false })
	for i, off in { V(-1.2, 0, -0.8), V(1.1, 0, 0.9), V(0, 0, 0) } do
		local d = 2.6 + (i % 2) * 0.8
		mk(parent, { Name = "Bush", Shape = Enum.PartType.Ball, Size = V(d, d, d), Position = pos + off + V(0, 2.3 + d / 4, 0), Color = Color3.fromRGB(64 + i * 14, 138 + i * 10, 76), Material = M.Grass, CanCollide = false })
	end
end

local function bench(parent: Instance, pos: Vector3, yawDeg: number)
	local cf = CFrame.new(pos) * CFrame.Angles(0, math.rad(yawDeg), 0)
	mk(parent, { Name = "BenchSeat", Size = V(7, 0.5, 2), CFrame = cf * CFrame.new(0, 1.7, 0), Color = Color3.fromRGB(176, 120, 66), Material = M.WoodPlanks })
	mk(parent, { Name = "BenchBack", Size = V(7, 1.8, 0.4), CFrame = cf * CFrame.new(0, 2.9, -0.9) * CFrame.Angles(math.rad(-8), 0, 0), Color = Color3.fromRGB(176, 120, 66), Material = M.WoodPlanks, CanCollide = false })
	for _, sx in { -3, 3 } do
		mk(parent, { Name = "BenchLeg", Size = V(0.6, 1.6, 1.8), CFrame = cf * CFrame.new(sx, 0.8, 0), Color = STEEL, Material = M.Metal })
	end
end

return function(ctx)
	local world = ctx.world
	local hub = world:FindFirstChild("Hub")
	if not hub then
		return "spawn21F: no Hub"
	end
	local old = hub:FindFirstChild("SpawnPlaza")
	if old then
		old:Destroy()
	end
	-- trees / props standing in the plaza go
	local scenery = world:FindFirstChild("Scenery")
	if scenery then
		for _, m in scenery:GetChildren() do
			local pos = if m:IsA("Model") then m:GetPivot().Position elseif m:IsA("BasePart") then m.Position else nil
			if pos and pos.X > X0 - 4 and pos.X < X1 + 4 and pos.Z > Z0 - 4 and pos.Z < Z1 + 4 then
				m:Destroy()
			end
		end
	end
	local f = Instance.new("Folder")
	f.Name = "SpawnPlaza"
	f.Parent = hub

	-- z-fighting / clutter fix: the old forecourt, its dark edge lines and the beams / formwork on the loading deck are replaced by this plaza
	-- and the two shops; the work path and apron keep their outside parts only (they used to overlap the plaza at the same height)
	local frame = hub:FindFirstChild("HubFrame")
	if frame then
		for _, d in frame:GetChildren() do
			if d.Name == "Forecourt" or d.Name == "ForecourtEdge" or d.Name == "BeamBundle" or d.Name == "Formwork" then
				d:Destroy()
			elseif (d.Name == "WorkPath" or d.Name == "WorkPathEdge") and d:IsA("BasePart") then
				local right = d.Position.X + d.Size.X / 2
				if right > X0 - 2 then
					local left = d.Position.X - d.Size.X / 2
					local newRight = X0 - 2
					d.Size = V(newRight - left, d.Size.Y, d.Size.Z)
					d.Position = V((left + newRight) / 2, d.Position.Y, d.Position.Z)
				end
			end
		end
	end
	local apron = hub:FindFirstChild("Apron")
	if apron then
		apron:Destroy() -- belonged to the old worker station
	end
	local oldStation = world:FindFirstChild("WorkerStation")
	if oldStation then
		oldStation:Destroy()
	end

	-- 1. tiled slab (top at 0.13, just above the old forecourt; the spawn pad and ring sit above it)
	local cols, rows = 8, 4
	local tw, td = (X1 - X0) / cols, (Z1 - Z0) / rows
	mk(f, { Name = "PlazaSlab", Size = V(X1 - X0, 0.1, Z1 - Z0), Position = V(CX, 0.09, CZ), Color = CONCRETE_B, Material = M.Concrete, CanQuery = false })
	for c = 0, cols - 1 do
		for r = 0, rows - 1 do
			mk(f, {
				Name = "Tile", Size = V(tw - 0.5, 0.06, td - 0.5),
				Position = V(X0 + tw * (c + 0.5), 0.15, Z0 + td * (r + 0.5)),
				Color = if (c + r) % 2 == 0 then CONCRETE_A else CONCRETE_B, Material = M.Concrete, CanCollide = false, CanQuery = false,
			})
		end
	end
	-- yellow safety line just inside the curb
	for _, e in {
		{ V(X1 - X0 - 4, 0.05, 0.5), V(CX, 0.185, Z0 + 2.2) }, { V(X1 - X0 - 4, 0.05, 0.5), V(CX, 0.185, Z1 - 2.2) },
		{ V(0.5, 0.05, Z1 - Z0 - 4), V(X0 + 2.2, 0.185, CZ) }, { V(0.5, 0.05, Z1 - Z0 - 4), V(X1 - 2.2, 0.185, CZ) },
	} do
		mk(f, { Name = "SafetyLine", Size = e[1], Position = e[2], Color = AMBER, CanCollide = false, CanQuery = false })
	end

	-- 2. curb with openings (north: the way to the build site, west: work path, south: deck steps, east: worker station)
	local function curbX(xa: number, xb: number, z: number)
		if xb - xa > 0.5 then
			mk(f, { Name = "Curb", Size = V(xb - xa, 0.35, 1.4), Position = V((xa + xb) / 2, 0.18, z), Color = CURB, Material = M.Concrete, CanQuery = false })
			mk(f, { Name = "CurbTrim", Size = V(xb - xa, 0.06, 0.3), Position = V((xa + xb) / 2, 0.38, z), Color = AMBER, CanCollide = false, CanQuery = false })
		end
	end
	local function curbZ(za: number, zb: number, x: number)
		if zb - za > 0.5 then
			mk(f, { Name = "Curb", Size = V(1.4, 0.35, zb - za), Position = V(x, 0.18, (za + zb) / 2), Color = CURB, Material = M.Concrete, CanQuery = false })
			mk(f, { Name = "CurbTrim", Size = V(0.3, 0.06, zb - za), Position = V(x, 0.38, (za + zb) / 2), Color = AMBER, CanCollide = false, CanQuery = false })
		end
	end
	curbX(X0, -16, Z0 + 0.7) curbX(16, X1, Z0 + 0.7) -- north opening x -16..16
	curbX(X0, -12, Z1 - 0.7) curbX(12, X1, Z1 - 0.7) -- south opening x -12..12
	curbZ(Z0, 160, X0 + 0.7) curbZ(184, Z1, X0 + 0.7) -- west opening z 160..184
	curbZ(Z0, Z1, X1 - 0.7) -- east side: closed (the old worker station was removed)

	-- 3. pylons, lamps
	for _, x in { X0 + 3, X1 - 3 } do
		pylon(f, V(x, 0.1, Z0 + 3))
		pylon(f, V(x, 0.1, Z1 - 3))
	end
	for _, x in { -26, 26 } do
		lampPost(f, V(x, 0.1, Z0 + 2.4), true)
		lampPost(f, V(x, 0.1, Z1 - 2.4), true)
	end
	for _, z in { 156, 188 } do
		lampPost(f, V(X0 + 2.4, 0.1, z))
	end
	lampPost(f, V(X1 - 2.4, 0.1, 160))

	-- 4. welcome arch over the north opening
	for _, sx in { -18, 18 } do
		mk(f, { Name = "ArchPost", Size = V(2, 16, 2), Position = V(sx, 8.1, Z0 + 0.8), Color = STEEL, Material = M.Metal })
		mk(f, { Name = "ArchBase", Size = V(3.4, 1, 3.4), Position = V(sx, 0.6, Z0 + 0.8), Color = DARK, Material = M.Metal })
		mk(f, { Name = "ArchGlow", Size = V(0.4, 14, 0.4), Position = V(sx, 8.1, Z0 + 2), Color = AMBER, Material = M.Neon, CanCollide = false })
		for _, y in { 4, 9, 14 } do
			mk(f, { Name = "ArchBand", Size = V(2.3, 0.6, 2.3), Position = V(sx, y, Z0 + 0.8), Color = AMBER })
		end
	end
	local banner = mk(f, { Name = "ArchBanner", Size = V(40, 4.4, 1.6), Position = V(0, 15.2, Z0 + 0.8), Color = DARK })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		label(banner, face, "COLOSSAL BUILDING", AMBER, 120)
	end
	mk(f, { Name = "ArchTrim", Size = V(40.6, 0.5, 1.9), Position = V(0, 17.6, Z0 + 0.8), Color = AMBER })
	mk(f, { Name = "ArchTrim", Size = V(40.6, 0.5, 1.9), Position = V(0, 12.8, Z0 + 0.8), Color = AMBER })
	mk(f, { Name = "ArchGlow", Size = V(38, 0.3, 0.4), Position = V(0, 12.4, Z0 + 1.9), Color = AMBER, Material = M.Neon, CanCollide = false })
	local sub = mk(f, { Name = "ArchSub", Size = V(16, 1.8, 0.5), Position = V(0, 10.9, Z0 + 0.8), Color = DARK, CanCollide = false })
	for _, face in { Enum.NormalId.Front, Enum.NormalId.Back } do
		label(sub, face, "BUILD TOGETHER", Color3.new(1, 1, 1), 50)
	end

	-- 5. direction signs (training west, workers east, the build north under the arch)
	smallGate(f, V(X0 + 0.7, 0.1, 172), true, 22, "TRAINING YARD", "RUN  -  LIFT  -  LEVEL UP")

	-- 6. planters + benches
	for _, x in { -34, 34 } do
		planter(f, V(x, 0.1, Z0 + 8))
	end
	planter(f, V(X0 + 8, 0.1, Z1 - 8))
	planter(f, V(X1 - 8, 0.1, Z1 - 8))
	bench(f, V(-26, 0.1, Z1 - 6), 180)
	bench(f, V(26, 0.1, Z1 - 6), 180)
	bench(f, V(-26, 0.1, Z0 + 6), 0)
	bench(f, V(26, 0.1, Z0 + 6), 0)

	-- 6b. the two shops on the loading deck (deck top is y 2.4)
	shop(f, V(-15, 2.4, 207), "BUILDERS SHOP", "CREW  &  WORKERS", "Worker", Color3.fromRGB(255, 194, 38), "builders")
	shop(f, V(15, 2.4, 207), "VEHICLE SHOP", "SITE FLEET", "Vehicles", Color3.fromRGB(96, 206, 255), "vehicles")

	-- 7. floor emblem: a dashed outer ring round the spawn ring + a welcome line (all flat, nothing blocks the spawn)
	local center = V(0, 0.21, 164)
	for k = 0, 23 do
		local a = k / 24 * math.pi * 2
		mk(f, {
			Name = "RingDash", Size = V(5.2, 0.05, 0.7),
			CFrame = CFrame.new(center + V(math.cos(a) * 21.5, 0, math.sin(a) * 21.5)) * CFrame.Angles(0, -a + math.pi / 2, 0),
			Color = AMBER, CanCollide = false, CanQuery = false,
		})
	end
	-- (a SurfaceGui on a top face runs along the part's Z axis, so the plate is built 4 x 30 and turned to read along X)
	local text = mk(f, { Name = "WelcomeText", Size = V(4, 0.05, 30), CFrame = CFrame.new(0, 0.21, Z1 - 6.5) * CFrame.Angles(0, math.rad(-90), 0), Transparency = 1, CanCollide = false, CanQuery = false })
	label(text, Enum.NormalId.Top, "WELCOME, BUILDERS", Color3.fromRGB(60, 64, 76), 70)
	return string.format("spawn21F: plaza %dx%d with arch, 4 pylons, lamps, 2 gates, 2 shops, planters", X1 - X0, Z1 - Z0)
end
