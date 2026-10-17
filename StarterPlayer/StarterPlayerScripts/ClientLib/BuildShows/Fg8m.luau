--!nonstrict
-- FORGOTTEN F6 show (module name = the opaque build key). Deliberately wrong, never perfectly synchronised: every mechanism keeps its
-- own speed and phase; the gear runs against the direction of the ring it seems to belong to; the block and the counterweight swap
-- places; the connector drifts but never touches.
-- Activation (~25%, Circle I built): the first circle starts to turn slowly.
-- Milestone 1 (~40%, rail and block built): the rail begins to carry the suspended block up and down.
-- Milestone 2 (~55%, Circle II and tower built): Circle II turns the opposite way and the counterweight answers out of step.
-- Milestone 3 (~82%, reverse gear built): the reverse gear turns against expectation; the connector begins to drift; the core pulses.
-- Milestone 4 (~93%, final loop built): the final loop wakes; everything briefly drifts out of sync, then steadies.
-- Completion (~18 s): see the numbered steps in Show.Spectacle: separate starts, opposed rotations, block and counterweight trading
-- places, the diagonal engaging, the core waking, the reverse gear, the connector settling without touching, the loop, a burst of
-- independent speed, the paradox core pulsing, one pulse through the void, then a slow impossible idle.
local Show = {}
Show.SpectacleId = "Fg8mShow"

local GLOW0 = Color3.fromRGB(86, 128, 148)
local COLD = Color3.fromRGB(160, 214, 232)
local WHITE = Color3.fromRGB(236, 246, 248)
local X, Y, Z = Vector3.xAxis, Vector3.yAxis, Vector3.zAxis

