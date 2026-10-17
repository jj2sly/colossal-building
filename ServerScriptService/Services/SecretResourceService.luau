--!strict
-- SECRET RESOURCE EVENTS (hook). Future events can call SpawnCache to drop a temporary cache of a secret resource anywhere on the
-- map. The nodes are ordinary ResourceNodes carrying a SecretId, so access stays PERSONAL: ResourceService refuses a gather from
-- anyone who has not unlocked that secret, and only eligible players get the announcement. Nothing runs per frame: one delay per cache.
--
--   SecretResourceService.SpawnCache("StarMetal", Vector3.new(x, y, z), 3, 90)   -- 3 nodes for 90 s
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Net = require(Shared.Net)
local ResourceConfig = require(Shared.Config.ResourceConfig)
local SecretResourceConfig = require(Shared.Config.SecretResourceConfig)
local CollectionService = game:GetService("CollectionService")

local SecretResourceService = {}
local S: any
local folder: Folder

function SecretResourceService.Init(registry)
	S = registry
end

-- Can this player gather the secret right now? (also exposed for UI / debug)
function SecretResourceService.CanAccess(player: Player, secretId: string): boolean
	return SecretResourceConfig.CanAccess(secretId, S.PlayerDataService.Get(player))
end

-- Spawns a temporary cache. Returns the nodes.
function SecretResourceService.SpawnCache(secretId: string, position: Vector3, count: number, lifetime: number): { BasePart }
	local sdef = SecretResourceConfig.Secrets[secretId]
	local res = sdef and sdef.ResourceId and ResourceConfig.Resources[sdef.ResourceId]
	local nodes: { BasePart } = {}
	if not sdef or not sdef.Enabled or not res then
		return nodes
	end
	for i = 1, count do
		local a = (i / count) * math.pi * 2
		local p = Instance.new("Part")
		p.Name = "SecretCacheNode"
		p.Anchored = true
		p.Size = Vector3.new(3.2, 2.6, 3.2)
		p.Position = position + Vector3.new(math.cos(a) * 4, 1.3, math.sin(a) * 4)
		p.Color = res.Color
		p.Material = res.Material
		p.TopSurface = Enum.SurfaceType.Smooth
		p:SetAttribute("ResourceId", res.Id)
		p:SetAttribute("SecretId", secretId)
		p:SetAttribute("SpotId", res.Zone)
		local glow = Instance.new("PointLight")
		glow.Color = if secretId == "StarMetal" then Color3.fromRGB(120, 190, 255) else Color3.fromRGB(255, 205, 110)
		glow.Range = 14
		glow.Brightness = 0.9
		glow.Shadows = false
		glow.Parent = p
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = ColorSequence.new(glow.Color)
		e.LightEmission = 0.6
		e.Rate = 4
		e.Lifetime = NumberRange.new(1.2, 2)
		e.Speed = NumberRange.new(1, 2.5)
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 0) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
		e.Parent = p
		p.Parent = folder
		CollectionService:AddTag(p, "ResourceNode") -- ResourceService adds the gather prompt
		table.insert(nodes, p)
	end
	-- announce to the players who can actually use it
	for _, pl in Players:GetPlayers() do
		if SecretResourceService.CanAccess(pl, secretId) then
			Net.Event("Effect"):FireClient(pl, "SecretCache", { Name = string.upper(res.DisplayName), Pos = position })
		end
	end
	task.delay(lifetime, function()
		for _, n in nodes do
			if n.Parent then
				n:Destroy()
			end
		end
	end)
	return nodes
end

function SecretResourceService.Start()
	local old = workspace:FindFirstChild("MB_SecretCaches")
	if old then
		old:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "MB_SecretCaches"
	folder.Parent = workspace
end

return SecretResourceService
