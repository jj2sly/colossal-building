--!nonstrict
-- WORLD TREE show. Activation (~40%): the tree stirs: a slow sway in the branches (and the canopy, once grown) and a few
-- drifting leaves. Milestone 1 (~65%): the branches start a slow living motion and the ancient heartwood core wakes with a warm
-- glow. Milestone 2 (~82%): the crown breathes (the canopy masses swell and settle), the hanging vines sway and the blossoms glow.
-- Completion (Bloom, ~12 s): the crown draws in, then spreads and settles into its final pose with the branches lifting; an
-- enormous golden pulse rises from the roots up the trunk into the crown; a sweep of golden leaves crosses the crown; soft
-- golden light; everything eases back to its living sway.
-- Every pose is composed per frame from each part's original CFrame (no drift).
local Show = {}

local CORE0 = Color3.fromRGB(86, 64, 34)
local AMBER = Color3.fromRGB(255, 190, 80)
local GOLD = Color3.fromRGB(255, 222, 130)
local LEAFC = Color3.fromRGB(150, 210, 90)

local function glow(p: BasePart, k: number, base: Color3)
	p.Color = base:Lerp(AMBER, math.clamp(k, 0, 1)):Lerp(GOLD, math.clamp(k - 1, 0, 1))
	p.Material = if k > 0.3 then Enum.Material.Neon else Enum.Material.SmoothPlastic
end

-- o = { sway (rad), lift (rad, branches raise their tips), breathe (scale delta for leaves), vine (rad) }
local function pose(sess, lib, o, t: number)
	local m = sess.model
	local P = m:GetPivot()
	local R = P.Rotation
	for i = 1, 6 do
		local root = lib.find(m, "BranchRoot" .. i)
		local rb = root and sess:base(root)
		if rb then
			local lp = P:PointToObjectSpace(rb.Position)
			local out = Vector3.new(lp.X, 0, lp.Z)
			out = if out.Magnitude > 0.1 then out.Unit else Vector3.xAxis
			-- the tip rises when we rotate about the horizontal axis perpendicular to the branch direction
			local axis = Vector3.yAxis:Cross(out)
			local a = (o.sway or 0) * math.sin(t * 0.6 + i * 1.3) + (o.lift or 0)
			local h = CFrame.new(rb.Position) * R
			local X = h * CFrame.fromAxisAngle(axis, -a) * CFrame.Angles(0, (o.sway or 0) * 0.6 * math.sin(t * 0.45 + i), 0) * h:Inverse()
			for _, p in lib.group(m, "Branch" .. i) do
				local b = sess:base(p)
				if b then
					p.CFrame = X * b
				end
			end
		end
	end
	local cp = lib.find(m, "CrownPivot")
	local cb = cp and sess:base(cp)
	if cb then
		local h = CFrame.new(cb.Position) * R
		local X = h * CFrame.Angles((o.sway or 0) * 0.5 * math.sin(t * 0.5), 0, (o.sway or 0) * 0.5 * math.sin(t * 0.4 + 1)) * h:Inverse()
		for _, p in lib.group(m, "Crown") do
			local b = sess:base(p)
			if b then
				p.CFrame = X * b
			end
		end
	end
	for i, p in lib.group(m, "Vine") do
		local b = sess:base(p)
		if b then
			local top = b * CFrame.new(0, p.Size.Y / 2, 0)
			local a = (o.vine or 0) * math.sin(t * 1.1 + i)
			p.CFrame = top * CFrame.Angles(a, 0, a * 0.6) * top:Inverse() * b
		end
	end
	if o.breathe then
		sess.leaves = sess.leaves or {}
		for _, d in m:GetDescendants() do
			if d:IsA("SpecialMesh") and d.Parent:GetAttribute("Leaf") then
				local s = 1 + o.breathe * (0.6 + 0.4 * math.sin(t * 0.9 + d.Parent.Position.X * 0.05))
				d.Scale = Vector3.new(s, s * 0.9 + 0.1, s)
			end
		end
	end
end

function Show.Activate(sess, lib)
	sess.life, sess.crown = 0, 0
	lib.Sound.Play("Chime")
	local leafE
	sess:step(function(_, t)
		local m = sess.model
		if not leafE then
			local cp = lib.find(m, "CrownPivot")
			if cp then
				local a = lib.anchor(cp.Position + Vector3.new(0, 20, 0), sess.trash)
				leafE = lib.emitter(a, lib.SPARK, LEAFC, 1.6, 6, 6, sess.trash)
				leafE.SpreadAngle = Vector2.new(180, 60)
				leafE.Acceleration = Vector3.new(2, -3, 1)
				leafE.Rate = 3
			end
		end
		for _, p in lib.group(m, "Core") do
			glow(p, 0.2 + sess.life * (0.8 + 0.25 * math.sin(t * 1.2)), CORE0)
		end
		for _, p in lib.group(m, "Bloom") do
			glow(p, sess.crown * (0.5 + 0.2 * math.sin(t * 1.4)), Color3.fromRGB(222, 186, 82))
		end
		pose(sess, lib, {
			sway = math.rad(0.8) + math.rad(1.8) * sess.life,
			breathe = if sess.crown > 0 then 0.035 * sess.crown * math.sin(t * 0.8) else nil,
			vine = math.rad(6) * sess.crown,
		}, t)
	end)
