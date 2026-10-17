--!strict
-- DELIVERY VFX, drawn locally by every client for every player. A delivery is detected from data the server already
-- replicates: a player's Carry_<Res> / CarryMut attributes dropping while they stand in the deposit zone (the same
-- zone test as DepositService.InZone). No remote, no server change, so deposit logic and economy are untouched.
-- The local player's delivery SOUND stays in GatherController ("Deposited" effect); this controller only adds visuals.
--
-- Per delivery (drops are pooled for CarryFXConfig.Deposit.Window seconds):
--   * motes: a few small pooled parts in the delivered resource's material arc from the hauler to the deck rim
--     (heavy Stone flies low and fast, Power floats high); mutated units fly as glowing motes in the tier colour
--   * impact: the resource's existing Cine.burst kind (Wood / Stone / Metal / Power / Cosmic / Ancient) plus its accent,
--     then the mutation burst (Gold / Diamond / Prismatic) on top, a ring and a short light flash for big or mutated drops
-- Everything scales with amount (log curve), grade and mutation. Other players' deliveries are distance culled,
-- rate limited and drawn smaller, so 25 players unloading at once stays readable.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local ResourceConfig = require(Shared.Config.ResourceConfig)
local MutationConfig = require(Shared.Config.MutationConfig)
local GameConfig = require(Shared.Config.GameConfig)
local CarryFXConfig = require(Shared.Config.CarryFXConfig)
local Lib = script.Parent.Parent.ClientLib
local Cine = require(Lib.Cine)
local UI = require(Lib.UI)

local DepositFXController = {}

local D = CarryFXConfig.Deposit
local TIERS = { "Golden", "Diamond", "Prismatic" } -- CarryMut field order (ResourceService.publish)

type Pending = { amounts: { [string]: number }, tiers: { [string]: number }, timer: boolean }
type Watch = { carry: { [string]: number }, mut: { [string]: { number } }, pending: Pending?, queued: boolean }
local watched: { [Player]: Watch } = {}

-- "Res=g,d,p;Res=g,d,p" -> { Res = { g, d, p } }  (same format CarryVisualController reads)
local function parseMut(str: any): { [string]: { number } }
	local out = {}
	if type(str) == "string" then
		for res, g, d, pr in string.gmatch(str, "(%w+)=(%d+),(%d+),(%d+)") do
			out[res] = { tonumber(g) or 0, tonumber(d) or 0, tonumber(pr) or 0 }
		end
	end
	return out
end

local function snapshot(player: Player): ({ [string]: number }, { [string]: { number } })
	local carry = {}
	for _, id in ResourceConfig.Order do
		carry[id] = player:GetAttribute("Carry_" .. id) or 0
	end
	return carry, parseMut(player:GetAttribute("CarryMut"))
end

local function rootOf(player: Player): BasePart?
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then
		return nil -- a death clears the load; that is not a delivery
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

-- mirror of DepositService.InZone
local function inZone(position: Vector3): boolean
	local site = GameConfig.Site
	local flat = Vector3.new(position.X - site.Center.X, 0, position.Z - site.Center.Z)
	return flat.Magnitude <= site.DepositOuterRadius and position.Y < site.PlatformTopY + 40
end

-- MOTES: a fixed pool of tiny parts animated by one Heartbeat (no tweens, no physics, nothing created per delivery)
type Mote = { part: Part, t0: number, dur: number, a: Vector3, b: Vector3, c: Vector3 }
local free: { Part } = {}
local flying: { Mote } = {}
local HIDE = CFrame.new(0, -10000, 0)

local function newMotePart(): Part
	local p = Instance.new("Part")
	p.Name = "MB_DepositMote"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch = true, false, false, false
	p.CastShadow = false
	p.CFrame = HIDE
	p.Parent = Cine.folder()
	return p
end

local function launchMote(from: Vector3, to: Vector3, arc: number, dur: number, color: Color3, mat: Enum.Material, shape: Enum.PartType, size: number)
	local p = table.remove(free)
	if not p then
		return -- pool exhausted: skip the mote rather than create more
	end
	if not p.Parent then
		p.Parent = Cine.folder()
	end
	p.Shape = shape
	p.Size = Vector3.one * size
	p.Color = color
	p.Material = mat
	p.Transparency = 0
	local mid = (from + to) / 2 + Vector3.new(0, arc, 0)
	table.insert(flying, { part = p, t0 = os.clock(), dur = dur, a = from, b = mid, c = to })
end

local function stepMotes()
	if #flying == 0 then
		return
	end
	local now = os.clock()
	for i = #flying, 1, -1 do
		local m = flying[i]
		local t = (now - m.t0) / m.dur
		if t >= 1 then
			m.part.CFrame = HIDE
			m.part.Transparency = 1
			table.insert(free, m.part)
			table.remove(flying, i)
		elseif t >= 0 then
			local u = 1 - t
			local pos = m.a * (u * u) + m.b * (2 * u * t) + m.c * (t * t) -- quadratic arc
			m.part.CFrame = CFrame.new(pos) * CFrame.Angles(t * 7, t * 5, 0)
		end
	end
