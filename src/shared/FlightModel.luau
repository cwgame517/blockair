--!strict
-- 비행 계산. 입력(조준 방향 바꾸기·속도 레버)과 능력치로 "어디를 보고 얼마나 빨리 갈지"를 정한다.
-- 물리 부품은 건드리지 않는 순수 계산이라 클라이언트·서버 어디서나 같은 결과가 나온다.
--
-- 방식: 조준 방향(aim)을 먼저 움직이고, 기수는 회전 한계 안에서 조준을 따라간다.
--   PC  : 마우스가 조준을 움직인다.
--   모바일: 스틱이 조준을 움직인다.
-- 그래서 두 조작이 같은 계산을 쓴다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Flight = Config.Flight

export type State = {
	aimYaw: number, -- 라디안, + 는 왼쪽
	aimPitch: number, -- 라디안, + 는 위
	forward: Vector3, -- 지금 기수 방향
	roll: number, -- 도, + 는 오른쪽으로 기울어짐
	throttle: number, -- 0~1
	speed: number,
	hover: boolean, -- 속도 레버가 맨 아래: 제자리 비행 (블록 캐기)
}

export type Command = {
	yaw: number, -- 이번 프레임에 조준을 돌릴 양 (라디안, + 는 왼쪽)
	pitch: number, -- 이번 프레임에 조준을 올릴 양 (라디안)
	throttleAxis: number, -- -1~1, 누르고 있는 동안 레버가 움직임 (PC W/S)
	throttleSet: number?, -- 0~1, 레버를 이 값으로 (모바일 슬라이더)
	move: number?, -- -1~1, 제자리 비행 중 앞(+)·뒤(-)로 움직이기 (W/S, 스틱 위아래)
}

export type Stats = { maxSpeed: number, minSpeed: number, turnRate: number }

local FlightModel = {}

function FlightModel.direction(yaw: number, pitch: number): Vector3
	local c = math.cos(pitch)
	return Vector3.new(-math.sin(yaw) * c, math.sin(pitch), -math.cos(yaw) * c)
end

function FlightModel.newState(cf: CFrame, stats: Stats): State
	local look = cf.LookVector
	local maxPitch = math.rad(Flight.MAX_AIM_PITCH)
	local pitch = math.clamp(math.asin(math.clamp(look.Y, -1, 1)), -maxPitch, maxPitch)
	local yaw = math.atan2(-look.X, -look.Z)
	local throttle = Flight.START_THROTTLE
	return {
		aimYaw = yaw,
		aimPitch = pitch,
		forward = FlightModel.direction(yaw, pitch),
		roll = 0,
		throttle = throttle,
		speed = stats.minSpeed + (stats.maxSpeed - stats.minSpeed) * throttle,
		hover = false,
	}
end

function FlightModel.aimDirection(state: State): Vector3
	return FlightModel.direction(state.aimYaw, state.aimPitch)
end

-- 수평면에서 a 에서 b 까지의 각도 (라디안, + 는 왼쪽)
local function flatAngle(a: Vector3, b: Vector3): number
	local fa = Vector3.new(a.X, 0, a.Z)
	local fb = Vector3.new(b.X, 0, b.Z)
	if fa.Magnitude < 1e-4 or fb.Magnitude < 1e-4 then
		return 0
	end
	fa, fb = fa.Unit, fb.Unit
	return math.atan2(fa:Cross(fb).Y, fa:Dot(fb))
end

