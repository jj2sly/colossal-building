--!nonstrict
-- GIANT ROBOT show. Activation (~45%): the chest core powers on with a slow cyan pulse (the visor lights as soon as the head
-- exists). Milestone 1 (~72%): head life (slow looks left and right) and a small breathing motion in both arms.
-- Completion (Power Up): a power surge with flickering core and visor, the head scans across the server, the right arm comes
-- up into one big salute, a chest-core peak flash with a ring, then the arm returns. Poses are composed per frame from each
-- part's original CFrame: shoulder -> elbow chains for the arms, a neck pivot for the head.
local Show = {}

local CORE = Color3.fromRGB(40, 70, 84)
local CYAN = Color3.fromRGB(90, 230, 255)
local WHITE = Color3.fromRGB(225, 252, 255)

local function glow(p: BasePart, k: number)
	p.Color = CORE:Lerp(CYAN, math.clamp(k, 0, 1)):Lerp(WHITE, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.2 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

-- o = { yaw, pitch, r = { x, z, el }, l = { x, z, el } } (radians); arm z > 0 raises the arm outward on its own side
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
	for _, tag in { "R", "L" } do
		local a = o[string.lower(tag)] or {}
		local side = if tag == "R" then 1 else -1
		local sh, el = lib.find(m, "Shoulder" .. tag), lib.find(m, "Elbow" .. tag)
		local sb, eb = sh and sess:base(sh), el and sess:base(el)
		if sb then
			local h = CFrame.new(sb.Position) * R
			local SH = h * CFrame.Angles(a.x or 0, 0, side * (a.z or 0)) * h:Inverse()
			for _, p in lib.group(m, "UpperArm" .. tag) do
				local b = sess:base(p)
				if b then
					p.CFrame = SH * b
				end
			end
			local EL = CFrame.identity
			if eb then
				local e = SH * (CFrame.new(eb.Position) * R)
				EL = e * CFrame.Angles(0, 0, side * (a.el or 0)) * e:Inverse()
			end
			for _, p in lib.group(m, "Forearm" .. tag) do
				local b = sess:base(p)
				if b then
					p.CFrame = EL * SH * b
				end
			end
		end
	end
end

function Show.Activate(sess, lib)
	sess.life = 0
	lib.Sound.Play("PowerUp")
	local light
	sess:step(function(_, t)
		local core = lib.group(sess.model, "Core")
		for _, p in core do
			glow(p, 0.7 + 0.3 * math.sin(t * 2))
		end
		if not light and core[1] then
			light = lib.light(core[1], CYAN, 36, 1.4, sess.trash)
		end
		for _, p in lib.group(sess.model, "Eye") do
			glow(p, 0.9 + 0.1 * math.sin(t * 5))
		end
		if sess.life > 0 then
			local L = sess.life
			local look = math.sin(t * 0.35) * math.rad(16) * L
			local br = math.sin(t * 0.9) * L
			pose(sess, lib, {
				yaw = look,
				pitch = math.sin(t * 0.5) * math.rad(2) * L,
				r = { x = math.rad(2.5) * br, z = math.rad(1.5) * br, el = math.rad(3) * br },
				l = { x = -math.rad(2.5) * br, z = math.rad(1.5) * br, el = math.rad(3) * br },
			})
		end
	end)
end

function Show.Milestone(sess, lib, n)
	if n ~= 1 then
		return
	end
	lib.Sound.Play("Zap")
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < 2 do
		sess.life = (os.clock() - t0) / 2
		task.wait()
	end
	sess.life = 1
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local function run(seconds: number, fn)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and ctx.alive() do
			fn((os.clock() - t0) / seconds, os.clock() - t0)
			task.wait()
		end
		fn(1, seconds)
	end
	local function ease(k: number): number
		return k * k * (3 - 2 * k)
	end
	local cores, eyes = lib.group(m, "Core"), lib.group(m, "Eye")
	local function lit(kc: number, ke: number)
		for _, p in cores do
			glow(p, kc)
		end
		for _, p in eyes do
			glow(p, ke)
		end
	end
	local coreC = cores[1]
	local light = lib.light(lib.anchor(if coreC then coreC.Position else m:GetPivot().Position, ctx.trash), CYAN, 70, 0, ctx.trash)
	local SAL = { x = math.rad(-18), z = math.rad(84), el = math.rad(112) }
	-- 1. power surge (1.4 s): flicker, then full power
	lib.Sound.Play("PowerUp")
	lib.Sound.Play("Rumble")
	lib.Cine.shake(0.2, 1.4)
	run(1.4, function(k, t)
		local flick = if k < 0.6 then (if math.sin(t * 40) > 0 then 1.2 else 0.1) else 1.3
		lit(flick, flick)
		light.Brightness = 2.5 * k
		pose(sess, lib, {})
	end)
	-- 2. head scan across the server (2.6 s): left, right, centre
	lib.Sound.Play("Zap")
	run(2.6, function(k)
		local yaw
		if k < 0.35 then
			yaw = -math.rad(38) * ease(k / 0.35)
		elseif k < 0.85 then
			yaw = -math.rad(38) + math.rad(76) * ease((k - 0.35) / 0.5)
		else
			yaw = math.rad(38) * (1 - ease((k - 0.85) / 0.15))
		end
		pose(sess, lib, { yaw = yaw, pitch = math.rad(-4) * math.sin(k * math.pi) })
	end)
	-- 3. the salute (1.2 s up)
	run(1.2, function(k)
		local e = ease(k)
		pose(sess, lib, { yaw = math.rad(-6) * e, pitch = math.rad(-3) * e, r = { x = SAL.x * e, z = SAL.z * e, el = SAL.el * e } })
	end)
	lib.Sound.Play("Thud")
	lib.Cine.shake(0.3, 0.5)
	-- 4. hold + chest-core peak
	lib.Sound.Play("Boom")
	lib.Cine.bloom(0.45, 0.15, 0.8, 1.2)
	if coreC then
		lib.Cine.ring(coreC.Position, CYAN, 120, 1.4)
		local a = lib.anchor(coreC.Position, ctx.trash)
		local e = lib.emitter(a, lib.SPARK, CYAN, 3, 1.6, 45, ctx.trash)
		e.SpreadAngle = Vector2.new(70, 70)
		e.LightEmission = 1
		e:Emit(60)
	end
	run(1.6, function(k)
		lit(2 - 0.6 * k, 1.6 - 0.4 * k)
		light.Brightness = 7 * (1 - k) + 2
		pose(sess, lib, { yaw = math.rad(-6), pitch = math.rad(-3), r = { x = SAL.x, z = SAL.z, el = SAL.el } })
	end)
	-- 5. arm back down (1.3 s)
	run(1.3, function(k)
		local e = 1 - ease(k)
		pose(sess, lib, { yaw = math.rad(-6) * e, pitch = math.rad(-3) * e, r = { x = SAL.x * e, z = SAL.z * e, el = SAL.el * e } })
		lit(1.4 - 0.4 * k, 1.2 - 0.2 * k)
	end)
	lib.Sound.Play("Cheer")
	task.wait(0.5)
	sess.paused = false
end

return Show
