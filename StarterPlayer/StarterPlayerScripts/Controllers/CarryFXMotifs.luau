--!nonstrict
-- (Pass 21R) CARRY FX MOTIFS: a SIGNATURE shape per named carry effect, layered on top of the existing two-layer aura
-- (CarryFXConfig resource family + mutation tier) and the named carry cosmetics (CosmeticConfig.CarryEffect).
--
-- Roblox-native and cheap: everything hangs off ONE anchor part per stack (the stack's first block, so it follows the player),
-- built from Attachments that are moved per frame (orbits, spirals, halos), Trails between orbiting attachments, ParticleEmitters
-- riding those attachments (a rotating emitter with upward acceleration draws a helix, a rotating one with gravity draws a falling
-- curtain), Beams (lightning, light pillars) and one PointLight. No extra parts, no physics, no per-unit instances.
-- Budget: at most ~3-6 instances per stack, only stacks the aura culler allows are switched on, one shared Heartbeat loop.
--
-- Spec grammar (per motif a list of components):
--   { t = "emit",  ... }  static emitter            { t = "orbit", ... } orbiting attachment (trail and/or emitter)
--   { t = "bolt",  ... }  jittering beam            { t = "pillar", ... } vertical soft light beam
--   { t = "light", ... }  pulsing / flickering point light
local RunService = game:GetService("RunService")

local CarryFXMotifs = {}

local SPARK = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local SIZE_BOOST = 1.7 -- gameplay-distance readability: every emitter size and trail width is scaled by this
local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- MOTIFS ----------------------------------------------------------------------------------------------------------------
-- Positions are studs in the anchor block's space (the block sits on the back of the carrier; +Y is up).
local Block, Ball, Cyl = Enum.PartType.Block, Enum.PartType.Ball, Enum.PartType.Cylinder
local MOTIFS = {
	-- NAMED CARRY COSMETICS (the effects players unlock) --------------------------------------------------------------
	Cosmetic = {
		-- a spinning crown of gold bars that rains glitter and coins, with a bright inner trail
		GoldDust = {
			{ t = "parts", n = 10, size = Vector3.new(0.5, 0.9, 0.35), color = { rgb(255, 196, 40), rgb(255, 232, 130) }, mode = "orbit", r = 2.7, y = 3.7, speed = 2.1, bob = 0.3, spin = 2.4, mat = Enum.Material.Metal },
			{ t = "orbit", trail = { rgb(255, 214, 90), rgb(255, 248, 200) }, life = 0.8, w = 0.45, r = 2.7, y = 3.7, speed = 2.1, light = 0.9,
				emit = { tex = SPARK, color = { rgb(255, 226, 120), rgb(255, 170, 60) }, rate = 18, life = { 0.9, 1.4 }, speed = { 0.2, 0.8 }, size = 0.4, accel = -7, spread = 180, trans = 0.05, light = 0.9 } },
			{ t = "parts", n = 5, size = Vector3.new(0.7, 0.14, 0.7), shape = Cyl, color = { rgb(255, 236, 140), rgb(255, 180, 50) }, mode = "fall", h = 6, y = 0.6, speed = 0.35, spread = 2, spin = 5, shrink = 0.2, mat = Enum.Material.Metal },
			{ t = "light", color = rgb(255, 208, 90), range = 11, bright = 0.9, pulse = 0.25, hz = 1.3 },
		},
		-- a flame plume of stretched neon embers, flying sparks, a thread of smoke, flickering warm light
		EmberGlow = {
			{ t = "parts", n = 16, size = Vector3.new(1.5, 1.5, 1.5), shape = Ball, color = { rgb(255, 205, 70), rgb(255, 105, 18), rgb(170, 28, 8) }, mode = "rise", h = 7, y = 0.8, speed = 1.1, spread = 1.5, stretch = 2.2, shrink = 0.8, mat = Enum.Material.Neon },
			{ t = "emit", pos = Vector3.new(0, 2.4, 0), tex = SPARK, color = { rgb(255, 232, 150), rgb(255, 120, 40) }, rate = 16, life = { 1.1, 2.0 },
				speed = { 2, 5 }, size = 0.35, accel = 3, drag = 0.4, spread = 38, trans = 0.05, light = 1 },
			{ t = "emit", pos = Vector3.new(0, 5.2, 0), tex = SMOKE, color = { rgb(90, 80, 76), rgb(40, 38, 40) }, rate = 3.5, life = { 1.4, 2 },
				speed = { 1, 2 }, size = { 1.0, 2.6 }, grow = 1, accel = 2.5, drag = 1.2, spread = 22, trans = 0.72, light = 0 },
			{ t = "light", color = rgb(255, 120, 40), range = 12, bright = 1.1, flicker = 0.55, hz = 11 },
		},
		-- a neon double helix climbing the carrier (two strands of glowing cubes), with a counter-spinning crest ring
		NeonGlow = {
			{ t = "parts", n = 20, size = Vector3.new(0.42, 0.42, 0.42), color = { rgb(20, 255, 90), rgb(90, 255, 150), rgb(200, 255, 225) }, mode = "helix", r = 2.3, h = 6.6, turns = 2.4, rot = 1.1, speed = 0.22, phase = 0, taper = 0.15, shrink = 0.35, spin = 2, mat = Enum.Material.Neon },
			{ t = "parts", n = 20, size = Vector3.new(0.42, 0.42, 0.42), color = { rgb(20, 255, 90), rgb(90, 255, 150), rgb(200, 255, 225) }, mode = "helix", r = 2.3, h = 6.6, turns = 2.4, rot = 1.1, speed = 0.22, phase = math.pi, taper = 0.15, shrink = 0.35, spin = 2, mat = Enum.Material.Neon },
			{ t = "orbit", r = 2.5, y = 0.6, speed = 3.4, phase = 0,
				emit = { tex = SPARK, color = { rgb(80, 255, 150), rgb(190, 255, 220) }, rate = 12, life = { 0.9, 1.2 }, speed = { 0.05, 0.2 }, size = 0.4, accel = 5.5, spread = 0, trans = 0.05, light = 1 } },
			{ t = "orbit", trail = { rgb(120, 255, 190), rgb(40, 230, 120) }, life = 0.45, w = 0.4, r = 2.2, y = 6.9, speed = -3.6, light = 1 },
			{ t = "light", color = rgb(80, 255, 150), range = 11, bright = 1, pulse = 0.4, hz = 2.2 },
		},
		-- a regal pillar of light with nested halos, spinning white crystals, a floor ring and drifting feathers
		PrestigeAura = {
			{ t = "pillar", h = 17, w0 = 3.2, w1 = 0.6, color = { rgb(190, 225, 255), rgb(255, 255, 255) }, trans = 0.8, pulse = 0.08, hz = 1.6 },
			{ t = "orbit", trail = { rgb(255, 255, 255), rgb(150, 205, 255) }, life = 0.85, w = 0.42, r = 2.6, y = 3.2, speed = 2.6, light = 1, bob = 0.3 },
			{ t = "orbit", trail = { rgb(230, 245, 255), rgb(120, 180, 255) }, life = 0.85, w = 0.42, r = 3.5, y = 5.6, speed = -1.9, light = 1, bob = 0.3 },
			{ t = "orbit", trail = { rgb(255, 255, 255), rgb(170, 140, 255) }, life = 0.85, w = 0.42, r = 4.3, y = 8, speed = 1.4, light = 1, bob = 0.3 },
			{ t = "orbit", trail = { rgb(200, 230, 255), rgb(120, 170, 255) }, life = 1.55, w = 0.3, r = 3.7, y = -1.2, speed = 4.2, light = 1 },
			{ t = "parts", n = 3, size = Vector3.new(0.45, 0.9, 0.45), color = { rgb(255, 255, 255), rgb(170, 215, 255) }, mode = "orbit", r = 3.5, y = 5.6, speed = -1.9, spin = 2.2, mat = Enum.Material.Neon },
			{ t = "emit", pos = Vector3.new(0, 1, 0), tex = SPARK, color = { rgb(255, 255, 255), rgb(150, 205, 255) }, rate = 9, life = { 1.6, 2.4 },
				speed = { 0.3, 1 }, size = 0.5, accel = 3.2, drag = 1, spread = 180, trans = 0.15, light = 1 },
			{ t = "light", color = rgb(150, 210, 255), range = 14, bright = 1.2, pulse = 0.5, hz = 1.3 },
		},
	},

	-- RESOURCE FAMILIES (what you are hauling; shown once the load is full enough) ---------------------------------------
	Family = {
		-- leaves spiralling down off the load, with a slow sawdust swirl
		Wood = {
			{ t = "parts", n = 8, size = Vector3.new(0.75, 0.08, 0.5), color = { rgb(110, 205, 60), rgb(205, 150, 60) }, mode = "fall", h = 6.5, y = 0.5, speed = 0.24, spread = 2.8, spin = 2.2, shrink = 0.1, mat = Enum.Material.SmoothPlastic },
			{ t = "orbit", r = 2.7, y = 3.6, speed = 1.3, bob = 0.8,
				emit = { tex = SPARK, color = { rgb(150, 200, 80), rgb(205, 150, 92) }, rate = 5, life = { 1.4, 2 }, speed = { 0.1, 0.4 }, size = 0.4, accel = -2.2, spread = 25, trans = 0.2, light = 0 } },
		},
		-- grit chips tumbling off the heavy load and a low dust cloud
		Stone = {
			{ t = "parts", n = 5, size = Vector3.new(0.5, 0.4, 0.45), color = { rgb(190, 184, 172), rgb(120, 116, 110) }, mode = "fall", h = 4, y = -0.4, speed = 0.55, spread = 1.4, spin = 6, shrink = 0.25, mat = Enum.Material.Slate },
			{ t = "emit", pos = Vector3.new(0, -1.2, 0), tex = SMOKE, color = { rgb(200, 190, 175), rgb(140, 134, 128) }, rate = 4.5, life = { 0.9, 1.4 },
				speed = { 0.6, 1.6 }, size = { 0.8, 2.4 }, grow = 1, accel = -3, drag = 2, spread = 80, trans = 0.55, light = 0 },
		},
		-- hot comet streaks circling the steel, with glowing slag chips
		Metal = {
			{ t = "orbit", trail = { rgb(255, 232, 160), rgb(255, 120, 30) }, life = 0.28, w = 0.26, r = 2.3, y = 2.4, speed = 6, light = 1, bob = 0.9, phase = 0 },
			{ t = "orbit", trail = { rgb(255, 232, 160), rgb(255, 120, 30) }, life = 0.28, w = 0.26, r = 2.3, y = 2.4, speed = 6, light = 1, bob = 0.9, phase = math.pi },
			{ t = "parts", n = 4, size = Vector3.new(0.3, 0.3, 0.3), color = { rgb(255, 230, 150), rgb(255, 100, 20) }, mode = "fall", h = 5, y = 0.8, speed = 0.9, spread = 1.5, spin = 8, shrink = 0.7, mat = Enum.Material.Neon },
		},
		-- crackling electric arcs and charged orbs
		PowerCell = {
			{ t = "bolt", n = 3, len = 4.2, hz = 14, jag = 0.8, color = { rgb(235, 255, 255), rgb(100, 225, 255) }, width = 0.34, pos = Vector3.new(0, 2.2, 0) },
			{ t = "parts", n = 3, size = Vector3.new(0.6, 0.6, 0.6), shape = Ball, color = { rgb(200, 255, 255), rgb(80, 210, 255) }, mode = "orbit", r = 2.6, y = 2.4, speed = 4.4, bob = 1.2, mat = Enum.Material.Neon },
		},
		-- a tiny star system: orbiting stars on three tilted rings
		StarMetal = {
			{ t = "orbit", trail = { rgb(220, 235, 255), rgb(130, 150, 255) }, life = 0.7, w = 0.3, r = 3.2, y = 3.2, speed = 2.2, tilt = 0.5, light = 1 },
			{ t = "orbit", trail = { rgb(200, 190, 255), rgb(120, 190, 255) }, life = 0.7, w = 0.3, r = 3.2, y = 3.2, speed = -1.8, tilt = -0.5, yaw = 1.6, light = 1 },
			{ t = "orbit", trail = { rgb(255, 255, 255), rgb(160, 140, 255) }, life = 0.5, w = 0.22, r = 2.0, y = 3.2, speed = 3.4, tilt = 1.2, yaw = 0.8, light = 1 },
			{ t = "parts", n = 1, size = Vector3.new(0.5, 0.5, 0.5), shape = Ball, color = rgb(255, 255, 255), mode = "orbit", r = 3.2, y = 3.2, speed = 2.2, tilt = 0.5, mat = Enum.Material.Neon },
			{ t = "parts", n = 1, size = Vector3.new(0.4, 0.4, 0.4), shape = Ball, color = rgb(190, 170, 255), mode = "orbit", r = 3.2, y = 3.2, speed = -1.8, tilt = -0.5, yaw = 1.6, mat = Enum.Material.Neon },
		},
		-- warm pollen rising in a column, crowned by a slow ring of gold-green leaves
		AncientTimber = {
			{ t = "emit", pos = Vector3.new(0, 0.2, 0), tex = SPARK, color = { rgb(255, 214, 120), rgb(180, 230, 120) }, rate = 7, life = { 1.8, 2.6 },
				speed = { 0.3, 0.8 }, size = 0.42, accel = 2.4, drag = 1, spread = 12, trans = 0.25, light = 0.5 },
			{ t = "parts", n = 7, size = Vector3.new(0.75, 0.1, 0.5), color = { rgb(255, 214, 120), rgb(140, 210, 100) }, mode = "orbit", r = 3, y = 5.2, speed = 1.3, bob = 0.5, spin = 1.6, mat = Enum.Material.Neon },
			{ t = "orbit", trail = { rgb(255, 214, 120), rgb(150, 220, 110) }, life = 1.3, w = 0.3, r = 3, y = 5.2, speed = 1.3, light = 0.6, bob = 0.5 },
		},
	},

	-- MUTATION LAYERS (what the load is made of) ----------------------------------------------------------------------
	Mutation = {
		-- polished gold coins spinning and bobbing around the load, with slow twinkles
		Golden = {
			{ t = "parts", n = 4, size = Vector3.new(0.9, 0.14, 0.9), shape = Cyl, color = { rgb(255, 214, 80), rgb(255, 244, 170) }, mode = "orbit", r = 3, y = 3, speed = 1.6, bob = 0.8, spin = 4, mat = Enum.Material.Metal },
			{ t = "emit", pos = Vector3.new(0, 2.8, 0), tex = SPARK, color = { rgb(255, 244, 190), rgb(255, 200, 70) }, rate = 3.2, life = { 0.35, 0.6 },
				speed = { 0.1, 0.4 }, size = { 1.2, 1.9 }, accel = 0, drag = 0, spread = 180, trans = 0, light = 1, fixed = true, sphere = 2.6 },
		},
		-- spinning crystals on a tilted ring and hard four-point glints
		Diamond = {
			{ t = "parts", n = 4, size = Vector3.new(0.55, 0.9, 0.55), color = { rgb(255, 255, 255), rgb(150, 235, 255) }, mode = "orbit", r = 3, y = 3, speed = 2.4, tilt = 0.55, spin = 3.2, mat = Enum.Material.Neon, trans = 0.05 },
			{ t = "emit", pos = Vector3.new(0, 2.8, 0), tex = SPARK, color = { rgb(255, 255, 255), rgb(150, 235, 255) }, rate = 4.5, life = { 0.25, 0.45 },
				speed = { 0.1, 0.3 }, size = { 0.7, 1.4 }, accel = 0, drag = 0, spread = 180, trans = 0, light = 1, fixed = true, sphere = 3.1 },
		},
		-- a hue-shifting ribbon snaking around the load with colour-cycling orbs
		Prismatic = {
			{ t = "orbit", trail = "rainbow", life = 0.95, w = 0.6, r = 3.1, y = 3, speed = 2.8, bob = 1.5, light = 1 },
			{ t = "parts", n = 5, size = Vector3.new(0.5, 0.5, 0.5), shape = Ball, color = "hue", mode = "orbit", r = 3.1, y = 3, speed = 2.8, bob = 1.5, mat = Enum.Material.Neon },
		},
	},
}
CarryFXMotifs.Motifs = MOTIFS

-- BUILDING ---------------------------------------------------------------------------------------------------------------
local function cs(list)
	if type(list) == "table" and typeof(list[1]) == "Color3" then
		if #list == 1 then
			return ColorSequence.new(list[1])
		elseif #list == 2 then
			return ColorSequence.new(list[1], list[2])
		end
		local kps = {}
		for i, c in list do
			table.insert(kps, ColorSequenceKeypoint.new((i - 1) / (#list - 1), c))
		end
		return ColorSequence.new(kps)
	end
	return ColorSequence.new(Color3.new(1, 1, 1))
end

local function rainbow(offset)
	local kps = {}
	for i = 0, 5 do
		table.insert(kps, ColorSequenceKeypoint.new(i / 5, Color3.fromHSV((offset + i / 6) % 1, 0.5, 1)))
	end
	return ColorSequence.new(kps)
end

local function attachment(anchor, pos)
	local a = Instance.new("Attachment")
	a.Position = pos or Vector3.zero
	a.Parent = anchor
	return a
end

local function range(v)
	if type(v) == "table" then
		return NumberRange.new(v[1], v[2])
	end
	return NumberRange.new(v)
end

local function makeEmitter(spec, parent)
	local e = Instance.new("ParticleEmitter")
	e.Texture = spec.tex
	e.Color = cs(spec.color)
	local s0 = (if type(spec.size) == "table" then spec.size[1] else spec.size) * SIZE_BOOST
	local s1 = (if type(spec.size) == "table" then spec.size[2] else spec.size) * SIZE_BOOST
	local endSize = if spec.grow then s1 * (1 + spec.grow) else 0
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, s0 * 0.4), NumberSequenceKeypoint.new(0.25, s1), NumberSequenceKeypoint.new(1, endSize) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, spec.trans or 0.2), NumberSequenceKeypoint.new(1, 1) })
	e.LightEmission = spec.light or 0
	e.Lifetime = range(spec.life)
	e.Speed = range(spec.speed)
	e.Acceleration = Vector3.new(0, spec.accel or 0, 0)
	e.Drag = spec.drag or 0
	e.SpreadAngle = Vector2.new(spec.spread or 0, spec.spread or 0)
	e.RotSpeed = if spec.fixed then NumberRange.new(0) else NumberRange.new(-120, 120)
	e.Rotation = if spec.fixed then NumberRange.new(0) else NumberRange.new(0, 360)
	e.Rate = 0
	e.EmissionDirection = Enum.NormalId.Top
	e.Parent = parent
	return e
