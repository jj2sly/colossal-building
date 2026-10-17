--!strict
-- COMPLETION SPECTACLES (client only). The server fires one "Spectacle" event when a build finishes; each handler below
-- animates the finished build model that is already replicated (SpectacleConfig lists ids and durations). Nothing is
-- simulated on the server and everything is cleaned up when the show ends (or the model disappears).
--
-- Handlers only use generic information about the model (its bounding box, Neon parts) so they work on every template
-- without authored hooks; a build can later add named parts / attributes for richer shows.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local SpectacleConfig = require(ReplicatedStorage.Shared.Config.SpectacleConfig)
local Sound = require(script.Parent.Parent.ClientLib.Sound)
local Cine = require(script.Parent.Parent.ClientLib.Cine)

local SpectacleController = {}

local PARTICLE_SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local PARTICLE_SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local PARTICLE_FIRE = "rbxasset://textures/particles/fire_main.dds"

type Ctx = { model: Model, cf: CFrame, size: Vector3, top: Vector3, floor: number, duration: number, alive: () -> boolean, cleanup: { () -> () }, trash: { Instance } }

local function tween(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?)
	local tw = TweenService:Create(inst, TweenInfo.new(t, style or Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), props)
	tw:Play()
	return tw
end

local function anchorPart(ctx: Ctx, pos: Vector3): Part
	local p = Instance.new("Part")
	p.Name = "MB_SpectacleAnchor"
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Position = pos
	p.Parent = workspace
	table.insert(ctx.trash, p)
	return p
end

local function emitter(parent: Instance, texture: string, color: Color3, rate: number, speed: number, lifetime: number, size: number, spread: number): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Texture = texture
	e.Color = ColorSequence.new(color)
	e.Rate = rate
	e.Speed = NumberRange.new(speed * 0.7, speed)
	e.Lifetime = NumberRange.new(lifetime * 0.7, lifetime)
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size), NumberSequenceKeypoint.new(1, size * 0.2) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	e.SpreadAngle = Vector2.new(spread, spread)
	e.LightEmission = 0.6
	e.Parent = parent
	return e
end

local function neonParts(model: Model, limit: number): { BasePart }
	local out = {}
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.Neon then
			table.insert(out, d)
			if #out >= limit then
				break
			end
		end
	end
	return out
end

local function addLight(part: BasePart, color: Color3, range: number, trash: { Instance }): PointLight
	local l = Instance.new("PointLight")
	l.Color = color
	l.Range = range
	l.Brightness = 0
	l.Parent = part
	table.insert(trash, l)
	return l
end

-- Short camera shake (a few frames of offset), strength in studs.
-- (shake goes through the shared Cine driver: Humanoid.CameraOffset, capped, never fights the camera)
local function shake(strength: number, duration: number)
	Cine.shake(strength * 0.7, duration)
end

local function wait(ctx: Ctx, seconds: number): boolean
	local t = os.clock()
	while os.clock() - t < seconds do
		if not ctx.alive() then
			return false
		end
		task.wait(0.05)
	end
	return ctx.alive()
end

local function burst(ctx: Ctx, pos: Vector3, color: Color3, count: number, speed: number, life: number)
	for _ = 1, count do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.one * 1.2
		p.Material = Enum.Material.Neon
		p.Color = color
		p.Position = pos
		p.Parent = workspace
		table.insert(ctx.trash, p)
		local dir = Vector3.new(math.random() - 0.5, math.random() * 0.8 + 0.4, math.random() - 0.5).Unit * speed * (0.6 + math.random() * 0.6)
		tween(p, life, { Position = pos + dir, Transparency = 1, Size = Vector3.one * 0.3 }, Enum.EasingStyle.Quad)
	end
end

------------------------------------------------------------------ handlers
local Handlers: { [string]: (Ctx) -> () } = {}

-- named groups authored in the templates (TemplateBuilder3): ArmL, ArmR, Head, WingL, WingR, Cannon
local function groupParts(model: Model, name: string): { BasePart }
	local out = {}
	for _, g in model:GetDescendants() do
		if g.Name == name and g:IsA("Model") then
			for _, p in g:GetDescendants() do
				if p:IsA("BasePart") then
					table.insert(out, p)
				end
			end
		end
	end
	return out
end

