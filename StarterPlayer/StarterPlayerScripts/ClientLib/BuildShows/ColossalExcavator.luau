--!nonstrict
-- COLOSSAL EXCAVATOR show. Activation (~55%): a slow idle cycle: the boom bobs, the stick extends a little, the bucket curls.
-- Completion: one full digging cycle: the boom lowers and the stick reaches out, the bucket bites into the mound (the dirt
-- Load appears in the bucket), the boom raises, the machine slews toward the spawn, the bucket opens and dumps (dust, a thud)
-- and everything returns to rest.
-- Kinematics: world = Slew * Rot(Pivot, a) * Rot(Elbow, b) * Rot(Wrist, c) * base, rotations about the local Z axis; + a = up.
local Show = {}

local function pose(sess, lib, s)
	local m = sess.model
	local P = m:GetPivot()
	local zW = P:VectorToWorldSpace(Vector3.zAxis)
	local up = P.UpVector
	local function pos(name: string): Vector3?
		local mk = lib.find(m, name)
		local b = mk and sess:base(mk)
		return b and b.Position
	end
	local P0, E, W, SL = pos("Pivot"), pos("Elbow"), pos("Wrist"), pos("Slew")
	if not (P0 and E and W and SL) then
		return
	end
	local function rot(axis: Vector3, ang: number, c: Vector3): CFrame
		return CFrame.new(c) * CFrame.fromAxisAngle(axis, ang) * CFrame.new(-c)
	end
	local TS, TP, TE, TW = rot(up, s.psi, SL), rot(zW, s.a, P0), rot(zW, s.b, E), rot(zW, s.c, W)
	local chain = {
		Boom = TS * TP,
		Stick = TS * TP * TE,
		Bucket = TS * TP * TE * TW,
		Load = TS * TP * TE * TW,
	}
	for name, T in chain do
		for _, p in lib.group(m, name) do
			local b = sess:base(p)
			if b then
				p.CFrame = T * b
				if name == "Load" then
					p.Transparency = if s.load then 0 else 1
				end
			end
		end
	end
end

function Show.Activate(sess, lib)
	sess:step(function(_, t)
		pose(sess, lib, { a = math.rad(2.5) * math.sin(t * 0.45), b = math.rad(4) * math.sin(t * 0.6 + 1), c = math.rad(6) * math.sin(t * 0.75 + 2), psi = 0, load = false })
	end)
end

local function ease(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * ease(k)
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
	-- key poses {a (boom), b (stick), c (bucket curl), psi (slew), load}. Solved offline against the template geometry so the
	-- bucket reaches the dirt mound (tooth tips at x 72..78) and its lowest point never goes below y 3 (the deck is at 0).
	local REST = { a = 0, b = 0, c = 0, psi = 0 }
	local REACH = { a = 0, b = math.rad(20), c = math.rad(-15), psi = 0 } -- stick extended, bucket open above the mound
	local BITE = { a = 0, b = 0, c = math.rad(8), psi = 0 } -- the bucket drops into the mound
	local SCOOP = { a = math.rad(2), b = math.rad(-16), c = math.rad(30), psi = 0 } -- pulled in and curled, full of dirt
	local LIFT = { a = math.rad(10), b = math.rad(-8), c = math.rad(40), psi = 0 } -- raised with the load, curled tight
	local SWING = { a = math.rad(10), b = math.rad(-8), c = math.rad(40), psi = math.rad(30) } -- slewed toward the spawn
	local DUMP = { a = math.rad(10), b = math.rad(-8), c = math.rad(-30), psi = math.rad(30) } -- bucket opens
	local function blend(A, B, k, load)
		pose(sess, lib, { a = lerp(A.a, B.a, k), b = lerp(A.b, B.b, k), c = lerp(A.c, B.c, k), psi = lerp(A.psi, B.psi, k), load = load })
	end
	lib.Sound.Play("Rumble")
	run(1.1, function(k) blend(REST, REACH, k, false) end)
	run(0.8, function(k) blend(REACH, BITE, k, false) end)
	-- the bite: dirt thud and a dust puff at the bucket
	lib.Sound.Play("Thud")
	lib.Cine.shake(0.25, 0.4)
	local wr = lib.find(m, "Wrist")
	if wr then
		lib.Cine.burst(wr.Position - Vector3.new(0, 36, 0), "Dust", 1.2)
	end
	run(0.8, function(k) blend(BITE, SCOOP, k, k > 0.15) end)
	run(0.6, function(k) blend(SCOOP, LIFT, k, true) end)
	run(0.8, function(k) blend(LIFT, SWING, k, true) end)
	-- the dump
	lib.Sound.Play("Boom")
	run(0.6, function(k) blend(SWING, DUMP, k, k < 0.5) end)
	local wp = lib.find(m, "Wrist")
	if wp then
		lib.Cine.burst(wp.Position - Vector3.new(0, 30, 0), "Dust", 1.6)
	end
	lib.Cine.ring(P.Position + Vector3.new(0, 0.5, 0), Color3.fromRGB(240, 170, 60), 130, 1.4)
	lib.Sound.Play("Cheer")
	run(0.9, function(k) blend(DUMP, REST, k, false) end)
	sess.paused = false
end

return Show
