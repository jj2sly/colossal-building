--!nonstrict
-- ORBITAL RING GATEWAY (Mythic). One enormous upright ring facing the spawn (the ring lies in the template XY plane, so the
-- spawn looks straight through it): outer ring 206 across (centre at y 112, bottom ~9 above the deck), 18 thick and 16 deep with
-- a wider flange, held by two colossal C-clamp supports standing OUTSIDE the ring, a separate concentric inner ring (130 across,
-- clearly apart from the outer), a small suspended core in the middle and four power modules on the outer rim. The opening
-- (~156 across inside the outer ring, ~118 inside the inner) stays empty: the open centre is the hero.
-- Groups for the client show: Outer (outer ring segments, each with attribute A = its angle in radians), Inner (inner ring +
-- its four nodes; marker InnerC = ring centre), Core (suspended core, marker CoreC), Tether (the two core tethers), Power (power
-- module glow faces), SupportGlow (support power lights), Crown (crown emitter, marker CrownC).
return {
	Id = "OrbitalRingGateway",
	Build = function(K)
		local V, M, RGB, box, bar, cyl, cylZ, ell, wedge = K.V, K.M, K.RGB, K.box, K.bar, K.cyl, K.cylZ, K.ell, K.wedge
		local HULL, HULL2, HULL3, DARK = RGB(196, 200, 210), RGB(160, 166, 178), RGB(118, 124, 138), RGB(52, 56, 66)
		local CONC, CONC2, ACC, GLOW0 = RGB(140, 140, 136), RGB(112, 112, 110), RGB(214, 170, 60), RGB(36, 58, 78)
		local m = K.template("OrbitalRingGateway")
		local CY = 112 -- ring centre height
		local C = V(0, CY, 0)
		local RO, RI = 103, 65 -- outer ring outer radius / inner ring radius
		local function at(r: number, a: number, z: number?): Vector3
			return C + V(math.cos(a) * r, math.sin(a) * r, z or 0)
		end
		-- a ring segment in the XY plane: tangent along the ring, radial thickness th, depth d (along Z)
		local function seg(parent: Instance, r: number, a: number, n: number, th: number, d: number, col: Color3, mat, z: number?)
			local p = at(r, a, z)
			local len = 2 * r * math.sin(math.pi / n) * 1.04
			return box(parent, V(len, th, d), CFrame.new(p) * CFrame.Angles(0, 0, a + math.pi / 2), col, mat)
		end
		local N = 32
		local RM = RO - 9 -- outer ring centre-line radius

		-- 1 FOUNDATION: a broad stepped plinth under the ring with a paved approach running straight through the gateway
		local s1 = K.stage(m, 1)
		box(s1, V(160, 4, 70), CFrame.new(0, 2, 0), CONC2, M.Concrete)
		box(s1, V(120, 4, 60), CFrame.new(0, 6, 0), CONC, M.Concrete)
		box(s1, V(34, 1, 120), CFrame.new(0, 8.5, -20), DARK, M.Slate) -- the approach through the gate
		for _, sx in { -1, 1 } do
			box(s1, V(26, 10, 46), CFrame.new(sx * 72, 5, 4), CONC2, M.Concrete) -- support footings (inside the deck)
		end

		-- 2 / 3 SUPPORTS: colossal C-clamps outside the ring: a heavy foot block, a raking column up to a lower clamp on the ring,
		-- an upright to a side clamp at mid-height, and a back-stay; power lights on the column
		for i, sx in { -1, 1 } do
			local s = K.stage(m, 1 + i)
			local foot = V(sx * 72, 10, 4)
			box(s, V(26, 32, 44), CFrame.new(foot + V(0, 16, 0)), HULL3, M.Metal)
			local lowA = math.rad(if sx > 0 then -32 else 212)
			local sideA = math.rad(if sx > 0 then 4 else 176)
			local low = at(RO + 6, lowA)
			local side = at(RO + 8, sideA)
			bar(s, foot + V(0, 26, 0), low, 26, HULL2, M.Metal)
			bar(s, foot + V(-sx * 4, 22, 0), side, 18, HULL2, M.Metal)
			box(s, V(16, 30, 30), CFrame.new(low) * CFrame.Angles(0, 0, lowA), HULL3, M.Metal) -- lower clamp
			box(s, V(16, 30, 30), CFrame.new(side) * CFrame.Angles(0, 0, sideA), HULL3, M.Metal) -- side clamp
			bar(s, side + V(0, 0, 12), foot + V(0, 4, 34), 10, HULL3, M.Metal) -- back-stay
			-- Pass 12B: a tall side pylon standing just outside the ring edge (x ~113, y 40..160) so each support reads beyond the
			-- ring from the spawn, with a sloped shoulder cap and a heavy strut down to the foot
			local px = sx * 113
			box(s, V(14, 120, 30), CFrame.new(px, 100, 6), HULL3, M.Metal)
			wedge(s, V(30, 14, 18), CFrame.new(px + sx * 2, 167, 6) * CFrame.Angles(0, math.rad(sx * -90), 0), HULL2, M.Metal)
			bar(s, foot + V(sx * 8, 30, 0), V(px, 46, 6), 14, HULL2, M.Metal)
			local g = K.group(s, "SupportGlow")
			box(g, V(4, 4, 46), CFrame.new(foot + V(-sx * 13.4, 22, 0)), GLOW0, M.SmoothPlastic)
		end

		-- 4 / 5 OUTER RING: 32 heavy segments (lower half, then upper half) with a deeper flange ring of 16 plates on the rim
		for half = 0, 1 do
			local s = K.stage(m, 4 + half)
			local outer = K.group(s, "Outer")
			for i = 0, N - 1 do
				local a = (i + 0.5) / N * math.pi * 2 - math.pi / 2 -- start at the bottom
				local up = math.sin(a) > 0
				if (half == 1) == up then
					local p = seg(outer, RM, a, N, 18, 16, if i % 2 == 0 then HULL else HULL2, M.Metal)
					p:SetAttribute("A", a)
				end
			end
			for i = 0, 15 do
				local a = (i + 0.5) / 16 * math.pi * 2 - math.pi / 2
				if (half == 1) == (math.sin(a) > 0) then
					seg(s, RO + 1, a, 16, 5, 22, HULL3, M.Metal)
				end
			end
		end

		-- 6 OUTER STRUCTURAL BRACES: deep radial ribs on the ring's back face at eight points and a back keel ring of eight beams
		local s6 = K.stage(m, 6)
		for i = 0, 7 do
			local a = i / 8 * math.pi * 2 + math.pi / 8
			box(s6, V(10, 26, 10), CFrame.new(at(RM, a, 12)) * CFrame.Angles(0, 0, a), HULL3, M.Metal)
			seg(s6, RM + 2, a + math.pi / 8, 8, 6, 6, DARK, M.Metal, 16)
		end

		-- 7 INNER RING: a separate concentric ring (130 across) with four large nodes, set a little behind the outer ring
		local s7 = K.stage(m, 7)
		local inner = K.group(s7, "Inner")
		for i = 0, 23 do
			local a = (i + 0.5) / 24 * math.pi * 2
			seg(inner, RI, a, 24, 7, 9, if i % 2 == 0 then HULL else HULL2, M.Metal, -4)
		end
		for i = 0, 3 do
			local a = i * math.pi / 2 + math.pi / 4
			box(inner, V(14, 14, 14), CFrame.new(at(RI, a, -4)) * CFrame.Angles(0, 0, a), ACC, M.Metal)
		end
		K.marker(inner, "InnerC", V(0, CY, -4))

		-- 8 SUSPENDED CORE: a small core (18 across) hanging in the exact centre on two thin tethers from the inner ring
		local s8 = K.stage(m, 8)
		local core = K.group(s8, "Core")
		ell(core, V(18, 18, 18), CFrame.new(C + V(0, 0, -4)), GLOW0, M.SmoothPlastic)
		cylZ(core, 26, 2, CFrame.new(C + V(0, 0, -4)), HULL3, M.Metal)
		K.marker(core, "CoreC", C + V(0, 0, -4))
		local teth = K.group(s8, "Tether")
		bar(teth, C + V(0, 10, -4), C + V(0, RI - 4, -4), 2.4, DARK, M.Metal)
		bar(teth, C + V(0, -10, -4), C + V(0, -RI + 4, -4), 2.4, DARK, M.Metal)

		-- 9 MAJOR POWER MODULES: four big modules on the outer rim (upper diagonals and the two sides), each with a glowing face
		local s9 = K.stage(m, 9)
		for _, deg in { 40, 140, -12, 192 } do
			local a = math.rad(deg)
			local p = at(RO + 12, a)
			box(s9, V(22, 18, 26), CFrame.new(p) * CFrame.Angles(0, 0, a), HULL3, M.Metal)
			local g = K.group(s9, "Power")
			box(g, V(14, 12, 1), CFrame.new(p + V(0, 0, -13.4)) * CFrame.Angles(0, 0, a), GLOW0, M.SmoothPlastic)
		end

		-- 10 GATEWAY CROWN: a keystone crown on top of the ring with two swept fins and the crown emitter
		local s10 = K.stage(m, 10)
		local top = at(RO + 9, math.pi / 2)
		box(s10, V(36, 18, 30), CFrame.new(top), HULL3, M.Metal)
		for _, sx in { -1, 1 } do
			wedge(s10, V(6, 22, 26), CFrame.new(top + V(sx * 20, 12, 0)) * CFrame.Angles(0, math.rad(sx * 90), 0), HULL2, M.Metal)
		end
		local crown = K.group(s10, "Crown")
		ell(crown, V(10, 10, 10), CFrame.new(top + V(0, 14, 0)), GLOW0, M.SmoothPlastic)
		K.marker(crown, "CrownC", top + V(0, 14, 0))
		return m
	end,
}
