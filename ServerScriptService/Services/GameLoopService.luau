--!strict
-- The server round state machine:
--   Intermission -> (Voting every N builds | Selecting) -> Reveal -> Building
--   -> Complete (rewards, index, luck, celebration) -> Resetting -> repeat
-- There is no failure state; Building lasts until the build is finished.
-- Debug tools can Restart (abort the current cycle cleanly) or Skip the current wait.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local BuildConfig = require(Shared.Config.BuildConfig)
local RarityConfig = require(Shared.Config.RarityConfig)
local Formulas = require(Shared.Formulas)
local SeasonConfig = require(Shared.Config.SeasonConfig)
local MasterProjectConfig = require(Shared.Config.MasterProjectConfig)
local SpectacleConfig = require(Shared.Config.SpectacleConfig)
local ColossalConfig = require(Shared.Config.ColossalConfig)

local GameLoopService = {}
local S: any

local abortFlag = false
local skipFlag = false
local completedFlag = false

local function now(): number
	return workspace:GetServerTimeNow()
end

local function setPhase(name: string, duration: number?)
	S.StateService.Set("Phase", name)
	S.StateService.Set("PhaseEndsAt", if duration then now() + duration else 0)
end

-- Waits `seconds`; returns false if the cycle was aborted. Skip ends the wait early.
local function waitFor(seconds: number): boolean
	local t = os.clock() + seconds
	skipFlag = false
	while os.clock() < t do
		if abortFlag then
			return false
		end
		if skipFlag then
			skipFlag = false
			return true
		end
		task.wait(0.1)
	end
	return not abortFlag
end

local function titleFor(choice: any): string
	local def = BuildConfig.Get(choice.BuildId)
	local name = def and def.DisplayName or choice.BuildId
	-- skip modifier words the name already contains ("GIANT GIANT ROBOT" -> "GIANT ROBOT");
	-- the modifier tags still show every modifier
	local words = {}
	for _, w in string.split(S.ModifierService.Prefix(choice.Modifiers), " ") do
		if w ~= "" and not string.find(string.upper(name), w, 1, true) then
			table.insert(words, w)
		end
	end
	local prefix = table.concat(words, " ")
	return string.upper(if prefix ~= "" then prefix .. " " .. name else name)
end

local function cleanupBuild()
	S.ForgottenService.ClearPending() -- an unclaimed first-discovery reward is forfeited when the project ends
	S.EventService.EndSchedule()
	S.BuildService.Clear()
	S.ContributionService.Reset()
	S.WorkerService.ResetAll()
	S.StateService.Set("BuildLegacy", false)
	S.StateService.Set("BuildId", "")
	S.StateService.Set("BuildTitle", "")
	S.StateService.Set("Rarity", "")
	S.StateService.Set("Modifiers", "")
end

