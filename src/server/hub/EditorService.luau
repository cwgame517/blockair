--!strict
-- 허브 에디터 (4단계): 플레이어마다 조립 자리를 하나 주고, 그 위에 내 비행기를 크게 전시한다.
-- 캐릭터로 걸어 다니며 칸을 누르면 클라이언트가 요청을 보내고, 서버가 창고 블록을 확인한 뒤 바꾼다.
--   1단계(처음부터): 칸 채우기·빼기, 부위 채우기, 자동 채우기, 모두 빼기, 부위 색, 무기 고르기, 설계 칸 3개
--   2단계(레벨 5): 키오스크에서 기수·날개·꼬리 모양 바꾸기
-- 규칙은 Shared/PlaneEdit 에 있고, 클라이언트 미리보기도 같은 규칙을 쓴다.
local MarketplaceService = game:GetService("MarketplaceService")
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
local ProgressService: any

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
local hasPass: { [Player]: boolean } = {} -- 자유틀 게임패스 (Studio 는 /freepass 로 켜고 끔)

local function checkPass(player: Player)
	local id = Editor.FREE_PASS_ID
	if id <= 0 then
		return
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, id)
	end)
	if ok and owns then
		hasPass[player] = true
	end
end

-- 자유틀 칸의 좌우 반대 칸 이름 (가운데 줄이면 nil)
local function mirrorKey(key: string): string?
	local pos = PlaneBuilder.parseFreeKey(key)
	if not pos or pos.X == 0 then
		return nil
	end
	return PlaneBuilder.freeKey(Vector3.new(-pos.X, pos.Y, pos.Z))
end

local FREE_WHY = {
	box = "상자 밖이라 못 붙여요",
	taken = "이미 블록이 있어요",
	touch = "다른 블록에 붙여야 해요",
	max = "칸 수가 가득 찼어요",
	blocks = "블록이 모자라요",
	core = "조종석 아래 블록은 뗄 수 없어요",
	min = `블록은 최소 {Editor.FREE_MIN_CELLS}개 있어야 해요`,
	split = "떼면 비행기가 두 조각이 나요",
}

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
	local cell = PlaneBuilder.displayCellSize(design.frameId)
	local model = PlaneBuilder.build(design, { cellSize = cell, display = true })
	model.Name = "Display"
	model:SetAttribute("OwnerId", player.UserId)
	local lift = -(PlaneBuilder.bottomY(design) - 0.5) * cell + 0.4
	model:PivotTo(CFrame.new(pad.center + Vector3.new(0, lift, 0)))
	model.Parent = pad.model
	pad.display = model
end

-- 고를 수 있는 틀 목록 (등급 해금 레벨이 되면 기본틀·확장 기본틀 모두 무료)
local function frameList(player: Player, data: any)
	local out = {}
	for _, id in Shapes.order do
		local shape = Shapes.byId[id]
		local need = Config.Frames.byId[shape.class].unlockLevel
		local pass = (shape :: any).free == true
		table.insert(out, {
			id = id,
			short = shape.short,
			unlocked = data.level >= need and (not pass or hasPass[player] == true),
			level = need,
			pass = pass,
		})
	end
	return out
end

-- 클라이언트에 보낼 에디터 상태
local function snapshot(player: Player, data: any)
	local inv = {}
	for key, n in data.inventory do
		local id = tonumber(key)
		if id and n > 0 and Blocks.byId[id] then
			table.insert(inv, { id = id, count = n })
		end
	end
	-- 레벨이 모자란 블록은 잠금(lock = 쓸 수 있는 레벨)으로 보내고 맨 뒤로
	for _, item in inv do
		local need = Blocks.byId[item.id].unlockLevel
		if need > data.level then
			item.lock = need
		end
	end
	table.sort(inv, function(a, b)
		if (a.lock ~= nil) ~= (b.lock ~= nil) then
			return a.lock == nil
		end
		return PlaneEdit.quality(a.id) > PlaneEdit.quality(b.id)
	end)
	return {
		design = activeDesign(data),
		slot = data.activePlane,
		slots = Editor.SLOTS,
		inventory = inv,
		level = data.level,
		frames = frameList(player, data),
		freePass = hasPass[player] == true,
		passId = Editor.FREE_PASS_ID,
	}
end

