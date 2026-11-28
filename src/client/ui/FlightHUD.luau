--!strict
-- 비행 중 화면: 조준점(가고 싶은 곳), 기수 표시(지금 향하는 곳), 속도 막대, PC 조작 안내.
local Widgets = require(script.Parent.components.Widgets)

local FlightHUD = {}

local gui: ScreenGui
local aimMark: Frame
local noseMark: Frame
local speedLabel: TextLabel
local speedBar: { set: (number) -> () }
local hint: TextLabel

local function ring(parent: Instance, size: number, color: Color3, thickness: number): Frame
	local f = Instance.new("Frame")
	f.Size = UDim2.fromOffset(size, size)
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.BackgroundTransparency = 1
	f.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = color
	stroke.Thickness = thickness
	stroke.Parent = f
	Widgets.corner(f, size // 2)
	return f
end

function FlightHUD.Mount(playerGui: Instance)
	gui = Instance.new("ScreenGui")
	gui.Name = "FlightHUD"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true -- 3D 위치를 화면에 찍으므로 화면 전체 기준
	gui.Enabled = false

	aimMark = ring(gui, 34, Color3.new(1, 1, 1), 2)
	noseMark = ring(gui, 12, Widgets.GOLD, 3)

	local panel = Instance.new("Frame")
	panel.Size = UDim2.fromOffset(240, 46)
	panel.AnchorPoint = Vector2.new(0.5, 1)
	panel.Position = UDim2.new(0.5, 0, 1, -20)
	panel.BackgroundColor3 = Widgets.PANEL
	panel.BackgroundTransparency = 0.3
	panel.Parent = gui
	Widgets.corner(panel, 10)
	speedLabel = Widgets.label(panel, "속도 0", UDim2.fromOffset(220, 20), UDim2.fromOffset(10, 4), 16)
	speedBar = Widgets.bar(panel, UDim2.fromOffset(220, 10), UDim2.fromOffset(10, 28), Widgets.ACCENT)

	hint = Widgets.label(gui, "마우스·WASD: 방향   Shift/Ctrl: 속도   F: 내리기", UDim2.fromOffset(460, 20), UDim2.new(0.5, -230, 1, -92), 15)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.TextStrokeTransparency = 0.5

	gui.Parent = playerGui
end

function FlightHUD.Show(mobile: boolean)
	hint.Visible = not mobile
	gui.Enabled = true
end

function FlightHUD.Hide()
	gui.Enabled = false
end

-- 화면 좌표(픽셀)와 보이는지 여부를 받아 표시를 옮긴다
function FlightHUD.SetMarks(aim: Vector2?, nose: Vector2?)
	aimMark.Visible = aim ~= nil
	noseMark.Visible = nose ~= nil
	if aim then
		aimMark.Position = UDim2.fromOffset(aim.X, aim.Y)
	end
	if nose then
		noseMark.Position = UDim2.fromOffset(nose.X, nose.Y)
	end
end

function FlightHUD.SetSpeed(speed: number, ratio: number)
	speedLabel.Text = `속도 {math.floor(speed + 0.5)}`
	speedBar.set(ratio)
end

return FlightHUD
