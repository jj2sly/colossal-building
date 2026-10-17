--!strict
-- PURCHASES (server-authoritative). The client never says what it owns: it can only ask the server to START a purchase
-- (StorePurchase), and everything granted comes from Roblox receipts / verified pass ownership.
--
--   Developer products: MarketplaceService.ProcessReceipt -> ProcessReceipt() below. Every receipt id is recorded in
--     PlayerData.Purchases.Receipts BEFORE anything is granted and saved before PurchaseGranted is returned, so a retried or
--     duplicated receipt can never grant twice. A player who is gone / not loaded returns NotProcessedYet (Roblox retries).
--   Game passes: ownership is verified with UserOwnsGamePassAsync on join and after PromptGamePassPurchaseFinished, then stored in
--     PlayerData.Purchases.Passes (persistent; an API outage never takes a pass away). Entitlements are re-applied (idempotently)
--     on every join.
--   DEV SIMULATION: only when GameConfig.IsDev() (Studio + Dev.Enabled) and MonetizationConfig.DevSimulation. It runs the SAME grant
--     and receipt code with a synthetic receipt, so duplicate protection is exercised too. Live servers can never take this path.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local GameConfig = require(Shared.Config.GameConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)

local PurchaseService = {}
local S: any

function PurchaseService.Init(registry)
	S = registry
end

local function devSimulationAllowed(): boolean
	return GameConfig.IsDev() and MonetizationConfig.DevSimulation
end

------------------------------------------------------------------ grants
-- Applies a pass entitlement to a loaded player: cosmetics are (re)granted, bonuses are read live by BoostService.
local function applyPass(player: Player, key: string)
	local pass = MonetizationConfig.Passes[key]
	if not pass then
		return
	end
	for _, g in pass.Grants or {} do
		S.CosmeticService.Grant(player, g.Category, g.Item, "pass")
	end
	player:SetAttribute("Pass_" .. key, true)
end

function PurchaseService.GrantPass(player: Player, key: string): boolean
	local d = S.PlayerDataService.Get(player)
	if not d or not MonetizationConfig.Passes[key] then
		return false
	end
	d.Purchases.Passes[key] = true
	applyPass(player, key)
	S.PlayerDataService.MarkDirty(player)
	S.PlayerDataService.Sync(player)
	return true
end

-- Grants one product (personal or server boost). Returns true on success.
local function grantProduct(player: Player, kind: string, def: any): boolean
	if kind == "Boost" then
		local ok = S.BoostService.StartPersonalBoost(player, def.Key)
		if ok then
			Net.Event("Notify"):FireClient(player, "Success", def.Name .. " active!", 4)
		end
		return ok
	elseif kind == "ServerBoost" then
		return (S.BoostService.StartServerBoost(player, def.Key))
	end
	return false
end

------------------------------------------------------------------ receipts
local inFlight: { [string]: boolean } = {} -- receipt ids currently granting/saving (Roblox can re-invoke while we yield)

local function remember(d: any, id: string)
	local r = d.Purchases.Receipts
	r[id] = os.time()
	local count = 0
	for _ in r do
		count += 1
	end
	if count > MonetizationConfig.Caps.ReceiptHistory then
		-- drop the oldest entries
		local ids = {}
		for k, t in r do
			table.insert(ids, { k = k, t = t })
		end
		table.sort(ids, function(a, b)
			return a.t < b.t
		end)
		for i = 1, count - MonetizationConfig.Caps.ReceiptHistory do
			r[ids[i].k] = nil
		end
	end
end

-- receipt = { PurchaseId, PlayerId, ProductId, ... }; sim = { Kind, Key } is supplied only by dev simulation.
function PurchaseService.ProcessReceipt(receipt: any, sim: any?): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receipt.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local d = S.PlayerDataService.Get(player)
	if not d then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if S.PlayerDataService.IsSaveBlocked(player) then
		-- their profile failed to load this session: nothing we grant here could be saved, and a later session would grant it
		-- again. Leave the receipt pending; Roblox re-offers it when they join a server where their data loads.
		Net.Event("Notify"):FireClient(player, "Warn", "Your purchase will be delivered the next time your data loads (rejoin).", 6)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local id = tostring(receipt.PurchaseId)
	if inFlight[id] then
		return Enum.ProductPurchaseDecision.NotProcessedYet -- the first call is still granting / saving this receipt
	end
	if d.Purchases.Receipts[id] then
		-- already granted (never grant twice). Acknowledge only once that record is safely in the store.
		inFlight[id] = true
		local saved = S.PlayerDataService.SaveNow(player)
		inFlight[id] = nil
		return if saved then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local kind, def
	if sim then
		kind = sim.Kind
		def = if kind == "Boost" then MonetizationConfig.Boosts[sim.Key] else MonetizationConfig.ServerBoosts[sim.Key]
	else
		kind, def = MonetizationConfig.ByProductId(receipt.ProductId)
	end
	if not def then
		warn("[Purchase] unknown product", receipt.ProductId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	remember(d, id)
	if not grantProduct(player, kind :: string, def) then
		d.Purchases.Receipts[id] = nil
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	S.PlayerDataService.MarkDirty(player)
	-- Acknowledge only after the receipt record + grant are actually in the store. If the save fails we return NotProcessedYet:
	-- the receipt id stays recorded in memory (a retry in this server re-saves instead of re-granting) and the profile stays
	-- dirty, so the next autosave / leave save persists it; Roblox's retry then finds the id and acknowledges without a 2nd grant.
	inFlight[id] = true
	local okSave, saved = pcall(S.PlayerDataService.SaveNow, player)
	inFlight[id] = nil
	S.PlayerDataService.Sync(player)
	return if okSave and saved then Enum.ProductPurchaseDecision.PurchaseGranted else Enum.ProductPurchaseDecision.NotProcessedYet
end

------------------------------------------------------------------ passes
local function verifyPass(player: Player, pass: any): boolean
	if pass.PassId <= 0 then
		return false
	end
	local ok, owns = pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, player.UserId, pass.PassId)
	return ok and owns == true
