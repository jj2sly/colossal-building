--!nonstrict
-- GIANT ARCADE MACHINE (Uncommon). An enormous arcade cabinet (58 wide, 70 deep including the control deck, 96 tall): a blue lower
-- cabinet with a coin door, a deep screen housing with side cheeks and a bezel (the screen is recessed ~30 studs and tilted
-- back), a marquee that clearly projects forward, a sloped control deck with a giant joystick and three giant buttons, and
-- a 9 x 6 pixel screen showing a classic invader. Front faces -Z.
-- Groups for the client show: Pixel (54 screen pixels, attributes Row / Col), Marquee (the glowing face), Stick (joystick,
-- marker StickBase), Button (three, pressed in turn).
return {
	Id = "ArcadeMachine",
	Build = function(K)
		local V, M, RGB, box, wedge, cyl, ell = K.V, K.M, K.RGB, K.box, K.wedge, K.cyl, K.ell
		local BLUE, BLUE2, DARK, TRIM = RGB(40, 74, 168), RGB(28, 52, 124), RGB(24, 28, 40), RGB(250, 196, 40)
		local MAG, PINK, STICK, GREY = RGB(220, 60, 160), RGB(110, 40, 90), RGB(204, 40, 40), RGB(150, 154, 166)
		local m = K.template("ArcadeMachine")
		local rot = CFrame.Angles

		-- 1 CABINET BASE: a blue lower cabinet (56 x 38 x 44) on a dark kick plate, with a coin door, two coin slots and side stripes
		local s1 = K.stage(m, 1)
		box(s1, V(60, 4, 48), CFrame.new(0, 2, 0), DARK, M.SmoothPlastic)
		box(s1, V(56, 36, 44), CFrame.new(0, 22, 0), BLUE, M.SmoothPlastic)
		box(s1, V(22, 16, 1.2), CFrame.new(0, 20, -22.4), DARK, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			box(s1, V(4, 7, 1.6), CFrame.new(sx * 5, 24, -22.9), TRIM, M.Neon)
			box(s1, V(1.4, 30, 44.4), CFrame.new(sx * 28.3, 22, 0), BLUE2, M.SmoothPlastic)
			box(s1, V(1.6, 5, 44.6), CFrame.new(sx * 28.4, 28, 0), TRIM, M.SmoothPlastic)
			box(s1, V(1.6, 5, 44.6), CFrame.new(sx * 28.4, 16, 0), MAG, M.SmoothPlastic)
		end

		-- 2 SCREEN HOUSING: two thick cheeks (6 x 44 x 44), a back wall, a bezel above and below the screen opening (44 wide,
		-- y 47 .. 75) so the screen sits deep inside the cabinet
		local s2 = K.stage(m, 2)
		for _, sx in { -1, 1 } do
			box(s2, V(7, 44, 44), CFrame.new(sx * 25.5, 62, 0), BLUE, M.SmoothPlastic)
		end
		box(s2, V(44, 44, 6), CFrame.new(0, 62, 19), BLUE2, M.SmoothPlastic)
		box(s2, V(44, 6, 8), CFrame.new(0, 44, -18), TRIM, M.SmoothPlastic)
		box(s2, V(44, 8, 8), CFrame.new(0, 79, -18), BLUE2, M.SmoothPlastic)
		box(s2, V(44, 40, 1), CFrame.new(0, 62, 15.5), DARK, M.SmoothPlastic)

		-- 3 MARQUEE: a big overhanging top (58 x 14 x 34, y 82 .. 96) projecting 8 studs past the cabinet front, with a pink
		-- glowing face (the Marquee group) and gold rim
		local s3 = K.stage(m, 3)
		box(s3, V(58, 14, 34), CFrame.new(0, 89, -13), BLUE, M.SmoothPlastic)
		box(s3, V(60, 2.6, 36), CFrame.new(0, 96.3, -13), TRIM, M.SmoothPlastic)
		local mq = K.group(s3, "Marquee")
		box(mq, V(50, 10, 1.4), CFrame.new(0, 89, -30.7), PINK, M.SmoothPlastic)
		box(mq, V(26, 4, 1.6), CFrame.new(0, 89, -31.2), MAG, M.SmoothPlastic)
		K.marker(mq, "MarqueeC", V(0, 89, -31.5))

		-- 4 CONTROL DECK: a sloped wedge deck (56 x 12 x 26) projecting 28 studs from the front, with a giant joystick and
		-- three giant buttons
		local s4 = K.stage(m, 4)
		wedge(s4, V(56, 12, 26), CFrame.new(0, 38, -35), DARK, M.SmoothPlastic)
		box(s4, V(58, 3, 4), CFrame.new(0, 33, -48.6), TRIM, M.SmoothPlastic)
		local stick = K.group(s4, "Stick")
		cyl(stick, 12, 3, CFrame.new(-14, 40.4, -33), GREY, M.Metal)
		cyl(stick, 5, 20, CFrame.new(-14, 51, -33), GREY, M.Metal)
		ell(stick, V(14, 14, 14), CFrame.new(-14, 63, -33), STICK, M.SmoothPlastic)
		K.marker(stick, "StickBase", V(-14, 41, -33))
		for i, c in { RGB(220, 50, 50), RGB(250, 206, 40), RGB(70, 190, 90) } do
			local b = K.group(s4, "Button")
			cyl(b, 10, 4, CFrame.new(4 + (i - 1) * 12.5, 41.2, -34 + (i % 2) * 2), c, M.SmoothPlastic)
		end

		-- 5 SCREEN / FINAL FORM: a dark recessed screen plate tilted back 10 degrees with a 9 x 6 grid of pixel blocks
		local s5 = K.stage(m, 5)
		local S = CFrame.new(0, 61, 3) * rot(math.rad(10), 0, 0)
		box(K.group(s5, "Screen"), V(44, 30, 2), S, DARK, M.SmoothPlastic)
		for r = 1, 6 do
			for c = 1, 9 do
				local p = box(s5, V(4, 4, 1.4), S * CFrame.new((c - 5) * 4.6, (3.5 - r) * 4.6, -1.8), RGB(14, 28, 34), M.SmoothPlastic, { Row = r, Col = c })
				p.Parent = K.group(s5, "Pixel")
			end
		end
		return m
	end,
}
