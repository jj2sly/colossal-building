--!nonstrict
-- WINDMILL show. Activation (~65%): the giant rotor turns slowly (once its blades are up). Completion: the blades accelerate
-- briefly (to about 3 rad/s), hold, then slow back down to the idle turn, with a gust of dust at the base and a ring.
-- The rotor turns about the Hub marker around the model's local Z axis; the angle accumulates so idle resumes where it stopped.
local Show = {}

local IDLE = 0.35 -- rad/s

local function setRotor(sess, lib, ang: number)
	local m = sess.model
	local P = m:GetPivot()
	local hub = lib.find(m, "Hub")
	local hb = hub and sess:base(hub)
	if not hb then
		return
	end
	local zW = P:VectorToWorldSpace(Vector3.zAxis)
	local rot = CFrame.new(hb.Position) * CFrame.fromAxisAngle(zW, ang) * CFrame.new(-hb.Position)
	for _, p in lib.group(m, "Rotor") do
		local b = sess:base(p)
		if b then
			p.CFrame = rot * b
		end
	end
end

function Show.Activate(sess, lib)
	sess.ang = 0
	sess.omega = IDLE
	sess:step(function(dt)
		sess.ang += sess.omega * dt
		setRotor(sess, lib, sess.ang)
	end)
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local PEAK = 3
	local UP, HOLD, DOWN = 1.5, 1.0, 1.7
	lib.Sound.Play("Rumble")
	local t0 = os.clock()
	local last = t0
	local gust = false
	while os.clock() - t0 < UP + HOLD + DOWN and ctx.alive() do
		local now = os.clock()
		local t = now - t0
		local w
		if t < UP then
			local k = t / UP
			w = IDLE + (PEAK - IDLE) * k * k
		elseif t < UP + HOLD then
			w = PEAK
		else
			local k = (t - UP - HOLD) / DOWN
			w = PEAK + (IDLE - PEAK) * (k * k * (3 - 2 * k))
		end
		sess.omega = w
		sess.ang += w * (now - last)
		last = now
		setRotor(sess, lib, sess.ang)
		if not gust and t > UP then
			gust = true
			lib.Sound.Play("Chime")
			lib.Cine.shake(0.15, 1)
			lib.Cine.burst(m:GetPivot().Position + Vector3.new(0, 4, -18), "Dust", 1.3)
			lib.Cine.ring(m:GetPivot().Position + Vector3.new(0, 0.5, 0), Color3.fromRGB(240, 226, 190), 120, 1.4)
		end
		task.wait()
	end
	sess.omega = IDLE
	lib.Sound.Play("Cheer")
	sess.paused = false
	task.wait(0.4)
end

return Show