local function boundsOf(parts: { BasePart }): (Vector3, Vector3)
	local lo, hi = Vector3.one * math.huge, -Vector3.one * math.huge
	for _, p in parts do
		lo = lo:Min(p.Position - p.Size / 2)
		hi = hi:Max(p.Position + p.Size / 2)
	end
	return lo, hi
end

-- Rotates a set of parts around `pivot` by angles(t) every frame for `seconds`, then puts them back exactly.
-- (Client-side only: the server's copy never moves.)
local function swing(ctx: Ctx, parts: { BasePart }, pivot: CFrame, seconds: number, angles: (number) -> CFrame)
	if #parts == 0 then
		return
	end
	local original = {}
	for _, p in parts do
		original[p] = p.CFrame
	end
	local function restore()
		for p, cf in original do
			if p.Parent then
				p.CFrame = cf
			end
		end
	end
	table.insert(ctx.cleanup, restore)
	task.spawn(function()
		local t0 = os.clock()
		while ctx.alive() do
			local t = os.clock() - t0
			if t > seconds then
				break
			end
			local k = pivot * angles(t) * pivot:Inverse()
			for p, cf in original do
				p.CFrame = k * cf
			end
			RunService.Heartbeat:Wait()
		end
		restore()
	end)
end

-- ease in, hold, ease out: 0..1..0 over `total` seconds with `ramp` seconds each side
local function envelope(t: number, total: number, ramp: number): number
	if t < ramp then
		return TweenService:GetValue(t / ramp, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	elseif t > total - ramp then
		return TweenService:GetValue(math.max(0, total - t) / ramp, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	end
	return 1
end

local function shockwave(ctx: Ctx, color: Color3, y: number, toSize: number, seconds: number)
	local ring = Instance.new("Part")
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.4, 6, 6)
	ring.CFrame = CFrame.new(ctx.cf.Position.X, y, ctx.cf.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.35
	ring.Parent = workspace
	table.insert(ctx.trash, ring)
	tween(ring, seconds, { Size = Vector3.new(0.4, toSize, toSize), Transparency = 1 }, Enum.EasingStyle.Quad)
end

-- PowerLight parts glow (client-side) in a colour, brightness tweened by the caller
local function powerLights(ctx: Ctx, color: Color3, limit: number): { PointLight }
	local lights = {}
	for _, d in ctx.model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("PowerLight") then
			d.Color = color
			d.Material = Enum.Material.Neon
			if #lights < limit then
				table.insert(lights, addLight(d, color, 26, ctx.trash))
			end
		end
	end
	return lights
end

-- Giant Robot (9 s): power climbs from the feet to the head (lights wake bottom to top), the chest core ignites, the head looks
-- around, then the right arm rises into a salute. PEAK = shockwave + spark burst at the hand. It ends lit and steady.
function Handlers.RobotPowerUp(ctx)
	local blue = Color3.fromRGB(90, 210, 255)
	Sound.Play("PowerUp")
	Sound.Play("Rumble")
	shake(0.35, 0.8)
	local parts = {}
	for _, d in ctx.model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("PowerLight") then
			table.insert(parts, d)
		end
	end
	table.sort(parts, function(x, y)
		return x.Position.Y < y.Position.Y
	end)
	local lights = {}
	for i, p in parts do
		task.delay(2.4 * (i - 1) / math.max(1, #parts), function()
			if not ctx.alive() then
				return
			end
			p.Material = Enum.Material.Neon
			tween(p, 0.3, { Color = blue })
			if #lights < 10 then
				local l = addLight(p, blue, 24, ctx.trash)
				table.insert(lights, l)
				tween(l, 0.5, { Brightness = 1.5 })
			end
		end)
	end
	shockwave(ctx, blue, ctx.floor + 0.6, ctx.size.X * 1.8, 1.6)
	if not wait(ctx, 1.2) then
		return
	end
	-- the chest core ignites
	local core = ctx.cf.Position + Vector3.new(0, ctx.size.Y * 0.08, 0) + ctx.cf.LookVector * (ctx.size.Z * 0.18)
	Cine.burst(core, "Power", 1.6)
	Sound.Play("Zap")
	local head = groupParts(ctx.model, "Head")
	local arm = groupParts(ctx.model, "ArmR")
	local up = ctx.cf.UpVector
	if #head > 0 then
		local lo, hi = boundsOf(head)
		local pivot = CFrame.new(Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2))
		swing(ctx, head, pivot, 6.5, function(t)
			return CFrame.fromAxisAngle(up, math.sin(t * 1.5) * math.rad(26) * envelope(t, 6.5, 1))
		end)
	end
	local hand = ctx.top
	if #arm > 0 then
		local lo, hi = boundsOf(arm)
		local pivot = CFrame.new(Vector3.new((lo.X + hi.X) / 2, hi.Y - 4, (lo.Z + hi.Z) / 2))
		local side = ctx.cf.RightVector
		swing(ctx, arm, pivot, 7, function(t)
			-- swing the arm forward and up (towards the spawn), hold, and lower it again
			return CFrame.fromAxisAngle(side, math.rad(120) * envelope(t - 0.6, 6.2, 1.4))
		end)
		local raised = CFrame.new(pivot.Position) * CFrame.fromAxisAngle(side, math.rad(120)) * CFrame.new(-pivot.Position)
		hand = raised * Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2)
	end
	local top = anchorPart(ctx, ctx.top)
	local steam = emitter(top, PARTICLE_SMOKE, Color3.fromRGB(230, 236, 245), 8, 10, 2.5, 5, 40)
	if not wait(ctx, 2.2) then
		return
	end
	-- PEAK: the salute lands
	shockwave(ctx, blue, ctx.floor + 0.6, ctx.size.X * 3, 2)
	Cine.burst(hand, "Spark", 1.6)
	Sound.Play("Boom")
	Sound.Play("Chime")
	shake(0.5, 0.6)
	for _, l in lights do
		tween(l, 0.3, { Brightness = 2.4 })
	end
	if not wait(ctx, 0.6) then
		return
	end
	for _, l in lights do
		tween(l, 1.2, { Brightness = 1.2 })
	end
	wait(ctx, 3)
	steam.Enabled = false
end

-- UFO: rim lights chase, it lifts off with a slow spin and a tractor beam, an energy pulse, then it settles back.
function Handlers.UfoHover(ctx)
	local origin = ctx.model:GetPivot()
	local lift = 9
	local rim = {}
	for _, d in ctx.model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("PowerLight") then
			d.Material = Enum.Material.Neon
			table.insert(rim, d)
		end
	end
	local beam = Instance.new("Part")
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch = true, false, false, false
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(lift + 10, 1, 1)
	beam.Material = Enum.Material.Neon
	beam.Color = Color3.fromRGB(150, 255, 200)
	beam.Transparency = 1
	beam.CFrame = CFrame.new(ctx.cf.Position.X, ctx.floor + (lift + 10) / 2, ctx.cf.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = workspace
	table.insert(ctx.trash, beam)
	table.insert(ctx.cleanup, function()
		if ctx.model.Parent then
			ctx.model:PivotTo(origin)
		end
	end)
	Sound.Play("PowerUp")
	-- energy field: a faint force-field shell around the saucer while it hovers
	local field = Instance.new("Part")
	field.Anchored, field.CanCollide, field.CanQuery, field.CanTouch = true, false, false, false
	field.Shape = Enum.PartType.Ball
	field.Material = Enum.Material.ForceField
	field.Color = Color3.fromRGB(130, 255, 220)
	field.Transparency = 1
	field.Size = Vector3.one * ctx.size.X * 1.05
	field.CastShadow = false
	field.Parent = workspace
	table.insert(ctx.trash, field)
	local t0 = os.clock()
	local rise, hold, fall = 2.4, ctx.duration - 5.4, 2.4
	tween(beam, 1.5, { Transparency = 0.72, Size = Vector3.new(lift + 10, ctx.size.X * 0.6, ctx.size.X * 0.6) })
	local pulsed = false
	while ctx.alive() do
		local t = os.clock() - t0
		local h
		if t < rise then
			h = lift * TweenService:GetValue(t / rise, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		elseif t < rise + hold then
			h = lift + math.sin((t - rise) * 2.2) * 0.8
			if not pulsed and t > rise + hold * 0.5 then
				pulsed = true
				shockwave(ctx, Color3.fromRGB(120, 255, 220), ctx.floor + lift + ctx.size.Y * 0.4, ctx.size.X * 3, 1.4)
				Cine.burst(ctx.cf.Position + Vector3.new(0, lift, 0), "Power", 2)
				Sound.Play("Zap")
				Sound.Play("Chime")
			end
		elseif t < rise + hold + fall then
			h = lift * (1 - TweenService:GetValue((t - rise - hold) / fall, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut))
		else
			break
		end
		for i, p in rim do
			-- a soft chase (not a rainbow strobe): bright spots run round the rim over a calm teal
			local w = (math.sin(i / math.max(1, #rim) * math.pi * 4 - t * 4) + 1) / 2
			p.Color = Color3.fromRGB(70, 170, 170):Lerp(Color3.fromRGB(200, 255, 240), w * w)
		end
		ctx.model:PivotTo(origin * CFrame.new(0, h, 0) * CFrame.Angles(0, math.rad(t * 26) * (if t < rise + hold then 1 else 0), 0))
		field.Position = ctx.cf.Position + Vector3.new(0, h, 0)
		field.Transparency = 1 - 0.75 * envelope(t - 1, rise + hold - 0.5, 1)
		RunService.Heartbeat:Wait()
	end
	if ctx.model.Parent then
		ctx.model:PivotTo(origin)
	end
	tween(beam, 0.5, { Transparency = 1 })
	field.Transparency = 1
	-- final beat: it touches down with a ground pulse
	shockwave(ctx, Color3.fromRGB(150, 255, 220), ctx.floor + 0.6, ctx.size.X * 2.4, 1.6)
	Cine.burst(Vector3.new(ctx.cf.Position.X, ctx.floor + 1, ctx.cf.Position.Z), "Dust", 1)
	Sound.Play("Thud")
	shake(0.3, 0.4)
end

-- Volcano Temple: rumble, the lava rivers flare, a fire fountain and smoke column, glowing ember bursts.
function Handlers.VolcanoEruption(ctx)
	local lavaParts = {}
	for _, d in ctx.model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Lava") then
			table.insert(lavaParts, d)
		end
	end
	local crater = anchorPart(ctx, ctx.top)
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 40)
	glow.Range = 70
	glow.Brightness = 0
	glow.Parent = crater
	table.insert(ctx.trash, glow)
	-- rumble: the ground shakes, the lava brightens and smoke builds up before the blast
	Sound.Play("Rumble")
	shake(0.4, 2)
	tween(glow, 2.2, { Brightness = 3 })
	for _, p in lavaParts do
		tween(p, 2.2, { Color = Color3.fromRGB(255, 200, 80) })
	end
	local smoke = emitter(crater, PARTICLE_SMOKE, Color3.fromRGB(70, 60, 56), 4, 10, 4.5, 12, 25)
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	Cine.burst(Vector3.new(ctx.cf.Position.X, ctx.floor + 2, ctx.cf.Position.Z), "Dust", 1.2)
	if not wait(ctx, 2.2) then
		return
	end
	-- ERUPTION (peak)
	smoke.Rate = 12
	local fire = emitter(crater, PARTICLE_FIRE, Color3.fromRGB(255, 120, 30), 60, 34, 2.2, 8, 30)
	fire.Acceleration = Vector3.new(0, -14, 0) -- the fountain arcs back down onto the cone instead of leaving the frame
	Sound.Play("Boom")
	shake(0.8, 1.2)
	for i = 1, 4 do
		burst(ctx, ctx.top, Color3.fromRGB(255, 140, 40), 8, 40 + i * 5, 1.8)
		tween(glow, 0.8, { Brightness = if i % 2 == 0 then 5 else 2.5 })
		Sound.Play("Meteor", 0.2)
		if not wait(ctx, 1.2) then
			break
		end
	end
	fire.Enabled = false
	smoke.Rate = 3
	-- settling glow: the lava cools slowly back to its normal colour
	for _, p in lavaParts do
		tween(p, 3, { Color = Color3.fromRGB(255, 112, 24) })
	end
	tween(glow, 3, { Brightness = 0.6 })
	wait(ctx, 1.6)
	smoke.Enabled = false
	tween(glow, 1.2, { Brightness = 0 })
end

-- Dragon Citadel: wings beat, the head rears and roars (shake), fire breath from the jaw, eyes and braziers glow.
function Handlers.DragonRoar(ctx)
	local red = Color3.fromRGB(255, 120, 40)
	local lights = powerLights(ctx, Color3.fromRGB(255, 220, 80), 4)
	for _, l in lights do
		tween(l, 0.8, { Brightness = 3 })
	end
	local up = ctx.cf.UpVector
	local fwd = ctx.cf.LookVector -- the build's authored front (it faces the spawn)
	for _, name in { "WingL", "WingR" } do
		local parts = groupParts(ctx.model, name)
		if #parts > 0 then
			local lo, hi = boundsOf(parts)
			local center = (lo + hi) / 2
			local rootX = if math.abs(lo.X - ctx.cf.Position.X) < math.abs(hi.X - ctx.cf.Position.X) then lo.X else hi.X
			local rootZ = if math.abs(lo.Z - ctx.cf.Position.Z) < math.abs(hi.Z - ctx.cf.Position.Z) then lo.Z else hi.Z
			local root = Vector3.new(if math.abs(hi.X - lo.X) > math.abs(hi.Z - lo.Z) then rootX else center.X, lo.Y + 2, if math.abs(hi.X - lo.X) > math.abs(hi.Z - lo.Z) then center.Z else rootZ)
			local out = (center - root) * Vector3.new(1, 0, 1)
			local axis = if out.Magnitude > 0.1 then out.Unit:Cross(up) else ctx.cf.LookVector
			swing(ctx, parts, CFrame.new(root), 8, function(t)
				return CFrame.fromAxisAngle(axis, math.sin(t * 3.4) * math.rad(24) * envelope(t, 8, 1))
			end)
		end
	end
	local head = groupParts(ctx.model, "Head")
	local mouth = ctx.top
	if #head > 0 then
		local lo, hi = boundsOf(head)
		local pivot = CFrame.new(Vector3.new((lo.X + hi.X) / 2, lo.Y, (lo.Z + hi.Z) / 2))
		local side = ctx.cf.RightVector
		swing(ctx, head, pivot, 8, function(t)
			return CFrame.fromAxisAngle(side, math.rad(14) * envelope(t - 1, 6, 1.2))
		end)
		local snout = Vector3.new((lo.X + hi.X) / 2, lo.Y + (hi.Y - lo.Y) * 0.78, (lo.Z + hi.Z) / 2) + fwd * ((hi - lo) * Vector3.new(1, 0, 1)).Magnitude * 0.45
		mouth = snout
	end
	local front = anchorPart(ctx, mouth)
	front.CFrame = CFrame.lookAt(mouth, mouth + fwd + Vector3.new(0, -0.25, 0))
	local fire = emitter(front, PARTICLE_FIRE, red, 120, 55, 1.6, 6, 14)
	fire.EmissionDirection = Enum.NormalId.Front
	fire.Enabled = false
	local light = Instance.new("PointLight")
	light.Color = red
	light.Range = 90
	light.Brightness = 0
	light.Parent = front
	table.insert(ctx.trash, light)
	Sound.Play("Meteor")
	if not wait(ctx, 1.4) then
		return
	end
	Sound.Play("Rumble")
	for _ = 1, 3 do
		shake(0.6, 0.8)
		fire.Enabled = true
		Sound.Play("Boom", 0.15)
		tween(light, 0.3, { Brightness = 6 })
		if not wait(ctx, 1.3) then
			break
		end
		fire.Enabled = false
		tween(light, 0.6, { Brightness = 1 })
		if not wait(ctx, 0.9) then
			break
		end
	end
	-- final roar: a red pulse rolls out from the citadel
	shockwave(ctx, Color3.fromRGB(255, 110, 50), ctx.floor + 0.6, ctx.size.X * 3, 2)
	Cine.burst(mouth, "Spark", 1.4)
	Sound.Play("Rumble")
	Sound.Play("ChimeLow")
	shake(0.5, 0.8)
	tween(light, 0.3, { Brightness = 4 })
	wait(ctx, 0.5)
	tween(light, 1.2, { Brightness = 0 })
end

-- Orbital Station (Master Project): the whole station powers on: ring lamps chase around both rings while the rings turn in opposite
-- directions, solar wings tilt, the dish sweeps a full turn, the station rises a little, three energy pulses and a firework finale.
-- Everything is client-side, parts return exactly to where they were.
function Handlers.OrbitalActivation(ctx)
	local cyan = Color3.fromRGB(110, 210, 255)
	Sound.Play("PowerUp")
	local up = ctx.cf.UpVector
	local right = ctx.cf.RightVector
	local center = Vector3.new(ctx.cf.Position.X, 0, ctx.cf.Position.Z)
	local duration = ctx.duration
	local lower, upper = groupParts(ctx.model, "RingLower"), groupParts(ctx.model, "RingUpper")
	local solarL, solarR, dish = groupParts(ctx.model, "SolarL"), groupParts(ctx.model, "SolarR"), groupParts(ctx.model, "Dish")
	local grouped: { [BasePart]: boolean } = {}
	for _, list in { lower, upper, solarL, solarR, dish } do
		for _, p in list do
			grouped[p] = true
		end
	end
	local rest = {}
	for _, d in ctx.model:GetDescendants() do
		if d:IsA("BasePart") and not grouped[d] then
			table.insert(rest, d)
		end
	end
	local function rise(t: number): number
		return 7 * envelope(t - 0.8, duration - 1.6, 2.5)
	end
	local function ease(t: number): number
		local k = math.clamp(t / (duration - 0.5), 0, 1)
		return (1 - math.cos(k * math.pi)) / 2
	end
	swing(ctx, rest, CFrame.new(center), duration, function(t)
		return CFrame.new(0, rise(t), 0)
	end)
	-- the rings turn a whole number of segments, so the end state looks identical to the start (no snap)
	swing(ctx, lower, CFrame.new(center), duration, function(t)
		return CFrame.new(0, rise(t), 0) * CFrame.fromAxisAngle(up, math.rad(3 * 360 / 28) * ease(t))
	end)
	swing(ctx, upper, CFrame.new(center), duration, function(t)
		return CFrame.new(0, rise(t), 0) * CFrame.fromAxisAngle(up, -math.rad(3 * 360 / 24) * ease(t))
	end)
	for _, list in { solarL, solarR } do
		if #list > 0 then
			local lo, hi = boundsOf(list)
			swing(ctx, list, CFrame.new((lo + hi) / 2), duration, function(t)
				return CFrame.new(0, rise(t), 0) * CFrame.fromAxisAngle(right, math.rad(24) * math.sin(math.pi * 3 * t / duration) * envelope(t, duration, 1.5))
			end)
		end
	end
	if #dish > 0 then
		local lo, hi = boundsOf(dish)
		swing(ctx, dish, CFrame.new(Vector3.new(center.X, (lo.Y + hi.Y) / 2, center.Z)), duration, function(t)
			return CFrame.new(0, rise(t), 0) * CFrame.fromAxisAngle(up, math.rad(360) * ease(t))
		end)
	end
	-- lamp chase: PowerLight parts glow in a travelling wave around the station
	local lamps = {}
	for _, d in ctx.model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("PowerLight") then
			d.Material = Enum.Material.Neon
			local off = d.Position - center
			table.insert(lamps, { part = d, ang = math.atan2(off.Z, off.X) })
		end
	end
	local coreLight = Instance.new("PointLight")
	coreLight.Color = cyan
	coreLight.Range = 70
	coreLight.Brightness = 0
	local anchor = anchorPart(ctx, ctx.top - Vector3.new(0, ctx.size.Y * 0.3, 0))
	coreLight.Parent = anchor
	table.insert(ctx.trash, coreLight)
	tween(coreLight, 2, { Brightness = 3 })
	local t0 = os.clock()
	task.spawn(function()
		while ctx.alive() and os.clock() - t0 < duration - 1 do
			local t = os.clock() - t0
			for _, l in lamps do
				if l.part.Parent then
					local w = (math.sin(l.ang * 3 - t * (3 + t * 0.6)) + 1) / 2
					l.part.Color = cyan:Lerp(Color3.new(1, 1, 1), w * w)
				end
			end
			task.wait(0.1)
		end
		tween(coreLight, 1, { Brightness = 0 })
	end)
	-- three energy pulses, then fireworks over the station
	local pulses = { 1.0, 5.0 }
	task.spawn(function()
		for _, at in pulses do
			while ctx.alive() and os.clock() - t0 < at do
				task.wait(0.05)
			end
			if not ctx.alive() then
				return
			end
			shockwave(ctx, cyan, ctx.floor + 0.8, ctx.size.X * 1.6, 2.2)
			shake(0.45, 0.7)
			Sound.Play("StageComplete")
		end
	end)
	local colors = { Color3.fromRGB(110, 210, 255), Color3.fromRGB(255, 220, 120), Color3.fromRGB(190, 150, 255), Color3.fromRGB(255, 150, 200) }
	-- build-up: the core brightens and a rising hum of chimes leads into the finale
	local finale = duration - 4.2
	while ctx.alive() and os.clock() - t0 < finale - 1.6 do
		task.wait(0.1)
	end
	tween(coreLight, 1.6, { Brightness = 3.5 })
	Sound.Play("Rumble")
	Cine.burst(anchor.Position, "Power", 2)
	while ctx.alive() and os.clock() - t0 < finale do
		task.wait(0.05)
	end
	-- FINALE: one big pulse, the whole station flares white-cyan, then fireworks over the rings
	if ctx.alive() then
		shockwave(ctx, Color3.fromRGB(200, 240, 255), ctx.floor + 0.8, ctx.size.X * 3.2, 2.6)
		shockwave(ctx, cyan, ctx.top.Y - ctx.size.Y * 0.4, ctx.size.X * 2.2, 2)
		Cine.fov(-5, 0.3, 1, 1.6)
		Cine.bloom(0.1, 0.2, 0.8, 1.6)
		shake(0.7, 0.8)
		Sound.Play("Boom")
		Sound.Play("ChimeLow")
		task.delay(0.4, function()
			Sound.Play("Cheer")
		end)
		for _, l in lamps do
			if l.part.Parent then
				l.part.Color = Color3.fromRGB(190, 236, 255)
			end
		end
	end
	for i = 1, 7 do
		if not ctx.alive() then
			break
		end
		local pos = ctx.top + Vector3.new((math.random() - 0.5) * ctx.size.X * 0.7, 6 + math.random() * 18, (math.random() - 0.5) * ctx.size.Z * 0.7)
		burst(ctx, pos, colors[i % #colors + 1], 26, 28, 1.6)
		Sound.Play("Meteor", 0.2)
		task.wait(0.45)
	end
	while ctx.alive() and os.clock() - t0 < duration do
		task.wait(0.1)
	end
end

-- Pirate Ship: lanterns light, then a rolling broadside from the real cannons (flash, smoke, recoil), flag fireworks.
function Handlers.ShipCannons(ctx)
	local lights = powerLights(ctx, Color3.fromRGB(255, 200, 110), 6)
	for i, l in lights do
		task.delay(i * 0.15, function()
			tween(l, 0.6, { Brightness = 2.5 })
		end)
	end
	Sound.Play("Chime")
	local cannons = {}
	for _, g in ctx.model:GetDescendants() do
		if g:IsA("Model") and g.Name == "Cannon" then
			local barrel
			for _, p in g:GetChildren() do
				if p:IsA("BasePart") and p.Shape == Enum.PartType.Cylinder then
					barrel = p
				end
			end
			if barrel then
				table.insert(cannons, barrel)
			end
		end
	end
	Sound.Play("StageComplete")
	if not wait(ctx, 0.8) then
		return
	end
	for i, barrel in cannons do
		-- the muzzle is the barrel end that points away from the ship's centre line
		local axis = barrel.CFrame.RightVector
		local toward = (barrel.Position - ctx.cf.Position) * Vector3.new(1, 0, 1)
		if axis:Dot(toward) < 0 then
			axis = -axis
		end
		local muzzle = barrel.Position + axis * (barrel.Size.X / 2 + 0.6)
		local a = anchorPart(ctx, muzzle)
		local smoke = emitter(a, PARTICLE_SMOKE, Color3.fromRGB(225, 225, 230), 0, 12, 1.4, 3.5, 30)
		smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
		smoke:Emit(7)
		local flash = Instance.new("PointLight")
		flash.Color = Color3.fromRGB(255, 190, 80)
		flash.Range = 28
		flash.Brightness = 8
		flash.Parent = a
		table.insert(ctx.trash, flash)
		tween(flash, 0.5, { Brightness = 0 })
		burst(ctx, muzzle, Color3.fromRGB(255, 190, 80), 4, 12, 0.5)
		swing(ctx, { barrel }, CFrame.new(barrel.Position), 0.45, function(t)
			return CFrame.new(-axis * math.sin(math.min(1, t / 0.45) * math.pi) * 1.2)
		end)
		shake(0.3, 0.25)
		Sound.Play("Boom", 0.2)
		if not wait(ctx, if i % 2 == 0 then 0.55 else 0.35) then
			break
		end
	end
	-- celebratory finish: three bursts over the masts, a chime and a cheer
	local colors = { Color3.fromRGB(255, 90, 60), Color3.fromRGB(255, 220, 90), Color3.fromRGB(120, 200, 255) }
	Sound.Play("Cheer")
	for i = 1, 3 do
		burst(ctx, ctx.top + Vector3.new(0, 8, 0), colors[i], 18, 20, 1.3)
		Sound.Play("Chime", 0.1)
		if not wait(ctx, 0.7) then
			break
		end
	end
	for _, l in lights do
		tween(l, 1.5, { Brightness = 1.2 })
	end
end

-- Giant Arcade: every neon part cycles through arcade colours.
function Handlers.ArcadeLightShow(ctx)
	local parts = neonParts(ctx.model, 60)
	local original = {}
	for _, p in parts do
		original[p] = p.Color
	end
	table.insert(ctx.cleanup, function()
		for p, c in original do
			if p.Parent then
				p.Color = c
			end
		end
	end)
	Sound.Play("StageComplete")
	local t0 = os.clock()
	while ctx.alive() and os.clock() - t0 < ctx.duration - 1 do
		local t = os.clock() - t0
		for i, p in parts do
			p.Color = Color3.fromHSV((t * 0.8 + i * 0.13) % 1, 0.85, 1)
		end
		task.wait(0.12)
	end
end

-- Mega Fortress: beacons flash and fireworks burst over the walls.
function Handlers.FortressBanners(ctx)
	local parts = neonParts(ctx.model, 20)
	local lights = {}
	for _, p in parts do
		table.insert(lights, addLight(p, Color3.fromRGB(255, 200, 90), 30, ctx.trash))
	end
	Sound.Play("StageComplete")
	local colors = { Color3.fromRGB(255, 90, 60), Color3.fromRGB(255, 220, 90), Color3.fromRGB(120, 200, 255), Color3.fromRGB(180, 255, 140) }
	for i = 1, 7 do
		local pos = Vector3.new(ctx.cf.Position.X + (math.random() - 0.5) * ctx.size.X * 0.8, ctx.top.Y + 10 + math.random() * 14, ctx.cf.Position.Z + (math.random() - 0.5) * ctx.size.Z)
		burst(ctx, pos, colors[i % #colors + 1], 22, 22, 1.4)
		for _, l in lights do
			tween(l, 0.4, { Brightness = if i % 2 == 0 then 3 else 0.5 })
		end
		if not wait(ctx, 1.1) then
			break
		end
	end
end

------------------------------------------------------------------ runner
local running = false

local function play(payload: any)
	if type(payload) ~= "table" or running then
		return
	end
	local def = SpectacleConfig.Spectacles[payload.Id]
	local handler = Handlers[payload.Id]
	local model = workspace:FindFirstChild("ActiveBuild")
	if not def or not handler or not model or not model:IsA("Model") then
		return
	end
	running = true
	local cf, size = model:GetBoundingBox()
	local ctx: Ctx = {
		model = model,
		cf = cf,
		size = size,
		top = cf.Position + Vector3.new(0, size.Y / 2, 0),
		floor = cf.Position.Y - size.Y / 2,
		duration = def.Duration,
		alive = function()
			return model.Parent ~= nil
		end,
		cleanup = {},
		trash = {},
	}
	task.spawn(function()
		local ok, err = pcall(handler, ctx)
		if not ok then
			warn("[Spectacle]", payload.Id, err)
		end
		for _, fn in ctx.cleanup do
			pcall(fn)
		end
		for _, inst in ctx.trash do
			if inst:IsA("PointLight") and inst.Parent then
				tween(inst, 1.5, { Brightness = 0 })
			end
		end
		task.delay(2.5, function()
			for _, inst in ctx.trash do
				if inst.Parent then
					inst:Destroy()
				end
			end
		end)
		running = false
	end)
end

function SpectacleController.Start()
	Net.Event("Spectacle").OnClientEvent:Connect(play)
end

-- debug hook: DebugController / the bridge can replay a spectacle locally
SpectacleController.Play = play

-- build-specific shows (BuildShowController) register their completion handlers here
function SpectacleController.Register(id: string, fn: (any) -> ())
	Handlers[id] = fn
end

return SpectacleController
