--!nonstrict
-- SKY CITY show. All motion is slow and majestic; poses are composed per frame from each part's original CFrame (no drift).
-- Activation (~35%): the central lift system wakes: a faint hover shiver in the central city, the underside cores glow and the
-- lift rings (once built) turn slowly.
-- Milestone 1 (~60%): the completed satellite districts start hovering independently (each its own slow bob and slight tilt).
-- Milestone 2 (~82%): the lift rings synchronise and speed up with a matched pulse, the tower and district window bands glow.
-- Completion (Ascension, ~14.5 s): rings accelerate; the whole city lifts 6 studs while the satellites drift a little outward;
-- district C (the free one, no bridge) makes a slow partial orbit round the spire while A and B sway on their bridges; the spire
-- crown peaks with a golden pulse; the city settles into a stable higher hover (and keeps C in its new place).
local Show = {}

local LIFT = Color3.fromRGB(40, 70, 90)
local CYAN = Color3.fromRGB(120, 230, 255)
local GOLD = Color3.fromRGB(255, 220, 130)
local RINGS = { RingC = "_", RingA = "A", RingB = "B", RingD = "C" }

local function glow(p: BasePart, k: number, hot: Color3?)
	p.Color = LIFT:Lerp(hot or CYAN, math.clamp(k, 0, 1))
	p.Material = if k > 0.2 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

-- every moving part with its owner ("_" = central, or a satellite key) and its ring (or nil)
local function items(sess)
	local now = os.clock()
	if sess.items and now - sess.itemsAt < 1 then
		return sess.items
	end
	local list = {}
	for _, d in sess.model:GetDescendants() do
		if d:IsA("BasePart") then
			local owner, ring, ground = "_", nil, false
			local a = d.Parent
			while a and a ~= sess.model do
				if a.Name == "Ground" then
					ground = true
				elseif a.Name == "SatA" or a.Name == "SatB" or a.Name == "SatC" then
					owner = string.sub(a.Name, 4)
				elseif RINGS[a.Name] then
					ring = a.Name
				end
				a = a.Parent
			end
			if not ground then
				table.insert(list, { part = d, owner = owner, ring = ring })
			end
		end
	end
	sess.items, sess.itemsAt = list, now
	return list
end

-- o = { lift, shiver, sats = { A = { out, bob, tilt, orbit }, ... }, ring = { RingC = ang, ... } }
local function pose(sess, lib, o)
	local m = sess.model
	local P = m:GetPivot()
	local R = P.Rotation
	local axis = CFrame.new(P.Position) * R
	local up = P.UpVector
	local liftCF = CFrame.new(up * ((o.lift or 0) + (o.shiver or 0)))
	local satX = {}
	for _, key in { "A", "B", "C" } do
		local mk = lib.find(m, "Sat" .. key .. "C")
		local b = mk and sess:base(mk)
		local so = o.sats and o.sats[key]
		if b and so then
			local flat = (b.Position - P.Position) * Vector3.new(1, 0, 1)
			local out = if flat.Magnitude > 0 then flat.Unit else Vector3.zero
			local c = CFrame.new(b.Position) * R
			local tilt = c * CFrame.Angles(so.tilt or 0, 0, (so.tilt or 0) * 0.6) * c:Inverse()
			local orbit = axis * CFrame.Angles(0, so.orbit or 0, 0) * axis:Inverse()
			satX[key] = CFrame.new(up * ((o.lift or 0) + (so.bob or 0)) + out * (so.out or 0)) * orbit * tilt
		elseif b then
			satX[key] = liftCF
		end
	end
	local ringX = {}
	for name in RINGS do
		local mk = lib.find(m, name .. "C")
		local b = mk and sess:base(mk)
		local ang = o.ring and o.ring[name] or 0
		if b and ang ~= 0 then
			local c = CFrame.new(b.Position) * R
			ringX[name] = c * CFrame.Angles(0, ang, 0) * c:Inverse()
		end
	end
	for _, it in items(sess) do
		local b = sess:base(it.part)
		if b then
			local cf = b
			if it.ring and ringX[it.ring] then
				cf = ringX[it.ring] * cf
			end
			local X = if it.owner == "_" then liftCF else (satX[it.owner] or liftCF)
			it.part.CFrame = X * cf
		end
	end
end

local function ringParts(m, lib)
	local out = {}
	for name in RINGS do
		for _, p in lib.group(m, name) do
			table.insert(out, p)
		end
	end
	return out
end

local PHASE = { A = 0, B = 2.1, C = 4.2 }

