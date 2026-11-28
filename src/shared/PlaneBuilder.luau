--!strict
-- 설계 데이터 → 비행기 모델 조립. 서버가 부르고, 허브 에디터의 전시 모델·미리보기도 이걸로 만든다.
--
-- 설계 데이터 모양 (저장 데이터의 planes[n]):
--   { frameId = "small_basic", parts = { nose = "A", wing = "A", tail = "A" },
--     cells = { ["nose:3"] = blockId }, colors = { body = "#RRGGBB", ... }, weapon = "cannon" }
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
export type Placed = { key: string, part: string, pos: Vector3, count: number }

local BLOCK_TINT = 0.3 -- 부위 색에 블록 고유색을 섞는 비율 (좋은 블록이 눈에 보이게)

local function vec(c: { number }): Vector3
	return Vector3.new(c[1], c[2], c[3])
end

local function shapeOf(frameId: string): any
	return Shapes.byId[frameId] or Shapes.byId[Shapes.DEFAULT_DESIGN.frameId]
end

-- 틀에 들어가는 모든 칸의 자리 목록 (대칭 복사 포함)
function PlaneBuilder.layout(frameId: string, parts: { [string]: string }?): { Placed }
	local shape = shapeOf(frameId)
	local out: { Placed } = {}
	for _, partName in shape.partOrder do
		local variants = shape.parts[partName]
		local variant = (parts and parts[partName]) or "A"
		local cells = variants[variant] or variants.A
		for i, c in cells do
			local key = partName .. ":" .. i
			local count = if c[1] ~= 0 then 2 else 1
			table.insert(out, { key = key, part = partName, pos = vec(c), count = count })
			if c[1] ~= 0 then
				table.insert(out, { key = key, part = partName, pos = Vector3.new(-c[1], c[2], c[3]), count = count })
			end
		end
	end
	return out
end

-- 칸 이름마다 하나씩 (대칭 쌍은 한 번만): { key, part, pos(오른쪽), count }.
-- 중요한 칸(가운데에 가까운 칸)이 먼저 오도록 정렬. 자동 채우기·부위 교체가 이 순서로 좋은 블록을 넣는다.
function PlaneBuilder.slots(frameId: string, parts: { [string]: string }?, onlyPart: string?): { Placed }
	local out: { Placed } = {}
	local seen: { [string]: boolean } = {}
	for _, p in PlaneBuilder.layout(frameId, parts) do
		if not seen[p.key] and (onlyPart == nil or p.part == onlyPart) then
			seen[p.key] = true
			table.insert(out, p)
		end
	end
	table.sort(out, function(a, b)
		local da, db = a.pos.Magnitude, b.pos.Magnitude
		if da ~= db then
			return da < db
		end
		return a.key < b.key
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
	local valid: { [string]: boolean } = {}
	for _, p in PlaneBuilder.layout(frameId, parts) do
		valid[p.key] = true
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
	return { frameId = frameId, parts = parts, cells = cells, colors = colors, weapon = weapon }
end

-- 블록 하나의 겉모습: 부위 색에 블록 고유색을 조금 섞고, 재질은 블록 것
function PlaneBuilder.blockLook(block: any, partHex: string): (Color3, Enum.Material)
	local look = Looks.byKey[block.key] or Looks.byFamily[block.family] or Looks.DEFAULT
	local color = Color3.fromHex(partHex):Lerp(look.color, BLOCK_TINT)
	return color, look.material
end

local function newPart(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
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

	for _, placed in PlaneBuilder.layout(design.frameId, design.parts) do
		local block = PlaneBuilder.blockAt(design, placed.key)
		local color, material = PlaneBuilder.blockLook(block, design.colors[placed.part])
		local p = newPart("C_" .. placed.key, Vector3.new(cell, cell, cell), CFrame.new(placed.pos * cell), color, material)
		p:SetAttribute("Cell", placed.key)
		p:SetAttribute("Part", placed.part)
		p:SetAttribute("BlockId", block.id)
		if display then
			p.CanCollide = true -- 위에 올라가 걸을 수 있게
			if PlaneBuilder.isDefault(design, placed.key) then
				p.Transparency = 0.45 -- 아직 기본 블록인 칸: 반투명
			end
		end
		p.Parent = model
		attach(p)
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
	local bpos = vec(shape.booster) * cell
	local booster = newPart(
		"Booster",
		Vector3.new(cell * 1.4, cell * 0.9, cell * 0.9),
		CFrame.new(bpos) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(70, 74, 84),
		Enum.Material.Metal
	)
	booster.Shape = Enum.PartType.Cylinder
	booster.Parent = model
	attach(booster)
	local flame = newPart(
		"Flame",
		Vector3.new(cell * 0.2, cell * 0.7, cell * 0.7),
		CFrame.new(bpos + Vector3.new(0, 0, cell * 0.75)) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(255, 150, 40),
		Enum.Material.Neon
	)
	flame.Shape = Enum.PartType.Cylinder
	flame.Parent = model
	attach(flame)

	-- 무기 자리 (6단계 전까지는 모양만). 무기 종류마다 색을 조금 다르게
	local gunColor = ({
		cannon = Color3.fromRGB(50, 52, 58),
		missile = Color3.fromRGB(150, 60, 50),
		laser = Color3.fromRGB(60, 120, 200),
	})[design.weapon] or Color3.fromRGB(50, 52, 58)
	for i, w in shape.weapons do
		for _, side in { 1, -1 } do
			if w[1] == 0 and side == -1 then
				continue
			end
			local pos = Vector3.new(w[1] * side, w[2], w[3]) * cell + Vector3.new(0, cell * 0.2, 0)
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
	for _, p in PlaneBuilder.layout(d.frameId, d.parts) do
		low = math.min(low, p.pos.Y)
	end
	return low
end

return PlaneBuilder