end

type Comp = { group: string, setOn: (boolean, number) -> (), step: ((number, number) -> ())? }

local BUILD = {}

BUILD.emit = function(spec, anchor, group): Comp
	local a = attachment(anchor, spec.pos)
	local e = makeEmitter(spec, a)
	return {
		group = group,
		setOn = function(on, k)
			e.Rate = if on then spec.rate * k else 0
		end,
		step = if spec.sphere
			then function(t, k)
				-- glints appear on a shell around the load: hop the attachment to a random point on it
				if math.random() < 0.35 then
					local v = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
					if v.Magnitude > 0.05 then
						a.Position = (spec.pos or Vector3.zero) + v.Unit * spec.sphere
					end
				end
			end
			else nil,
	}
end

BUILD.orbit = function(spec, anchor, group): Comp
	local a0 = attachment(anchor)
	local a1
	local trail
	if spec.trail then
		a1 = attachment(anchor)
		trail = Instance.new("Trail")
		trail.Attachment0, trail.Attachment1 = a0, a1
		trail.Color = if spec.trail == "rainbow" then rainbow(0) else cs(spec.trail)
		trail.Lifetime = spec.life or 0.5
		trail.LightEmission = spec.light or 0.8
		trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(1, 1) })
		trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
		trail.FaceCamera = true
		trail.MinLength = 0.05
		trail.Enabled = false
		trail.Parent = a0
	end
	local emitter = if spec.emit then makeEmitter(spec.emit, a0) else nil
	local tilt = CFrame.Angles(spec.tilt or 0, spec.yaw or 0, 0)
	local center = Vector3.new(0, spec.y or 0, 0)
	local phase = spec.phase or 0
	local isRainbow = spec.trail == "rainbow"
	return {
		group = group,
		setOn = function(on, k)
			if trail then
				trail.Enabled = on
			end
			if emitter then
				emitter.Rate = if on then spec.emit.rate * k else 0
			end
		end,
		step = function(t, k)
			local ang = phase + t * spec.speed
			local r = (spec.r or 2.5) * (0.85 + 0.15 * math.min(k, 1.5))
			local p = center + tilt * Vector3.new(math.cos(ang) * r, (spec.bob or 0) * math.sin(t * 2.3 + phase * 1.7), math.sin(ang) * r)
			a0.Position = p
			if a1 then
				a1.Position = p + Vector3.new(0, (spec.w or 0.4) * 1.5, 0)
			end
			if isRainbow and trail then
				trail.Color = rainbow(t * 0.25)
			end
		end,
	}
