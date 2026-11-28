--!strict
-- 설계 데이터 → 비행기 모델 조립. 서버가 부르고, 허브 에디터의 전시 모델·미리보기도 이걸로 만든다.
--
-- 설계 데이터 모양 (저장 데이터의 planes[n]):
--   { frameId = "small_basic", parts = { nose = "A", wing = "A", tail = "A" },
--     cells = { ["nose:3"] = blockId }, colors = { body = "#RRGGBB", ... }, cellColors = { ["nose:3"] = "#RRGGBB" },
--     weapon = "cannon" }
--   colors 는 부위 색, cellColors 는 한 칸만 따로 칠한 색 (있으면 부위 색보다 먼저)
--   cellShapes = { ["nose:3"] = "wedge:2" } 에디터에서 바꾼 칸 모양 (없으면 틀에 정해진 모양)
--   cells 에 없는 칸은 기본 블록(Flight.DEFAULT_BLOCK). 대칭 쌍은 칸 이름 하나에 블록 2개.
--
-- 만들어지는 모델:
--   Plane (Model, PrimaryPart = Root)
--     Root   보이지 않는 중심 부품. 비행용 Drive(Attachment)·LinearVelocity·AlignOrientation 이 여기 붙는다
--     C_칸이름 블록 부품들 (모두 Root 에 용접, 무게 없음)
--     Seat   조종석 (아바타가 앉는 자리)
--     Booster, Weapon  모양만 있는 부품
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Flight = Config.Flight
local Blocks = Config.Blocks
local Shapes = Config.FrameShapes
local Looks = Config.BlockLooks

local PlaneBuilder = {}

-- key: 칸 이름 "부위:번호", count: 그 칸 이름이 차지하는 블록 수(대칭이면 2) — 같은 key 의 두 칸 모두 같은 값
-- shape: 틀에 정해진 칸 모양 "모양:회전" (없으면 사각형). mirror: 왼쪽 거울 칸인지
export type Placed = { key: string, part: string, pos: Vector3, count: number, shape: string?, mirror: boolean }

local BLOCK_TINT = 0.3 -- 부위 색에 블록 고유색을 섞는 비율 (좋은 블록이 눈에 보이게)

local function vec(c: { number }): Vector3
	return Vector3.new(c[1], c[2], c[3])
end

local function shapeOf(frameId: string): any
	return Shapes.byId[frameId] or Shapes.byId[Shapes.DEFAULT_DESIGN.frameId]
end

-- 자유틀 칸 이름 "x,y,z" → 좌표 (잘못되면 nil)
function PlaneBuilder.parseFreeKey(key: any): Vector3?
	if type(key) ~= "string" then
		return nil
	end
	local x, y, z = string.match(key, "^(-?%d+),(-?%d+),(-?%d+)$")
	if not x then
		return nil
	end
	return Vector3.new(tonumber(x) :: number, tonumber(y) :: number, tonumber(z) :: number)
end

function PlaneBuilder.freeKey(pos: Vector3): string
	return `{math.round(pos.X)},{math.round(pos.Y)},{math.round(pos.Z)}`
end

function PlaneBuilder.isFree(design: any): boolean
	local shape = Shapes.byId[design.frameId]
	return shape ~= nil and (shape :: any).free == true
end

