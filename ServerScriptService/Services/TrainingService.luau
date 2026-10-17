--!strict
-- CHARACTER TRAINING (server-authoritative). Strength and Speed are earned at the Training Yard.
--
--   PASSIVE (hands-off, lower XP/min)    Treadmill (tag "TrainingTreadmill", Speed) and Bench Press
--                                        (tag "TrainingBench", Strength): use the machine and the
--                                        character is held in place and trained automatically.
--   ACTIVE (real play, better XP/min)    Race Track (tag "TrainingGate", attribute GateIndex, Speed):
--                                        pass the gates in order. Crate Lift (tags "CrateStack" ->
--                                        "CratePallet") and Beam Carry ("BeamStack" -> "BeamPallet",
--                                        attribute Lane pairs them), Strength: carry a heavy prop
--                                        between two marked points.
--
-- Everything pays training points through ONE award() function: shared stamina and a hard XP-per-minute
-- ceiling apply to every station, and XP is only ever granted by the server (clients just ask to start / stop).
-- Anti-abuse: passive sessions need proximity and an unmoved pose, deliveries need a minimum travel time,
-- laps are speed- and order-checked. All numbers: TrainingConfig.
-- Points persist in PlayerData.Training; levels (derived) replicate as StrengthLevel / SpeedLevel.
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local TrainingConfig = require(Shared.Config.TrainingConfig)
local MasterBuilderConfig = require(Shared.Config.MasterBuilderConfig)

local TrainingService = {}
local S: any

type Session = {
	kind: string, -- "Treadmill" | "Bench"
	part: BasePart,
	hrp: BasePart,
	pose: CFrame,
	nextTick: number,
	xp: number,
	mult: number?,
}
type Carry = { kind: string, lane: number, prop: BasePart, pickedAt: number, from: Vector3, baseSpeed: number }
type RunState = { next: number, start: number, lapStart: number?, lastT: number, lastPos: Vector3, warned: number } -- start = the gate this lap began at (any gate)

local sessions: { [Player]: Session } = {}
local carries: { [Player]: Carry } = {}
local runStates: { [Player]: RunState } = {}
local stamina: { [Player]: { value: number, t: number } } = {}
local xpWindow: { [Player]: { [string]: { { t: number, xp: number } } } } = {}
local gates: { BasePart } = {}
local cfgTread = TrainingConfig.Treadmill
local cfgBench = TrainingConfig.Bench
local cfgCrate = TrainingConfig.Crate
local cfgBeam = TrainingConfig.Beam
local cfgRun = TrainingConfig.Run
local cfgSta = TrainingConfig.Stamina

local function now(): number
	return workspace:GetServerTimeNow()
end

function TrainingService.Init(registry)
	S = registry
end

------------------------------------------------------------------ data helpers
local function data(player: Player): any?
	return S.PlayerDataService.Get(player)
end

function TrainingService.Level(player: Player, statId: string): number
	local d = data(player)
	return d and TrainingConfig.Level(statId, d.Training[statId] or 0) or 0
end

local function publishLevels(player: Player)
	player:SetAttribute("StrengthLevel", TrainingService.Level(player, "Strength"))
	player:SetAttribute("SpeedLevel", TrainingService.Level(player, "Speed"))
end

TrainingService.PublishLevels = publishLevels

local function effectsChanged(player: Player, statId: string)
	if statId == "Strength" then
		S.ResourceService.RefreshCapacity(player)
	else
		S.UpgradeService.RefreshMovement(player)
	end
end

------------------------------------------------------------------ stamina
local function currentStamina(player: Player): number
	local s = stamina[player]
	if not s then
		return 0
	end
	return math.max(0, s.value - cfgSta.RecoveryPerSecond * (now() - s.t))
end

local function addStamina(player: Player, amount: number)
	local v = math.min(1, currentStamina(player) + amount)
	stamina[player] = { value = v, t = now() }
	player:SetAttribute("Fatigue", math.floor(v * 20 + 0.5) / 20)
end

local function xpMultiplier(player: Player): number
	return math.clamp(1 - currentStamina(player), cfgSta.MinMultiplier, 1)
