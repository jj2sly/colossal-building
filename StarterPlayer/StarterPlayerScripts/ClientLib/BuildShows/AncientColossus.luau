--!nonstrict
-- ANCIENT COLOSSUS show. Activation (~40%): the crack lines and shield/pedestal runes faintly wake with a slow amber pulse.
-- Milestone 1 (~65%): the eyes and the chest core light, and the head begins a very slow, tiny look.
-- Milestone 2 (~82%): the sword arm starts a heavy shift: every few seconds it lifts the sword a few degrees and lets it settle.
-- Completion (Awakening, ~12 s): ancient energy climbs through the body from the feet to the helmet; the head turns toward the
-- server; the right arm slowly hauls the colossal sword up into a raised hero pose; an ancient pulse rings out from the core;
-- then the sword comes down and its point strikes the pedestal with a deep stone impact and dust.
-- Every pose is composed per frame from each part's original CFrame (no drift). All motion is slow and heavy.
local Show = {}

local GLOW0 = Color3.fromRGB(70, 58, 44)
local AMBER = Color3.fromRGB(255, 168, 60)
local GOLD = Color3.fromRGB(255, 220, 140)
local DUST = Color3.fromRGB(176, 166, 150)

local function glow(p: BasePart, k: number)
	p.Color = GLOW0:Lerp(AMBER, math.clamp(k, 0, 1)):Lerp(GOLD, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.25 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

local function heavy(k: number): number -- quintic ease in-out: slow start, slow stop
	k = math.clamp(k, 0, 1)
	return k * k * k * (k * (k * 6 - 15) + 10)
end

-- the hero raise: the arm turns about the shoulder from its resting direction toward a raised direction (template space)
local REST = Vector3.new(20, -74, -36).Unit
local RAISED = Vector3.new(0.45, 0.8, -0.4).Unit

-- o = { yaw (head, rad), raise (0..1 of the hero raise), lift (extra small lift, rad) }
local function pose(sess, lib, o)
	local m = sess.model
	local P = m:GetPivot()
	local R = P.Rotation
	local neck = lib.find(m, "Neck")
	local nb = neck and sess:base(neck)
	if nb then
		local h = CFrame.new(nb.Position) * R
		local X = h * CFrame.Angles(o.pitch or 0, o.yaw or 0, 0) * h:Inverse()
		for _, p in lib.group(m, "Head") do
			local b = sess:base(p)
			if b then
				p.CFrame = X * b
			end
		end
	end
	local sh = lib.find(m, "ShoulderR")
	local sb = sh and sess:base(sh)
	if sb then
		local axis = REST:Cross(RAISED).Unit
		local full = math.acos(math.clamp(REST:Dot(RAISED), -1, 1))
		local ang = full * (o.raise or 0) + (o.lift or 0)
		local h = CFrame.new(sb.Position) * R
		local X = h * CFrame.fromAxisAngle(axis, ang) * h:Inverse()
		for _, p in lib.group(m, "ArmR") do
			local b = sess:base(p)
			if b then
				p.CFrame = X * b
			end
		end
	end
end

local function cracks(m, lib, k: number, wave: number?)
	local P = m:GetPivot()
	for _, name in { "Crack", "Rune" } do
		for _, p in lib.group(m, name) do
			local kk = k
			if wave then
				local y = P:PointToObjectSpace(p.Position).Y
				kk = k + 1.2 * math.exp(-((y - wave) / 30) ^ 2)
			end
			glow(p, kk)
		end
	end
end

function Show.Activate(sess, lib)
	sess.wake, sess.shift = 0, 0
	lib.Sound.Play("Rumble")
	local nextShift = 4
	sess:step(function(_, t)
		local m = sess.model
		cracks(m, lib, 0.45 + 0.2 * math.sin(t * 0.8))
		for _, name in { "Eye", "Core" } do
			for _, p in lib.group(m, name) do
				glow(p, sess.wake * (0.85 + 0.15 * math.sin(t * 1.1)))
			end
		end
		local lift = 0
		if sess.shift > 0 then
			local tt = t - nextShift
			if tt > 0 then
				lift = math.sin(math.clamp(tt / 4, 0, 1) * math.pi) * math.rad(4) * sess.shift
				if tt > 4 then
					nextShift = t + 5
					lib.Sound.Play("Thud")
				end
			end
		end
		pose(sess, lib, { yaw = math.rad(3) * sess.wake * math.sin(t * 0.25), lift = lift })
	end)
end

function Show.Milestone(sess, lib, n)
	local key = if n == 1 then "wake" else "shift"
	lib.Sound.Play(if n == 1 then "ChimeLow" else "Rumble")
	if n == 1 then
		local c = lib.group(sess.model, "Core")[1]
		if c then
			lib.light(c, AMBER, 30, 1.2, sess.trash)
		end
	end
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
	local scale = m:GetScale()
	local function run(seconds: number, fn)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and ctx.alive() do
			fn((os.clock() - t0) / seconds, os.clock() - t0)
			task.wait()
		end
		fn(1, seconds)
	end
	local cores, eyes = lib.group(m, "Core"), lib.group(m, "Eye")
	local function inner(k: number)
		for _, p in cores do
			glow(p, k)
		end
		for _, p in eyes do
			glow(p, k)
		end
	end
	local YAW = math.rad(-16)
	-- 1. ancient energy climbs the body (2.4 s)
	lib.Sound.Play("Rumble")
	lib.Cine.shake(0.15, 2.2)
	run(2.4, function(k)
		cracks(m, lib, 0.6, -10 + 270 * k)
		inner(0.8 + 0.6 * k)
		pose(sess, lib, {})
	end)
	-- 2. the head turns toward the server (1.8 s)
	lib.Sound.Play("ChimeLow")
	run(1.8, function(k)
		cracks(m, lib, 0.9)
		pose(sess, lib, { yaw = YAW * heavy(k), pitch = math.rad(-4) * heavy(k) })
	end)
	-- 3. the sword is hauled up into the raised hero pose (3.4 s)
	lib.Sound.Play("Rumble")
	lib.Cine.shake(0.12, 3.2)
	run(3.4, function(k)
		pose(sess, lib, { yaw = YAW, pitch = math.rad(-4), raise = heavy(k) })
	end)
	-- 4. the ancient pulse from the core (1.4 s)
	lib.Sound.Play("Boom")
	lib.Sound.Play("ChimeLow")
	lib.Cine.bloom(0.35, 0.2, 1, 1.2)
	local c = cores[1]
	local cpos = if c then c.Position else (P * CFrame.new(0, 170 * scale, 0)).Position
	lib.Cine.ring(cpos, GOLD, 200, 1.6)
	lib.Cine.ring(P.Position + Vector3.new(0, 2, 0), AMBER, 220, 2)
	run(1.4, function(k)
		inner(2 - 0.6 * k)
		cracks(m, lib, 1.6 - 0.5 * k)
		pose(sess, lib, { yaw = YAW, pitch = math.rad(-4), raise = 1 })
	end)
	-- 5. the sword comes down: point strikes the pedestal (2.6 s) with a deep stone impact and dust
	run(2.6, function(k)
		local e = 1 - k ^ 2.4 -- accelerating fall: weight
		pose(sess, lib, { yaw = YAW * (1 - heavy(k)), pitch = math.rad(-4) * (1 - heavy(k)), raise = e })
		inner(1.4 - 0.4 * k)
		cracks(m, lib, 1.1 - 0.4 * k)
	end)
	lib.Sound.Play("Boom")
	lib.Sound.Play("Thud")
	lib.Cine.shake(0.7, 0.8)
	local tip = (P * CFrame.Angles(0, math.rad(-8), 0) * CFrame.new(124 * scale, 20 * scale, -62 * scale)).Position -- the template twists the upper body 8 degrees
	local a = lib.anchor(tip, ctx.trash)
	local e = lib.emitter(a, lib.SMOKE, DUST, 16, 3, 22, ctx.trash)
	e.SpreadAngle = Vector2.new(90, 25)
	e:Emit(60)
	lib.Cine.ring(tip, DUST, 160, 1.6)
	lib.Sound.Play("Cheer")
	task.wait(0.6)
	sess.paused = false
end

return Show
