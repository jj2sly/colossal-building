--!nonstrict
-- TITAN MECH FOUNDRY (Mythic). A partially assembled titan mech standing in an even bigger OPEN factory frame, seen from the
-- spawn (-Z): two huge lattice side towers (x +-74, 215 tall) carrying an overhead frame of deep girders at y ~210, a gantry
-- trolley on the girders holding the mech's unfinished left arm on hoist cables, the head hanging just above the neck on its
-- own cables, three big assembly arms (two on the floor, one on the right tower) working on the mech, clamp beams from the
-- towers gripping the torso, and a lot of industrial empty space above and around the mech. The factory, not the robot, is
-- the silhouette: the mech is ~160 tall inside a ~215 tall, ~170 wide frame.
-- Nothing like Giant Robot (a finished robot standing alone) or Clockwork Titan (a bronze gear giant).
-- Groups for the client show: Mech (legs/pelvis/torso/armour: lifts as one), ArmR (seated right arm, marker ShoulderR),
-- Limb (suspended left arm, marker LimbSeat), Gantry (trolley + hoist cables), Head (marker HeadC), HeadCable, Core,
-- Eye, Clamp (clamp beams, attribute Side), Asm1/Asm2/Asm3 (assembly arms, markers Asm1Base.. at their bases, tool tips in
-- group Tool), FactoryLight (tower strips, attribute Order), Hook (idle hoist hooks), Beacon.
return {
	Id = "TitanMechFoundry",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, cylZ, ell, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.cylZ, K.ell, K.wedge
		local FRAME, FRAME2, DARK = RGB(58, 62, 70), RGB(80, 86, 96), RGB(34, 36, 42)
		local HAZ, HAZ2 = RGB(222, 168, 40), RGB(36, 36, 36)
		local ARMOR, ARMOR2, JOINT = RGB(196, 198, 202), RGB(150, 154, 162), RGB(70, 74, 82)
		local CONC, CONC2 = RGB(128, 128, 124), RGB(104, 104, 100)
		local GLOW0, CABLE = RGB(70, 40, 20), RGB(28, 28, 30)
		local m = K.template("TitanMechFoundry")
		local TX, TOP, FX = 96, 236, 72 -- tower centre x, underside of the overhead girders, footing x (inside the deck rail)

		-- 1 FOUNDATION: a heavy concrete factory floor, the assembly cradle pad under the mech and two tower footings
		local s1 = K.stage(m, 1)
		box(s1, V(150, 4, 90), CFrame.new(0, 2, 0), CONC2, M.Concrete)
		box(s1, V(70, 3, 50), CFrame.new(0, 5.5, 0), CONC, M.Concrete)
		for _, sz in { -1, 1 } do
			box(s1, V(70, 1, 4), CFrame.new(0, 7.5, sz * 23), HAZ, M.SmoothPlastic) -- hazard edge of the cradle pad
		end
		for _, sx in { -1, 1 } do
			box(s1, V(18, 12, 44), CFrame.new(sx * FX, 8, 0), CONC, M.Concrete)
		end

		-- 2 SIDE TOWERS: two open lattice towers (four corner columns, cross braces, three floor bands) with light strips
		local s2 = K.stage(m, 2)
		local lights = K.group(s2, "FactoryLight")
		for _, sx in { -1, 1 } do
			local cx = sx * TX
			-- the towers stand outboard of the deck on raking trestle legs from footings inside the rail
			for _, dx in { -10, 10 } do
				for _, dz in { -16, 16 } do
					box(s2, V(5, TOP + 4 - 30, 5), CFrame.new(cx + dx, 30 + (TOP + 4 - 30) / 2, dz), FRAME, M.Metal)
					bar(s2, V(sx * FX, 13, dz * 1.2), V(cx + dx, 32, dz), 5, FRAME, M.Metal)
				end
			end
			box(s2, V(26, 6, 38), CFrame.new(cx, 31, 0), FRAME2, M.Metal)
			for i, y in { 80, 140, 195 } do
				box(s2, V(26, 5, 38), CFrame.new(cx, y, 0), FRAME2, M.Metal)
				box(s2, V(26.4, 1.4, 1), CFrame.new(cx, y + 1, -19.2), HAZ, M.SmoothPlastic)
				local l = box(lights, V(1, 3, 30), CFrame.new(cx - sx * 13.2, y - 5, 0), GLOW0, M.SmoothPlastic)
				l:SetAttribute("Order", i)
			end
			-- X braces on the front and back faces between the bands, and on the inner face
			for _, seg in { { 32, 80 }, { 80, 140 }, { 140, 195 }, { 195, TOP } } do
				for _, dz in { -16, 16 } do
					bar(s2, V(cx - 10, seg[1], dz), V(cx + 10, seg[2], dz), 3, FRAME2, M.Metal)
					bar(s2, V(cx + 10, seg[1], dz), V(cx - 10, seg[2], dz), 3, FRAME2, M.Metal)
				end
				bar(s2, V(cx - sx * 10, seg[1], -16), V(cx - sx * 10, seg[2], 16), 3, FRAME2, M.Metal)
			end
		end

		-- 3 OVERHEAD FRAME: two deep girders spanning tower to tower, cross beams, a rail on top and two idle hoist hooks
		local s3 = K.stage(m, 3)
		local GW = TX * 2 + 60 -- the girders run past the towers as cantilevers
		for _, sz in { -1, 1 } do
			box(s3, V(GW, 12, 6), CFrame.new(0, TOP + 6, sz * 16), FRAME2, M.Metal)
			box(s3, V(GW, 2, 8), CFrame.new(0, TOP + 13, sz * 16), DARK, M.Metal) -- rail
			box(s3, V(GW, 1.4, 0.6), CFrame.new(0, TOP + 2, sz * 19.2), HAZ, M.SmoothPlastic)
		end
		for _, x in { -110, -70, -35, 0, 35, 70, 110 } do
			box(s3, V(4, 6, 26), CFrame.new(x, TOP + 6, 0), FRAME, M.Metal)
		end
		-- a roof truss over the girders: a top chord and diagonals (open, so the sky shows through)
		box(s3, V(TX * 2 + 20, 4, 4), CFrame.new(0, TOP + 34, 0), FRAME, M.Metal)
		for i = -4, 3 do
			local x0, x1 = i * 24, (i + 1) * 24
			bar(s3, V(x0, TOP + 14, 0), V(x1, TOP + 33, 0), 3, FRAME2, M.Metal)
			bar(s3, V(x1, TOP + 14, 0), V(x1, TOP + 33, 0), 3, FRAME2, M.Metal)
		end
		for _, sx in { -1, 1 } do
			bar(s3, V(sx * (TX + 10), TOP + 14, 0), V(sx * 96, TOP + 33, 0), 3, FRAME2, M.Metal)
			for _, sz in { -1, 1 } do
				wedge(s3, V(16, 16, 6), CFrame.new(sx * (TX - 18), TOP - 8, sz * 16) * CFrame.Angles(0, math.rad(sx * 90), math.rad(180)), FRAME, M.Metal) -- knee brackets
				bar(s3, V(sx * (TX + 10), TOP - 26, sz * 16), V(sx * (TX + 30), TOP, sz * 16), 3, FRAME2, M.Metal) -- cantilever stays
			end
		end
		local hooks = K.group(s3, "Hook")
		for _, x in { 40, 116 } do
			bar(hooks, V(x, TOP, 0), V(x, TOP - 80, 0), 0.8, CABLE, M.Metal)
			box(hooks, V(5, 6, 5), CFrame.new(x, TOP - 83, 0), HAZ, M.Metal)
			K.marker(hooks, "HookTop", V(x, TOP, 0))
		end

		-- 4 LEGS: two massive armoured legs on the cradle pad (feet, shins, knee guards, thighs) up to the hips at y ~80
		local s4 = K.stage(m, 4)
		local mech4 = K.group(s4, "Mech")
		for _, sx in { -1, 1 } do
			local x = sx * 17
			box(mech4, V(22, 10, 32), CFrame.new(x, 12, -3), ARMOR2, M.Metal) -- foot
			wedge(mech4, V(22, 8, 10), CFrame.new(x, 11, -24) * CFrame.Angles(0, math.rad(180), 0), ARMOR2, M.Metal) -- toe
			box(mech4, V(16, 30, 18), CFrame.new(x, 32, 0), ARMOR, M.Metal) -- shin
			box(mech4, V(10, 30, 10), CFrame.new(x, 32, 9), JOINT, M.Metal)
			box(mech4, V(20, 12, 20), CFrame.new(x, 50, 0), JOINT, M.Metal) -- knee
			wedge(mech4, V(18, 14, 8), CFrame.new(x, 50, -13) * CFrame.Angles(0, math.rad(180), 0), ARMOR2, M.Metal) -- knee guard
			box(mech4, V(18, 22, 20), CFrame.new(x, 67, 0), ARMOR, M.Metal) -- thigh
		end

		-- 5 TORSO: pelvis, a broad torso with the reactor socket and its core, chest plates and shoulder blocks (to y ~132)
		local s5 = K.stage(m, 5)
		local mech5 = K.group(s5, "Mech")
		box(mech5, V(48, 12, 26), CFrame.new(0, 82, 0), JOINT, M.Metal) -- pelvis
		box(mech5, V(30, 12, 22), CFrame.new(0, 94, 0), ARMOR2, M.Metal) -- waist
		box(mech5, V(56, 30, 30), CFrame.new(0, 114, 0), ARMOR, M.Metal) -- chest
		for _, sx in { -1, 1 } do
			wedge(mech5, V(26, 16, 10), CFrame.new(sx * 14, 104, -17) * CFrame.Angles(0, math.rad(180), 0), ARMOR2, M.Metal)
			box(mech5, V(18, 16, 22), CFrame.new(sx * 36, 124, 0), JOINT, M.Metal) -- shoulder blocks
		end
		box(mech5, V(16, 10, 14), CFrame.new(0, 133, 0), JOINT, M.Metal) -- neck socket
		local core = K.group(mech5, "Core")
		cylZ(mech5, 20, 2, CFrame.new(0, 116, -15.2), DARK, M.Metal)
		cylZ(core, 14, 2, CFrame.new(0, 116, -15.8), GLOW0, M.SmoothPlastic)

		-- 7 ARM 1: the right arm, already seated: shoulder pauldron, upper arm, elbow, forearm and a huge fist at the hip
		local s7 = K.stage(m, 7)
		local armR = K.group(s7, "ArmR")
		local SR = V(48, 124, 0)
		box(armR, V(16, 30, 16), CFrame.new(SR + V(4, -20, 0)), ARMOR, M.Metal)
		box(armR, V(14, 10, 14), CFrame.new(SR + V(4, -40, 0)), JOINT, M.Metal)
		box(armR, V(16, 28, 18), CFrame.new(SR + V(4, -58, -2)), ARMOR2, M.Metal)
		box(armR, V(20, 18, 20), CFrame.new(SR + V(4, -80, -2)), JOINT, M.Metal) -- fist
		K.marker(armR, "ShoulderR", SR)

		-- 8 ARM 2 (SUSPENDED): the left arm, built but not attached, hanging out beside the shoulder on hoist cables from the
		-- overhead frame (the gantry trolley is added in stage 9)
		local s8 = K.stage(m, 8)
		local limb = K.group(s8, "Limb")
		local LS = V(-48, 124, 0) -- where it will seat
		local LO = V(-18, 26, -6) -- its hanging offset (out, up and a little forward)
		local L0 = LS + LO
		box(limb, V(22, 14, 22), CFrame.new(L0 + V(-2, 6, 0)), ARMOR2, M.Metal) -- pauldron ring
		box(limb, V(16, 30, 16), CFrame.new(L0 + V(-4, -14, 0)), ARMOR, M.Metal)
		box(limb, V(14, 10, 14), CFrame.new(L0 + V(-4, -34, 0)), JOINT, M.Metal)
		box(limb, V(16, 28, 18), CFrame.new(L0 + V(-4, -52, -2)), ARMOR2, M.Metal)
		box(limb, V(20, 18, 20), CFrame.new(L0 + V(-4, -74, -2)), JOINT, M.Metal)
		box(limb, V(6, 6, 6), CFrame.new(L0 + V(-2, 15, 0)), HAZ, M.Metal) -- lifting eye
		K.marker(limb, "LimbSeat", L0)

		-- 6 HEAD: the head hanging just above the neck socket (a clear gap) on two cables from the overhead frame
		local s6 = K.stage(m, 6)
		local head = K.group(s6, "Head")
		local HC = V(0, 152, 0) -- seats at y 146
		box(head, V(22, 18, 22), CFrame.new(HC), ARMOR, M.Metal)
		wedge(head, V(22, 6, 10), CFrame.new(HC + V(0, -6, -14)) * CFrame.Angles(0, math.rad(180), 0), ARMOR2, M.Metal) -- jaw guard
		box(head, V(26, 4, 16), CFrame.new(HC + V(0, 11, 2)), ARMOR2, M.Metal) -- crest
		wedge(head, V(4, 10, 18), CFrame.new(HC + V(0, 18, 2)), JOINT, M.Metal) -- crest fin
		local eye = K.group(head, "Eye")
		box(eye, V(16, 3, 1), CFrame.new(HC + V(0, 2, -11.2)), GLOW0, M.SmoothPlastic)
		K.marker(head, "HeadC", HC)
		local hc = K.group(s6, "HeadCable")
		for _, sx in { -1, 1 } do
			bar(hc, V(sx * 8, TOP, 0), HC + V(sx * 8, 9, 0), 0.8, CABLE, M.Metal)
		end

		-- 9 ASSEMBLY ARMS: three big industrial arms (base drum, two links, tool head), all reaching into the mech
		local s9 = K.stage(m, 9)
		local function asmArm(i: number, base: Vector3, elbow: Vector3, tool: Vector3, upright: boolean)
			local g = K.group(s9, "Asm" .. i)
			if upright then
				cyl(g, 16, 8, CFrame.new(base + V(0, 4, 0)), HAZ, M.Metal)
				box(g, V(12, 10, 12), CFrame.new(base + V(0, 13, 0)), FRAME, M.Metal)
			else
				box(g, V(10, 16, 16), CFrame.new(base), HAZ, M.Metal)
			end
			local b2 = if upright then base + V(0, 16, 0) else base
			bar(g, b2, elbow, 8, HAZ, M.Metal)
			ell(g, V(11, 11, 11), CFrame.new(elbow), FRAME, M.Metal)
			bar(g, elbow, tool, 6, HAZ, M.Metal)
			box(g, V(7, 7, 7), CFrame.new(tool), FRAME, M.Metal)
			local t = K.group(g, "Tool")
			box(t, V(3, 3, 3), CFrame.new(tool + (tool - elbow).Unit * 4.5), GLOW0, M.SmoothPlastic)
			K.marker(g, "Asm" .. i .. "Base", b2)
		end
		asmArm(1, V(38, 6, -34), V(44, 72, -46), V(14, 104, -22), true) -- floor, front right: welding the chest
		asmArm(2, V(-36, 6, 34), V(-60, 86, 40), V(-40, 120, 14), true) -- floor, back left: reaching up to the left shoulder
		asmArm(3, V(TX - 15, 150, 0), V(64, 172, -26), V(56, 100, -16), false) -- on the right tower: the right elbow

		-- 10 GANTRY & SUSPENDED COMPONENTS: the gantry trolley on the overhead rails over the hanging arm, its hoist cables and
		-- the work lamps
		local s10 = K.stage(m, 10)
		local gantry = K.group(s10, "Gantry")
		local GX = L0.X - 2
		box(gantry, V(18, 10, 40), CFrame.new(GX, TOP + 19, 0), HAZ, M.Metal)
		for _, dz in { -14, 14 } do
			box(gantry, V(6, 6, 6), CFrame.new(GX, TOP + 13, dz), DARK, M.Metal) -- wheels on the rails
		end
		box(gantry, V(12, 10, 12), CFrame.new(GX, TOP - 2, 0), FRAME2, M.Metal) -- hoist block
		for _, dz in { -4, 4 } do
			bar(gantry, V(GX, TOP - 7, dz), L0 + V(-2, 18, dz * 0.5), 0.9, CABLE, M.Metal)
		end
		K.marker(gantry, "GantryC", V(GX, TOP + 19, 0))
		local beacon = K.group(s10, "Beacon")
		box(beacon, V(4, 3, 4), CFrame.new(GX, TOP + 25.5, 0), GLOW0, M.SmoothPlastic)

		-- 11 POWER & FINAL LOCK: clamp beams from both towers gripping the torso, power conduits into the mech's back, chest
		-- and shoulder armour, and tower-top warning beacons
		local s11 = K.stage(m, 11)
		for _, sx in { -1, 1 } do
			local c = K.group(s11, "Clamp")
			box(c, V(TX - 10 - 34, 8, 10), CFrame.new(sx * (TX - 10 + 34) / 2, 104, 18), FRAME2, M.Metal)
			box(c, V(6, 16, 14), CFrame.new(sx * 31, 104, 18), HAZ, M.Metal) -- clamp jaw
			for _, p in c:GetChildren() do
				if p:IsA("BasePart") then
					p:SetAttribute("Side", sx)
				end
			end
			bar(s11, V(sx * (TX - 10), 80, 14), V(sx * 14, 100, 16), 3, CABLE, M.Metal) -- power conduit
			local b = K.group(s11, "Beacon")
			box(b, V(5, 4, 5), CFrame.new(sx * (TX + 50), TOP + 15, 0), GLOW0, M.SmoothPlastic) -- cantilever-tip beacons
		end
		local mech11 = K.group(s11, "Mech")
		box(mech11, V(40, 18, 4), CFrame.new(0, 124, -16.6), ARMOR2, M.Metal) -- chest plate (above the core)
		box(mech11, V(26, 16, 26), CFrame.new(-38, 136, 0), ARMOR2, M.Metal) -- left shoulder mount
		box(mech11, V(26, 16, 26), CFrame.new(SR + V(-10, 12, 0)), ARMOR2, M.Metal) -- right shoulder mount
		return m
	end,
}