end

-- IMPACT FLASH: a few pooled lights
local flashes: { PointLight } = {}
local flashIdx = 0
local function flash(pos: Vector3, color: Color3, brightness: number)
	if brightness <= 0 then
		return
	end
	flashIdx = flashIdx % 4 + 1
	local l = flashes[flashIdx]
	if not l or not l.Parent or not l.Parent.Parent then
		local holder = Instance.new("Part")
		holder.Name = "MB_DepositFlash"
		holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch = true, false, false, false
		holder.Transparency = 1
		holder.Size = Vector3.one
		holder.Parent = Cine.folder()
		l = Instance.new("PointLight")
		l.Shadows = false
		l.Brightness = 0
		l.Parent = holder
		flashes[flashIdx] = l
	end
	local light = l :: PointLight
	local holder = light.Parent :: BasePart
	holder.Position = pos
	light.Color = color
	light.Range = D.FlashRange
	light.Brightness = brightness
	UI.tween(light, D.FlashSeconds, { Brightness = 0 })
end

local activeRings = 0
local function ring(pos: Vector3, color: Color3, size: number)
	if activeRings >= D.MaxRings then
		return
	end
	activeRings += 1
	Cine.ring(pos, color, size, D.RingSeconds)
	task.delay(D.RingSeconds, function()
		activeRings -= 1
	end)
end

-- crowd limiter for OTHER players' deliveries (token bucket)
local tokens, lastRefill = D.MaxPerSecond, os.clock()
local function allowRemote(): boolean
	local now = os.clock()
	tokens = math.min(D.MaxPerSecond, tokens + (now - lastRefill) * D.MaxPerSecond)
	lastRefill = now
	if tokens >= 1 then
		tokens -= 1
		return true
	end
	return false
end

local function tierColor(tier: string): Color3
	if tier == "Prismatic" then
		return Color3.fromHSV(math.random(), 0.45, 1)
	end
	return MutationConfig.Get(tier).Color
end

-- `origin` is where the hauler stands; `isLocal` deliveries skip the crowd limits.
local function play(origin: Vector3, isLocal: boolean, p: Pending)
	local cam = workspace.CurrentCamera
	if not isLocal then
		if cam and (cam.CFrame.Position - origin).Magnitude > D.CullDistance then
			return
		end
		if not allowRemote() then
			return
		end
	end
	-- what was delivered: the resource with the most units sets the identity, the best tier sets the mutation layer
	local total, mainId, mainN = 0, nil :: string?, 0
	for id, n in p.amounts do
		total += n
		if n > mainN then
			mainId, mainN = id, n
		end
	end
	local res = mainId and ResourceConfig.Resources[mainId]
	if not res or total <= 0 then
		return
	end
	local tier: string? = nil
	local tierN = 0
	for _, t in TIERS do
		if (p.tiers[t] or 0) > 0 then
			tier, tierN = t, p.tiers[t]
		end
	end
	local fam = CarryFXConfig.Family(res.Family)
	local mdef = tier and CarryFXConfig.Mutations[tier]
	local scale = CarryFXConfig.DepositScale(total, res.Grade, res.Secret ~= nil) * (if isLocal then 1 else D.RemoteScale)

	-- impact point: the deck rim toward the hauler
	local site = GameConfig.Site
	local flat = Vector3.new(origin.X - site.Center.X, 0, origin.Z - site.Center.Z)
	local dir = if flat.Magnitude > 0.1 then flat.Unit else Vector3.zAxis
	local radius = math.min(D.ImpactRadius, flat.Magnitude)
	local impact = site.Center + dir * radius + Vector3.new(0, site.PlatformTopY + D.ImpactHeight, 0)

	-- motes
	local mc = D.Motes
	local count = math.floor(mc.Min + (mc.Max - mc.Min) * math.clamp(scale, 0, 1) + 0.5)
	local glowing = if mdef and mdef.MoteGlow then math.min(mc.MutatedExtra + math.ceil(count * tierN / total), count + mc.MutatedExtra) else 0
	if mdef and mdef.MoteGlow then
		count += mc.MutatedExtra
	end
	local dur = mc.FlightTime * fam.MoteSpeed
	local from = origin + Vector3.new(0, 3, 0)
	for i = 1, count do
		local glow = i <= glowing and tier ~= nil
		local jitter = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 3
		task.delay((i - 1) * 0.035, launchMote, from + jitter * 0.4, impact + jitter, mc.ArcHeight * fam.MoteArc * (0.8 + math.random() * 0.4), dur,
			if glow then tierColor(tier :: string) else res.Color, if glow then Enum.Material.Neon else fam.MoteMaterial, fam.MoteShape,
			mc.Size * (if glow then 0.8 else 1) * (0.8 + math.random() * 0.4))
	end

	-- impact, timed to the first motes landing
	task.delay(dur, function()
		Cine.burst(impact, fam.Burst, D.BurstScale * scale)
		if fam.Accent then
			Cine.burst(impact, fam.Accent, fam.AccentScale * scale)
		end
		local ringColor = fam.RingColor
		local ringSize = D.RingSize * math.max(0.5, scale)
		if mdef then
			-- the mutation layer: its burst over the resource burst, stronger the more of the delivery was mutated
			local share = math.clamp(tierN / total, 0.25, 1)
			Cine.burst(impact + Vector3.new(0, 1, 0), mdef.Burst, mdef.BurstScale * scale * (0.6 + share))
			flash(impact + Vector3.new(0, 2, 0), MutationConfig.Get(tier).Color, mdef.Flash * math.max(0.5, scale))
			if mdef.Ring then
				ring(impact, tierColor(tier :: string), ringSize * mdef.RingScale)
			end
		elseif ringColor and scale >= D.RingAt then
			ring(impact, ringColor, ringSize)
		end
	end)
