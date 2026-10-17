--!nonstrict
-- VOLCANO TEMPLE show. Activation (~45%): a low rumble and the first lava glow (the temple doorway, the terrace basins and,
-- once built, the crater pool) breathing slowly. Milestone 1 (~75%): the lava channels heat up and pulse DOWN the flanks, and a
-- thin smoke column rises from the crater. Completion (Eruption): a rumble build-up, a crater flare, an upward burst of lava
-- bombs that arc out and land on the slopes, a short ember fountain and smoke plume, and every lava piece at full heat.
local Show = {}

local COOL = Color3.fromRGB(96, 42, 30)
local HOT = Color3.fromRGB(255, 104, 28)
local WHITE = Color3.fromRGB(255, 218, 130)
local SMOKE = Color3.fromRGB(70, 64, 62)

local function lavaParts(sess)
	local now = os.clock()
	if sess.lava and now - sess.lavaAt < 1 then
		return sess.lava
	end
	local list = {}
	for _, d in sess.model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Lava") then
			table.insert(list, d)
		end
	end
	sess.lava, sess.lavaAt = list, now
	return list
end

-- k: 0 = cooled rock, 1 = glowing orange, 2 = white-hot
local function heat(p: BasePart, k: number)
	p.Color = COOL:Lerp(HOT, math.clamp(k, 0, 1)):Lerp(WHITE, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.25 then Enum.Material.Neon else Enum.Material.Basalt
end

-- the crater pool and the door get a point light once they exist
local function lights(sess, lib)
	if not sess.ventLight then
		local v = lib.find(sess.model, "Vent")
		if v then
			sess.ventLight = lib.light(v, HOT, 60, 0, sess.trash)
		end
	end
	if not sess.doorLight then
		local d = lib.find(sess.model, "DoorC")
		if d then
			sess.doorLight = lib.light(d, HOT, 34, 0, sess.trash)
		end
	end
end

function Show.Activate(sess, lib)
	sess.flow = 0
	lib.Sound.Play("Rumble")
	lib.Cine.shake(0.12, 1.4)
	sess:step(function(_, t)
		lights(sess, lib)
		local flow = sess.flow
		for _, p in lavaParts(sess) do
			local y = p.Position.Y
			if p:GetAttribute("Glow") then
				heat(p, 0.5 + 0.18 * math.sin(t * 1.2 + y * 0.03) + 0.35 * flow)
			else
				-- the pulse phase rises with height and falls with time: bright bands travel down the channels
				heat(p, flow * (0.62 + 0.38 * math.sin(y * 0.16 + t * 2.4)))
			end
		end
		if sess.ventLight then
			sess.ventLight.Brightness = 1.2 + 1.6 * flow + 0.3 * math.sin(t * 2)
		end
		if sess.doorLight then
			sess.doorLight.Brightness = 1.1 + 0.4 * math.sin(t * 1.2)
		end
	end)
end

function Show.Milestone(sess, lib, n)
	if n ~= 1 then
		return
	end
	lib.Sound.Play("Rumble")
	lib.Cine.shake(0.18, 1.6)
	local v = lib.find(sess.model, "Vent")
	if v then
		local a = lib.anchor(v.Position + Vector3.new(0, 8, 0), sess.trash)
		local e = lib.emitter(a, lib.SMOKE, SMOKE, 16, 7, 9, sess.trash)
		e.Rate = 3
		e.SpreadAngle = Vector2.new(10, 10)
		e.Acceleration = Vector3.new(1.5, 2, 0)
	end
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < 3 do
		sess.flow = (os.clock() - t0) / 3
		task.wait()
	end
	sess.flow = 1
end

-- height of the cone surface at radius r (template space), for landing the lava bombs
local function surface(r: number): number
	if r < 30 then
		return 79
	elseif r < 48 then
		return 88 - (r - 30) * 40 / 18
	elseif r < 66 then
		return 48 - (r - 48) * 26 / 18
	elseif r < 88 then
		return 22 - (r - 66) * 20 / 22
	end
	return 2
end

function Show.Spectacle(ctx, sess, lib)
	local m = ctx.model
	local P = m:GetPivot()
	local lava = {}
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Lava") then
			table.insert(lava, d)
		end
	end
	local vent = lib.find(m, "Vent")
	local ventPos = if vent then vent.Position else (P * CFrame.new(0, 80, 0)).Position
	local light = lib.light(lib.anchor(ventPos + Vector3.new(0, 12, 0), ctx.trash), HOT, 120, 0, ctx.trash)
	local function heatAll(base: number, t: number)
		for _, p in lava do
			heat(p, base + 0.25 * math.sin(p.Position.Y * 0.16 + t * 4))
		end
	end
	local t0 = os.clock()
	-- 1. build-up (1.6 s): rumble, shaking, the lava climbing to full heat
	lib.Sound.Play("Rumble")
	lib.Cine.shake(0.25, 1.8)
	while ctx.alive() and os.clock() - t0 < 1.6 do
		local k = (os.clock() - t0) / 1.6
		heatAll(0.6 + 0.6 * k, os.clock() - t0)
		light.Brightness = 3 * k
		task.wait()
	end
	-- 2. crater flare + upward burst
	lib.Sound.Play("Boom")
	lib.Sound.Play("Meteor")
	lib.Cine.shake(0.6, 0.9)
	lib.Cine.bloom(0.5, 0.15, 1.2, 1.5)
	lib.Cine.ring(ventPos, HOT, 120, 1.4)
	local flare = Instance.new("Part")
	flare.Name = "MB_Flare"
	flare.Anchored, flare.CanCollide, flare.CanQuery, flare.CanTouch, flare.CastShadow = true, false, false, false, false
	flare.Shape = Enum.PartType.Cylinder
	flare.Material = Enum.Material.Neon
	flare.Color = WHITE
	flare.Transparency = 0.15
	flare.Size = Vector3.new(4, 30, 30)
	flare.CFrame = CFrame.new(ventPos + Vector3.new(0, 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
	flare.Parent = workspace
	table.insert(ctx.trash, flare)
	lib.tween(flare, 0.5, { Size = Vector3.new(70, 22, 22), CFrame = CFrame.new(ventPos + Vector3.new(0, 36, 0)) * CFrame.Angles(0, 0, math.rad(90)) }, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	task.delay(0.5, function()
		if flare.Parent then
			lib.tween(flare, 1.6, { Transparency = 1, Size = Vector3.new(90, 34, 34) })
		end
	end)
	-- embers and smoke
	local ea = lib.anchor(ventPos + Vector3.new(0, 4, 0), ctx.trash)
	local embers = lib.emitter(ea, lib.SPARK, HOT, 2.4, 3, 70, ctx.trash)
	embers.SpreadAngle = Vector2.new(24, 24)
	embers.Acceleration = Vector3.new(0, -30, 0)
	embers.LightEmission = 1
	embers.Rate = 70
	local smoke = lib.emitter(ea, lib.SMOKE, SMOKE, 26, 7, 26, ctx.trash)
	smoke.SpreadAngle = Vector2.new(14, 14)
	smoke.Rate = 9
	task.delay(3, function()
		embers.Rate = 0
	end)
	task.delay(4.5, function()
		smoke.Rate = 0
	end)
	-- lava bombs: arcs out of the crater that land on the slopes and fizzle
	local bombs = {}
	local rng = Random.new()
	for i = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local sz = rng:NextNumber(4, 8)
		local b = Instance.new("Part")
		b.Name = "MB_LavaBomb"
		b.Shape = Enum.PartType.Ball
		b.Size = Vector3.new(sz, sz, sz)
		b.Anchored, b.CanCollide, b.CanQuery, b.CanTouch, b.CastShadow = true, false, false, false, false
		b.Material = Enum.Material.Neon
		b.Color = HOT:Lerp(WHITE, rng:NextNumber(0, 0.6))
		b.Position = ventPos
		b.Parent = workspace
		table.insert(ctx.trash, b)
		local hs = rng:NextNumber(14, 34)
		table.insert(bombs, {
			part = b,
			vel = Vector3.new(math.cos(a) * hs, rng:NextNumber(70, 100), math.sin(a) * hs),
			pos = ventPos,
			delay = (i - 1) * 0.07,
			landed = false,
		})
	end
	local t1 = os.clock()
	local last = t1
	while ctx.alive() and os.clock() - t1 < 4.2 do
		local now = os.clock()
		local dt = math.min(now - last, 0.05)
		last = now
		local tt = now - t1
		heatAll(1.45, now - t0)
		light.Brightness = 6 - 2.5 * math.clamp(tt / 4.2, 0, 1)
		for _, bb in bombs do
			if not bb.landed and tt >= bb.delay then
				bb.vel += Vector3.new(0, -62, 0) * dt
				bb.pos += bb.vel * dt
				bb.part.Position = bb.pos
				local lp = P:PointToObjectSpace(bb.pos)
				if bb.vel.Y < 0 and lp.Y <= surface(Vector3.new(lp.X, 0, lp.Z).Magnitude) + 1 then
					bb.landed = true
					local s = bb.part.Size
					lib.tween(bb.part, 1.4, { Size = s * Vector3.new(1.8, 0.3, 1.8), Transparency = 1, Color = COOL })
				end
			end
		end
		task.wait()
	end
	-- 3. settle: the lava stays bright, then eases back to its flowing pulse; the crowd cheers
	lib.Sound.Play("Cheer")
	local t2 = os.clock()
	local left = math.max(1.5, ctx.duration - (t2 - t0))
	while ctx.alive() and os.clock() - t2 < left do
		local k = (os.clock() - t2) / left
		heatAll(1.45 - 0.6 * k, os.clock() - t0)
		light.Brightness = 3.5 * (1 - k)
		task.wait()
	end
	if sess then
		sess.paused = false
	end
end

return Show
