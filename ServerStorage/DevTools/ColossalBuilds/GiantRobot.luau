--!nonstrict
-- GIANT ROBOT (Epic). A broad, heavy humanoid mech facing -Z (authored ~190 tall; BuildConfig TemplateScale 0.86 -> ~164):
-- planted oversized feet, thick legs with a clear gap between them, a broad inverted-trapezoid torso (waist 30, chest 82,
-- shoulder pads 138 across), arms hanging in a relaxed A-pose with bent elbows and big forearms, and a readable head.
-- Groups for the client show: Head (marker Neck), UpperArmL/R (marker ShoulderL/R), ForearmL/R (marker ElbowL/R),
-- Core (chest core), Eye (visor). R = +X = the robot's own right.
return {
	Id = "GiantRobot",
	Build = function(K)
		local V, M, RGB, box, cyl, cylZ, ell, wedge = K.V, K.M, K.RGB, K.box, K.cyl, K.cylZ, K.ell, K.wedge
		local STEEL, STEEL2, DARK, JOINT = RGB(120, 128, 142), RGB(98, 106, 120), RGB(56, 60, 68), RGB(72, 76, 86)
		local ACC, CORE, BASE = RGB(214, 150, 40), RGB(40, 70, 84), RGB(78, 80, 86)
		local m = K.template("GiantRobot")
		local AWAY = V(0, 0, -1)
		local LEGEXT = 10 -- the legs are 10 studs (about 13%) longer: everything above them (stages 3..8) is lifted by this
		local NOSHIFT = { NoShift = true }
		-- a limb box from a to b (length along a->b), roll kept so its X stays roughly world X
		local function limb(parent: Instance, a: Vector3, b: Vector3, w: number, d: number, col: Color3, mat)
			return box(parent, V(w, d, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b, AWAY), col, mat)
		end
		-- a side wedge of the inverted-trapezoid torso: vertical face against the core, flat top, slope down-inward
		local function flank(parent: Instance, size: Vector3, c: Vector3, s: number, col: Color3)
			local Z = V(-s, 0, 0)
			local Y = V(0, -1, 0)
			return wedge(parent, size, CFrame.fromMatrix(c, Y:Cross(Z), Y, Z), col, M.Metal)
		end

		-- 1 FEET / BASE: a steel plinth and two huge planted feet (24 x 12 x 36) with sloped toes, heels and ankles
		local s1 = K.stage(m, 1)
		cyl(s1, 100, 3, CFrame.new(0, 1.5, 0), BASE, M.DiamondPlate)
		for _, sx in { -1, 1 } do
			box(s1, V(26, 12, 34), CFrame.new(sx * 22, 9, -2), STEEL2, M.Metal)
			wedge(s1, V(26, 9, 12), CFrame.new(sx * 22, 7.5, -25), ACC, M.Metal)
			box(s1, V(22, 10, 8), CFrame.new(sx * 22, 8, 19), DARK, M.Metal)
			ell(s1, V(16, 10, 16), CFrame.new(sx * 22, 17, 0), JOINT, M.Metal)
		end

		-- 2 LEGS: thick shins and thighs (20 wide), knee blocks and hip joints; 24 studs of open gap between the legs
		local s2 = K.stage(m, 2)
		for _, sx in { -1, 1 } do
			box(s2, V(19, 35, 21), CFrame.new(sx * 22, 35.5, 0), STEEL, M.Metal)
			box(s2, V(21, 10, 12), CFrame.new(sx * 22, 55, -6), ACC, M.Metal)
			box(s2, V(21, 27, 22), CFrame.new(sx * 22, 68.5, 0), STEEL2, M.Metal)
			ell(s2, V(20, 16, 20), CFrame.new(sx * 22, 86, 0), JOINT, M.Metal)
		end

		-- 3 TORSO: pelvis, a narrow waist and the broad inverted-trapezoid chest (core box + sloped flanks + shoulder slab);
		-- the chest core sits in its centre from the start (it is the first thing to wake)
		local s3 = K.stage(m, 3)
		box(s3, V(52, 12, 28), CFrame.new(0, 82, 0), STEEL2, M.Metal)
		box(s3, V(30, 10, 22), CFrame.new(0, 93, 0), JOINT, M.Metal)
		box(s3, V(44, 34, 32), CFrame.new(0, 115, 0), STEEL, M.Metal)
		for _, sx in { -1, 1 } do
			flank(s3, V(32, 34, 17), V(sx * 30, 115, 0), sx, STEEL)
		end
		box(s3, V(82, 8, 34), CFrame.new(0, 135, 0), STEEL2, M.Metal)
		local core = K.group(s3, "Core")
		cylZ(core, 16, 4, CFrame.new(0, 116, -17), CORE, M.SmoothPlastic)

		-- 4 SHOULDERS / UPPER BODY: shoulder joints, oversized shoulder pads (30 x 22 x 34), a collar and the upper back
		local s4 = K.stage(m, 4)
		for _, sx in { -1, 1 } do
			ell(s4, V(18, 18, 18), CFrame.new(sx * 46, 127, 0), JOINT, M.Metal)
			box(s4, V(30, 22, 34), CFrame.new(sx * 54, 136, 0), ACC, M.Metal)
		end
		box(s4, V(26, 6, 24), CFrame.new(0, 142, 0), DARK, M.Metal)
		box(s4, V(56, 20, 14), CFrame.new(0, 126, 20), STEEL2, M.Metal)

		-- 5 ARMS: upper arms hanging out at a slight angle (not a T-pose), elbows bent forward, big forearms and fists
		local s5 = K.stage(m, 5)
		for _, sx in { -1, 1 } do
			local tag = if sx > 0 then "R" else "L"
			local S, E, W = V(sx * 50, 128, 0), V(sx * 56, 98, -2), V(sx * 58, 68, -14)
			local up = K.group(s5, "UpperArm" .. tag)
			limb(up, S, E, 16, 18, STEEL2, M.Metal)
			ell(up, V(17, 15, 17), CFrame.new(E), JOINT, M.Metal)
			K.marker(up, "Shoulder" .. tag, S)
			local fore = K.group(s5, "Forearm" .. tag)
			limb(fore, E, W, 24, 26, STEEL, M.Metal)
			box(fore, V(20, 18, 20), CFrame.lookAt(W + (W - E).Unit * 5, W + (W - E).Unit * 6, AWAY), DARK, M.Metal)
			K.marker(fore, "Elbow" .. tag, E)
		end

		-- 6 HEAD: neck, a big readable head (36 x 26 x 30) with a wide visor, chin plate, ear fins and a crest
		local s6 = K.stage(m, 6)
		local head = K.group(s6, "Head")
		box(head, V(12, 8, 12), CFrame.new(0, 146, 0), JOINT, M.Metal)
		box(head, V(36, 26, 30), CFrame.new(0, 161, -1), STEEL, M.Metal)
		box(head, V(24, 7, 3), CFrame.new(0, 152.5, -16), DARK, M.Metal)
		for _, sx in { -1, 1 } do
			box(head, V(4, 15, 15), CFrame.new(sx * 19.5, 162, 0), ACC, M.Metal)
		end
		wedge(head, V(5, 8, 22), CFrame.new(0, 178, 1), ACC, M.Metal)
		local eye = K.group(head, "Eye")
		box(eye, V(28, 5.5, 1.5), CFrame.new(0, 163, -16.6), CORE, M.SmoothPlastic)
		K.marker(head, "Neck", V(0, 148, 0))

		-- 7 ARMOR / CORE HOUSING: a heavy frame around the chest core, a belly plate, shin and thigh armor, forearm cuffs
		local s7 = K.stage(m, 7)
		box(s7, V(26, 4, 5), CFrame.new(0, 126, -17.5), DARK, M.Metal)
		box(s7, V(26, 4, 5), CFrame.new(0, 106, -17.5), DARK, M.Metal)
		for _, sx in { -1, 1 } do
			box(s7, V(4, 16, 5), CFrame.new(sx * 11, 116, -17.5), DARK, M.Metal)
			box(s7, V(16, 28, 4), CFrame.new(sx * 22, 36, -11.5), ACC, M.Metal, NOSHIFT)
			box(s7, V(17, 20, 4), CFrame.new(sx * 22, 69, -12.5), STEEL, M.Metal, NOSHIFT)
			local tag = if sx > 0 then "R" else "L"
			local E, W = V(sx * 56, 98, -2), V(sx * 58, 68, -14)
			local dirEW = (W - E).Unit
			limb(K.group(s7, "Forearm" .. tag), E + dirEW * 4, E + dirEW * 13, 27, 29, ACC, M.Metal)
		end
		box(s7, V(24, 8, 3), CFrame.new(0, 93, -12.5), ACC, M.Metal)

		-- 8 BACK REACTOR & FINS: a big back reactor with twin exhaust stacks and tall shoulder fins (final silhouette mass)
		local s8 = K.stage(m, 8)
		box(s8, V(46, 36, 16), CFrame.new(0, 116, 24), DARK, M.DiamondPlate)
		for _, sx in { -1, 1 } do
			cyl(s8, 10, 26, CFrame.new(sx * 14, 140, 28), STEEL2, M.Metal)
			box(s8, V(4, 18, 26), CFrame.new(sx * 62, 155, 2), STEEL2, M.Metal)
		end
		for i = 3, 8 do
			for _, d in m:FindFirstChild(string.format("Stage_%02d", i)):GetDescendants() do
				if d:IsA("BasePart") and not d:GetAttribute("NoShift") then
					d.CFrame += V(0, LEGEXT, 0)
				end
			end
		end
		return m
	end,
}
