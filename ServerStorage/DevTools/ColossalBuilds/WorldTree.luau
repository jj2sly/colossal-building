--!nonstrict
-- WORLD TREE (Legendary). A monumental ancient tree: a root mound with seven great buttress roots fanning out across the deck
-- (to r ~86), a thick tapered trunk (58 -> 36 across) that leans and kinks as it rises, six huge primary branches reaching out
-- in different directions, and a crown built from separate canopy masses (one per branch plus a top crown) with open sky
-- between them; hanging vines, an ancient stone shrine arch at the trunk foot and a glowing heartwood core.
-- About 230 wide (crown) x 220 tall.
-- Groups for the client show: Branch1..Branch6 (each holds its branch segments and its canopy masses; marker BranchRootN),
-- Crown (top crown masses, marker CrownPivot), Vine, Core, Bloom (golden blossom clusters). Canopy ellipsoids carry Leaf = true.
return {
	Id = "WorldTree",
	Build = function(K)
		local V, M, RGB, box, cylZ, ell, wedge = K.V, K.M, K.RGB, K.box, K.cylZ, K.ell, K.wedge
		local BARK, BARK2, ROOT, MOSS, EARTH = RGB(104, 74, 50), RGB(86, 60, 42), RGB(94, 68, 46), RGB(74, 106, 58), RGB(98, 82, 62)
		local LEAF, LEAF2, LEAF3, GOLDL = RGB(60, 114, 56), RGB(78, 134, 64), RGB(48, 94, 50), RGB(222, 186, 82)
		local STONE, CORE = RGB(150, 146, 132), RGB(86, 64, 34)
		local m = K.template("WorldTree")
		local LEAFA = { Leaf = true }
		local function limb(parent: Instance, a: Vector3, b: Vector3, d: number, col: Color3)
			return cylZ(parent, d, (b - a).Magnitude + d * 0.4, CFrame.lookAt((a + b) / 2, b), col, M.Wood)
		end
		local T0, T1, T2, T3 = V(0, 2, 0), V(3, 54, -2), V(-3, 98, 2), V(1, 134, 0)
		-- the six primary branches: root on the trunk, elbow, tip (the canopy mass sits just above the tip)
		local BR = {
			{ V(-12, 96, 0), V(-46, 116, -6), V(-76, 128, -10) },
			{ V(12, 98, 2), V(48, 114, 4), V(78, 124, 8) },
			{ V(-8, 112, -10), V(-34, 140, -40), V(-50, 156, -58) },
			{ V(8, 114, 10), V(38, 142, 36), V(56, 158, 50) },
			{ V(6, 124, -8), V(30, 158, -22), V(42, 176, -30) },
			{ V(-6, 126, 8), V(-30, 158, 22), V(-44, 176, 30) },
		}
		local function branch(stage: Instance, i: number)
			local b = BR[i]
			local g = K.group(stage, "Branch" .. i)
			limb(g, b[1], b[2], 17, BARK)
			ell(g, V(16, 16, 16), CFrame.new(b[2]), BARK2, M.Wood)
			limb(g, b[2], b[3], 11.5, BARK)
			K.marker(g, "BranchRoot" .. i, b[1])
		end
		local function canopy(stage: Instance, i: number, big: number)
			local b = BR[i]
			local g = K.group(stage, "Branch" .. i)
			local out = (b[3] - b[1]) * V(1, 0, 1)
			out = if out.Magnitude > 0 then out.Unit else V(1, 0, 0)
			local c = b[3] + V(0, 8, 0)
			local side = out:Cross(Vector3.yAxis)
			ell(g, V(80, 32, 68) * big, CFrame.lookAt(c, c + out), if i % 2 == 0 then LEAF else LEAF2, M.Grass, LEAFA)
			ell(g, V(50, 26, 44) * big, CFrame.new(c + out * 22 + V(0, -7, 0) + side * 16), LEAF3, M.Grass, LEAFA)
			ell(g, V(46, 24, 40) * big, CFrame.new(c - out * 18 + V(0, 8, 0) - side * 14), if i % 2 == 0 then LEAF2 else LEAF, M.Grass, LEAFA)
		end

		-- 1 ROOT PLATFORM: an earth mound with moss and seven great buttress roots fanning out, plus surface root tendrils
		local s1 = K.stage(m, 1)
		ell(s1, V(150, 14, 140), CFrame.new(0, 0, 0), EARTH, M.Ground)
		ell(s1, V(116, 10, 108), CFrame.new(0, 3, 0), MOSS, M.Grass)
		for k = 0, 6 do
			local a = math.rad(k * 360 / 7 + 12 + (k % 2) * 9)
			local d = V(math.cos(a), 0, math.sin(a))
			local len = 44 + (k % 3) * 6
			local c = d * (26 + len / 2) + V(0, 17, 0)
			wedge(s1, V(10, 34, len), CFrame.lookAt(c, c + d), ROOT, M.Wood)
			local t = d * math.min(26 + len + 4, 75) + V(0, 3, 0) -- surface tendril, kept inside the deck (r <= 86)
			ell(s1, V(9, 6, 22), CFrame.lookAt(t, t + d), ROOT, M.Wood)
		end

		-- 2 LOWER TRUNK: a huge flared base, the thick lower trunk (58 across) and the heartwood core niche (dark until it wakes)
		local s2 = K.stage(m, 2)
		ell(s2, V(84, 34, 80), CFrame.new(0, 10, 0), BARK2, M.Wood)
		limb(s2, T0, T1, 58, BARK)
		ell(s2, V(56, 20, 54), CFrame.new(T1), BARK2, M.Wood)
		box(s2, V(16, 22, 2), CFrame.new(1, 30, -29.2), RGB(40, 30, 22), M.Wood)
		local core = K.group(s2, "Core")
		ell(core, V(9, 13, 4), CFrame.new(1, 30, -30), CORE, M.SmoothPlastic)

		-- 3 UPPER TRUNK: the trunk tapers (46 -> 36) and kinks as it rises to the crown fork
		local s3 = K.stage(m, 3)
		limb(s3, T1, T2, 46, BARK)
		ell(s3, V(46, 18, 44), CFrame.new(T2), BARK2, M.Wood)
		limb(s3, T2, T3, 36, BARK)
		local crownBase = K.group(s3, "Crown")
		ell(crownBase, V(42, 24, 40), CFrame.new(T3), BARK2, M.Wood)
		K.marker(crownBase, "CrownPivot", T3)

		-- 4 FIRST MAJOR BRANCHES: the two great low side limbs and the front-left limb
		local s4 = K.stage(m, 4)
		for _, i in { 1, 2, 3 } do
			branch(s4, i)
		end

		-- 5 REMAINING MAJOR BRANCHES: back-right and the two high limbs
		local s5 = K.stage(m, 5)
		for _, i in { 4, 5, 6 } do
			branch(s5, i)
		end

		-- 6 LOWER CROWN: big separate canopy masses on the four lower branches (open sky between them)
		local s6 = K.stage(m, 6)
		for _, i in { 1, 2, 3, 4 } do
			canopy(s6, i, 1)
		end

		-- 7 UPPER CROWN: canopy masses on the two high branches and the great top crown
		local s7 = K.stage(m, 7)
		for _, i in { 5, 6 } do
			canopy(s7, i, 0.95)
		end
		local crown = K.group(s7, "Crown")
		ell(crown, V(92, 36, 80), CFrame.new(2, 186, 0), LEAF, M.Grass, LEAFA)
		ell(crown, V(56, 26, 50), CFrame.new(-22, 176, -18), LEAF3, M.Grass, LEAFA)
		ell(crown, V(52, 24, 46), CFrame.new(24, 178, 20), LEAF2, M.Grass, LEAFA)

		-- 8 HANGING ROOTS / VINES / ANCIENT STRUCTURES: vines hanging from the lower crown and a stone shrine arch at the trunk foot
		local s8 = K.stage(m, 8)
		for _, v in { { -60, 116, -8, 34 }, { -34, 110, -4, 26 }, { 62, 112, 6, 34 }, { 36, 108, 4, 24 }, { -40, 144, -48, 30 }, { 44, 146, 42, 30 }, { -22, 150, -28, 22 } } do
			local g = K.group(s8, "Vine")
			box(g, V(1.8, v[4], 1.8), CFrame.new(v[1], v[2] - v[4] / 2, v[3]), MOSS, M.Grass)
		end
		for _, sx in { -1, 1 } do
			box(s8, V(7, 28, 7), CFrame.new(sx * 14, 14, -40), STONE, M.Slate)
			box(s8, V(8, 14, 3), CFrame.new(sx * 46, 7, -52) * CFrame.Angles(math.rad(-8), sx * 0.4, sx * 0.1), STONE, M.Slate)
		end
		box(s8, V(38, 7, 9), CFrame.new(0, 31.5, -40), STONE, M.Slate)

		-- 9 FINAL CROWN: the crown cap and five golden blossom clusters set into the canopy
		local s9 = K.stage(m, 9)
		local cap = K.group(s9, "Crown")
		ell(cap, V(54, 24, 48), CFrame.new(6, 203, -2), LEAF2, M.Grass, LEAFA)
		for _, p in { { -74, 142, -12 }, { 80, 138, 10 }, { -48, 170, -60 }, { 58, 172, 52 }, { 4, 214, 0 } } do
			local g = K.group(s9, "Bloom")
			ell(g, V(14, 9, 14), CFrame.new(p[1], p[2], p[3]), GOLDL, M.SmoothPlastic, LEAFA)
		end
		return m
	end,
}
