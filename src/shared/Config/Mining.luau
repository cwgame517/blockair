--!strict
-- 채굴 폭탄과 블록 수집 수치 (임시값). 범위·재장전·위력 단계는 Upgrades 에 있다.
local Mining = {}

-- 폭탄이 떨어지는 모양
Mining.GRAVITY = 120 -- 스터드/초²
Mining.INHERIT = 0.6 -- 비행기 속도를 이만큼 물려받음 (1 이면 비행기와 같이 날아감)
Mining.DROP_SPEED = 15 -- 처음에 아래로 던지는 속도
Mining.DROP_OFFSET = 3 -- 비행기 중심에서 이만큼 아래에서 떨어짐
Mining.MAX_FALL_TIME = 6 -- 이 시간 안에 땅에 안 닿으면 사라짐
Mining.STEP = 1 / 30 -- 궤도 계산 간격

-- 수집
Mining.COLLECT_DELAY = 0.5 -- 부서진 블록이 내 비행기로 날아오는 시간
Mining.CRACK_STAGES = 3 -- 균열 단계 수

-- 깨는 데 필요한 횟수 = 올림(블록에 필요한 채굴력 ÷ 내 채굴력), 최소 1
-- 내 채굴력 = 비행기 블록 평균 채굴력 + 폭탄 위력 강화
function Mining.hitsFor(required: number, power: number): number
	return math.max(1, math.ceil(required / math.max(power, 0.1) - 1e-6))
end

return Mining
