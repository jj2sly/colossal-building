--!nonstrict
-- OLD ROBLOX HQ (Uncommon). A chunky, stepped, flat-fronted brick-block headquarters: a broad lower block, a narrower upper tier,
-- a big central entrance tower projecting forward, dark blue roof slabs and a tall flag mast. ~104 wide x 80 deep x 100 tall.
-- Front faces -Z. No glass curtain walls, just eight big blocky windows (the Window group) the show lights up.
-- Groups for the client show: Window (glass panes), Flag (marker FlagPole; the flag unfurls from the pole's +x side).
return {
	Id = "OldRobloxHQ",
	Build = function(K)
		local V, M, RGB, box, cyl = K.V, K.M, K.RGB, K.box, K.cyl
		local STONE, STONE2 = RGB(124, 120, 114), RGB(158, 154, 146)
		local WALL, WALL2, WALL3, TRIM = RGB(214, 196, 150), RGB(196, 176, 130), RGB(204, 184, 138), RGB(90, 96, 112)
		local ROOF, ROOF2, DARK, GLASS = RGB(54, 84, 140), RGB(40, 64, 112), RGB(40, 34, 32), RGB(116, 150, 176)
		local FLAG, WHITE, MAST = RGB(204, 52, 44), RGB(244, 240, 228), RGB(190, 192, 198)
		local m = K.template("OldRobloxHQ")
		local function window(parent: Instance, x: number, y: number, z: number, w: number, h: number)
			local g = K.group(parent, "Window")
			box(g, V(w, h, 1), CFrame.new(x, y, z), GLASS, M.Glass, { Window = true }).Transparency = 0.15
			box(parent, V(w + 3, h + 3, 0.8), CFrame.new(x, y, z + 0.5), TRIM, M.SmoothPlastic)
		end

		-- 1 FOUNDATION: a wide two-step stone plinth (104 x 6 x 66 and 96 x 3 x 58) with a broad entrance stair
		local s1 = K.stage(m, 1)
		box(s1, V(104, 6, 66), CFrame.new(0, 3, 0), STONE, M.Slate)
		box(s1, V(96, 3, 58), CFrame.new(0, 7.5, 0), STONE2, M.Slate)
		box(s1, V(34, 2, 6), CFrame.new(0, 1, -36), STONE, M.Slate)
		box(s1, V(26, 4, 6), CFrame.new(0, 2, -32), STONE2, M.Slate)

		-- 2 LOWER HQ: the broad lower block (92 x 24 x 54, to y 33), four corner piers and four big windows
		local s2 = K.stage(m, 2)
		box(s2, V(92, 24, 54), CFrame.new(0, 21, 0), WALL, M.Brick)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(s2, V(9, 26, 9), CFrame.new(sx * 46, 21, sz * 27), WALL3, M.Brick)
			end
		end
		box(s2, V(96, 2.6, 58), CFrame.new(0, 33.3, 0), TRIM, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			window(s2, sx * 28, 24, -27.6, 12, 10)
			window(s2, sx * 42, 24, -27.6, 8, 10)
		end

		-- 3 UPPER HQ: the narrower upper tier (68 x 20 x 40, to y 54), stepped in from the lower block, with two more windows
		local s3 = K.stage(m, 3)
		box(s3, V(68, 20, 40), CFrame.new(0, 44, -2), WALL2, M.Brick)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(s3, V(8, 22, 8), CFrame.new(sx * 34, 44, -2 + sz * 18), WALL3, M.Brick)
			end
			window(s3, sx * 26, 46, -22.6, 12, 10)
		end
		box(s3, V(72, 2.6, 44), CFrame.new(0, 55.3, -2), TRIM, M.SmoothPlastic)

		-- 4 ENTRANCE TOWER: a big central tower (32 wide, 30 deep) projecting from the front, up to y 68, with a dark double door
		local s4 = K.stage(m, 4)
		box(s4, V(32, 62, 30), CFrame.new(0, 36, -29), WALL3, M.Brick)
		for _, sx in { -1, 1 } do
			box(s4, V(7, 64, 7), CFrame.new(sx * 16, 37, -42), WALL, M.Brick)
		end
		box(s4, V(14, 18, 1), CFrame.new(0, 17, -44.4), DARK, M.SmoothPlastic)
		box(s4, V(22, 3, 4), CFrame.new(0, 28, -45), TRIM, M.SmoothPlastic)
		window(s4, 0, 44, -44.6, 14, 12)
		window(s4, 0, 59, -44.6, 10, 8)
		box(s4, V(36, 2.6, 34), CFrame.new(0, 68.3, -29), TRIM, M.SmoothPlastic)

		-- 5 ROOF / FLAG: dark blue roof slabs on both tiers, a stepped pyramid roof on the tower and a tall flag mast
		local s5 = K.stage(m, 5)
		box(s5, V(100, 3, 62), CFrame.new(0, 36.5, 0), ROOF2, M.Slate)
		box(s5, V(76, 3, 48), CFrame.new(0, 58, -2), ROOF, M.Slate)
		box(s5, V(40, 4, 40), CFrame.new(0, 71, -29), ROOF, M.Slate)
		box(s5, V(28, 4, 28), CFrame.new(0, 75, -29), ROOF2, M.Slate)
		box(s5, V(16, 4, 16), CFrame.new(0, 79, -29), ROOF, M.Slate)
		cyl(s5, 3, 28, CFrame.new(0, 93, -29), MAST, M.Metal)
		K.marker(s5, "FlagPole", V(0, 92, -29))
		local flag = K.group(s5, "Flag")
		box(flag, V(34, 20, 0.8), CFrame.new(18.5, 96, -29), FLAG, M.Fabric)
		box(flag, V(34, 5.4, 0.9), CFrame.new(18.5, 96, -29), WHITE, M.Fabric)
		return m
	end,
}
