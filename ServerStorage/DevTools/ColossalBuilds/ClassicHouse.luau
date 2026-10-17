--!nonstrict
-- CLASSIC ROBLOX HOUSE (Common). A chunky nostalgic two-tone house with a big red gable roof and a brick chimney.
-- ~72 wide x 56 deep x 67 tall. Front (door, porch) faces -Z (the spawn).
-- Groups for the client show: Door (hinged on its -X edge), Window (glass panes), Smoke marker "ChimneyTop".
return {
	Id = "ClassicHouse",
	Build = function(K)
		local V, M, RGB, box, wedge = K.V, K.M, K.RGB, K.box, K.wedge
		local STONE, FLOOR = RGB(128, 124, 118), RGB(150, 112, 74)
		local WALL, WALL2, TRIM = RGB(222, 204, 168), RGB(204, 186, 152), RGB(214, 208, 196)
		local ROOF, ROOF2, BRICK = RGB(170, 56, 44), RGB(146, 46, 38), RGB(150, 74, 56)
		local GLASS = RGB(122, 156, 178)
		local m = K.template("ClassicHouse")

		-- 1 FOUNDATION: a heavy stone plinth, the wooden floor and wide front steps
		local s1 = K.stage(m, 1)
		box(s1, V(68, 5, 56), CFrame.new(0, 2.5, 0), STONE, M.Slate)
		box(s1, V(64, 0.8, 52), CFrame.new(0, 5.4, 0), FLOOR, M.WoodPlanks)
		for k = 1, 3 do -- three wide steps up to the floor
			box(s1, V(18, 1.8 * k, 3), CFrame.new(0, 0.9 * k, -29.5 - (3 - k) * 3), STONE, M.Slate)
		end

		-- 2 WALLS: 58 x 44 x 26 shell with a door and four big windows (panes are the Window group)
		local s2 = K.stage(m, 2)
		local FY, H, T = 5.8, 26, 2.4 -- floor top, wall height, thickness
		local top = FY + H
		local function wallX(z: number, segs) -- a wall along X at depth z: segs = { {x0, x1, y0, y1} }
			for _, sg in segs do
				box(s2, V(sg[2] - sg[1], sg[4] - sg[3], T), CFrame.new((sg[1] + sg[2]) / 2, (sg[3] + sg[4]) / 2, z), WALL)
			end
		end
		local function wallZ(x: number, segs)
			for _, sg in segs do
				box(s2, V(T, sg[4] - sg[3], sg[2] - sg[1]), CFrame.new(x, (sg[3] + sg[4]) / 2, (sg[1] + sg[2]) / 2), WALL2)
			end
		end
		local WY0, WY1 = FY + 8, FY + 19 -- window band
		-- front: windows at x -17 / +17 (10 wide), door at x 0 (10 wide, 16 tall)
		wallX(-22, {
			{ -29, -22, FY, top }, { -22, -12, FY, WY0 }, { -22, -12, WY1, top }, { -12, -5, FY, top },
			{ -5, 5, FY + 16, top }, { 5, 12, FY, top }, { 12, 22, FY, WY0 }, { 12, 22, WY1, top }, { 22, 29, FY, top },
		})
		wallX(22, { { -29, -8, FY, top }, { -8, 8, FY, WY0 }, { -8, 8, WY1, top }, { 8, 29, FY, top } })
		wallZ(-29, { { -20.8, -6, FY, top }, { -6, 6, FY, WY0 }, { -6, 6, WY1, top }, { 6, 20.8, FY, top } })
		wallZ(29, { { -20.8, -6, FY, top }, { -6, 6, FY, WY0 }, { -6, 6, WY1, top }, { 6, 20.8, FY, top } })
		local win = K.group(s2, "Window")
		for _, w in { { V(-17, (WY0 + WY1) / 2, -22), V(10, 11, 0.6) }, { V(17, (WY0 + WY1) / 2, -22), V(10, 11, 0.6) }, { V(0, (WY0 + WY1) / 2, 22), V(16, 11, 0.6) }, { V(-29, (WY0 + WY1) / 2, 0), V(0.6, 11, 12) }, { V(29, (WY0 + WY1) / 2, 0), V(0.6, 11, 12) } } do
			box(win, w[2], CFrame.new(w[1]), GLASS, M.Glass, { Window = true }).Transparency = 0.15
		end
		-- corner posts and a floor band (the trim that frames the mass)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(s2, V(3.4, H + 0.4, 3.4), CFrame.new(sx * 29, FY + H / 2, sz * 22), TRIM)
			end
		end
		box(s2, V(61, 1.4, 47), CFrame.new(0, top + 0.5, 0), TRIM)

		-- 3 ROOF + CHIMNEY: a 66-long red gable (ridge along X, 20 studs rise), gable ends and a tall brick chimney
		local s3 = K.stage(m, 3)
		local half, rise = 28, 20
		local ang = math.atan(rise / half)
		local slab = math.sqrt(half * half + rise * rise) + 1.5
		local ry = top + 1.2
		for _, sz in { -1, 1 } do
			box(s3, V(68, 2.4, slab), CFrame.new(0, ry + rise / 2, sz * half / 2) * CFrame.Angles(sz * ang, 0, 0), if sz < 0 then ROOF else ROOF2)
		end
		box(s3, V(70, 2.4, 3.4), CFrame.new(0, ry + rise + 0.6, 0), ROOF2)
		for _, sx in { -1, 1 } do
			-- gable triangle (two wedges, tall at the ridge)
			wedge(s3, V(T, rise, 22), CFrame.new(sx * 29, ry + rise / 2, -11), WALL)
			wedge(s3, V(T, rise, 22), CFrame.new(sx * 29, ry + rise / 2, 11) * CFrame.Angles(0, math.pi, 0), WALL)
		end
		box(s3, V(7.5, 40, 7.5), CFrame.new(18, top - 2 + 20, 9), BRICK, M.Brick)
		box(s3, V(9.5, 1.8, 9.5), CFrame.new(18, top + 38.9, 9), RGB(96, 60, 48), M.Brick)
		K.marker(s3, "ChimneyTop", V(18, top + 40.5, 9))

		-- 4 PORCH + FINAL FORM: a deep covered porch, the front door, a side wing and a front dormer (width + depth + mass)
		local s4 = K.stage(m, 4)
		box(s4, V(42, 1.2, 12), CFrame.new(0, FY - 0.4, -28), FLOOR, M.WoodPlanks)
		box(s4, V(42, 5, 12), CFrame.new(0, 2.5, -28), STONE, M.Slate)
		for k = 1, 3 do -- the porch steps
			box(s4, V(16, 1.8 * k, 3), CFrame.new(0, 0.9 * k, -35.5 - (3 - k) * 3), STONE, M.Slate)
		end
		for _, x in { -19, -7, 7, 19 } do
			box(s4, V(1.8, 14, 1.8), CFrame.new(x, FY + 7, -33), TRIM)
		end
		box(s4, V(46, 1.6, 15), CFrame.new(0, FY + 15.2, -29.5) * CFrame.Angles(math.rad(14), 0, 0), ROOF)
		local win4 = K.group(s4, "Window") -- the new windows belong to this stage
		local door = K.group(s4, "Door")
		box(door, V(9.6, 15.6, 1), CFrame.new(0, FY + 7.8, -22.2), RGB(120, 70, 44), M.WoodPlanks)
		box(door, V(1.2, 1.2, 1.4), CFrame.new(3.2, FY + 7.8, -22.9), RGB(214, 170, 70), M.Metal)
		K.marker(door, "DoorHinge", V(-4.8, FY + 7.8, -22.2))
		-- side wing on +X: 15 wide, 30 deep, 18 tall with its own lean-to roof
		box(s4, V(15, 18, 30), CFrame.new(36.5, FY + 9, 4), WALL2)
		box(s4, V(17, 1.6, 33), CFrame.new(37, FY + 19.4, 4) * CFrame.Angles(0, 0, math.rad(-12)), ROOF2)
		box(s4, V(15, 5, 30), CFrame.new(36.5, 2.5, 4), STONE, M.Slate)
		box(win4, V(0.6, 8, 10), CFrame.new(44.1, FY + 10, 4), GLASS, M.Glass, { Window = true }).Transparency = 0.15
		-- front dormer on the roof: a small gabled box with a window
		box(s4, V(14, 10, 12), CFrame.new(-14, ry + 8, -11), WALL)
		for _, sx in { -1, 1 } do
			box(s4, V(9.5, 1.4, 14), CFrame.new(-14 + sx * 3.6, ry + 15, -11) * CFrame.Angles(0, 0, sx * math.rad(-38)), ROOF)
		end
		box(win4, V(7, 6, 0.6), CFrame.new(-14, ry + 8, -17.2), GLASS, M.Glass, { Window = true }).Transparency = 0.15
		return m
	end,
}
