--!strict
-- Cosmetic ownership. The ONE place that grants cosmetics (rare drops, Index milestones, later Master Builder and
-- event rewards all call CosmeticService.Grant). Ownership is stored in PlayerData.Cosmetics[Category][Id];
-- Titles live in PlayerData.Titles. See CosmeticConfig for the catalogue.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local CosmeticConfig = require(Shared.Config.CosmeticConfig)

local CosmeticService = {}
local S: any

function CosmeticService.Init(registry)
	S = registry
end

function CosmeticService.Owns(player: Player, category: string, id: string): boolean
	local d = S.PlayerDataService.Get(player)
	if not d then
		return false
	end
	if category == "Title" then
		return d.Titles[id] == true
	end
	local cat = d.Cosmetics[category]
	return cat ~= nil and cat[id] == true
end

-- The Equippable entry for a category (nil for categories equipped elsewhere: Title, WorkerOutfit).
function CosmeticService.Info(category: string): any?
	for _, e in CosmeticConfig.Equippable do
		if e.Category == category then
			return e
		end
	end
	return nil
end

-- Equips an owned cosmetic (id "" or nil unequips). The selection persists in PlayerData.Equipped and is mirrored to
-- a player attribute so every client can draw it. Returns (ok, message).
function CosmeticService.Equip(player: Player, category: string, id: string?): (boolean, string)
	local d = S.PlayerDataService.Get(player)
	local info = CosmeticService.Info(category)
	if not d or not info then
		return false, "Cannot equip that"
	end
	if id == nil or id == "" then
		d.Equipped[category] = nil
		player:SetAttribute(info.Attribute, nil)
	else
		if not CosmeticService.Owns(player, category, id) or not CosmeticConfig.Get(category, id) then
			return false, "You don't own that"
		end
		d.Equipped[category] = id
		player:SetAttribute(info.Attribute, id)
	end
	S.PlayerDataService.MarkDirty(player)
	if category == "VehicleSkin" then
		S.VehicleService.ApplySkin(player)
	end
	return true, "Equipped"
end

-- Mirrors saved selections to attributes (after load) and drops selections that are no longer owned.
function CosmeticService.Refresh(player: Player)
	local d = S.PlayerDataService.Get(player)
	if not d then
		return
	end
	for _, info in CosmeticConfig.Equippable do
		local id = d.Equipped[info.Category]
		if id and not CosmeticService.Owns(player, info.Category, id) then
			d.Equipped[info.Category] = nil
			id = nil
		end
		player:SetAttribute(info.Attribute, id)
	end
end

function CosmeticService.Start()
	local limiter = Net.RateLimiter(3, 6)
	Net.Event("EquipCosmetic").OnServerEvent:Connect(function(player, category, id)
		if not limiter(player) or type(category) ~= "string" or (id ~= nil and type(id) ~= "string") then
			return
		end
		local ok, msg = CosmeticService.Equip(player, category, id)
		if not ok then
			Net.Event("Notify"):FireClient(player, "Error", msg)
		end
	end)
	S.PlayerDataService.Loaded:Connect(function(player)
		CosmeticService.Refresh(player)
	end)
end

-- Grants an item once. Returns true if it was NEW (false = the player already owned it).
function CosmeticService.Grant(player: Player, category: string, id: string, source: string?): boolean
	local d = S.PlayerDataService.Get(player)
	if not d then
		return false
	end
	if CosmeticService.Owns(player, category, id) then
		return false
	end
	if category == "Title" then
		d.Titles[id] = true
	else
		d.Cosmetics[category] = d.Cosmetics[category] or {}
		d.Cosmetics[category][id] = true
	end
	S.PlayerDataService.MarkDirty(player)
	-- the first item you ever own in a visual category is equipped for you, so a new reward is seen straight away
	local info = CosmeticService.Info(category)
	if info and not (d.Equipped or {})[category] then
		CosmeticService.Equip(player, category, id)
	end
	if source ~= "Worker type" then
		Net.Event("Notify"):FireClient(player, "Success", string.format("New %s: %s", string.lower(category == "WorkerOutfit" and "Worker outfit" or category), CosmeticConfig.Name(category, id)), 4)
	end
	return true
end

return CosmeticService
