--!nonstrict
-- MEGA FORTRESS WALL show. Activation (~40%): the wall torches ignite one by one outward from the gate; a low rumble.
-- Milestone 1 (~65%): the gate machinery stirs: the winch drums creak back and forth and the portcullis shudders.
-- Milestone 2 (~82%): the fortress comes alive: banners sway, standards fly and the tower beacons are lit.
-- Completion (Gates Open, ~12 s): three heavy drum beats; the portcullis winds fully up with the drums spinning; the two great
-- gate leaves swing open with dust and weight; a wave of fire runs along the wall from the gate to the towers and the beacons
-- flare; the banners snap out on the final beats; gold ring and cheer.
-- Every pose is composed per frame from each part's original CFrame (no drift).
local Show = {}

local FLAME = Color3.fromRGB(255, 98, 22)
local HOTF = Color3.fromRGB(255, 196, 96)
local GATE_AJAR = math.rad(22) -- matches the template
local DUST = Color3.fromRGB(190, 176, 150)

local function flames(sess, P: CFrame, name: string)
	sess.fl = sess.fl or {}
	local now = os.clock()
	local c = sess.fl[name]
	if c and now - c.at < 1 then
		return c.list
	end
	local list = {}
	for _, p in sess.model:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Flame") and p:FindFirstAncestor(name) then
			local l = P:PointToObjectSpace(p.Position)
			table.insert(list, { part = p, x = math.abs(l.X), mesh = p:FindFirstChildOfClass("SpecialMesh") })
		end
	end
	table.sort(list, function(a, b)
		return a.x < b.x
	end)
	sess.fl[name] = { at = now, list = list }
	return list
end

local function burn(fc, k: number, t: number, lib, trash)
	local p = fc.part
	if k <= 0.02 then
		p.Transparency = 1
		return
	end
	p.Transparency = 0.05
	local f = 1 + 0.12 * math.sin(t * 13 + fc.x) + 0.07 * math.sin(t * 23 + fc.x * 0.3)
	local s = math.clamp(k, 0, 2.6) * f
	if fc.mesh then
		fc.mesh.Scale = Vector3.new(0.7 + 0.3 * s, 0.6 + 0.45 * s, 0.7 + 0.3 * s)
	end
	p.Color = FLAME:Lerp(HOTF, math.clamp(k - 1, 0, 1))
	if not fc.light then
		fc.light = lib.light(p, FLAME, 9, 0, trash)
	end
	fc.light.Brightness = 0.22 * k * f
end

-- o = { port (studs up), gate (rad open beyond ajar), drum (rad), shake (studs), billow (rad), flutter (rad) }
local function pose(sess, lib, o, t: number)
	local m = sess.model
	local P = m:GetPivot()
	local R = P.Rotation
	local function apply(name: string, fn)
		for _, p in lib.group(m, name) do
			local b = sess:base(p)
			if b then
				p.CFrame = fn(b, p)
			end
		end
	end
	local up = P.UpVector
	apply("Portcullis", function(b)
		return b + up * ((o.port or 0) + (o.shake or 0) * math.sin(t * 31))
	end)
	for _, tag in { "L", "R" } do
		local h = lib.find(m, "Hinge" .. tag)
		local hb = h and sess:base(h)
		if hb then
			local side = if tag == "R" then 1 else -1
			local H = CFrame.new(hb.Position) * R
			local X = H * CFrame.Angles(0, side * (o.gate or 0), 0) * H:Inverse()
			apply("Gate" .. tag, function(b)
				return X * b
			end)
		end
	end
	apply("Drum", function(b)
		return b * CFrame.Angles(o.drum or 0, 0, 0)
	end)
	apply("Banner", function(b, p)
		local hinge = b * CFrame.new(0, p.Size.Y / 2, 0)
		if p.Size.Y < 10 then -- the gold header band rides with its banner: hinge at the banner top
			hinge = b * CFrame.new(0, 3, 0)
		end
		local a = (o.billow or 0) + 0.04 * math.sin(t * 1.6 + b.Position.X)
		return hinge * CFrame.Angles(-a, 0, 0) * hinge:Inverse() * b
	end)
	apply("Flag", function(b, p)
		local hinge = b * CFrame.new(-p.Size.X / 2, 0, 0)
		return hinge * CFrame.Angles(0, (o.flutter or 0) * math.sin(t * 7 + b.Position.X), 0) * hinge:Inverse() * b
	end)
end

