--!strict
-- PC 와 모바일 입력을 하나의 "비행 명령"(FlightModel.Command)으로 바꾼다.
--   PC  : 마우스 또는 W/A/S/D(방향키)로 조준, Shift/Ctrl 속도, F 타기/내리기
--   모바일: 왼쪽 스틱으로 조준, 오른쪽 슬라이더로 속도 (자동 전진)
--   PC 화면 스틱 모드: 모바일과 같은 화면 스틱을 마우스로 끈다 (마우스가 잠기지 않아 테스트가 편함)
--     Studio 에서는 이 모드로 시작하고, M 키로 마우스 조준과 바꾼다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Flight = Config.Flight
local TouchControls = require(script.Parent.Parent.ui.TouchFlightControls)

local InputController = {}
InputController.ToggleRequested = Signal.new() -- F 키 또는 화면의 내리기 버튼
InputController.ModeChanged = Signal.new() -- 마우스 조준 ↔ 화면 스틱

local flying = false
local mobile = false
local screenStick = false -- PC 에서 화면 스틱을 쓰는 중인지 (모바일은 항상 화면 스틱)

local SINK_ACTION = "BlockAirFlightSink"
local MOUSE_LOCK_STEP = "BlockAirMouseLock"

function InputController:IsMobile(): boolean
	return mobile
end

function InputController:UsesScreenStick(): boolean
	return mobile or screenStick
end

-- 화면 슬라이더를 지금 속도 레버 값에 맞춘다 (조작 방식을 바꿀 때 속도가 튀지 않게)
function InputController:SyncThrottle(throttle: number)
	TouchControls.SetThrottle(throttle)
end

-- 비행 화면 아래에 보여 줄 조작 안내 (모바일은 없음)
function InputController:GetHint(): string?
	if mobile then
		return nil
	elseif screenStick then
		return "화면 스틱·WASD: 방향   Shift/Ctrl: 속도   M: 마우스 조준   F: 내리기"
	end
	return "마우스·WASD: 방향   Shift/Ctrl: 속도   M: 화면 스틱   F: 내리기"
end

local function lockMouse(on: boolean)
	RunService:UnbindFromRenderStep(MOUSE_LOCK_STEP)
	if on then
		-- 마우스는 매 프레임 다시 잠가야 한다 (기본 카메라 스크립트·로블록스 메뉴가 풀 수 있음)
		RunService:BindToRenderStep(MOUSE_LOCK_STEP, Enum.RenderPriority.Camera.Value + 2, function()
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
			UserInputService.MouseIconEnabled = false
		end)
	else
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
	end
end

-- 비행 중 조작 방식에 맞게 화면 스틱·마우스 잠금을 맞춘다
local function applyMode(throttle: number?)
	if InputController:UsesScreenStick() then
		lockMouse(false)
		TouchControls.Show(throttle or TouchControls.GetThrottle())
	else
		TouchControls.Hide()
		lockMouse(true)
	end
end

-- 비행 시작/끝. throttle 은 모바일 슬라이더를 맞출 처음 값.
function InputController:SetFlying(on: boolean, throttle: number?)
	if flying == on then
		return
	end
	flying = on
	if on then
		-- 모바일 기본 스틱·점프 버튼을 숨기고, 스페이스 점프로 내리지 않게 막는다
		-- (조종석에서는 W/A/S/D 걷기가 원래 동작하지 않는다)
		GuiService.TouchControlsEnabled = false
		ContextActionService:BindActionAtPriority(SINK_ACTION, function()
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		applyMode(throttle or Flight.START_THROTTLE)
	else
		GuiService.TouchControlsEnabled = true
		ContextActionService:UnbindAction(SINK_ACTION)
		TouchControls.Hide()
		lockMouse(false)
	end
end

-- 매 프레임 부른다. 이번 프레임의 비행 명령을 돌려준다.
function InputController:GetCommand(dt: number): any
	if mobile then
		local stick = TouchControls.GetStick() -- x: 오른쪽 +, y: 위 +
		local rate = math.rad(Flight.STICK_TURN_RATE) * dt
		return {
			yaw = -stick.X * rate,
			pitch = stick.Y * rate,
			throttleAxis = 0,
			throttleSet = TouchControls.GetThrottle(),
		}
	end

	-- PC: 마우스와 키보드를 같이 쓸 수 있다
	--   W/S 또는 ↑/↓ : 위/아래,  A/D 또는 ←/→ : 왼쪽/오른쪽
	--   Shift : 빨라지기,  Ctrl : 느려지기
	local function key(...: Enum.KeyCode): boolean
		for _, k in { ... } do
			if UserInputService:IsKeyDown(k) then
				return true
			end
		end
		return false
	end
	local K = Enum.KeyCode
	local right = (if key(K.D, K.Right) then 1 else 0) - (if key(K.A, K.Left) then 1 else 0)
	local up = (if key(K.W, K.Up) then 1 else 0) - (if key(K.S, K.Down) then 1 else 0)
	local faster = (if key(K.LeftShift, K.RightShift) then 1 else 0) - (if key(K.LeftControl, K.RightControl) then 1 else 0)
	local rate = math.rad(Flight.KEY_TURN_RATE) * dt

	if screenStick then
		-- 화면 스틱 + 키보드. 속도는 슬라이더 값이고 Shift/Ctrl 이 슬라이더를 움직인다.
		local stick = TouchControls.GetStick()
		local stickRate = math.rad(Flight.STICK_TURN_RATE) * dt
		if faster ~= 0 then
			TouchControls.SetThrottle(TouchControls.GetThrottle() + faster * Flight.THROTTLE_RATE * dt)
		end
		return {
			yaw = -stick.X * stickRate - right * rate,
			pitch = stick.Y * stickRate + up * rate,
			throttleAxis = 0,
			throttleSet = TouchControls.GetThrottle(),
		}
	end

	local delta = UserInputService:GetMouseDelta()
	return {
		yaw = -delta.X * Flight.MOUSE_SENSITIVITY - right * rate,
		pitch = -delta.Y * Flight.MOUSE_SENSITIVITY + up * rate,
		throttleAxis = faster,
		throttleSet = nil,
	}
end

function InputController:Init(_controllers)
	mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
	screenStick = RunService:IsStudio() -- Studio 에서는 화면 스틱으로 시작
end

function InputController:Start()
	TouchControls.Mount(Players.LocalPlayer:WaitForChild("PlayerGui"))
	TouchControls.ExitPressed:Connect(function()
		InputController.ToggleRequested:Fire()
	end)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.KeyCode == Enum.KeyCode.F then
			InputController.ToggleRequested:Fire()
		elseif input.KeyCode == Enum.KeyCode.M and not mobile then
			screenStick = not screenStick
			if flying then
				applyMode(nil)
			end
			InputController.ModeChanged:Fire()
		end
	end)
end

return InputController
