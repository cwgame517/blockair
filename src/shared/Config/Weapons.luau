--!strict
-- 공격 무기 3종과 채굴 폭탄. 원본: 성장 수치표 '무기' 시트 (임시값)
-- 거리 상성: 기관포 > 미사일 > 레이저 > 기관포
return {
	cannon = {
		name = "기관포", strongAgainst = "missile",
		rangeMin = 10, rangeMax = 60, damage = 15, fireRate = 10,
		useTime = 4, cooldown = 2, -- 4초 쏘면 과열, 2초 냉각
	},
	missile = {
		name = "미사일", strongAgainst = "laser",
		rangeMin = 40, rangeMax = 150, damage = 200, fireRate = 0.8,
		magazine = 4, reload = 3, homing = true,
	},
	laser = {
		name = "레이저", strongAgainst = "cannon",
		rangeMin = 80, rangeMax = 250, damage = 12, fireRate = 10,
		useTime = 3, cooldown = 1.5,
	},
	bomb = {
		name = "채굴 폭탄", damagesPlayers = false, unlimited = true,
		-- 범위·재장전·위력은 Upgrades 의 bombRadius/bombReload/bombPower
	},
}
