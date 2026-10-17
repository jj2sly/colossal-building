--!nonstrict
-- GIANT SPAWN PAD show. The model is plain classic grey (no permanent neon); the cyan only appears here.
-- The pad is authored TILTED on one lower corner with temporary orange braces (see ServerStorage/DevTools/ColossalBuilds).
-- Activation (~75%): a restrained classic cyan shimmer runs across the plate and the pad settles / rocks a hair on its corner.
-- Completion (one slow, heavy showpiece): the braces release and sink into the deck; the pad lifts; it rolls the whole way
-- over its resting corner (never fast; the hoist keeps it clear of the deck) while the cyan shimmer pulses; it comes in flat
-- on its base and drops with a heavy impact; the studs / core flash once; the classic spawn burst plays; the colours are
-- restored to grey and the braces are gone for good.
-- Everything is composed from each part's original (tilted) CFrame, about the corner that never moves.
local Show = {}

local GLOW = Color3.fromRGB(90, 220, 255)
local WHITE = Color3.fromRGB(235, 252, 255)

local function baseColor(sess, p: BasePart): Color3
	sess.colors = sess.colors or {}
	local c = sess.colors[p]
	if not c then
		c = p.Color
		sess.colors[p] = c
	end
	return c
end

-- every part that moves with the plate (the three groups), refreshed twice a second while stages are still appearing
local function movers(sess, lib)
	local c = sess.moverCache
	if not c or os.clock() - c.at > 0.5 then
		local list = {}
		for _, g in { "Pad", "Cap", "Core" } do
			for _, p in lib.group(sess.model, g) do
				table.insert(list, p)
			end
		end
		c = { at = os.clock(), list = list, core = lib.group(sess.model, "Core"), caps = lib.group(sess.model, "Cap") }
		sess.moverCache = c
	end
	return c
end

-- the tilt in world space: Tw (flat -> tilted), the fixed corner Cw and the rotation back to flat
local function tiltInfo(sess, lib)
	local m = sess.model
	local ref = lib.find(m, "TiltRef")
	local rb = ref and sess:base(ref)
	if not rb then
		return nil
	end
	local P = m:GetPivot()
	local Tl = P:Inverse() * rb
	local Tw = P * Tl * P:Inverse()
	local cornerLocal: Vector3 = ref:GetAttribute("Corner")
	local Cw = P:PointToWorldSpace(cornerLocal)
	local Rinv = (Tw - Tw.Position):Inverse()
	local ax, ang = Rinv:ToAxisAngle()
	return { P = P, Tw = Tw, Cw = Cw, ax = ax, ang = ang }
end

-- pose every plate part: rotate by `alpha` about the corner axis, then lift by `h`
local function pose(sess, lib, info, alpha: number, h: number, extraYaw: number?)
	local rot = CFrame.fromAxisAngle(info.ax, alpha)
	local M = CFrame.new(0, h, 0) * CFrame.new(info.Cw) * rot * CFrame.new(-info.Cw)
	for _, p in movers(sess, lib).list do
		local b = sess:base(p)
		if b then
			p.CFrame = M * b
		end
	end
end

-- lowest world Y of the pad's bounding box (8 corners) after rotating by alpha about the corner (no lift)
local function lowest(info, alpha: number): number
	local rot = CFrame.fromAxisAngle(info.ax, alpha)
	local M = CFrame.new(info.Cw) * rot * CFrame.new(-info.Cw)
	local minY = math.huge
	for _, sx in { -36, 36 } do
		for _, sz in { -36, 36 } do
			for _, y in { 0, 30 } do
				local flat = info.P:PointToWorldSpace(Vector3.new(sx, y, sz))
				local pt = M:PointToWorldSpace(info.Tw:PointToWorldSpace(flat))
				minY = math.min(minY, pt.Y)
			end
		end
	end
	return minY
end

local function tint(sess, lib, amount: number, coreAmount: number)
	local c = movers(sess, lib)
	for _, p in c.list do
		if not p:GetAttribute("Marker") then
			p.Color = baseColor(sess, p):Lerp(GLOW, amount)
		end
	end
	for _, p in c.core do
		if not p:GetAttribute("Marker") then
			p.Color = baseColor(sess, p):Lerp(GLOW, coreAmount)
		end
	end
end

function Show.Activate(sess, lib)
	local light
	sess:step(function(_, t)
		if sess.landed then
			return
		end
		local info = tiltInfo(sess, lib)
		-- slight settling on the corner
		if info then
			local a = math.rad(0.35) * math.sin(t * 0.9) + math.rad(0.12) * math.sin(t * 2.3)
			pose(sess, lib, info, a, 0)
		end
		-- restrained classic cyan shimmer sweeping across the plate
		local pulse = 0.12 + 0.1 * math.sin(t * 2.2) + 0.05 * math.noise(t * 5, 1.7)
		tint(sess, lib, math.clamp(pulse, 0, 0.3), math.clamp(pulse * 2.4, 0, 0.7))
		if not light then
			local top = lib.find(sess.model, "CoreTop")
			if top then
				light = lib.light(top, GLOW, 40, 0, sess.trash)
			end
		end
		if light then
			light.Brightness = math.clamp(pulse * 3, 0, 1.2)
		end
	end)
end

