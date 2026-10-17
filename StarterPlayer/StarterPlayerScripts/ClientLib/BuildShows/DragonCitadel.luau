--!nonstrict
-- DRAGON CITADEL show. Activation (~45%): the chest core and the gate glow like embers, the dragon breathes (a slow rise and
-- fall) and, once the head exists, its eyes burn and the head sways a little. Milestone 1 (~75%): the wings flex, the tail
-- sweeps and the neck looks around. Completion (Dragon Roar): the dragon rears up, gives two huge wing beats, lowers its head
-- toward the crowd and breathes one fire burst while the core and the fortress gate flare, then settles.
-- Every pose is composed per frame from each part's original CFrame (body -> neck -> head chain, wings and tail on the body).
local Show = {}

local EMBER = Color3.fromRGB(96, 40, 26)
local FIRE = Color3.fromRGB(255, 110, 30)
local HOT = Color3.fromRGB(255, 214, 120)

local function glow(p: BasePart, k: number)
	p.Color = EMBER:Lerp(FIRE, math.clamp(k, 0, 1)):Lerp(HOT, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.25 then Enum.Material.Neon else Enum.Material.Slate
end

-- o = { lift, pitch, neck, hp, hy, flap, tail } (studs / radians)
local function pose(sess, lib, o)
	local m = sess.model
	local P = m:GetPivot()
	local R = P.Rotation
	local function at(pos: Vector3, rx: number, ry: number, rz: number): CFrame
		local h = CFrame.new(pos) * R
		return h * CFrame.Angles(rx, ry, rz) * h:Inverse()
	end
	local D = CFrame.new(0, o.lift or 0, 0) * at((P * CFrame.new(0, 50, 10)).Position, o.pitch or 0, 0, 0)
	local function apply(name: string, X: CFrame)
		for _, p in lib.group(m, name) do
			local b = sess:base(p)
			if b then
				p.CFrame = X * b
			end
		end
	end
	apply("Body", D)
	local nb = lib.find(m, "NeckBase")
	local nbb = nb and sess:base(nb)
	local NX = D
	if nbb then
		NX = D * at(nbb.Position, o.neck or 0, 0, 0)
	end
	apply("Neck", NX)
	local hp = lib.find(m, "HeadPivot")
	local hpb = hp and sess:base(hp)
	if hpb then
		apply("Head", NX * at(hpb.Position, o.hp or 0, o.hy or 0, 0))
	end
	for _, tag in { "L", "R" } do
		local root = lib.find(m, "WingRoot" .. tag)
		local rb = root and sess:base(root)
		if rb then
			local side = if tag == "R" then 1 else -1
			apply("Wing" .. tag, D * at(rb.Position, 0, 0, side * (o.flap or 0)))
		end
	end
	local tb = lib.find(m, "TailBase")
	local tbb = tb and sess:base(tb)
	if tbb then
		apply("Tail", D * at(tbb.Position, 0, o.tail or 0, 0))
	end
end

local function embers(model, lib, k: number)
	for _, name in { "Core", "Eye", "Gate" } do
		for _, p in lib.group(model, name) do
			glow(p, k)
		end
	end
end

function Show.Activate(sess, lib)
	sess.life = 0
	lib.Sound.Play("Rumble")
	local light
	sess:step(function(_, t)
		embers(sess.model, lib, 0.7 + 0.25 * math.sin(t * 1.3))
		if not light then
			local c = lib.group(sess.model, "Core")[1]
			if c then
				light = lib.light(c, FIRE, 40, 1.2, sess.trash)
			end
		end
		local L = sess.life
		pose(sess, lib, {
			lift = 0.6 * math.sin(t * 1.1),
			pitch = math.rad(0.6) * math.sin(t * 1.1),
			neck = math.rad(2) * math.sin(t * 0.7) + math.rad(3) * L * math.sin(t * 0.33),
			hp = math.rad(2) * math.sin(t * 0.9),
			hy = math.rad(5) * math.sin(t * 0.4) + math.rad(12) * L * math.sin(t * 0.27),
			flap = math.rad(1) * math.sin(t * 1.1) + math.rad(5) * L * math.sin(t * 0.8),
			tail = math.rad(10) * L * math.sin(t * 0.5),
		})
	end)
end

function Show.Milestone(sess, lib, n)
	if n ~= 1 then
		return
	end
	lib.Sound.Play("Rumble")
	lib.Cine.shake(0.15, 1)
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < 2.5 do
		sess.life = (os.clock() - t0) / 2.5
		task.wait()
	end
	sess.life = 1
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
			fn((os.clock() - t0) / seconds, os.clock() - t0)
			task.wait()
		end
		fn(1, seconds)
	end
	local function ease(k: number): number
		return k * k * (3 - 2 * k)
	end
	local REAR = { lift = 5, pitch = math.rad(8), neck = math.rad(10), hp = math.rad(12), flap = math.rad(15) }
	-- 1. rear up (1.6 s)
	lib.Sound.Play("Rumble")
	lib.Cine.shake(0.2, 1.6)
	run(1.6, function(k)
		local e = ease(k)
		embers(m, lib, 0.8 + 0.6 * e)
		pose(sess, lib, { lift = REAR.lift * e, pitch = REAR.pitch * e, neck = REAR.neck * e, hp = REAR.hp * e, flap = REAR.flap * e })
	end)
	-- 2. two huge wing beats (2.8 s)
	local beats = 0
	run(2.8, function(k)
		local ph = k * 2
		local flap = REAR.flap + math.rad(28) * math.sin(ph * math.pi * 2) -- up first, then the down-stroke
		if math.floor(ph + 0.75) > beats and k < 1 then
			beats += 1
			lib.Sound.Play("Boom")
			lib.Cine.shake(0.35, 0.4)
			lib.Cine.ring(P.Position + Vector3.new(0, 1, 0), Color3.fromRGB(200, 180, 150), 200, 1.4)
		end
		pose(sess, lib, { lift = REAR.lift + 2 * math.sin(ph * math.pi * 2), pitch = REAR.pitch, neck = REAR.neck, hp = REAR.hp, flap = flap })
	end)
	-- 3. the head comes down toward the crowd and breathes fire (2.6 s)
	local fired = false
	run(2.6, function(k)
		local e = ease(math.clamp(k / 0.35, 0, 1))
		pose(sess, lib, {
			lift = REAR.lift * (1 - 0.4 * e),
			pitch = REAR.pitch * (1 - e),
			neck = REAR.neck * (1 - e) - math.rad(6) * e,
			hp = REAR.hp + (math.rad(-22) - REAR.hp) * e,
			flap = REAR.flap * (1 - 0.5 * e),
		})
		embers(m, lib, 1.4 + 0.6 * math.sin(k * math.pi))
		if k > 0.3 and not fired then
			fired = true
			lib.Sound.Play("Boom")
			lib.Sound.Play("Meteor")
			lib.Cine.bloom(0.4, 0.15, 1, 1)
			local mouth = lib.find(m, "Mouth")
			if mouth then
				local a = lib.anchor(mouth.Position, ctx.trash)
				a.CFrame = mouth.CFrame
				local f = lib.emitter(a, lib.SPARK, FIRE, 5, 1.3, 70, ctx.trash)
				f.EmissionDirection = Enum.NormalId.Front
				f.SpreadAngle = Vector2.new(12, 12)
				f.LightEmission = 1
				f.Color = ColorSequence.new(HOT, FIRE)
				f.Rate = 160
				local s = lib.emitter(a, lib.SMOKE, Color3.fromRGB(90, 70, 60), 10, 2.2, 40, ctx.trash)
				s.EmissionDirection = Enum.NormalId.Front
				s.SpreadAngle = Vector2.new(16, 16)
				s.Rate = 18
				lib.light(a, FIRE, 80, 6, ctx.trash)
				task.delay(1.4, function()
					f.Rate = 0
					s.Rate = 0
				end)
			end
		end
	end)
	-- 4. settle (1.6 s)
	lib.Sound.Play("Cheer")
	run(1.6, function(k)
		local e = 1 - ease(k)
		pose(sess, lib, { lift = REAR.lift * 0.6 * e, neck = math.rad(-6) * e, hp = math.rad(-22) * e, flap = REAR.flap * 0.5 * e })
		embers(m, lib, 0.9 + 0.8 * e)
	end)
	sess.paused = false
end

return Show
