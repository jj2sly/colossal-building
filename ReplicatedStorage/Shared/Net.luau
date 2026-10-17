--!strict
-- Central remote registry. The server creates every remote once (Net.Setup); clients
-- fetch them by name. Remotes are semantic (one per intent), never per value; values
-- every client needs (phase, requirements, luck, events) replicate through attributes
-- on ReplicatedStorage.GameState instead of remotes.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.Events = {
	-- server -> client
	"Notify", -- (kind, text) toast
	"Effect", -- (effectId, payload) one-shot visual/audio cue
	"Leaderboard", -- (top, selfEntry, totals)
	"Reveal", -- (payload) rarity reveal sequence
	"VoteState", -- (payload) vote open/update/close
	"Celebration", -- (payload) completion summary + personal rewards
	"Discovery", -- (buildId) NEW BUILD DISCOVERED
	"PlayerSync", -- (privateData) upgrades/index/vehicles/worker for the local player
	"DebugReport", -- (text) long dev reports (balance telemetry) for the debug panel
	"TrainingUpdate", -- (msg) training session start / tick / carry / deliver / lap / end for the local player
	"Spectacle", -- (payload) a finished build plays its completion spectacle (client-side show)
	-- client -> server
	"RequestSync", -- client asks for its PlayerSync after its UI loads
	"DropCarry",
	"VoteCast",
	"WorkerCommand",
	"VehicleCommand",
	"DebugCommand",
	"EquipTitle",
	"TrainingRequest", -- ("Hit", challengeId) | ("Stop")
	"EquipCosmetic", -- (category, id | "") equip or unequip an owned cosmetic
}

Net.Functions = {
	"BuyUpgrade",
	"BuyItem",
	"MasterBuilderAdvance", -- () -> (ok, payload | reason): confirmed rank-up
	"DailyClaim", -- () -> (ok, payload | reason)
	"GetBoards", -- () -> persistent leaderboards { [statId] = { {u, name, v} } }
	"WorkerCrate", -- (cmd, arg) -> (ok, result | reason): "Open" | "Equip" ({Type, Tier}) | "Info"
	"StorePurchase", -- (kind, key) -> (ok, message): starts a purchase (opens Roblox checkout); never grants anything itself
	"AdminRequest", -- (action, args) -> { ok, msg, data }: developer admin panel; the server re-checks AdminConfig on EVERY call
}

local folder: Folder? = nil
local cache: { [string]: Instance } = {}

function Net.Setup()
	assert(RunService:IsServer(), "Net.Setup is server-only")
	local f = ReplicatedStorage:FindFirstChild("Remotes")
	if f then
		f:Destroy()
	end
	local newFolder = Instance.new("Folder")
	newFolder.Name = "Remotes"
	for _, name in Net.Events do
		local r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = newFolder
	end
	for _, name in Net.Functions do
		local r = Instance.new("RemoteFunction")
		r.Name = name
		r.Parent = newFolder
	end
	newFolder.Parent = ReplicatedStorage
	folder = newFolder
end

local function get(name: string): Instance
	local c = cache[name]
	if c then
		return c
	end
	if not folder then
		folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
	end
	local r = (folder :: Folder):WaitForChild(name)
	cache[name] = r
	return r
end

function Net.Event(name: string): RemoteEvent
	return get(name) :: RemoteEvent
end

function Net.Function(name: string): RemoteFunction
	return get(name) :: RemoteFunction
end

-- Simple per-player token bucket for client->server remotes.
-- Returns a function(player) -> boolean (true = allowed).
function Net.RateLimiter(perSecond: number, burst: number)
	local buckets: { [Player]: { tokens: number, t: number } } = {}
	game:GetService("Players").PlayerRemoving:Connect(function(p)
		buckets[p] = nil
	end)
	return function(player: Player): boolean
		local now = os.clock()
		local b = buckets[player]
		if not b then
			b = { tokens = burst, t = now }
			buckets[player] = b
		end
		b.tokens = math.min(burst, b.tokens + (now - b.t) * perSecond)
		b.t = now
		if b.tokens >= 1 then
			b.tokens -= 1
			return true
		end
		return false
	end
end

return Net
