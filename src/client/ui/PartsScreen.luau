--!strict
-- 부위 교체 화면 (에디터 2단계, 키오스크에서 열림).
--   아래 탭 [기수] [날개] [꼬리] [색칠]: 누르면 카메라가 그 부위로 날아가고, 그 부위만 또렷하게 보인다.
--   ◀ ▶ 로 모양을 넘기면 그 자리에서 바뀐 모습(미리보기)과 막대 변화가 보이고, [적용]을 눌러야 진짜로 바뀐다.
--   색칠 탭은 부위를 고르고 색을 누르면 바로 칠해진다.
-- 미리보기는 내 화면에서만 만드는 모델이고, 서버의 전시 모델은 그동안 내 화면에서만 숨긴다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local PlaneBuilder = require(ReplicatedStorage.Shared.PlaneBuilder)
local PlaneStats = require(ReplicatedStorage.Shared.PlaneStats)
local PlaneEdit = require(ReplicatedStorage.Shared.PlaneEdit)
local Widgets = require(script.Parent.components.Widgets)

local Editor = Config.Editor
local Shapes = Config.FrameShapes

local PartsScreen = {}

export type Context = {
	pad: Model, -- 내 조립 자리 (안에 서버가 만든 Display 모델)
	pivot: CFrame, -- 전시 모델이 놓인 자리
	cellSize: number,
	state: any,
	onApply: (parts: { [string]: string }) -> any?, -- 서버에 보내고 새 상태를 돌려줌
	onColor: (part: string, hex: string) -> any?,
	onClose: () -> (),
}

local GRAY = Color3.fromRGB(80, 88, 105)
local TABS = { "nose", "wing", "tail", "color" }
local CAMERA_VIEW: { [string]: { dir: Vector3, dist: number } } = {
	nose = { dir = Vector3.new(0.35, 0.55, -1), dist = 20 },
	wing = { dir = Vector3.new(1, 0.9, 0.15), dist = 24 },
	tail = { dir = Vector3.new(0.45, 0.6, 1), dist = 20 },
	color = { dir = Vector3.new(0.75, 0.8, -0.9), dist = 42 },
}

local gui: ScreenGui
local tabButtons: { [string]: TextButton } = {}
local variantRow: Frame
local variantLabel: TextLabel
local colorRow: Frame
local colorPartRow: Frame
local colorPartButtons: { [string]: TextButton } = {}
local infoLabel: TextLabel
local statLines: { [string]: TextLabel } = {}
local applyButton: TextButton
local toastLabel: TextLabel

local ctx: Context? = nil
local tab = "nose"
local colorPart = "body"
local pending: { [string]: string } = {}
local preview: Model? = nil
local hiddenConn: RBXScriptConnection? = nil
local busy = false

local function button(parent: Instance, text: string, color: Color3, size: UDim2, pos: UDim2?): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	if pos then
		b.Position = pos
	end
	b.BackgroundColor3 = color
	b.Font = Widgets.FONT
	b.TextSize = 16
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.AutoButtonColor = true
	b.Parent = parent
	Widgets.corner(b, 8)
	return b
end

local function hlist(parent: Instance, padding: number)
	local l = Instance.new("UIListLayout")
	l.FillDirection = Enum.FillDirection.Horizontal
	l.HorizontalAlignment = Enum.HorizontalAlignment.Center
	l.VerticalAlignment = Enum.VerticalAlignment.Center
	l.Padding = UDim.new(0, padding)
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.Parent = parent
end

local function toast(text: string, warn: boolean?)
	toastLabel.Text = text
	toastLabel.TextColor3 = if warn then Color3.fromRGB(255, 120, 110) else Widgets.GOLD
	toastLabel.TextTransparency = 0
	task.delay(2.5, function()
		if toastLabel.Text == text then
			TweenService:Create(toastLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
	end)
end

-- 서버 전시 모델을 내 화면에서만 숨기기/다시 보이기
local function setServerDisplayHidden(hidden: boolean)
	local c = ctx
	if not c then
		return
	end
	local display = c.pad:FindFirstChild("Display")
	if display then
		for _, d in display:GetDescendants() do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = if hidden then 1 else 0
			end
		end
	end
end

local function inventoryDict(state: any): { [string]: number }
	local inv = {}
	for _, item in state.inventory do
		inv[tostring(item.id)] = item.count
	end
	return inv
end

-- 지금 고른 모양으로 바꾸면 어떻게 되는지 (복사본에 미리 해 봄)
local function simulate(): (any, PlaneEdit.SwapResult)
	local c = ctx :: Context
	local design = PlaneEdit.copy(c.state.design)
	local inv = inventoryDict(c.state)
	local result = PlaneEdit.setParts(design, inv, pending)
	return design, result
end

local function focusCenter(model: Model, part: string?): Vector3
	local sum, n = Vector3.zero, 0
	for _, p in model:GetDescendants() do
		if p:IsA("BasePart") and p:GetAttribute("Cell") and (part == nil or p:GetAttribute("Part") == part) then
			sum += p.Position
			n += 1
		end
	end
	return if n > 0 then sum / n else model:GetPivot().Position
end

local function moveCamera()
	local c = ctx
	local model = preview
	if not c or not model then
		return
	end
	local focusPart = if tab == "color" then nil else tab
	local center = focusCenter(model, focusPart)
	local view = CAMERA_VIEW[tab]
	local dist = view.dist * c.cellSize / (Config.Flight.CELL_SIZE * Editor.DISPLAY_SCALE)
	local camPos = center + c.pivot:VectorToWorldSpace(view.dir.Unit) * dist
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Scriptable
	TweenService:Create(camera, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		CFrame = CFrame.lookAt(camPos, center),
	}):Play()
