--!nonstrict
-- ROCKET LAUNCHER MONUMENT (Uncommon). A heavy stone pedestal, two thick A-frame supports and a very long olive launcher tube
-- (80 long, 18 across) raised 34 degrees on its trunnion with a big red rocket nose sticking out of the muzzle. ~106 long
-- end to end. Long axis X (seen broadside from the spawn), launcher pointing +X and up. Front faces -Z.
-- Groups for the client show: Tube (everything that elevates), Rocket (rides with the tube, then flies off). Marker Pivot is
-- the trunnion; the Rocket flies along the tube axis, whose authored elevation is 34 degrees.
return {
	Id = "RocketMonument",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, ell = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.ell
		local ST1, ST2, ST3 = RGB(138, 134, 126), RGB(164, 158, 146), RGB(108, 104, 98)
		local OLIVE, OLIVE2, STEEL, ORANGE, RED, WHITE = RGB(92, 110, 66), RGB(70, 84, 52), RGB(110, 118, 130), RGB(232, 126, 36), RGB(206, 52, 44), RGB(240, 236, 226)
		local m = K.template("RocketMonument")
		local OX = -22 -- shift so the whole monument is centred on the origin
		local E0 = math.rad(34)
		local P0 = V(OX, 46, 0)
		local F = CFrame.new(P0) * CFrame.Angles(0, 0, E0) -- local +X = the tube axis

		-- 1 PEDESTAL: a stepped stone pedestal: slab (62 x 8 x 46), block (46 x 18 x 34) and a cap (50 x 4 x 38), to y 30
		local s1 = K.stage(m, 1)
		box(s1, V(62, 8, 46), CFrame.new(OX, 4, 0), ST3, M.Slate)
		box(s1, V(46, 18, 34), CFrame.new(OX, 17, 0), ST1, M.Slate)
		box(s1, V(50, 4, 38), CFrame.new(OX, 28, 0), ST2, M.Slate)
		box(s1, V(20, 3, 8), CFrame.new(OX, 1.5, -27), ST3, M.Slate)

		-- 2 SUPPORT FRAME: two A-frames (thick bars rising from the cap to the trunnion), a trunnion axle and an elevation strut
		local s2 = K.stage(m, 2)
		for _, sz in { -1, 1 } do
			bar(s2, V(OX - 20, 30, sz * 14), P0 + V(0, 0, sz * 14), 8, ST1, M.Slate)
			bar(s2, V(OX + 20, 30, sz * 14), P0 + V(0, 0, sz * 14), 8, ST1, M.Slate)
			box(s2, V(12, 7, 10), CFrame.new(P0 + V(0, 0, sz * 14)), ST2, M.Slate)
		end
		cyl(s2, 10, 40, CFrame.new(P0) * CFrame.Angles(math.rad(90), 0, 0), STEEL, M.Metal)
		K.marker(s2, "Pivot", P0)

		-- 3 LAUNCHER TUBE: the long olive tube (t -15 .. 63 along the axis), breech cap, muzzle ring and three orange bands
		local s3 = K.stage(m, 3)
		local tube = K.group(s3, "Tube")
		local function axial(parent: Instance, d: number, len: number, t: number, color: Color3, mat: Enum.Material?)
			return cyl(parent, d, len, F * CFrame.new(t, 0, 0) * CFrame.Angles(0, 0, -math.rad(90)), color, mat)
		end
		axial(tube, 18, 78, 24, OLIVE, M.Metal)
		axial(tube, 22, 8, -17, OLIVE2, M.Metal)
		axial(tube, 23, 6, 61, STEEL, M.Metal)
		for _, t in { 4, 24, 44 } do
			axial(tube, 20.4, 4, t, ORANGE, M.Metal)
		end
		K.marker(tube, "Muzzle", (F * CFrame.new(64, 0, 0)).Position)

		-- 4 ROCKET / FINAL ASSEMBLY: a big red rocket loaded in the tube; its nose, body and fins stick out of the muzzle
		local s4 = K.stage(m, 4)
		local rk = K.group(s4, "Rocket")
		axial(rk, 12, 36, 52, RED, M.SmoothPlastic)
		ell(rk, V(22, 12, 12), F * CFrame.new(71, 0, 0), WHITE, M.SmoothPlastic)
		axial(rk, 12.4, 3, 69.5, ORANGE, M.SmoothPlastic)
		for _, a in { 0, math.rad(90) } do
			box(rk, V(9, 1.6, 20), F * CFrame.new(40, 0, 0) * CFrame.Angles(a, 0, 0), RED, M.SmoothPlastic)
		end
		K.marker(rk, "RocketTail", (F * CFrame.new(32, 0, 0)).Position)
		return m
	end,
}
