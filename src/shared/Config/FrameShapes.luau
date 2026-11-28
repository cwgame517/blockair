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
			A = { -- 22칸
				{ 0, 0, -2 }, { 0, 0, -1 }, { 0, 0, 0 }, { 0, 0, 1 }, { 0, 0, 2 }, { 0, 0, 3, "stairs:2" },
				{ 1, 0, -1 }, { 1, 0, 0 }, { 1, 0, 1 }, { 1, 0, 2, "halfwedge:2" },
				{ 0, -1, -1, "wedge:4" }, { 0, -1, 0 }, { 0, -1, 1 }, { 0, -1, 2, "wedge:6" },
				{ 0, 1, -2, "wedge:0" }, -- 앞유리
				{ 0, 1, 0, "wedge:2" }, -- 조종석 뒤 캐노피
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

-- 자유틀 (게임패스): 정해진 칸 없이 상자 안 아무 곳에나 블록을 붙이고 떼고, 모양 블록으로 바꾼다.
-- 칸 수 상한·무기 칸·피격 구슬은 같은 등급 규칙. 칸 자리는 설계 데이터 free 에 "x,y,z" 로 저장.
-- core 칸(조종석 아래)은 뗄 수 없다. 처음에는 지금 비행기 모양을 그대로 옮겨 와서 시작한다.
local small_free: Shape = {
	id = "small_free",
	name = "소형 자유틀",
	short = "자유틀",
	class = "small",
	free = true,
	box = { x = 7, yMin = -3, yMax = 4, zMin = -8, zMax = 8 }, -- 블록을 놓을 수 있는 상자 (칸 단위)
	core = { 0, 0, -1 },
	partOrder = { "body" },
	swappable = {},
	partNames = { body = "몸통" },
	variantOrder = { "A" },
	variantNames = {},
	parts = { body = { A = {} } },
	seat = { 0, 1, -1 },
	booster = { 0, -1, 3 }, -- 자유틀은 블록 모양에 맞춰 다시 정함 (가장 뒤 칸 뒤)
	weapons = { { 3, -1, 0 } }, -- 자유틀은 가장 바깥 칸 아래로 다시 정함
	defaultColors = { body = "#3D7FD9" },
} :: any

-- ── 중형·대형·초대형 기본틀 (5단계) ──────────────────────────────────────────
-- 칸이 많아서 손으로 적지 않고 숫자 몇 개로 만든다. 소형 기본틀과 같은 구조:
-- 몸통(고정) + 기수·날개·꼬리 A·B·C (부위 교체). 칸 수는 등급 상한(150·300·500)에 맞춰 둠.
-- 오른쪽 절반(x ≥ 0)만 만든다 (x > 0 칸은 자동 거울 복사).
type Params = {
	id: string, name: string, short: string, class: string,
	bw: number, -- 몸통 반폭 (x 0..bw)
	bh: number, -- 몸통 층 수 (y 0 ~ -(bh-1))
	front: number, back: number, -- 몸통 앞·뒤 z
	nose: number, -- 기수 길이
	span: number, -- 날개 길이 (몸통 옆으로 몇 칸)
	chord: number, -- 날개 폭 (앞뒤)
	wingZ: number, -- 날개 앞 끝 z
	wingT: number, -- 날개 뿌리 두께 (층)
	tail: number, -- 꼬리 길이
	fin: number, -- 꼬리 날개 높이
	stab: number, -- 수평 꼬리 날개 길이
	weapons: number,
	colors: { [string]: string },
}

local function add(list: { Cell }, seen: { [string]: boolean }, x: number, y: number, z: number)
	if x < 0 then
		return
	end
	local k = `{x},{y},{z}`
	if not seen[k] then
		seen[k] = true
		table.insert(list, { x, y, z })
	end
end

local function makeBody(p: Params): { Cell }
	local out, seen = {}, {}
	for y = 0, -(p.bh - 1), -1 do
		for z = p.front, p.back do
			-- 아래층은 앞뒤가 조금 짧다 (배 모양)
			local cut = -y
			if z >= p.front + cut and z <= p.back - cut then
				for x = 0, p.bw do
					add(out, seen, x, y, z)
				end
			end
		end
	end
	-- 등 (조종석 뒤 혹)
	for z = p.front + 3, p.back - 2 do
		add(out, seen, 0, 1, z)
	end
	return out
end

local function makeNose(p: Params, kind: string): { Cell }
	local out, seen = {}, {}
	if kind == "A" then -- 기본: 고르게 좁아짐
		for i = 1, p.nose do
			local w = math.max(0, p.bw - math.floor(i * (p.bw + 1) / (p.nose + 1)))
			local h = math.max(1, p.bh - math.floor(i * p.bh / (p.nose + 1)))
			for y = 0, -(h - 1), -1 do
				for x = 0, w do
					add(out, seen, x, y, p.front - i)
				end
			end
		end
	elseif kind == "B" then -- 뾰족: 더 길고 가늘다
		local len = p.nose + 3
		for i = 1, len do
			local w = math.max(0, p.bw - 1 - math.floor(i * p.bw / len))
			local h = math.max(1, p.bh - 1 - math.floor(i * p.bh / len))
			for y = 0, -(h - 1), -1 do
				for x = 0, w do
					add(out, seen, x, y, p.front - i)
				end
			end
		end
	else -- 넓적: 짧고 넓다
		local len = math.max(2, p.nose - 2)
		for i = 1, len do
			local w = p.bw + 1 - math.floor((i - 1) / 2)
			for y = 0, -math.max(0, p.bh - 2), -1 do
				for x = 0, w do
					add(out, seen, x, y, p.front - i)
				end
			end
		end
	end
	return out
end

local function makeWing(p: Params, kind: string): { Cell }
	local out, seen = {}, {}
	for i = 1, p.span do
		local x = p.bw + i
		local t = (i - 1) / math.max(p.span - 1, 1) -- 뿌리 0 → 끝 1
		local z1, z2
		if kind == "A" then -- 곧은 날개: 끝만 조금 좁아짐
			z1 = p.wingZ
			z2 = p.wingZ + p.chord - 1 - math.floor(t * 2)
		elseif kind == "B" then -- 젖힌 날개: 끝으로 갈수록 뒤로
			local shift = math.floor(t * (p.chord - 1) + 0.5)
			z1 = p.wingZ + shift
			z2 = z1 + p.chord - 2
		else -- 삼각 날개: 뿌리가 넓고 끝이 뾰족
			z2 = p.back - 1
			local len = math.max(1, math.floor((p.chord + 3) * (1 - t) + 0.5))
			z1 = z2 - len + 1
		end
		z1 = math.max(z1, p.front)
		z2 = math.min(z2, p.back)
		local thick = if t < 0.4 then p.wingT else 1
		for y = 0, -(thick - 1), -1 do
			for z = z1, z2 do
				add(out, seen, x, y, z)
			end
		end
	end
	return out
end

local function makeTail(p: Params, kind: string): { Cell }
	local out, seen = {}, {}
	local z1, z2 = p.back + 1, p.back + p.tail
	-- 꼬리 몸통 (점점 좁아짐)
	for z = z1, z2 do
		local i = z - z1
		local w = math.max(0, p.bw - 1 - math.floor(i * p.bw / p.tail))
		for x = 0, w do
			add(out, seen, x, 0, z)
		end
	end
	local finX = if kind == "B" then math.max(1, p.bw) else 0
	local finZ1 = z2 - math.max(1, math.floor(p.tail / 2))
	local finH = if kind == "B" then math.max(1, p.fin - 2) else p.fin -- 쌍꼬리는 두 개라 낮게
	for y = 1, finH do
		for z = finZ1 + math.floor((y - 1) / 2), z2 do
			add(out, seen, finX, y, z)
		end
	end
	local stabY = if kind == "C" then p.fin + 1 else 0
	local stabZ1 = z2 - math.max(1, math.floor(p.tail / 3))
	for x = 1, p.stab do
		local xx = if kind == "C" then x - 1 else p.bw - 1 + x
		for z = stabZ1 + math.floor(x / 3), z2 do
			add(out, seen, xx, stabY, z)
		end
	end
	return out
end

local function makeShape(p: Params): Shape
	local parts = { body = { A = makeBody(p) }, nose = {}, wing = {}, tail = {} }
	for _, v in { "A", "B", "C" } do
		parts.nose[v] = makeNose(p, v)
		parts.wing[v] = makeWing(p, v)
		parts.tail[v] = makeTail(p, v)
	end
	-- 무기: 날개 뿌리 아래에 앞뒤로 줄지어 (무기 칸 수만큼)
	local weapons = {}
	for i = 1, p.weapons do
		table.insert(weapons, { p.bw + 2 + (i - 1) // 2 * 2, -p.wingT, p.wingZ + 1 + ((i - 1) % 2) * 2 })
	end
	return {
		id = p.id,
		name = p.name,
		short = p.short,
		class = p.class,
		partOrder = { "body", "nose", "wing", "tail" },
		swappable = { "nose", "wing", "tail" },
		partNames = { body = "몸통", nose = "기수", wing = "날개", tail = "꼬리" },
		variantOrder = { "A", "B", "C" },
		variantNames = small_basic.variantNames,
		parts = parts,
		seat = { 0, 1, p.front + 1 },
		booster = { 0, -p.bh, p.back - p.bh + 1 },
		weapons = weapons,
		defaultColors = p.colors,
	}
end

local medium_basic = makeShape({
	id = "medium_basic", name = "중형 기본틀", short = "중형", class = "medium",
	bw = 1, bh = 2, front = -4, back = 4, nose = 3,
	span = 9, chord = 4, wingZ = -1, wingT = 1,
	tail = 4, fin = 3, stab = 3, weapons = 2,
	colors = { body = "#E04848", nose = "#F2F2F2", wing = "#2B2B30", tail = "#F2C230" },
})

local large_basic = makeShape({
	id = "large_basic", name = "대형 기본틀", short = "대형", class = "large",
	bw = 2, bh = 2, front = -6, back = 6, nose = 3,
	span = 9, chord = 5, wingZ = -2, wingT = 2,
	tail = 5, fin = 3, stab = 3, weapons = 3,
	colors = { body = "#2E9E5B", nose = "#F2F2F2", wing = "#F28C28", tail = "#2B2B30" },
})

local xlarge_basic = makeShape({
	id = "xlarge_basic", name = "초대형 기본틀", short = "초대형", class = "xlarge",
	bw = 2, bh = 3, front = -8, back = 8, nose = 4,
	span = 11, chord = 6, wingZ = -3, wingT = 2,
	tail = 6, fin = 5, stab = 5, weapons = 4,
	colors = { body = "#6A4FD9", nose = "#F2F2F2", wing = "#3DC6D9", tail = "#F2C230" },
})

local byId: { [string]: Shape } = {
	small_basic = small_basic, small_ext = small_ext, small_free = small_free,
	medium_basic = medium_basic, large_basic = large_basic, xlarge_basic = xlarge_basic,
}
-- 에디터 [틀] 버튼 순서 (자유틀은 게임패스)
local order = { "small_basic", "small_ext", "medium_basic", "large_basic", "xlarge_basic", "small_free" }

-- 틀마다 가장 긴 길이(칸): 가로 폭·앞뒤 길이 중 큰 것 (모든 부위 모양 중 최대).
-- 에디터 전시 크기와 비행 카메라 거리를 맞출 때 쓴다. 자유틀은 상자 크기.
for _, shape in byId do
	local s = shape :: any
	if s.free then
		s.extent = math.max(s.box.x * 2 + 1, s.box.zMax - s.box.zMin + 1)
		continue
	end
	local maxX, minZ, maxZ = 0, math.huge, -math.huge
	for _, variants in s.parts do
		for _, cells in variants do
			for _, c in cells do
				maxX = math.max(maxX, math.abs(c[1]))
				minZ = math.min(minZ, c[3])
				maxZ = math.max(maxZ, c[3])
			end
		end
	end
	s.extent = math.max(maxX * 2 + 1, maxZ - minZ + 1)
end
local SMALL_EXTENT = (small_basic :: any).extent

-- 처음 받는 비행기 (저장된 비행기가 없을 때)
local DEFAULT_DESIGN = {
	frameId = "small_basic",
	parts = { nose = "A", wing = "A", tail = "A" },
	cells = {}, -- 비어 있으면 모두 기본 블록
	colors = {},
	weapon = "cannon",
}

return { byId = byId, order = order, DEFAULT_DESIGN = DEFAULT_DESIGN, SMALL_EXTENT = SMALL_EXTENT }
