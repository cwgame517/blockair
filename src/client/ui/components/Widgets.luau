--!strict
-- 여러 화면이 같이 쓰는 UI 조각. 디자인은 8단계에서 다듬는다.
local Widgets = {}

Widgets.FONT = Enum.Font.GothamBold
Widgets.PANEL = Color3.fromRGB(20, 28, 44)
Widgets.ACCENT = Color3.fromRGB(80, 170, 255)
Widgets.GOLD = Color3.fromRGB(255, 205, 70)

function Widgets.corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
end

function Widgets.label(parent: Instance, text: string, size: UDim2, pos: UDim2, textSize: number?): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Widgets.FONT
	l.TextColor3 = Color3.new(1, 1, 1)
	l.TextSize = textSize or 18
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Size = size
	l.Position = pos
	l.Text = text
	l.Parent = parent
	return l
end

-- 가로 막대 게이지. set(0~1)로 채운다. fill 은 채워지는 막대 (색을 바꿀 때)
function Widgets.bar(parent: Instance, size: UDim2, pos: UDim2, color: Color3)
	local back = Instance.new("Frame")
	back.Size = size
	back.Position = pos
	back.BackgroundColor3 = Color3.fromRGB(45, 55, 75)
	back.BorderSizePixel = 0
	back.Parent = parent
	Widgets.corner(back, 6)
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = color
	fill.BorderSizePixel = 0
	fill.Parent = back
	Widgets.corner(fill, 6)
	return {
		fill = fill,
		set = function(ratio: number)
			fill.Size = UDim2.fromScale(math.clamp(ratio, 0, 1), 1)
		end,
	}
end

return Widgets
