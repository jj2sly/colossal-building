--!nonstrict
-- GIANT TOOLBOX (Common). A wide, low red toolbox (66 x 26 x 38) with its lid flipped open on a back hinge and three
-- oversized tools (hammer, wrench, saw) standing up out of it. ~66 tall. Front faces -Z (the spawn); the lid is behind the tools.
-- Groups for the client show: Lid (LidHinge marker, 105 degrees open), Hammer, Wrench, Saw (each swayed / bounced).
return {
	Id = "GiantToolbox",
	Build = function(K)
		local V, M, RGB, box = K.V, K.M, K.RGB, K.box
		local DEEP = RGB(112, 24, 26)
		local RED, RED2, INTERIOR, STEEL, STEEL2 = RGB(196, 48, 40), RGB(168, 38, 34), RGB(58, 34, 30), RGB(150, 158, 170), RGB(110, 118, 130)
		local WOOD, ORANGE, GOLD = RGB(168, 116, 62), RGB(236, 132, 40), RGB(214, 170, 58)
		local m = K.template("GiantToolbox")
		local rot = CFrame.Angles

		-- 1 BOX BODY: a hollow box with thick walls, steel corner brackets and a latch on the front
		local s1 = K.stage(m, 1)
		box(s1, V(60, 3, 32), CFrame.new(0, 2.5, 0), INTERIOR, M.SmoothPlastic)
		box(s1, V(66, 26, 3), CFrame.new(0, 13, -17.5), RED, M.SmoothPlastic)
		box(s1, V(66, 26, 3), CFrame.new(0, 13, 17.5), RED2, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			box(s1, V(3, 26, 32), CFrame.new(sx * 31.5, 13, 0), RED2, M.SmoothPlastic)
			for _, sz in { -1, 1 } do
				box(s1, V(7, 28, 7), CFrame.new(sx * 31, 14, sz * 17), STEEL2, M.Metal)
			end
		end
		box(s1, V(66, 3, 4), CFrame.new(0, 25.5, -17), STEEL, M.Metal)
		box(s1, V(12, 9, 2), CFrame.new(0, 19, -19.5), STEEL, M.Metal)
		box(s1, V(5, 3, 2.4), CFrame.new(0, 19, -20.2), GOLD, M.Metal)

		-- 2 LID: flipped open about the back rim (hinge at y 27, z +19), leaning back 15 degrees past vertical
		local s2 = K.stage(m, 2)
		local lid = K.group(s2, "Lid")
		local H = CFrame.new(0, 27, 19) * rot(math.rad(105), 0, 0)
		box(lid, V(66, 3, 38), H * CFrame.new(0, 1.5, -19), DEEP, M.SmoothPlastic)
		box(lid, V(66, 4, 4), H * CFrame.new(0, 2, -36.5), STEEL, M.Metal)
		box(lid, V(8, 4, 30), H * CFrame.new(-26, 3.5, -19), RED, M.SmoothPlastic)
		box(lid, V(8, 4, 30), H * CFrame.new(26, 3.5, -19), RED, M.SmoothPlastic)
		K.marker(lid, "LidHinge", Vector3.new(0, 27, 19))

		-- 3 GIANT TOOLS: a hammer, a wrench and a saw standing up out of the box, leaning apart
		local s3 = K.stage(m, 3)
		local function tool(name: string, x: number, lean: number, y: number?)
			return K.group(s3, name), CFrame.new(x, y or 4, -3) * rot(0, 0, math.rad(lean))
		end
		-- spread wide and leaning outward so each tool has its own patch of sky from the spawn
		local hammer, hb = tool("Hammer", -26, 18)
		box(hammer, V(6, 48, 6), hb * CFrame.new(0, 24, 0), WOOD, M.Wood)
		box(hammer, V(26, 13, 12), hb * CFrame.new(0, 53, 0), STEEL, M.Metal)
		box(hammer, V(8, 13, 10), hb * CFrame.new(-16, 53, 0), STEEL2, M.Metal)
		-- the wrench stands upright in the middle: a long handle and a big open C-jaw with a wide gap
		local CHROME = RGB(188, 196, 208)
		local wrench, wb = tool("Wrench", 0, 0)
		box(wrench, V(8, 42, 5), wb * CFrame.new(0, 21, 0), CHROME, M.Metal)
		box(wrench, V(26, 8, 5), wb * CFrame.new(0, 45, 0), CHROME, M.Metal)
		for _, sx in { -1, 1 } do
			box(wrench, V(8, 18, 5), wb * CFrame.new(sx * 9, 57, 0), CHROME, M.Metal)
		end
		-- the saw leans the other way: blade down in the box, a big orange D-handle up top, coarse teeth on one edge
		local saw, sb = tool("Saw", 30, -34, 18) -- raised so the blade and teeth clear the box rim
		box(saw, V(16, 38, 2.4), sb * CFrame.new(0, 23, 0), CHROME, M.Metal) -- light blade so it separates from the dark lid
		for i = 0, 3 do
			box(saw, V(6, 6, 2.4), sb * CFrame.new(9, 10 + i * 8.5, 0) * rot(0, 0, math.rad(45)), CHROME, M.Metal)
		end
		box(saw, V(18, 4, 6), sb * CFrame.new(0, 44, 0), ORANGE, M.SmoothPlastic)
		box(saw, V(18, 4, 6), sb * CFrame.new(0, 56, 0), ORANGE, M.SmoothPlastic)
		for _, sx in { -1, 1 } do
			box(saw, V(4, 16, 6), sb * CFrame.new(sx * 7, 50, 0), ORANGE, M.SmoothPlastic)
		end
		return m
	end,
}
