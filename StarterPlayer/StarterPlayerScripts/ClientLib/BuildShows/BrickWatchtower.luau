--!nonstrict
-- BRICK WATCHTOWER show. Activation (~76%): the flag (at half-mast) starts to wave about its pole.
-- Completion: the flag is raised to the top of the pole while it keeps waving, with a burst of sparks and a gold ring.
local Show = {}

local RAISE = 5 -- studs from half-mast to the top of the pole

-- the flag swings about the pole's vertical axis (yaw) and sits `lift` studs above half-mast
local function pose(sess, lib, yaw: number, lift: number)
	local m = sess.model
	local P = m:GetPivot()
	local pole = lib.find(m, "FlagPole")
	local pb = pole and sess:base(pole)
	if not pb then
		return
	end
	local axis = CFrame.new(pb.Position) * P.Rotation
	for _, p in lib.group(m, "Flag") do
		local b = sess:base(p)
		if b then
			p.CFrame = axis * CFrame.Angles(0, yaw, 0) * axis:Inverse() * (b + P.UpVector * lift)
		end
	end
end

function Show.Activate(sess, lib)
	sess:step(function(_, t)
		pose(sess, lib, math.sin(t * 2.4) * math.rad(14) + math.sin(t * 5.3) * math.rad(4), 0)
	end)
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local pole = lib.find(m, "FlagPole")
	lib.Sound.Play("Chime")
	local t0 = os.clock()
	local SPAN = 2.8
	while os.clock() - t0 < SPAN and ctx.alive() do
		local t = os.clock() - t0
		local k = math.clamp(t / SPAN, 0, 1)
		pose(sess, lib, math.sin(t * 3) * math.rad(14), RAISE * (k * k * (3 - 2 * k)))
		task.wait()
	end
	pose(sess, lib, 0, RAISE)
	if pole then
		local top = pole.Position + m:GetPivot().UpVector * (RAISE + 5)
		local a = lib.anchor(top, ctx.trash)
		local e = lib.emitter(a, lib.SPARK, Color3.fromRGB(255, 226, 120), 2.4, 2, 24, ctx.trash)
		e.SpreadAngle = Vector2.new(180, 180)
		e.Acceleration = Vector3.new(0, -14, 0)
		e:Emit(90)
	end
	lib.Sound.Play("Cheer")
	lib.Cine.shake(0.15, 0.3)
	lib.Cine.ring(m:GetPivot().Position + Vector3.new(0, 0.5, 0), Color3.fromRGB(250, 214, 90), 130, 1.5)
	task.wait(1.2)
	-- the flag stays raised for the rest of the celebration (the session is released but its pose is kept by the last frame)
	sess.paused = true
	task.wait(1)
end

return Show
