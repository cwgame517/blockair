--!strict
-- 몸통 블록이 아닌 맵 블록: 캐면 바로 효과. 원본: 성장 수치표 '코인 수입' 시트 (임시값)
-- id는 Blocks 와 겹치지 않게 200번대부터 쓴다 (섬 청크는 1바이트).
return {
	fuel = {
		{ id = 201, key = "coal", name = "석탄", fuel = 0.10 },
		{ id = 202, key = "oil", name = "석유", fuel = 0.25 },
		{ id = 203, key = "uranium", name = "우라늄", fuel = 0.60 },
	},
	treasure = {
		{ id = 211, key = "goldOre", name = "금광석", coins = 100 },
		{ id = 212, key = "gem", name = "보석", coins = 400 },
		{ id = 213, key = "bigGem", name = "큰 보석", coins = 1500 },
	},
}
