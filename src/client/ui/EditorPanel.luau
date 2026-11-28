--!strict
-- 허브 에디터 화면 (내 조립 자리 근처에 서 있을 때만 보임).
--   아래: 도구 [한 칸] [부위 채우기] [모양] [칸 색칠] [부위 색칠] [자동 채우기] [모두 빼기] + 블록 단축바(또는 색 목록)
--   오른쪽: 속도·튼튼함·화력·채굴력 막대, 무기 고르기, 설계 1·2·3, [부위 교체] [시험 비행]
-- 화면은 그리기만 하고, 누르면 EditorController 에 알린다. 디자인은 8단계에서 다듬는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local BlockInfo = require(ReplicatedStorage.Shared.Island.BlockInfo)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local Widgets = require(script.Parent.components.Widgets)

local Editor = Config.Editor

local EditorPanel = {}
EditorPanel.ModeChosen = Signal.new() -- (mode: "cell" | "fill" | "shape" | "paintCell" | "paint")
EditorPanel.BlockChosen = Signal.new() -- (blockId: number) 0 = 빼기
EditorPanel.ColorChosen = Signal.new() -- (hex: string) "" = 원래 색(칸 색칠만)
EditorPanel.Action = Signal.new() -- (name: "auto" | "clear" | "parts" | "fly") 또는 ("weapon", id) / ("slot", n)

local GRAY = Color3.fromRGB(80, 88, 105)
local DARK = Color3.fromRGB(32, 42, 62)
local GREEN = Color3.fromRGB(70, 180, 90)
local RED = Color3.fromRGB(220, 80, 80)

local gui: ScreenGui
local scale: UIScale
local hotbar: ScrollingFrame
local modeButtons: { [string]: TextButton } = {}
local weaponButtons: { [string]: TextButton } = {}
local slotButtons: { TextButton } = {}
local partsButton: TextButton
local frameRow: Frame
local frameButtons: { [string]: TextButton } = {}
local flyButton: TextButton
local heavyLabel: TextLabel
local toastLabel: TextLabel
local bars: { [string]: any } = {}

local mode = "cell"
local selectedBlock = 0
local selectedColor = Editor.PALETTE[1]
local selectedShape = "wedge"
local inventory: { { id: number, count: number } } = {}

local function button(parent: Instance, text: string, color: Color3, size: UDim2, pos: UDim2?): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	if pos then
		b.Position = pos
	end
	b.BackgroundColor3 = color
	b.Font = Widgets.FONT
	b.TextSize = 15
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	Widgets.corner(b, 8)
	return b
end

local function hlist(parent: Instance, padding: number): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.Padding = UDim.new(0, padding)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Parent = parent
	return l
end

local function stroke(obj: GuiObject, on: boolean)
	local s = obj:FindFirstChildOfClass("UIStroke")
	if on then
		if not s then
			s = Instance.new("UIStroke")
			s.Color = Widgets.GOLD
			s.Thickness = 3
			s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
			s.Parent = obj
		end
	elseif s then
		s:Destroy()
	end
end

