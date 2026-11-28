--!strict
-- PC 와 모바일 입력을 하나의 "비행 명령"(FlightModel.Command)으로 바꾼다.
--   PC  : 마우스로 조준 (마우스 잠금), W/S 속도, F 타기/내리기
--   모바일: 왼쪽 스틱으로 조준, 오른쪽 슬라이더로 속도 (자동 전진)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local ContextActionService = game:GetService("ContextActionService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Flight = Config.Flight
local TouchControls = require(script.Parent.Parent.ui.TouchFlightControls)

local InputController = {}
InputController.ToggleRequested = Signal.new() -- F 키 또는 화면의 내리기 버튼

local flying = false
local mobile = false

local SINK_ACTION = "BlockAirFlightSink"
local MOUSE_LOCK_STEP = "BlockAirMouseLock"

local function playerControls(): any
	local ok, controls = pcall(function()
		local module = require(Players.LocalPlayer:WaitForChild("PlayerScripts"):WaitForChild("PlayerModule") :: ModuleScript) :: any
		return module:GetControls()
	end)
	return if ok then controls else nil
end

function InputController:IsMobile(): boolean
	return mobile
end

-- 비행 시작/끝. throttle 은 모바일 슬라이더를 맞출 처음 값.
function InputController:SetFlying(on: boolean, throttle: number?)
	if flying == on then
		return
	end
	flying = on
	local controls = playerControls()
	if on then
		-- 걷기·점프 조작을 끄고(모바일 기본 스틱·점프 버튼도 숨겨짐), 스페이스 점프로 내리지 않게 막는다
		if controls then
			controls:Disable()
		end
		ContextActionService:BindActionAtPriority(SINK_ACTION, function()
			return Enum.ContextActionResult.Sink
		end, false, Enum.ContextActionPriority.High.Value + 10, Enum.KeyCode.Space, Enum.KeyCode.ButtonA)
		if mobile then
			TouchControls.Show(throttle or Flight.START_THROTTLE)
		else
			-- 마우스는 매 프레임 다시 잠가야 한다 (기본 카메라 스크립트·로블록스 메뉴가 풀 수 있음)
			RunService:BindToRenderStep(MOUSE_LOCK_STEP, Enum.RenderPriority.Camera.Value + 2, function()
				UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
				UserInputService.MouseIconEnabled = false
			end)
		end
	else
		if controls then
			controls:Enable()
		end
		ContextActionService:UnbindAction(SINK_ACTION)
		TouchControls.Hide()
		RunService:UnbindFromRenderStep(MOUSE_LOCK_STEP)
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		UserInputService.MouseIconEnabled = true
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

	-- PC
	local delta = UserInputService:GetMouseDelta()
	local axis = 0
	if UserInputService:IsKeyDown(Enum.KeyCode.W) or UserInputService:IsKeyDown(Enum.KeyCode.Up) then
		axis += 1
	end
	if UserInputService:IsKeyDown(Enum.KeyCode.S) or UserInputService:IsKeyDown(Enum.KeyCode.Down) then
		axis -= 1
	end
	return {
		yaw = -delta.X * Flight.MOUSE_SENSITIVITY,
		pitch = -delta.Y * Flight.MOUSE_SENSITIVITY,
		throttleAxis = axis,
		throttleSet = nil,
	}
end

function InputController:Init(_controllers)
	mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
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
		end
	end)
end

return InputController
