--!nonstrict
-- VOLCANO TEMPLE (Epic). A broad, low, faceted volcano (about 180 across, ~114 tall) shaped as a truncated cone: a shallow outer
-- apron, a steeper middle flank and an upper cone ending in a wide (60 across) jagged crater. A sandstone temple is carved into the front
-- slope (-Z, the spawn): a deep giant doorway, a columned portico and a rock brow over it, with the mountain wrapping its sides.
-- Four lava channels run from the crater rim down the flanks; lava pools sit on the terrace and in the crater.
-- Every lava piece carries attribute Lava = true (Glow = 1 marks the early-glow pieces: door, terrace basins, crater pool).
-- Markers: Vent (crater centre, eruption source), DoorC (doorway).
return {
	Id = "VolcanoTemple",
	Build = function(K)
		local V, M, RGB, box, cyl, ell, wedge = K.V, K.M, K.RGB, K.box, K.cyl, K.ell, K.wedge
		local ROCK, ROCK2, ROCK3, ASH = RGB(92, 78, 70), RGB(108, 92, 80), RGB(72, 62, 58), RGB(56, 50, 50)
		local SAND, SAND2, SAND3, GOLD = RGB(196, 168, 124), RGB(170, 144, 106), RGB(140, 118, 88), RGB(214, 170, 60)
		local LAVA = RGB(96, 42, 30) -- cooled lava (the client show heats it up)
		local m = K.template("VolcanoTemple")
		local N = 16
		local LAVAA = { Lava = true }
		local GLOW = { Lava = true, Glow = 1 }

		-- a faceted conical band: N wedges whose sloped faces run from radius ro (height y0) up to radius ri (height y0 + h);
		-- facet centres sit at -90 + k * 22.5 degrees, so lava channels placed on those angles lie exactly on a facet
		local function band(parent: Instance, ro: number, ri: number, y0: number, h: number, mat, cols, jit: number)
			for k = 0, N - 1 do
				local a = math.rad(-90 + k * 360 / N)
				local d = V(math.cos(a), 0, math.sin(a))
				local hh = h + ((k * 7) % 5) / 4 * jit -- a little irregularity per facet
				local c = d * ((ro + ri) / 2) + V(0, y0 + hh / 2, 0)
				wedge(parent, V(2 * ro * math.sin(math.pi / N) * 1.05, hh, ro - ri), CFrame.lookAt(c, c + d), cols[k % #cols + 1], mat)
			end
		end
		-- a lava strip lying on the cone surface along angle `deg` from (r1, y1) down to (r2, y2)
		local function flow(parent: Instance, deg: number, r1: number, y1: number, r2: number, y2: number, w: number)
			local a = math.rad(deg)
			local d = V(math.cos(a), 0, math.sin(a))
			local p1, p2 = d * r1 + V(0, y1, 0), d * r2 + V(0, y2, 0)
			local t = p2 - p1
			local n = (d * (y1 - y2) + V(0, r2 - r1, 0)).Unit -- outward/up surface normal
			local mid = (p1 + p2) / 2 + n * 0.7
			box(parent, V(w, 1.6, t.Magnitude + 3), CFrame.lookAt(mid, mid + t, n), LAVA, M.Basalt, LAVAA)
		end

		-- 1 TEMPLE TERRACE: a dark rock apron over the deck, a broad stone terrace cut into the front, an upper landing for the
		-- temple, a grand stair and two lava basins either side of it (they give the first glow)
		local s1 = K.stage(m, 1)
		cyl(s1, 178, 2, CFrame.new(0, 1, 0), ASH, M.Slate)
		box(s1, V(94, 8, 30), CFrame.new(0, 6, -68), SAND3, M.Sandstone)
		box(s1, V(70, 6, 24), CFrame.new(0, 13, -62), SAND2, M.Sandstone)
		wedge(s1, V(34, 8, 8), CFrame.new(0, 6, -88), SAND2, M.Sandstone)
		wedge(s1, V(26, 6, 6), CFrame.new(0, 13, -77), SAND2, M.Sandstone)
		for _, sx in { -1, 1 } do
			box(s1, V(20, 2, 9), CFrame.new(sx * 28, 10, -79), SAND3, M.Sandstone)
			box(s1, V(16, 1, 6), CFrame.new(sx * 28, 10.6, -79), LAVA, M.Basalt, GLOW)
		end

		-- 2 LOWER VOLCANO MASS: the shallow outer apron (r 88 -> 66, to y 22) and the steeper middle flank (r 66 -> 48, to y 48)
		local s2 = K.stage(m, 2)
		band(s2, 88, 66, 2, 20, M.Slate, { ROCK, ROCK2 }, 2)
		cyl(s2, 134, 20, CFrame.new(0, 12, 0), ROCK3, M.Slate)
		band(s2, 66, 48, 22, 26, M.Slate, { ROCK2, ROCK }, 3)
		cyl(s2, 98, 26, CFrame.new(0, 35, 0), ROCK3, M.Slate)

		-- 3 UPPER VOLCANO MASS: the upper cone (r 48 -> 30, to y 88) around a wide hollow crater (the fill stops at y 78)
		local s3 = K.stage(m, 3)
		band(s3, 48, 30, 48, 40, M.Basalt, { ROCK3, ASH }, 3)
		cyl(s3, 62, 30, CFrame.new(0, 63, 0), ASH, M.Basalt)

		-- 4 TEMPLE FACADE: a sandstone block carved into the slope with a giant doorway (20 x 22, 28 deep), a four-column
		-- portico with a pediment, a rock brow over the block and rock flanks that wrap its sides into the mountain
		local s4 = K.stage(m, 4)
		for _, sx in { -1, 1 } do
			box(s4, V(17, 30, 30), CFrame.new(sx * 18.5, 29, -45), SAND, M.Sandstone) -- walls either side of the door
			local c = V(sx * 40, 31, -45)
			wedge(s4, V(32, 46, 26), CFrame.lookAt(c, c + V(sx, 0, 0)), ROCK, M.Slate) -- the mountain wraps the block
		end
		box(s4, V(20, 6, 30), CFrame.new(0, 41, -45), SAND, M.Sandstone) -- lintel
		box(s4, V(20, 22, 2), CFrame.new(0, 27, -31), LAVA, M.Basalt, GLOW) -- the glowing heart deep inside the door
		K.marker(s4, "DoorC", V(0, 27, -58))
		for _, x in { -24, -14, 14, 24 } do
			cyl(s4, 5.5, 22, CFrame.new(x, 27, -65), SAND2, M.Sandstone)
		end
		box(s4, V(58, 5, 11), CFrame.new(0, 40.5, -64), SAND2, M.Sandstone) -- entablature
		for _, sx in { -1, 1 } do
			wedge(s4, V(11, 10, 29), CFrame.new(sx * -14.5, 48, -64) * CFrame.Angles(0, math.rad(sx * 90), 0), SAND, M.Sandstone)
		end
		wedge(s4, V(74, 14, 32), CFrame.new(0, 51, -46), ROCK2, M.Slate) -- rock brow over the block, sloping back into the cone

		-- 5 LAVA CHANNELS: four broad channels from the crater rim down the flanks (two flank the temple, two run down the
		-- back shoulders), widening as they fall, each ending in a lava fan on the apron
		local s5 = K.stage(m, 5)
		for _, deg in { -157.5, -22.5, 45, 135 } do
			flow(s5, deg, 31, 88, 48, 48, 8)
			flow(s5, deg, 48, 48, 66, 22, 10)
			flow(s5, deg, 66, 22, 88, 2, 12)
			local a = math.rad(deg)
			ell(s5, V(22, 1.6, 22), CFrame.new(math.cos(a) * 88, 2.4, math.sin(a) * 88), LAVA, M.Basalt, LAVAA)
		end

		-- 6 CRATER: a jagged broken rim of big rock blocks around the throat and a lava pool deep inside it (the cavity reads
		-- from above and as a notched crown from the ground)
		local s6 = K.stage(m, 6)
		for k = 0, 13 do
			local a = math.rad(k * 360 / 14 + 8)
			local d = V(math.cos(a), 0, math.sin(a))
			local h = 7 + ((k * 5) % 4) * 2.5
			local c = d * 31 + V(0, 86 + h / 2, 0)
			box(s6, V(15, h, 9), CFrame.lookAt(c, c + d) * CFrame.Angles(math.rad(-12), 0, 0), if k % 2 == 0 then ROCK3 else ASH, M.Basalt)
		end
		cyl(s6, 54, 1, CFrame.new(0, 78.6, 0), LAVA, M.Basalt, GLOW)
		K.marker(s6, "Vent", V(0, 80, 0))

		-- 7 SUMMIT: three big broken peaks on the back of the rim make the summit taller and asymmetric, and two rock
		-- buttresses ridge the upper flanks
		local s7 = K.stage(m, 7)
		for _, p in { { 66, 26 }, { 108, 21 }, { 146, 15 } } do
			local a = math.rad(p[1])
			local d = V(math.cos(a), 0, math.sin(a))
			local c = d * 34 + V(0, 88 + p[2] / 2, 0)
			box(s7, V(22, p[2], 16), CFrame.lookAt(c, c + d) * CFrame.Angles(math.rad(-16), 0, 0), ROCK3, M.Basalt)
		end
		for _, deg in { -60, -120 } do
			local a = math.rad(deg)
			local d = V(math.cos(a), 0, math.sin(a))
			local c = d * 45 + V(0, 62, 0)
			wedge(s7, V(14, 32, 18), CFrame.lookAt(c, c + d), ROCK2, M.Slate)
		end

		-- 8 TEMPLE CROWN: a carved stepped crest set into the rock brow with a gold sun disc, and two giant fire braziers
		local s8 = K.stage(m, 8)
		box(s8, V(42, 6, 14), CFrame.new(0, 56, -50), SAND2, M.Sandstone)
		box(s8, V(26, 6, 12), CFrame.new(0, 61, -47), SAND, M.Sandstone)
		cyl(s8, 14, 1.2, CFrame.new(0, 57, -57.6) * CFrame.Angles(math.rad(90), 0, 0), GOLD, M.Metal) -- sun disc
		for _, sx in { -1, 1 } do
			box(s8, V(9, 20, 9), CFrame.new(sx * 40, 20, -72), SAND2, M.Sandstone)
			cyl(s8, 14, 4, CFrame.new(sx * 40, 32, -72), SAND3, M.Sandstone)
			ell(s8, V(10, 9, 10), CFrame.new(sx * 40, 36, -72), LAVA, M.Basalt, LAVAA)
		end
		return m
	end,
}
