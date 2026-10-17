--!nonstrict
-- TITAN MECH FOUNDRY show. Industrial, deliberate motion: the factory works on the mech; the mech never walks away.
-- Poses are composed per frame from each part's original CFrame.
-- Activation (~35%): the machinery wakes: the tower light strips come on bottom to top and pulse, the beacons blink and the idle
-- hoist hooks sway.
-- Milestone 1 (~60%, torso and head exist): the mech's reactor core starts to glow and the hanging head's eye flickers on.
-- Milestone 2 (~82%, assembly arms exist): the three assembly arms sync into a shared work rhythm with welding flickers; the
-- suspended arm sways on its hoist.
-- Completion (Foundry Birth, ~15.5 s): the gantry rolls the arm into position; the assembly arms lock it and it seats on the
-- shoulder; the core surges; the clamps release, the hoists let go and the head drops into its socket; the mech rises a little,
-- its head powers on, it raises its fist and stomps; the factory lights answer in a cascade. Powered idle afterwards.
local Show = {}

local GLOW0 = Color3.fromRGB(70, 40, 20)
local AMBER = Color3.fromRGB(255, 150, 40)
local HOT = Color3.fromRGB(255, 236, 190)

local LO = Vector3.new(-18, 26, -6) -- the suspended arm's hanging offset from its seat (template space)
local HEAD_DROP = 5
local CLAMP_OUT = 22

