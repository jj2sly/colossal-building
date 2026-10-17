--!strict
-- Counts Roblox friends present in this server for the Friend Bonus (+2%/friend, capped).
-- Friendship checks are cached per pair and run once when someone joins, so this costs
-- O(players) web calls per join, not per round. GameConfig.Dev.FriendCountOverride (or
-- the debug panel) forces a count for testing in Studio where friends are rarely present.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Formulas = require(ReplicatedStorage.Shared.Formulas)

local FriendService = {}

local friendsOf: { [Player]: { [Player]: boolean } } = {}
local override: number? = nil

local function publish(player: Player)
	local count = 0
	for other in friendsOf[player] or {} do
		if other.Parent then
			count += 1
		end
	end
	-- overrides only exist in Studio dev mode; a live server can never read them
	local forced = nil
	if GameConfig.IsDev() then
		forced = override or GameConfig.Dev.FriendCountOverride
	end
	if forced then
		count = forced
	end
	player:SetAttribute("FriendsInServer", count)
end

-- One retry on API failure; if the API stays unavailable the pair is simply treated as
-- "not friends" (no bonus) and gameplay is unaffected.
local function checkPair(a: Player, b: Player)
	local ok, isFriend = pcall(function()
		return a:IsFriendsWith(b.UserId)
	end)
	if not ok then
		task.wait(2)
		ok, isFriend = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
	end
	-- the web call yields: if either player left meanwhile, don't re-insert them (PlayerRemoving already cleaned up)
	if ok and isFriend and a.Parent and b.Parent then
		friendsOf[a] = friendsOf[a] or {}
		friendsOf[b] = friendsOf[b] or {}
		friendsOf[a][b] = true
		friendsOf[b][a] = true
	end
end

function FriendService.Start()
	Players.PlayerAdded:Connect(function(player)
		friendsOf[player] = friendsOf[player] or {}
		for _, other in Players:GetPlayers() do
			if not player.Parent then
				return -- left while the friendship checks were running
			end
			if other ~= player and other.Parent then
				checkPair(player, other)
				publish(other)
			end
		end
		publish(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		local mine = friendsOf[player]
		friendsOf[player] = nil
		for other in mine or {} do
			if friendsOf[other] then
				friendsOf[other][player] = nil
				publish(other)
			end
		end
	end)
	for _, p in Players:GetPlayers() do
		friendsOf[p] = friendsOf[p] or {}
		publish(p)
	end
end

-- Dev/test only (reachable through DebugService, which is gated): link two players as
-- friends without the web API, exercising the same publish/leave code paths.
function FriendService.DebugLink(a: Player, b: Player)
	if not GameConfig.IsDev() then
		return
	end
	friendsOf[a] = friendsOf[a] or {}
	friendsOf[b] = friendsOf[b] or {}
	friendsOf[a][b] = true
	friendsOf[b][a] = true
	publish(a)
	publish(b)
end

function FriendService.GetBonus(player: Player): number
	return Formulas.FriendBonus(player:GetAttribute("FriendsInServer") or 0)
end

function FriendService.SetOverride(count: number?)
	if not GameConfig.IsDev() then
		return
	end
	override = count
	for _, p in Players:GetPlayers() do
		publish(p)
	end
end

return FriendService
