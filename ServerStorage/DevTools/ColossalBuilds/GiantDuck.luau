--!nonstrict
-- GIANT DUCK (Rare). ONE enormous LOW HORIZONTAL rubber duck standing in a round pond: a long egg body (154 long, 84 wide, only
-- ~56 tall, flattened underneath), a smaller head set low and forward that grows straight out of the front of the body (almost
-- no neck), a broad flat wedge beak, flattened wings that hug the body contour, a low rear wedge/fan tail that extends the
-- horizontal line, and two big wide webbed feet. ~94 tall, ~180 long (beak to tail), ~84 wide. Head faces -Z.
-- Groups for the client show: Body (body + tail), WingL, WingR, Head (head, beak, eyes; marker HeadPivot at the head base).
return {
	Id = "GiantDuck",
	Build = function(K)
		local V, M, RGB, box, ell, cyl, wedge = K.V, K.M, K.RGB, K.box, K.ell, K.cyl, K.wedge
		local Y, Y2, Y3 = RGB(240, 192, 50), RGB(222, 168, 38), RGB(248, 210, 84)
		local OR, OR2 = RGB(236, 124, 34), RGB(206, 100, 28)
		local WATER, RIM = RGB(70, 140, 182), RGB(118, 124, 134)
		local m = K.template("GiantDuck")
		local rot = CFrame.Angles

		-- 1 FEET / BASE: the pond and two big flat webbed feet, wide-set, with short thick ankles up into the body
		local s1 = K.stage(m, 1)
		cyl(s1, 132, 2.4, CFrame.new(0, 1.2, 4), RIM, M.Concrete)
		local water = cyl(s1, 124, 0.6, CFrame.new(0, 2.5, 4), WATER, M.Glass)
		water.Transparency = 0.25
		for _, sx in { -1, 1 } do
			local foot = CFrame.new(sx * 27, 5.5, -36) * rot(0, sx * 0.18, 0)
			box(s1, V(34, 5, 30), foot * CFrame.new(0, 0, 4), OR, M.SmoothPlastic) -- broad flat web
			for i = -1, 1 do -- three fat toes splayed forward
				box(s1, V(11, 5.6, 18), foot * CFrame.new(i * 11.5, 0.3, -16) * rot(0, i * -0.22, 0), OR2, M.SmoothPlastic)
			end
			box(s1, V(16, 14, 18), CFrame.new(sx * 25, 13, -26), OR, M.SmoothPlastic) -- short chunky ankle
		end

		-- 2 BODY (the primary mass): one long egg, much longer than tall, fuller at the front, with a flat heavy underside
		local s2 = K.stage(m, 2)
		local body = K.group(s2, "Body")
		ell(body, V(84, 56, 154), CFrame.new(0, 42, 6), Y)
		ell(body, V(80, 22, 140), CFrame.new(0, 24, 6), Y) -- a wide flat lower ellipsoid: the underside reads heavy and flat, not round
		ell(body, V(76, 44, 70), CFrame.new(0, 40, -28), Y) -- fuller front half (the body itself carries the chest, no separate blob)

		-- 3 WINGS: long flattened slabs pressed along the body sides, following its curve, the rear tips lifting slightly
		local s3 = K.stage(m, 3)
		for _, sx in { -1, 1 } do
			local wing = K.group(s3, if sx < 0 then "WingL" else "WingR")
			ell(wing, V(9, 40, 104), CFrame.new(sx * 40.5, 44, 14) * rot(-0.08, 0, sx * -0.2), Y2)
			ell(wing, V(8, 18, 44), CFrame.new(sx * 37, 55, 52) * rot(-0.3, 0, sx * -0.18), Y3)
		end

		-- 4 HEAD: a smaller round head (44 wide) set LOW and far forward, sunk into the front of the body: no visible neck
		local s4 = K.stage(m, 4)
		local head4 = K.group(s4, "Head")
		ell(head4, V(54, 30, 44), CFrame.new(0, 54, -46), Y) -- the short fat transition: the head grows out of the body
		ell(head4, V(44, 38, 42), CFrame.new(0, 66, -56), Y3)
		K.marker(head4, "HeadPivot", V(0, 52, -46))

		-- 5 BEAK / FACE: a broad flat beak (42 wide, only 10 tall), tilted slightly down, and two small simple eyes
		local s5 = K.stage(m, 5)
		local head5 = K.group(s5, "Head")
		ell(head5, V(42, 10, 32), CFrame.new(0, 62, -80) * rot(0.08, 0, 0), OR)
		ell(head5, V(34, 6, 24), CFrame.new(0, 56.5, -76) * rot(0.04, 0, 0), OR2)
		for _, sx in { -1, 1 } do
			ell(head5, V(4.4, 6, 3), CFrame.new(sx * 12.5, 73, -73) * rot(0, sx * 0.45, 0), RGB(26, 26, 32))
		end

		-- 6 TAIL / FINAL MASS: a low rear wedge rising gently out of the back of the body and a flat fan tip (extends the length)
		local s6 = K.stage(m, 6)
		local body6 = K.group(s6, "Body")
		wedge(body6, V(54, 20, 40), CFrame.new(0, 52, 80), Y)
		wedge(body6, V(46, 12, 26), CFrame.new(0, 66, 96) * rot(-0.15, 0, 0), Y3) -- the fan tip continues the low wedge
		return m
	end,
}
