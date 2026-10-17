--!nonstrict
-- LOGGING MACHINE (Uncommon). A low, long tracked forestry machine: two chunky tracks, an orange chassis, a tall rear cab, a
-- thick two-part boom that rises to an elbow and drops to a big log grapple (clear triangle under the boom), and a pile of logs.
-- ~104 long x 80 tall x 40 deep. Long axis X (seen broadside from the spawn), cab at -X, boom reaching +X.
-- Groups for the client show: Boom (lower arm + ram), Arm2 (forearm + elbow cap), Cable, Claw (hub), TongL, TongR, HeroLog
-- (the loose log under the grapple); markers Pivot (boom foot), Elbow, Hub (grapple hub), Slew (turret centre).
return {
	Id = "LoggingMachine",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, cylZ = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.cylZ
		local ORANGE, ORANGE2, DARK, STEEL = RGB(236, 140, 36), RGB(200, 108, 28), RGB(52, 54, 60), RGB(150, 156, 166)
		local GLASS, LOG, LOGEND = RGB(120, 160, 190), RGB(122, 80, 48), RGB(190, 150, 100)
		local m = K.template("LoggingMachine")
		local SH = -26 -- shift so the whole machine (x -26 .. 78) is centred on the origin
		local function X(x: number): number
			return x + SH
		end

		-- 1 TRACKS / CHASSIS: two long chunky tracks with big end wheels, an orange chassis deck and a stone-dark undercarriage
		local s1 = K.stage(m, 1)
		for _, sz in { -1, 1 } do
			box(s1, V(46, 12, 10), CFrame.new(X(-4), 8, sz * 17), DARK, M.Metal)
			for _, ex in { -26, 18 } do
				cylZ(s1, 14, 10, CFrame.new(X(ex), 8, sz * 17), DARK, M.Metal)
			end
			for _, wx in { -16, -4, 8 } do
				cylZ(s1, 8, 10.6, CFrame.new(X(wx), 4, sz * 17), STEEL, M.Metal)
			end
		end
		box(s1, V(50, 8, 30), CFrame.new(X(-4), 14, 0), ORANGE2, M.Metal)
		box(s1, V(54, 4, 36), CFrame.new(X(-4), 20, 0), ORANGE, M.SmoothPlastic)

		-- 2 CAB: a tall rear cab with a big window, an engine block / counterweight behind it and a slewing turret ring
		local s2 = K.stage(m, 2)
		box(s2, V(20, 26, 22), CFrame.new(X(-17), 35, -2), ORANGE, M.SmoothPlastic)
		box(s2, V(2, 12, 16), CFrame.new(X(-6.6), 38, -2), GLASS, M.Glass).Transparency = 0.2
		box(s2, V(14, 2, 26), CFrame.new(X(-17), 49, -2), ORANGE2, M.SmoothPlastic)
		box(s2, V(14, 12, 28), CFrame.new(X(-34), 28, 0), ORANGE2, M.Metal) -- counterweight / engine
		cyl(s2, 24, 6, CFrame.new(X(2), 25, 0), DARK, M.Metal) -- turret ring
		K.marker(s2, "Slew", V(X(0), 25, 0))

		-- 3 BOOM: a thick lower boom up to the elbow, a ram, and the forearm dropping to the wrist. 9 studs thick, clear
		-- triangle underneath. Pivot (X(0), 28), elbow (X(24), 64), wrist (X(46), 40).
		local s3 = K.stage(m, 3)
		local P0, E, W = V(X(0), 28, 0), V(X(24), 64, 0), V(X(46), 40, 0)
		K.marker(s3, "Pivot", P0)
		K.marker(s3, "Elbow", E)
		local boom = K.group(s3, "Boom")
		bar(boom, P0, E, 9, ORANGE, M.SmoothPlastic)
		bar(boom, V(X(-8), 26, 0), V(X(15), 50, 0), 4, STEEL, M.Metal) -- ram
		cyl(boom, 12, 12, CFrame.new(P0) * CFrame.Angles(math.rad(90), 0, 0), ORANGE2, M.Metal)
		local arm2 = K.group(s3, "Arm2")
		bar(arm2, E, W, 8, ORANGE, M.SmoothPlastic)
		cyl(arm2, 13, 12, CFrame.new(E) * CFrame.Angles(math.rad(90), 0, 0), ORANGE2, M.Metal)
		box(arm2, V(12, 7, 12), CFrame.new(W), DARK, M.Metal)

		-- 4 GRAPPLE: a cable from the wrist to a heavy hub with two curved tongs (open) - the oversized claw
		local s4 = K.stage(m, 4)
		local HUB = V(X(46), 30, 0)
		K.marker(s4, "Hub", HUB)
		local cable = K.group(s4, "Cable")
		local cb = box(cable, V(2, 6, 2), CFrame.new(X(46), 36.5, 0), DARK, M.Metal)
		cb:SetAttribute("L0", 6)
		local claw = K.group(s4, "Claw")
		box(claw, V(14, 7, 14), CFrame.new(HUB), STEEL, M.Metal)
		for _, side in { -1, 1 } do
			local tong = K.group(s4, if side < 0 then "TongL" else "TongR")
			local top = HUB + V(side * 7, -2, 0)
			bar(tong, top, V(HUB.X + side * 11, HUB.Y - 11, 0), 5, STEEL, M.Metal)
			bar(tong, V(HUB.X + side * 11, HUB.Y - 11, 0), V(HUB.X + side * 6, HUB.Y - 20, 0), 5, STEEL, M.Metal)
			box(tong, V(7, 4, 9), CFrame.new(HUB.X + side * 5, HUB.Y - 21, 0), DARK, M.Metal)
		end

		-- 5 LOG LOAD: a pile of two big logs (rotated 35 degrees toward the spawn, where the boom swings) and the loose log
		-- under the grapple that the finale picks up and stacks on top
		local s5 = K.stage(m, 5)
		-- logs lie along local Z (across the grapple tongs, which squeeze along X); the pile is turned 35 degrees about the turret
		local function log(parent: Instance, center: Vector3, yaw: number, d: number, len: number, color: Color3)
			local cf = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
			cylZ(parent, d, len, cf, color, M.Wood)
			for _, e in { -1, 1 } do
				cylZ(parent, d - 0.6, 0.6, cf * CFrame.new(0, 0, e * (len / 2 + 0.2)), LOGEND, M.Wood)
			end
		end
		local ang = math.rad(35)
		local radial = V(math.cos(ang), 0, -math.sin(ang))
		local C = V(X(0), 0, 0) + radial * 46
		for _, o in { -5.5, 5.5 } do
			log(s5, V(C.X + radial.X * o, 5.5, C.Z + radial.Z * o), ang, 11, 30, LOG)
		end
		local hero = K.group(s5, "HeroLog")
		log(hero, V(X(46), 6.5, 0), 0, 13, 36, RGB(176, 116, 64)) -- the big light log the grapple stacks
		return m
	end,
}
