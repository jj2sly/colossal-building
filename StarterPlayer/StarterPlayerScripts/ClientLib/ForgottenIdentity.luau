--!nonstrict
-- FORGOTTEN IDENTITY (client). The server never replicates a Forgotten build's real name, stage names or activation points; a
-- player receives them as a personal "ForgottenIdentity" effect only after holding that structure's record. Until then the opaque
-- key in State BuildId resolves to nothing here, so the tracker shows "???" and the Index has no Forgotten tab.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)

local ForgottenIdentity = {}
local known = {}

-- A BuildConfig-shaped def (DisplayName, StageNames, ActivateAt, Milestones, Rarity) or nil while undiscovered.
function ForgottenIdentity.Def(key: any): any
	local k = known[key]
	return if k then { Id = k.Key, DisplayName = k.Name, Rarity = "Forgotten", StageNames = k.StageNames, ActivateAt = k.ActivateAt, Milestones = k.Milestones, Forgotten = true } else nil
end

Net.Event("Effect").OnClientEvent:Connect(function(id, payload)
	if id == "ForgottenIdentity" and type(payload) == "table" and type(payload.Key) == "string" then
		known[payload.Key] = payload
	end
end)

return ForgottenIdentity
