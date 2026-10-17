--!nonstrict
-- (Pass 21S) PREMIUM COSMETIC VISUALS, client only. One signature look per named cosmetic in CosmeticConfig:
--   * DELIVERY effects (ContributionEffect): a short, choreographed show at the build site when the wearer delivers.
--   * TRAILS (Trail): ribbons plus a signature extra (stripes, embers, dashes, orbiting orbs, floating lanterns...).
--   * VEHICLE SKIN extras (VehicleSkin): the server repaints the vehicle; this adds the premium details (underglow, beacon,
--     headlight beams, glints, exhaust embers) to any vehicle whose model carries a Skin attribute.
-- Cheap by construction: no physics (every moving piece is an anchored part posed from a formula each frame), bursts
-- are short-lived and capped, trails only animate while their wearer moves, everything is culled by camera distance.
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local CosmeticFX = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

local function seq(list)
	if typeof(list) == "Color3" then
		return ColorSequence.new(list)
	end
	if #list == 1 then
		return ColorSequence.new(list[1])
	end
	local kps = {}
	for i, c in list do
		table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#list - 1), c))
	end
	return ColorSequence.new(kps)
end

local function hard(colors, bands)
	-- hard-edged stripes along a trail: each band is a flat colour with a tiny ramp to the next
	local kps = {}
	for i = 0, bands - 1 do
		local c = colors[i % #colors + 1]
		local a, b = i / bands, (i + 1) / bands
		table.insert(kps, ColorSequenceKeypoint.new(a, c))
		table.insert(kps, ColorSequenceKeypoint.new(math.max(a, b - 0.001), c))
	end
	kps[#kps] = ColorSequenceKeypoint.new(1, kps[#kps].Value)
	return ColorSequence.new(kps)
end

local function rainbowSeq(off, sat)
	local kps = {}
	for i = 0, 6 do
		table.insert(kps, ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((off + i / 7) % 1, sat or 0.6, 1)))
	end
	return ColorSequence.new(kps)
end

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Material = Enum.Material.Neon
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in props do
		p[k] = v
	end
	p.Parent = parent
	return p
end

local function emitter(parent, s)
	local e = Instance.new("ParticleEmitter")
	e.Texture = s.tex or SPARK
	e.Color = seq(s.color)
	e.LightEmission = s.light or 0.8
	e.Lifetime = NumberRange.new(s.life[1], s.life[2])
	e.Speed = NumberRange.new(s.speed[1], s.speed[2])
	e.SpreadAngle = Vector2.new(s.spread or 180, s.spread or 180)
	e.Acceleration = s.accel or Vector3.zero
	e.Drag = s.drag or 0
	e.RotSpeed = NumberRange.new(-150, 150)
	e.Rotation = NumberRange.new(0, 360)
	local s0, s1 = s.size, s.size2 or 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s0), NumberSequenceKeypoint.new(1, s1) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, s.trans or 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.Rate = s.rate or 0
	e.EmissionDirection = s.dir or Enum.NormalId.Top
	e.Enabled = s.rate ~= nil and s.rate > 0
	e.Parent = parent
	return e
end

-- ONE shared animation loop for every burst, trail extra and skin detail ------------------------------------------------
local anims = {} -- { step = function(t, dt) -> keepAlive }
local loop = nil
local function run(step)
	table.insert(anims, step)
	if not loop then
		loop = RunService.Heartbeat:Connect(function(dt)
			local t = os.clock()
			for i = #anims, 1, -1 do
				local ok, alive = pcall(anims[i], t, dt)
				if not ok or not alive then
					table.remove(anims, i)
				end
			end
			if #anims == 0 and loop then
				loop:Disconnect()
				loop = nil
			end
		end)
	end
end

local function ring(folder, at, color, r0, r1, dur, thick, t0)
	-- a flat expanding shock ring (a thin neon cylinder lying on its side)
	local p = part(folder, { Shape = Enum.PartType.Cylinder, Color = color, Size = Vector3.new(thick or 0.25, r0 * 2, r0 * 2), CFrame = CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)) })
	run(function(t)
		local f = math.clamp((t - t0) / dur, 0, 1)
		if not p.Parent then
			return false
		end
		local e = 1 - (1 - f) ^ 3
		local r = r0 + (r1 - r0) * e
		p.Size = Vector3.new(thick or 0.25, r * 2, r * 2)
		p.Transparency = 0.1 + 0.9 * f
		return f < 1
	end)
	return p
end

local function pop(folder, at, color, r, dur, t0)
	-- the instant of impact: a bright neon sphere that swells and fades
	local p = part(folder, { Shape = Enum.PartType.Ball, Color = color, Size = Vector3.one * 0.5, CFrame = CFrame.new(at) })
	run(function(t)
		local f = math.clamp((t - t0) / dur, 0, 1)
		if not p.Parent then
			return false
		end
		local s = 0.5 + (r * 2 - 0.5) * (1 - (1 - f) ^ 3)
		p.Size = Vector3.one * s
		p.Transparency = 0.15 + 0.85 * f
		return f < 1
	end)
end

local function flash(folder, at, color, brightness, range, dur, t0)
	local holder = part(folder, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(at) })
	local l = Instance.new("PointLight")
	l.Color, l.Range, l.Brightness, l.Shadows = color, range, brightness, false
	l.Parent = holder
	run(function(t)
		local f = math.clamp((t - t0) / dur, 0, 1)
		if not holder.Parent then
			return false
		end
		l.Brightness = brightness * (1 - f) ^ 2
		return f < 1
	end)
end

local function boltChain(folder, from, to, color, width, segs)
	-- jagged lightning between two points: beams through jittered attachments on one anchor part
	local anchor = part(folder, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(from) })
	local atts = {}
	for k = 0, segs do
		local a = Instance.new("Attachment")
		a.Parent = anchor
		atts[k] = a
	end
	local beams = {}
	for k = 1, segs do
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = atts[k - 1], atts[k]
		b.Color = seq(color)
		b.Width0, b.Width1 = width, width
		b.LightEmission, b.FaceCamera, b.Segments = 1, true, 1
		b.Transparency = NumberSequence.new(0)
		b.Parent = anchor
		beams[k] = b
	end
	local function rejig()
		local dir = to - from
		local side = dir:Cross(Vector3.yAxis)
		side = if side.Magnitude > 0.01 then side.Unit else Vector3.xAxis
		local up = dir.Unit:Cross(side)
		for k = 0, segs do
			local f = k / segs
			local jag = if k == 0 or k == segs then 0 else dir.Magnitude * 0.08
			atts[k].WorldPosition = from + dir * f + side * (math.random() - 0.5) * 2 * jag + up * (math.random() - 0.5) * 2 * jag
		end
	end
	rejig()
	return anchor, beams, rejig
