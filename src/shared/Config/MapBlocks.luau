--!strict
-- 몸통 블록이 아닌 맵 블록: 캐면 바로 효과. 원본: 성장 수치표 '코인 수입' 시트 (임시값)
-- id는 Blocks 와 겹치지 않게 200번대부터 쓴다 (섬 칸은 1바이트).
-- minePower: 이 블록을 한 방에 깨려면 필요한 채굴력 (몸통 블록은 Blocks 의 minePower)
return {
	fuel = {
		{ id = 201, key = "coal", name = "석탄", fuel = 0.10, minePower = 1 },
		{ id = 202, key = "oil", name = "석유", fuel = 0.25, minePower = 2 },
		{ id = 203, key = "uranium", name = "우라늄", fuel = 0.60, minePower = 5 },
	},
	treasure = {
		{ id = 211, key = "goldOre", name = "금광석", coins = 100, minePower = 2 },
		{ id = 212, key = "gem", name = "보석", coins = 400, minePower = 4 },
		{ id = 213, key = "bigGem", name = "큰 보석", coins = 1500, minePower = 7 },
	},
}
