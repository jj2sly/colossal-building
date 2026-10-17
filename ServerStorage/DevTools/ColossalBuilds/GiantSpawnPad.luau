--!nonstrict
-- GIANT SPAWN PAD (Common). The classic Roblox spawn plate at colossal size: a broad grey studded plate (72 x 72) with
-- oversized studs, chunky low corner blocks and a simple raised square spawn point in the middle (~30 tall when flat).
-- No permanent neon: the cyan shimmer is added by the client show during activation / completion.
--
-- PRESENTATION: while it is being built the whole pad stands TILTED (35 degrees toward the spawn plus a 12 degree roll) resting
-- on ONE lower corner, held by chunky orange construction braces ("Brace" models: two in stage 1, a third with the core in
-- stage 3). The geometry is baked tilted; the TiltRef marker's CFrame is that tilt (T), its "Corner" attribute is the fixed
-- resting corner, so the client show can rotate everything back to the flat authored pose (flat = T:Inverse() * tilted).
-- Authored for BuildConfig Offset (0, 0, 45) so the finishing flip over the front corner stays on the deck. Front faces -Z.
-- Groups for the client show: Pad / Cap / Core (everything that moves with the plate), Brace (temporary supports,
-- attribute Dir = unit vector from the pad down to the deck foot).
return {
	Id = "GiantSpawnPad",
	Build = function(K)
		local V, M, RGB, box, cyl = K.V, K.M, K.RGB, K.box, K.cyl
		local GREY, GREY2, STUD, DARK = RGB(163, 162, 165), RGB(140, 140, 144), RGB(178, 177, 180), RGB(110, 112, 118)
		local ORANGE, ORANGE2 = RGB(226, 126, 40), RGB(176, 92, 30)
		local m = K.template("GiantSpawnPad")

		-- the tilt: rotate about the front-left bottom corner C, which stays exactly where it is (it is the lowest point)
		local C = V(-36, 0, -36)
		local T = CFrame.new(C) * CFrame.Angles(-math.rad(35), 0, 0) * CFrame.Angles(0, 0, math.rad(12)) * CFrame.new(-C)
		local function tilt(stage: Instance)
			for _, d in stage:GetDescendants() do
				if d:IsA("BasePart") then
					d.CFrame = T * d.CFrame
				end
			end
		end
		-- a chunky brace from the deck up to a flat-pad underside point (it meets the underside square on)
		local function brace(stage: Instance, flatPt: Vector3)
			local q = T:PointToWorldSpace(flatPt)
			local down = T:VectorToWorldSpace(V(0, -1, 0))
			local anchor = q + down * (-q.Y / down.Y)
			local g = K.group(stage, "Brace")
			g:SetAttribute("Dir", (anchor - q).Unit)
			K.bar(g, anchor + V(0, 1, 0), q - down * 1.5, 6, ORANGE, M.Metal)
			box(g, V(13, 2.5, 13), CFrame.new(q + down * 1.2) * T.Rotation, ORANGE2, M.Metal) -- cap plate on the underside
			box(g, V(14, 3, 14), CFrame.new(anchor.X, 1.5, anchor.Z), ORANGE2, M.Metal) -- foot on the deck
		end

		-- 1 STUDDED BASE: the broad classic grey plate with a 5 x 5 grid of oversized studs (the middle 3 x 3 left clear),
		-- standing tilted on its corner with two braces
		local s1 = K.stage(m, 1)
		local p1 = K.group(s1, "Pad")
		box(p1, V(72, 6, 72), CFrame.new(0, 3, 0), DARK, M.SmoothPlastic)
		box(p1, V(70, 1.2, 70), CFrame.new(0, 6.6, 0), GREY, M.SmoothPlastic)
		for i = -2, 2 do
			for j = -2, 2 do
				if math.max(math.abs(i), math.abs(j)) == 2 then
					cyl(p1, 11, 4, CFrame.new(i * 14, 9.2, j * 14), STUD, M.SmoothPlastic)
				end
			end
		end
		tilt(s1)
		brace(s1, V(-20, 0, 24))
		brace(s1, V(22, 0, 0))
		local ref = K.marker(s1, "TiltRef", C)
		ref.CFrame = T
		ref:SetAttribute("Corner", C)

		-- 2 CORNER FRAMING: four chunky low corner blocks, each with one big stud on top (the plate's outline)
		local s2 = K.stage(m, 2)
		local p2 = K.group(s2, "Pad")
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				box(p2, V(12, 6, 12), CFrame.new(sx * 30, 10.2, sz * 30), GREY2, M.SmoothPlastic)
				local cap = K.group(s2, "Cap")
				cyl(cap, 9, 3, CFrame.new(sx * 30, 14.7, sz * 30), STUD, M.SmoothPlastic)
			end
			box(p2, V(48, 2, 3), CFrame.new(0, 8.2, sx * 34.5), GREY2, M.SmoothPlastic)
			box(p2, V(3, 2, 48), CFrame.new(sx * 34.5, 8.2, 0), GREY2, M.SmoothPlastic)
		end
		tilt(s2)

		-- 3 CENTRAL SPAWN POINT: a stepped square plinth with a studded top plate (the spot you spawn on), attached to the
		-- tilted plate; a third brace takes its weight
		local s3 = K.stage(m, 3)
		local p3 = K.group(s3, "Pad")
		box(p3, V(30, 9, 30), CFrame.new(0, 11.7, 0), DARK, M.SmoothPlastic)
		box(p3, V(23, 8, 23), CFrame.new(0, 20.2, 0), GREY, M.SmoothPlastic)
		local core = K.group(s3, "Core")
		box(core, V(19, 1.2, 19), CFrame.new(0, 24.8, 0), STUD, M.SmoothPlastic)
		cyl(core, 12, 4, CFrame.new(0, 27.4, 0), STUD, M.SmoothPlastic)
		K.marker(core, "CoreTop", V(0, 30, 0))
		tilt(s3)
		brace(s3, V(2, 0, -20))
		return m
	end,
}
