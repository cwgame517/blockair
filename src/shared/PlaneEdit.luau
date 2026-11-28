--!strict
-- 에디터 규칙: 설계 데이터(design)와 창고(inventory)를 함께 바꾼다.
-- 서버가 진짜로 쓰고, 클라이언트는 부위 교체 미리보기에서 복사본에 써 본다 (같은 결과가 나오게).
--
-- 규칙
--   * 칸에 블록을 넣으면 창고에서 빠지고, 빼면 창고로 돌아온다. 블록은 절대 사라지지 않는다.
--   * 대칭 칸은 블록 2개가 든다 (가운데 줄 칸은 1개).
--   * cells 에 없는 칸은 기본 블록(공짜, 창고와 상관없음).
--   * inventory 는 { ["블록번호"] = 개수 } (저장 데이터와 같은 모양)
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlaneBuilder = require(ReplicatedStorage.Shared.PlaneBuilder)

local Blocks = Config.Blocks
local Editor = Config.Editor
local Shapes = Config.FrameShapes

local PlaneEdit = {}

local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in t do
		c[k] = deepCopy(v)
	end
	return c
end
PlaneEdit.copy = deepCopy

-- 블록 좋은 순서: 티어 → 단단함 → 채굴력
function PlaneEdit.quality(id: number): number
	local b = Blocks.byId[id]
	if not b then
		return -1
	end
	return b.tier * 10000 + b.hardness * 100 + b.minePower
end

function PlaneEdit.count(inv: any, id: number): number
	return inv[tostring(id)] or 0
end

local function give(inv: any, id: number, n: number)
	if n <= 0 then
		return
	end
	local key = tostring(id)
	inv[key] = (inv[key] or 0) + n
end

local function take(inv: any, id: number, n: number): boolean
	local key = tostring(id)
	local have = inv[key] or 0
	if have < n then
		return false
	end
	local left = have - n
	inv[key] = if left > 0 then left else nil
	return true
end

-- 새 설계 (기본 비행기)
function PlaneEdit.newDesign(): any
	return PlaneBuilder.sanitize(deepCopy(Shapes.DEFAULT_DESIGN))
end

local function slotCount(design: any, key: string): number?
	for _, s in PlaneBuilder.slots(design) do
		if s.key == key then
			return s.count
		end
	end
	return nil
end

-- 칸 하나 바꾸기. blockId 0 = 빼기(기본 블록으로). 실패 이유: "cell" | "blocks"
function PlaneEdit.setCell(design: any, inv: any, key: string, blockId: number): (boolean, string?)
	local count = slotCount(design, key)
	if not count then
		return false, "cell"
	end
	local old = design.cells[key]
	if old == blockId or (old == nil and blockId == 0) then
		return true, nil
	end
	if blockId ~= 0 then
		if not Blocks.byId[blockId] then
			return false, "blocks"
		end
		if not take(inv, blockId, count) then
			return false, "blocks"
		end
	end
	if old then
		give(inv, old, count)
	end
	design.cells[key] = if blockId ~= 0 then blockId else nil
	return true, nil
end

-- 부위 하나를 같은 블록으로 채우기 (중요한 칸부터). blockId 0 = 부위 비우기.
-- 돌려줌: 바뀐 칸 수, 블록이 모자라 못 채운 칸 수
function PlaneEdit.fillPart(design: any, inv: any, part: string, blockId: number): (number, number)
	local changed, short = 0, 0
	for _, s in PlaneBuilder.slots(design, part) do
		if design.cells[s.key] == blockId or (blockId == 0 and design.cells[s.key] == nil) then
			continue
		end
		local ok = PlaneEdit.setCell(design, inv, s.key, blockId)
		if ok then
			changed += 1
		else
			short += 1
		end
	end
	return changed, short
end

-- 모든 칸을 비워 블록을 창고로 돌려보내기. 돌려준 블록 수
function PlaneEdit.clearAll(design: any, inv: any): number
	local n = 0
	for _, s in PlaneBuilder.slots(design) do
		local id = design.cells[s.key]
		if id then
			give(inv, id, s.count)
			n += s.count
		end
	end
	design.cells = {}
	return n
end

