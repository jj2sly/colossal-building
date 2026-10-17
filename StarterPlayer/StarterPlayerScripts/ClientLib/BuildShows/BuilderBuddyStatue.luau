--!nonstrict
-- BUILDER BUDDY STATUE show. Activation (~75%): a confident idle: the hammer arm gives a small "tap tap" every few seconds and the head
-- nods along. Completion (~4.5 s): the right arm swings the giant hammer up overhead while the left arm comes forward in a
-- thumbs-up; the hard hat flashes gold with a bright construction chime and a ring; both hold a beat, then settle back down.
-- Everything is composed per frame from each part's original CFrame (no drift), about the model's own axes.
local Show = {}

local ORANGE = Color3.fromRGB(238, 128, 36)
local GOLD = Color3.fromRGB(255, 226, 120)

-- head nod / yaw (rad); right arm swing (rad, + = outward and up), left arm raise (rad, forward about X)
local function pose(sess, lib, nod: number, yaw: number, armR: number, armL: number)
	local m = sess.model
	local R = m:GetPivot().Rotation
	local function pivot(name: string): CFrame?
		local mk = lib.find(m, name)
		local b = mk and sess:base(mk)
		return if b then CFrame.new(b.Position) * R else nil
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
	if sr then
		for _, p in lib.group(m, "ArmR") do
			local b = sess:base(p)
			if b then
				p.CFrame = sr * CFrame.Angles(0, 0, armR) * sr:Inverse() * b
			end
		end
	end
	if sl then
		for _, p in lib.group(m, "ArmL") do
			local b = sess:base(p)
			if b then
				p.CFrame = sl * CFrame.Angles(armL, 0, 0) * sl:Inverse() * b
			end
		end
	end
end

local function hat(sess, lib, k: number)
	for _, p in lib.group(sess.model, "Hat") do
		if not p:GetAttribute("MBHatCol") then
			p:SetAttribute("MBHatCol", p.Color)
		end
		p.Color = p:GetAttribute("MBHatCol"):Lerp(GOLD, math.clamp(k, 0, 1) * 0.75) -- a bright gleam, not a white-out (the hat keeps its shape)
	end
end

function Show.Activate(sess, lib)
	sess:step(function(_, t)
		-- a "tap tap" every ~4 s: two quick swings of the hammer arm
		local c = t % 4
		local tap = 0
		if c > 3 then
			tap = math.abs(math.sin((c - 3) * math.pi * 2)) * math.rad(9)
		end
		pose(sess, lib, math.sin(t * 0.9) * math.rad(2.5) + tap * 0.3, math.sin(t * 0.4) * math.rad(8), tap, 0)
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
	local function ease(k: number): number
		return k * k * (3 - 2 * k)
	end
	local SWING, THUMB = math.rad(115), math.rad(88)
	-- 1. hammer up, thumbs-up (0.9 s)
	lib.Sound.Play("Thud")
	run(0.9, function(k)
		local e = ease(k)
		pose(sess, lib, math.rad(-7) * e, math.rad(-10) * e, SWING * e, THUMB * e)
	end)
	-- 2. the pose and the hard-hat flash with a chime (1.9 s)
	lib.Sound.Play("Chime")
	lib.Sound.Play("Cheer")
	lib.Cine.shake(0.15, 0.3)
	local model = ctx.model
	lib.Cine.ring(model:GetPivot().Position + Vector3.new(0, 0.5, 0), ORANGE, 120, 1.4)
	local hp = lib.find(model, "HeadPivot")
	if hp then
		local a = lib.anchor(hp.Position + Vector3.new(0, 24, 0), ctx.trash)
		local e = lib.emitter(a, lib.SPARK, GOLD, 1.6, 1.6, 22, ctx.trash)
		e.SpreadAngle = Vector2.new(180, 180)
		e.LightEmission = 1
		e:Emit(36)
		lib.light(a, GOLD, 40, 3, ctx.trash)
	end
	run(1.9, function(k)
		hat(sess, lib, 0.5 + 0.5 * math.sin(k * math.pi * 4) ^ 2)
		pose(sess, lib, math.rad(-7), math.rad(-10), SWING + math.rad(5) * math.sin(k * math.pi * 3), THUMB)
	end)
	hat(sess, lib, 0)
	-- 3. settle (1.0 s)
	run(1.0, function(k)
		local e = 1 - ease(k)
		pose(sess, lib, math.rad(-7) * e, math.rad(-10) * e, SWING * e, THUMB * e)
	end)
	sess.paused = false
end

return Show
