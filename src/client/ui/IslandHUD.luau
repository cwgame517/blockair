--!strict
-- 하늘 섬 UI (임시): 지금은 허브와 같은 레벨·코인 표시. HP·연료·화물칸은 2단계에서 붙인다
local TweenService = game:GetService("TweenService")

local Widgets = require(script.Parent.components.Widgets)

local IslandHUD = {}

local gui: ScreenGui
local levelLabel: TextLabel
local xpLabel: TextLabel
local coinLabel: TextLabel
local xpBar: { set: (number) -> () }
local toast: TextLabel

function IslandHUD.Mount(playerGui: Instance)
	gui = Instance.new("ScreenGui")
	gui.Name = "IslandHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.Enabled = false

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(260, 84)
	panel.Position = UDim2.fromOffset(16, 16)
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

	toast = Widgets.label(gui, "", UDim2.fromOffset(420, 48), UDim2.new(0.5, -210, 0, 120), 28)
	toast.TextXAlignment = Enum.TextXAlignment.Center
	toast.TextColor3 = Widgets.GOLD
	toast.TextTransparency = 1

	gui.Parent = playerGui
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

function IslandHUD.ShowLevelUp(level: number, unlock: string?)
	toast.Text = if unlock then `레벨 {level}! {unlock}` else `레벨 {level}!`
	toast.TextTransparency = 0
	task.delay(2.5, function()
		TweenService:Create(toast, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
	end)
end

return IslandHUD