-- 후보 블록 목록 (좋은 순). first 에 든 블록 번호는 티어가 낮아도 후보에 넣고, firstFirst 면 맨 앞에 둔다.
-- 그 밖에는 창고의 다른 블록(최소 티어 이상)
local function candidates(inv: any, first: { [number]: boolean }?, firstFirst: boolean): { number }
	local list: { number } = {}
	local prio: { [number]: number } = {}
	if first then
		for id in first do
			if Blocks.byId[id] and not prio[id] then
				prio[id] = if firstFirst then 1 else 0
				table.insert(list, id)
			end
		end
	end
	for key, n in inv do
		local id = tonumber(key)
		local b = id and Blocks.byId[id]
		if id and b and n > 0 and not prio[id] and b.tier >= Editor.AUTO_MIN_TIER then
			prio[id] = 0
			table.insert(list, id)
		end
	end
	table.sort(list, function(x, y)
		if prio[x] ~= prio[y] then
			return prio[x] > prio[y]
		end
		return PlaneEdit.quality(x) > PlaneEdit.quality(y)
	end)
	return list
end

-- 빈 칸(기본 블록 칸)들을 후보 블록으로 채운다. 중요한 칸에 좋은 블록. 채운 칸 수
local function fillEmpty(design: any, inv: any, slots: { any }, first: { [number]: boolean }?, firstFirst: boolean): number
	local list = candidates(inv, first, firstFirst)
	local filled = 0
	for _, s in slots do
		if design.cells[s.key] then
			continue
		end
		for _, id in list do
			if take(inv, id, s.count) then
				design.cells[s.key] = id
				filled += 1
				break
			end
		end
	end
	return filled
end

-- 자동 채우기: 지금 블록을 모두 돌려받고, 가진 블록 중 좋은 것부터 중요한 칸에 넣는다.
-- (1티어 블록은 기본 블록과 비슷해서 쓰지 않음. 다만 이미 비행기에 넣어 둔 블록은 티어가 낮아도 다시 씀)
function PlaneEdit.autoFill(design: any, inv: any): number
	local mine: { [number]: boolean } = {}
	for _, id in design.cells do
		mine[id] = true
	end
	PlaneEdit.clearAll(design, inv)
	return fillEmpty(design, inv, PlaneBuilder.slots(design), mine, false)
end

export type SwapResult = { returned: number, refilled: number, defaults: number }

-- 부위 모양 바꾸기 (부위 교체). newParts = { nose = "B", ... } 바꿀 부위만 있어도 됨.
-- 바뀌는 부위의 블록은 창고로 돌아가고, 새 부위는 방금 돌아온 블록을 먼저, 모자라면 창고의 다른 블록으로 자동 채움.
-- 그래도 모자란 칸은 기본 블록. 색은 부위에 저장돼 있어 그대로.
function PlaneEdit.setParts(design: any, inv: any, newParts: { [string]: string }): SwapResult
	local shape = Shapes.byId[design.frameId]
	local result = { returned = 0, refilled = 0, defaults = 0 }
	for _, part in shape.swappable do
		local want = newParts[part]
		if type(want) ~= "string" or not shape.parts[part][want] or design.parts[part] == want then
			continue
		end
		local back: { [number]: boolean } = {}
		for _, s in PlaneBuilder.slots(design, part) do
			local id = design.cells[s.key]
			if id then
				give(inv, id, s.count)
				result.returned += s.count
				back[id] = true
				design.cells[s.key] = nil
			end
			if design.cellColors then
				design.cellColors[s.key] = nil -- 한 칸 색·모양은 칸이 없어지니 지움 (부위 색은 그대로)
			end
			if design.cellShapes then
				design.cellShapes[s.key] = nil
			end
		end
		design.parts[part] = want
		local slots = PlaneBuilder.slots(design, part)
		fillEmpty(design, inv, slots, back, true)
		for _, s in slots do
			if design.cells[s.key] then
				result.refilled += s.count
			else
				result.defaults += 1
			end
		end
	end
	return result
end

-- 설계 칸 바꾸기: 지금 비행기(cur)의 블록을 창고로 돌려보내고(cur 의 배치는 기억으로 남김),
-- 고른 칸(target)의 배치대로 창고에서 블록을 가져와 채운다. 모자란 칸 수를 돌려준다.
function PlaneEdit.switchSlot(cur: any, target: any, inv: any): number
	for _, s in PlaneBuilder.slots(cur) do
		local id = cur.cells[s.key]
		if id then
			give(inv, id, s.count)
		end
	end
	local wanted = target.cells
	target.cells = {}
	local missing = 0
	for _, s in PlaneBuilder.slots(target) do
		local id = wanted[s.key]
		if id then
			if take(inv, id, s.count) then
				target.cells[s.key] = id
			else
				missing += 1
			end
		end
	end
	return missing
end

