--!strict
-- 비행기 소환·회수, 조종 권한(네트워크 소유권)을 조종자에게 넘기기, 속도 감시.
-- 비행기는 workspace.Planes 폴더에 들어가고, 모델 속성 OwnerId 로 주인을 안다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local PlaneBuilder = require(ReplicatedStorage.Shared.PlaneBuilder)
local PlaneStats = require(ReplicatedStorage.Shared.PlaneStats)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local Flight = Config.Flight
local CHECK_INTERVAL = 0.5

local PlaneService = {}
PlaneService.Spawned = Signal.new() -- (player, model, stats)
PlaneService.Despawned = Signal.new() -- (player)

type Entry = { model: Model, seat: Seat, stats: any, maxSpeed: number, strikes: number, unseated: number }

local DataService: any
local folder: Folder
local planes: { [Player]: Entry } = {}
local lastRequest: { [Player]: number } = {}
local speedMul = 1 -- Studio 테스트 명령 /speed 로 바꾸는 속도 배율

local function humanoidOf(player: Player): (Humanoid?, BasePart?)
	local char = player.Character
	if not char then
		return nil, nil
	end
	local hum = char:FindFirstChildOfClass("Humanoid")
	local hrp = char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not hum or hum.Health <= 0 or not hrp then
		return nil, nil
	end
	return hum, hrp
end

-- 저장된 비행기가 있으면 그것, 없으면 기본 비행기
local function designOf(player: Player): any
	local data = DataService and DataService:Get(player)
	local saved = data and data.planes and data.planes[data.activePlane]
	return saved or Config.FrameShapes.DEFAULT_DESIGN
end

-- 내릴 때 돌아갈 곳: 맵의 SpawnLocation
local function homeCFrame(): CFrame?
	for _, d in workspace:GetDescendants() do
		if d:IsA("SpawnLocation") and d.Enabled then
			return d.CFrame + Vector3.new(0, 4, 0)
		end
	end
	return nil
end

function PlaneService:Despawn(player: Player, sendHome: boolean)
	local entry = planes[player]
	if not entry then
		return
	end
	planes[player] = nil
	PlaneService.Despawned:Fire(player)
	local hum, hrp = humanoidOf(player)
	if hum then
		hum.Sit = false
	end
	entry.model:Destroy()
	if sendHome and hrp and player.Character then
		local home = homeCFrame()
		if home then
			player.Character:PivotTo(home)
			hrp.AssemblyLinearVelocity = Vector3.zero
			hrp.AssemblyAngularVelocity = Vector3.zero
		end
	end
end

function PlaneService:Spawn(player: Player): boolean
	if planes[player] then
		return false
	end
	local hum, hrp = humanoidOf(player)
	if not hum or not hrp then
		return false
	end

	local design = PlaneBuilder.sanitize(designOf(player))
	local stats = PlaneStats.compute(design)
	stats.maxSpeed *= speedMul
	stats.minSpeed *= speedMul
	local model = PlaneBuilder.build(design)
	model.Name = player.Name .. "_Plane"
	model:SetAttribute("OwnerId", player.UserId)
	model:SetAttribute("MaxSpeed", stats.maxSpeed)
	model:SetAttribute("MinSpeed", stats.minSpeed)
	model:SetAttribute("TurnRate", stats.turnRate)

	-- 서 있는 곳 위, 바라보는 방향(수평)으로 놓는다
	local look = hrp.CFrame.LookVector * Vector3.new(1, 0, 1)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, -1)
	end
	local pos = hrp.Position + Vector3.new(0, Flight.SPAWN_HEIGHT, 0)
	local cf = CFrame.lookAt(pos, pos + look.Unit)
	model:PivotTo(cf)
	local root = model.PrimaryPart :: BasePart
	local steer = root:FindFirstChild("Steer") :: AlignOrientation
	steer.CFrame = cf.Rotation
	model.Parent = folder

	local seat = model:FindFirstChild("Seat") :: Seat
	seat:Sit(hum)
	root:SetNetworkOwner(player)

	planes[player] = { model = model, seat = seat, stats = stats, maxSpeed = stats.maxSpeed, strikes = 0, unseated = 0 }
	PlaneService.Spawned:Fire(player, model, stats)
	return true
