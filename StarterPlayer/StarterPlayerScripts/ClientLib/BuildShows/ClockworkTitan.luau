--!nonstrict
-- CLOCKWORK TITAN show. Activation (~45%): the great gear (A) begins to turn and the lens eyes warm up.
-- Milestone 1 (~72%): the shoulder gear (B, counter-rotating) and the chest gear (C) join, the core glows and the great
-- pendulum starts to swing between the legs. Completion (Titan Chime): every gear spins up and locks into step, steam vents
-- from the shoulder stacks, the head lifts, the right arm swings up and forward in one heavy clockwork motion with a clang,
-- three deep chimes ring (each one ticks the gears forward and pulses a gold ring), then the arm returns.
-- Every pose is composed per frame from each part's original CFrame (no drift).
local Show = {}

local CORE = Color3.fromRGB(110, 70, 30)
local AMBER = Color3.fromRGB(255, 176, 60)
local GOLD = Color3.fromRGB(255, 214, 120)

-- gear ratios (tooth counts by diameter): A 80, B 54 (meshes the other way), C 26
local RATIO = { GearA = 1, GearB = -80 / 54, GearC = 80 / 26 }

local function glow(p: BasePart, k: number)
	p.Color = CORE:Lerp(AMBER, math.clamp(k, 0, 1)):Lerp(GOLD, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.2 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

-- o = { a = { GearA = rad, ... }, pend = rad, yaw, pitch, r = { x, z, el } }
local function pose(sess, lib, o)
	local m = sess.model
	local P = m:GetPivot()
	local R = P.Rotation
	local function about(markerName: string, rx: number, ry: number, rz: number): CFrame?
		local mk = lib.find(m, markerName)
		local b = mk and sess:base(mk)
		if not b then
			return nil
		end
		local h = CFrame.new(b.Position) * R
		return h * CFrame.Angles(rx, ry, rz) * h:Inverse()
	end
	local function apply(name: string, X: CFrame?)
		if not X then
			return
		end
		for _, p in lib.group(m, name) do
			local b = sess:base(p)
			if b then
				p.CFrame = X * b
			end
		end
	end
	for name, ang in o.a or {} do
		apply(name, about(name .. "C", 0, 0, ang))
	end
	apply("Pendulum", about("PendPivot", 0, 0, o.pend or 0))
	apply("Head", about("Neck", o.pitch or 0, o.yaw or 0, 0))
	local r = o.r
	if r then
		local SH = about("ShoulderR", r.x or 0, 0, r.z or 0)
		if SH then
			apply("UpperArmR", SH)
			local el = lib.find(m, "ElbowR")
			local eb = el and sess:base(el)
			local EL = CFrame.identity
			if eb then
				local e = SH * (CFrame.new(eb.Position) * R)
				EL = e * CFrame.Angles(r.el or 0, 0, 0) * e:Inverse()
			end
			apply("ForearmR", EL * SH)
		end
	end
end

local function steam(model, lib, trash, n: number)
	for _, nm in { "SteamL", "SteamR" } do
		local mk = lib.find(model, nm)
		if mk then
			local a = lib.anchor(mk.Position, trash)
			local e = lib.emitter(a, lib.SMOKE, Color3.fromRGB(235, 235, 235), 7, 2.4, 22, trash)
			e.SpreadAngle = Vector2.new(10, 10)
			e:Emit(n)
		end
	end
end

function Show.Activate(sess, lib)
	sess.ang = { GearA = 0, GearB = 0, GearC = 0 }
	sess.join = 0
	lib.Sound.Play("Thud")
	sess:step(function(dt, t)
		local base = 0.22 * dt
		sess.ang.GearA += base
		sess.ang.GearB += base * RATIO.GearB * sess.join
		sess.ang.GearC += base * RATIO.GearC * sess.join
		for _, p in lib.group(sess.model, "Eye") do
			glow(p, 0.8 + 0.15 * math.sin(t * 2))
		end
		if sess.join > 0 then
			for _, p in lib.group(sess.model, "Core") do
				glow(p, (0.6 + 0.3 * math.sin(t * 1.5)) * sess.join + 0.1)
			end
		end
		pose(sess, lib, {
			a = sess.ang,
			pend = math.rad(14) * math.sin(t * 1.6) * sess.join,
		})
	end)
end

function Show.Milestone(sess, lib, n)
	if n ~= 1 then
		return
	end
	lib.Sound.Play("ChimeLow")
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < 2.5 do
		sess.join = (os.clock() - t0) / 2.5
		task.wait()
	end
	sess.join = 1
end

function Show.Spectacle(ctx, sess, lib)
	if not sess or not sess.ang then
		return
	end
	local m = ctx.model
	local ang = sess.ang
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
	local function turn(dt: number, speed: number)
		for name, r in RATIO do
			ang[name] += dt * speed * r
		end
	end
	local cores, eyes = lib.group(m, "Core"), lib.group(m, "Eye")
	local function lit(k: number)
		for _, p in cores do
			glow(p, k)
		end
		for _, p in eyes do
			glow(p, k)
		end
	end
	local ARM = { x = math.rad(78), z = math.rad(8), el = math.rad(-20) }
	-- 1. everything spins up and locks into step (1.6 s), steam vents
	lib.Sound.Play("Rumble")
	steam(m, lib, ctx.trash, 30)
	run(1.6, function(k, t, dt)
		turn(dt, 0.22 + 1.2 * k)
		lit(0.8 + 0.5 * k)
		pose(sess, lib, { a = ang, pend = math.rad(18) * math.sin(t * 2.4) })
	end)
	-- 2. the head lifts and looks (1.4 s)
	run(1.4, function(k, t, dt)
		turn(dt, 1.4)
		pose(sess, lib, { a = ang, pend = math.rad(18) * math.sin((t + 1.6) * 2.4), pitch = math.rad(-8) * ease(k), yaw = math.rad(16) * math.sin(k * math.pi) })
	end)
	-- 3. one heavy clockwork motion: the right arm swings up and forward, CLANG (1.6 s)
	run(1.6, function(k, t, dt)
		turn(dt, 1.4)
		local e = ease(k)
		pose(sess, lib, { a = ang, pend = math.rad(18) * math.sin((t + 3) * 2.4), pitch = math.rad(-8), r = { x = ARM.x * e, z = ARM.z * e, el = ARM.el * e } })
	end)
	lib.Sound.Play("Thud")
	lib.Sound.Play("Boom")
	lib.Cine.shake(0.4, 0.5)
	steam(m, lib, ctx.trash, 20)
	-- 4. three deep chimes: each one ticks the gears forward with a gold pulse (2.4 s)
	local chimes = 0
	local core = cores[1]
	local light = lib.light(lib.anchor(if core then core.Position else m:GetPivot().Position, ctx.trash), AMBER, 70, 0, ctx.trash)
	run(2.4, function(k, t, dt)
		local idx = math.floor(k * 3)
		if idx >= chimes and chimes < 3 and k < 1 then
			chimes += 1
			lib.Sound.Play("ChimeLow")
			lib.Cine.ring((core and core.Position) or m:GetPivot().Position, GOLD, 140, 1.2)
			for name, r in RATIO do
				ang[name] += math.rad(15) * r
			end
		end
		local pulse = math.exp(-((k * 3) % 1) * 5)
		lit(1.2 + 0.8 * pulse)
		light.Brightness = 1 + 5 * pulse
		turn(dt, 0.3)
		pose(sess, lib, { a = ang, pend = math.rad(18) * math.sin((t + 4.6) * 2.4), pitch = math.rad(-8), r = ARM })
	end)
	-- 5. the arm returns and everything settles back to its idle turn (1.6 s)
	lib.Sound.Play("Cheer")
	run(1.6, function(k, t, dt)
		turn(dt, 0.22)
		local e = 1 - ease(k)
		lit(0.9 + 0.3 * e)
		light.Brightness = 1 * e
		pose(sess, lib, { a = ang, pend = math.rad(14) * math.sin((t + 7) * 1.6), pitch = math.rad(-8) * e, r = { x = ARM.x * e, z = ARM.z * e, el = ARM.el * e } })
	end)
	sess.paused = false
end

return Show
