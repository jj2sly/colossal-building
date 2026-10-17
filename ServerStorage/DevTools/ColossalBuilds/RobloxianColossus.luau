--!nonstrict
-- FORGOTTEN F5 (server-only template, id "Fg6d"): an ancient ceremonial monument in CLASSIC block-character proportions
-- (R6 logic, unit u = 42: legs 2u, torso 2u wide x 2u tall, 1u head, 1u limbs). Upright, symmetrical, iconic: a studded base, big
-- studded feet, block legs, a broad block torso with a chest cavity, block arms (left hanging, right lowered outward gripping),
-- a plain cylinder head, a helmet with a three-slab crown, a portal-frame monument behind it, and a giant studded brick-topped
-- staff planted well clear of the body. Stone / aged concrete / dark material / restrained brass; cold glow only in the heart.
-- Groups: Base, Feet, Legs, Torso, ArmL, ArmR, Head, Helmet, Monument, Heart (Order), Tool, Finish.
-- Markers: LegsC, HeadC, ShoulderLC, ShoulderRC, ToolC, HeartC.
return {
	Id = "Fg6d",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, cylZ, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.cylZ, K.wedge
		local PALE, GRAY, CONC, DARK, BRASS = RGB(196, 192, 178), RGB(142, 140, 134), RGB(118, 116, 110), RGB(66, 66, 72), RGB(172, 136, 72)
		local GLOW0 = RGB(70, 110, 140)
		local m = K.template("Fg6d")
		local A, r = CFrame.Angles, math.rad
		local function stud(parent, x, y, z, d, col)
			return cyl(parent, d or 11, 5, CFrame.new(x, y + 2.5, z), col or PALE, M.Slate)
		end

		-- 1 STUDDED BASE: a two-step monument base with a ring of big studs on the lower step
		local s1 = K.stage(m, 1)
		local base = K.group(s1, "Base")
		box(base, V(156, 10, 128), CFrame.new(0, 5, 0), CONC, M.Concrete)
		box(base, V(128, 8, 104), CFrame.new(0, 14, 0), PALE, M.Slate)
		for i = 0, 7 do
			local x = -63 + i * 18
			stud(base, x, 10, -55, 12, GRAY)
			stud(base, x, 10, 55, 12, GRAY)
		end
		for i = 1, 4 do
			local z = -55 + i * 22
			stud(base, -71, 10, z, 12, GRAY)
			stud(base, 71, 10, z, 12, GRAY)
		end
		K.marker(base, "LegsC", V(0, 18, 0))

		-- 2 FEET: two massive block feet, studded on top
		local s2 = K.stage(m, 2)
		local ft = K.group(s2, "Feet")
		for _, sx in { -1, 1 } do
			box(ft, V(40, 13, 56), CFrame.new(sx * 22, 24.5, -6), DARK, M.Slate)
			stud(ft, sx * 22, 31, -20, 14, PALE)
			stud(ft, sx * 22, 31, 8, 14, PALE)
		end

		-- 3 LEGS: two plain block legs
		local s3 = K.stage(m, 3)
		local lg = K.group(s3, "Legs")
		for _, sx in { -1, 1 } do
			box(lg, V(40, 78, 42), CFrame.new(sx * 22, 69, -2), if sx < 0 then GRAY else PALE, M.Slate)
		end
		box(lg, V(86, 6, 44), CFrame.new(0, 108, -2), BRASS, M.Metal) -- a plain belt band where legs meet the torso

		-- 4 TORSO: the broad block torso
		local s4 = K.stage(m, 4)
		local tr = K.group(s4, "Torso")
		box(tr, V(86, 78, 44), CFrame.new(0, 150, -2), PALE, M.Slate)
		box(tr, V(86, 6, 44), CFrame.new(0, 192, -2), GRAY, M.Slate)
		K.marker(tr, "HeartC", V(0, 150, -24))

		-- 5 LEFT ARM (hangs at the side) and 6 RIGHT ARM (lowered outward, gripping the staff)
		local s5 = K.stage(m, 5)
		local al = K.group(s5, "ArmL")
		box(al, V(40, 84, 40), CFrame.new(-64, 150, -2) * A(0, 0, r(5)), GRAY, M.Slate)
		box(al, V(42, 8, 42), CFrame.new(-65, 107, -2) * A(0, 0, r(5)), DARK, M.Slate)
		K.marker(al, "ShoulderLC", V(-64, 190, -2))
		local s6 = K.stage(m, 6)
		local ar = K.group(s6, "ArmR")
		box(ar, V(40, 84, 40), CFrame.new(95, 157, -2) * A(0, 0, r(50)), PALE, M.Slate)
		box(ar, V(44, 9, 44), CFrame.new(121, 128, -2) * A(0, 0, r(50)), DARK, M.Slate)
		K.marker(ar, "ShoulderRC", V(63, 184, -2))

		-- 7 HEAD: a simple cylinder head with two hollow eye slits, a flat stud on top
		local s7 = K.stage(m, 7)
		local hd = K.group(s7, "Head")
		K.marker(hd, "HeadC", V(0, 196, -2))
		cyl(hd, 44, 42, CFrame.new(0, 216, -2), PALE, M.Slate)
		box(hd, V(10, 5, 4), CFrame.new(-9, 220, -23), RGB(30, 30, 34), M.Slate)
		box(hd, V(10, 5, 4), CFrame.new(9, 220, -23), RGB(30, 30, 34), M.Slate)
		cyl(hd, 22, 5, CFrame.new(0, 239.5, -2), GRAY, M.Slate)

		-- 8 HELMET / CROWN: a block helmet cap and a three-slab crown
		local s8 = K.stage(m, 8)
		local hm = K.group(s8, "Helmet")
		box(hm, V(50, 16, 50), CFrame.new(0, 238, -2), GRAY, M.Slate)
		box(hm, V(54, 4, 54), CFrame.new(0, 232, -2), BRASS, M.Metal)
		for _, x in { -17, 0, 17 } do
			box(hm, V(11, if x == 0 then 40 else 30, 11), CFrame.new(x, if x == 0 then 266 else 261, -2), PALE, M.Slate)
		end

		-- 9 BACK MONUMENT: a tall portal frame rising behind the body (two pillars and a heavy lintel), studded on top
		local s9 = K.stage(m, 9)
		local mo = K.group(s9, "Monument")
		for _, sx in { -1, 1 } do
			box(mo, V(30, 236, 30), CFrame.new(sx * 66, 126, 66), CONC, M.Concrete)
			box(mo, V(36, 8, 36), CFrame.new(sx * 66, 22, 66), GRAY, M.Slate)
		end
		box(mo, V(168, 28, 32), CFrame.new(0, 250, 66), GRAY, M.Slate)
		box(mo, V(168, 4, 34), CFrame.new(0, 266, 66), BRASS, M.Metal)
		for i = 0, 5 do
			stud(mo, -70 + i * 28, 264, 66, 14, PALE)
		end

		-- 10 STAR METAL HEART: a framed chest cavity, a restrained glowing core and a FEW major seams
		local s10 = K.stage(m, 10)
		local ht = K.group(s10, "Heart")
		box(ht, V(34, 34, 5), CFrame.new(0, 150, -24.5), RGB(30, 30, 34), M.Slate)
		box(ht, V(40, 4, 6), CFrame.new(0, 169, -25), BRASS, M.Metal)
		box(ht, V(40, 4, 6), CFrame.new(0, 131, -25), BRASS, M.Metal)
		box(ht, V(4, 38, 6), CFrame.new(-19, 150, -25), BRASS, M.Metal)
		box(ht, V(4, 38, 6), CFrame.new(19, 150, -25), BRASS, M.Metal)
		local core = box(ht, V(20, 20, 6), CFrame.new(0, 150, -26) * A(0, 0, r(45)), GLOW0, M.SmoothPlastic)
		core:SetAttribute("Order", 1)
		local function seam(c, sz, o)
			box(ht, sz, c, GLOW0, M.SmoothPlastic):SetAttribute("Order", o)
		end
		seam(CFrame.new(0, 176, -24.4), V(4, 28, 1.5), 2) -- up toward the neck
		seam(CFrame.new(-30, 150, -24.4), V(24, 4, 1.5), 2) -- across the chest
		seam(CFrame.new(30, 150, -24.4), V(24, 4, 1.5), 2)
		seam(CFrame.new(0, 120, -24.4), V(4, 22, 1.5), 3) -- down toward the belt

		-- 11 GIANT STUDDED TOOL: a brick-topped staff planted clear of the body, gripped by the lowered right hand
		local s11 = K.stage(m, 11)
		local tl = K.group(s11, "Tool")
		K.marker(tl, "ToolC", V(128, 122, -14))
		box(tl, V(34, 16, 34), CFrame.new(128, 2, -14), CONC, M.Concrete) -- foot
		cyl(tl, 11, 236, CFrame.new(128, 118, -14), DARK, M.Metal)
		box(tl, V(20, 24, 20), CFrame.new(128, 122, -14), BRASS, M.Metal) -- grip block
		-- a stacked totem of three studded bricks (reads as a builder's brick tower, not a hammer or a sword)
		local bricks = { { 58, 190, -3 }, { 48, 214, 4 }, { 38, 238, -2 } }
		for _, bk in bricks do
			box(tl, V(bk[1], 22, 34), CFrame.new(128 + bk[3], bk[2], -14), if bk[2] == 214 then GRAY else PALE, M.Slate)
		end
		for i = 0, 1 do
			stud(tl, 128 - 8 + i * 16, 249, -14, 12, GRAY)
		end
		for i = 0, 2 do
			stud(tl, 125 - 16 + i * 16, 201, -14, 12, GRAY)
		end

		-- 12 ANCIENT FINISH: large masses, not trim: a great halo slab behind the head, two heavy shoulder slabs, tall crown wings
		local s12 = K.stage(m, 12)
		local fn = K.group(s12, "Finish")
		cylZ(fn, 118, 14, CFrame.new(0, 226, 34), CONC, M.Concrete)
		cylZ(fn, 126, 5, CFrame.new(0, 226, 40), BRASS, M.Metal)
		for _, sx in { -1, 1 } do
			box(fn, V(44, 16, 50), CFrame.new(sx * 58, 200, -2), GRAY, M.Slate)
			stud(fn, sx * 58, 208, -2, 14, PALE)
			box(fn, V(12, 44, 18), CFrame.new(sx * 38, 262, 2) * A(0, 0, r(sx * -10)), PALE, M.Slate)
		end
		return m
	end,
}
