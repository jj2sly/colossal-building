--!nonstrict
-- CONSTRUCTION CRANE (Common). A chunky yellow tower crane: a 53-stud lattice mast and a huge 60-stud jib, 76 tall.
-- The jib runs along +X (broadside to the spawn). Groups for the client show: Trolley, Hook (cable + block), LiftBeam (the
-- big I-beam lying under the jib), markers BeamGround / BeamTarget.
return {
	Id = "ConstructionCrane",
	Build = function(K)
		local V, M, RGB, box, bar, cyl = K.V, K.M, K.RGB, K.box, K.bar, K.cyl
		local YEL, YEL2, DARK = RGB(214, 162, 44), RGB(190, 138, 36), RGB(58, 62, 72)
		local CONC, CONC2 = RGB(138, 134, 126), RGB(110, 108, 104)
		local m = K.template("ConstructionCrane")

		-- 1 BASE: a concrete pad, a crossed steel foot, four ballast blocks, the beam frame the load will go into
		local s1 = K.stage(m, 1)
		box(s1, V(34, 3, 34), CFrame.new(0, 1.5, 0), CONC, M.Concrete)
		for _, a in { math.rad(45), math.rad(-45) } do
			box(s1, V(44, 3, 4), CFrame.new(0, 4.5, 0) * CFrame.Angles(0, a, 0), DARK, M.Metal)
		end
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(s1, V(8, 6, 8), CFrame.new(sx * 11, 6, sz * 11), CONC2, M.Concrete)
			end
		end
		box(s1, V(12, 2, 12), CFrame.new(0, 7, 0), DARK, M.Metal)
		-- the frame the beam is lifted into (two concrete piers with steel caps)
		for _, sz in { -11, 11 } do
			box(s1, V(5, 15, 5), CFrame.new(28, 7.5, sz), CONC, M.Concrete)
			box(s1, V(6, 1.4, 6), CFrame.new(28, 15.7, sz), DARK, M.Metal)
		end
		K.marker(s1, "BeamTarget", V(28, 21, 0)) -- where the beam's top flange ends up (resting on the pier caps)

		-- 2 TOWER MAST: corner chords, a dark core, bands and X-bracing on the faces (53 tall)
		local s2 = K.stage(m, 2)
		local Y0, Y1 = 8, 58
		box(s2, V(10, Y1 - Y0, 10), CFrame.new(0, (Y0 + Y1) / 2, 0), DARK, M.Metal)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(s2, V(3, Y1 - Y0, 3), CFrame.new(sx * 6, (Y0 + Y1) / 2, sz * 6), YEL, M.Metal)
			end
		end
		for k = 0, 5 do
			box(s2, V(14.4, 1.6, 14.4), CFrame.new(0, Y0 + 4 + k * 8, 0), YEL2, M.Metal)
		end
		for k = 0, 4 do
			local y = Y0 + 4 + k * 8
			for _, sz in { -6.2, 6.2 } do
				bar(s2, V(-6, y, sz), V(6, y + 8, sz), 1.4, YEL2, M.Metal)
			end
		end

		-- 3 MAIN JIB: slewing ring, a 60-stud triangular lattice jib along +X, the A-frame apex and its pendants
		local s3 = K.stage(m, 3)
		cyl(s3, 16, 3, CFrame.new(0, Y1 + 1.5, 0), DARK, M.Metal)
		box(s3, V(12, 3, 9), CFrame.new(0, Y1 + 4.5, 0), YEL, M.Metal)
		local JY, JT, X0, X1 = Y1 + 4, Y1 + 12, 4, 64
		for _, sz in { -3.4, 3.4 } do
			box(s3, V(X1 - X0, 2.6, 2.6), CFrame.new((X0 + X1) / 2, JY, sz), YEL, M.Metal)
		end
		box(s3, V(X1 - X0, 2.6, 2.6), CFrame.new((X0 + X1) / 2, JT, 0), YEL, M.Metal)
		for k = 0, 9 do
			local x = X0 + k * 6
			for _, sz in { -3.4, 3.4 } do
				bar(s3, V(x, JY, sz), V(x + 3, JT, 0), 1.3, YEL2, M.Metal)
				bar(s3, V(x + 3, JT, 0), V(x + 6, JY, sz), 1.3, YEL2, M.Metal)
			end
		end
		box(s3, V(2.4, 4, 9), CFrame.new(X1, JY + 1, 0), DARK, M.Metal)
		for _, sz in { -2.6, 2.6 } do
			bar(s3, V(-2.6, Y1 + 6, sz), V(0, Y1 + 18, 0), 1.6, YEL, M.Metal)
			bar(s3, V(2.6, Y1 + 6, sz), V(0, Y1 + 18, 0), 1.6, YEL, M.Metal)
		end
		bar(s3, V(0, Y1 + 18, 0), V(44, JT, 0), 0.6, DARK, M.Metal)

		-- 4 CAB + COUNTERWEIGHT + HOOK: counter-jib with concrete weights, the operator cab, trolley, hook and the load beam
		local s4 = K.stage(m, 4)
		for _, sz in { -3.4, 3.4 } do
			box(s4, V(24, 2.6, 2.6), CFrame.new(-14, JY, sz), YEL, M.Metal)
		end
		box(s4, V(24, 0.6, 9), CFrame.new(-14, JY + 1.6, 0), DARK, M.DiamondPlate)
		for k = 0, 2 do
			box(s4, V(4.4, 8, 7.6), CFrame.new(-20 - k * 4.6, JY - 3.4, 0), CONC2, M.Concrete)
		end
		bar(s4, V(0, Y1 + 18, 0), V(-25, JY + 1, 0), 0.6, DARK, M.Metal)
		box(s4, V(7, 7, 7), CFrame.new(1, Y1 + 1, -7.5), YEL, M.Metal)
		box(s4, V(6, 3.6, 0.4), CFrame.new(1, Y1 + 2, -11.1), RGB(120, 160, 184), M.Glass).Transparency = 0.2
		local trolley = K.group(s4, "Trolley")
		box(trolley, V(5, 2.6, 9), CFrame.new(46, JY - 2.6, 0), DARK, M.Metal).Name = "TrolleyBody"
		local hook = K.group(s4, "Hook")
		local HY = 30
		box(hook, V(0.5, JY - 3.9 - HY, 0.5), CFrame.new(46, (JY - 3.9 + HY) / 2, 0), RGB(36, 36, 42), M.SmoothPlastic, { Cable = true }).Name = "Cable"
		box(hook, V(3.6, 4.4, 3.6), CFrame.new(46, HY - 2.2, 0), YEL, M.Metal).Name = "HookBlock"
		box(hook, V(1.2, 3, 1.2), CFrame.new(46, HY - 5.4, 0), DARK, M.Metal)
		-- the load: a big steel I-beam lying across the jib line, waiting to be lifted onto the piers
		local beam = K.group(s4, "LiftBeam")
		box(beam, V(1.4, 3.4, 28), CFrame.new(46, 2.4, 0), RGB(150, 64, 48), M.Metal)
		for _, dy in { -1.9, 1.9 } do
			box(beam, V(4, 0.8, 28), CFrame.new(46, 2.4 + dy, 0), RGB(130, 56, 42), M.Metal)
		end
		K.marker(s4, "BeamGround", V(46, 4.7, 0)) -- the beam's top flange as it lies on the deck
		return m
	end,
}
