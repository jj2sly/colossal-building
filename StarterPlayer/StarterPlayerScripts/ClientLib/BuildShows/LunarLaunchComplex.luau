--!nonstrict
-- LUNAR LAUNCH COMPLEX show. Activation (~40%): the pad lamps come on and the rocket vents thin white wisps.
-- Milestone 1 (~68%, once the service arms exist): the service arms swing slightly in and out on their hinges.
-- Milestone 2 (~84%): launch systems wake: stronger venting, the gantry beacon blinks red, the pad lamps turn red, the engine
-- bells warm faintly, a low rumble.
-- Completion (Liftoff, ~12.5 s): the service arms swing clear; a big 3-2-1 countdown over the pad with lamp flashes; IGNITION
-- (white engines, a flash, shock and dust rings, long plumes into the trench and a billow of exhaust out of the trench mouth);
-- the rocket rises ~20 studs on full thrust and holds there, then sinks back onto the pad as the engines shut down.
-- It never leaves the site. Every pose is composed per frame from each part's original CFrame (no drift).
local Show = {}

local GLOW0 = Color3.fromRGB(60, 56, 54)
local AMBER = Color3.fromRGB(255, 176, 70)
local REDL = Color3.fromRGB(255, 60, 40)
local FIRE = Color3.fromRGB(255, 150, 60)
local HOT = Color3.fromRGB(255, 244, 214)
local STEAM = Color3.fromRGB(236, 236, 236)