end

-- DELIVERY EFFECTS ----------------------------------------------------------------------------------------------------------
local Delivery = {}

-- Golden Sparks: a fountain of spinning gold coins with a spark spray, a gold shock ring and a warm flash
Delivery.GoldenSparks = function(f, at, s, t0)
	local coins = {}
	for i = 1, math.floor(14 * s) do
		local a = math.random() * math.pi * 2
		local out = (6 + math.random() * 7) * s
		table.insert(coins, {
			p = part(f, { Shape = Enum.PartType.Cylinder, Material = Enum.Material.Metal, Reflectance = 0.25, Color = rgb(255, 200, 50), Size = Vector3.new(0.22, 1.1, 1.1) * s, CFrame = CFrame.new(at) }),
			v = Vector3.new(math.cos(a) * out, (24 + math.random() * 10) * s, math.sin(a) * out),
			spin = 8 + math.random() * 10,
		})
	end
	run(function(t)
		local dt = t - t0
		local f2 = dt / 1.6
		for _, c in coins do
			if c.p.Parent then
				local pos = at + c.v * dt + Vector3.new(0, -0.5 * 46 * dt * dt, 0)
				c.p.CFrame = CFrame.new(pos) * CFrame.Angles(dt * c.spin, dt * c.spin * 0.6, 0)
				c.p.Transparency = math.clamp((f2 - 0.7) / 0.3, 0, 1)
			end
		end
		return f2 < 1
	end)
	local holder = part(f, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(at) })
	emitter(holder, { color = { rgb(255, 246, 190), rgb(255, 170, 40) }, life = { 0.5, 0.9 }, speed = { 18, 30 }, spread = 40, accel = Vector3.new(0, -30, 0), size = 0.7, drag = 1 }):Emit(math.floor(36 * s))
	ring(f, at - Vector3.new(0, 1, 0), rgb(255, 210, 80), 1, 11 * s, 0.6, 0.3, t0)
	pop(f, at, rgb(255, 220, 110), 2.6 * s, 0.3, t0)
	flash(f, at, rgb(255, 210, 100), 6, 22, 0.6, t0)
	return 1.7
end

-- Robot Bolts: a storm strike: three jagged bolts slam down, a cyan shock ring, glowing chips scatter
Delivery.RobotBolts = function(f, at, s, t0)
	local bolts = {}
	for i = 1, 3 do
		local top = at + Vector3.new((math.random() - 0.5) * 10, 22 + math.random() * 6, (math.random() - 0.5) * 10) * s
		local anchor, beams, rejig = boltChain(f, top, at, { rgb(240, 255, 255), rgb(90, 200, 255) }, 0.55 * s, 7)
		table.insert(bolts, { anchor = anchor, beams = beams, rejig = rejig, start = t0 + (i - 1) * 0.09 })
	end
	local last = 0
	run(function(t)
		local dt = t - t0
		if t - last > 0.05 then
			last = t
			for _, b in bolts do
				local on = t >= b.start and t - b.start < 0.42
				for _, bm in b.beams do
					bm.Enabled = on and math.random() > 0.1
				end
				if on then
					b.rejig()
				end
			end
		end
		return dt < 0.75
	end)
	local chips = {}
	for i = 1, math.floor(10 * s) do
		local a = math.random() * math.pi * 2
		table.insert(chips, { p = part(f, { Color = rgb(110, 220, 255), Size = Vector3.one * 0.45 * s, CFrame = CFrame.new(at) }), v = Vector3.new(math.cos(a) * 16, 12 + math.random() * 10, math.sin(a) * 16) * s })
	end
	run(function(t)
		local dt = t - t0
		for _, c in chips do
			c.p.CFrame = CFrame.new(at + c.v * dt + Vector3.new(0, -30 * dt * dt, 0)) * CFrame.Angles(dt * 9, dt * 7, 0)
			c.p.Transparency = math.clamp((dt - 0.5) / 0.5, 0, 1)
		end
		return dt < 1
	end)
	ring(f, at - Vector3.new(0, 1, 0), rgb(110, 220, 255), 1, 13 * s, 0.5, 0.3, t0 + 0.05)
	ring(f, at - Vector3.new(0, 1, 0), rgb(230, 250, 255), 0.5, 7 * s, 0.35, 0.2, t0 + 0.15)
	pop(f, at, rgb(170, 235, 255), 2.4 * s, 0.25, t0 + 0.05)
	flash(f, at + Vector3.new(0, 3, 0), rgb(140, 220, 255), 8, 26, 0.5, t0)
	return 1.1
end