local function glow(p: BasePart, k: number)
	p.Color = GLOW0:Lerp(AMBER, math.clamp(k, 0, 1)):Lerp(HOT, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.2 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

local function ease(k: number): number
	k = math.clamp(k, 0, 1)
	return k * k * (3 - 2 * k)
end

local function lerp(a: number, b: number, k: number): number
	return a + (b - a) * k
end

local HANGING = { lift = 0, arm = 0, limb = 0, gantry = 0, cable = 0, headCable = 0, head = 0, clamp = 0, asm = { 0, 0, 0 }, sway = 0, headYaw = 0, hook = 0 }
local SEATED = { lift = 0, arm = 0, limb = 1, gantry = 1, cable = 1, headCable = 1, head = 1, clamp = 1, asm = { -0.5, 0.45, 0.6 }, sway = 0, headYaw = 0, hook = 0 }

local function copy(t)
	local c = table.clone(t)
	c.asm = table.clone(t.asm)
	return c
end

-- rebuild a cable bar between two moved endpoints (bars run along their LookVector, from the top end to the bottom end)
local function cable(p: BasePart, b: CFrame, topOff: Vector3, botOff: Vector3, retract: number)
	local base = p:GetAttribute("MBLen")
	if not base then
		p:SetAttribute("MBLen", p.Size.Z)
		base = p.Size.Z
	end
	local top = b.Position - b.LookVector * base / 2 + topOff
	local bot = b.Position + b.LookVector * base / 2 + botOff
	bot = bot:Lerp(top, math.clamp(retract, 0, 1) * 0.97)
	local len = math.max((bot - top).Magnitude, 0.1)
	p.Size = Vector3.new(p.Size.X, p.Size.Y, len)
	p.CFrame = CFrame.lookAt((top + bot) / 2, bot)
	p.Transparency = if retract > 0.96 then 1 else 0
end

local function isCable(p: BasePart): boolean
	return p.Size.X < 1.2 and p.Size.Y < 1.2
end

local function pose(sess, lib, o)
	local m = sess.model
	local P = m:GetPivot()
	local R = P.Rotation
	local function at(pos: Vector3, rx: number, ry: number, rz: number): CFrame
		local h = CFrame.new(pos) * R
		return h * CFrame.Angles(rx, ry, rz) * h:Inverse()
	end
	local function T(v: Vector3): CFrame
		return CFrame.new(R * v)
	end
	local function apply(name: string, X: CFrame, skipCables: boolean?)
		for _, p in lib.group(m, name) do
			local b = sess:base(p)
			if b and not (skipCables and isCable(p)) then
				p.CFrame = X * b
			end
		end
	end
	local L = T(Vector3.new(0, o.lift, 0))
	apply("Mech", L)
	local sr = lib.find(m, "ShoulderR")
	local srb = sr and sess:base(sr)
	if srb then
		apply("ArmR", L * at(srb.Position, o.arm, 0, 0))
	end
	-- the suspended arm: hangs (with sway) at limb 0, seated (riding the mech) at limb 1
	local ls = lib.find(m, "LimbSeat")
	local lsb = ls and sess:base(ls)
	local limbOff = (o.limbV or -LO * o.limb) + Vector3.new(0, o.lift * o.limb, 0)
	if lsb then
		local X = T(limbOff) * at(lsb.Position, o.sway * 0.4, 0, o.sway)
		apply("Limb", X)
	end
	local gOff = Vector3.new(-LO.X * o.gantry, 0, 0)
	for _, p in lib.group(m, "Gantry") do
		local b = sess:base(p)
		if b then
			if isCable(p) then
				cable(p, b, R * gOff, R * limbOff, o.cable)
			else
				p.CFrame = T(gOff) * b
			end
		end
	end
	local hc = lib.find(m, "HeadC")
	local hcb = hc and sess:base(hc)
	local headOff = Vector3.new(0, -HEAD_DROP * o.head + o.lift * o.head, 0)
	if hcb then
		apply("Head", T(headOff) * at(hcb.Position, 0, o.headYaw, 0))
	end
	for _, p in lib.group(m, "HeadCable") do
		local b = sess:base(p)
		if b then
			cable(p, b, Vector3.zero, R * headOff, o.headCable)
		end
	end
	for _, p in lib.group(m, "Clamp") do
		local b = sess:base(p)
		if b then
			p.CFrame = T(Vector3.new((p:GetAttribute("Side") or 1) * CLAMP_OUT * o.clamp, 0, 0)) * b
		end
	end
	for i = 1, 3 do
		local mk = lib.find(m, "Asm" .. i .. "Base")
		local mb = mk and sess:base(mk)
		if mb then
			apply("Asm" .. i, at(mb.Position, 0, o.asm[i], 0))
		end
	end
	if o.hook ~= 0 then
		local tops = {}
		for _, d in m:GetDescendants() do
			if d.Name == "HookTop" and d:IsA("BasePart") then
				table.insert(tops, sess:base(d) or d.CFrame)
			end
		end
		for _, p in lib.group(m, "Hook") do
			local b = sess:base(p)
			if b and not p:GetAttribute("Marker") then
				local best, bd = nil, math.huge
				for _, t in tops do
					local d = (t.Position - b.Position) * Vector3.new(1, 0, 1)
					if d.Magnitude < bd then
						best, bd = t, d.Magnitude
					end
				end
				if best then
					p.CFrame = at(best.Position, o.hook * 0.6, 0, o.hook) * b
				end
			end
		end
	end
end

local function lights(m, lib, k: number, wave: number?)
	for _, p in lib.group(m, "FactoryLight") do
		local ord = p:GetAttribute("Order") or 1
		local w = if wave then math.exp(-((wave - ord) ^ 2) * 1.5) else 0
		glow(p, k + w)
	end
end

function Show.Activate(sess, lib)
	sess.core, sess.sync = 0, 0
	sess.wake0 = os.clock()
	lib.Sound.Play("PowerUp")
	sess:step(function(_, t)
		local m = sess.model
		local F = sess.final
		local pw = if F then 1 else 0
		-- the tower strips come on bottom to top over the first 3 s, then pulse
		local on = math.clamp((os.clock() - sess.wake0) / 3, 0, 1)
		for _, p in lib.group(m, "FactoryLight") do
			local ord = p:GetAttribute("Order") or 1
			local lit = math.clamp(on * 3 - (ord - 1), 0, 1)
			glow(p, lit * (0.6 + 0.2 * math.sin(t * 1.6 - ord) + 0.3 * pw))
		end
		for i, p in lib.group(m, "Beacon") do
			glow(p, if (t * 1.2 + i * 0.5) % 2 < 0.6 then 1.2 else 0.15)
		end
		for _, p in lib.group(m, "Core") do
			glow(p, sess.core * (0.6 + 0.3 * math.sin(t * 1.4)) + 0.5 * pw)
		end
		for _, p in lib.group(m, "Eye") do
			local flick = if pw > 0 then 1 else (if math.sin(t * 7) + math.sin(t * 2.3) > 0.4 then 0.8 else 0.25)
			glow(p, sess.core * flick)
		end
		local S = sess.sync
		local weld = S * (if math.sin(t * 23) + math.sin(t * 9.7) > 0.6 then 1.6 else 0.25)
		for _, p in lib.group(m, "Tool") do
			glow(p, if pw > 0 then 0.3 else weld)
		end
		local o = copy(if F then SEATED else HANGING)
		-- shared work rhythm: a slow servo cycle all three arms keep in step
		local x = (t * 0.18) % 2
		local cyc = if x < 1 then ease(x) else 1 - ease(x - 1)
		for i = 1, 3 do
			o.asm[i] += S * math.rad(if i == 2 then -10 else 10) * (cyc - 0.5) * (1 - pw)
		end
		o.sway = math.rad(2.5) * S * math.sin(t * 0.6) * (1 - pw)
		o.hook = math.rad(1.6) * math.sin(t * 0.5)
		o.headYaw = math.rad(8) * pw * math.sin(t * 0.21)
		o.lift = 0
		sess.pose = o
		pose(sess, lib, o)
	end)
end

function Show.Milestone(sess, lib, n)
	local key = if n == 1 then "core" else "sync"
	lib.Sound.Play(if n == 1 then "PowerUp" else "Rumble")
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < 3 do
		sess[key] = (os.clock() - t0) / 3
		task.wait()
	end
	sess[key] = 1
end

function Show.Spectacle(ctx, sess, lib)
	if not sess or not sess.wake0 then
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
	-- start from the live idle pose (no pop): the arm and sway offsets ease out while the gantry rolls
	local from = if sess.pose then copy(sess.pose) else copy(HANGING)
	local o = copy(HANGING)
	local cores, tools, eyes, beacons = lib.group(m, "Core"), lib.group(m, "Tool"), lib.group(m, "Eye"), lib.group(m, "Beacon")
	local function sparks(part: BasePart?, n: number)
		if part then
			local a = lib.anchor(part.Position, ctx.trash)
			local e = lib.emitter(a, lib.SPARK, AMBER, 1.6, 0.6, 26, ctx.trash)
			e.SpreadAngle = Vector2.new(70, 70)
			e.LightEmission = 1
			e:Emit(n)
		end
	end
	-- 1. the gantry rolls the arm into position over its shoulder (2.5 s)
	lib.Sound.Play("Rumble")
	run(2.5, function(k, t)
		local e = ease(k)
		o.gantry = e
		o.limb = 0
		local f = ease(k / 0.6)
		o.sway = from.sway * (1 - f)
		o.hook = from.hook * (1 - f)
		for i = 1, 3 do
			o.asm[i] = from.asm[i] * (1 - f)
		end
		for i, p in beacons do
			glow(p, if (t * 3 + i) % 1 < 0.5 then 1.4 else 0.2)
		end
		o.limbV = Vector3.new(-LO.X * e, 0, -LO.Z * e) -- still hanging: it slides sideways with the trolley
		pose(sess, lib, o)
	end)
	-- 2. the assembly arms swing in and lock it; it lowers onto the shoulder (2 s)
	lib.Sound.Play("Thud")
	run(2, function(k)
		local e = ease(k)
		o.asm = { lerp(0, math.rad(-8), e), lerp(0, math.rad(10), e), lerp(0, math.rad(6), e) }
		for _, p in tools do
			glow(p, 0.8 + 0.8 * math.abs(math.sin(k * 30)))
		end
		o.limbV = Vector3.new(-LO.X, -LO.Y * e, -LO.Z) -- only the drop remains
		pose(sess, lib, o)
	end)
	o.limbV = nil
	o.limb = 1
	lib.Sound.Play("Boom")
	lib.Cine.shake(0.3, 0.5)
	sparks(lib.find(m, "LimbSeat"), 60)
	for _, p in tools do
		sparks(p, 20)
	end
	-- 3. the core surges (1.8 s)
	lib.Sound.Play("PowerUp")
	local core = cores[1]
	local cl = core and lib.light(core, AMBER, 70, 0, ctx.trash)
	run(1.8, function(k)
		for _, p in cores do
			glow(p, 0.8 + 1.2 * k)
		end
		if cl then
			cl.Brightness = 6 * k
		end
		pose(sess, lib, o)
	end)
	if core then
		lib.Cine.ring(core.Position, AMBER, 80, 0.9)
	end
	-- 4. the clamps release, the hoists let go and the head drops into its socket (2.2 s)
	lib.Sound.Play("Zap")
	run(2.2, function(k)
		o.clamp = ease(k / 0.5)
		o.cable = ease((k - 0.2) / 0.5)
		o.head = ease((k - 0.45) / 0.35)
		o.headCable = ease((k - 0.75) / 0.25)
		pose(sess, lib, o)
	end)
	lib.Sound.Play("Thud")
	lib.Cine.shake(0.2, 0.3)
	-- 5. the mech rises a little as the arms swing clear (1.6 s)
	lib.Sound.Play("Rumble")
	lib.Cine.shake(0.12, 1.6)
	local asm0 = table.clone(o.asm)
	run(1.6, function(k)
		local e = ease(k)
		o.lift = 3 * e
		for i = 1, 3 do
			o.asm[i] = lerp(asm0[i], SEATED.asm[i], e)
		end
		pose(sess, lib, o)
	end)
	-- 6. the head powers on and looks across the crowd (1.2 s)
	lib.Sound.Play("Chime")
	run(1.2, function(k)
		for _, p in eyes do
			glow(p, 0.3 + 1.5 * ease(k / 0.3))
		end
		o.headYaw = math.rad(14) * math.sin(k * math.pi)
		pose(sess, lib, o)
	end)
	-- 7. the big pose: the fist rises, then one stomp as the mech settles (2.4 s)
	local stomped = false
	run(2.4, function(k)
		o.arm = math.rad(105) * ease(k / 0.45) * (1 - ease((k - 0.75) / 0.25))
		o.lift = if k < 0.55 then 3 + 1.5 * ease(k / 0.55) else 4.5 * (1 - ease((k - 0.55) / 0.12))
		if k > 0.62 and not stomped then
			stomped = true
			lib.Sound.Play("Boom")
			lib.Sound.Play("Thud")
			lib.Cine.shake(0.55, 0.7)
			lib.Cine.ring(P.Position + Vector3.new(0, 2, 0), AMBER, 260, 1.6)
			lib.Cine.bloom(0.35, 0.15, 0.8, 0.8)
		end
		pose(sess, lib, o)
	end)
	-- 8. the factory answers: a light cascade up both towers, beacons, then the powered idle (1.8 s)
	lib.Sound.Play("Cheer")
	run(1.8, function(k)
		lights(m, lib, 0.9, k * 4.5)
		for _, p in beacons do
			glow(p, 1.5)
		end
		for _, p in cores do
			glow(p, 2 - 0.6 * k)
		end
		if cl then
			cl.Brightness = 6 - 3 * k
		end
		o.lift = 0
		o.arm = 0
		pose(sess, lib, o)
	end)
	sess.final = true
	sess.core = 1
	sess.paused = false
end

return Show