end

------------------------------------------------------------------ XP
-- Level milestones (TrainingConfig.Milestones): a toast the first time a level is reached, plus an optional title / cosmetic.
local function checkMilestones(player: Player, statId: string, before: number, after: number)
	local d = data(player)
	local list = TrainingConfig.Milestones[statId]
	if not d or not list or after <= before then
		return
	end
	d.TrainingMilestones = d.TrainingMilestones or {}
	for level = before + 1, after do
		local m = list[level]
		local key = statId .. level
		if m and not d.TrainingMilestones[key] then
			d.TrainingMilestones[key] = true
			if m.Title then
				S.CosmeticService.Grant(player, "Title", m.Title, "Training")
			end
			if m.Cosmetic then
				S.CosmeticService.Grant(player, m.Cosmetic.Category, m.Cosmetic.Item, "Training")
			end
			Net.Event("Notify"):FireClient(player, "Success", m.Text .. (if m.Title then "  (title: " .. m.Title .. ")" else ""), if m.Big then 8 else 4.5)
			Net.Event("Effect"):FireClient(player, "TrainingMilestone", { Stat = statId, Level = level, Big = m.Big == true })
			if m.Big then
				Net.Event("Notify"):FireAllClients("Success", string.format("%s reached %s!", player.DisplayName, m.Text), 6)
			end
			S.PlayerDataService.MarkDirty(player)
		end
	end
end

-- Adds `xp` points to a stat, levels up, publishes. (Shared by dedicated training and natural XP.)
local function applyXP(player: Player, statId: string, xp: number)
	local d = data(player)
	if not d then
		return
	end
	local before = TrainingConfig.Level(statId, d.Training[statId] or 0)
	d.Training[statId] = (d.Training[statId] or 0) + xp
	local after = TrainingConfig.Level(statId, d.Training[statId])
	if after > before then
		publishLevels(player)
		effectsChanged(player, statId)
		S.PlayerDataService.MarkDirty(player)
		local def = TrainingConfig.Stats[statId]
		Net.Event("Notify"):FireClient(player, "Success", string.format("%s level %d! %s is now %s", def.DisplayName, after, def.EffectLabel, tostring(math.floor(TrainingConfig.Effect(statId, after) * 10 + 0.5) / 10)), 3.5)
		Net.Event("Effect"):FireClient(player, "UpgradeBought", { Id = statId, Level = after })
		checkMilestones(player, statId, before, after)
	else
		S.PlayerDataService.MarkDirty(player, true)
	end
end

-- permanent Master Builder rank bonus x any XP boost
local function xpBonus(player: Player): number
	return (1 + MasterBuilderConfig.TrainingXPBonus(S.UpgradeService.MasterRank(player))) * S.BoostService.Mult(player, "Training")
end

-- Returns the XP actually granted (after stamina and the per-minute ceiling). DEDICATED training only.
local function award(player: Player, statId: string, baseXP: number): number
	local d = data(player)
	if not d then
		return 0
	end
	local t = os.clock()
	local windows = xpWindow[player]
	if not windows then
		windows = {}
		xpWindow[player] = windows
	end
	local list = windows[statId]
	if not list then
		list = {}
		windows[statId] = list
	end
	local recent = 0
	for i = #list, 1, -1 do
		if t - list[i].t > 60 then
			table.remove(list, i)
		else
			recent += list[i].xp
		end
	end
	local xp = baseXP * xpMultiplier(player) * xpBonus(player)
	xp = math.min(xp, math.max(0, cfgSta.MaxXPPerMinute[statId] - recent))
	if xp < 0.2 then
		return 0
	end
	xp = math.floor(xp * 10 + 0.5) / 10
	table.insert(list, { t = t, xp = xp })
	if S.TelemetryService then
		S.TelemetryService.Record("Train", player, statId, xp)
	end
	applyXP(player, statId, xp)
	return xp
end

------------------------------------------------------------------ natural XP
-- A small trickle from normal play: hauling on foot (Strength) and real distance travelled on foot (Speed). Never fatiguing,
-- never from vehicles or while training at a machine, with its own low per-minute ceiling. Dedicated training stays far faster.
local naturalWindow: { [Player]: { [string]: { t0: number, xp: number } } } = {}
local nav: { [Player]: { last: Vector3, anchor: Vector3, path: number } } = {}