-- 부위 색칠: 부위 색을 바꾸고, 그 부위에서 한 칸씩 칠한 색은 지운다 (부위 전체가 같은 색이 되게)
function PlaneEdit.paintPart(design: any, part: string, hex: string)
	design.colors[part] = hex
	if design.cellColors then
		for _, s in PlaneBuilder.slots(design, part) do
			design.cellColors[s.key] = nil
		end
	end
end

-- 한 칸 색칠 (대칭 칸도 같이). hex 가 nil 이면 부위 색으로 되돌림
function PlaneEdit.paintCell(design: any, key: string, hex: string?): boolean
	local ok = false
	for _, s in PlaneBuilder.slots(design) do
		if s.key == key then
			ok = true
		end
	end
	if not ok then
		return false
	end
	design.cellColors = design.cellColors or {}
	design.cellColors[key] = hex
	return true
end

-- 틀 바꾸기 (기본틀 ↔ 확장 기본틀 등). 블록은 모두 창고로 돌아갔다가, 새 틀에 같은 블록을 먼저 다시 채운다.
-- 부위 색은 그대로, 부위 모양은 새 틀의 첫 모양, 한 칸 색·모양은 지운다. 돌려줌: 기본 블록으로 남은 칸 수
function PlaneEdit.setFrame(design: any, inv: any, frameId: string): number
	local shape = Shapes.byId[frameId]
	if not shape or design.frameId == frameId then
		return 0
	end
	if (shape :: any).free then
		PlaneEdit.toFree(design, inv, frameId)
		return 0
	end
	local back: { [number]: boolean } = {}
	for _, id in design.cells do
		back[id] = true
	end
	PlaneEdit.clearAll(design, inv)
	design.free = nil
	design.frameId = frameId
	local parts = {}
	for _, partName in shape.partOrder do
		parts[partName] = shape.variantOrder[1] or "A"
	end
	design.parts = parts
	design.cellColors = {}
	design.cellShapes = {}
	local slots = PlaneBuilder.slots(design)
	if next(back) ~= nil then
		fillEmpty(design, inv, slots, back, true)
	end
	local defaults = 0
	for _, s in slots do
		if not design.cells[s.key] then
			defaults += 1
		end
	end
	return defaults
end

-- 거울(좌우 반대) 칸의 회전 번호
function PlaneEdit.mirrorRot(rot: number): number
	return (4 - rot % 4) % 4 + (if rot >= 4 then 4 else 0)
end

-- 자유틀로 바꾸기: 지금 비행기 모양을 블록·모양·색 그대로 자유틀 칸으로 옮긴다 (블록 수도 그대로).
-- 칸 수가 등급 상한을 넘으면 바깥쪽 칸부터 빼서 창고로 돌려보낸다.
function PlaneEdit.toFree(design: any, inv: any, frameId: string)
	local shape = Shapes.byId[frameId] :: any
	local frame = Config.Frames.byId[shape.class]
	local cells: { { pos: Vector3, block: number?, shape: string, hex: string } } = {}
	for _, p in PlaneBuilder.layout(design) do
		local id, rot = PlaneBuilder.cellShape(design, p.key, p.shape)
		if p.mirror then
			rot = PlaneEdit.mirrorRot(rot)
		end
		local block = design.cells[p.key]
		table.insert(cells, {
			pos = p.pos,
			block = block,
			shape = `{id}:{rot}`,
			hex = PlaneBuilder.cellHex(design, p.key, p.part),
		})
	end
	table.sort(cells, function(a, b)
		return a.pos.Magnitude < b.pos.Magnitude
	end)
	local coreKey = PlaneBuilder.freeKey(Vector3.new(shape.core[1], shape.core[2], shape.core[3]))
	local free: { [string]: boolean } = { [coreKey] = true }
	local newCells, newShapes, newColors = {}, {}, {}
	local count = 1
	for _, c in cells do
		local key = PlaneBuilder.freeKey(c.pos)
		local keep = PlaneBuilder.inBox(shape, c.pos) and (free[key] or count < frame.cells)
		if keep then
			if not free[key] then
				free[key] = true
				count += 1
			end
			if c.block then
				newCells[key] = c.block
			end
			if c.shape ~= "cube:0" then
				newShapes[key] = c.shape
			end
			newColors[key] = c.hex
		elseif c.block then
			give(inv, c.block, 1)
		end
	end
	design.frameId = frameId
	design.parts = { body = "A" }
	design.free = free
	design.cells = newCells
	design.cellShapes = newShapes
	design.cellColors = newColors
	design.colors = { body = design.colors and design.colors.body or shape.defaultColors.body }
end