-- 단축바 다시 그리기 (블록 모드: 빼기 + 가진 블록 / 색칠 모드: 색 목록)
local function renderHotbar()
	for _, c in hotbar:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
	if mode == "shape" then
		for i, def in Config.BlockShapes.list do
			local b = button(hotbar, def.name, DARK, UDim2.fromOffset(72, 56))
			b.LayoutOrder = i
			b.TextSize = 13
			b.TextWrapped = true
			stroke(b, def.id == selectedShape)
			b.Activated:Connect(function()
				selectedShape = def.id
				renderHotbar()
			end)
		end
		return
	end
	if mode == "paint" or mode == "paintCell" then
		if selectedColor == "" and mode == "paint" then
			selectedColor = Editor.PALETTE[1]
		end
		if mode == "paintCell" then
			-- 칸 색을 지우고 부위 색으로 되돌리는 칸
			local reset = button(hotbar, "원래 색", GRAY, UDim2.fromOffset(64, 56))
			reset.LayoutOrder = 0
			reset.TextSize = 13
			stroke(reset, selectedColor == "")
			reset.Activated:Connect(function()
				selectedColor = ""
				EditorPanel.ColorChosen:Fire("")
				renderHotbar()
			end)
		end
		for i, hex in Editor.PALETTE do
			local b = button(hotbar, "", Color3.fromHex(hex), UDim2.fromOffset(56, 56))
			b.LayoutOrder = i
			stroke(b, hex == selectedColor)
			b.Activated:Connect(function()
				selectedColor = hex
				EditorPanel.ColorChosen:Fire(hex)
				renderHotbar()
			end)
		end
		return
	end

	local erase = button(hotbar, "빼기", RED, UDim2.fromOffset(64, 64))
	erase.LayoutOrder = 0
	erase.TextSize = 16
	stroke(erase, selectedBlock == 0)
	erase.Activated:Connect(function()
		selectedBlock = 0
		EditorPanel.BlockChosen:Fire(0)
		renderHotbar()
	end)

	if #inventory == 0 then
		local l = Widgets.label(hotbar, "창고에 블록이 없어요. 섬에서 캐서 격납고에 맡기면 여기 생겨요", UDim2.fromOffset(420, 64), UDim2.new(), 14)
		l.LayoutOrder = 1
		l.TextWrapped = true
		return
	end
	for i, item in inventory do
		local info = BlockInfo.byId[item.id]
		local b = button(hotbar, "", DARK, UDim2.fromOffset(64, 64))
		b.LayoutOrder = i
		stroke(b, item.id == selectedBlock)
		local sw = Instance.new("Frame")
		sw.Size = UDim2.fromOffset(28, 28)
		sw.Position = UDim2.new(0.5, -14, 0, 5)
		sw.BackgroundColor3 = if info then info.color else GRAY
		sw.Parent = b
		Widgets.corner(sw, 5)
		local name = Widgets.label(b, if info then info.name else tostring(item.id), UDim2.new(1, -4, 0, 14), UDim2.fromOffset(2, 34), 11)
		name.TextXAlignment = Enum.TextXAlignment.Center
		name.TextScaled = true
		local count = Widgets.label(b, `x{item.count}`, UDim2.new(1, -4, 0, 14), UDim2.fromOffset(2, 48), 12)
		count.TextXAlignment = Enum.TextXAlignment.Center
		count.TextColor3 = Color3.fromRGB(190, 210, 240)
		b.Activated:Connect(function()
			selectedBlock = item.id
			EditorPanel.BlockChosen:Fire(item.id)
			renderHotbar()
		end)
	end
end

local function renderModes()
	for m, b in modeButtons do
		b.BackgroundColor3 = if m == mode then Widgets.ACCENT else GRAY
	end
end

