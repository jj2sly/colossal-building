--!nonstrict
-- FORGOTTEN F1 (server-only template, id "Fg7a"): an ancient orbital cannon. One enormous barrel pitched ~40 degrees toward
-- template -X (screen right from the spawn) is the primary mass; its long diagonal overhang reaches past the deck edge. It rides a
-- big rotator platform with a heavy rear buttress, a circular charge chamber and two giant barrel rings. Ivory stone, dark stone,
-- aged steel, restrained brass; cold-energy accents only on the chamber core, the conduits and the bank slits.
-- Groups (for the client show): Foundation (static), Rotator, Rear, Chamber, Core, BarrelLow, BarrelUp, Ring1, Ring2, Banks,
-- BankGlow, Spine, Conduit (parts carry Order 1..8), Crown. Markers: RotC, PivC, Ring1C, Ring2C, MuzzleC (look = barrel direction).
return {
	Id = "Fg7a",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, cylZ, ell, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.cylZ, K.ell, K.wedge
		local IVORY, STONE, DARK, STEEL, BRASS = RGB(206, 198, 176), RGB(150, 144, 132), RGB(86, 84, 80), RGB(96, 106, 112), RGB(170, 134, 70)
		local GLOW0 = RGB(52, 78, 96)
		local m = K.template("Fg7a")
		local D = V(-0.766, 0.643, 0).Unit -- barrel direction (template space)
		local UP = V(0.643, 0.766, 0) -- the barrel's upper side
		local P0 = V(34, 72, 0) -- chamber centre
		local function at(t: number, o: Vector3?): Vector3
			return P0 + D * t + (o or V(0, 0, 0))
		end
		local function hw(t: number): number -- barrel half-width at distance t along the barrel
			return 30 - (t - 20) * (10 / 170)
		end
		local function seg(parent: Instance, a: Vector3, b: Vector3, w: number, h: number, col: Color3, mat)
			return box(parent, V(w, h, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b, V(0, 1, 0)), col, mat)
		end
		-- a ring in the plane perpendicular to the barrel, `n` boxes, a brass lug every 4th box (so spinning reads)
		local function ring(parent: Instance, c: Vector3, R: number, tube: number, depth: number, n: number)
			local e1 = V(0, 0, 1)
			local e2 = D:Cross(e1)
			for i = 0, n - 1 do
				local a = i / n * math.pi * 2
				local radial = e1 * math.cos(a) + e2 * math.sin(a)
				local tang = -e1 * math.sin(a) + e2 * math.cos(a)
				local pos = c + radial * R
				local len = 2 * R * math.sin(math.pi / n) * 1.06
				local lug = i % 4 == 0
				box(parent, V(if lug then depth * 1.5 else depth, if lug then tube * 1.6 else tube, len), CFrame.lookAt(pos, pos + tang, radial), if lug then BRASS else (if i % 2 == 0 then STONE else STEEL), if lug then M.Metal else M.Slate)
			end
			-- four heavy spokes down to the barrel
			for k = 0, 3 do
				local a = k * math.pi / 2 + math.pi / 4
				local radial = e1 * math.cos(a) + e2 * math.sin(a)
				bar(parent, c + radial * (R - tube * 0.5), c + radial * 20, 7, DARK, M.Metal)
			end
		end

		-- 1 BURIED FOUNDATION: a half-buried stepped stone vault the machine rises from
		local s1 = K.stage(m, 1)
		local fnd = K.group(s1, "Foundation")
		box(fnd, V(176, 5, 120), CFrame.new(0, 2.5, 0), DARK, M.Concrete)
		box(fnd, V(150, 5, 100), CFrame.new(0, 7.5, 0), STONE, M.Slate)
		cyl(fnd, 112, 4, CFrame.new(0, 12, 0), STEEL, M.Metal)
		for _, sx in { -1, 1 } do
			wedge(fnd, V(176, 5, 12), CFrame.new(0, 2.5, sx * 66) * CFrame.Angles(0, if sx > 0 then 0 else math.rad(180), 0), STONE, M.Concrete)
		end
		for _, p in { V(-70, 5, -44), V(70, 5, -44), V(-70, 5, 44), V(70, 5, 44) } do
			box(fnd, V(22, 14, 22), CFrame.new(p + V(0, 7, 0)), IVORY, M.Slate)
		end

		-- 2 ROTATOR PLATFORM: a big turning drum
		local s2 = K.stage(m, 2)
		local rot = K.group(s2, "Rotator")
		cyl(rot, 104, 10, CFrame.new(0, 19, 0), IVORY, M.Slate)
		cyl(rot, 92, 4, CFrame.new(0, 26, 0), DARK, M.Metal)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			box(rot, V(10, 6, 14), CFrame.lookAt(V(math.cos(a) * 50, 19, math.sin(a) * 50), V(0, 19, 0)), BRASS, M.Metal)
		end
		K.marker(rot, "RotC", V(0, 24, 0))

		-- 3 REAR SUPPORT: two raking buttress legs, a rear brace and a heavy rear wedge block
		local s3 = K.stage(m, 3)
		local rear = K.group(s3, "Rear")
		for _, sz in { -1, 1 } do
			bar(rear, V(64, 26, sz * 30), V(40, 68, sz * 17), 18, STONE, M.Slate)
			box(rear, V(30, 16, 14), CFrame.new(66, 31, sz * 30), IVORY, M.Slate)
		end
		bar(rear, V(88, 26, 0), V(56, 72, 0), 14, STEEL, M.Metal)
		wedge(rear, V(46, 34, 56), CFrame.new(74, 43, 0) * CFrame.Angles(0, math.rad(90), 0), DARK, M.Concrete)

		-- 4 CHARGE CHAMBER: a circular chamber drum seen broadside, a glowing core disc on the spawn-facing side
		local s4 = K.stage(m, 4)
		local ch = K.group(s4, "Chamber")
		cylZ(ch, 98, 10, CFrame.new(P0 + V(0, 0, 8)), DARK, M.Metal)
		cylZ(ch, 82, 22, CFrame.new(P0 + V(0, 0, -2)), IVORY, M.Slate)
		cylZ(ch, 92, 5, CFrame.new(P0 + V(0, 0, -13)), BRASS, M.Metal)
		ell(ch, V(58, 58, 58), CFrame.new(P0 + V(30, 8, 14)), STEEL, M.Metal)
		local core = K.group(s4, "Core")
		cylZ(core, 54, 3, CFrame.new(P0 + V(0, 0, -16.2)), GLOW0, M.SmoothPlastic)
		K.marker(core, "CoreC", P0 + V(0, 0, -17))
		K.marker(ch, "PivC", P0)

		-- 5 / 6 BARREL: the primary mass. Lower barrel t 20..104, upper barrel t 104..196 (tapering)
		local s5 = K.stage(m, 5)
		local low = K.group(s5, "BarrelLow")
		local cuts = { 20, 50, 80, 104 }
		for i = 1, 3 do
			local w = 2 * hw((cuts[i] + cuts[i + 1]) / 2)
			seg(low, at(cuts[i]), at(cuts[i + 1]), w, w, if i % 2 == 1 then IVORY else STONE, M.Slate)
		end
		for _, t in { 34, 66, 96 } do
			seg(low, at(t - 3), at(t + 3), 2 * hw(t) + 8, 2 * hw(t) + 8, DARK, M.Metal)
		end
		local s6 = K.stage(m, 6)
		local up = K.group(s6, "BarrelUp")
		local cuts2 = { 104, 132, 164, 190 }
		for i = 1, 3 do
			local w = 2 * hw((cuts2[i] + cuts2[i + 1]) / 2)
			seg(up, at(cuts2[i]), at(cuts2[i + 1]), w, w, if i % 2 == 1 then STONE else IVORY, M.Slate)
		end
		for _, t in { 120, 150, 178 } do
			seg(up, at(t - 3), at(t + 3), 2 * hw(t) + 8, 2 * hw(t) + 8, DARK, M.Metal)
		end
		seg(up, at(188), at(200), 50, 50, STEEL, M.Metal) -- muzzle flare
		seg(up, at(199), at(204), 34, 34, RGB(24, 24, 28), M.Slate) -- the dark bore
		K.marker(up, "MuzzleC", at(204), D)

		-- 7 / 8 RING I and RING II: two giant rings around the barrel
		local s7 = K.stage(m, 7)
		local r1 = K.group(s7, "Ring1")
		ring(r1, at(70), 74, 11, 12, 28)
		K.marker(r1, "Ring1C", at(70), D)
		local s8 = K.stage(m, 8)
		local r2 = K.group(s8, "Ring2")
		ring(r2, at(142), 62, 10, 11, 26)
		K.marker(r2, "Ring2C", at(142), D)

		-- 9 POWER BANKS: heavy angular banks flanking the rotator
		local s9 = K.stage(m, 9)
		local banks = K.group(s9, "Banks")
		local glow = K.group(s9, "BankGlow")
		for _, sz in { -1, 1 } do
			box(banks, V(40, 34, 20), CFrame.new(-18, 43, sz * 40), DARK, M.Concrete)
			wedge(banks, V(40, 14, 20), CFrame.new(-18, 67, sz * 40) * CFrame.Angles(0, if sz > 0 then 0 else math.rad(180), 0), STONE, M.Slate)
			box(banks, V(24, 22, 14), CFrame.new(-52, 37, sz * 36), STEEL, M.Metal)
			box(glow, V(3, 18, 20), CFrame.new(-18, 43, sz * 30), GLOW0, M.SmoothPlastic)
		end

		-- 10 TARGETING SPINE: a long dorsal spine on the barrel with heavy fins
		local s10 = K.stage(m, 10)
		local spine = K.group(s10, "Spine")
		bar(spine, at(30, UP * (hw(30) + 6)), at(176, UP * (hw(176) + 6)), 6, STEEL, M.Metal)
		for _, t in { 40, 78, 116, 154 } do
			bar(spine, at(t, UP * (hw(t) - 2)), at(t, UP * (hw(t) + 6)), 5, DARK, M.Metal)
			wedge(spine, V(5, 14, 18), CFrame.lookAt(at(t, UP * (hw(t) + 12)), at(t, UP * (hw(t) + 12)) + D, UP), BRASS, M.Metal)
		end

		-- 11 STAR METAL CONDUITS: glowing conduit runs along both flanks of the barrel and down the rear (Order = pulse sequence)
		local s11 = K.stage(m, 11)
		local cond = K.group(s11, "Conduit")
		for _, sz in { -1, 1 } do
			for i = 1, 8 do
				local t0, t1 = 24 + (i - 1) * 22, 24 + i * 22 - 2
				local a, b = at(t0, V(0, 0, sz * (hw(t0) + 2))), at(t1, V(0, 0, sz * (hw(t1) + 2)))
				local p = seg(cond, a, b, 4.4, 4.4, GLOW0, M.SmoothPlastic)
				p:SetAttribute("Order", i)
			end
		end
		for i = 1, 4 do
			local p = seg(cond, V(60 + i * 5, 58 - i * 8, -14), V(60 + (i + 1) * 5 - 1, 58 - (i + 1) * 8, -14), 3.4, 3.4, GLOW0, M.SmoothPlastic)
			p:SetAttribute("Order", 1)
		end

		-- 12 FINAL CROWN: a brass crown collar at the muzzle and a tall capstone spire on the rear buttress
		local s12 = K.stage(m, 12)
		local crown = K.group(s12, "Crown")
		seg(crown, at(176), at(184), 58, 58, BRASS, M.Metal)
		for k = 0, 5 do
			local a = k / 6 * math.pi * 2
			local e1, e2 = V(0, 0, 1), D:Cross(V(0, 0, 1))
			local radial = e1 * math.cos(a) + e2 * math.sin(a)
			wedge(crown, V(6, 18, 10), CFrame.lookAt(at(180) + radial * 30, at(180) + radial * 30 + D, radial), IVORY, M.Slate)
		end
		bar(crown, V(80, 70, 0), V(94, 124, 0), 12, IVORY, M.Slate)
		box(crown, V(16, 8, 16), CFrame.new(94, 128, 0), BRASS, M.Metal)
		return m
	end,
}