-- 틀에 들어가는 모든 칸의 자리 목록 (대칭 복사 포함).
-- PlaneBuilder.layout(design) 처럼 설계를 통째로 줘도 된다 (자유틀은 설계의 free 칸을 읽어야 해서 이쪽을 쓴다).
function PlaneBuilder.layout(frameOrDesign: any, parts: { [string]: string }?): { Placed }
	local frameId = frameOrDesign
	local free = nil
	if type(frameOrDesign) == "table" then
		frameId = frameOrDesign.frameId
		parts = frameOrDesign.parts
		free = frameOrDesign.free
	end
	local shape = shapeOf(frameId)
	local out: { Placed } = {}
	if (shape :: any).free then
		local keys = {}
		for key in (if type(free) == "table" then free else {}) do
			if PlaneBuilder.parseFreeKey(key) then
				table.insert(keys, key)
			end
		end
		table.sort(keys)
		for _, key in keys do
			table.insert(out, { key = key, part = "body", pos = PlaneBuilder.parseFreeKey(key) :: Vector3, count = 1, shape = nil, mirror = false })
		end
		return out
	end
	for _, partName in shape.partOrder do
		local variants = shape.parts[partName]
		local variant = (parts and parts[partName]) or "A"
		local cells = variants[variant] or variants.A
		for i, c in cells do
			local key = partName .. ":" .. i
			local count = if c[1] ~= 0 then 2 else 1
			local cellShape = c[4]
			table.insert(out, { key = key, part = partName, pos = vec(c), count = count, shape = cellShape, mirror = false })
			if c[1] ~= 0 then
				table.insert(out, { key = key, part = partName, pos = Vector3.new(-c[1], c[2], c[3]), count = count, shape = cellShape, mirror = true })
			end
		end
	end
	return out
end

-- 칸 이름마다 하나씩 (대칭 쌍은 한 번만): { key, part, pos(오른쪽), count }.
-- 중요한 칸(가운데에 가까운 칸)이 먼저 오도록 정렬. 자동 채우기·부위 교체가 이 순서로 좋은 블록을 넣는다.
-- PlaneBuilder.slots(design, 부위?) 또는 예전처럼 (frameId, parts, 부위?)
function PlaneBuilder.slots(frameOrDesign: any, a: any?, b: string?): { Placed }
	local list: { Placed }
	local onlyPart: string?
	if type(frameOrDesign) == "table" then
		list = PlaneBuilder.layout(frameOrDesign)
		onlyPart = a
	else
		list = PlaneBuilder.layout(frameOrDesign, a)
		onlyPart = b
	end
	local out: { Placed } = {}
	local seen: { [string]: boolean } = {}
	for _, p in list do
		if not seen[p.key] and (onlyPart == nil or p.part == onlyPart) then
			seen[p.key] = true
			table.insert(out, p)
		end
	end
	table.sort(out, function(x, y)
		local dx, dy = x.pos.Magnitude, y.pos.Magnitude
		if dx ~= dy then
			return dx < dy
		end
		return x.key < y.key
	end)
	return out
end

-- 칸에 들어간 블록. 없거나 잘못된 값이면 기본 블록.
function PlaneBuilder.blockAt(design: any, key: string): any
	local cells = design.cells
	local id = cells and cells[key]
	local block = if type(id) == "number" then Blocks.byId[id] else nil
	return block or Blocks.byKey[Flight.DEFAULT_BLOCK]
end

-- 기본 블록인 칸인지 (에디터에서 반투명하게 보여 줌)
function PlaneBuilder.isDefault(design: any, key: string): boolean
	local id = design.cells and design.cells[key]
	return not (type(id) == "number" and Blocks.byId[id])
end

local function validHex(s: any): boolean
	return type(s) == "string" and string.match(s, "^#%x%x%x%x%x%x$") ~= nil
end

-- 자유틀 칸 목록 정리: 상자 안, 상한 이하, 조종석 아래 core 칸은 항상 있음
function PlaneBuilder.sanitizeFree(shape: any, raw: any): { [string]: boolean }
	local frame = Config.Frames.byId[shape.class]
	local coreKey = PlaneBuilder.freeKey(vec(shape.core))
	local out: { [string]: boolean } = { [coreKey] = true }
	local n = 1
	if type(raw) == "table" then
		local keys = {}
		for k in raw do
			table.insert(keys, k)
		end
		table.sort(keys, function(x, y)
			return tostring(x) < tostring(y)
		end)
		for _, k in keys do
			local pos = PlaneBuilder.parseFreeKey(k)
			if pos and not out[k] and n < frame.cells and PlaneBuilder.inBox(shape, pos) then
				out[k] = true
				n += 1
			end
		end
	end
	return out
