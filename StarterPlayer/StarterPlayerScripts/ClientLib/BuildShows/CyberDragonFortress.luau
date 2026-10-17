--!nonstrict
-- CYBER DRAGON FORTRESS show. Mechanical, deliberate motion: servo-like eases, no organic flapping. Poses are composed per frame
-- from each part's original CFrame (body -> neck -> head -> jaw chain; wings and tail ride the body).
-- Activation (~35%): the reactor core breathes (slow violet pulse) and the hull rises and falls a fraction; bastion slits glow.
-- Milestone 1 (~60%, the head exists): the neck lifts a little and scans slowly; the eye slit lights.
-- Milestone 2 (~82%, wings and tail exist): the wings make slow servo adjustments, the tail drifts, energy travels along the spine
-- plates (once built).
-- Completion (Core Ignition, ~15.6 s): the core surges; the neck raises and the head locks level; the wings flex open; energy runs
-- down the spine; the tail sweeps; one controlled violet beam from the jaw; the fortress slits answer with a pulse; the dragon
-- settles into a powered idle (brighter glows, higher neck).
local Show = {}

local GLOW0 = Color3.fromRGB(58, 30, 82)
local VIOLET = Color3.fromRGB(176, 96, 255)
local WHITE = Color3.fromRGB(236, 220, 255)