function Show.Activate(sess, lib)
	sess.mech, sess.life = 0, 0
	sess.drum = 0
	local P = sess.model:GetPivot()
	local start = os.clock()
	lib.Sound.Play("Rumble")
	sess:step(function(dt, t)
		for i, fc in flames(sess, P, "Torch") do
			local lit = os.clock() - start > (i - 1) * 0.35
			if lit and not fc.on then
				fc.on = true
				lib.Sound.Play("Click")
			end
			burn(fc, if lit then 1 else 0, t, lib, sess.trash)
		end
		for _, fc in flames(sess, P, "Beacon") do
			burn(fc, sess.life * 1.3, t, lib, sess.trash)
		end
		sess.drum += dt * sess.mech * 0.6 * math.sin(t * 0.8)
		local open = sess.final -- after the completion show the gate stays open and the portcullis up
		pose(sess, lib, {
			drum = sess.drum,
			shake = if open then 0 else 0.12 * sess.mech,
			port = if open then 15 else 0.4 * sess.mech * math.sin(t * 0.8),
			gate = if open then math.rad(88) - GATE_AJAR else 0,
			billow = math.rad(5) * sess.life * (0.5 + 0.5 * math.sin(t * 0.7)),
			flutter = math.rad(20) * sess.life,
		}, t)
	end)
end

function Show.Milestone(sess, lib, n)
	local key = if n == 1 then "mech" else "life"
	lib.Sound.Play(if n == 1 then "Thud" else "Cheer")
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < 2.5 do
		sess[key] = (os.clock() - t0) / 2.5
		task.wait()
	end
	sess[key] = 1
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local P = m:GetPivot()
	local torches, beacons = flames(sess, P, "Torch"), flames(sess, P, "Beacon")
	local drum = sess.drum or 0
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
	local function ease(k: number): number
		return k * k * (3 - 2 * k)
	end
	local function fire(k: number, t: number)
		for _, fc in torches do
			burn(fc, k, t, lib, ctx.trash)
		end
		for _, fc in beacons do
			burn(fc, k * 1.2, t, lib, ctx.trash)
		end
	end
	local gatePos = (P * CFrame.new(0, 3, -30)).Position
	local function dust(n: number, size: number)
		local a = lib.anchor(gatePos, ctx.trash)
		local e = lib.emitter(a, lib.SMOKE, DUST, size, 2.6, 18, ctx.trash)
		e.SpreadAngle = Vector2.new(80, 20)
		e:Emit(n)
	end
	-- 1. three heavy drum beats (1.5 s)
	local beats = 0
	run(1.5, function(k, t)
		if k < 1 and math.floor(k * 3) >= beats then
			beats += 1
			lib.Sound.Play("Thud")
			lib.Cine.shake(0.25, 0.25)
		end
		fire(0.6 + 0.6 * math.exp(-((k * 3) % 1) * 6), t)
		pose(sess, lib, { drum = drum }, t)
	end)
	-- 2. the portcullis winds fully up (2 s)
	lib.Sound.Play("Rumble")
	run(2, function(k, t, dt)
		drum += dt * 9
		fire(0.8, t)
		pose(sess, lib, { drum = drum, port = 15 * ease(k), shake = 0.15 * (1 - k) }, t)
	end)
	-- 3. the gates swing open (3.6 s), with weight: a slow start, dust, a heavy stop
	dust(30, 10)
	lib.Cine.shake(0.2, 3.4)
	run(3.6, function(k, t, dt)
		drum += dt * 3 * (1 - k)
		local e = k * k * k * (k * (k * 6 - 15) + 10)
		fire(0.8, t)
		pose(sess, lib, { drum = drum, port = 15, gate = (math.rad(88) - GATE_AJAR) * e }, t)
	end)
	lib.Sound.Play("Boom")
	lib.Cine.shake(0.5, 0.6)
	lib.Cine.ring(gatePos, DUST, 170, 1.8)
	dust(50, 14)
	-- 4. a wave of fire along the wall from the gate to the towers; beacons flare (2.4 s)
	lib.Sound.Play("Meteor")
	run(2.4, function(k, t)
		local wave = k * 90
		for _, fc in torches do
			burn(fc, 1 + 1.4 * math.exp(-((fc.x - wave) / 14) ^ 2), t, lib, ctx.trash)
		end
		for _, fc in beacons do
			burn(fc, 1.2 + 1.4 * math.clamp((k - 0.6) / 0.4, 0, 1), t, lib, ctx.trash)
		end
		pose(sess, lib, { drum = drum, port = 15, gate = math.rad(88) - GATE_AJAR }, t)
	end)
	-- 5. banners snap out, standards whip, gold ring and cheer (2.3 s)
	lib.Sound.Play("Cheer")
	lib.Sound.Play("Boom")
	lib.Cine.bloom(0.3, 0.2, 1, 1.2)
	lib.Cine.ring(P.Position + Vector3.new(0, 2, 0), Color3.fromRGB(255, 214, 110), 220, 1.8)
	run(2.3, function(k, t)
		local snap = math.sin(math.clamp(k / 0.35, 0, 1) * math.pi) * math.rad(40) + math.rad(8) * (1 - k)
		fire(1.6 - 0.5 * k, t)
		pose(sess, lib, { drum = drum, port = 15, gate = math.rad(88) - GATE_AJAR, billow = snap, flutter = math.rad(35) }, t)
	end)
	sess.drum = drum
	sess.final = true
	sess.paused = false
end

return Show
