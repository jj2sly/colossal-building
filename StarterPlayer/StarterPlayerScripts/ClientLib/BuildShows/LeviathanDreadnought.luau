--!nonstrict
-- LEVIATHAN DREADNOUGHT show. Activation (~40%): the rear engines warm (a slow orange glow) with a low hum.
-- Milestone 1 (~65%): the power conduits light with a cyan chase along the hull and the fin engines wake.
-- Milestone 2 (~82%): the ship unloads its weight from the cradle: it lifts a stud and holds a low vibration; the reactor glows.
-- Completion (Ignition, ~12 s): the engines spool from orange to white over a rising rumble, IGNITION (a flash, a shock ring
-- and long thrust plumes behind every nozzle), the dreadnought rises ~10 studs with its nose up a touch and holds against
-- strong thrust while the conduits race, then throttles down and settles back on its cradle. It never leaves the site.
local Show = {}

local GLOW0 = Color3.fromRGB(40, 52, 70)
local WARM = Color3.fromRGB(255, 120, 40)
local HOT = Color3.fromRGB(255, 236, 200)
local CYAN = Color3.fromRGB(90, 220, 255)

local function glow(p: BasePart, to: Color3, k: number)
	p.Color = GLOW0:Lerp(to, math.clamp(k, 0, 1)):Lerp(HOT, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.2 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

local function craft(sess)
	local now = os.clock()
	if sess.craft and now - sess.craftAt < 1 then
		return sess.craft
	end
	local list = {}
	for _, d in sess.model:GetDescendants() do
		if d:IsA("BasePart") and not d:FindFirstAncestor("Ground") then
			table.insert(list, d)
		end
	end
	sess.craft, sess.craftAt = list, now
	return list
end

-- lift (studs), pitch (rad, + = nose up; the bow is the template +X), shiver (studs)
local function pose(sess, lift: number, pitch: number)
	local P = sess.model:GetPivot()
	local h = CFrame.new((P * CFrame.new(-20, 40, 0)).Position) * P.Rotation
	local H = CFrame.new(0, lift, 0) * h * CFrame.Angles(0, 0, pitch) * h:Inverse()
	for _, p in craft(sess) do
		local b = sess:base(p)
		if b then
			p.CFrame = H * b
		end
	end
end

function Show.Activate(sess, lib)
	sess.power, sess.unload = 0, 0
	lib.Sound.Play("Rumble")
	local lights = {}
	sess:step(function(_, t)
		local m = sess.model
		for _, p in lib.group(m, "Engine") do
			glow(p, WARM, 0.55 + 0.15 * math.sin(t * 1.4) + 0.25 * sess.unload)
			if not lights[p] and p.Size.Y > 14 then
				lights[p] = lib.light(p, WARM, 30, 1, sess.trash)
			end
		end
		if sess.power > 0 then
			local P = m:GetPivot()
			for _, p in lib.group(m, "Conduit") do
				glow(p, CYAN, sess.power * (0.6 + 0.4 * math.sin(t * 3)))
			end
			for _, p in lib.group(m, "Engine2") do
				glow(p, CYAN, sess.power * (0.7 + 0.2 * math.sin(t * 2)))
			end
			local _ = P
		end
		for _, p in lib.group(m, "Reactor") do
			glow(p, CYAN, 0.3 + 0.7 * sess.unload * (0.8 + 0.2 * math.sin(t * 2.5)))
		end
		if sess.unload > 0 then
			local U = sess.unload
			pose(sess, 1.2 * U + 0.12 * U * math.sin(t * 27) + 0.3 * U * math.sin(t * 0.9), math.rad(0.2) * U * math.sin(t * 0.6))
		end
	end)
end

function Show.Milestone(sess, lib, n)
	local key = if n == 1 then "power" else "unload"
	lib.Sound.Play(if n == 1 then "Zap" else "Rumble")
	if n == 2 then
		lib.Cine.shake(0.12, 1.2)
	end
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < 2.5 do
		sess[key] = (os.clock() - t0) / 2.5
		task.wait()
	end
	sess[key] = 1
end

function Show.Spectacle(ctx, sess, lib)
	if not sess then
		return
	end
	local m = ctx.model
	local P = m:GetPivot()
	local engines, conduits, fins = lib.group(m, "Engine"), lib.group(m, "Conduit"), lib.group(m, "Engine2")
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
	local back = -P.RightVector -- thrust goes out the stern (template -X)
	local plumes = {}
	for _, e in engines do
		local pl = Instance.new("Part")
		pl.Name = "MB_Plume"
		pl.Anchored, pl.CanCollide, pl.CanQuery, pl.CanTouch, pl.CastShadow = true, false, false, false, false
		pl.Shape = Enum.PartType.Cylinder
		pl.Material = Enum.Material.Neon
		pl.Color = Color3.fromRGB(170, 220, 255)
		pl.Transparency = 1
		pl.Parent = workspace
		table.insert(ctx.trash, pl)
		table.insert(plumes, { part = pl, eng = e })
	end
	local function plume(k: number, t: number)
		for _, pp in plumes do
			local e = pp.eng
			local d = e.Size.Y * 0.8
			local len = 4 + 46 * k * (1 + 0.08 * math.sin(t * 30 + d))
			pp.part.Size = Vector3.new(len, d, d)
			pp.part.CFrame = CFrame.lookAt(e.Position + back * (len / 2), e.Position + back * len) * CFrame.Angles(0, math.rad(90), 0)
			pp.part.Transparency = 1 - 0.55 * math.clamp(k * 1.4, 0, 1)
		end
	end
	local U = sess.unload or 0
	-- 1. spool (2.6 s): engines climb from orange to white, conduits race, rising rumble
	lib.Sound.Play("PowerUp")
	lib.Sound.Play("Rumble")
	run(2.6, function(k, t)
		for _, p in engines do
			glow(p, WARM, 0.7 + 0.9 * k + 0.1 * math.sin(t * 20))
		end
		for i, p in conduits do
			glow(p, CYAN, 0.6 + 0.5 * k + 0.3 * math.sin(t * (4 + 10 * k) + i))
		end
		for _, p in fins do
			glow(p, CYAN, 0.9 + 0.6 * k)
		end
		pose(sess, 1.2 * U + 0.25 * k * math.sin(t * 34), 0)
	end)
	-- 2. IGNITION
	lib.Sound.Play("Boom")
	lib.Sound.Play("Meteor")
	lib.Cine.shake(0.55, 0.9)
	lib.Cine.bloom(0.5, 0.1, 1.5, 1.5)
	local stern = (P * CFrame.new(-125, 45, 0)).Position
	lib.Cine.ring(stern, HOT, 160, 1.4)
	lib.Cine.ring(P.Position + Vector3.new(0, 2, 0), CYAN, 230, 2)
	local ea = lib.anchor(stern + back * 8, ctx.trash)
	local heat = lib.emitter(ea, lib.SMOKE, Color3.fromRGB(200, 200, 210), 18, 2.5, 30, ctx.trash)
	heat.EmissionDirection = Enum.NormalId.Front
	ea.CFrame = CFrame.lookAt(ea.Position, ea.Position + back)
	heat.SpreadAngle = Vector2.new(20, 20)
	heat.Rate = 22
	lib.light(ea, HOT, 90, 5, ctx.trash)
	-- 3. rise (2.6 s) with the nose up a touch, full thrust
	run(2.6, function(k, t)
		local e = ease(k)
		plume(math.clamp(k * 3, 0, 1), t)
		for _, p in engines do
			glow(p, WARM, 2)
		end
		pose(sess, 1.2 * U + (10 - 1.2 * U) * e + 0.2 * math.sin(t * 30), math.rad(1.6) * e)
	end)
	-- 4. hold against the thrust (2.8 s): heavy vibration, conduits race
	run(2.8, function(k, t)
		plume(1, t)
		for i, p in conduits do
			glow(p, CYAN, 1.2 + 0.5 * math.sin(t * 14 + i))
		end
		pose(sess, 10 + 0.8 * math.sin(t * 2.4) + 0.25 * math.sin(t * 29), math.rad(1.6) + math.rad(0.5) * math.sin(t * 1.7))
	end)
	heat.Rate = 0
	-- 5. throttle down and settle on the cradle (3 s)
	lib.Sound.Play("Rumble")
	run(3, function(k, t)
		local e = ease(k)
		plume(1 - e, t)
		for _, p in engines do
			glow(p, WARM, 2 - 1.2 * e)
		end
		pose(sess, 10 * (1 - e) + 1.2 * e, math.rad(1.6) * (1 - e))
	end)
	plume(0, 0)
	lib.Sound.Play("Thud")
	lib.Cine.shake(0.2, 0.4)
	lib.Sound.Play("Cheer")
	sess.paused = false
end

return Show
