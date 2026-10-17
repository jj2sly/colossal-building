--!nonstrict
-- GIANT LINKED SWORD (Rare). The classic blocky Roblox sword, enormous: a straight 18-wide silver blade (78 tall, with a diamond tip
-- driven into the stone) rising from a stone pedestal, a dramatically wide gold crossguard (76 across, wing tips swept up), a thick dark
-- grip with gold bands and a gold pommel. About 132 tall. Seen flat-on from the spawn (front faces -Z).
-- Group for the client show: Sword (blade, guard, grip, pommel across stages 2-5); markers SwordBase (rotation centre, at the stone),
-- SlashC (the centre of the blade, where the slash pulse is drawn).
return {
	Id = "GiantLinkedSword",
	Build = function(K)
		local V, M, RGB, box, cyl, ell = K.V, K.M, K.RGB, K.box, K.cyl, K.ell
		local function wedgeP(parent, size, cf, color)
			return K.wedge(parent, size, cf, color, Enum.Material.Metal)
		end
		local ST1, ST2, ST3 = RGB(124, 120, 114), RGB(150, 146, 138), RGB(98, 94, 90)
		local BLADE, BLADE2, GOLD, GOLD2, GRIP, GEM = RGB(206, 212, 222), RGB(240, 244, 250), RGB(226, 178, 58), RGB(180, 132, 40), RGB(76, 50, 34), RGB(70, 150, 230)
		local m = K.template("GiantLinkedSword")
		local rot = CFrame.Angles

		-- 1 STONE PEDESTAL: a stepped, chunky stone mound (16 tall) with loose blocks around it
		local s1 = K.stage(m, 1)
		box(s1, V(58, 6, 58), CFrame.new(0, 3, 0), ST3, M.Slate)
		box(s1, V(46, 6, 46), CFrame.new(0, 9, 0), ST1, M.Slate)
		box(s1, V(34, 4, 34), CFrame.new(0, 14, 0), ST2, M.Slate)
		for _, c in { { -30, 5, -20 }, { 28, 4, -24 }, { 24, 3.5, 26 }, { -26, 4, 22 } } do
			box(s1, V(c[2] * 2, c[2] * 1.4, c[2] * 2), CFrame.new(c[1], c[2] * 0.7, c[3]) * rot(0, c[1] * 0.04, 0), ST1, M.Slate)
		end

		-- the pointed tip: two wedges meeting on the centre line (vertical inner edge, flat top edge), so the point reads as a clean V
		local function tip(parent: Instance, yTip: number, yTop: number, half: number, color: Color3)
			local h = yTop - yTip
			local yc = (yTip + yTop) / 2
			wedgeP(parent, V(5, h, half), CFrame.fromMatrix(V(half / 2, yc, 0), V(0, 0, -1), V(0, -1, 0)), color)
			wedgeP(parent, V(5, h, half), CFrame.fromMatrix(V(-half / 2, yc, 0), V(0, 0, 1), V(0, -1, 0)), color)
		end

		-- 2 LOWER BLADE: a long pointed tip driven into the stone and the narrow lower blade (18 wide) with the raised centre ridge (to y 58)
		local s2 = K.stage(m, 2)
		local sw2 = K.group(s2, "Sword")
		K.marker(s2, "SwordBase", V(0, 16, 0))
		tip(sw2, 14, 34, 9, BLADE)
		box(sw2, V(18, 24, 5), CFrame.new(0, 46, 0), BLADE, M.Metal)
		box(sw2, V(4.4, 30, 6.4), CFrame.new(0, 43, 0), BLADE2, M.Metal)

		-- 3 FULL BLADE: the blade widens toward the guard (21, then 24 wide) - a clear taper - with the ridge running up to a collar (to y 96)
		local s3 = K.stage(m, 3)
		local sw3 = K.group(s3, "Sword")
		box(sw3, V(21, 22, 5), CFrame.new(0, 69, 0), BLADE, M.Metal)
		box(sw3, V(24, 16, 5), CFrame.new(0, 88, 0), BLADE, M.Metal)
		box(sw3, V(4.4, 38, 6.4), CFrame.new(0, 77, 0), BLADE2, M.Metal)
		box(sw3, V(28, 6, 8), CFrame.new(0, 95, 0), GOLD2, M.Metal)
		K.marker(s3, "SlashC", V(0, 66, 0))

		-- 4 GUARD + HANDLE: a thick, iconic gold crossguard (about 80 across, wing tips swept up), a gem, and the grip with gold bands
		local s4 = K.stage(m, 4)
		local sw4 = K.group(s4, "Sword")
		box(sw4, V(40, 12, 12), CFrame.new(0, 101, 0), GOLD, M.Metal)
		for _, s in { -1, 1 } do
			box(sw4, V(26, 10, 11), CFrame.new(s * 30, 103.5, 0) * rot(0, 0, s * math.rad(14)), GOLD, M.Metal)
			box(sw4, V(12, 17, 11), CFrame.new(s * 43.5, 110.5, 0) * rot(0, 0, s * math.rad(-8)), GOLD2, M.Metal)
		end
		ell(sw4, V(10, 10, 7), CFrame.new(0, 101, -6.5), GEM, M.SmoothPlastic)
		cyl(sw4, 9, 24, CFrame.new(0, 118, 0), GRIP, M.Wood)
		for _, y in { 110, 118, 126 } do
			cyl(sw4, 10.4, 2.4, CFrame.new(0, y, 0), GOLD, M.Metal)
		end

		-- 5 POMMEL / FINAL ASSEMBLY: a heavy gold pommel ball with a cap, collar plates, and rivets of gold on the blade base
		local s5 = K.stage(m, 5)
		local sw5 = K.group(s5, "Sword")
		cyl(sw5, 12, 3, CFrame.new(0, 131.5, 0), GOLD2, M.Metal)
		ell(sw5, V(16, 16, 16), CFrame.new(0, 138, 0), GOLD, M.Metal)
		box(sw5, V(14, 9, 11), CFrame.new(0, 95, -2), GOLD, M.Metal)
		for _, s in { -1, 1 } do
			box(sw5, V(7, 4, 11), CFrame.new(s * 12, 96, 0), GOLD2, M.Metal)
		end
		K.marker(s5, "PommelTop", V(0, 146, 0))
		return m
	end,
}
