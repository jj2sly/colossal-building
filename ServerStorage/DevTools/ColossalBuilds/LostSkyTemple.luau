--!nonstrict
-- FORGOTTEN F4 (server-only template, id "Fg4b"): the broken remains of an enormous ancient temple that cannot stay in the air.
-- Nothing touches anything: a broken central platform (a missing front piece, a relic hanging in the notch), a tall shrine on its back
-- half, two separated wings at different heights, distances and compositions (LEFT: a high tilted colonnade; RIGHT: a lower, farther
-- tower fragment), four massive loose pillars, large floating stones, timber roots that REACH for the wings and stop short, and a
-- broken crown ring high above. Sky passes through every gap. Pale stone, dark structural stone, aged brass, Ancient Timber roots.
-- Groups: Platform, WingL, WingR, Shrine, Pillars, Roof, StonesA, StonesB, Relic, RelicGlow, Roots (Idx), Crown.
-- Markers: WingLC, WingRC, RelicC, CrownC.
return {
	Id = "Fg4b",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, ell, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.ell, K.wedge
		local PALE, STONE, DARK, BRASS = RGB(214, 207, 188), RGB(158, 152, 140), RGB(96, 93, 90), RGB(176, 140, 74)
		local TIMBER, TIMBER2 = RGB(104, 72, 44), RGB(138, 100, 62)
		local GLOW0 = RGB(112, 150, 160)
		local m = K.template("Fg4b")
		local A, r = CFrame.Angles, math.rad

		-- 1 BROKEN CENTRAL PLATFORM: three slabs around a missing front piece, a hanging underside, two stray shards
		local s1 = K.stage(m, 1)
		local pl = K.group(s1, "Platform")
		box(pl, V(88, 10, 52), CFrame.new(0, 78, 14) * A(0, r(2), 0), PALE, M.Slate)
		box(pl, V(36, 10, 28), CFrame.new(-26, 77, -26) * A(0, r(-4), r(2)), PALE, M.Slate)
		box(pl, V(30, 10, 26), CFrame.new(30, 79, -24) * A(0, r(5), r(-2)), STONE, M.Slate)
		box(pl, V(70, 10, 40), CFrame.new(0, 69, 14), STONE, M.Slate)
		box(pl, V(46, 10, 28), CFrame.new(5, 60, 16) * A(0, r(8), 0), DARK, M.Slate)
		box(pl, V(24, 10, 16), CFrame.new(9, 52, 18) * A(0, r(20), r(6)), STONE, M.Slate)
		box(pl, V(24, 8, 20), CFrame.new(-58, 70, 20) * A(r(8), r(20), r(14)), PALE, M.Slate)
		box(pl, V(20, 8, 18), CFrame.new(54, 62, 44) * A(r(-10), r(-24), r(-12)), STONE, M.Slate)
		box(pl, V(88, 2, 3), CFrame.new(0, 83.5, 38), BRASS, M.Metal)

		-- 2 FLOATING WING I (left): a high, tilted colonnade fragment under a half roof
		local s2 = K.stage(m, 2)
		local wl = K.group(s2, "WingL")
		do
			local f = CFrame.new(-112, 132, -10) * A(r(-6), r(14), r(11))
			local function b(p, sz, c, mt, rot) return box(wl, sz, f * CFrame.new(p) * (rot or CFrame.identity), c, mt) end
			b(V(0, 0, 0), V(64, 7, 52), PALE, M.Slate)
			b(V(-4, -7, 2), V(44, 8, 34), STONE, M.Slate)
			b(V(-6, -14, 4), V(22, 8, 18), DARK, M.Slate)
			for i = 1, 5 do
				local c = f * CFrame.new(-24 + (i - 1) * 12, 19, -18)
				cyl(wl, 5, if i == 4 then 22 else 30, c, if i % 2 == 0 then PALE else STONE, M.Slate)
			end
			b(V(-12, 36, -18), V(36, 5, 8), STONE, M.Slate)
			b(V(26, 14, 4), V(6, 24, 40), STONE, M.Slate)
			b(V(8, 40, 6), V(46, 4, 30), DARK, M.Slate, A(r(10), 0, r(-6)))
			b(V(-10, 6, 12), V(26, 5, 5), PALE, M.Slate, A(0, r(30), 0)) -- a toppled column
			K.marker(wl, "WingLC", (f * CFrame.new(0, 0, 0)).Position)
		end

		-- 3 FLOATING WING II (right): lower and farther back, a different form: a stacked tower fragment with a broken arch
		local s3 = K.stage(m, 3)
		local wr = K.group(s3, "WingR")
		do
			local f = CFrame.new(116, 70, 36) * A(r(4), r(-30), r(-5))
			local function b(p, sz, c, mt, rot) return box(wr, sz, f * CFrame.new(p) * (rot or CFrame.identity), c, mt) end
			b(V(0, 0, 0), V(50, 7, 50), STONE, M.Slate)
			cyl(wr, 36, 28, f * CFrame.new(2, 18, 0), PALE, M.Slate)
			cyl(wr, 29, 24, f * CFrame.new(-3, 44, 2) * A(r(4), 0, r(-4)), STONE, M.Slate)
			cyl(wr, 20, 16, f * CFrame.new(-6, 62, 2) * A(r(8), 0, r(-8)), PALE, M.Slate)
			b(V(-16, 22, -24), V(9, 36, 10), PALE, M.Slate)
			b(V(14, 18, -24), V(9, 28, 10), PALE, M.Slate)
			b(V(-12, 44, -24), V(22, 7, 10), STONE, M.Slate, A(0, 0, r(10))) -- the broken lintel
			b(V(2, -8, 2), V(34, 9, 34), DARK, M.Slate)
			b(V(4, -16, 4), V(18, 8, 18), STONE, M.Slate)
			K.marker(wr, "WingRC", f.Position)
		end

		-- 4 CENTRAL SHRINE: plinth, cella with a dark doorway, a front colonnade, and a tall back tower
		local s4 = K.stage(m, 4)
		local sr = K.group(s4, "Shrine")
		box(sr, V(60, 6, 46), CFrame.new(0, 86, 14), STONE, M.Slate)
		box(sr, V(50, 38, 30), CFrame.new(0, 108, 18), PALE, M.Slate)
		box(sr, V(16, 26, 3), CFrame.new(0, 100, 3.6), RGB(30, 30, 34), M.Slate)
		for _, x in { -26, -9, 9, 26 } do
			cyl(sr, 7, 38, CFrame.new(x, 108, -8), PALE, M.Slate)
		end
		box(sr, V(66, 7, 14), CFrame.new(0, 130, -8), STONE, M.Slate)
		box(sr, V(32, 90, 24), CFrame.new(0, 171, 28), STONE, M.Slate)
		box(sr, V(30, 3, 24), CFrame.new(0, 123, 26), BRASS, M.Metal)

		-- 5 OUTER PILLARS: four massive loose pillars, tilted, jagged-topped, nothing holding them
		local s5 = K.stage(m, 5)
		local pi = K.group(s5, "Pillars")
		local function pillar(p, d, h, rx, rz, col)
			local c = CFrame.new(p) * A(r(rx), 0, r(rz))
			cyl(pi, d, h, c, col, M.Slate)
			wedge(pi, V(d, 12, d * 0.6), c * CFrame.new(0, h / 2 + 6, 0) * A(0, r(30), 0), col, M.Slate)
			cyl(pi, d + 3, 4, c * CFrame.new(0, -h / 4, 0), BRASS, M.Metal)
		end
		pillar(V(-66, 135, -96), 15, 170, 6, 8, PALE)
		pillar(V(76, 122, -84), 13, 150, -5, -12, STONE)
		pillar(V(-128, 86, 62), 13, 112, 10, 20, STONE)
		pillar(V(138, 160, -10), 12, 80, 4, -66, PALE)

		-- 6 UPPER ROOF: a heavy gable over the cella and the tall tower, with a brass ridge and finial
		local s6 = K.stage(m, 6)
		local rf = K.group(s6, "Roof")
		box(rf, V(40, 4, 50), CFrame.new(-17, 138, 18) * A(0, 0, r(26)), DARK, M.Slate)
		box(rf, V(40, 4, 50), CFrame.new(17, 138, 18) * A(0, 0, r(-26)), DARK, M.Slate)
		box(rf, V(5, 5, 52), CFrame.new(0, 148, 18), BRASS, M.Metal)
		box(rf, V(40, 4, 28), CFrame.new(0, 218, 28) * A(r(-8), 0, 0), DARK, M.Slate)
		box(rf, V(7, 36, 7), CFrame.new(0, 238, 28), STONE, M.Slate)
		box(rf, V(10, 6, 10), CFrame.new(0, 258, 28), BRASS, M.Metal)

		-- 7 FLOATING STONE A and 8 STONE B: big loose masses at different heights, one broken arch
		local s7 = K.stage(m, 7)
		local sa = K.group(s7, "StonesA")
		box(sa, V(34, 26, 30), CFrame.new(-42, 190, -70) * A(r(10), r(24), r(-14)), STONE, M.Slate)
		ell(sa, V(28, 24, 26), CFrame.new(54, 214, -46), PALE, M.Slate)
		box(sa, V(32, 8, 12), CFrame.new(-44, 232, 50) * A(0, r(16), r(10)), PALE, M.Slate)
		box(sa, V(8, 22, 10), CFrame.new(-56, 222, 52) * A(0, r(16), r(8)), PALE, M.Slate)
		local s8 = K.stage(m, 8)
		local sb = K.group(s8, "StonesB")
		box(sb, V(30, 24, 28), CFrame.new(-136, 156, -58) * A(r(-8), r(-20), r(16)), DARK, M.Slate)
		box(sb, V(38, 28, 34), CFrame.new(140, 118, -66) * A(r(12), r(30), r(-10)), STONE, M.Slate)
		box(sb, V(26, 20, 24), CFrame.new(-34, 58, -92) * A(r(6), r(-16), r(8)), PALE, M.Slate)
		ell(sb, V(22, 18, 22), CFrame.new(10, 262, 74), STONE, M.Slate)

		-- 9 SUSPENDED RELIC: hanging in the notch of the platform; brass rings, orbiting shards, a pale glow
		local s9 = K.stage(m, 9)
		local rl = K.group(s9, "Relic")
		K.marker(rl, "RelicC", V(0, 62, -26))
		box(rl, V(22, 22, 22), CFrame.new(0, 62, -26) * A(r(45), r(45), 0), PALE, M.Slate)
		cyl(rl, 40, 1.6, CFrame.new(0, 62, -26) * A(r(14), 0, r(8)), BRASS, M.Metal)
		cyl(rl, 30, 1.6, CFrame.new(0, 62, -26) * A(r(-30), 0, r(-18)), BRASS, M.Metal)
		for i = 0, 2 do
			local a = i / 3 * math.pi * 2
			box(rl, V(5, 5, 5), CFrame.new(math.cos(a) * 24, 66 + i * 3, -26 + math.sin(a) * 24) * A(r(30), r(40), r(20)), STONE, M.Slate)
		end
		local rg = K.group(s9, "RelicGlow")
		ell(rg, V(12, 12, 12), CFrame.new(0, 62, -26), GLOW0, M.SmoothPlastic)

		-- 10 ANCIENT TIMBER BRIDGES / ROOTS: timber that reaches for the wings and STOPS SHORT
		local s10 = K.stage(m, 10)
		local rt = K.group(s10, "Roots")
		local function root(a, b, n, sag, thick)
			local prev
			for i = 0, n do
				local t = i / n
				local p = a:Lerp(b, t) + V(0, -sag * math.sin(t * math.pi), math.sin(t * 5 + a.X) * 3)
				if prev then
					local seg = bar(rt, prev, p, thick * (1 - 0.5 * t), if i % 2 == 0 then TIMBER else TIMBER2, M.Wood)
					seg:SetAttribute("Idx", i)
				end
				prev = p
			end
		end
		root(V(-44, 82, 8), V(-82, 122, -6), 6, 10, 6)
		root(V(-42, 80, 20), V(-86, 110, 14), 5, 8, 4)
		root(V(44, 80, 24), V(90, 80, 28), 6, 8, 6)
		root(V(12, 92, 34), V(50, 186, 26), 5, 4, 4)
		root(V(-30, 66, -34), V(-58, 60, -76), 4, 5, 4)

		-- 11 SKY CROWN: a broken brass ring and a capstone floating high above the roof, separated from it
		local s11 = K.stage(m, 11)
		local cr = K.group(s11, "Crown")
		K.marker(cr, "CrownC", V(0, 292, 26))
		for i = 0, 9 do
			if i ~= 3 and i ~= 4 then
				local a = i / 10 * math.pi * 2
				local p = V(math.cos(a) * 36, 292 + math.sin(a) * 8, 26 + math.sin(a) * 36)
				box(cr, V(15, 5, 7), CFrame.lookAt(p, V(0, 292, 26)) * A(0, 0, r(10)), if i % 2 == 0 then BRASS else PALE, M.Metal)
			end
		end
		box(cr, V(12, 20, 12), CFrame.new(0, 302, 26) * A(r(180), r(45), 0), PALE, M.Slate)
		box(cr, V(5, 18, 5), CFrame.new(0, 320, 26), BRASS, M.Metal)
		return m
	end,
}
