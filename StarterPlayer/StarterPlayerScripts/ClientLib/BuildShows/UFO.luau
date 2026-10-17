--!nonstrict
-- UFO show. Activation (~45%): the eight rim panels and (once built) the dome core come alive with a slow cyan chase.
-- Milestone 1 (~75%): a low hover vibration through the whole craft and the underside emitter starts to glow.
-- Completion (Hover): power-up, the craft lifts ~22 studs off its pad as the legs retract into the hull, holds a slow
-- turning hover while the halo ring spins and a pulse chases round it, a tractor beam touches the pad, then it settles back.
-- Every pose is composed per frame from each part's original CFrame (no drift).
local Show = {}

local PANEL = Color3.fromRGB(44, 78, 90)
local CYAN = Color3.fromRGB(110, 236, 255)
local WHITE = Color3.fromRGB(220, 252, 255)

-- the craft: every part except the landing pad; legs are flagged so they can retract
local function craft(sess)
	local now = os.clock()
	if sess.craft and now - sess.craftAt < 1 then
		return sess.craft
	end
	local list = {}
	for _, d in sess.model:GetDescendants() do
		if d:IsA("BasePart") then
			local inGround, leg, halo = false, false, false
			local a = d.Parent
			while a and a ~= sess.model do
				if a.Name == "Ground" then
					inGround = true
				elseif string.match(a.Name, "^Leg%d$") then
					leg = true
				elseif a.Name == "Halo" then
					halo = true
				end
				a = a.Parent
			end
			if not inGround then
				table.insert(list, { part = d, leg = leg, halo = halo })
			end
		end
	end
	sess.craft, sess.craftAt = list, now
	return list
end

-- lift/bob: studs up; yaw: whole-craft turn (rad); retract: legs up into the hull (studs); spin: extra halo turn (rad)
local function pose(sess, lift: number, yaw: number, retract: number, spin: number)
	local P = sess.model:GetPivot()
	local o = CFrame.new(P.Position) * P.Rotation
	local H = CFrame.new(0, lift, 0) * o * CFrame.Angles(0, yaw, 0) * o:Inverse()
	local S = o * CFrame.Angles(0, spin, 0) * o:Inverse()
	for _, c in craft(sess) do
		local b = sess:base(c.part)
		if b then
			local cf = b
			if c.leg and retract ~= 0 then
				cf = CFrame.new(0, retract, 0) * cf
			elseif c.halo and spin ~= 0 then
				cf = S * cf
			end
			c.part.CFrame = H * cf
		end
	end
end

