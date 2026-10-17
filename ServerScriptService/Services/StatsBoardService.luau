--!strict
-- PERSISTENT LEADERBOARDS (global, via OrderedDataStore): Lifetime Contribution, Total Builds Completed, Master Builder Rank
-- and Mythic Builds Completed. Values are pushed every minute (only when they changed) and on leave; the top lists are
-- cached and refreshed every couple of minutes, so reading never hits the store per request. When the store is
-- unavailable (Studio without API access) the boards fall back to the players in this server and say so.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)

local StatsBoardService = {}
local S: any

local TOP = 10
local PUSH_INTERVAL = 60
local REFRESH_INTERVAL = 150

StatsBoardService.Boards = {
	{ Id = "Contribution", Title = "Lifetime Contribution", Value = function(d: any): number return math.floor(d.Stats.LifetimeContribution or 0) end },
	{ Id = "Builds", Title = "Builds Completed", Value = function(d: any): number return d.Stats.BuildsCompleted or 0 end },
	{ Id = "MasterRank", Title = "Master Builder Rank", Value = function(d: any): number return d.MasterBuilder.Rank or 0 end },
	{ Id = "Mythic", Title = "Mythic Builds Completed", Value = function(d: any): number return (d.Stats.CompletedByRarity or {}).Mythic or 0 end },
}

local stores: { [string]: OrderedDataStore } = {}
local storeOk = false
local pushed: { [Player]: { [string]: number } } = {}
local dirty: { [Player]: boolean } = {}
local cache: { [string]: { { u: number, name: string, v: number } } } = {}
local names: { [number]: string } = {}
local lastRefresh = 0

function StatsBoardService.Init(registry)
	S = registry
	local ok = pcall(function()
		for _, b in StatsBoardService.Boards do
			stores[b.Id] = DataStoreService:GetOrderedDataStore("MB_Board_v1_" .. b.Id)
		end
	end)
	storeOk = ok
end

function StatsBoardService.Touch(player: Player)
	dirty[player] = true
end

local function nameOf(userId: number): string
	local p = Players:GetPlayerByUserId(userId)
	if p then
		names[userId] = p.DisplayName
		return p.DisplayName
	end
	if names[userId] then
		return names[userId]
	end
	local ok, n = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	names[userId] = if ok then n else "Builder"
	return names[userId]
end

local function push(player: Player)
	local d = S.PlayerDataService.Get(player)
	if not d or not storeOk then
		return
	end
	local last = pushed[player] or {}
	pushed[player] = last
	for _, b in StatsBoardService.Boards do
		local v = b.Value(d)
		if v > 0 and last[b.Id] ~= v then
			local ok = pcall(function()
				stores[b.Id]:SetAsync(tostring(player.UserId), v)
			end)
			if ok then
				last[b.Id] = v
			else
				storeOk = false
				return
			end
		end
	end
	dirty[player] = nil
end

-- Local fallback: players currently in this server.
local function localTop(b: any): { any }
	local list = {}
	for _, p in Players:GetPlayers() do
		local d = S.PlayerDataService.Get(p)
		if d then
			local v = b.Value(d)
			if v > 0 then
				table.insert(list, { u = p.UserId, name = p.DisplayName, v = v })
			end
		end
	end
	table.sort(list, function(a, c)
		return a.v > c.v
	end)
	return list
end

function StatsBoardService.Refresh()
	lastRefresh = os.clock()
	for _, b in StatsBoardService.Boards do
		local list: { any } = {}
		local ok = false
		if storeOk then
			ok = pcall(function()
				local page = stores[b.Id]:GetSortedAsync(false, TOP):GetCurrentPage()
				for _, e in page do
					local u = tonumber(e.key) or 0
					table.insert(list, { u = u, name = nameOf(u), v = e.value })
				end
			end)
		end
		if not ok then
			list = localTop(b)
		end
		cache[b.Id] = list
	end
end

function StatsBoardService.Get(): { any }
	if os.clock() - lastRefresh > REFRESH_INTERVAL or next(cache) == nil then
		StatsBoardService.Refresh()
	end
	local out = {}
	for _, b in StatsBoardService.Boards do
		table.insert(out, { Id = b.Id, Title = b.Title, Entries = cache[b.Id] or {}, Global = storeOk })
	end
	return out
end

function StatsBoardService.Start()
	local limiter = Net.RateLimiter(0.25, 2)
	Net.Function("GetBoards").OnServerInvoke = function(player)
		if not limiter(player) then
			return {}
		end
		return StatsBoardService.Get()
	end
	Players.PlayerRemoving:Connect(function(p)
		push(p)
		pushed[p] = nil
		dirty[p] = nil
	end)
	S.PlayerDataService.Loaded:Connect(function(player)
		dirty[player] = true
	end)
	task.spawn(function()
		while true do
			task.wait(PUSH_INTERVAL)
			-- snapshot first: the loop yields, and joins/leaves edit `dirty` meanwhile
			local list = {}
			for p in dirty do
				table.insert(list, p)
			end
			for _, p in list do
				if p.Parent and dirty[p] then
					pcall(push, p)
					task.wait(0.2)
				end
			end
		end
	end)
	game:BindToClose(function()
		for _, p in Players:GetPlayers() do
			push(p)
		end
	end)
end

return StatsBoardService