function Show.Activate(sess, lib)
	sess.sats, sess.sync = 0, 0
	sess.ang = { RingC = 0, RingA = 0, RingB = 0, RingD = 0 }
	sess.final = sess.final or { lift = 0, out = 0, orbitC = 0 }
	lib.Sound.Play("PowerUp")
	sess:step(function(dt, t)
		local m = sess.model
		local speed = 0.18 + 0.5 * sess.sync
		for name in RINGS do
			local dir = if name == "RingC" then 1 else -1
			sess.ang[name] += dt * speed * dir * (1 + 0.15 * sess.sync)
		end
		for _, p in lib.group(m, "Core") do
			glow(p, 0.55 + 0.3 * math.sin(t * 1.4))
		end
		local syncPulse = 0.5 + 0.5 * math.sin(t * 2)
		for _, p in ringParts(m, lib) do
			glow(p, sess.sync * (0.4 + 0.6 * syncPulse))
		end
		for _, p in lib.group(m, "Glow") do
			glow(p, 0.15 + 0.75 * sess.sync, GOLD)
		end
		local F = sess.final
		local sats = {}
		for key, ph in PHASE do
			sats[key] = {
				out = F.out,
				bob = sess.sats * 1.3 * math.sin(t * 0.55 + ph),
				tilt = sess.sats * math.rad(1.2) * math.sin(t * 0.4 + ph),
				orbit = if key == "C" then F.orbitC else 0,
			}
		end
		pose(sess, lib, { lift = F.lift, shiver = 0.25 * math.sin(t * 1.1) + 0.06 * math.sin(t * 17), sats = sats, ring = sess.ang })
	end)
end

function Show.Milestone(sess, lib, n)
	local key = if n == 1 then "sats" else "sync"
	lib.Sound.Play(if n == 1 then "Rumble" else "Zap")
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < 3 do
		sess[key] = (os.clock() - t0) / 3
		task.wait()
	end
	sess[key] = 1
end

function Show.Spectacle(ctx, sess, lib)
	if not sess or not sess.ang then
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
	local function ease(k: number): number
		return k * k * (3 - 2 * k)
	end
	local rings, glows, cores = ringParts(m, lib), lib.group(m, "Glow"), lib.group(m, "Core")
	local speed = 0.7
	local function spin(dt: number)
		for name in RINGS do
			local dir = if name == "RingC" then 1 else -1
			sess.ang[name] += dt * speed * dir
		end
	end
	local st = { lift = 0, out = 0, orbit = 0, sway = 0 }
	local function apply(t: number)
		local sats = {}
		for key, ph in PHASE do
			sats[key] = {
				out = st.out,
				bob = 1.3 * math.sin(t * 0.55 + ph),
				tilt = math.rad(1.2) * math.sin(t * 0.4 + ph) + (if key ~= "C" then st.sway * math.sin(t * 0.8 + ph) else 0),
				orbit = if key == "C" then st.orbit else 0,
			}
		end
		pose(sess, lib, { lift = st.lift, shiver = 0.05 * math.sin(t * 17), sats = sats, ring = sess.ang })
	end
	local T = 0
	-- 1. the lift rings accelerate (2.5 s)
	lib.Sound.Play("PowerUp")
	lib.Sound.Play("Rumble")
	run(2.5, function(k, t, dt)
		T += dt
		speed = 0.7 + 2.3 * k
		spin(dt)
		for _, p in rings do
			glow(p, 0.8 + 0.5 * k)
		end
		for _, p in cores do
			glow(p, 1 + 0.4 * k)
		end
		apply(T)
	end)
	-- 2. the whole city lifts; the satellites drift outward (3 s)
	lib.Cine.shake(0.12, 2.6)
	lib.Cine.ring(P.Position + Vector3.new(0, 1, 0), CYAN, 260, 2.4)
	run(3, function(k, t, dt)
		T += dt
		spin(dt)
		local e = ease(k)
		st.lift, st.out = 6 * e, 6 * e
		apply(T)
	end)
	-- 3. district C makes a slow partial orbit round the spire; A and B sway on their bridges (5 s)
	lib.Sound.Play("Zap")
	run(5, function(k, t, dt)
		T += dt
		spin(dt)
		st.orbit = math.rad(-55) * ease(k)
		st.sway = math.rad(1.5) * math.sin(k * math.pi)
		for _, p in glows do
			glow(p, 0.6 + 0.6 * k, GOLD)
		end
		apply(T)
	end)
	-- 4. the spire crown peaks with a golden pulse (1.6 s)
	lib.Sound.Play("Boom")
	lib.Sound.Play("Chime")
	lib.Cine.bloom(0.4, 0.2, 1, 1.2)
	local top = lib.find(m, "TowerTop")
	if top then
		local a = lib.anchor(top.Position + Vector3.new(0, st.lift, 0), ctx.trash)
		lib.light(a, GOLD, 140, 6, ctx.trash)
		lib.Cine.ring(a.Position, GOLD, 200, 1.6)
		local e = lib.emitter(a, lib.SPARK, GOLD, 2.4, 2.4, 30, ctx.trash)
		e.SpreadAngle = Vector2.new(180, 180)
		e.LightEmission = 1
		e:Emit(50)
	end
	run(1.6, function(k, t, dt)
		T += dt
		spin(dt)
		for _, p in glows do
			glow(p, 1.6 - 0.4 * k, GOLD)
		end
		apply(T)
	end)
	-- 5. settle into a stable higher hover (2.4 s); C keeps its new place
	lib.Sound.Play("Cheer")
	run(2.4, function(k, t, dt)
		T += dt
		speed = 3 - 2.3 * ease(k)
		spin(dt)
		local e = ease(k)
		st.lift = 6 - 3 * e
		st.out = 6 - 4 * e
		for _, p in rings do
			glow(p, 1.3 - 0.4 * k)
		end
		apply(T)
	end)
	sess.final = { lift = st.lift, out = st.out, orbitC = st.orbit }
	sess.paused = false
end

return Show
