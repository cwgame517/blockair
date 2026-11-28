--!strict
-- 허브 격납고 창: [창고] 맡긴 블록 팔기, [강화] 코인으로 화물칸·채굴 폭탄 올리기.
-- 서버가 모든 걸 검사하고 새 상태를 돌려주면 그대로 다시 그린다. 디자인은 8단계에서 다듬는다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local BlockInfo = require(ReplicatedStorage.Shared.Island.BlockInfo)
local Widgets = require(script.Parent.components.Widgets)

local Upgrades = Config.Upgrades

local HangarMenu = {}

local GREEN = Color3.fromRGB(70, 180, 90)
local GRAY = Color3.fromRGB(80, 88, 105)
local ROW = Color3.fromRGB(32, 42, 62)

local gui: ScreenGui
local coinLabel: TextLabel
local list: ScrollingFrame
local tabButtons: { [string]: TextButton } = {}
local tab = "storage" -- "storage" | "upgrade"
local state: any = nil
local busy = false
local msgLabel: TextLabel
local msgId = 0

local function comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

-- 창 아래쪽 한 줄 알림 (창이 화면 알림을 가리므로 창 안에 띄운다)
local function toast(text: string, warn: boolean?)
	msgId += 1
	local id = msgId
	msgLabel.Text = text
	msgLabel.TextColor3 = if warn then Color3.fromRGB(255, 110, 110) else Widgets.GOLD
	msgLabel.TextTransparency = 0
	task.delay(2.5, function()
		if id == msgId then
			TweenService:Create(msgLabel, TweenInfo.new(0.5), { TextTransparency = 1 }):Play()
		end
	end)
end

local function textButton(parent: Instance, text: string, color: Color3, size: UDim2, pos: UDim2): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.Position = pos
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

local function row(order: number, height: number?): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.new(1, -8, 0, height or 52)
	f.BackgroundColor3 = ROW
	f.LayoutOrder = order
	f.Parent = list
	Widgets.corner(f, 8)
	return f
end

local function fmtValue(item: string, step: number): string
	local def = Upgrades.ITEMS[item]
	local v = def.values[step]
	if string.sub(def.unit, -1) == "+" then
		return `{def.unit}{v}` -- "채굴력 +2"
	end
	return `{v}{def.unit}`
end

local render: () -> ()

-- 서버에 요청하고 돌아온 상태로 다시 그린다
local function call(name: string, arg: any)
	if busy then
		return
	end
	busy = true
	local ok, result = pcall(function()
		return Net.func(name):InvokeServer(arg)
	end)
	busy = false
	if not ok or not result then
		toast("잠시 후 다시 해 주세요", true)
		return
	end
	if result.state then
		state = result.state
	end
	if name == "SellBlocks" and result.ok then
		toast(`블록 {comma(result.sold)}개 팔기 +{comma(result.earned)} 코인`)
	elseif name == "BuyUpgrade" then
		if result.ok then
			toast(`{Upgrades.ITEMS[result.item].name} {result.step}단계!`)
		elseif result.why == "coins" then
			toast("코인이 모자라요", true)
		elseif result.why == "level" then
			toast("레벨을 더 올려야 해요", true)
		end
	end
	render()
end

local function clear()
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

local function renderStorage()
	local blocks = state.blocks
	if #blocks == 0 then
		local f = row(1, 80)
		local l = Widgets.label(f, "창고가 비었어요.\n섬에서 캔 블록을 격납고에 맡기면 여기로 와요.", UDim2.new(1, -20, 1, 0), UDim2.fromOffset(10, 0), 15)
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.TextWrapped = true
		return
	end
	local total, count = 0, 0
	for _, b in blocks do
		total += b.count * b.price
		count += b.count
	end
	local top = row(0, 52)
	top.BackgroundTransparency = 1
	Widgets.label(top, `블록 {comma(count)}개`, UDim2.new(0.5, 0, 1, 0), UDim2.fromOffset(6, 0), 17)
	textButton(top, `전부 팔기 +{comma(total)}`, Widgets.GOLD, UDim2.new(0.5, -6, 0, 40), UDim2.new(0.5, 0, 0, 6)).Activated:Connect(function()
		call("SellBlocks", nil)
	end)
	for i, b in blocks do
		local info = BlockInfo.byId[b.id]
		local f = row(i)
		local swatch = Instance.new("Frame")
		swatch.Size = UDim2.fromOffset(32, 32)
		swatch.Position = UDim2.fromOffset(10, 10)
		swatch.BackgroundColor3 = if info then info.color else GRAY
		swatch.Parent = f
		Widgets.corner(swatch, 6)
		Widgets.label(f, if info then info.name else `블록 {b.id}`, UDim2.new(0.4, -52, 1, 0), UDim2.fromOffset(52, 0), 16)
		local n = Widgets.label(f, `{comma(b.count)}개`, UDim2.new(0.2, 0, 1, 0), UDim2.new(0.4, 0, 0, 0), 16)
		n.TextColor3 = Color3.fromRGB(190, 200, 220)
		textButton(f, `팔기 +{comma(b.count * b.price)}`, GREEN, UDim2.new(0.4, -14, 0, 38), UDim2.new(0.6, 4, 0, 7)).Activated:Connect(function()
			call("SellBlocks", b.id)
		end)
	end
