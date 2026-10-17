--!nonstrict
-- FORGOTTEN F2 (server-only template, id "Fg3c"): an ancient world engine. A vertical central axle runs through a nest of
-- concentric mechanisms (a vertical ring, a horizontal ring, an inner armillary, a split core) inside a square outer frame whose
-- big open bays are deliberate voids. Two giant gears sit on different faces, counterweights hang from arms over the core.
-- No front: the plan is a square with the axle at the centre. Ivory/stone/steel/aged brass; cold glow only on the core band,
-- the synchronizer conduits and the crown.
-- Groups: Frame, Axle, Gear1, Gear2, VRing, HRing, Inner, CoreLow, CoreUp, CoreGlow, Arms, Weights (Alt 1/2), Sync (Order 1..n), Crown.
-- Markers (centres): Gear1C (axis Z), Gear2C (axis X), VRingC (axis Z), HRingC (axis Y), InnerC (axis X), CoreC.
return {
	Id = "Fg3c",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, ell, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.ell, K.wedge
		local IVORY, STONE, DARK, STEEL, BRASS = RGB(206, 198, 176), RGB(150, 144, 132), RGB(86, 84, 80), RGB(96, 106, 112), RGB(170, 134, 70)
		local GLOW0 = RGB(52, 78, 96)
		local m = K.template("Fg3c")
		local C = V(0, 125, 0) -- the core / nest centre

		local function basis(ax: Vector3)
			local up = if math.abs(ax.Y) > 0.9 then V(1, 0, 0) else V(0, 1, 0)
			local e1 = ax:Cross(up).Unit
			return e1, ax:Cross(e1).Unit
		end
		-- a ring perpendicular to `ax`: boxes along the circle, a brass lug every `lugEvery` (so spinning reads)
		local function ring(parent: Instance, c: Vector3, ax: Vector3, R: number, tube: number, depth: number, n: number, lugEvery: number)
			local e1, e2 = basis(ax)
			for i = 0, n - 1 do
				local a = i / n * math.pi * 2
				local radial = e1 * math.cos(a) + e2 * math.sin(a)
				local tang = -e1 * math.sin(a) + e2 * math.cos(a)
				local pos = c + radial * R
				local len = 2 * R * math.sin(math.pi / n) * 1.06
				local lug = i % lugEvery == 0
				box(parent, V(if lug then depth * 1.5 else depth, if lug then tube * 1.6 else tube, len), CFrame.lookAt(pos, pos + tang, radial), if lug then BRASS else (if i % 2 == 0 then STONE else STEEL), if lug then M.Metal else M.Slate)
			end
		end
		local function spokes(parent: Instance, c: Vector3, ax: Vector3, R: number, count: number, t: number, hub: number)
			local e1, e2 = basis(ax)
			for k = 0, count - 1 do
				local a = k / count * math.pi * 2
				local radial = e1 * math.cos(a) + e2 * math.sin(a)
				bar(parent, c + radial * (hub * 0.5), c + radial * R, t, DARK, M.Metal)
			end
		end
		local function gear(parent: Instance, c: Vector3, ax: Vector3, R: number, teeth: number, toothH: number, depth: number)
			local e1, e2 = basis(ax)
			ring(parent, c, ax, R, 7, depth, 28, 7)
			for i = 0, teeth - 1 do
				local a = (i + 0.5) / teeth * math.pi * 2
				local radial = e1 * math.cos(a) + e2 * math.sin(a)
				local tang = -e1 * math.sin(a) + e2 * math.cos(a)
				local pos = c + radial * (R + toothH * 0.45)
				box(parent, V(depth * 0.9, toothH, 2 * R * math.pi / teeth * 0.5), CFrame.lookAt(pos, pos + tang, radial), if i % 2 == 0 then IVORY else STONE, M.Slate)
			end
			spokes(parent, c, ax, R - 2, 6, 6, 18)
			K.cylZ(parent, 22, depth * 1.8, CFrame.lookAt(c, c + ax), BRASS, M.Metal) -- hub
		end

		-- 1 FOUNDATION VAULT: stepped round vault with eight buttresses; open arches between them
		local s1 = K.stage(m, 1)
		local fnd = K.group(s1, "Frame")
		cyl(fnd, 196, 6, CFrame.new(0, 3, 0), DARK, M.Concrete)
		cyl(fnd, 164, 6, CFrame.new(0, 9, 0), STONE, M.Slate)
		cyl(fnd, 120, 6, CFrame.new(0, 15, 0), IVORY, M.Slate)
		cyl(fnd, 64, 14, CFrame.new(0, 25, 0), STEEL, M.Metal)
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2 + math.pi / 8
			local p = V(math.cos(a) * 80, 12, math.sin(a) * 80)
			box(fnd, V(22, 24, 12), CFrame.lookAt(p, V(0, 12, 0)), if k % 2 == 0 then IVORY else STONE, M.Slate)
		end

		-- 2 CENTRAL AXLE: a tall vertical axle with collars and four ribs (rotates slowly)
		local s2 = K.stage(m, 2)
		local ax = K.group(s2, "Axle")
		cyl(ax, 22, 200, CFrame.new(0, 114, 0), STEEL, M.Metal)
		for _, y in { 40, 82, 168, 206 } do
			cyl(ax, 32, 6, CFrame.new(0, y, 0), BRASS, M.Metal)
		end
		for k = 0, 3 do
			local a = k * math.pi / 2
			local dir = V(math.cos(a), 0, math.sin(a))
			box(ax, V(4, 4, 190), CFrame.lookAt(dir * 13 + V(0, 114, 0), dir * 13 + V(0, 115, 0), dir), DARK, M.Metal)
		end

		-- 3 OUTER FRAME: four tall corner pylons, top/mid beams, X braces; big open bays between
		local s3 = K.stage(m, 3)
		local fr = K.group(s3, "Frame")
		local px, pz = 96, 80
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(fr, V(22, 214, 22), CFrame.new(sx * px, 112, sz * pz), STONE, M.Slate)
				box(fr, V(30, 10, 30), CFrame.new(sx * px, 18, sz * pz), IVORY, M.Slate)
				wedge(fr, V(22, 18, 22), CFrame.new(sx * px, 228, sz * pz), IVORY, M.Slate)
			end
		end
		for _, sz in { -1, 1 } do
			box(fr, V(2 * px, 10, 10), CFrame.new(0, 222, sz * pz), STEEL, M.Metal)
			box(fr, V(2 * px, 8, 8), CFrame.new(0, 40, sz * pz), STEEL, M.Metal)
		end
		for _, sx in { -1, 1 } do
			box(fr, V(10, 10, 2 * pz), CFrame.new(sx * px, 222, 0), STEEL, M.Metal)
			box(fr, V(8, 8, 2 * pz), CFrame.new(sx * px, 40, 0), STEEL, M.Metal)
			bar(fr, V(sx * px, 46, -pz), V(sx * px, 216, pz), 5, DARK, M.Metal)
		end

		-- 4 GEAR I: a giant gear facing +/-Z, offset from the axle
		local s4 = K.stage(m, 4)
		local g1 = K.group(s4, "Gear1")
		local g1c = V(-34, 112, -56)
		gear(g1, g1c, V(0, 0, 1), 62, 22, 12, 12)
		K.marker(g1, "Gear1C", g1c)

		-- 5 GEAR II: a second giant gear on a perpendicular face
		local s5 = K.stage(m, 5)
		local g2 = K.group(s5, "Gear2")
		local g2c = V(62, 138, 20)
		gear(g2, g2c, V(1, 0, 0), 54, 20, 11, 12)
		K.marker(g2, "Gear2C", g2c)

		-- 6 VERTICAL RING: a big ring standing in the XY plane around the nest
		local s6 = K.stage(m, 6)
		local vr = K.group(s6, "VRing")
		ring(vr, C, V(0, 0, 1), 86, 10, 12, 44, 6)
		spokes(vr, C, V(0, 0, 1), 84, 4, 5, 30)
		K.marker(vr, "VRingC", C)

		-- 7 HORIZONTAL RING: a ring lying flat around the axle, nested inside the vertical ring
		local s7 = K.stage(m, 7)
		local hr = K.group(s7, "HRing")
		ring(hr, C, V(0, 1, 0), 70, 9, 11, 40, 5)
		spokes(hr, C, V(0, 1, 0), 68, 4, 5, 34)
		K.marker(hr, "HRingC", C)

		-- 8 INNER MECHANISM: a small armillary (two nested rings)
		local s8 = K.stage(m, 8)
		local inn = K.group(s8, "Inner")
		ring(inn, C, V(1, 0, 0), 46, 7, 9, 28, 7)
		ring(inn, C, V(0, 0, 1), 38, 6, 8, 24, 6)
		K.marker(inn, "InnerC", C)

		-- 9 LOWER CORE and 10 UPPER CORE: two halves with a glowing band between them
		local s9 = K.stage(m, 9)
		local cl = K.group(s9, "CoreLow")
		ell(cl, V(34, 34, 34), CFrame.new(C + V(0, -8, 0)), STEEL, M.Metal)
		cyl(cl, 40, 6, CFrame.new(C + V(0, -2, 0)), BRASS, M.Metal)
		K.marker(cl, "CoreC", C)
		local gl = K.group(s9, "CoreGlow")
		cyl(gl, 31, 4, CFrame.new(C), GLOW0, M.SmoothPlastic)
		local s10 = K.stage(m, 10)
		local cu = K.group(s10, "CoreUp")
		ell(cu, V(34, 34, 34), CFrame.new(C + V(0, 8, 0)), IVORY, M.Slate)
		cyl(cu, 40, 6, CFrame.new(C + V(0, 2, 0)), BRASS, M.Metal)

		-- 11 COUNTERWEIGHTS: four arms over the core, a heavy weight hanging from each (Alt 1/2 move in opposite pairs)
		local s11 = K.stage(m, 11)
		local arms = K.group(s11, "Arms")
		local wts = K.group(s11, "Weights")
		for k = 0, 3 do
			local a = k * math.pi / 2
			local dir = V(math.cos(a), 0, math.sin(a))
			local alt = if k % 2 == 0 then 1 else 2
			bar(arms, V(0, 190, 0) + dir * 12, V(0, 190, 0) + dir * 66, 9, STEEL, M.Metal)
			local top = V(0, 190, 0) + dir * 66
			local h = bar(wts, top + V(0, -30, 0), top + V(0, -2, 0), 4, DARK, M.Metal)
			h:SetAttribute("Alt", alt)
			local w = box(wts, V(26, 30, 26), CFrame.lookAt(top + V(0, -46, 0), top + V(0, -46, 0) + dir), STONE, M.Slate)
			w:SetAttribute("Alt", alt)
			local cap = box(wts, V(30, 6, 30), CFrame.lookAt(top + V(0, -29, 0), top + V(0, -29, 0) + dir), BRASS, M.Metal)
			cap:SetAttribute("Alt", alt)
		end

		-- 12 STAR METAL SYNCHRONIZERS: glowing conduits from the core to each ring and gear hub (Order = pulse sequence)
		local s12 = K.stage(m, 12)
		local sy = K.group(s12, "Sync")
		local function conduit(a: Vector3, b: Vector3, order: number)
			local p = bar(sy, a, b, 3.4, GLOW0, M.SmoothPlastic)
			p:SetAttribute("Order", order)
		end
		conduit(C + V(0, 0, 18), V(0, 125, 82), 1)
		conduit(C + V(0, 0, -18), V(0, 125, -82), 1)
		conduit(C + V(18, 0, 0), V(66, 125, 0), 2)
		conduit(C + V(-18, 0, 0), V(-66, 125, 0), 2)
		conduit(C + V(0, 16, 0), V(0, 184, 0), 3)
		conduit(C + V(0, -16, 0), V(0, 70, 0), 3)
		conduit(V(-34, 112, -56), V(-14, 120, -14), 4)
		conduit(V(62, 138, 20), V(18, 128, 6), 4)
		for _, p in { V(0, 125, 82), V(0, 125, -82), V(66, 125, 0), V(-66, 125, 0) } do
			local n = box(sy, V(9, 9, 9), CFrame.new(p), GLOW0, M.SmoothPlastic)
			n:SetAttribute("Order", 5)
		end

		-- 13 ENGINE CROWN: a brass crown on the axle top and a tall spire
		local s13 = K.stage(m, 13)
		local cr = K.group(s13, "Crown")
		cyl(cr, 56, 8, CFrame.new(0, 218, 0), BRASS, M.Metal)
		for k = 0, 7 do
			local a = k / 8 * math.pi * 2
			local dir = V(math.cos(a), 0, math.sin(a))
			wedge(cr, V(8, 22, 12), CFrame.lookAt(dir * 24 + V(0, 234, 0), dir * 24 + V(0, 234, 0) + dir, V(0, 1, 0)), IVORY, M.Slate)
		end
		bar(cr, V(0, 222, 0), V(0, 254, 0), 8, IVORY, M.Slate)
		ell(cr, V(14, 14, 14), CFrame.new(0, 258, 0), GLOW0, M.SmoothPlastic)
		return m
	end,
}
