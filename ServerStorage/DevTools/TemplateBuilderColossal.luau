--!nonstrict
-- EDIT-TIME GENERATOR for COLOSSAL build templates. Every module in DevTools/ColossalBuilds (except Kit) is one build:
-- it returns { Id, Build(kit) -> Model } and is written to ServerStorage.BuildTemplates.<Id> (replacing an older one).
-- Run: require(game.ServerStorage.DevTools.TemplateBuilderColossal:Clone()).BuildAll()
local ServerStorage = game:GetService("ServerStorage")

local TB = {}

function TB.BuildAll(only: string?): string
	local folder = ServerStorage.DevTools.ColossalBuilds -- (run from a :Clone(), so script.Parent is nil)
	local Kit = require(folder.Kit:Clone())
	local templates = ServerStorage:FindFirstChild("BuildTemplates")
	if not templates then
		templates = Instance.new("Folder")
		templates.Name = "BuildTemplates"
		templates.Parent = ServerStorage
	end
	local out = {}
	for _, mod in folder:GetChildren() do
		if mod:IsA("ModuleScript") and mod.Name ~= "Kit" and (only == nil or only == mod.Name) then
			local def = require(mod:Clone())
			Kit.ResetCount()
			local model = def.Build(Kit)
			model.WorldPivot = CFrame.new() -- bottom-centre of the footprint = the build origin
			local old = templates:FindFirstChild(def.Id)
			if old then
				old:Destroy()
			end
			model.Name = def.Id
			model.Parent = templates
			local _, size = model:GetBoundingBox()
			local stages = 0
			for _, c in model:GetChildren() do
				if string.match(c.Name, "^Stage_%d+$") then
					stages += 1
				end
			end
			table.insert(out, string.format("%s: %d parts, %d stages, %.0f x %.0f x %.0f", def.Id, Kit.Count(), stages, size.X, size.Y, size.Z))
		end
	end
	table.sort(out)
	return table.concat(out, "\n")
end

return TB
