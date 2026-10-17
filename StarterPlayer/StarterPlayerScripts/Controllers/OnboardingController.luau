--!strict
-- Lightweight onboarding driven by observable state plus ONE saved flag (PlayerData.Tutorial.Done, set by the server on the
-- first accepted delivery):
--   NEW player  = Tutorial.Done is false AND never completed a build, hasn't earned meaningful Coins, owns no upgrades.
--   The gather / carry / deliver steps and the guide beam only ever run for a NEW player. After the first delivery a short
--   "Help finish the current stage" nudge shows, then normal objectives take over (the upgrade / vehicle / Worker hints are
--   contextual: they show whenever they are affordable and not yet bought, never as a replayed tutorial).
--   Steps (shown as "STEP n/4" on the objective pill):
--     1 Gather   → guide beam to the most-needed zone
--     2 Carry    → guide beam to the drop-off ring
--     3 Unload   → toast once: unloading is automatic, it pays Coins
--     4 Upgrade  → "!" badge on Upgrades once affordable
--     5 Worker   → "!" badge on Workers and an objective to hire the cheap first Worker (WorkerConfig.FirstHirePrice)
-- The Worker hint also shows for any player without a Worker who can afford the first hire, so nobody misses Workers.
-- RETURNING players (any progress) get no welcome toasts, no step chip and no beam; they
-- only see a short contextual objective while a build is under construction.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local ResourceConfig = require(Shared.Config.ResourceConfig)
local ResourceSpotConfig = require(Shared.Config.ResourceSpotConfig)
local GameConfig = require(Shared.Config.GameConfig)
local UpgradeConfig = require(Shared.Config.UpgradeConfig)
local WorkerConfig = require(Shared.Config.WorkerConfig)
local Lib = script.Parent.Parent.ClientLib
local State = require(Lib.State)
local HUD = require(script.Parent.HUDController)
local Tracker = require(script.Parent.TrackerController)
local Notify = require(script.Parent.NotifyController)

local OnboardingController = {}
local player = Players.LocalPlayer

local workerHintAt: number? = nil
local NEW_PLAYER_COINS = 400 -- lifetime Coins earned below this still counts as "new"

local targetPart: Part
local targetAttachment: Attachment
local beam: Beam
local isNew: boolean? = nil -- decided once, when saved data first arrives
local welcomed = false
local unloadToastShown = false
local finished = false
local sawNewbie = false -- this session started as a new player
local ackAt: number? = nil -- first delivery of this session just happened
local vehicleHintAt: number? = nil

local function needed(): { [string]: number }
	local out = {}
	for _, id in ResourceConfig.Order do
		local need = State.Get("Need_" .. id) or 0
		if ResourceConfig.Resources[id].Secret then
			need = 0 -- secret resources are never part of the guided objective
		end
		local have = State.Get("Have_" .. id) or 0
		local rn = State.Get("RepairNeed_" .. id) or 0
		local rh = State.Get("RepairHave_" .. id) or 0
		local rem = math.max(0, need - have) + math.max(0, rn - rh)
		if rem > 0 then
			out[id] = rem
		end
	end
	return out
end

local function zonePosition(resId: string): Vector3?
	local res = ResourceConfig.Resources[resId]
	local world = workspace:FindFirstChild("World")
	local zones = world and world:FindFirstChild("Zones")
	local zone = res and zones and zones:FindFirstChild(res.Zone)
	local gp = zone and zone:FindFirstChild("GatherPoint") :: BasePart?
	return gp and gp.Position
end

local function setBeam(target: Vector3?, color: Color3?)
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not target or not hrp or isNew ~= true or finished or (hrp.Position - target).Magnitude < 30 then
		beam.Enabled = false
		return
	end
	local a0 = hrp:FindFirstChild("MB_GuideAttachment") :: Attachment?
	if not a0 then
		local a = Instance.new("Attachment")
		a.Name = "MB_GuideAttachment"
		a.Position = Vector3.new(0, -2.5, 0)
		a.Parent = hrp
		a0 = a
	end
	targetPart.Position = target
	beam.Attachment0 = a0
	beam.Attachment1 = targetAttachment
	beam.Color = ColorSequence.new(color or Color3.fromRGB(255, 220, 90))
	beam.Enabled = true