end

-- 미리보기 모델 다시 만들기. 지금 탭의 부위는 또렷하게(외곽선), 나머지는 흐리게
local function rebuildPreview(design: any)
	local c = ctx :: Context
	if preview then
		preview:Destroy()
	end
	local model = PlaneBuilder.build(design, { cellSize = c.cellSize, display = true })
	model.Name = "PartsPreview"
	local focus = Instance.new("Model")
	focus.Name = "Focus"
	focus.Parent = model
	for _, p in model:GetChildren() do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			local part = p:GetAttribute("Part")
			if tab ~= "color" and part ~= nil then
				if part == tab then
					p.Parent = focus
				else
					p.Transparency = math.max(p.Transparency, 0.7)
				end
			end
		end
	end
	if tab ~= "color" then
		local hl = Instance.new("Highlight")
		hl.Adornee = focus
		hl.FillTransparency = 1
		hl.OutlineColor = Widgets.GOLD
		hl.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
		hl.Parent = focus
	end
	model:PivotTo(c.pivot)
	model.Parent = workspace
	preview = model
end

local function render(moveCam: boolean)
	local c = ctx
	if not c then
		return
	end
	local shape = Shapes.byId[c.state.design.frameId]
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == tab then Widgets.ACCENT else GRAY
	end
	local design, result = simulate()
	rebuildPreview(design)

	variantRow.Visible = tab ~= "color"
	colorRow.Visible = tab == "color"
	colorPartRow.Visible = tab == "color"
	applyButton.Visible = tab ~= "color"

	if tab ~= "color" then
		local v = pending[tab] or c.state.design.parts[tab]
		local order = shape.variantOrder
		local i = table.find(order, v) or 1
		local now = if c.state.design.parts[tab] == v then "  (지금)" else ""
		variantLabel.Text = `{shape.partNames[tab]}: {shape.variantNames[tab][v]}  {i}/{#order}{now}`
	else
		for name, b in colorPartButtons do
			b.BackgroundColor3 = if name == colorPart then Widgets.ACCENT else GRAY
		end
	end

	-- 막대 변화: 지금 → 바꾼 뒤
	local before = PlaneStats.compute(c.state.design)
	local after = PlaneStats.compute(design)
	local rows = {
		{ "speed", "속도", before.maxSpeed, after.maxSpeed },
		{ "hp", "튼튼함", before.hp, after.hp },
		{ "fire", "화력", before.firepower, after.firepower },
		{ "mine", "채굴력", before.minePower, after.minePower },
	}
	for _, r in rows do
		local key, name, a, b = r[1] :: string, r[2] :: string, r[3] :: number, r[4] :: number
		local function f(x: number): string
			return if key == "mine" then string.format("%.1f", x) else tostring(math.floor(x + 0.5))
		end
		local line = statLines[key]
		if math.abs(b - a) < (if key == "mine" then 0.05 else 0.5) then
			line.Text = `{name}  {f(a)}`
			line.TextColor3 = Color3.new(1, 1, 1)
		else
			line.Text = `{name}  {f(a)} → {f(b)}`
			line.TextColor3 = if b > a then Color3.fromRGB(120, 230, 120) else Color3.fromRGB(255, 120, 110)
		end
	end

	local changed = false
	for part, v in pending do
		if c.state.design.parts[part] ~= v then
			changed = true
		end
	end
	if tab == "color" then
		infoLabel.Text = "부위를 고르고 색을 누르면 바로 칠해져요"
	elseif not changed then
		infoLabel.Text = "◀ ▶ 로 모양을 골라 보세요"
	else
		local text = `블록 {result.returned}개가 창고로 돌아갔다가 새 모양에 다시 채워져요`
		if result.defaults > 0 then
			text ..= `\n모자란 {result.defaults}칸은 기본 블록`
		end
		infoLabel.Text = text
	end
	applyButton.BackgroundColor3 = if changed then Color3.fromRGB(70, 180, 90) else GRAY
	applyButton.AutoButtonColor = changed

	if moveCam then
		moveCamera()
	end
