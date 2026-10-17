--!strict
-- Random server events framework. While a build is under construction, a scheduler
-- picks an enabled event (EventConfig weights) whose module says it CanStart, runs it
-- for its Duration, then stops it. Event modules live in Services/Events and implement:
--   CanStart(ctx) -> boolean           (optional)
--   Start(ctx, def) -> cleanup?        (required; may yield for warnings)
--   Stop(ctx, def)                     (optional)
-- ctx exposes the registry plus helpers (SetModifier, Announce, Param...).
-- Gameplay services query multipliers through EventService.* so events never reach
-- into other services' internals.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local EventConfig = require(Shared.Config.EventConfig)
local Weighted = require(Shared.Util.Weighted)

local EventService = {}
local S: any

local modules: { [string]: any } = {}
local current: { id: string, def: any, cleanup: (() -> ())?, token: number }? = nil
local token = 0
local schedulerToken = 0

-- active multipliers (reset when events stop)
local mult = {
	Carry = 1,
	Coins = 1,
	Construction = 1,
	DepositSpeed = 1,
	GatherYield = {} :: { [string]: number },
	GatherSpeed = {} :: { [string]: number },
}

local function resetMultipliers()
	mult.Carry = 1
	mult.Coins = 1
	mult.Construction = 1
	mult.DepositSpeed = 1
	table.clear(mult.GatherYield)
	table.clear(mult.GatherSpeed)
end

local function intervalScale(): number
	return if GameConfig.IsDev() then GameConfig.Dev.EventIntervalMultiplier else 1
end

local ctx = {}

function ctx.Registry()
	return S
end

function ctx.SetCarryMultiplier(m: number)
	mult.Carry = m
	S.ResourceService.RefreshAllCapacities()
end

function ctx.SetGatherBoost(resId: string, yield: number, speed: number)
	mult.GatherYield[resId] = yield
	mult.GatherSpeed[resId] = speed
end

function ctx.SetCoinMultiplier(m: number)
	mult.Coins = m
end

function ctx.SetConstructionMultiplier(construction: number, depositSpeed: number)
	mult.Construction = construction
	mult.DepositSpeed = depositSpeed
end

function ctx.SetState(phase: string, endsAt: number, param: string?)
	S.StateService.Set("EventPhase", phase)
	S.StateService.Set("EventEndsAt", endsAt)
	S.StateService.Set("EventParam", param or "")
end

function ctx.Effect(effectId: string, payload: any)
	Net.Event("Effect"):FireAllClients(effectId, payload)
end

function ctx.IsCurrent(t: number): boolean
	return current ~= nil and current.token == t
end

function EventService.Init(registry)
	S = registry
	local folder = ServerScriptService:WaitForChild("Services"):WaitForChild("Events")
	for id, def in EventConfig.Events do
		local m = folder:FindFirstChild(def.Module)
		if def.Enabled and m then
			modules[id] = require(m :: ModuleScript)
		elseif def.Enabled then
			warn("[Events] enabled event has no module:", id)
		end
	end
end

function EventService.CarryMultiplier(): number
	return mult.Carry
end

function EventService.GatherYieldMultiplier(resId: string): number
	return mult.GatherYield[resId] or 1
end

function EventService.GatherSpeedMultiplier(resId: string): number
	return mult.GatherSpeed[resId] or 1
end

function EventService.CoinMultiplier(): number
	return mult.Coins
end

-- Build Frenzy: each delivered unit counts this much toward construction.
function EventService.ConstructionMultiplier(): number
	return mult.Construction
end

function EventService.DepositSpeedMultiplier(): number
	return mult.DepositSpeed
end

function EventService.Current(): string?
	return current and current.id
end

function EventService.StopCurrent()
	local c = current
	if not c then
		return
	end
	current = nil
	local m = modules[c.id]
	if c.cleanup then
		pcall(c.cleanup)
	end
	if m and m.Stop then
		pcall(m.Stop, ctx, c.def)
	end
	-- always restore neutral multipliers, whatever the event did
	resetMultipliers()
	S.ResourceService.RefreshAllCapacities()
	S.StateService.Set("EventId", "")
	ctx.SetState("", 0, nil)
	Net.Event("Effect"):FireAllClients("EventEnded", { Id = c.id })
end

-- Starts an event now (used by scheduler and debug). Returns success.
function EventService.Trigger(id: string): boolean
	local def = EventConfig.Events[id]
	local m = modules[id]
	if not def or not m then
		return false
	end
	if m.CanStart and not m.CanStart(ctx, def) then
		return false
	end
	EventService.StopCurrent()
	token += 1
	local myToken = token
	current = { id = id, def = def, cleanup = nil, token = myToken }
	if S.ForgottenService and S.ForgottenService.NoteEvent then
		S.ForgottenService.NoteEvent(id) -- session flag (e.g. an Earthquake has happened)
	end
	S.StateService.Set("EventId", id)
	Net.Event("Effect"):FireAllClients("EventStarted", { Id = id })
	task.spawn(function()
		local ok, cleanup = pcall(m.Start, ctx, def, myToken)
		if not ok then
			warn("[Events] start failed:", id, cleanup)
		end
		if current and current.token == myToken then
			current.cleanup = if type(cleanup) == "function" then cleanup else nil
			-- Start may have used part of the time for a warning; end at EventEndsAt.
			local endsAt = S.StateService.Get("EventEndsAt")
			local remaining = if type(endsAt) == "number" and endsAt > 0 then endsAt - workspace:GetServerTimeNow() else def.Duration
			task.wait(math.max(0, remaining))
			if current and current.token == myToken then
				EventService.StopCurrent()
			end
		end
	end)
	return true
end

local function pickEvent(): string?
	local candidates = {}
	for id, def in EventConfig.Events do
		local m = modules[id]
		if m and def.Enabled and (not m.CanStart or m.CanStart(ctx, def)) then
			table.insert(candidates, def)
		end
	end
	local chosen = Weighted.Pick(candidates, function(d)
		return d.Weight
	end)
	return chosen and chosen.Id
end

-- Called by the game loop when construction begins/ends.
function EventService.BeginSchedule()
	schedulerToken += 1
	local my = schedulerToken
	task.spawn(function()
		task.wait(EventConfig.FirstEventDelay * intervalScale())
		while schedulerToken == my do
			if S.BuildService.IsActive() and not current then
				local id = pickEvent()
				if id then
					EventService.Trigger(id)
				end
			end
			local lo, hi = EventConfig.Interval[1], EventConfig.Interval[2]
			-- modifiers such as Corrupted make events more frequent
			local active = S.BuildService.Get()
			local modMult = if active then S.ModifierService.EventIntervalMultiplier(active.modifiers) else 1
			task.wait(Random.new():NextNumber(lo, hi) * intervalScale() * modMult)
		end
	end)
end

function EventService.EndSchedule()
	schedulerToken += 1
	EventService.StopCurrent()
end

function EventService.Start()
	S.StateService.Set("EventId", "")
	ctx.SetState("", 0, nil)
end

return EventService
