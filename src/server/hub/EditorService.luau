--!strict
-- 허브 에디터 (4단계): 플레이어마다 조립 자리를 하나 주고, 그 위에 내 비행기를 크게 전시한다.
-- 캐릭터로 걸어 다니며 칸을 누르면 클라이언트가 요청을 보내고, 서버가 창고 블록을 확인한 뒤 바꾼다.
--   1단계(처음부터): 칸 채우기·빼기, 부위 채우기, 자동 채우기, 모두 빼기, 부위 색, 무기 고르기, 설계 칸 3개
--   2단계(레벨 5): 키오스크에서 기수·날개·꼬리 모양 바꾸기
-- 규칙은 Shared/PlaneEdit 에 있고, 클라이언트 미리보기도 같은 규칙을 쓴다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local PlaneBuilder = require(ReplicatedStorage.Shared.PlaneBuilder)
local PlaneEdit = require(ReplicatedStorage.Shared.PlaneEdit)

local Editor = Config.Editor
local Blocks = Config.Blocks
local Shapes = Config.FrameShapes

local EditorService = {}

local DataService: any

type Pad = {
	index: number,
	model: Model,
	center: Vector3,
	sign: TextLabel,
	prompt: ProximityPrompt,
	display: Model?,
	owner: Player?,
}

local pads: { Pad } = {}
local padOf: { [Player]: Pad } = {}
local lastEdit: { [Player]: number } = {}

local WEAPONS = { cannon = true, missile = true, laser = true }
local PALETTE: { [string]: boolean } = {}
for _, hex in Editor.PALETTE do
	PALETTE[hex] = true
end

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- 자리 i 의 가운데 (바닥 높이)
function EditorService.PadCenter(i: number): Vector3
	local col = (i - 1) % Editor.PAD_COLUMNS
	local row = (i - 1) // Editor.PAD_COLUMNS
	return Editor.PAD_ORIGIN + Vector3.new(col * Editor.PAD_GAP, 0, row * Editor.PAD_GAP)
end

local function makePad(i: number, folder: Folder): Pad
	local center = EditorService.PadCenter(i)
	local size = Editor.PAD_SIZE
	local model = Instance.new("Model")
	model.Name = "Pad_" .. i
	model:SetAttribute("PadIndex", i)

	local base = part("Base", Vector3.new(size, 0.4, size), CFrame.new(center + Vector3.new(0, 0.2, 0)), Color3.fromRGB(70, 76, 88), Enum.Material.Concrete, model)
	-- 테두리 선 (자리 구분)
	for _, e in { { Vector3.new(size, 0.1, 0.6), Vector3.new(0, 0, size / 2 - 0.3) }, { Vector3.new(size, 0.1, 0.6), Vector3.new(0, 0, -size / 2 + 0.3) }, { Vector3.new(0.6, 0.1, size), Vector3.new(size / 2 - 0.3, 0, 0) }, { Vector3.new(0.6, 0.1, size), Vector3.new(-size / 2 + 0.3, 0, 0) } } do
		local line = part("Line", e[1], CFrame.new(center + Vector3.new(0, 0.45, 0) + e[2]), Color3.fromRGB(255, 205, 70), Enum.Material.SmoothPlastic, model)
		line.CanCollide = false
	end

	-- 이름표: 자리 뒤쪽 위에 뜬다
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, 16, size / 2 - 2)
	att.Parent = base
	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(260, 40)
	bb.MaxDistance = 160
	bb.Adornee = att
	bb.AlwaysOnTop = false
	bb.Parent = base
	local sign = Instance.new("TextLabel")
	sign.Size = UDim2.fromScale(1, 1)
	sign.BackgroundTransparency = 1
	sign.Font = Enum.Font.GothamBold
	sign.TextScaled = true
	sign.TextColor3 = Color3.new(1, 1, 1)
	sign.TextStrokeTransparency = 0.4
	sign.Text = "빈 조립 자리"
	sign.Parent = bb

	-- 키오스크 (부위 교체): 자리 앞쪽 오른편
	local kiosk = part("Kiosk", Vector3.new(2.4, 4.4, 1.2), CFrame.new(center + Vector3.new(size / 2 - 4, 2.6, -size / 2 + 3)), Color3.fromRGB(40, 46, 60), Enum.Material.Metal, model)
	local screen = part("Screen", Vector3.new(2, 1.6, 0.2), kiosk.CFrame * CFrame.new(0, 1, -0.65), Color3.fromRGB(80, 170, 255), Enum.Material.Neon, model)
	screen.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PartsPrompt"
	prompt.ActionText = "부위 바꾸기"
	prompt.ObjectText = "부위 교체"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false -- 주인 화면에서만 켠다 (클라이언트가 자기 자리 것만 켬)
	prompt.Parent = kiosk

	model.Parent = folder
	return { index = i, model = model, center = center, sign = sign, prompt = prompt, display = nil, owner = nil }
