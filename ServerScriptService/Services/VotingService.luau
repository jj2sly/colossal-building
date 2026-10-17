--!strict
-- Milestone vote: players pick the next build from the options SelectionService
-- produced. One vote per player (changeable), tallies broadcast at most ~3x/sec,
-- ties resolved randomly. With a single option the vote is skipped.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)

local VotingService = {}
local S: any

local open = false
local options: { any } = {}
local votes: { [Player]: number } = {}
local endsAt = 0
local broadcastQueued = false

local function tallies(): { number }
	local t = table.create(#options, 0)
	for p, idx in votes do
		if p.Parent then
			t[idx] += 1
		end
	end
	return t
end

local function broadcast(state: string)
	Net.Event("VoteState"):FireAllClients({
		State = state,
		Options = options,
		Tallies = tallies(),
		EndsAt = endsAt,
	})
end

function VotingService.Init(registry)
	S = registry
end

function VotingService.Start()
	Net.Event("VoteCast").OnServerEvent:Connect(function(player, idx)
		if not open or type(idx) ~= "number" or idx ~= idx then
			return
		end
		idx = math.floor(idx)
		if idx < 1 or idx > #options then
			return
		end
		votes[player] = idx
		if not broadcastQueued then
			broadcastQueued = true
			task.delay(0.3, function()
				broadcastQueued = false
				if open then
					broadcast("Update")
				end
			end)
		end
	end)
	Players.PlayerRemoving:Connect(function(p)
		if votes[p] then
			votes[p] = nil
			if open then
				broadcast("Update")
			end
		end
	end)
	-- players joining mid-vote get the open ballot
	Players.PlayerAdded:Connect(function(p)
		if open then
			Net.Event("VoteState"):FireClient(p, {
				State = "Open",
				Options = options,
				Tallies = tallies(),
				EndsAt = endsAt,
			})
		end
	end)
end

-- Runs a vote (yields for `duration`). Returns the winning option index.
function VotingService.Run(opts: { any }, duration: number, shouldAbort: () -> boolean): number
	if #opts <= 1 then
		return 1 -- nothing to vote on; the reveal still announces the build
	end
	options = opts
	table.clear(votes)
	endsAt = workspace:GetServerTimeNow() + duration
	open = true
	broadcast("Open")
	while workspace:GetServerTimeNow() < endsAt and not shouldAbort() do
		task.wait(0.25)
	end
	open = false
	local t = tallies()
	local best, winners = -1, {}
	for i, n in t do
		if n > best then
			best, winners = n, { i }
		elseif n == best then
			table.insert(winners, i)
		end
	end
	local winner = winners[Random.new():NextInteger(1, #winners)]
	Net.Event("VoteState"):FireAllClients({ State = "Closed", Options = options, Tallies = t, Winner = winner, EndsAt = endsAt })
	return winner
end

return VotingService
