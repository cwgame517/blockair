--!strict
-- 내 비행기 조종. 서버가 비행기를 만들고 나를 조종석에 앉히면 시작하고, 조종석에서 내리면 끝난다.
-- 비행기의 네트워크 소유권이 내게 있어서, 여기서 바꾼 속도·자세가 즉시 반영되고 다른 사람에게도 전달된다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local FlightModel = require(ReplicatedStorage.Shared.FlightModel)
local FlightHUD = require(script.Parent.Parent.ui.FlightHUD)

local Flight = Config.Flight
local player = Players.LocalPlayer

local FlightController = {}
FlightController.FlyingChanged = Signal.new() -- (flying: boolean)

local InputController: any
local CameraController: any

type Session = {
	plane: Model,
	root: BasePart,
	move: LinearVelocity,
	steer: AlignOrientation,
	stats: FlightModel.Stats,
	state: FlightModel.State,
	params: RaycastParams,
	conn: RBXScriptConnection,
}

local session: Session? = nil
local requestPending = false

function FlightController:IsFlying(): boolean
	return session ~= nil
end

-- 지금 타고 있는 내 비행기 (없으면 nil)
function FlightController:GetPlane(): Model?
	local s = session
	return if s then s.plane else nil
end

-- 타기/내리기 버튼·F 키
function FlightController:RequestToggle()
	if requestPending then
		return
	end
	requestPending = true
	Net.event("PlaneRequest"):FireServer(session == nil)
	task.delay(Flight.REQUEST_COOLDOWN, function()
		requestPending = false
	end)
end

-- 벽·땅·하늘 경계에 닿을 속도 성분을 지워서 미끄러지게 한다
local function avoid(s: Session, velocity: Vector3, dt: number): Vector3
	local pos = s.root.Position
	local speed = velocity.Magnitude
	if speed > 0.1 then
		local dist = speed * dt + Flight.PROBE_MARGIN
		local hit = workspace:Spherecast(pos, Flight.PROBE_RADIUS, velocity.Unit * dist, s.params)
		if hit then
			local n = hit.Normal
			local into = velocity:Dot(n)
			if into < 0 then
				velocity -= n * into
			end
		end
	end
	-- 하늘 경계 (섬 서버는 자기 경계를 ReplicatedStorage 속성으로 알려 줌)
	local radius = ReplicatedStorage:GetAttribute("WorldRadius") :: number? or Flight.WORLD_RADIUS
	local ceiling = ReplicatedStorage:GetAttribute("Ceiling") :: number? or Flight.CEILING
	local floor = ReplicatedStorage:GetAttribute("Floor") :: number? or Flight.FLOOR
	local flat = Vector3.new(pos.X, 0, pos.Z)
	if flat.Magnitude > radius then
		local out = flat.Unit
		local into = velocity:Dot(out)
		if into > 0 then
			velocity -= out * into
		end
	end
	if pos.Y > ceiling and velocity.Y > 0 then
		velocity = Vector3.new(velocity.X, 0, velocity.Z)
	elseif pos.Y < floor and velocity.Y < 0 then
		velocity = Vector3.new(velocity.X, 0, velocity.Z)
	end
	return velocity
end

local function stop()
	local s = session
	if not s then
		return
	end
	session = nil
	s.conn:Disconnect()
	InputController:SetFlying(false)
	CameraController:Release()
	FlightHUD.Hide()
	FlightController.FlyingChanged:Fire(false)
end

