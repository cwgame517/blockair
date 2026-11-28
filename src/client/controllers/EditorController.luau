--!strict
-- 허브 에디터 (4단계). 내 조립 자리 근처를 걸으면 에디터 화면이 뜨고,
-- 전시된 비행기의 칸을 누르면(PC 클릭·모바일 탭) 고른 블록으로 채운다. 대칭 칸은 같이 바뀐다.
-- 키오스크(또는 [부위 교체] 버튼)로 부위 교체 화면을 연다 (레벨 5).
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local PlaneBuilder = require(ReplicatedStorage.Shared.PlaneBuilder)
local PlaneStats = require(ReplicatedStorage.Shared.PlaneStats)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local getPlaceKind = require(script.Parent.Parent.util.PlaceKind)

local Editor = Config.Editor
local player = Players.LocalPlayer

local EditorController = {}
EditorController.ZoneChanged = Signal.new() -- (inZone: boolean) 에디터 화면이 뜨면 허브 버튼을 숨기려고

local FlightController: any
local Panel: any
local Parts: any

local state: any = nil
local lastStats: any = nil
local inZone = false
local busy = false
local hoverBoxes: { SelectionBox } = {}

local function myPad(): Model?
	local i = player:GetAttribute("EditorPad")
	local folder = workspace:FindFirstChild("EditorPads")
	if typeof(i) ~= "number" or not folder then
		return nil
	end
	return folder:FindFirstChild("Pad_" .. i) :: Model?
end

local function padCenter(pad: Model): Vector3
	local base = pad:FindFirstChild("Base") :: BasePart?
	return if base then base.Position else pad:GetPivot().Position
end

local function showStats()
	if not state then
		return
	end
	local stats = PlaneStats.compute(state.design)
	Panel.SetStats(stats, PlaneStats.bars(stats, state.design.frameId), lastStats)
	lastStats = stats
end

local function setState(s: any)
	if not s then
		return
	end
	state = s
	Panel.SetState(s)
	showStats()
	if Parts.IsOpen() then
		Parts.Update(s)
	end
end

local function fetch()
	local ok, s = pcall(function()
		return Net.func("GetEditor"):InvokeServer()
	end)
	if ok and s then
		setState(s)
	end
end

-- 서버에 편집 요청 → 새 상태 (실패하면 nil)
local function send(op: any): any?
	if busy then
		return nil
	end
	busy = true
	local ok, r = pcall(function()
		return Net.func("EditPlane"):InvokeServer(op)
	end)
	busy = false
	if not ok or not r then
		Panel.Toast("잠시 후 다시 해 주세요", true)
		return nil
	end
	if r.msg then
		Panel.Toast(r.msg, r.warn)
	end
	setState(r.state)
	return if r.ok then r.state else nil
end

