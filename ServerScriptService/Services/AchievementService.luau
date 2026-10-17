--!strict
-- Achievements + titles. Check(player) compares persistent stats with AchievementConfig
-- and unlocks anything newly reached (granting its title). Players can equip one
-- unlocked title, shown above their head; the server validates ownership.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local AchievementConfig = require(Shared.Config.AchievementConfig)

local AchievementService = {}
local S: any

local function titleOwned(d: any, title: string): boolean
	for id, a in AchievementConfig.Achievements do
		if a.Title == title and d.Achievements[id] then
			return true
		end
	end
	return false
end

local function applyTitle(player: Player)
	local d = S.PlayerDataService.Get(player)
	local char = player.Character
	local head = char and char:FindFirstChild("Head")
	if not head then
		return
	end
	local existing = head:FindFirstChild("MB_Title")
	local title = d and d.EquippedTitle or ""
	if title == "" then
		if existing then
			existing:Destroy()
		end
		return
	end
	local gui = existing :: BillboardGui?
	if not gui then
		local g = Instance.new("BillboardGui")
		g.Name = "MB_Title"
		g.Size = UDim2.fromOffset(200, 26)
		g.StudsOffset = Vector3.new(0, 2.6, 0)
		g.MaxDistance = 80
		local l = Instance.new("TextLabel")
		l.BackgroundTransparency = 1
		l.Size = UDim2.fromScale(1, 1)
		l.Font = Enum.Font.FredokaOne
		l.TextScaled = true
		l.TextColor3 = Color3.fromRGB(255, 215, 90)
		l.TextStrokeTransparency = 0.3
		l.Parent = g
		g.Parent = head
		gui = g
	end
	local label = (gui :: BillboardGui):FindFirstChildOfClass("TextLabel")
	if label then
		label.Text = "« " .. title .. " »"
	end
end

function AchievementService.Init(registry)
	S = registry
end

-- Unlock anything the player now qualifies for. Cheap: a handful of table reads.
function AchievementService.Check(player: Player)
	local d = S.PlayerDataService.Get(player)
	if not d then
		return
	end
	local changed = false
	for _, a in AchievementConfig.Ordered() do
		if not d.Achievements[a.Id] and AchievementConfig.StatValue(d.Stats, a.Stat) >= a.Target then
			d.Achievements[a.Id] = true
			d.Titles[a.Title] = true
			changed = true
			Net.Event("Effect"):FireClient(player, "Achievement", { Id = a.Id })
		end
	end
	if changed then
		S.PlayerDataService.MarkDirty(player)
	end
end

local limiter = Net.RateLimiter(1, 3)

function AchievementService.Start()
	Net.Event("EquipTitle").OnServerEvent:Connect(function(player, title)
		if not limiter(player) or type(title) ~= "string" or #title > 40 then
			return
		end
		local d = S.PlayerDataService.Get(player)
		if not d then
			return
		end
		if title ~= "" and not titleOwned(d, title) then
			return
		end
		d.EquippedTitle = title
		S.PlayerDataService.MarkDirty(player)
		applyTitle(player)
	end)
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(char)
			char:WaitForChild("Head", 10)
			applyTitle(player)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	S.PlayerDataService.Loaded:Connect(function(player)
		AchievementService.Check(player)
		applyTitle(player)
	end)
end

return AchievementService