end

function PlaneBuilder.inBox(shape: any, pos: Vector3): boolean
	local box = shape.box
	return math.abs(pos.X) <= box.x and pos.Y >= box.yMin and pos.Y <= box.yMax and pos.Z >= box.zMin and pos.Z <= box.zMax
end

-- 받은 설계 데이터를 믿을 수 있는 모양으로 정리한다 (새 표를 돌려줌, 원본은 그대로)
function PlaneBuilder.sanitize(design: any): any
	local d = if type(design) == "table" then design else {}
	local frameId = if type(d.frameId) == "string" and Shapes.byId[d.frameId] then d.frameId else Shapes.DEFAULT_DESIGN.frameId
	local shape = Shapes.byId[frameId]
	local parts = {}
	for partName, variants in shape.parts do
		local v = type(d.parts) == "table" and d.parts[partName]
		parts[partName] = if type(v) == "string" and variants[v] then v else "A"
	end
	local colors = {}
	for partName, hex in shape.defaultColors do
		local c = type(d.colors) == "table" and d.colors[partName]
		colors[partName] = if validHex(c) then c else hex
	end
	local free = nil
	if (shape :: any).free then
		free = PlaneBuilder.sanitizeFree(shape, d.free)
	end
	local valid: { [string]: boolean } = {}
	for _, p in PlaneBuilder.layout({ frameId = frameId, parts = parts, free = free }) do
		valid[p.key] = true
	end
	local cellColors = {}
	if type(d.cellColors) == "table" then
		for k, v in d.cellColors do
			if type(k) == "string" and valid[k] and validHex(v) then
				cellColors[k] = v
			end
		end
	end
	local cellShapes = {}
	if type(d.cellShapes) == "table" then
		for k, v in d.cellShapes do
			if type(k) == "string" and valid[k] and PlaneBuilder.parseShape(v) then
				cellShapes[k] = v
			end
		end
	end
	local cells = {}
	if type(d.cells) == "table" then
		for k, v in d.cells do
			if type(k) == "string" and valid[k] and type(v) == "number" and Blocks.byId[v] then
				cells[k] = v
			end
		end
	end
	local weapon = d.weapon
	if type(weapon) ~= "string" or weapon == "bomb" or not Config.Weapons[weapon] then
		weapon = Shapes.DEFAULT_DESIGN.weapon
	end
	return { frameId = frameId, parts = parts, cells = cells, colors = colors, cellColors = cellColors, cellShapes = cellShapes, weapon = weapon, free = free }
end

-- 블록 하나의 겉모습: 부위 색에 블록 고유색을 조금 섞고, 재질은 블록 것
function PlaneBuilder.blockLook(block: any, partHex: string): (Color3, Enum.Material)
	local look = Looks.byKey[block.key] or Looks.byFamily[block.family] or Looks.DEFAULT
	local color = Color3.fromHex(partHex):Lerp(look.color, BLOCK_TINT)
	return color, look.material
end

-- 칸의 색: 한 칸 색이 있으면 그것, 없으면 부위 색
function PlaneBuilder.cellHex(design: any, key: string, part: string): string
	local c = design.cellColors and design.cellColors[key]
	return if type(c) == "string" then c else design.colors[part]
end

-- "모양:회전" 문자열 → 모양, 회전 (잘못되면 nil)
function PlaneBuilder.parseShape(v: any): (string?, number?)
	if type(v) ~= "string" then
		return nil, nil
	end
	local id, r = string.match(v, "^(%a[%w]*):(%d)$")
	local rot = tonumber(r)
	if id and rot and Config.BlockShapes.byId[id] and rot < Config.BlockShapes.ROTATIONS then
		return id, rot
	end
	return nil, nil
end