end

local function onRequest(player: Player, want: any)
	if typeof(want) ~= "boolean" then
		return
	end
	local now = os.clock()
	if now - (lastRequest[player] or 0) < Flight.REQUEST_COOLDOWN then
		return
	end
	lastRequest[player] = now
	if want then
		PlaneService:Spawn(player)
	else
		PlaneService:Despawn(player, true)
	end
end

-- 0.5초마다: 너무 빠르면 경고 누적, 조종석에서 떨어졌으면 회수
local function check()
	local limitPad = 10
	for player, entry in planes do
		local root = entry.model.PrimaryPart
		local hum = humanoidOf(player)
		if not root or not root.Parent or not hum then
			PlaneService:Despawn(player, false)
			continue
		end
		if hum.SeatPart ~= entry.seat then
			entry.unseated += 1
			if entry.unseated >= 2 then
				PlaneService:Despawn(player, false)
				continue
			end
		else
			entry.unseated = 0
		end
		local limit = entry.maxSpeed * Flight.SPEED_TOLERANCE + limitPad
		if root.AssemblyLinearVelocity.Magnitude > limit then
			entry.strikes += 1
			if entry.strikes >= Flight.SPEED_STRIKES then
				warn(`[PlaneService] {player.Name} 속도 초과로 비행기 회수`)
				PlaneService:Despawn(player, true)
			end
		else
			entry.strikes = math.max(0, entry.strikes - 1)
		end
	end
end

-- 속도 배율 바꾸기 (테스트용). 지금 날고 있는 비행기에도 바로 적용된다.
function PlaneService:SetSpeedPercent(percent: number)
	local newMul = math.clamp(percent, 10, 300) / 100
	local ratio = newMul / speedMul
	speedMul = newMul
	for _, entry in planes do
		entry.maxSpeed *= ratio
		local m = entry.model
		m:SetAttribute("MaxSpeed", (m:GetAttribute("MaxSpeed") :: number) * ratio)
		m:SetAttribute("MinSpeed", (m:GetAttribute("MinSpeed") :: number) * ratio)
	end
end

-- 지금 타고 있는 비행기와 능력치 (없으면 nil)
function PlaneService:Get(player: Player): (Model?, any)
	local entry = planes[player]
	if not entry then
		return nil, nil
	end
	return entry.model, entry.stats
end

function PlaneService:GetSpeedPercent(): number
	return math.floor(speedMul * 100 + 0.5)
end

function PlaneService:Init(services)
	DataService = services.DataService
end

function PlaneService:Start()
	folder = Instance.new("Folder")
	folder.Name = "Planes"
	folder.Parent = workspace

	Net.event("PlaneRequest").OnServerEvent:Connect(onRequest)

	local function hookCharacter(player: Player, char: Model)
		local hum = char:WaitForChild("Humanoid", 10) :: Humanoid?
		if hum then
			hum.Died:Connect(function()
				PlaneService:Despawn(player, false)
			end)
		end
	end
	local function hookPlayer(player: Player)
		player.CharacterAdded:Connect(function(char)
			hookCharacter(player, char)
		end)
		player.CharacterRemoving:Connect(function()
			PlaneService:Despawn(player, false)
		end)
		if player.Character then
			task.spawn(hookCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hookPlayer)
	for _, p in Players:GetPlayers() do
		hookPlayer(p)
	end
	Players.PlayerRemoving:Connect(function(player)
		PlaneService:Despawn(player, false)
		lastRequest[player] = nil
	end)

	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= CHECK_INTERVAL then
			acc = 0
			check()
		end
	end)
end

return PlaneService
