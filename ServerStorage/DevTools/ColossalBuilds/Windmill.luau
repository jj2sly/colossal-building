--!nonstrict
-- WINDMILL (Uncommon). A tapered timber-and-stone mill tower (38 wide at the base, 24 at the top), a roof housing with a nose for
-- the axle, a giant four-blade rotor (X shaped, 72 across, nearly the tower's height) standing out in front, then a ring
-- balcony on four diagonal struts. ~76 wide x 96 tall x 76 deep. Rotor faces -Z (the spawn).
-- Group for the client show: Rotor (blades + hub, turns about the local Z axis through marker Hub).
return {
	Id = "Windmill",
	Build = function(K)
		local V, M, RGB, box, bar, cylZ = K.V, K.M, K.RGB, K.box, K.bar, K.cylZ
		local STONE, STONE2 = RGB(128, 124, 118), RGB(158, 154, 146)
		local WALL, WALL2, WOOD, WOOD2 = RGB(214, 196, 150), RGB(196, 176, 130), RGB(150, 98, 54), RGB(112, 70, 40)
		local ROOF, SAIL, DARK, IRON = RGB(150, 62, 48), RGB(238, 230, 206), RGB(40, 34, 32), RGB(70, 74, 82)
		local m = K.template("Windmill")
		local BASE, TOP, YB, YT = 19, 12, 6, 50 -- tower half widths (bottom, top) and heights
		local HUB = V(0, 58, -38)

		-- a tilted wall plate for one side of the tapered tower
		local function wall(parent: Instance, axis: string, sign: number, color: Color3)
			local dy = YT - YB
			local d = TOP - BASE -- horizontal change from bottom to top (negative = leaning in)
			local len = math.sqrt(dy * dy + d * d)
			local mid = (BASE + TOP) / 2
			local up, wvec, c
			if axis == "z" then
				up = V(0, dy, sign * d).Unit
				wvec = V(1, 0, 0)
				c = V(0, (YB + YT) / 2, sign * mid)
			else
				up = V(sign * d, dy, 0).Unit
				wvec = V(0, 0, 1)
				c = V(sign * mid, (YB + YT) / 2, 0)
			end
			box(parent, V(2 * mid + 3, len, 3), CFrame.fromMatrix(c, wvec, up), color, M.WoodPlanks)
		end

		-- 1 BASE: a broad stone plinth (50 x 6 x 50), a stone skirt and four chunky corner blocks
		local s1 = K.stage(m, 1)
		box(s1, V(50, 6, 50), CFrame.new(0, 3, 0), STONE, M.Slate)
		box(s1, V(42, 4, 42), CFrame.new(0, 8, 0), STONE2, M.Slate)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(s1, V(9, 9, 9), CFrame.new(sx * 22, 7.5, sz * 22), STONE, M.Slate)
			end
		end
		box(s1, V(14, 3, 8), CFrame.new(0, 1.5, -28), STONE2, M.Slate)

		-- 2 TOWER: the tapered mill tower (four leaning wall plates) with a dark door and a timber ring band at the top
		local s2 = K.stage(m, 2)
		wall(s2, "z", -1, WALL)
		wall(s2, "z", 1, WALL2)
		wall(s2, "x", -1, WALL2)
		wall(s2, "x", 1, WALL)
		box(s2, V(10, 15, 2), CFrame.new(0, 15, -17.8), DARK, M.SmoothPlastic)
		box(s2, V(14, 3, 3), CFrame.new(0, 24, -17.2), WOOD2, M.Wood)
		box(s2, V(31, 3, 31), CFrame.new(0, 49, 0), WOOD2, M.Wood)

		-- 3 ROOF HOUSING: the machinery housing (30 x 16 x 30) with a stepped red roof and a front nose where the axle comes out
		local s3 = K.stage(m, 3)
		box(s3, V(30, 16, 30), CFrame.new(0, 58, 0), WOOD, M.WoodPlanks)
		box(s3, V(36, 3, 36), CFrame.new(0, 67.5, 0), ROOF, M.Slate)
		box(s3, V(26, 4, 26), CFrame.new(0, 71, 0), ROOF, M.Slate)
		box(s3, V(14, 4, 14), CFrame.new(0, 75, 0), ROOF, M.Slate)
		box(s3, V(16, 14, 10), CFrame.new(0, 58, -20), WOOD2, M.Wood)

		-- 4 GIANT BLADES: an axle, a heavy hub and four big blades in an X (each a thick spar with a broad cloth sail on one side)
		local s4 = K.stage(m, 4)
		K.marker(s4, "Hub", HUB)
		cylZ(s4, 6, 16, CFrame.new(0, 58, -29), IRON, M.Metal)
		local rotor = K.group(s4, "Rotor")
		cylZ(rotor, 13, 9, CFrame.new(HUB), IRON, M.Metal)
		for k = 0, 3 do
			local B = CFrame.new(HUB) * CFrame.Angles(0, 0, math.rad(45 + 90 * k))
			box(rotor, V(5, 34, 4), B * CFrame.new(0, 22, 0), WOOD2, M.Wood)
			box(rotor, V(13, 27, 1.4), B * CFrame.new(8.5, 24.5, 0.6), SAIL, M.Fabric)
		end

		-- 5 FINAL SUPPORT / BALCONY: four diagonal timber struts and a ring balcony around the tower with a chunky rail
		local s5 = K.stage(m, 5)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				bar(s5, V(sx * 26, 6, sz * 26), V(sx * 21, 33, sz * 21), 5, WOOD2, M.Wood)
				box(s5, V(3.4, 9, 3.4), CFrame.new(sx * 22.4, 39, sz * 22.4), WOOD2, M.Wood)
			end
		end
		for _, sz in { -1, 1 } do
			box(s5, V(50, 3, 10), CFrame.new(0, 34.5, sz * 20), WOOD, M.WoodPlanks)
			box(s5, V(10, 3, 30), CFrame.new(sz * 20, 34.5, 0), WOOD, M.WoodPlanks)
			box(s5, V(50, 2.4, 2), CFrame.new(0, 42, sz * 24), WOOD2, M.Wood)
			box(s5, V(2, 2.4, 44), CFrame.new(sz * 24, 42, 0), WOOD2, M.Wood)
		end
		return m
	end,
}