end

-- 저장 데이터에 설계 칸 3개를 맞춰 둔다 (없으면 기본 비행기)
local function ensureDesigns(data: any)
	if type(data.planes) ~= "table" then
		data.planes = {}
	end
	for i = 1, Editor.SLOTS do
		local d = data.planes[i]
		data.planes[i] = if type(d) == "table" then PlaneBuilder.sanitize(d) else PlaneEdit.newDesign()
	end
	if type(data.activePlane) ~= "number" or data.activePlane < 1 or data.activePlane > Editor.SLOTS then
		data.activePlane = 1
	end
	data.activePlane = math.floor(data.activePlane)
end

local function activeDesign(data: any): any
	return data.planes[data.activePlane]
end

local function rebuild(player: Player)
	local pad = padOf[player]
	local data = DataService:Get(player)
	if not pad or not data then
		return
	end
	if pad.display then
		pad.display:Destroy()
		pad.display = nil
	end
	local design = activeDesign(data)
	local cell = Config.Flight.CELL_SIZE * Editor.DISPLAY_SCALE
	local model = PlaneBuilder.build(design, { cellSize = cell, display = true })
	model.Name = "Display"
	model:SetAttribute("OwnerId", player.UserId)
	local lift = -(PlaneBuilder.bottomY(design) - 0.5) * cell + 0.4
	model:PivotTo(CFrame.new(pad.center + Vector3.new(0, lift, 0)))
	model.Parent = pad.model
	pad.display = model
end

-- 클라이언트에 보낼 에디터 상태
local function snapshot(data: any)
	local inv = {}
	for key, n in data.inventory do
		local id = tonumber(key)
		if id and n > 0 and Blocks.byId[id] then
			table.insert(inv, { id = id, count = n })
		end
	end
	table.sort(inv, function(a, b)
		return PlaneEdit.quality(a.id) > PlaneEdit.quality(b.id)
	end)
	return {
		design = activeDesign(data),
		slot = data.activePlane,
		slots = Editor.SLOTS,
		inventory = inv,
		level = data.level,
	}
end

function EditorService:Push(player: Player)
	local data = DataService:Get(player)
	if data then
		ensureDesigns(data)
		Net.event("EditorState"):FireClient(player, snapshot(data))
	end
end

local function validPart(design: any, name: any): boolean
	if type(name) ~= "string" then
		return false
	end
	return table.find(Shapes.byId[design.frameId].partOrder, name) ~= nil
end

local function blockArg(v: any): number?
	if typeof(v) ~= "number" or v % 1 ~= 0 then
		return nil
	end
	if v == 0 or Blocks.byId[v] then
		return v
	end
	return nil
end

