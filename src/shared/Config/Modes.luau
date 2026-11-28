--!strict
-- 원정 모드 규칙. 원본: 기획서 4·6장
return {
	coop = {
		name = "협동", duration = 15 * 60, pvp = false, naturalRegen = true,
	},
	survival = {
		name = "서바이벌", duration = 15 * 60, pvp = true, naturalRegen = false,
		minPlayers = 4, minLevel = 5,
		dropRatio = 0.5, protectedDropRatio = 0.25, protectedBelowLevel = 10, protectedBelowCargo = 10,
		respawnTimes = { 5, 8, 10 }, spawnInvincible = 3, noRespawnLast = 120,
	},
	HANGAR_REPAIR_DELAY = 3,
}
