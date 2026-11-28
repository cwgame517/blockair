--!strict
-- 레벨 곡선. 원본: 성장 수치표 '레벨' 시트 (임시값)
local Levels = {}

Levels.MAX_LEVEL = 40
-- 원정 XP (5단계): 원정을 마치고 돌아갈 때 (기본 + 레벨당 추가) × 머문 시간 비율(15분이면 100%)
-- 격납고에 블록을 1개도 맡기지 않았으면 0 (가만히 있기 방지). 15분 타이머가 생기면(6단계) 완주 보상으로 바뀐다.
Levels.EXPEDITION_BASE_XP = 300 -- 원정 1회 기본 XP
Levels.EXPEDITION_XP_PER_LEVEL = 50 -- 레벨당 추가 XP
Levels.EXPEDITION_FULL_TIME = 15 * 60 -- 이만큼 머물면 원정 XP 100% (초)
Levels.XP_PER_DEPOSIT = 0 -- 격납고에 맡긴 블록 1개당 XP (3단계 임시 방식, 지금은 원정 XP 로 바꿔 0)

function Levels.expeditionXp(level: number, seconds: number): number
	local full = Levels.EXPEDITION_BASE_XP + Levels.EXPEDITION_XP_PER_LEVEL * level
	return math.floor(full * math.clamp(seconds / Levels.EXPEDITION_FULL_TIME, 0, 1) + 0.5)
end

-- 다음 레벨까지 필요한 XP = 100 × 레벨^1.5 를 10 단위로 반올림
function Levels.xpToNext(level: number): number
	if level >= Levels.MAX_LEVEL then
		return math.huge
	end
	return math.floor(100 * level ^ 1.5 / 10 + 0.5) * 10
end

-- 강화 상한 단계 (1 = 기본, 5 = 최대)
function Levels.upgradeCap(level: number): number
	if level >= 25 then
		return 5
	elseif level >= 15 then
		return 4
	elseif level >= 8 then
		return 3
	elseif level >= 3 then
		return 2
	end
	return 1
end

Levels.UNLOCKS = {
	[1] = "소형 틀, 무기 3종, 협동 원정",
	[3] = "강화 2단계",
	[5] = "중형 틀, 서바이벌 입장",
	[8] = "강화 3단계",
	[10] = "서바이벌 드롭 보호 끝 (25%→50%)",
	[15] = "대형 틀, 강화 4단계",
	[25] = "강화 5단계",
	[30] = "초대형 틀",
}

return Levels