-- 편집 요청 하나 처리. 돌려줌: 문구, 경고인지 (문구 nil 이면 조용히 성공)
local function apply(player: Player, data: any, op: any): (boolean, string?, boolean?)
	local design = activeDesign(data)
	local inv = data.inventory
	local kind = op.op

	if kind == "cell" then
		local block = blockArg(op.block)
		if type(op.key) ~= "string" or block == nil then
			return false
		end
		local ok, why = PlaneEdit.setCell(design, inv, op.key, block)
		if not ok and why == "blocks" then
			return false, "블록이 모자라요 (양쪽 칸은 2개 필요)", true
		end
		return ok
	elseif kind == "fill" then
		local block = blockArg(op.block)
		if not validPart(design, op.part) or block == nil then
			return false
		end
		local changed, short = PlaneEdit.fillPart(design, inv, op.part, block)
		if short > 0 then
			return changed > 0, `블록이 모자라 {short}칸은 못 채웠어요`, true
		end
		return changed > 0
	elseif kind == "auto" then
		local n = PlaneEdit.autoFill(design, inv)
		if n == 0 then
			return true, "넣을 좋은 블록이 없어요. 섬에서 캐 오세요!", true
		end
		return true, `가진 블록 중 좋은 것으로 {n}칸 채웠어요`
	elseif kind == "clear" then
		local n = PlaneEdit.clearAll(design, inv)
		return true, if n > 0 then `블록 {n}개를 창고로 돌려보냈어요` else nil
	elseif kind == "color" then
		if not validPart(design, op.part) or type(op.hex) ~= "string" or not PALETTE[op.hex] then
			return false
		end
		PlaneEdit.paintPart(design, op.part, op.hex)
		return true
	elseif kind == "paintCell" then
		-- hex 가 "" 이면 원래(부위) 색으로
		if type(op.key) ~= "string" or type(op.hex) ~= "string" or (op.hex ~= "" and not PALETTE[op.hex]) then
			return false
		end
		return PlaneEdit.paintCell(design, op.key, if op.hex == "" then nil else op.hex)
	elseif kind == "weapon" then
		if type(op.id) ~= "string" or not WEAPONS[op.id] then
			return false
		end
		design.weapon = op.id
		return true, `무기: {(Config.Weapons :: any)[op.id].name}`
	elseif kind == "parts" then
		if data.level < Editor.PARTS_LEVEL then
			return false, `부위 교체는 레벨 {Editor.PARTS_LEVEL}에 열려요`, true
		end
		if type(op.parts) ~= "table" then
			return false
		end
		local want = {}
		for _, name in Shapes.byId[design.frameId].swappable do
			local v = op.parts[name]
			if type(v) == "string" then
				want[name] = v
			end
		end
		local r = PlaneEdit.setParts(design, inv, want)
		if r.defaults > 0 then
			return true, `부위를 바꿨어요! 모자란 {r.defaults}칸은 기본 블록이에요`
		end
		return true, "부위를 바꿨어요!"
	elseif kind == "slot" then
		local i = op.index
		if typeof(i) ~= "number" or i % 1 ~= 0 or i < 1 or i > Editor.SLOTS then
			return false
		end
		if i == data.activePlane then
			return true
		end
		local missing = PlaneEdit.switchSlot(design, data.planes[i], inv)
		data.activePlane = i
		if missing > 0 then
			return true, `설계 {i}번으로 바꿨어요. 블록이 모자란 {missing}칸은 기본 블록`, true
		end
		return true, `설계 {i}번으로 바꿨어요`
	end
	return false
end

local function onEdit(player: Player, op: any)
	local data = DataService:Get(player)
	if not data or type(op) ~= "table" then
		return nil
	end
	ensureDesigns(data)
	local now = os.clock()
	if now - (lastEdit[player] or 0) < Editor.EDIT_COOLDOWN then
		return { ok = false, state = snapshot(data) }
	end
	lastEdit[player] = now
	local ok, msg, warn = apply(player, data, op)
	if ok then
		rebuild(player)
	end
	return { ok = ok, msg = msg, warn = warn, state = snapshot(data) }
end

local function assign(player: Player)
	if padOf[player] then
		return
	end
	for _, pad in pads do
		if not pad.owner then
			pad.owner = player
			padOf[player] = pad
			pad.sign.Text = player.DisplayName .. "의 비행기"
			pad.model:SetAttribute("OwnerId", player.UserId)
			player:SetAttribute("EditorPad", pad.index)
			rebuild(player)
			return
		end
	end
	warn(`[EditorService] 조립 자리가 모두 찼어요 ({#pads}개). Config/Editor 의 PAD_ROWS 를 늘리세요`)
end

local function release(player: Player)
	local pad = padOf[player]
	padOf[player] = nil
	lastEdit[player] = nil
	if not pad then
		return
	end
	pad.owner = nil
	pad.sign.Text = "빈 조립 자리"
	pad.model:SetAttribute("OwnerId", nil)
	if pad.display then
		pad.display:Destroy()
		pad.display = nil
	end
end

function EditorService:Init(services)
	DataService = services.DataService
end

function EditorService:Start()
	local folder = Instance.new("Folder")
	folder.Name = "EditorPads"
	folder.Parent = workspace
	for i = 1, Editor.PAD_COLUMNS * Editor.PAD_ROWS do
		table.insert(pads, makePad(i, folder))
	end

	DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		ensureDesigns(data)
		assign(player)
	end)
	for _, player in Players:GetPlayers() do
		if DataService:Get(player) then
			ensureDesigns(DataService:Get(player))
			assign(player)
		end
	end
	Players.PlayerRemoving:Connect(release)

	Net.func("GetEditor").OnServerInvoke = function(player: Player)
		local data = DataService:Get(player)
		if not data then
			return nil
		end
		ensureDesigns(data)
		return snapshot(data)
	end
	Net.func("EditPlane").OnServerInvoke = onEdit
end

return EditorService
