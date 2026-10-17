--!strict
-- (Pass 21Q) BACKGROUND MUSIC: a shuffled, looping playlist at low volume. Add tracks by pasting asset ids into TRACKS.
-- Empty list = silent (nothing is created). M mutes / unmutes. MusicController.Duck(seconds) dips the music for a big moment.
local ContextActionService = game:GetService("ContextActionService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local MusicController = {}

local TRACKS: { number } = {}
local VOLUME = 0.22

local sound: Sound?
local muted = false
local ducked = 0

local function targetVolume(): number
	if muted then
		return 0
	end
	return if ducked > 0 then VOLUME * 0.3 else VOLUME
end

local function fade()
	if sound then
		TweenService:Create(sound, TweenInfo.new(0.6), { Volume = targetVolume() }):Play()
	end
end

function MusicController.Duck(seconds: number)
	ducked += 1
	fade()
	task.delay(seconds, function()
		ducked -= 1
		fade()
	end)
end

function MusicController.Start()
	if #TRACKS == 0 then
		return
	end
	local group = Instance.new("SoundGroup")
	group.Name = "MB_Music"
	group.Parent = SoundService
	local order = table.clone(TRACKS)
	local i = #order
	task.spawn(function()
		while true do
			i += 1
			if i > #order then
				i = 1
				for k = #order, 2, -1 do
					local j = math.random(k)
					order[k], order[j] = order[j], order[k]
				end
			end
			local s = Instance.new("Sound")
			s.Name = "Track"
			s.SoundId = "rbxassetid://" .. order[i]
			s.Volume = 0
			s.SoundGroup = group
			s.Parent = group
			sound = s
			s:Play()
			fade()
			local waited = 0
			while not s.IsLoaded and waited < 8 do -- a track that cannot load is skipped, never stalls the playlist
				waited += task.wait(0.25)
			end
			if s.IsLoaded then
				s.Ended:Wait()
			end
			s:Destroy()
		end
	end)
	ContextActionService:BindAction("MB_MuteMusic", function(_, state)
		if state == Enum.UserInputState.Begin then
			muted = not muted
			fade()
		end
		return Enum.ContextActionResult.Pass
	end, false, Enum.KeyCode.M)
end

return MusicController