function EditorPanel.Mount(playerGui: Instance)
	gui = Instance.new("ScreenGui")
	gui.Name = "EditorPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 3
	gui.Enabled = false

	-- 작은 화면(폰)에서는 줄여서 보여 준다
	scale = Instance.new("UIScale")
	scale.Parent = gui
	local function fit()
		local cam = workspace.CurrentCamera
		local h = if cam then cam.ViewportSize.Y else 700
		scale.Scale = math.clamp(h / 720, 0.6, 1)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	-- 아래: 도구 줄 + 단축바
	local bottom = Instance.new("Frame")
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -10)
	bottom.Size = UDim2.fromOffset(640, 132)
	bottom.BackgroundColor3 = Widgets.PANEL
	bottom.BackgroundTransparency = 0.15
	bottom.Parent = gui
	Widgets.corner(bottom, 12)

	local tools = Instance.new("Frame")
	tools.Position = UDim2.fromOffset(10, 8)
	tools.Size = UDim2.new(1, -20, 0, 38)
	tools.BackgroundTransparency = 1
	tools.Parent = bottom
	hlist(tools, 6)
	local modes = { { "cell", "한 칸", 66 }, { "fill", "부위 채우기", 96 }, { "paintCell", "칸 색칠", 80 }, { "paint", "부위 색칠", 88 } }
	if Editor.FREE_SHAPES then -- 자유 에디터(나중에)에서만 칸 모양 고르기
		table.insert(modes, 3, { "shape", "모양", 58 })
	end
	for i, m in modes do
		local b = button(tools, m[2] :: string, GRAY, UDim2.fromOffset(m[3] :: number, 36))
		b.LayoutOrder = i
		modeButtons[m[1] :: string] = b
		b.Activated:Connect(function()
			mode = m[1] :: string
			renderModes()
			renderHotbar()
			EditorPanel.ModeChosen:Fire(mode)
		end)
	end
	local gap = Instance.new("Frame")
	gap.Size = UDim2.fromOffset(8, 36)
	gap.BackgroundTransparency = 1
	gap.LayoutOrder = 10
	gap.Parent = tools
	local auto = button(tools, "자동 채우기", GREEN, UDim2.fromOffset(96, 36))
	auto.LayoutOrder = 11
	auto.Activated:Connect(function()
		EditorPanel.Action:Fire("auto")
	end)
	local clear = button(tools, "모두 빼기", GRAY, UDim2.fromOffset(84, 36))
	clear.LayoutOrder = 12
	clear.Activated:Connect(function()
		EditorPanel.Action:Fire("clear")
	end)

	hotbar = Instance.new("ScrollingFrame")
	hotbar.Position = UDim2.fromOffset(10, 52)
	hotbar.Size = UDim2.new(1, -20, 0, 74)
	hotbar.BackgroundTransparency = 1
	hotbar.BorderSizePixel = 0
	hotbar.ScrollBarThickness = 4
	hotbar.ScrollingDirection = Enum.ScrollingDirection.X
	hotbar.CanvasSize = UDim2.new()
	hotbar.AutomaticCanvasSize = Enum.AutomaticSize.X
	hotbar.Parent = bottom
	hlist(hotbar, 6)

	toastLabel = Widgets.label(bottom, "", UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, -36), 20)
	toastLabel.TextXAlignment = Enum.TextXAlignment.Center
	toastLabel.TextStrokeTransparency = 0.3
	toastLabel.TextTransparency = 1

	-- 오른쪽: 성능 막대 + 무기 + 설계 칸 + 버튼
	local side = Instance.new("Frame")
	side.AnchorPoint = Vector2.new(1, 0.5)
	side.Position = UDim2.new(1, -10, 0.45, 0)
	side.Size = UDim2.fromOffset(220, 376)
	side.BackgroundColor3 = Widgets.PANEL
	side.BackgroundTransparency = 0.15
	side.Parent = gui
	Widgets.corner(side, 12)

	Widgets.label(side, "내 비행기", UDim2.new(1, -20, 0, 26), UDim2.fromOffset(12, 6), 18)
	local rows = { { "speed", "속도", Color3.fromRGB(90, 200, 255) }, { "hp", "튼튼함", Color3.fromRGB(110, 210, 110) }, { "fire", "화력", Color3.fromRGB(255, 120, 90) }, { "mine", "채굴력", Widgets.GOLD } }
	for i, r in rows do
		local y = 34 + (i - 1) * 36
		Widgets.label(side, r[2], UDim2.fromOffset(80, 16), UDim2.fromOffset(12, y), 13)
		local value = Widgets.label(side, "", UDim2.fromOffset(120, 16), UDim2.fromOffset(88, y), 13)
		value.TextXAlignment = Enum.TextXAlignment.Right
		local bar = Widgets.bar(side, UDim2.fromOffset(196, 10), UDim2.fromOffset(12, y + 19), r[3])
		bars[r[1]] = { bar = bar, value = value }
	end

	heavyLabel = Widgets.label(side, "부스터 힘이 부족해요 (무거워서 느려요)", UDim2.new(1, -20, 0, 16), UDim2.fromOffset(12, 178), 12)
	heavyLabel.TextColor3 = Color3.fromRGB(255, 140, 120)
	heavyLabel.Visible = false

	local wrow = Instance.new("Frame")
	wrow.Position = UDim2.fromOffset(12, 198)
	wrow.Size = UDim2.new(1, -24, 0, 30)
	wrow.BackgroundTransparency = 1
	wrow.Parent = side
	hlist(wrow, 4)
	for i, id in { "cannon", "missile", "laser" } do
		local b = button(wrow, (Config.Weapons :: any)[id].name, GRAY, UDim2.fromOffset(62, 28))
		b.TextSize = 13
		b.LayoutOrder = i
		weaponButtons[id] = b
		b.Activated:Connect(function()
			EditorPanel.Action:Fire("weapon", id)
		end)
	end

	local frow = Instance.new("Frame")
	frow.Position = UDim2.fromOffset(12, 234)
	frow.Size = UDim2.new(1, -24, 0, 30)
	frow.BackgroundTransparency = 1
	frow.Parent = side
	hlist(frow, 4)
	local fl = Widgets.label(frow, "틀", UDim2.fromOffset(24, 28), UDim2.new(), 14)
	fl.LayoutOrder = 0
	frameRow = frow

	local srow = Instance.new("Frame")
	srow.Position = UDim2.fromOffset(12, 268)
	srow.Size = UDim2.new(1, -24, 0, 30)
	srow.BackgroundTransparency = 1
	srow.Parent = side
	hlist(srow, 4)
	local sl = Widgets.label(srow, "설계", UDim2.fromOffset(40, 28), UDim2.new(), 14)
	sl.LayoutOrder = 0
	for i = 1, Editor.SLOTS do
		local b = button(srow, tostring(i), GRAY, UDim2.fromOffset(44, 28))
		b.LayoutOrder = i
		slotButtons[i] = b
		b.Activated:Connect(function()
			EditorPanel.Action:Fire("slot", i)
		end)
	end

	partsButton = button(side, "부위 교체", Color3.fromRGB(120, 90, 200), UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 304))
	partsButton.Activated:Connect(function()
		EditorPanel.Action:Fire("parts")
	end)
	flyButton = button(side, "시험 비행", Widgets.ACCENT, UDim2.new(1, -24, 0, 30), UDim2.fromOffset(12, 338))
	flyButton.Activated:Connect(function()
		EditorPanel.Action:Fire("fly")
	end)

	renderModes()
	gui.Parent = playerGui
