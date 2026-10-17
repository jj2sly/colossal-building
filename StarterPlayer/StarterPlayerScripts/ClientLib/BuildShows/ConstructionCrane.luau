--!nonstrict
-- CONSTRUCTION CRANE show. Activation (~76%): the trolley creeps along the jib and the hook sways.
-- Completion: the trolley runs out over the beam, the hook drops, lifts the big I-beam, carries it in and sets it on the
-- piers with a thud. All motion is in the template's own frame (the model can be turned on the platform).
local Show = {}

-- trolley offset along the jib (studs), extra cable (studs, + = hook lower), beam lift (studs), beam carried (bool)
local function pose(sess, lib, dx: number, drop: number, lift: number, carry: boolean)
	local m = sess.model
	local P = m:GetPivot()
	local along = P:VectorToWorldSpace(Vector3.new(dx, 0, 0))
	local up = P.UpVector
	for _, p in lib.group(m, "Trolley") do
		local b = sess:base(p)
		if b then
			p.CFrame = b + along
		end
	end
	for _, p in lib.group(m, "Hook") do
		local b = sess:base(p)
		if b then
			if p.Name == "Cable" then
				local L0 = p:GetAttribute("L0") or p.Size.Y
				p:SetAttribute("L0", L0)
				p.Size = Vector3.new(p.Size.X, math.max(0.5, L0 + drop), p.Size.Z)
				p.CFrame = b + along - up * (drop / 2)
			else
				p.CFrame = b + along - up * drop
			end
		end
	end
	if carry then
		for _, p in lib.group(m, "LiftBeam") do
			local b = sess:base(p)
			if b then
				p.CFrame = b + along + up * lift
			end
		end
	end
end

function Show.Activate(sess, lib)
	sess:step(function(_, t)
		local dx = math.sin(t * 0.35) * 10 - 4
		pose(sess, lib, dx, math.sin(t * 0.8) * 1.2, 0, false)
		sess.dx = dx
	end)
end

local function ease(a: number, b: number, k: number): number
	k = math.clamp(k, 0, 1)
	k = k * k * (3 - 2 * k)
	return a + (b - a) * k
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local hookTip, beamTop = 23.1, 4.7 -- template heights: hook tip, top flange of the beam on the deck
	local DROP = hookTip - beamTop - 0.2
	local LIFT, CARRY, SET = 19.3, -18, 16.3
	local dx0 = sess.dx or 0
	local phases = {
		{ 0.8, function(k) pose(sess, lib, ease(dx0, 0, k), 0, 0, false) end },
		{ 1.0, function(k) pose(sess, lib, 0, ease(0, DROP, k), 0, false) end },
		{ 1.2, function(k) pose(sess, lib, 0, ease(DROP, DROP - LIFT, k), ease(0, LIFT, k), true) end },
		{ 1.0, function(k) pose(sess, lib, ease(0, CARRY, k), DROP - LIFT, LIFT, true) end },
		{ 0.6, function(k) pose(sess, lib, CARRY, ease(DROP - LIFT, DROP - SET, k), ease(LIFT, SET, k), true) end },
	}
	lib.Sound.Play("Chime")
	for i, ph in phases do
		local t0 = os.clock()
		while os.clock() - t0 < ph[1] and ctx.alive() do
			ph[2]((os.clock() - t0) / ph[1])
			task.wait()
		end
		ph[2](1)
		if i == 3 then
			lib.Sound.Play("Rumble")
		end
	end
	-- set down: a thud, a dust puff on the piers, a gold ground pulse
	local target = lib.find(m, "BeamTarget")
	local pos = if target then target.Position else m:GetPivot().Position
	lib.Sound.Play("Thud")
	lib.Cine.burst(pos, "Dust", 1.4)
	lib.Cine.shake(0.25, 0.4)
	lib.Cine.ring(m:GetPivot().Position + Vector3.new(0, 0.5, 0), Color3.fromRGB(230, 176, 60), 100, 1.4)
	lib.Sound.Play("Cheer")
	task.wait(1.2)
end

return Show