local function glow(p: BasePart, col: Color3, k: number)
	p.Color = GLOW0:Lerp(col, math.clamp(k, 0, 1)):Lerp(HOT, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.2 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

-- rise (studs), arms (rad swing about each hinge, + = away from the rocket toward the back)
local function pose(sess, lib, rise: number, arms: number, shake: number)
	local m = sess.model
	local P = m:GetPivot()
	local R = P.Rotation
	local up = P.UpVector * (rise + shake)
	for _, p in lib.group(m, "Rocket") do
		local b = sess:base(p)
		if b then
			p.CFrame = b + up
		end
	end
	for i = 1, 3 do
		local h = lib.find(m, "ArmHinge" .. i)
		local hb = h and sess:base(h)
		if hb then
			local H = CFrame.new(hb.Position) * R
			local X = H * CFrame.Angles(0, arms * (1 + 0.15 * (i - 2)), 0) * H:Inverse()
			for _, p in lib.group(m, "Arm" .. i) do
				local b = sess:base(p)
				if b then
					p.CFrame = X * b
				end
			end
		end
	end
end

local function vents(sess, lib, trash, rate: number)
	sess.vents = sess.vents or {}
	for i = 1, 3 do
		local mk = lib.find(sess.model, "Vent" .. i)
		if mk and not sess.vents[i] then
			local e = lib.emitter(mk, lib.SMOKE, STEAM, 5, 2.4, 6, trash)
			e.EmissionDirection = Enum.NormalId.Front
			e.SpreadAngle = Vector2.new(20, 20)
			e.Acceleration = Vector3.new(0, -3, 0)
			sess.vents[i] = e
		end
		if sess.vents[i] then
			sess.vents[i].Rate = rate
		end
	end
end

function Show.Activate(sess, lib)
	sess.arms, sess.prep = 0, 0
	lib.Sound.Play("Zap")
	sess:step(function(_, t)
		local m = sess.model
		vents(sess, lib, sess.trash, 1.5 + 6 * sess.prep)
		for i, p in lib.group(m, "PadLight") do
			glow(p, AMBER:Lerp(REDL, sess.prep), 0.6 + 0.3 * math.sin(t * 2 + i))
		end
		for _, p in lib.group(m, "Beacon") do
			glow(p, REDL, if sess.prep > 0 and math.sin(t * 5) > 0 then 1 else 0.05)
		end
		for _, p in lib.group(m, "Engine") do
			glow(p, FIRE, 0.3 * sess.prep * (0.7 + 0.3 * math.sin(t * 3)))
		end
		pose(sess, lib, 0, math.rad(6) * sess.arms * math.sin(t * 0.5), 0)
	end)
end

function Show.Milestone(sess, lib, n)
	local key = if n == 1 then "arms" else "prep"
	lib.Sound.Play(if n == 1 then "Thud" else "Rumble")
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
	local engines, pads = lib.group(m, "Engine"), lib.group(m, "PadLight")
	local ARMS = math.rad(70)
	-- 1. service arms swing clear (2 s)
	lib.Sound.Play("Thud")
	vents(sess, lib, ctx.trash, 10)
	run(2, function(k)
		pose(sess, lib, 0, ARMS * ease(k), 0)
	end)
	-- 2. countdown 3-2-1 (2.4 s): a big number over the pad, lamp flashes
	local top = lib.find(m, "ArmHinge3")
	local anchor = lib.anchor((top and top.Position or P.Position) + Vector3.new(0, 30, 0), ctx.trash)
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromScale(40, 20)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = HOT
	label.TextStrokeTransparency = 0.2
	label.Parent = bb
	for n = 3, 1, -1 do
		label.Text = tostring(n)
		lib.Sound.Play("Chime")
		run(0.8, function(k)
			for _, p in pads do
				glow(p, REDL, if k < 0.4 then 1.4 else 0.4)
			end
			for _, p in engines do
				glow(p, FIRE, 0.3 + 0.2 * (3 - n))
			end
			pose(sess, lib, 0, ARMS, 0)
		end)
	end
	label.Text = "IGNITION"
	-- 3. IGNITION
	lib.Sound.Play("Boom")
	lib.Sound.Play("Meteor")
	lib.Cine.shake(0.6, 1.2)
	lib.Cine.bloom(0.55, 0.1, 1.6, 1.6)
	lib.Cine.ring(P.Position + Vector3.new(0, 2, 0), HOT, 220, 1.6)
	lib.Cine.ring(P.Position + Vector3.new(0, 1, 0), STEAM, 260, 2.4)
	local mouth = lib.find(m, "TrenchMouth")
	local billow
	if mouth then
		local a = lib.anchor(mouth.Position, ctx.trash)
		a.CFrame = mouth.CFrame
		billow = lib.emitter(a, lib.SMOKE, STEAM, 22, 4, 34, ctx.trash)
		billow.EmissionDirection = Enum.NormalId.Front
		billow.SpreadAngle = Vector2.new(35, 15)
		billow.Rate = 30
		lib.light(a, FIRE, 90, 4, ctx.trash)
	end
	local plumes = {}
	for _, e in engines do
		local pl = Instance.new("Part")
		pl.Name = "MB_Plume"
		pl.Anchored, pl.CanCollide, pl.CanQuery, pl.CanTouch, pl.CastShadow = true, false, false, false, false
		pl.Shape = Enum.PartType.Cylinder
		pl.Material = Enum.Material.Neon
		pl.Color = Color3.fromRGB(255, 214, 150)
		pl.Transparency = 1
		pl.Parent = workspace
		table.insert(ctx.trash, pl)
		table.insert(plumes, { part = pl, eng = e })
	end
	local function plume(k: number, t: number)
		for _, pp in plumes do
			local e = pp.eng
			local d = e.Size.Y * 0.9
			local len = 6 + 30 * k * (1 + 0.1 * math.sin(t * 30 + d))
			local base = e.Position - Vector3.new(0, len / 2, 0)
			pp.part.Size = Vector3.new(len, d, d)
			pp.part.CFrame = CFrame.new(base) * CFrame.Angles(0, 0, math.rad(90))
			pp.part.Transparency = 1 - 0.6 * math.clamp(k * 1.5, 0, 1)
		end
	end
	-- 4. the rise (3 s): ~20 studs on full thrust
	run(3, function(k, t)
		for _, p in engines do
			glow(p, FIRE, 2)
		end
		plume(1, t)
		local e = ease(k)
		pose(sess, lib, 20 * e, ARMS, 0.25 * math.sin(t * 31))
	end)
	-- 5. hold the moment (1.6 s)
	run(1.6, function(k, t)
		plume(1, t)
		pose(sess, lib, 20 + 0.6 * math.sin(t * 3), ARMS, 0.2 * math.sin(t * 29))
	end)
	label.Text = ""
	if billow then
		billow.Rate = 6
	end
	-- 6. engines throttle down, the rocket sinks back onto the pad, arms return (2.8 s)
	lib.Sound.Play("Rumble")
	run(2.8, function(k, t)
		local e = ease(k)
		plume(1 - e, t)
		for _, p in engines do
			glow(p, FIRE, 2 - 1.8 * e)
		end
		pose(sess, lib, 20 * (1 - e), ARMS * (1 - ease(math.clamp((k - 0.4) / 0.6, 0, 1))), 0)
	end)
	plume(0, 0)
	if billow then
		billow.Rate = 0
	end
	lib.Sound.Play("Thud")
	lib.Cine.shake(0.25, 0.4)
	lib.Sound.Play("Cheer")
	sess.paused = false
end

return Show
