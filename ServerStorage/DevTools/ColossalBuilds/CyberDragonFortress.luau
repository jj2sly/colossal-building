--!nonstrict
-- CYBER DRAGON FORTRESS (Mythic). A colossal MECHANICAL dragon whose body IS the fortress, seen broadside from the spawn (-Z):
-- its long armoured hull rides on four angular bastion-towers that are its legs, with open air between the low curtain walls
-- and the hull. A segmented angular neck drives up and forward (+X) to a long wedge skull with a separate heavy jaw; two
-- enormous architectural wings of spars and separated angular panels rise up and back; a long segmented tail sweeps back and
-- curls round toward the spawn side; a few large violet energy plates run along the spine. Dark steel, one violet accent.
-- Nothing like the Dragon Citadel (red organic dragon perched on a square stone keep): here the creature is the building.
-- About 300 long x 225 tall x 140 deep.
-- Groups for the client show: Fortress (bastions/walls: static), Body (hull, chest, armour, spine; breathes), Neck (marker
-- NeckBase), Head (marker HeadPivot), Jaw (marker JawPivot), Mouth (marker), WingNear / WingFar (markers WingRootNear /
-- WingRootFar), Tail (marker TailRoot), Core, Eye, Spine (energy plates), FortGlow (bastion slits).
return {
	Id = "CyberDragonFortress",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, cylZ, ell, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.cylZ, K.ell, K.wedge
		local STEEL, GUN, SLATE, DARK = RGB(64, 68, 80), RGB(86, 92, 104), RGB(108, 112, 122), RGB(38, 40, 48)
		local TRIM, GLOW0 = RGB(140, 146, 158), RGB(58, 30, 82)
		local m = K.template("CyberDragonFortress")
		local AWAY = V(0, 0, -1)
		-- a box from a to b (length along a->b), w across, h "up" (roll keeps its Y roughly vertical)
		local function seg(parent: Instance, a: Vector3, b: Vector3, w: number, h: number, col: Color3, mat)
			return box(parent, V(w, h, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), col, mat)
		end
		-- a triangular plate through a, b, c (two wedges), shrunk toward its centroid so neighbouring panels keep visible gaps
		local function panel(parent: Instance, a: Vector3, b: Vector3, c: Vector3, th: number, col: Color3, mat, shrink: number?)
			local g = (a + b + c) / 3
			local k = shrink or 0.86
			a, b, c = g + (a - g) * k, g + (b - g) * k, g + (c - g) * k
			local ab, ac, bc = b - a, c - a, c - b
			local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
			if abd > acd and abd > bcd then
				c, a = a, c
			elseif acd > bcd and acd > abd then
				a, b = b, a
			end
			ab, ac, bc = b - a, c - a, c - b
			local right = ac:Cross(ab).Unit
			local up = bc:Cross(right).Unit
			local back = bc.Unit
			local h = math.abs(ab:Dot(up))
			wedge(parent, V(th, h, math.abs(ab:Dot(back))), CFrame.fromMatrix((a + b) / 2, right, up, back), col, mat)
			wedge(parent, V(th, h, math.abs(ac:Dot(back))), CFrame.fromMatrix((a + c) / 2, -right, up, -back), col, mat)
		end

		-- 1 FORTRESS FOUNDATION / LOWER BASTIONS: four angular bastion-towers (the dragon's legs) and low curtain walls between
		-- them, with gun-slit glows; the hull will float above the walls
		local s1 = K.stage(m, 1)
		local fort = K.group(s1, "Fortress")
		box(fort, V(150, 4, 76), CFrame.new(-4, 2, 0), DARK, M.DiamondPlate)
		local LEGS = { { 34, -24 }, { 34, 24 }, { -40, -24 }, { -40, 24 } }
		for _, l in LEGS do
			local p = V(l[1], 0, l[2])
			box(fort, V(24, 36, 24), CFrame.new(p + V(0, 22, 0)), STEEL, M.Metal)
			wedge(fort, V(24, 12, 14), CFrame.new(p + V(0, 46, -5)) * CFrame.Angles(0, math.rad(180), 0), GUN, M.Metal)
			wedge(fort, V(28, 10, 12), CFrame.new(p + V(if l[1] > 0 then 15 else -15, 9, 0)) * CFrame.Angles(0, math.rad(if l[1] > 0 then -90 else 90), 0), SLATE, M.Metal) -- splayed claw/buttress
			local gl = K.group(fort, "FortGlow")
			box(gl, V(3, 16, 1), CFrame.new(p + V(0, 24, l[2] > 0 and 12.4 or -12.4)), GLOW0, M.SmoothPlastic)
		end
		for _, sz in { -1, 1 } do
			box(fort, V(52, 18, 8), CFrame.new(-3, 13, sz * 26), GUN, M.Metal)
		end
		box(fort, V(8, 18, 40), CFrame.new(34, 13, 0), GUN, M.Metal)
		box(fort, V(8, 18, 40), CFrame.new(-40, 13, 0), GUN, M.Metal)

		-- 2 LOWER CYBER-DRAGON BODY: the long armoured hull (100 long) riding on the bastions, with an angular keel
		local s2 = K.stage(m, 2)
		local body = K.group(s2, "Body")
		box(body, V(120, 30, 46), CFrame.new(-8, 60, 0), STEEL, M.Metal)
		wedge(body, V(120, 10, 23), CFrame.new(-8, 40, -11.5) * CFrame.Angles(0, 0, math.rad(180)), GUN, M.Metal) -- keel chamfers
		wedge(body, V(120, 10, 23), CFrame.new(-8, 40, 11.5) * CFrame.Angles(0, math.rad(180), math.rad(180)), GUN, M.Metal)
		for _, sz in { -1, 1 } do
			wedge(body, V(120, 14, 16), CFrame.new(-8, 82, sz * 15) * CFrame.Angles(0, if sz < 0 then 0 else math.rad(180), 0), SLATE, M.Metal) -- sloped back plates
		end
		-- the bastions are the dragon's legs: heavy angled thigh struts from each bastion crown up into the hull
		for _, l in LEGS do
			bar(body, V(l[1], 40, l[2]), V(l[1] * 0.75, 52, l[2] * 0.55), 14, GUN, M.Metal)
		end

		-- 3 CHEST / CENTRAL CORE: a deep angular chest prow at the front with the big violet core on the spawn-side flank
		local s3 = K.stage(m, 3)
		local chest = K.group(s3, "Body")
		box(chest, V(34, 48, 48), CFrame.new(64, 66, 0), STEEL, M.Metal)
		wedge(chest, V(48, 48, 20), CFrame.new(91, 66, 0) * CFrame.Angles(0, math.rad(-90), 0), GUN, M.Metal)
		box(chest, V(36, 10, 50), CFrame.new(62, 94, 0), SLATE, M.Metal)
		local core = K.group(chest, "Core")
		cylZ(core, 24, 3, CFrame.new(62, 64, -24.6), GLOW0, M.SmoothPlastic)
		cylZ(chest, 32, 2, CFrame.new(62, 64, -24.2), DARK, M.Metal)

		-- 4 NECK: four angular segments driving up and forward, each with a dorsal fin plate
		local s4 = K.stage(m, 4)
		local neck = K.group(s4, "Neck")
		local NP = { V(70, 86, 0), V(86, 112, 0), V(100, 136, 0), V(110, 158, 0), V(116, 174, 0) }
		for i = 1, #NP - 1 do
			local w = 26 - i * 3
			seg(neck, NP[i], NP[i + 1], w, w * 0.9, if i % 2 == 0 then GUN else STEEL, M.Metal)
			local mid = (NP[i] + NP[i + 1]) / 2
			local dir = (NP[i + 1] - NP[i]).Unit
			local back = V(-dir.Y, dir.X, 0) -- the neck's upper/back side
			wedge(neck, V(3, 10, 14), CFrame.lookAt(mid + back * (w * 0.5 + 4), mid + back * (w * 0.5 + 4) - dir), SLATE, M.Metal)
		end
		K.marker(neck, "NeckBase", NP[1])

		-- 5 HEAD: a long angular wedge skull pointing forward and a little down, a separate heavy jaw with a gap, swept horn fins
		-- and violet eye slits on the spawn side
		local s5 = K.stage(m, 5)
		local head = K.group(s5, "Head")
		local H0 = NP[#NP]
		local hd = V(1, -0.2, 0).Unit
		local tip = H0 + hd * 54
		seg(head, H0 - hd * 4, tip, 22, 17, STEEL, M.Metal)
		wedge(head, V(22, 12, 24), CFrame.lookAt(tip + hd * 4 + V(0, 2, 0), tip + hd * 4 + V(0, 2, 0) - hd), GUN, M.Metal) -- snout
		seg(head, H0 + V(0, 10, 0), H0 + hd * 30 + V(0, 10, 0), 24, 9, GUN, M.Metal) -- brow plate
		for _, sz in { -1, 1 } do
			bar(head, H0 + V(-2, 12, sz * 8), H0 + V(-34, 32, sz * 16), 5, SLATE, M.Metal)
			bar(head, H0 + V(8, 10, sz * 9), H0 + V(-20, 36, sz * 20), 3.5, SLATE, M.Metal)
		end
		local eye = K.group(head, "Eye")
		box(eye, V(16, 2.8, 1), CFrame.lookAt(H0 + hd * 22 + V(0, 4, -11.4), H0 + hd * 23 + V(0, 4, -11.4)), GLOW0, M.SmoothPlastic)
		K.marker(head, "HeadPivot", H0)
		local jaw = K.group(s5, "Jaw")
		local J0 = H0 + V(2, -11, 0)
		seg(jaw, J0, J0 + V(1, -0.42, 0).Unit * 46, 18, 7, DARK, M.Metal)
		K.marker(jaw, "JawPivot", J0)
		K.marker(head, "Mouth", tip + V(4, -6, 0), hd)

		-- 6 / 7 WINGS: two huge architectural wings rising up and back from the shoulders: a main spar to the elbow, a second spar
		-- to the tip, three finger spars, and angular panels between them that keep clear gaps (the far wing rises higher)
		local function wingPoints(sz: number, far: boolean)
			local root = V(18, 84, sz * 18)
			if far then -- the far wing rises almost straight up behind the neck
				return root, V(14, 170, sz * 40), V(-24, 236, sz * 56), V(-70, 196, sz * 52), V(-80, 144, sz * 44), V(-50, 104, sz * 34)
			end
			-- the near wing sweeps back and out over the tail
			return root, V(-28, 146, sz * 40), V(-112, 190, sz * 56), V(-140, 132, sz * 52), V(-124, 94, sz * 44), V(-84, 82, sz * 34)
		end
		for i, spec in { { -1, false, "WingNear" }, { 1, true, "WingFar" } } do
			local s = K.stage(m, 5 + i)
			local wing = K.group(s, spec[3])
			local root, elbow, wtip, f1, f2, f3 = wingPoints(spec[1], spec[2])
			bar(wing, root, elbow, 9, STEEL, M.Metal)
			bar(wing, elbow, wtip, 7, STEEL, M.Metal)
			for _, f in { f1, f2, f3 } do
				bar(wing, elbow, f, 4.5, GUN, M.Metal)
			end
			local col = if spec[2] then SLATE else GUN
			panel(wing, elbow, wtip, f1, 2, col, M.Metal)
			panel(wing, elbow, f1, f2, 2, col, M.Metal)
			panel(wing, elbow, f2, f3, 2, col, M.Metal)
			panel(wing, elbow, f3, root + V(-14, 0, 0), 2, col, M.Metal)
			ell(wing, V(14, 14, 14), CFrame.new(elbow), DARK, M.Metal)
			K.marker(wing, "WingRoot" .. (if spec[2] then "Far" else "Near"), root)
		end

		-- 8 TAIL: a long segmented mechanical tail from the hull's rear sweeping back and curling round toward the spawn side,
		-- ending in a blade
		local s8 = K.stage(m, 8)
		local tail = K.group(s8, "Tail")
		local TP = { V(-66, 58, 0), V(-92, 50, 4), V(-112, 44, 14), V(-124, 40, 32), V(-120, 38, 52), V(-106, 37, 66) }
		for i = 1, #TP - 1 do
			local w = 18 - i * 2.4
			seg(tail, TP[i], TP[i + 1], w, w * 0.85, if i % 2 == 0 then GUN else STEEL, M.Metal)
		end
		local tb = TP[#TP]
		local td = (TP[#TP] - TP[#TP - 1]).Unit
		wedge(tail, V(4, 18, 20), CFrame.lookAt(tb + td * 8, tb + td * 9), SLATE, M.Metal)
		K.marker(tail, "TailRoot", TP[1])

		-- 9 ENERGY SPINE: a few large angular energy plates along the back and neck base (violet cores in dark housings)
		local s9 = K.stage(m, 9)
		local spineBody = K.group(s9, "Body")
		for i, sp in { { -48, 89, 20 }, { -22, 90, 26 }, { 4, 90, 26 }, { 30, 89, 20 } } do
			local base = V(sp[1], sp[2], 0)
			wedge(spineBody, V(6, sp[3], 18), CFrame.new(base + V(0, sp[3] / 2, 0)) * CFrame.Angles(0, math.rad(-90), 0), DARK, M.Metal)
			local g = K.group(spineBody, "Spine")
			local p = box(g, V(2, sp[3] * 0.7, 10), CFrame.new(base + V(1, sp[3] * 0.35, 0)), GLOW0, M.SmoothPlastic)
			p:SetAttribute("Order", i)
		end

		-- 10 UPPER FORTRESS / FINAL ARMOUR: heavy shoulder armour over the wing roots, flank armour plates, bastion crowns and a
		-- battle-turret on the hull's back between the wings
		local s10 = K.stage(m, 10)
		local armour = K.group(s10, "Body")
		for _, sz in { -1, 1 } do
			box(armour, V(32, 18, 16), CFrame.new(18, 88, sz * 26), SLATE, M.Metal)
			box(armour, V(70, 16, 4), CFrame.new(-10, 58, sz * 24.6), GUN, M.Metal)
		end
		box(armour, V(22, 12, 20), CFrame.new(-60, 86, 0), STEEL, M.Metal)
		cylZ(armour, 6, 28, CFrame.new(-50, 90, 0) * CFrame.Angles(0, math.rad(90), 0), DARK, M.Metal)
		local fort10 = K.group(s10, "Fortress")
		for _, l in LEGS do
			for _, dx in { -8, 8 } do
				box(fort10, V(6, 6, 24), CFrame.new(l[1] + dx, 43, l[2]), GUN, M.Metal)
			end
		end
		return m
	end,
}
