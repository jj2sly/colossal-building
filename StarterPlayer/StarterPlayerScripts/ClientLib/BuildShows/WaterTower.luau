--!nonstrict
-- WATER TOWER show. Activation (~76%): the big outlet pipe hums (a tiny vibration) and a steady trickle drips from the spout.
-- Completion: the valve wheel spins, the pressure is released as a strong spray out of the spout toward the spawn and a
-- puff of vapour rises from the cap vent.
local Show = {}

local WATER = Color3.fromRGB(150, 205, 255)

local function spoutEmitter(sess, lib, spout: BasePart)
	local a = lib.anchor(spout.Position, sess.trash)
	a.CFrame = CFrame.lookAt(spout.Position, spout.Position + spout.CFrame.LookVector)
	local e = lib.emitter(a, lib.SPARK, WATER, 1.3, 1.4, 12, sess.trash)
	e.EmissionDirection = Enum.NormalId.Front
	e.SpreadAngle = Vector2.new(4, 4)
	e.Acceleration = Vector3.new(0, -44, 0)
	e.LightEmission = 0.4
	return e
end

local function shake(sess, lib, t: number, amp: number)
	for _, p in lib.group(sess.model, "Pipe") do
		local b = sess:base(p)
		if b then
			p.CFrame = b + Vector3.new(math.sin(t * 47) * amp, math.sin(t * 39 + 1) * amp * 0.6, 0)
		end
	end
end

function Show.Activate(sess, lib)
	local e
	sess:step(function(_, t)
		shake(sess, lib, t, 0.1)
	end)
	while sess.alive() do
		local sp = lib.find(sess.model, "Spout")
		if sp and not e then
			e = spoutEmitter(sess, lib, sp)
			e.Rate = 14
		end
		task.wait(1)
	end
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local sp = lib.find(m, "Spout")
	local vent = lib.find(m, "VentTop")
	local ctr = lib.find(m, "ValveCenter")
	local cb = ctr and sess:base(ctr)
	lib.Sound.Play("Rumble")
	-- 1. the valve wheel spins two turns
	local t0 = os.clock()
	while os.clock() - t0 < 1.3 and ctx.alive() do
		local k = math.clamp((os.clock() - t0) / 1.3, 0, 1)
		k = k * k * (3 - 2 * k)
		if cb then
			local rot = CFrame.new(cb.Position) * CFrame.Angles(0, math.rad(720) * k, 0) * CFrame.new(-cb.Position)
			for _, p in lib.group(m, "Valve") do
				local b = sess:base(p)
				if b then
					p.CFrame = rot * b
				end
			end
		end
		shake(sess, lib, os.clock(), 0.25 * k)
		task.wait()
	end
	-- 2. pressure release: a strong spray from the spout and vapour from the vent
	lib.Sound.Play("Zap")
	lib.Cine.shake(0.3, 0.6)
	if sp then
		local e = spoutEmitter(sess, lib, sp)
		e.Speed = NumberRange.new(40, 62)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.4), NumberSequenceKeypoint.new(1, 5) })
		e.Lifetime = NumberRange.new(1.4, 2)
		e.SpreadAngle = Vector2.new(9, 9)
		e.Rate = 150
		task.delay(2.2, function()
			e.Rate = 0
		end)
	end
	if vent then
		local a = lib.anchor(vent.Position, ctx.trash)
		local v = lib.emitter(a, lib.SMOKE, Color3.fromRGB(240, 246, 252), 7, 3, 12, ctx.trash)
		v.SpreadAngle = Vector2.new(25, 25)
		v:Emit(36)
	end
	lib.Cine.ring(m:GetPivot().Position + Vector3.new(0, 0.5, 0), WATER, 120, 1.5)
	local t1 = os.clock()
	while os.clock() - t1 < 2.4 and ctx.alive() do
		shake(sess, lib, os.clock(), 0.3 * (1 - (os.clock() - t1) / 2.4))
		task.wait()
	end
	lib.Sound.Play("Cheer")
	task.wait(0.4)
	sess.paused = false
end

return Show
