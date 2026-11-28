--!strict
-- 3인칭 추적 카메라. 비행 중에는 조준 방향 뒤에서 비행기를 따라가고, 내리면 로블록스 기본 카메라로 돌아간다.
-- (4단계 에디터의 "부위로 날아가는 카메라"도 여기에 붙인다)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)

local Flight = Config.Flight
local BIND_NAME = "BlockAirFlightCamera"

local CameraController = {}

-- 매 프레임 (비행기 위치 CFrame, 조준 방향, 속도 비율 0~1) 을 돌려주는 함수
type Target = () -> (CFrame?, Vector3, number)

local following = false

-- scale: 큰 비행기(중형~초대형)는 카메라를 그만큼 멀리 (기본 1)
function CameraController:FollowPlane(getTarget: Target, scale: number?)
	local k = math.max(scale or 1, 1)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	following = true
	RunService:UnbindFromRenderStep(BIND_NAME)
	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function()
		local cf, aim, speedRatio = getTarget()
		if not cf then
			return
		end
		local focus = cf.Position
		local pos = focus - aim * (Flight.CAMERA_DISTANCE * k) + Vector3.yAxis * (Flight.CAMERA_HEIGHT * k)
		camera.CFrame = CFrame.lookAt(pos, focus + aim * Flight.CAMERA_LOOK_AHEAD)
		camera.FieldOfView = Flight.CAMERA_FOV + Flight.CAMERA_FOV_BOOST * speedRatio
	end)
end

function CameraController:Release()
	if not following then
		return
	end
	following = false
	RunService:UnbindFromRenderStep(BIND_NAME)
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = Flight.CAMERA_FOV
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
	end
end

function CameraController:Init(_controllers) end

function CameraController:Start() end

return CameraController
