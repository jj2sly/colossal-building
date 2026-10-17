--!nonstrict
-- BRICK WATCHTOWER (Common). A thick brick shaft (24 wide) rising from a flared stone base to a much wider OPEN observation
-- level (50 wide deck, clearly overhanging, chunky corner posts, sky visible through it) under a stepped roof, with a flag pole on top. ~73 tall. Front faces -Z (the spawn).
-- Group for the client show: Flag (starts at half-mast, rises to the top at completion).
return {
	Id = "BrickWatchtower",
	Build = function(K)
		local V, M, RGB, box, cyl = K.V, K.M, K.RGB, K.box, K.cyl
		local STONE, STONE2 = RGB(124, 120, 114), RGB(158, 154, 146)
		local BRICK, BRICK2, DARK = RGB(166, 86, 62), RGB(146, 72, 52), RGB(40, 30, 28)
		local ROOF, WOOD, FLAG = RGB(112, 62, 48), RGB(120, 84, 52), RGB(206, 52, 44)
		local m = K.template("BrickWatchtower")

		-- 1 BASE: a broad flared stone plinth (44 wide, 8 tall) with a front step
		local s1 = K.stage(m, 1)
		box(s1, V(44, 3, 44), CFrame.new(0, 1.5, 0), STONE, M.Slate)
		box(s1, V(36, 5, 36), CFrame.new(0, 5.5, 0), STONE2, M.Slate)
		box(s1, V(14, 2, 4), CFrame.new(0, 1, -24), STONE, M.Slate)

		-- 2 SHAFT: the thick brick shaft (24 x 22 x 24) with a dark door, two slits and a stone course on top (to y 32)
		local s2 = K.stage(m, 2)
		box(s2, V(24, 22, 24), CFrame.new(0, 19, 0), BRICK, M.Brick)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(s2, V(4, 22, 4), CFrame.new(sx * 11, 19, sz * 11), BRICK2, M.Brick)
			end
		end
		box(s2, V(8, 12, 1), CFrame.new(0, 14, -12.2), DARK, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			box(s2, V(2.6, 7, 1), CFrame.new(sx * 5, 25, -12.2), DARK, M.SmoothPlastic)
		end
		box(s2, V(28, 2, 28), CFrame.new(0, 31, 0), STONE2, M.Slate)

		-- 3 OBSERVATION DECK: a 50 x 50 deck overhanging the shaft and four chunky corner posts holding the roof up.
		-- The level between deck and roof (y 35 .. 50) is OPEN: only a low thin rail, so the sky shows through.
		local s3 = K.stage(m, 3)
		box(s3, V(50, 3, 50), CFrame.new(0, 33.5, 0), WOOD, M.WoodPlanks)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(s3, V(6, 15, 6), CFrame.new(sx * 22, 42.5, sz * 22), STONE2, M.Slate)
			end
			box(s3, V(1.4, 1.4, 38), CFrame.new(sx * 22.4, 38, 0), WOOD, M.Wood)
			box(s3, V(38, 1.4, 1.4), CFrame.new(0, 38, sx * 22.4), WOOD, M.Wood)
		end

		-- 4 ROOF / FLAG: a light underside slab (so the open level reads), two stepped roof slabs, a tall pole and a big flag
		local s4 = K.stage(m, 4)
		box(s4, V(56, 2, 56), CFrame.new(0, 51, 0), STONE2, M.Slate)
		box(s4, V(54, 3, 54), CFrame.new(0, 53.5, 0), ROOF, M.Brick)
		box(s4, V(36, 3, 36), CFrame.new(0, 56.5, 0), ROOF, M.Brick)
		cyl(s4, 2.6, 22, CFrame.new(0, 69, 0), STONE2, M.Metal)
		K.marker(s4, "FlagPole", V(0, 58, 0))
		local flag = K.group(s4, "Flag")
		box(flag, V(24, 12, 0.8), CFrame.new(13.3, 69, 0), FLAG, M.Fabric)
		box(flag, V(24, 3.6, 0.9), CFrame.new(13.3, 69, 0), RGB(244, 240, 228), M.Fabric)
		return m
	end,
}
