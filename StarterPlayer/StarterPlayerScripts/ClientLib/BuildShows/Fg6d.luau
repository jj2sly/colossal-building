--!nonstrict
-- FORGOTTEN F5 show (module name = the opaque build key). An ancient ceremonial statue slowly becoming functional: slow, heavy, no walking.
-- Activation (~30%, legs built): a subtle weight shift, the body settling from side to side through the legs.
-- Milestone 1 (~50%, torso and arms built): faint internal movement in the torso; the left arm settles slightly.
-- Milestone 2 (~86%, Star Metal Heart built): the heart wakes; energy spreads through a few major seams.
-- Milestone 3 (~93%, tool built): the head turns slightly, the tool answers, the crown and monument synchronise.
-- Completion (~17 s): a huge settling pulse in the base, legs brace, the torso straightens, the arms shift into their final pose,
-- the heart wakes, energy rises through the torso, the head turns and raises, the crown responds, the tool rises a little, the back
-- monument activates, one huge controlled pulse, then a slow active idle.
local Show = {}
Show.SpectacleId = "Fg6dShow"

local GLOW0 = Color3.fromRGB(70, 110, 140)
local COLD = Color3.fromRGB(140, 205, 235)
local WHITE = Color3.fromRGB(232, 246, 250)
local Y, Z = Vector3.yAxis, Vector3.zAxis
local BODY = { "Legs", "Torso", "ArmL", "ArmR", "Head", "Helmet", "Heart", "Finish" }