local function glow(p: BasePart, k: number)
	p.Color = GLOW0:Lerp(VIOLET, math.clamp(k, 0, 1)):Lerp(WHITE, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.2 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

local function ease(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

-- o = { lift, neck, hp, jaw, wing, sweep, tail } (studs / radians)
local function pose(sess, lib, o)
	local m = sess.model
	local P = m:GetPivot()
	local R = P.Rotation
	local function at(pos: Vector3, rx: number, ry: number, rz: number): CFrame
		local h = CFrame.new(pos) * R
		return h * CFrame.Angles(rx, ry, rz) * h:Inverse()
	end
	local function apply(name: string, X: CFrame)
		for _, p in lib.group(m, name) do
			local b = sess:base(p)
			if b then
				p.CFrame = X * b
			end
		end
	end
	local D = CFrame.new(P.UpVector * (o.lift or 0))
	apply("Body", D)
	local nb = lib.find(m, "NeckBase")
	local nbb = nb and sess:base(nb)
	local NX = D
	if nbb then
		NX = D * at(nbb.Position, 0, 0, o.neck or 0)
	end
	apply("Neck", NX)
	local hp = lib.find(m, "HeadPivot")
	local hpb = hp and sess:base(hp)
	local HX = NX
	if hpb then
		HX = NX * at(hpb.Position, 0, o.hy or 0, o.hp or 0)
	end
	apply("Head", HX)
	local jp = lib.find(m, "JawPivot")
	local jpb = jp and sess:base(jp)
	if jpb then
		apply("Jaw", HX * at(jpb.Position, 0, 0, -(o.jaw or 0)))
	end
	for _, tag in { "Near", "Far" } do
		local root = lib.find(m, "WingRoot" .. tag)
		local rb = root and sess:base(root)
		if rb then
			local side = if tag == "Near" then -1 else 1 -- positive wing = open outward
			apply("Wing" .. tag, D * at(rb.Position, side * (o.wing or 0), side * (o.sweep or 0), 0))
		end
	end
	local tr = lib.find(m, "TailRoot")
	local trb = tr and sess:base(tr)
	if trb then
		apply("Tail", D * at(trb.Position, 0, o.tail or 0, 0))
	end
end

-- energy pulse along the spine plates (Order 1 = rear): head position h in 0..5
local function spine(m, lib, h: number, gain: number, floor: number)
	for _, p in lib.group(m, "Spine") do
		local d = math.abs((p:GetAttribute("Order") or 0) - h)
		glow(p, floor + gain * math.exp(-d * d))
	end
end

function Show.Activate(sess, lib)
	sess.head, sess.wings = 0, 0
	sess.powered = sess.powered or 0
	lib.Sound.Play("PowerUp")
	sess:step(function(_, t)
		local m = sess.model
		local pw = sess.powered
		local breath = 0.5 + 0.5 * math.sin(t * 1.2)
		for _, p in lib.group(m, "Core") do
			glow(p, 0.45 + 0.35 * breath + 0.3 * pw)
		end
		for i, p in lib.group(m, "FortGlow") do
			glow(p, 0.3 + 0.25 * math.sin(t * 1.2 - i * 0.4) + 0.3 * pw)
		end
		for _, p in lib.group(m, "Eye") do
			glow(p, sess.head * (0.75 + 0.2 * math.sin(t * 2.3)) + 0.3 * pw)
		end
		if sess.wings > 0 then
			spine(m, lib, (t * 1.1) % 6 - 0.5, 0.9 * sess.wings, 0.15 + 0.35 * pw)
		end
		local H, W = sess.head, sess.wings
		-- servo steps: smoothstepped holds instead of a sine (reads mechanical, not organic)
		local function servo(rate: number, ph: number): number
			local x = (t * rate + ph) % 2
			return if x < 1 then ease(x) * 2 - 1 else 1 - ease(x - 1) * 2
		end
		sess.pose = {
			lift = 0.5 * math.sin(t * 1.2),
			neck = math.rad(4) * H + math.rad(3) * H * servo(0.12, 0) + math.rad(6) * pw,
			hy = math.rad(8) * H * servo(0.09, 0.5),
			hp = math.rad(-2) * H * servo(0.15, 1) + math.rad(5) * pw,
			jaw = math.rad(1.5) * (1 + math.sin(t * 1.2)) * H,
			wing = math.rad(4) * W * servo(0.1, 0.3) + math.rad(5) * pw,
			sweep = math.rad(3) * W * servo(0.07, 1.2),
			tail = math.rad(9) * W * servo(0.08, 0.8),
		}
		pose(sess, lib, sess.pose)
	end)
end

function Show.Milestone(sess, lib, n)
	local key = if n == 1 then "head" else "wings"
	lib.Sound.Play(if n == 1 then "Rumble" else "Zap")
	lib.Cine.shake(0.12, 1)
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < 3 do
		sess[key] = (os.clock() - t0) / 3
		task.wait()
	end
	sess[key] = 1
end

function Show.Spectacle(ctx, sess, lib)
	if not sess or not sess.head then
		return
	end
	local m = ctx.model
	local P = m:GetPivot()
	local last = os.clock()
	local function run(seconds: number, fn)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and ctx.alive() do
			local now = os.clock()
			fn((now - t0) / seconds, now - t0, math.min(now - last, 0.05))
			last = now
			task.wait()
		end
		fn(1, seconds, 0)
	end
	local cores, forts, eyes = lib.group(m, "Core"), lib.group(m, "FortGlow"), lib.group(m, "Eye")
	-- start from the live idle pose (no pop) and ease every joint to the neutral pose during the core surge
	local from = table.clone(sess.pose or {})
	local NEUTRAL = { lift = 0, neck = math.rad(4), hp = 0, hy = 0, jaw = 0, wing = 0, sweep = 0, tail = 0 }
	local st = table.clone(NEUTRAL)
	local function apply()
		pose(sess, lib, st)
	end
	local core = cores[1]
	local coreLight = core and lib.light(core, VIOLET, 60, 0, ctx.trash)
	-- 1. the core surges (2 s)
	lib.Sound.Play("PowerUp")
	lib.Sound.Play("Rumble")
	run(2, function(k)
		for _, p in cores do
			glow(p, 0.8 + 1.1 * k)
		end
		if coreLight then
			coreLight.Brightness = 5 * k
		end
		local e = ease(k)
		for key, v in NEUTRAL do
			st[key] = (from[key] or v) + (v - (from[key] or v)) * e
		end
		st.lift += 1.5 * e
		apply()
	end)
	lib.Cine.shake(0.2, 0.5)
	if core then
		lib.Cine.ring(core.Position, VIOLET, 70, 0.9)
	end
	-- 2. the neck raises and the head locks level (2.2 s)
	lib.Sound.Play("Thud")
	run(2.2, function(k)
		local e = ease(k)
		st.neck = math.rad(4) + math.rad(10) * e
		st.hp = math.rad(9) * e
		st.hy = 0
		for _, p in eyes do
			glow(p, 0.8 + 0.9 * e)
		end
		apply()
	end)
	lib.Sound.Play("Thud")
	-- 3. the wings flex open in two servo stages (2.4 s)
	run(2.4, function(k)
		local a = ease(k / 0.5)
		local b = ease((k - 0.55) / 0.45)
		st.wing = math.rad(9) * a + math.rad(6) * b
		st.sweep = math.rad(-5) * a + math.rad(8) * b
		apply()
	end)
	lib.Cine.shake(0.25, 0.5)
	lib.Sound.Play("Boom")
	-- 4. energy runs down the spine, rear to front, twice (1.8 s)
	lib.Sound.Play("Zap")
	run(1.8, function(k)
		spine(m, lib, -0.5 + (k * 2 % 1) * 5.5, 1.5, 0.4)
		apply()
	end)
	-- 5. the tail sweeps out and back (1.8 s)
	run(1.8, function(k)
		st.tail = math.rad(-22) * math.sin(math.pi * ease(k))
		apply()
	end)
	-- 6. one controlled beam from the jaw (3 s)
	local mouth = lib.find(m, "Mouth")
	if mouth then
		lib.Sound.Play("Boom")
		lib.Sound.Play("Meteor")
		lib.Cine.bloom(0.4, 0.15, 1.6, 1)
		local beam = Instance.new("Part")
		beam.Name = "MB_DragonBeam"
		beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch, beam.CastShadow = true, false, false, false, false
		beam.Shape = Enum.PartType.Cylinder
		beam.Material = Enum.Material.Neon
		beam.Color = VIOLET
		beam.Transparency = 1
		beam.Parent = workspace
		table.insert(ctx.trash, beam)
		local glowA = lib.anchor(mouth.Position, ctx.trash)
		local ml = lib.light(glowA, VIOLET, 90, 0, ctx.trash)
		local sp = lib.emitter(glowA, lib.SPARK, VIOLET, 3, 0.8, 30, ctx.trash)
		sp.SpreadAngle = Vector2.new(40, 40)
		sp.LightEmission = 1
		sp.Rate = 60
		run(3, function(k)
			st.jaw = math.rad(16) * ease(k / 0.2) * (1 - ease((k - 0.85) / 0.15))
			st.hp = math.rad(9) - math.rad(3) * math.sin(math.pi * k) -- a slow controlled sweep down and back
			apply()
			local grow = ease((k - 0.15) / 0.25) * (1 - ease((k - 0.8) / 0.2))
			local len = 170 * ease((k - 0.15) / 0.3)
			local look = mouth.CFrame.LookVector
			local pos = mouth.Position
			beam.Size = Vector3.new(math.max(len, 0.1), 7 * grow + 0.1, 7 * grow + 0.1)
			beam.CFrame = CFrame.lookAt(pos + look * len / 2, pos + look * len) * CFrame.Angles(0, math.rad(90), 0)
			beam.Transparency = 1 - 0.85 * grow
			beam.Color = VIOLET:Lerp(WHITE, 0.3 + 0.2 * math.sin(k * 40))
			glowA.Position = pos
			ml.Brightness = 7 * grow
			if k > 0.85 then
				sp.Rate = 0
			end
		end)
		beam.Transparency = 1
	end
	-- 7. the fortress answers: a pulse runs down the bastion slits; settle into the powered idle (2.4 s)
	lib.Sound.Play("Cheer")
	lib.Cine.ring(P.Position + Vector3.new(0, 2, 0), VIOLET, 240, 1.8)
	run(2.4, function(k)
		local e = ease(k)
		for i, p in forts do
			glow(p, 0.6 + 1.2 * math.exp(-((k * 5 - i * 0.6) ^ 2)))
		end
		for _, p in cores do
			glow(p, 1.9 - 0.9 * e)
		end
		if coreLight then
			coreLight.Brightness = 5 - 3 * e
		end
		st.lift = 1.5 * (1 - e)
		st.neck = math.rad(14) - math.rad(4) * e
		st.hp = math.rad(9) - math.rad(4) * e
		st.wing = math.rad(15) - math.rad(10) * e
		st.sweep = math.rad(3) * (1 - e)
		apply()
	end)
	sess.powered = 1
	sess.paused = false
end

return Show
