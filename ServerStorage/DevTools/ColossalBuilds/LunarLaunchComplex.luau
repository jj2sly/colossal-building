--!nonstrict
-- LUNAR LAUNCH COMPLEX (Legendary). An enormous, thick moon rocket (core 34 across, ~215 tall with its escape tower) standing
-- left of centre on a broad launch base over a deep flame trench, with a heavy orange launch gantry offset to its right
-- (shorter than the rocket, ~196 to the crane), three big service arms bridging the clear air gap to the rocket, two strap-on
-- boosters, and low wide fuel spheres. Facing -Z (the spawn); the trench mouth and its deflector open toward the spawn.
-- Groups for the client show: Rocket (everything that rises: stages, boosters, capsule, engine bells; markers Vent1/Vent2/Vent3),
-- Engine (engine glow discs, inside Rocket), Arm1..Arm3 (service arms, marker ArmHingeN on the gantry face), PadLight (pad lamps),
-- Beacon (gantry top beacon), Trench (marker TrenchMouth: where the exhaust leaves the trench).
return {
	Id = "LunarLaunchComplex",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, cylZ, ell, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.cylZ, K.ell, K.wedge
		local WHITE, WHITE2, BAND, GREY = RGB(228, 228, 222), RGB(206, 206, 200), RGB(48, 50, 56), RGB(168, 170, 174)
		local CONC, CONC2, DARK, RED = RGB(138, 136, 130), RGB(112, 110, 106), RGB(40, 40, 44), RGB(186, 72, 40)
		local RED2, TANK, GLOW0 = RGB(150, 56, 34), RGB(214, 214, 208), RGB(60, 56, 54)
		local m = K.template("LunarLaunchComplex")
		local RX, GX = -20, 36 -- rocket axis x, gantry tower centre x
		local BASE = 12 -- launch base top

		-- 1 LAUNCH FOUNDATION / FLAME TRENCH: a broad two-part launch base split by a deep flame trench under the rocket, a
		-- curved deflector that throws the exhaust out of the trench mouth toward the spawn, hold-down pedestals and pad lamps
		local s1 = K.stage(m, 1)
		box(s1, V(54, BASE, 96), CFrame.new(RX - 14 - 27, BASE / 2, 0), CONC, M.Concrete)
		box(s1, V(86, BASE, 96), CFrame.new(RX + 14 + 43, BASE / 2, 0), CONC, M.Concrete)
		box(s1, V(28, BASE, 40), CFrame.new(RX, BASE / 2, 28), CONC, M.Concrete) -- trench back wall / bridge
		box(s1, V(28, 2, 56), CFrame.new(RX, 1, -20), DARK, M.Slate) -- trench floor
		wedge(s1, V(28, 10, 26), CFrame.new(RX, 6, 1) * CFrame.Angles(0, 0, 0), CONC2, M.Concrete) -- deflector
		local trench = K.group(s1, "Trench")
		K.marker(trench, "TrenchMouth", V(RX, 6, -46), V(0, 0, -1))
		for _, sx in { -1, 1 } do
			box(s1, V(8, 6, 8), CFrame.new(RX + sx * 19, BASE + 3, 0), CONC2, M.Concrete)
		end
		box(s1, V(150, 2, 100), CFrame.new(0, 0.5, 0), CONC2, M.Concrete) -- apron
		for _, p in { { -66, -44 }, { 22, -46 }, { 74, -44 }, { -66, 44 } } do
			local l = K.group(s1, "PadLight")
			box(l, V(4, 3, 4), CFrame.new(p[1], BASE + 1.5, p[2]), GLOW0, M.SmoothPlastic)
		end

		local rocket2 = K.group(K.stage(m, 2), "Rocket")
		local rocket3 = K.group(K.stage(m, 3), "Rocket")
		local rocket4 = K.group(K.stage(m, 4), "Rocket")
		local rocket5 = K.group(K.stage(m, 5), "Rocket")

		-- 2 LOWER ROCKET: the fat first stage (34 across, y 22..96) with two strap-on boosters and black roll-pattern panels
		cyl(rocket2, 34, 74, CFrame.new(RX, 59, 0), WHITE, M.SmoothPlastic)
		box(rocket2, V(12, 28, 1), CFrame.new(RX - 9, 40, -16.8), BAND, M.SmoothPlastic)
		box(rocket2, V(12, 28, 1), CFrame.new(RX + 9, 76, -16.8), BAND, M.SmoothPlastic)
		cyl(rocket2, 36, 4, CFrame.new(RX, 24, 0), BAND, M.Metal)
		for _, sx in { -1, 1 } do
			cyl(rocket2, 16, 62, CFrame.new(RX + sx * 26, 55, 0), WHITE2, M.SmoothPlastic)
			ell(rocket2, V(16, 22, 16), CFrame.new(RX + sx * 26, 86, 0), WHITE2, M.SmoothPlastic)
			box(rocket2, V(4, 6, 4), CFrame.new(RX + sx * 19.5, 80, 0), BAND, M.Metal)
		end
		K.marker(rocket2, "Vent1", V(RX - 17, 88, -4), V(-1, 0, -0.3))

		-- 3 MIDDLE ROCKET: a dark interstage and the second stage (30 across, y 100..150)
		cyl(rocket3, 35, 5, CFrame.new(RX, 98.5, 0), BAND, M.Metal)
		cyl(rocket3, 30, 50, CFrame.new(RX, 126, 0), WHITE, M.SmoothPlastic)
		box(rocket3, V(10, 20, 1), CFrame.new(RX - 8, 120, -14.8), BAND, M.SmoothPlastic)
		K.marker(rocket3, "Vent2", V(RX + 15, 146, -4), V(1, 0, -0.3))

		-- 4 UPPER ROCKET: a second interstage and the third stage (26 across, y 153..180) with a service module band
		cyl(rocket4, 31, 4, CFrame.new(RX, 152, 0), BAND, M.Metal)
		cyl(rocket4, 26, 26, CFrame.new(RX, 167, 0), WHITE, M.SmoothPlastic)
		cyl(rocket4, 27, 4, CFrame.new(RX, 178, 0), GREY, M.Metal)
		K.marker(rocket4, "Vent3", V(RX - 13, 170, -4), V(-1, 0, -0.3))

		-- 5 CAPSULE / NOSE: the capsule cone and the launch escape tower
		ell(rocket5, V(26, 36, 26), CFrame.new(RX, 180, 0), WHITE2, M.SmoothPlastic)
		cyl(rocket5, 4, 16, CFrame.new(RX, 205, 0), BAND, M.Metal)
		ell(rocket5, V(6, 8, 6), CFrame.new(RX, 214, 0), RED, M.SmoothPlastic)

		-- 6 GANTRY MAIN TOWER: a heavy orange tower (20 x 20) offset right of the rocket with a dark lift core, belt floors
		-- every ~30 studs and a hammerhead crane on top (to y ~196, shorter than the rocket)
		local s6 = K.stage(m, 6)
		box(s6, V(28, 6, 28), CFrame.new(GX, BASE + 3, 0), CONC2, M.Concrete)
		for _, dx in { -1, 1 } do
			for _, dz in { -1, 1 } do
				box(s6, V(5, 172, 5), CFrame.new(GX + dx * 8.5, BASE + 6 + 86, dz * 8.5), RED, M.Metal)
			end
		end
		box(s6, V(10, 172, 10), CFrame.new(GX, BASE + 6 + 86, 0), DARK, M.Metal)
		for _, y in { 50, 80, 110, 140, 170 } do
			box(s6, V(24, 4, 24), CFrame.new(GX, y, 0), RED2, M.Metal)
		end
		box(s6, V(26, 6, 26), CFrame.new(GX, 193, 0), RED2, M.Metal)
		box(s6, V(46, 5, 7), CFrame.new(GX + 6, 199.5, 0), RED, M.Metal)

		-- 7 SERVICE ARMS: three big service arms from the gantry face to the rocket, each with a swing-hinge on the tower
		local s7 = K.stage(m, 7)
		for i, a in { { 80, 6, 10 }, { 140, 6, 9 }, { 172, 5, 8 } } do
			local arm = K.group(s7, "Arm" .. i)
			local hinge = V(GX - 12, a[1], 0)
			local tipX = if i == 1 then RX + 17 else if i == 2 then RX + 15 else RX + 13
			box(arm, V(hinge.X - tipX, a[2], a[3]), CFrame.new((hinge.X + tipX) / 2, a[1], 0), RED, M.Metal)
			box(arm, V(6, a[2] + 4, a[3] + 4), CFrame.new(tipX + 3, a[1], 0), RED2, M.Metal) -- clamp head
			K.marker(arm, "ArmHinge" .. i, hinge)
		end

		-- 8 SUPPORT / FUELING STRUCTURES: two big low fuel spheres on stands, their feed lines to the gantry and a support wing
		local s8 = K.stage(m, 8)
		for _, p in { { 62, -30 }, { 64, 30 } } do
			for _, dx in { -1, 1 } do
				box(s8, V(3, 14, 3), CFrame.new(p[1] + dx * 8, BASE + 7, p[2]), GREY, M.Metal)
			end
			ell(s8, V(30, 28, 30), CFrame.new(p[1], BASE + 26, p[2]), TANK, M.Metal)
			bar(s8, V(p[1] - 14, BASE + 18, p[2] * 0.6), V(GX + 10, 30, p[2] * 0.25), 3, GREY, M.Metal)
		end
		box(s8, V(28, 22, 30), CFrame.new(-66, BASE + 11, 26), CONC2, M.Concrete) -- control bunker
		wedge(s8, V(28, 8, 12), CFrame.new(-66, BASE + 4, 5) * CFrame.Angles(0, math.rad(180), 0), CONC2, M.Concrete)

		-- 9 FINAL LAUNCH SYSTEMS: engine bells and their glow discs under the core and boosters, launch clamps and the gantry beacon
		local s9 = K.stage(m, 9)
		local bells = K.group(s9, "Rocket")
		for _, e in { { 0, 14 }, { -26, 9 }, { 26, 9 } } do
			cyl(bells, e[2] + 6, 8, CFrame.new(RX + e[1], 18, 0), BAND, M.Metal)
			local g = K.group(bells, "Engine")
			cyl(g, e[2], 1, CFrame.new(RX + e[1], 13.6, 0), GLOW0, M.SmoothPlastic)
		end
		for _, sx in { -1, 1 } do
			box(s9, V(6, 10, 10), CFrame.new(RX + sx * 20, BASE + 5, -14), RED2, M.Metal)
		end
		local beacon = K.group(s9, "Beacon")
		ell(beacon, V(5, 5, 5), CFrame.new(GX + 28, 203, 0), GLOW0, M.SmoothPlastic)
		return m
	end,
}