local function runCycle()
	local T = GameConfig.Timing
	setPhase("Intermission", T("Intermission"))
	if not waitFor(T("Intermission")) then
		return
	end

	-- 1. choose the build (vote every N completions)
	local choice
	local isVote = false
	local milestone = S.StateService.Get("MilestoneCount") or 0
	-- MASTER PROJECT: starts automatically the moment the server meets an enabled project's conditions (no vote, everyone can
	-- help). Guarded: any error or missing build simply falls back to the normal selection.
	local project = nil
	if not S.SelectionService.HasForcedBuild() then
		local okP, p = pcall(S.MasterBuilderService.EligibleMasterProject)
		if okP and p and p.Build and BuildConfig.Get(p.Build) then
			project = p
		elseif not okP then
			warn("[GameLoop] Master Project check failed:", p)
		end
	end
	-- FORGOTTEN: only a dev ForceNext starts one here. Natural encounters are rolled below, only in place of an ordinary random selection.
	local forgotten = nil
	if not project and not S.SelectionService.HasForcedBuild() then
		local okF, f = pcall(S.ForgottenService.EligibleForgotten)
		if okF and f and f.Build and BuildConfig.Get(f.Build) then
			forgotten = f
		elseif not okF then
			warn("[GameLoop] Forgotten check failed:", f)
		end
	end
	if project then
		setPhase("Selecting", 0.5)
		choice = { BuildId = project.Build, Modifiers = {} }
		local mpc: any = MasterProjectConfig
		mpc.ForceNext = nil -- a dev override is single-use
		S.StateService.Set("MasterProject", project.Id)
		S.StateService.Set("MasterProjectAt", S.StateService.Get("BuildsCompleted") or 0)
		Net.Event("Notify"):FireAllClients("Success", "MASTER PROJECT: " .. string.upper(project.DisplayName) .. "! Everyone can help.", 7)
	elseif forgotten then
		setPhase("Selecting", 0.5)
		choice = { BuildId = forgotten.Build, Modifiers = {} }
		S.ForgottenService.ForceNext = nil -- a dev override is single-use
		S.StateService.Set("MasterProject", "")
	elseif milestone >= GameConfig.VoteEveryNBuilds and not S.SelectionService.HasForcedBuild() then
		local options = S.SelectionService.VoteOptions()
		-- ballot cards show what each option would cost and pay (display data only)
		local voteScale = Formulas.RequirementScale(S.BuildService.ActivePlayerCount())
		for _, o in options do
			local d = BuildConfig.Get(o.BuildId)
			if d then
				o.Title = titleFor(o)
				o.RewardMultiplier = S.RewardService.Multiplier(d, o.Modifiers)
				o.Requirements = S.BuildService.ComputeRequirements(d, o.Modifiers, voteScale)
			end
		end
		if #options > 1 then
			local duration = T("VoteDuration")
			setPhase("Voting", duration)
			local idx = S.VotingService.Run(options, duration, function()
				return abortFlag or skipFlag
			end)
			skipFlag = false
			if abortFlag then
				return
			end
			choice = options[idx]
			isVote = true
			if not waitFor(2.5) then
				return
			end
		else
			-- only one build in the rolled tier: no ballot, it simply becomes the next build
			choice = options[1]
		end
		S.StateService.Set("MilestoneCount", 0)
	else
		setPhase("Selecting", 0.5)
		-- natural Forgotten encounter: only where an ordinary random selection would happen (no vote, project or forced selection)
		if not S.SelectionService.HasForced() then
			local okN, nat = pcall(S.ForgottenService.RollNatural)
			if okN and nat and nat.Build and BuildConfig.Get(nat.Build) then
				forgotten = nat
			elseif not okN then
				warn("[GameLoop] Forgotten roll failed:", nat)
			end
		end
		if forgotten then
			choice = { BuildId = forgotten.Build, Modifiers = {} }
		else
			choice = S.SelectionService.Next()
		end
		S.StateService.Set("MasterProject", "")
	end
	S.SelectionService.SetLast(choice.BuildId)
	local def = BuildConfig.Get(choice.BuildId)
	if not def then
		warn("[GameLoop] unknown build", choice.BuildId)
		task.wait(1)
		return
	end

	-- 2. reveal
	local scale = Formulas.RequirementScale(S.BuildService.ActivePlayerCount())
	local secretScales, secretSubs = nil, nil
	if def.Forgotten then
		secretScales, secretSubs = S.ForgottenService.SecretPlan(def)
	end
	local requirements = S.BuildService.ComputeRequirements(def, choice.Modifiers, scale, secretScales, secretSubs)
	local title = if forgotten then "???" else titleFor(choice) -- a Forgotten name is never shown before personal discovery
	-- LEGACY build: an ended-event build that came back through the rare activation chance (or was forced)
	local isLegacy = def.Season ~= nil and SeasonConfig.PoolOf(def.Season) == "Legacy"
	if isLegacy then
		title = "LEGACY " .. title
		Net.Event("Notify"):FireAllClients("Success", "LEGACY BUILD: " .. def.DisplayName .. " has returned!", 7)
	end
	S.StateService.Set("BuildLegacy", isLegacy)
	S.StateService.Set("BuildId", def.Id)
	-- a Forgotten structure shows as a neutral "???" (never a real tier) in replicated state until a player holds its record
	local publicRarity = if def.Forgotten then "Hidden" else def.Rarity
	S.StateService.Set("Rarity", publicRarity)
	S.StateService.Set("Modifiers", table.concat(choice.Modifiers, ","))
	S.StateService.Set("BuildTitle", title)
	local revealScale = RarityConfig.RevealScale[def.Rarity] or { Roll = 1, Hold = 1 }
	local rollTime, holdTime = T("RevealRoll") * revealScale.Roll, T("RevealHold") * revealScale.Hold
	if project then
		rollTime, holdTime = T("RevealRoll") * 1.05, T("RevealHold") * 1.7 -- a full ~11 s Master Project reveal (overlay only)
	end
	if forgotten then
		rollTime, holdTime = 4.2, 7.2 -- fake rarity -> ??? -> FORGOTTEN STRUCTURE DISCOVERED -> name (~11 s, overlay only)
	end
	setPhase("Reveal", rollTime + holdTime)
	local candidates = {}
	for r in S.SelectionService.CandidateRarities() do
		table.insert(candidates, r)
	end
	table.sort(candidates, function(a, b)
		return RarityConfig.Get(a).Order < RarityConfig.Get(b).Order
	end)
	if forgotten then
		-- PERSONAL DISCOVERY happens here, at the encounter: every present player records the discovery (reward hook fires once),
		-- receives the real identity and plays ??? -> DISCOVERED -> name. Nothing identifying is in the shared state or payload.
		for _, pl in Players:GetPlayers() do
			if S.PlayerDataService.IsLoaded(pl) then
				local ok, info = pcall(S.ForgottenService.Encounter, pl, forgotten)
				Net.Event("Reveal"):FireClient(pl, {
					Forgotten = true,
					Rarity = "Forgotten",
					Title = "???",
					Name = if ok then info.Name else nil,
					Repeat = ok and info.Repeat or false,
					Modifiers = {},
					RewardMultiplier = 1,
					Requirements = {},
					RollTime = rollTime,
					HoldTime = holdTime,
					Candidates = {},
					FakeFrom = forgotten.FakeAs,
				})
			end
		end
	else
		Net.Event("Reveal"):FireAllClients({
			BuildId = def.Id,
			Rarity = def.Rarity,
			Title = title,
			Name = def.DisplayName,
			Modifiers = choice.Modifiers,
			RewardMultiplier = S.RewardService.Multiplier(def, choice.Modifiers),
			Requirements = requirements,
			RollTime = rollTime,
			HoldTime = holdTime,
			Candidates = candidates,
			Voted = isVote,
			Legacy = isLegacy,
			MasterProject = project ~= nil,
			ProjectName = if project then project.DisplayName else nil,
		})
	end
	if not waitFor(rollTime + holdTime) then
		return
	end

	-- 3. build
	if not S.BuildService.Begin(def.Id, choice.Modifiers, scale, secretScales, secretSubs) then
		task.wait(2)
		return
	end
	S.ContributionService.Reset()
	completedFlag = false
	setPhase("Building", nil)
	S.EventService.BeginSchedule()
	local conn = S.BuildService.Completed:Connect(function()
		completedFlag = true
	end)
	while not completedFlag and not abortFlag do
		task.wait(0.2)
	end
	conn:Disconnect()
	S.EventService.EndSchedule()
	if abortFlag then
		return
	end

	-- 4. completion: lock, finish animation, celebrate, reward
	local anim, view = T("CompletionAnimation"), T("CelebrationView")
	-- every completion show gets its rarity's spectacle window before the site resets (Forgotten shows run up to 20 s)
	if def.CompletionSpectacle then
		local sp = SpectacleConfig.Spectacles[def.CompletionSpectacle]
		view = math.max(view, ColossalConfig.SpectacleSeconds(def, sp and sp.Duration) + 1.5)
	end
	if def.MasterProject and def.CompletionSpectacle then
		-- a Master Project's show always plays to the end before the site resets (also with dev-shortened timings)
		local sp = SpectacleConfig.Spectacles[def.CompletionSpectacle]
		view = math.max(view, (sp and sp.Duration or 12) + 1.5)
	end
	setPhase("Complete", anim + view)
	local elapsed = S.BuildService.ElapsedSeconds()
	S.BuildService.FinishPresentation()
	Net.Event("Effect"):FireAllClients("BuildComplete", {
		Title = title,
		Rarity = publicRarity,
		Position = GameConfig.Site.Center,
	})
	if not waitFor(anim) then
		return
	end
	-- the finished build may put on a short show (client-side, see SpectacleConfig); it overlaps the celebration
	if def.CompletionSpectacle then
		Net.Event("Spectacle"):FireAllClients({ Id = def.CompletionSpectacle, BuildId = def.Id, Position = GameConfig.Site.Center })
	end
	local results = S.RewardService.Compute(def, choice.Modifiers)
	S.RewardService.Apply(results)
	S.TelemetryService.Record("Complete", nil, def, choice.Modifiers, S.BuildService.ElapsedSeconds(), results)
	local luckGain = S.ServerLuckService.AddForRarity(def.Rarity)
	if def.MasterProject then
		-- the server became more valuable: a big (but not capping) Server Luck bump
		local before = S.ServerLuckService.Get()
		S.ServerLuckService.Set(before + MasterProjectConfig.ServerLuckBonus)
		luckGain += S.ServerLuckService.Get() - before
		Net.Event("Notify"):FireAllClients("Success", string.format("MASTER PROJECT COMPLETE! Server Luck +%d", math.floor(luckGain + 0.5)), 8)
	end
	S.StateService.Set("BuildsCompleted", (S.StateService.Get("BuildsCompleted") or 0) + 1)
	if not def.Forgotten and not def.MasterProject then
		S.ForgottenService.NoteNormalCompleted()
	end
	if not isVote then
		S.StateService.Set("MilestoneCount", (S.StateService.Get("MilestoneCount") or 0) + 1)
	end
	local top = {}
	for _, r in results do
		if r.Eligible and #top < 3 then
			table.insert(top, { u = r.Player.UserId, n = r.Player.DisplayName, p = math.floor(r.Points) })
		end
	end
	local summary = {
		BuildId = def.Id,
		Title = title,
		Rarity = publicRarity,
		MasterProject = def.MasterProject == true,
		Modifiers = choice.Modifiers,
		Seconds = math.floor(elapsed),
		TotalContribution = math.floor(S.ContributionService.Total()),
		Top = top,
		ServerLuck = S.ServerLuckService.Get(),
		LuckGain = luckGain,
		Participants = #results,
	}
	for _, r in results do
		if r.Player.Parent then
			local isNew = false
			if r.Eligible then
				S.DropService.Roll(r.Player, def, choice.Modifiers)
				isNew = S.BuildIndexService.Record(r.Player, {
					BuildId = def.Id,
					Modifiers = choice.Modifiers,
					ContributionPct = r.Share,
					CompletionSeconds = elapsed,
					Reward = r.Coins,
					IsMVP = r.Rank == 1,
				})
			end
			local mine = summary
			if forgotten and S.ForgottenService.Has(r.Player, forgotten.Id) then
				-- the certificate shows the real name only to a player who holds the record
				mine = table.clone(summary)
				mine.Title = string.upper(forgotten.Name)
				mine.Rarity = "Forgotten"
			end
			Net.Event("Celebration"):FireClient(r.Player, mine, {
				Eligible = r.Eligible,
				Rank = r.Rank,
				Coins = r.Coins,
				Lucky = r.Lucky,
				FriendBonus = r.FriendBonus,
				Points = math.floor(r.Points),
				Share = r.Share,
				NewDiscovery = isNew,
			})
		end
	end
	if not waitFor(view) then
		return
	end

	-- 5. reset
	local fade = math.max(T("ResetFade"), ColossalConfig.ResetSeconds(def))
	setPhase("Resetting", fade)
	Net.Event("Effect"):FireAllClients("BuildReset", { Time = fade })
	waitFor(fade)
end

function GameLoopService.Init(registry)
	S = registry
end

function GameLoopService.Start()
	S.StateService.Set("BuildsCompleted", 0)
	S.StateService.Set("MilestoneCount", 0)
	S.StateService.Set("VoteEvery", GameConfig.VoteEveryNBuilds)
	cleanupBuild()
	-- give the first player a moment to load in
	task.wait(2)
	while true do
		abortFlag = false
		local ok, err = pcall(runCycle)
		if not ok then
			warn("[GameLoop] cycle error:", err)
			task.wait(2)
		end
		cleanupBuild()
	end
end

-- Abort the current cycle (state is cleaned up and a new cycle starts).
function GameLoopService.Restart()
	abortFlag = true
end

function GameLoopService.Skip()
	skipFlag = true
end

-- Debug: mark the active build complete right now (fills requirements, repairs all).
function GameLoopService.ForceComplete()
	if S.BuildService.IsActive() then
		S.BuildService.RepairAll()
		S.BuildService.FillTo(1)
	end
end

return GameLoopService