end

-- small modeled elements: n anchored, non-colliding parts re-posed each frame (orbit / rise / fall), never physics
local function lerpColors(list, f)
	if typeof(list) == "Color3" then
		return list
	end
	local n = #list
	if n == 1 then
		return list[1]
	end
	local x = math.clamp(f, 0, 1) * (n - 1)
	local i = math.min(math.floor(x) + 1, n - 1)
	return list[i]:Lerp(list[i + 1], x - (i - 1))
end

BUILD.parts = function(spec, anchor, group): Comp
	local parts = {}
	local n = spec.n
	local sz = spec.size * (if group == "Cosmetic" then 1 else 1.45) -- resource / mutation layers read from further away: bigger pieces
	for i = 1, n do
		local p = Instance.new("Part")
		p.Name = "MB_FXPart"
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
		p.Shape = spec.shape or Enum.PartType.Block
		p.Material = spec.mat or Enum.Material.Neon
		p.Size = sz
		p.Color = if spec.color == "hue" then Color3.fromHSV(i / n, 0.5, 1) else lerpColors(spec.color, 0)
		p.Transparency = spec.trans or 0
		parts[i] = p
	end
	local center = Vector3.new(0, spec.y or 0, 0)
	local tilt = CFrame.Angles(spec.tilt or 0, spec.yaw or 0, 0)
	local mode = spec.mode or "orbit"
	local isOn = false
	return {
		group = group,
		setOn = function(on)
			isOn = on
			for _, p in parts do
				p.Parent = if on then anchor else nil
			end
		end,
		step = function(t, k)
			if not isOn then
				return
			end
			local base = anchor.CFrame
			for i, p in parts do
				local ph = (i - 1) / n
				local cf
				local f = 0
				if mode == "orbit" then
					local ang = ph * math.pi * 2 + t * spec.speed
					local r = spec.r * (0.85 + 0.15 * math.min(k, 1.5))
					local pos = center + tilt * Vector3.new(math.cos(ang) * r, (spec.bob or 0) * math.sin(t * 2.1 + ph * 9), math.sin(ang) * r)
					cf = base * CFrame.new(pos)
				elseif mode == "helix" then
					-- a climbing spiral: each element rides one strand from the base to the top, wrapping `turns` times
					f = (t * spec.speed + ph) % 1
					local ang = f * (spec.turns or 1.5) * math.pi * 2 + (spec.phase or 0) + t * (spec.rot or 0)
					local r = spec.r * (1 - f * (spec.taper or 0))
					cf = base * CFrame.new(center + Vector3.new(math.cos(ang) * r, f * spec.h, math.sin(ang) * r))
				else
					f = (t * spec.speed + ph + (spec.offset or 0)) % 1
					if mode == "fall" then
						f = 1 - f
					end
					local jx = math.sin(ph * 40 + t * 1.7) * (spec.spread or 0.5) * (1 - f * 0.4)
					local jz = math.cos(ph * 55 + t * 1.3) * (spec.spread or 0.5) * (1 - f * 0.4)
					cf = base * CFrame.new(center + Vector3.new(jx, f * spec.h, jz))
				end
				if spec.spin then
					cf = cf * CFrame.Angles(t * spec.spin + ph * 6, t * spec.spin * 0.7, ph * 3)
				end
				p.CFrame = cf
				if mode ~= "orbit" then
					local sc = 1 - f * (spec.shrink or 0.8)
					p.Size = Vector3.new(sz.X * sc, sz.Y * sc * (spec.stretch or 1), sz.Z * sc)
					p.Transparency = (spec.trans or 0) + f * f * 0.6
					if spec.color ~= "hue" then
						p.Color = lerpColors(spec.color, f)
					end
				elseif spec.color == "hue" then
					p.Color = Color3.fromHSV((t * 0.25 + ph) % 1, 0.5, 1)
				end
			end
		end,
	}
