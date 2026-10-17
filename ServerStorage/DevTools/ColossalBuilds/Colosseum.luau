--!nonstrict
-- COLOSSEUM ARENA (Epic). A wide, low elliptical amphitheatre (about 178 x 146, wall ~61 tall, back attic ~74, gate crown ~80):
-- a stone plinth with a sand arena, a lower arcade of 16 big bays (piers + ring beam + chamfered arch shoulders), a solid
-- upper ring, an upper arcade of 16 open bays, a seating bowl sloping down to the arena, a monumental entrance gate facing
-- the spawn (-Z) and a crown: a raised attic around the back half with flags. The upper arcade stands above the bowl, so its
-- openings read as open sky / far wall; the gate opening is 30 x 44.
-- Groups for the client show: Band (the 16 upper-ring segments the completion wave lights), Torch (8 braziers; the flame part has attribute Flame and starts invisible), Banner (8 hanging
-- banners), Flag (6 attic flags).
return {
	Id = "Colosseum",
	Build = function(K)
		local V, M, RGB, box, cyl, ell, wedge = K.V, K.M, K.RGB, K.box, K.cyl, K.ell, K.wedge
		local STONE, STONE2, STONE3, SEAT = RGB(206, 190, 160), RGB(184, 166, 136), RGB(150, 134, 110), RGB(126, 110, 90)
		local SAND, BRONZE, RED, GOLD = RGB(214, 190, 140), RGB(150, 104, 56), RGB(172, 42, 38), RGB(214, 170, 60)
		local FLAME = RGB(255, 98, 22)
		local m = K.template("Colosseum")
		local A, B, NB = 84, 66, 16
		local UP = Vector3.yAxis
		local function P(t: number, da: number?): Vector3 -- point on the ellipse (shrunk by da), t in degrees
			local r = math.rad(t)
			return V((A - (da or 0)) * math.cos(r), 0, (B - (da or 0)) * math.sin(r))
		end
		local function normal(t: number): Vector3
			local r = math.rad(t)
			return V(B * math.cos(r), 0, A * math.sin(r)).Unit
		end
		local function pierT(k: number): number -- pier k sits between bays; bay 0 is centred on the front (-Z)
			return -90 + (k + 0.5) * 360 / NB
		end
		-- a ring of piers (one per bay boundary) from y0 to y1
		local function piers(parent: Instance, y0: number, y1: number, w: number, d: number, col: Color3)
			for k = 0, NB - 1 do
				local t = pierT(k)
				local n = normal(t)
				box(parent, V(w, y1 - y0, d), CFrame.fromMatrix(P(t) + V(0, (y0 + y1) / 2, 0), UP:Cross(n), UP), col, M.Sandstone)
			end
		end
		-- a ring of straight segments between consecutive piers (beams / solid bands), y0..y1, `extra` overlap into piers
		local function ring(parent: Instance, y0: number, y1: number, d: number, col: Color3, extra: number, only: ((number) -> boolean)?, da: number?)
			for k = 0, NB - 1 do
				local ta, tb = pierT(k), pierT(k + 1)
				if not only or only((ta + tb) / 2) then
					local a, b = P(ta, da), P(tb, da)
					local u = (b - a).Unit
					box(parent, V((b - a).Magnitude + extra, y1 - y0, d), CFrame.fromMatrix((a + b) / 2 + V(0, (y0 + y1) / 2, 0), u, UP), col, M.Sandstone)
				end
			end
		end

		-- 1 ARENA FLOOR / FOUNDATION: a broad stone plinth, a stepped outer terrace and the sand arena floor
		local s1 = K.stage(m, 1)
		ell(s1, V(184, 4, 160), CFrame.new(0, 1, 0), STONE3, M.Slate)
		ell(s1, V(172, 6, 148), CFrame.new(0, 1.5, 0), STONE2, M.Sandstone)
		ell(s1, V(96, 2, 68), CFrame.new(0, 4, 0), SAND, M.Sand)

		-- 2 LOWER WALL MASS: 16 heavy piers (9 x 24 x 11) around the ellipse
		local s2 = K.stage(m, 2)
		piers(s2, 3, 27, 10, 15, STONE)

		-- 3 LOWER ARCADE: the ring beam over the bays and chamfered arch shoulders in every opening (each bay ~20 wide, 24 tall),
		-- plus eight bronze torch braziers on the pier faces
		local s3 = K.stage(m, 3)
		ring(s3, 27, 33, 15, STONE2, 9)
		for k = 0, NB - 1 do
			local ta, tb = pierT(k), pierT(k + 1)
			local a, b = P(ta), P(tb)
			local u = (b - a).Unit
			for _, e in { { a, -u, u }, { b, u, -u } } do
				local c = e[1] + e[3] * 7.5 + V(0, 23, 0)
				local Z, Y = e[2], V(0, -1, 0)
				wedge(s3, V(15, 9, 6), CFrame.fromMatrix(c, Y:Cross(Z), Y, Z), STONE, M.Sandstone)
			end
		end
		for k = 0, NB - 1, 2 do
			local t = pierT(k + 1)
			local n = normal(t)
			local torch = K.group(s3, "Torch")
			local base = P(t) + n * 8.5
			cyl(torch, 6, 2, CFrame.new(base + V(0, 21, 0)), BRONZE, M.Metal)
			local f = ell(torch, V(5, 8, 5), CFrame.new(base + V(0, 26, 0)), FLAME, M.Neon, { Flame = true })
			f.Transparency = 1
			f.CastShadow = false
		end

		-- 4 UPPER RING: a solid projecting band all the way round (y 33..41), the floor of the upper arcade
		local s4 = K.stage(m, 4)
		ring(K.group(s4, "Band"), 33, 41, 17, STONE3, 10)

		-- 5 UPPER ARCADE: 16 piers (y 41..57) and their ring beam: big open bays above the seating bowl; eight red banners hang
		-- on alternate piers
		local s5 = K.stage(m, 5)
		piers(s5, 41, 57, 10, 12, STONE)
		ring(s5, 57, 61, 12, STONE2, 9)
		for k = 0, NB - 1, 2 do
			local t = pierT(k)
			local n = normal(t)
			local banner = K.group(s5, "Banner")
			box(banner, V(7, 13, 0.8), CFrame.fromMatrix(P(t) + n * 5.6 + V(0, 49, 0), UP:Cross(n), UP), RED, M.Fabric)
		end

		-- 6 SEATING BOWL: 16 sloped stands from y 36 down to the arena edge, set back 11 studs behind the piers so the lower
		-- arches read as deep shadowed openings
		local s6 = K.stage(m, 6)
		for k = 0, NB - 1 do
			local t = -90 + k * 360 / NB
			local n = normal(t)
			local w = (P(t + 11.25, 16) - P(t - 11.25, 16)).Magnitude * 1.08
			local c = P(t, 28) + V(0, 20, 0)
			wedge(s6, V(w, 32, 24), CFrame.fromMatrix(c, UP:Cross(n), UP, n), if k % 2 == 0 then SEAT else STONE2, M.Sandstone)
		end

		-- 7 GIANT ENTRANCE: two massive pylons and a deep lintel framing a 30 x 44 opening, an attic block with a pediment and
		-- a gold inscription band
		local s7 = K.stage(m, 7)
		local GZ = -B - 7
		for _, sx in { -1, 1 } do
			box(s7, V(14, 58, 14), CFrame.new(sx * 22, 32, GZ), STONE, M.Sandstone)
			local c = V(sx * 11, 43, GZ)
			wedge(s7, V(14, 10, 8), CFrame.fromMatrix(c, V(0, -1, 0):Cross(V(sx, 0, 0)), V(0, -1, 0), V(sx, 0, 0)), STONE, M.Sandstone)
		end
		box(s7, V(30, 14, 14), CFrame.new(0, 54, GZ), STONE2, M.Sandstone)
		box(s7, V(62, 8, 16), CFrame.new(0, 65, GZ), STONE2, M.Sandstone)
		for _, sx in { -1, 1 } do
			wedge(s7, V(14, 11, 31), CFrame.new(sx * -15.5, 74.5, GZ) * CFrame.Angles(0, math.rad(sx * 90), 0), STONE, M.Sandstone)
		end
		box(s7, V(34, 4, 0.6), CFrame.new(0, 54, GZ - 7.2), GOLD, M.Metal)

		-- 8 CROWN / BANNERS: a raised attic wall around the back half (to y 74) with six flags on it
		local s8 = K.stage(m, 8)
		local function back(t: number): boolean
			return math.sin(math.rad(t)) > 0.15
		end
		ring(s8, 61, 74, 9, STONE, 9, back)
		local i = 0
		for k = 0, NB - 1 do
			local t = pierT(k)
			if math.sin(math.rad(t)) > 0.3 then
				i += 1
				if i <= 6 then
					local p = P(t)
					cyl(s8, 1.6, 20, CFrame.new(p + V(0, 84, 0)), BRONZE, M.Metal)
					local n = normal(t)
					local tang = UP:Cross(n)
					local flag = K.group(s8, "Flag")
					box(flag, V(10, 6, 0.4), CFrame.fromMatrix(p + tang * 5.4 + V(0, 90.5, 0), tang, UP), RED, M.Fabric)
				end
			end
		end
		return m
	end,
}
