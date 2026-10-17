--!strict
-- Owns ReplicatedStorage.GameState: the replicated, server-written snapshot that every
-- client UI reads (see Shared/Types for the attribute contract). Attribute writes are
-- de-duplicated so unchanged values never generate network traffic.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StateService = {}

local folder: Configuration

function StateService.Init()
	local existing = ReplicatedStorage:FindFirstChild("GameState")
	if existing then
		existing:Destroy()
	end
	folder = Instance.new("Configuration")
	folder.Name = "GameState"
	folder.Parent = ReplicatedStorage
end

function StateService.Set(key: string, value: any)
	if folder:GetAttribute(key) ~= value then
		folder:SetAttribute(key, value)
	end
end

function StateService.Get(key: string): any
	return folder:GetAttribute(key)
end

-- Clears every attribute whose name starts with one of the prefixes.
function StateService.ClearPrefixed(prefixes: { string })
	for name in folder:GetAttributes() do
		for _, p in prefixes do
			if string.sub(name, 1, #p) == p then
				folder:SetAttribute(name, nil)
				break
			end
		end
	end
end

function StateService.Folder(): Configuration
	return folder
end

return StateService
