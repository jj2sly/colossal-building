--!nonstrict
-- LEANING TOWER OF PISA (Rare). A tall round marble tower (46 across, ~128 tall) leaning 6.5 degrees toward +X (seen side-on from the
-- spawn): a stone foundation, a tall lower arcade, four more stacked arcade rings (a ring of 12 columns over a dark core with a slab on
-- top of each level, so the arch openings read), a smaller open bell chamber with three golden bells and a domed crown with a spire.
-- Everything above the foundation is tilted together about the foundation top, so the lean is one clean line.
-- Groups for the client show: Bell (three; marker BellTop = the yoke each bell swings from); marker CrownTop (flock circle centre).
return {
	Id = "LeaningTowerOfPisa",
	Build = function(K)
		local V, M, RGB, box, cyl, ell = K.V, K.M, K.RGB, K.box, K.cyl, K.ell
		local MARB, MARB2, CORE, STONE, STONE2 = RGB(236, 230, 214), RGB(214, 206, 186), RGB(104, 98, 90), RGB(128, 124, 116), RGB(160, 154, 144)
		local ROOF, GOLD, GOLD2 = RGB(150, 84, 62), RGB(222, 176, 60), RGB(176, 130, 40)
		local m = K.template("LeaningTowerOfPisa")
		local LEAN = math.rad(6.5)
		local BASEY = 6
		local T = CFrame.new(0, BASEY, 0) * CFrame.Angles(0, 0, -LEAN) * CFrame.new(0, -BASEY, 0)
		local function lean(stage: Instance)
			for _, d in stage:GetDescendants() do
				if d:IsA("BasePart") then
					d.CFrame = T * d.CFrame
				end
			end
		end
		local R, NCOL = 19, 12

		-- 1 FOUNDATION: a wide stone apron (66 across) and a stepped drum (52 across) up to y 6, level with the ground
		local s1 = K.stage(m, 1)
		cyl(s1, 68, 2.4, CFrame.new(0, 1.2, 0), STONE, M.Slate)
		cyl(s1, 60, 2.4, CFrame.new(0, 3.6, 0), STONE2, M.Slate)
		cyl(s1, 52, 2.2, CFrame.new(0, 4.9, 0), STONE, M.Slate)

		-- one arcade level: dark core wall, a ring of marble columns, a capital ring and a floor slab on top
		local y = BASEY
		local function level(stage: Instance, h: number)
			cyl(stage, 2 * R - 7, h, CFrame.new(0, y + h / 2, 0), CORE, M.Slate)
			for i = 0, NCOL - 1 do
				local a = i / NCOL * math.pi * 2
				cyl(stage, 4.6, h - 1.4, CFrame.new(R * math.cos(a), y + h / 2 - 0.4, R * math.sin(a)), MARB, M.Marble)
			end
			cyl(stage, 2 * R + 6, 2.4, CFrame.new(0, y + h + 1.2, 0), MARB2, M.Marble)
			y += h + 2.4
		end

		-- 2 LOWER ARCADE: the tall first level (14) with its base ring
		local s2 = K.stage(m, 2)
		cyl(s2, 2 * R + 8, 2.4, CFrame.new(0, y + 1.2, 0), MARB2, M.Marble)
		y += 2.4
		level(s2, 14)
		lean(s2)

		-- 3 MID TOWER I: two more levels
		local s3 = K.stage(m, 3)
		level(s3, 12)
		level(s3, 12)
		lean(s3)

		-- 4 MID TOWER II: two more levels
		local s4 = K.stage(m, 4)
		level(s4, 12)
		level(s4, 12)
		lean(s4)

		-- 5 UPPER ARCADE: the top arcade level, a little taller, with a heavier cornice
		local s5 = K.stage(m, 5)
		level(s5, 13)
		cyl(s5, 2 * R + 10, 2.6, CFrame.new(0, y + 1.3, 0), MARB, M.Marble)
		y += 2.6
		lean(s5)

		-- 6 BELL CHAMBER: a smaller open drum (radius 12.5): eight columns, a floor, a roof ring and three golden bells hung inside
		local s6 = K.stage(m, 6)
		local BR, BH = 12.5, 11
		cyl(s6, 2 * BR - 4, 2, CFrame.new(0, y + 1, 0), CORE, M.Slate)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2
			cyl(s6, 4.2, BH, CFrame.new(BR * math.cos(a), y + 2 + BH / 2, BR * math.sin(a)), MARB, M.Marble)
		end
		cyl(s6, 2 * BR + 5, 2.6, CFrame.new(0, y + 2 + BH + 1.3, 0), MARB2, M.Marble)
		for k, bx in { -6.5, 0, 6.5 } do
			local b = K.group(s6, "Bell")
			local top = y + 2 + BH - 0.5
			box(b, V(2, 1.6, 2), CFrame.new(bx, top, (k - 2) * 0), GOLD2, M.Metal)
			ell(b, V(9, 10.5, 9), CFrame.new(bx, top - 5.6, 0), GOLD, M.Metal)
			K.marker(b, "BellTop", V(bx, top + 0.5, 0))
		end
		y += 2 + BH + 2.6
		lean(s6)

		-- 7 CROWN: a terracotta dome over the bell chamber, a gold lantern and spire
		local s7 = K.stage(m, 7)
		ell(s7, V(2 * BR + 6, 20, 2 * BR + 6), CFrame.new(0, y + 4, 0), ROOF, M.Slate)
		cyl(s7, 6, 6, CFrame.new(0, y + 14, 0), MARB, M.Marble)
		cyl(s7, 2, 12, CFrame.new(0, y + 23, 0), GOLD, M.Metal)
		ell(s7, V(5, 5, 5), CFrame.new(0, y + 30, 0), GOLD, M.Metal)
		K.marker(s7, "CrownTop", V(0, y + 14, 0))
		lean(s7)
		return m
	end,
}
