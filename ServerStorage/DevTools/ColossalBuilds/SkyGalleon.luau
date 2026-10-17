--!nonstrict
-- SKY GALLEON (Epic). A long, deep fantasy airship (hull ~150 long, bow toward +X) seen broadside from the spawn (-Z), held up
-- by three huge lift envelopes on a rigid frame with a clear air gap between deck and envelopes (~deck y 52, envelopes from
-- y 85). It rests on a dock cradle (its own air gap under the keel) and carries a stern propeller, two side engine nacelles,
-- stern fins, side fins and a bridge with an observation dome. About 200 long (envelopes) x 133 tall x 86 wide (with fins).
-- Groups for the client show: Ground (dock cradle: never moves), Lift (envelopes), LiftCore (glow under each envelope),
-- Prop (each propeller, marker PropC; spins about the template X axis), Exhaust (engine glows). Everything else is the craft.
return {
	Id = "SkyGalleon",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, cylZ, ell, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.cylZ, K.ell, K.wedge
		local HULL, HULL2, DECK, GOLD = RGB(116, 72, 44), RGB(144, 92, 54), RGB(178, 140, 96), RGB(212, 168, 64)
		local CANVAS, CANVAS2, IRON, BRASS = RGB(228, 214, 184), RGB(206, 190, 158), RGB(64, 64, 70), RGB(186, 140, 64)
		local CORE, GLASS, RED = RGB(40, 82, 92), RGB(120, 170, 200), RGB(168, 44, 40)
		local m = K.template("SkyGalleon")
		local rot = CFrame.Angles
		local ALONG = rot(0, math.rad(90), 0) -- cylZ along the template X axis

		-- 1 KEEL / LOWER HULL: the dock cradle (three trestles on rails) and the deep rounded lower hull with its keel
		local s1 = K.stage(m, 1)
		local ground = K.group(s1, "Ground")
		for _, sz in { -1, 1 } do
			box(ground, V(124, 3, 6), CFrame.new(0, 1.5, sz * 12), IRON, M.Metal)
		end
		for _, x in { -48, 0, 48 } do
			box(ground, V(8, 18, 30), CFrame.new(x, 10, 0), IRON, M.Metal)
		end
		ell(s1, V(152, 30, 36), CFrame.new(0, 34, 0), HULL, M.WoodPlanks)
		box(s1, V(124, 4, 5), CFrame.new(0, 20.5, 0), IRON, M.Metal)

		-- 2 UPPER HULL: hull sides with a gold band, the deck, a raised sterncastle and a rising bow deck
		local s2 = K.stage(m, 2)
		box(s2, V(132, 10, 36), CFrame.new(0, 46, 0), HULL2, M.WoodPlanks)
		box(s2, V(134, 2, 36.6), CFrame.new(0, 44, 0), GOLD, M.Metal)
		box(s2, V(128, 2, 32), CFrame.new(0, 51.5, 0), DECK, M.WoodPlanks)
		box(s2, V(26, 14, 34), CFrame.new(-58, 58, 0), HULL2, M.WoodPlanks)
		box(s2, V(30, 2, 37), CFrame.new(-58, 66, 0), HULL, M.WoodPlanks)
		wedge(s2, V(32, 8, 22), CFrame.new(58, 55, 0) * rot(0, math.rad(90), 0), HULL2, M.WoodPlanks)

		-- 3 MAST / SUPPORT FRAME: two masts, a long girder under the envelopes, A-frame struts and three cross beams
		local s3 = K.stage(m, 3)
		for _, x in { -32, 32 } do
			cyl(s3, 4, 36, CFrame.new(x, 69, 0), HULL, M.Wood)
		end
		box(s3, V(150, 4, 4), CFrame.new(0, 86, 0), IRON, M.Metal)
		for _, x in { -56, 56 } do
			for _, sz in { -1, 1 } do
				bar(s3, V(x, 52, sz * 16), V(x * 0.8, 86, 0), 3, IRON, M.Metal)
			end
		end
		for _, x in { -60, 0, 60 } do
			box(s3, V(4, 3, 40), CFrame.new(x, 84, 0), IRON, M.Metal)
		end

		-- 4 LIFT STRUCTURES: one huge central envelope (92 x 46 x 52) and two big end pods (60 x 34 x 38) with brass bands, and a lift core
		-- under each (they glow when the lift wakes)
		local s4 = K.stage(m, 4)
		local lift = K.group(s4, "Lift")
		ell(lift, V(92, 46, 52), CFrame.new(0, 110, 0), CANVAS, M.Fabric)
		for _, sx in { -1, 1 } do
			ell(lift, V(60, 34, 38), CFrame.new(sx * 70, 102, 0), CANVAS2, M.Fabric)
			cylZ(lift, 46, 3, CFrame.new(sx * 22, 110, 0) * ALONG, BRASS, M.Metal)
			cylZ(lift, 36, 3, CFrame.new(sx * 70, 102, 0) * ALONG, BRASS, M.Metal)
		end
		for _, x in { -70, 0, 70 } do
			local c = K.group(s4, "LiftCore")
			ell(c, V(12, 5, 12), CFrame.new(x, if x == 0 then 87.5 else 85.5, 0), CORE, M.SmoothPlastic)
		end

		-- 5 SAILS / FINS: two broad side fins, stern fin and stabiliser, two small mast sails facing broadside
		local s5 = K.stage(m, 5)
		for _, sz in { -1, 1 } do
			box(s5, V(34, 1.6, 26), CFrame.new(10, 47, sz * 30) * rot(sz * math.rad(14), 0, 0), CANVAS2, M.Fabric)
		end
		box(s5, V(22, 24, 2), CFrame.new(-70, 79, 0), CANVAS2, M.Fabric)
		box(s5, V(18, 2, 34), CFrame.new(-74, 63, 0), HULL, M.Wood)
		for _, x in { -32, 32 } do
			box(s5, V(22, 14, 0.8), CFrame.new(x, 72, -2.6), CANVAS, M.Fabric)
			box(s5, V(22, 3, 0.9), CFrame.new(x, 72, -2.7), RED, M.Fabric)
		end

		-- 6 PROPULSION: a big stern propeller and two side engine nacelles on pylons, each with a front propeller and a glow
		local s6 = K.stage(m, 6)
		cylZ(s6, 9, 12, CFrame.new(-80, 44, 0) * ALONG, IRON, M.Metal)
		local p1 = K.group(s6, "Prop")
		box(p1, V(1.6, 30, 5), CFrame.new(-87, 44, 0), BRASS, M.Metal)
		box(p1, V(1.6, 5, 30), CFrame.new(-87, 44, 0), BRASS, M.Metal)
		K.marker(p1, "PropC", V(-87, 44, 0))
		for _, sz in { -1, 1 } do
			box(s6, V(10, 3, 12), CFrame.new(-14, 57, sz * 24), IRON, M.Metal)
			cylZ(s6, 11, 28, CFrame.new(-14, 60, sz * 31) * ALONG, BRASS, M.Metal)
			local pr = K.group(s6, "Prop")
			box(pr, V(1.4, 22, 4), CFrame.new(1, 60, sz * 31), IRON, M.Metal)
			box(pr, V(1.4, 4, 22), CFrame.new(1, 60, sz * 31), IRON, M.Metal)
			K.marker(pr, "PropC", V(1, 60, sz * 31))
			local ex = K.group(s6, "Exhaust")
			cylZ(ex, 7, 1, CFrame.new(-28.6, 60, sz * 31) * ALONG, CORE, M.SmoothPlastic)
		end

		-- 7 COMMAND STRUCTURE: a bridge house with a window band, an observation dome, a bowsprit with a gold figurehead
		-- and a command pennant
		local s7 = K.stage(m, 7)
		box(s7, V(22, 12, 20), CFrame.new(40, 58.5, 0), HULL2, M.WoodPlanks)
		box(s7, V(22.4, 3, 20.4), CFrame.new(40, 60.5, 0), GLASS, M.Glass)
		box(s7, V(26, 2, 24), CFrame.new(40, 65.5, 0), HULL, M.WoodPlanks)
		local dome = ell(s7, V(14, 10, 14), CFrame.new(40, 67, 0), GLASS, M.Glass)
		dome.Transparency = 0.35
		bar(s7, V(70, 52, 0), V(96, 62, 0), 3, HULL, M.Wood)
		ell(s7, V(9, 11, 7), CFrame.new(76, 50, 0), GOLD, M.Metal)
		cyl(s7, 1.5, 14, CFrame.new(40, 79, 0), IRON, M.Metal)
		box(s7, V(9, 5, 0.4), CFrame.new(44.5, 83.5, 0), RED, M.Fabric)
		return m
	end,
}
