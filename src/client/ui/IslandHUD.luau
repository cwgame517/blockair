--!strict
-- 하늘 섬 UI: 레벨·코인, 화물칸 게이지("화물 32/50"), 알림,
-- 내려 있을 때 "비행기 타기"·"허브로" 버튼, 날 때 폭탄 버튼(재장전 표시). 디자인은 8단계에서 다듬는다.
local TweenService = game:GetService("TweenService")

local Widgets = require(script.Parent.components.Widgets)

local IslandHUD = {}

local RED = Color3.fromRGB(255, 110, 110)

local gui: ScreenGui
local levelLabel: TextLabel
local xpLabel: TextLabel
local coinLabel: TextLabel
local xpBar: { set: (number) -> () }
local cargoLabel: TextLabel
local cargoBar: { set: (number) -> (), fill: Frame }
local toast: TextLabel
local buttons: Frame
local bombButton: TextButton
local bombShade: Frame
local flyCallback: (() -> ())? = nil
local homeCallback: (() -> ())? = nil
local bombCallback: (() -> ())? = nil

local function button(parent: Instance, text: string, color: Color3, order: number): TextButton
	local b = Instance.new("TextButton")
	b.Size = UDim2.fromOffset(150, 50)
	b.BackgroundColor3 = color
	b.Font = Widgets.FONT
	b.TextSize = 20
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Text = text
	b.LayoutOrder = order
	b.AutoButtonColor = true
	b.Parent = parent
	Widgets.corner(b, 12)
	return b
end

function IslandHUD.Mount(playerGui: Instance)
	gui = Instance.new("ScreenGui")
	gui.Name = "IslandHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Enabled = false

	-- 가운데 위: 레벨·코인·XP (왼쪽 위는 채팅창, 오른쪽 위는 순위표 자리)
	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(260, 84)
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 8)
	panel.BackgroundColor3 = Widgets.PANEL
	panel.BackgroundTransparency = 0.15
	panel.Parent = gui
	Widgets.corner(panel, 12)

	levelLabel = Widgets.label(panel, "Lv 1", UDim2.fromOffset(120, 28), UDim2.fromOffset(14, 8), 22)
	coinLabel = Widgets.label(panel, "0", UDim2.fromOffset(110, 28), UDim2.fromOffset(136, 8), 20)
	coinLabel.TextXAlignment = Enum.TextXAlignment.Right
	coinLabel.TextColor3 = Widgets.GOLD
	xpBar = Widgets.bar(panel, UDim2.fromOffset(232, 12), UDim2.fromOffset(14, 44), Widgets.ACCENT)
	xpLabel = Widgets.label(panel, "0 / 100 XP", UDim2.fromOffset(232, 18), UDim2.fromOffset(14, 60), 13)
	xpLabel.TextColor3 = Color3.fromRGB(180, 195, 220)

	-- 그 아래: 화물칸
	local cargo = Instance.new("Frame")
	cargo.Size = UDim2.fromOffset(260, 46)
	cargo.AnchorPoint = Vector2.new(0.5, 0)
	cargo.Position = UDim2.new(0.5, 0, 0, 98)
	cargo.BackgroundColor3 = Widgets.PANEL
	cargo.BackgroundTransparency = 0.15
	cargo.Parent = gui
	Widgets.corner(cargo, 12)
	cargoLabel = Widgets.label(cargo, "화물 0/50", UDim2.fromOffset(232, 20), UDim2.fromOffset(14, 4), 16)
	cargoBar = Widgets.bar(cargo, UDim2.fromOffset(232, 12), UDim2.fromOffset(14, 27), Color3.fromRGB(190, 140, 80))

	toast = Widgets.label(gui, "", UDim2.fromOffset(520, 48), UDim2.new(0.5, -260, 0, 200), 26)
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.TextColor3 = Widgets.GOLD
	toast.TextTransparency = 1
	toast.TextStrokeTransparency = 1

	-- 아래 가운데: 내려 있을 때 버튼
	buttons = Instance.new("Frame")
	buttons.Size = UDim2.fromOffset(312, 50)
	buttons.AnchorPoint = Vector2.new(0.5, 1)
	buttons.Position = UDim2.new(0.5, 0, 1, -20)
	buttons.BackgroundTransparency = 1
	buttons.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Padding = UDim.new(0, 12)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = buttons
	button(buttons, "비행기 타기", Widgets.ACCENT, 1).Activated:Connect(function()
		if flyCallback then
			flyCallback()
		end
	end)
	button(buttons, "허브로", Color3.fromRGB(90, 100, 125), 2).Activated:Connect(function()
		if homeCallback then
			homeCallback()
		end
	end)

	-- 날 때: 폭탄 버튼 (오른쪽 아래 속도 막대 왼쪽). PC 는 Space 도 됨
	bombButton = Instance.new("TextButton")
	bombButton.Name = "Bomb"
	bombButton.Size = UDim2.fromOffset(84, 84)
	bombButton.AnchorPoint = Vector2.new(1, 1)
	bombButton.Position = UDim2.new(1, -124, 1, -30)
	bombButton.BackgroundColor3 = Color3.fromRGB(230, 120, 50)
	bombButton.Font = Widgets.FONT
	bombButton.TextSize = 20
	bombButton.TextColor3 = Color3.new(1, 1, 1)
	bombButton.Text = "폭탄"
	bombButton.Visible = false
	bombButton.ClipsDescendants = true
	bombButton.Parent = gui
	Widgets.corner(bombButton, 42)
	bombShade = Instance.new("Frame")
	bombShade.AnchorPoint = Vector2.new(0, 1)
	bombShade.Position = UDim2.fromScale(0, 1)
	bombShade.Size = UDim2.fromScale(1, 0)
	bombShade.BackgroundColor3 = Color3.new(0, 0, 0)
	bombShade.BackgroundTransparency = 0.45
	bombShade.BorderSizePixel = 0
	bombShade.Parent = bombButton
	bombButton.Activated:Connect(function()
		if bombCallback then
			bombCallback()
		end
	end)

	gui.Parent = playerGui
