--!nonstrict
-- SKY CITY (Mythic). A floating city made of SEPARATE masses with open sky between them, not one platform with buildings on it.
--   * Central city: a 80-across floating platform at y 80 with a deep stepped underside, a lower district ring of big blocks, a
--     raised upper district, a hero spire (to y ~200) with a halo crown, and a giant lift ring under it. A slim glass lift beam
--     drops from its underside to an anchor pad on the deck; everything else is in the air.
--   * Three satellite districts at different heights and distances, each its own floating platform with an underside, blocks,
--     a tall tower and its own lift ring. Positions are chosen in WORLD terms for the spawn view and converted to template space
--     (template = -world because the site turns builds 180 degrees): A low on the left, B higher on the right, C highest, behind.
--   * Two huge bridges join A and B to the centre; C floats free.
-- Authored ~270 x 222 x 220; BuildConfig TemplateScale 1.15 -> ~310 x 255 x 250. (Pass 12B: central platform +12%, heavier spire.) The satellites overhang the 90-stud deck by up to
-- ~70 studs, all of it above y ~35 (nothing at ground level outside the deck).
-- Groups for the client show: Ground (anchor pad + lift beam: never moves), SatA / SatB / SatC (everything belonging to a satellite,
-- including its bridge and ring; marker SatXC at its centre), RingC / RingA / RingB / RingD (lift rings, marker RingXC; RingD = C's
-- ring), Core (underside glow cores), Glow (tower window bands), Tower (spire + crown, marker TowerTop). Everything else = central.
return {
	Id = "SkyCity",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, ell = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.ell
		local STONE, STONE2, STONE3 = RGB(232, 226, 214), RGB(206, 198, 184), RGB(184, 176, 162)
		local ROOF, ROOF2, GOLD = RGB(70, 92, 124), RGB(56, 74, 104), RGB(214, 176, 90)
		local UNDER, DARKU, LIFT, GLASS = RGB(104, 108, 120), RGB(68, 72, 84), RGB(40, 70, 90), RGB(170, 214, 232)
		local m = K.template("SkyCity")
		local UPV = Vector3.yAxis
		local function W(x: number, z: number): Vector3 -- a world-plan offset converted to template space
			return V(-x, 0, -z)
		end
		local C0 = V(0, 80, 0)
		local SAT = {
			A = { c = W(-102, 26) + V(0, 62, 0), r = 31 }, -- world: left, slightly toward the spawn, low
			B = { c = W(100, -30) + V(0, 104, 0), r = 29 }, -- world: right, slightly behind, higher
			C = { c = W(-62, -92) + V(0, 146, 0), r = 27 }, -- world: behind and left of the spire, highest
		}

		-- a floating platform: deck slab (top at c.Y), gold rim band, a stepped inverted-cone underside and a glow core at the tip
		local function platform(g: Instance, c: Vector3, r: number, coreGroup: Instance)
			local s = r / 40
			cyl(g, 2 * r, 6, CFrame.new(c - V(0, 3, 0)), STONE2, M.Slate)
			cyl(g, 2 * r + 1.6, 2, CFrame.new(c - V(0, 4.5, 0)), GOLD, M.Metal)
			cyl(g, 2 * r * 0.82, 8 * s + 2, CFrame.new(c - V(0, 6 + (8 * s + 2) / 2, 0)), UNDER, M.Metal)
			cyl(g, 2 * r * 0.56, 9 * s + 2, CFrame.new(c - V(0, 6 + (8 * s + 2) + (9 * s + 2) / 2, 0)), UNDER, M.Metal)
			cyl(g, 2 * r * 0.32, 10 * s + 2, CFrame.new(c - V(0, 6 + (8 * s + 2) + (9 * s + 2) + (10 * s + 2) / 2, 0)), DARKU, M.Metal)
			local tip = c - V(0, 6 + (8 * s + 2) + (9 * s + 2) + (10 * s + 2) + 3, 0)
			ell(coreGroup, V(2 * r * 0.18, 9 * s + 3, 2 * r * 0.18), CFrame.new(tip), LIFT, M.SmoothPlastic)
			return tip
		end
		local function block(g: Instance, base: Vector3, w: number, d: number, h: number, col: Color3)
			box(g, V(w, h, d), CFrame.new(base + V(0, h / 2, 0)), col, M.Slate)
			box(g, V(w + 2, 2.4, d + 2), CFrame.new(base + V(0, h + 1.2, 0)), ROOF, M.Slate)
		end
		local function ring(g: Instance, c: Vector3, r: number, n: number, th: number, col: Color3)
			for i = 0, n - 1 do
				local a = (i + 0.5) / n * math.pi * 2
				local d = V(math.cos(a), 0, math.sin(a))
				box(g, V(2 * r * math.sin(math.pi / n) * 1.08, th, th + 1), CFrame.fromMatrix(c + d * r, UPV:Cross(d), UPV), col, M.Metal)
			end
		end

		-- 1 CENTRAL FOUNDATION / UNDERSIDE: the anchor pad on the deck, the glass lift beam, and the central floating platform with
		-- its deep underside
		local s1 = K.stage(m, 1)
		local ground = K.group(s1, "Ground")
		cyl(ground, 48, 3, CFrame.new(0, 1.5, 0), DARKU, M.DiamondPlate)
		cyl(ground, 30, 1.4, CFrame.new(0, 3.4, 0), GOLD, M.Metal)
		local beam = cyl(ground, 9, 38, CFrame.new(0, 22, 0), GLASS, M.Glass)
		beam.Transparency = 0.55
		beam.CastShadow = false
		local core1 = K.group(s1, "Core")
		platform(s1, C0, 45, core1) -- Pass 12B: central platform 80 -> 90 across (underside scales with it)

		-- 2 LOWER CENTRAL DISTRICT: a ring of six big blocks on the platform edge (heights 14..24), leaving the middle for the upper
		-- district
		local s2 = K.stage(m, 2)
		for k, h in { 16, 22, 14, 20, 18, 24 } do
			local a = math.rad((k - 1) * 60 + 30)
			block(s2, C0 + V(math.cos(a) * 32, 0, math.sin(a) * 32), 15, 15, h + 2, if k % 2 == 0 then STONE else STONE3)
		end

		-- 3 UPPER CENTRAL DISTRICT: a raised inner terrace with four domed towers
		local s3 = K.stage(m, 3)
		cyl(s3, 42, 10, CFrame.new(C0 + V(0, 5, 0)), STONE, M.Slate)
		cyl(s3, 43.6, 1.6, CFrame.new(C0 + V(0, 10.2, 0)), GOLD, M.Metal)
		for k, h in { 26, 30, 24, 28 } do
			local a = math.rad((k - 1) * 90 + 45)
			local p = C0 + V(math.cos(a) * 15, 10, math.sin(a) * 15)
			cyl(s3, 8, h, CFrame.new(p + V(0, h / 2, 0)), STONE2, M.Slate)
			ell(s3, V(9, 7, 9), CFrame.new(p + V(0, h, 0)), ROOF2, M.Slate)
		end

		-- 4 / 5 / 6 SATELLITE DISTRICTS A, B, C: separate floating platforms, each with an underside, three blocks and a glow core
		for i, key in { "A", "B", "C" } do
			local sat = SAT[key]
			local st = K.stage(m, 3 + i)
			local g = K.group(st, "Sat" .. key)
			local r = sat.r
			platform(g, sat.c, r, K.group(g, "Core"))
			block(g, sat.c + V(-0.45 * r, 0, 0.1 * r), 0.42 * r, 0.42 * r, 14, STONE)
			block(g, sat.c + V(0.45 * r, 0, -0.2 * r), 0.36 * r, 0.36 * r, 18, STONE3)
			block(g, sat.c + V(-0.05 * r, 0, -0.55 * r), 0.5 * r, 0.3 * r, 11, STONE2)
			K.marker(g, "Sat" .. key .. "C", sat.c)
		end

		-- 7 GIANT STRUCTURAL BRIDGES: huge sloping spans from the central platform to A and B (each belongs to its satellite);
		-- a deep V truss under each span leaves open sky below
		local s7 = K.stage(m, 7)
		for _, key in { "A", "B" } do
			local sat = SAT[key]
			local flat = V(sat.c.X, 0, sat.c.Z)
			local dir = flat.Unit
			local p1 = dir * 39 + V(0, C0.Y - 1.5, 0)
			local p2 = flat - dir * (sat.r - 4) + V(0, sat.c.Y - 1.5, 0)
			local g = K.group(s7, "Sat" .. key)
			box(g, V(14, 3, (p2 - p1).Magnitude + 2), CFrame.lookAt((p1 + p2) / 2, p2), STONE2, M.Slate)
			local low = (p1 + p2) / 2 - V(0, 14, 0)
			bar(g, p1 - V(0, 2, 0), low, 4, UNDER, M.Metal)
			bar(g, low, p2 - V(0, 2, 0), 4, UNDER, M.Metal)
			bar(g, p1 - V(0, 1.6, 0), p2 - V(0, 1.6, 0), 2.5, GOLD, M.Metal) -- a gold edge line along the deck underside
		end

		-- 8 CENTRAL TOWER / SKYLINE HERO MASS: a stepped spire from the upper terrace to y ~200 with window bands
		local s8 = K.stage(m, 8)
		local tower = K.group(s8, "Tower")
		-- Pass 12B: a heavier, taller spire (base 20 -> 26 across, top ~y 222 authored)
		cyl(tower, 26, 60, CFrame.new(C0 + V(0, 10 + 30, 0)), STONE, M.Slate)
		cyl(tower, 18, 34, CFrame.new(C0 + V(0, 70 + 17, 0)), STONE2, M.Slate)
		cyl(tower, 10, 18, CFrame.new(C0 + V(0, 104 + 9, 0)), STONE, M.Slate)
		ell(tower, V(12, 12, 12), CFrame.new(C0 + V(0, 123, 0)), GOLD, M.Metal)
		cyl(tower, 1.8, 16, CFrame.new(C0 + V(0, 134, 0)), GOLD, M.Metal)
		cyl(tower, 28, 2, CFrame.new(C0 + V(0, 70, 0)), GOLD, M.Metal)
		cyl(tower, 20, 2, CFrame.new(C0 + V(0, 104, 0)), GOLD, M.Metal)
		local glow = K.group(tower, "Glow")
		for _, y in { 32, 52 } do
			cyl(glow, 26.6, 3, CFrame.new(C0 + V(0, y, 0)), LIFT, M.SmoothPlastic)
		end
		cyl(glow, 18.6, 3, CFrame.new(C0 + V(0, 90, 0)), LIFT, M.SmoothPlastic)
		K.marker(tower, "TowerTop", C0 + V(0, 140, 0))

		-- 9 UNDERSIDE LIFT RINGS: a giant ring under the centre and one under each satellite (each spins in the show)
		local s9 = K.stage(m, 9)
		local rc = K.group(s9, "RingC")
		ring(rc, C0 - V(0, 28, 0), 32, 14, 3.6, LIFT)
		K.marker(rc, "RingCC", C0 - V(0, 28, 0))
		for key, rname in { A = "RingA", B = "RingB", C = "RingD" } do
			local sat = SAT[key]
			local g = K.group(K.group(s9, "Sat" .. key), rname)
			local y = sat.c.Y - 16 * sat.r / 40 - 2
			ring(g, V(sat.c.X, y, sat.c.Z), sat.r * 0.62, 8, 2.6, LIFT)
			K.marker(g, rname .. "C", V(sat.c.X, y, sat.c.Z))
		end

		-- 10 SECONDARY SKYLINE: a tall tower on every satellite and two tall towers flanking the spire
		local s10 = K.stage(m, 10)
		for key, h in { A = 40, B = 46, C = 36 } do
			local sat = SAT[key]
			local g = K.group(s10, "Sat" .. key)
			local p = sat.c + V(0.1 * sat.r, 0, 0.42 * sat.r)
			cyl(g, 9, h, CFrame.new(p + V(0, h / 2, 0)), STONE, M.Slate)
			ell(g, V(10, 9, 10), CFrame.new(p + V(0, h, 0)), ROOF2, M.Slate)
			local gl = K.group(g, "Glow")
			cyl(gl, 9.6, 2.4, CFrame.new(p + V(0, h * 0.7, 0)), LIFT, M.SmoothPlastic)
		end
		for _, sx in { -1, 1 } do
			local p = C0 + V(sx * 24, 0, 0)
			cyl(s10, 10, 56, CFrame.new(p + V(0, 28, 0)), STONE3, M.Slate)
			ell(s10, V(11, 10, 11), CFrame.new(p + V(0, 56, 0)), ROOF, M.Slate)
		end

		-- 11 CITY CROWN: a halo ring around the spire at y ~165 on four spokes
		local s11 = K.stage(m, 11)
		local crown = K.group(s11, "Tower")
		local hc = C0 + V(0, 96, 0)
		ring(crown, hc, 25, 12, 3.2, GOLD)
		for k = 0, 3 do
			local a = math.rad(k * 90 + 45)
			bar(crown, hc + V(math.cos(a) * 8, 0, math.sin(a) * 8), hc + V(math.cos(a) * 24, 0, math.sin(a) * 24), 2, GOLD, M.Metal)
		end
		return m
	end,
}
