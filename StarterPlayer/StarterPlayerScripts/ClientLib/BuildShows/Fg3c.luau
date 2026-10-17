--!nonstrict
-- FORGOTTEN F2 show (module name = the opaque build key; nothing here names the structure). A gigantic ancient engine.
-- Activation (~17%, axle built): the central axle turns slowly.
-- Milestone 1 (~33%, Gear I built): the first giant gear engages.
-- Milestone 2 (~56%, rings built): the vertical and horizontal rings join, then the second gear.
-- Milestone 3 (~87%, counterweights built): the inner mechanism spins up and the counterweights begin to swing.
-- Milestone 4 (~94%, synchronizers built): the core halves breathe and the conduits synchronise the whole engine.
-- Completion (~17 s): mechanisms wake in sequence, rings and gears synchronise, the counterweights move, the core compresses and
-- pulses, full power for a moment, one huge controlled pulse, then a settled active idle.
local Show = {}
Show.SpectacleId = "Fg3cShow"

local GLOW0 = Color3.fromRGB(52, 78, 96)
local CYAN = Color3.fromRGB(120, 215, 255)
local WHITE = Color3.fromRGB(230, 248, 255)
local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

local function glow(p: BasePart, k: number)
	p.Color = GLOW0:Lerp(CYAN, math.clamp(k, 0, 1)):Lerp(WHITE, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.3 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

-- sess.a = { axle, g1, g2, vr, hr, inn } angles; sess.lv = { axle, g1, g2, vr, hr, inn } speed levels; sess.wt (weight swing, studs);
-- sess.core (compress studs); sess.glow 0..1
local function pose(sess, lib)
	local a = sess.a
	lib.spin(sess, "Axle", "HRingC", Y, a.axle)
	lib.spin(sess, "Gear1", "Gear1C", Z, a.g1)
	lib.spin(sess, "Gear2", "Gear2C", X, a.g2)
	lib.spin(sess, "VRing", "VRingC", Z, a.vr)
	lib.spin(sess, "HRing", "HRingC", Y, a.hr)
	lib.spin(sess, "Inner", "InnerC", X, a.inn)
	local up = sess.model:GetPivot().Rotation * Y
	lib.spin(sess, "CoreLow", nil, nil, 0, CFrame.new(up * sess.core))
	lib.spin(sess, "CoreUp", nil, nil, 0, CFrame.new(-up * sess.core))
	-- counterweights: pairs move in opposition
	for _, p in lib.groupOf(sess, "Weights") do
		local b = sess:base(p)
		if b then
			local sign = if p:GetAttribute("Alt") == 2 then -1 else 1
			p.CFrame = CFrame.new(up * (sign * sess.wt)) * b
		end
	end
end

local function lights(sess, lib, t: number, level: number, pulse: number)
	for _, p in lib.groupOf(sess, "Sync") do
		local o = p:GetAttribute("Order") or 1
		local wave = 0.5 + 0.5 * math.sin(t * 4 - o * 0.8)
		glow(p, level * 0.4 + pulse * wave)
	end
	for _, p in lib.groupOf(sess, "CoreGlow") do
		glow(p, 0.3 + level * 0.6 + pulse * 0.3 + 0.12 * math.sin(t * 2))
	end
end

local SPEED = { axle = 0.18, g1 = 0.26, g2 = -0.29, vr = 0.2, hr = -0.15, inn = 0.5 }

function Show.Activate(sess, lib)
	sess.a = { axle = 0, g1 = 0, g2 = 0, vr = 0, hr = 0, inn = 0 }
	sess.lv = { axle = 1, g1 = 0, g2 = 0, vr = 0, hr = 0, inn = 0 }
	sess.wt, sess.core, sess.level, sess.pulse = 0, 0, 0, 0
	lib.Sound.Play("Rumble")
	sess:step(function(dt, t)
		for k, v in SPEED do
			sess.a[k] += dt * v * sess.lv[k]
		end
		sess.core = sess.level * 1.6 * math.sin(t * 1.1)
		sess.wt = sess.level * 8 * math.sin(t * 0.55)
		pose(sess, lib)
		if sess.level > 0 then
			lights(sess, lib, t, sess.level, sess.pulse)
		end
	end)
end

local function ramp(tbl, key: string, to: number, secs: number, alive)
	local from = tbl[key] or 0
	local t0 = os.clock()
	while alive() and os.clock() - t0 < secs do
		tbl[key] = from + (to - from) * ((os.clock() - t0) / secs)
		task.wait()
	end
	tbl[key] = to
end

function Show.Milestone(sess, lib, n)
	if n == 1 then
		lib.Sound.Play("Rumble")
		ramp(sess.lv, "g1", 1, 3, sess.alive)
	elseif n == 2 then
		lib.Sound.Play("PowerUp")
		ramp(sess.lv, "vr", 1, 3, sess.alive)
		ramp(sess.lv, "hr", 1, 2, sess.alive)
		ramp(sess.lv, "g2", 1, 2, sess.alive)
	elseif n == 3 then
		lib.Sound.Play("PowerUp")
		ramp(sess.lv, "inn", 1, 3, sess.alive)
		ramp(sess, "level", 0.4, 2, sess.alive)
	else
		lib.Sound.Play("Zap")
		ramp(sess, "level", 0.8, 3, sess.alive)
		ramp(sess, "pulse", 0.6, 2, sess.alive)
	end
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local P = m:GetPivot()
	local last = os.clock()
	local T = 0
	local function run(seconds: number, fn)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and ctx.alive() do
			local now = os.clock()
			local dt = math.min(now - last, 0.05)
			T += dt
			fn((now - t0) / seconds, dt)
			pose(sess, lib)
			last = now
			task.wait()
		end
		fn(1, 0)
		pose(sess, lib)
	end
	local function ease(k: number): number
		return k * k * (3 - 2 * k)
	end
	local lv = sess.lv
	-- speed multiplier per mechanism (so the spin can wake in sequence, synchronise, then idle)
	local mul = { axle = 1, g1 = 1, g2 = 1, vr = 1, hr = 1, inn = 1 }
	local function spin(dt: number)
		for k, v in SPEED do
			sess.a[k] += dt * v * math.max(lv[k], 0.4) * mul[k]
		end
	end
	local cc = lib.find(m, "CoreC")
	local cb = cc and sess:base(cc)
	local centre = if cb then cb.Position else (P * CFrame.new(0, 125, 0)).Position
	local order = { "axle", "g1", "g2", "vr", "hr", "inn" }
	-- 1. mechanisms wake in sequence (3.5 s): each speeds up in turn
	lib.Sound.Play("PowerUp")
	lib.Sound.Play("Rumble")
	run(3.5, function(k, dt)
		for i, key in order do
			mul[key] = 1 + 2.2 * ease(math.clamp(k * 1.6 - (i - 1) * 0.16, 0, 1))
		end
		spin(dt)
		lights(sess, lib, T, 0.7 + 0.3 * k, 0.3 * k)
	end)
	-- 2. rings and gears synchronise (3 s): all settle onto one steady rate
	lib.Sound.Play("Thud")
	lib.Cine.shake(0.2, 0.5)
	run(3, function(k, dt)
		for _, key in order do
			mul[key] = 3.2 - 1.6 * ease(k)
		end
		spin(dt)
		lights(sess, lib, T, 1, 0.5 + 0.3 * k)
	end)
	-- 3. counterweights move (3 s)
	lib.Sound.Play("Rumble")
	run(3, function(k, dt)
		spin(dt)
		sess.wt = 22 * math.sin(k * math.pi * 2) * ease(math.clamp(k * 3, 0, 1)) * (1 - 0.3 * k)
		lights(sess, lib, T, 1, 0.8)
	end)
	-- 4. the core compresses and pulses (3 s)
	lib.Sound.Play("Zap")
	run(3, function(k, dt)
		spin(dt)
		sess.wt *= 0.9
		sess.core = -7 * ease(math.clamp(k * 1.4, 0, 1)) + 2.2 * math.sin(T * 14) * k
		lights(sess, lib, T, 1.2, 1 + 0.5 * k)
		for _, p in lib.groupOf(sess, "CoreGlow") do
			glow(p, 1 + 0.9 * k)
		end
	end)
	sess.wt = 0
	-- 5. full power briefly (1.5 s)
	lib.Cine.bloom(0.4, 0.2, 1.5, 1)
	run(1.5, function(k, dt)
		for _, key in order do
			mul[key] = 1.6 + 2 * ease(k)
		end
		spin(dt)
		sess.core = -7
		lights(sess, lib, T, 1.3, 1.2)
		for _, p in lib.groupOf(sess, "CoreGlow") do
			glow(p, 2)
		end
	end)
	-- 6. one huge controlled pulse (1.5 s): an expanding see-through ring from the core
	lib.Sound.Play("Boom")
	lib.Sound.Play("Meteor")
	lib.Cine.shake(0.5, 1)
	lib.Cine.bloom(0.55, 0.2, 2.5, 1.5)
	lib.Cine.ring(centre, WHITE, 220, 1.5)
	local wave = Instance.new("Part")
	wave.Name = "MB_EnginePulse"
	wave.Anchored, wave.CanCollide, wave.CanQuery, wave.CanTouch, wave.CastShadow = true, false, false, false, false
	wave.Shape = Enum.PartType.Cylinder
	wave.Material = Enum.Material.Neon
	wave.Color = CYAN
	wave.Size = Vector3.new(2, 10, 10)
	wave.CFrame = CFrame.new(centre) * P.Rotation * CFrame.Angles(0, 0, math.rad(90))
	wave.Parent = workspace
	table.insert(ctx.trash, wave)
	local la = lib.anchor(centre, ctx.trash)
	local fl = lib.light(la, CYAN, 200, 0, ctx.trash)
	run(1.5, function(k, dt)
		spin(dt)
		local d = 10 + 380 * ease(k)
		wave.Size = Vector3.new(2, d, d)
		wave.Transparency = 0.35 + 0.65 * k
		sess.core = -7 * (1 - ease(k))
		fl.Brightness = 12 * (1 - k)
		lights(sess, lib, T, 1.3, 1.4 * (1 - k) + 0.3)
	end)
	wave:Destroy()
	-- 7. settle to an active idle (1.5 s)
	lib.Cine.shake(0.15, 0.4)
	run(1.5, function(k, dt)
		for _, key in order do
			mul[key] = 3.6 - 2.6 * ease(k)
		end
		spin(dt)
		sess.core = 0
		lights(sess, lib, T, 1 - 0.3 * k, 0.4)
	end)
	sess.core = 0
	sess.level, sess.pulse = 0.7, 0.3
	sess.paused = false
end

return Show