function EditorService:Push(player: Player)
	local data = DataService:Get(player)
	if data then
		ensureDesigns(data)
		Net.event("EditorState"):FireClient(player, snapshot(player, data))
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
		local other = if ok and op.mirror == true and PlaneBuilder.isFree(design) then mirrorKey(op.key) else nil
		if other and design.free[other] then
			PlaneEdit.setCell(design, inv, other, block)
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
	elseif kind == "shape" then
		-- 칸 모양 직접 고르기는 자유 에디터(게임패스, 나중에) 전용
		if not (Editor.FREE_SHAPES or PlaneBuilder.isFree(design)) or type(op.key) ~= "string" or type(op.shape) ~= "string" then
			return false
		end
		local ok = PlaneEdit.setShape(design, op.key, op.shape)
		local other = if op.mirror == true then mirrorKey(op.key) else nil
		local id, rot = PlaneBuilder.parseShape(op.shape)
		if ok and other and design.free[other] and id and rot then
			PlaneEdit.setShape(design, other, `{id}:{PlaneEdit.mirrorRot(rot)}`)
		end
		return ok
	elseif kind == "add" then
		-- 자유틀: 블록 붙이기 (mirror 면 반대쪽에도)
		local p = op.pos
		local block = blockArg(op.block)
		if type(p) ~= "table" or block == nil then
			return false
		end
		local x, y, z = p[1], p[2], p[3]
		if typeof(x) ~= "number" or typeof(y) ~= "number" or typeof(z) ~= "number" then
			return false
		end
		local pos = Vector3.new(math.round(x), math.round(y), math.round(z))
		local shapeStr = if type(op.shape) == "string" then op.shape else nil
		local ok, why = PlaneEdit.addCell(design, inv, pos, block, shapeStr)
		if not ok then
			return false, FREE_WHY[why or ""], true
		end
		if op.mirror == true and pos.X ~= 0 then
			local mShape = nil
			local id, rot = PlaneBuilder.parseShape(shapeStr)
			if id and rot then
				mShape = `{id}:{PlaneEdit.mirrorRot(rot)}`
			end
			local ok2, why2 = PlaneEdit.addCell(design, inv, Vector3.new(-pos.X, pos.Y, pos.Z), block, mShape)
			if not ok2 and why2 == "blocks" then
				return true, "반대쪽은 블록이 모자라 못 붙였어요", true
			end
		end
		return true
	elseif kind == "remove" then
		if type(op.key) ~= "string" then
			return false
		end
		local ok, why = PlaneEdit.removeCell(design, inv, op.key)
		if not ok then
			return false, FREE_WHY[why or ""], true
		end
		local other = if op.mirror == true then mirrorKey(op.key) else nil
		if other and design.free[other] then
			PlaneEdit.removeCell(design, inv, other)
		end
		return true
	elseif kind == "frame" then
		local shape = type(op.id) == "string" and Shapes.byId[op.id]
		if not shape then
			return false
		end
		local need = Config.Frames.byId[shape.class].unlockLevel
		if data.level < need then
			return false, `{shape.name}은 레벨 {need}에 열려요`, true
		end
		if design.frameId == op.id then
			return true
		end
		if (shape :: any).free and not hasPass[player] then
			return false, "자유틀은 게임패스가 있어야 해요", true
		end
		local defaults = PlaneEdit.setFrame(design, inv, op.id)
		if (shape :: any).free then
			return true, "자유틀! 블록을 눌러 붙이고 떼고, 모양을 바꿔 보세요"
		end
		if defaults > 0 and PlaneEdit.placedBlocks(design) > 0 then
			return true, `{shape.name}으로 바꿨어요. 모자란 {defaults}칸은 기본 블록`
		end
		return true, `{shape.name}으로 바꿨어요`
	elseif kind == "paintCell" then
		-- hex 가 "" 이면 원래(부위) 색으로
		if type(op.key) ~= "string" or type(op.hex) ~= "string" or (op.hex ~= "" and not PALETTE[op.hex]) then
			return false
		end
		local hex = if op.hex == "" then nil else op.hex
		local ok = PlaneEdit.paintCell(design, op.key, hex)
		local other = if op.mirror == true and PlaneBuilder.isFree(design) then mirrorKey(op.key) else nil
		if ok and other and design.free[other] then
			PlaneEdit.paintCell(design, other, hex)
		end
		return ok
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
		return { ok = false, state = snapshot(player, data) }
	end
	lastEdit[player] = now
	-- 레벨별 해금: 레벨이 모자란 블록은 비행기에 못 넣는다 (캐서 팔 수는 있음)
	local block = if typeof(op.block) == "number" then Blocks.byId[op.block] else nil
	if block and block.unlockLevel > data.level then
		return { ok = false, msg = `{block.name}은 레벨 {block.unlockLevel}부터 쓸 수 있어요`, warn = true, state = snapshot(player, data) }
	end
	-- 편집하는 동안 창고에서 잠긴 블록을 빼 두었다가(자동 채우기·부위 교체가 쓰지 않게) 끝나면 되돌린다
	local locked: { [string]: number } = {}
	local usable: { [string]: number } = {}
	for key, n in data.inventory do
		local b = Blocks.byId[tonumber(key) or 0]
		if b and b.unlockLevel > data.level then
			locked[key] = n
		else
			usable[key] = n
		end
	end
	data.inventory = usable
	local okCall, ok, msg, isWarn = pcall(apply, player, data, op)
	for key, n in locked do
		usable[key] = (usable[key] or 0) + n
	end
	data.inventory = usable
	if not okCall then
		warn(`[EditorService] 편집 오류: {ok}`)
		ok, msg, isWarn = false, nil, nil
	end
	if ok then
		rebuild(player)
	end
	return { ok = ok, msg = msg, warn = isWarn, state = snapshot(player, data) }
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

-- Studio 테스트 명령 /freepass: 게임패스를 가진 것처럼 켜고 끄기
function EditorService:SetDevPass(player: Player, on: boolean)
	hasPass[player] = on or nil
	EditorService:Push(player)
end

function EditorService:HasPass(player: Player): boolean
	return hasPass[player] == true
end

function EditorService:Init(services)
	DataService = services.DataService
	ProgressService = services.ProgressService
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
	Players.PlayerRemoving:Connect(function(player)
		release(player)
		hasPass[player] = nil
	end)
	Players.PlayerAdded:Connect(checkPass)
	for _, player in Players:GetPlayers() do
		task.spawn(checkPass, player)
	end
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player: Player, passId: number, bought: boolean)
		if bought and passId == Editor.FREE_PASS_ID then
			hasPass[player] = true
			EditorService:Push(player)
			Net.event("Notify"):FireClient(player, "자유틀이 열렸어요!")
		end
	end)

	-- 레벨이 오르면 새로 열린 틀·블록이 에디터에 바로 보이게
	ProgressService.LeveledUp:Connect(function(player: Player)
		EditorService:Push(player)
	end)

	Net.func("GetEditor").OnServerInvoke = function(player: Player)
		local data = DataService:Get(player)
		if not data then
			return nil
		end
		ensureDesigns(data)
		return snapshot(player, data)
	end
	Net.func("EditPlane").OnServerInvoke = onEdit
end

return EditorService
