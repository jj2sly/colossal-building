--!nonstrict
-- GIANT HAMMER (Uncommon). An absurd sledge head (58 x 32 x 44) on a thick angled handle (9 thick, 40 long) that pivots on a
-- tall stone pedestal, aimed at a big impact slab. Leaning 22 degrees toward the slab; at completion it slams down onto it.
-- ~86 wide x 94 tall x 46 deep. Long axis X, the pedestal at -X and the impact slab at +X. Front faces -Z.
-- Group for the client show: Hammer (handle + head, rigid); marker Pivot (rotation centre, rotate about local Z).
-- Geometry check: handle length L=40 from the pivot, strike face at local x=27: at 90 degrees the face lands at pivot.y - 27 = 6
-- (the top of the slab) and spans x = pivot.x + 40 +- 16.
return {
	Id = "GiantHammer",
	Build = function(K)
		local V, M, RGB, box, wedge = K.V, K.M, K.RGB, K.box, K.wedge
		local ST1, ST2, ST3 = RGB(140, 136, 128), RGB(166, 160, 148), RGB(112, 108, 102)
		local WOOD, WOOD2 = RGB(150, 98, 54), RGB(120, 76, 42)
		local STEEL, STEEL2, FACE, GOLD = RGB(112, 120, 134), RGB(86, 92, 104), RGB(226, 126, 40), RGB(214, 170, 58)
		local m = K.template("GiantHammer")
		local PX, PY, L, H0 = -28, 35, 50, 22 -- pivot, handle length, authored lean (degrees from vertical toward +X)
		local pivot = V(PX, PY, 0)
		local frame = CFrame.new(pivot) * CFrame.Angles(0, 0, -math.rad(H0)) -- local +y = handle, +x = strike direction

		-- 1 PEDESTAL: a tall stepped stone pedestal with a front step and a cradle (two posts) around the pivot
		local s1 = K.stage(m, 1)
		box(s1, V(46, 8, 44), CFrame.new(PX, 4, 0), ST3, M.Slate)
		box(s1, V(38, 20, 36), CFrame.new(PX, 18, 0), ST1, M.Slate)
		box(s1, V(42, 4, 40), CFrame.new(PX, 30, 0), ST2, M.Slate)
		for _, sz in { -1, 1 } do
			box(s1, V(10, 8, 7), CFrame.new(PX, 36, sz * 14), ST2, M.Slate)
		end
		box(s1, V(18, 3, 8), CFrame.new(PX, 1.5, -26), ST3, M.Slate)

		-- 2 HANDLE: a thick wooden handle (9 x 9) from the pivot (the butt dips below it) with grip bands, leaning at H0
		local s2 = K.stage(m, 2)
		local hm = K.group(s2, "Hammer")
		K.marker(s2, "Pivot", pivot)
		box(hm, V(11, L + 6, 11), frame * CFrame.new(0, (L - 6) / 2, 0), WOOD, M.Wood)
		box(hm, V(13, 4, 13), frame * CFrame.new(0, -3, 0), GOLD, M.Metal) -- butt cap
		for _, y in { 12, 28 } do
			box(hm, V(13, 3, 13), frame * CFrame.new(0, y, 0), WOOD2, M.Wood)
		end

		-- 3 HAMMER HEAD: the absurd sledge head - a 60 x 30 x 40 steel block with a big orange strike cap (local +x) and a smaller
		-- back cap, sitting on the end of the handle
		local s3 = K.stage(m, 3)
		local head = K.group(s3, "Hammer")
		box(head, V(35, 28, 40), frame * CFrame.new(-4.5, L, 0), STEEL, M.Metal)
		box(head, V(14, 32, 44), frame * CFrame.new(20, L, 0), FACE, M.Metal) -- strike cap (its +x side is the strike face, local x 27)
		box(head, V(9, 24, 36), frame * CFrame.new(-26.5, L, 0), STEEL2, M.Metal) -- back cap

		-- 4 IMPACT BASE: a broad slab (56 x 6 x 46) the head will come down on, a low rim and chunky cracked stone blocks
		local s4 = K.stage(m, 4)
		local bx = PX + L + 8
		box(s4, V(48, 6, 46), CFrame.new(bx, 3, 0), ST3, M.Slate)
		box(s4, V(40, 2, 38), CFrame.new(bx, 7, 0), ST1, M.Slate)
		for _, sz in { -1, 1 } do
			box(s4, V(48, 4, 4), CFrame.new(bx, 8, sz * 21), ST2, M.Slate)
		end
		box(s4, V(4, 4, 38), CFrame.new(bx + 22, 8, 0), ST2, M.Slate)
		K.marker(s4, "ImpactPoint", V(PX + L, 8, 0))
		return m
	end,
}