local function naturalGrant(player: Player, statId: string, baseXP: number): number
	local cfg = TrainingConfig.Natural[statId]
	local t = os.clock()
	local w = naturalWindow[player]
	if not w then
		w = {}
		naturalWindow[player] = w
	end
	local rec = w[statId]
	if not rec or t - rec.t0 > 60 then
		rec = { t0 = t, xp = 0 }
		w[statId] = rec
	end
	local xp = math.min(baseXP * xpBonus(player), cfg.MaxPerMinute - rec.xp)
	if xp <= 0 then
		return 0
	end
	rec.xp += xp
	applyXP(player, statId, xp)
	return xp
end

-- Called by DepositService after units are delivered on foot.
function TrainingService.NaturalDeliver(player: Player, units: number)
	if player:GetAttribute("Driving") then
		return
	end
	naturalGrant(player, "Strength", TrainingConfig.Natural.Strength.DeliverXPPerUnit * units)
end

-- Debug/test hook: add raw points (no stamina or caps).
function TrainingService.AddPoints(player: Player, statId: string, points: number)
	local d = data(player)
	if not d or not TrainingConfig.Stats[statId] then
		return
	end
	local max = TrainingConfig.PointsFor(statId, TrainingConfig.Stats[statId].MaxLevel)
	local before = TrainingConfig.Level(statId, d.Training[statId] or 0)
	d.Training[statId] = math.clamp((d.Training[statId] or 0) + points, 0, max)
	checkMilestones(player, statId, before, TrainingConfig.Level(statId, d.Training[statId]))
	publishLevels(player)
	effectsChanged(player, statId)
	S.PlayerDataService.MarkDirty(player)
end

------------------------------------------------------------------ stations
local function send(player: Player, msg: any)
	Net.Event("TrainingUpdate"):FireClient(player, msg)
end

local function notify(player: Player, kind: string, text: string)
	Net.Event("Notify"):FireClient(player, kind, text, 3)
end

local function bodyOf(player: Player): (BasePart?, Humanoid?)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hrp and hum and hum.Health > 0 then
		return hrp, hum
	end
	return nil, nil
end

-- One pass per second over players (cheap: a few attribute reads and one distance each).
local function naturalTick()
	local cs, ss = TrainingConfig.Natural.Strength, TrainingConfig.Natural.Speed
	for _, player in Players:GetPlayers() do
		local hrp, hum = bodyOf(player)
		local n = nav[player]
		if not hrp or not hum or not data(player) then
			nav[player] = nil
		else
			local pos = hrp.Position
			if not n then
				nav[player] = { last = pos, anchor = pos, path = 0 }
			else
				local step = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(n.last.X, 0, n.last.Z)).Magnitude
				n.last = pos
				local onFoot = not player:GetAttribute("Driving") and not sessions[player] and hum.Sit == false and hum.FloorMaterial ~= Enum.Material.Air
				-- a teleport / respawn is not travel (more than ~1.6x the walk speed in one second)
				local plausible = step <= math.max(8, hum.WalkSpeed * 1.6)
				if not onFoot or not plausible then
					n.anchor = pos
					n.path = 0
				else
					-- Speed: XP for a chunk only once you are `MinStep` studs (straight line) from where it began
					n.path += step
					local away = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(n.anchor.X, 0, n.anchor.Z)).Magnitude
					if away >= ss.MinStep then
						naturalGrant(player, "Speed", math.min(n.path, away * 1.6) * ss.XPPerStud)
						n.anchor = pos
						n.path = 0
					end
					-- Strength: hauling a meaningful load while actually moving
					local cap = math.max(1, player:GetAttribute("CarryCap") or 1)
					local load = (player:GetAttribute("CarryTotal") or 0) / cap
					if load >= cs.MinLoadFraction and step >= 3 then
						naturalGrant(player, "Strength", cs.CarryXPPerSecond * math.min(1, load))
					end
				end
			end
		end
	end