-- 화면 위치에서 광선을 쏴서 내 전시 비행기의 칸을 찾는다
local function cellAt(screenPos: Vector2): BasePart?
	local pad = myPad()
	local display = pad and pad:FindFirstChild("Display")
	if not display then
		return nil
	end
	local camera = workspace.CurrentCamera
	local ray = camera:ViewportPointToRay(screenPos.X, screenPos.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { display }
	local hit = workspace:Raycast(ray.Origin, ray.Direction * 300, params)
	if hit and hit.Instance:GetAttribute("Cell") then
		return hit.Instance :: BasePart
	end
	return nil
end

local function onPress(screenPos: Vector2)
	if not inZone or not state or Parts.IsOpen() then
		return
	end
	local cell = cellAt(screenPos)
	if not cell then
		return
	end
	local key = cell:GetAttribute("Cell") :: string
	local part = cell:GetAttribute("Part") :: string
	local mode = Panel.GetMode()
	if mode == "paint" then
		send({ op = "color", part = part, hex = Panel.GetColor() })
	elseif mode == "shape" then
		-- 같은 모양을 다시 누르면 다음 방향으로 돌린다
		local want = Panel.GetShape()
		local cur, rot = PlaneBuilder.cellShape(state.design, key, PlaneBuilder.frameShapeOf(state.design, key))
		local nextRot = if cur == want then (rot + 1) % Config.BlockShapes.ROTATIONS else 0
		send({ op = "shape", key = key, shape = `{want}:{nextRot}` })
	elseif mode == "paintCell" then
		send({ op = "paintCell", key = key, hex = Panel.GetColor() })
	elseif mode == "fill" then
		send({ op = "fill", part = part, block = Panel.GetBlock() })
	else
		send({ op = "cell", key = key, block = Panel.GetBlock() })
	end
end

-- PC: 마우스가 올라간 칸(대칭 칸 포함, 부위 모드면 부위 전체)을 테두리로 보여 준다
local function clearHover()
	for _, b in hoverBoxes do
		b.Adornee = nil
	end
end

local function updateHover()
	clearHover()
	if not inZone or Parts.IsOpen() or UserInputService.TouchEnabled and not UserInputService.MouseEnabled then
		return
	end
	local cell = cellAt(UserInputService:GetMouseLocation())
	if not cell or not cell.Parent then
		return
	end
	local mode = Panel.GetMode()
	local key, part = cell:GetAttribute("Cell"), cell:GetAttribute("Part")
	local n = 0
	for _, p in (cell.Parent :: Instance):GetChildren() do
		if p:IsA("BasePart") and p:GetAttribute("Cell") then
			local match = if mode == "cell" or mode == "paintCell" or mode == "shape" then p:GetAttribute("Cell") == key else p:GetAttribute("Part") == part
			if match then
				n += 1
				local box = hoverBoxes[n]
				if not box then
					box = Instance.new("SelectionBox")
					box.Color3 = Color3.fromRGB(255, 205, 70)
					box.LineThickness = 0.08
					box.Parent = workspace
					hoverBoxes[n] = box
				end
				box.Adornee = p
			end
		end
	end
end

local function openParts()
	local pad = myPad()
	if not pad or not state or Parts.IsOpen() then
		return
	end
	if state.level < Editor.PARTS_LEVEL then
		Panel.Toast(`부위 교체는 레벨 {Editor.PARTS_LEVEL}에 열려요`, true)
		return
	end
	local display = pad:FindFirstChild("Display") :: Model?
	local cell = Config.Flight.CELL_SIZE * Editor.DISPLAY_SCALE
	local pivot = if display then display:GetPivot() else CFrame.new(padCenter(pad))
	Panel.Hide()
	clearHover()
	Parts.Open({
		pad = pad,
		pivot = pivot,
		cellSize = cell,
		state = state,
		onApply = function(parts)
			return send({ op = "parts", parts = parts })
		end,
		onColor = function(part, hex)
			return send({ op = "color", part = part, hex = hex })
		end,
		onClose = function()
			if inZone then
				Panel.Show()
			end
		end,
	})
end

-- 허브의 [내 비행기] 버튼: 내 조립 자리 앞으로 걸어가 있게 옮겨 준다
function EditorController:GoToPad()
	local pad = myPad()
	local char = player.Character
	if not pad or not char then
		return
	end
	if FlightController:IsFlying() then
		FlightController:RequestToggle()
		task.wait(1)
	end
	local center = padCenter(pad)
	local stand = center + Vector3.new(0, 4, -Editor.PAD_SIZE / 2 - 2)
	char:PivotTo(CFrame.lookAt(stand, Vector3.new(center.X, stand.Y, center.Z)))
end

local function checkZone()
	local pad = myPad()
	local char = player.Character
	local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	local now = false
	if pad and hrp and not FlightController:IsFlying() then
		local d = hrp.Position - padCenter(pad)
		now = Vector3.new(d.X, 0, d.Z).Magnitude < Editor.EDIT_RANGE and math.abs(d.Y) < 40
	end
	if now == inZone then
		return
	end
	inZone = now
	if now then
		Panel.ResetSelection()
		lastStats = nil
		Panel.Show()
		fetch()
	else
		Panel.Hide()
		clearHover()
		if Parts.IsOpen() then
			Parts.Close()
		end
	end
	EditorController.ZoneChanged:Fire(now)
end

function EditorController:InZone(): boolean
	return inZone
end

function EditorController:Init(controllers)
	FlightController = controllers.FlightController
end

function EditorController:Start()
	if getPlaceKind() ~= "hub" then
		return
	end
	local ui = script.Parent.Parent:WaitForChild("ui")
	Panel = require(ui:WaitForChild("EditorPanel") :: ModuleScript) :: any
	Parts = require(ui:WaitForChild("PartsScreen") :: ModuleScript) :: any
	local playerGui = player:WaitForChild("PlayerGui")
	Panel.Mount(playerGui)
	Parts.Mount(playerGui)

	Panel.Action:Connect(function(name: string, arg: any)
		if name == "auto" or name == "clear" then
			send({ op = name })
		elseif name == "weapon" then
			send({ op = "weapon", id = arg })
		elseif name == "frame" then
			send({ op = "frame", id = arg })
		elseif name == "slot" then
			send({ op = "slot", index = arg })
		elseif name == "parts" then
			openParts()
		elseif name == "fly" then
			FlightController:RequestToggle()
		end
	end)
	FlightController.FlyingChanged:Connect(function(flying: boolean)
		Panel.SetFlying(flying)
		checkZone()
	end)
	Net.event("EditorState").OnClientEvent:Connect(setState)

	-- 누르기: PC 는 왼쪽 클릭, 모바일은 화면 탭 (버튼을 누른 건 무시)
	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then
			return
		end
		if input.UserInputType == Enum.UserInputType.MouseButton1 then
			onPress(UserInputService:GetMouseLocation()) -- 화면 위 메뉴 줄까지 포함한 좌표 (ViewportPointToRay 와 맞음)
		end
	end)
	UserInputService.TouchTapInWorld:Connect(function(pos: Vector2, processedByUI: boolean)
		if not processedByUI then
			onPress(pos)
		end
	end)

	-- 키오스크: 내 자리 것만 켠다
	local function hookPrompt()
		local pad = myPad()
		local kiosk = pad and pad:FindFirstChild("Kiosk")
		local prompt = kiosk and kiosk:FindFirstChild("PartsPrompt") :: ProximityPrompt?
		if prompt then
			prompt.Enabled = true
		end
	end
	player:GetAttributeChangedSignal("EditorPad"):Connect(hookPrompt)
	task.spawn(function()
		local folder = workspace:WaitForChild("EditorPads", 30)
		if folder then
			hookPrompt()
			folder.DescendantAdded:Connect(function(d)
				if d.Name == "PartsPrompt" then
					hookPrompt()
				end
			end)
		end
	end)
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
		local pad = myPad()
		if prompt.Name == "PartsPrompt" and pad and prompt:IsDescendantOf(pad) then
			openParts()
		end
	end)

	local acc = 0
	RunService.RenderStepped:Connect(function(dt)
		acc += dt
		if acc >= 0.2 then
			acc = 0
			checkZone()
		end
		updateHover()
	end)
end

return EditorController