local function start(plane: Model)
	if session then
		stop()
	end
	local root = plane.PrimaryPart or plane:WaitForChild("Root", 5) :: BasePart?
	if not root then
		return
	end
	local move = root:WaitForChild("Move", 5) :: LinearVelocity?
	local steer = root:WaitForChild("Steer", 5) :: AlignOrientation?
	if not move or not steer then
		return
	end

	local stats: FlightModel.Stats = {
		maxSpeed = plane:GetAttribute("MaxSpeed") :: number? or Flight.BASE_MAX_SPEED,
		minSpeed = plane:GetAttribute("MinSpeed") :: number? or Flight.MIN_SPEED,
		turnRate = plane:GetAttribute("TurnRate") :: number? or Flight.BASE_TURN_RATE,
	}
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { plane }
	local planesFolder = workspace:FindFirstChild("Planes")
	if planesFolder then
		table.insert(exclude, planesFolder)
	end
	if player.Character then
		table.insert(exclude, player.Character)
	end
	params.FilterDescendantsInstances = exclude

	local state = FlightModel.newState(root.CFrame, stats)

	local s: Session
	local conn = RunService.PreSimulation:Connect(function(dt)
		if not plane.Parent or not root.Parent then
			stop()
			return
		end
		-- 테스트 명령(/speed)으로 속도가 바뀔 수 있어 매번 읽는다
		stats.maxSpeed = plane:GetAttribute("MaxSpeed") :: number? or stats.maxSpeed
		stats.minSpeed = plane:GetAttribute("MinSpeed") :: number? or stats.minSpeed
		local cmd = InputController:GetCommand(dt)
		local orientation, velocity = FlightModel.step(state, cmd, stats, dt)
		velocity = avoid(s, velocity, dt)
		move.VectorVelocity = velocity
		steer.CFrame = orientation
	end)
	s = {
		plane = plane,
		root = root,
		move = move,
		steer = steer,
		stats = stats,
		state = state,
		params = params,
		conn = conn,
	}
	session = s

	InputController:SetFlying(true, state.throttle)
	FlightHUD.SetHint(InputController:GetHint())
	FlightHUD.Show()
	CameraController:FollowPlane(function()
		if not root.Parent then
			return nil, Vector3.zero, 0
		end
		local aim = FlightModel.aimDirection(state)
		local range = stats.maxSpeed - stats.minSpeed
		local ratio = if range > 0 then (state.speed - stats.minSpeed) / range else 0
		-- 화면 표시도 같은 타이밍에 갱신
		local camera = workspace.CurrentCamera
		local function toScreen(dir: Vector3): Vector2?
			local p, onScreen = camera:WorldToViewportPoint(root.Position + dir * Flight.AIM_MARK_DISTANCE)
			return if onScreen then Vector2.new(p.X, p.Y) else nil
		end
		FlightHUD.SetMarks(toScreen(aim), toScreen(root.CFrame.LookVector))
		FlightHUD.SetSpeed(state.speed, ratio)
		return root.CFrame, aim, math.clamp(ratio, 0, 1)
	end)
	FlightController.FlyingChanged:Fire(true)
end

local function isMyPlaneSeat(seat: Instance?): Model?
	if not seat then
		return nil
	end
	local plane = seat.Parent
	if plane and plane:IsA("Model") and plane:GetAttribute("OwnerId") == player.UserId then
		return plane
	end
	return nil
end

local function hookCharacter(char: Model)
	stop()
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	hum.Seated:Connect(function(active, seatPart)
		local plane = if active then isMyPlaneSeat(seatPart) else nil
		if plane then
			start(plane)
		else
			stop()
		end
	end)
	-- 이미 앉아 있을 때
	local plane = isMyPlaneSeat(hum.SeatPart)
	if plane then
		start(plane)
	end
end

function FlightController:Init(controllers)
	InputController = controllers.InputController
	CameraController = controllers.CameraController
end

function FlightController:Start()
	FlightHUD.Mount(player:WaitForChild("PlayerGui"))
	InputController.ToggleRequested:Connect(function()
		FlightController:RequestToggle()
	end)
	-- M 키로 조작 방식을 바꾸면 안내 문구와 속도 슬라이더를 맞춘다
	InputController.ModeChanged:Connect(function()
		FlightHUD.SetHint(InputController:GetHint())
		local s = session
		if s then
			InputController:SyncThrottle(s.state.throttle)
		end
	end)
	player.CharacterAdded:Connect(hookCharacter)
	if player.Character then
		task.spawn(hookCharacter, player.Character)
	end
end

return FlightController
