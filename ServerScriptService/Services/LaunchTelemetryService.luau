--!strict
-- LAUNCH TELEMETRY: the new-player funnel and pacing, sent to Roblox's built-in AnalyticsService (Creator Dashboard).
-- Separate from TelemetryService, which is a Studio-only balance recorder.
--
-- What is sent (nothing per tick, nothing per deposit, no personal data beyond what AnalyticsService attaches itself):
--   * Onboarding funnel (LogOnboardingFunnelStepEvent, once per player for life): the ordered core loop in FUNNEL below.
--   * One-time milestones (LogCustomEvent "First<Thing>", value = PLAY seconds since the player's first join): the pacing numbers
--     (time-to-first-gather, -deposit, -upgrade, -completed build, ...). Each fires once per player, ever (persisted).
--   * Rare repeatable events: Master Builder rank-up (value = new rank), Forgotten discovery (value = archive count).
--   * Session start / end (value = session seconds on end, with the furthest funnel step reached as a coarse field).
--
-- Gameplay code calls LaunchTelemetryService.Milestone(player, id) at the point the thing happens; after the first time the call is
-- a table lookup and returns. Every AnalyticsService call is pcall'd and never yields gameplay.
local AnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LaunchTelemetryService = {}
local S: any

-- Studio play tests would pollute the live dashboard; flip on only to verify the calls in Studio.
local SEND_IN_STUDIO = false
local PLAYTIME_STEP = 30 -- seconds; play time is folded into the profile this often (the leave save then carries it)

-- Ordered onboarding funnel. Steps may be reached out of order; each is logged once.
local FUNNEL = {
	SessionStart = { Step = 1, Name = "Joined" },
	FirstGather = { Step = 2, Name = "First Gather" },
	FirstDeposit = { Step = 3, Name = "First Deposit" },
	FirstUpgrade = { Step = 4, Name = "First Upgrade" },
	FirstCompletion = { Step = 5, Name = "First Build Completed" },
	FirstIndexDiscovery = { Step = 6, Name = "First Index Discovery" },
}

-- Milestones logged once per player as a custom event whose value is time-to-reach (play seconds).
local MILESTONES = {
	FirstGather = true,
	FirstDeposit = true,
	FirstUpgrade = true,
	FirstWorker = true, -- a Worker was hired and deployed
	FirstWorkerDelivery = true, -- that Worker delivered to a build
	FirstVehicle = true, -- a vehicle was obtained
	FirstVehicleDrive = true, -- the owner sat in it and drove
	FirstCompletion = true,
	FirstIndexDiscovery = true,
}

local sessionStart: { [Player]: number } = {}
local lastFold: { [Player]: number } = {}

local function enabled(): boolean
	return SEND_IN_STUDIO or not RunService:IsStudio()
end

local function store(player: Player): any?
	local d = S.PlayerDataService.Get(player)
	if not d then
		return nil
	end
	local t = d.Telemetry
	if type(t) ~= "table" then
		t = { Done = {}, PlaySeconds = 0, Furthest = 0 }
		d.Telemetry = t
	end
	t.Done = t.Done or {}
	t.PlaySeconds = t.PlaySeconds or 0
	t.Furthest = t.Furthest or 0
	return t
end

-- Lifetime play seconds including the running session.
local function playSeconds(player: Player, t: any): number
	local since = lastFold[player]
	return math.floor(t.PlaySeconds + (if since then os.clock() - since else 0))
end

local function send(fn: () -> ())
	if not enabled() then
		return
	end
	local ok, err = pcall(fn)
	if not ok then
		warn("[LaunchTelemetry]", err)
	end
end

local function funnelStep(player: Player, t: any, id: string)
	local f = FUNNEL[id]
	if not f then
		return
	end
	if f.Step > t.Furthest then
		t.Furthest = f.Step
	end
	send(function()
		AnalyticsService:LogOnboardingFunnelStepEvent(player, f.Step, f.Name)
	end)
end

-- One-time milestone (no-op after the first time for this player, ever).
function LaunchTelemetryService.Milestone(player: Player, id: string)
	if not MILESTONES[id] or not player.Parent then
		return
	end
	local t = store(player)
	if not t or t.Done[id] then
		return
	end
	t.Done[id] = true
	local secs = playSeconds(player, t)
	S.PlayerDataService.MarkDirty(player, true)
	funnelStep(player, t, id)
	send(function()
		AnalyticsService:LogCustomEvent(player, id, secs)
	end)
end

-- Rare repeatable events (rank-ups, Forgotten discoveries): value is a small number, never free text.
function LaunchTelemetryService.Event(player: Player, name: string, value: number?)
	if not player.Parent then
		return
	end
	send(function()
		AnalyticsService:LogCustomEvent(player, name, value or 1)
	end)
end

local function onLoaded(player: Player)
	local t = store(player)
	if not t then
		return
	end
	sessionStart[player] = os.clock()
	lastFold[player] = os.clock()
	local firstSession = not t.Done.SessionStart
	if firstSession then
		t.Done.SessionStart = true
		S.PlayerDataService.MarkDirty(player, true)
		funnelStep(player, t, "SessionStart")
	end
	send(function()
		AnalyticsService:LogCustomEvent(player, "SessionStart", 1, {
			[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = if firstSession then "New" else "Returning",
		})
	end)
end

local function fold(player: Player)
	local since = lastFold[player]
	local d = S.PlayerDataService.Get(player)
	if since and d and type(d.Telemetry) == "table" then
		local now = os.clock()
		d.Telemetry.PlaySeconds = (d.Telemetry.PlaySeconds or 0) + (now - since)
		lastFold[player] = now
	end
end

function LaunchTelemetryService.Init(registry)
	S = registry
end

function LaunchTelemetryService.Start()
	S.PlayerDataService.Loaded:Connect(onLoaded)
	Players.PlayerRemoving:Connect(function(player)
		local started = sessionStart[player]
		local d = S.PlayerDataService.Get(player)
		fold(player)
		sessionStart[player] = nil
		lastFold[player] = nil
		if started then
			local furthest = d and type(d.Telemetry) == "table" and d.Telemetry.Furthest or 0
			local stepName = "None"
			for _, f in FUNNEL do
				if f.Step == furthest then
					stepName = f.Name
				end
			end
			send(function()
				AnalyticsService:LogCustomEvent(player, "SessionEnd", math.floor(os.clock() - started), {
					[Enum.AnalyticsCustomFieldKeys.CustomField01.Name] = stepName,
				})
			end)
		end
	end)
	-- fold play time into the profile periodically: PlayerDataService's leave save writes whatever is in memory at that moment
	task.spawn(function()
		while true do
			task.wait(PLAYTIME_STEP)
			for player in lastFold do
				if player.Parent then
					fold(player)
				end
			end
		end
	end)
end

return LaunchTelemetryService