end

BUILD.bolt = function(spec, anchor, group): Comp
	-- jagged lightning: each bolt is a chain of short beams between attachments that are re-randomised along a random direction
	local SEG = 5
	local center = spec.pos or Vector3.zero
	local bolts = {}
	for i = 1, spec.n or 2 do
		local atts, beams = {}, {}
		for k = 0, SEG do
			atts[k] = attachment(anchor, center)
		end
		for k = 1, SEG do
			local bm = Instance.new("Beam")
			bm.Attachment0, bm.Attachment1 = atts[k - 1], atts[k]
			bm.Color = cs(spec.color)
			bm.Width0, bm.Width1 = spec.width or 0.3, spec.width or 0.3
			bm.LightEmission = 1
			bm.FaceCamera = true
			bm.Segments = 1
			bm.Transparency = NumberSequence.new(0)
			bm.Enabled = false
			bm.Parent = atts[k - 1]
			beams[k] = bm
		end
		bolts[i] = { atts = atts, beams = beams }
	end
	local frames = 0
	local isOn = false
	return {
		group = group,
		setOn = function(on)
			isOn = on
			for _, bolt in bolts do
				for _, bm in bolt.beams do
					bm.Enabled = on
				end
			end
		end,
		step = function()
			if not isOn then
				return
			end
			frames += 1
			if frames < 60 / (spec.hz or 12) then
				return
			end
			frames = 0
			for _, bolt in bolts do
				local dir = Vector3.new(math.random() * 2 - 1, math.random() * 1.2 - 0.1, math.random() * 2 - 1)
				if dir.Magnitude < 0.2 then
					dir = Vector3.yAxis
				end
				dir = dir.Unit
				local side = dir:Cross(Vector3.yAxis)
				if side.Magnitude < 0.1 then
					side = Vector3.xAxis
				end
				side = side.Unit
				local up = dir:Cross(side)
				local len = (spec.len or 3) * (0.7 + math.random() * 0.3)
				local visible = math.random() > 0.12
				for k = 0, SEG do
					local f = k / SEG
					local jag = if k == 0 or k == SEG then 0 else (spec.jag or 0.7)
					bolt.atts[k].Position = center + dir * (len * f) + side * ((math.random() - 0.5) * 2 * jag) + up * ((math.random() - 0.5) * 2 * jag)
				end
				for _, bm in bolt.beams do
					bm.Enabled = visible
				end
			end
		end,
	}
