--!strict
-- SECRET RESOURCES (foundation only). A secret resource is an extra resource id that only players who personally
-- unlocked it can gather, whoever else is standing nearby. Access is checked by the SERVER per player
-- (SecretResourceConfig.CanAccess); nodes carry the attribute `SecretId`, and ResourceService refuses a gather when the
-- check fails, so a Master Builder's friend gains nothing from standing next to them.
--
-- Nothing here is content-complete: the table lists no resources by default (Enabled entries are what the world builder /
-- event system may spawn). To add Star Metal later:
--   1. add the resource to ResourceConfig (with `Secret = "StarMetal"`),
--   2. add an entry below,
--   3. place nodes tagged ResourceNode with attribute SecretId = "StarMetal" (hidden area), or let an event spawn them.
--
-- Unlock requirements (all optional; every one that is present must hold):
--   MinMasterRank   Master Builder rank
--   Flag            a boolean the server sets in PlayerData.Unlocks[Flag] (event reward, achievement...)
--   MinBuilds       lifetime builds completed
local SecretResourceConfig = {}

export type Secret = {
	Id: string,
	DisplayName: string,
	ResourceId: string?, -- the ResourceConfig id it yields (nil until the resource exists)
	MinMasterRank: number?,
	Flag: string?,
	MinBuilds: number?,
	Enabled: boolean,
}

SecretResourceConfig.Secrets = {
	StarMetal = { Id = "StarMetal", DisplayName = "Star Metal", ResourceId = "StarMetal", MinMasterRank = 1, Flag = nil, MinBuilds = nil, Enabled = true },
	AncientTimber = { Id = "AncientTimber", DisplayName = "Ancient Timber", ResourceId = "AncientTimber", MinMasterRank = 3, Flag = nil, MinBuilds = nil, Enabled = true },
	-- (more secrets later: add an entry here and a ResourceConfig resource with Secret = "<id>")
} :: { [string]: Secret }

-- Does this PlayerData-shaped table meet the unlock requirements of a secret?
function SecretResourceConfig.CanAccess(secretId: string?, data: any): boolean
	if secretId == nil or secretId == "" then
		return true -- not a secret node
	end
	local s = SecretResourceConfig.Secrets[secretId]
	if not s or not s.Enabled or not data then
		return false
	end
	if s.MinMasterRank and ((data.MasterBuilder and data.MasterBuilder.Rank) or 0) < s.MinMasterRank then
		return false
	end
	if s.Flag and not (data.Unlocks and data.Unlocks[s.Flag]) then
		return false
	end
	if s.MinBuilds and ((data.Stats and data.Stats.BuildsCompleted) or 0) < s.MinBuilds then
		return false
	end
	return true
end

return SecretResourceConfig