-- 한 프레임 진행. 돌려주는 값: 목표 자세(위치 없는 CFrame), 목표 속도(Vector3)
function FlightModel.step(state: State, cmd: Command, stats: Stats, dt: number): (CFrame, Vector3)
	-- 1) 조준 움직이기
	local maxPitch = math.rad(Flight.MAX_AIM_PITCH)
	state.aimYaw += cmd.yaw
	state.aimPitch = math.clamp(state.aimPitch + cmd.pitch, -maxPitch, maxPitch)
	-- 각도가 끝없이 커지지 않게 -π~π 로 감싼다
	state.aimYaw = (state.aimYaw + math.pi) % (2 * math.pi) - math.pi

	-- 2) 속도 레버와 속도
	if cmd.throttleSet then
		state.throttle = math.clamp(cmd.throttleSet, 0, 1)
	else
		state.throttle = math.clamp(state.throttle + cmd.throttleAxis * Flight.THROTTLE_RATE * dt, 0, 1)
	end
	-- 레버 맨 아래: 제자리 비행. 수평을 잡고 멈춰 떠 있으며, 조준 좌우로 돌고 W/S(스틱 위아래)로 천천히 앞뒤 이동.
	-- 높이는 그대로 (폭탄은 바로 아래로 떨어지므로 높이를 맞출 필요가 없다).
	state.hover = state.throttle < Flight.HOVER_ZONE
	if state.hover then
		local brake = Flight.HOVER_BRAKE * dt
		state.speed = math.max(0, state.speed - brake)
		state.aimPitch += (0 - state.aimPitch) * math.min(1, 4 * dt)
		local level = FlightModel.direction(state.aimYaw, 0)
		local fwd = state.forward
		local flatFwd = Vector3.new(fwd.X, 0, fwd.Z)
		flatFwd = if flatFwd.Magnitude > 1e-4 then flatFwd.Unit else level
		local angle = math.acos(math.clamp(flatFwd:Dot(level), -1, 1))
		local maxStep = math.rad(Flight.HOVER_TURN_RATE) * dt
		if angle <= maxStep then
			fwd = level
		else
			local axis = if flatFwd:Cross(level).Y >= 0 then Vector3.yAxis else -Vector3.yAxis
			fwd = (CFrame.fromAxisAngle(axis, maxStep) * flatFwd).Unit
		end
		state.forward = fwd
		state.roll += (0 - state.roll) * math.min(1, Flight.BANK_SMOOTH * dt)
		local move = math.clamp(cmd.move or 0, -1, 1) * Flight.HOVER_MOVE_SPEED
		local orientation = CFrame.lookAt(Vector3.zero, fwd, Vector3.yAxis) * CFrame.Angles(0, 0, -math.rad(state.roll))
		return orientation, fwd * (state.speed + move)
	end

	-- 레버 위쪽 구간을 최저~최고 속도에 맞춘다
	local t = (state.throttle - Flight.HOVER_ZONE) / (1 - Flight.HOVER_ZONE)
	local target = stats.minSpeed + (stats.maxSpeed - stats.minSpeed) * t
	local accel = Flight.ACCELERATION * dt
	state.speed += math.clamp(target - state.speed, -accel, accel)

	-- 3) 기수가 조준을 따라 돈다 (1초에 turnRate 도까지)
	local aim = FlightModel.aimDirection(state)
	local fwd = state.forward
	local angle = math.acos(math.clamp(fwd:Dot(aim), -1, 1))
	local maxStep = math.rad(stats.turnRate) * dt
	if angle <= maxStep then
		fwd = aim
	else
		local axis = fwd:Cross(aim)
		if axis.Magnitude < 1e-6 then
			axis = Vector3.yAxis -- 정반대 방향: 옆으로 돌아 나간다
		end
		fwd = (CFrame.fromAxisAngle(axis.Unit, maxStep) * fwd).Unit
	end
	state.forward = fwd

	-- 4) 도는 쪽으로 기울이기
	local turnLeft = math.deg(flatAngle(fwd, aim))
	local desiredRoll = math.clamp(-turnLeft * Flight.BANK_GAIN, -Flight.MAX_BANK, Flight.MAX_BANK)
	state.roll += (desiredRoll - state.roll) * math.min(1, Flight.BANK_SMOOTH * dt)

	local orientation = CFrame.lookAt(Vector3.zero, fwd, Vector3.yAxis) * CFrame.Angles(0, 0, -math.rad(state.roll))
	return orientation, fwd * state.speed
end

return FlightModel