end

local function standY(hrp: BasePart, hum: Humanoid): number
	return hum.HipHeight + hrp.Size.Y / 2
end

-- Where the character is held while using a machine.
local function poseFor(kind: string, part: BasePart, hrp: BasePart, hum: Humanoid): CFrame
	if kind == "Bench" then
		-- lying on the back, head toward the pad's +Z end, chest under the bar
		return part.CFrame * CFrame.new(0, part.Size.Y / 2 + 0.65, 0.9) * CFrame.Angles(math.rad(90), 0, 0)
	end
	return part.CFrame * CFrame.new(0, part.Size.Y / 2 + standY(hrp, hum), 0)
end

local function exitPoint(kind: string, part: BasePart, hrp: BasePart, hum: Humanoid): CFrame
	local y = part.Size.Y / 2 + standY(hrp, hum) + 0.5
	if kind == "Bench" then
		return part.CFrame * CFrame.new(part.Size.X / 2 + 3.2, y - part.Size.Y / 2 + 0.2, 0)
	end
	return part.CFrame * CFrame.new(0, y, part.Size.Z / 2 + 3)
end

local mustLeave: { [Player]: BasePart } = {} -- a treadmill you just got off: you have to step off it before it can start you again

local function endSession(player: Player, reason: string?)
	local ses = sessions[player]
	if not ses then
		return
	end
	sessions[player] = nil
	if ses.kind == "Treadmill" then
		mustLeave[player] = ses.part
	end
	if ses.part.Parent then
		ses.part:SetAttribute("Occupant", nil)
	end
	player:SetAttribute("TrainKind", nil)
	local hrp, hum = bodyOf(player)
	if hrp and hum and hrp == ses.hrp then
		hrp.Anchored = false
		hrp.CFrame = exitPoint(ses.kind, ses.part, hrp, hum)
	end
	send(player, { Type = "End", Reason = reason or "" })
end

