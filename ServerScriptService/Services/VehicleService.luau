--!strict
-- Transport vehicles: REAL driveable vehicles (see "driveable vehicles" below). They raise carry capacity
-- and top speed while you drive, but the player still gathers and delivers: never passive automation.
--
-- Visual builders are keyed by VehicleConfig.Builder; add a builder function for new vehicles.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local VehicleConfig = require(Shared.Config.VehicleConfig)
local Formulas = require(Shared.Formulas)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)

local VehicleService = {}
local S: any

local function part(model: Model, props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in props do
		(p :: any)[k] = v
	end
	p.Parent = model
	return p
end

-- Builders return a model whose PrimaryPart ("Root") sits at the character's feet,
-- in HRP-relative space (front = -Z). The "Cargo" attachment marks where the carried
-- stack is displayed.
local Builders: { [string]: (Model) -> () } = {}

-- CLASSIC ROBLOX UTILITY VEHICLES. Chunky colour-blocked plastic, studs on the flat tops, fat tyres with a coloured rim and
-- a metal cap, real wheel wells (body panels stop around the tyres instead of cutting through them), and one accent colour each:
--   Wheelbarrow  red ride-on barrow: deep tray, one big front wheel, two long handles, support legs   (small, cheap, agile)
--   Hand Cart    teal wagon: four wheels outside a shallow bed, T-handle pull/steer bar                (bigger early hauler)
--   Utility Cart green/white golf cart: front cowl, steering wheel, canopy, rear cargo bed              (strong midgame)
--   Pickup       red pickup: hood, cab with windshield and white roof, open bed, chrome bumpers          (fast)
--   Dump Truck   yellow cab + big orange tipper on six wheels, cab guard, exhaust stack                (slow, huge bed)
-- DRIVER FIT (measured on a default R15 avatar in the VehicleSeat): feet rest ~0.85 below the seat top and reach ~1.9 forward,
-- hands sit ~1.5 out to the sides and ~0.9 up, the head top is ~3.8 above the seat top. Every cab keeps its floor, dash, roof
-- and walls outside that envelope. Parts are massless and non-colliding (the invisible Hull collides).
local WHITE = Color3.fromRGB(246, 247, 250)
local BLACK = Color3.fromRGB(34, 36, 42)
local TIRE = Color3.fromRGB(44, 46, 52)
local GLASS = Color3.fromRGB(150, 210, 245)
local METAL = Color3.fromRGB(196, 202, 212)
local INTERIOR = Color3.fromRGB(58, 62, 74)

local function tint(c: Color3, t: number): Color3
	return if t >= 0 then c:Lerp(WHITE, t) else c:Lerp(BLACK, -t)
end

-- plastic block, optional studs on top
local function blk(m: Model, name: string, size: Vector3, pos: Vector3, color: Color3, studs: boolean?, rot: CFrame?): Part
	return part(m, { Name = name, Size = size, CFrame = CFrame.new(pos) * (rot or CFrame.identity), Color = color, Material = Enum.Material.Plastic, TopSurface = if studs then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth })
end

-- a square bar from a to b
local function bar(m: Model, name: string, a: Vector3, b: Vector3, thickness: number, color: Color3, mat: Enum.Material?): Part
	return part(m, { Name = name, Size = Vector3.new(thickness, thickness, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color, Material = mat or Enum.Material.Plastic })
end

-- a flat panel from a to b (its face points `up`-ish), e.g. windshields and sloped tray walls
local function panel(m: Model, name: string, a: Vector3, b: Vector3, width: number, thickness: number, color: Color3, mat: Enum.Material?, transparency: number?): Part
	return part(m, { Name = name, Size = Vector3.new(width, thickness, (b - a).Magnitude), CFrame = CFrame.lookAt((a + b) / 2, b), Color = color, Material = mat or Enum.Material.Plastic, Transparency = transparency or 0 })
end

local function wedge(m: Model, name: string, size: Vector3, cf: CFrame, color: Color3): WedgePart
	local w = Instance.new("WedgePart")
	w.Name = name
	w.Size = size
	w.CFrame = cf
	w.Color = color
	w.Material = Enum.Material.Plastic
	w.Anchored = false
	w.CanCollide = false
	w.CanQuery = false
	w.CanTouch = false
	w.Massless = true
	w.TopSurface = Enum.SurfaceType.Smooth
	w.BottomSurface = Enum.SurfaceType.Smooth
	w.Parent = m
	return w
end

-- a fat tyre (axis along X) standing on the ground: dark tyre, coloured rim, metal cap
local function wheel(m: Model, pos: Vector3, radius: number, width: number, rim: Color3)
	local r = CFrame.new(pos)
	part(m, { Name = "Wheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(width, radius * 2, radius * 2), Color = TIRE, Material = Enum.Material.SmoothPlastic, CFrame = r })
	part(m, { Name = "Hub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(width + 0.12, radius * 1.2, radius * 1.2), Color = rim, Material = Enum.Material.SmoothPlastic, CFrame = r })
	part(m, { Name = "HubCap", Shape = Enum.PartType.Cylinder, Size = Vector3.new(width + 0.24, radius * 0.46, radius * 0.46), Color = METAL, Material = Enum.Material.Metal, CFrame = r })
end

-- steering wheel facing the driver (tilted up), on a short column from `from`
local function steering(m: Model, center: Vector3, diameter: number, from: Vector3)
	bar(m, "Column", from, center, 0.25, BLACK)
	local dir = Vector3.new(0, 0.75, 1).Unit
	part(m, { Name = "SteeringWheel", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.22, diameter, diameter), Color = BLACK, Material = Enum.Material.SmoothPlastic, CFrame = CFrame.lookAt(center, center + dir) * CFrame.Angles(0, math.rad(90), 0) })
	part(m, { Name = "SteeringHub", Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.3, diameter * 0.35, diameter * 0.35), Color = METAL, Material = Enum.Material.Metal, CFrame = CFrame.lookAt(center, center + dir) * CFrame.Angles(0, math.rad(90), 0) })
end

local function lamp(m: Model, pos: Vector3, color: Color3?)
	part(m, { Name = "Light", Size = Vector3.new(0.9, 0.7, 0.25), Color = color or Color3.fromRGB(255, 244, 190), Material = Enum.Material.SmoothPlastic, CFrame = CFrame.new(pos) })
end

-- a body slab from z0 to z1 with square wheel wells left open around the wheels at `wells` (z centres)
local function wellSlab(m: Model, name: string, width: number, y0: number, y1: number, z0: number, z1: number, wells: { number }, half: number, color: Color3, studs: boolean?)
	local z = z0
	for _, wz in wells do
		local a, b = wz - half, wz + half
		if a - z > 0.15 then
			blk(m, name, Vector3.new(width, y1 - y0, a - z), Vector3.new(0, (y0 + y1) / 2, (z + a) / 2), color, studs)
		end
		z = math.max(z, b)
	end
	if z1 - z > 0.15 then
		blk(m, name, Vector3.new(width, y1 - y0, z1 - z), Vector3.new(0, (y0 + y1) / 2, (z + z1) / 2), color, studs)
	end
end

-- Root + the "Cargo" attachment the carried load is laid out on (set a little above the floor of deep beds so the load reads
-- as heaped in, not hidden below the walls). CarryVisualController reads BedWidth / BedLength to spread the load over the
-- bed in rows instead of stacking it in one column.
local function rootAndCargo(m: Model, cargoAt: CFrame, bedWidth: number, bedLength: number): BasePart
	local root = part(m, { Name = "Root", Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new() })
	m.PrimaryPart = root
	local cargo = Instance.new("Attachment")
	cargo.Name = "Cargo"
	cargo.CFrame = cargoAt
	cargo:SetAttribute("BedWidth", bedWidth)
	cargo:SetAttribute("BedLength", bedLength)
	cargo.Parent = root
	return root
end

function Builders.Wheelbarrow(m: Model)
	-- a ride-on barrow: the driver sits on a saddle between the handles, hands on the handles, feet on a footplate
	rootAndCargo(m, CFrame.new(0, 3.2, -2.6), 2.6, 3.0)
	local red, deep = Color3.fromRGB(222, 52, 46), Color3.fromRGB(168, 34, 32)
	-- deep tray (front)
	blk(m, "TrayFloor", Vector3.new(3.0, 0.4, 3.6), Vector3.new(0, 2.2, -2.6), deep, true)
	for _, sx in { -1, 1 } do
		blk(m, "TraySide", Vector3.new(0.35, 1.9, 4.0), Vector3.new(sx * 1.675, 2.95, -2.6), red)
		blk(m, "TrayRim", Vector3.new(0.55, 0.3, 4.1), Vector3.new(sx * 1.675, 4.0, -2.6), deep)
		-- the sloped front corners of the tray sides
		wedge(m, "TraySide", Vector3.new(0.35, 1.7, 0.9), CFrame.new(sx * 1.675, 3.05, -5.05) * CFrame.Angles(0, 0, math.pi), red)
	end
	blk(m, "TrayBack", Vector3.new(3.7, 1.9, 0.35), Vector3.new(0, 2.95, -0.6), red)
	blk(m, "TrayRim", Vector3.new(3.8, 0.3, 0.55), Vector3.new(0, 4.0, -0.6), deep)
	panel(m, "TrayFront", Vector3.new(0, 2.2, -4.45), Vector3.new(0, 3.9, -5.5), 3.7, 0.35, red)
	-- one big front wheel on a fork
	wheel(m, Vector3.new(0, 1.2, -5.3), 1.2, 0.9, WHITE)
	for _, sx in { -0.65, 0.65 } do
		bar(m, "Fork", Vector3.new(sx, 2.05, -4.0), Vector3.new(sx, 1.2, -5.3), 0.3, METAL, Enum.Material.Metal)
	end
	-- two support legs under the back of the tray
	for _, sx in { -1.2, 1.2 } do
		bar(m, "Leg", Vector3.new(sx, 2.0, -1.2), Vector3.new(sx, 0.4, -1.4), 0.35, METAL, Enum.Material.Metal)
		blk(m, "LegFoot", Vector3.new(0.6, 0.2, 0.8), Vector3.new(sx, 0.3, -1.4), BLACK)
	end
	-- two long handles running back past the driver, black grips at the ends
	for _, sx in { -1.55, 1.55 } do
		bar(m, "Handle", Vector3.new(sx, 1.95, -3.6), Vector3.new(sx, 3.0, 3.0), 0.4, METAL, Enum.Material.Metal)
		bar(m, "Grip", Vector3.new(sx, 2.98, 2.9), Vector3.new(sx, 3.14, 3.9), 0.56, BLACK)
		-- saddle and footplate brackets
		bar(m, "Bracket", Vector3.new(sx * 0.62, 1.72, 1.6), Vector3.new(sx, 2.66, 1.6), 0.25, METAL, Enum.Material.Metal)
		bar(m, "Bracket", Vector3.new(sx * 0.85, 1.45, 0.1), Vector3.new(sx, 2.45, 0.1), 0.25, METAL, Enum.Material.Metal)
	end
	blk(m, "Saddle", Vector3.new(2.2, 0.35, 1.9), Vector3.new(0, 1.78, 1.6), deep)
	blk(m, "Footplate", Vector3.new(2.4, 0.2, 1.2), Vector3.new(0, 1.4, 0.1), BLACK, true)
end

function Builders.HandCart(m: Model)
	-- a wagon: the driver sits at the front holding the T-handle, the load rides in the back
	rootAndCargo(m, CFrame.new(0, 1.95, 0.1), 3.3, 3.4)
	local teal, cream = Color3.fromRGB(30, 166, 182), Color3.fromRGB(252, 236, 196)
	blk(m, "BedFloor", Vector3.new(4.2, 0.4, 7.8), Vector3.new(0, 1.4, -1.7), tint(teal, -0.2), true)
	for _, sx in { -1, 1 } do
		blk(m, "BedSide", Vector3.new(0.35, 0.9, 7.8), Vector3.new(sx * 1.925, 2.05, -1.7), teal)
		blk(m, "Rail", Vector3.new(0.55, 0.25, 7.9), Vector3.new(sx * 1.925, 2.62, -1.7), cream)
	end
	for _, z in { -5.6, 2.2 } do
		blk(m, "BedEnd", Vector3.new(4.2, 0.9, 0.35), Vector3.new(0, 2.05, z), teal)
		blk(m, "Rail", Vector3.new(4.3, 0.25, 0.55), Vector3.new(0, 2.62, z), cream)
	end
	-- four wheels outside the bed on two axles
	for _, z in { -4.4, 1.0 } do
		blk(m, "Axle", Vector3.new(5.1, 0.3, 0.3), Vector3.new(0, 1.05, z), BLACK)
		for _, sx in { -2.55, 2.55 } do
			wheel(m, Vector3.new(sx, 1.25, z), 1.25, 0.8, cream)
		end
	end
	-- driver's bench with a cream backrest that also fences off the load
	blk(m, "SeatBase", Vector3.new(2.6, 0.35, 1.8), Vector3.new(0, 1.78, -3.0), tint(teal, -0.35))
	blk(m, "Backrest", Vector3.new(3.5, 1.4, 0.35), Vector3.new(0, 3.15, -1.95), cream)
	-- pull/steer bar from the front axle bracket up to a T-grip at the driver's hands
	blk(m, "HandleBracket", Vector3.new(1.2, 0.5, 0.6), Vector3.new(0, 1.4, -5.95), BLACK)
	bar(m, "HandleBar", Vector3.new(0, 1.5, -5.95), Vector3.new(0, 3.7, -3.65), 0.35, Color3.fromRGB(150, 100, 56), Enum.Material.Wood)
	blk(m, "TGrip", Vector3.new(3.0, 0.38, 0.38), Vector3.new(0, 3.7, -3.6), cream)
	for _, sx in { -1.6, 1.6 } do
		blk(m, "Grip", Vector3.new(0.6, 0.48, 0.48), Vector3.new(sx, 3.7, -3.6), BLACK)
	end
end

function Builders.UtilityCart(m: Model)
	rootAndCargo(m, CFrame.new(0, 3.3, 3.5), 3.3, 3.3)
	local green, dark = Color3.fromRGB(96, 196, 64), Color3.fromRGB(52, 58, 70)
	blk(m, "Chassis", Vector3.new(4.0, 0.5, 9.8), Vector3.new(0, 1.25, 0.5), dark)
	-- front cowl, bumper, lights
	blk(m, "Cowl", Vector3.new(4.0, 1.7, 2.2), Vector3.new(0, 2.35, -3.3), green, true)
	blk(m, "Bumper", Vector3.new(4.4, 0.5, 0.5), Vector3.new(0, 1.5, -4.6), WHITE)
	for _, sx in { -1.3, 1.3 } do
		lamp(m, Vector3.new(sx, 2.6, -4.45))
	end
	blk(m, "Dash", Vector3.new(4.0, 0.6, 0.5), Vector3.new(0, 3.5, -2.15), green)
	steering(m, Vector3.new(0, 3.85, -1.15), 2.0, Vector3.new(0, 3.5, -1.95))
	-- bench seat with a white back
	blk(m, "SeatBase", Vector3.new(4.0, 0.4, 1.8), Vector3.new(0, 1.7, 0.2), green)
	blk(m, "SeatBack", Vector3.new(4.0, 1.7, 0.4), Vector3.new(0, 3.25, 1.3), WHITE)
	-- canopy on four posts
	blk(m, "Canopy", Vector3.new(4.8, 0.4, 4.8), Vector3.new(0, 6.6, -0.2), WHITE, true)
	blk(m, "CanopyTrim", Vector3.new(4.9, 0.25, 4.9), Vector3.new(0, 6.3, -0.2), green)
	for _, p in { Vector3.new(-1.85, 4.8, -2.2), Vector3.new(1.85, 4.8, -2.2) } do
		blk(m, "Post", Vector3.new(0.3, 3.2, 0.3), p, METAL)
	end
	for _, sx in { -1.85, 1.85 } do
		blk(m, "Post", Vector3.new(0.3, 4.5, 0.3), Vector3.new(sx, 4.15, 1.6), METAL)
	end
	-- rear cargo bed: green box, white rails
	blk(m, "BedBox", Vector3.new(4.0, 1.4, 3.8), Vector3.new(0, 2.2, 3.5), tint(green, -0.2), true)
	for _, sx in { -1.85, 1.85 } do
		blk(m, "BedSide", Vector3.new(0.3, 1.0, 3.8), Vector3.new(sx, 3.4, 3.5), WHITE)
	end
	blk(m, "BedBack", Vector3.new(4.0, 1.0, 0.3), Vector3.new(0, 3.4, 5.25), WHITE)
	for _, sx in { -1.5, 1.5 } do
		lamp(m, Vector3.new(sx, 2.4, 5.45), Color3.fromRGB(255, 80, 70))
	end
	-- wheels outside the body, white fenders over them
	for _, z in { -3.0, 3.8 } do
		for _, sx in { -2.5, 2.5 } do
			wheel(m, Vector3.new(sx, 1.35, z), 1.35, 0.9, WHITE)
			blk(m, "Fender", Vector3.new(1.05, 0.3, 2.9), Vector3.new(sx, 3.0, z), WHITE)
		end
	end
end

function Builders.Pickup(m: Model)
	rootAndCargo(m, CFrame.new(0, 3.55, 4.2), 4.0, 4.6)
	local red = Color3.fromRGB(226, 46, 52)
	local wells = { -4.4, 4.2 }
	blk(m, "Chassis", Vector3.new(3.6, 0.5, 13.6), Vector3.new(0, 1.45, 0), BLACK)
	-- lower body with wheel wells (front and bed zones), cab floor between them
	wellSlab(m, "Body", 5.0, 1.7, 3.1, -7.0, -2.6, { -4.4 }, 1.75, red)
	blk(m, "CabFloor", Vector3.new(5.0, 0.4, 4.1), Vector3.new(0, 1.9, -0.55), red)
	wellSlab(m, "Body", 5.0, 1.7, 3.1, 1.5, 7.0, { 4.2 }, 1.75, red)
	-- hood, grille, chrome bumper, headlights
	blk(m, "Hood", Vector3.new(5.0, 0.8, 4.4), Vector3.new(0, 3.5, -4.8), red, true)
	blk(m, "HoodStripe", Vector3.new(1.2, 0.08, 4.4), Vector3.new(0, 3.94, -4.8), WHITE)
	blk(m, "Grille", Vector3.new(3.6, 1.4, 0.2), Vector3.new(0, 2.6, -7.08), BLACK)
	for _, y in { 2.2, 2.6, 3.0 } do
		blk(m, "GrilleBar", Vector3.new(3.4, 0.14, 0.12), Vector3.new(0, y, -7.2), METAL)
	end
	blk(m, "Bumper", Vector3.new(5.6, 0.7, 0.7), Vector3.new(0, 1.8, -7.2), METAL)
	for _, sx in { -1.95, 1.95 } do
		lamp(m, Vector3.new(sx, 3.3, -7.1))
	end
	-- cab: dash, doors, windshield, pillars, white roof, rear wall with a window
	blk(m, "Dash", Vector3.new(4.4, 0.8, 0.5), Vector3.new(0, 3.5, -2.35), INTERIOR)
	steering(m, Vector3.new(0, 4.35, -1.45), 2.0, Vector3.new(0, 3.7, -2.2))
	for _, sx in { -2.35, 2.35 } do
		blk(m, "Door", Vector3.new(0.3, 2.0, 3.8), Vector3.new(sx, 3.1, -0.7), red)
		blk(m, "DoorHandle", Vector3.new(0.15, 0.2, 0.6), Vector3.new(sx * 1.07, 3.7, 0.4), METAL)
		bar(m, "Pillar", Vector3.new(sx, 3.9, -2.6), Vector3.new(sx, 6.95, -1.85), 0.3, red)
		bar(m, "Pillar", Vector3.new(sx, 4.1, 1.15), Vector3.new(sx, 6.95, 1.15), 0.35, red)
	end
	panel(m, "Windshield", Vector3.new(0, 3.9, -2.6), Vector3.new(0, 6.95, -1.85), 4.4, 0.15, GLASS, Enum.Material.Glass, 0.4)
	blk(m, "Roof", Vector3.new(5.0, 0.45, 3.4), Vector3.new(0, 7.17, -0.3), WHITE, true)
	blk(m, "CabBack", Vector3.new(5.0, 4.85, 0.35), Vector3.new(0, 4.52, 1.35), red)
	part(m, { Name = "Windshield", Size = Vector3.new(3.6, 1.3, 0.45), Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.4, CFrame = CFrame.new(0, 5.6, 1.35) })
	-- bench seat
	blk(m, "SeatBase", Vector3.new(4.4, 0.35, 1.9), Vector3.new(0, 2.28, -0.3), INTERIOR)
	blk(m, "SeatBack", Vector3.new(4.4, 1.8, 0.4), Vector3.new(0, 3.85, 0.95), INTERIOR)
	-- open bed
	blk(m, "BedFloor", Vector3.new(4.4, 0.1, 5.3), Vector3.new(0, 3.15, 4.2), BLACK, true)
	for _, sx in { -2.35, 2.35 } do
		blk(m, "BedSide", Vector3.new(0.3, 1.4, 5.5), Vector3.new(sx, 3.8, 4.25), red)
		blk(m, "BedTrim", Vector3.new(0.45, 0.2, 5.5), Vector3.new(sx, 4.6, 4.25), WHITE)
	end
	blk(m, "Tailgate", Vector3.new(5.0, 1.4, 0.3), Vector3.new(0, 3.8, 6.85), red)
	blk(m, "RearBumper", Vector3.new(5.2, 0.6, 0.6), Vector3.new(0, 2.0, 7.2), METAL)
	for _, sx in { -2.0, 2.0 } do
		blk(m, "TailLight", Vector3.new(0.8, 0.5, 0.1), Vector3.new(sx, 3.8, 7.02), Color3.fromRGB(255, 80, 70))
	end
	for _, z in wells do
		for _, sx in { -2.4, 2.4 } do
			wheel(m, Vector3.new(sx, 1.5, z), 1.5, 1.2, WHITE)
		end
	end
end

-- BUILDER BUGGY (Master Builder rank 1): compact construction-site buggy. Slate body, amber roll cage / bumper / rack, short wheelbase,
-- fat tyres, a small rear cargo rack. Same driver envelope as the Pickup (seat y 2.7, dash z -2.35).
function Builders.BuilderBuggy(m: Model)
	rootAndCargo(m, CFrame.new(0, 3.4, 3.1), 3.6, 3.2)
	local slate, amber, steel = Color3.fromRGB(88, 102, 122), Color3.fromRGB(255, 170, 24), Color3.fromRGB(60, 64, 74)
	blk(m, "Chassis", Vector3.new(3.8, 0.5, 10.4), Vector3.new(0, 1.45, -0.1), steel)
	blk(m, "Floor", Vector3.new(4.4, 0.35, 3.9), Vector3.new(0, 2.0, -0.4), slate)
	-- front: hood over the front wheels, grille, chunky amber bumper, two headlights
	blk(m, "Hood", Vector3.new(4.4, 0.8, 3.0), Vector3.new(0, 3.4, -4.0), slate, true)
	blk(m, "HoodStripe", Vector3.new(1.1, 0.08, 3.0), Vector3.new(0, 3.84, -4.0), amber)
	blk(m, "Grille", Vector3.new(3.4, 1.2, 0.2), Vector3.new(0, 2.7, -5.55), BLACK)
	blk(m, "Bumper", Vector3.new(5.0, 0.8, 0.8), Vector3.new(0, 1.9, -5.9), amber)
	for _, sx in { -1.6, 1.6 } do
		lamp(m, Vector3.new(sx, 3.2, -5.6))
	end
	-- dash + steering + seat
	blk(m, "Dash", Vector3.new(4.0, 0.7, 0.5), Vector3.new(0, 3.5, -2.35), INTERIOR)
	steering(m, Vector3.new(0, 4.35, -1.45), 1.9, Vector3.new(0, 3.7, -2.2))
	blk(m, "SeatBase", Vector3.new(3.4, 0.35, 1.8), Vector3.new(0, 2.3, -0.3), INTERIOR)
	blk(m, "SeatBack", Vector3.new(3.4, 1.6, 0.4), Vector3.new(0, 3.5, 0.85), INTERIOR)
	-- roll cage: two hoops, side rails, roof bars and rear braces (amber, outside the driver envelope)
	local cx = 2.15
	for _, sx in { -cx, cx } do
		bar(m, "CagePost", Vector3.new(sx, 2.2, -2.2), Vector3.new(sx, 6.6, -1.6), 0.34, amber)
		bar(m, "CagePost", Vector3.new(sx, 2.2, 1.6), Vector3.new(sx, 6.6, 1.2), 0.34, amber)
		bar(m, "CageRail", Vector3.new(sx, 6.6, -1.6), Vector3.new(sx, 6.6, 1.2), 0.34, amber)
		bar(m, "CageBrace", Vector3.new(sx, 6.6, 1.2), Vector3.new(sx, 2.6, 3.4), 0.28, amber)
	end
	bar(m, "CageRoof", Vector3.new(-cx, 6.6, -1.6), Vector3.new(cx, 6.6, -1.6), 0.34, amber)
	bar(m, "CageRoof", Vector3.new(-cx, 6.6, 1.2), Vector3.new(cx, 6.6, 1.2), 0.34, amber)
	bar(m, "CageMid", Vector3.new(-cx, 4.6, 1.4), Vector3.new(cx, 4.6, 1.4), 0.28, amber)
	-- rear cargo rack: a steel deck, two low rails, an amber tail panel, tail lights, rear bumper
	blk(m, "RackFloor", Vector3.new(4.0, 0.25, 3.6), Vector3.new(0, 2.85, 3.5), steel, true)
	for _, sx in { -1.95, 1.95 } do
		blk(m, "RackRail", Vector3.new(0.25, 0.8, 3.6), Vector3.new(sx, 3.3, 3.5), amber)
	end
	blk(m, "TailPanel", Vector3.new(4.2, 0.9, 0.25), Vector3.new(0, 3.35, 5.3), amber)
	blk(m, "RearBumper", Vector3.new(4.6, 0.5, 0.5), Vector3.new(0, 1.9, 5.6), steel)
	for _, sx in { -1.7, 1.7 } do
		blk(m, "TailLight", Vector3.new(0.6, 0.4, 0.1), Vector3.new(sx, 3.3, 5.45), Color3.fromRGB(255, 80, 70))
	end
	for _, z in { -3.7, 3.0 } do
		for _, sx in { -2.55, 2.55 } do
			wheel(m, Vector3.new(sx, 1.55, z), 1.55, 1.5, amber)
		end
	end
end

function Builders.DumpTruck(m: Model)
	local yellow, orange = Color3.fromRGB(255, 196, 30), Color3.fromRGB(255, 128, 30)
	-- the tipper body is hinged at the back and raised a touch at the front
	local bedCF = CFrame.new(0, 4.4, 10.6) * CFrame.Angles(math.rad(4), 0, 0)
	rootAndCargo(m, bedCF * CFrame.new(0, 2.2, -4.5), 6.0, 8.2)
	blk(m, "Chassis", Vector3.new(3.6, 0.9, 18.4), Vector3.new(0, 2.05, 1.2), BLACK)
	-- front: bumper, big grille, hood with wells over the front wheels, black fender flares, lights
	blk(m, "Bumper", Vector3.new(7.4, 1.2, 1.0), Vector3.new(0, 2.2, -8.7), Color3.fromRGB(70, 74, 84))
	wellSlab(m, "Hood", 6.0, 2.5, 3.9, -8.2, -3.0, { -5.0 }, 2.15, yellow)
	blk(m, "Hood", Vector3.new(6.0, 1.9, 5.2), Vector3.new(0, 4.85, -5.6), yellow, true)
	blk(m, "Grille", Vector3.new(4.6, 2.6, 0.3), Vector3.new(0, 3.9, -8.3), BLACK)
	for _, y in { 3.0, 3.6, 4.2, 4.8 } do
		blk(m, "GrilleBar", Vector3.new(4.4, 0.18, 0.12), Vector3.new(0, y, -8.45), METAL)
	end
	for _, sx in { -1, 1 } do
		blk(m, "FenderFlare", Vector3.new(1.7, 0.4, 4.4), Vector3.new(sx * 3.0, 4.05, -5.0), BLACK)
		lamp(m, Vector3.new(sx * 2.25, 4.6, -8.3))
	end
	-- cab: floor, seat, dash, doors, windshield, pillars, roof, back wall
	blk(m, "CabFloor", Vector3.new(6.4, 0.7, 4.2), Vector3.new(0, 2.85, -0.9), tint(yellow, -0.15))
	blk(m, "SeatBase", Vector3.new(4.4, 0.35, 2.0), Vector3.new(0, 3.38, -0.6), INTERIOR)
	blk(m, "SeatBack", Vector3.new(4.4, 2.0, 0.4), Vector3.new(0, 5.05, 0.6), INTERIOR)
	blk(m, "Dash", Vector3.new(6.0, 1.0, 0.6), Vector3.new(0, 5.3, -2.7), INTERIOR)
	steering(m, Vector3.new(0, 5.5, -1.8), 2.3, Vector3.new(0, 5.2, -2.6))
	panel(m, "Windshield", Vector3.new(0, 5.8, -3.0), Vector3.new(0, 8.1, -2.6), 5.8, 0.15, GLASS, Enum.Material.Glass, 0.4)
	for _, sx in { -1, 1 } do
		blk(m, "Door", Vector3.new(0.3, 2.6, 3.9), Vector3.new(sx * 3.05, 4.5, -0.95), yellow)
		bar(m, "Pillar", Vector3.new(sx * 3.05, 5.8, -3.0), Vector3.new(sx * 3.05, 8.1, -2.6), 0.4, yellow)
		bar(m, "Pillar", Vector3.new(sx * 3.05, 5.8, 1.0), Vector3.new(sx * 3.05, 8.1, 1.0), 0.4, yellow)
		blk(m, "Step", Vector3.new(0.6, 0.25, 1.2), Vector3.new(sx * 3.5, 2.4, -1.0), BLACK)
		blk(m, "Step", Vector3.new(0.6, 0.25, 1.2), Vector3.new(sx * 3.5, 1.5, -1.0), BLACK)
		part(m, { Name = "FuelTank", Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.2, 1.3, 1.3), Color = METAL, Material = Enum.Material.Metal, CFrame = CFrame.new(sx * 2.6, 2.3, 1.9) * CFrame.Angles(0, math.rad(90), 0) })
	end
	blk(m, "Roof", Vector3.new(6.8, 0.5, 4.6), Vector3.new(0, 8.35, -0.9), tint(yellow, 0.1), true)
	blk(m, "Beacon", Vector3.new(0.9, 0.45, 0.9), Vector3.new(0, 8.82, -0.4), orange)
	blk(m, "CabBack", Vector3.new(6.4, 4.9, 0.4), Vector3.new(0, 5.65, 1.2), yellow)
	part(m, { Name = "Windshield", Size = Vector3.new(4.2, 1.4, 0.5), Color = GLASS, Material = Enum.Material.Glass, Transparency = 0.4, CFrame = CFrame.new(0, 6.9, 1.2) })
	part(m, { Name = "Exhaust", Shape = Enum.PartType.Cylinder, Size = Vector3.new(6.4, 0.55, 0.55), Color = METAL, Material = Enum.Material.Metal, CFrame = CFrame.new(3.55, 6.3, 1.45) * CFrame.Angles(0, 0, math.rad(90)) })
	-- the tipper: floor, tall sides with ribs, headboard and a cab guard reaching over the roof, tailgate
	local function bed(name: string, size: Vector3, at: Vector3, color: Color3, studs: boolean?)
		part(m, { Name = name, Size = size, CFrame = bedCF * CFrame.new(at), Color = color, Material = Enum.Material.Plastic, TopSurface = if studs then Enum.SurfaceType.Studs else Enum.SurfaceType.Smooth })
	end
	bed("Subframe", Vector3.new(3.4, 1.9, 8.6), Vector3.new(0, -0.95, -4.5), BLACK)
	bed("BedFloor", Vector3.new(6.8, 0.5, 9.0), Vector3.new(0, 0.25, -4.5), tint(orange, -0.15), true)
	for _, sx in { -1, 1 } do
		bed("BedSide", Vector3.new(0.4, 3.6, 9.0), Vector3.new(sx * 3.2, 2.3, -4.5), orange)
		bed("BedRim", Vector3.new(0.7, 0.35, 9.2), Vector3.new(sx * 3.2, 4.25, -4.5), tint(orange, -0.2))
		for _, z in { -2.2, -4.5, -6.8 } do
			bed("Rib", Vector3.new(0.3, 3.6, 0.5), Vector3.new(sx * 3.45, 2.3, z), tint(orange, -0.2))
		end
	end
	bed("Headboard", Vector3.new(6.8, 4.6, 0.45), Vector3.new(0, 2.8, -8.8), orange)
	bed("CabGuard", Vector3.new(6.8, 0.4, 3.0), Vector3.new(0, 5.0, -10.3), tint(orange, -0.2), true)
	bed("Tailgate", Vector3.new(6.8, 3.6, 0.4), Vector3.new(0, 2.3, -0.2), tint(orange, -0.1))
	bed("TailHinge", Vector3.new(7.0, 0.4, 0.5), Vector3.new(0, 4.2, -0.2), BLACK)
	-- rear: bumper, lights, mud flaps
	blk(m, "RearBumper", Vector3.new(6.0, 0.6, 0.6), Vector3.new(0, 2.0, 10.7), Color3.fromRGB(70, 74, 84))
	for _, sx in { -1, 1 } do
		blk(m, "TailLight", Vector3.new(1.0, 0.6, 0.2), Vector3.new(sx * 2.2, 2.6, 10.75), Color3.fromRGB(255, 80, 70))
		blk(m, "MudFlap", Vector3.new(1.6, 1.6, 0.15), Vector3.new(sx * 3.0, 1.5, 11.0), BLACK)
	end
	-- six wheels: one steering axle, two driven axles with wider tyres
	for _, sx in { -3.0, 3.0 } do
		wheel(m, Vector3.new(sx, 1.9, -5.0), 1.9, 1.5, yellow)
		for _, z in { 4.6, 8.8 } do
			wheel(m, Vector3.new(sx, 1.9, z), 1.9, 1.8, yellow)
		end
	end
end

------------------------------------------------------------------ driveable vehicles
-- A vehicle is a REAL moving object: an unanchored model in Workspace.MB_Vehicles (one per player) built around a
-- VehicleSeat. Physics: a low-friction collision "Hull" slides on the ground while two constraints on the Root part
-- steer it: a LinearVelocity (horizontal velocity only, gravity stays free) and an AlignOrientation (keeps it upright and
-- sets the heading), so it cannot flip and has no wheel jitter. The DRIVING CLIENT (which owns the physics once seated)
-- runs the arcade controller in Controllers/VehicleDriveController from the seat's Throttle / Steer, which Roblox already fills
-- for keyboard, gamepad and touch. Stats (MaxSpeed from VehicleConfig + trained Speed share, Accel, Brake, Turn) are
-- published as seat attributes. The wheels are cosmetic.
local MODEL_FOLDER = "MB_Vehicles"
local vehicles: { [Player]: Model } = {}

-- seat position, hull box (width, length, z centre) per vehicle, in builder space (feet at the origin, front = -Z)
local LAYOUT: { [string]: { seat: Vector3, seatSize: Vector3, hull: Vector3, hullZ: number } } = {
	Wheelbarrow = { seat = Vector3.new(0, 2.2, 1.6), seatSize = Vector3.new(2.0, 0.5, 1.8), hull = Vector3.new(4.4, 1, 10), hullZ = -1.3 },
	HandCart = { seat = Vector3.new(0, 2.2, -3.0), seatSize = Vector3.new(2.4, 0.5, 1.8), hull = Vector3.new(4.6, 1, 9.2), hullZ = -1.7 },
	UtilityCart = { seat = Vector3.new(0, 2.15, 0.2), seatSize = Vector3.new(3.4, 0.5, 1.8), hull = Vector3.new(4.6, 1, 10.4), hullZ = 0.5 },
	Pickup = { seat = Vector3.new(0, 2.7, -0.3), seatSize = Vector3.new(3.6, 0.5, 1.9), hull = Vector3.new(5.4, 1, 14.6), hullZ = 0 },
	BuilderBuggy = { seat = Vector3.new(0, 2.7, -0.3), seatSize = Vector3.new(3.0, 0.5, 1.9), hull = Vector3.new(4.8, 1, 10.4), hullZ = -0.1 },
	DumpTruck = { seat = Vector3.new(0, 3.8, -0.6), seatSize = Vector3.new(4.0, 0.5, 2.0), hull = Vector3.new(7.0, 1, 20.2), hullZ = 1.3 },
}
-- exposed for Studio previews (render a vehicle in Edit mode to check proportions)
VehicleService.Builders = Builders
VehicleService.Layout = LAYOUT

local function vehiclesFolder(): Folder
	local f = workspace:FindFirstChild(MODEL_FOLDER)
	if not f then
		f = Instance.new("Folder")
		f.Name = MODEL_FOLDER
		f.Parent = workspace
	end
	return f :: Folder
end

local function seatOf(m: Model): VehicleSeat?
	return m:FindFirstChild("DriverSeat") :: VehicleSeat?
end

function VehicleService.Get(player: Player): Model?
	local m = vehicles[player]
	return if m and m.Parent then m else nil
end

local function despawn(player: Player)
	local m = vehicles[player]
	vehicles[player] = nil
	if m then
		m:Destroy()
	end
	player:SetAttribute("Driving", nil)
end

local function groundY(pos: Vector3, ignore: { Instance }): number
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 30, 0), Vector3.new(0, -80, 0), params)
	return if hit then hit.Position.Y else 0
end

-- publish the numbers the drive controller reads (call again when trained Speed changes)
function VehicleService.RefreshStats(player: Player, baseSpeed: number)
	local m = VehicleService.Get(player)
	local seat = m and seatOf(m)
	if not m or not seat then
		return
	end
	local id = m:GetAttribute("VehicleId")
	local def = VehicleConfig.Vehicles[id]
	if not def then
		return
	end
	seat:SetAttribute("MaxSpeed", Formulas.VehicleSpeed(id, baseSpeed))
end

-- COSMETIC SKINS. Every part remembers its builder colour (BaseColor / BaseMaterial); a skin recolours the vehicle's two
-- most common "paint" colours (body, then accent) and leaves tyres, glass, lights and chrome alone. Skins never touch stats.
local SKIP_NAMES = { Wheel = true, Hub = true, HubCap = true, SteeringWheel = true, SteeringHub = true, Light = true, TailLight = true, Root = true, Hull = true, DriverSeat = true, Windshield = true, SideWindow = true, Grille = true }

local function applySkinTo(m: Model, skinId: string?)
	local skin = skinId and CosmeticConfig.Get("VehicleSkin", skinId)
	local counts: { [string]: number } = {}
	local byKey: { [string]: Color3 } = {}
	local paintParts: { BasePart } = {}
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			local base = p:GetAttribute("BaseColor") :: Color3?
			if base then
				p.Color = base
				p.Material = (Enum.Material :: any)[p:GetAttribute("BaseMaterial") :: string]
			end
			if base and not SKIP_NAMES[p.Name] and p.Transparency < 0.5 and p.Material ~= Enum.Material.Neon and p.Material ~= Enum.Material.Glass and select(3, base:ToHSV()) > 0.45 and (select(2, base:ToHSV()) > 0.3 or select(3, base:ToHSV()) > 0.85) then
				local key = base:ToHex()
				counts[key] = (counts[key] or 0) + 1
				byKey[key] = base
				table.insert(paintParts, p)
			end
		end
	end
	if not skin then
		return
	end
	local keys = {}
	for k in counts do
		table.insert(keys, k)
	end
	table.sort(keys, function(a, b)
		return counts[a] > counts[b]
	end)
	local map: { [string]: Color3 } = {}
	if keys[1] then
		map[keys[1]] = skin.Body
	end
	if keys[2] then
		map[keys[2]] = skin.Accent
	end
	for _, p in paintParts do
		local to = map[(p:GetAttribute("BaseColor") :: Color3):ToHex()]
		if to then
			p.Color = to
			if skin.Material then
				p.Material = skin.Material
			end
		end
	end
end

-- Re-applies the owner's equipped skin to their live vehicle (also called when the equip changes).
function VehicleService.ApplySkin(player: Player)
	local m = VehicleService.Get(player)
	if m then
		local d = S.PlayerDataService.Get(player)
		applySkinTo(m, d and d.Equipped and d.Equipped.VehicleSkin)
	end
end

local function exitSpot(seat: VehicleSeat, width: number): CFrame
	return seat.CFrame * CFrame.new(-(width / 2 + 3), 1.5, 0)
end

local function spawnVehicle(player: Player, def: any): Model?
	despawn(player)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	local builder = Builders[def.Builder]
	local layout = LAYOUT[def.Id]
	if not hrp or not hum or not builder or not layout then
		return nil
	end
	local m = Instance.new("Model")
	m.Name = tostring(player.UserId)
	m:SetAttribute("VehicleId", def.Id)
	m:SetAttribute("Owner", player.UserId)
	builder(m)
	local root = m.PrimaryPart :: BasePart
	-- cosmetic builder seat parts that the real seat replaces
	local old = m:FindFirstChild("Seat")
	if old then
		old:Destroy()
	end
	-- collision hull (the only part that collides, slides with zero friction)
	local hull = part(m, { Name = "Hull", Size = layout.hull, Transparency = 1, CanCollide = true, CanQuery = false, CanTouch = false, Massless = false, CFrame = CFrame.new(0, 0.55, layout.hullZ) })
	hull.CustomPhysicalProperties = PhysicalProperties.new(0.5, 0, 0, 100, 1)
	local seat = Instance.new("VehicleSeat")
	seat.Name = "DriverSeat"
	seat.Size = layout.seatSize
	seat.Color = Color3.fromRGB(46, 50, 62)
	seat.Material = Enum.Material.SmoothPlastic
	seat.Anchored = false
	seat.CanCollide = false
	seat.CanQuery = true
	seat.CanTouch = true
	seat.Massless = true
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.CFrame = CFrame.new(layout.seat)
	seat.Parent = m
	seat:SetAttribute("MBVehicle", true)
	seat:SetAttribute("VehicleId", def.Id)
	seat:SetAttribute("Accel", def.Accel)
	seat:SetAttribute("Brake", def.Brake)
	seat:SetAttribute("Turn", def.Turn)
	seat:SetAttribute("Reverse", VehicleConfig.ReverseFactor)
	seat:SetAttribute("MaxSpeed", def.Speed)
	-- place in the world: in front of the player, on the ground, facing the same way
	local look = Vector3.new(hrp.CFrame.LookVector.X, 0, hrp.CFrame.LookVector.Z)
	look = if look.Magnitude > 0.1 then look.Unit else Vector3.new(0, 0, -1)
	local flat = hrp.Position + look * 10
	-- spawn half a stud up and let it settle: the hull is long and must never start inside a raised pad or kerb
	-- (starting inside one can push the light hull down through thin floor parts)
	local gy = groundY(flat, { char :: Instance, m }) + 0.5
	local origin = CFrame.lookAt(Vector3.new(flat.X, gy, flat.Z), Vector3.new(flat.X, gy, flat.Z) + look)
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p.CFrame = origin * p.CFrame
			if p ~= root then
				local w = Instance.new("WeldConstraint")
				w.Part0 = root
				w.Part1 = p
				w.Parent = p
			end
		end
	end
	for _, p in m:GetDescendants() do
		if p:IsA("BasePart") then
			p:SetAttribute("BaseColor", p.Color)
			p:SetAttribute("BaseMaterial", p.Material.Name)
		end
	end
	do
		local d = S.PlayerDataService.Get(player)
		applySkinTo(m, d and d.Equipped and d.Equipped.VehicleSkin)
	end
	-- steering constraints on the root
	local att = Instance.new("Attachment")
	att.Name = "DriveAtt"
	att.Parent = root
	local drive = Instance.new("LinearVelocity")
	drive.Name = "Drive"
	drive.Attachment0 = att
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.ForceLimitMode = Enum.ForceLimitMode.PerAxis -- (Magnitude mode ignores MaxAxesForce and would also fight gravity)
	drive.MaxAxesForce = Vector3.new(400000, 0, 400000) -- no vertical force: gravity stays free
	drive.VectorVelocity = Vector3.zero
	drive.Parent = root
	local _, yaw = origin:ToOrientation()
	local upright = Instance.new("AlignOrientation")
	upright.Name = "Upright"
	upright.Mode = Enum.OrientationAlignmentMode.OneAttachment
	upright.Attachment0 = att
	upright.CFrame = CFrame.Angles(0, yaw, 0)
	upright.MaxTorque = 1e7
	upright.Responsiveness = 60
	upright.RigidityEnabled = false
	upright.Parent = root
	-- explicit "Drive" prompt for re-entering after you stepped out (also the only way on controllers / touch)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Drive"
	prompt.ObjectText = def.DisplayName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = seat
	prompt.Triggered:Connect(function(who)
		local c = who.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if who == player and h and h.Health > 0 and not seat.Occupant then
			seat:Sit(h)
		end
	end)
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		local occ = seat.Occupant
		if occ then
			local who = Players:GetPlayerFromCharacter(occ.Parent)
			if who ~= player then
				occ.Sit = false
				occ.Jump = true
				return
			end
			prompt.Enabled = false
			player:SetAttribute("Driving", def.Id)
		else
			prompt.Enabled = true
			drive.VectorVelocity = Vector3.zero
			local _, yawNow = root.CFrame:ToOrientation()
			upright.CFrame = CFrame.Angles(0, yawNow, 0) -- the server keeps the parked heading
			player:SetAttribute("Driving", nil)
			-- step out beside the vehicle, never inside it
			local c = player.Character
			local h = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
			if h then
				task.defer(function()
					h.CFrame = exitSpot(seat, layout.hull.X)
				end)
			end
		end
		S.UpgradeService.RefreshMovement(player)
		S.ResourceService.RefreshCapacity(player)
	end)
	m.Parent = vehiclesFolder()
	vehicles[player] = m
	return m