end

BUILD.pillar = function(spec, anchor, group): Comp
	local base = attachment(anchor, Vector3.new(0, spec.y0 or -1, 0))
	local top = attachment(anchor, Vector3.new(0, (spec.y0 or -1) + spec.h, 0))
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = base, top
	b.Color = cs(spec.color)
	b.Width0, b.Width1 = spec.w0, spec.w1
	b.LightEmission = 1
	b.FaceCamera = true
	b.Segments = 1
	b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, spec.trans), NumberSequenceKeypoint.new(1, 1) })
	b.Enabled = false
	b.Parent = base
	return {
		group = group,
		setOn = function(on)
			b.Enabled = on
		end,
		step = function(t)
			local p = spec.trans + spec.pulse * math.sin(t * spec.hz * 2)
			b.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, p), NumberSequenceKeypoint.new(1, 1) })
		end,
	}
end

BUILD.light = function(spec, anchor, group): Comp
	local l = Instance.new("PointLight")
	l.Color = spec.color
	l.Range = spec.range
	l.Brightness = spec.bright
	l.Shadows = false
	l.Enabled = false
	l.Parent = anchor
	return {
		group = group,
		setOn = function(on)
			l.Enabled = on
		end,
		step = function(t)
			if spec.flicker then
				l.Brightness = spec.bright * (1 - spec.flicker * 0.5 + spec.flicker * math.noise(t * spec.hz, 0.5))
			else
				l.Brightness = spec.bright * (1 + (spec.pulse or 0) * math.sin(t * (spec.hz or 1) * 2))
			end
		end,
	}