-- the tier of a treadmill part (attribute Level, default 1; beyond the table = the top tier)
function TrainingService.MachineTier(part: Instance, kind: string): { Rank: number, XPMult: number, Name: string, Label: string, Color: Color3 }
	local tiers = (if kind == "Bench" then cfgBench else cfgTread).Tiers
	local level = math.clamp(math.floor((part:GetAttribute("Level") :: number?) or 1), 1, #tiers)
	return tiers[level]
end
function TrainingService.TreadmillTier(part: Instance)
	return TrainingService.MachineTier(part, "Treadmill")
end

local function startSession(player: Player, part: BasePart, kind: string)
	local cfg = if kind == "Bench" then cfgBench else cfgTread
	local d = data(player)
	local hrp, hum = bodyOf(player)
	if not d or not hrp or not hum or sessions[player] or carries[player] then
		return
	end
	if (hrp.Position - part.Position).Magnitude > cfg.Radius then
		return
	end
	if cfg.BlockWithVehicle and player:GetAttribute("Driving") then
		notify(player, "Warn", "Park your vehicle before using the " .. string.lower(cfg.Label) .. ".")
		return
	end
	local occupant = part:GetAttribute("Occupant")
	if occupant ~= nil and occupant ~= player.UserId then
		notify(player, "Warn", "Someone is already using this.")
		return
	end
	local tier = TrainingService.MachineTier(part, kind)
	if S.UpgradeService.MasterRank(player) < tier.Rank then
		if kind == "Bench" then
			notify(player, "Info", string.format("%s needs Master Builder rank %d.", tier.Name, tier.Rank))
		end
		return -- locked (treadmills explain it from the walk-on tick, throttled)
	end
	local mult: number? = tier.XPMult
	local pose = poseFor(kind, part, hrp, hum)
	hrp.AssemblyLinearVelocity = Vector3.zero
	hrp.CFrame = pose
	hrp.Anchored = true
	sessions[player] = { kind = kind, part = part, hrp = hrp, pose = pose, nextTick = now() + cfg.TickSeconds, xp = 0, mult = mult }
	part:SetAttribute("Occupant", player.UserId)
	player:SetAttribute("TrainKind", kind)
	send(player, { Type = "Start", Kind = kind, Stat = cfg.Stat, Part = part, Fatigue = currentStamina(player) })
end

------------------------------------------------------------------ carry tasks (crate / beam)
local function dropCarry(player: Player, restore: boolean)
	local c = carries[player]
	if not c then
		return
	end
	carries[player] = nil
	if c.prop.Parent then
		c.prop:Destroy()
	end
	player:SetAttribute("TrainCarry", nil)
	if restore then
		S.UpgradeService.RefreshMovement(player)
	end
	send(player, { Type = "Carry", Kind = nil })
end

local padNotice: (Player, string) -> ()
local padNoticeAt: { [Player]: number }
local lastDropAt: { [Player]: number }

local function pickUp(player: Player, part: BasePart, kind: string)
	local cfg = if kind == "Beam" then cfgBeam else cfgCrate
	local hrp, hum = bodyOf(player)
	if not hrp or not hum or sessions[player] or carries[player] or not data(player) then
		return
	end
	if (hrp.Position - part.Position).Magnitude > cfg.Radius + part.Size.Magnitude / 2 then
		return
	end
	if player:GetAttribute("Driving") then
		padNotice(player, "Park your vehicle first.")
		return
	end
	local prop = Instance.new("Part")
	prop.Name = "TrainingProp"
	prop.CanCollide = false
	prop.CanQuery = false
	prop.CanTouch = false
	prop.Massless = true
	local carryCF: CFrame
	if kind == "Beam" then
		prop.Size = Vector3.new(1.1, 1, 11)
		prop.Color = Color3.fromRGB(120, 140, 165)
		prop.Material = Enum.Material.DiamondPlate
		carryCF = CFrame.new(0, 2.4, 0)
	else
		prop.Size = Vector3.new(2.6, 2.2, 2.6)
		prop.Color = Color3.fromRGB(186, 130, 70)
		prop.Material = Enum.Material.WoodPlanks
		carryCF = CFrame.new(0, 0.5, -2.1)
	end
	prop.CFrame = hrp.CFrame * carryCF
	local w = Instance.new("WeldConstraint")
	w.Part0 = hrp
	w.Part1 = prop
	w.Parent = prop
	prop.Parent = hrp.Parent
	local base = hum.WalkSpeed
	hum.WalkSpeed = base * cfg.CarrySpeedFactor
	carries[player] = { kind = kind, lane = part:GetAttribute("Lane") or 1, prop = prop, pickedAt = now(), from = part.Position, baseSpeed = base }
	player:SetAttribute("TrainCarry", kind)
	send(player, { Type = "Carry", Kind = kind })
end

local function deliver(player: Player, part: BasePart, kind: string)
	local cfg = if kind == "Beam" then cfgBeam else cfgCrate
	local c = carries[player]
	local hrp = bodyOf(player)
	if not hrp then
		return
	end
	if not c or c.kind ~= kind then
		notify(player, "Info", "Pick up a " .. string.lower(kind) .. " first.")
		return
	end
	if c.lane ~= (part:GetAttribute("Lane") or 1) then
		notify(player, "Info", "That's the wrong stack. Take it to the matching pallet.")
		return
	end
	if (hrp.Position - part.Position).Magnitude > cfg.Radius + part.Size.Magnitude / 2 + 6 then
		return
	end
	-- anti-teleport: the trip has to take at least distance / (normal walk speed x factor)
	local minSeconds = (part.Position - c.from).Magnitude / (c.baseSpeed * cfg.MinTravelSpeedFactor)
	if now() - c.pickedAt < minSeconds then
		notify(player, "Warn", "Carry it all the way, no shortcuts!")
		return
	end
	local stat = cfg.Stat
	local xp = award(player, stat, cfg.XP)
	dropCarry(player, true)
	send(player, { Type = "Deliver", Kind = kind, XP = xp, Stat = stat, Fatigue = currentStamina(player) })
end

------------------------------------------------------------------ requests
local limiter = Net.RateLimiter(6, 8)

local function onRequest(player: Player, action: any)
	if not limiter(player) then
		return
	end
	if action == "Stop" then
		if sessions[player] then
			endSession(player, "")
		end
		if carries[player] then
			dropCarry(player, true)
		end
	end
end

------------------------------------------------------------------ track
local lapLength = 0
local function collectGates()
	table.clear(gates)
	for _, g in CollectionService:GetTagged("TrainingGate") do
		if g:IsA("BasePart") and g:GetAttribute("GateIndex") then
			table.insert(gates, g)
		end
	end
	table.sort(gates, function(a, b)
		return (a:GetAttribute("GateIndex") :: number) < (b:GetAttribute("GateIndex") :: number)
	end)
	-- the loop's length (gate to gate and back round to gate 1): a lap pays XPPerStud for every stud of it
	lapLength = 0
	for i, g in gates do
		local nxt = gates[i % #gates + 1]
		lapLength += Vector3.new(g.Position.X - nxt.Position.X, 0, g.Position.Z - nxt.Position.Z).Magnitude
	end
end

local function setGateAttr(player: Player, value: number)
	if player:GetAttribute("TrainGate") ~= value then
		player:SetAttribute("TrainGate", value)
	end
end

local function resetRun(player: Player)
	runStates[player] = nil
	setGateAttr(player, 0)
end

local function tickRun(player: Player, hrp: BasePart, hum: Humanoid)
	local n = #gates
	if n < 3 then
		return
	end
	local st = runStates[player]
	local t = now()
	-- only react near the track (cheap reject for everyone else)
	local first = gates[1].Position
	if (hrp.Position - first).Magnitude > 420 then
		if st then
			resetRun(player)
		end
		return
	end
	if cfgRun.BlockWithVehicle and player:GetAttribute("Driving") then
		if st then
			resetRun(player)
		end
		return
	end
	if st and st.lapStart and t - st.lapStart > cfgRun.LapTimeout then
		resetRun(player)
		st = nil
	end
	local function inside(g: BasePart): boolean
		local flat = Vector3.new(hrp.Position.X - g.Position.X, 0, hrp.Position.Z - g.Position.Z)
		return flat.Magnitude <= cfgRun.GateRadius and math.abs(hrp.Position.Y - g.Position.Y) <= 12
	end
	if not st then
		-- (Pass 21F) a lap can start at ANY gate: the first gate you run through is your start / finish line for this lap
		for idx, g in gates do
			if inside(g) then
				local nxt = idx % n + 1
				runStates[player] = { next = nxt, start = idx, lapStart = t, lastT = t, lastPos = g.Position, warned = 0 }
				setGateAttr(player, nxt)
				return
			end
		end
		return
	end
	local target = st.next
	local gate = gates[target]
	if not inside(gate) then
		return
	end
	-- speed sanity: the leg must take at least distance / (walk speed * factor)
	local legDist = (gate.Position - st.lastPos).Magnitude
	local minTime = legDist / math.max(8, hum.WalkSpeed * cfgRun.MaxSpeedFactor)
	if t - st.lastT < minTime then
		if t - st.warned > 5 then
			st.warned = t
			Net.Event("Notify"):FireClient(player, "Warn", "Run the track, don't skip ahead!")
		end
		return
	end
	st.lastT = t
	st.lastPos = gate.Position
	if target == st.start then
		-- lap complete (back at the gate this lap began at, after every other gate in order), and it also starts the next lap
		local lapXP = if lapLength > 0 then lapLength * cfgRun.XPPerStud else cfgRun.XPPerLap
		local xp = award(player, "Speed", lapXP)
		addStamina(player, cfgSta.GainPerLap)
		send(player, { Type = "Lap", XP = xp, Stat = "Speed", Fatigue = currentStamina(player) })
		st.lapStart = t
		st.next = st.start % n + 1
	else
		st.next = if target == n then 1 else target + 1
	end
	setGateAttr(player, st.next)
end

------------------------------------------------------------------ lifecycle
local treadmills: { BasePart } = {}

local function setupMachine(part: Instance, kind: string)
	if not part:IsA("BasePart") then
		return
	end
	if kind == "Treadmill" then
		-- (Pass 21C) treadmills start by walking onto them (no prompt); see tickTreadmills
		if not table.find(treadmills, part) then
			table.insert(treadmills, part)
		end
		local old = part:FindFirstChild("TrainPrompt")
		if old then
			old:Destroy()
		end
		return
	end
	if part:FindFirstChild("TrainPrompt") then
		return
	end
	local cfg = if kind == "Bench" then cfgBench else cfgTread
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TrainPrompt"
	prompt.ActionText = cfg.Label
	prompt.ObjectText = if kind == "Bench" then "Strength (hands-off)" else "Speed (hands-off)"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 11
	prompt.RequiresLineOfSight = false
	prompt.Parent = part
	prompt.Triggered:Connect(function(player)
		startSession(player, part, kind)
	end)
end

-- WALK-ON CARRY PADS: no prompt. Walking onto a crate / beam stack picks one up; walking onto the matching pallet while carrying
-- delivers it. Pads are plain registry entries checked by the 4 Hz loop below (flat distance to the pad footprint + a height check).
type CarryPad = { part: BasePart, kind: string, pickup: boolean }
local carryPads: { CarryPad } = {}
padNoticeAt = {}
lastDropAt = {}
local PAD_MARGIN = 1.5 -- studs beyond the pad's edge that still count as "on it"

local function setupCarryPoint(part: Instance, kind: string, isPickup: boolean)
	if not part:IsA("BasePart") then
		return
	end
	for _, pad in carryPads do
		if pad.part == part then
			return
		end
	end
	table.insert(carryPads, { part = part, kind = kind, pickup = isPickup })
	local old = part:FindFirstChild("TrainPrompt")
	if old then
		old:Destroy()
	end
end

local function onPad(hrp: BasePart, part: BasePart): boolean
	if math.abs(hrp.Position.Y - part.Position.Y) > 9 then
		return false
	end
	local rel = part.CFrame:PointToObjectSpace(hrp.Position)
	return math.abs(rel.X) <= part.Size.X / 2 + PAD_MARGIN and math.abs(rel.Z) <= part.Size.Z / 2 + PAD_MARGIN
end

padNotice = function(player: Player, text: string)
	local t = now()
	if t - (padNoticeAt[player] or 0) > 3.5 then
		padNoticeAt[player] = t
		notify(player, "Info", text)
	end
end

-- WALK-ON TREADMILLS: step onto a treadmill you have the Master Builder rank for and it starts; locked ones tell you what they need.
local function tickTreadmills(player: Player, hrp: BasePart)
	local leaving = mustLeave[player]
	if leaving and (not leaving.Parent or not onPad(hrp, leaving)) then
		mustLeave[player] = nil
		leaving = nil
	end
	if carries[player] then
		return
	end
	for _, part in treadmills do
		if part.Parent and part ~= leaving and onPad(hrp, part) then
			local tier = TrainingService.TreadmillTier(part)
			if S.UpgradeService.MasterRank(player) < tier.Rank then
				padNotice(player, string.format("%s needs Master Builder rank %d.", tier.Name, tier.Rank))
			else
				startSession(player, part, "Treadmill")
				if sessions[player] then
					return
				end
			end
		end
	end
end

local function tickCarryPads(player: Player, hrp: BasePart)
	local c = carries[player]
	for _, pad in carryPads do
		if pad.part.Parent and onPad(hrp, pad.part) then
			if pad.pickup then
				if not c and now() - (lastDropAt[player] or 0) > 1.2 then
					pickUp(player, pad.part, pad.kind)
					return
				end
			elseif c and c.kind == pad.kind then
				if c.lane ~= (pad.part:GetAttribute("Lane") or 1) then
					padNotice(player, "That's the wrong stack. Take it to the matching pallet.")
				else
					-- deliver() answers "carry it all the way" itself; throttle that message too
					local minSeconds = (pad.part.Position - c.from).Magnitude / (c.baseSpeed * (if pad.kind == "Beam" then cfgBeam else cfgCrate).MinTravelSpeedFactor)
					if now() - c.pickedAt < minSeconds then
						padNotice(player, "Carry it all the way, no shortcuts!")
					else
						deliver(player, pad.part, pad.kind)
						lastDropAt[player] = now()
						return
					end
				end
			end
		end
	end
end

function TrainingService.Start()
	Net.Event("TrainingRequest").OnServerEvent:Connect(onRequest)
	local tagSetups: { { any } } = {
		{ "TrainingTreadmill", function(p: Instance) setupMachine(p, "Treadmill") end },
		{ "TrainingBench", function(p: Instance) setupMachine(p, "Bench") end },
		{ "CrateStack", function(p: Instance) setupCarryPoint(p, "Crate", true) end },
		{ "CratePallet", function(p: Instance) setupCarryPoint(p, "Crate", false) end },
		{ "BeamStack", function(p: Instance) setupCarryPoint(p, "Beam", true) end },
		{ "BeamPallet", function(p: Instance) setupCarryPoint(p, "Beam", false) end },
	}
	for _, entry in tagSetups do
		for _, inst in CollectionService:GetTagged(entry[1]) do
			entry[2](inst)
		end
		CollectionService:GetInstanceAddedSignal(entry[1]):Connect(entry[2])
	end
	collectGates()
	CollectionService:GetInstanceAddedSignal("TrainingGate"):Connect(collectGates)
	CollectionService:GetInstanceRemovedSignal("TrainingGate"):Connect(collectGates)

	S.PlayerDataService.Loaded:Connect(function(player)
		publishLevels(player)
		player:SetAttribute("Fatigue", 0)
		player:SetAttribute("TrainGate", 0)
	end)
	Players.PlayerRemoving:Connect(function(p)
		sessions[p] = nil
		carries[p] = nil
		padNoticeAt[p] = nil
		lastDropAt[p] = nil
		mustLeave[p] = nil
		runStates[p] = nil
		stamina[p] = nil
		xpWindow[p] = nil
		naturalWindow[p] = nil
		nav[p] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(1)
			local ok, err = pcall(naturalTick)
			if not ok then
				warn("[Training] natural tick error:", err)
			end
		end
	end)

	local function sessionTick()
			local t = now()
			for player, ses in sessions do
				local hrp, hum = bodyOf(player)
				if not player.Parent or not hrp or hrp ~= ses.hrp or not hum then
					-- respawned / died: forget the session (the old character is gone)
					sessions[player] = nil
					if ses.part.Parent then
						ses.part:SetAttribute("Occupant", nil)
					end
					player:SetAttribute("TrainKind", nil)
				elseif (hrp.Position - ses.pose.Position).Magnitude > 6 or not hrp.Anchored then
					endSession(player, "Training stopped.")
				elseif player:GetAttribute("Driving") then
					endSession(player, "Training stopped.")
				elseif t >= ses.nextTick then
					local cfg = if ses.kind == "Bench" then cfgBench else cfgTread
					ses.nextTick = t + cfg.TickSeconds
					local xp = award(player, cfg.Stat, cfg.XPPerTick * (ses.mult or 1))
					ses.xp += xp
					send(player, { Type = "Tick", Kind = ses.kind, XP = xp, Total = ses.xp, Stat = cfg.Stat, Fatigue = currentStamina(player) })
				end
			end
			for player, c in carries do
				local hrp, hum = bodyOf(player)
				if not player.Parent or not hrp or not hum or not c.prop.Parent then
					carries[player] = nil
					if c.prop.Parent then
						c.prop:Destroy()
					end
					player:SetAttribute("TrainCarry", nil)
				elseif player:GetAttribute("Driving") or (hrp.Position - c.from).Magnitude > 220 then
					dropCarry(player, true)
				end
			end
			for _, player in Players:GetPlayers() do
				local hrp, hum = bodyOf(player)
				if hrp and hum and data(player) and not sessions[player] then
					tickRun(player, hrp, hum)
					if not player:GetAttribute("Driving") then
						tickCarryPads(player, hrp)
						tickTreadmills(player, hrp)
					end
				end
			end
	end
	task.spawn(function()
		while true do
			task.wait(0.25)
			local ok, err = pcall(sessionTick)
			if not ok then
				warn("[Training] session tick error:", err)
			end
		end
	end)
end

return TrainingService