local function glow(p: BasePart, k: number)
	p.Color = PANEL:Lerp(CYAN, math.clamp(k, 0, 1)):Lerp(WHITE, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.2 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

local function angleOf(P: CFrame, p: BasePart): number
	local l = P:PointToObjectSpace(p.Position)
	return math.atan2(l.Z, l.X)
end

function Show.Activate(sess, lib)
	sess.hover = 0
	lib.Sound.Play("PowerUp")
	local P = sess.model:GetPivot()
	local coreLight
	sess:step(function(_, t)
		for _, p in lib.group(sess.model, "RimLight") do
			glow(p, 0.45 + 0.45 * math.sin(t * 1.6 - angleOf(P, p) * 2))
		end
		local core = lib.group(sess.model, "Core")
		for _, p in core do
			glow(p, 0.75 + 0.25 * math.sin(t * 2.2))
		end
		if not coreLight and core[1] then
			coreLight = lib.light(core[1], CYAN, 40, 1.5, sess.trash)
		end
		if sess.hover > 0 then
			for _, p in lib.group(sess.model, "Beam") do
				glow(p, (0.5 + 0.4 * math.sin(t * 3)) * sess.hover)
			end
			-- low hover vibration: a fast shiver on a slow breath
			pose(sess, sess.hover * (0.22 * math.sin(t * 23) + 0.45 * math.sin(t * 1.4)), 0, 0, 0)
		end
	end)
end

function Show.Milestone(sess, lib, n)
	if n ~= 1 then
		return
	end
	lib.Sound.Play("Zap")
	lib.Sound.Play("Rumble")
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < 2 do
		sess.hover = (os.clock() - t0) / 2
		task.wait()
	end
	sess.hover = 1
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
	local rims, cores, beams, halos = lib.group(m, "RimLight"), lib.group(m, "Core"), lib.group(m, "Beam"), lib.group(m, "Halo")
	local haloCol = {}
	for _, h in halos do
		haloCol[h] = { h.Color, h.Material }
	end
	local function rimChase(t: number, speed: number, base: number)
		for _, p in rims do
			glow(p, base + 0.6 * math.sin(t * speed - angleOf(P, p) * 2))
		end
	end
	local LIFT, RETRACT = 22, 24
	-- 1. power-up (1.2 s)
	lib.Sound.Play("PowerUp")
	lib.Cine.bloom(0.35, 0.3, 1.5, 1.5)
	run(1.2, function(k, t)
		rimChase(t, 4 + 8 * k, 0.6 + 0.5 * k)
		for _, p in cores do
			glow(p, 1 + 0.6 * k)
		end
		for _, p in beams do
			glow(p, k)
		end
		pose(sess, 0.3 * math.sin(t * 30) * k, 0, 0, 0)
	end)
	-- 2. lift-off (2.6 s): rise, legs retract
	lib.Sound.Play("Rumble")
	lib.Cine.shake(0.15, 1.2)
	lib.Cine.ring(P.Position + Vector3.new(0, 1, 0), CYAN, 170, 1.8)
	run(2.6, function(k, t)
		local e = ease(k)
		rimChase(t + 1.2, 12, 1.1)
		pose(sess, LIFT * e + 0.15 * math.sin(t * 25), 0, RETRACT * ease(math.clamp(k * 1.3, 0, 1)), 0)
	end)
	-- 3. hover (3.2 s): slow turn, halo spins with a chasing pulse, a tractor beam touches the pad
	lib.Sound.Play("Zap")
	local beamC = lib.find(m, "BeamC")
	local beamPart
	if beamC then
		local top = beamC.Position
		beamPart = Instance.new("Part")
		beamPart.Name = "MB_TractorBeam"
		beamPart.Anchored, beamPart.CanCollide, beamPart.CanQuery, beamPart.CanTouch, beamPart.CastShadow = true, false, false, false, false
		beamPart.Shape = Enum.PartType.Cylinder
		beamPart.Material = Enum.Material.Neon
		beamPart.Color = CYAN
		beamPart.Transparency = 1
		local h = top.Y - P.Position.Y
		beamPart.Size = Vector3.new(h, 22, 22)
		beamPart.CFrame = CFrame.new(P.Position + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		beamPart.Parent = workspace
		table.insert(ctx.trash, beamPart)
	end
	local pulsed = false
	run(3.2, function(k, t)
		local yaw = math.rad(28) * ease(k)
		local spin = -math.rad(70) * k
		pose(sess, LIFT + 1.2 * math.sin(t * 2.2), yaw, RETRACT, spin)
		rimChase(t + 4, 10, 1.2)
		-- the energy pulse: a bright band chasing round the halo
		local head = (t * 2.6) % (math.pi * 2) - math.pi
		for _, h in halos do
			local d = math.abs(((angleOf(P, h) - head + math.pi) % (math.pi * 2)) - math.pi)
			local g = math.exp(-(d / 0.5) ^ 2)
			if g > 0.15 then
				h.Material = Enum.Material.Neon
				h.Color = haloCol[h][1]:Lerp(CYAN, g)
			else
				h.Material = haloCol[h][2]
				h.Color = haloCol[h][1]
			end
		end
		if beamPart then
			local bk = math.clamp(math.sin(math.clamp((k - 0.25) / 0.6, 0, 1) * math.pi), 0, 1)
			beamPart.Transparency = 1 - 0.55 * bk
			-- the beam follows the craft's height
			local c = beamC.Position
			local h = c.Y - P.Position.Y
			beamPart.Size = Vector3.new(h, 22, 22)
			beamPart.CFrame = CFrame.new(P.Position + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
			if bk > 0.9 and not pulsed then
				pulsed = true
				lib.Cine.ring(P.Position + Vector3.new(0, 1, 0), WHITE, 190, 1.6)
				lib.Sound.Play("Boom")
			end
		end
	end)
	for _, h in halos do
		h.Color, h.Material = haloCol[h][1], haloCol[h][2]
	end
	if beamPart then
		beamPart.Transparency = 1
	end
	-- 4. settle (2.2 s): descend, legs extend, turn back
	run(2.2, function(k, t)
		local e = ease(k)
		pose(sess, LIFT * (1 - e) + 1.2 * math.sin((t + 3.2) * 2.2) * (1 - e), math.rad(28) * (1 - e), RETRACT * (1 - ease(math.clamp((k - 0.2) / 0.8, 0, 1))), -math.rad(70) * (1 - e))
		rimChase(t + 7, 4, 0.8)
	end)
	pose(sess, 0, 0, 0, 0)
	lib.Cine.shake(0.15, 0.4)
	lib.Sound.Play("Thud")
	lib.Sound.Play("Cheer")
	task.wait(0.4)
	sess.paused = false
end

return Show
