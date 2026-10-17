--!nonstrict
-- MEDIEVAL SIEGE TOWER (Uncommon). A broad timber tower (about 58 x 50 x 100) on four oversized wheels (26 across), an
-- enclosed lower body, an open timber frame above it, a battlemented fighting platform and a big drawbridge standing raised
-- on the front. Front (and the bridge's drop) faces -Z, the spawn. The bridge, once dropped, reaches 40 studs out.
-- Authored for BuildConfig Offset (0, 0, 19) so the dropped bridge stays on the deck.
-- Groups for the client show: Wheel (one per wheel, marker WheelC at its centre), Bridge (marker BridgeHinge).
return {
	Id = "SiegeTower",
	Build = function(K)
		local V, M, RGB, box, bar, cyl = K.V, K.M, K.RGB, K.box, K.bar, K.cyl
		local TIM, TIM2, PLANK, IRON = RGB(122, 84, 50), RGB(92, 60, 38), RGB(154, 108, 62), RGB(66, 68, 76)
		local STONE, RED, GOLD = RGB(128, 124, 118), RGB(176, 48, 40), RGB(214, 170, 58)
		local m = K.template("SiegeTower")
		local rot = CFrame.Angles
		local PX, PZ = 22, 18 -- post positions
		local SLAB, POSTB, POSTT = 32, 32, 86

		-- 1 WHEELS / BASE: four huge wheels (26 across, 6 thick) with iron cross spokes and a heavy timber base slab on axle beams
		local s1 = K.stage(m, 1)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				local w = K.group(s1, "Wheel")
				local c = V(sx * 35, 16, sz * 16)
				cyl(w, 32, 7, CFrame.new(c) * rot(0, 0, math.rad(90)), TIM, M.Wood)
				cyl(w, 11, 9, CFrame.new(c + V(sx * 1, 0, 0)) * rot(0, 0, math.rad(90)), IRON, M.Metal)
				box(w, V(1.6, 30, 6), CFrame.new(c + V(sx * 3.9, 0, 0)), IRON, M.Metal)
				box(w, V(1.6, 6, 30), CFrame.new(c + V(sx * 3.9, 0, 0)), IRON, M.Metal)
				K.marker(w, "WheelC", c)
			end
			box(s1, V(72, 5, 5), CFrame.new(0, 16, sx * 16), TIM2, M.Wood) -- axle beams
		end
		box(s1, V(62, 8, 52), CFrame.new(0, 28, 0), PLANK, M.WoodPlanks)
		box(s1, V(66, 2.4, 56), CFrame.new(0, 32.2, 0), TIM2, M.Wood)

		-- 2 TOWER FRAME: four thick corner posts to y 86, ring beams at y 58 and 84, X braces in the side and back frames
		local s2 = K.stage(m, 2)
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(s2, V(7, POSTT - POSTB, 7), CFrame.new(sx * PX, (POSTT + POSTB) / 2, sz * PZ), TIM, M.Wood)
			end
		end
		for _, y in { 58, 84 } do
			for _, s in { -1, 1 } do
				box(s2, V(2 * PX + 7, 5, 5), CFrame.new(0, y, s * PZ), TIM2, M.Wood)
				box(s2, V(5, 5, 2 * PZ + 7), CFrame.new(s * PX, y, 0), TIM2, M.Wood)
			end
		end
		for _, s in { -1, 1 } do -- X braces between the beams (side planes) and in the back plane
			bar(s2, V(s * PX, 58, -PZ), V(s * PX, 84, PZ), 3.4, TIM2, M.Wood)
			bar(s2, V(s * PX, 58, PZ), V(s * PX, 84, -PZ), 3.4, TIM2, M.Wood)
		end
		bar(s2, V(-PX, 58, PZ), V(PX, 84, PZ), 3.4, TIM2, M.Wood)
		bar(s2, V(PX, 58, PZ), V(-PX, 84, PZ), 3.4, TIM2, M.Wood)

		-- 3 ENCLOSED BODY: planked walls on the lower level (y 34 .. 58) with a front entrance, and a floor at y 58
		local s3 = K.stage(m, 3)
		local WY0, WY1 = 34, 58
		box(s3, V(2 * PX + 8, WY1 - WY0, 3), CFrame.new(0, (WY0 + WY1) / 2, PZ + 1), PLANK, M.WoodPlanks) -- back
		for _, s in { -1, 1 } do
			box(s3, V(3, WY1 - WY0, 2 * PZ + 8), CFrame.new(s * (PX + 1), (WY0 + WY1) / 2, 0), PLANK, M.WoodPlanks)
			box(s3, V(14, WY1 - WY0, 3), CFrame.new(s * 17.5, (WY0 + WY1) / 2, -PZ - 1), PLANK, M.WoodPlanks) -- front sides of the entrance
		end
		box(s3, V(22, 14, 3), CFrame.new(0, 51, -PZ - 1), PLANK, M.WoodPlanks) -- lintel over the door (y 44 .. 58)
		box(s3, V(2 * PX + 4, 3, 2 * PZ + 4), CFrame.new(0, 59.5, 0), TIM, M.Wood)
		for _, y in { 40, 52 } do
			box(s3, V(2 * PX + 9, 2.4, 2 * PZ + 9), CFrame.new(0, y, 0), TIM2, M.Wood) -- iron-banded timber courses
		end

		-- 4 UPPER PLATFORM: an overhanging fighting platform on the frame (62 x 5 x 56) with chunky battlements, to y 99
		local s4 = K.stage(m, 4)
		box(s4, V(62, 5, 56), CFrame.new(0, 88.5, 0), PLANK, M.WoodPlanks)
		box(s4, V(66, 3, 60), CFrame.new(0, 85.5, 0), TIM2, M.Wood)
		for _, ox in { -26, -9, 9, 26 } do
			for _, oz in { -1, 1 } do
				box(s4, V(10, 9, 6), CFrame.new(ox, 95.5, oz * 26), TIM, M.Wood)
			end
		end
		for _, ox in { -1, 1 } do
			for _, oz in { -17, 0, 17 } do
				box(s4, V(6, 9, 10), CFrame.new(ox * 29, 95.5, oz), TIM, M.Wood)
			end
		end
		box(s4, V(4, 10, 4), CFrame.new(-26, 104, 0), IRON, M.Metal) -- a flag pole + red pennant
		box(s4, V(15, 8, 0.8), CFrame.new(-18, 105, 0), RED, M.Fabric)

		-- 5 DRAWBRIDGE: a big raised bridge (30 x 40 x 4) standing on its hinge at the front of the tower; it drops 90 degrees
		-- toward the spawn (-Z). Hinge (0, 40, -24).
		local s5 = K.stage(m, 5)
		local br = K.group(s5, "Bridge")
		local HZ = -25
		box(br, V(30, 40, 4), CFrame.new(0, 60, HZ - 1), PLANK, M.WoodPlanks)
		for _, y in { 46, 60, 74 } do
			box(br, V(32, 3.4, 5.4), CFrame.new(0, y, HZ - 1.2), IRON, M.Metal)
		end
		for _, sx in { -1, 1 } do
			box(br, V(3.4, 40, 6), CFrame.new(sx * 15, 60, HZ - 1), TIM2, M.Wood)
			bar(br, V(sx * 15, 76, HZ - 4), V(sx * 22, 86, -PZ - 3), 1.6, IRON, M.Metal) -- chain up to the tower top
		end
		K.marker(br, "BridgeHinge", V(0, 40, HZ))
		box(s5, V(34, 3, 6), CFrame.new(0, 40, HZ + 2), IRON, M.Metal) -- the hinge beam
		return m
	end,
}
