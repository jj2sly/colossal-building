--!nonstrict
-- ROCKET MONUMENT show. Activation (~65%): the launcher tube slowly elevates (about 9 degrees over 12 s) and then holds with a
-- tiny settle. Completion: it raises another ~26 degrees, a pause, then it fires one harmless sky rocket along the tube axis
-- (restrained muzzle puff, a thin smoke trail, a tiny sparkle burst high in the sky), the tube recoils a little and settles.
-- The Tube and Rocket groups rotate about the Pivot marker around the model's local Z axis; the rocket then flies along the
-- (rotated) tube axis, whose authored elevation is 34 degrees.
local Show = {}

local E0 = math.rad(34)

local function pose(sess, lib, delta: number, dist: number, hidden: boolean)
	local m = sess.model
	local P = m:GetPivot()
	local pv = lib.find(m, "Pivot")
	local pb = pv and sess:base(pv)
	if not pb then
		return
	end
	local zW = P:VectorToWorldSpace(Vector3.zAxis)
	local rot = CFrame.new(pb.Position) * CFrame.fromAxisAngle(zW, delta) * CFrame.new(-pb.Position)
	local dir = CFrame.fromAxisAngle(zW, delta):VectorToWorldSpace(P:VectorToWorldSpace(Vector3.new(math.cos(E0), math.sin(E0), 0)))
	for _, p in lib.group(m, "Tube") do
		local b = sess:base(p)
		if b then
			p.CFrame = rot * b
		end
	end
	for _, p in lib.group(m, "Rocket") do
		local b = sess:base(p)
		if b then
			p.CFrame = CFrame.new(dir * dist) * rot * b
			if not p:GetAttribute("Marker") then
				p.Transparency = if hidden then 1 else 0
			end
		end
	end
	return dir
end

function Show.Activate(sess, lib)
	sess.delta, sess.dist, sess.gone = 0, 0, false
	sess:step(function(_, t)
		local k = math.min(1, t / 9) -- a clear, slow, heavy raise: 22 degrees over 9 s
		sess.delta = math.rad(22) * (k * k * (3 - 2 * k)) + math.rad(0.3) * math.sin(t * 0.8) * k
		pose(sess, lib, sess.delta, sess.dist, sess.gone)
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
	local d0 = sess.delta or 0
	local TOP = math.rad(34)
	lib.Sound.Play("Rumble")
	run(1.4, function(k) pose(sess, lib, d0 + (TOP - d0) * ease(k), 0, false) end) -- elevate higher
	task.wait(0.3)
	-- fire: recoil, muzzle puff, the rocket accelerates away along the axis
	local rt = lib.find(m, "RocketTail")
	local mz = lib.find(m, "Muzzle")
	local muzzlePos = if mz then mz.Position else m:GetPivot().Position
	lib.Sound.Play("Boom")
	lib.Sound.Play("Zap")
	lib.Cine.shake(0.35, 0.6)
	local puff = lib.anchor(muzzlePos, ctx.trash)
	local pe = lib.emitter(puff, lib.SMOKE, Color3.fromRGB(210, 206, 200), 5, 2.4, 6, ctx.trash)
	pe.SpreadAngle = Vector2.new(40, 40)
	pe:Emit(18)
	local trail = lib.anchor(muzzlePos, ctx.trash)
	local te = lib.emitter(trail, lib.SMOKE, Color3.fromRGB(230, 226, 220), 2.6, 1.8, 2, ctx.trash)
	te.Rate = 40
	local flame = lib.anchor(muzzlePos, ctx.trash)
	flame.Shape = Enum.PartType.Ball
	flame.Material = Enum.Material.Neon
	flame.Color = Color3.fromRGB(255, 170, 70)
	flame.Size = Vector3.one * 5
	flame.Transparency = 0.1
	local FLY, DIST = 1.3, 230
	local t0 = os.clock()
	local lastDir
	while os.clock() - t0 < FLY and ctx.alive() do
		local t = os.clock() - t0
		local k = t / FLY
		local dist = DIST * k * k
		-- tiny recoil of the tube in the first 0.25 s
		local rc = math.rad(-1.4) * math.exp(-t * 9) * math.sin(math.min(t, 0.25) * 12)
		lastDir = pose(sess, lib, TOP + rc, dist, false)
		local tail = (if rt then rt.Position else muzzlePos)
		trail.Position = tail
		flame.Position = tail
		task.wait()
	end
	te.Rate = 0
	flame.Transparency = 1
	-- the rocket is gone: a small sparkle burst high in the sky where it ended
	sess.gone = true
	sess.dist = DIST
	pose(sess, lib, TOP, DIST, true)
	local sky = (lib.find(m, "Muzzle") and lib.find(m, "Muzzle").Position or muzzlePos) + (lastDir or Vector3.yAxis) * 6
	local sa = lib.anchor(sky, ctx.trash)
	local se = lib.emitter(sa, lib.SPARK, Color3.fromRGB(255, 226, 150), 2.4, 2, 14, ctx.trash)
	se.SpreadAngle = Vector2.new(180, 180)
	se.Acceleration = Vector3.new(0, -8, 0)
	se:Emit(70)
	lib.Sound.Play("Cheer")
	lib.Cine.ring(m:GetPivot().Position + Vector3.new(0, 0.5, 0), Color3.fromRGB(250, 210, 120), 120, 1.4)
	-- the tube settles back a little
	run(1.4, function(k)
		sess.delta = TOP - math.rad(14) * ease(k)
		pose(sess, lib, sess.delta, DIST, true)
	end)
	sess.paused = false
end

return Show