-- 칸의 모양: 에디터에서 바꾼 모양(cellShapes)이 있으면 그것, 없으면 틀에 정해진 모양, 그것도 없으면 사각형
function PlaneBuilder.cellShape(design: any, key: string, frameDefault: string?): (string, number)
	local id, rot = PlaneBuilder.parseShape(design.cellShapes and design.cellShapes[key])
	if not id then
		id, rot = PlaneBuilder.parseShape(frameDefault)
	end
	return id or "cube", rot or 0
end

-- 칸 이름 → 틀에 정해진 처음 모양 ("모양:회전" 또는 nil)
function PlaneBuilder.frameShapeOf(design: any, key: string): string?
	for _, p in PlaneBuilder.layout(design) do
		if p.key == key then
			return p.shape
		end
	end
	return nil
end

-- 모양 하나를 이루는 조각들 (칸 가운데 기준, 회전 전). { size(칸 비율), offset(칸 비율), wedge }
type Piece = { size: Vector3, offset: Vector3, wedge: boolean }
local PIECES: { [string]: { Piece } } = {
	cube = { { size = Vector3.new(1, 1, 1), offset = Vector3.zero, wedge = false } },
	three4 = { { size = Vector3.new(1, 0.75, 1), offset = Vector3.new(0, -0.125, 0), wedge = false } },
	half = { { size = Vector3.new(1, 0.5, 1), offset = Vector3.new(0, -0.25, 0), wedge = false } },
	quarter = { { size = Vector3.new(1, 0.25, 1), offset = Vector3.new(0, -0.375, 0), wedge = false } },
	wedge = { { size = Vector3.new(1, 1, 1), offset = Vector3.zero, wedge = true } }, -- 비탈이 앞(-z)·위
	halfwedge = { { size = Vector3.new(1, 0.5, 1), offset = Vector3.new(0, -0.25, 0), wedge = true } },
	stairs = { -- 앞이 낮고 뒤가 높은 두 단
		{ size = Vector3.new(1, 0.5, 1), offset = Vector3.new(0, -0.25, 0), wedge = false },
		{ size = Vector3.new(1, 0.5, 0.5), offset = Vector3.new(0, 0.25, 0.25), wedge = false },
	},
	stick = { { size = Vector3.new(0.35, 0.35, 1), offset = Vector3.zero, wedge = false } }, -- 앞뒤로 누운 막대
}

-- 회전 번호 → 칸 회전. 왼쪽 거울 칸은 좌우로 뒤집는다.
local function shapeRotation(id: string, rot: number, mirror: boolean): CFrame
	local quarter = rot % 4
	local yaw = quarter * 90
	if mirror then
		yaw = -yaw
	end
	local cf = CFrame.Angles(0, math.rad(yaw), 0)
	if rot >= 4 then
		if id == "stick" then
			cf *= CFrame.Angles(math.pi / 2, 0, 0) -- 세운 막대
		else
			cf *= CFrame.Angles(0, 0, math.pi) -- 뒤집기
		end
	end
	return cf
end

local function newPart(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, className: string?): BasePart
	local p = Instance.new((className or "Part") :: any) :: BasePart
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.Massless = true
	return p
end