end

function IslandHUD.OnFly(fn: () -> ())
	flyCallback = fn
end

function IslandHUD.OnHome(fn: () -> ())
	homeCallback = fn
end

function IslandHUD.OnBomb(fn: () -> ())
	bombCallback = fn
end

function IslandHUD.SetFlying(flying: boolean)
	buttons.Visible = not flying
	bombButton.Visible = flying
end

-- 폭탄 재장전: 버튼이 어두워졌다가 아래로 걷힌다
function IslandHUD.StartCooldown(seconds: number)
	bombShade.Size = UDim2.fromScale(1, 1)
	TweenService:Create(bombShade, TweenInfo.new(seconds, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 0) }):Play()
end

function IslandHUD.SetCargo(count: number, cap: number)
	cargoLabel.Text = `화물 {count}/{cap}`
	cargoBar.set(count / math.max(cap, 1))
	local full = count >= cap
	cargoLabel.TextColor3 = if full then Widgets.GOLD else Color3.new(1, 1, 1)
	cargoBar.fill.BackgroundColor3 = if full then Widgets.GOLD else Color3.fromRGB(190, 140, 80)
	if full then
		cargoLabel.Text ..= "  가득!"
	end
end

function IslandHUD.Show()
	gui.Enabled = true
end

function IslandHUD.Hide()
	gui.Enabled = false
end

local function comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function IslandHUD.SetStats(stats: { level: number, xp: number, xpToNext: number, coins: number })
	levelLabel.Text = `Lv {stats.level}`
	coinLabel.Text = comma(stats.coins) .. " 코인"
	if stats.xpToNext <= 0 then
		xpLabel.Text = "최고 레벨"
		xpBar.set(1)
	else
		xpLabel.Text = `{comma(stats.xp)} / {comma(stats.xpToNext)} XP`
		xpBar.set(stats.xp / stats.xpToNext)
	end
end

local toastId = 0
function IslandHUD.Toast(text: string, warn: boolean?)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextColor3 = if warn then RED else Widgets.GOLD
	toast.TextTransparency = 0
	toast.TextStrokeTransparency = 0.4
	task.delay(if warn then 3 else 2.5, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(0.6), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
		end
	end)
end

function IslandHUD.ShowLevelUp(level: number, unlock: string?)
	IslandHUD.Toast(if unlock then `레벨 {level}! {unlock}` else `레벨 {level}!`)
end

return IslandHUD
