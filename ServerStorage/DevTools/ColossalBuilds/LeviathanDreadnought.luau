--!nonstrict
-- LEVIATHAN DREADNOUGHT (Legendary). A capital ship seen broadside from the spawn: an extremely long armored wedge hull (bow
-- toward +X, ~230 long) held on a docking cradle so the overhanging bow and stern float above the deck edge. The hull is
-- shallow and knife-sharp at the bow and grows deep and heavy toward a gigantic rear engine block (62 deep, five huge nozzles) flanked by two giant side engine barrels.
-- A compact command tower sits aft, a long dorsal spinal cannon runs forward, broad swept side fins with engines on their
-- tips, ventral pods underneath. About 247 long x 107 tall x 144 wide (fins / side engines); hull 40 wide.
-- Groups for the client show: Ground (docking cradle: never moves), Engine (main nozzle glows, marker-free: their centres are
-- the thrust points), Engine2 (fin-tip engine glows), Conduit (power conduit strips along the hull), Reactor (dorsal reactor
-- glow), Bridge (bridge window band). Everything else is the ship.
return {
	Id = "LeviathanDreadnought",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, cylZ, ell, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.cylZ, K.ell, K.wedge
		local HULL, HULL2, HULL3, DARK = RGB(118, 124, 136), RGB(92, 98, 110), RGB(70, 74, 84), RGB(44, 46, 54)
		local ACC, GLOW0, GLASS = RGB(176, 58, 44), RGB(40, 52, 70), RGB(110, 170, 210)
		local m = K.template("LeviathanDreadnought")
		local ALONG = CFrame.Angles(0, math.rad(90), 0) -- cylZ along the template X axis
		-- a triangular plate of thickness th through points a, b, c (two wedges)
		local function tri(parent: Instance, a: Vector3, b: Vector3, c: Vector3, th: number, col: Color3, mat)
			local ab, ac, bc = b - a, c - a, c - b
			local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
			if abd > acd and abd > bcd then
				c, a = a, c
			elseif acd > bcd and acd > abd then
				a, b = b, a
			end
			ab, ac, bc = b - a, c - a, c - b
			local right = ac:Cross(ab).Unit
			local up = bc:Cross(right).Unit
			local back = bc.Unit
			local h = math.abs(ab:Dot(up))
			wedge(parent, V(th, h, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), col, mat)
			wedge(parent, V(th, h, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), col, mat)
		end

		-- 1 KEEL: the docking cradle (three pylons on rails, inside the deck) and the long keel spine with a sharp bow foot
		local s1 = K.stage(m, 1)
		local ground = K.group(s1, "Ground")
		for _, sz in { -1, 1 } do
			box(ground, V(140, 3, 6), CFrame.new(-6, 1.5, sz * 14), DARK, M.DiamondPlate)
		end
		for _, x in { -62, -6, 50 } do
			box(ground, V(12, 20, 34), CFrame.new(x, 11, 0), DARK, M.Metal)
			box(ground, V(16, 3, 38), CFrame.new(x, 22.5, 0), HULL3, M.Metal)
		end
		box(s1, V(190, 6, 12), CFrame.new(-10, 27, 0), HULL3, M.Metal)
		tri(s1, V(85, 27, -6), V(85, 27, 6), V(114, 33, 0), 6, HULL3, M.Metal)

		-- 2 LOWER HULL: the deep armored belly (40 wide) and the bow wedge tapering to a point in plan, ventral pods
		local s2 = K.stage(m, 2)
		box(s2, V(130, 22, 40), CFrame.new(-40, 39, 0), HULL2, M.Metal)
		tri(s2, V(25, 40, -20), V(25, 40, 20), V(112, 36, 0), 20, HULL2, M.Metal)
		for _, sz in { -1, 1 } do
			ell(s2, V(54, 14, 16), CFrame.new(-40, 30, sz * 14), HULL3, M.Metal)
		end

		-- 3 UPPER HULL: a narrower upper hull with a sloped bow deck down to the prow, side armor belts and the power conduits
		local s3 = K.stage(m, 3)
		box(s3, V(116, 12, 34), CFrame.new(-48, 52, 0), HULL, M.Metal)
		tri(s3, V(10, 58, -17), V(10, 58, 17), V(106, 44, 0), 10, HULL, M.Metal)
		for _, sz in { -1, 1 } do
			box(s3, V(150, 5, 2), CFrame.new(-20, 44, sz * 20.6), ACC, M.Metal)
			local cnd = K.group(s3, "Conduit")
			box(cnd, V(120, 1.6, 1), CFrame.new(-34, 50, sz * 17.4), GLOW0, M.SmoothPlastic)
		end

		-- 4 REAR ENGINE BLOCK: a gigantic engine block deeper and wider than the hull (36 x 56 x 58) with five huge nozzles
		local s4 = K.stage(m, 4)
		box(s4, V(32, 62, 58), CFrame.new(-102, 47, 0), HULL2, M.Metal)
		for _, sz in { -1, 1 } do -- two giant side engine barrels: they carry the engine mass into the broadside view
			cylZ(s4, 26, 50, CFrame.new(-100, 40, sz * 38) * ALONG, HULL3, M.Metal)
			cylZ(s4, 30, 6, CFrame.new(-121, 40, sz * 38) * ALONG, DARK, M.Metal)
			local e = K.group(s4, "Engine")
			cylZ(e, 20, 1, CFrame.new(-124.6, 40, sz * 38) * ALONG, GLOW0, M.SmoothPlastic)
		end
		wedge(s4, V(58, 16, 22), CFrame.new(-80, 66, 0) * CFrame.Angles(0, math.rad(-90), 0), HULL2, M.Metal) -- top blend into hull
		for _, n in { { 0, 58, 22 }, { -19, 58, 18 }, { 19, 58, 18 }, { -12, 32, 16 }, { 12, 32, 16 } } do
			local z, y, d = n[1], n[2] - 10, n[3]
			cylZ(s4, d, 10, CFrame.new(-122, y, z) * ALONG, DARK, M.Metal)
			local e = K.group(s4, "Engine")
			cylZ(e, d * 0.72, 1, CFrame.new(-127.4, y, z) * ALONG, GLOW0, M.SmoothPlastic)
		end

		-- 5 COMMAND STRUCTURE: a compact stepped command tower aft, with a bridge window band and a sensor mast
		local s5 = K.stage(m, 5)
		box(s5, V(26, 12, 22), CFrame.new(-60, 64, 0), HULL, M.Metal)
		box(s5, V(18, 12, 16), CFrame.new(-62, 76, 0), HULL2, M.Metal)
		local bridge = K.group(s5, "Bridge")
		box(bridge, V(18.4, 3, 16.4), CFrame.new(-62, 77, 0), GLASS, M.Glass)
		box(s5, V(22, 3, 20), CFrame.new(-62, 83.5, 0), HULL3, M.Metal)
		cyl(s5, 2, 22, CFrame.new(-66, 96, 0), DARK, M.Metal)

		-- 6 SIDE FINS: broad swept fins aft with engines on their tips, forward canards and a tall stern fin
		local s6 = K.stage(m, 6)
		for _, sz in { -1, 1 } do
			tri(s6, V(-24, 40, sz * 20), V(-82, 40, sz * 20), V(-92, 30, sz * 62), 4, HULL2, M.Metal)
			tri(s6, V(-24, 40, sz * 20), V(-92, 30, sz * 62), V(-70, 32, sz * 62), 4, HULL2, M.Metal)
			tri(s6, V(46, 38, sz * 18), V(22, 38, sz * 18), V(14, 32, sz * 40), 3, HULL2, M.Metal)
			cylZ(s6, 10, 24, CFrame.new(-80, 31, sz * 64) * ALONG, HULL3, M.Metal)
			local e2 = K.group(s6, "Engine2")
			cylZ(e2, 7, 1, CFrame.new(-92.6, 31, sz * 64) * ALONG, GLOW0, M.SmoothPlastic)
		end
		tri(s6, V(-110, 74, 0), V(-80, 74, 0), V(-112, 104, 0), 4, HULL2, M.Metal)

		-- 7 DORSAL HERO MASS: an armored dorsal ridge and one long spinal cannon running forward to the bow
		local s7 = K.stage(m, 7)
		box(s7, V(80, 8, 14), CFrame.new(-6, 62, 0), HULL2, M.Metal)
		wedge(s7, V(14, 8, 20), CFrame.new(44, 62, 0) * CFrame.Angles(0, math.rad(-90), 0), HULL2, M.Metal)
		cylZ(s7, 7, 70, CFrame.new(36, 68, 0) * ALONG, HULL3, M.Metal)
		cylZ(s7, 14, 10, CFrame.new(-2, 68, 0) * ALONG, DARK, M.Metal)
		cylZ(s7, 10, 5, CFrame.new(71, 68, 0) * ALONG, DARK, M.Metal)

		-- 8 POWER SYSTEMS: the dorsal reactor dome behind the bridge and two power pylons feeding the engine block
		local s8 = K.stage(m, 8)
		local reactor = K.group(s8, "Reactor")
		ell(reactor, V(22, 14, 22), CFrame.new(-84, 74, 0), GLOW0, M.SmoothPlastic)
		cyl(s8, 26, 4, CFrame.new(-84, 72, 0), HULL3, M.Metal)
		for _, sz in { -1, 1 } do
			box(s8, V(8, 18, 6), CFrame.new(-84, 64, sz * 16), HULL3, M.Metal)
		end

		-- 9 FINAL ARMOR / ENGINE ASSEMBLY: engine cowl plates framing the nozzles and the bow armor ram
		local s9 = K.stage(m, 9)
		box(s9, V(14, 4, 62), CFrame.new(-119, 72, 0), HULL3, M.Metal)
		box(s9, V(14, 4, 62), CFrame.new(-119, 18, 0), HULL3, M.Metal)
		for _, sz in { -1, 1 } do
			box(s9, V(14, 58, 4), CFrame.new(-119, 45, sz * 30), HULL3, M.Metal)
		end
		tri(s9, V(80, 30, 0), V(118, 34, 0), V(84, 24, 0), 10, ACC, M.Metal)
		return m
	end,
}
