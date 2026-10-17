--!strict
-- Toast notifications (server Notify remote + local Notify.Show). Max 4 visible,
-- duplicates within a short window are merged so spam can't flood the screen.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Net = require(ReplicatedStorage.Shared.Net)
local Lib = script.Parent.Parent.ClientLib
local UI = require(Lib.UI)
local Sound = require(Lib.Sound)

local NotifyController = {}

local container: Frame
local recent: { [string]: number } = {}
-- toasts are plates like everything else: dark steel with a 4 px kind edge (no random blue/green/red slabs)
local K = UI.Tokens
local COLORS = {
	Info = K.InkDim,
	Success = K.Good,
	Warn = K.Signal,
	Error = K.Bad,
	Debug = K.Dev,
}

function NotifyController.Show(kind: string, text: string, duration: number?)
	if not container then
		return
	end
	local t = os.clock()
	if recent[text] and t - recent[text] < 1.5 then
		return
	end
	recent[text] = t
	local items = {}
	for _, c in container:GetChildren() do
		if c:IsA("Frame") then
			table.insert(items, c)
		end
	end
	if #items >= 4 then
		table.sort(items, function(a, b)
			return a.LayoutOrder < b.LayoutOrder
		end)
		items[1]:Destroy()
	end
	local toast = UI.card({
		BackgroundColor3 = K.Plate,
		BackgroundTransparency = 0.04,
		Size = UDim2.fromOffset(340, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = math.floor(t * 100),
		Parent = container,
	})
	UI.new("UIPadding", { PaddingLeft = UDim.new(0, 16), PaddingRight = UDim.new(0, 12), PaddingTop = UDim.new(0, 8), PaddingBottom = UDim.new(0, 9), Parent = toast })
	local edge = UI.new("Frame", { Name = "Edge", BackgroundColor3 = COLORS[kind] or K.InkDim, BackgroundTransparency = 0, Size = UDim2.new(0, 4, 1, 0), Parent = toast })
	local label = UI.new("TextLabel", {
		Text = text,
		Font = UI.Type.Bold,
		TextSize = UI.Type.Body + 1,
		TextColor3 = K.Ink,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = toast,
	})
	if kind == "Error" then
		Sound.Play("Error")
	end
	task.delay(duration or (if kind == "Debug" then 8 else 3.2), function()
		if toast.Parent then
			UI.tween(toast, 0.3, { BackgroundTransparency = 1 })
			UI.tween(edge, 0.3, { BackgroundTransparency = 1 })
			UI.tween(label, 0.3, { TextTransparency = 1 })
			task.wait(0.3)
			toast:Destroy()
		end
	end)
end

function NotifyController.Start()
	local g = UI.root("Toasts", 8)
	container = UI.new("Frame", {
		Name = "Toasts",
		BackgroundTransparency = 1,
		-- bottom-right column: clear of the centered reveal / celebration / carry panels
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -12, 1, -90),
		Size = UDim2.fromOffset(340, 300),
		Parent = g,
	})
	local layout = UI.list(container, 6, false, Enum.HorizontalAlignment.Right)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	Net.Event("Notify").OnClientEvent:Connect(function(kind, text)
		NotifyController.Show(kind, text)
	end)
end

return NotifyController