local function ease(k: number): number -- smootherstep: slow start, slow finish
	k = math.clamp(k, 0, 1)
	return k * k * k * (k * (k * 6 - 15) + 10)
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local info = tiltInfo(sess, lib)
	if not info then
		return
	end
	local function run(seconds: number, fn)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and ctx.alive() do
			fn((os.clock() - t0) / seconds)
			task.wait()
		end
		fn(1)
	end
	local flatCorners = {}
	for _, sx in { -36, 36 } do
		for _, sz in { -36, 36 } do
			table.insert(flatCorners, info.P:PointToWorldSpace(Vector3.new(sx, 0, sz)))
		end
	end

	-- 1. the braces release: each one slides down its own axis into the deck and fades; dust at the feet
	lib.Sound.Play("Rumble")
	local braces = {}
	for _, d in m:GetDescendants() do
		if d:IsA("Model") and d.Name == "Brace" then
			local dir = info.P:VectorToWorldSpace(d:GetAttribute("Dir") or Vector3.new(0, -1, 0))
			local parts = {}
			for _, p in d:GetDescendants() do
				if p:IsA("BasePart") then
					p.CanCollide = false
					table.insert(parts, { p = p, b = p.CFrame, t = p.Transparency })
				end
			end
			table.insert(braces, { dir = dir, parts = parts })
		end
	end
	for _, br in braces do
		local foot = br.parts[#br.parts]
		if foot then
			lib.Cine.burst(foot.b.Position, "Dust", 1.2)
		end
	end
	run(0.7, function(k)
		local e = ease(k)
		pose(sess, lib, info, math.rad(0.35) * math.sin(k * 11) * (1 - k), 0)
		for _, br in braces do
			for _, it in br.parts do
				it.p.CFrame = it.b + br.dir * (38 * e)
				it.p.Transparency = it.t + (1 - it.t) * math.clamp((k - 0.55) / 0.45, 0, 1)
			end
		end
		tint(sess, lib, 0.14 + 0.1 * math.sin(k * 14), 0.4)
	end)
	for _, br in braces do
		for _, it in br.parts do
			it.p.Transparency = 1
		end
	end

	-- 2. the pad lifts slightly off its corner
	local LIFT = 8
	run(0.5, function(k)
		pose(sess, lib, info, 0, LIFT * ease(k))
		tint(sess, lib, 0.2 + 0.1 * k, 0.5)
	end)

	-- 3. the showpiece: one slow roll the whole way over the resting corner, ending flat. The hoist keeps the lowest corner of
	-- the pad (studs and core included) a stud clear of the deck all the way; it hovers a few studs up at the end.
	local total = info.ang - 2 * math.pi
	local HOVER = 6
	lib.Sound.Play("Chime")
	lib.Cine.shake(0.2, 1.2)
	run(2.6, function(k)
		local e = ease(k)
		local alpha = total * e
		local clear = (info.P.Position.Y + 1) - lowest(info, alpha) -- a stud clear of the deck surface
		local h = math.max(LIFT + (HOVER - LIFT) * e, clear)
		pose(sess, lib, info, alpha, h)
		local energy = math.sin(math.clamp(k, 0, 1) * math.pi) -- strongest mid-roll
		tint(sess, lib, 0.2 + 0.28 * energy, 0.45 + 0.4 * energy)
	end)

	-- 4. the drop: it falls the last few studs flat onto its base, accelerating, and lands heavily
	run(0.25, function(k)
		pose(sess, lib, info, total, HOVER * (1 - k * k))
		tint(sess, lib, 0.2, 0.5)
	end)
	sess.landed = true
	lib.Sound.Play("Thud")
	lib.Sound.Play("Boom")
	lib.Cine.shake(0.9, 0.9)
	for _, pt in flatCorners do
		lib.Cine.burst(pt, "Dust", 1.6)
	end
	local base = info.P.Position
	lib.Cine.ring(base + Vector3.new(0, 6, 0), Color3.fromRGB(220, 224, 232), 130, 1.1)

	-- 5. studs / core flash once, then the classic spawn burst
	local c = movers(sess, lib)
	for _, p in c.core do
		if not p:GetAttribute("Marker") then
			p.Color = WHITE
			p.Material = Enum.Material.Neon
		end
	end
	for _, p in c.caps do
		p.Color = GLOW
	end
	task.wait(0.15)
	for _, p in c.list do
		if not p:GetAttribute("Marker") and not (p.Parent and p.Parent.Name == "Core") then
			lib.tween(p, 0.5, { Color = baseColor(sess, p) })
		end
	end
	local top = lib.find(m, "CoreTop")
	local topPos = if top then top.Position else base + Vector3.new(0, 30, 0)
	lib.Sound.Play("Chime")
	for i = 1, 3 do
		lib.Cine.ring(base + Vector3.new(0, 7, 0), GLOW, 70 + i * 45, 1.3)
		task.wait(0.1)
	end
	local a = lib.anchor(topPos, ctx.trash)
	local e = lib.emitter(a, lib.SPARK, WHITE, 3, 3, 42, ctx.trash)
	e.SpreadAngle = Vector2.new(24, 24)
	e.Acceleration = Vector3.new(0, -8, 0)
	e.LightEmission = 1
	e:Emit(150)
	local beam = Instance.new("Part")
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch = true, false, false, false
	beam.Shape = Enum.PartType.Cylinder
	beam.Material = Enum.Material.Neon
	beam.Color = GLOW
	beam.Transparency = 0.45
	beam.Size = Vector3.new(70, 16, 16)
	beam.CFrame = CFrame.new(topPos + Vector3.new(0, 34, 0)) * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = workspace
	table.insert(ctx.trash, beam)
	lib.tween(beam, 1.0, { Transparency = 1, Size = Vector3.new(120, 3, 3) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	lib.Sound.Play("Cheer")
	task.wait(0.5)

	-- 6. everything back to permanent grey (no neon left)
	for _, p in c.list do
		if not p:GetAttribute("Marker") then
			p.Material = Enum.Material.SmoothPlastic
			lib.tween(p, 0.4, { Color = baseColor(sess, p) })
		end
	end
	task.wait(0.3)
	sess.paused = false
end

return Show
