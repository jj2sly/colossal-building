--!nonstrict
-- CLOCKWORK TITAN (Epic). A massive bronze-and-iron clockwork humanoid facing -Z (authored ~204 tall; BuildConfig
-- TemplateScale 0.8 -> ~163). Thick planted legs with a wide gap, a broad torso with an open chest cavity, huge shoulders
-- and arms, a readable head with round lens eyes, and three truly enormous open gears that change the silhouette:
--   Gear A (80 across) stands behind the right shoulder on an outrigger from the spine and towers out past it;
--   Gear B (54 across) stands behind the left shoulder and sticks far out past it;
--   Gear C (30 across) turns inside the open chest cavity.
-- A big pendulum swings in the gap between the legs.
-- Groups for the client show: GearA / GearB / GearC (markers GearAC / GearBC / GearCC: rotation centres, axis = template Z),
-- Pendulum (marker PendPivot), Head (marker Neck), UpperArmL/R (marker ShoulderL/R), ForearmL/R (marker ElbowL/R), Eye, Core,
-- Steam (markers SteamL/SteamR on the shoulder stacks). R = +X = the titan's own right.
return {
	Id = "ClockworkTitan",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, cylZ, ell, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.cylZ, K.ell, K.wedge
		local BRONZE, BRASS, COPPER = RGB(170, 118, 58), RGB(206, 160, 74), RGB(156, 90, 56)
		local IRON, IRON2, STEEL, CORE = RGB(62, 58, 56), RGB(84, 78, 74), RGB(122, 118, 110), RGB(110, 70, 30)
		local m = K.template("ClockworkTitan")
		local AWAY = V(0, 0, -1)
		local function limb(parent: Instance, a: Vector3, b: Vector3, w: number, d: number, col: Color3, mat)
			return box(parent, V(w, d, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b, AWAY), col, mat)
		end
		local function flank(parent: Instance, size: Vector3, c: Vector3, s: number, col: Color3)
			local Z, Y = V(-s, 0, 0), V(0, -1, 0)
			return wedge(parent, size, CFrame.fromMatrix(c, Y:Cross(Z), Y, Z), col, M.Metal)
		end
		-- an open gear in the template XY plane (axis Z): a segmented rim, square teeth, two crossed spokes and a hub; the
		-- open sectors between rim and hub are real holes
		local function gear(parent: Instance, name: string, c: Vector3, d: number, n: number, th: number, col: Color3, col2: Color3)
			local g = K.group(parent, name)
			local r = d / 2
			local rimW = math.max(4, d * 0.09)
			local rm = r - rimW / 2
			for i = 0, n - 1 do
				local a = (i + 0.5) / n * math.pi * 2
				local p = c + V(math.cos(a) * rm, math.sin(a) * rm, 0)
				local seg = 2 * rm * math.sin(math.pi / n) * 1.08
				box(g, V(seg, rimW, th), CFrame.new(p) * CFrame.Angles(0, 0, a + math.pi / 2), col, M.Metal)
				local at = i / n * math.pi * 2
				local tp = c + V(math.cos(at) * (r + 2), math.sin(at) * (r + 2), 0)
				box(g, V(rimW * 0.9, 5, th), CFrame.new(tp) * CFrame.Angles(0, 0, at + math.pi / 2), col, M.Metal)
			end
			box(g, V(d - rimW, rimW * 0.8, th * 0.8), CFrame.new(c) * CFrame.Angles(0, 0, math.rad(45)), col2, M.Metal)
			box(g, V(d - rimW, rimW * 0.8, th * 0.8), CFrame.new(c) * CFrame.Angles(0, 0, math.rad(-45)), col2, M.Metal)
			cylZ(g, math.max(8, d * 0.18), th + 3, CFrame.new(c), col2, M.Metal)
			K.marker(g, name .. "C", c)
			return g
		end

		-- 1 FEET / PLATFORM: an iron clockwork platform and two huge planted feet with toe caps and heels
		local s1 = K.stage(m, 1)
		cyl(s1, 106, 4, CFrame.new(0, 2, 0), IRON, M.DiamondPlate)
		cyl(s1, 96, 1.2, CFrame.new(0, 4.4, 0), BRASS, M.Metal)
		for _, sx in { -1, 1 } do
			box(s1, V(28, 12, 36), CFrame.new(sx * 24, 10, -2), BRONZE, M.Metal)
			wedge(s1, V(28, 9, 12), CFrame.new(sx * 24, 8.5, -26), BRASS, M.Metal)
			box(s1, V(24, 10, 8), CFrame.new(sx * 24, 9, 19), IRON2, M.Metal)
			ell(s1, V(18, 10, 18), CFrame.new(sx * 24, 18, 0), IRON, M.Metal)
		end

		-- 2 LEGS: thick shins and thighs (22-24 wide) with brass knee drums and hip joints; a 24-stud gap between them
		local s2 = K.stage(m, 2)
		for _, sx in { -1, 1 } do
			box(s2, V(22, 38, 24), CFrame.new(sx * 24, 39, 0), BRONZE, M.Metal)
			cylZ(s2, 18, 26, CFrame.new(sx * 24, 60, 0) * CFrame.Angles(0, math.rad(90), 0), BRASS, M.Metal)
			box(s2, V(24, 30, 26), CFrame.new(sx * 24, 78, 0), IRON2, M.Metal)
			ell(s2, V(22, 16, 22), CFrame.new(sx * 24, 94, 0), IRON, M.Metal)
		end

		-- 3 PELVIS / FRAME: the pelvis, a spine frame column up the back, and the GREAT GEAR (A, 80 across) on an outrigger behind the right shoulder
		local s3 = K.stage(m, 3)
		box(s3, V(62, 14, 30), CFrame.new(0, 100, 0), BRONZE, M.Metal)
		box(s3, V(10, 70, 8), CFrame.new(0, 136, 21), IRON, M.Metal)
		gear(s3, "GearA", V(68, 156, 26), 80, 14, 5, BRASS, BRONZE)
		bar(s3, V(0, 166, 26), V(68, 156, 26), 6, IRON, M.Metal) -- outrigger from the spine to the great gear's hub

		-- 4 TORSO: a broad barrel chest framed around an open cavity (30 x 30), sloped flanks and a lower torso
		local s4 = K.stage(m, 4)
		box(s4, V(44, 14, 30), CFrame.new(0, 114, 0), IRON2, M.Metal)
		for _, sx in { -1, 1 } do
			box(s4, V(15, 42, 34), CFrame.new(sx * 22.5, 141, 0), BRONZE, M.Metal)
			flank(s4, V(34, 42, 14), V(sx * 37, 141, 0), sx, BRONZE)
		end
		box(s4, V(30, 6, 34), CFrame.new(0, 123, 0), BRONZE, M.Metal)
		box(s4, V(30, 6, 34), CFrame.new(0, 159, 0), BRONZE, M.Metal)
		box(s4, V(30, 30, 3), CFrame.new(0, 141, 14), IRON, M.Metal) -- back of the cavity
		box(s4, V(104, 6, 34), CFrame.new(0, 163, 0), IRON2, M.Metal) -- shoulder beam

		-- 5 ARMS: huge shoulder pads, upper arms hanging out at an angle, elbows bent forward, massive forearms and fists
		local s5 = K.stage(m, 5)
		for _, sx in { -1, 1 } do
			local tag = if sx > 0 then "R" else "L"
			box(s5, V(30, 24, 36), CFrame.new(sx * 50, 166, 0), BRASS, M.Metal)
			local S, E, W = V(sx * 52, 154, 0), V(sx * 58, 122, -2), V(sx * 60, 90, -14)
			local up = K.group(s5, "UpperArm" .. tag)
			limb(up, S, E, 18, 20, IRON2, M.Metal)
			ell(up, V(18, 16, 18), CFrame.new(E), IRON, M.Metal)
			K.marker(up, "Shoulder" .. tag, S)
			local fore = K.group(s5, "Forearm" .. tag)
			limb(fore, E, W, 26, 28, BRONZE, M.Metal)
			limb(fore, E + (W - E).Unit * 6, E + (W - E).Unit * 13, 28.5, 30.5, BRASS, M.Metal)
			box(fore, V(22, 20, 22), CFrame.lookAt(W + (W - E).Unit * 5, W + (W - E).Unit * 6, AWAY), IRON, M.Metal)
			K.marker(fore, "Elbow" .. tag, E)
		end

		-- 6 HEAD: a neck, a big head (30 x 26 x 28) with two round lens eyes, a grille mouth and a brass crest
		local s6 = K.stage(m, 6)
		local head = K.group(s6, "Head")
		box(head, V(14, 8, 14), CFrame.new(0, 168, -2), IRON, M.Metal)
		box(head, V(30, 26, 28), CFrame.new(0, 183, -4), BRONZE, M.Metal)
		box(head, V(18, 6, 2), CFrame.new(0, 174, -18.6), IRON, M.Metal)
		wedge(head, V(6, 8, 24), CFrame.new(0, 200, -2), BRASS, M.Metal)
		for _, sx in { -1, 1 } do
			local eye = K.group(head, "Eye")
			cylZ(eye, 8, 2, CFrame.new(sx * 7.5, 186, -18.6), CORE, M.SmoothPlastic)
			cylZ(head, 11, 1.4, CFrame.new(sx * 7.5, 186, -18.2), BRASS, M.Metal)
		end
		K.marker(head, "Neck", V(0, 168, -2))

		-- 7 GIANT GEAR SYSTEM: Gear B behind the left shoulder (54 across), Gear C in the chest cavity (30 across), the drive
		-- shaft between A and B, and the great pendulum swinging between the legs
		local s7 = K.stage(m, 7)
		gear(s7, "GearB", V(-70, 150, 24), 54, 10, 5, BRONZE, BRASS)
		gear(s7, "GearC", V(0, 141, 4), 26, 8, 4, BRASS, COPPER)
		bar(s7, V(0, 166, 31), V(-70, 150, 31), 4, STEEL, M.Metal)
		local pend = K.group(s7, "Pendulum")
		bar(pend, V(0, 93, -6), V(0, 42, -6), 3, STEEL, M.Metal)
		cylZ(pend, 18, 5, CFrame.new(0, 38, -6), BRASS, M.Metal)
		K.marker(pend, "PendPivot", V(0, 93, -6))

		-- 8 CORE / FINAL MECHANISM: the glowing core behind the chest gear, a brass collar round the cavity and two steam
		-- stacks rising from the shoulder pads
		local s8 = K.stage(m, 8)
		local core = K.group(s8, "Core")
		cylZ(core, 22, 2, CFrame.new(0, 141, 11.5), CORE, M.SmoothPlastic)
		for _, p in { { 0, 156.5, 34, 3 }, { 0, 125.5, 34, 3 } } do
			box(s8, V(p[3], p[4], 4), CFrame.new(p[1], p[2], -17.5), BRASS, M.Metal)
		end
		for _, sx in { -1, 1 } do
			box(s8, V(3, 34, 4), CFrame.new(sx * 16.5, 141, -17.5), BRASS, M.Metal)
			cyl(s8, 8, 20, CFrame.new(sx * 50, 188, 8), IRON, M.Metal)
			cyl(s8, 10, 3, CFrame.new(sx * 50, 199, 8), BRASS, M.Metal)
			K.marker(s8, if sx < 0 then "SteamL" else "SteamR", V(sx * 50, 201, 8))
		end
		return m
	end,
}
