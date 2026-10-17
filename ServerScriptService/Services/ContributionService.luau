--!strict
-- Per-round contribution tracking + throttled leaderboard broadcast.
-- Sources: player deliveries (x1), repairs (x RepairWeight), worker deliveries
-- (x WorkerWeight). Standing AFK earns nothing.
--
-- The leaderboard is sent as a compact {userId, points} list at most every
-- LeaderboardBroadcastInterval seconds and only when something changed, so 50 players
-- depositing at once doesn't spam remotes. Clients resolve names locally.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)

local ContributionService = {}
local S: any

local points: { [number]: number } = {} -- userId -> points (survives leave/rejoin within the round)
local names: { [number]: string } = {}
local dirty = false
local roundTotal = 0
local changed: { [Player]: boolean } = {}

function ContributionService.Init(registry)
	S = registry
end

local function setLeaderstat(player: Player, value: number)
	local ls = player:FindFirstChild("leaderstats")
	local built = ls and ls:FindFirstChild("Built")
	if built then
		(built :: IntValue).Value = math.floor(value)
	end
end

function ContributionService.Add(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local id = player.UserId
	points[id] = (points[id] or 0) + amount
	names[id] = player.DisplayName
	roundTotal += amount
	-- replicated values are flushed with the leaderboard broadcast (not per deposit tick),
	-- so 50 players depositing doesn't flood attribute replication
	changed[player] = true
	dirty = true
end

function ContributionService.Get(player: Player): number
	return points[player.UserId] or 0
end

function ContributionService.Total(): number
	return roundTotal
end

-- Sorted standings of players currently in the server.
function ContributionService.Standings(): { { player: Player, points: number } }
	local list = {}
	for _, p in Players:GetPlayers() do
		table.insert(list, { player = p, points = points[p.UserId] or 0 })
	end
	table.sort(list, function(a, b)
		if a.points ~= b.points then
			return a.points > b.points
		end
		return a.player.UserId < b.player.UserId
	end)
	return list
end

function ContributionService.Reset()
	table.clear(points)
	table.clear(changed)
	roundTotal = 0
	for _, p in Players:GetPlayers() do
		p:SetAttribute("Contribution", 0)
		setLeaderstat(p, 0)
	end
	dirty = true
end

function ContributionService.Broadcast()
	dirty = false
	for p in changed do
		if p.Parent then
			local v = points[p.UserId] or 0
			p:SetAttribute("Contribution", math.floor(v))
			setLeaderstat(p, v)
		end
	end
	table.clear(changed)
	local list = {}
	for _, entry in ContributionService.Standings() do
		if entry.points > 0 then
			table.insert(list, { u = entry.player.UserId, p = math.floor(entry.points) })
		end
	end
	Net.Event("Leaderboard"):FireAllClients(list, math.floor(roundTotal))
end

function ContributionService.Start()
	Players.PlayerAdded:Connect(function(p)
		p:SetAttribute("Contribution", math.floor(points[p.UserId] or 0))
		task.delay(1, function()
			if p.Parent then
				setLeaderstat(p, points[p.UserId] or 0)
			end
		end)
		dirty = true
	end)
	Players.PlayerRemoving:Connect(function(p)
		changed[p] = nil
		dirty = true
	end)
	task.spawn(function()
		while true do
			task.wait(GameConfig.Timings.LeaderboardBroadcastInterval)
			if dirty then
				ContributionService.Broadcast()
			end
		end
	end)
end

return ContributionService
