--!nonstrict
-- PIRATE SHIP (Rare). A big galleon on a stone dry-dock cradle: ~150 long (bowsprit included), 34 beam, mainmast top ~104.
-- The ship runs along X (bow at -X), its port broadside faces -Z (the spawn; BuildConfig Yaw turns it to a 3/4 view).
-- The hull sweeps: half-beam narrows to the bow, the sheer rises to both ends, plates tumble home above the bilge.
-- Groups for the client show: Sail, Lantern, Cannon (Side, Order attributes; "Muzzle" marker), Flag.
return {
	Id = "PirateShip",
	Build = function(K)
		local V, M, RGB, box, bar, ell, cyl, cylZ, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.ell, K.cyl, K.cylZ, K.wedge
		local HULL, HULL2, WALE = RGB(92, 58, 38), RGB(116, 74, 46), RGB(150, 112, 56)
		local DECK, KEEL, STONE = RGB(150, 112, 74), RGB(70, 46, 32), RGB(124, 120, 114)
		local SAIL, SAIL2, MAST = RGB(226, 214, 186), RGB(212, 198, 168), RGB(98, 66, 44)
		local IRON, RED, GOLD = RGB(44, 44, 50), RGB(150, 46, 40), RGB(204, 160, 60)
		local m = K.template("PirateShip")

		local function halfBeam(x: number): number
			if x < 0 then
				return 17 * math.sqrt(math.max(0.02, 1 - (x / 62) ^ 2))
			end
			return 17 * (1 - 0.3 * (x / 58) ^ 2)
		end
		local function deckY(x: number): number
			-- crescent sheer: the deck sweeps up toward both ends, much higher at the stern than the bow
			return 30 + (if x < 0 then 3.5 else 10) * (x / 60) ^ 2
		end
		local XS = { -49, -35, -21, -7, 7, 21, 35, 49 } -- segment centres (14 long each, -56 .. 56)
		local YK = 8 -- keel top amidships
		local function keelY(x: number): number -- the keel rockers up toward bow and stern (a sweeping bottom line)
			return YK + 10 * (x / 56) ^ 2
		end
		local function bilgeY(x: number): number
			return 19 + 5 * (x / 56) ^ 2
		end
		-- a plate between two points in a YZ section, length L along X, thickness t
		local function plate(parent: Instance, xc: number, a: Vector3, b: Vector3, L: number, t: number, color: Color3, mat: Enum.Material?)
			local d = b - a
			local cf = CFrame.fromMatrix((a + b) / 2, Vector3.xAxis, d.Unit)
			return box(parent, V(L, d.Magnitude, t), cf, color, mat)
		end

		-- 1 KEEL: dry-dock cradle, the keel, stem and sternpost, and the ribs that show the hull to come
		local s1 = K.stage(m, 1)
		for _, x in { -40, -14, 14, 40 } do
			local h = keelY(x) - 2.5
			box(s1, V(8, h, 24), CFrame.new(x, h / 2, 0), STONE, M.Slate)
		end
		for _, x in XS do -- the keel in eight rockered lengths
			local a, b = V(x - 7.4, keelY(x - 7) - 1.5, 0), V(x + 7.4, keelY(x + 7) - 1.5, 0)
			bar(s1, a, b, 3.4, KEEL, M.Wood)
		end
		bar(s1, V(-57, keelY(-56) - 1, 0), V(-66, deckY(-62) + 2, 0), 3.2, KEEL, M.Wood)
		bar(s1, V(57, keelY(56) - 1, 0), V(59, deckY(58) + 4, 0), 3.2, KEEL, M.Wood)
		for _, x in { -42, -21, 0, 21, 42 } do
			local b = halfBeam(x)
			for _, sz in { -1, 1 } do
				bar(s1, V(x, keelY(x), 0), V(x, bilgeY(x), sz * b), 1.8, HULL2, M.Wood)
				bar(s1, V(x, bilgeY(x), sz * b), V(x, deckY(x), sz * b * 0.94), 1.8, HULL2, M.Wood)
			end
		end

		-- 2 LOWER HULL: V-bottom plates from the keel to the bilge, bow and transom closures
		local s2 = K.stage(m, 2)
		for _, x in XS do
			local b = halfBeam(x)
			for _, sz in { -1, 1 } do
				plate(s2, x, V(x, keelY(x) - 1, 0), V(x, bilgeY(x) + 0.5, sz * b), 14.8, 2.2, HULL, M.WoodPlanks)
			end
		end
		-- a bow plate in plan view from (x0, z0) to the stem at (x1, 0), spanning y0..y1
		local function bowPlate(parent: Instance, z0: number, y0: number, y1: number, color: Color3)
			local p0, p1 = V(-56, (y0 + y1) / 2, z0), V(-65, (y0 + y1) / 2, 0)
			local mid = (p0 + p1) / 2
			return box(parent, V(2.2, y1 - y0, (p1 - p0).Magnitude + 1), CFrame.lookAt(mid, mid + (p1 - p0)), color, M.WoodPlanks)
		end
		for _, sz in { -1, 1 } do -- the bow: plates converging on the stem
			bowPlate(s2, sz * halfBeam(-56), keelY(-56) - 1, bilgeY(-56) + 0.5, HULL)
		end
		box(s2, V(2.4, bilgeY(56) - keelY(56) + 2, halfBeam(56) * 2), CFrame.new(57, (bilgeY(56) + keelY(56)) / 2, 0), HULL, M.WoodPlanks)

		-- 3 UPPER DECK / BOW / STERN: tumblehome topsides with a wale, the deck, forecastle, a big stern castle with
		-- windows and lanterns, and the bowsprit
		local s3 = K.stage(m, 3)
		for _, x in XS do
			local b = halfBeam(x)
			local yd = deckY(x)
			for _, sz in { -1, 1 } do
				plate(s3, x, V(x, bilgeY(x), sz * b), V(x, yd + 2.5, sz * b * 0.93), 14.8, 2.2, HULL2, M.WoodPlanks)
				box(s3, V(14.8, 1.6, 1), CFrame.new(x, 21.5, sz * (b * 0.99 + 0.9)), WALE, M.Wood)
			end
			box(s3, V(14.8, 1, b * 2 * 0.9), CFrame.new(x, yd - 0.5, 0), DECK, M.WoodPlanks)
		end
		for _, sz in { -1, 1 } do -- bow topsides
			bowPlate(s3, sz * halfBeam(-56), bilgeY(-56), deckY(-60) + 4, HULL2)
		end
		box(s3, V(18, 8, 18), CFrame.new(-48, deckY(-48) + 4, 0), HULL2, M.WoodPlanks) -- forecastle
		box(s3, V(19, 1, 19), CFrame.new(-48, deckY(-48) + 8.5, 0), DECK, M.WoodPlanks)
		box(s3, V(2.4, deckY(57) + 2 - bilgeY(56), halfBeam(56) * 2 * 0.95), CFrame.new(57, (deckY(57) + 2 + bilgeY(56)) / 2, 0), HULL2, M.WoodPlanks) -- upper transom
		box(s3, V(24, 13, 24), CFrame.new(46, deckY(46) + 6.5, 0), HULL2, M.WoodPlanks) -- stern castle
		box(s3, V(25, 1, 25), CFrame.new(46, deckY(46) + 13.5, 0), DECK, M.WoodPlanks)
		box(s3, V(14, 6, 22), CFrame.new(52, deckY(52) + 17, 0), HULL, M.WoodPlanks) -- poop cabin
		box(s3, V(0.6, 3.4, 18), CFrame.new(58.4, deckY(58) + 7, 0), RGB(60, 70, 84), M.Glass) -- stern windows
		for _, sz in { -1, 1 } do
			box(s3, V(20, 3, 0.6), CFrame.new(46, deckY(46) + 8, sz * 12.4), RGB(60, 70, 84), M.Glass)
		end
		local lanterns = K.group(s3, "Lantern")
		for _, p in { V(59, deckY(59) + 16, -11), V(59, deckY(59) + 16, 11), V(60, deckY(60) + 22, 0) } do
			box(lanterns, V(2.2, 3.2, 2.2), CFrame.new(p), RGB(110, 72, 34), M.Neon, { Lantern = true })
		end
		bar(s3, V(-60, deckY(-60) + 4, 0), V(-90, deckY(-60) + 20, 0), 2.6, MAST, M.Wood) -- bowsprit

		-- 4 MASTS: fore, main (with crow's nest) and mizzen, each with two braced yards
		local s4 = K.stage(m, 4)
		-- yards braced hard round (stylized) so the oversized sails read as big planes from the spawn, which sees the port broadside
		local BRACE = math.rad(48)
		-- { x, masthead, diameter, { lower yard, upper yard }, { lower width, upper width }, lower sail foot }
		local masts = {
			{ -36, 98, 3.8, { 58, 86 }, { 42, 34 }, deckY(-36) + 7 },
			{ 2, 112, 4.4, { 62, 94 }, { 48, 40 }, deckY(2) + 7 },
			{ 36, 92, 3.4, { 66, 86 }, { 34, 28 }, 52 },
		}
		for _, mt in masts do
			local x, top, d = mt[1], mt[2], mt[3]
			local y0 = deckY(x) - 1
			cyl(s4, d, top - y0, CFrame.new(x, (top + y0) / 2, 0), MAST, M.Wood)
			for i, yy in mt[4] do
				box(s4, V(1.6, 1.6, mt[5][i]), CFrame.new(x, yy, 0) * CFrame.Angles(0, BRACE, 0), MAST, M.Wood)
			end
		end
		cyl(s4, 8, 3, CFrame.new(2, 101, 0), MAST, M.WoodPlanks)

		-- 5 MAIN SAILS: six oversized square sails on the braced yards plus two jibs that read broadside
		local s5 = K.stage(m, 5)
		for _, mt in masts do
			local x = mt[1]
			for i, yy in mt[4] do
				local w = mt[5][i] - 2
				local h = if i == 1 then yy - mt[6] else (mt[4][2] - mt[4][1] - 3)
				local sail = K.group(s5, "Sail")
				box(sail, V(0.8, h, w), CFrame.new(x - 1.4, yy - h / 2 - 0.8, 0) * CFrame.Angles(0, BRACE, 0) * CFrame.Angles(0, 0, math.rad(-4)), if i == 1 then SAIL else SAIL2, M.Fabric)
			end
		end
		for k, j in { { -46, 30, 34 }, { -60, 26, 26 } } do -- jibs: triangles from the foremast to the bowsprit
			local jib = K.group(s5, "Sail")
			wedge(jib, V(0.8, j[2], j[3]), CFrame.new(j[1], deckY(-50) + 6 + j[2] / 2 + k * 2, 0) * CFrame.Angles(0, math.rad(90), 0), SAIL, M.Fabric)
		end

		-- 6 CANNONS / BROADSIDE FORM: gun-deck bands, six guns a side and red port lids
		local s6 = K.stage(m, 6)
		for _, x in XS do
			local b = halfBeam(x)
			for _, sz in { -1, 1 } do
				box(s6, V(14.8, 3, 0.8), CFrame.new(x, 25, sz * (b * 0.97 + 1.2)), IRON, M.Wood)
			end
		end
		local order = 0
		for _, x in { -38, -24, -10, 4, 18, 30 } do
			order += 1
			local b = halfBeam(x)
			for _, sz in { -1, 1 } do
				local g = K.group(s6, "Cannon")
				g:SetAttribute("Side", if sz < 0 then "Port" else "Starboard")
				g:SetAttribute("Order", order)
				local zc = sz * (b * 0.97 + 3.4)
				cylZ(g, 2.6, 8, CFrame.new(x, 25, zc), IRON, M.Metal)
				cylZ(g, 3.4, 1.2, CFrame.new(x, 25, zc + sz * 3.6), IRON, M.Metal)
				K.marker(g, "Muzzle", V(x, 25, zc + sz * 4.6), V(0, 0, sz))
				box(s6, V(3.6, 0.6, 3.2), CFrame.new(x, 28.4, sz * (b * 0.97 + 2.4)) * CFrame.Angles(sz * math.rad(-50), 0, 0), RED, M.Wood)
			end
		end

		-- 7 FIGUREHEAD / FLAGS: a gold figurehead, black flags at every masthead, the stern ensign and the shrouds
		local s7 = K.stage(m, 7)
		ell(s7, V(7, 12, 6), CFrame.new(-67, deckY(-62) - 2, 0) * CFrame.Angles(0, 0, math.rad(-30)), GOLD, M.Metal)
		ell(s7, V(6, 6, 6), CFrame.new(-70, deckY(-62) + 4, 0), GOLD, M.Metal)
		for _, mt in masts do
			local flag = K.group(s7, "Flag")
			box(flag, V(16, 10, 0.4), CFrame.new(mt[1] + 8.5, mt[2] - 4, 0), RGB(28, 28, 32), M.Fabric)
			box(flag, V(4, 4, 0.5), CFrame.new(mt[1] + 6.5, mt[2] - 4, 0), RGB(226, 222, 212), M.SmoothPlastic)
		end
		bar(s7, V(58, deckY(58) + 14, 0), V(64, deckY(58) + 30, 0), 0.8, MAST, M.Wood)
		local ens = K.group(s7, "Flag")
		box(ens, V(14, 9, 0.4), CFrame.new(70, deckY(58) + 25, 0), RED, M.Fabric)
		for _, mt in { masts[1], masts[2] } do
			for _, sz in { -1, 1 } do
				local b = halfBeam(mt[1])
				for _, dx in { -5, 5 } do
					bar(s7, V(mt[1] + dx, deckY(mt[1]) + 2, sz * b * 0.9), V(mt[1], mt[4][2] + 2, 0), 0.5, IRON, M.SmoothPlastic)
				end
			end
		end
		return m
	end,
}
