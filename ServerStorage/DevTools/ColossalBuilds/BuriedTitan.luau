--!nonstrict
-- FORGOTTEN F3 (server-only template, id "Fg9e"): an ancient colossal construct being EXCAVATED from beneath the site. Only the
-- upper body emerges: a huge buried hand clawing out at front-left, a second arm rising at the right, uneven shoulders, a leaning
-- chest with a hollow cavity, a late-rising head. Everything is asymmetric; the lower body stays buried (the ground ring hides it).
-- Ivory / aged stone / dark metal with restrained brass; cold glow only in the chest core, its conduits and the eyes.
-- Groups: Dig (static pit ring), Hand, Arm2, Shoulders, Torso, Chest, Neck, Head, Eyes, Crown, CoreGlow (Order 1..6), Back, Gantry.
-- Markers: HandC (wrist), HeadC (neck top, head pivot), CoreC (chest core).
return {
	Id = "Fg9e",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, ell, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.ell, K.wedge
		local IVORY, STONE, DARK, STEEL, BRASS, EARTH = RGB(206, 198, 176), RGB(150, 144, 132), RGB(76, 74, 72), RGB(92, 100, 108), RGB(170, 134, 70), RGB(112, 94, 74)
		local GLOW0 = RGB(52, 78, 96)
		local m = K.template("Fg9e")
		local A = CFrame.Angles
		local r = math.rad

		-- 1 EXCAVATION RING: an irregular broken-earth ring around a dark pit, slabs leaning outward, rubble heaps
		local s1 = K.stage(m, 1)
		local dig = K.group(s1, "Dig")
		cyl(dig, 170, 4, CFrame.new(0, 2, 0), DARK, M.Concrete)
		cyl(dig, 214, 3, CFrame.new(0, 1, 0), EARTH, M.Ground)
		for i = 0, 15 do
			local a = i / 16 * math.pi * 2
			local rr = 1 + 0.12 * math.sin(i * 2.3)
			local p = V(math.cos(a) * 98 * rr, 6, math.sin(a) * 84 * rr)
			local look = CFrame.lookAt(p, V(0, 6, 0))
			local h = 10 + (i % 3) * 5
			box(dig, V(28 + (i % 2) * 8, h, 17), look * A(r(-24), 0, r((i % 3) * 4 - 4)) * CFrame.new(0, h / 2 - 5, 0), if i % 2 == 0 then STONE else EARTH, if i % 2 == 0 then M.Slate else M.Ground)
		end
		for _, q in { V(-70, 10, 70), V(80, 9, -62), V(-96, 8, -30), V(40, 8, 90) } do
			ell(dig, V(26, 18, 22), CFrame.new(q) * A(0, r(q.X), 0), RGB(130, 118, 100), M.Slate)
		end

		-- the earth that swallows the lower body: a front shelf, a leaning stone slab, a buried shoulder slab, side and back masses
		box(dig, V(150, 62, 46), CFrame.new(6, 26, -46) * A(r(-4), r(5), r(3)), EARTH, M.Ground)
		box(dig, V(112, 62, 14), CFrame.new(22, 52, -66) * A(r(-30), r(-6), r(5)), STONE, M.Slate)
		box(dig, V(64, 74, 30), CFrame.new(-74, 52, 36) * A(r(-8), r(18), r(-16)), STONE, M.Slate)
		wedge(dig, V(86, 50, 58), CFrame.new(70, 25, 4) * A(0, r(90), 0), EARTH, M.Ground)
		box(dig, V(56, 40, 34), CFrame.new(124, 52, 50) * A(r(8), r(-14), r(10)), EARTH, M.Ground) -- covers the second arm's elbow
		ell(dig, V(40, 30, 36), CFrame.new(118, 100, 54), RGB(130, 118, 100), M.Slate) -- and its wrist
		ell(dig, V(60, 36, 46), CFrame.new(-6, 38, 78), RGB(130, 118, 100), M.Slate)
		box(dig, V(76, 20, 28), CFrame.new(-62, 14, -24) * A(r(6), r(8), r(-5)), EARTH, M.Ground) -- mound over the wrist
		box(dig, V(34, 28, 14), CFrame.new(-90, 30, -30) * A(r(-30), r(20), r(26)), STONE, M.Slate)
		box(dig, V(30, 24, 14), CFrame.new(-36, 26, -34) * A(r(-26), r(-16), r(-22)), STONE, M.Slate)

		-- 2 BURIED HAND: forearm rising from the ground at front-left, an upright palm and curling fingers (the strongest anchor)
		local s2 = K.stage(m, 2)
		local hand = K.group(s2, "Hand")
		K.marker(hand, "HandC", V(-62, 40, -40))
		box(hand, V(44, 44, 130), CFrame.new(-62, 8, 10) * A(r(-26), 0, r(6)), STONE, M.Slate) -- forearm, running down into the ground
		box(hand, V(48, 6, 46), CFrame.new(-62, 33, -30) * A(r(-30), 0, 0), BRASS, M.Metal) -- wrist band (half buried)
		box(hand, V(56, 50, 20), CFrame.new(-62, 60, -42) * A(r(-30), 0, r(9)), IVORY, M.Slate) -- palm, tipped back toward the ground
		for i = 1, 4 do
			local x = -62 + (i - 2.5) * 13.5
			local len = ({ 34, 42, 40, 32 })[i]
			box(hand, V(11, len, 12), CFrame.new(x, 100 + len * 0.1, -52) * A(r(-20), 0, r((i - 2.5) * 9)), IVORY, M.Slate)
			box(hand, V(10, 22, 11), CFrame.new(x, 118 + len * 0.3, -62 - i * 1.5) * A(r(-52), 0, 0), STONE, M.Slate) -- curled tip
			box(hand, V(12.5, 4, 13), CFrame.new(x, 90, -49), BRASS, M.Metal) -- knuckle cap
		end
		box(hand, V(14, 36, 13), CFrame.new(-96, 70, -48) * A(r(-8), 0, r(34)), IVORY, M.Slate) -- thumb

		-- 3 SECOND ARM: another arm rising at the right, bent at the elbow, fist raised
		local s3 = K.stage(m, 3)
		local arm = K.group(s3, "Arm2")
		bar(arm, V(84, 10, 44), V(120, 62, 34), 36, STONE, M.Slate)
		ell(arm, V(44, 40, 44), CFrame.new(122, 66, 32), STEEL, M.Metal)
		bar(arm, V(122, 66, 32), V(132, 112, 70), 28, IVORY, M.Slate) -- forearm angled outward and back
		box(arm, V(34, 28, 32), CFrame.new(134, 122, 76) * A(r(-20), r(30), r(14)), STONE, M.Slate) -- hand, open and slumped, not raised
		box(arm, V(36, 5, 36), CFrame.new(100, 36, 38) * A(0, 0, r(-22)), BRASS, M.Metal)

		-- 4 SHOULDERS: two uneven shoulder masses, the right higher and further back
		local s4 = K.stage(m, 4)
		local sh = K.group(s4, "Shoulders")
		box(sh, V(68, 38, 56), CFrame.new(-46, 116, 20) * A(0, r(10), r(14)), STONE, M.Slate)
		box(sh, V(72, 42, 60), CFrame.new(62, 130, 32) * A(0, r(-8), r(-12)), IVORY, M.Slate)
		wedge(sh, V(40, 14, 40), CFrame.new(-50, 140, 14) * A(0, r(180), 0), DARK, M.Slate)
		box(sh, V(42, 5, 44), CFrame.new(66, 152, 32) * A(0, r(-8), r(-12)), BRASS, M.Metal)

		-- 5 UPPER TORSO: a leaning chest slab with a stepped back and chest plates
		local s5 = K.stage(m, 5)
		local tor = K.group(s5, "Torso")
		box(tor, V(100, 80, 68), CFrame.new(8, 88, 24) * A(r(-9), r(-5), r(2)), IVORY, M.Slate)
		box(tor, V(86, 36, 60), CFrame.new(6, 52, 30), STONE, M.Slate)
		wedge(tor, V(96, 24, 34), CFrame.new(8, 138, 4) * A(r(-9), r(180), 0), STONE, M.Slate)
		box(tor, V(24, 70, 14), CFrame.new(-34, 88, -14) * A(r(-9), 0, 0), DARK, M.Metal)
		box(tor, V(24, 70, 14), CFrame.new(48, 88, -12) * A(r(-9), 0, 0), DARK, M.Metal)

		-- 6 CHEST CAVITY: a recessed dark cavity with brass ribs and a hollow socket for the core
		local s6 = K.stage(m, 6)
		local ch = K.group(s6, "Chest")
		box(ch, V(46, 46, 12), CFrame.new(8, 98, -14) * A(r(-9), 0, 0), RGB(28, 28, 32), M.Slate)
		for k = -1, 1 do
			box(ch, V(50, 3.5, 5), CFrame.new(8, 98 + k * 14, -18) * A(r(-9), 0, 0), BRASS, M.Metal)
		end
		box(ch, V(4, 54, 5), CFrame.new(-18, 98, -18) * A(r(-9), 0, 0), BRASS, M.Metal)
		box(ch, V(4, 54, 5), CFrame.new(34, 98, -18) * A(r(-9), 0, 0), BRASS, M.Metal)
		K.marker(ch, "CoreC", V(8, 98, -12))

		-- 7 NECK: a heavy neck column with collar rings
		local s7 = K.stage(m, 7)
		local nk = K.group(s7, "Neck")
		cyl(nk, 34, 38, CFrame.new(6, 160, 24), STEEL, M.Metal)
		for _, y in { 146, 162, 176 } do
			cyl(nk, 44, 5, CFrame.new(6, y, 24), if y == 162 then BRASS else DARK, M.Metal)
		end
		K.marker(nk, "HeadC", V(6, 176, 24))

		-- 8 HEAD: an ancient heavy head, brow ridge, jaw, dark eye sockets (the eyes stay dormant until late)
		local s8 = K.stage(m, 8)
		local hd = K.group(s8, "Head")
		box(hd, V(54, 56, 58), CFrame.new(6, 204, 22) * A(r(6), 0, r(-3)), IVORY, M.Slate)
		box(hd, V(60, 11, 16), CFrame.new(6, 224, -4) * A(r(6), 0, r(-3)), STONE, M.Slate)
		wedge(hd, V(46, 18, 28), CFrame.new(6, 180, -2) * A(r(6), r(180), 0), STONE, M.Slate)
		box(hd, V(12, 12, 8), CFrame.new(-12, 212, -8) * A(r(6), 0, r(-3)), RGB(24, 24, 28), M.Slate)
		box(hd, V(12, 12, 8), CFrame.new(24, 211, -8) * A(r(6), 0, r(-3)), RGB(24, 24, 28), M.Slate)
		local ey = K.group(s8, "Eyes")
		box(ey, V(8, 5, 3), CFrame.new(-12, 212, -11.5) * A(r(6), 0, r(-3)), GLOW0, M.SmoothPlastic)
		box(ey, V(8, 5, 3), CFrame.new(24, 211, -11.5) * A(r(6), 0, r(-3)), GLOW0, M.SmoothPlastic)

		-- 9 CROWN / HELMET: a heavy crest, brass band, side fins and back spikes
		local s9 = K.stage(m, 9)
		local cr = K.group(s9, "Crown")
		box(cr, V(62, 7, 64), CFrame.new(6, 232, 22) * A(r(6), 0, r(-3)), BRASS, M.Metal)
		box(cr, V(14, 30, 70), CFrame.new(6, 246, 22) * A(r(6), 0, r(-3)), STONE, M.Slate)
		for _, sx in { -1, 1 } do
			wedge(cr, V(10, 30, 36), CFrame.new(6 + sx * 36, 222, 22) * A(0, sx > 0 and 0 or r(180), 0), IVORY, M.Slate)
		end
		for i = 0, 2 do
			wedge(cr, V(10, 24, 14), CFrame.new(6, 238 - i * 2, 54 + i * 8) * A(0, r(90), 0), DARK, M.Slate)
		end

		-- 10 STAR METAL CORE: the glowing core in the cavity and conduits up the neck to the eyes (Order = pulse sequence)
		local s10 = K.stage(m, 10)
		local cg = K.group(s10, "CoreGlow")
		ell(cg, V(26, 26, 26), CFrame.new(8, 98, -12), GLOW0, M.SmoothPlastic):SetAttribute("Order", 1)
		local function conduit(a, b, o)
			bar(cg, a, b, 3.6, GLOW0, M.SmoothPlastic):SetAttribute("Order", o)
		end
		conduit(V(8, 112, -14), V(8, 140, -10), 2)
		conduit(V(8, 140, -10), V(6, 178, 4), 3)
		conduit(V(6, 178, 4), V(6, 208, -2), 4)
		conduit(V(6, 208, -9), V(-12, 212, -12), 5)
		conduit(V(6, 208, -9), V(24, 211, -12), 5)
		conduit(V(8, 86, -14), V(-24, 70, -14), 2)

		-- 11 BACK STRUCTURES: tall rear slabs, buttress fins and pipe runs behind the torso
		local s11 = K.stage(m, 11)
		local bk = K.group(s11, "Back")
		box(bk, V(74, 118, 16), CFrame.new(-10, 118, 72) * A(r(8), r(-8), r(4)), STONE, M.Slate)
		box(bk, V(40, 90, 14), CFrame.new(56, 104, 78) * A(r(6), r(10), r(-6)), DARK, M.Slate)
		for _, x in { -34, 6, 44 } do
			cyl(bk, 9, 96, CFrame.new(x, 76, 56), STEEL, M.Metal)
		end
		wedge(bk, V(18, 70, 44), CFrame.new(-52, 60, 56) * A(0, r(180), 0), IVORY, M.Slate)

		-- 12 FINAL EXCAVATION: steel gantries over the pit, a crane arm over the hand, rubble
		local s12 = K.stage(m, 12)
		local gt = K.group(s12, "Gantry")
		local function gantry(x, z, h, w)
			for _, sx in { -1, 1 } do
				box(gt, V(5, h, 5), CFrame.new(x + sx * w / 2, h / 2 + 2, z), STEEL, M.Metal)
			end
			box(gt, V(w + 6, 5, 6), CFrame.new(x, h + 3, z), DARK, M.Metal)
			bar(gt, V(x - w / 2, 4, z), V(x, h, z), 3, DARK, M.Metal)
		end
		gantry(-112, -6, 92, 26)
		gantry(98, -66, 74, 22)
		gantry(24, 98, 84, 30)
		bar(gt, V(-110, 90, -10), V(-70, 126, -46), 6, STEEL, M.Metal)
		box(gt, V(8, 14, 8), CFrame.new(-70, 118, -46), BRASS, M.Metal)
		for _, q in { V(-24, 6, -92), V(58, 5, 66), V(-86, 5, 52) } do
			ell(gt, V(20, 12, 18), CFrame.new(q), RGB(130, 118, 100), M.Slate)
		end
		-- BURIED POSE: the whole upper body is sunk and tipped off-axis (trapped, not posed): rolled to one side and pitched
		-- forward, so the chest is never vertical or centred and the lower torso vanishes into the pit masses above
		local pivot = V(8, 60, 24)
		local U = CFrame.new(0, -26, 0) * CFrame.new(pivot) * A(r(-9), r(-7), r(12)) * CFrame.new(-pivot)
		for _, g in m:GetDescendants() do
			if g:IsA("Model") and (g.Name == "Shoulders" or g.Name == "Torso" or g.Name == "Chest" or g.Name == "Neck" or g.Name == "Head" or g.Name == "Eyes" or g.Name == "Crown" or g.Name == "CoreGlow") then
				for _, p in g:GetDescendants() do
					if p:IsA("BasePart") then
						p.CFrame = U * p.CFrame
					end
				end
			end
		end
		return m
	end,
}
