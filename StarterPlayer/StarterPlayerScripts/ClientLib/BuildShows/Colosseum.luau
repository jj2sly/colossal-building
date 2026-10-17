--!nonstrict
-- COLOSSEUM show. Activation (~45%): the eight torch braziers ignite one after another around the ring and keep flickering.
-- Milestone 1 (~75%): the banners start to sway, a slow glow wave travels round the torches and every few seconds a soft
-- crowd cheer rises with a few sparks over the stands. Completion (Arena Wave): three drum beats, then a stadium-wide light
-- wave sweeps the ring twice (the upper ring band glows gold as it passes, each torch flares, a bright light rides along
-- above the stands with gold sparks),
-- the banners snap outward on the beats, the flags whip, and a final gold ring and cheer.
local Show = {}

local FLAME = Color3.fromRGB(255, 98, 22)
local HOTF = Color3.fromRGB(255, 196, 96)
local GOLD = Color3.fromRGB(255, 214, 110)

local function torches(sess, P: CFrame)
	local now = os.clock()
	if sess.torches and now - sess.torchAt < 1 then
		return sess.torches
	end
	local list = {}
	for _, d in sess.model:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("Flame") then
			local l = P:PointToObjectSpace(d.Position)
			table.insert(list, { part = d, ang = math.atan2(l.Z, l.X), mesh = d:FindFirstChildOfClass("SpecialMesh") })
		end
	end
	table.sort(list, function(a, b)
		return a.ang < b.ang
	end)
	sess.torches, sess.torchAt = list, now
	return list
end

-- k: 0 = out, 1 = burning, 2 = flaring
local function flame(tc, k: number, t: number)
	local p = tc.part
	if k <= 0.02 then
		p.Transparency = 1
		return
	end
	p.Transparency = 0.05
	local f = 1 + 0.12 * math.sin(t * 13 + tc.ang * 5) + 0.08 * math.sin(t * 21 + tc.ang)
	local s = math.clamp(k, 0, 2.4) * f
	if tc.mesh then
		tc.mesh.Scale = Vector3.new(0.8 + 0.25 * s, 0.6 + 0.5 * s, 0.8 + 0.25 * s)
	end
	p.Color = FLAME:Lerp(HOTF, math.clamp(k - 1, 0, 1))
	if tc.light then
		tc.light.Brightness = 0.8 * k * f
		tc.light.Range = 14 + 8 * math.clamp(k - 1, 0, 1)
	end
end

local function wrap(d: number): number
	return ((d + math.pi) % (math.pi * 2)) - math.pi
end

-- banners billow outward about their top edge; flags turn about their mast edge
local function cloth(sess, lib, billow: number, flutter: number, t: number)
	for i, p in lib.group(sess.model, "Banner") do
		local b = sess:base(p)
		if b then
			local h = b * CFrame.new(0, p.Size.Y / 2, 0)
			local a = billow + 0.05 * math.sin(t * 1.7 + i)
			p.CFrame = h * CFrame.Angles(-a, 0, 0) * h:Inverse() * b
		end
	end
	for i, p in lib.group(sess.model, "Flag") do
		local b = sess:base(p)
		if b then
			local h = b * CFrame.new(-p.Size.X / 2, 0, 0)
			p.CFrame = h * CFrame.Angles(0, flutter * math.sin(t * 7 + i * 1.3), 0) * h:Inverse() * b
		end
	end
end

function Show.Activate(sess, lib)
	sess.energy = 0
	local P = sess.model:GetPivot()
	local lit = {}
	local start = os.clock()
	lib.Sound.Play("Chime")
	local nextCheer = 0
	sess:step(function(_, t)
		local list = torches(sess, P)
		for i, tc in list do
			if not lit[tc.part] and os.clock() - start > (i - 1) * 0.3 then
				lit[tc.part] = true
				tc.light = lib.light(tc.part, FLAME, 14, 0, sess.trash)
				lib.Sound.Play("Click")
			end
			if lit[tc.part] then
				local wave = 0
				if sess.energy > 0 then
					wave = sess.energy * 0.6 * math.exp(-(wrap(tc.ang - t * 0.9) / 0.7) ^ 2)
				end
				flame(tc, 1 + wave, t)
			else
				flame(tc, 0, t)
			end
		end
		if sess.energy > 0 then
			cloth(sess, lib, math.rad(6) * sess.energy * (0.5 + 0.5 * math.sin(t * 0.8)), math.rad(18) * sess.energy, t)
			if t > nextCheer then
				nextCheer = t + 7
				lib.Sound.Play("Cheer")
				local ang = t * 0.9
				local pos = P * CFrame.new(math.cos(ang) * 55, 46, math.sin(ang) * 45)
				local a = lib.anchor(pos.Position, sess.trash)
				local e = lib.emitter(a, lib.SPARK, GOLD, 1.6, 1.8, 18, sess.trash)
				e.SpreadAngle = Vector2.new(50, 50)
				e:Emit(14)
				task.delay(3, function()
					a:Destroy()
				end)
			end
		end
	end)
