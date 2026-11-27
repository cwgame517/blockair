--!strict
-- 협동 모드 몹. 원본: 성장 수치표 '몹' 시트 (임시값)
local Mobs = {}

Mobs.STAGE_SCALE = 0.25 -- 섬 단계가 하나 오를 때마다 HP·보상 +25%
Mobs.DENSITY_AREA = 64 -- 64×64 칸마다 1마리
Mobs.DRONE_RESPAWN = 60 -- 초
Mobs.REWARD_WINDOW = 10 -- 마지막 10초 안에 피해를 준 사람 모두가 보상

Mobs.TYPES = {
	patrolDrone = { name = "순찰 드론", hp = 300, coins = 50, xp = 20 },
	turret = { name = "터렛", hp = 600, coins = 80, xp = 30 },
	oreThief = { name = "광석 도둑", hp = 400, coins = 60, xp = 25 },
	shieldDrone = { name = "보호막 드론", hp = 250, coins = 100, xp = 35, shield = 300 },
	guardian = { name = "섬 수호자", hp = 0, coins = 1000, xp = 400, isBoss = true },
}

function Mobs.scale(stage: number): number
	return 1 + Mobs.STAGE_SCALE * (stage - 1)
end

function Mobs.bossHp(players: number): number
	return 4000 + 2500 * players
end

return Mobs
