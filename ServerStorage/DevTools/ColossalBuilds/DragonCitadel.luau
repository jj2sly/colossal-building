--!nonstrict
-- DRAGON CITADEL (Epic). A giant dragon perched on, and gripping, a squat stone citadel. Facing -Z (the spawn):
-- the fortress stays in the lower third (walls to y 40, four squat towers to y 54); the dragon's torso/chest sits on it, a
-- thick neck rises forward to a huge horned head (~y 145, out at z -105), and two enormous bat wings spread to ~212 across,
-- clearly wider than the fortress (104). The forelegs grip the front wall, the tail drapes over the back wall and round
-- one side. About 212 wide x 158 tall x ~180 deep; placed with Yaw 30 so the neck and head read in profile.
-- Groups for the client show: Body (torso, chest, haunches, forelegs, spines), Neck (marker NeckBase), Head (marker
-- HeadPivot, Mouth), Eye, Core (chest glow), WingL / WingR (marker WingRootL / WingRootR), Tail (marker TailBase), Gate (fortress
-- gate glow). Everything else is the fortress (static).
return {
	Id = "DragonCitadel",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, ell, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.ell, K.wedge
		local STONE, STONE2, STONE3, ROOF = RGB(112, 108, 104), RGB(92, 88, 86), RGB(70, 68, 68), RGB(60, 48, 52)
		local SCALE, SCALE2, BELLY, BONE = RGB(134, 36, 36), RGB(104, 26, 30), RGB(196, 148, 92), RGB(62, 28, 30)
		local WING, HORN, GLOWC = RGB(150, 46, 42), RGB(228, 210, 170), RGB(96, 40, 26)
		local m = K.template("DragonCitadel")
		-- a triangle as two wedges (the standard right-triangle split), thickness th
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
		-- a rounded limb/neck segment (ellipsoid) from a to b
		local function seg(parent: Instance, a: Vector3, b: Vector3, w: number, h: number, col: Color3, mat)
			return ell(parent, V(w, h, (b - a).Magnitude + math.min(w, h) * 1.1), CFrame.lookAt((a + b) / 2, b), col, mat)
		end

		-- 1 FORTRESS FOUNDATION: a dark rock apron, a battered stone base (104 x 88) with sloped skirts
		local s1 = K.stage(m, 1)
		cyl(s1, 132, 3, CFrame.new(0, 1.5, 0), STONE3, M.Slate)
		box(s1, V(104, 15, 88), CFrame.new(0, 10.5, 0), STONE2, M.Slate)
		for _, r in { 0, 90, 180, 270 } do
			local d = CFrame.Angles(0, math.rad(r), 0)
			local depth = if r % 180 == 0 then 104 else 88
			local off = if r % 180 == 0 then 50 else 58
			wedge(s1, V(depth, 14, 12), d * CFrame.new(0, 10, -off), STONE3, M.Slate)
		end

		-- 2 FORTRESS WALLS: a low curtain wall (to y 40) with a dark gate, four squat towers (to y 54) and the inner keep deck
		local s2 = K.stage(m, 2)
		for _, sx in { -1, 1 } do
			box(s2, V(38, 22, 8), CFrame.new(sx * 29, 29, -40), STONE, M.Slate) -- front wall either side of the gate
			box(s2, V(8, 22, 72), CFrame.new(sx * 48, 29, 0), STONE, M.Slate)
			for _, sz in { -1, 1 } do
				cyl(s2, 18, 36, CFrame.new(sx * 46, 36, sz * 38), STONE2, M.Slate)
				cyl(s2, 21, 3, CFrame.new(sx * 46, 55.5, sz * 38), ROOF, M.Slate)
			end
		end
		box(s2, V(96, 22, 8), CFrame.new(0, 29, 40), STONE, M.Slate)
		box(s2, V(20, 8, 8), CFrame.new(0, 36, -40), STONE, M.Slate) -- gate lintel
		local gate = K.group(s2, "Gate")
		box(gate, V(20, 14, 2), CFrame.new(0, 25, -37), GLOWC, M.Slate)
		box(s2, V(88, 10, 72), CFrame.new(0, 23, 0), STONE3, M.Slate) -- keep deck

		-- 3 DRAGON TORSO / CHEST: one big body on the keep, a deep raised chest, haunches, wing shoulders and a chest core
		local s3 = K.stage(m, 3)
		local body = K.group(s3, "Body")
		ell(body, V(48, 34, 76), CFrame.new(0, 50, 10), SCALE)
		ell(body, V(44, 40, 36), CFrame.new(0, 58, -20) * CFrame.Angles(math.rad(-15), 0, 0), SCALE)
		ell(body, V(30, 28, 10), CFrame.new(0, 54, -36) * CFrame.Angles(math.rad(-15), 0, 0), BELLY) -- chest plate
		for _, sx in { -1, 1 } do
			ell(body, V(22, 28, 32), CFrame.new(sx * 20, 44, 28), SCALE2)
			ell(body, V(22, 24, 26), CFrame.new(sx * 20, 64, -12), SCALE2)
		end
		local core = K.group(body, "Core")
		ell(core, V(14, 18, 4), CFrame.new(0, 56, -39) * CFrame.Angles(math.rad(-15), 0, 0), GLOWC)

		-- 4 NECK: a thick neck rising forward from the chest in three segments
		local s4 = K.stage(m, 4)
		local neck = K.group(s4, "Neck")
		local N0, N1, N2, N3 = V(0, 68, -30), V(0, 92, -46), V(0, 112, -58), V(0, 126, -64)
		seg(neck, N0, N1, 24, 24, SCALE)
		seg(neck, N1, N2, 21, 21, SCALE)
		seg(neck, N2, N3, 19, 19, SCALE)
		seg(neck, N0 + V(0, -4, -8), N2 + V(0, -3, -8), 12, 10, BELLY) -- throat
		K.marker(neck, "NeckBase", N0)

		-- 5 HEAD: a huge readable head (skull 26 x 22 x 32, long snout, open jaw), two big swept horns, glowing eyes
		local s5 = K.stage(m, 5)
		local head = K.group(s5, "Head")
		ell(head, V(26, 22, 32), CFrame.new(0, 134, -72), SCALE)
		box(head, V(18, 12, 28), CFrame.new(0, 130, -92) * CFrame.Angles(math.rad(8), 0, 0), SCALE)
		box(head, V(14, 5, 24), CFrame.new(0, 121, -88) * CFrame.Angles(math.rad(-10), 0, 0), SCALE2) -- open lower jaw
		box(head, V(24, 5, 10), CFrame.new(0, 143, -76), SCALE2) -- brow
		for _, sx in { -1, 1 } do
			bar(head, V(sx * 9, 142, -66), V(sx * 17, 154, -46), 5, HORN, M.SmoothPlastic)
			bar(head, V(sx * 17, 154, -46), V(sx * 19, 158, -32), 3.4, HORN, M.SmoothPlastic)
			local eye = K.group(head, "Eye")
			ell(eye, V(5, 4, 3), CFrame.new(sx * 9, 138, -86) * CFrame.Angles(0, sx * 0.4, 0), GLOWC)
		end
		K.marker(head, "HeadPivot", N3)
		K.marker(head, "Mouth", V(0, 124, -106), V(0, -0.15, -1))

		-- 6 WINGS: two enormous bat wings (span ~212): an arm bone up to the wrist, three finger bones and a scalloped membrane
		local s6 = K.stage(m, 6)
		for _, sx in { -1, 1 } do
			local tag = if sx < 0 then "L" else "R"
			local wing = K.group(s6, "Wing" .. tag)
			local function P(x, y, z)
				return V(sx * x, y, z)
			end
			local S, E = P(24, 76, -8), P(70, 138, 0)
			local F1, F2, F3 = P(106, 122, 6), P(104, 90, 12), P(82, 64, 14)
			local M1, M2, M3, R = P(95, 106, 10), P(88, 80, 13), P(58, 68, 12), P(26, 62, 8)
			for _, t in { { E, F1, M1 }, { E, M1, F2 }, { E, F2, M2 }, { E, M2, F3 }, { E, F3, M3 }, { E, M3, R }, { S, E, R } } do
				tri(wing, t[1], t[2], t[3], 1.6, WING, M.Fabric)
			end
			bar(wing, S, E, 6, BONE, M.SmoothPlastic)
			for _, f in { F1, F2, F3 } do
				bar(wing, E, f, 3.2, BONE, M.SmoothPlastic)
			end
			ell(wing, V(7, 7, 7), CFrame.new(E), BONE)
			K.marker(wing, "WingRoot" .. tag, S)
		end

		-- 7 TAIL / CLAWS: forelegs gripping the front wall, and a long tail draping over the back wall and round one side
		local s7 = K.stage(m, 7)
		local body7 = K.group(s7, "Body")
		for _, sx in { -1, 1 } do
			seg(body7, V(sx * 18, 56, -26), V(sx * 19, 44, -40), 12, 12, SCALE2)
			ell(body7, V(15, 7, 18), CFrame.new(sx * 19, 43.5, -44), SCALE2)
			for _, tx in { -4, 0, 4 } do
				wedge(body7, V(3, 5, 6), CFrame.new(sx * 19 + tx, 42, -54) * CFrame.Angles(0, 0, 0), HORN, M.SmoothPlastic)
			end
		end
		local tail = K.group(s7, "Tail")
		local T = { V(0, 50, 44), V(8, 44, 62), V(28, 34, 76), V(54, 28, 74), V(70, 24, 58) }
		for i = 1, #T - 1 do
			seg(tail, T[i], T[i + 1], 18 - i * 3, 16 - i * 2.6, SCALE)
		end
		tri(tail, T[5] + V(-2, 0, 0), T[5] + V(10, 0, -10), T[5] + V(6, 0, 4), 2, SCALE2, M.SmoothPlastic)
		K.marker(tail, "TailBase", T[1])

		-- 8 CITADEL CROWN / SPINES: big dorsal plates along the back and neck (the dragon's ridge, not spike spam) and the
		-- fortress crown: battlement caps on the walls
		local s8 = K.stage(m, 8)
		local spine = K.group(s8, "Body")
		for i, p in { { 0, 66, 36, 10 }, { 0, 70, 20, 12 }, { 0, 72, 4, 13 } } do
			wedge(spine, V(3, p[4], 12), CFrame.new(p[1], p[2] + p[4] / 2, p[3]) * CFrame.Angles(0, math.rad(180), 0), SCALE2, M.SmoothPlastic)
			local _ = i
		end
		local neckSp = K.group(s8, "Neck")
		for _, p in { { 86, -42, 9 }, { 106, -54, 8 } } do
			wedge(neckSp, V(3, p[3], 10), CFrame.new(0, p[1] + 10 + p[3] / 2, p[2] + 2) * CFrame.Angles(0, math.rad(180), 0), SCALE2, M.SmoothPlastic)
		end
		for _, sx in { -1, 1 } do
			box(s8, V(40, 3, 10), CFrame.new(sx * 29, 41.5, -40), STONE2, M.Slate)
			box(s8, V(10, 3, 74), CFrame.new(sx * 48, 41.5, 0), STONE2, M.Slate)
		end
		box(s8, V(98, 3, 10), CFrame.new(0, 41.5, 40), STONE2, M.Slate)
		return m
	end,
}
