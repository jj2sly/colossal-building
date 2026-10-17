--!nonstrict
-- GIANT TOILET show. Activation (~55%): the water swirls slowly and the big lid rocks a few degrees.
-- Completion: the lid lifts higher, the handle is pushed, a strong stylized flush vortex spins up (the swirl whirls fast, the
-- water drains, a ring of foam particles orbits the bowl), a short water pulse shoots up from the bowl, the water refills and
-- the lid settles. Funny and colossal, nothing gross.
local Show = {}

local FOAM = Color3.fromRGB(206, 238, 255)
local WATERC = Color3.fromRGB(120, 200, 255)
local THETA0 = math.rad(62)

-- lid angle (rad, extra on top of the authored 62 deg), swirl angle, water drop (studs), handle angle
local function pose(sess, lib, lid: number, swirl: number, drop: number, handle: number)
	local m = sess.model
	local P = m:GetPivot()
	local xW = P:VectorToWorldSpace(Vector3.xAxis)
	local up = P.UpVector
	local lh = lib.find(m, "LidHinge")
	local lb = lh and sess:base(lh)
	if lb then
		local H = lb.Position
		local rot = CFrame.new(H) * CFrame.fromAxisAngle(xW, lid) * CFrame.new(-H)
		for _, p in lib.group(m, "Lid") do
			local b = sess:base(p)
			if b then
				p.CFrame = rot * b
			end
		end
	end
	for _, p in lib.group(m, "Water") do
		local b = sess:base(p)
		if b then
			p.CFrame = b - up * drop
		end
	end
	local sc = lib.find(m, "SwirlC")
	local sb = sc and sess:base(sc)
	if sb then
		local C = sb.Position - up * drop
		local rot = CFrame.new(C) * CFrame.fromAxisAngle(up, swirl) * CFrame.new(-C)
		for _, p in lib.group(m, "Swirl") do
			local b = sess:base(p)
			if b then
				p.CFrame = rot * (b - up * drop)
			end
		end
	end
	local hp = lib.find(m, "HandleP")
	local hb = hp and sess:base(hp)
	if hb then
		local zW = P:VectorToWorldSpace(Vector3.zAxis)
		local rot = CFrame.new(hb.Position) * CFrame.fromAxisAngle(zW, handle) * CFrame.new(-hb.Position)
		for _, p in lib.group(m, "Handle") do
			local b = sess:base(p)
			if b then
				p.CFrame = rot * b
			end
		end
	end
end

function Show.Activate(sess, lib)
	sess.lid, sess.swirlA = 0, 0
	sess:step(function(dt, t)
		sess.swirlA += dt * 0.7
		pose(sess, lib, sess.lid + math.rad(2.2) * math.sin(t * 0.9), sess.swirlA, 0, 0)
	end)
end

local function ease(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local P = m:GetPivot()
	local function run(seconds: number, fn)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and ctx.alive() do
			fn((os.clock() - t0) / seconds)
			task.wait()
		end
		fn(1)
	end
	local sc = lib.find(m, "SwirlC")
	local center = if sc then sc.Position else P.Position + Vector3.new(0, 31, -6)
	local LIFT = math.rad(34)
	local a = sess.swirlA or 0
	lib.Sound.Play("Chime")
	-- 1. the lid lifts higher
	run(0.8, function(k) pose(sess, lib, (sess.lid or 0) + LIFT * ease(k), a, 0, 0) end)
	-- 2. the handle is pushed
	lib.Sound.Play("Thud")
	run(0.35, function(k) pose(sess, lib, LIFT, a, 0, -math.rad(28) * math.sin(k * math.pi)) end)
	-- 3. the vortex: the swirl spins up, the water drains, foam orbits the bowl
	lib.Sound.Play("Rumble")
	lib.Cine.shake(0.15, 1.6)
	local orb = lib.anchor(center + Vector3.new(24, 2, 0), ctx.trash)
	local oe = lib.emitter(orb, lib.SPARK, FOAM, 2.2, 1.1, 2, ctx.trash)
	oe.Rate = 70
	oe.LightEmission = 0.3
	local t0 = os.clock()
	local VT = 1.8
	local w = 0.7
	local last = os.clock()
	while os.clock() - t0 < VT and ctx.alive() do
		local now = os.clock()
		local k = (now - t0) / VT
		w = 0.7 + 12 * ease(math.min(1, k * 1.4))
		a += w * (now - last)
		last = now
		local drop = 9 * ease(math.min(1, k * 1.2))
		pose(sess, lib, LIFT, a, drop, 0)
		local r = 26 * (1 - 0.55 * k)
		orb.Position = center - Vector3.new(0, drop, 0) + Vector3.new(math.cos(a * 1.3) * r, 3 + k * 3, math.sin(a * 1.3) * r * 1.2)
		task.wait()
	end
	oe.Rate = 0
	-- 4. a short water pulse up out of the bowl
	lib.Sound.Play("Zap")
	lib.Sound.Play("Boom")
	local pa = lib.anchor(center - Vector3.new(0, 9, 0), ctx.trash)
	local pe = lib.emitter(pa, lib.SPARK, WATERC, 3, 1.6, 36, ctx.trash)
	pe.SpreadAngle = Vector2.new(14, 14)
	pe.Acceleration = Vector3.new(0, -34, 0)
	pe.LightEmission = 0.3
	pe:Emit(90)
	lib.Cine.shake(0.3, 0.4)
	lib.Cine.ring(center - Vector3.new(0, 20, 0), WATERC, 110, 1.2)
	-- 5. the water refills, the swirl calms, the lid settles a little
	run(1.1, function(k)
		a += 3 * (1 - k) * 0.016
		pose(sess, lib, LIFT - math.rad(6) * ease(k), a, 9 * (1 - ease(k)), 0)
	end)
	sess.lid = LIFT - math.rad(6)
	sess.swirlA = a
	lib.Sound.Play("Cheer")
	task.wait(0.4)
	sess.paused = false
end

return Show
