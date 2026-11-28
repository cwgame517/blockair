--!strict
-- 레벨 곡선. 원본: 성장 수치표 '레벨' 시트 (임시값)
local Levels = {}

Levels.MAX_LEVEL = 40
Levels.EXPEDITION_BASE_XP = 300 -- 원정 1회 기본 XP
Levels.EXPEDITION_XP_PER_LEVEL = 50 -- 레벨당 추가 XP (15분 타이머·섬 붕괴가 생기면 완주 보너스로 쓴다)
Levels.XP_PER_DEPOSIT = 1 -- 격납고에 맡긴 블록 1개당 XP (지금 XP 를 얻는 길)

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