end

function Show.Milestone(sess, lib, n)
	local key = if n == 1 then "life" else "crown"
	lib.Sound.Play(if n == 1 then "ChimeLow" else "Chime")
	if n == 1 then
		local c = lib.group(sess.model, "Core")[1]
		if c then
			lib.light(c, AMBER, 34, 1.4, sess.trash)
		end
	end
	local t0 = os.clock()
	while sess.alive() and os.clock() - t0 < 3 do
		sess[key] = (os.clock() - t0) / 3
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
	local cores, blooms = lib.group(m, "Core"), lib.group(m, "Bloom")
	local SW = math.rad(2.6)
	-- 1. the crown draws in (1.6 s)
	lib.Sound.Play("ChimeLow")
	run(1.6, function(k, t)
		local e = ease(k)
		for _, p in cores do
			glow(p, 1 + 0.8 * e, CORE0)
		end
		pose(sess, lib, { sway = SW, lift = math.rad(-2.5) * e, breathe = -0.06 * e, vine = math.rad(4) }, t)
	end)
	-- 2. the golden pulse rises from the roots, up the trunk and into the crown (3 s)
	lib.Sound.Play("Rumble")
	lib.Cine.ring(P.Position + Vector3.new(0, 2, 0), GOLD, 200, 1.6)
	local col = Instance.new("Part")
	col.Name = "MB_TreePulse"
	col.Anchored, col.CanCollide, col.CanQuery, col.CanTouch, col.CastShadow = true, false, false, false, false
	col.Shape = Enum.PartType.Cylinder
	col.Material = Enum.Material.Neon
	col.Color = GOLD
	col.Transparency = 1
	col.Parent = workspace
	table.insert(ctx.trash, col)
	local glowAnchor = lib.anchor(P.Position, ctx.trash)
	local gl = lib.light(glowAnchor, GOLD, 120, 0, ctx.trash)
	run(3, function(k, t)
		local y = 10 + 190 * ease(k)
		col.Size = Vector3.new(y, 26 - 10 * k, 26 - 10 * k)
		col.CFrame = CFrame.new(P.Position + Vector3.new(0, y / 2, 0)) * CFrame.Angles(0, 0, math.rad(90))
		col.Transparency = 0.45 + 0.4 * k
		glowAnchor.Position = P.Position + Vector3.new(0, y, 0)
		gl.Brightness = 3 + 2 * k
		pose(sess, lib, { sway = SW, lift = math.rad(-2.5) * (1 - k), breathe = -0.06 * (1 - k), vine = math.rad(5) }, t)
	end)
	col.Transparency = 1
	-- 3. the crown spreads and settles into its final pose; golden leaves sweep across; blossoms flare (3.6 s)
	lib.Sound.Play("Boom")
	lib.Sound.Play("Chime")
	lib.Cine.bloom(0.35, 0.3, 2, 1.5)
	local crownC = (P * CFrame.new(0, 170, 0)).Position
	lib.Cine.ring(crownC, GOLD, 240, 2.2)
	local sweep = lib.anchor(crownC, ctx.trash)
	local leaves = lib.emitter(sweep, lib.SPARK, GOLD, 2.4, 3.5, 14, ctx.trash)
	leaves.SpreadAngle = Vector2.new(90, 40)
	leaves.Acceleration = Vector3.new(0, -4, 0)
	leaves.LightEmission = 0.6
	leaves.Rate = 70
	run(3.6, function(k, t)
		local spread = math.sin(math.clamp(k / 0.55, 0, 1) * math.pi * 0.5)
		local settle = if k > 0.55 then ease((k - 0.55) / 0.45) else 0
		local lift = math.rad(4) * spread * (1 - 0.6 * settle)
		local br = 0.09 * spread * (1 - 0.7 * settle)
		local a = k * math.pi * 2
		sweep.Position = crownC + (P.RightVector * math.cos(a) + P.LookVector * math.sin(a)) * 70
		for _, p in blooms do
			glow(p, 1.4 + 0.6 * math.sin(k * math.pi), Color3.fromRGB(222, 186, 82))
		end
		gl.Brightness = 5 * (1 - 0.5 * k)
		pose(sess, lib, { sway = SW * 1.4, lift = lift, breathe = br, vine = math.rad(9) }, t)
	end)
	leaves.Rate = 0
	-- 4. ease back to the living sway (2.4 s)
	lib.Sound.Play("Cheer")
	run(2.4, function(k, t)
		local e = 1 - ease(k)
		gl.Brightness = 2.5 * e
		for _, p in cores do
			glow(p, 1 + 0.8 * e, CORE0)
		end
		pose(sess, lib, { sway = SW, lift = math.rad(1.6) * e, breathe = 0.027 * e, vine = math.rad(6) }, t)
	end)
	sess.paused = false
end

return Show
