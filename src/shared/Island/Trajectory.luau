--!strict
-- 채굴 폭탄이 떨어지는 길. 서버(진짜 판정)와 클라이언트(착탄 원·폭탄 모습)가 같은 식을 쓴다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Mining = Config.Mining

local Trajectory = {}

-- 비행기 위치·속도 → 폭탄 시작 위치·속도
function Trajectory.launch(planePos: Vector3, planeVel: Vector3): (Vector3, Vector3)
	local start = planePos - Vector3.new(0, Mining.DROP_OFFSET, 0)
	local vel = planeVel * Mining.INHERIT - Vector3.new(0, Mining.DROP_SPEED, 0)
	return start, vel
end

-- t 초 뒤 폭탄 위치
function Trajectory.at(start: Vector3, vel: Vector3, t: number): Vector3
	return start + vel * t - Vector3.new(0, 0.5 * Mining.GRAVITY * t * t, 0)
end

-- 땅(블록)에 닿는 곳과 걸리는 시간. 닿지 않으면 nil.
function Trajectory.impact(grid: any, start: Vector3, vel: Vector3): (Vector3?, number)
	local step = Mining.STEP
	local t = 0
	local prev = start
	while t < Mining.MAX_FALL_TIME do
		t += step
		local pos = Trajectory.at(start, vel, t)
		if grid:solidAt(pos) then
			-- 한 칸을 건너뛰지 않도록 이전 위치와의 사이를 잘게 다시 본다
			local n = math.max(1, math.ceil((pos - prev).Magnitude / (grid.BS * 0.5)))
			for i = 1, n do
				local p = prev:Lerp(pos, i / n)
				if grid:solidAt(p) then
					return p, t - step + step * i / n
				end
			end
			return pos, t
		end
		if pos.Y < grid.corner.Y - 20 then
			return nil, t
		end
		prev = pos
	end
	return nil, t
end

return Trajectory
