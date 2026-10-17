--!nonstrict
-- NOOB STATUE show. Activation (~76%, as the head goes up): the head slowly looks side to side and nods a little.
-- Completion: both arms go up in a victory pose, the right arm waves three times while the head turns, then the arms come back down.
-- Everything is composed per frame from each part's original CFrame (no drift), about the model's own axes.
local Show = {}

-- head yaw / nod (rad), arm raise (rad, + = outward and up) for the right and left arm
local function pose(sess, lib, yaw: number, nod: number, armR: number, armL: number)
	local m = sess.model
	local rotP = m:GetPivot().Rotation
	local function pivot(name: string): CFrame?
		local mk = lib.find(m, name)
		local b = mk and sess:base(mk)
		return if b then CFrame.new(b.Position) * rotP else nil
	end
	local hp, sr, sl = pivot("HeadPivot"), pivot("ShoulderR"), pivot("ShoulderL")
	if hp then
		for _, p in lib.group(m, "Head") do
			local b = sess:base(p)
			if b then
				p.CFrame = hp * CFrame.Angles(nod, yaw, 0) * hp:Inverse() * b
			end
		end
	end
	for _, a in { { "ArmR", sr, armR, 1 }, { "ArmL", sl, armL, -1 } } do
		if a[2] then
			for _, p in lib.group(m, a[1]) do
				local b = sess:base(p)
				if b then
					p.CFrame = a[2] * CFrame.Angles(0, 0, a[4] * a[3]) * a[2]:Inverse() * b
				end
			end
		end
	end
end

function Show.Activate(sess, lib)
	sess:step(function(_, t)
		pose(sess, lib, math.sin(t * 0.55) * math.rad(14), math.sin(t * 0.9 + 1) * math.rad(3), 0, 0)
	end)
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local function run(seconds: number, fn)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and ctx.alive() do
			fn((os.clock() - t0) / seconds)
			task.wait()
		end
		fn(1)
	end
	local UP = math.rad(150)
	lib.Sound.Play("Chime")
	-- 1. both arms go up
	run(0.8, function(k)
		local e = k * k * (3 - 2 * k)
		pose(sess, lib, 0, math.rad(-6) * e, UP * e, UP * e)
	end)
	-- 2. the right arm waves, the head follows it, the left arm stays up
	lib.Cine.shake(0.15, 0.3)
	run(2.6, function(k)
		local wave = math.sin(k * math.pi * 2 * 3) * math.rad(24)
		pose(sess, lib, math.sin(k * math.pi * 2) * math.rad(-16), math.rad(-6), UP + wave, UP)
	end)
	lib.Sound.Play("Cheer")
	lib.Cine.ring(ctx.model:GetPivot().Position + Vector3.new(0, 0.5, 0), Color3.fromRGB(250, 214, 90), 130, 1.5)
	-- 3. arms down
	run(0.9, function(k)
		local e = k * k * (3 - 2 * k)
		pose(sess, lib, 0, math.rad(-6) * (1 - e), UP * (1 - e), UP * (1 - e))
	end)
	task.wait(0.4)
	sess.paused = false
end

return Show
