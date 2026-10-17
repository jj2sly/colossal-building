--!strict
-- DAILY REWARDS and the WELCOME BACK bonus. Deliberately small and forgiving: a 7-day cycle that advances by CLAIMS (not by
-- consecutive days), so missing a day costs nothing and the cycle simply restarts after day 7. One claim per UTC day.
-- Rewards never skip progression: the biggest Coin day is about one completed Common build's payout, buffs are short and
-- modest, and the occasional cosmetic is a common-tier item that is also reachable through normal play.
--
-- A reward entry (all fields optional, combined):
--   Coins     flat Coins
--   Buff      { Key = "Luck" | "Gather", Amount = n, Minutes = m }: Luck adds personal Luck points, Gather adds a fraction of gather speed
--   Cosmetic  { Category, Item }: granted once; if already owned it converts to DuplicateCoins instead
--   Text      one line for the UI
local DailyConfig = {}

DailyConfig.DaySeconds = 86400

export type Reward = {
	Coins: number?,
	Buff: { Key: string, Amount: number, Minutes: number }?,
	Cosmetic: { Category: string, Item: string }?,
	Text: string,
}

DailyConfig.Cycle = {
	{ Coins = 250, Text = "250 Coins" },
	{ Buff = { Key = "Luck", Amount = 4, Minutes = 30 }, Text = "+4 Luck for 30 min" },
	{ Coins = 400, Text = "400 Coins" },
	{ Buff = { Key = "Gather", Amount = 0.10, Minutes = 30 }, Text = "+10% gather speed for 30 min" },
	{ Coins = 600, Text = "600 Coins" },
	{ Buff = { Key = "Luck", Amount = 6, Minutes = 45 }, Coins = 200, Text = "+6 Luck for 45 min and 200 Coins" },
	{ Coins = 800, Cosmetic = { Category = "Trail", Item = "SawdustTrail" }, Text = "800 Coins and a Sawdust Trail" },
} :: { Reward }

DailyConfig.DuplicateCoins = 300 -- paid instead of a cosmetic the player already owns

-- WELCOME BACK: after this many days away the next login gets a small bonus (once per return).
DailyConfig.Return = {
	MinDaysAway = 3,
	Coins = 400,
	Buff = { Key = "Luck", Amount = 3, Minutes = 20 },
	Text = "WELCOME BACK",
}

-- The current UTC day number.
function DailyConfig.DayNumber(t: number?): number
	return math.floor((t or os.time()) / DailyConfig.DaySeconds)
end

-- Which cycle slot (1..7) the NEXT claim gives, from the number of claims so far.
function DailyConfig.Slot(claims: number): number
	return (claims % #DailyConfig.Cycle) + 1
end

return DailyConfig