end

function Show.Milestone(sess, lib, n)
	if n ~= 1 then
		return
	end
	lib.Sound.Play("Cheer")
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < 2.5 do
		sess.energy = (os.clock() - t0) / 2.5
		task.wait()
	end
	sess.energy = 1
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local P = m:GetPivot()
	local list = torches(sess, P)
	for _, tc in list do
		if not tc.light then
			tc.light = lib.light(tc.part, FLAME, 14, 0, ctx.trash)
		end
	end
	local function run(seconds: number, fn)
		local t0 = os.clock()
		while os.clock() - t0 < seconds and ctx.alive() do
			fn((os.clock() - t0) / seconds, os.clock() - t0)
			task.wait()
		end
		fn(1, seconds)
	end
	-- 1. three drum beats; the torches dip and jump with each
	local beats = 0
	run(1.5, function(k, t)
		local beat = (k * 3) % 1
		if k < 1 and math.floor(k * 3) >= beats then
			beats += 1
			lib.Sound.Play("Thud")
			lib.Cine.shake(0.12, 0.2)
		end
		for _, tc in list do
			flame(tc, 0.5 + 1.2 * math.exp(-beat * 8), t)
		end
		cloth(sess, lib, 0, math.rad(10), t)
	end)
	-- 2. the wave: twice round the ring in 4.6 s, a bright light and gold sparks ride along above the stands
	local rider = lib.anchor(P.Position, ctx.trash)
	local rl = lib.light(rider, HOTF, 90, 0, ctx.trash)
	-- the upper ring band carries the visible wave: each segment glows gold as the wave passes
	local band = {}
	for _, p in lib.group(m, "Band") do
		local l = P:PointToObjectSpace(p.Position)
		table.insert(band, { part = p, ang = math.atan2(l.Z, l.X), col = p.Color, mat = p.Material })
	end
	local sparks = lib.emitter(rider, lib.SPARK, GOLD, 1.8, 1.6, 16, ctx.trash)
	sparks.SpreadAngle = Vector2.new(60, 60)
	sparks.LightEmission = 1
	sparks.Rate = 45
	lib.Sound.Play("Cheer")
	local snaps = { 0.15, 0.45, 0.75 }
	local snapped = {}
	local start = -math.pi / 2 -- begins at the gate (template -Z)
	run(4.6, function(k, t)
		local w = start + k * math.pi * 4
		for _, tc in list do
			local d = wrap(tc.ang - w)
			flame(tc, 1 + 1.3 * math.exp(-(d / 0.55) ^ 2), t)
		end
		rider.Position = (P * CFrame.new(math.cos(w) * 70, 50, math.sin(w) * 56)).Position
		rl.Brightness = 5
		for _, sg in band do
			local g = math.exp(-(wrap(sg.ang - w) / 0.45) ^ 2)
			if g > 0.3 then
				sg.part.Material = Enum.Material.Neon
				sg.part.Color = sg.col:Lerp(GOLD, 0.35 + 0.5 * g)
			else
				sg.part.Material = sg.mat
				sg.part.Color = sg.col:Lerp(GOLD, g)
			end
		end
		local billow = 0
		for i, s in snaps do
			local dk = k - s
			if dk >= 0 and dk < 0.12 then
				billow = math.max(billow, math.sin(dk / 0.12 * math.pi) * math.rad(38))
				if not snapped[i] then
					snapped[i] = true
					lib.Sound.Play("Thud")
				end
			end
		end
		cloth(sess, lib, billow, math.rad(32), t)
	end)
	sparks.Rate = 0
	for _, sg in band do
		sg.part.Material, sg.part.Color = sg.mat, sg.col
	end
	-- 3. finale: every torch flares, gold ring, a burst of sparks over the stands, the crowd roars
	lib.Sound.Play("Boom")
	lib.Sound.Play("Cheer")
	lib.Cine.bloom(0.3, 0.2, 0.8, 1.2)
	lib.Cine.ring(P.Position + Vector3.new(0, 2, 0), GOLD, 210, 1.8)
	for _, ang in { 0, 1.57, 3.14, 4.71 } do
		local a = lib.anchor((P * CFrame.new(math.cos(ang) * 40, 44, math.sin(ang) * 32)).Position, ctx.trash)
		local e = lib.emitter(a, lib.SPARK, GOLD, 2, 2, 26, ctx.trash)
		e.SpreadAngle = Vector2.new(70, 70)
		e.LightEmission = 1
		e:Emit(30)
	end
	run(math.max(1.5, ctx.duration - 6.1), function(k, t)
		for _, tc in list do
			flame(tc, 2.2 - 1.2 * k, t)
		end
		rl.Brightness = 3 * (1 - k)
		cloth(sess, lib, math.rad(14) * (1 - k), math.rad(24), t)
	end)
	sess.paused = false
end

return Show
