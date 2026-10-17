--!nonstrict
-- WATER TOWER (Common). A huge round wooden tank (52 wide) on a much narrower braced frame (about 34 wide) with a wide open
-- space underneath, a domed cap and one big light-blue outlet pipe down the front of the frame that ends in a spout facing the spawn. ~72 tall.
-- Groups for the client show: Pipe (vibrates), Valve (hand wheel); markers Spout (water exits toward -Z) and VentTop.
return {
	Id = "WaterTower",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, cylZ, ell = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.cylZ, K.ell
		local CONC, TIMBER, IRON = RGB(138, 134, 128), RGB(104, 70, 46), RGB(70, 74, 82)
		local TANK, DOME, RED = RGB(160, 112, 66), RGB(150, 72, 54), RGB(200, 52, 44)
		local m = K.template("WaterTower")
		local function legX(y: number): number -- the legs lean in from 19 at the footings to 14 under the tank
			return 19 - 5 * (y - 6) / 34
		end

		-- 1 FOOTINGS: a broad concrete pad with four heavy corner footings
		local s1 = K.stage(m, 1)
		box(s1, V(46, 2.4, 46), CFrame.new(0, 1.2, 0), CONC, M.Concrete)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(s1, V(13, 6, 13), CFrame.new(sx * 19, 3, sz * 19), CONC, M.Concrete)
			end
		end

		-- 2 SUPPORT FRAME: four thick leaning legs, two levels of ring beams and X cross-braces (to y 40)
		local s2 = K.stage(m, 2)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				bar(s2, V(sx * 19, 6, sz * 19), V(sx * 14, 40, sz * 14), 5.4, TIMBER, M.Wood)
			end
		end
		for _, y in { 14, 27 } do
			local x = legX(y)
			for _, s in { -1, 1 } do
				bar(s2, V(-x, y, s * x), V(x, y, s * x), 2.8, TIMBER, M.Wood)
				bar(s2, V(s * x, y, -x), V(s * x, y, x), 2.8, TIMBER, M.Wood)
			end
		end
		local x14, x27 = legX(14), legX(27)
		for _, s in { -1, 1 } do -- X braces on the four faces
			bar(s2, V(-x14, 14, s * x14), V(x27, 27, s * x27), 2, IRON, M.Metal)
			bar(s2, V(x14, 14, s * x14), V(-x27, 27, s * x27), 2, IRON, M.Metal)
			bar(s2, V(s * x14, 14, -x14), V(s * x27, 27, x27), 2, IRON, M.Metal)
			bar(s2, V(s * x14, 14, x14), V(s * x27, 27, -x27), 2, IRON, M.Metal)
		end
		box(s2, V(34, 2.4, 34), CFrame.new(0, 39.4, 0), TIMBER, M.Wood)

		-- 3 TANK: the huge round tank (52 wide, 22 tall) on its steel ring with three iron bands
		local s3 = K.stage(m, 3)
		cyl(s3, 54, 2, CFrame.new(0, 41, 0), IRON, M.Metal)
		cyl(s3, 52, 22, CFrame.new(0, 52, 0), TANK, M.WoodPlanks)
		for _, y in { 45, 52, 59 } do
			cyl(s3, 53.4, 1.6, CFrame.new(0, y, 0), IRON, M.Metal)
		end

		-- 4 CAP / PIPES: a domed cap with a vent, the outlet pipe and a red valve wheel
		local s4 = K.stage(m, 4)
		ell(s4, V(52, 22, 52), CFrame.new(0, 63, 0), DOME, M.Wood)
		cyl(s4, 6, 5, CFrame.new(0, 72.5, 0), IRON, M.Metal)
		K.marker(s4, "VentTop", V(0, 75.5, 0))
		-- one big, light outlet pipe down the FRONT of the frame (in front of the braces) and out to a spout facing the spawn
		local PIPE2 = RGB(118, 176, 214)
		local pipe = K.group(s4, "Pipe")
		cyl(pipe, 9, 32, CFrame.new(0, 26, -21), PIPE2, M.SmoothPlastic)
		cyl(pipe, 11, 2, CFrame.new(0, 40, -21), IRON, M.Metal) -- collar under the tank
		ell(pipe, V(11, 11, 11), CFrame.new(0, 9.5, -21), PIPE2, M.SmoothPlastic)
		cylZ(pipe, 9, 13, CFrame.new(0, 9.5, -27.5), PIPE2, M.SmoothPlastic)
		cylZ(pipe, 12, 2.4, CFrame.new(0, 9.5, -34.6), IRON, M.Metal)
		K.marker(pipe, "Spout", V(0, 9.5, -36), V(0, -0.25, -1))
		local valve = K.group(s4, "Valve")
		box(valve, V(2, 5, 2), CFrame.new(0, 16, -27), IRON, M.Metal)
		cyl(valve, 10, 1.6, CFrame.new(0, 18.8, -27), RED, M.SmoothPlastic)
		K.marker(valve, "ValveCenter", V(0, 18.8, -27))
		return m
	end,
}
