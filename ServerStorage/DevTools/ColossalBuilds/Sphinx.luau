--!nonstrict
-- SPHINX (Rare). One integrated LONG RECLINING lion-bodied sphinx (~176 long, ~86 tall, ~70 wide) on a low plinth. Head / paws
-- point toward +X. Primary mass: a very long, heavy, low lion torso. Secondary: two enormous long front paws stretched forward
-- with a gap between them, a broad raised chest that rises into the shoulders, a human head pushing forward out of the chest (low and
-- broad, flat face plane), and a true nemes headdress whose wedge-shaped side flaps flare outward and slope down onto the
-- shoulders. Rear haunches and a tail are secondary. Stone dominates; blue/gold are restrained accents.
-- Group for the client show: Eye (two parts; marker EyeC is the glow anchor).
return {
	Id = "Sphinx",
	Build = function(K)
		local V, M, RGB, box, ell, bar, wedge = K.V, K.M, K.RGB, K.box, K.ell, K.bar, K.wedge
		local SAND, SAND2, SAND3, DARK = RGB(222, 190, 126), RGB(200, 166, 102), RGB(234, 206, 146), RGB(116, 86, 52)
		local BLUE, GOLD, STONE = RGB(52, 88, 158), RGB(214, 170, 62), RGB(170, 146, 104)
		local m = K.template("Sphinx")
		local rot = CFrame.Angles

		-- 1 PLINTH / PAWS: a long low plinth and the two enormous front paws: long low forearms ending in big rounded paws
		local s1 = K.stage(m, 1)
		box(s1, V(176, 5, 70), CFrame.new(0, 2.5, 0), STONE, M.Sandstone)
		for _, sz in { -1, 1 } do
			box(s1, V(56, 13, 17), CFrame.new(54, 11.5, sz * 15), SAND, M.Sandstone) -- forearm (a 13-stud gap between the two)
			ell(s1, V(26, 15, 21), CFrame.new(82, 11, sz * 15), SAND3, M.Sandstone) -- the paw: a big rounded pad
			for _, t in { -6, 0, 6 } do
				ell(s1, V(9, 9, 6.6), CFrame.new(93, 8, sz * 15 + t), SAND2, M.Sandstone) -- three big toes
			end
		end

		-- 2 LION BODY (the primary mass): a very long, heavy, low torso: a faceted box core with a rounded back over it
		local s2 = K.stage(m, 2)
		box(s2, V(110, 22, 46), CFrame.new(-18, 16, 0), SAND2, M.Sandstone)
		ell(s2, V(120, 34, 50), CFrame.new(-18, 26, 0), SAND, M.Sandstone)
		for _, sz in { -1, 1 } do -- rear haunches and the tucked back legs
			ell(s2, V(44, 32, 18), CFrame.new(-50, 22, sz * 22), SAND2, M.Sandstone)
			box(s2, V(34, 9, 15), CFrame.new(-40, 9.5, sz * 25), SAND, M.Sandstone)
		end
		bar(s2, V(-76, 14, 18), V(-60, 8, 32), 5, SAND2, M.Sandstone) -- the tail curling round the haunch
		ell(s2, V(8, 8, 9), CFrame.new(-58, 8, 34), DARK, M.Sandstone)

		-- 3 CHEST / SHOULDERS: a sloped chest that flows forward and down out of the torso, and broad faceted shoulders
		local s3 = K.stage(m, 3)
		wedge(s3, V(56, 24, 40), CFrame.fromMatrix(V(18, 34, 0), V(0, 0, -1), V(0, 1, 0)), SAND, M.Sandstone) -- rises toward the head
		ell(s3, V(34, 32, 46), CFrame.new(36, 30, 0), SAND, M.Sandstone) -- rounded chest front
		for _, sz in { -1, 1 } do
			box(s3, V(36, 18, 18), CFrame.new(30, 20, sz * 24) * CFrame.Angles(sz * math.rad(10), 0, 0), SAND2, M.Sandstone) -- shoulder block, tilted in toward the chest
		end

		-- 4 NECK / HEAD: the head pushes FORWARD from the shoulders (low and wide), no pedestal under it
		local s4 = K.stage(m, 4)
		wedge(s4, V(30, 12, 26), CFrame.fromMatrix(V(36, 48, 0), V(0, 0, -1), V(0, 1, 0)), SAND, M.Sandstone) -- sloped neck/back of head
		box(s4, V(24, 22, 32), CFrame.new(44, 58, 0), SAND3, M.Sandstone) -- head: 32 wide x 22 tall, face plane at x 56

		-- 5 HEADDRESS (nemes): a low cap and two short tapered flaps that flare out from the skull and angle down to the shoulders
		local s5 = K.stage(m, 5)
		wedge(s5, V(34, 5, 26), CFrame.fromMatrix(V(42, 71.5, 0), V(0, 0, 1), V(0, 1, 0)), BLUE, M.Sandstone) -- cap
		box(s5, V(32, 2, 26), CFrame.new(44, 69, 0), GOLD, M.Sandstone) -- forehead band
		for _, sz in { -1, 1 } do
			-- upper flare: a wedge out from the temple; lower flap: a short wedge sloping down onto the shoulder
			wedge(s5, V(18, 10, 10), CFrame.fromMatrix(V(42, 64, sz * 20), V(1, 0, 0), V(0, 1, 0)) * CFrame.Angles(0, sz < 0 and math.pi or 0, 0), BLUE, M.Sandstone)
			local flap = CFrame.new(40, 51, sz * 23) * CFrame.Angles(-sz * math.rad(38), 0, 0)
			box(s5, V(16, 16, 4), flap, BLUE, M.Sandstone)
			box(s5, V(16.4, 2.4, 4.4), flap * CFrame.new(0, 2, 0), GOLD, M.Sandstone)
		end

		-- 6 FACE / FINAL MONUMENT: brow, eyes, a strong nose and chin, a short beard, a small gold cobra
		local s6 = K.stage(m, 6)
		box(s6, V(4, 3.4, 26), CFrame.new(56.5, 64, 0), SAND2, M.Sandstone) -- brow
		for _, sz in { -1, 1 } do
			local e = K.group(s6, "Eye")
			ell(e, V(3.4, 4, 6), CFrame.new(56.4, 60.5, sz * 7), DARK, M.Sandstone)
			K.marker(e, "EyeC", V(57.4, 60.5, sz * 7))
		end
		box(s6, V(5, 9, 7), CFrame.new(58, 56, 0), SAND3, M.Sandstone) -- nose
		box(s6, V(3, 2.4, 13), CFrame.new(56.6, 50.5, 0), DARK, M.Sandstone) -- mouth
		box(s6, V(6, 6, 14), CFrame.new(55.5, 46, 0), SAND2, M.Sandstone) -- chin
		box(s6, V(5, 8, 6), CFrame.new(54, 39, 0), SAND2, M.Sandstone) -- beard
		ell(s6, V(5, 7, 5), CFrame.new(55, 73, 0), GOLD, M.Metal) -- cobra
		return m
	end,
}
