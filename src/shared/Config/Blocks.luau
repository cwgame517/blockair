--!strict
-- 자동 생성 파일: tools/export_config.py 로 다시 만든다. 직접 고치지 말 것.
-- 원본: data/blocks_v2.csv

export type Block = {
	id: number, key: string, name: string, grade: string, tier: number,
	family: string, layer: string, hardness: number, weight: number,
	minePower: number, unlockLevel: number, price: number, flavor: string,
}

local list: { Block } = {
	{ id = 1, key = "tree", name = "나무", grade = "F", tier = 1, family = "경량", layer = "표면", hardness = 6, weight = 0.4, minePower = 1, unlockLevel = 1, price = 6, flavor = "" },
	{ id = 2, key = "wood", name = "원목", grade = "F", tier = 1, family = "경량", layer = "표면", hardness = 6, weight = 0.4, minePower = 1, unlockLevel = 1, price = 6, flavor = "" },
	{ id = 3, key = "glass", name = "유리", grade = "F", tier = 1, family = "특수", layer = "표면", hardness = 10, weight = 1, minePower = 1, unlockLevel = 1, price = 6, flavor = "" },
	{ id = 4, key = "grass", name = "잔디", grade = "F", tier = 1, family = "경량", layer = "표면", hardness = 6, weight = 0.4, minePower = 1, unlockLevel = 1, price = 6, flavor = "" },
	{ id = 5, key = "dirt", name = "흙", grade = "F", tier = 1, family = "구조", layer = "표면", hardness = 10, weight = 1, minePower = 1, unlockLevel = 1, price = 6, flavor = "" },
	{ id = 6, key = "sand", name = "모래", grade = "F", tier = 1, family = "구조", layer = "표면", hardness = 10, weight = 1, minePower = 1, unlockLevel = 1, price = 6, flavor = "" },
	{ id = 7, key = "stone", name = "돌", grade = "F", tier = 1, family = "구조", layer = "표면", hardness = 10, weight = 1, minePower = 1, unlockLevel = 1, price = 11, flavor = "" },
	{ id = 8, key = "stone1", name = "암석", grade = "E", tier = 2, family = "구조", layer = "표면", hardness = 10, weight = 1, minePower = 1.5, unlockLevel = 1, price = 11, flavor = "" },
	{ id = 9, key = "brick", name = "벽돌", grade = "E", tier = 2, family = "구조", layer = "표면", hardness = 10, weight = 1, minePower = 1.5, unlockLevel = 1, price = 11, flavor = "" },
	{ id = 10, key = "concrete", name = "콘크리트", grade = "E+", tier = 2, family = "구조", layer = "표면", hardness = 10, weight = 1, minePower = 1.5, unlockLevel = 1, price = 11, flavor = "" },
	{ id = 11, key = "asphalt", name = "아스팔트", grade = "E+", tier = 2, family = "구조", layer = "표면", hardness = 10, weight = 1, minePower = 1.5, unlockLevel = 1, price = 11, flavor = "" },
	{ id = 12, key = "stone2", name = "자갈", grade = "E+", tier = 2, family = "구조", layer = "표면", hardness = 10, weight = 1, minePower = 1.5, unlockLevel = 1, price = 17, flavor = "" },
	{ id = 13, key = "limestone", name = "석회암", grade = "D", tier = 3, family = "구조", layer = "중간층", hardness = 15, weight = 1, minePower = 2, unlockLevel = 1, price = 43, flavor = "" },
	{ id = 14, key = "granite", name = "화강암", grade = "D+", tier = 3, family = "구조", layer = "중간층", hardness = 15, weight = 1, minePower = 2, unlockLevel = 1, price = 65, flavor = "" },
	{ id = 15, key = "tempglass", name = "강화유리", grade = "C-", tier = 3, family = "특수", layer = "중간층", hardness = 15, weight = 1, minePower = 2, unlockLevel = 1, price = 150, flavor = "" },
	{ id = 16, key = "marble", name = "대리암", grade = "D++", tier = 3, family = "구조", layer = "중간층", hardness = 15, weight = 1, minePower = 2, unlockLevel = 1, price = 107, flavor = "" },
	{ id = 17, key = "Copper_1", name = "초급구리", grade = "C-", tier = 4, family = "장갑", layer = "중간층", hardness = 22, weight = 2, minePower = 3, unlockLevel = 2, price = 150, flavor = "" },
	{ id = 18, key = "Copper_2", name = "중급구리", grade = "C", tier = 4, family = "장갑", layer = "중간층", hardness = 22, weight = 2, minePower = 3, unlockLevel = 3, price = 171, flavor = "" },
	{ id = 19, key = "Copper_3", name = "고급구리", grade = "C+", tier = 4, family = "장갑", layer = "중간층", hardness = 22, weight = 2, minePower = 3, unlockLevel = 4, price = 193, flavor = "" },
	{ id = 20, key = "Copper_4", name = "최고급구리", grade = "C++", tier = 4, family = "장갑", layer = "중간층", hardness = 22, weight = 2, minePower = 3, unlockLevel = 5, price = 214, flavor = "" },
	{ id = 21, key = "Iron_1", name = "초급철", grade = "B-", tier = 5, family = "장갑", layer = "심층", hardness = 30, weight = 2, minePower = 5, unlockLevel = 6, price = 294, flavor = "" },
	{ id = 22, key = "Iron_2", name = "중급철", grade = "B-", tier = 5, family = "장갑", layer = "심층", hardness = 30, weight = 2, minePower = 5, unlockLevel = 7, price = 321, flavor = "" },
	{ id = 23, key = "Iron_3", name = "고급철", grade = "B+", tier = 5, family = "장갑", layer = "심층", hardness = 30, weight = 2, minePower = 5, unlockLevel = 8, price = 347, flavor = "" },
	{ id = 24, key = "Iron_4", name = "최고급철", grade = "B++", tier = 5, family = "장갑", layer = "심층", hardness = 30, weight = 2, minePower = 5, unlockLevel = 9, price = 374, flavor = "" },
	{ id = 25, key = "nikel_1", name = "초급니켈", grade = "A-", tier = 6, family = "장갑", layer = "심층", hardness = 30, weight = 2, minePower = 7, unlockLevel = 10, price = 481, flavor = "" },
	{ id = 26, key = "nikel_2", name = "중급니켈", grade = "A", tier = 6, family = "장갑", layer = "심층", hardness = 30, weight = 2, minePower = 7, unlockLevel = 11, price = 513, flavor = "" },
	{ id = 27, key = "nikel_3", name = "고급니켈", grade = "A+", tier = 6, family = "장갑", layer = "심층", hardness = 30, weight = 2, minePower = 7, unlockLevel = 12, price = 545, flavor = "" },
	{ id = 28, key = "nikel_4", name = "최고급니켈", grade = "A++", tier = 6, family = "장갑", layer = "심층", hardness = 30, weight = 2, minePower = 7, unlockLevel = 13, price = 577, flavor = "" },
	{ id = 29, key = "titanium_1", name = "초급티타늄", grade = "S-", tier = 7, family = "장갑", layer = "심층", hardness = 30, weight = 2, minePower = 10, unlockLevel = 14, price = 710, flavor = "" },
	{ id = 30, key = "titanium_2", name = "중급티타늄", grade = "S", tier = 7, family = "장갑", layer = "심층", hardness = 30, weight = 2, minePower = 10, unlockLevel = 15, price = 747, flavor = "" },
	{ id = 31, key = "titanium_3", name = "고급티타늄", grade = "S+", tier = 7, family = "장갑", layer = "심층", hardness = 30, weight = 2, minePower = 10, unlockLevel = 16, price = 785, flavor = "" },
	{ id = 32, key = "titanium_4", name = "최고급티타늄", grade = "S++", tier = 7, family = "장갑", layer = "심층", hardness = 30, weight = 2, minePower = 10, unlockLevel = 17, price = 822, flavor = "" },
	{ id = 33, key = "crystal", name = "볼트리움", grade = "SS-", tier = 8, family = "구조", layer = "코어 주변", hardness = 30, weight = 1, minePower = 15, unlockLevel = 18, price = 982, flavor = "천둥구름 한가운데에 벼락이 천 번 내리쳐 굳은 금속입니다. 손을 대면 아직도 찌릿합니다." },
	{ id = 34, key = "valyrian", name = "셀레스티움", grade = "SS", tier = 9, family = "경량", layer = "코어 주변", hardness = 18, weight = 0.4, minePower = 22, unlockLevel = 20, price = 1153, flavor = "구름보다 높은 하늘의 빛이 내려앉아 생긴 금속입니다. 깃털처럼 가볍지만 결코 꺾이지 않습니다." },
	{ id = 35, key = "Gundarium", name = "그라비움", grade = "SS+", tier = 9, family = "장갑", layer = "코어 주변", hardness = 45, weight = 2, minePower = 22, unlockLevel = 21, price = 1201, flavor = "하늘 섬을 붙잡고 있는 중력이 한 점에 뭉친 금속입니다. 손톱만 한 조각도 놀랄 만큼 무겁고 단단합니다." },
	{ id = 36, key = "Vibranium", name = "노바리움", grade = "SS++", tier = 10, family = "특수", layer = "코어 주변", hardness = 30, weight = 1, minePower = 30, unlockLevel = 22, price = 1387, flavor = "먼 옛날 별이 터지며 하늘 섬의 심장에 박힌 금속입니다. 이 금속을 단 비행기는 별처럼 빛납니다." },
}

local byId: { [number]: Block } = {}
local byKey: { [string]: Block } = {}
for _, b in list do
	byId[b.id] = b
	byKey[b.key] = b
end

return { list = list, byId = byId, byKey = byKey }