end

local function cheapestUpgrade(d: any): number
	local cheapest = math.huge
	for id, level in d.Upgrades do
		local price = UpgradeConfig.Price(id, level)
		if price then
			cheapest = math.min(cheapest, price)
		end
	end
	return cheapest
end

-- Re-evaluated from saved data every tick (cheap). Progress is monotonic for real players
-- (earn Coins / buy an upgrade / finish a build), so "new" simply turns off for good once any
-- of those happens; nothing extra needs saving.
local function decideIfNew()
	local d = State.Data
	if not d or not d.Stats then
		return
	end
	local anyUpgrade = false
	for _, level in d.Upgrades or {} do
		if level > 0 then
			anyUpgrade = true
		end
	end
	local tutorialDone = d.Tutorial ~= nil and d.Tutorial.Done == true
	finished = tutorialDone or anyUpgrade or (d.Stats.BuildsCompleted or 0) > 0 or (d.Stats.CoinsEarned or 0) >= NEW_PLAYER_COINS
	isNew = not finished
	if isNew then
		sawNewbie = true
	elseif sawNewbie and not ackAt then
		ackAt = os.clock() -- the intro just completed in this session: acknowledge it once
		Notify.Show("Success", "✅ Delivered! Your load went into the build. Watch it grow.", 4)
	end
	if isNew and not welcomed then
		welcomed = true
		local title = State.Get("BuildTitle")
		local what = if type(title) == "string" and title ~= "" then title else "something HUGE"
		Notify.Show("Info", string.format("Welcome! The whole server is building %s together.", what), 5)
	end
end

