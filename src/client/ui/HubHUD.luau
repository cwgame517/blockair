--!strict
-- 허브 UI: 레벨·XP 바·코인, 비행기 타기·출격 버튼. (에디터 버튼은 4단계에서 붙인다)
local TweenService = game:GetService("TweenService")

local Widgets = require(script.Parent.components.Widgets)

local HubHUD = {}

local gui: ScreenGui
local levelLabel: TextLabel
local xpLabel: TextLabel
local coinLabel: TextLabel
local xpBar: { set: (number) -> () }
local toast: TextLabel
local buttons: Frame
local flyCallback: (() -> ())? = nil
local sortieCallback: (() -> ())? = nil

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

function HubHUD.Mount(playerGui: Instance)
	gui = Instance.new("ScreenGui")
	gui.Name = "HubHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(260, 84)
	-- 왼쪽 위는 로블록스 채팅창, 오른쪽 위는 순위표 자리라 가운데 위에 둔다
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

	toast = Widgets.label(gui, "", UDim2.fromOffset(420, 48), UDim2.new(0.5, -210, 0, 140), 28)
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.TextColor3 = Widgets.GOLD
	toast.TextTransparency = 1

	-- 아래 가운데: 모바일의 기본 스틱(왼쪽)·점프 버튼(오른쪽)과 겹치지 않는 자리
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
	button(buttons, "출격", Color3.fromRGB(230, 120, 50), 2).Activated:Connect(function()
		if sortieCallback then
			sortieCallback()
		end
	end)

	gui.Parent = playerGui
end

function HubHUD.OnFly(fn: () -> ())
	flyCallback = fn
end

function HubHUD.OnSortie(fn: () -> ())
	sortieCallback = fn
end

-- 비행 중에는 버튼을 숨긴다 (내리기는 F 키나 비행 화면의 버튼)
function HubHUD.SetFlying(flying: boolean)
	buttons.Visible = not flying
end

function HubHUD.Show()
	gui.Enabled = true
end

function HubHUD.Hide()
	gui.Enabled = false
end

local function comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function HubHUD.SetStats(stats: { level: number, xp: number, xpToNext: number, coins: number })
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
function HubHUD.Toast(text: string)
	toastId += 1
	local id = toastId
	toast.Text = text
	toast.TextTransparency = 0
	task.delay(2.5, function()
		if id == toastId then
			TweenService:Create(toast, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end
	end)
end

function HubHUD.ShowLevelUp(level: number, unlock: string?)
	HubHUD.Toast(if unlock then `레벨 {level}! {unlock}` else `레벨 {level}!`)
end

return HubHUD
