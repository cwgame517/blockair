--!strict
-- 원정 결과 화면: 섬에서 허브로 돌아오면 한 번 뜬다. 확인을 누르면 닫힌다.
local Widgets = require(script.Parent.components.Widgets)

local ResultPanel = {}

local gui: ScreenGui
local body: TextLabel
local levelLabel: TextLabel

local function comma(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function ResultPanel.Mount(playerGui: Instance)
	gui = Instance.new("ScreenGui")
	gui.Name = "ResultPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 10
	gui.Enabled = false

	local win = Instance.new("Frame")
	win.AnchorPoint = Vector2.new(0.5, 0.5)
	win.Position = UDim2.fromScale(0.5, 0.5)
	win.Size = UDim2.new(1, -32, 0, 330)
	win.BackgroundColor3 = Widgets.PANEL
	win.Parent = gui
	Widgets.corner(win, 14)
	local limit = Instance.new("UISizeConstraint")
	limit.MaxSize = Vector2.new(380, 330)
	limit.Parent = win

	local title = Widgets.label(win, "원정 결과", UDim2.new(1, 0, 0, 44), UDim2.fromOffset(0, 10), 26)
	title.TextXAlignment = Enum.TextXAlignment.Center
	title.TextColor3 = Widgets.GOLD

	body = Widgets.label(win, "", UDim2.new(1, -48, 0, 150), UDim2.fromOffset(24, 60), 19)
	body.TextYAlignment = Enum.TextYAlignment.Top
	body.LineHeight = 1.25

	levelLabel = Widgets.label(win, "", UDim2.new(1, -48, 0, 30), UDim2.fromOffset(24, 210), 22)
	levelLabel.TextXAlignment = Enum.TextXAlignment.Center
	levelLabel.TextColor3 = Widgets.ACCENT

	local ok = Instance.new("TextButton")
	ok.Size = UDim2.fromOffset(160, 48)
	ok.AnchorPoint = Vector2.new(0.5, 1)
	ok.Position = UDim2.new(0.5, 0, 1, -16)
	ok.BackgroundColor3 = Widgets.ACCENT
	ok.Font = Widgets.FONT
	ok.TextSize = 20
	ok.TextColor3 = Color3.new(1, 1, 1)
	ok.Text = "확인"
	ok.Parent = win
	Widgets.corner(ok, 12)
	ok.Activated:Connect(function()
		gui.Enabled = false
	end)

	gui.Parent = playerGui
end

-- r = { mined, lost, deposited, coins, xp, levelFrom, levelTo }
function ResultPanel.Show(r: any)
	if type(r) ~= "table" then
		return
	end
	local lines = {
		`캔 블록  {comma(r.mined or 0)}개`,
		`맡긴 블록  {comma(r.deposited or 0)}개`,
	}
	if (r.lost or 0) > 0 then
		table.insert(lines, `사라진 블록  {comma(r.lost)}개`)
	end
	table.insert(lines, `보물 코인  +{comma(r.coins or 0)}`)
	table.insert(lines, `XP  +{comma(r.xp or 0)}`)
	body.Text = table.concat(lines, "\n")
	if (r.levelTo or 1) > (r.levelFrom or 1) then
		levelLabel.Text = `레벨 업! Lv {r.levelFrom} → Lv {r.levelTo}`
		levelLabel.TextSize = 22
	else
		levelLabel.Text = "격납고에서 블록을 팔아 코인으로 바꾸세요"
		levelLabel.TextSize = 16
	end
	gui.Enabled = true
end

return ResultPanel
