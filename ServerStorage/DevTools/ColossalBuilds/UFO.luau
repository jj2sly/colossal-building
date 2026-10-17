--!nonstrict
-- UFO (Epic). A huge landed saucer (disc 152 across, outer halo ring 169 across, ~102 tall) standing high on four splayed
-- landing legs: a deep lower hull bowl, a lens-shaped main disc with a dark rim band, an upper hull, one glass dome with an
-- energy core inside, a single underside emitter and a detached outer halo ring. Width : dome height (above the rim) is about 4.5.
-- Groups for the client show: Leg1..Leg4 (marker LegHinge in each: where the leg meets the hull), RimLight (8 big rim panels),
-- Core (dome core + beacon), Beam (underside emitter lens, marker BeamC), Halo (16 outer ring segments), Ground (the landing
-- pad: never moves). Everything else is the craft (rises in the completion hover).
return {
	Id = "UFO",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, ell = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.ell
		local HULL, HULL2, UNDER, DARK = RGB(178, 184, 194), RGB(150, 158, 170), RGB(98, 104, 116), RGB(58, 62, 72)
		local PANEL, GLASS, PAD, STRIPE = RGB(44, 78, 90), RGB(150, 204, 222), RGB(70, 72, 78), RGB(214, 170, 52)
		local m = K.template("UFO")
		local function dir(deg: number): Vector3
			local a = math.rad(deg)
			return V(math.cos(a), 0, math.sin(a))
		end
		local LEGS = { 45, 135, 225, 315 }

		-- 1 LANDING BASE: a marked landing pad on the deck and the four lower legs (foot pad, strut, knee)
		local s1 = K.stage(m, 1)
		local ground = K.group(s1, "Ground")
		cyl(ground, 124, 1, CFrame.new(0, 0.5, 0), PAD, M.Concrete)
		cyl(ground, 110, 1.2, CFrame.new(0, 0.6, 0), STRIPE, M.SmoothPlastic)
		cyl(ground, 102, 1.4, CFrame.new(0, 0.7, 0), PAD, M.Concrete)
		for i, deg in LEGS do
			local d = dir(deg)
			local leg = K.group(s1, "Leg" .. i)
			cyl(leg, 18, 3, CFrame.new(d * 64 + V(0, 2.5, 0)), DARK, M.DiamondPlate)
			bar(leg, d * 64 + V(0, 4, 0), d * 57 + V(0, 22, 0), 6, UNDER, M.Metal)
			ell(leg, V(10, 10, 10), CFrame.new(d * 57 + V(0, 22, 0)), DARK, M.Metal)
		end

		-- 2 LOWER HULL: the deep underside bowl (120 across, bottom at y 31) with a flat plate, and the upper legs into it
		local s2 = K.stage(m, 2)
		ell(s2, V(120, 32, 120), CFrame.new(0, 47, 0), UNDER, M.DiamondPlate)
		cyl(s2, 64, 3, CFrame.new(0, 32.5, 0), DARK, M.DiamondPlate)
		for i, deg in LEGS do
			local d = dir(deg)
			local leg = K.group(s2, "Leg" .. i)
			bar(leg, d * 57 + V(0, 22, 0), d * 40 + V(0, 40, 0), 7, HULL2, M.Metal)
			bar(leg, d * 61 + V(0, 8, 0), d * 45 + V(0, 36, 0), 3, DARK, M.Metal) -- hydraulic
			K.marker(leg, "LegHinge", d * 40 + V(0, 40, 0))
		end

		-- 3 MAIN DISC: one lens-shaped disc 152 across with a dark rim band and eight big rim panels
		local s3 = K.stage(m, 3)
		ell(s3, V(152, 14, 152), CFrame.new(0, 52, 0), HULL, M.Metal)
		cyl(s3, 148, 4, CFrame.new(0, 52, 0), DARK, M.Metal)
		for k = 0, 7 do
			local deg = k * 45 + 22.5
			local d = dir(deg)
			local rim = K.group(s3, "RimLight")
			box(rim, V(18, 2.6, 1.2), CFrame.fromMatrix(d * 74.4 + V(0, 52, 0), V(-d.Z, 0, d.X), Vector3.yAxis), PANEL, M.SmoothPlastic)
		end

		-- 4 UPPER HULL: a broad raised upper hull and the collar the dome sits in
		local s4 = K.stage(m, 4)
		ell(s4, V(112, 24, 112), CFrame.new(0, 58, 0), HULL2, M.Metal)
		cyl(s4, 66, 4, CFrame.new(0, 68, 0), HULL, M.Metal)

		-- 5 DOME / CORE: one glass dome (56 across, top at y 93) over a tall energy core, and a short beacon
		local s5 = K.stage(m, 5)
		cyl(s5, 62, 3, CFrame.new(0, 71, 0), DARK, M.Metal)
		local core = K.group(s5, "Core")
		cyl(core, 18, 16, CFrame.new(0, 80, 0), PANEL, M.SmoothPlastic)
		ell(core, V(12, 8, 12), CFrame.new(0, 89, 0), PANEL, M.SmoothPlastic)
		local dome = ell(s5, V(56, 44, 56), CFrame.new(0, 71, 0), GLASS, M.Glass)
		dome.Transparency = 0.45
		cyl(s5, 2.4, 9, CFrame.new(0, 96.5, 0), DARK, M.Metal)
		ell(core, V(4.5, 4.5, 4.5), CFrame.new(0, 101.5, 0), PANEL, M.SmoothPlastic)

		-- 6 UNDERSIDE MECHANISM: one central emitter (housing + lens) and four big underside pods between the legs
		local s6 = K.stage(m, 6)
		cyl(s6, 34, 6, CFrame.new(0, 28.5, 0), DARK, M.DiamondPlate)
		local beam = K.group(s6, "Beam")
		ell(beam, V(24, 8, 24), CFrame.new(0, 25.5, 0), PANEL, M.SmoothPlastic)
		K.marker(beam, "BeamC", V(0, 24, 0))
		for _, deg in { 0, 90, 180, 270 } do
			ell(s6, V(26, 11, 26), CFrame.new(dir(deg) * 34 + V(0, 34, 0)), HULL2, M.Metal)
		end

		-- 7 OUTER RING: a detached halo ring (r 82) around the disc on four pylons, leaving a clear gap all round
		local s7 = K.stage(m, 7)
		for _, deg in { 0, 90, 180, 270 } do
			local d = dir(deg)
			box(s7, V(14, 4, 12), CFrame.lookAt(d * 77 + V(0, 52, 0), d * 78 + V(0, 52, 0)), DARK, M.Metal)
		end
		for k = 0, 15 do
			local d = dir(k * 22.5 + 11.25)
			local halo = K.group(s7, "Halo")
			box(halo, V(33, 5, 5), CFrame.fromMatrix(d * 82 + V(0, 52, 0), V(-d.Z, 0, d.X), Vector3.yAxis), if k % 2 == 0 then HULL else HULL2, M.Metal)
		end
		return m
	end,
}
