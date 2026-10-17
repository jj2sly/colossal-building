--!nonstrict
-- GIANT TOILET (Rare). A colossal, friendly white porcelain toilet (80 wide x 112 deep x ~108 tall): a rounded plinth and neck, a
-- deep oval bowl built from 20 flared wall blocks with a rim, a visible water cavity, a tall rear tank, a cream seat ring and a
-- big oval lid standing open at 62 degrees (it lifts further for the flush). Front faces -Z, the tank is at the back (+Z).
-- Groups for the client show: Lid (marker LidHinge), Water (the disc), Swirl (3 arms, marker SwirlC), Handle (marker HandleP).
return {
	Id = "GiantToilet",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, ell = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.ell
		local PORC, PORC2, CREAM, WATER, FOAM, CHROME = RGB(232, 230, 222), RGB(194, 198, 204), RGB(240, 230, 196), RGB(80, 168, 232), RGB(206, 238, 255), RGB(190, 198, 210)
		local m = K.template("GiantToilet")
		local rot = CFrame.Angles
		local ZC = -6 -- bowl centre

		-- a ring of N blocks around the oval (a, b = half axes at the block centre), y centre, height, thickness, flare (rad)
		-- `front`: "cut" skips the blocks on the spawn side (open bowl), "low" keeps them but short (a low front lip)
		local function ring(parent: Instance, N: number, a: number, b: number, y: number, h: number, th: number, flare: number, color: Color3, mat: Enum.Material?, front: string?)
			for i = 0, N - 1 do
				local phi = (i + 0.5) / N * math.pi * 2
				local isFront = math.sin(phi) < -0.62
				if isFront and front == "cut" then
					continue
				end
				local hh, yy = h, y
				if isFront and front == "low" then
					hh, yy = 12, 18
				end
				local pos = V(a * math.cos(phi), yy, ZC + b * math.sin(phi))
				local n = V(math.cos(phi) / a, 0, math.sin(phi) / b).Unit
				local t = V(-a * math.sin(phi), 0, b * math.cos(phi)).Unit
				local up = (V(0, math.cos(flare), 0) + n * math.sin(flare)).Unit
				local chord = (V(a * math.cos(phi + math.pi / N), 0, b * math.sin(phi + math.pi / N)) - V(a * math.cos(phi - math.pi / N), 0, b * math.sin(phi - math.pi / N))).Magnitude
				box(parent, V(chord + 1.6, hh, th), CFrame.fromMatrix(pos, t, up), color, mat or M.SmoothPlastic)
			end
		end

		-- 1 PEDESTAL / BASE: a rounded plinth (80 x 16 x 112) and a thick neck (52 x 30 x 66)
		local s1 = K.stage(m, 1)
		ell(s1, V(80, 18, 112), CFrame.new(0, 7, 4), PORC2)
		ell(s1, V(56, 34, 70), CFrame.new(0, 20, -2), PORC)

		-- 2 BOWL: a flared outer ell, 20 tilted wall blocks (y 12 .. 40), a rim ring and the water with a swirl
		local s2 = K.stage(m, 2)
		ell(s2, V(70, 32, 86), CFrame.new(0, 15, ZC), PORC)
		ring(s2, 20, 31, 38, 27, 30, 5, math.rad(13), PORC, nil, "low")
		ring(s2, 20, 35.5, 43, 40, 5, 7, 0, PORC, nil, "cut")
		local w = K.group(s2, "Water")
		ell(w, V(52, 3, 64), CFrame.new(0, 31, ZC), RGB(40, 140, 236), M.SmoothPlastic)
		local sw = K.group(s2, "Swirl")
		for k = 0, 2 do
			local a = k * math.pi * 2 / 3
			box(sw, V(20, 1.4, 4.4), CFrame.new(0, 32.8, ZC) * rot(0, a, 0) * CFrame.new(10, 0, 0), FOAM, M.SmoothPlastic)
		end
		K.marker(sw, "SwirlC", V(0, 32.8, ZC))

		-- 3 TANK: the tall rear tank (56 x 44 x 22), a thick base block under it and a back panel
		local s3 = K.stage(m, 3)
		box(s3, V(56, 44, 22), CFrame.new(0, 36, 47), PORC, M.SmoothPlastic)
		box(s3, V(62, 8, 28), CFrame.new(0, 12, 46), PORC2, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			box(s3, V(4, 36, 18), CFrame.new(sx * 28.4, 36, 47), PORC2, M.SmoothPlastic)
		end

		-- 4 SEAT / LID: a cream seat ring on the rim and a big oval lid standing open at 62 degrees on a hinge at the bowl's back
		local s4 = K.stage(m, 4)
		ring(s4, 20, 37, 44.5, 44, 4, 10, 0, CREAM, nil, "cut")
		local lid = K.group(s4, "Lid")
		local HZ = ZC + 40
		local H = CFrame.new(0, 46.5, HZ) * rot(math.rad(62), 0, 0)
		ell(lid, V(70, 5, 80), H * CFrame.new(0, 2.5, -38), PORC)
		ell(lid, V(60, 1.4, 68), H * CFrame.new(0, -0.4, -38), CREAM)
		box(lid, V(24, 6, 6), H * CFrame.new(0, 0, -2), CREAM, M.SmoothPlastic)
		K.marker(lid, "LidHinge", V(0, 46.5, HZ))

		-- 5 FLUSH ASSEMBLY: the tank lid (62 x 5 x 28), a big chrome handle with a round knob and a fat supply pipe down the side
		local s5 = K.stage(m, 5)
		box(s5, V(62, 5, 28), CFrame.new(0, 60.5, 47), PORC2, M.SmoothPlastic)
		local hd = K.group(s5, "Handle")
		box(hd, V(20, 4, 4), CFrame.new(-30, 52, 36), CHROME, M.Metal)
		ell(hd, V(8, 8, 8), CFrame.new(-40, 52, 36), CHROME, M.Metal)
		K.marker(hd, "HandleP", V(-24, 52, 36))
		cyl(s5, 8, 40, CFrame.new(-36, 22, 56), CHROME, M.Metal)
		bar(s5, V(-36, 8, 56), V(-26, 8, 30), 8, CHROME, M.Metal)
		return m
	end,
}
