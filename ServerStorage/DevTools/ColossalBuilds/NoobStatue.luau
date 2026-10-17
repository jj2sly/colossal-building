--!nonstrict
-- NOOB STATUE (Common). A chunky classic Roblox "noob": blue block torso, green block legs, broad yellow block arms held a
-- little away from the torso and an oversized round yellow head with a simple face, on a stone pedestal. ~66 tall, 48 wide.
-- Front faces -Z (the spawn). Groups for the client show: Head (HeadPivot marker), ArmR / ArmL (ShoulderR / ShoulderL markers).
return {
	Id = "NoobStatue",
	Build = function(K)
		local V, M, RGB, box, cyl = K.V, K.M, K.RGB, K.box, K.cyl
		local STONE, STONE2 = RGB(122, 120, 116), RGB(150, 148, 142)
		local YEL, BLUE, GREEN, BLACK = RGB(246, 205, 52), RGB(34, 112, 190), RGB(52, 140, 66), RGB(26, 26, 30)
		local m = K.template("NoobStatue")

		-- 1 PEDESTAL / FEET: a two-step stone pedestal and the two green feet on it (top of the feet = 12)
		local s1 = K.stage(m, 1)
		-- a broad three-step pedestal (the statue's base reads from spawn), the feet stand on the top step at y 9
		box(s1, V(66, 4, 54), CFrame.new(0, 2, 0), STONE, M.Slate)
		box(s1, V(54, 3, 44), CFrame.new(0, 5.5, 0), STONE2, M.Slate)
		box(s1, V(44, 2, 34), CFrame.new(0, 8, 0), STONE, M.Slate)
		for _, sx in { -1, 1 } do
			box(s1, V(12, 3, 15), CFrame.new(sx * 6.4, 10.5 + 1.5, -1), GREEN, M.SmoothPlastic)
		end

		-- 2 LEGS / TORSO: two thick legs and the wide blue torso (to 50)
		local s2 = K.stage(m, 2)
		for _, sx in { -1, 1 } do
			box(s2, V(12, 16, 11), CFrame.new(sx * 6.4, 12 + 8, 0), GREEN, M.SmoothPlastic)
		end
		box(s2, V(28, 22, 13), CFrame.new(0, 28 + 11, 0), BLUE, M.SmoothPlastic)

		-- 3 ARMS: two broad arms held 2.4 studs away from the torso (clear gaps), shoulder pivots for the show
		local s3 = K.stage(m, 3)
		for _, sx in { -1, 1 } do
			local arm = K.group(s3, if sx > 0 then "ArmR" else "ArmL")
			box(arm, V(9.6, 24, 10.5), CFrame.new(sx * 21, 38, 0), YEL, M.SmoothPlastic)
			K.marker(arm, if sx > 0 then "ShoulderR" else "ShoulderL", V(sx * 21, 49, 0))
		end

		-- 4 HEAD: an oversized round head (18 wide, 17 tall) with the classic smile; top at 67
		local s4 = K.stage(m, 4)
		local head = K.group(s4, "Head")
		cyl(head, 18.5, 17, CFrame.new(0, 58.5, 0), YEL, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			box(head, V(2.6, 4.6, 1.4), CFrame.new(sx * 3.6, 61, -8.1), BLACK, M.SmoothPlastic)
		end
		box(head, V(7, 1.5, 1.4), CFrame.new(0, 55, -8.4), BLACK, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			box(head, V(1.6, 1.8, 1.4), CFrame.new(sx * 4.4, 56.2, -8.2), BLACK, M.SmoothPlastic)
		end
		K.marker(head, "HeadPivot", V(0, 50, 0))
		return m
	end,
}
