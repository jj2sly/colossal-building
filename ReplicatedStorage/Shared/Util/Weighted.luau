--!strict
-- Weighted random selection.
local Weighted = {}

function Weighted.Pick<T>(entries: { T }, weightOf: (T) -> number, rng: Random?): T?
	local total = 0
	for _, e in entries do
		total += math.max(0, weightOf(e))
	end
	if total <= 0 then
		return entries[1]
	end
	local r = (rng or Random.new()):NextNumber() * total
	for _, e in entries do
		r -= math.max(0, weightOf(e))
		if r <= 0 then
			return e
		end
	end
	return entries[#entries]
end

function Weighted.Shuffle<T>(list: { T }, rng: Random?): { T }
	local out = table.clone(list)
	local rand = rng or Random.new()
	for i = #out, 2, -1 do
		local j = rand:NextInteger(1, i)
		out[i], out[j] = out[j], out[i]
	end
	return out
end

return Weighted
