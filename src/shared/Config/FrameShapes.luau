--!strict
-- 기체 틀 모양: 어느 자리에 블록이 들어가는지.
-- 좌표는 칸 단위 { x, y, z }. -z 가 앞(기수), +y 가 위, +x 가 오른쪽.
-- x > 0 인 칸은 왼쪽(-x)에 자동으로 거울 복사된다 (좌우 대칭). 그래서 오른쪽 절반만 적는다.
-- 칸 이름(설계 데이터 cells 의 키)은 "부위:번호". 번호는 그 부위 모양 안에서 1부터. 대칭 쌍은 이름 하나를 같이 쓴다.
-- 몸통(body)은 고정이고, 기수·날개·꼬리는 A·B·C 세 모양 중 고른다 (부위 교체, 레벨 5).
-- 같은 부위끼리는 칸 수를 비슷하게 맞춘다 (모양은 꾸미기, 성능은 블록이 정함).
-- 모양 블록: 칸 뒤에 "모양:회전" 을 적으면 그 칸은 그 모양이 된다 (BlockShapes 참고, 없으면 사각형).
-- 기본틀은 사각형(육면체)만, 확장 기본틀은 모양 블록이 들어간 비행기 모양. 유저가 칸 모양을 직접 고르는 건 자유 에디터에서만.
-- 모양이 달라도 블록 1개, 성능 같음. 오른쪽 칸 기준이고 왼쪽 거울 칸은 자동으로 좌우가 뒤집힌다.
--   회전: 0 앞  1 왼쪽(안쪽)  2 뒤  3 바깥  / 4~7 은 같은 방향을 뒤집은 것 (예: "wedge:4" 비탈이 앞·아래)
export type Cell = { any }
export type Shape = {
	id: string,
	name: string,
	short: string, -- 에디터 버튼 이름
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
	short = "기본틀",
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

-- 확장 기본틀: 기본틀과 같은 등급·성능 규칙에 모양 블록(경사·반경사·계단 등)을 섞은 비행기 모양.
-- 앞유리·캐노피, 뾰족한 기수, 젖힌 날개, 꼬리 날개. (부위 모양은 지금 한 가지씩, 칸 수는 임시)
local small_ext: Shape = {
	id = "small_ext",
	name = "소형 확장 기본틀",
	short = "확장틀",
	class = "small",
	partOrder = { "body", "nose", "wing", "tail" },
	swappable = { "nose", "wing", "tail" },
	partNames = { body = "몸통", nose = "기수", wing = "날개", tail = "꼬리" },
	variantOrder = { "A" },
	variantNames = {
		nose = { A = "뾰족" },
		wing = { A = "젖힌 날개" },
		tail = { A = "꼬리 날개" },
	},
	parts = {
		body = {
			A = { -- 24칸
				{ 0, 0, -2 }, { 0, 0, -1 }, { 0, 0, 0 }, { 0, 0, 1 }, { 0, 0, 2 }, { 0, 0, 3, "stairs:2" },
				{ 1, 0, -1 }, { 1, 0, 0 }, { 1, 0, 1 }, { 1, 0, 2, "halfwedge:2" },
				{ 0, -1, -1, "wedge:4" }, { 0, -1, 0 }, { 0, -1, 1 }, { 0, -1, 2, "wedge:6" },
				{ 0, 1, -2, "wedge:0" }, -- 앞유리
				{ 0, 1, 0, "wedge:2" }, -- 조종석 뒤 캐노피
				{ 1, 1, -1, "halfwedge:3" }, -- 조종석 옆
			},
		},
		nose = {
			A = { { 0, 0, -3 }, { 0, 0, -4, "wedge:0" }, { 1, 0, -2, "wedge:0" }, { 0, -1, -2, "halfwedge:4" } }, -- 5칸
		},
		wing = {
			A = { -- 16칸
				{ 2, 0, -1, "wedge:0" }, { 2, 0, 0 }, { 2, 0, 1 }, { 3, 0, 0, "wedge:0" }, { 3, 0, 1 },
				{ 4, 0, 1, "wedge:0" }, { 4, 0, 2, "half:0" }, { 5, 0, 2, "halfwedge:3" },
			},
		},
		tail = {
			A = { -- 9칸
				{ 0, 0, 4 }, { 0, 0, 5, "stairs:2" }, { 0, 1, 4, "wedge:0" }, { 0, 1, 5 }, { 0, 2, 5, "wedge:0" },
				{ 1, 0, 5, "half:0" }, { 2, 0, 5, "halfwedge:3" },
			},
		},
	},
	seat = { 0, 1, -1 },
	booster = { 0, -1, 3 },
	weapons = { { 3, -1, 0 } },
	defaultColors = { body = "#7BC043", nose = "#F2F2F2", wing = "#2E9E5B", tail = "#2B2B30" },
}

local byId: { [string]: Shape } = { small_basic = small_basic, small_ext = small_ext }
local order = { "small_basic", "small_ext" } -- 에디터 [틀] 버튼 순서

-- 처음 받는 비행기 (저장된 비행기가 없을 때)
local DEFAULT_DESIGN = {
	frameId = "small_basic",
	parts = { nose = "A", wing = "A", tail = "A" },
	cells = {}, -- 비어 있으면 모두 기본 블록
	colors = {},
	weapon = "cannon",
}

return { byId = byId, order = order, DEFAULT_DESIGN = DEFAULT_DESIGN }
