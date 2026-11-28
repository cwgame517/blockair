--!strict
-- 설계 데이터 → 비행기 모델 조립. 서버가 부르고, 4단계 에디터 미리보기에서도 쓴다.
--
-- 설계 데이터 모양 (저장 데이터의 planes[n]):
--   { frameId = "small_basic", parts = { nose = "A", wing = "A", tail = "A" },
--     cells = { ["칸번호"] = blockId }, colors = { body = "#RRGGBB", ... }, weapon = "cannon" }
--
-- 만들어지는 모델:
--   Plane (Model, PrimaryPart = Root)
--     Root   보이지 않는 중심 부품. 비행용 Drive(Attachment)·LinearVelocity·AlignOrientation 이 여기 붙는다
--     C_번호 블록 부품들 (모두 Root 에 용접, 무게 없음)
--     Seat   조종석 (아바타가 앉는 자리)
--     Booster, Weapon  모양만 있는 부품
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Flight = Config.Flight
local Blocks = Config.Blocks
local Shapes = Config.FrameShapes

local PlaneBuilder = {}

export type Placed = { index: number, part: string, pos: Vector3 }

local FAMILY_MATERIAL: { [string]: Enum.Material } = {
	["경량"] = Enum.Material.WoodPlanks,
	["구조"] = Enum.Material.Concrete,
	["장갑"] = Enum.Material.DiamondPlate,
	["특수"] = Enum.Material.Glass,
}

local function vec(c: { number }): Vector3
	return Vector3.new(c[1], c[2], c[3])
end

-- 틀에 들어가는 모든 칸의 자리 목록 (대칭 복사 포함)
function PlaneBuilder.layout(frameId: string, parts: { [string]: string }?): { Placed }
	local shape = Shapes.byId[frameId] or Shapes.byId[Shapes.DEFAULT_DESIGN.frameId]
	local out: { Placed } = {}
	local index = 0
	for _, partName in shape.partOrder do
		local variants = shape.parts[partName]
		local variant = (parts and parts[partName]) or "A"
		local cells = variants[variant] or variants.A
		for _, c in cells do
			index += 1
			table.insert(out, { index = index, part = partName, pos = vec(c) })
			if c[1] ~= 0 then
				table.insert(out, { index = index, part = partName, pos = Vector3.new(-c[1], c[2], c[3]) })
			end
		end
	end
	return out
end

-- 칸 번호에 들어간 블록. 없거나 잘못된 값이면 기본 블록.
function PlaneBuilder.blockAt(design: any, index: number): any
	local cells = design.cells
	local id = cells and (cells[tostring(index)] or cells[index])
	local block = if type(id) == "number" then Blocks.byId[id] else nil
	return block or Blocks.byKey[Flight.DEFAULT_BLOCK]
end

local function validHex(s: any): boolean
	return type(s) == "string" and string.match(s, "^#%x%x%x%x%x%x$") ~= nil
end

-- 받은 설계 데이터를 믿을 수 있는 모양으로 정리한다 (서버에서 사용)
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
	local cells = {}
	if type(d.cells) == "table" then
		for k, v in d.cells do
			if type(v) == "number" and Blocks.byId[v] then
				cells[tostring(k)] = v
			end
		end
	end
	local weapon = d.weapon
	if type(weapon) ~= "string" or weapon == "bomb" or not Config.Weapons[weapon] then
		weapon = Shapes.DEFAULT_DESIGN.weapon
	end
	return { frameId = frameId, parts = parts, cells = cells, colors = colors, weapon = weapon }
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

-- 설계 데이터로 모델을 만든다. 모델은 원점에 앞(-z)을 보고 만들어진다. 놓을 곳은 PivotTo 로 옮길 것.
function PlaneBuilder.build(rawDesign: any): Model
	local design = PlaneBuilder.sanitize(rawDesign)
	local shape = Shapes.byId[design.frameId]
	local cell = Flight.CELL_SIZE

	local model = Instance.new("Model")
	model.Name = "Plane"

	local root = newPart("Root", Vector3.new(cell, cell, cell), CFrame.identity, Color3.new(1, 1, 1), Enum.Material.SmoothPlastic)
	root.Transparency = 1
	root.Massless = false
	root.CanQuery = false
	root.RootPriority = 127
	root.Parent = model
	model.PrimaryPart = root

	for _, placed in PlaneBuilder.layout(design.frameId, design.parts) do
		local block = PlaneBuilder.blockAt(design, placed.index)
		local color = Color3.fromHex(design.colors[placed.part])
		local p = newPart(
			"C_" .. placed.index,
			Vector3.new(cell, cell, cell),
			CFrame.new(placed.pos * cell),
			color,
			FAMILY_MATERIAL[block.family] or Enum.Material.SmoothPlastic
		)
		p:SetAttribute("Cell", placed.index)
		p:SetAttribute("BlockId", block.id)
		p.Parent = model
		weld(root, p)
	end

	-- 조종석: 칸 위에 얇게 얹는다
	local seat = Instance.new("Seat")
	seat.Name = "Seat"
	seat.Size = Vector3.new(cell, 0.4, cell)
	seat.CFrame = CFrame.new(vec(shape.seat) * cell - Vector3.new(0, cell / 2 - 0.2, 0))
	seat.Color = Color3.fromRGB(40, 40, 48)
	seat.TopSurface = Enum.SurfaceType.Smooth
	seat.CanCollide = false
	seat.CanTouch = false -- 지나가던 사람이 앉지 않도록 (서버가 Sit 으로만 태움)
	seat.Massless = true
	seat.Parent = model
	weld(root, seat)

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
	weld(root, booster)
	local flame = newPart(
		"Flame",
		Vector3.new(cell * 0.2, cell * 0.7, cell * 0.7),
		CFrame.new(bpos + Vector3.new(0, 0, cell * 0.75)) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(255, 150, 40),
		Enum.Material.Neon
	)
	flame.Shape = Enum.PartType.Cylinder
	flame.Parent = model
	weld(root, flame)

	-- 무기 자리 (1단계는 모양만)
	for i, w in shape.weapons do
		for _, side in { 1, -1 } do
			if w[1] == 0 and side == -1 then
				continue
			end
			local pos = Vector3.new(w[1] * side, w[2], w[3]) * cell + Vector3.new(0, cell * 0.2, 0)
			local gun = newPart(
				"Weapon_" .. i,
				Vector3.new(cell * 0.4, cell * 0.4, cell * 1.4),
				CFrame.new(pos),
				Color3.fromRGB(50, 52, 58),
				Enum.Material.Metal
			)
			gun.Parent = model
			weld(root, gun)
		end
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

	model:SetAttribute("FrameId", design.frameId)
	model:SetAttribute("Weapon", design.weapon)
	return model
end

return PlaneBuilder
