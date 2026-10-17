--!strict
-- CINEMATIC TOOLKIT (client only). One place for every "game feel" accent so they share rules and never fight each other:
--   Cine.shake(amp, seconds)          camera shake through Humanoid.CameraOffset (never touches the camera itself), capped
--   Cine.fov(delta, tIn, hold, tOut)  a short field-of-view punch for big moments; the latest call wins, always returns to base
--   Cine.grade(props, tIn, hold, tOut) a temporary ColorCorrection layer (its own effect, so the base grade is never edited)
--   Cine.bloom(add, tIn, hold, tOut)  a temporary lift of the world bloom
--   Cine.vignette(color, alpha, tIn, hold, tOut) soft coloured screen edges (never covers the centre)
--   Cine.duck(level, tIn, hold, tOut) dips the ambience sound group (music / ambience hook) under a big moment
--   Cine.burst(pos, kind, scale?)     a short material particle burst from a POOLED emitter (no part is created per burst)
--   Cine.ring(pos, color, size, seconds) a flat ground pulse ring
-- Rules: shake max 0.9 studs and only for heavy moments; FOV only for build completion, Master Project and Prismatic; nothing here
-- loops forever, and every effect returns the world to exactly where it was.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local Cine = {}

local function tw(inst: Instance, t: number, props: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local tween = TweenService:Create(inst, TweenInfo.new(math.max(0.01, t), style or Enum.EasingStyle.Sine, dir or Enum.EasingDirection.InOut), props)
	tween:Play()
	return tween
end

------------------------------------------------------------------ shake (one shared driver; overlapping shakes take the max)
local shakeAmp, shakeUntil, shakeStart, shakeLen = 0, 0, 0, 1
local shakeConn: RBXScriptConnection? = nil
local MAX_SHAKE = 0.9

function Cine.shake(amp: number, seconds: number)
	local now = os.clock()
	local remaining = if now < shakeUntil then shakeAmp * (1 - (now - shakeStart) / shakeLen) else 0
	if math.min(amp, MAX_SHAKE) < remaining then
		return
	end
	shakeAmp, shakeStart, shakeLen, shakeUntil = math.min(amp, MAX_SHAKE), now, seconds, now + seconds
	if shakeConn then
		return
	end
	shakeConn = RunService.RenderStepped:Connect(function()
		local char = Players.LocalPlayer.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		local t = os.clock()
		if t >= shakeUntil or not hum then
			if hum then
				hum.CameraOffset = Vector3.zero
			end
			if shakeConn then
				shakeConn:Disconnect()
				shakeConn = nil
			end
			return
		end
		local k = shakeAmp * (1 - (t - shakeStart) / shakeLen)
		hum.CameraOffset = Vector3.new((math.random() - 0.5) * k, (math.random() - 0.5) * k, (math.random() - 0.5) * k * 0.5)
	end)
end

------------------------------------------------------------------ FOV punch
local BASE_FOV = 70
local fovToken = 0
function Cine.fov(delta: number, tIn: number, hold: number, tOut: number)
	local cam = workspace.CurrentCamera
	if not cam then
		return
	end
	fovToken += 1
	local my = fovToken
	tw(cam, tIn, { FieldOfView = BASE_FOV + math.clamp(delta, -12, 12) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(tIn + hold, function()
		if fovToken == my then
			tw(cam, tOut, { FieldOfView = BASE_FOV })
		end
	end)
end

------------------------------------------------------------------ colour grade layer
function Cine.grade(props: { [string]: any }, tIn: number, hold: number, tOut: number)
	local cc = Instance.new("ColorCorrectionEffect")
	cc.Name = "MB_CineGrade"
	cc.Parent = Lighting
	tw(cc, tIn, props)
	task.delay(tIn + hold, function()
		tw(cc, tOut, { TintColor = Color3.new(1, 1, 1), Saturation = 0, Brightness = 0, Contrast = 0 })
		task.delay(tOut + 0.05, function()
			cc:Destroy()
		end)
	end)
end

------------------------------------------------------------------ bloom lift
local bloomBase: number? = nil
local bloomToken = 0
function Cine.bloom(add: number, tIn: number, hold: number, tOut: number)
	local b = Lighting:FindFirstChild("MB_Bloom") :: BloomEffect?
	if not b then
		return
	end
	bloomBase = bloomBase or b.Intensity
	bloomToken += 1
	local my = bloomToken
	tw(b, tIn, { Intensity = (bloomBase :: number) + add })
	task.delay(tIn + hold, function()
		if bloomToken == my then
			tw(b, tOut, { Intensity = bloomBase })
		end
	end)
end

------------------------------------------------------------------ vignette (four soft gradient edges)
local vigGui: ScreenGui? = nil
local vigEdges: { Frame } = {}
local vigToken = 0
local function ensureVignette()
	if vigGui then
		return
	end
	local g = Instance.new("ScreenGui")
	g.Name = "MB_Vignette"
	g.IgnoreGuiInset = true
	g.DisplayOrder = 2
	g.ResetOnSpawn = false
	g.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	vigGui = g
	for i, spec in { { UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0), 90 }, { UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0.78), -90 }, { UDim2.fromScale(0.18, 1), UDim2.fromScale(0, 0), 0 }, { UDim2.fromScale(0.18, 1), UDim2.fromScale(0.82, 0), 180 } } do
		local f = Instance.new("Frame")
		f.BorderSizePixel = 0
		f.Size = spec[1]
		f.Position = spec[2]
		f.BackgroundTransparency = 1
		local gr = Instance.new("UIGradient")
		gr.Rotation = spec[3]
		gr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
		gr.Parent = f
		f.Parent = g
		vigEdges[i] = f
	end
end

function Cine.vignette(color: Color3, alpha: number, tIn: number, hold: number, tOut: number)
	ensureVignette()
	vigToken += 1
	local my = vigToken
	for _, f in vigEdges do
		f.BackgroundColor3 = color
		tw(f, tIn, { BackgroundTransparency = 1 - math.clamp(alpha, 0, 0.6) })
	end
	task.delay(tIn + hold, function()
		if vigToken == my then
			for _, f in vigEdges do
				tw(f, tOut, { BackgroundTransparency = 1 })
			end
		end
	end)
end

------------------------------------------------------------------ ambience ducking
local ambience: SoundGroup? = nil
function Cine.ambienceGroup(): SoundGroup
	if ambience then
		return ambience
	end
	local g = SoundService:FindFirstChild("MB_Ambience") :: SoundGroup?
	if not g then
		g = Instance.new("SoundGroup")
		g.Name = "MB_Ambience"
		g.Volume = 1
		g.Parent = SoundService
	end
	ambience = g
	return g :: SoundGroup
end

local duckToken = 0
function Cine.duck(level: number, tIn: number, hold: number, tOut: number)
	local g = Cine.ambienceGroup()
	duckToken += 1
	local my = duckToken
	tw(g, tIn, { Volume = level })
	task.delay(tIn + hold, function()
		if duckToken == my then
			tw(g, tOut, { Volume = 1 })
		end
	end)
end

------------------------------------------------------------------ pooled bursts
local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

type BurstDef = { tex: string, c1: Color3, c2: Color3, n: number, speed: number, life: number, size: number, grav: number, light: number, drag: number, grow: number?, soft: boolean? }
local KINDS: { [string]: BurstDef } = {
	Wood = { tex = SPARK, c1 = Color3.fromRGB(196, 140, 84), c2 = Color3.fromRGB(120, 190, 90), n = 10, speed = 10, life = 0.7, size = 0.5, grav = -30, light = 0, drag = 2 },
	Stone = { tex = SMOKE, c1 = Color3.fromRGB(214, 204, 186), c2 = Color3.fromRGB(170, 160, 150), n = 7, speed = 6, life = 0.9, size = 1.4, grav = -4, light = 0, drag = 3 },
	Metal = { tex = SPARK, c1 = Color3.fromRGB(255, 214, 120), c2 = Color3.fromRGB(255, 150, 60), n = 9, speed = 16, life = 0.45, size = 0.35, grav = -40, light = 0.9, drag = 1 },
	Power = { tex = SPARK, c1 = Color3.fromRGB(130, 240, 255), c2 = Color3.fromRGB(200, 255, 255), n = 9, speed = 7, life = 0.6, size = 0.6, grav = 6, light = 1, drag = 2 },
	Cosmic = { tex = SPARK, c1 = Color3.fromRGB(150, 205, 255), c2 = Color3.fromRGB(235, 220, 255), n = 16, speed = 9, life = 1.1, size = 0.7, grav = 2, light = 1, drag = 2 },
	Ancient = { tex = SPARK, c1 = Color3.fromRGB(255, 214, 130), c2 = Color3.fromRGB(170, 230, 120), n = 14, speed = 6, life = 1.3, size = 0.7, grav = 1.5, light = 0.6, drag = 2 },
	Dust = { tex = SMOKE, c1 = Color3.fromRGB(222, 206, 176), c2 = Color3.fromRGB(196, 186, 170), n = 14, speed = 12, life = 1.4, size = 4, grav = 1, light = 0, drag = 3 },
	Spark = { tex = SPARK, c1 = Color3.fromRGB(255, 226, 140), c2 = Color3.fromRGB(255, 255, 255), n = 18, speed = 24, life = 0.7, size = 0.6, grav = -30, light = 1, drag = 1 },
	Gold = { tex = SPARK, c1 = Color3.fromRGB(255, 214, 90), c2 = Color3.fromRGB(255, 246, 190), n = 18, speed = 10, life = 1, size = 0.8, grav = 2, light = 0.8, drag = 2 },
	Diamond = { tex = SPARK, c1 = Color3.fromRGB(170, 230, 255), c2 = Color3.fromRGB(255, 255, 255), n = 24, speed = 14, life = 1, size = 0.9, grav = 2, light = 1, drag = 2 },
	Steam = { tex = SMOKE, c1 = Color3.fromRGB(236, 236, 232), c2 = Color3.fromRGB(205, 208, 210), n = 7, speed = 2.5, life = 3.6, size = 4.5, grav = 2.5, light = 0, drag = 1.5, grow = 2.6, soft = true },
	Leaf = { tex = SPARK, c1 = Color3.fromRGB(150, 176, 82), c2 = Color3.fromRGB(196, 150, 70), n = 5, speed = 2, life = 4.5, size = 0.45, grav = -2, light = 0, drag = 1 },
	Prismatic = { tex = SPARK, c1 = Color3.fromRGB(255, 150, 230), c2 = Color3.fromRGB(150, 255, 230), n = 34, speed = 18, life = 1.3, size = 1, grav = 2, light = 1, drag = 2 },
}

local pool: { [string]: { part: Part, emitter: ParticleEmitter } } = {}
local fxFolder: Folder? = nil
local function folderFx(): Folder
	if fxFolder and fxFolder.Parent then
		return fxFolder
	end
	local f = Instance.new("Folder")
	f.Name = "MB_ClientFX"
	f.Parent = workspace
	fxFolder = f
	return f
end
Cine.folder = folderFx

local function emitterFor(kind: string): { part: Part, emitter: ParticleEmitter }?
	local e = pool[kind]
	if e and e.part.Parent then
		return e
	end
	local d = KINDS[kind]
	if not d then
		return nil
	end
	local p = Instance.new("Part")
	p.Name = "Burst_" .. kind
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.Transparency = 1
	p.Size = Vector3.one
	p.Parent = folderFx()
	local em = Instance.new("ParticleEmitter")
	em.Texture = d.tex
	em.Color = ColorSequence.new(d.c1, d.c2)
	em.LightEmission = d.light
	em.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, d.size), NumberSequenceKeypoint.new(1, d.size * (d.grow or 0.1)) })
	em.Transparency = if d.soft
		-- slow vapor: fades in, holds dense, thins out (a linear fade reads as nothing at this texture's softness)
		then NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.15, 0.05), NumberSequenceKeypoint.new(0.6, 0.35), NumberSequenceKeypoint.new(1, 1) })
		else NumberSequence.new({ NumberSequenceKeypoint.new(0, if d.tex == SMOKE then 0.45 else 0.05), NumberSequenceKeypoint.new(1, 1) })
	em.Speed = NumberRange.new(d.speed * 0.4, d.speed)
	em.Lifetime = NumberRange.new(d.life * 0.6, d.life)
	em.Acceleration = Vector3.new(0, d.grav, 0)
	em.Drag = d.drag
	em.SpreadAngle = Vector2.new(180, 180)
	em.RotSpeed = NumberRange.new(-120, 120)
	em.Rate = 0
	em.Shape = Enum.ParticleEmitterShape.Sphere
	em.Parent = p
	local entry = { part = p, emitter = em }
	pool[kind] = entry
	return entry
end

function Cine.burst(pos: Vector3, kind: string, scale: number?)
	local e = emitterFor(kind)
	if not e then
		return
	end
	e.part.Position = pos
	e.emitter:Emit(math.max(1, math.floor(KINDS[kind].n * (scale or 1) + 0.5)))
end

function Cine.ring(pos: Vector3, color: Color3, size: number, seconds: number)
	local ring = Instance.new("Part")
	ring.Name = "MB_PulseRing"
	ring.Anchored, ring.CanCollide, ring.CanQuery, ring.CanTouch = true, false, false, false
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.CFrame = CFrame.new(pos) * CFrame.Angles(0, 0, math.rad(90))
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.3
	ring.CastShadow = false
	ring.Parent = folderFx()
	tw(ring, seconds, { Size = Vector3.new(0.3, size, size), Transparency = 1 }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(seconds + 0.05, function()
		ring:Destroy()
	end)
end

return Cine