end

local function renderUpgrades()
	for i, item in Upgrades.OPEN do
		local def = Upgrades.ITEMS[item]
		local step = state.upgrades[item] or 1
		local maxStep = #def.values
		local f = row(i, 64)
		Widgets.label(f, `{def.name}  {step}/{maxStep}`, UDim2.new(0.55, -12, 0, 26), UDim2.fromOffset(12, 6), 17)
		local value = if step >= maxStep then fmtValue(item, step) else `{fmtValue(item, step)} → {fmtValue(item, step + 1)}`
		local v = Widgets.label(f, value, UDim2.new(0.55, -12, 0, 22), UDim2.fromOffset(12, 34), 15)
		v.TextColor3 = Color3.fromRGB(150, 220, 255)
		local text, color = "", GREEN
		if step >= maxStep then
			text, color = "최대", GRAY
		elseif step + 1 > state.cap then
			text, color = `레벨 {Upgrades.STEP_LEVEL[step + 1]} 필요`, GRAY
		else
			local cost = Upgrades.STEP_COST[step + 1]
			text = `{comma(cost)} 코인`
			color = if state.coins >= cost then GREEN else GRAY
		end
		local b = textButton(f, text, color, UDim2.new(0.45, -14, 0, 44), UDim2.new(0.55, 4, 0, 10))
		if step < maxStep then
			b.Activated:Connect(function()
				call("BuyUpgrade", item)
			end)
		else
			b.AutoButtonColor = false
		end
	end
end

render = function()
	if not state then
		return
	end
	coinLabel.Text = `{comma(state.coins)} 코인`
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == tab then Widgets.ACCENT else GRAY
	end
	clear()
	if tab == "storage" then
		renderStorage()
	else
		renderUpgrades()
	end
end

function HangarMenu.Mount(playerGui: Instance)
	gui = Instance.new("ScreenGui")
	gui.Name = "HangarMenu"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Enabled = false

	local win = Instance.new("Frame")
	win.AnchorPoint = Vector2.new(0.5, 0.5)
	win.Position = UDim2.fromScale(0.5, 0.52)
	win.Size = UDim2.new(1, -32, 0.78, 0)
	win.BackgroundColor3 = Widgets.PANEL
	win.Parent = gui
	Widgets.corner(win, 14)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(560, 460)
	limit.Parent = win

	Widgets.label(win, "격납고", UDim2.fromOffset(140, 40), UDim2.fromOffset(16, 8), 24)
	coinLabel = Widgets.label(win, "0 코인", UDim2.new(1, -220, 0, 40), UDim2.fromOffset(150, 8), 18)
	coinLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinLabel.TextColor3 = Widgets.GOLD
	textButton(win, "X", Color3.fromRGB(200, 70, 70), UDim2.fromOffset(40, 40), UDim2.new(1, -52, 0, 8)).Activated:Connect(function()
		HangarMenu.Close()
	end)

	local tabs = { { "storage", "창고 (팔기)" }, { "upgrade", "강화" } }
	for i, t in tabs do
		local b = textButton(win, t[2], GRAY, UDim2.new(0.5, -20, 0, 40), UDim2.new((i - 1) * 0.5, if i == 1 then 16 else 4, 0, 56))
		b.TextSize = 18
		tabButtons[t[1]] = b
		b.Activated:Connect(function()
			tab = t[1]
			render()
		end)
	end

	list = Instance.new("ScrollingFrame")
	list.Position = UDim2.fromOffset(16, 106)
	list.Size = UDim2.new(1, -24, 1, -146)
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.ScrollBarThickness = 6
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.Parent = win
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list

	msgLabel = Widgets.label(win, "", UDim2.new(1, -32, 0, 28), UDim2.new(0, 16, 1, -36), 17)
	msgLabel.TextXAlignment = Enum.TextXAlignment.Center
	msgLabel.TextTransparency = 1

	gui.Parent = playerGui
end

function HangarMenu.Open()
	gui.Enabled = true
	task.spawn(function()
		local ok, result = pcall(function()
			return Net.func("GetHangar"):InvokeServer()
		end)
		if ok and result then
			state = result
			render()
		end
	end)
end

function HangarMenu.Close()
	gui.Enabled = false
end

function HangarMenu.Toggle()
	if gui.Enabled then
		HangarMenu.Close()
	else
		HangarMenu.Open()
	end
end

-- 코인이 다른 곳에서 바뀌었을 때 버튼 색을 맞춘다
function HangarMenu.SetCoins(coins: number)
	if state then
		state.coins = coins
		if gui.Enabled then
			render()
		end
	end
end

return HangarMenu
