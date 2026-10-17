--!strict
-- DEVELOPER ADMIN PANEL (server). One RemoteFunction (Net "AdminRequest"): the client sends (action, args), the server
-- answers { ok, msg, data }. Every call is re-authorized against AdminConfig (UserId only), rate limited, and its
-- action name and arguments are validated here; the client UI is only a set of buttons.
-- This module holds NO gameplay logic: each action calls an existing service (BuildService, GameLoopService,
-- SelectionService, ServerLuckService, MutationService, EventService, PlayerDataService, TrainingService,
-- MasterBuilderService, VehicleService, WorkerService, DebugService.Run for profile reset / index unlock).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local BuildConfig = require(Shared.Config.BuildConfig)
local EventConfig = require(Shared.Config.EventConfig)
local ModifierConfig = require(Shared.Config.ModifierConfig)
local MutationConfig = require(Shared.Config.MutationConfig)
local MasterProjectConfig = require(Shared.Config.MasterProjectConfig)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local ResourceSpotConfig = require(Shared.Config.ResourceSpotConfig)
local TrainingConfig = require(Shared.Config.TrainingConfig)
local VehicleConfig = require(Shared.Config.VehicleConfig)
local WorkerConfig = require(Shared.Config.WorkerConfig)
local AdminConfig = require(ServerScriptService:WaitForChild("Admin"):WaitForChild("AdminConfig"))

local AdminService = {}
local S: any

type Result = { ok: boolean, msg: string, data: any? }
type Handler = (Player, { [string]: any }) -> (boolean, string)

local function fail(msg: string): (boolean, string)
	return false, msg
end

-- ---------------------------------------------------------------- argument validation (never trust the client)
local function num(v: any, lo: number, hi: number): number?
	if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
		return nil
	end
	return math.clamp(v, lo, hi)
end

local function oneOf(v: any, set: { [string]: any }): string?
	if type(v) == "string" and set[v] ~= nil then
		return v
	end
	return nil
end

local function buildIds(): { [string]: boolean }
	local t = {}
	for _, def in BuildConfig.Eligible(nil, math.huge) do
		t[def.Id] = true
	end
	return t
end

-- "Random" leaves the normal modifier roll alone; "None" forces none; a modifier id forces that one.
local function variantOk(v: any): string?
	if v == nil then
		return "Random"
	end
	if v == "Random" or v == "None" or (type(v) == "string" and ModifierConfig.Modifiers[v] ~= nil) then
		return v
	end
	return nil
end

local function forceVariant(variant: string)
	if variant == "None" then
		S.SelectionService.Force("Modifiers", {})
	elseif variant ~= "Random" then
		S.SelectionService.Force("Modifiers", { variant })
	end
end

-- ---------------------------------------------------------------- snapshot (shown in the panel header)
local function snapshot(player: Player): { [string]: any }
	local st = S.StateService
	local d = S.PlayerDataService.Get(player)
	local b = S.BuildService.Get()
	return {
		BuildId = st.Get("BuildId") or "",
		BuildTitle = st.Get("BuildTitle") or "",
		Rarity = st.Get("Rarity") or "",
		Stage = st.Get("Stage") or 0,
		StageCount = st.Get("StageCount") or 0,
		Progress = st.Get("Progress") or 0,
		Phase = st.Get("Phase") or "",
		Activated = b ~= nil and b.activated == true,
		Luck = S.ServerLuckService.Get(),
		BuildsCompleted = st.Get("BuildsCompleted") or 0,
		Event = S.EventService.Current() or "",
		Coins = d and math.floor(d.Coins) or 0,
		Strength = S.TrainingService.Level(player, "Strength"),
		Speed = S.TrainingService.Level(player, "Speed"),
		MasterRank = d and d.MasterBuilder.Rank or 0,
		ForcedProject = MasterProjectConfig.ForceNext or "",
		Mock = S.PlayerDataService.IsMock(),
	}
end

