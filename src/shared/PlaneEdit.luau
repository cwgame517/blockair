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
	for _, s in PlaneBuilder.slots(design.frameId, design.parts) do
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
	for _, s in PlaneBuilder.slots(design.frameId, design.parts, part) do
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
	for _, s in PlaneBuilder.slots(design.frameId, design.parts) do
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
	return fillEmpty(design, inv, PlaneBuilder.slots(design.frameId, design.parts), mine, false)
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
		for _, s in PlaneBuilder.slots(design.frameId, design.parts, part) do
			local id = design.cells[s.key]
			if id then
				give(inv, id, s.count)
				result.returned += s.count
				back[id] = true
				design.cells[s.key] = nil
			end
			if design.cellColors then
				design.cellColors[s.key] = nil -- 한 칸 색은 칸이 없어지니 지움 (부위 색은 그대로)
			end
		end
		design.parts[part] = want
		local slots = PlaneBuilder.slots(design.frameId, design.parts, part)
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
	for _, s in PlaneBuilder.slots(cur.frameId, cur.parts) do
		local id = cur.cells[s.key]
		if id then
			give(inv, id, s.count)
		end
	end
	local wanted = target.cells
	target.cells = {}
	local missing = 0
	for _, s in PlaneBuilder.slots(target.frameId, target.parts) do
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
		for _, s in PlaneBuilder.slots(design.frameId, design.parts, part) do
			design.cellColors[s.key] = nil
		end
	end
end

-- 한 칸 색칠 (대칭 칸도 같이). hex 가 nil 이면 부위 색으로 되돌림
function PlaneEdit.paintCell(design: any, key: string, hex: string?): boolean
	local ok = false
	for _, s in PlaneBuilder.slots(design.frameId, design.parts) do
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

-- 설계에 실제로 들어 있는 블록 수
function PlaneEdit.placedBlocks(design: any): number
	local n = 0
	for _, s in PlaneBuilder.slots(design.frameId, design.parts) do
		if design.cells[s.key] then
			n += s.count
		end
	end
	return n
end

return PlaneEdit
