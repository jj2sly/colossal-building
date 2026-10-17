--!nonstrict
-- MEGA FORTRESS WALL (Legendary). Not a castle: one colossal, LOW defensive WALL across the whole site, facing -Z (the spawn).
-- Width dominates height (~193 wide x ~126 tall; Pass 10 raised the towers, gatehouse and inner towers ~26-30 studs): a battered stone plinth (176 wide), two long heavy wall spans (40 tall,
-- 30 thick) with buttress pilasters, two squat round end towers (32 across, crowns 40, kept secondary to the wall width), a massive
-- central gatehouse (64 wide) with a 32 x 40 gate passage that runs right through the wall (the gate leaves stand ajar deep in
-- it, so it reads as an opening), two low square inner towers behind, and the gate machinery: winch drums, chains, portcullis.
-- Groups for the client show: Torch (sconces; flame parts have attribute Flame and start invisible), Drum (winch drums, spin about
-- the template X axis), Chain, Portcullis, GateL / GateR (markers HingeL / HingeR; built ajar by GATE_AJAR), Banner, Flag,
-- Beacon (tower braziers; flame parts have attribute Flame and start invisible).
return {
	Id = "MegaFortress",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, cylZ, ell, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.cylZ, K.ell, K.wedge
		local STONE, STONE2, STONE3, DARK = RGB(150, 144, 134), RGB(126, 120, 112), RGB(98, 94, 90), RGB(46, 44, 46)
		local WOOD, IRON, BRONZE, RED, GOLD = RGB(96, 64, 40), RGB(58, 58, 64), RGB(150, 104, 56), RGB(160, 34, 34), RGB(214, 170, 60)
		local FLAME = RGB(255, 98, 22)
		local m = K.template("MegaFortress")
		local ALONG = CFrame.Angles(0, math.rad(90), 0) -- cylZ along the template X axis
		local GATE_AJAR = math.rad(22) -- the client show knows this (it opens the leaves the rest of the way)
		local WT, GO = 54, 16 -- wall top, gate opening half-width
		local function torch(parent: Instance, pos: Vector3)
			local t = K.group(parent, "Torch")
			box(t, V(3, 3, 4), CFrame.new(pos + V(0, -1, 1.5)), IRON, M.Metal)
			cyl(t, 5, 2, CFrame.new(pos + V(0, 1, 0)), BRONZE, M.Metal)
			local f = ell(t, V(4.4, 7, 4.4), CFrame.new(pos + V(0, 5, 0)), FLAME, M.Neon, { Flame = true })
			f.Transparency = 1
			f.CastShadow = false
		end
		local function merlonRing(parent: Instance, c: Vector3, r: number, n: number, y0: number, col: Color3)
			for i = 0, n - 1 do
				local a = (i + 0.5) / n * math.pi * 2
				local p = c + V(math.cos(a) * r, y0 + 4, math.sin(a) * r)
				box(parent, V(10, 8, 6), CFrame.lookAt(p, p + V(math.cos(a), 0, math.sin(a))), col, M.Slate)
			end
		end

		-- 1 FOUNDATION / LOWER WALL: a battered plinth along the whole wall line with a sloped front talus
		local s1 = K.stage(m, 1)
		box(s1, V(176, 14, 46), CFrame.new(0, 7, 2), STONE3, M.Slate)
		wedge(s1, V(168, 14, 12), CFrame.new(0, 7, -27), STONE3, M.Slate)
		box(s1, V(172, 2, 42), CFrame.new(0, 15, 2), STONE2, M.Slate)

		-- 2 MAIN WALL SPAN: two long heavy wall planes (42 wide... to the towers) x 40 tall x 30 thick, buttress pilasters,
		-- a string course and torch sconces
		local s2 = K.stage(m, 2)
		for _, sx in { -1, 1 } do
			box(s2, V(50, WT - 14, 30), CFrame.new(sx * 52, (WT + 14) / 2, 0), STONE, M.Slate)
			box(s2, V(50, 3, 33), CFrame.new(sx * 52, 40, 0), STONE2, M.Slate)
			for _, x in { 36, 48, 60 } do
				box(s2, V(7, WT - 14, 5), CFrame.new(sx * x, (WT + 14) / 2, -17), STONE2, M.Slate)
				torch(s2, V(sx * x, 38, -21.5))
			end
		end

		-- 3 / 4 OUTER TOWERS: two squat round towers (shaft 32 across, crown 40) at the wall ends
		for i, sx in { -1, 1 } do
			local s = K.stage(m, 2 + i)
			local c = V(sx * 76, 0, 0)
			cyl(s, 38, 16, CFrame.new(c + V(0, 8, 0)), STONE3, M.Slate)
			cyl(s, 32, 86, CFrame.new(c + V(0, 59, 0)), STONE, M.Slate)
			cyl(s, 40, 7, CFrame.new(c + V(0, 105.5, 0)), STONE2, M.Slate)
			merlonRing(s, c, 17.5, 6, 109, STONE)
			box(s, V(5, 26, 3), CFrame.new(c + V(0, 70, -16.2)), DARK, M.Slate)
			torch(s, c + V(0, 34, -19.5))
		end

		-- 5 GATEHOUSE: piers, a deep lintel, chamfered arch shoulders and two flat buttress frames around a 32 x 40 passage
		-- right through the wall; a ramp up to it and the winch drums + chains of the gate machinery
		local s5 = K.stage(m, 5)
		for _, sx in { -1, 1 } do
			box(s5, V(14, 84, 44), CFrame.new(sx * (GO + 7), 56, -3), STONE, M.Slate)
			local c = V(sx * (GO - 4), WT - 4.5, -3)
			local Z, Y = V(sx, 0, 0), V(0, -1, 0)
			wedge(s5, V(44, 9, 8), CFrame.fromMatrix(c, Y:Cross(Z), Y, Z), STONE, M.Slate)
			box(s5, V(14, 88, 6), CFrame.new(sx * (GO + 14), 58, -27), STONE2, M.Slate) -- flat buttress frames, not towers
			local drum = K.group(s5, "Drum")
			cylZ(drum, 8, 10, CFrame.new(sx * 10, 62, -27) * ALONG, IRON, M.Metal)
			local chain = K.group(s5, "Chain")
			bar(chain, V(sx * 10, 58, -28), V(sx * 10, 52, -23), 1.6, IRON, M.Metal)
		end
		box(s5, V(GO * 2, 44, 44), CFrame.new(0, WT + 22, -3), STONE, M.Slate)
		wedge(s5, V(34, 14, 22), CFrame.new(0, 7, -38), STONE2, M.Slate)

		-- 6 BATTLEMENTS / UPPER MASS: big merlons on the wall spans, rear parapets, the gatehouse machicolation and merlons,
		-- and four long red banners hanging on the wall front
		local s6 = K.stage(m, 6)
		for _, sx in { -1, 1 } do
			for _, x in { 32, 42, 52, 62, 70 } do
				box(s6, V(8, 8, 6), CFrame.new(sx * x, WT + 4, -12), STONE2, M.Slate)
			end
			box(s6, V(46, 4, 3), CFrame.new(sx * 52, WT + 2, 13.5), STONE2, M.Slate)
			for _, x in { 42, 54 } do
				local b = K.group(s6, "Banner")
				box(b, V(9, 26, 0.8), CFrame.new(sx * x, 39, -15.6), RED, M.Fabric)
				box(b, V(9.2, 3, 1), CFrame.new(sx * x, 49, -15.7), GOLD, M.Fabric)
			end
		end
		box(s6, V(64, 6, 50), CFrame.new(0, 101, -3), STONE2, M.Slate)
		for _, x in { -28, -14, 0, 14, 28 } do
			box(s6, V(9, 8, 6), CFrame.new(x, 108, -25), STONE, M.Slate)
		end

		-- 7 INNER TOWERS: two low square towers rising behind the wall between the gate and the end towers
		local s7 = K.stage(m, 7)
		for _, sx in { -1, 1 } do
			local c = V(sx * 50, 0, 24)
			box(s7, V(18, 90, 18), CFrame.new(c + V(0, 45, 0)), STONE2, M.Slate)
			box(s7, V(22, 5, 22), CFrame.new(c + V(0, 92.5, 0)), STONE3, M.Slate)
			for _, dx in { -1, 1 } do
				for _, dz in { -1, 1 } do
					box(s7, V(6, 6, 6), CFrame.new(c + V(dx * 8, 98, dz * 8)), STONE2, M.Slate)
				end
			end
		end

		-- 8 GATE MECHANISM: the portcullis (raised into the lintel slot) and two great iron-banded gate leaves standing ajar deep
		-- in the passage
		local s8 = K.stage(m, 8)
		local port = K.group(s8, "Portcullis")
		for _, x in { -11, -3.7, 3.7, 11 } do
			box(port, V(2, 30, 2), CFrame.new(x, WT + 9, -21), IRON, M.Metal)
		end
		for _, y in { WT - 2, WT + 8 } do
			box(port, V(GO * 2, 2, 2), CFrame.new(0, y, -21), IRON, M.Metal)
		end
		for _, sx in { -1, 1 } do
			local tag = if sx < 0 then "L" else "R"
			local g = K.group(s8, "Gate" .. tag)
			local hinge = V(sx * GO, 34, 14)
			-- the leaf is built closed, then turned ajar about its hinge (toward +Z, into the wall)
			local R = CFrame.new(hinge) * CFrame.Angles(0, sx * GATE_AJAR, 0) * CFrame.new(-hinge)
			box(g, V(GO, 40, 3), R * CFrame.new(sx * GO / 2, 34, 14), WOOD, M.WoodPlanks)
			for _, y in { 22, 34, 46 } do
				box(g, V(GO + 0.4, 2.4, 3.6), R * CFrame.new(sx * GO / 2, y, 14), IRON, M.Metal)
			end
			K.marker(g, "Hinge" .. tag, hinge)
		end

		-- 9 CROWN / BANNERS: beacon braziers on the end towers, a crest over the gate and two standards on the inner towers
		local s9 = K.stage(m, 9)
		for _, sx in { -1, 1 } do
			local beacon = K.group(s9, "Beacon")
			cyl(beacon, 16, 5, CFrame.new(sx * 76, 111.5, 0), BRONZE, M.Metal)
			local f = ell(beacon, V(12, 14, 12), CFrame.new(sx * 76, 119, 0), FLAME, M.Neon, { Flame = true })
			f.Transparency = 1
			f.CastShadow = false
			cyl(s9, 2, 26, CFrame.new(sx * 50, 114, 24), IRON, M.Metal)
			local flag = K.group(s9, "Flag")
			box(flag, V(16, 9, 0.5), CFrame.new(sx * 50 + 8.5, 122, 24), RED, M.Fabric)
		end
		box(s9, V(28, 12, 4), CFrame.new(0, 84, -27), STONE2, M.Slate)
		cylZ(s9, 9, 1.2, CFrame.new(0, 84, -29.4), GOLD, M.Metal)
		return m
	end,
}
