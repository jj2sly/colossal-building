--!nonstrict
-- SKY GALLEON show. Activation (~45%): the lift system wakes: the cores under the envelopes pulse teal with a soft hum.
-- Milestone 1 (~75%): the propellers start turning, the engine exhausts glow and the hull unloads from its cradle (it lifts a
-- little and floats with a slow bob). Completion (Galleon Lift): the propellers spin up, the ship rises ~18 studs clear of the
-- dock with a slight nose-up, engines flare, it drifts forward and rolls gently while hovering, then settles back on the cradle.
-- Every pose is composed per frame from each part's original CFrame (no drift).
local Show = {}

local CORE = Color3.fromRGB(40, 82, 92)
local TEAL = Color3.fromRGB(90, 236, 220)
local FLARE = Color3.fromRGB(255, 170, 70)

local function glow(p: BasePart, from: Color3, to: Color3, k: number)
	p.Color = from:Lerp(to, math.clamp(k, 0, 1))
	p.Material = if k > 0.2 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

-- the craft (everything but the cradle) and the propellers (with their centres)
local function parts(sess)
	local now = os.clock()
	if sess.craft and now - sess.craftAt < 1 then
		return sess.craft
	end
	local list = {}
	for _, d in sess.model:GetDescendants() do
		if d:IsA("BasePart") then
			local ground, prop = false, nil
			local a = d.Parent
			while a and a ~= sess.model do
				if a.Name == "Ground" then
					ground = true
				elseif a.Name == "Prop" then
					prop = a
				end
				a = a.Parent
			end
			if not ground then
				table.insert(list, { part = d, prop = prop })
			end
		end
	end
	sess.craft, sess.craftAt = list, now
	return list
end

-- lift (studs up), drift (studs along the ship), pitch / roll (rad), spin (prop angle, rad)
local function pose(sess, lift: number, drift: number, pitch: number, roll: number, spin: number)
	local P = sess.model:GetPivot()
	local R = P.Rotation
	local c = (P * CFrame.new(0, 60, 0)).Position
	local h = CFrame.new(c) * R
	local H = CFrame.new(0, lift, 0) * CFrame.new(R:VectorToWorldSpace(Vector3.new(drift, 0, 0))) * h * CFrame.Angles(roll, 0, pitch) * h:Inverse()
	local centres = {}
	for _, it in parts(sess) do
		local b = sess:base(it.part)
		if b then
			local cf = b
			if it.prop and spin ~= 0 then
				local pc = centres[it.prop]
				if pc == nil then
					local mk = it.prop:FindFirstChild("PropC")
					local mb = mk and sess:base(mk)
					pc = if mb then CFrame.new(mb.Position) * R else false
					centres[it.prop] = pc
				end
				if pc then
					cf = pc * CFrame.Angles(spin, 0, 0) * pc:Inverse() * cf
				end
			end
			it.part.CFrame = H * cf
		end
	end
end

function Show.Activate(sess, lib)
	sess.engines = 0
	sess.spin = 0
	lib.Sound.Play("PowerUp")
	local lights = {}
	sess:step(function(dt, t)
		for i, p in lib.group(sess.model, "LiftCore") do
			glow(p, CORE, TEAL, 0.65 + 0.3 * math.sin(t * 1.6 + i))
			if not lights[p] then
				lights[p] = lib.light(p, TEAL, 30, 1, sess.trash)
			end
		end
		local E = sess.engines
		if E > 0 then
			sess.spin += dt * 4 * E
			for _, p in lib.group(sess.model, "Exhaust") do
				glow(p, CORE, FLARE, 0.6 * E + 0.2 * math.sin(t * 6))
			end
			pose(sess, 0.8 * E + 0.35 * math.sin(t * 1.1) * E, 0, 0, math.rad(0.5) * math.sin(t * 0.7) * E, sess.spin)
		end
	end)
end

function Show.Milestone(sess, lib, n)
	if n ~= 1 then
		return
	end
	lib.Sound.Play("Rumble")
	lib.Sound.Play("Zap")
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < 2.5 do
		sess.engines = (os.clock() - t0) / 2.5
		task.wait()
	end
	sess.engines = 1
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local P = m:GetPivot()
	local spin = sess.spin or 0
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
	local exh, cores = lib.group(m, "Exhaust"), lib.group(m, "LiftCore")
	local LIFT = 18
	-- 1. spin-up (1.2 s)
	lib.Sound.Play("PowerUp")
	lib.Sound.Play("Rumble")
	run(1.2, function(k, t, dt)
		spin += dt * (4 + 16 * k)
		for _, p in cores do
			glow(p, CORE, TEAL, 0.8 + 0.4 * k)
		end
		for _, p in exh do
			glow(p, CORE, FLARE, 0.6 + 0.5 * k)
		end
		pose(sess, 0.8 + 0.3 * math.sin(t * 20) * k, 0, 0, 0, spin)
	end)
	-- 2. lift-off (3 s): clear of the dock, slight nose-up, engines flare
	lib.Cine.shake(0.15, 1.2)
	lib.Cine.ring(P.Position + Vector3.new(0, 1, 0), TEAL, 190, 1.8)
	lib.Cine.bloom(0.3, 0.3, 2, 1.5)
	for _, p in exh do
		local a = lib.emitter(p, lib.SMOKE, Color3.fromRGB(200, 200, 205), 6, 2.2, 10, ctx.trash)
		a.Rate = 14
		task.delay(6, function()
			a.Rate = 0
		end)
	end
	run(3, function(k, t, dt)
		spin += dt * 20
		local e = ease(k)
		pose(sess, 0.8 + (LIFT - 0.8) * e, 0, math.rad(2.5) * math.sin(k * math.pi), 0, spin)
	end)
	-- 3. hover and drift (2.8 s)
	lib.Sound.Play("Zap")
	run(2.8, function(k, t, dt)
		spin += dt * 16
		pose(sess, LIFT + 1.4 * math.sin(t * 2.2), 9 * math.sin(k * math.pi), 0, math.rad(2) * math.sin(t * 1.6), spin)
	end)
	-- 4. settle on the cradle (2.3 s)
	run(2.3, function(k, t, dt)
		spin += dt * (16 - 12 * k)
		local e = ease(k)
		pose(sess, LIFT * (1 - e) + 0.8 * e, 0, 0, 0, spin)
		for _, p in exh do
			glow(p, CORE, FLARE, 1.1 - 0.5 * k)
		end
	end)
	lib.Sound.Play("Thud")
	lib.Cine.shake(0.12, 0.4)
	lib.Sound.Play("Cheer")
	sess.spin = spin
	sess.paused = false
end

return Show
