--!nonstrict
-- ANCIENT COLOSSUS (Legendary). A statue as architecture: a weathered stone giant (authored ~232 tall; BuildConfig TemplateScale
-- 0.9 -> ~209) on a stepped pedestal, facing -Z. Monumental feet in a wide, uneven stance; thick structural legs; a huge broad
-- trapezoid torso; enormous stepped shoulder blocks; a deliberately small helmeted head. Asymmetric: the left arm hangs and rests
-- on a giant tower shield planted on the pedestal, the right arm (heavier, bronze-cuffed) grips a colossal sword whose point rests
-- on the pedestal out to the right front. The whole upper body is twisted 8 degrees toward the sword side.
-- Groups for the client show: Head (marker Neck), ArmR (upper arm, forearm, fist and the Sword; marker ShoulderR), Eye, Core,
-- Crack (stone crack lines that glow), Rune (shield/pedestal runes).
return {
	Id = "AncientColossus",
	Build = function(K)
		local V, M, RGB, box, cyl, cylZ, ell, wedge = K.V, K.M, K.RGB, K.box, K.cyl, K.cylZ, K.ell, K.wedge
		local STONE, STONE2, STONE3, MOSS = RGB(140, 136, 126), RGB(116, 112, 104), RGB(92, 88, 84), RGB(98, 112, 80)
		local BRONZE, BRONZE2, DARK, GLOW0 = RGB(146, 108, 62), RGB(116, 84, 50), RGB(52, 50, 50), RGB(70, 58, 44)
		local m = K.template("AncientColossus")
		local AWAY = V(0, 0, -1)
		local TWIST = math.rad(8)
		local function limb(parent: Instance, a: Vector3, b: Vector3, w: number, d: number, col: Color3, mat)
			return box(parent, V(w, d, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b, AWAY), col, mat)
		end
		local function flank(parent: Instance, size: Vector3, c: Vector3, s: number, col: Color3)
			local Z, Y = V(-s, 0, 0), V(0, -1, 0)
			return wedge(parent, size, CFrame.fromMatrix(c, Y:Cross(Z), Y, Z), col, M.Slate)
		end

		-- 1 MONUMENTAL PEDESTAL / FEET: a stepped stone pedestal and two monumental feet in a wide, uneven stance
		local s1 = K.stage(m, 1)
		box(s1, V(132, 8, 100), CFrame.new(4, 4, -4), STONE3, M.Slate)
		box(s1, V(112, 8, 84), CFrame.new(4, 12, -4), STONE2, M.Slate)
		for _, f in { { -28, -10 }, { 28, 6 } } do
			box(s1, V(32, 16, 46), CFrame.new(f[1], 24, f[2]), STONE, M.Slate)
			wedge(s1, V(32, 10, 12), CFrame.new(f[1], 21, f[2] - 29), STONE2, M.Slate)
		end
		local rune = K.group(s1, "Rune")
		box(rune, V(40, 3, 0.6), CFrame.new(4, 12, -46.3), GLOW0, M.SmoothPlastic)

		-- 2 LEGS: thick structural legs (28-32 wide) with blocky knees; a clear gap between them
		local s2 = K.stage(m, 2)
		for _, f in { { -28, -10, -6 }, { 28, 6, 6 } } do
			box(s2, V(34, 50, 34), CFrame.new(f[1], 57, f[2] * 0.6), STONE, M.Slate)
			box(s2, V(36, 14, 18), CFrame.new(f[1], 84, f[2] * 0.4 - 11), STONE2, M.Slate)
			box(s2, V(38, 44, 38), CFrame.new(f[1], 112, f[3]), STONE, M.Slate)
		end

		-- 3 PELVIS / LOWER TORSO: a heavy pelvis block and a stone kilt of three hanging plates
		local s3 = K.stage(m, 3)
		box(s3, V(90, 22, 42), CFrame.new(0, 141, 0), STONE2, M.Slate)
		for _, x in { -22, 0, 22 } do
			box(s3, V(22, 26, 5), CFrame.new(x, 128, -22) * CFrame.Angles(math.rad(-6), 0, 0), STONE3, M.Slate)
		end

		-- 4 FULL TORSO: a huge broad trapezoid torso (waist 52 -> chest 120) with a chest cavity for the core
		local s4 = K.stage(m, 4)
		box(s4, V(52, 52, 42), CFrame.new(0, 178, 0), STONE, M.Slate)
		for _, sx in { -1, 1 } do
			flank(s4, V(42, 52, 34), V(sx * 43, 178, 0), sx, STONE)
		end
		box(s4, V(124, 16, 46), CFrame.new(0, 210, 0), STONE2, M.Slate)
		box(s4, V(20, 22, 2), CFrame.new(0, 186, -21.4), DARK, M.Slate)

		-- 5 FIRST ARM (LEFT): hangs down and rests on a giant tower shield planted on the pedestal
		local s5 = K.stage(m, 5)
		do
			local S, E, W = V(-66, 204, 0), V(-76, 162, -8), V(-80, 128, -30)
			limb(s5, S, E, 30, 32, STONE, M.Slate)
			ell(s5, V(30, 26, 30), CFrame.new(E), STONE2, M.Slate)
			limb(s5, E, W, 30, 32, STONE, M.Slate)
			box(s5, V(26, 22, 26), CFrame.new(W + V(0, -6, -4)), STONE2, M.Slate)
			box(s5, V(52, 104, 10), CFrame.new(-80, 68, -40), STONE2, M.Slate) -- the tower shield, face to the front
			box(s5, V(56, 8, 12), CFrame.new(-80, 116, -40), BRONZE2, M.Metal)
			box(s5, V(56, 8, 12), CFrame.new(-80, 20, -40), BRONZE2, M.Metal)
			local rr = K.group(s5, "Rune")
			box(rr, V(20, 20, 1), CFrame.new(-80, 72, -45.6) * CFrame.Angles(0, 0, math.rad(45)), GLOW0, M.SmoothPlastic) -- diamond rune
			box(s5, V(13, 13, 1.2), CFrame.new(-80, 72, -45.8) * CFrame.Angles(0, 0, math.rad(45)), STONE2, M.Slate)
		end

		-- 6 SECOND ARM / WEAPON (RIGHT): a heavier bronze-cuffed arm gripping a colossal sword, its point resting on the pedestal
		-- out to the right front (the hero diagonal)
		local s6 = K.stage(m, 6)
		local armR = K.group(s6, "ArmR")
		do
			local S, E, W = V(66, 204, 0), V(80, 164, -12), V(86, 130, -36)
			limb(armR, S, E, 34, 36, STONE, M.Slate)
			ell(armR, V(34, 30, 34), CFrame.new(E), STONE2, M.Slate)
			limb(armR, E, W, 38, 40, STONE, M.Slate)
			limb(armR, E + (W - E).Unit * 6, E + (W - E).Unit * 18, 42, 44, BRONZE, M.Metal)
			box(armR, V(30, 28, 30), CFrame.new(W + V(0, -6, -4)), STONE2, M.Slate)
			K.marker(armR, "ShoulderR", S)
			local sword = K.group(armR, "Sword")
			local hilt, tip = V(86, 118, -44), V(124, 20, -62)
			local dir = (tip - hilt).Unit
			local bladeStart = hilt + dir * 14
			box(sword, V(24, 6, (tip - bladeStart).Magnitude), CFrame.lookAt((bladeStart + tip) / 2, tip, AWAY), STONE3, M.Slate)
			box(sword, V(6, 7, (tip - bladeStart).Magnitude - 10), CFrame.lookAt((bladeStart + tip) / 2 - dir * 5, tip, AWAY), STONE2, M.Slate) -- fuller ridge
			box(sword, V(60, 10, 12), CFrame.lookAt(hilt + dir * 10, hilt + dir * 11, AWAY), BRONZE, M.Metal) -- crossguard
			limb(sword, hilt - dir * 12, hilt + dir * 8, 9, 9, BRONZE2, M.Metal) -- grip
			ell(sword, V(12, 12, 12), CFrame.new(hilt - dir * 14), BRONZE, M.Metal) -- pommel
		end

		-- 7 HEAD / HELMET: a deliberately small helmeted head (24 wide) with a dark visor slit, cheek guards and a crest
		local s7 = K.stage(m, 7)
		local head = K.group(s7, "Head")
		box(head, V(18, 10, 18), CFrame.new(0, 222, 0), STONE2, M.Slate)
		box(head, V(24, 26, 26), CFrame.new(0, 238, -2), STONE, M.Slate)
		box(head, V(26, 4, 28), CFrame.new(0, 245, -2), BRONZE2, M.Metal)
		local eye = K.group(head, "Eye")
		box(eye, V(18, 3, 1.4), CFrame.new(0, 238, -15.6), DARK, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			box(head, V(4, 16, 14), CFrame.new(sx * 13, 232, -8), STONE2, M.Slate)
		end
		wedge(head, V(6, 12, 30), CFrame.new(0, 257, 0), STONE2, M.Slate)
		K.marker(head, "Neck", V(0, 222, 0))

		-- 8 SHOULDER / BACK STRUCTURES: enormous stepped shoulder blocks (the architectural silhouette) and a stone back plate
		local s8 = K.stage(m, 8)
		for _, sx in { -1, 1 } do
			local big = if sx > 0 then 1.1 else 1
			box(s8, V(40 * big, 26, 50), CFrame.new(sx * 68, 216, 0), STONE2, M.Slate)
			box(s8, V(30 * big, 12, 40), CFrame.new(sx * 70, 235, 0), STONE, M.Slate)
			box(s8, V(42 * big, 4, 52), CFrame.new(sx * 68, 229, 0), MOSS, M.Grass)
		end
		box(s8, V(86, 70, 10), CFrame.new(0, 186, 24), STONE3, M.Slate)

		-- 9 ANCIENT CORE / FINAL WEAPON MASS: the chest core, glowing crack lines down the body and the shield, and a great stone
		-- pommel weight on the sword
		local s9 = K.stage(m, 9)
		local core = K.group(s9, "Core")
		cylZ(core, 14, 2, CFrame.new(0, 186, -22), GLOW0, M.SmoothPlastic)
		for _, c in { { 0, 168, -21.6, 2, 18, 0.3 }, { -14, 196, -21.6, 2, 16, -0.6 }, { 14, 158, -21.6, 2, 20, 0.5 }, { -28, 112, -17.6, 2, 22, -0.3 }, { 28, 60, -9.6, 2, 18, 0.4 } } do
			local g = K.group(s9, "Crack")
			box(g, V(c[4], c[5], 0.8), CFrame.new(c[1], c[2], c[3]) * CFrame.Angles(0, 0, c[6]), GLOW0, M.SmoothPlastic)
		end
		local armR9 = K.group(s9, "ArmR") -- a stage-9 piece of the right arm group: the pommel weight moves with the sword
		local sword9 = K.group(armR9, "Sword")
		ell(sword9, V(18, 18, 18), CFrame.new(V(86, 118, -44) - (V(124, 20, -62) - V(86, 118, -44)).Unit * 16), STONE3, M.Slate)

		-- twist the whole upper body (stages 4..9) toward the sword side, about the vertical axis through the pelvis
		for i = 4, 9 do
			local st = m:FindFirstChild(string.format("Stage_%02d", i))
			for _, d in st:GetDescendants() do
				if d:IsA("BasePart") then
					d.CFrame = CFrame.Angles(0, -TWIST, 0) * d.CFrame
				end
			end
		end
		return m
	end,
}