local function glow(p: BasePart, k: number)
	p.Color = GLOW0:Lerp(COLD, math.clamp(k, 0, 1)):Lerp(WHITE, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.7 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

-- sess: a1 (circle I angle), a2 (circle II), ag (gear), ap (paradox), al (loop), v1/v2/vg/vp/vl (speed levels), block (0..1 position),
-- counter (0..1), diag (studs), conn (vector offset), swing (rad), core (0..1.5)
local function pose(sess, lib, t: number)
	local R = sess.model:GetPivot().Rotation
	local up = R * Y
	local fwd = R * Z
	lib.spin(sess, "CircleI", "CircleIC", Z, sess.a1 or 0)
	lib.spin(sess, "CircleII", "CircleIIC", X, sess.a2 or 0)
	lib.spin(sess, "Gear", "GearC", Z, sess.ag or 0)
	lib.spin(sess, "Loop", "LoopC", Z, sess.al or 0)
	lib.spin(sess, "Paradox", "CoreC", Y, sess.ap or 0)
	lib.spin(sess, "Core", "CoreC", Y, -(sess.ap or 0) * 0.7)
	lib.spin(sess, "Upper", "UpperP", Z, sess.swing or 0)
	-- the block rides the tilted rail: 60 studs of travel, z follows the tilt (68 over 238 studs)
	local bp = (sess.block or 0.5) - 0.5
	lib.spin(sess, "Block", nil, nil, 0, CFrame.new(up * (bp * 90) - fwd * (bp * 90 * 68 / 238)))
	lib.spin(sess, "Counter", nil, nil, 0, CFrame.new(up * ((sess.counter or 0.5) - 0.5) * 70))
	lib.spin(sess, "Diagonal", nil, nil, 0, CFrame.new(R * Vector3.new(-1, 0.75, 0.72).Unit * (sess.diag or 0)))
	lib.spin(sess, "Connector", nil, nil, 0, CFrame.new(R * (sess.conn or Vector3.zero) + up * (math.sin(t * 0.5) * 1.5 * (sess.connLv or 0))))
end

local function lights(sess, lib, t: number)
	local c = sess.core or 0
	for _, p in lib.groupOf(sess, "CoreGlow") do
		glow(p, c * (0.6 + 0.4 * math.sin(t * 3.1)))
	end
end

function Show.Activate(sess, lib)
	sess.a1, sess.a2, sess.ag, sess.ap, sess.al = 0, 0, 0, 0, 0
	sess.v1, sess.v2, sess.vg, sess.vp, sess.vl = 0.32, 0, 0, 0, 0
	sess.block, sess.counter, sess.diag, sess.swing, sess.core, sess.connLv = 0.5, 0.5, 0, 0, 0, 0
	sess.conn = Vector3.zero
	lib.Sound.Play("Rumble")
	sess:step(function(dt, t)
		sess.a1 += dt * sess.v1
		sess.a2 -= dt * sess.v2
		sess.ag -= dt * sess.vg -- the gear turns AGAINST circle I (whose angle grows), on purpose
		sess.ap += dt * sess.vp
		sess.al += dt * sess.vl
		-- the block and the counterweight each follow their own slow, unrelated oscillation once enabled
		if sess.blockOn then
			sess.block = 0.5 + 0.5 * math.sin(t * 0.33)
		end
		if sess.counterOn then
			sess.counter = 0.5 + 0.5 * math.sin(t * 0.27 + 2.2)
		end
		if sess.swingOn then
			sess.swing = math.rad(10) * math.sin(t * 0.41)
		end
		pose(sess, lib, t)
		lights(sess, lib, t)
	end)
end

local function ramp(sess, key: string, to: number, secs: number)
	local from = sess[key] or 0
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < secs do
		sess[key] = from + (to - from) * ((os.clock() - t0) / secs)
		task.wait()
	end
	sess[key] = to
end

function Show.Milestone(sess, lib, n)
	if n == 1 then
		lib.Sound.Play("Rumble")
		sess.blockOn = true
	elseif n == 2 then
		lib.Sound.Play("PowerUp")
		ramp(sess, "v2", 0.45, 2)
		sess.counterOn = true
		sess.swingOn = true
	elseif n == 3 then
		lib.Sound.Play("Zap")
		ramp(sess, "vg", 0.5, 2)
		sess.connLv = 1
		ramp(sess, "core", 0.6, 3)
	else
		lib.Sound.Play("PowerUp")
		ramp(sess, "vl", 0.12, 2)
		ramp(sess, "vp", 0.4, 2)
		-- briefly out of step, then steadier
		ramp(sess, "v1", 0.55, 1.5)
		ramp(sess, "v1", 0.32, 2.5)
	end
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local P = m:GetPivot()
	local up = P.Rotation * Y
	local last, T = os.clock(), 0
	local function run(seconds: number, fn)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and ctx.alive() do
			local now = os.clock()
			local dt = math.min(now - last, 0.05)
			T += dt
			sess.a1 += dt * sess.v1
			sess.a2 -= dt * sess.v2
			sess.ag -= dt * sess.vg
			sess.ap += dt * sess.vp
			sess.al += dt * sess.vl
			fn((now - t0) / seconds, dt)
			pose(sess, lib, T)
			lights(sess, lib, T)
			last = now
			task.wait()
		end
		fn(1, 0)
		pose(sess, lib, T)
	end
	local function ease(k: number): number
		return k * k * (3 - 2 * k)
	end
	-- the spectacle drives block / counter / swing itself
	sess.blockOn, sess.counterOn, sess.swingOn = false, false, false
	local b0, c0, s0 = sess.block or 0.5, sess.counter or 0.5, sess.swing or 0
	local cb = lib.find(m, "CoreC")
	local cp = cb and sess:base(cb)
	local centre = if cp then cp.Position else (P * CFrame.new(6, 122, -6)).Position
	-- 1. the outer mechanisms start separately (1.2 s)
	lib.Sound.Play("Rumble")
	run(1.2, function(k)
		sess.v1 = 0.32 + 0.2 * ease(k)
		sess.v2 = 0.45 * ease(math.clamp(k * 2 - 0.6, 0, 1))
	end)
	-- 2. the first circle turns (1 s)
	run(1, function(k)
		sess.v1 = 0.52 + 0.5 * ease(k)
	end)
	-- 3. the rail moves the suspended block (1.4 s)
	lib.Sound.Play("Thud")
	run(1.4, function(k)
		sess.block = b0 + (1 - b0) * ease(k)
	end)
	-- 4. the second circle turns the opposite way (1.2 s)
	lib.Sound.Play("PowerUp")
	run(1.2, function(k)
		sess.v2 = 0.45 + 0.6 * ease(k)
	end)
	-- 5. the counterweight rises while the block appears to descend (1.6 s)
	run(1.6, function(k)
		sess.counter = c0 + (1 - c0) * ease(k)
		sess.block = 1 - 0.8 * ease(k)
	end)
	-- 6. the diagonal mechanism engages: it slides along its own axis (1 s)
	lib.Sound.Play("Thud")
	lib.Cine.shake(0.12, 0.8)
	run(1, function(k)
		sess.diag = 6 * ease(k)
	end)
	-- 7. the core wakes (1.2 s)
	lib.Sound.Play("Chime")
	run(1.2, function(k)
		sess.core = 0.6 + 0.7 * ease(k)
		sess.vp = 0.4 + 0.3 * ease(k)
	end)
	-- 8. the reverse gear runs against the direction of the circle it seems to drive (1.6 s)
	run(1.6, function(k)
		sess.vg = 0.5 + 1.1 * ease(k)
		sess.swing = s0 + math.rad(24) * math.sin(k * math.pi)
	end)
	-- 9. the floating connector moves into position without attaching (1.4 s)
	lib.Sound.Play("Zap")
	run(1.4, function(k)
		sess.connLv = 1
		sess.conn = Vector3.new(-7, -10, -9) * ease(k) -- closes most of the gap, never touches
	end)
	-- 10. the final loop activates (1.2 s)
	lib.Sound.Play("PowerUp")
	run(1.2, function(k)
		sess.vl = 0.12 + 0.2 * ease(k)
	end)
	-- 11. the mechanisms briefly speed up, each on its own (1.4 s)
	lib.Sound.Play("Rumble")
	run(1.4, function(k)
		local s = math.sin(k * math.pi)
		sess.v1 = 1.0 + 0.9 * s
		sess.v2 = 1.05 + 0.5 * s
		sess.vg = 1.6 + 1.2 * s
		sess.vl = 0.32 + 0.35 * s
		sess.vp = 0.7 + 0.5 * s
		sess.counter = 1 - 0.5 * ease(k)
		sess.block = 0.2 + 0.6 * ease(k)
	end)
	-- 12. the paradox core pulses (1.2 s)
	lib.Sound.Play("Boom")
	lib.Cine.shake(0.25, 0.8)
	run(1.2, function(k)
		sess.core = 1.3 + 0.3 * math.sin(k * math.pi * 3)
	end)
	-- 13. one large controlled pulse through the void (1.4 s): two see-through rings expand from the core in crossed planes
	lib.Sound.Play("Meteor")
	lib.Cine.bloom(0.4, 0.2, 2, 1.3)
	lib.Cine.ring(centre, WHITE, 200, 1.4)
	local function wave(rot)
		local w = Instance.new("Part")
		w.Name = "MB_VoidPulse"
		w.Anchored, w.CanCollide, w.CanQuery, w.CanTouch, w.CastShadow = true, false, false, false, false
		w.Shape = Enum.PartType.Cylinder
		w.Material = Enum.Material.Neon
		w.Color = COLD
		w.Size = Vector3.new(1.5, 10, 10)
		w.CFrame = CFrame.new(centre) * P.Rotation * rot
		w.Parent = workspace
		table.insert(ctx.trash, w)
		return w
	end
	local w1 = wave(CFrame.Angles(0, 0, math.rad(90))) -- horizontal ring
	local w2 = wave(CFrame.Angles(0, math.rad(90), 0)) -- ring facing the viewer
	local la = lib.anchor(centre, ctx.trash)
	local fl = lib.light(la, COLD, 200, 0, ctx.trash)
	run(1.4, function(k)
		local d = 10 + 260 * ease(k)
		w1.Size = Vector3.new(1.5, d, d)
		w2.Size = Vector3.new(1.5, d * 0.8, d * 0.8)
		w1.Transparency = 0.4 + 0.6 * k
		w2.Transparency = 0.5 + 0.5 * k
		fl.Brightness = 8 * (1 - k)
		sess.core = 1.5 * (1 - k) + 0.7 * k
	end)
	w1:Destroy()
	w2:Destroy()
	-- 14. settle into a slow impossible idle (1.4 s): speeds drop to their own slow rates, never equal
	lib.Sound.Play("Cheer")
	run(1.4, function(k)
		local e = ease(k)
		sess.v1 = 1.9 * (1 - e) + 0.32 * e
		sess.v2 = 1.55 * (1 - e) + 0.4 * e
		sess.vg = 2.8 * (1 - e) + 0.45 * e
		sess.vl = 0.67 * (1 - e) + 0.12 * e
		sess.vp = 1.2 * (1 - e) + 0.4 * e
		sess.core = 0.7
	end)
	sess.blockOn, sess.counterOn, sess.swingOn = true, true, true
	sess.paused = false
end

return Show