-- Confetti Burst: a party popper: dozens of tumbling, fluttering paper flakes and four curling streamers
Delivery.ConfettiBurst = function(f, at, s, t0)
	local PAL = { rgb(255, 90, 170), rgb(90, 220, 255), rgb(255, 225, 70), rgb(140, 255, 120), rgb(190, 120, 255), rgb(255, 150, 70) }
	local flakes = {}
	for i = 1, math.floor(42 * s) do
		local a = math.random() * math.pi * 2
		local out = (3 + math.random() * 9) * s
		table.insert(flakes, {
			p = part(f, { Material = Enum.Material.SmoothPlastic, Color = PAL[i % #PAL + 1], Size = Vector3.new(0.8, 0.06, 0.5) * s, CFrame = CFrame.new(at) }),
			v = Vector3.new(math.cos(a) * out, (22 + math.random() * 12) * s, math.sin(a) * out),
			ph = math.random() * 6, spin = 6 + math.random() * 8,
		})
	end
	run(function(t)
		local dt = t - t0
		for _, c in flakes do
			-- strong drag: shoots up, then hangs and flutters down with a side-to-side sway
			local k = 1.5
			local decay = (1 - math.exp(-k * dt)) / k
			local pos = at + Vector3.new(c.v.X * decay, c.v.Y * decay - 7 * dt, c.v.Z * decay) + Vector3.new(math.sin(dt * 5 + c.ph) * 0.8, 0, math.cos(dt * 4 + c.ph) * 0.8) * math.min(dt, 1)
			c.p.CFrame = CFrame.new(pos) * CFrame.Angles(dt * c.spin, c.ph, dt * c.spin * 0.7)
			c.p.Transparency = math.clamp((dt - 1.8) / 0.6, 0, 1)
		end
		return dt < 2.4
	end)
	for i = 1, 4 do
		local head = part(f, { Size = Vector3.one * 0.3 * s, Color = PAL[i], CFrame = CFrame.new(at) })
		local a0 = Instance.new("Attachment")
		a0.Position = Vector3.new(0, 0.35 * s, 0)
		a0.Parent = head
		local a1 = Instance.new("Attachment")
		a1.Position = Vector3.new(0, -0.35 * s, 0)
		a1.Parent = head
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = a0, a1
		tr.Color = seq({ PAL[i], PAL[(i + 2) % #PAL + 1] })
		tr.Lifetime, tr.LightEmission, tr.FaceCamera = 0.6, 0.4, true
		tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		tr.Parent = head
		local a = (i / 4) * math.pi * 2
		run(function(t)
			local dt = t - t0
			local h = 18 * s * (1 - (1 - math.min(dt / 0.9, 1)) ^ 2)
			local r = (2 + dt * 6) * s
			head.CFrame = CFrame.new(at + Vector3.new(math.cos(a + dt * 6) * r, h - math.max(0, dt - 0.9) ^ 2 * 10, math.sin(a + dt * 6) * r))
			return dt < 1.6
		end)
	end
	local holder = part(f, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(at) })
	emitter(holder, { color = { rgb(255, 255, 255), rgb(255, 200, 240) }, life = { 0.3, 0.5 }, speed = { 14, 22 }, spread = 50, size = 0.9 }):Emit(math.floor(18 * s))
	pop(f, at, rgb(255, 230, 250), 1.8 * s, 0.22, t0)
	flash(f, at, rgb(255, 200, 240), 4, 18, 0.4, t0)
	return 2.6
end

-- Blueprint Burst: a glowing blueprint wireframe cube unfolds and spins up out of the delivery, framed by a square
-- grid outline on the ground, then dissolves into white sparks (the construction-plan fantasy)
Delivery.BlueprintBurst = function(f, at, s, t0)
	local anchor = part(f, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(at) })
	local corners = {}
	for i = 1, 8 do
		local a = Instance.new("Attachment")
		a.Parent = anchor
		corners[i] = a
	end
	local EDGES = { { 1, 2 }, { 2, 4 }, { 4, 3 }, { 3, 1 }, { 5, 6 }, { 6, 8 }, { 8, 7 }, { 7, 5 }, { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 } }
	local beams = {}
	for _, e in EDGES do
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = corners[e[1]], corners[e[2]]
		b.Color = seq({ rgb(70, 160, 255), rgb(190, 230, 255) })
		b.Width0, b.Width1 = 0.36 * s, 0.36 * s
		b.LightEmission, b.FaceCamera, b.Segments = 0.45, true, 1
		b.Parent = anchor
		table.insert(beams, b)
	end
	-- the ground outline: a square of four beams
	local sq = {}
	for i = 1, 4 do
		local a = Instance.new("Attachment")
		a.Parent = anchor
		sq[i] = a
	end
	local grid = {}
	for i = 1, 6 do
		local b = Instance.new("Beam")
		-- 4 sides of the square, then its two diagonals (the drafting cross)
		b.Attachment0, b.Attachment1 = if i <= 4 then sq[i] else sq[i - 4], if i <= 4 then sq[i % 4 + 1] else sq[i - 2]
		b.Color = seq(rgb(60, 150, 255))
		b.Width0, b.Width1 = 0.25 * s, 0.25 * s
		b.LightEmission, b.FaceCamera, b.Segments = 0.4, true, 1
		b.Parent = anchor
		table.insert(grid, b)
	end
	run(function(t)
		local dt = t - t0
		local grow = 1 - (1 - math.clamp(dt / 0.55, 0, 1)) ^ 3
		local half = 3.6 * s * grow
		local lift = 2 + 7 * s * grow
		local rot = CFrame.new(at + Vector3.new(0, lift, 0)) * CFrame.Angles(dt * 0.9, dt * 2.2, dt * 0.5)
		local i = 0
		for x = -1, 1, 2 do
			for y = -1, 1, 2 do
				for z = -1, 1, 2 do
					i += 1
					corners[i].WorldPosition = (rot * CFrame.new(x * half, y * half, z * half)).Position
				end
			end
		end
		local g = 9 * s * grow
		local pts = { Vector3.new(-g, 0, -g), Vector3.new(g, 0, -g), Vector3.new(g, 0, g), Vector3.new(-g, 0, g) }
		for k = 1, 4 do
			sq[k].WorldPosition = at + Vector3.new(0, -1, 0) + (CFrame.Angles(0, dt * 0.6, 0) * pts[k])
		end
		local fade = math.clamp((dt - 1.1) / 0.5, 0, 1)
		for _, b in beams do
			b.Transparency = NumberSequence.new(fade)
		end
		for _, b in grid do
			b.Transparency = NumberSequence.new(0.2 + 0.8 * fade)
		end
		return dt < 1.7
	end)
	local holder = part(f, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(at + Vector3.new(0, 8 * s, 0)) })
	local e = emitter(holder, { color = { rgb(255, 255, 255), rgb(140, 200, 255) }, life = { 0.5, 0.9 }, speed = { 6, 14 }, size = 0.55, drag = 2 })
	task.delay(1.15, function()
		if e.Parent then
			e:Emit(math.floor(30 * s))
		end
	end)
	flash(f, at + Vector3.new(0, 6, 0), rgb(130, 190, 255), 5, 20, 1.2, t0)
	return 1.9
end

-- Firework Burst: a rocket streaks up and bursts into a rainbow chrysanthemum of trailing stars
Delivery.FireworkBurst = function(f, at, s, t0)
	local rocket = part(f, { Color = rgb(255, 240, 200), Size = Vector3.new(0.4, 1, 0.4) * s, CFrame = CFrame.new(at) })
	local a0 = Instance.new("Attachment")
	a0.Position = Vector3.new(0.2, 0, 0)
	a0.Parent = rocket
	local a1 = Instance.new("Attachment")
	a1.Position = Vector3.new(-0.2, 0, 0)
	a1.Parent = rocket
	local tr = Instance.new("Trail")
	tr.Attachment0, tr.Attachment1 = a0, a1
	tr.Color = seq({ rgb(255, 230, 160), rgb(255, 120, 40) })
	tr.Lifetime, tr.LightEmission, tr.FaceCamera = 0.35, 1, true
	tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0) })
	tr.Parent = rocket
	local peak = at + Vector3.new(0, 24 * s, 0)
	local stars = nil
	run(function(t)
		local dt = t - t0
		if dt < 0.5 then
			local e = 1 - (1 - dt / 0.5) ^ 2
			rocket.CFrame = CFrame.new(at:Lerp(peak, e))
			return true
		end
		if not stars then
			rocket.Transparency = 1
			tr.Enabled = false
			stars = {}
			local n = math.floor(22 * s)
			for i = 1, n do
				-- even directions on a sphere (golden spiral), each star a different hue
				local y = 1 - (i - 0.5) / n * 2
				local r = math.sqrt(1 - y * y)
				local th = i * 2.399
				local dir = Vector3.new(math.cos(th) * r, y * 0.8 + 0.2, math.sin(th) * r)
				local c = Color3.fromHSV(i / n, 0.8, 1)
				local p = part(f, { Shape = Enum.PartType.Ball, Color = c, Size = Vector3.one * 0.55 * s, CFrame = CFrame.new(peak) })
				local b0 = Instance.new("Attachment")
				b0.Position = Vector3.new(0, 0.25, 0)
				b0.Parent = p
				local b1 = Instance.new("Attachment")
				b1.Position = Vector3.new(0, -0.25, 0)
				b1.Parent = p
				local st = Instance.new("Trail")
				st.Attachment0, st.Attachment1 = b0, b1
				st.Color = seq({ Color3.new(1, 1, 1), c })
				st.Lifetime, st.LightEmission, st.FaceCamera = 0.6, 0.6, true
				st.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
				st.Parent = p
				table.insert(stars, { p = p, v = dir * 24 * s })
			end
			flash(f, peak, rgb(255, 240, 220), 9, 40, 0.6, t)
			ring(f, peak, rgb(255, 255, 255), 0.5, 6 * s, 0.25, 0.2, t)
		end
		local bt = dt - 0.5
		local k = 2.5
		local decay = (1 - math.exp(-k * bt)) / k
		for _, st in stars do
			st.p.CFrame = CFrame.new(peak + st.v * decay + Vector3.new(0, -5 * bt * bt, 0))
			st.p.Transparency = math.clamp((bt - 0.9) / 0.5, 0, 1)
		end
		return bt < 1.5
	end)
	return 2.1