-- everything the panel needs to build its controls (sent once on Open)
local function catalog(): { [string]: any }
	local builds = {}
	for _, def in BuildConfig.Eligible(nil, math.huge) do
		table.insert(builds, { Id = def.Id, Name = def.DisplayName, Rarity = def.Rarity, Stages = if def.StageNames then #def.StageNames else nil })
	end
	local variants = { "Random", "None" }
	for _, m in ModifierConfig.Order do
		table.insert(variants, m)
	end
	local events = {}
	for id, def in EventConfig.Events do
		if def.Enabled then
			table.insert(events, { Id = id, Name = def.DisplayName })
		end
	end
	table.sort(events, function(a, b)
		return a.Name < b.Name
	end)
	local tiers = {}
	for _, id in MutationConfig.Order do
		table.insert(tiers, id)
	end
	local resources = { "Auto" }
	local seen = {}
	for _, sp in ResourceSpotConfig.List() do
		if not seen[sp.Resource] then
			seen[sp.Resource] = true
			table.insert(resources, sp.Resource)
		end
	end
	local vehicles = { "None" }
	for id in VehicleConfig.Vehicles do
		table.insert(vehicles, id)
	end
	table.sort(vehicles)
	local projects = {}
	for _, p in MasterProjectConfig.Projects do
		if p.Enabled then
			table.insert(projects, p.Id)
		end
	end
	return {
		Builds = builds,
		Variants = variants,
		Events = events,
		MutationTiers = tiers,
		MutationResources = resources,
		Vehicles = vehicles,
		WorkerTypes = WorkerConfig.TypeOrder,
		Projects = projects,
		Teleports = AdminConfig.Teleports,
		Stats = { "Strength", "Speed" },
		MaxLevel = { Strength = TrainingConfig.Stats.Strength.MaxLevel, Speed = TrainingConfig.Stats.Speed.MaxLevel },
		ResetToken = AdminConfig.ResetToken,
	}
end

-- ---------------------------------------------------------------- teleport (safe: ray down to the ground, land above it)
local function groundPoint(pos: Vector3, ignore: { Instance }): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(pos.X, 700, pos.Z), Vector3.new(0, -1400, 0), params)
	return if hit then hit.Position + Vector3.new(0, 4, 0) else Vector3.new(pos.X, math.max(pos.Y, 40), pos.Z)
end

local function teleportTarget(id: string): Vector3?
	local world = workspace:FindFirstChild("World")
	if id == "Spawn" then
		local sp = world and world:FindFirstChild("Hub") and world.Hub:FindFirstChild("SpawnLocation")
		return if sp and sp:IsA("BasePart") then sp.Position else nil
	elseif id == "Training" then
		local t = world and world:FindFirstChild("Areas") and world.Areas:FindFirstChild("TrainingYard")
		return if t and t:IsA("Model") then t:GetPivot().Position else nil
	end
	local zone = world and world:FindFirstChild("Zones") and world.Zones:FindFirstChild(id)
	local gp = zone and zone:FindFirstChild("GatherPoint")
	if gp and gp:IsA("BasePart") then
		return gp.Position
	end
	for _, sp in ResourceSpotConfig.List() do
		if sp.Id == id then
			return sp.Position
		end
	end
	return nil
end

-- ---------------------------------------------------------------- actions
local H: { [string]: Handler } = {}

-- BUILDS (BuildService / GameLoopService / SelectionService)
H["Builds.Start"] = function(_p, a)
	local id = oneOf(a.Id, buildIds())
	local variant = variantOk(a.Variant)
	if not id or not variant then
		return fail("Unknown build or variant")
	end
	S.SelectionService.Force("BuildId", id)
	forceVariant(variant)
	S.GameLoopService.Restart()
	-- the round cycle restarts through its normal phases; skip them until the forced build is running
	task.spawn(function()
		for _ = 1, 24 do
			task.wait(1.2)
			local act = S.BuildService.Get()
			if act and act.def.Id == id then
				return
			end
			S.GameLoopService.Skip()
		end
	end)
	return true, string.format("Starting %s (%s)", id, variant)
end

H["Builds.ForceNext"] = function(_p, a)
	local id = oneOf(a.Id, buildIds())
	local variant = variantOk(a.Variant)
	if not id or not variant then
		return fail("Unknown build or variant")
	end
	S.SelectionService.Force("BuildId", id)
	forceVariant(variant)
	return true, string.format("Next build forced: %s (%s)", id, variant)
end

H["Builds.Reset"] = function()
	S.GameLoopService.Restart()
	return true, "Build reset (cycle restarting)"
end

H["Builds.SetStage"] = function(_p, a)
	local act = S.BuildService.Get()
	if not act then
		return fail("No active build")
	end
	local n = #act.stages
	local stage = num(a.Stage, 1, n)
	if not stage then
		return fail("Stage must be 1-" .. n)
	end
	stage = math.floor(stage)
	if stage - 1 <= act.completedStages then
		if stage - 1 == act.completedStages then
			return true, "Already building stage " .. stage
		end
		return fail("Can only advance (use Reset Build to go back)")
	end
	S.BuildService.FillTo((stage - 1) / n)
	return true, string.format("Stages 1-%d filled, now on stage %d/%d", stage - 1, stage, n)
end

H["Builds.Progress"] = function(_p, a)
	local pct = num(a.Percent, 1, 100)
	if not pct or not S.BuildService.Get() then
		return fail(if pct then "No active build" else "Percent must be 1-100")
	end
	local target = math.min(1, (S.StateService.Get("Progress") or 0) + pct / 100)
	S.BuildService.FillTo(target)
	return true, string.format("Progress +%d%% -> %d%%", pct, math.floor(target * 100))
end

H["Builds.Complete"] = function()
	if not S.BuildService.IsActive() then
		return fail("No active build")
	end
	S.GameLoopService.ForceComplete()
	return true, "Completing current build"
end

-- SERVER (ServerLuckService / StateService / SelectionService / MasterProjectConfig dev override)
H["Server.SetLuck"] = function(_p, a)
	local v = num(a.Value, 0, 100)
	if not v then
		return fail("Luck must be 0-100")
	end
	S.ServerLuckService.Set(v)
	return true, "Server Luck = " .. S.ServerLuckService.Get()
end

H["Server.AddLuck"] = function(_p, a)
	local d = num(a.Delta, -100, 100)
	if not d then
		return fail("Delta must be -100..100")
	end
	S.ServerLuckService.Set(S.ServerLuckService.Get() + d)
	return true, "Server Luck = " .. S.ServerLuckService.Get()
end

H["Server.SetBuildCount"] = function(_p, a)
	local n = num(a.Count, 0, 9999)
	if not n then
		return fail("Count must be 0-9999")
	end
	S.StateService.Set("BuildsCompleted", math.floor(n))
	return true, "Completed-build count = " .. math.floor(n)
end

H["Server.NormalSelection"] = function()
	S.SelectionService.Force("BuildId", nil)
	S.SelectionService.Force("Rarity", nil)
	S.SelectionService.Force("Modifiers", nil)
	MasterProjectConfig.ForceNext = nil
	S.GameLoopService.Restart()
	return true, "Overrides cleared; normal build selection restarting"
end

H["Server.MasterProject"] = function(_p, a)
	local ids = {}
	for _, p in MasterProjectConfig.Projects do
		if p.Enabled then
			ids[p.Id] = true
		end
	end
	local id = if a.Id == nil then "OrbitalStation" else oneOf(a.Id, ids)
	if not id then
		return fail("Unknown Master Project")
	end
	MasterProjectConfig.ForceNext = id -- the existing dev override (cleared by Reset Temp State / Normal Selection)
	S.GameLoopService.Restart()
	return true, "Master Project forced: " .. id
end

-- MUTATIONS (MutationService) and EVENTS (EventService)
H["Mutation.Spawn"] = function(_p, a)
	local tier = oneOf(a.Tier, MutationConfig.Tiers)
	if not tier then
		return fail("Unknown tier")
	end
	local res = a.Resource
	if res ~= nil and res ~= "Auto" and (type(res) ~= "string" or not ResourceConfig.Resources[res]) then
		return fail("Unknown resource")
	end
	local candidates = {}
	if res and res ~= "Auto" then
		candidates = { res }
	else
		local seen = {}
		for _, sp in ResourceSpotConfig.List() do
			if not seen[sp.Resource] then
				seen[sp.Resource] = true
				table.insert(candidates, sp.Resource)
			end
		end
		local rng = Random.new()
		for i = #candidates, 2, -1 do
			local j = rng:NextInteger(1, i)
			candidates[i], candidates[j] = candidates[j], candidates[i]
		end
	end
	for _, r in candidates do
		local pile = S.MutationService.Spawn(r, tier)
		if pile then
			return true, string.format("%s %s pile spawned (%d nodes)", tier, r, #pile.nodes)
		end
	end
	return fail("Could not spawn a " .. tier .. " pile")
end

H["Mutation.Clear"] = function()
	S.MutationService.Clear()
	return true, "Mutation piles cleared"
end

-- VFX TESTING: put a real load in your own stack (CarryVisual auras; walk into the deposit ring for the real delivery FX).
-- Replaces what you carry. Uses ResourceService.Give, so capacity still applies.
H["VFX.GiveLoad"] = function(p, a)
	local res = oneOf(a.Resource, ResourceConfig.Resources)
	local tier = oneOf(a.Tier, MutationConfig.Tiers)
	local amount = num(a.Amount, 1, 100000)
	if not res or not tier or not amount then
		return fail("Unknown resource/tier or bad amount")
	end
	S.ResourceService.Clear(p)
	local given = S.ResourceService.Give(p, res, amount, nil, if tier == "Normal" then nil else tier)
	return true, string.format("Carrying %d %s %s (capacity %d)", given, tier, res, S.ResourceService.GetCapacity(p))
end

H["VFX.ClearLoad"] = function(p)
	S.ResourceService.Clear(p)
	return true, "Load cleared"
end

H["Event.Trigger"] = function(_p, a)
	local def = if type(a.Id) == "string" then EventConfig.Events[a.Id] else nil
	if not def or not def.Enabled then
		return fail("Unknown or disabled event")
	end
	if S.EventService.Current() then
		S.EventService.StopCurrent()
	end
	if S.EventService.Trigger(a.Id) then
		return true, "Event started: " .. def.DisplayName
	end
	return fail(def.DisplayName .. " can't start right now")
end

H["Event.Stop"] = function()
	if not S.EventService.Current() then
		return true, "No active event"
	end
	S.EventService.StopCurrent()
	return true, "Event ended"
end

-- PLAYER (the invoking admin only; always through the profile / service APIs)
H["Player.AddCoins"] = function(p, a)
	local n = num(a.Amount, -1e9, 1e9)
	if not n then
		return fail("Amount must be a number")
	end
	S.PlayerDataService.AddCoins(p, n)
	return true, "Coins " .. (if n >= 0 then "+" else "") .. math.floor(n)
end

H["Player.SetCoins"] = function(p, a)
	local n = num(a.Amount, 0, 1e12)
	local d = S.PlayerDataService.Get(p)
	if not n or not d then
		return fail("Amount must be 0-1e12 (and data loaded)")
	end
	S.PlayerDataService.AddCoins(p, math.floor(n) - d.Coins)
	return true, "Coins = " .. math.floor(n)
end

H["Player.SetTrainingLevel"] = function(p, a)
	local stat = oneOf(a.Stat, TrainingConfig.Stats)
	local d = S.PlayerDataService.Get(p)
	local level = if stat then num(a.Level, 0, TrainingConfig.Stats[stat].MaxLevel) else nil
	if not stat or not level or not d then
		return fail("Bad stat or level")
	end
	d.Training[stat] = 0
	S.TrainingService.AddPoints(p, stat, TrainingConfig.PointsFor(stat, math.floor(level)))
	return true, string.format("%s level %d", stat, S.TrainingService.Level(p, stat))
end

H["Player.AddTrainingXP"] = function(p, a)
	local stat = oneOf(a.Stat, TrainingConfig.Stats)
	local pts = num(a.Points, 1, 1e7)
	if not stat or not pts then
		return fail("Bad stat or XP")
	end
	S.TrainingService.AddPoints(p, stat, pts)
	return true, string.format("%s +%d XP (level %d)", stat, pts, S.TrainingService.Level(p, stat))
end

H["Player.SetMasterRank"] = function(p, a)
	local rank = num(a.Rank, 0, 10)
	local d = S.PlayerDataService.Get(p)
	if not rank or not d then
		return fail("Rank must be 0-10")
	end
	d.MasterBuilder.Rank = math.floor(rank)
	d.MasterBuilder.LastAdvancedAt = os.time()
	S.PlayerDataService.MarkDirty(p)
	S.MasterBuilderService.Refresh(p)
	return true, "Master Builder rank = " .. math.floor(rank)
end

H["Player.GrantVehicles"] = function(p)
	for id in VehicleConfig.Vehicles do
		S.VehicleService.Grant(p, id)
	end
	return true, "All vehicles unlocked"
end

H["Player.EquipVehicle"] = function(p, a)
	if a.Id == "None" then
		S.VehicleService.Equip(p, nil)
		return true, "Vehicle parked"
	end
	local id = oneOf(a.Id, VehicleConfig.Vehicles)
	if not id then
		return fail("Unknown vehicle")
	end
	S.VehicleService.Grant(p, id)
	local ok, msg = S.VehicleService.Equip(p, id)
	return ok, tostring(msg)
end

H["Player.GrantWorker"] = function(p, a)
	local t = if a.Type == nil then WorkerConfig.DefaultType else oneOf(a.Type, WorkerConfig.Types)
	local d = S.PlayerDataService.Get(p)
	if not t or not d then
		return fail("Unknown worker type")
	end
	d.Worker.Unlocked = true
	d.Worker.OwnedTypes[t] = true
	S.PlayerDataService.MarkDirty(p)
	local ok, msg = S.WorkerService.SetType(p, t)
	S.WorkerService.Spawn(p)
	return ok, "Worker: " .. t .. " (" .. tostring(msg) .. ")"
end

H["Player.DismissWorker"] = function(p)
	S.WorkerService.Despawn(p)
	return true, "Worker dismissed"
end

-- TELEPORT
H["Teleport.To"] = function(p, a)
	local known = false
	for _, t in AdminConfig.Teleports do
		if t.Id == a.Id then
			known = true
		end
	end
	if not known or type(a.Id) ~= "string" then
		return fail("Unknown teleport target")
	end
	local char = p.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	local pos = teleportTarget(a.Id)
	if not char or not root or not pos then
		return fail("No character or target")
	end
	char:PivotTo(CFrame.new(groundPoint(pos, { char })))
	return true, "Teleported to " .. a.Id
end

-- PROFILE / DEBUG (own profile only)
H["Profile.Reset"] = function(p, a)
	if a.Confirm ~= AdminConfig.ResetToken then
		return fail("Confirmation required")
	end
	if not (S.PlayerDataService.IsMock() or RunService:IsStudio() or AdminConfig.AllowLiveProfileReset) then
		return fail("Profile reset is disabled on live servers")
	end
	return true, S.DebugService.Run(p, "ResetData")
end

H["Profile.ResetTemp"] = function(_p)
	S.MutationService.Clear()
	S.EventService.StopCurrent()
	S.BuildService.RepairAll()
	S.SelectionService.Force("BuildId", nil)
	S.SelectionService.Force("Rarity", nil)
	S.SelectionService.Force("Modifiers", nil)
	MasterProjectConfig.ForceNext = nil
	return true, "Temporary state cleared (event, mutations, damage, forced selections)"
end

H["Profile.UnlockIndex"] = function(p, a)
	local id = oneOf(a.Id, buildIds())
	if not id then
		return fail("Unknown build")
	end
	return true, S.DebugService.Run(p, "DiscoverBuild", id)
end

-- ---------------------------------------------------------------- entry points
local warned: { [any]: boolean } = {}

-- Single choke point: authorization -> action allow-list -> handler (which validates its own args).
function AdminService.Handle(player: any, action: any, args: any): Result
	if not AdminConfig.IsAdmin(player) then
		if not warned[player] then
			warned[player] = true
			warn(string.format("[Admin] rejected unauthorized request from %s (%s)", tostring(player.Name), tostring(player.UserId)))
		end
		return { ok = false, msg = "Not authorized" }
	end
	if action == "Open" then
		return { ok = true, msg = "ok", data = { Catalog = catalog(), Snapshot = snapshot(player) } }
	elseif action == "Snapshot" then
		return { ok = true, msg = "ok", data = { Snapshot = snapshot(player) } }
	end
	local fn = if type(action) == "string" then H[action] else nil
	if not fn then
		return { ok = false, msg = "Unknown action" }
	end
	local a = if type(args) == "table" then args else {}
	local ok, success, msg = pcall(fn, player, a)
	if not ok then
		warn("[Admin] action error", action, success)
		return { ok = false, msg = "Server error" }
	end
	print(string.format("[Admin] %s -> %s %s", player.Name, tostring(action), success and "ok" or "refused"))
	return { ok = success, msg = tostring(msg), data = { Snapshot = snapshot(player) } }
end

function AdminService.Init(registry)
	S = registry
end

function AdminService.Start()
	local limiter = Net.RateLimiter(AdminConfig.RateLimit.PerSecond, AdminConfig.RateLimit.Burst)
	Players.PlayerRemoving:Connect(function(p)
		warned[p] = nil
	end)
	Net.Function("AdminRequest").OnServerInvoke = function(player, action, args)
		if not AdminConfig.IsAdmin(player) then
			return AdminService.Handle(player, action, args) -- rejects (one warning per player), reveals nothing
		end
		if not limiter(player) then
			return { ok = false, msg = "Slow down" }
		end
		return AdminService.Handle(player, action, args)
	end
	-- Studio-only test hook: ServerStorage.MB_AdminBridge:Invoke(userId, action, args) acts as that UserId.
	if RunService:IsStudio() and AdminConfig.TestBridge then
		local bridge = Instance.new("BindableFunction")
		bridge.Name = "MB_AdminBridge"
		bridge.OnInvoke = function(userId, action, args)
			local real = Players:GetPlayerByUserId(userId)
			local who: any = real or { UserId = userId, Name = "FakePlayer" .. tostring(userId) }
			return AdminService.Handle(who, action, args)
		end
		bridge.Parent = ServerStorage
	end
end

return AdminService