local function glow(p: BasePart, k: number)
	p.Color = GLOW0:Lerp(COLD, math.clamp(k, 0, 1)):Lerp(WHITE, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.7 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

-- sess: sway (0..1 weight shift level), breath (torso), armL (rad), armR (rad), turn (rad), headUp (studs), drop (studs, base pulse),
-- heart (0..1.4), toolUp (studs), mon (studs), crown (studs), sync (0..1)
local function pose(sess, lib, t: number)
	local R = sess.model:GetPivot().Rotation
	local up = R * Y
	local side = R * Vector3.xAxis
	local ph = 1 - (sess.sync or 0)
	local sway = side * (math.sin(t * 0.4 + ph) * 0.6 * (sess.sway or 0))
	local lift = up * (-(sess.drop or 0) + math.sin(t * 0.8) * 0.3 * (sess.breath or 0))
	local body = CFrame.new(sway + lift)
	lib.spin(sess, "Legs", nil, nil, 0, body)
	lib.spin(sess, "Torso", nil, nil, 0, body)
	lib.spin(sess, "Heart", nil, nil, 0, body)
	lib.spin(sess, "Finish", nil, nil, 0, body)
	lib.spin(sess, "ArmL", "ShoulderLC", Z, (sess.armL or 0) + math.sin(t * 0.5) * 0.012 * (sess.breath or 0), body)
	lib.spin(sess, "ArmR", "ShoulderRC", Z, (sess.armR or 0), body)
	local hb = CFrame.new(up * (sess.headUp or 0)) * body
	lib.spin(sess, "Head", "HeadC", Y, (sess.turn or 0) + math.sin(t * 0.3) * 0.02 * (sess.heartLv or 0), hb)
	lib.spin(sess, "Helmet", "HeadC", Y, (sess.turn or 0), CFrame.new(up * (sess.crown or 0)) * hb)
	lib.spin(sess, "Tool", nil, nil, 0, CFrame.new(up * ((sess.toolUp or 0) + math.sin(t * 0.7 + ph) * 0.4 * (sess.toolLv or 0))))
	lib.spin(sess, "Monument", nil, nil, 0, CFrame.new(up * ((sess.mon or 0) + math.sin(t * 0.35 + ph * 2) * 0.5 * (sess.toolLv or 0))))
end

local function lights(sess, lib, t: number)
	local h = sess.heart or 0
	for _, p in lib.groupOf(sess, "Heart") do
		local o = p:GetAttribute("Order")
		if o then
			local wave = 0.5 + 0.5 * math.sin(t * 2.6 - o * 1.1)
			glow(p, h * (if o == 1 then 0.8 + 0.2 * math.sin(t * 2) else 0.25 + 0.65 * wave))
		end
	end
end

function Show.Activate(sess, lib)
	sess.sway, sess.breath, sess.heart, sess.heartLv, sess.toolLv = 0.5, 0, 0, 0, 0
	lib.Sound.Play("Rumble")
	sess:step(function(dt, t)
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
		ramp(sess, "breath", 1, 3)
		ramp(sess, "armL", math.rad(-2), 3)
	elseif n == 2 then
		lib.Sound.Play("PowerUp")
		ramp(sess, "heart", 0.7, 3)
		ramp(sess, "heartLv", 1, 1)
	else
		lib.Sound.Play("Zap")
		ramp(sess, "turn", math.rad(4), 3)
		sess.toolLv = 1
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
	local hc = lib.find(m, "HeartC")
	local hb = hc and sess:base(hc)
	local heartPos = if hb then hb.Position else (P * CFrame.new(0, 150, -24)).Position
	local baseFoot = (P * CFrame.new(0, 3, 0)).Position
	sess.toolLv, sess.heartLv = 1, 1
	-- 1. the base gives one huge settling pulse (1.4 s)
	lib.Sound.Play("Thud")
	lib.Sound.Play("Rumble")
	lib.Cine.shake(0.25, 0.9)
	lib.Cine.ring(baseFoot, WHITE, 150, 1.4)
	run(1.4, function(k)
		sess.drop = 2.4 * math.sin(k * math.pi) * (1 - 0.3 * k)
	end)
	-- 2. the legs brace (1.2 s)
	run(1.2, function(k)
		sess.drop = 0.8 * math.sin(k * math.pi)
		sess.sway = 0.5 * (1 - ease(k))
	end)
	-- 3. the torso straightens slightly (1.2 s)
	run(1.2, function(k)
		sess.breath = 1 - 0.5 * ease(k)
	end)
	-- 4. the arms shift into the final monumental pose (1.8 s)
	lib.Sound.Play("Thud")
	local armL0 = sess.armL or 0
	run(1.8, function(k)
		sess.armL = armL0 + math.rad(-7) * ease(k)
		sess.armR = math.rad(5) * ease(k)
	end)
	-- 5. the heart wakes fully (1.4 s)
	lib.Sound.Play("PowerUp")
	run(1.4, function(k)
		sess.heart = 0.7 + 0.6 * ease(k)
	end)
	-- 6. energy moves upward through the torso (1.8 s)
	lib.Sound.Play("Zap")
	run(1.8, function(k)
		sess.heart = 1.3
		for _, p in lib.groupOf(sess, "Heart") do
			local o = p:GetAttribute("Order")
			if o then
				local d = math.abs(o - 1 - k * 2.4)
				glow(p, 0.5 + 1.1 * math.exp(-(d / 0.9) ^ 2))
			end
		end
	end)
	-- 7. the head turns and raises (1.6 s)
	lib.Sound.Play("Rumble")
	run(1.6, function(k)
		sess.turn = math.rad(4) + math.rad(8) * math.sin(k * math.pi / 2) * (1 - 0.4 * k)
		sess.headUp = 3 * ease(k)
	end)
	-- 8. the crown responds (1 s)
	lib.Sound.Play("Chime")
	run(1, function(k)
		sess.crown = 3 * math.sin(k * math.pi)
	end)
	-- 9. the giant tool rises slightly into its final pose (1.2 s)
	lib.Sound.Play("Thud")
	run(1.2, function(k)
		sess.toolUp = 4 * ease(k)
	end)
	-- 10. the back monument activates (1.2 s)
	lib.Sound.Play("PowerUp")
	run(1.2, function(k)
		sess.mon = 3 * ease(k)
		sess.sync = ease(k)
	end)
	-- 11. one huge controlled final pulse (1.6 s): a flat see-through ring races out across the deck
	lib.Sound.Play("Boom")
	lib.Sound.Play("Meteor")
	lib.Cine.shake(0.4, 1)
	lib.Cine.bloom(0.4, 0.2, 2, 1.3)
	lib.Cine.ring(heartPos, WHITE, 200, 1.6)
	local wave = Instance.new("Part")
	wave.Name = "MB_ColossusPulse"
	wave.Anchored, wave.CanCollide, wave.CanQuery, wave.CanTouch, wave.CastShadow = true, false, false, false, false
	wave.Shape = Enum.PartType.Cylinder
	wave.Material = Enum.Material.Neon
	wave.Color = COLD
	wave.Size = Vector3.new(2, 10, 10)
	wave.CFrame = CFrame.new(baseFoot + up * 3) * P.Rotation * CFrame.Angles(0, 0, math.rad(90))
	wave.Parent = workspace
	table.insert(ctx.trash, wave)
	local la = lib.anchor(heartPos, ctx.trash)
	local fl = lib.light(la, COLD, 180, 0, ctx.trash)
	run(1.6, function(k)
		local d = 10 + 360 * ease(k)
		wave.Size = Vector3.new(2, d, d)
		wave.Transparency = 0.4 + 0.6 * k
		fl.Brightness = 9 * (1 - k)
		sess.heart = 1.5 * (1 - k) + 0.7 * k
		sess.drop = 1.0 * math.sin(k * math.pi)
	end)
	wave:Destroy()
	-- 12. settle into a slow active idle (1.6 s)
	lib.Sound.Play("Cheer")
	run(1.6, function(k)
		sess.heart = 0.7
		sess.headUp = 3 * (1 - 0.5 * ease(k))
		sess.toolUp = 4 * (1 - 0.5 * ease(k))
		sess.mon = 3 * (1 - 0.5 * ease(k))
		sess.sway = 0.5 * ease(k)
	end)
	sess.paused = false
end

return Show
