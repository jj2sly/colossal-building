--!nonstrict
-- FORGOTTEN F3 show (module name = the opaque build key). An ancient buried construct slowly waking. Nothing attacks or damages.
-- Activation (~20%, hand exposed): the buried hand settles and shifts a little.
-- Milestone 1 (~52%, chest cavity built): the cavity answers faintly (dim core glow, a slow breath through the torso).
-- Milestone 2 (~84%, Star Metal Core built): the core wakes the torso; conduits pulse up the neck; the head stays dormant.
-- Milestone 3 (~92%): systems synchronise; the head rises a little and the eyes give a faint flicker.
-- Completion (~16.5 s): debris settles, the hand shifts, the core wakes, energy travels up the torso, the head lifts into place,
-- restrained eye and core light, a low stone/metal movement, one monumental pulse, then an active idle.
local Show = {}
Show.SpectacleId = "Fg9eShow"

local GLOW0 = Color3.fromRGB(52, 78, 96)
local CYAN = Color3.fromRGB(120, 215, 255)
local WHITE = Color3.fromRGB(230, 248, 255)
local X = Vector3.xAxis
local UPPER = { "Shoulders", "Torso", "Chest", "Neck", "CoreGlow" }
local HEAD = { "Head", "Eyes", "Crown" }

local function glow(p: BasePart, k: number)
	p.Color = GLOW0:Lerp(CYAN, math.clamp(k, 0, 1)):Lerp(WHITE, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.3 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

-- sess: hand (rad), breath (0..1 level), lift (0..1), debris (studs of settle), core level, eye level
local function pose(sess, lib, t: number)
	local m = sess.model
	local R = m:GetPivot().Rotation
	local up = R * Vector3.yAxis
	lib.spin(sess, "Hand", "HandC", X, sess.hand or 0)
	local br = CFrame.new(up * (math.sin(t * 0.9) * 0.7 * (sess.breath or 0)))
	for _, g in UPPER do
		lib.spin(sess, g, nil, nil, 0, br)
	end
	local lift = sess.lift or 0
	local hp = CFrame.new(up * (lift * 5)) * br
	for _, g in HEAD do
		lib.spin(sess, g, "HeadC", X, lift * 0.1, hp) -- chin rises a little as the head lifts
	end
	lib.spin(sess, "Dig", nil, nil, 0, CFrame.new(up * -(sess.debris or 0)))
	lib.spin(sess, "Gantry", nil, nil, 0, CFrame.new(up * -(sess.debris or 0) * 0.5))
end

local function lights(sess, lib, t: number)
	local core, eye = sess.core or 0, sess.eye or 0
	for _, p in lib.groupOf(sess, "CoreGlow") do
		local o = p:GetAttribute("Order") or 1
		local wave = 0.5 + 0.5 * math.sin(t * 3 - o * 0.9)
		glow(p, core * (0.35 + 0.6 * wave))
	end
	for _, p in lib.groupOf(sess, "Eyes") do
		glow(p, eye * (0.7 + 0.3 * math.sin(t * 5)))
	end
end

function Show.Activate(sess, lib)
	sess.hand, sess.breath, sess.lift, sess.debris, sess.core, sess.eye = 0, 0, 0, 0, 0, 0
	lib.Sound.Play("Rumble")
	sess:step(function(dt, t)
		sess.hand = math.rad(2.2) * math.sin(t * 0.45) + math.rad(1.2) * math.sin(t * 1.3)
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
		ramp(sess, "core", 0.25, 2.5)
		ramp(sess, "breath", 0.5, 2)
	elseif n == 2 then
		lib.Sound.Play("PowerUp")
		ramp(sess, "core", 0.7, 3)
		ramp(sess, "breath", 1, 2)
	else
		lib.Sound.Play("Zap")
		ramp(sess, "lift", 0.4, 3)
		ramp(sess, "eye", 0.35, 2)
	end
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local P = m:GetPivot()
	local last, T = os.clock(), 0
	local function run(seconds: number, fn)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and ctx.alive() do
			local now = os.clock()
			local dt = math.min(now - last, 0.05)
			T += dt
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
	local hand0 = sess.hand or 0
	local lift0 = sess.lift or 0
	local cb = lib.find(m, "CoreC")
	local cp = cb and sess:base(cb)
	local centre = if cp then cp.Position else (P * CFrame.new(0, 100, -12)).Position
	-- 1. excavation debris and structures settle (2 s)
	lib.Sound.Play("Rumble")
	run(2, function(k)
		sess.debris = 3.2 * math.sin(k * math.pi) * (1 - k * 0.5)
		sess.hand = hand0
	end)
	sess.debris = 0
	-- 2. the buried hand shifts (2 s)
	lib.Sound.Play("Thud")
	lib.Cine.shake(0.18, 0.8)
	run(2, function(k)
		sess.hand = hand0 + math.rad(-7) * ease(math.sin(k * math.pi / 2)) * (1 - 0.3 * k)
	end)
	-- 3. the chest core wakes (2 s)
	lib.Sound.Play("PowerUp")
	run(2, function(k)
		sess.core = 0.7 + 0.5 * ease(k)
		sess.breath = 1
	end)
	-- 4. energy travels up through the torso (2.5 s): the Order pulse runs neck-ward
	lib.Sound.Play("Zap")
	run(2.5, function(k)
		sess.core = 1.2
		for _, p in lib.groupOf(sess, "CoreGlow") do
			local o = p:GetAttribute("Order") or 1
			local d = math.abs(o - 1 - k * 5)
			glow(p, 0.5 + 1.2 * math.exp(-(d / 1.0) ^ 2))
		end
	end)
	-- 5. the head lifts into its final position (2.5 s)
	lib.Sound.Play("Rumble")
	lib.Cine.shake(0.15, 1.2)
	run(2.5, function(k)
		sess.lift = lift0 + (1 - lift0) * ease(k)
		sess.core = 1.2
	end)
	-- 6. restrained eye and core activation (1.2 s)
	lib.Sound.Play("Chime")
	run(1.2, function(k)
		sess.eye = 0.4 + 0.9 * ease(k)
		sess.core = 1.2 + 0.4 * k
	end)
	-- 7. a large, low stone/metal movement (0.8 s)
	lib.Sound.Play("Thud")
	lib.Cine.shake(0.3, 0.7)
	run(0.8, function(k)
		sess.debris = -1.4 * math.sin(k * math.pi)
		sess.hand = hand0 + math.rad(-7) * (1 - k * 0.5)
	end)
	sess.debris = 0
	-- 8. one monumental final pulse (1.5 s): a see-through ring expanding across the pit
	lib.Sound.Play("Boom")
	lib.Sound.Play("Meteor")
	lib.Cine.shake(0.45, 1)
	lib.Cine.bloom(0.45, 0.2, 2.2, 1.4)
	lib.Cine.ring(centre, WHITE, 220, 1.5)
	local wave = Instance.new("Part")
	wave.Name = "MB_TitanPulse"
	wave.Anchored, wave.CanCollide, wave.CanQuery, wave.CanTouch, wave.CastShadow = true, false, false, false, false
	wave.Shape = Enum.PartType.Cylinder
	wave.Material = Enum.Material.Neon
	wave.Color = CYAN
	wave.Size = Vector3.new(1.5, 10, 10)
	wave.CFrame = CFrame.new(P.Position + Vector3.new(0, 6, 0)) * P.Rotation * CFrame.Angles(0, 0, math.rad(90))
	wave.Parent = workspace
	table.insert(ctx.trash, wave)
	local la = lib.anchor(centre, ctx.trash)
	local fl = lib.light(la, CYAN, 160, 0, ctx.trash)
	run(1.5, function(k)
		local d = 10 + 360 * ease(k)
		wave.Size = Vector3.new(1.5, d, d)
		wave.Transparency = 0.4 + 0.6 * k
		fl.Brightness = 10 * (1 - k)
		sess.core = 1.6 * (1 - k) + 0.6 * k
		sess.eye = 1.3 * (1 - k) + 0.5 * k
	end)
	wave:Destroy()
	-- 9. settle into an active idle (2 s)
	lib.Sound.Play("Cheer")
	run(2, function(k)
		sess.core = 0.6 + 0.1 * (1 - k)
		sess.eye = 0.5
	end)
	sess.breath, sess.core, sess.eye = 1, 0.6, 0.5
	sess.paused = false
end

return Show
