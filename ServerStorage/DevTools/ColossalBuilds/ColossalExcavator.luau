--!nonstrict
-- COLOSSAL EXCAVATOR (Rare). A long, low, wide tracked chassis (two 70-long tracks), a massive orange upper body with a heavy rear
-- counterweight and a cab on the spawn side, a thick boom, a long stick and an absurdly big bucket (44 wide), with a mound of
-- earth in front for the finale. ~136 long x 82 tall x 60 deep. Long axis X, digging toward +X. Front faces -Z.
-- Groups for the client show: Boom (boom + boom ram), Stick (stick, elbow cap, stick ram), Bucket (bucket, teeth, linkage),
-- Load (the dirt in the bucket, hidden by the show until the scoop), Mound (the dirt pile), markers Pivot (boom foot), Elbow,
-- Wrist, Slew (turret centre).
return {
	Id = "ColossalExcavator",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, cylZ, ell = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.cylZ, K.ell
		local ORANGE, ORANGE2, DARK, STEEL, STEEL2 = RGB(240, 150, 30), RGB(204, 112, 24), RGB(48, 50, 58), RGB(150, 156, 168), RGB(104, 110, 124)
		local GLASS, DIRT, DIRT2, YEL = RGB(120, 160, 190), RGB(120, 84, 52), RGB(100, 68, 42), RGB(250, 214, 60)
		local m = K.template("ColossalExcavator")
		local SH = -22 -- centre the machine on the origin
		local function X(x: number): number
			return x + SH
		end
		local ZB = 6 -- the boom / stick / bucket plane (the cab sits on the spawn side of it)
		local P0, E, W = V(X(4), 36, ZB), V(X(36), 84, ZB), V(X(70), 52, ZB)

		-- 1 TRACKS: two long, chunky tracks (70 x 18 x 16) with big end wheels and rollers, and a track-frame cross beam
		local s1 = K.stage(m, 1)
		for _, sz in { -1, 1 } do
			box(s1, V(70, 16, 15), CFrame.new(X(-4), 9, sz * 22), DARK, M.Metal)
			for _, ex in { -34, 28 } do
				cylZ(s1, 20, 15, CFrame.new(X(ex), 9, sz * 22), DARK, M.Metal)
				cylZ(s1, 11, 15.8, CFrame.new(X(ex), 9, sz * 22), STEEL, M.Metal)
			end
			for _, rx in { -18, -4, 10 } do
				cylZ(s1, 9, 15.8, CFrame.new(X(rx), 3, sz * 22), STEEL, M.Metal)
			end
		end
		box(s1, V(50, 10, 32), CFrame.new(X(-4), 13, 0), ORANGE2, M.Metal)

		-- 2 CHASSIS / COUNTERWEIGHT: a wide orange deck (66 x 12 x 54), the turret ring, a big rear counterweight (20 x 28 x 54) and the engine bay
		local s2 = K.stage(m, 2)
		box(s2, V(66, 10, 54), CFrame.new(X(-4), 24, 0), ORANGE, M.SmoothPlastic)
		cyl(s2, 34, 4, CFrame.new(X(2), 30, 0), DARK, M.Metal)
		K.marker(s2, "Slew", V(X(2), 30, 0))
		box(s2, V(22, 28, 54), CFrame.new(X(-33), 43, 0), STEEL2, M.Metal)
		box(s2, V(26, 16, 48), CFrame.new(X(-12), 40, 0), ORANGE, M.SmoothPlastic)

		-- 3 CAB: a tall cab (24 x 28 x 26) on the spawn side, a big front window and a roof
		local s3 = K.stage(m, 3)
		box(s3, V(26, 28, 26), CFrame.new(X(18), 49, -14), ORANGE, M.SmoothPlastic)
		box(s3, V(1.4, 16, 20), CFrame.new(X(31.4), 53, -14), GLASS, M.Glass).Transparency = 0.2
		box(s3, V(1.2, 14, 16), CFrame.new(X(18), 53, -27.2), GLASS, M.Glass).Transparency = 0.2
		box(s3, V(32, 3, 32), CFrame.new(X(18), 64.5, -14), ORANGE2, M.SmoothPlastic)

		-- 4 BOOM: a very thick two-segment-looking boom (11 thick) from the foot up to the elbow, with a steel elbow cap
		local s4 = K.stage(m, 4)
		K.marker(s4, "Pivot", P0)
		K.marker(s4, "Elbow", E)
		local boom = K.group(s4, "Boom")
		bar(boom, P0, E, 11, ORANGE, M.SmoothPlastic)
		cylZ(boom, 17, 15, CFrame.new(P0), STEEL2, M.Metal)
		cylZ(boom, 16, 15, CFrame.new(E), STEEL2, M.Metal)

		-- 5 STICK / BUCKET: a long stick down to the wrist, and the enormous bucket: back plate, floor, two side plates, five teeth
		local s5 = K.stage(m, 5)
		K.marker(s5, "Wrist", W)
		local stick = K.group(s5, "Stick")
		bar(stick, E, W, 9, ORANGE, M.SmoothPlastic)
		cylZ(stick, 13, 13, CFrame.new(W), STEEL2, M.Metal)
		local bucket = K.group(s5, "Bucket")
		local B = CFrame.new(W) * CFrame.Angles(0, 0, -math.rad(30)) -- the opening faces +x and down at rest
		box(bucket, V(3, 36, 46), B * CFrame.new(-2, -13, 0), STEEL, M.Metal)
		box(bucket, V(36, 3, 46), B * CFrame.new(15, -30, 0), STEEL, M.Metal)
		for _, sz in { -1, 1 } do
			box(bucket, V(34, 32, 3), B * CFrame.new(14, -14, sz * 21.5), STEEL2, M.Metal)
		end
		for i = -2, 2 do
			box(bucket, V(9, 5, 6), B * CFrame.new(35, -31, i * 9), DARK, M.Metal)
		end
		local load = K.group(s5, "Load")
		ell(load, V(26, 20, 34), B * CFrame.new(14, -17, 0), DIRT, M.Slate)

		-- 6 FINAL HYDRAULICS / MASSES: boom ram, stick ram, bucket linkage, fuel tank, exhaust stack, a roof light bar and a second
		-- weight block; plus the dirt mound the finale digs
		local s6 = K.stage(m, 6)
		bar(K.group(s6, "Boom"), V(X(-2), 33, ZB + 2), V(X(22), 62, ZB + 2), 7, STEEL, M.Metal)
		bar(K.group(s6, "Stick"), V(X(22), 78, ZB + 4), V(X(52), 70, ZB + 4), 6, STEEL, M.Metal)
		bar(K.group(s6, "Bucket"), W + V(-4, -2, 6), W + V(14, -24, 6), 4, STEEL2, M.Metal)
		box(s6, V(22, 14, 18), CFrame.new(X(-24), 31, -30), ORANGE2, M.Metal) -- fuel tank
		cyl(s6, 7, 18, CFrame.new(X(-22), 62, 18), DARK, M.Metal) -- exhaust stack
		box(s6, V(22, 5, 10), CFrame.new(X(-33), 60, 0), STEEL2, M.Metal) -- second weight
		box(s6, V(30, 3, 5), CFrame.new(X(18), 67.5, -14), YEL, M.Neon) -- light bar
		local mound = K.group(s6, "Mound")
		ell(mound, V(36, 18, 44), CFrame.new(X(94), 6, ZB), DIRT2, M.Slate)
		ell(mound, V(22, 12, 26), CFrame.new(X(104), 4, ZB + 4), DIRT, M.Slate)
		return m
	end,
}