end

function EditorPanel.Show()
	gui.Enabled = true
end

function EditorPanel.Hide()
	gui.Enabled = false
end

function EditorPanel.IsShown(): boolean
	return gui.Enabled
end

function EditorPanel.GetMode(): string
	return mode
end

function EditorPanel.GetBlock(): number
	return selectedBlock
end

function EditorPanel.GetShape(): string
	return selectedShape
end

function EditorPanel.GetColor(): string
	return selectedColor
end

-- 서버 상태로 다시 그리기
function EditorPanel.SetState(state: any)
	inventory = state.inventory
	-- 고른 블록이 다 떨어졌으면 그대로 두되(빼기 아님), 처음 열 때는 가장 좋은 블록을 고른다
	if selectedBlock == -1 then
		selectedBlock = if #inventory > 0 then inventory[1].id else 0
	end
	for id, b in weaponButtons do
		b.BackgroundColor3 = if state.design.weapon == id then Widgets.ACCENT else GRAY
	end
	for i, b in slotButtons do
		b.BackgroundColor3 = if state.slot == i then Widgets.ACCENT else GRAY
	end
	-- 틀 버튼 (기본틀·확장틀). 처음 받을 때 만든다
	for i, f in state.frames or {} do
		local b = frameButtons[f.id]
		if not b then
			b = button(frameRow, f.short, GRAY, UDim2.fromOffset(74, 28))
			b.TextSize = 13
			b.LayoutOrder = i
			frameButtons[f.id] = b
			b.Activated:Connect(function()
				EditorPanel.Action:Fire("frame", f.id)
			end)
		end
		b.Text = if f.unlocked then f.short else `{f.short} Lv{f.level}`
		b.BackgroundColor3 = if state.design.frameId == f.id then Widgets.ACCENT else GRAY
	end
	if state.level < Editor.PARTS_LEVEL then
		partsButton.Text = `부위 교체 (레벨 {Editor.PARTS_LEVEL})`
		partsButton.BackgroundColor3 = GRAY
	else
		partsButton.Text = "부위 교체"
		partsButton.BackgroundColor3 = Color3.fromRGB(120, 90, 200)
	end
	renderHotbar()
end

-- 처음 열릴 때 가장 좋은 블록을 고르게 한다
function EditorPanel.ResetSelection()
	selectedBlock = -1
end

local deltaIds: { [string]: number } = {}

local function fmt(key: string, v: number): string
	if key == "mine" then
		return string.format("%.1f", v)
	end
	return tostring(math.floor(v + 0.5))
end

-- 막대와 숫자. prev 가 있으면 바뀐 만큼 +/- 를 잠깐 보여 준다
function EditorPanel.SetStats(stats: any, ratios: any, prev: any?)
	local values = { speed = stats.maxSpeed, hp = stats.hp, fire = stats.firepower, mine = stats.minePower }
	local before = if prev then { speed = prev.maxSpeed, hp = prev.hp, fire = prev.firepower, mine = prev.minePower } else nil
	for key, row in bars do
		row.bar.set(ratios[key])
		local text = fmt(key, values[key])
		if before then
			local d = values[key] - before[key]
			if math.abs(d) >= (if key == "mine" then 0.05 else 0.5) then
				deltaIds[key] = (deltaIds[key] or 0) + 1
				local id = deltaIds[key]
				local sign = if d > 0 then "+" else ""
				row.value.Text = `{text}  ({sign}{fmt(key, d)})`
				row.value.TextColor3 = if d > 0 then Color3.fromRGB(120, 230, 120) else Color3.fromRGB(255, 120, 110)
				task.delay(1.5, function()
					if deltaIds[key] == id then
						row.value.Text = text
						row.value.TextColor3 = Color3.new(1, 1, 1)
					end
				end)
				continue
			end
		end
		row.value.Text = text
	end
	heavyLabel.Visible = stats.heavy
end

function EditorPanel.SetFlying(flying: boolean)
	flyButton.Text = if flying then "내리기" else "시험 비행"
end

local toastId = 0
function EditorPanel.Toast(text: string, warn: boolean?)
	toastId += 1
	local id = toastId
	toastLabel.Text = text
	toastLabel.TextColor3 = if warn then Color3.fromRGB(255, 120, 110) else Widgets.GOLD
	toastLabel.TextTransparency = 0
	task.delay(2.5, function()
		if id == toastId then
			TweenService:Create(toastLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
	end)
end

return EditorPanel
