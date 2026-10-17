--!nonstrict
-- BUILDER BUDDY STATUE (Common). The game mascot: a chunky yellow builder with an oversized head and a big yellow hard hat, a
-- broad hi-vis torso over blue overalls, short thick legs on HUGE boots, thick arms, and a giant claw-less sledgehammer held
-- upright in the right fist beside the hat (left fist: a thumbs-up thumb already pointing forward). ~74 tall, ~90 wide with the
-- hammer. Front faces -Z (the spawn). Groups for the client show: Head (head + hat; marker HeadPivot), Hat (the hard hat; its parts
-- can glow), ArmR (right arm + fist + hammer; marker ShoulderR), ArmL (left arm + fist + thumb; marker ShoulderL).
return {
	Id = "BuilderBuddyStatue",
	Build = function(K)
		local V, M, RGB, box, cyl, ell = K.V, K.M, K.RGB, K.box, K.cyl, K.ell
		local STONE, STONE2 = RGB(122, 120, 116), RGB(150, 148, 142)
		local YEL, YEL2, ORANGE = RGB(246, 205, 52), RGB(238, 190, 40), RGB(238, 128, 36)
		local BLUE, BLUE2, BROWN, BROWN2 = RGB(38, 98, 172), RGB(30, 78, 140), RGB(130, 84, 48), RGB(88, 58, 36)
		local STEEL, WOOD, BLACK, PINK, GREY = RGB(150, 154, 162), RGB(150, 104, 58), RGB(28, 28, 32), RGB(238, 148, 132), RGB(214, 216, 214)
		local m = K.template("BuilderBuddyStatue")
		local rot = CFrame.Angles

		-- 1 PEDESTAL / BOOTS: a two-step stone pedestal and the two HUGE boots (17 wide x 11 tall x 29 long with rounded toes), top at y 18
		local s1 = K.stage(m, 1)
		box(s1, V(62, 4, 50), CFrame.new(0, 2, 0), STONE, M.Slate)
		box(s1, V(50, 3, 40), CFrame.new(0, 5.5, 0), STONE2, M.Slate)
		for _, sx in { -1, 1 } do
			box(s1, V(18, 2.4, 29), CFrame.new(sx * 10, 8.2, -3), BROWN2, M.SmoothPlastic) -- sole
			box(s1, V(17, 9.5, 18), CFrame.new(sx * 10, 13.2, 3), BROWN, M.SmoothPlastic) -- boot shaft
			ell(s1, V(17, 10, 16), CFrame.new(sx * 10, 12.4, -8.5), BROWN, M.SmoothPlastic) -- rounded toe
		end

		-- 2 LEGS + TORSO: short thick blue legs, a belt, the broad torso (38 wide) with an orange hi-vis vest and two grey stripes
		local s2 = K.stage(m, 2)
		for _, sx in { -1, 1 } do
			box(s2, V(14, 11, 15), CFrame.new(sx * 10, 23.5, 1), BLUE, M.SmoothPlastic)
		end
		box(s2, V(38, 3.2, 21), CFrame.new(0, 30.4, 0), BROWN2, M.SmoothPlastic) -- belt
		box(s2, V(7, 3.6, 1), CFrame.new(0, 30.4, -10.6), YEL, M.Metal) -- buckle
		box(s2, V(38, 14, 20), CFrame.new(0, 39, 0), BLUE, M.SmoothPlastic)
		box(s2, V(38.6, 12.5, 20.6), CFrame.new(0, 39.8, 0), ORANGE, M.SmoothPlastic) -- vest
		for _, y in { 36, 42 } do
			box(s2, V(38.8, 1.8, 20.8), CFrame.new(0, y, 0), GREY, M.SmoothPlastic) -- hi-vis stripes
		end

		-- 3 ARMS + GIANT TOOL: thick arms hanging a little away from the torso (clear gaps), big round fists; the right fist grips
		-- a giant sledgehammer held upright (handle 46 tall, head 24 x 12 x 13) beside the hat; the left fist's thumb points forward
		local s3 = K.stage(m, 3)
		local armR = K.group(s3, "ArmR")
		box(armR, V(11, 20, 12), CFrame.new(28.5, 37, 0) * rot(0, 0, 0.2), YEL2, M.SmoothPlastic)
		ell(armR, V(13, 13, 13), CFrame.new(33, 26, -2), YEL, M.SmoothPlastic)
		box(armR, V(4.6, 46, 4.6), CFrame.new(33, 43, -2), WOOD, M.Wood) -- handle
		box(armR, V(24, 12, 13), CFrame.new(33, 66, -2), STEEL, M.Metal) -- hammer head
		box(armR, V(25, 3, 13.6), CFrame.new(33, 70.8, -2), YEL, M.Metal) -- paint band on the head
		K.marker(armR, "ShoulderR", V(26, 45, 0))
		local armL = K.group(s3, "ArmL")
		box(armL, V(11, 20, 12), CFrame.new(-28.5, 37, 0) * rot(0, 0, -0.2), YEL2, M.SmoothPlastic)
		ell(armL, V(13, 13, 13), CFrame.new(-33, 26, -2), YEL, M.SmoothPlastic)
		box(armL, V(4.5, 4.5, 8), CFrame.new(-33, 27.5, -9), YEL, M.SmoothPlastic) -- thumb pointing forward (up once the arm is raised)
		K.marker(armL, "ShoulderL", V(-26, 45, 0))

		-- 4 HEAD + HARD HAT: a big blocky head (26 x 22 x 24) with a simple smile, cheeks and nose; a big yellow-orange hard hat
		-- with a wide brim, a ridge and a front badge (top at y ~74)
		local s4 = K.stage(m, 4)
		local head = K.group(s4, "Head")
		box(head, V(12, 3, 12), CFrame.new(0, 45.5, 0), YEL2, M.SmoothPlastic) -- neck
		box(head, V(26, 22, 24), CFrame.new(0, 55.5, 0), YEL, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			box(head, V(3.4, 5.4, 1.2), CFrame.new(sx * 6, 58, -12.4), BLACK, M.SmoothPlastic) -- eyes
			box(head, V(4.4, 3, 1), CFrame.new(sx * 9.6, 52.6, -12.4), PINK, M.SmoothPlastic) -- cheeks
			box(head, V(1.6, 2.2, 1.2), CFrame.new(sx * 5.4, 51.4, -12.4), BLACK, M.SmoothPlastic) -- smile ends
		end
		box(head, V(10, 1.8, 1.2), CFrame.new(0, 50.6, -12.4), BLACK, M.SmoothPlastic) -- smile
		box(head, V(3.6, 4, 2), CFrame.new(0, 54, -13), YEL2, M.SmoothPlastic) -- nose
		local hat = K.group(head, "Hat")
		ell(hat, V(31, 17, 31), CFrame.new(0, 65.5, 0), ORANGE, M.SmoothPlastic)
		box(hat, V(34, 2.6, 36), CFrame.new(0, 62.6, -2), ORANGE, M.SmoothPlastic) -- brim
		box(hat, V(5.5, 2.4, 30), CFrame.new(0, 73, 0), YEL, M.SmoothPlastic) -- ridge
		box(hat, V(8, 6, 1.2), CFrame.new(0, 66.5, -15.4), YEL, M.SmoothPlastic) -- badge
		K.marker(head, "HeadPivot", V(0, 45, 0))
		return m
	end,
}
