--!nonstrict
-- FORGOTTEN F4 show (module name = the opaque build key). Slow, monumental, never busy. The pieces NEVER close the air gaps.
-- Activation (~22%, wing I built): wing I drifts and turns slowly; the small floating stones begin to hover.
-- Milestone 1 (~46%): wing II stabilises on its own rhythm; hovering grows a little.
-- Milestone 2 (~84%, relic built): the relic begins a weak levitation and pulse.
-- Milestone 3 (~92%): the timber roots flex and tighten; the larger stones settle into impossible positions; the crown answers the relic.
-- Completion (~17 s): loose stones rise, wing I shifts, wing II moves independently, the relic wakes and lifts, the roots tension,
-- the masses briefly synchronise, the crown rises, one tall controlled upward pulse, then a quiet floating idle.
local Show = {}
Show.SpectacleId = "Fg4bShow"

local GLOW0 = Color3.fromRGB(112, 150, 160)
local PALE = Color3.fromRGB(196, 226, 232)
local WHITE = Color3.fromRGB(238, 246, 244)
local Y = Vector3.yAxis

local function glow(p: BasePart, k: number)
	p.Color = GLOW0:Lerp(PALE, math.clamp(k, 0, 1)):Lerp(WHITE, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.5 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

-- sess fields: stones (hover amp), wl/wr (wing drift 0..1 level), wlx/wrx (extra shift studs), wly/wry (extra yaw rad), relic (lift studs),
-- rglow (0..1.3), flex (root amp), crown (lift studs), sync (0..1 in-phase), pulse
local function pose(sess, lib, t: number)
	local up = sess.model:GetPivot().Rotation * Y
	local ph = 1 - (sess.sync or 0)
	local function bob(speed: number, phase: number, amp: number): CFrame
		return CFrame.new(up * (math.sin(t * speed + phase * ph) * amp))
	end
	local sa, sb = sess.stones or 0, sess.stones or 0
	lib.spin(sess, "StonesA", nil, nil, 0, bob(0.45, 0, 1.6 * sa) * CFrame.new(up * (sess.liftA or 0)))
	lib.spin(sess, "StonesB", nil, nil, 0, bob(0.35, 2.1, 2 * sb) * CFrame.new(up * (sess.liftB or 0)))
	lib.spin(sess, "Platform", nil, nil, 0, bob(0.3, 1, 0.5 * (sess.wl or 0)))
	lib.spin(sess, "Shrine", nil, nil, 0, bob(0.3, 1, 0.5 * (sess.wl or 0)))
	lib.spin(sess, "Roof", nil, nil, 0, bob(0.3, 1, 0.5 * (sess.wl or 0)))
	local left = (sess.wl or 0) * (math.sin(t * 0.22) * math.rad(3) + math.rad(1.5)) + (sess.wly or 0)
	local right = (sess.wr or 0) * (math.sin(t * 0.17 + 1.4) * math.rad(2.4)) + (sess.wry or 0)
	lib.spin(sess, "WingL", "WingLC", Y, left, bob(0.28, 0.6, 2.2 * (sess.wl or 0)) * CFrame.new(up * 0 + (sess.wlv or Vector3.zero)))
	lib.spin(sess, "WingR", "WingRC", Y, right, bob(0.21, 3.2, 1.8 * (sess.wr or 0)) * CFrame.new(sess.wrv or Vector3.zero))
	local rl = bob(0.7, 0, 1.2 * math.min(sess.relic or 0, 1)) * CFrame.new(up * (sess.relic or 0))
	lib.spin(sess, "Relic", "RelicC", Y, t * 0.4 * math.min((sess.relic or 0) + (sess.rglow or 0), 1), rl)
	lib.spin(sess, "RelicGlow", nil, nil, 0, rl)
	lib.spin(sess, "Crown", "CrownC", Y, t * (0.1 + 0.25 * (sess.rglow or 0)) * (if sess.crownOn then 1 else 0), CFrame.new(up * (sess.crown or 0)))
	-- roots: each timber segment flexes a little sideways, further along the root = more movement
	local fx = sess.flex or 0
	if fx > 0 then
		local side = sess.model:GetPivot().Rotation * Vector3.xAxis
		for _, p in lib.groupOf(sess, "Roots") do
			local b = sess:base(p)
			if b then
				local i = p:GetAttribute("Idx") or 1
				p.CFrame = CFrame.new(side * (math.sin(t * 0.8 + i * 0.9) * fx * (0.4 + 0.2 * i)) + up * (math.sin(t * 0.6 + i) * fx * 0.5)) * b
			end
		end
	end
end

local function lights(sess, lib, t: number)
	local g = sess.rglow or 0
	for _, p in lib.groupOf(sess, "RelicGlow") do
		glow(p, g * (0.7 + 0.3 * math.sin(t * 2)))
	end
end

function Show.Activate(sess, lib)
	sess.stones, sess.wl, sess.wr, sess.relic, sess.rglow, sess.flex, sess.crown, sess.sync = 0.3, 0.6, 0, 0, 0, 0, 0, 0
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
		ramp(sess, "wr", 1, 3)
		ramp(sess, "stones", 0.6, 3)
	elseif n == 2 then
		lib.Sound.Play("PowerUp")
		ramp(sess, "relic", 2, 3)
		ramp(sess, "rglow", 0.5, 3)
	else
		lib.Sound.Play("Zap")
		ramp(sess, "flex", 1.4, 3)
		ramp(sess, "stones", 1, 3)
		sess.crownOn = true
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
	-- toward-centre shifts are small (about 10 studs) so every major air gap stays open
	local toL = P.Rotation * Vector3.new(10, 3, 2) -- template +x = toward the centre from the left wing
	local toR = P.Rotation * Vector3.new(-8, 6, -6)
	-- 1. loose stone pieces rise slightly (2 s)
	lib.Sound.Play("Rumble")
	run(2, function(k)
		sess.liftA = 5 * ease(k)
		sess.liftB = 4 * ease(k)
	end)
	-- 2. the first wing shifts into alignment (2 s)
	lib.Sound.Play("Thud")
	lib.Cine.shake(0.12, 1)
	run(2, function(k)
		sess.wlv = toL * ease(k)
		sess.wly = math.rad(-9) * ease(k)
	end)
	-- 3. the second wing moves independently (2 s)
	run(2, function(k)
		sess.wrv = toR * ease(k)
		sess.wry = math.rad(12) * ease(k)
	end)
	-- 4. the relic wakes and lifts (2 s)
	lib.Sound.Play("PowerUp")
	run(2, function(k)
		sess.relic = 2 + 9 * ease(k)
		sess.rglow = 0.5 + 0.8 * ease(k)
	end)
	-- 5. the timber roots tension between the pieces (2 s)
	lib.Sound.Play("Zap")
	run(2, function(k)
		sess.flex = 1.4 + 1.4 * math.sin(k * math.pi)
	end)
	-- 6. the masses briefly synchronise, still apart (2 s)
	run(2, function(k)
		sess.sync = ease(math.clamp(k * 1.5, 0, 1)) * (1 - ease(math.clamp((k - 0.7) / 0.3, 0, 1)))
		sess.stones = 1
	end)
	-- 7. the crown rises and activates (1.8 s)
	lib.Sound.Play("Chime")
	sess.crownOn = true
	run(1.8, function(k)
		sess.crown = 12 * ease(k)
		sess.rglow = 1.3 + 0.2 * k
	end)
	-- 8. one large controlled upward pulse through the whole structure (1.5 s)
	lib.Sound.Play("Boom")
	lib.Sound.Play("Meteor")
	lib.Cine.shake(0.35, 1)
	lib.Cine.bloom(0.4, 0.2, 2, 1.3)
	local base = (P * CFrame.new(0, 44, -26)).Position
	lib.Cine.ring(base, WHITE, 180, 1.5)
	local beam = Instance.new("Part")
	beam.Name = "MB_TemplePulse"
	beam.Anchored, beam.CanCollide, beam.CanQuery, beam.CanTouch, beam.CastShadow = true, false, false, false, false
	beam.Shape = Enum.PartType.Cylinder
	beam.Material = Enum.Material.Neon
	beam.Color = PALE
	beam.Size = Vector3.new(4, 40, 40)
	beam.CFrame = CFrame.new(base + up * 2) * P.Rotation * CFrame.Angles(0, 0, math.rad(90))
	beam.Parent = workspace
	table.insert(ctx.trash, beam)
	local la = lib.anchor(base + up * 110, ctx.trash)
	local fl = lib.light(la, PALE, 220, 0, ctx.trash)
	run(1.5, function(k)
		local h = 8 + 330 * ease(k)
		beam.Size = Vector3.new(h, 46 * (1 - 0.4 * k), 46 * (1 - 0.4 * k))
		beam.CFrame = CFrame.new(base + up * (h / 2)) * P.Rotation * CFrame.Angles(0, 0, math.rad(90))
		beam.Transparency = 0.45 + 0.55 * k * k
		fl.Brightness = 8 * (1 - k)
		sess.liftA = 5 + 3 * math.sin(k * math.pi)
		sess.liftB = 4 + 3 * math.sin(k * math.pi)
		sess.rglow = 1.5 * (1 - k) + 0.7 * k
	end)
	beam:Destroy()
	-- 9. settle into a quiet floating active idle (1.7 s): wings keep part of their new positions
	lib.Sound.Play("Cheer")
	run(1.7, function(k)
		local keep = 1 - 0.5 * ease(k)
		sess.wlv = toL * keep
		sess.wrv = toR * keep
		sess.wly = math.rad(-9) * keep
		sess.wry = math.rad(12) * keep
		sess.liftA = 5 * (1 - ease(k)) * 0.6
		sess.liftB = 4 * (1 - ease(k)) * 0.6
		sess.relic = 11 - 5 * ease(k)
		sess.crown = 12 - 4 * ease(k)
		sess.rglow = 0.7
		sess.flex = 1.4
	end)
	sess.paused = false
end

return Show
