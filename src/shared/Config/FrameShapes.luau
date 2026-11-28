--!strict
-- 기체 틀 모양: 어느 자리에 블록이 들어가는지.
-- 좌표는 칸 단위 { x, y, z }. -z 가 앞(기수), +y 가 위, +x 가 오른쪽.
-- x > 0 인 칸은 왼쪽(-x)에 자동으로 거울 복사된다 (좌우 대칭). 그래서 오른쪽 절반만 적는다.
-- 칸 이름(설계 데이터 cells 의 키)은 "부위:번호". 번호는 그 부위 모양 안에서 1부터. 대칭 쌍은 이름 하나를 같이 쓴다.
-- 몸통(body)은 고정이고, 기수·날개·꼬리는 A·B·C 세 모양 중 고른다 (부위 교체, 레벨 5).
-- 같은 부위끼리는 칸 수를 비슷하게 맞춘다 (모양은 꾸미기, 성능은 블록이 정함).
export type Cell = { number }
export type Shape = {
	id: string,
	name: string,
	class: string, -- Frames.byId 의 등급
	partOrder: { string },
	swappable: { string }, -- 바꿀 수 있는 부위 (에디터 탭 순서)
	partNames: { [string]: string },
	variantOrder: { string },
	variantNames: { [string]: { [string]: string } },
	parts: { [string]: { [string]: { Cell } } },
	seat: Cell, -- 조종석(아바타 자리)
	booster: Cell, -- 부스터 위치
	weapons: { Cell }, -- 무기 자리 (무기 칸 수만큼, 대칭으로 그려짐)
	defaultColors: { [string]: string },
}

local small_basic: Shape = {
	id = "small_basic",
	name = "소형 기본틀",
	class = "small",
	partOrder = { "body", "nose", "wing", "tail" },
	swappable = { "nose", "wing", "tail" },
	partNames = { body = "몸통", nose = "기수", wing = "날개", tail = "꼬리" },
	variantOrder = { "A", "B", "C" },
	variantNames = {
		nose = { A = "기본", B = "뾰족", C = "넓적" },
		wing = { A = "곧은 날개", B = "젖힌 날개", C = "삼각 날개" },
		tail = { A = "기본", B = "쌍꼬리", C = "T자 꼬리" },
	},
	parts = {
		body = {
			A = {
				{ 0, 0, -2 }, { 0, 0, -1 }, { 0, 0, 0 }, { 0, 0, 1 }, { 0, 0, 2 }, { 0, 0, 3 },
				{ 1, 0, -1 }, { 1, 0, 0 }, { 1, 0, 1 }, { 1, 0, 2 },
				{ 0, -1, -1 }, { 0, -1, 0 }, { 0, -1, 1 }, { 0, -1, 2 },
			},
		},
		nose = {
			A = { { 0, 0, -4 }, { 0, 0, -3 }, { 1, 0, -3 }, { 0, -1, -2 } }, -- 5칸
			B = { { 0, 0, -5 }, { 0, 0, -4 }, { 0, 0, -3 }, { 0, -1, -3 }, { 0, -1, -2 } }, -- 5칸
			C = { { 0, 0, -3 }, { 1, 0, -3 }, { 0, -1, -2 }, { 1, -1, -2 } }, -- 6칸
		},
		wing = {
			A = { -- 18칸
				{ 2, 0, 0 }, { 3, 0, 0 }, { 4, 0, 0 }, { 5, 0, 0 },
				{ 2, 0, 1 }, { 3, 0, 1 }, { 4, 0, 1 }, { 5, 0, 1 },
				{ 6, 0, 1 },
			},
			B = { -- 18칸
				{ 2, 0, -1 }, { 2, 0, 0 }, { 3, 0, 0 }, { 3, 0, 1 }, { 4, 0, 1 },
				{ 4, 0, 2 }, { 5, 0, 2 }, { 5, 0, 3 }, { 6, 0, 3 },
			},
			C = { -- 18칸
				{ 2, 0, -1 }, { 2, 0, 0 }, { 2, 0, 1 }, { 2, 0, 2 },
				{ 3, 0, 0 }, { 3, 0, 1 }, { 3, 0, 2 }, { 4, 0, 1 }, { 4, 0, 2 },
			},
		},
		tail = {
			A = { { 0, 0, 4 }, { 0, 0, 5 }, { 0, 1, 4 }, { 0, 1, 5 }, { 0, 2, 5 }, { 1, 0, 5 }, { 2, 0, 5 } }, -- 9칸
			B = { { 0, 0, 4 }, { 0, 0, 5 }, { 0, 0, 6 }, { 1, 0, 5 }, { 1, 1, 5 }, { 1, 2, 5 } }, -- 9칸
			C = { { 0, 0, 4 }, { 0, 0, 5 }, { 0, 1, 4 }, { 0, 1, 5 }, { 0, 2, 5 }, { 1, 2, 5 }, { 2, 2, 5 } }, -- 9칸
		},
	},
	seat = { 0, 1, -1 },
	booster = { 0, -1, 3 },
	weapons = { { 3, -1, 0 } }, -- 날개 A·B·C 모두 (3,0,0) 칸이 있어 그 아래에 단다
	defaultColors = { body = "#3D7FD9", nose = "#F2F2F2", wing = "#F2C230", tail = "#E04848" },
}

local byId: { [string]: Shape } = { small_basic = small_basic }

-- 처음 받는 비행기 (저장된 비행기가 없을 때)
local DEFAULT_DESIGN = {
	frameId = "small_basic",
	parts = { nose = "A", wing = "A", tail = "A" },
	cells = {}, -- 비어 있으면 모두 기본 블록
	colors = {},
	weapon = "cannon",
}

return { byId = byId, DEFAULT_DESIGN = DEFAULT_DESIGN }