end

local function refreshPasses(player: Player)
	local d = S.PlayerDataService.Get(player)
	if not d then
		return
	end
	for key, pass in MonetizationConfig.Passes do
		if not d.Purchases.Passes[key] and verifyPass(player, pass) then
			d.Purchases.Passes[key] = true
			S.PlayerDataService.MarkDirty(player)
		end
		if d.Purchases.Passes[key] then
			applyPass(player, key)
		end
	end
end

------------------------------------------------------------------ starting a purchase
-- Called by the Store UI. Returns (ok, message). With a real id it opens Roblox's own prompt; the grant happens later through
-- ProcessReceipt / the pass-finished event. With id 0 it is "coming soon" live and a clearly marked simulation in Studio.
function PurchaseService.Begin(player: Player, kind: string, key: string): (boolean, string)
	local def
	local id = 0
	if kind == "Pass" then
		def = MonetizationConfig.Passes[key]
		id = def and def.PassId or 0
		local d = S.PlayerDataService.Get(player)
		if d and d.Purchases.Passes[key] then
			return false, "You already own this"
		end
	elseif kind == "Boost" then
		def = MonetizationConfig.Boosts[key]
		id = def and def.ProductId or 0
	elseif kind == "ServerBoost" then
		def = MonetizationConfig.ServerBoosts[key]
		id = def and def.ProductId or 0
	end
	if not def then
		return false, "Unknown item"
	end
	if kind == "Boost" or kind == "ServerBoost" then
		-- never open checkout for a boost that could not add its full time (no paying Robux for nothing)
		local can, why = S.BoostService.CanBuy(player, kind, key)
		if not can then
			return false, why or "Not available right now"
		end
	end
	if id <= 0 then
		if devSimulationAllowed() then
			local ok, msg = PurchaseService.Simulate(player, kind, key)
			return ok, "[DEV SIMULATION] " .. msg
		end
		return false, "Not available yet"
	end
	if kind == "Pass" then
		MarketplaceService:PromptGamePassPurchase(player, id)
	else
		MarketplaceService:PromptProductPurchase(player, id)
	end
	return true, "Opening checkout..."
end

-- DEV ONLY: runs a purchase through the real grant code. `purchaseId` lets a test repeat the SAME receipt.
local simCounter = 0
function PurchaseService.Simulate(player: Player, kind: string, key: string, purchaseId: string?): (boolean, string)
	if not devSimulationAllowed() then
		return false, "Simulation is disabled outside Studio"
	end
	if kind == "Pass" then
		return PurchaseService.GrantPass(player, key), "pass " .. key
	end
	simCounter += 1
	local pid = purchaseId or ("SIM-" .. player.UserId .. "-" .. os.time() .. "-" .. simCounter)
	local decision = PurchaseService.ProcessReceipt({ PurchaseId = pid, PlayerId = player.UserId, ProductId = 0 }, { Kind = kind, Key = key })
	return decision == Enum.ProductPurchaseDecision.PurchaseGranted, string.format("%s %s (receipt %s -> %s)", kind, key, pid, decision.Name)
end

function PurchaseService.Start()
	-- the one ProcessReceipt callback (Roblox allows a single assignment)
	MarketplaceService.ProcessReceipt = function(receipt)
		return PurchaseService.ProcessReceipt(receipt)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then
			return
		end
		-- PromptGamePassPurchaseFinished is raised by Roblox on the server, so wasPurchased is trustworthy here; UserOwnsGamePassAsync
		-- can return a cached "false" right after a purchase, which used to leave a paid pass ungranted until the next join.
		local pass = MonetizationConfig.PassByProductId(passId)
		if pass then
			PurchaseService.GrantPass(player, pass.Key)
			Net.Event("Notify"):FireClient(player, "Success", pass.Name .. " unlocked. Thank you!", 5)
		end
	end)
	local limiter = Net.RateLimiter(0.5, 2)
	Net.Function("StorePurchase").OnServerInvoke = function(player, kind, key)
		if not limiter(player) or type(kind) ~= "string" or type(key) ~= "string" then
			return false, "Slow down"
		end
		return PurchaseService.Begin(player, kind, key)
	end
	S.PlayerDataService.Loaded:Connect(function(player)
		task.spawn(refreshPasses, player)
	end)
end

return PurchaseService