end

-- INSTANCES --------------------------------------------------------------------------------------------------------------
export type Motif = { anchor: BasePart, comps: { Comp }, on: { [string]: boolean }, k: number, active: boolean }
local live: { Motif } = {}
local loop: RBXScriptConnection? = nil

local function ensureLoop()
	if loop then
		return
	end
	loop = RunService.Heartbeat:Connect(function()
		local t = os.clock()
		for i = #live, 1, -1 do
			local m = live[i]
			if not m.anchor.Parent then
				table.remove(live, i)
			elseif m.active then
				for _, c in m.comps do
					if c.step and m.on[c.group] then
						c.step(t, m.k)
					end
				end
			end
		end
		if #live == 0 and loop then
			loop:Disconnect()
			loop = nil
		end
	end)
end

local function addGroup(m: Motif, anchor: BasePart, list, group: string)
	if not list then
		return
	end
	for _, spec in list do
		local build = BUILD[spec.t]
		if build then
			table.insert(m.comps, build(spec, anchor, group))
		end
	end
end

-- opts: { family = "Wood", tier = "Golden" | nil, cosmetic = "GoldDust" | nil }
function CarryFXMotifs.Attach(anchor: BasePart, opts): Motif
	local m: Motif = { anchor = anchor, comps = {}, on = { Family = false, Mutation = false, Cosmetic = false }, k = 1, active = false }
	addGroup(m, anchor, MOTIFS.Family[opts.family], "Family")
	if opts.tier then
		addGroup(m, anchor, MOTIFS.Mutation[opts.tier], "Mutation")
	end
	if opts.cosmetic then
		addGroup(m, anchor, MOTIFS.Cosmetic[opts.cosmetic], "Cosmetic")
	end
	table.insert(live, m)
	ensureLoop()
	return m
