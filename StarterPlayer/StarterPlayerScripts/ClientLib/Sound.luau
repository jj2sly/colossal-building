--!strict
-- Client sound hooks (SoundConfig). Each hook has its own cooldown so dozens of
-- simultaneous events produce one sound, not a wall of noise.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local SoundConfig = require(ReplicatedStorage.Shared.Config.SoundConfig)

local Sound = {}
local instances: { [string]: Sound } = {}
local last: { [string]: number } = {}

local function get(name: string): Sound?
	local s = instances[name]
	if s then
		return s
	end
	local def = SoundConfig.Sounds[name]
	if not def then
		return nil
	end
	local snd = Instance.new("Sound")
	snd.Name = "MB_" .. name
	snd.SoundId = def.SoundId
	snd.Volume = def.Volume
	snd.PlaybackSpeed = def.Pitch
	snd.Parent = SoundService
	instances[name] = snd
	return snd
end

function Sound.Play(name: string, pitchJitter: number?, vol: number?, pitchMul: number?)
	local def = SoundConfig.Sounds[name]
	if not def then
		return
	end
	local t = os.clock()
	if last[name] and t - last[name] < def.Cooldown then
		return
	end
	last[name] = t
	local s = get(name)
	if s then
		s.PlaybackSpeed = def.Pitch * (pitchMul or 1) * (1 + (if pitchJitter then (math.random() * 2 - 1) * pitchJitter else 0))
		s.Volume = def.Volume * (vol or 1)
		SoundService:PlayLocalSound(s)
		if def.Max then
			-- long recordings (machine spin-ups, struck metal) are cut after Max seconds so they read as one punchy hit
			task.delay(def.Max, function()
				if s.IsPlaying and last[name] == t then
					s:Stop()
				end
			end)
		end
	end
end

-- A one-shot 3D sound at a world position (landmark clanks, spectacle hits): heard as you approach, silent across the map.
-- Uses a tiny pool of anchors so nothing is created per call.
local anchors: { Part } = {}
local nextAnchor = 0
function Sound.PlayAt(name: string, pos: Vector3, maxDistance: number?, pitchJitter: number?)
	local def = SoundConfig.Sounds[name]
	if not def then
		return
	end
	nextAnchor = nextAnchor % 6 + 1
	local a = anchors[nextAnchor]
	if not a or not a.Parent then
		a = Instance.new("Part")
		a.Name = "MB_SoundAnchor"
		a.Anchored, a.CanCollide, a.CanQuery, a.CanTouch = true, false, false, false
		a.Transparency = 1
		a.Size = Vector3.one
		a.Parent = workspace
		anchors[nextAnchor] = a
	end
	a.Position = pos
	local s = a:FindFirstChild(name) :: Sound?
	if not s then
		local snd = Instance.new("Sound")
		snd.Name = name
		snd.SoundId = def.SoundId
		snd.RollOffMode = Enum.RollOffMode.InverseTapered
		snd.RollOffMinDistance = 20
		snd.Parent = a
		s = snd
	end
	local snd = s :: Sound
	snd.Volume = def.Volume
	snd.RollOffMaxDistance = maxDistance or 160
	snd.PlaybackSpeed = def.Pitch * (1 + (if pitchJitter then (math.random() * 2 - 1) * pitchJitter else 0))
	snd.TimePosition = 0
	snd:Play()
end

-- PASS 16A: layered cues. `layers` = { {sound, volMul, pitchMul, delay} }; `vol` scales the whole cue.
function Sound.Layers(layers: { { any } }, vol: number?)
	for _, l in layers do
		local d = l[4] or 0
		if d <= 0 then
			Sound.Play(l[1], 0.03, (l[2] or 1) * (vol or 1), l[3])
		else
			task.delay(d, Sound.Play, l[1], 0.03, (l[2] or 1) * (vol or 1), l[3])
		end
	end
end

function Sound.Cue(name: string, vol: number?)
	local c = SoundConfig.Cues[name]
	if c then
		Sound.Layers(c, vol)
	end
end

-- Build completion: the same layers added per rarity level (Forgotten has its own low, ancient set).
function Sound.Complete(rarity: string)
	local level = SoundConfig.RarityLevel[rarity] or 1
	if level >= 7 then
		Sound.Layers(SoundConfig.ForgottenComplete)
		return
	end
	for i = 1, math.min(level, #SoundConfig.CompleteLayers) do
		Sound.Layers(SoundConfig.CompleteLayers[i], 0.8 + 0.04 * i)
	end
end

-- Reveal impact: pitch drops and weight rises with rarity.
function Sound.RevealImpact(rarity: string)
	local level = SoundConfig.RarityLevel[rarity] or 1
	Sound.Play("RevealFinal", nil, 0.6 + 0.08 * level, 1.05 - 0.03 * level)
	if level >= 4 then
		Sound.Play("Boom", nil, 0.3 + 0.1 * (level - 3), 1.1 - 0.05 * level)
	end
end

-- Activation milestone: step 0 = the build waking (activation), then 1..total; the last step is the strongest.
function Sound.Milestone(step: number, total: number)
	if step <= 0 then
		Sound.Cue("Wake", 0.9)
		return
	end
	local k = math.clamp(step / math.max(total, 1), 0, 1)
	Sound.Play("PowerUp", nil, 0.7 + 0.3 * k, 0.9 + 0.25 * k)
	task.delay(0.12, Sound.Play, "Chime", 0.03, 0.6 + 0.3 * k, 0.9 + 0.3 * k)
	if step >= total then
		task.delay(0.2, Sound.Play, "Boom", 0.03, 0.7, 0.8)
		task.delay(0.35, Sound.Play, "Rumble", 0.03, 0.8, 1)
	end
end

return Sound
