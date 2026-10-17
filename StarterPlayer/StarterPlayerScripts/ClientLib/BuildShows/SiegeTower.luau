--!nonstrict
-- SIEGE TOWER show. Activation (~65%): the four wheels creak back and forth a hair and the raised drawbridge shifts on its hinge.
-- Completion: the whole tower rolls ~6 studs toward the spawn on its wheels, settles with a heavy bounce, and the drawbridge
-- drops 90 degrees (accelerating) onto the ground in front with a thud, dust and a shake.
-- Everything is composed from each part's original CFrame. State kept in the session (sess.shift / sess.bridge) so the idle
-- loop never snaps the tower back after the finale.
local Show = {}

local R = 16 -- wheel radius

local function cache(sess, lib)
	local c = sess.cache
	if not c or os.clock() - c.at > 0.5 then
		local list = {}
		for _, p in sess.model:GetDescendants() do
			if p:IsA("BasePart") then
				local par = p.Parent
				local kind = if par and par.Name == "Wheel" then "w" elseif par and par.Name == "Bridge" then "b" else nil
				table.insert(list, { p = p, kind = kind, model = par })
			end
		end
		c = { at = os.clock(), list = list }
		sess.cache = c
	end
	return c.list
end

-- shift: studs toward -Z; dy: vertical bounce; wheel: extra wheel angle; bridge: radians dropped (0 raised .. pi/2 down)
local function pose(sess, lib, shift: number, dy: number, wheel: number, bridge: number)
	local m = sess.model
	local P = m:GetPivot()
	local xW = P:VectorToWorldSpace(Vector3.xAxis)
	local fwd = P:VectorToWorldSpace(Vector3.new(0, 0, -1))
	local up = P.UpVector
	local hinge = lib.find(m, "BridgeHinge")
	local hb = hinge and sess:base(hinge)
	local move = CFrame.new(fwd * shift + up * dy)
	local wa = wheel - shift / R
	for _, it in cache(sess, lib) do
		local b = sess:base(it.p)
		if b then
			local cf = b
			if it.kind == "w" then
				local mk = it.model:FindFirstChild("WheelC")
				local mb = mk and sess:base(mk)
				if mb then
					local C = mb.Position
					cf = CFrame.new(C) * CFrame.fromAxisAngle(xW, wa) * CFrame.new(-C) * b
				end
			elseif it.kind == "b" and hb then
				local H = hb.Position
				cf = CFrame.new(H) * CFrame.fromAxisAngle(xW, -bridge) * CFrame.new(-H) * b
			end
			it.p.CFrame = move * cf
		end
	end
end

function Show.Activate(sess, lib)
	sess.shift, sess.bridge = 0, 0
	sess:step(function(_, t)
		local sway = math.sin(t * 0.7)
		pose(sess, lib, sess.shift + sway * 0.25, 0, math.sin(t * 0.7 + 1) * math.rad(1.2) * 0, sess.bridge + math.rad(1.4) * math.sin(t * 0.9))
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
	local function run(seconds: number, fn)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and ctx.alive() do
			fn((os.clock() - t0) / seconds)
			task.wait()
		end
		fn(1)
	end
	local SHIFT = 6
	lib.Sound.Play("Rumble")
	-- 1. the tower rolls toward the spawn on its wheels
	run(1.5, function(k) pose(sess, lib, SHIFT * ease(k), 0, 0, 0) end)
	-- 2. it settles: a heavy dip and a rebound
	lib.Cine.shake(0.2, 0.5)
	run(0.5, function(k) pose(sess, lib, SHIFT, -1.4 * math.sin(k * math.pi) * (1 - k * 0.5), 0, 0) end)
	task.wait(0.25)
	-- 3. the drawbridge drops (accelerates), slams down, bounces once
	lib.Sound.Play("Chime")
	run(1.0, function(k) pose(sess, lib, SHIFT, 0, 0, (math.pi / 2) * k * k) end) -- about 1 s: slow enough to read, still accelerating into the slam
	local hinge = lib.find(m, "BridgeHinge")
	local P = m:GetPivot()
	local land = (if hinge then hinge.Position else P.Position) + P:VectorToWorldSpace(Vector3.new(0, -38, -60 + 0))
	lib.Sound.Play("Thud")
	lib.Sound.Play("Boom")
	lib.Cine.shake(0.7, 0.7)
	lib.Cine.burst(P.Position + P:VectorToWorldSpace(Vector3.new(0, 1, -64 - SHIFT)), "Dust", 1.8)
	lib.Cine.ring(P.Position + Vector3.new(0, 0.5, 0), Color3.fromRGB(214, 190, 150), 120, 1.3)
	run(0.35, function(k) pose(sess, lib, SHIFT, 0, 0, (math.pi / 2) - math.rad(5) * math.sin(k * math.pi)) end)
	sess.shift, sess.bridge = SHIFT, math.pi / 2
	lib.Sound.Play("Cheer")
	task.wait(1.2)
	sess.paused = false
end

return Show