end

function CarryFXMotifs.HasCosmetic(id: any): boolean
	return type(id) == "string" and MOTIFS.Cosmetic[id] ~= nil
end

-- family / mutation / cosmetic switches + intensity scale (called whenever the aura state changes)
function CarryFXMotifs.SetState(m: Motif?, family: boolean, mutation: boolean, cosmetic: boolean, k: number)
	if not m then
		return
	end
	local on = m.on
	if on.Family == family and on.Mutation == mutation and on.Cosmetic == cosmetic and m.k == k then
		return
	end
	on.Family, on.Mutation, on.Cosmetic, m.k = family, mutation, cosmetic, k
	m.active = family or mutation or cosmetic
	for _, c in m.comps do
		c.setOn(on[c.group], if c.group == "Cosmetic" then 1 else k)
	end
end

-- SHOWCASE (admin tester, local only) ---------------------------------------------------------------------------------------
-- Every named effect side by side: a row of real builder rigs, each carrying a crate with ONE effect fully on, with a name tag.
function CarryFXMotifs.Showcase(origin: CFrame, rigs: Instance?): Folder
	local f = Instance.new("Folder")
	f.Name = "MB_VFXShowcase"
	local list = {}
	local function add(kind, id)
		table.insert(list, { kind = kind, id = id })
	end
	for _, id in { "Wood", "Stone", "Metal", "PowerCell", "StarMetal", "AncientTimber" } do
		add("Family", id)
	end
	for _, id in { "Golden", "Diamond", "Prismatic" } do
		add("Mutation", id)
	end
	for _, id in { "GoldDust", "EmberGlow", "NeonGlow", "PrestigeAura" } do
		add("Cosmetic", id)
	end
	local per = 7
	-- a dark floor under the line-up so glows read cleanly (the admin places the showcase high above the map, away from terrain)
	local floor = Instance.new("Part")
	floor.Name = "ShowcaseFloor"
	floor.Anchored, floor.CanCollide, floor.CanQuery, floor.CanTouch = true, true, false, false
	floor.Size = Vector3.new(per * 13 + 20, 1, 70)
	floor.Color = Color3.fromRGB(34, 38, 48)
	floor.Material = Enum.Material.SmoothPlastic
	floor.CFrame = origin * CFrame.new(0, -0.5, -11)
	floor.Parent = f
	local wall = floor:Clone()
	wall.Name = "ShowcaseBackdrop"
	wall.CanCollide = false
	wall.Size = Vector3.new(per * 13 + 20, 70, 2)
	wall.CFrame = origin * CFrame.new(0, 34, -46)
	wall.Parent = f
	for i, e in list do
		local col = (i - 1) % per
		local row = (i - 1) // per
		local cf = origin * CFrame.new((col - (per - 1) / 2) * 13, 0, -row * 22)
		local model = Instance.new("Model")
		model.Name = e.kind .. "_" .. e.id
		local rig = rigs and rigs:FindFirstChildWhichIsA("Model")
		local torso: BasePart
		if rig then
			rig = rig:Clone()
			for _, d in rig:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
				end
			end
			rig:PivotTo(cf * CFrame.new(0, 3, 0))
			rig.Parent = model
			torso = rig:FindFirstChild("UpperTorso") or rig:FindFirstChild("HumanoidRootPart")
		end
		local crate = Instance.new("Part")
		crate.Name = "Crate"
		crate.Anchored, crate.CanCollide, crate.CanQuery, crate.CanTouch = true, false, false, false
		crate.Size = Vector3.new(2.4, 2, 1.6)
		crate.Color = Color3.fromRGB(176, 120, 66)
		crate.Material = Enum.Material.WoodPlanks
		crate.CFrame = (if torso then torso.CFrame else cf * CFrame.new(0, 4, 0)) * CFrame.new(0, -0.6, 1.6)
		crate.Parent = model
		local opts = { family = "Wood" }
		local m
		if e.kind == "Family" then
			opts.family = e.id
			m = CarryFXMotifs.Attach(crate, opts)
			CarryFXMotifs.SetState(m, true, false, false, 1.3)
		elseif e.kind == "Mutation" then
			opts.tier = e.id
			opts.family = "None"
			m = CarryFXMotifs.Attach(crate, opts)
			CarryFXMotifs.SetState(m, false, true, false, 1.3)
		else
			opts.cosmetic = e.id
			opts.family = "None"
			m = CarryFXMotifs.Attach(crate, opts)
			CarryFXMotifs.SetState(m, false, false, true, 1)
		end
		local tag = Instance.new("BillboardGui")
		tag.Size = UDim2.fromOffset(150, 34)
		tag.StudsOffset = Vector3.new(0, 11, 0)
		tag.AlwaysOnTop = true
		tag.MaxDistance = 400
		tag.Adornee = crate
		tag.Parent = model
		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.fromScale(1, 1)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.BuilderSansExtraBold
		lbl.TextSize = 16
		lbl.RichText = true
		lbl.Text = string.format('%s\n<font size="12" color="rgb(190,200,215)">%s</font>', e.id, string.upper(e.kind))
		lbl.TextColor3 = Color3.new(1, 1, 1)
		lbl.TextStrokeTransparency = 0.4
		lbl.Parent = tag
		model.Parent = f
	end
	f.Parent = workspace
	return f
end

return CarryFXMotifs
