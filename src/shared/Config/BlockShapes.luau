--!strict
-- 모양 블록 8종 (원작 에디터와 같은 종류). 모양은 꾸미기용이라 성능(무게·단단함)은 블록 종류로만 정해진다.
-- 회전 번호 0~7: 0~3 = 위를 보고 90도씩 돌림, 4~7 = 뒤집어서(아래를 보게) 90도씩 돌림.
-- 막대기는 4~7 이 세운 막대.
export type ShapeDef = { id: string, name: string }

local list: { ShapeDef } = {
	{ id = "cube", name = "사각형" },
	{ id = "three4", name = "사각형¾" },
	{ id = "half", name = "반사각형" },
	{ id = "quarter", name = "반반사각형" },
	{ id = "wedge", name = "삼각형" },
	{ id = "halfwedge", name = "반삼각형" },
	{ id = "stairs", name = "계단" },
	{ id = "stick", name = "막대기" },
}

local byId: { [string]: ShapeDef } = {}
for _, s in list do
	byId[s.id] = s
end

return { list = list, byId = byId, ROTATIONS = 8 }
