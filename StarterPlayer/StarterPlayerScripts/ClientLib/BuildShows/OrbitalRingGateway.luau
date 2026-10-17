--!nonstrict
-- ORBITAL RING GATEWAY show. The open centre stays open: nothing here fills the aperture except a brief transparent field.
-- Activation (~35%): energy traces start to travel slowly round the built outer ring segments; the support lights pulse.
-- Milestone 1 (~62%, once the inner ring exists): the inner ring turns slowly in its plane and sways a little on its vertical
-- axis like a gyroscope.
-- Milestone 2 (~82%, once the core exists): the core wakes and levitates, the power modules pulse, the inner ring settles into a
-- steadier spin and a faint shimmer begins to form just inside the inner ring.
-- Completion (Gateway Open, ~14 s): the rings accelerate; the inner ring swings flat into alignment as the core rises and locks
-- in the exact centre; energy traces race twice round the circumference; a transparent gateway field grows from the core to
-- fill the opening (shimmering, see-through), a world pulse rings out; the field holds, then fades and the rings idle down.
local Show = {}

local GLOW0 = Color3.fromRGB(36, 58, 78)
local CYAN = Color3.fromRGB(110, 230, 255)
local WHITE = Color3.fromRGB(225, 250, 255)

local function glow(p: BasePart, k: number)
	p.Color = GLOW0:Lerp(CYAN, math.clamp(k, 0, 1)):Lerp(WHITE, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.2 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

local function wrap(d: number): number
	return ((d + math.pi) % (math.pi * 2)) - math.pi
end

-- remember each outer segment's own colour so the traces can tint it and give it back
local function outer(sess, lib)
	local list = {}
	for _, p in lib.group(sess.model, "Outer") do
		if p:GetAttribute("A") then
			if not p:GetAttribute("MBCol") then
				p:SetAttribute("MBCol", p.Color)
			end
			table.insert(list, p)
		end
	end
	return list
end

local function trace(list, head: number, width: number, gain: number)
	for _, p in list do
		local d = math.abs(wrap(p:GetAttribute("A") - head))
		local g = math.exp(-(d / width) ^ 2) * gain
		local base = p:GetAttribute("MBCol")
		p.Color = base:Lerp(CYAN, math.clamp(g, 0, 1))
		p.Material = if g > 0.35 then Enum.Material.Neon else Enum.Material.Metal
	end
end

-- o = { spin (rad, in-plane), tilt (rad, about the vertical axis), coreLift (studs), coreSpin (rad) }
local function pose(sess, lib, o)
	local m = sess.model
	local P = m:GetPivot()
	local R = P.Rotation
	local ic = lib.find(m, "InnerC")
	local ib = ic and sess:base(ic)
	if ib then
		local h = CFrame.new(ib.Position) * R
		local X = h * CFrame.Angles(0, o.tilt or 0, 0) * CFrame.Angles(0, 0, o.spin or 0) * h:Inverse()
		for _, name in { "Inner", "Tether" } do
			for _, p in lib.group(m, name) do
				local b = sess:base(p)
				if b then
					p.CFrame = X * b
				end
			end
		end
	end
	local cc = lib.find(m, "CoreC")
	local cb = cc and sess:base(cc)
	if cb then
		local h = CFrame.new(cb.Position) * R
		local X = CFrame.new(P.UpVector * (o.coreLift or 0)) * h * CFrame.Angles(0, o.coreSpin or 0, 0) * h:Inverse()
		for _, p in lib.group(m, "Core") do
			local b = sess:base(p)
			if b then
				p.CFrame = X * b
			end
		end
	end
end

-- a thin see-through field disc filling the aperture (template Z axis = the disc axis)
local function fieldPart(P: CFrame, pos: Vector3, trash)
	local f = Instance.new("Part")
	f.Name = "MB_GateField"
	f.Anchored, f.CanCollide, f.CanQuery, f.CanTouch, f.CastShadow = true, false, false, false, false
	f.Shape = Enum.PartType.Cylinder
	f.Material = Enum.Material.ForceField
	f.Color = CYAN
	f.Transparency = 1
	f.Size = Vector3.new(0.6, 4, 4)
	f.CFrame = CFrame.new(pos) * P.Rotation * CFrame.Angles(0, math.rad(90), 0)
	f.Parent = workspace
	table.insert(trash, f)
	return f
end

function Show.Activate(sess, lib)
	sess.inner, sess.core = 0, 0
	sess.spin = 0
	lib.Sound.Play("Zap")
	sess:step(function(dt, t)
		local m = sess.model
		trace(outer(sess, lib), (t * 0.5) % (math.pi * 2) - math.pi, 0.35, 0.7)
		for _, p in lib.group(m, "SupportGlow") do
			glow(p, 0.5 + 0.3 * math.sin(t * 1.5))
		end
		sess.spin += dt * (0.22 + 0.25 * sess.core) * sess.inner
		local tilt = math.rad(14) * sess.inner * (1 - 0.6 * sess.core) * math.sin(t * 0.35)
		if sess.core > 0 then
			for _, p in lib.group(m, "Core") do
				glow(p, 0.7 + 0.3 * math.sin(t * 2))
			end
			for i, p in lib.group(m, "Power") do
				glow(p, sess.core * (0.55 + 0.45 * math.sin(t * 2.2 + i)))
			end
			for _, p in lib.group(m, "Crown") do
				glow(p, sess.core * 0.8)
			end
			if not sess.shimmer then
				local cc = lib.find(m, "CoreC")
				if cc then
					sess.shimmer = fieldPart(m:GetPivot(), cc.Position, sess.trash)
					sess.shimmer.Size = Vector3.new(0.4, 116, 116)
				end
			end
			if sess.shimmer then
				sess.shimmer.Transparency = 1 - 0.12 * sess.core * (0.6 + 0.4 * math.sin(t * 1.3))
			end
		end
		pose(sess, lib, { spin = sess.spin, tilt = tilt, coreLift = -4 * sess.core + 1.2 * sess.core * math.sin(t * 1.1), coreSpin = t * 0.6 * sess.core })
	end)
end

function Show.Milestone(sess, lib, n)
	local key = if n == 1 then "inner" else "core"
	lib.Sound.Play(if n == 1 then "Rumble" else "PowerUp")
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < 3 do
		sess[key] = (os.clock() - t0) / 3
		task.wait()
	end
	sess[key] = 1
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local P = m:GetPivot()
	local last = os.clock()
	local function run(seconds: number, fn)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and ctx.alive() do
			local now = os.clock()
			fn((now - t0) / seconds, now - t0, math.min(now - last, 0.05))
			last = now
			task.wait()
		end
		fn(1, seconds, 0)
	end
	local function ease(k: number): number
		return k * k * (3 - 2 * k)
	end
	local list = outer(sess, lib)
	local powers, cores, crown = lib.group(m, "Power"), lib.group(m, "Core"), lib.group(m, "Crown")
	local spin, speed = sess.spin or 0, 0.47
	local cc = lib.find(m, "CoreC")
	local centre = if cc then cc.Position else (P * CFrame.new(0, 112, -4)).Position
	local T = 0
	if sess.shimmer then
		sess.shimmer.Transparency = 1
	end
	-- 1. the rings accelerate (2.5 s)
	lib.Sound.Play("PowerUp")
	lib.Sound.Play("Rumble")
	run(2.5, function(k, t, dt)
		T += dt
		speed = 0.47 + 2.6 * k
		spin += dt * speed
		for i, p in powers do
			glow(p, 0.9 + 0.5 * k)
		end
		trace(list, (T * (0.5 + 2 * k)) % (math.pi * 2) - math.pi, 0.4, 0.8)
		pose(sess, lib, { spin = spin, tilt = math.rad(8) * math.sin(T * 0.6), coreLift = -4, coreSpin = T })
	end)
	-- 2. the inner ring swings flat into alignment; the core rises and locks in the exact centre (2 s)
	run(2, function(k, t, dt)
		T += dt
		spin += dt * speed
		local e = ease(k)
		for _, p in cores do
			glow(p, 1 + 0.7 * e)
		end
		pose(sess, lib, { spin = spin, tilt = math.rad(8) * math.sin(T * 0.6) * (1 - e), coreLift = -4 * (1 - e), coreSpin = T * (1 - e) })
	end)
	lib.Sound.Play("Thud")
	lib.Cine.shake(0.25, 0.4)
	lib.Cine.ring(centre, WHITE, 60, 0.8)
	-- 3. energy traces race twice round the circumference (2.5 s)
	lib.Sound.Play("Zap")
	run(2.5, function(k, t, dt)
		T += dt
		spin += dt * speed
		local head = -math.pi / 2 + k * math.pi * 4
		trace(list, head, 0.45, 1.6)
		for _, p in crown do
			glow(p, 0.8 + 0.8 * k)
		end
		pose(sess, lib, { spin = spin, tilt = 0, coreLift = 0, coreSpin = 0 })
	end)
	-- 4. the gateway field grows from the core to fill the opening; the world pulse (3.5 s)
	lib.Sound.Play("Boom")
	lib.Sound.Play("Meteor")
	lib.Cine.bloom(0.45, 0.2, 2.5, 1.5)
	lib.Cine.ring(P.Position + Vector3.new(0, 2, 0), CYAN, 300, 2.4)
	local field = fieldPart(P, centre, ctx.trash)
	local inner2 = fieldPart(P, centre + P.LookVector * -1.5, ctx.trash) -- a second layer a little deeper: depth, not a flat disc
	local la = lib.anchor(centre, ctx.trash)
	local fl = lib.light(la, CYAN, 160, 0, ctx.trash)
	run(3.5, function(k, t, dt)
		T += dt
		spin += dt * speed
		local e = ease(math.clamp(k / 0.6, 0, 1))
		local d = 10 + 150 * e
		field.Size = Vector3.new(0.6, d, d)
		field.Transparency = 0.25 + 0.15 * math.sin(T * 6)
		inner2.Size = Vector3.new(0.6, d * 0.72, d * 0.72)
		inner2.Transparency = 0.45 + 0.15 * math.sin(T * 5 + 1)
		fl.Brightness = 6 * e
		trace(list, -math.pi / 2 + T * 3, 0.6, 1.2)
		pose(sess, lib, { spin = spin, tilt = 0, coreLift = 0, coreSpin = 0 })
	end)
	-- 5. the field holds briefly, then fades; the rings idle down (3 s)
	lib.Sound.Play("Cheer")
	run(3, function(k, t, dt)
		T += dt
		speed = 3.07 - 2.6 * ease(k)
		spin += dt * speed
		local f = math.clamp((k - 0.25) / 0.75, 0, 1)
		field.Transparency = 0.25 + 0.75 * f
		inner2.Transparency = 0.45 + 0.55 * f
		fl.Brightness = 6 * (1 - f)
		trace(list, -math.pi / 2 + T * (3 - 2.5 * k), 0.5, 1.2 * (1 - f) + 0.5)
		for _, p in powers do
			glow(p, 1.4 - 0.6 * k)
		end
		pose(sess, lib, { spin = spin, tilt = 0, coreLift = 0, coreSpin = 0 })
	end)
	sess.spin = spin
	sess.paused = false
end

return Show