end

function VehicleService.Init(registry)
	S = registry
end

-- owned = bought/granted (resets on prestige) OR a Master Builder vehicle recorded in the permanent MasterBuilder.Vehicles
local function ownsData(d: any, id: string): boolean
	if d.Vehicles.Owned[id] then
		return true
	end
	local def = VehicleConfig.Vehicles[id]
	return def ~= nil and def.Master == true and d.MasterBuilder ~= nil and d.MasterBuilder.Vehicles ~= nil and d.MasterBuilder.Vehicles[id] == true
end

function VehicleService.Owns(player: Player, id: string): boolean
	local d = S.PlayerDataService.Get(player)
	return d ~= nil and ownsData(d, id)
end

-- Equip = spawn your (one) vehicle in front of you and sit in it. Unequip (nil) parks / removes it.
function VehicleService.Equip(player: Player, id: string?): (boolean, string)
	local d = S.PlayerDataService.Get(player)
	if not d then
		return false, "Data not loaded"
	end
	if id ~= nil then
		local def = VehicleConfig.Vehicles[id]
		if not def then
			return false, "Unknown vehicle"
		end
		if not ownsData(d, id) then
			return false, "You don't own that"
		end
		if player:GetAttribute("TrainKind") or player:GetAttribute("TrainCarry") then
			return false, "Finish training first"
		end
		player:SetAttribute("Vehicle", id)
		local m = spawnVehicle(player, def)
		if m then
			local seat = seatOf(m)
			local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
			if seat and hum then
				task.delay(0.35, function()
					if seat.Parent and not seat.Occupant and hum.Health > 0 then
						seat:Sit(hum)
					end
				end)
			end
		end
	else
		player:SetAttribute("Vehicle", nil)
		despawn(player)
	end
	d.Vehicles.Equipped = id
	S.PlayerDataService.MarkDirty(player)
	S.UpgradeService.RefreshMovement(player)
	S.ResourceService.RefreshCapacity(player)
	return true, id and "Vehicle ready! Hold W to drive, Jump to get out." or "Vehicle parked"
