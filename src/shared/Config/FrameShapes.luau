--!strict
-- 기체 틀 모양: 어느 자리에 블록이 들어가는지.
-- 좌표는 칸 단위 { x, y, z }. -z 가 앞(기수), +y 가 위, +x 가 오른쪽.
-- x > 0 인 칸은 왼쪽(-x)에 자동으로 거울 복사된다 (좌우 대칭). 그래서 오른쪽 절반만 적는다.
-- 칸 번호(설계 데이터의 cells 키)는 아래 순서대로 1부터 붙는다. 대칭 쌍은 번호 하나를 같이 쓴다.
-- 부위(nose·wing·tail)는 지금 "A" 하나뿐. 4단계 에디터에서 B·C 를 더한다.
export type Cell = { number }
export type Shape = {
	id: string,
	name: string,
	class: string, -- Frames.byId 의 등급
	partOrder: { string },
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
	parts = {
		body = {
			A = {
				{ 0, 0, -2 }, { 0, 0, -1 }, { 0, 0, 0 }, { 0, 0, 1 }, { 0, 0, 2 }, { 0, 0, 3 },
				{ 1, 0, -1 }, { 1, 0, 0 }, { 1, 0, 1 }, { 1, 0, 2 },
				{ 0, -1, -1 }, { 0, -1, 0 }, { 0, -1, 1 }, { 0, -1, 2 },
			},
		},
		nose = {
			A = {
				{ 0, 0, -4 }, { 0, 0, -3 }, { 1, 0, -3 }, { 0, -1, -2 },
			},
		},
		wing = {
			A = {
				{ 2, 0, 0 }, { 3, 0, 0 }, { 4, 0, 0 }, { 5, 0, 0 },
				{ 2, 0, 1 }, { 3, 0, 1 }, { 4, 0, 1 }, { 5, 0, 1 },
				{ 6, 0, 1 },
			},
		},
		tail = {
			A = {
				{ 0, 0, 4 }, { 0, 0, 5 }, { 0, 1, 4 }, { 0, 1, 5 }, { 0, 2, 5 },
				{ 1, 0, 5 }, { 2, 0, 5 },
			},
		},
	},
	seat = { 0, 1, -1 },
	booster = { 0, -1, 3 },
	weapons = { { 3, -1, 0 } },
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
