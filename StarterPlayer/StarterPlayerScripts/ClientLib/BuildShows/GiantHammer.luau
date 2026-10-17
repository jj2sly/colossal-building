--!nonstrict
-- GIANT HAMMER show. Activation (~65%): the hammer makes a small, heavy tilt on its pedestal pivot, slow and weighty.
-- Completion: it heaves back, then one huge slam down onto the impact slab (the handle swings 77 degrees about the pivot until
-- it is horizontal and the strike face lands flat), a shake, a dust burst and an impact pulse; it holds, then eases back up.
-- Rotation is about the Pivot marker around the model's local Z axis (positive lean = toward the slab = rotation by -angle).
local Show = {}

local LEAN = 22 -- authored lean from vertical (degrees); 90 - LEAN is the whole slam

local function pose(sess, lib, delta: number)
	local m = sess.model
	local P = m:GetPivot()
	local pv = lib.find(m, "Pivot")
	local pb = pv and sess:base(pv)
	if not pb then
		return
	end
	local zW = P:VectorToWorldSpace(Vector3.zAxis)
	local rot = CFrame.new(pb.Position) * CFrame.fromAxisAngle(zW, -math.rad(delta)) * CFrame.new(-pb.Position)
	for _, p in lib.group(m, "Hammer") do
		local b = sess:base(p)
		if b then
			p.CFrame = rot * b
		end
	end
end

function Show.Activate(sess, lib)
	sess:step(function(_, t)
		-- slow and heavy: a smoothed see-saw with a pause at each end
		local w = math.sin(t * 0.5)
		pose(sess, lib, 1.7 * w * math.abs(w) ^ 0.4)
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
	local FULL = 90 - LEAN
	lib.Sound.Play("Rumble")
	run(0.9, function(k) pose(sess, lib, -11 * ease(k)) end) -- heave back
	task.wait(0.15)
	run(0.7, function(k) pose(sess, lib, -11 + (FULL + 11) * k * k) end) -- the slam (about 0.7 s, accelerating into the slab)
	pose(sess, lib, FULL)
	-- the impact
	local ip = lib.find(m, "ImpactPoint")
	local pos = if ip then ip.Position else m:GetPivot().Position
	lib.Sound.Play("Boom")
	lib.Sound.Play("Thud")
	lib.Cine.shake(1.1, 0.9)
	lib.Cine.burst(pos, "Dust", 2)
	lib.Cine.ring(pos + Vector3.new(0, 1, 0), Color3.fromRGB(250, 170, 70), 130, 1.2)
	task.delay(0.2, function()
		lib.Cine.ring(pos + Vector3.new(0, 1, 0), Color3.fromRGB(255, 240, 200), 90, 1)
	end)
	local a = lib.anchor(pos + Vector3.new(0, 2, 0), ctx.trash)
	local e = lib.emitter(a, lib.SPARK, Color3.fromRGB(255, 210, 120), 3, 1.6, 40, ctx.trash)
	e.SpreadAngle = Vector2.new(75, 75)
	e.Acceleration = Vector3.new(0, -50, 0)
	e:Emit(60)
	-- a tiny rebound, then it settles and eases back to its pose
	run(0.25, function(k) pose(sess, lib, FULL - 3 * math.sin(k * math.pi)) end)
	task.wait(0.5)
	lib.Sound.Play("Cheer")
	run(1.3, function(k) pose(sess, lib, FULL * (1 - ease(k))) end)
	sess.paused = false
end

return Show
