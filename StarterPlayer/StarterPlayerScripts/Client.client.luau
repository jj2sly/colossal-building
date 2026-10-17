--!strict
-- Client entry point. Each controller owns one slice of presentation (HUD, tracker,
-- reveal, carry visuals...). Controllers only READ replicated state and send intent
-- remotes; the server is authoritative for everything that matters.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local controllers = script.Parent:WaitForChild("Controllers")
local ORDER = {
	"NotifyController",
	"HUDController",
	"TrackerController",
	"LeaderboardController",
	"RevealController",
	"EventUIController",
	"CelebrationController",
	"CarryVisualController",
	"BuildFXController",
	"SpectacleController",
	"BuildShowController",
	"AmbienceController",
	"LifeController",
	"MusicController",
	"MutationController",
	"GatherController",
	"WorkerVisualController",
	"TrainingController",
	"UpgradePanel",
	"IndexPanel",
	"WorkerPanel",
	"VehiclePanel",
	"VehicleDriveController",
	"CosmeticVisualController",
	"RewardsPanel",
	"OnboardingController",
	"DebugController",
	"AdminPanelController",
}

-- Notify + HUD start synchronously first: other controllers parent into the HUD's
-- containers, so they must exist before those controllers start.
local SYNC_START = { NotifyController = true, HUDController = true }

for _, name in ORDER do
	local ok, mod = pcall(require, controllers:WaitForChild(name))
	if not ok then
		warn("[Client] failed to load", name, mod)
	elseif mod.Start then
		local function run()
			local ok2, err = pcall(mod.Start)
			if not ok2 then
				warn("[Client] start failed", name, err)
			end
		end
		if SYNC_START[name] then
			run()
		else
			task.spawn(run)
		end
	end
end

Net.Event("RequestSync"):FireServer()
