--!strict
-- 섬 크기표와 섬 만들기 규칙. 원본: 기획서 4장 (임시값)
-- 단위: 섬 안의 좌표는 "블록 칸", 월드 크기는 칸 × BLOCK_SIZE 스터드.
return {
	CHUNK = 16, -- 화면에 그릴 때 묶는 단위 (16×16×16 칸)
	BLOCK_SIZE = 4, -- 섬 블록 한 칸 크기 (스터드)
	HEIGHT = 64, -- 섬 공간 높이 (칸). 아래쪽 뿌리 + 위쪽 언덕·나무
	TOP = 50, -- 평평할 때 땅 표면 높이 (칸). 이 높이의 윗면이 월드 Y=0
	AIRSPACE_SCALE = 3, -- 하늘 공간 = 섬 지름 × 3 (최대 1024)
	AIRSPACE_MAX = 1024,
	CEILING = 400, -- 섬 하늘의 천장 (스터드)
	FLOOR = -420, -- 섬 하늘의 바닥 (스터드)
	HANGARS = 4,
	SIZES = {
		{ minPlayers = 1, maxPlayers = 2, diameter = 96, cap = 3 },
		{ minPlayers = 3, maxPlayers = 5, diameter = 160, cap = 7 },
		{ minPlayers = 6, maxPlayers = 10, diameter = 224, cap = 12 },
		{ minPlayers = 11, maxPlayers = 15, diameter = 256, cap = 15 },
	},

	-- 2단계 MVP: 섬 하나 (인원별 크기는 매칭이 생기면 고른다)
	MVP_DIAMETER = 96,
	FIXED_SEED = 0, -- 0 이면 서버마다 새 씨앗. 같은 섬을 다시 보고 싶으면 출력 창의 씨앗 번호를 넣는다

	-- 모양
	EDGE_WOBBLE = 0.12, -- 섬 가장자리가 들쭉날쭉한 정도 (0~0.3)
	HILL_HEIGHT = 4, -- 언덕 높이 (칸)
	MIN_THICKNESS = 3, -- 가장자리 두께 (칸)
	MAX_THICKNESS = 46, -- 가운데 뿌리 깊이 (칸)
	TREES_PER_96 = 9, -- 지름 96 섬 기준 나무 수

	-- 깊이(표면에서 몇 칸 아래)별 바탕 블록. 위에서부터 차례로 맞는 첫 줄을 쓴다.
	LAYERS = {
		{ maxDepth = 0, block = "grass", edgeBlock = "sand" }, -- 표면 (가장자리는 모래)
		{ maxDepth = 3, block = "dirt" },
		{ maxDepth = 9, block = "stone" },
		{ maxDepth = 16, block = "stone1", patch = "limestone" },
		{ maxDepth = 999, block = "granite", patch = "marble" },
	},
	PATCH_CHANCE = 0.18, -- 바탕 블록 대신 patch 블록이 나올 비율

	-- 광맥: 지름 96 섬 기준 개수. minDepth~maxDepth 깊이에 size 칸 정도로 뭉친다.
	-- block 은 Blocks 또는 MapBlocks 의 key
	ORES = {
		{ block = "coal", veins = 14, minDepth = 2, maxDepth = 14, size = 7 },
		{ block = "Copper_1", veins = 10, minDepth = 5, maxDepth = 22, size = 6 },
		{ block = "goldOre", veins = 7, minDepth = 6, maxDepth = 30, size = 4 },
		{ block = "oil", veins = 5, minDepth = 10, maxDepth = 30, size = 6 },
		{ block = "Iron_1", veins = 8, minDepth = 14, maxDepth = 99, size = 5 },
		{ block = "gem", veins = 4, minDepth = 18, maxDepth = 99, size = 3 },
		{ block = "uranium", veins = 3, minDepth = 20, maxDepth = 99, size = 3 },
		{ block = "bigGem", veins = 1, minDepth = 26, maxDepth = 99, size = 2 },
	},
}
