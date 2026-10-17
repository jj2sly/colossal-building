--!strict
-- AMBIENCE (client only): makes the valley feel alive without touching gameplay.
--   * Ambient audio: one quiet 2D breeze bed + one LOW spatial loop per destination (SoundConfig.Ambient), all in the MB_Ambience
--     sound group so big moments can duck it (Cine.duck). Rolloff keeps each landmark local.
--   * Environmental motion: nearby trees sway, the reactor halos turn, the sawmill blade spins, hanging loads sway, the furnace
--     flickers, energy pulses run along a few cables, a little dust at the excavation, leaves drift in the Ancient Grove.
--     Everything is distance-gated, updated at ~30 Hz from ONE loop, and restored exactly when out of range.
--   * Rare landmark one-shots: a metal clank in the metal yards, a transformer spark at the Power Plant, a rock knock at the dig.
--   * Event atmosphere: a small identity per world event (grade / vignette / pulse) while it runs.
--   * Server Luck tier-up: a small banner, a chime and a restrained world pulse (Legendary Site is bigger).
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage.Shared
local ResourceSpotConfig = require(Shared.Config.ResourceSpotConfig)
local SoundConfig = require(Shared.Config.SoundConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Sound = require(Lib.Sound)
local State = require(Lib.State)
local Cine = require(Lib.Cine)

local AmbienceController = {}
local T = UI.Theme

------------------------------------------------------------------ ambient audio
local SPOT_BED = {
	Forest = "Forest", LumberCamp = "Forest", TimberStand = "Redwood",
	Quarry = "Wind", DeepQuarry = "Wind", BoulderField = "Wind",
	Mine = "Industrial", IndustrialYard = "Industrial", SteelWorks = "Industrial",
	Energy = "Hum", ReactorYard = "Hum", CoreVault = "Reactor",
	StarCrater = "Cosmic", AncientGrove = "Grove",
}
local SPOT_VOLUME = { Mine = 0.8, Energy = 0.8, Quarry = 0.8, Forest = 0.9 }

local function bed(name: string, pos: Vector3?, volumeScale: number?)
	local def = SoundConfig.Ambient[name]
	if not def then
		return
	end
	local s = Instance.new("Sound")
	s.Name = "Amb_" .. name
	s.SoundId = def.SoundId
	s.Looped = true
	s.Volume = def.Volume * (volumeScale or 1)
	s.PlaybackSpeed = def.Pitch
	s.SoundGroup = Cine.ambienceGroup()
	if pos and def.Max > 0 then
		local a = Instance.new("Part")
		a.Name = "AmbAnchor_" .. name
		a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch = true, false, false, false
		a.Transparency = 1
		a.Size = Vector3.one
		a.Position = pos
		a.Parent = Cine.folder()
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = def.Min
		s.RollOffMaxDistance = def.Max
		s.Parent = a
	else
		s.Parent = SoundService
	end
	s.TimePosition = math.random() * 10
	s:Play()
end

local function startAudio()
	bed("Breeze", nil)
	bed("HubBirds", Vector3.new(0, 8, 190))
	bed("Site", Vector3.new(0, 8, 205))
	-- (Pass 20D) the site equipment hums quietly: one low spatial loop at the silo cluster
	local world = workspace:WaitForChild("World", 30)
	local silo = world and world:FindFirstChild("SitePolish") and world.SitePolish:FindFirstChild("Silos")
	local housing = silo and silo:FindFirstChild("SiloHousing", true) :: BasePart?
	if housing then
		bed("Industrial", housing.Position, 0.5)
	end
	for _, spot in ResourceSpotConfig.List() do
		local b = SPOT_BED[spot.Id]
		if b then
			bed(b, spot.Position + Vector3.new(0, 8, 0), SPOT_VOLUME[spot.Id])
		end
	end
end

------------------------------------------------------------------ environmental motion
local camPos = Vector3.zero
local now = 0

type Sway = { parts: { BasePart }, orig: { CFrame }, pivot: Vector3, amp: number, phase: number, freq: number, active: boolean }
local trees: { Sway } = {}

local function canopyOf(m: Model): { BasePart }
	local out = {}
	for _, c in m:GetChildren() do
		if c:IsA("BasePart") and (c.Name == "Leaves" or c.Name == "Tier" or c.Name == "Crown") then
			table.insert(out, c)
		end
	end
	return out
end

local function addTree(m: Model, amp: number)
	local parts = canopyOf(m)
	if #parts == 0 then
		return
	end
	local lo = math.huge
	local x, z = 0, 0
	for _, p in parts do
		lo = math.min(lo, p.Position.Y - p.Size.Y / 2)
		x += p.Position.X
		z += p.Position.Z
	end
	local orig = {}
	for i, p in parts do
		orig[i] = p.CFrame
	end
	table.insert(trees, { parts = parts, orig = orig, pivot = Vector3.new(x / #parts, lo, z / #parts), amp = amp, phase = math.random() * 6.28, freq = 0.7 + math.random() * 0.5, active = false })
end

local WIND = Vector3.new(1, 0, 0.35).Unit
local WIND_AXIS = WIND:Cross(Vector3.yAxis)

local function updateTrees()
	for _, t in trees do
		local near = (t.pivot - camPos).Magnitude < 170
		if near then
			t.active = true
			local a = math.rad(t.amp) * (math.sin(now * t.freq + t.phase) * 0.7 + math.sin(now * t.freq * 2.3 + t.phase) * 0.3)
			local k = CFrame.new(t.pivot) * CFrame.fromAxisAngle(WIND_AXIS, a) * CFrame.new(-t.pivot)
			for i, p in t.parts do
				p.CFrame = k * t.orig[i]
			end
		elseif t.active then
			t.active = false
			for i, p in t.parts do
				p.CFrame = t.orig[i]
			end
		end
	end
end

-- generic rotators / pendulums for a handful of named landmark parts
type Mover = { parts: { BasePart }, orig: { CFrame }, at: Vector3, fn: (number) -> CFrame, range: number }
local movers: { Mover } = {}

local function addMover(parts: { BasePart }, at: Vector3, range: number, fn: (number) -> CFrame)
	if #parts == 0 then
		return
	end
	local orig = {}
	for i, p in parts do
		orig[i] = p.CFrame
	end
	table.insert(movers, { parts = parts, orig = orig, at = at, fn = fn, range = range })
end

local function updateMovers()
	for _, m in movers do
		if (m.at - camPos).Magnitude < m.range then
			local k = m.fn(now)
			for i, p in m.parts do
				p.CFrame = k * m.orig[i]
			end
		end
	end
end

local function zone(id: string): Instance?
	local w = workspace:FindFirstChild("World")
	local z = w and w:FindFirstChild("Zones")
	return z and z:FindFirstChild(id)
end

local function named(root: Instance?, name: string): { BasePart }
	local out = {}
	if root then
		for _, d in root:GetDescendants() do
			if d:IsA("BasePart") and d.Name == name then
				table.insert(out, d)
			end
		end
	end
	return out
end

-- a pendulum hanging from the top of `rope` (rope + load swing together)
local function pendulum(rope: BasePart?, loads: { BasePart }, ampDeg: number, period: number)
	if not rope then
		return
	end
	local top = rope.Position + Vector3.new(0, rope.Size.Y / 2, 0)
	local parts = { rope }
	for _, l in loads do
		table.insert(parts, l)
	end
	local phase = math.random() * 6
	addMover(parts, top, 220, function(t)
		local a = math.rad(ampDeg) * math.sin(t * 2 * math.pi / period + phase)
		return CFrame.new(top) * CFrame.fromAxisAngle(WIND_AXIS, a) * CFrame.new(-top)
	end)
end

local flickers: { { at: Vector3, fn: (number) -> () } } = {}
local pulses: { { a: Vector3, b: Vector3, ball: BasePart, period: number, offset: number } } = {}

local function addPulse(a: Vector3, b: Vector3, color: Color3, period: number)
	local ball = Instance.new("Part")
	ball.Name = "CablePulse"
	ball.Anchored, ball.CanCollide, ball.CanQuery, ball.CanTouch = true, false, false, false
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.one * 0.9
	ball.Material = Enum.Material.Neon
	ball.Color = color
	ball.Transparency = 1
	ball.CastShadow = false
	ball.Parent = Cine.folder()
	table.insert(pulses, { a = a, b = b, ball = ball, period = period, offset = math.random() * period })
end

local function updatePulses()
	for _, p in pulses do
		if ((p.a + p.b) / 2 - camPos).Magnitude < 220 then
			-- travel, then rest (a pulse every few seconds, not a constant stream)
			local k = ((now + p.offset) % p.period) / 1.4
			if k <= 1 then
				p.ball.Position = p.a:Lerp(p.b, k)
				p.ball.Transparency = 0.15 + 0.6 * math.abs(k - 0.5)
			else
				p.ball.Transparency = 1
			end
		else
			p.ball.Transparency = 1
		end
	end
end

local function buildMotion()
	-- trees (decor + young trees + redwood crowns)
	local world = workspace:WaitForChild("World", 30)
	if not world then
		return
	end
	local scenery = world:FindFirstChild("Scenery")
	if scenery then
		for _, m in scenery:GetChildren() do
			if m:IsA("Model") and m.Name == "Tree" then
				addTree(m, 1.6)
			end
		end
	end
	local zones = world:FindFirstChild("Zones")
	if zones then
		for _, d in zones:GetDescendants() do
			if d:IsA("Model") and (d.Name == "YoungTree" or d.Name == "Tree") then
				addTree(d, 1.8)
			elseif d:IsA("Model") and d.Name == "Redwood" then
				addTree(d, 0.5)
			end
		end
	end
	-- sawmill blade spins slowly
	for _, blade in named(zone("LumberCamp"), "SawBlade") do
		local c = blade.CFrame
		addMover({ blade }, c.Position, 160, function(t)
			return c * CFrame.Angles(math.rad(t * 140), 0, 0) * c:Inverse()
		end)
	end
	-- hanging loads sway
	local camp = zone("LumberCamp")
	pendulum(named(camp, "CraneRope")[1], named(camp, "HoistLog"), 2.5, 5.5)
	local scrap = zone("Mine")
	pendulum(named(scrap, "Cable")[1], named(scrap, "Magnet"), 3, 4.6)
	local quarry = zone("DeepQuarry")
	pendulum(named(quarry, "Rope")[1], named(quarry, "HangingBlock"), 1.6, 6)
	local steel = zone("SteelWorks")
	pendulum(named(steel, "HoistCable")[1], named(steel, "HangingIngot"), 1.4, 6.5)
	-- reactor: the two halo rings turn in opposite directions, the core breathes
	local vault = zone("CoreVault")
	local core = named(vault, "Core")[1]
	if core then
		local center = core.Position
		local rings: { [number]: { BasePart } } = {}
		for _, h in named(vault, "Halo") do
			local key = math.floor(h.Position.Y + 0.5)
			rings[key] = rings[key] or {}
			table.insert(rings[key], h)
		end
		local dir = 1
		for _, list in rings do
			local d = dir
			addMover(list, center, 260, function(t)
				return CFrame.new(center) * CFrame.Angles(0, math.rad(t * 9 * d), 0) * CFrame.new(-center)
			end)
			dir = -dir
		end
		local light = core:FindFirstChildOfClass("PointLight")
		if light then
			local base = light.Brightness
			table.insert(flickers, { at = center, fn = function(t)
				light.Brightness = base * (0.85 + 0.15 * math.sin(t * 1.6))
			end })
		end
		for _, c in named(vault, "Conduit") do
			local half = c.CFrame.LookVector * c.Size.Z / 2
			addPulse(c.Position - half, c.Position + half, Color3.fromRGB(160, 245, 255), 3.2 + math.random())
		end
	end
	-- power plant lines carry a pulse now and then
	local plant = zone("ReactorYard")
	for _, l in named(plant, "Line") do
		local half = l.CFrame.LookVector * l.Size.Z / 2
		addPulse(l.Position - half, l.Position + half, Color3.fromRGB(150, 230, 255), 4.5 + math.random())
	end
	-- foundry: furnace light and hot windows flicker softly
	local foundry = zone("IndustrialYard")
	local mouth = named(foundry, "FurnaceMouth")[1]
	if mouth then
		local l = mouth:FindFirstChildOfClass("PointLight")
		local windows = named(foundry, "HotWindow")
		-- (art reset pass 4) restrained heat: deep orange to warm amber, never a bright neon sign
		local hot, warm = Color3.fromRGB(132, 92, 36), Color3.fromRGB(112, 76, 30)
		table.insert(flickers, { at = mouth.Position, fn = function(t)
			local n = math.noise(t * 1.7, 0.3) * 0.5 + 0.5
			if l then
				l.Brightness = 0.7 + n * 0.4
			end
			for i, w in windows do
				w.Color = warm:Lerp(hot, math.noise(t * 1.3, i * 0.7) * 0.5 + 0.5)
			end
		end })
	end
	-- (art reset) no always-on ambient particles here: excavation dust and grove leaves removed

	-- (Pass 20D) SITE CRANE idles: the trolley creeps a few studs along the jib and back, the hook and its load bob gently.
	-- Small amplitudes around the authored position, so it never swings over the build volume.
	local crane = world:FindFirstChild("SitePolish") and world.SitePolish:FindFirstChild("Crane")
	if crane then
		local jib = crane:FindFirstChild("CraneJib", true) :: BasePart?
		if jib then
			local s = jib.Size
			local axis = if s.X >= s.Y and s.X >= s.Z then jib.CFrame.RightVector elseif s.Z >= s.Y then jib.CFrame.LookVector else jib.CFrame.UpVector
			axis = Vector3.new(axis.X, 0, axis.Z).Unit
			local ph = math.random() * 10
			local function slide(t: number): number
				return math.sin((t + ph) * 2 * math.pi / 38) * 4 + math.sin((t + ph) * 2 * math.pi / 13) * 0.6
			end
			local riders = {}
			for _, n in { "CraneTrolley", "CraneCable" } do
				for _, p in named(crane, n) do
					table.insert(riders, p)
				end
			end
			local hooked = {}
			for _, n in { "CraneHook", "CraneLoad" } do
				for _, p in named(crane, n) do
					table.insert(hooked, p)
				end
			end
			addMover(riders, jib.Position, 300, function(t)
				return CFrame.new(axis * slide(t))
			end)
			addMover(hooked, jib.Position, 300, function(t)
				return CFrame.new(axis * slide(t) + Vector3.new(0, math.sin((t + ph) * 2 * math.pi / 23) * 0.9, 0))
			end)
		end
		-- a restrained amber warning beacon on the crane apex: a short blink about every two seconds
		local apex = crane:FindFirstChild("CraneApex", true) :: BasePart?
		if apex then
			local light = Instance.new("PointLight")
			light.Name = "MB_Beacon"
			light.Color = Color3.fromRGB(255, 170, 60)
			light.Range = 10
			light.Brightness = 2.2
			light.Shadows = false
			light.Enabled = false
			light.Parent = apex
			local period = 1.9 + math.random() * 0.3
			table.insert(flickers, { at = apex.Position, fn = function(t)
				light.Enabled = (t % period) < 0.18
			end })
		end
	end
end

------------------------------------------------------------------ (Pass 20D) occasional site + zone life
-- One slow loop; every source has its own randomised interval, only fires when the camera is near, and is a short local
-- burst (no always-on emitters, nothing replicated, no physics). Sounds are the existing quiet ambience cues.
type Life = { at: Vector3, kind: string, scale: number, min: number, max: number, nextAt: number, range: number, sound: string? }
local life: { Life } = {}
local function addLife(at: Vector3, kind: string, scale: number, min: number, max: number, range: number?, sound: string?)
	table.insert(life, { at = at, kind = kind, scale = scale, min = min, max = max, nextAt = os.clock() + min * math.random(), range = range or 260, sound = sound })
end

-- only parts that are actually in the world (some retired zone props are parked far below the map)
local function shown(parts: { BasePart }): { BasePart }
	local out = {}
	for _, p in parts do
		if p.Position.Y > -500 and p.Transparency < 1 then
			table.insert(out, p)
		end
	end
	return out
end

local function buildLife()
	local world = workspace:FindFirstChild("World")
	if not world then
		return
	end
	local site = world:FindFirstChild("SitePolish")
	-- silo vents
	for _, cap in named(site and site:FindFirstChild("Silos"), "SiloCap") do
		addLife(cap.Position + Vector3.new(0, cap.Size.Y / 2 + 0.5, 0), "Steam", 0.7, 9, 20)
	end
	-- dust settling at a few points of the pad edge (positions picked once, the loop alternates between them)
	for i = 1, 4 do
		local a = math.rad(i * 90 + math.random(-30, 30))
		addLife(Vector3.new(math.cos(a) * 99, 2.5, math.sin(a) * 99), "Dust", 0.35, 14, 30)
	end
	-- WOOD: leaves drift down in the Stick Grove
	for i, l in named(zone("Forest"), "Leaves") do
		if i % 2 == 1 then
			addLife(l.Position, "Leaf", 1, 7, 16, 180)
		end
	end
	-- STONE: a little rock dust and a knock at the Rock Field
	local rubble = named(zone("Quarry"), "Rubble")
	for i = 1, math.min(3, #rubble) do
		addLife(rubble[i].Position + Vector3.new(0, 1, 0), "Stone", 0.8, 10, 22, 200, if i == 1 then "Thud" else nil)
	end
	-- METAL: sparks off two of the scrap presses and the foundry mouth
	local presses = shown(named(zone("Mine"), "Housing"))
	for i = 1, math.min(2, #presses) do
		local h = presses[i * 3 - 2] or presses[i]
		addLife(h.Position + Vector3.new(0, h.Size.Y / 2, 0), "Metal", 0.6, 8, 18, 200)
	end
	for _, m in shown(named(zone("IndustrialYard"), "FurnaceMouth")) do
		addLife(m.Position, "Metal", 0.5, 8, 18, 220)
	end
	-- POWER: the turbine hall stack vents vapor, a battery rack crackles now and then (restrained cyan)
	for _, e in shown(named(zone("ReactorYard"), "ExhaustStack")) do
		addLife(e.Position + Vector3.new(0, e.Size.Y / 2 + 1, 0), "Steam", 0.8, 10, 22, 260)
	end
	local caps = shown(named(zone("Energy"), "Cap"))
	for i = 1, math.min(2, #caps) do
		local c = caps[i * 3 - 2] or caps[i]
		addLife(c.Position + Vector3.new(0, c.Size.Y / 2 + 0.5, 0), "Power", 0.45, 10, 22, 160, if i == 1 then "Zap" else nil)
	end
end

local function lifeLoop()
	while true do
		task.wait(0.5)
		local t = os.clock()
		for _, l in life do
			if t >= l.nextAt then
				l.nextAt = t + l.min + math.random() * (l.max - l.min)
				if (l.at - camPos).Magnitude < l.range then
					Cine.burst(l.at, l.kind, l.scale)
					if l.sound then
						Sound.PlayAt(l.sound, l.at, 70, 0.2)
					end
				end
			end
		end
	end
end

-- (Pass 21I) SITE TRAFFIC: a few client-only work trucks loop the ring road (path = the lane's dashes, sorted round the centre).
-- Visual only: anchored, no collision, no physics; they slow down near players so nobody gets "run through".
local function siteTraffic()
	local hubLanes = workspace:WaitForChild("World", 30) and workspace.World:FindFirstChild("CirculationHub")
	if not hubLanes then
		return
	end
	local pts = {}
	for _, d in hubLanes:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "LaneDash" then
			table.insert(pts, d.Position)
		end
	end
	if #pts < 8 then
		return
	end
	table.sort(pts, function(a, b)
		return math.atan2(a.Z, a.X) < math.atan2(b.Z, b.X)
	end)
	local cum = { 0 }
	for i = 2, #pts + 1 do
		local a, b = pts[i - 1], pts[(i - 1) % #pts + 1]
		cum[i] = cum[i - 1] + (b - a).Magnitude
	end
	local total = cum[#pts + 1]
	local function at(dist: number): (Vector3, Vector3)
		dist = dist % total
		for i = 1, #pts do
			if dist <= cum[i + 1] then
				local a, b = pts[i], pts[i % #pts + 1]
				local t = (dist - cum[i]) / math.max(0.01, cum[i + 1] - cum[i])
				return a:Lerp(b, t), (b - a).Unit
			end
		end
		return pts[1], (pts[2] - pts[1]).Unit
	end
	local folder = Instance.new("Folder")
	folder.Name = "MB_Traffic"
	folder.Parent = workspace
	local function part(m: Model, size: Vector3, cf: CFrame, color: Color3, mat: Enum.Material?, shape: Enum.PartType?)
		local p = Instance.new("Part")
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
		p.Size, p.Color, p.Material = size, color, mat or Enum.Material.SmoothPlastic
		if shape then
			p.Shape = shape
		end
		p.CFrame = cf
		p.Parent = m
		return p
	end
	local trucks = {}
	local colors = { Color3.fromRGB(255, 194, 38), Color3.fromRGB(96, 170, 230), Color3.fromRGB(230, 120, 50) }
	for i = 1, 3 do
		local m = Instance.new("Model")
		m.Name = "WorkTruck"
		local root = part(m, Vector3.new(4.4, 1.6, 8), CFrame.new(), Color3.fromRGB(46, 50, 60), Enum.Material.Metal)
		part(m, Vector3.new(4.2, 2.4, 2.8), CFrame.new(0, 1.9, -2.4), colors[i])
		part(m, Vector3.new(3.8, 1, 0.2), CFrame.new(0, 2.4, -3.85), Color3.fromRGB(150, 210, 240), Enum.Material.Glass)
		part(m, Vector3.new(4.4, 1.4, 4.6), CFrame.new(0, 1.5, 1.4), colors[i]:Lerp(Color3.new(0, 0, 0), 0.25))
		if i ~= 2 then
			part(m, Vector3.new(1.6, 1.4, 1.6), CFrame.new(-0.9, 2.9, 1.2), Color3.fromRGB(176, 120, 66), Enum.Material.WoodPlanks)
			part(m, Vector3.new(1.4, 1.2, 1.4), CFrame.new(1.0, 2.8, 2.2), Color3.fromRGB(150, 104, 62), Enum.Material.WoodPlanks)
		else
			part(m, Vector3.new(0.6, 0.6, 4.2), CFrame.new(-1, 2.5, 1.4), Color3.fromRGB(140, 150, 166), Enum.Material.Metal)
			part(m, Vector3.new(0.6, 0.6, 4.2), CFrame.new(1, 2.5, 1.4), Color3.fromRGB(140, 150, 166), Enum.Material.Metal)
		end
		for _, wx in { -2.2, 2.2 } do
			for _, wz in { -2.6, 2.6 } do
				part(m, Vector3.new(0.7, 1.8, 1.8), CFrame.new(wx, -0.5, wz), Color3.fromRGB(28, 30, 36), nil, Enum.PartType.Cylinder)
			end
		end
		local beacon = part(m, Vector3.new(0.6, 0.4, 0.6), CFrame.new(0, 3.3, -2.4), Color3.fromRGB(255, 160, 40), Enum.Material.Neon)
		m.PrimaryPart = root
		-- parts were built around the origin: remember their offsets from the root
		local offs = {}
		for _, p in m:GetChildren() do
			offs[p] = p.CFrame
		end
		m.Parent = folder
		table.insert(trucks, { model = m, root = root, offs = offs, dist = total * (i - 1) / 3, speed = 20 + i * 2, beacon = beacon })
	end
	local last = os.clock()
	RunService.RenderStepped:Connect(function()
		local t = os.clock()
		local dt = math.min(0.1, t - last)
		last = t
		if (camPos - pts[1]).Magnitude > 600 then
			return
		end
		local players = {}
		for _, plr in Players:GetPlayers() do
			local hrp = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
			if hrp then
				table.insert(players, hrp.Position)
			end
		end
		for _, tr in trucks do
			local pos, dir = at(tr.dist)
			-- ease off when a player stands in the lane ahead
			local ahead = pos + dir * 10
			local slow = 1
			for _, pp in players do
				if (Vector3.new(pp.X, 0, pp.Z) - Vector3.new(ahead.X, 0, ahead.Z)).Magnitude < 9 then
					slow = 0
				end
			end
			tr.v = (tr.v or tr.speed) + ((tr.speed * slow) - (tr.v or tr.speed)) * math.min(1, dt * 3)
			tr.dist += tr.v * dt
			local cf = CFrame.lookAt(Vector3.new(pos.X, pos.Y + 1.9, pos.Z), Vector3.new(pos.X + dir.X, pos.Y + 1.9, pos.Z + dir.Z))
			for p, off in tr.offs do
				p.CFrame = cf * off
			end
			tr.beacon.Transparency = if (t * 2.5) % 1 < 0.5 then 0 else 0.7
		end
	end)
end

-- a tiny visual-only flock crosses the valley now and then (anchored, no collision, client only)
local function birds()
	while true do
		task.wait(35 + math.random() * 45)
		local cam = workspace.CurrentCamera
		if cam then
			local center = camPos
			local a = math.random() * math.pi * 2
			local dir = Vector3.new(math.cos(a), 0, math.sin(a))
			local side = Vector3.new(-dir.Z, 0, dir.X)
			local start = center - dir * 260 + side * math.random(-90, 90) + Vector3.new(0, 80 + math.random() * 40, 0)
			local folder = Instance.new("Folder")
			folder.Name = "MB_Birds"
			folder.Parent = workspace
			local flock = {}
			for i = 1, 4 + math.random(0, 2) do
				local b = Instance.new("Part")
				b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow = true, false, false, false, false
				b.Size = Vector3.new(1.8, 0.15, 0.7)
				b.Color = Color3.fromRGB(46, 48, 54)
				b.Material = Enum.Material.SmoothPlastic
				b.Parent = folder
				local row = math.ceil(i / 2)
				table.insert(flock, { part = b, off = -dir * row * 4 + side * (if i % 2 == 0 then row * 3 else -row * 3) + Vector3.new(0, math.random() * 1.5, 0), ph = math.random() * 6 })
			end
			local speed = 12 + math.random() * 4
			local t0 = os.clock()
			local conn
			conn = RunService.RenderStepped:Connect(function()
				local t = os.clock() - t0
				local head = start + dir * speed * t
				for _, f in flock do
					local flap = math.sin((t + f.ph) * 9) * 0.5
					f.part.CFrame = CFrame.lookAt(head + f.off, head + f.off + dir) * CFrame.Angles(0, 0, flap)
				end
				if t > 520 / speed then
					conn:Disconnect()
					folder:Destroy()
				end
			end)
		end
	end
end

------------------------------------------------------------------ landmark one-shots
local function oneShots()
	local metal = { zone("IndustrialYard"), zone("SteelWorks"), zone("Mine") }
	local plant = zone("ReactorYard")
	local dig = zone("BoulderField")
	while true do
		task.wait(6 + math.random() * 7)
		local r = math.random()
		if r < 0.45 then
			local z = metal[math.random(1, #metal)]
			local spot = z and z:FindFirstChild("GatherPoint") :: BasePart?
			if spot and (spot.Position - camPos).Magnitude < 120 then
				local p = spot.Position + Vector3.new(math.random(-20, 20), 0, math.random(-20, 20))
				Sound.PlayAt("GatherMetal", p, 110, 0.2)
			end
		elseif r < 0.75 then
			local banks = named(plant, "TransformerBank")
			local b = banks[math.random(1, math.max(1, #banks))]
			if b and (b.Position - camPos).Magnitude < 110 then
				local p = b.Position + Vector3.new(0, b.Size.Y / 2 + 1.2, 0)
				Cine.burst(p, "Power", 0.8)
				Sound.PlayAt("Zap", p, 90, 0.2)
			end
		else
			local bucket = named(dig, "Bucket")[1]
			if bucket and (bucket.Position - camPos).Magnitude < 140 then
				Cine.burst(bucket.Position - Vector3.new(0, 2, 0), "Dust", 0.5)
				Sound.PlayAt("Thud", bucket.Position, 120, 0.15)
			end
		end
	end
end

------------------------------------------------------------------ event atmosphere
local eventFx: { () -> () } = {}
local function clearEventFx()
	for _, fn in eventFx do
		pcall(fn)
	end
	table.clear(eventFx)
end

local function holdGrade(props: { [string]: any })
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "MB_EventGrade"
	cc.Parent = game:GetService("Lighting")
	UI.tween(cc, 1.5, props)
	table.insert(eventFx, function()
		UI.tween(cc, 1.2, { TintColor = Color3.new(1, 1, 1), Saturation = 0, Brightness = 0, Contrast = 0 })
		task.delay(1.3, function()
			cc:Destroy()
		end)
	end)
end

local function onEvent(id: string?)
	clearEventFx()
	if id == "MeteorShower" then
		holdGrade({ TintColor = Color3.fromRGB(255, 236, 222), Contrast = 0.05 })
	elseif id == "Earthquake" then
		holdGrade({ TintColor = Color3.fromRGB(250, 240, 226), Saturation = -0.06 })
	elseif id == "GoldenHour" then
		Cine.bloom(0.12, 1.5, 9999, 1.2)
		table.insert(eventFx, function()
			Cine.bloom(0, 0.01, 0, 1.2)
		end)
	elseif id == "WorkerStrike" then
		holdGrade({ Saturation = -0.12 })
	elseif id == "DoubleCarry" then
		Cine.ring(Vector3.new(0, 0.5, 104), Color3.fromRGB(120, 230, 140), 90, 1.6)
	elseif id == "BuildFrenzy" then
		Cine.vignette(Color3.fromRGB(255, 140, 50), 0.28, 0.6, 1.2, 1.4)
		local alive = true
		task.spawn(function()
			while alive do
				local a = math.random() * math.pi * 2
				Cine.burst(Vector3.new(math.cos(a) * 38, 4, math.sin(a) * 38), "Spark", 0.6)
				task.wait(2.5 + math.random() * 2)
			end
		end)
		table.insert(eventFx, function()
			alive = false
		end)
	elseif id == "ResourceRush" then
		Cine.ring(Vector3.new(0, 0.5, 104), Color3.fromRGB(255, 220, 90), 70, 1.4)
	end
end

------------------------------------------------------------------ Server Luck tier-up
local gui: ScreenGui? = nil
local function tierBanner(name: string, big: boolean)
	gui = gui or UI.root("ServerTier", 5)
	local holder = UI.new("Frame", { BackgroundColor3 = Color3.fromRGB(26, 30, 44), BackgroundTransparency = 0.25, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 96), Size = UDim2.fromOffset(if big then 460 else 360, if big then 64 else 50), Parent = gui })
	UI.corner(holder, 10)
	UI.stroke(holder, Color3.fromRGB(255, 205, 80), 2)
	local scale = UI.new("UIScale", { Scale = 0.85, Parent = holder })
	local top = UI.new("TextLabel", { Text = "SERVER UPGRADED", Font = T.Bold, TextSize = 13, TextColor3 = Color3.fromRGB(255, 220, 140), Position = UDim2.fromOffset(0, 4), Size = UDim2.new(1, 0, 0, 16), Parent = holder })
	local title = UI.new("TextLabel", { Text = string.upper(name), Font = T.Title, TextSize = if big then 32 else 24, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(0, 18), Size = UDim2.new(1, 0, 1, -20), Parent = holder })
	UI.textStroke(title, 1.6)
	UI.tween(scale, UI.Anim.Normal, { Scale = 1 }, Enum.EasingStyle.Back)
	task.delay(if big then 5 else 3.5, function()
		UI.tween(holder, UI.Anim.Slow, { BackgroundTransparency = 1 })
		UI.tween(top, UI.Anim.Slow, { TextTransparency = 1 })
		UI.tween(title, UI.Anim.Slow, { TextTransparency = 1, TextStrokeTransparency = 1 })
		local s = holder:FindFirstChildOfClass("UIStroke")
		if s then
			UI.tween(s, UI.Anim.Slow, { Transparency = 1 })
		end
		task.delay(UI.Anim.Slow + 0.05, function()
			holder:Destroy()
		end)
	end)
end

local function tierIndex(id: string?): number
	for i, st in EconomyConfig.ServerStates do
		if st.Id == id then
			return i
		end
	end
	return 0
end

local function watchTier()
	local last = tierIndex(State.Get("ServerState"))
	State.Changed("ServerState", function(id)
		local i = tierIndex(id)
		if i > last and i > 1 then
			local st = EconomyConfig.ServerStates[i]
			local big = st.Id == "Legendary"
			tierBanner(st.Name, big)
			Sound.Play("Chime")
			task.delay(0.25, function()
				Sound.Play("ChimeLow")
			end)
			Cine.ring(Vector3.new(0, 2.4, 0), Color3.fromRGB(255, 206, 90), if big then 160 else 110, if big then 2.2 else 1.6)
			Cine.bloom(if big then 0.25 else 0.1, 0.4, 0.6, 1.2)
			if big then
				Cine.grade({ TintColor = Color3.fromRGB(255, 236, 200), Saturation = 0.08 }, 0.6, 2, 1.6)
				Cine.vignette(Color3.fromRGB(255, 196, 70), 0.3, 0.6, 2, 1.4)
				Sound.Play("Cheer")
			end
		end
		last = i
	end)
end

------------------------------------------------------------------ vehicles (presentation only: no speed or handling is touched)
-- Each vehicle gets ONE looped sound on its body whose pitch/volume follow its speed (hand-pushed carts rattle, the Utility Cart
-- whirs, the Pickup hums brighter, the Dump Truck rumbles low), and a puff of dust from the rear wheels on a hard stop.
local VEHICLE_SOUND = {
	Wheelbarrow = { "rbxassetid://9119096873", 0.16, 1.25 },
	HandCart = { "rbxassetid://9119096873", 0.2, 1.0 },
	UtilityCart = { "rbxassetid://9125767745", 0.12, 1.25 },
	Pickup = { "rbxassetid://9125767745", 0.16, 0.85 },
	DumpTruck = { "rbxassetid://9113119896", 0.3, 0.75 },
}
type Ride = { model: Model, root: BasePart, sound: Sound, base: number, vol: number, max: number, last: number, dustAt: number }
local rides: { [Model]: Ride } = {}
local pendingRide: { [Instance]: boolean } = {}

local function trackVehicle(m: Instance)
	if not m:IsA("Model") then
		return
	end
	pendingRide[m] = true
	task.spawn(function()
		-- the model arrives before its parts finish replicating: wait for the body
		local root = m.PrimaryPart or m:WaitForChild("Root", 10) :: BasePart?
		local id = m:GetAttribute("VehicleId")
		local t0 = os.clock()
		while not id and m.Parent and os.clock() - t0 < 10 do
			task.wait(0.2) -- the server sets the id just after the model appears
			id = m:GetAttribute("VehicleId")
		end
		local def = VEHICLE_SOUND[id or ""]
		pendingRide[m] = nil
		if not root or not def or rides[m] then
			return
		end
		local seat = m:FindFirstChildWhichIsA("VehicleSeat", true)
		local snd = Instance.new("Sound")
		snd.Name = "MB_Engine"
		snd.SoundId = def[1]
		snd.Looped = true
		snd.Volume = 0
		snd.PlaybackSpeed = def[3]
		snd.RollOffMode = Enum.RollOffMode.InverseTapered
		snd.RollOffMinDistance = 10
		snd.RollOffMaxDistance = 90
		snd.Parent = root
		snd:Play()
		rides[m] = { model = m, root = root, sound = snd, base = def[3], vol = def[2], max = (seat and seat:GetAttribute("MaxSpeed") or 40) :: number, last = 0, dustAt = 0 }
	end)
end

local function updateRides(dt: number)
	for m, r in rides do
		if not m.Parent or not r.root.Parent then
			rides[m] = nil
			continue
		end
		local v = r.root.AssemblyLinearVelocity * Vector3.new(1, 0, 1)
		local speed = v.Magnitude
		local k = math.clamp(speed / math.max(1, r.max), 0, 1)
		local occupied = false
		local seat = m:FindFirstChildWhichIsA("VehicleSeat", true)
		if seat and seat.Occupant then
			occupied = true
		end
		local targetVol = if occupied then r.vol * (0.45 + 0.55 * k) else r.vol * k
		r.sound.Volume += (targetVol - r.sound.Volume) * math.min(1, dt * 6)
		r.sound.PlaybackSpeed = r.base * (0.85 + 0.45 * k)
		-- brake feedback: a sharp drop in speed kicks up dust behind the vehicle
		local decel = (r.last - speed) / math.max(dt, 1e-3)
		if decel > 60 and r.last > 12 and now - r.dustAt > 0.6 then
			r.dustAt = now
			Cine.burst(r.root.Position - r.root.CFrame.LookVector * 3 - Vector3.new(0, 1.5, 0), "Dust", 0.35)
		end
		r.last = speed
	end
end

------------------------------------------------------------------ start
function AmbienceController.Start()
	Cine.ambienceGroup()
	task.spawn(startAudio)
	task.spawn(function()
		buildMotion()
		local acc, flickAcc = 0, 0
		RunService.Heartbeat:Connect(function(dt)
			acc += dt
			flickAcc += dt
			if acc < 1 / 30 then
				return
			end
			acc = 0
			now = os.clock()
			local cam = workspace.CurrentCamera
			camPos = if cam then cam.CFrame.Position else camPos
			updateTrees()
			updateMovers()
			updatePulses()
			updateRides(1 / 30)
			if flickAcc > 0.1 then
				flickAcc = 0
				for _, f in flickers do
					if (f.at - camPos).Magnitude < 220 then
						f.fn(now)
					end
				end
			end
		end)
		buildLife()
		task.spawn(lifeLoop)
		task.spawn(birds)
		task.spawn(siteTraffic)
		oneShots()
	end)
	-- vehicles come and go (equip, respawn): a slow poll picks up any untracked one
	task.spawn(function()
		while true do
			local vehicles = workspace:FindFirstChild("MB_Vehicles")
			if vehicles then
				for _, m in vehicles:GetChildren() do
					if m:IsA("Model") and not rides[m] and not pendingRide[m] then
						trackVehicle(m)
					end
				end
			end
			task.wait(1)
		end
	end)
	State.Changed("EventId", onEvent)
	if (State.Get("EventId") or "") ~= "" then
		onEvent(State.Get("EventId"))
	end
	watchTier()
end

return AmbienceController