local NEIGHBORS = {
	Vector3.new(1, 0, 0), Vector3.new(-1, 0, 0), Vector3.new(0, 1, 0),
	Vector3.new(0, -1, 0), Vector3.new(0, 0, 1), Vector3.new(0, 0, -1),
}

-- 자유틀에 블록 하나 붙이기. blockId 0 = 기본 블록(공짜). 실패 이유:
-- "free"(자유틀 아님) | "box"(상자 밖) | "taken"(이미 있음) | "touch"(붙어 있는 칸 없음) | "max"(칸 수 상한) | "blocks"(블록 모자람)
function PlaneEdit.addCell(design: any, inv: any, pos: Vector3, blockId: number, shapeStr: string?): (boolean, string?)
	local shape = Shapes.byId[design.frameId] :: any
	if not shape or not shape.free then
		return false, "free"
	end
	if not PlaneBuilder.inBox(shape, pos) then
		return false, "box"
	end
	local key = PlaneBuilder.freeKey(pos)
	design.free = design.free or {}
	if design.free[key] then
		return false, "taken"
	end
	local touching = false
	for _, d in NEIGHBORS do
		if design.free[PlaneBuilder.freeKey(pos + d)] then
			touching = true
		end
	end
	if not touching then
		return false, "touch"
	end
	local n = 0
	for _ in design.free do
		n += 1
	end
	if n >= Config.Frames.byId[shape.class].cells then
		return false, "max"
	end
	if blockId ~= 0 then
		if not Blocks.byId[blockId] or not take(inv, blockId, 1) then
			return false, "blocks"
		end
		design.cells[key] = blockId
	end
	design.free[key] = true
	if shapeStr and PlaneBuilder.parseShape(shapeStr) and shapeStr ~= "cube:0" then
		design.cellShapes = design.cellShapes or {}
		design.cellShapes[key] = shapeStr
	end
	return true, nil
end

-- 자유틀에서 블록 하나 떼기 (블록은 창고로). 실패 이유: "free" | "none" | "core"(조종석 아래) | "min"(최소 칸 수) | "split"(떨어진 조각이 생김)
function PlaneEdit.removeCell(design: any, inv: any, key: string): (boolean, string?)
	local shape = Shapes.byId[design.frameId] :: any
	if not shape or not shape.free then
		return false, "free"
	end
	if not design.free or not design.free[key] then
		return false, "none"
	end
	local coreKey = PlaneBuilder.freeKey(Vector3.new(shape.core[1], shape.core[2], shape.core[3]))
	if key == coreKey then
		return false, "core"
	end
	local n = 0
	for _ in design.free do
		n += 1
	end
	if n <= Config.Editor.FREE_MIN_CELLS then
		return false, "min"
	end
	-- 떼고 나서도 모든 칸이 조종석 칸과 이어져 있는지
	local seen: { [string]: boolean } = { [coreKey] = true }
	local stack = { coreKey }
	local reached = 1
	while #stack > 0 do
		local cur = table.remove(stack) :: string
		local pos = PlaneBuilder.parseFreeKey(cur) :: Vector3
		for _, d in NEIGHBORS do
			local k = PlaneBuilder.freeKey(pos + d)
			if k ~= key and design.free[k] and not seen[k] then
				seen[k] = true
				reached += 1
				table.insert(stack, k)
			end
		end
	end
	if reached < n - 1 then
		return false, "split"
	end
	local id = design.cells[key]
	if id then
		give(inv, id, 1)
	end
	design.free[key] = nil
	design.cells[key] = nil
	if design.cellShapes then
		design.cellShapes[key] = nil
	end
	if design.cellColors then
		design.cellColors[key] = nil
	end
	return true, nil
end

-- 칸 모양 바꾸기 (대칭 칸도 같이). shape = "모양:회전". 성능은 그대로
function PlaneEdit.setShape(design: any, key: string, shape: string): boolean
	if not PlaneBuilder.parseShape(shape) then
		return false
	end
	local ok = false
	for _, s in PlaneBuilder.slots(design) do
		if s.key == key then
			ok = true
		end
	end
	if not ok then
		return false
	end
	design.cellShapes = design.cellShapes or {}
	-- 틀에 정해진 처음 모양과 같으면 기억할 필요 없음
	design.cellShapes[key] = if PlaneBuilder.frameShapeOf(design, key) == shape then nil else shape
	return true
end

-- 설계에 실제로 들어 있는 블록 수
function PlaneEdit.placedBlocks(design: any): number
	local n = 0
	for _, s in PlaneBuilder.slots(design) do
		if design.cells[s.key] then
			n += s.count
		end
	end
	return n
end

return PlaneEdit
