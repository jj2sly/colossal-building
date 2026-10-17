--!nonstrict
-- STEAM LOCOMOTIVE show. Activation (~55%): steam begins to vent: a slow, soft plume from the stack, little puffs from the cylinders,
-- and the wheels and side rods turn slowly (about 0.4 rad/s, the engine standing still).
-- Completion: a big steam burst from the stack and both cylinders, the whistle (chimes) and the wheels and rods cycle once
-- (a full turn in ~3 s, eased), then they settle back to the slow idle turn.
local Show = {}

local STEAM = Color3.fromRGB(240, 244, 248)
local RC = 5 -- crank radius (the pin sits 5 studs ahead of each driver's centre at angle 0)

-- every wheel turns about its own centre (rolling toward +X = clockwise = negative rotation about +Z); the two side rods are
-- pure translations by the crank offset (a parallelogram linkage)
local function pose(sess, lib, theta: number)
	local m = sess.model
	local P = m:GetPivot()
	local zW = P:VectorToWorldSpace(Vector3.zAxis)
	local xW = P:VectorToWorldSpace(Vector3.xAxis)
	local up = P.UpVector
	for _, w in m:GetDescendants() do
		if w:IsA("Model") and w.Name == "Wheel" then
			local mk = w:FindFirstChild("WheelC")
			local mb = mk and sess:base(mk)
			if mb then
				local rot = CFrame.new(mb.Position) * CFrame.fromAxisAngle(zW, -theta) * CFrame.new(-mb.Position)
				for _, p in w:GetDescendants() do
					if p:IsA("BasePart") then
						local b = sess:base(p)
						if b then
							p.CFrame = rot * b
						end
					end
				end
			end
		end
	end
	local d = xW * (RC * (math.cos(theta) - 1)) + up * (RC * -math.sin(theta))
	for _, p in lib.group(m, "Rod") do
		local b = sess:base(p)
		if b then
			p.CFrame = b + d
		end
	end
end

local function puff(sess, lib, name: string, count: number, size: number, speed: number)
	local mk = lib.find(sess.model, name)
	if not mk then
		return
	end
	local a = lib.anchor(mk.Position, sess.trash)
	local e = lib.emitter(a, lib.SMOKE, STEAM, size, 2.4, speed, sess.trash)
	e.Acceleration = Vector3.new(0, 4, 0)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e:Emit(count)
	task.delay(4, function()
		a:Destroy()
	end)
end

function Show.Activate(sess, lib)
	sess.theta = 0
	sess.omega = 0.4
	local stack
	local nextPuff = 1.5
	sess:step(function(dt, t)
		sess.theta += sess.omega * dt
		pose(sess, lib, sess.theta)
		if not stack then
			local mk = lib.find(sess.model, "StackTop")
			if mk then
				local a = lib.anchor(mk.Position, sess.trash)
				stack = lib.emitter(a, lib.SMOKE, STEAM, 6, 3.6, 7, sess.trash)
				stack.Rate = 7
				stack.Acceleration = Vector3.new(2, 3, 0)
				stack.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
			end
		end
		if t > nextPuff then
			nextPuff = t + 1.1 + math.random() * 0.8
			puff(sess, lib, if math.random() < 0.5 then "CylL" else "CylR", 6, 3.4, 8)
		end
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
	lib.Sound.Play("Rumble")
	puff(sess, lib, "StackTop", 70, 11, 22)
	puff(sess, lib, "CylL", 28, 7, 20)
	puff(sess, lib, "CylR", 28, 7, 20)
	puff(sess, lib, "Whistle", 22, 5, 14)
	lib.Sound.Play("Chime")
	lib.Cine.shake(0.25, 0.8)
	lib.Cine.ring(m:GetPivot().Position + Vector3.new(0, 0.5, 0), Color3.fromRGB(230, 236, 244), 130, 1.4)
	task.delay(0.9, function()
		lib.Sound.Play("Chime")
	end)
	local th0 = sess.theta or 0
	local t0 = os.clock()
	local DUR = 3.2
	while os.clock() - t0 < DUR and ctx.alive() do
		local k = (os.clock() - t0) / DUR
		sess.theta = th0 + 2 * math.pi * ease(k)
		pose(sess, lib, sess.theta)
		task.wait()
	end
	sess.theta = th0 + 2 * math.pi
	puff(sess, lib, "StackTop", 30, 8, 14)
	lib.Sound.Play("Cheer")
	sess.paused = false
	local left = ctx.duration - DUR - 0.4
	if left > 0 then
		task.wait(left)
	end
end

return Show
