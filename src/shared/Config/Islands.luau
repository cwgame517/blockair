--!strict
-- 섬 크기표. 원본: 기획서 4장
return {
	CHUNK = 16,
	AIRSPACE_SCALE = 3, -- 하늘 공간 = 섬 지름 × 3 (최대 1024)
	AIRSPACE_MAX = 1024,
	HANGARS = 4,
	SIZES = {
		{ minPlayers = 1, maxPlayers = 2, diameter = 96, cap = 3 },
		{ minPlayers = 3, maxPlayers = 5, diameter = 160, cap = 7 },
		{ minPlayers = 6, maxPlayers = 10, diameter = 224, cap = 12 },
		{ minPlayers = 11, maxPlayers = 15, diameter = 256, cap = 15 },
	},
}
