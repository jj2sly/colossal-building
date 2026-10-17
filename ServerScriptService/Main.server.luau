--!strict
-- Server entry point. Loads every service, wires them through a shared registry
-- (no service requires another directly, which avoids circular dependencies), then
-- runs Init on all services followed by Start on all services.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
Net.Setup()

-- loud startup check that no implemented build silently vanished from BuildConfig (see BuildConfig.RequiredIds)
do
	local BuildConfig = require(ReplicatedStorage.Shared.Config.BuildConfig)
	local problems = BuildConfig.Validate()
	for _, msg in problems do
		warn("[BuildConfig] " .. msg)
	end
	if #problems == 0 then
		print(string.format("[BuildConfig] ok: %d canonical builds; pools %s", #BuildConfig.RequiredIds, BuildConfig.PoolSummary()))
	end
end

-- launch sanity for monetization: free-first rules, and a single reminder while store ids are still placeholders (0 = the
-- store shows "Coming soon" and nothing can be bought, which is safe but probably not intended on a public server)
do
	local MonetizationConfig = require(ReplicatedStorage.Shared.Config.MonetizationConfig)
	local okR, problems = pcall(MonetizationConfig.FreeFirstReport)
	if not okR then
		warn("[MonetizationConfig] check failed: " .. tostring(problems))
	else
		for _, msg in problems do
			warn("[MonetizationConfig] " .. msg)
		end
	end
	local missing = {}
	for key, p in MonetizationConfig.Passes do
		if (p.PassId or 0) <= 0 then
			table.insert(missing, key)
		end
	end
	for key, b in MonetizationConfig.Boosts do
		if (b.ProductId or 0) <= 0 then
			table.insert(missing, key)
		end
	end
	for key, b in MonetizationConfig.ServerBoosts do
		if (b.ProductId or 0) <= 0 then
			table.insert(missing, key)
		end
	end
	if #missing > 0 and not game:GetService("RunService"):IsStudio() then
		table.sort(missing)
		warn("[MonetizationConfig] placeholder store ids (shown as Coming soon): " .. table.concat(missing, ", "))
	end
end

local ORDER = {
	"StateService",
	"PlayerDataService",
	"TelemetryService",
	"FriendService",
	"ServerLuckService",
	"UpgradeService",
	"VehicleService",
	"ResourceService",
	"MutationService",
	"SecretResourceService",
	"TrainingService",
	"ContributionService",
	"ModifierService",
	"BuildService",
	"DepositService",
	"EventService",
	"WorkerService",
	"BuildIndexService",
	"AchievementService",
	"CosmeticService",
	"BoostService",
	"PurchaseService",
	"MasterBuilderService",
	"ForgottenService",
	"DailyService",
	"StatsBoardService",
	"DropService",
	"RewardService",
	"SelectionService",
	"VotingService",
	"ShopService",
	"GameLoopService",
	"DebugService",
	"AdminService",
}

local servicesFolder = ServerScriptService:WaitForChild("Services")
local registry: { [string]: any } = {}
for _, name in ORDER do
	registry[name] = require(servicesFolder:WaitForChild(name) :: ModuleScript)
end
for _, name in ORDER do
	local svc = registry[name]
	if svc.Init then
		svc.Init(registry)
	end
end
for _, name in ORDER do
	local svc = registry[name]
	if svc.Start then
		task.spawn(svc.Start)
	end
end
print("[MegaBuild] server started")