end

function VehicleService.Grant(player: Player, id: string)
	local d = S.PlayerDataService.Get(player)
	if d then
		d.Vehicles.Owned[id] = true
		S.PlayerDataService.MarkDirty(player)
	end
end

local limiter = Net.RateLimiter(2, 4)

function VehicleService.Start()
	Net.Event("VehicleCommand").OnServerEvent:Connect(function(player, cmd, id)
		if not limiter(player) then
			return
		end
		if cmd == "Equip" and type(id) == "string" then
			local ok, msg = VehicleService.Equip(player, id)
			Net.Event("Notify"):FireClient(player, ok and "Info" or "Error", msg)
		elseif cmd == "Unequip" then
			VehicleService.Equip(player, nil)
		end
	end)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(char)
			if not char:WaitForChild("HumanoidRootPart", 10) or not char:WaitForChild("Humanoid", 5) then
				return
			end
			task.wait(0.4)
			local id = player:GetAttribute("Vehicle")
			if player.Parent and id and VehicleConfig.Vehicles[id] then
				-- after a respawn the vehicle waits beside you (you step in with the Drive prompt)
				spawnVehicle(player, VehicleConfig.Vehicles[id])
				S.UpgradeService.RefreshMovement(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		despawn(p)
	end)
	S.PlayerDataService.Loaded:Connect(function(player, data)
		local eq = data.Vehicles.Equipped
		if eq and ownsData(data, eq) then
			VehicleService.Equip(player, eq)
		end
	end)
	-- safety net: a vehicle that fell out of the world or got stranded is brought back beside its owner
	task.spawn(function()
		while true do
			task.wait(2)
			for player, m in vehicles do
				local okV, errV = pcall(function()
				local root = m.Parent and m.PrimaryPart
				local id = player:GetAttribute("Vehicle")
				if id and not VehicleConfig.Vehicles[id] then
					id = nil
				end
				local seat = seatOf(m)
				local hrp = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
				local lost = not root or root.Position.Y < -30
				if id and hrp and seat and (lost or (not seat.Occupant and (root.Position - hrp.Position).Magnitude > 700)) then
					local was = seat.Occupant
					local nm = spawnVehicle(player, VehicleConfig.Vehicles[id])
					local ns = nm and seatOf(nm)
					if was and ns then
						task.delay(0.3, function()
							if ns.Parent and not ns.Occupant then
								ns:Sit(was)
							end
						end)
					end
				end
				end)
				if not okV then
					warn("[Vehicle] recovery error:", errV)
				end
			end
		end
	end)
end

return VehicleService