end

-- Grand Burst: the Grand Master's starburst: a pillar of light, rotating golden spokes, twin shock rings and rising stars
Delivery.GrandBurst = function(f, at, s, t0)
	local anchor = part(f, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = CFrame.new(at) })
	local base = Instance.new("Attachment")
	base.Parent = anchor
	local top = Instance.new("Attachment")
	top.Position = Vector3.new(0, 60 * s, 0)
	top.Parent = anchor
	local pillar = Instance.new("Beam")
	pillar.Attachment0, pillar.Attachment1 = base, top
	pillar.Color = seq({ rgb(255, 236, 150), rgb(255, 255, 255) })
	pillar.LightEmission, pillar.FaceCamera, pillar.Segments = 1, true, 1
	pillar.Parent = anchor
	local spokes, tips = {}, {}
	local center = Instance.new("Attachment")
	center.Position = Vector3.new(0, 4 * s, 0)
	center.Parent = anchor
	for i = 1, 12 do
		local tip = Instance.new("Attachment")
		tip.Parent = anchor
		local b = Instance.new("Beam")
		b.Attachment0, b.Attachment1 = center, tip
		b.Color = seq({ rgb(255, 245, 210), rgb(255, 185, 40) })
		b.Width0, b.Width1 = 1.3 * s, 0.05
		b.LightEmission, b.FaceCamera, b.Segments = 0.6, true, 1
		b.Parent = anchor
		spokes[i], tips[i] = b, tip
	end
	local stars = {}
	for i = 1, math.floor(18 * s) do
		table.insert(stars, { p = part(f, { Color = if i % 3 == 0 then rgb(255, 250, 230) else rgb(255, 196, 60), Size = Vector3.new(0.45, 0.8, 0.45) * s, CFrame = CFrame.new(at) }), a = math.random() * 6.28, r = (3 + math.random() * 6) * s, sp = 0.6 + math.random() })
	end
	run(function(t)
		local dt = t - t0
		local pf = math.clamp(dt / 1.1, 0, 1)
		pillar.Width0 = 7 * s * (1 - pf)
		pillar.Width1 = 2 * s * (1 - pf)
		pillar.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1 + 0.9 * pf), NumberSequenceKeypoint.new(1, 1) })
		local grow = 1 - (1 - math.clamp(dt / 0.5, 0, 1)) ^ 3
		local sf = math.clamp((dt - 0.9) / 0.6, 0, 1)
		for i, tip in tips do
			local a = i / 12 * math.pi * 2 + dt * 1.4
			local len = (if i % 2 == 0 then 18 else 12) * s * grow
			tip.Position = Vector3.new(math.cos(a) * len, 4 * s, math.sin(a) * len)
			spokes[i].Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, sf), NumberSequenceKeypoint.new(1, 1) })
		end
		for _, st in stars do
			local h = dt * 14 * st.sp * s
			local a = st.a + dt * 2.5
			st.p.CFrame = CFrame.new(at + Vector3.new(math.cos(a) * st.r, h, math.sin(a) * st.r)) * CFrame.Angles(dt * 4, dt * 3, 0)
			st.p.Transparency = math.clamp((dt - 1.1) / 0.6, 0, 1)
		end
		return dt < 1.8
	end)
	ring(f, at - Vector3.new(0, 1, 0), rgb(255, 214, 90), 1, 18 * s, 0.7, 0.35, t0)
	ring(f, at - Vector3.new(0, 1, 0), rgb(255, 255, 255), 1, 11 * s, 0.5, 0.25, t0 + 0.12)
	pop(f, at + Vector3.new(0, 2, 0), rgb(255, 236, 170), 3.2 * s, 0.35, t0)
	flash(f, at + Vector3.new(0, 5, 0), rgb(255, 230, 160), 10, 45, 0.9, t0)
	return 1.9
end

CosmeticFX.DeliveryIds = { "GoldenSparks", "RobotBolts", "ConfettiBurst", "BlueprintBurst", "FireworkBurst", "GrandBurst" }

-- plays one delivery effect at `at`; scale < 1 for other players' deliveries. Returns false if the id has no show.
function CosmeticFX.Delivery(id: string, at: Vector3, scale: number?): boolean
	local fn = Delivery[id]
	if not fn then
		return false
	end
	local f = Instance.new("Folder")
	f.Name = "MB_Delivery_" .. id
	f.Parent = workspace
	local ok, dur = pcall(fn, f, at, scale or 1, os.clock())
	Debris:AddItem(f, (if ok then dur else 0) + 0.6)
	return ok
end

-- TRAILS ----------------------------------------------------------------------------------------------------------------------
-- ribbon = { top, bottom (HRP-space attachment offsets), color (ColorSequence), life, glow, trans (NumberSequence?) }
local function ribbonDef(top, bottom, color, life, glow, trans)
	return { top = top, bottom = bottom, color = color, life = life, glow = glow, trans = trans }
