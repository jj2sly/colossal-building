--!nonstrict
-- GIANT DUCK show. Activation (~55%): the whole duck bobs gently on its pond and the wings twitch now and then.
-- Milestone 1 (~85%): the head starts to look around. Completion: head turn, three big wing flaps and a QUACK pulse with a
-- burst of feathers. Everything is composed per frame from each part's original CFrame (no drift).
local Show = {}

local GROUPS = { "Body", "WingL", "WingR", "Head" }

-- the duck's pose: bob (studs), roll (rad), head yaw / nod (rad), wing lift (rad, + = up)
local function pose(sess, lib, bob: number, roll: number, yaw: number, nod: number, wing: number)
	local m = sess.model
	local P = m:GetPivot()
	local base = CFrame.new(P.Position) * P.Rotation
	-- whole-body transform about the pivot (on the pond)
	local body = base * CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, roll) * base:Inverse()
	local hingeH = lib.find(m, "HeadPivot")
	local hb = hingeH and sess:base(hingeH)
	for _, name in GROUPS do
		for _, p in lib.group(m, name) do
			local b = sess:base(p)
			if b then
				local cf = b
				if name == "Head" and hb then
					local h = CFrame.new(hb.Position) * P.Rotation
					cf = h * CFrame.Angles(nod, yaw, 0) * h:Inverse() * cf
				elseif (name == "WingL" or name == "WingR") and wing ~= 0 then
					-- each wing hinges along its top inner edge (local X sign = side)
					local side = if name == "WingL" then -1 else 1
					local hingeLocal = Vector3.new(side * 38, 62, 14)
					local h = base * CFrame.new(hingeLocal)
					cf = h * CFrame.Angles(0, 0, side * wing) * h:Inverse() * cf
				end
				p.CFrame = body * cf
			end
		end
	end
end

function Show.Activate(sess, lib)
	sess.look = 0
	local nextTwitch = 3
	sess:step(function(_, t)
		local wing = 0
		local tt = t - nextTwitch
		if tt > 0 then
			wing = math.sin(math.clamp(tt / 0.6, 0, 1) * math.pi) * math.rad(9)
			if tt > 0.6 then
				nextTwitch = t + 3 + math.random() * 3
			end
		end
		local yaw, nod = 0, 0
		if sess.look > 0 then
			yaw = math.sin(t * 0.45) * math.rad(10) * sess.look
			nod = math.sin(t * 0.7 + 1) * math.rad(3) * sess.look
		end
		pose(sess, lib, math.sin(t * 0.9) * 0.9, math.sin(t * 0.6) * math.rad(0.7), yaw, nod, wing)
		sess.lastPose = { yaw, nod }
	end)
end

function Show.Milestone(sess, _lib, n)
	if n >= 1 then
		-- ease the head-look in over two seconds
		local t0 = os.clock()
		while sess.alive() and os.clock() - t0 < 2 do
			sess.look = (os.clock() - t0) / 2
			task.wait()
		end
		sess.look = 1
	end
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
	-- 1. the head turns toward the crowd (the spawn sits along the template's -Z after placement) and lifts
	run(1.1, function(k)
		local e = k * k * (3 - 2 * k)
		pose(sess, lib, 0, 0, math.rad(-28) * e, math.rad(-8) * e, 0)
	end)
	-- 2. three big wing flaps with a bounce
	run(1.8, function(k)
		local flap = math.abs(math.sin(k * math.pi * 3)) * math.rad(32)
		pose(sess, lib, math.abs(math.sin(k * math.pi * 3)) * 2.5, 0, math.rad(-28), math.rad(-8), flap)
	end)
	-- 3. QUACK: the beak pulse, a ring over the pond, a burst of feathers
	local beak = P * CFrame.new(0, 62, -88)
	lib.Sound.Play("Boom")
	lib.Sound.Play("Zap")
	lib.Cine.shake(0.35, 0.5)
	lib.Cine.ring(P.Position + Vector3.new(0, 1, 0), Color3.fromRGB(250, 214, 90), 150, 1.8)
	local a = lib.anchor(beak.Position, ctx.trash)
	local e = lib.emitter(a, lib.SPARK, Color3.fromRGB(255, 244, 214), 3, 3, 40, ctx.trash)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Acceleration = Vector3.new(0, -12, 0)
	e.Drag = 2
	e:Emit(140)
	local b2 = lib.anchor((P * CFrame.new(0, 66, 10)).Position, ctx.trash)
	local e2 = lib.emitter(b2, lib.SPARK, Color3.fromRGB(250, 214, 90), 4, 4, 30, ctx.trash)
	e2.SpreadAngle = Vector2.new(180, 180)
	e2.Acceleration = Vector3.new(0, -8, 0)
	e2.Drag = 1.5
	e2:Emit(90)
	run(0.9, function(k)
		pose(sess, lib, 0, 0, math.rad(-28) * (1 - k), math.rad(-8) * (1 - k) + math.sin(k * math.pi) * math.rad(10), 0)
	end)
	lib.Sound.Play("Cheer")
	task.wait(1.5)
	sess.paused = false -- back to its gentle bob for the rest of the celebration
end

return Show
