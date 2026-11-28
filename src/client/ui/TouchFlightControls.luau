--!strict
-- 모바일 비행 조작 화면: 왼쪽 아래 스틱, 오른쪽 아래 속도 슬라이더, 위쪽 내리기 버튼.
-- PC 에서는 마우스로 끌어서도 쓸 수 있다 (Studio 테스트용 화면 스틱 모드).
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Widgets = require(script.Parent.components.Widgets)

local Flight = Config.Flight

local TouchFlightControls = {}
TouchFlightControls.ExitPressed = Signal.new()

local STICK_SIZE = 150
local KNOB_SIZE = 64
local SLIDER_W, SLIDER_H = 64, 170

local gui: ScreenGui
local stickBase: Frame
local knob: Frame
local slider: Frame
local fill: Frame
local sliderLabel: TextLabel

-- 지금 스틱·슬라이더를 잡고 있는 손가락(InputObject) 또는 "mouse"
local stickInput: any = nil
local sliderInput: any = nil
local stick = Vector2.zero
local throttle = 0

local function setThrottle(v: number)
	throttle = math.clamp(v, 0, 1)
	fill.Size = UDim2.fromScale(1, throttle)
	sliderLabel.Text = if throttle < Flight.HOVER_ZONE then "정지" else `{math.floor(throttle * 100 + 0.5)}%`
end

local function updateStick(pos: Vector3)
	local center = stickBase.AbsolutePosition + stickBase.AbsoluteSize / 2
	local offset = Vector2.new(pos.X, pos.Y) - center
	local radius = STICK_SIZE / 2
	if offset.Magnitude > radius then
		offset = offset.Unit * radius
	end
	knob.Position = UDim2.new(0.5, offset.X, 0.5, offset.Y)
	local v = offset / radius
	if v.Magnitude < Flight.STICK_DEAD_ZONE then
		v = Vector2.zero
	end
	stick = Vector2.new(v.X, -v.Y) -- 화면은 아래가 + 라서 뒤집는다
end

local function updateSlider(pos: Vector3)
	local top = slider.AbsolutePosition.Y
	local h = slider.AbsoluteSize.Y
	setThrottle(1 - (pos.Y - top) / h)
end

function TouchFlightControls.Mount(playerGui: Instance)
	gui = Instance.new("ScreenGui")
	gui.Name = "TouchFlightControls"
	gui.ResetOnSpawn = false
	gui.Enabled = false
	gui.DisplayOrder = 5

	stickBase = Instance.new("Frame")
	stickBase.Name = "Stick"
	stickBase.Size = UDim2.fromOffset(STICK_SIZE, STICK_SIZE)
	stickBase.AnchorPoint = Vector2.new(0, 1)
	stickBase.Position = UDim2.new(0, 40, 1, -30)
	stickBase.BackgroundColor3 = Color3.new(0, 0, 0)
	stickBase.BackgroundTransparency = 0.6
	stickBase.Active = true
	stickBase.Parent = gui
	Widgets.corner(stickBase, STICK_SIZE // 2)

	knob = Instance.new("Frame")
	knob.Size = UDim2.fromOffset(KNOB_SIZE, KNOB_SIZE)
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0.5, 0.5)
	knob.BackgroundColor3 = Color3.new(1, 1, 1)
	knob.BackgroundTransparency = 0.2
	knob.Parent = stickBase
	Widgets.corner(knob, KNOB_SIZE // 2)

	slider = Instance.new("Frame")
	slider.Name = "Throttle"
	slider.Size = UDim2.fromOffset(SLIDER_W, SLIDER_H)
	slider.AnchorPoint = Vector2.new(1, 1)
	slider.Position = UDim2.new(1, -40, 1, -30)
	slider.BackgroundColor3 = Color3.new(0, 0, 0)
	slider.BackgroundTransparency = 0.6
	slider.ClipsDescendants = true
	slider.Active = true
	slider.Parent = gui
	Widgets.corner(slider, 14)

	fill = Instance.new("Frame")
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = Widgets.ACCENT
	fill.BackgroundTransparency = 0.15
	fill.BorderSizePixel = 0
	fill.Parent = slider
	Widgets.corner(fill, 14)

	sliderLabel = Widgets.label(slider, "", UDim2.new(1, 0, 0, 24), UDim2.new(0, 0, 0, 6), 16)
	sliderLabel.TextXAlignment = Enum.TextXAlignment.Center
	sliderLabel.ZIndex = 2
	local caption = Widgets.label(gui, "속도", UDim2.fromOffset(SLIDER_W, 20), UDim2.new(1, -40 - SLIDER_W, 1, -30 - SLIDER_H - 24), 15)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	caption.TextStrokeTransparency = 0.5

	local exit = Instance.new("TextButton")
	exit.Name = "Exit"
	exit.Size = UDim2.fromOffset(110, 40)
	exit.AnchorPoint = Vector2.new(0.5, 0)
	exit.Position = UDim2.new(0.5, 0, 0, 190) -- 위쪽 레벨·화물·HP 표시 아래
	exit.BackgroundColor3 = Color3.fromRGB(200, 70, 70)
	exit.Font = Widgets.FONT
	exit.TextSize = 18
	exit.TextColor3 = Color3.new(1, 1, 1)
	exit.Text = "내리기"
	exit.Parent = gui
	Widgets.corner(exit, 10)
	exit.Activated:Connect(function()
		TouchFlightControls.ExitPressed:Fire()
	end)

	local function isPress(input: InputObject): boolean
		return input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1
	end
	local function owner(input: InputObject): any
		return if input.UserInputType == Enum.UserInputType.Touch then input else "mouse"
	end
	stickBase.InputBegan:Connect(function(input)
		if isPress(input) and not stickInput then
			stickInput = owner(input)
			updateStick(input.Position)
		end
	end)
	slider.InputBegan:Connect(function(input)
		if isPress(input) and not sliderInput then
			sliderInput = owner(input)
			updateSlider(input.Position)
		end
	end)
	local function moved(input: InputObject)
		local who = if input.UserInputType == Enum.UserInputType.MouseMovement then "mouse" else input
		if who == stickInput then
			updateStick(input.Position)
		elseif who == sliderInput then
			updateSlider(input.Position)
		end
	end
	local function ended(input: InputObject)
		local who = if input.UserInputType == Enum.UserInputType.MouseButton1 then "mouse" else input
		if who == stickInput then
			stickInput = nil
			stick = Vector2.zero
			knob.Position = UDim2.fromScale(0.5, 0.5)
		elseif who == sliderInput then
			sliderInput = nil
		end
	end
	UserInputService.TouchMoved:Connect(moved)
	UserInputService.TouchEnded:Connect(ended)
	UserInputService.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement then
			moved(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			ended(input)
		end
	end)

	setThrottle(Flight.START_THROTTLE)
	gui.Parent = playerGui
end

function TouchFlightControls.Show(startThrottle: number)
	setThrottle(startThrottle)
	stick = Vector2.zero
	stickInput = nil
	sliderInput = nil
	knob.Position = UDim2.fromScale(0.5, 0.5)
	gui.Enabled = true
end

function TouchFlightControls.Hide()
	gui.Enabled = false
	stick = Vector2.zero
	stickInput = nil
	sliderInput = nil
end

function TouchFlightControls.GetStick(): Vector2
	return stick
end

function TouchFlightControls.SetThrottle(v: number)
	setThrottle(v)
end

function TouchFlightControls.GetThrottle(): number
	return throttle
end

return TouchFlightControls