end
local FEET_T, FEET_B = Vector3.new(0, -1.6, 0.6), Vector3.new(0, -2.9, 0.6)
local FULL_T, FULL_B = Vector3.new(0, 0.6, 0.6), Vector3.new(0, -1.9, 0.6)
local function fade(a)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, a), NumberSequenceKeypoint.new(1, 1) })
end
local function dashed(a, n)
	-- n dashes along the trail: solid bands separated by fully clear gaps, fading toward the tail
	local kps = { NumberSequenceKeypoint.new(0, a) }
	for i = 0, n - 1 do
		local x0 = i / n
		local x1 = x0 + 0.55 / n
		local x2 = (i + 1) / n
		local v = a + (1 - a) * x0 * 0.7
		if i > 0 then
			table.insert(kps, NumberSequenceKeypoint.new(x0 + 0.002, v))
		end
		table.insert(kps, NumberSequenceKeypoint.new(x1, v))
		table.insert(kps, NumberSequenceKeypoint.new(x1 + 0.002, 1))
		if x2 < 1 then
			table.insert(kps, NumberSequenceKeypoint.new(x2, 1))
		end
	end
	table.insert(kps, NumberSequenceKeypoint.new(1, 1))
	return NumberSequence.new(kps)
end

local TRAILS = {
	-- puffs of sawdust and tumbling wood chips kicked up at your heels, over a short tan ribbon
	SawdustTrail = {
		ribbons = { ribbonDef(FEET_T, FEET_B, seq({ rgb(214, 168, 96), rgb(150, 100, 52) }), 0.55, 0, fade(0.08)) },
		emit = {
			{ at = Vector3.new(0, -2.8, 0.8), tex = SMOKE, color = { rgb(226, 196, 150), rgb(190, 160, 120) }, life = { 0.6, 1.0 }, speed = { 1, 3 }, spread = 70, accel = Vector3.new(0, 1.5, 0), size = 1.3, size2 = 3, trans = 0.2, light = 0, rate = 18, drag = 2 },
			{ at = Vector3.new(0, -2.6, 0.8), tex = "rbxasset://textures/particles/SquareParticle.png", color = { rgb(200, 140, 70), rgb(140, 95, 50) }, life = { 0.5, 0.8 }, speed = { 4, 8 }, spread = 60, accel = Vector3.new(0, -30, 0), size = 0.45, size2 = 0.3, trans = 0, light = 0, rate = 14 },
		},
	},
	-- bold caution stripes: a full-height ribbon of hard yellow/black bands with a bright edge line
	HazardTrail = {
		ribbons = {
			ribbonDef(FULL_T, FULL_B, hard({ rgb(255, 200, 20), rgb(28, 28, 34) }, 8), 0.9, 0, NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.75, 0.1), NumberSequenceKeypoint.new(1, 1) })),
			ribbonDef(Vector3.new(0, 0.75, 0.6), Vector3.new(0, 0.55, 0.6), seq(rgb(255, 255, 220)), 0.7, 1, fade(0.1)),
		},
	},
	-- a molten ribbon at your feet that spits rising embers and a curl of dark smoke
	LavaTrail = {
		ribbons = { ribbonDef(Vector3.new(0, -1.2, 0.6), FEET_B, seq({ rgb(255, 210, 70), rgb(255, 90, 10), rgb(120, 14, 4) }), 0.8, 0.35, fade(0)) },
		emit = {
			{ at = Vector3.new(0, -2.4, 0.9), color = { rgb(255, 230, 140), rgb(255, 90, 20) }, life = { 0.8, 1.4 }, speed = { 2, 6 }, spread = 35, accel = Vector3.new(0, 6, 0), size = 0.6, size2 = 0.1, trans = 0, light = 1, rate = 22, drag = 0.6 },
			{ at = Vector3.new(0, -1.6, 1.2), tex = SMOKE, color = { rgb(70, 50, 44), rgb(30, 26, 26) }, life = { 1.0, 1.6 }, speed = { 1, 2 }, spread = 25, accel = Vector3.new(0, 3, 0), size = 1, size2 = 3, trans = 0.65, light = 0, rate = 5, drag = 1 },
		},
		light = { color = rgb(255, 120, 40), range = 10, bright = 1.2 },
	},
	-- twin cosmic ribbons (cyan over violet) dusted with big twinkling stars
	StarTrail = {
		ribbons = {
			ribbonDef(Vector3.new(0, 0.9, 0.6), Vector3.new(0, 0.1, 0.6), seq({ rgb(80, 200, 255), rgb(50, 90, 255) }), 0.8, 0.35, fade(0.05)),
			ribbonDef(Vector3.new(0, -0.9, 0.6), Vector3.new(0, -1.7, 0.6), seq({ rgb(170, 90, 255), rgb(100, 40, 230) }), 0.8, 0.35, fade(0.05)),
		},
		emit = { { at = Vector3.new(0, -0.4, 1), color = { rgb(255, 255, 255), rgb(170, 200, 255) }, life = { 0.8, 1.4 }, speed = { 0.3, 1.2 }, size = 1.1, size2 = 0, trans = 0, light = 1, rate = 14 } },
	},
	-- a dashed blueprint line with a bright white centre stroke and drafting ticks
	BlueprintTrail = {
		ribbons = {
			ribbonDef(Vector3.new(0, 0.2, 0.6), Vector3.new(0, -1.6, 0.6), seq({ rgb(40, 120, 235), rgb(20, 60, 150) }), 0.9, 0.2, dashed(0.1, 5)),
			ribbonDef(Vector3.new(0, -0.6, 0.6), Vector3.new(0, -0.8, 0.6), seq(rgb(235, 245, 255)), 0.9, 1, fade(0)),
		},
		emit = { { at = Vector3.new(0, -0.7, 1), color = { rgb(235, 245, 255), rgb(120, 180, 255) }, life = { 0.5, 0.9 }, speed = { 0.2, 0.6 }, size = 0.35, size2 = 0, trans = 0, light = 1, rate = 8 } },
	},
	-- a slim, shimmering gold ribbon with sharp golden glints
	VIPTrail = {
		ribbons = { ribbonDef(Vector3.new(0, 0.1, 0.6), Vector3.new(0, -1.2, 0.6), seq({ rgb(255, 222, 110), rgb(255, 176, 20), rgb(255, 236, 160) }), 0.65, 0.3, fade(0.05)) },
		emit = { { at = Vector3.new(0, -0.5, 0.9), color = { rgb(255, 250, 220), rgb(255, 200, 60) }, life = { 0.3, 0.55 }, speed = { 0.1, 0.4 }, size = 0.8, size2 = 0, trans = 0, light = 1, rate = 7 } },
		shimmer = true,
	},
	-- a wide, saturated full-spectrum ribbon whose colours flow along it
	RainbowTrail = {
		ribbons = { ribbonDef(FULL_T, FULL_B, rainbowSeq(0, 0.85), 0.8, 0.3, fade(0.05)) },
		emit = { { at = Vector3.new(0, -0.6, 1), color = { rgb(255, 200, 240), rgb(200, 255, 240) }, life = { 0.6, 1.0 }, speed = { 0.4, 1.4 }, size = 0.5, size2 = 0, trans = 0.1, light = 1, rate = 8 } },
		flow = true,
	},
	-- a soft starlit ribbon and two little moons orbiting you, each drawing its own thin orbit trail
	OrbitalTrail = {
		ribbons = { ribbonDef(Vector3.new(0, 0.3, 0.6), Vector3.new(0, -1.5, 0.6), seq({ rgb(120, 180, 255), rgb(190, 140, 255) }), 0.9, 0.3, fade(0.2)) },
		emit = { { at = Vector3.new(0, -0.6, 1), color = { rgb(220, 235, 255), rgb(200, 180, 255) }, life = { 0.6, 1.1 }, speed = { 0.4, 1.2 }, size = 0.4, size2 = 0, trans = 0.1, light = 1, rate = 8 } },
		orbs = { { r = 2.6, y = 0.6, speed = 3.2, color = rgb(170, 215, 255), size = 0.75 }, { r = 2.1, y = -0.9, speed = -4.2, color = rgb(205, 165, 255), size = 0.55, tilt = 0.5 } },
	},
	-- a warm paper-lantern glow, with little glowing lanterns floating up from your path
	LanternTrail = {
		ribbons = { ribbonDef(Vector3.new(0, 0.2, 0.6), Vector3.new(0, -1.8, 0.6), seq({ rgb(255, 196, 90), rgb(240, 70, 50) }), 0.7, 0.3, fade(0.2)) },
		lanterns = { colors = { rgb(255, 120, 70), rgb(255, 196, 90), rgb(255, 90, 110) }, every = 0.75, rise = 7, life = 2.6, max = 5 },
		light = { color = rgb(255, 170, 90), range = 8, bright = 0.8 },
	},
}
CosmeticFX.TrailIds = { "SawdustTrail", "HazardTrail", "LavaTrail", "StarTrail", "BlueprintTrail", "VIPTrail", "RainbowTrail", "OrbitalTrail", "LanternTrail" }