end

local function flush(player: Player)
	local w = watched[player]
	local p = w and w.pending
	if not w or not p then
		return
	end
	w.pending = nil
	local root = rootOf(player)
	if root then
		play(root.Position, player == Players.LocalPlayer, p)
	end
end

-- ADMIN TESTING (AdminPanelController "VFX" tab): play a delivery locally without touching any server state.
-- `origin` defaults to the local player; `asRemote` runs it through the other-player culling / rate limit / scale.
function DepositFXController.Preview(resId: string, tier: string?, amount: number, origin: Vector3?, asRemote: boolean?)
	local res = ResourceConfig.Resources[resId]
	if not res or amount <= 0 then
		return
	end
	local root = rootOf(Players.LocalPlayer)
	local from = origin or (root and root.Position)
	if not from then
		return
	end
	local p: Pending = { amounts = { [resId] = amount }, tiers = {}, timer = false }
	if tier and tier ~= "Normal" and CarryFXConfig.Mutations[tier] then
		p.tiers[tier] = amount
	end
	play(from, not asRemote, p)
end

-- Crowd stress test: `n` simulated haulers unloading at random points around the deposit ring over `seconds`.
function DepositFXController.Stress(n: number, seconds: number)
	local site = GameConfig.Site
	local ids = ResourceConfig.Order
	for i = 1, n do
		task.delay(math.random() * seconds, function()
			local a = math.random() * math.pi * 2
			local r = site.DepositOuterRadius - 6
			local origin = site.Center + Vector3.new(math.cos(a) * r, site.PlatformTopY + 1, math.sin(a) * r)
			local roll = math.random()
			local tier = if roll < 0.04 then "Prismatic" elseif roll < 0.12 then "Diamond" elseif roll < 0.35 then "Golden" else nil
			DepositFXController.Preview(ids[math.random(1, #ids)], tier, math.random(10, 120), origin, i ~= 1)
		end)
	end
end

local function diff(player: Player)
	local w = watched[player]
	if not w then
		return
	end
	local carry, mut = snapshot(player)
	local root = rootOf(player)
	if root and inZone(root.Position) then
		for id, old in w.carry do
			local drop = old - (carry[id] or 0)
			if drop > 0 then
				local p = w.pending or { amounts = {}, tiers = {}, timer = false }
				w.pending = p
				p.amounts[id] = (p.amounts[id] or 0) + drop
				local om, nm = w.mut[id], mut[id]
				if om then
					for k, t in TIERS do
						local md = om[k] - (if nm then nm[k] else 0)
						if md > 0 then
							p.tiers[t] = (p.tiers[t] or 0) + md
						end
					end
				end
				if not p.timer then
					p.timer = true
					task.delay(D.Window, flush, player)
				end
			end
		end
	end
	w.carry, w.mut = carry, mut
end

local function watch(player: Player)
	local carry, mut = snapshot(player)
	local w: Watch = { carry = carry, mut = mut, pending = nil, queued = false }
	watched[player] = w
	-- Carry_<Res>, CarryTotal and CarryMut change together on every deposit tick: one diff per frame per player
	player.AttributeChanged:Connect(function(attr)
		if (string.sub(attr, 1, 6) == "Carry_" or attr == "CarryMut") and not w.queued then
			w.queued = true
			task.defer(function()
				w.queued = false
				diff(player)
			end)
		end
	end)
end

function DepositFXController.Start()
	if not CarryFXConfig.Enabled then
		return
	end
	for _ = 1, D.Motes.Pool do
		table.insert(free, newMotePart())
	end
	RunService.Heartbeat:Connect(stepMotes)
	Players.PlayerAdded:Connect(watch)
	for _, p in Players:GetPlayers() do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		watched[p] = nil
	end)
end

return DepositFXController
