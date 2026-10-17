--!nonstrict
-- FORGOTTEN F6 (server-only template, id "Fg8m"): a machine whose geometry contradicts itself. Six dominant forms around an open void:
-- an outer square loop (back), a big ring facing the viewer (Circle I), a ring facing sideways (Circle II), a tall vertical rail that
-- tilts in DEPTH so it passes in front of Circle I at the top and behind it at the bottom, a diagonal frame crossing the whole
-- composition (in front low-right, behind high-left), and a FINAL LOOP whose four beams each slant in depth so every corner has the
-- next beam in front (a cyclic overlap: an impossible closed square from the main view). A paradox core hangs in the middle void.
-- Nothing here is a trick of tiny detail: the contradictions are big depth tilts and overlaps. Pale stone frames, dark steel, aged brass.
-- Groups: Base, Outer, CircleI, Rail, Block, CircleII, Tower, Counter, Diagonal, Core, CoreGlow, Upper, Gear, Connector, Loop, Paradox.
-- Markers: CircleIC, CircleIIC, CoreC, UpperP, GearC, LoopC.
return {
	Id = "Fg8m",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, cylZ, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.cylZ, K.wedge
		local PALE, STONE, STEEL, BRASS = RGB(204, 199, 184), RGB(150, 146, 136), RGB(62, 66, 74), RGB(172, 138, 74)
		local GLOW0 = RGB(86, 128, 148)
		local m = K.template("Fg8m")
		local A, r = CFrame.Angles, math.rad

		-- a ring made of boxes in the plane perpendicular to `ax` (unit); brass lugs break the line so rotation reads
		local function basis(ax)
			local up = if math.abs(ax.Y) > 0.9 then V(1, 0, 0) else V(0, 1, 0)
			local e1 = ax:Cross(up).Unit
			return e1, ax:Cross(e1).Unit
		end
		local function ring(parent, c, ax, R, tube, depth, n, lugEvery)
			local e1, e2 = basis(ax)
			for i = 0, n - 1 do
				local a = i / n * math.pi * 2
				local rad = e1 * math.cos(a) + e2 * math.sin(a)
				local tan = -e1 * math.sin(a) + e2 * math.cos(a)
				local lug = i % lugEvery == 0
				box(parent, V(if lug then depth * 1.4 else depth, if lug then tube * 1.5 else tube, 2 * R * math.sin(math.pi / n) * 1.07), CFrame.lookAt(c + rad * R, c + rad * R + tan, rad), if lug then BRASS else (if i % 2 == 0 then STEEL else STONE), if lug then M.Metal else M.Slate)
			end
		end

		-- 1 BASE FRAME: three separate footings (under the loop, the rail, the tower) and a low front plinth
		local s1 = K.stage(m, 1)
		local base = K.group(s1, "Base")
		box(base, V(156, 12, 34), CFrame.new(-50, 6, 96), STONE, M.Concrete)
		box(base, V(46, 12, 46), CFrame.new(-64, 6, 0), STONE, M.Concrete)
		box(base, V(54, 12, 54), CFrame.new(96, 6, 30), STONE, M.Concrete)
		box(base, V(120, 6, 46), CFrame.new(-6, 3, -52), STEEL, M.Concrete)

		-- 2 OUTER SQUARE LOOP: a heavy rectangular stone frame standing at the back
		local s2 = K.stage(m, 2)
		local ou = K.group(s2, "Outer")
		-- a tall rectangle standing far back and left (not a box around everything); the rail climbs "through" it
		box(ou, V(146, 14, 16), CFrame.new(-50, 30, 96), PALE, M.Slate)
		box(ou, V(146, 14, 16), CFrame.new(-50, 250, 96), PALE, M.Slate)
		box(ou, V(16, 234, 16), CFrame.new(-115, 140, 96), PALE, M.Slate)
		box(ou, V(16, 234, 16), CFrame.new(15, 140, 96), PALE, M.Slate)
		for _, p in { V(-115, 30, 96), V(15, 30, 96), V(-115, 250, 96), V(15, 250, 96) } do
			box(ou, V(22, 22, 20), CFrame.new(p), BRASS, M.Metal)
		end

		-- 3 CIRCLE I: a big ring facing the viewer, low-left and a little behind the void
		local s3 = K.stage(m, 3)
		local c1 = K.group(s3, "CircleI")
		local c1c = V(-82, 100, 46)
		ring(c1, c1c, V(0, 0, 1), 44, 10, 14, 24, 6)
		cylZ(c1, 18, 16, CFrame.new(c1c), BRASS, M.Metal)
		for k = 0, 2 do
			local a = k / 3 * math.pi * 2 + 0.5
			bar(c1, c1c, c1c + V(math.cos(a) * 40, math.sin(a) * 40, 0), 6, STEEL, M.Metal)
		end
		K.marker(c1, "CircleIC", c1c)

		-- 4 VERTICAL RAIL: one tall beam tilted in depth (z +34 at the bottom, -34 at the top): in front of Circle I at the top, behind it low
		local s4 = K.stage(m, 4)
		local rl = K.group(s4, "Rail")
		bar(rl, V(-64, 12, 34), V(-64, 250, -34), 11, STEEL, M.Metal)
		bar(rl, V(-64, 12, 34), V(-64, 250, -34), 3, BRASS, M.Metal).Size = V(15, 3, (V(-64, 250, -34) - V(-64, 12, 34)).Magnitude)
		box(rl, V(18, 8, 18), CFrame.new(-64, 252, -35), BRASS, M.Metal)

		-- 5 SUSPENDED BLOCK: a heavy block gripping the rail, trapped between the rail and Circle I's plane
		local s5 = K.stage(m, 5)
		local bk = K.group(s5, "Block")
		local rz = function(y) return 34 - (y - 12) / 238 * 68 end
		box(bk, V(40, 40, 40), CFrame.new(-64, 150, rz(150)), STONE, M.Slate)
		box(bk, V(44, 6, 44), CFrame.new(-64, 133, rz(133)), BRASS, M.Metal)
		box(bk, V(44, 6, 44), CFrame.new(-64, 167, rz(167)), BRASS, M.Metal)

		-- 6 CIRCLE II: a smaller ring facing sideways, upper right: it passes "through" the plane of the outer loop
		local s6 = K.stage(m, 6)
		local c2 = K.group(s6, "CircleII")
		local c2c = V(64, 164, -22)
		ring(c2, c2c, V(1, 0, 0), 40, 10, 13, 22, 5)
		cyl(c2, 14, 14, CFrame.new(c2c) * A(0, 0, r(90)), BRASS, M.Metal)
		K.marker(c2, "CircleIIC", c2c)

		-- 7 COUNTERWEIGHT TOWER: a tall open tower at the back right with a heavy weight hanging inside it
		local s7 = K.stage(m, 7)
		local tw = K.group(s7, "Tower")
		for _, sz in { 18, 42 } do
			box(tw, V(10, 168, 10), CFrame.new(96, 96, sz), STEEL, M.Metal)
		end
		box(tw, V(18, 8, 38), CFrame.new(96, 184, 30), STONE, M.Slate)
		local cw = K.group(s7, "Counter")
		box(cw, V(34, 30, 20), CFrame.new(96, 112, 30), STONE, M.Slate)
		box(cw, V(38, 5, 24), CFrame.new(96, 129, 30), BRASS, M.Metal)

		-- 8 DIAGONAL FRAME: two parallel beams crossing the whole composition (front at low right, behind at high left)
		local s8 = K.stage(m, 8)
		local dg = K.group(s8, "Diagonal")
		bar(dg, V(112, 96, -90), V(-96, 252, 60), 14, PALE, M.Slate)
		box(dg, V(20, 20, 20), CFrame.new(112, 96, -90), BRASS, M.Metal)

		-- 9 CORE: the readable central core, hung in the void
		local s9 = K.stage(m, 9)
		local co = K.group(s9, "Core")
		local cc = V(6, 122, -6)
		K.marker(co, "CoreC", cc)
		box(co, V(34, 34, 34), CFrame.new(cc) * A(r(45), r(45), 0), STEEL, M.Metal)
		cyl(co, 40, 4, CFrame.new(cc) * A(r(12), 0, r(8)), BRASS, M.Metal)
		local cg = K.group(s9, "CoreGlow")
		box(cg, V(16, 16, 16), CFrame.new(cc) * A(r(45), r(45), 0), GLOW0, M.SmoothPlastic)

		-- 10 UPPER MECHANISM: a long stone crossbar high in the void and a heavy swing arm hung from it
		local s10 = K.stage(m, 10)
		local up = K.group(s10, "Upper")
		box(up, V(120, 12, 12), CFrame.new(30, 198, -24), PALE, M.Slate)
		K.marker(up, "UpperP", V(72, 198, -24))
		bar(up, V(72, 198, -24), V(72, 140, -24), 9, STEEL, M.Metal)
		box(up, V(28, 20, 28), CFrame.new(72, 134, -24), BRASS, M.Metal)

		-- 11 REVERSE GEAR: the one gear, low in front of the rail foot
		local s11 = K.stage(m, 11)
		local gr = K.group(s11, "Gear")
		local gc = V(-100, 46, -38)
		ring(gr, gc, V(0, 0, 1), 28, 8, 12, 16, 4)
		for i = 0, 11 do
			local a = (i + 0.5) / 12 * math.pi * 2
			local p = gc + V(math.cos(a) * 33, math.sin(a) * 33, 0)
			box(gr, V(11, 9, 12), CFrame.lookAt(p, gc) * A(0, 0, 0), if i % 2 == 0 then STONE else STEEL, M.Slate)
		end
		cylZ(gr, 16, 14, CFrame.new(gc), BRASS, M.Metal)
		K.marker(gr, "GearC", gc)

		-- 12 FLOATING CONNECTOR: a heavy beam hovering between Circle II and the tower, touching neither
		local s12 = K.stage(m, 12)
		local cn = K.group(s12, "Connector")
		bar(cn, V(80, 150, -2), V(88, 186, 20), 10, PALE, M.Slate)
		box(cn, V(16, 16, 16), CFrame.new(80, 150, -2), BRASS, M.Metal)
		box(cn, V(16, 16, 16), CFrame.new(88, 186, 20), BRASS, M.Metal)

		-- 13 FINAL LOOP: four slanted beams: every corner has the NEXT beam in front: a closed square that cannot exist
		local s13 = K.stage(m, 13)
		local lp = K.group(s13, "Loop")
		local P = { V(-76, 74, 0), V(76, 74, 0), V(76, 226, 0), V(-76, 226, 0) }
		for i = 1, 4 do
			local a, b = P[i], P[i % 4 + 1]
			bar(lp, V(a.X, a.Y, -88), V(b.X, b.Y, -58), 9, if i % 2 == 0 then PALE else STONE, M.Slate)
			box(lp, V(13, 13, 13), CFrame.new(a.X, a.Y, -88), BRASS, M.Metal)
		end
		K.marker(lp, "LoopC", V(0, 150, -73))

		-- 14 PARADOX CORE: two nested open cubes (wire frames) turning around the core
		local s14 = K.stage(m, 14)
		local pd = K.group(s14, "Paradox")
		local function wire(size, rot, col)
			local h = size / 2
			local function at(x, y, z) return cc + (rot * V(x, y, z)) end
			for _, sy in { -1, 1 } do
				for _, sz in { -1, 1 } do
					bar(pd, at(-h, sy * h, sz * h), at(h, sy * h, sz * h), 4, col, M.Metal)
				end
			end
			for _, sx in { -1, 1 } do
				for _, sz in { -1, 1 } do
					bar(pd, at(sx * h, -h, sz * h), at(sx * h, h, sz * h), 4, col, M.Metal)
				end
			end
			for _, sx in { -1, 1 } do
				for _, sy in { -1, 1 } do
					bar(pd, at(sx * h, sy * h, -h), at(sx * h, sy * h, h), 4, col, M.Metal)
				end
			end
		end
		wire(60, CFrame.new(), BRASS)
		wire(44, A(0, r(45), r(35)), STEEL)
		-- the final loop is rolled about 18 degrees (distinct from the axis-aligned frames) around the core
		local lc = V(0, 150, -73)
		local roll = CFrame.new(lc) * A(0, 0, r(18)) * CFrame.new(-lc)
		for _, g in m:GetDescendants() do
			if g:IsA("Model") and g.Name == "Loop" then
				for _, p in g:GetDescendants() do
					if p:IsA("BasePart") then
						p.CFrame = roll * p.CFrame
					end
				end
			end
		end
		return m
	end,
}