function CosmeticFX.HasTrail(id)
	return type(id) == "string" and TRAILS[id] ~= nil
end

-- Builds a trail on `root` (a HumanoidRootPart). Returns a controller { setMoving(on), destroy() }.
function CosmeticFX.Trail(root: BasePart, id: string)
	local def = TRAILS[id]
	if not def then
		return nil
	end
	local made = {}
	local trails, emitters = {}, {}
	local function keep(x)
		table.insert(made, x)
		return x
	end
	for _, r in def.ribbons do
		local a0 = keep(Instance.new("Attachment"))
		a0.Name = "CosTrailA"
		a0.Position = r.top
		a0.Parent = root
		local a1 = keep(Instance.new("Attachment"))
		a1.Name = "CosTrailB"
		a1.Position = r.bottom
		a1.Parent = root
		local t = keep(Instance.new("Trail"))
		t.Name = "CosTrail"
		t.Attachment0, t.Attachment1 = a0, a1
		t.Color = r.color
		t.Transparency = r.trans or fade(0.3)
		t.Lifetime = r.life
		t.LightEmission = r.glow
		t.MinLength = 0.1
		t.FaceCamera = true
		t.Enabled = false
		t.Parent = root
		table.insert(trails, t)
	end
	for _, e in def.emit or {} do
		local a = keep(Instance.new("Attachment"))
		a.Position = e.at
		a.Parent = root
		local em = emitter(a, e)
		em.Enabled = false
		table.insert(emitters, em)
	end
	local light
	if def.light then
		light = keep(Instance.new("PointLight"))
		light.Color, light.Range, light.Brightness, light.Shadows, light.Enabled = def.light.color, def.light.range, def.light.bright, false, false
		light.Parent = root
	end
	local orbs = {}
	for _, o in def.orbs or {} do
		local p = keep(part(nil, { Shape = Enum.PartType.Ball, Color = o.color, Size = Vector3.one * o.size }))
		local b0 = Instance.new("Attachment")
		b0.Position = Vector3.new(0, o.size * 0.4, 0)
		b0.Parent = p
		local b1 = Instance.new("Attachment")
		b1.Position = Vector3.new(0, -o.size * 0.4, 0)
		b1.Parent = p
		local tr = Instance.new("Trail")
		tr.Attachment0, tr.Attachment1 = b0, b1
		tr.Color = seq({ Color3.new(1, 1, 1), o.color })
		tr.Lifetime, tr.LightEmission, tr.FaceCamera = 0.55, 1, true
		tr.Transparency = fade(0.1)
		tr.Parent = p
		table.insert(orbs, { p = p, o = o })
	end
	local moving = false
	local lanternFolder = nil
	local lanterns = {}
	local lastLantern = 0
	local alive = true
	local ctl = {}
	function ctl.setMoving(on)
		if on == moving then
			return
		end
		moving = on
		for _, t in trails do
			t.Enabled = on
		end
		for _, em in emitters do
			em.Enabled = on
		end
		if light then
			light.Enabled = on
		end
	end
	function ctl.destroy()
		alive = false
		for _, x in made do
			x:Destroy()
		end
		if lanternFolder then
			lanternFolder:Destroy()
		end
	end
	-- per-frame extras: orbiting moons (always, while the wearer exists), flowing rainbow, shimmering gold, lanterns
	if #orbs > 0 or def.flow or def.shimmer or def.lanterns then
		run(function(t, dt)
			if not alive or not root.Parent then
				return false
			end
			for i, ob in orbs do
				local o = ob.o
				local a = t * o.speed + i * 2
				local pos = CFrame.Angles(o.tilt or 0, 0, 0) * Vector3.new(math.cos(a) * o.r, 0, math.sin(a) * o.r)
				ob.p.CFrame = root.CFrame * CFrame.new(Vector3.new(0, o.y, 0) + pos)
				if not ob.p.Parent then
					ob.p.Parent = workspace
				end
			end
			if def.flow then
				trails[1].Color = rainbowSeq((t * 0.35) % 1, 0.85)
			end
			if def.shimmer then
				local s = 0.05 + 0.25 * (0.5 + 0.5 * math.sin(t * 9))
				trails[1].Transparency = fade(s)
			end
			if def.lanterns then
				local L = def.lanterns
				if moving and t - lastLantern > L.every and #lanterns < L.max then
					lastLantern = t
					if not lanternFolder then
						lanternFolder = Instance.new("Folder")
						lanternFolder.Name = "MB_Lanterns"
						lanternFolder.Parent = workspace
					end
					local c = L.colors[math.random(#L.colors)]
					local body = part(lanternFolder, { Color = c, Size = Vector3.new(0.7, 0.9, 0.7), Transparency = 0.1 })
					local cap = part(lanternFolder, { Material = Enum.Material.SmoothPlastic, Color = rgb(60, 40, 30), Size = Vector3.new(0.8, 0.14, 0.8) })
					local start = (root.CFrame * CFrame.new((math.random() - 0.5) * 2, -1, 1.5)).Position
					table.insert(lanterns, { body = body, cap = cap, start = start, t0 = t, sway = math.random() * 6 })
				end
				for i = #lanterns, 1, -1 do
					local ln = lanterns[i]
					local f = (t - ln.t0) / L.life
					if f >= 1 then
						ln.body:Destroy()
						ln.cap:Destroy()
						table.remove(lanterns, i)
					else
						local pos = ln.start + Vector3.new(math.sin(t * 1.3 + ln.sway) * 0.5, f * L.rise, math.cos(t * 1.1 + ln.sway) * 0.5)
						local cf = CFrame.new(pos) * CFrame.Angles(0, t * 0.6 + ln.sway, math.sin(t * 2 + ln.sway) * 0.12)
						ln.body.CFrame = cf
						ln.cap.CFrame = cf * CFrame.new(0, 0.52, 0)
						local tr = math.clamp((f - 0.65) / 0.35, 0, 1)
						ln.body.Transparency = 0.1 + 0.9 * tr
						ln.cap.Transparency = tr
					end
				end
			end
			return true
		end)
	end
	return ctl
end

-- VEHICLE SKIN DETAILS --------------------------------------------------------------------------------------------------------
-- Added to the live vehicle model by every client (welded, massless, non-colliding): purely visual.
local SKIN_DETAILS = {
	SafetyOrange = { beacon = rgb(255, 160, 30), underglow = nil },
	GoldenHaul = { glints = { rgb(255, 250, 210), rgb(255, 200, 60) }, underglow = rgb(255, 200, 80), light = rgb(255, 210, 120) },
	NeonRacer = { underglow = rgb(255, 60, 170), light = rgb(255, 80, 190), neonAccent = true },
	CandyStripe = { stripes = true, glints = { rgb(255, 255, 255), rgb(255, 160, 180) } },
	MidnightBlack = { headlights = rgb(225, 238, 255), underglow = rgb(120, 160, 255) },
	DragonScale = { exhaust = { rgb(140, 255, 120), rgb(40, 120, 40) }, eyes = rgb(120, 255, 90), underglow = rgb(60, 200, 80) },
	MasterChrome = { glints = { rgb(255, 255, 255), rgb(255, 214, 90) }, underglow = rgb(255, 200, 70), light = rgb(255, 236, 190) },
}
CosmeticFX.SkinIds = { "SafetyOrange", "GoldenHaul", "NeonRacer", "CandyStripe", "MidnightBlack", "DragonScale", "MasterChrome" }

local function weldTo(root, p)
	p.Anchored = false
	p.Massless = true
	local w = Instance.new("WeldConstraint")
	w.Part0, w.Part1 = root, p
	w.Parent = p
end

-- Decorates `m` (a vehicle model with PrimaryPart) for skin `id`. Returns a cleanup function.
function CosmeticFX.DecorateVehicle(m: Model, id: string)
	local d = SKIN_DETAILS[id]
	local root = m.PrimaryPart
	if not d or not root then
		return function() end
	end
	local folder = Instance.new("Folder")
	folder.Name = "MB_SkinFX"
	folder.Parent = m
	local cf, size = m:GetBoundingBox()
	local rel = root.CFrame:ToObjectSpace(cf)
	local hull = m:FindFirstChild("Hull") :: BasePart?
	local w = if hull then hull.Size.X else size.X
	local len = if hull then hull.Size.Z else size.Z
	local zc = if hull then root.CFrame:ToObjectSpace(hull.CFrame).Position.Z else rel.Position.Z
	local bottom = (root.CFrame:ToObjectSpace(cf * CFrame.new(0, -size.Y / 2, 0))).Position.Y
	local topY = (root.CFrame:ToObjectSpace(cf * CFrame.new(0, size.Y / 2, 0))).Position.Y
	local alive = true
	if d.underglow then
		-- tucked under the chassis: only its glow on the ground shows, never the slab itself
		local plate = part(folder, { Color = d.underglow, Size = Vector3.new(w * 0.55, 0.1, len * 0.55), Transparency = 0.35, CFrame = root.CFrame * CFrame.new(0, bottom + 0.55, zc) })
		weldTo(root, plate)
		local l = Instance.new("SurfaceLight")
		l.Face = Enum.NormalId.Bottom
		l.Color, l.Range, l.Brightness, l.Angle = d.underglow, 12, 5, 150
		l.Parent = plate
	end
	if d.light then
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness, l.Shadows = d.light, 12, 0.8, false
		l.Parent = root
		folder.Destroying:Connect(function()
			l:Destroy()
		end)
	end
	if d.beacon then
		local base = part(folder, { Material = Enum.Material.SmoothPlastic, Color = rgb(40, 40, 46), Size = Vector3.new(0.9, 0.3, 0.9), CFrame = root.CFrame * CFrame.new(0, topY + 0.15, zc) })
		weldTo(root, base)
		local dome = part(folder, { Shape = Enum.PartType.Ball, Color = d.beacon, Size = Vector3.one * 0.9, Transparency = 0.1, CFrame = root.CFrame * CFrame.new(0, topY + 0.6, zc) })
		weldTo(root, dome)
		local att = Instance.new("Attachment")
		att.Parent = dome
		local spot = Instance.new("SpotLight")
		spot.Color, spot.Range, spot.Brightness, spot.Angle, spot.Face = d.beacon, 22, 6, 35, Enum.NormalId.Front
		spot.Parent = dome
		local spot2 = spot:Clone()
		spot2.Face = Enum.NormalId.Back
		spot2.Parent = dome
		-- the rotating sweep: a beam fan that turns with time (attachments re-posed locally)
		local beams = {}
		for k = 1, 2 do
			local a1 = Instance.new("Attachment")
			a1.Parent = dome
			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = att, a1
			b.Color = seq(d.beacon)
			b.Width0, b.Width1 = 0.6, 4
			b.LightEmission, b.FaceCamera, b.Segments = 1, true, 1
			b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
			b.Parent = dome
			beams[k] = a1
		end
		run(function(t)
			if not alive or not dome.Parent then
				return false
			end
			local a = t * 5
			for k, a1 in beams do
				local ang = a + (k - 1) * math.pi
				a1.Position = Vector3.new(math.cos(ang) * 9, 0, math.sin(ang) * 9)
			end
			dome.Transparency = 0.05 + 0.25 * (0.5 + 0.5 * math.sin(t * 10))
			return true
		end)
	end
	if d.headlights then
		for _, x in { -w * 0.32, w * 0.32 } do
			local lamp = part(folder, { Shape = Enum.PartType.Ball, Color = d.headlights, Size = Vector3.one * 0.6, CFrame = root.CFrame * CFrame.new(x, bottom + 1.3, zc - len / 2 - 0.1) })
			weldTo(root, lamp)
			local a0 = Instance.new("Attachment")
			a0.Parent = lamp
			local a1 = Instance.new("Attachment")
			a1.Position = Vector3.new(0, -0.8, -14)
			a1.Parent = lamp
			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = a0, a1
			b.Color = seq(d.headlights)
			b.Width0, b.Width1 = 0.6, 5
			b.LightEmission, b.FaceCamera, b.Segments = 1, true, 1
			b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) })
			b.Parent = lamp
			local sl = Instance.new("SpotLight")
			sl.Color, sl.Range, sl.Brightness, sl.Angle, sl.Face = d.headlights, 24, 4, 45, Enum.NormalId.Front
			sl.Parent = lamp
		end
	end
	if d.eyes then
		for _, x in { -w * 0.3, w * 0.3 } do
			local eye = part(folder, { Color = d.eyes, Size = Vector3.new(0.7, 0.25, 0.15), CFrame = root.CFrame * CFrame.new(x, bottom + 1.6, zc - len / 2 - 0.05) * CFrame.Angles(0, 0, math.rad(if x < 0 then 12 else -12)) })
			weldTo(root, eye)
		end
	end
	if d.exhaust then
		local pipe = part(folder, { Size = Vector3.one * 0.2, Transparency = 1, CFrame = root.CFrame * CFrame.new(w * 0.3, bottom + 0.8, zc + len / 2 + 0.2) })
		weldTo(root, pipe)
		emitter(pipe, { color = d.exhaust, life = { 0.6, 1.0 }, speed = { 2, 4 }, spread = 25, accel = Vector3.new(0, 5, 0), size = 0.5, size2 = 0, light = 1, rate = 14, dir = Enum.NormalId.Back })
		emitter(pipe, { tex = SMOKE, color = { rgb(60, 90, 60), rgb(30, 40, 30) }, life = { 0.8, 1.3 }, speed = { 1, 2 }, spread = 20, accel = Vector3.new(0, 3, 0), size = 0.8, size2 = 2.4, trans = 0.6, light = 0, rate = 5, dir = Enum.NormalId.Back })
	end
	if d.glints then
		-- glints sparkle across the whole body: a box-shaped emitter on an invisible part the size of the vehicle
		local box = part(folder, { Size = Vector3.new(w, size.Y * 0.8, len), Transparency = 1, CFrame = root.CFrame * CFrame.new(0, (bottom + topY) / 2, zc) })
		weldTo(root, box)
		local e = emitter(box, { color = d.glints, life = { 0.25, 0.45 }, speed = { 0, 0.1 }, size = 0.9, size2 = 0, trans = 0, light = 1, rate = 6 })
		e.Shape = Enum.ParticleEmitterShape.Box
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.RotSpeed = NumberRange.new(0)
		e.Rotation = NumberRange.new(0)
	end
	return function()
		alive = false
		folder:Destroy()
	end
