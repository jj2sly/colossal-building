--!strict
-- DEVELOPER ADMIN: the single place that decides who may use the admin panel. SERVER-ONLY (ServerScriptService), so
-- clients never see this list. Authorization is by numeric UserId only (usernames can be changed or spoofed in
-- display), and every admin action is checked against it again on the server (AdminService); hiding the client UI
-- is cosmetic.
local AdminConfig = {}

-- UserId -> label (the label is only a note for humans; it is never used for authorization).
AdminConfig.Admins = {
	[1596279643] = "jj",
} :: { [number]: string }

-- A reset of the invoking admin's OWN profile is refused in live servers unless this is true (Studio / mock data
-- always allows it; it still needs the confirmation token below).
AdminConfig.AllowLiveProfileReset = false

-- Studio-only test hook (ServerStorage.MB_AdminBridge) for exercising the unauthorized path from the MCP command
-- bar. Keep this false; it is never created outside Studio.
AdminConfig.TestBridge = false

AdminConfig.RateLimit = { PerSecond = 6, Burst = 12 }
AdminConfig.ResetToken = "RESET" -- Profile.Reset must carry this exact string (the client asks for confirmation first)

-- Teleport targets: Id -> label. "Spawn" / "Training" are world markers, the rest are ResourceSpotConfig ids.
AdminConfig.Teleports = {
	{ Id = "Spawn", Label = "Spawn" },
	{ Id = "Training", Label = "Training" },
	{ Id = "Forest", Label = "Stick Grove" },
	{ Id = "LumberCamp", Label = "Logging Camp" },
	{ Id = "TimberStand", Label = "Redwood" },
	{ Id = "Quarry", Label = "Rock Field" },
	{ Id = "DeepQuarry", Label = "Quarry" },
	{ Id = "BoulderField", Label = "Mountain Excavation" },
	{ Id = "Mine", Label = "Scrap Yard" },
	{ Id = "IndustrialYard", Label = "Foundry" },
	{ Id = "SteelWorks", Label = "Steel Mine" },
	{ Id = "Energy", Label = "Battery Depot" },
	{ Id = "ReactorYard", Label = "Power Plant" },
	{ Id = "CoreVault", Label = "Reactor" },
	{ Id = "StarCrater", Label = "Star Crater" },
	{ Id = "AncientGrove", Label = "Ancient Grove" },
}

function AdminConfig.IsAdmin(player: any): boolean
	local id = if typeof(player) == "Instance" or type(player) == "table" then player.UserId else nil
	return type(id) == "number" and AdminConfig.Admins[id] ~= nil
end

return AdminConfig
