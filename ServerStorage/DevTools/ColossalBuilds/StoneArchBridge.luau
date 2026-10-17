--!nonstrict
-- STONE ARCH BRIDGE (Uncommon). One massive semicircular arch (54 wide opening, 27 radius) between two thick piers, a heavy
-- stone deck over it, chunky end towers and parapets, then a central crest with banners. ~104 wide x 36 deep x 95 tall.
-- Spans along X; the arch opening faces the spawn (-Z). Real arch: a ring of 13 stone blocks (voussoirs) with a key stone.
-- Groups for the client show: Lantern (lit by the show), Banner (hangs from its top edge, waved), Dust markers under the deck.
return {
	Id = "StoneArchBridge",
	Build = function(K)
		local V, M, RGB, box, cyl = K.V, K.M, K.RGB, K.box, K.cyl
		local ST1, ST2, ST3, DARK = RGB(150, 146, 138), RGB(172, 166, 154), RGB(128, 124, 118), RGB(104, 100, 96)
		local ROAD, LAMP, RED, GOLD = RGB(118, 114, 108), RGB(110, 72, 34), RGB(180, 48, 44), RGB(214, 170, 58)
		local m = K.template("StoneArchBridge")
		local CY, RI, RO = 20, 27, 35 -- arch centre height, inner and outer radius
		local DECK = 56 -- underside of the deck
		local D = 36 -- depth (z)

		-- 1 PIERS: two thick piers 25 wide; the inner seats up to the arch spring (20), the outer parts rise to the deck (56)
		local s1 = K.stage(m, 1)
		for _, sx in { -1, 1 } do
			box(s1, V(25, 4, 40), CFrame.new(sx * 39.5, 2, 0), ST3, M.Slate) -- footing
			box(s1, V(9, 18, D), CFrame.new(sx * 31.5, 13, 0), ST1, M.Slate) -- arch seat
			box(s1, V(16, 52, D), CFrame.new(sx * 44, 30, 0), ST1, M.Slate) -- the tall pier
			box(s1, V(17, 3, D + 3), CFrame.new(sx * 44, 22, 0), ST2, M.Slate) -- a course band
		end

		-- 2 ARCH: 13 stone blocks round the semicircle, the middle one a bigger key stone
		local s2 = K.stage(m, 2)
		local N = 13
		for i = 0, N - 1 do
			local th = (i + 0.5) * math.pi / N
			local key = i == (N - 1) / 2
			local rm = (RI + RO) / 2 + (if key then 1 else 0)
			local cf = CFrame.new(math.cos(th) * rm, CY + math.sin(th) * rm, 0) * CFrame.Angles(0, 0, th)
			box(s2, V(if key then 10 else 8, 7.6, D), cf, if key then ST2 else (if i % 2 == 0 then ST1 else ST3), M.Slate)
		end

		-- 3 DECK: the spandrel wall columns over the arch and a heavy deck slab with a road surface
		local s3 = K.stage(m, 3)
		for _, ax in { 12, 16.5, 21, 25.5, 30, 34 } do
			local ytop = CY + math.sqrt(RO * RO - ax * ax)
			local h = DECK - ytop
			if h > 1.5 then
				for _, sx in { -1, 1 } do
					box(s3, V(4.5, h, D), CFrame.new(sx * ax, ytop + h / 2, 0), ST3, M.Slate)
				end
			end
		end
		box(s3, V(104, 6, D), CFrame.new(0, DECK + 3, 0), ST1, M.Slate)
		box(s3, V(100, 1, 28), CFrame.new(0, DECK + 6.5, 0), ROAD, M.Slate)

		-- 4 TOWERS / PARAPETS: two big end towers (16 x 26 x 28), merlons, parapet walls and four lamps (the Lantern group)
		local s4 = K.stage(m, 4)
		local TOP = DECK + 6
		local lamps = K.group(s4, "Lantern")
		for _, sx in { -1, 1 } do
			box(s4, V(18, 28, 30), CFrame.new(sx * 43, TOP + 14, 0), ST1, M.Slate)
			box(s4, V(21, 3, 33), CFrame.new(sx * 43, TOP + 29.5, 0), ST2, M.Slate)
			for _, ox in { -1, 1 } do
				for _, oz in { -1, 1 } do
					box(s4, V(6, 6, 6), CFrame.new(sx * 43 + ox * 7.5, TOP + 34, oz * 12), ST2, M.Slate)
				end
			end
			box(s4, V(7, 12, 1), CFrame.new(sx * 43, TOP + 14, -15.4), DARK, M.SmoothPlastic) -- a dark door slot
			box(lamps, V(6, 9, 6), CFrame.new(sx * 36, TOP + 22, -18), LAMP, M.Neon, { Lantern = true })
		end
		for _, sz in { -1, 1 } do
			box(s4, V(60, 6, 3.4), CFrame.new(0, TOP + 3, sz * 14.3), ST1, M.Slate)
			for _, px in { -18, 0, 18 } do
				box(s4, V(6, 10, 6), CFrame.new(px, TOP + 5, sz * 14.3), ST2, M.Slate)
			end
		end
		for _, px in { -18, 18 } do
			box(lamps, V(6, 9, 6), CFrame.new(px, TOP + 14, -14.3), LAMP, M.Neon, { Lantern = true })
		end

		-- 5 FINAL STRUCTURE: a central crest block over the key stone with a dark gate niche, a finial and two banners
		local s5 = K.stage(m, 5)
		box(s5, V(30, 16, 30), CFrame.new(0, TOP + 8, 0), ST1, M.Slate)
		box(s5, V(34, 3, 34), CFrame.new(0, TOP + 17.5, 0), ST2, M.Slate)
		box(s5, V(12, 11, 1), CFrame.new(0, TOP + 8, -15.4), DARK, M.SmoothPlastic)
		cyl(s5, 5, 12, CFrame.new(0, TOP + 25, 0), GOLD, M.Metal)
		for _, sx in { -1, 1 } do
			local b = K.group(s5, "Banner")
			box(b, V(14, 30, 0.8), CFrame.new(sx * 47.5, TOP + 16, -16.4), RED, M.Fabric)
			box(b, V(14, 3.6, 0.9), CFrame.new(sx * 47.5, TOP + 29, -16.4), GOLD, M.Fabric)
			K.marker(b, "BannerTop", V(sx * 47.5, TOP + 31, -16.4))
		end
		-- dust points: invisible markers under the deck edge for the settling dust
		for _, px in { -26, -9, 9, 26 } do
			K.marker(s5, "DustPoint", V(px, DECK - 1, -18))
		end
		return m
	end,
}