end

-- SHOWCASE (admin tester, local only) ----------------------------------------------------------------------------------------
-- builder rigs running laps on the showcase floor, one per trail, each with a name tag; returns a stop function
function CosmeticFX.TrailShowcase(origin: CFrame, rigs: Instance?)
	local f = Instance.new("Folder")
	f.Name = "MB_TrailShowcase"
	local floor = part(f, { Material = Enum.Material.Concrete, Color = rgb(168, 164, 156), Size = Vector3.new(170, 1, 80), CFrame = origin * CFrame.new(0, -0.5, -20) })
	floor.CanCollide = true
	local backdrop = part(f, { Material = Enum.Material.SmoothPlastic, Color = rgb(70, 78, 96), Size = Vector3.new(170, 70, 2), CFrame = origin * CFrame.new(0, 34, -62) })
	local _ = backdrop
	local runners = {}
	for i, id in CosmeticFX.TrailIds do
		local center = origin * CFrame.new((i - 5) * 17, 3, -22)
		local rig = rigs and rigs:FindFirstChildWhichIsA("Model")
		local root
		if rig then
			rig = rig:Clone()
			for _, d in rig:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				end
			end
			rig.Parent = f
			root = rig:FindFirstChild("HumanoidRootPart") or rig.PrimaryPart
		else
			root = part(f, { Size = Vector3.new(2, 2, 1), Color = rgb(200, 200, 200) })
		end
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(140, 26)
		tag.StudsOffset = Vector3.new(0, 5, 0)
		tag.AlwaysOnTop = true
		tag.Adornee = root
		tag.Parent = f
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.BuilderSansExtraBold
		lbl.TextSize = 15
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.TextStrokeTransparency = 0.4
		lbl.Text = id
		lbl.Parent = tag
		local ctl = CosmeticFX.Trail(root, id)
		if ctl then
			ctl.setMoving(true)
		end
		table.insert(runners, { rig = rig, root = root, center = center, ph = i, ctl = ctl })
	end
	f.Parent = workspace
	run(function(t)
		if not f.Parent then
			for _, r in runners do
				if r.ctl then
					r.ctl.destroy()
				end
			end
			return false
		end
		for _, r in runners do
			-- a small oval lap so every trail streams out behind its runner
			local a = t * 2.4 + r.ph
			local pos = r.center * CFrame.new(math.cos(a) * 5, 0, math.sin(a) * 9)
			local ahead = r.center * CFrame.new(math.cos(a + 0.1) * 5, 0, math.sin(a + 0.1) * 9)
			local cf = CFrame.lookAt(pos.Position, ahead.Position)
			if r.rig then
				r.rig:PivotTo(cf)
			else
				r.root.CFrame = cf
			end
		end
		return true
	end)
	return f
end

-- every delivery effect fired in turn along a line (local preview; no rewards)
function CosmeticFX.DeliveryShowcase(origin: CFrame)
	for i, id in CosmeticFX.DeliveryIds do
		local at = (origin * CFrame.new((i - 3.5) * 24, 2, -30)).Position
		task.delay((i - 1) * 0.35, CosmeticFX.Delivery, id, at, 1)
	end
end

return CosmeticFX
