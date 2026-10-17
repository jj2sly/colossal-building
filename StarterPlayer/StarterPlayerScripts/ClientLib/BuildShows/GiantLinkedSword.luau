--!nonstrict
-- GIANT LINKED SWORD show. Activation (~55%): a restrained hum: the whole sword (blade, guard, grip, pommel) rises and settles a stud
-- or two and a faint pale light breathes along the blade.
-- Completion: the sword rises about 8 studs, then one large clean slash pulse: a wide neon line sweeps through the blade plane
-- from upper-left to lower-right (fading as it goes) with a shake and a ring, and the sword settles back.
local Show = {}

local PALE = Color3.fromRGB(190, 224, 255)

-- lift (studs) and tilt (rad) of the whole sword about the SwordBase marker (rotation about the model's Z axis)
local function pose(sess, lib, lift: number, tilt: number)
	local m = sess.model
	local P = m:GetPivot()
	local up = P.UpVector
	local zW = P:VectorToWorldSpace(Vector3.zAxis)
	local sb = lib.find(m, "SwordBase")
	local bb = sb and sess:base(sb)
	local rot = if bb then CFrame.new(bb.Position) * CFrame.fromAxisAngle(zW, tilt) * CFrame.new(-bb.Position) else CFrame.new()
	for _, p in lib.group(m, "Sword") do
		local b = sess:base(p)
		if b then
			p.CFrame = CFrame.new(up * lift) * rot * b
		end
	end
end

function Show.Activate(sess, lib)
	local light
	sess:step(function(_, t)
		pose(sess, lib, 1.6 + 1.4 * math.sin(t * 0.8) + math.sin(t * 38) * 0.05, 0)
		if not light then
			local sc = lib.find(sess.model, "SlashC")
			if sc then
				light = lib.light(sc, PALE, 36, 0, sess.trash)
			end
		end
		if light then
			light.Brightness = 0.5 + 0.4 * math.sin(t * 1.6)
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
	local P = m:GetPivot()
	local function run(seconds: number, fn)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and ctx.alive() do
			fn((os.clock() - t0) / seconds)
			task.wait()
		end
		fn(1)
	end
	local sc = lib.find(m, "SlashC")
	local center = if sc then sc.Position else P.Position + Vector3.new(0, 66, 0)
	lib.Sound.Play("Chime")
	run(1.2, function(k) pose(sess, lib, 2 + 8 * ease(k), 0) end)
	task.wait(0.2)
	lib.Sound.Play("Zap")
	lib.Sound.Play("Boom")
	lib.Cine.shake(0.35, 0.5)
	local bar = Instance.new("Part")
	bar.Anchored, bar.CanCollide, bar.CanQuery, bar.CanTouch = true, false, false, false
	bar.Material = Enum.Material.Neon
	bar.Color = PALE
	bar.Size = Vector3.new(150, 5, 2)
	bar.Parent = workspace
	table.insert(ctx.trash, bar)
	local trail = {}
	for i = 1, 3 do
		local t = bar:Clone()
		t.Parent = workspace
		table.insert(ctx.trash, t)
		trail[i] = t
	end
	local s0 = os.clock()
	local SW = 0.75 -- slow enough to follow the sweep
	while os.clock() - s0 < SW and ctx.alive() do
		local k = (os.clock() - s0) / SW
		local ang = math.rad(62) * (1 - 2 * ease(k))
		local at = CFrame.new(center + Vector3.new(0, 6, 0)) * P.Rotation
		bar.CFrame = at * CFrame.Angles(0, 0, ang)
		bar.Transparency = k * 0.4
		for i, t in trail do
			t.CFrame = at * CFrame.Angles(0, 0, ang + math.rad(9 * i))
			t.Transparency = 0.35 + i * 0.15 + k * 0.3
		end
		pose(sess, lib, 10, math.rad(-7) * math.sin(k * math.pi))
		task.wait()
	end
	-- the slash lingers and fades out rather than vanishing
	for _, t in trail do
		lib.tween(t, 0.35, { Transparency = 1 })
	end
	lib.tween(bar, 0.45, { Transparency = 1, Size = Vector3.new(170, 1, 1) })
	lib.Cine.ring(P.Position + Vector3.new(0, 20, 0), PALE, 130, 1.2)
	lib.Cine.burst(P.Position + Vector3.new(0, 12, 0), "Dust", 1.4)
	task.wait(0.4)
	lib.Sound.Play("Cheer")
	run(1.2, function(k) pose(sess, lib, 10 * (1 - ease(k)), 0) end)
	sess.paused = false
end

return Show