end

local function step(dir: number)
	local c = ctx
	if not c or tab == "color" then
		return
	end
	local order = Shapes.byId[c.state.design.frameId].variantOrder
	local v = pending[tab] or c.state.design.parts[tab]
	local i = table.find(order, v) or 1
	i = (i - 1 + dir) % #order + 1
	pending[tab] = order[i]
	render(false)
end

local function apply()
	local c = ctx
	if not c or busy then
		return
	end
	local changed = false
	for part, v in pending do
		if c.state.design.parts[part] ~= v then
			changed = true
		end
	end
	if not changed then
		return
	end
	busy = true
	local state = c.onApply(pending)
	busy = false
	if ctx ~= c then
		return
	end
	if state then
		c.state = state
		table.clear(pending)
		toast("부위를 바꿨어요!")
	end
	render(false)
end

local function chooseColor(hex: string)
	local c = ctx
	if not c or busy then
		return
	end
	busy = true
	local state = c.onColor(colorPart, hex)
	busy = false
	if ctx ~= c then
		return
	end
	if state then
		c.state = state
	end
	render(false)
end

function PartsScreen.Mount(playerGui: Instance)
	gui = Instance.new("ScreenGui")
	gui.Name = "PartsScreen"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Enabled = false
	local scale = Instance.new("UIScale")
	scale.Parent = gui
	local function fit()
		local cam = workspace.CurrentCamera
		scale.Scale = math.clamp((if cam then cam.ViewportSize.Y else 700) / 720, 0.6, 1)
	end
	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end

	-- 위: 제목 + 닫기
	local top = Instance.new("Frame")
	top.AnchorPoint = Vector2.new(0.5, 0)
	top.Position = UDim2.new(0.5, 0, 0, 10)
	top.Size = UDim2.fromOffset(300, 44)
	top.BackgroundColor3 = Widgets.PANEL
	top.BackgroundTransparency = 0.15
	top.Parent = gui
	Widgets.corner(top, 12)
	Widgets.label(top, "부위 교체", UDim2.new(1, -60, 1, 0), UDim2.fromOffset(14, 0), 20)
	button(top, "X", Color3.fromRGB(200, 70, 70), UDim2.fromOffset(36, 36), UDim2.new(1, -40, 0, 4)).Activated:Connect(function()
		PartsScreen.Close()
	end)

	-- 오른쪽: 막대 변화
	local side = Instance.new("Frame")
	side.AnchorPoint = Vector2.new(1, 0.5)
	side.Position = UDim2.new(1, -10, 0.4, 0)
	side.Size = UDim2.fromOffset(230, 130)
	side.BackgroundColor3 = Widgets.PANEL
	side.BackgroundTransparency = 0.15
	side.Parent = gui
	Widgets.corner(side, 12)
	for i, key in { "speed", "hp", "fire", "mine" } do
		statLines[key] = Widgets.label(side, "", UDim2.new(1, -24, 0, 26), UDim2.fromOffset(12, 8 + (i - 1) * 29), 16)
	end

	-- 아래: 모양 넘기기 / 색 + 탭
	local bottom = Instance.new("Frame")
	bottom.AnchorPoint = Vector2.new(0.5, 1)
	bottom.Position = UDim2.new(0.5, 0, 1, -10)
	bottom.Size = UDim2.fromOffset(600, 196)
	bottom.BackgroundColor3 = Widgets.PANEL
	bottom.BackgroundTransparency = 0.15
	bottom.Parent = gui
	Widgets.corner(bottom, 12)

	infoLabel = Widgets.label(bottom, "", UDim2.new(1, -20, 0, 38), UDim2.fromOffset(10, 4), 14)
	infoLabel.TextXAlignment = Enum.TextXAlignment.Center
	infoLabel.TextWrapped = true
	infoLabel.TextColor3 = Color3.fromRGB(190, 210, 240)

	variantRow = Instance.new("Frame")
	variantRow.Position = UDim2.fromOffset(10, 46)
	variantRow.Size = UDim2.new(1, -20, 0, 50)
	variantRow.BackgroundTransparency = 1
	variantRow.Parent = bottom
	hlist(variantRow, 10)
	local prev = button(variantRow, "◀", GRAY, UDim2.fromOffset(56, 46))
	prev.TextSize = 24
	prev.LayoutOrder = 1
	prev.Activated:Connect(function()
		step(-1)
	end)
	variantLabel = Widgets.label(variantRow, "", UDim2.fromOffset(250, 46), UDim2.new(), 18)
	variantLabel.TextXAlignment = Enum.TextXAlignment.Center
	variantLabel.LayoutOrder = 2
	local nextB = button(variantRow, "▶", GRAY, UDim2.fromOffset(56, 46))
	nextB.TextSize = 24
	nextB.LayoutOrder = 3
	nextB.Activated:Connect(function()
		step(1)
	end)
	applyButton = button(variantRow, "적용", GRAY, UDim2.fromOffset(96, 46))
	applyButton.TextSize = 18
	applyButton.LayoutOrder = 4
	applyButton.Activated:Connect(apply)

	colorPartRow = Instance.new("Frame")
	colorPartRow.Position = UDim2.fromOffset(10, 44)
	colorPartRow.Size = UDim2.new(1, -20, 0, 30)
	colorPartRow.BackgroundTransparency = 1
	colorPartRow.Parent = bottom
	hlist(colorPartRow, 6)
	for i, part in { "body", "nose", "wing", "tail" } do
		local b = button(colorPartRow, Shapes.byId[Shapes.DEFAULT_DESIGN.frameId].partNames[part], GRAY, UDim2.fromOffset(80, 28))
		b.TextSize = 14
		b.LayoutOrder = i
		colorPartButtons[part] = b
		b.Activated:Connect(function()
			colorPart = part
			render(false)
		end)
	end

	colorRow = Instance.new("Frame")
	colorRow.Position = UDim2.fromOffset(10, 78)
	colorRow.Size = UDim2.new(1, -20, 0, 40)
	colorRow.BackgroundTransparency = 1
	colorRow.Parent = bottom
	hlist(colorRow, 5)
	for i, hex in Editor.PALETTE do
		local b = button(colorRow, "", Color3.fromHex(hex), UDim2.fromOffset(38, 38))
		b.LayoutOrder = i
		b.Activated:Connect(function()
			chooseColor(hex)
		end)
	end

	local tabs = Instance.new("Frame")
	tabs.Position = UDim2.new(0, 10, 1, -66)
	tabs.Size = UDim2.new(1, -20, 0, 56)
	tabs.BackgroundTransparency = 1
	tabs.Parent = bottom
	hlist(tabs, 8)
	local names = { nose = "기수", wing = "날개", tail = "꼬리", color = "색칠" }
	for i, name in TABS do
		local b = button(tabs, names[name], GRAY, UDim2.fromOffset(130, 52))
		b.TextSize = 20
		b.LayoutOrder = i
		tabButtons[name] = b
		b.Activated:Connect(function()
			tab = name
			render(true)
		end)
	end

	toastLabel = Widgets.label(bottom, "", UDim2.new(1, 0, 0, 30), UDim2.fromOffset(0, -36), 20)
	toastLabel.TextXAlignment = Enum.TextXAlignment.Center
	toastLabel.TextStrokeTransparency = 0.3
	toastLabel.TextTransparency = 1

	gui.Parent = playerGui
