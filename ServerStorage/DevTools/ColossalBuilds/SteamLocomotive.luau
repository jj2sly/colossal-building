--!nonstrict
-- STEAM LOCOMOTIVE (Rare). A long, low classic steam engine (about 150 long, 76 tall) heading toward +X: big spoked drivers on a long
-- frame, a fat boiler (28 across) with brass bands and a smokebox, a tall rear cab with a roof, an oversized flared smokestack, a
-- cowcatcher and headlamp up front, a coal tender behind, then side rods, pistons, a steam dome, a sand dome and a whistle.
-- Groups for the client show: Wheel (each wheel is its own Model with marker WheelC at its centre; drivers carry a crank pin),
-- Rod (the two side rods, which move as a parallelogram), markers StackTop, Whistle, CylL, CylR (steam puff points).
return {
	Id = "SteamLocomotive",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, cylZ, ell, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.cylZ, K.ell, K.wedge
		local BLACK, DARKG, RED, BRASS, STEEL = RGB(40, 42, 48), RGB(66, 70, 78), RGB(176, 44, 40), RGB(214, 170, 60), RGB(150, 156, 168)
		local GREEN, WOOD, COAL, GLASS = RGB(34, 96, 70), RGB(132, 92, 56), RGB(30, 30, 34), RGB(120, 160, 190)
		local m = K.template("SteamLocomotive")
		local rot = CFrame.Angles
		local ALONG = rot(0, math.rad(90), 0) -- cylZ lies along the CFrame's Z: this makes it lie along X

		-- a wheel: its own Model (group) with the rim, hub, two spokes and (drivers) a crank pin; marker WheelC at the centre
		local function wheel(stage: Instance, cx: number, cy: number, cz: number, d: number, pin: boolean)
			local w = K.group(stage, "Wheel")
			local c = CFrame.new(cx, cy, cz)
			cylZ(w, d, 3, c, DARKG, M.Metal)
			cylZ(w, d * 0.32, 4.2, c, STEEL, M.Metal)
			K.box(w, V(d * 0.94, d * 0.16, 3.6), c, STEEL, M.Metal)
			K.box(w, V(d * 0.16, d * 0.94, 3.6), c, STEEL, M.Metal)
			if pin then
				cylZ(w, 3.2, 4.8, CFrame.new(cx + 5, cy, cz + math.sign(cz) * 1.2), BRASS, M.Metal)
			end
			K.marker(w, "WheelC", V(cx, cy, cz))
		end

		-- 1 WHEELS / FRAME: a long frame deck (118 x 4 x 24), side frames, three big drivers a side (22 across), a leading pair and buffers
		local s1 = K.stage(m, 1)
		box(s1, V(118, 4, 24), CFrame.new(11, 17, 0), BLACK, M.Metal)
		for _, sz in { -1, 1 } do
			box(s1, V(104, 5, 3), CFrame.new(16, 13, sz * 11.5), DARKG, M.Metal)
			for _, x in { 0, 24, 48 } do
				wheel(s1, x, 12, sz * 13.5, 22, true)
			end
			wheel(s1, 72, 7, sz * 13.5, 12, false)
		end
		box(s1, V(5, 8, 34), CFrame.new(75, 21, 0), RED, M.Metal)
		for _, sz in { -1, 1 } do
			cyl(s1, 5, 4, CFrame.new(78, 21, sz * 11.5), BRASS, M.Metal).CFrame = CFrame.new(78, 21, sz * 11.5) * ALONG * rot(0, 0, math.rad(90))
		end

		-- 2 BOILER: the long fat boiler (64 x 28 across) with three brass bands, a front smokebox and a rear firebox ring
		local s2 = K.stage(m, 2)
		cylZ(s2, 28, 64, CFrame.new(26, 34, 0) * ALONG, GREEN, M.Metal)
		cylZ(s2, 30, 9, CFrame.new(61.5, 34, 0) * ALONG, BLACK, M.Metal)
		for _, x in { 8, 26, 44 } do
			cylZ(s2, 29.4, 2.4, CFrame.new(x, 34, 0) * ALONG, BRASS, M.Metal)
		end
		cylZ(s2, 31, 3, CFrame.new(-6, 34, 0) * ALONG, BLACK, M.Metal)

		-- 3 CAB: a tall rear cab (28 x 38 x 30) with a big roof overhang, side windows and a front window
		local s3 = K.stage(m, 3)
		box(s3, V(28, 38, 30), CFrame.new(-21, 39, 0), RED, M.Metal)
		box(s3, V(36, 3, 38), CFrame.new(-21, 59.5, 0), BLACK, M.Metal)
		for _, sz in { -1, 1 } do
			box(s3, V(14, 14, 1), CFrame.new(-21, 46, sz * 15.4), GLASS, M.Glass).Transparency = 0.2
		end
		box(s3, V(1, 12, 16), CFrame.new(-6.6, 46, 0), GLASS, M.Glass).Transparency = 0.2
		box(s3, V(30, 3, 32), CFrame.new(-21, 19.5, 0), BLACK, M.Metal)

		-- 4 SMOKESTACK: an exaggerated stack (9 wide, flaring to 16) rising to y 78 from the front of the boiler
		local s4 = K.stage(m, 4)
		cyl(s4, 10, 26, CFrame.new(52, 61, 0), BLACK, M.Metal)
		cyl(s4, 13, 6, CFrame.new(52, 73, 0), DARKG, M.Metal)
		cyl(s4, 17, 4, CFrame.new(52, 78, 0), BLACK, M.Metal)
		K.marker(s4, "StackTop", V(52, 82, 0))

		-- 5 COWCATCHER / FRONT: a big sloped cowcatcher wedge, a brass headlamp and a smokebox door with a boiler-front ring
		local s5 = K.stage(m, 5)
		wedge(s5, V(30, 16, 26), CFrame.new(86, 14, 0) * rot(0, math.rad(-90), 0), RED, M.Metal)
		for k = -2, 2 do
			box(s5, V(22, 1.6, 1.6), CFrame.new(86, 15.5, k * 5.4), STEEL, M.Metal)
		end
		cylZ(s5, 9, 5, CFrame.new(67.5, 44, 0) * ALONG, BRASS, M.Metal)
		cylZ(s5, 5, 3, CFrame.new(70.8, 44, 0) * ALONG, RGB(255, 236, 170), M.SmoothPlastic)
		cylZ(s5, 24, 2, CFrame.new(66.5, 34, 0) * ALONG, STEEL, M.Metal)

		-- 6 TENDER: a long coal tender (36 x 24 x 26) on four wheels, a coal heap and a coupling to the cab
		local s6 = K.stage(m, 6)
		box(s6, V(40, 4, 26), CFrame.new(-60, 17, 0), BLACK, M.Metal)
		box(s6, V(42, 26, 28), CFrame.new(-61, 32, 0), GREEN, M.Metal)
		ell(s6, V(34, 14, 22), CFrame.new(-61, 46, 0), COAL, M.Slate)
		box(s6, V(46, 3, 30), CFrame.new(-61, 45.5, 0), BLACK, M.Metal)
		box(s6, V(12, 5, 6), CFrame.new(-38, 18, 0), STEEL, M.Metal)
		for _, sz in { -1, 1 } do
			for _, x in { -72, -48 } do
				wheel(s6, x, 8, sz * 13.5, 14, false)
			end
		end

		-- 7 RODS / STEAM HARDWARE: two long side rods (they cycle with the drivers), two big piston cylinders, a steam dome, a sand dome,
		-- a steam pipe along the boiler and a whistle on the cab roof
		local s7 = K.stage(m, 7)
		for _, sz in { -1, 1 } do
			local r = K.group(s7, "Rod")
			box(r, V(54, 3.4, 2.4), CFrame.new(29, 12, sz * 17.2), BRASS, M.Metal)
			cylZ(s7, 10, 18, CFrame.new(58, 18, sz * 15.5) * ALONG, STEEL, M.Metal)
			K.marker(s7, if sz < 0 then "CylL" else "CylR", V(66, 18, sz * 15.5))
		end
		ell(s7, V(15, 13, 15), CFrame.new(20, 50, 0), BRASS, M.Metal)
		ell(s7, V(13, 11, 13), CFrame.new(36, 49, 0), BLACK, M.Metal)
		cylZ(s7, 3.4, 40, CFrame.new(28, 48.6, 0) * ALONG, STEEL, M.Metal)
		cyl(s7, 3.4, 10, CFrame.new(-26, 65, 0), BRASS, M.Metal)
		K.marker(s7, "Whistle", V(-26, 71, 0))
		return m
	end,
}
