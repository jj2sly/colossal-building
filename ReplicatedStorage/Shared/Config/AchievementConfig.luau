--!strict
-- Achievements + the cosmetic titles they unlock. Each achievement is data only:
-- unlocked when the player's persistent stat at `Stat` (dot path into PlayerData.Stats)
-- reaches `Target`. Add one by appending an entry; AchievementService checks them all.
-- Titles are status only (shown above the player's head when equipped).
export type Achievement = {
	Id: string,
	Order: number,
	DisplayName: string,
	Description: string,
	Stat: string,
	Target: number,
	Title: string,
	Icon: string,
}

local AchievementConfig = {}

AchievementConfig.Achievements = {
	FirstBuild = {
		Id = "FirstBuild", Order = 1, DisplayName = "First Build",
		Description = "Help complete your first build.",
		Stat = "BuildsCompleted", Target = 1, Title = "First Brick", Icon = "🧱",
	},
	Builder = {
		Id = "Builder", Order = 2, DisplayName = "Builder",
		Description = "Help complete 10 builds.",
		Stat = "BuildsCompleted", Target = 10, Title = "Builder", Icon = "🔨",
	},
	Builds25 = {
		Id = "Builds25", Order = 3, DisplayName = "25 Builds Completed",
		Description = "Help complete 25 builds.",
		Stat = "BuildsCompleted", Target = 25, Title = "Veteran Builder", Icon = "🏗",
	},
	TopContributor = {
		Id = "TopContributor", Order = 4, DisplayName = "Top Contributor",
		Description = "Be the #1 contributor (MVP) on a build.",
		Stat = "MVPCount", Target = 1, Title = "Top Contributor", Icon = "🏆",
	},
	RepairCrew = {
		Id = "RepairCrew", Order = 5, DisplayName = "Repair Crew",
		Description = "Deliver 100 resources to repair damaged sections.",
		Stat = "LifetimeRepairs", Target = 100, Title = "Repair Crew", Icon = "🔧",
	},
	LegendaryBuilder = {
		Id = "LegendaryBuilder", Order = 6, DisplayName = "Legendary Builder",
		Description = "Help complete a Legendary build.",
		Stat = "CompletedByRarity.Legendary", Target = 1, Title = "Legendary Builder", Icon = "⭐",
	},
	MythicWitness = {
		Id = "MythicWitness", Order = 7, DisplayName = "Mythic Witness",
		Description = "Help complete a Mythic build.",
		Stat = "CompletedByRarity.Mythic", Target = 1, Title = "Mythic Witness", Icon = "🐉",
	},
} :: { [string]: Achievement }

-- Reads a dot-path stat ("CompletedByRarity.Legendary") from a Stats table.
function AchievementConfig.StatValue(stats: any, path: string): number
	local v: any = stats
	for _, key in string.split(path, ".") do
		if type(v) ~= "table" then
			return 0
		end
		v = v[key]
	end
	return if type(v) == "number" then v else 0
end

function AchievementConfig.Ordered(): { Achievement }
	local list = {}
	for _, a in AchievementConfig.Achievements do
		table.insert(list, a)
	end
	table.sort(list, function(a, b)
		return a.Order < b.Order
	end)
	return list
end

return AchievementConfig