end

function PartsScreen.IsOpen(): boolean
	return ctx ~= nil
end

function PartsScreen.Open(context: Context)
	if ctx then
		return
	end
	ctx = context
	tab = "nose"
	colorPart = "body"
	table.clear(pending)
	setServerDisplayHidden(true)
	-- 서버가 전시 모델을 다시 만들면 새 것도 숨긴다
	hiddenConn = context.pad.ChildAdded:Connect(function(child)
		if child.Name == "Display" then
			task.defer(setServerDisplayHidden, true)
		end
	end)
	gui.Enabled = true
	render(true)
end

-- 서버 상태가 다른 곳에서 바뀌었을 때
function PartsScreen.Update(state: any)
	local c = ctx
	if c then
		c.state = state
		render(false)
	end
end

function PartsScreen.Close()
	local c = ctx
	if not c then
		return
	end
	setServerDisplayHidden(false)
	ctx = nil
	if hiddenConn then
		hiddenConn:Disconnect()
		hiddenConn = nil
	end
	if preview then
		preview:Destroy()
		preview = nil
	end
	gui.Enabled = false
	local camera = workspace.CurrentCamera
	camera.CameraType = Enum.CameraType.Custom
	local char = Players.LocalPlayer.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		camera.CameraSubject = hum
	end
	c.onClose()
end

return PartsScreen