local function weld(root: BasePart, p: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = root
	w.Part1 = p
	w.Parent = p
end

-- 부스터 자리와 무기 자리(오른쪽만). 정해진 틀은 틀에 적힌 자리,
-- 자유틀은 블록 모양에 맞춰: 부스터 = 가운데 줄 가장 뒤 칸의 바로 뒤, 무기 = 가장 바깥(오른쪽) 칸의 바로 아래
function PlaneBuilder.attachPoints(design: any): (Vector3, { Vector3 })
	local shape = shapeOf(design.frameId)
	if not (shape :: any).free then
		local weapons = {}
		for _, w in shape.weapons do
			table.insert(weapons, vec(w))
		end
		return vec(shape.booster), weapons
	end
	local back: Vector3? = nil
	local outer: Vector3? = nil
	local occupied: { [string]: boolean } = {}
	for _, p in PlaneBuilder.layout(design) do
		occupied[p.key] = true
		if p.pos.X == 0 and (not back or p.pos.Z > back.Z or (p.pos.Z == back.Z and p.pos.Y < back.Y)) then
			back = p.pos
		end
		if p.pos.X >= 0 and (not outer or p.pos.X > outer.X or (p.pos.X == outer.X and p.pos.Y < outer.Y)) then
			outer = p.pos
		end
	end
	local core = vec(shape.core)
	local b = (back or core) + Vector3.new(0, 0, 1)
	local o = outer or core
	local w = o - Vector3.new(0, 1, 0)
	if o.X == 0 then
		w = Vector3.new(1, o.Y - 1, o.Z) -- 가운데 줄뿐이면 바로 옆 아래
	end
	local weapons = {}
	local frame = Config.Frames.byId[shape.class]
	for i = 1, frame.weaponSlots do
		table.insert(weapons, w + Vector3.new(0, 0, (i - 1) * 2))
	end
	return b, weapons
end

export type BuildOptions = {
	cellSize: number?, -- 칸 크기 (기본 Flight.CELL_SIZE)
	display: boolean?, -- true 면 허브 에디터 전시용: 고정(Anchored), 밟을 수 있음, 비행 장치 없음, 기본 칸은 반투명
}

-- 설계 데이터로 모델을 만든다. 모델은 원점에 앞(-z)을 보고 만들어진다. 놓을 곳은 PivotTo 로 옮길 것.
function PlaneBuilder.build(rawDesign: any, options: BuildOptions?): Model
	local design = PlaneBuilder.sanitize(rawDesign)
	local shape = Shapes.byId[design.frameId]
	local display = options ~= nil and options.display == true
	local cell = (options and options.cellSize) or Flight.CELL_SIZE

	local model = Instance.new("Model")
	model.Name = "Plane"

	local root = newPart("Root", Vector3.new(cell, cell, cell), CFrame.identity, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	root.Transparency = 1
	root.Massless = false
	root.CanQuery = false
	root.RootPriority = 127
	root.Anchored = display
	root.Parent = model
	model.PrimaryPart = root

	local function attach(p: BasePart)
		if display then
			p.Anchored = true
		else
			weld(root, p)
		end
	end

	for _, placed in PlaneBuilder.layout(design) do
		local block = PlaneBuilder.blockAt(design, placed.key)
		local color, material = PlaneBuilder.blockLook(block, PlaneBuilder.cellHex(design, placed.key, placed.part))
		local shapeId, rot = PlaneBuilder.cellShape(design, placed.key, placed.shape)
		local cellCf = CFrame.new(placed.pos * cell) * shapeRotation(shapeId, rot, placed.mirror)
		local default = display and PlaneBuilder.isDefault(design, placed.key)
		for i, piece in PIECES[shapeId] do
			local p = newPart(
				if i == 1 then "C_" .. placed.key else "C_" .. placed.key .. "_" .. i,
				piece.size * cell,
				cellCf * CFrame.new(piece.offset * cell),
				color,
				material,
				if piece.wedge then "WedgePart" else nil
			)
			p:SetAttribute("Cell", placed.key)
			p:SetAttribute("Part", placed.part)
			p:SetAttribute("BlockId", block.id)
			if display then
				p.CanCollide = true -- 위에 올라가 걸을 수 있게
				if default then
					p.Transparency = 0.45 -- 아직 기본 블록인 칸: 반투명
				end
			end
			p.Parent = model
			attach(p)
		end
	end

	-- 조종석: 칸 위에 얇게 얹는다 (전시용은 앉을 수 없는 평범한 부품)
	local seat: BasePart
	if display then
		seat = Instance.new("Part")
	else
		seat = Instance.new("Seat")
		seat.CanTouch = false -- 지나가던 사람이 앉지 않도록 (서버가 Sit 으로만 태움)
	end
	seat.Name = "Seat"
	seat.Size = Vector3.new(cell, 0.4, cell)
	seat.CFrame = CFrame.new(vec(shape.seat) * cell - Vector3.new(0, cell / 2 - 0.2, 0))
	seat.Color = Color3.fromRGB(40, 40, 48)
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.CanCollide = false
	seat.Massless = true
	seat.Parent = model
	attach(seat)

	-- 부스터: 꼬리 쪽 원통 + 빛나는 분사구
	local boosterCell, weaponCells = PlaneBuilder.attachPoints(design)
	local bpos = boosterCell * cell
	local booster = newPart(
		"Booster",
		Vector3.new(cell * 1.4, cell * 0.9, cell * 0.9),
		CFrame.new(bpos) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(70, 74, 84),
		Enum.Material.Metal
	) :: Part
	booster.Shape = Enum.PartType.Cylinder
	booster.Parent = model
	attach(booster)
	local flame = newPart(
		"Flame",
		Vector3.new(cell * 0.2, cell * 0.7, cell * 0.7),
		CFrame.new(bpos + Vector3.new(0, 0, cell * 0.75)) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(255, 150, 40),
		Enum.Material.Neon
	) :: Part
	flame.Shape = Enum.PartType.Cylinder
	flame.Parent = model
	attach(flame)

	-- 무기 자리 (6단계 전까지는 모양만). 무기 종류마다 색을 조금 다르게
	local gunColor = ({
		cannon = Color3.fromRGB(50, 52, 58),
		missile = Color3.fromRGB(150, 60, 50),
		laser = Color3.fromRGB(60, 120, 200),
	})[design.weapon] or Color3.fromRGB(50, 52, 58)
	for i, w in weaponCells do
		for _, side in { 1, -1 } do
			if w.X == 0 and side == -1 then
				continue
			end
			local pos = Vector3.new(w.X * side, w.Y, w.Z) * cell + Vector3.new(0, cell * 0.2, 0)
			local gun = newPart("Weapon_" .. i, Vector3.new(cell * 0.4, cell * 0.4, cell * 1.4), CFrame.new(pos), gunColor, Enum.Material.Metal)
			gun.Parent = model
			attach(gun)
		end
	end

	model:SetAttribute("FrameId", design.frameId)
	model:SetAttribute("Weapon", design.weapon)
	if display then
		return model
	end

	-- 비행용 구속(constraint). 조종하는 사람의 컴퓨터가 값을 바꾼다.
	local att = Instance.new("Attachment")
	att.Name = "Drive"
	att.Parent = root

	local lv = Instance.new("LinearVelocity")
	lv.Name = "Move"
	lv.Attachment0 = att
	lv.RelativeTo = Enum.ActuatorRelativeTo.World
	lv.VelocityConstraintMode = Enum.VelocityConstraintMode.Vector
	lv.ForceLimitsEnabled = false
	lv.VectorVelocity = Vector3.zero
	lv.Parent = root

	local ao = Instance.new("AlignOrientation")
	ao.Name = "Steer"
	ao.Mode = Enum.OrientationAlignmentMode.OneAttachment
	ao.Attachment0 = att
	ao.MaxTorque = math.huge
	ao.MaxAngularVelocity = math.huge
	ao.Responsiveness = Flight.STEER_RESPONSIVENESS
	ao.CFrame = CFrame.identity
	ao.Parent = root

	return model
end

-- 칸 좌표의 가장 낮은 y (전시할 때 바닥에 맞추려고)
function PlaneBuilder.bottomY(design: any): number
	local d = PlaneBuilder.sanitize(design)
	local low = math.huge
	for _, p in PlaneBuilder.layout(d) do
		low = math.min(low, p.pos.Y)
	end
	return low
end

return PlaneBuilder