local function update()
	decideIfNew()
	local d = State.Data
	local phase = State.Get("Phase") or ""
	if phase ~= "Building" or not d then
		HUD.SetObjective("")
		setBeam(nil)
		return
	end
	local need = needed()
	local total = player:GetAttribute("CarryTotal") or 0
	local cap = player:GetAttribute("CarryCap") or 1
	local carryingNeeded = false
	for id in need do
		if (player:GetAttribute("Carry_" .. id) or 0) > 0 then
			carryingNeeded = true
		end
	end
	local delivered = (player:GetAttribute("Contribution") or 0) > 0
	local coins = player:GetAttribute("Coins") or 0
	local canBuy = coins >= cheapestUpgrade(d)
	local anyUpgrade = false
	for _, level in d.Upgrades or {} do
		if level > 0 then
			anyUpgrade = true
		end
	end
	local newbie = isNew == true and not finished
	local step = function(n: number): string?
		return if newbie then string.format("STEP %d/5", n) else nil
	end
	local site = GameConfig.Site.Center + Vector3.new(0, 2, 0)

	-- first Worker: everyone without one sees the menu badge once they can afford the first hire; new players get the objective
	local noWorker = not (d.Worker and d.Worker.Unlocked)
	local canHire = noWorker and coins >= WorkerConfig.FirstHirePrice
	HUD.SetBadge("Worker", canHire)
	if canHire and not workerHintAt and (anyUpgrade or not canBuy) and (newbie or (d.Stats.BuildsCompleted or 0) < 3) then
		workerHintAt = os.clock() -- the objective shows for a few seconds; the badge stays until the first hire
	end
	if canHire and workerHintAt and os.clock() - workerHintAt < 10 then
		HUD.SetObjective(string.format("Hire your first Worker! Open 👷 Workers (%d coins)", WorkerConfig.FirstHirePrice), Color3.fromRGB(255, 205, 90), step(5))
		setBeam(nil)
		return
	end
	-- right after the first delivery: one short line, then the normal objectives take over
	if ackAt and os.clock() - ackAt < 10 then
		HUD.SetObjective("Help finish the current stage", Color3.fromRGB(150, 235, 160), nil)
		setBeam(nil)
		return
	end
	-- first upgrade: contextual (shows while affordable and unbought, never opens the menu); cleared by the purchase
	if canBuy and not anyUpgrade and (d.Stats.BuildsCompleted or 0) < 3 then
		HUD.SetObjective("Buy your first upgrade: open ⬆ Upgrades", Color3.fromRGB(150, 210, 255), step(4))
		setBeam(nil)
		return
	end
	-- first vehicle: a badge on Vehicles once the cheapest one is affordable; a short objective once the first upgrade is bought
	local ownsVehicle = false
	for _ in (d.Vehicles and d.Vehicles.Owned) or {} do
		ownsVehicle = true
	end
	local canVehicle = not ownsVehicle and coins >= 75
	HUD.SetBadge("Vehicles", canVehicle)
	if canVehicle and anyUpgrade and not vehicleHintAt and (d.Stats.BuildsCompleted or 0) < 3 then
		vehicleHintAt = os.clock()
	end
	if canVehicle and vehicleHintAt and os.clock() - vehicleHintAt < 10 then
		HUD.SetObjective("Buy a Wheelbarrow in 🛒 Vehicles to carry more", Color3.fromRGB(255, 205, 90), nil)
		setBeam(nil)
		return
	end

	if carryingNeeded and total >= cap * 0.5 then
		HUD.SetObjective(if total >= cap then "FULL! Walk into the yellow DROP-OFF ring (unloads by itself)" else "Bring your load to the yellow DROP-OFF ring", Color3.fromRGB(255, 220, 90), step(2), newbie)
		setBeam(site, Color3.fromRGB(255, 220, 90))
		return
	end
	if total > 0 and not carryingNeeded then
		HUD.SetObjective("The build doesn't need that. Tap Drop, then gather what the tracker shows.", Color3.fromRGB(255, 150, 120), step(2), newbie)
		setBeam(nil)
		return
	end
	local resId = Tracker.MostNeeded
	if newbie then
		-- a brand-new player is sent to the LOWEST-tier material the build still lacks (Tier 1 when it needs any), most needed first
		local pick, pickGrade, most = nil, 99, 0
		for _, id in ResourceConfig.Order do
			local res = ResourceConfig.Resources[id]
			if need[id] and not res.Secret and (res.Grade < pickGrade or (res.Grade == pickGrade and need[id] > most)) then
				pick, pickGrade, most = id, res.Grade, need[id]
			end
		end
		if pick then
			resId = pick
		end
	end
	if not resId or not need[resId] then
		resId = nil
		for _, id in ResourceConfig.Order do
			if need[id] then
				resId = id
				break
			end
		end
	end
	if resId then
		local res = ResourceConfig.Resources[resId]
		local zoneName = string.upper((ResourceSpotConfig.Get(res.Zone) or { DisplayName = res.Zone }).DisplayName)
		local text = if newbie and (player:GetAttribute("CarryTotal") or 0) > 0 then "Keep gathering: hold E / tap on the glowing nodes" else string.format("%s Gather %s at the %s (hold E / tap)", res.Icon, res.DisplayName, zoneName)
		if not newbie then
			text = string.format("%s Go to the %s and gather %s", res.Icon, zoneName, res.DisplayName)
		end
		HUD.SetObjective(text, res.Color:Lerp(Color3.new(1, 1, 1), 0.45), step(if delivered then 3 else 1), newbie)
		setBeam(zonePosition(resId), res.Color)
	else
		HUD.SetObjective("Almost there! Finishing construction...")
		setBeam(nil)
	end
end

function OnboardingController.Start()
	targetPart = Instance.new("Part")
	targetPart.Name = "MB_GuideTarget"
	targetPart.Anchored = true
	targetPart.CanCollide = false
	targetPart.CanQuery = false
	targetPart.CanTouch = false
	targetPart.Transparency = 1
	targetPart.Size = Vector3.one
	targetPart.Parent = workspace
	targetAttachment = Instance.new("Attachment")
	targetAttachment.Parent = targetPart
	beam = Instance.new("Beam")
	beam.Width0 = 1.2
	beam.Width1 = 1.2
	beam.FaceCamera = true
	beam.LightEmission = 0.7
	beam.Transparency = NumberSequence.new(0.35)
	beam.Segments = 1
	beam.Enabled = false
	beam.Parent = targetPart

	-- (the Upgrades alert marker lives in UpgradePanel and applies to every player)
	State.DataChanged:Connect(decideIfNew)
	decideIfNew()
	task.spawn(function()
		while true do
			task.wait(0.5)
			local ok, err = pcall(update)
			if not ok then
				warn("[Onboarding]", err)
			end
		end
	end)
end

return OnboardingController
