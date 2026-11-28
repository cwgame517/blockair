--!strict
-- 원정 섬 서버: 섬 블록 배열을 만들고 가진다 (서버는 배열만, 화면은 클라이언트가 그림).
-- 씨앗으로 섬을 만들기 때문에 클라이언트에는 씨앗과 "그동안 사라진 칸"만 보내면 된다.
local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local IslandGenerator = require(ReplicatedStorage.Shared.Island.IslandGenerator)
local IslandGrid = require(ReplicatedStorage.Shared.Island.IslandGrid)

local Islands = Config.Islands

local IslandService = {}

local grid: IslandGrid.Grid
local diameter = Islands.MVP_DIAMETER
local seed = 0
local checksum = 0
local removed: { number } = {} -- 지금까지 사라진 칸 번호 (늦게 들어온 사람에게 보냄)
local damaged: { [number]: number } = {} -- 금 간 칸 번호 → 균열 단계
local dataAsked: { [Player]: boolean } = {}

function IslandService:GetGrid(): IslandGrid.Grid
	return grid
end

-- 칸을 없애고 금 간 칸을 표시한 뒤 모두에게 알린다
function IslandService:Apply(removedNow: { number }, damagedIdx: { number }, damagedStage: { number })
	for _, idx in removedNow do
		grid:setIdx(idx, 0)
		damaged[idx] = nil
		table.insert(removed, idx)
	end
	for i, idx in damagedIdx do
		damaged[idx] = damagedStage[i]
	end
	if #removedNow > 0 or #damagedIdx > 0 then
		Net.event("BlocksChanged"):FireAllClients(removedNow, damagedIdx, damagedStage)
	end
end

local function airspaceRadius(): number
	return math.min(diameter * Islands.AIRSPACE_SCALE, Islands.AIRSPACE_MAX) * Islands.BLOCK_SIZE / 2
end

-- 출발 발판: 섬 남쪽 바깥, 섬을 바라보는 방향
local function buildSpawn()
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
	end
	for _, d in workspace:GetChildren() do
		if d:IsA("SpawnLocation") then
			d:Destroy()
		end
	end
	local z = -(diameter / 2 * Islands.BLOCK_SIZE + 70)
	local pos = Vector3.new(0, 30, z)
	local pad = Instance.new("Part")
	pad.Name = "LaunchPad"
	pad.Size = Vector3.new(30, 2, 30)
	pad.CFrame = CFrame.new(pos - Vector3.new(0, 1.5, 0))
	pad.Anchored = true
	pad.Color = Color3.fromRGB(70, 80, 95)
	pad.Material = Enum.Material.DiamondPlate
	pad.Parent = workspace
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "IslandSpawn"
	spawn.Size = Vector3.new(12, 1, 12)
	spawn.CFrame = CFrame.lookAt(pos, pos + Vector3.zAxis) -- 섬 쪽(+z)을 본다
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(80, 170, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = workspace
end

local function setupSky()
	Lighting.ClockTime = 14
	if not Lighting:FindFirstChildOfClass("Atmosphere") then
		local atm = Instance.new("Atmosphere")
		atm.Density = 0.3
		atm.Haze = 1
		atm.Color = Color3.fromRGB(200, 225, 255)
		atm.Decay = Color3.fromRGB(110, 150, 200)
		atm.Parent = Lighting
	end
	local terrain = workspace:FindFirstChildOfClass("Terrain")
	if terrain and not terrain:FindFirstChildOfClass("Clouds") then
		local clouds = Instance.new("Clouds")
		clouds.Cover = 0.5
		clouds.Density = 0.6
		clouds.Parent = terrain
	end
end

function IslandService:Init(_services)
	seed = if Islands.FIXED_SEED ~= 0 then Islands.FIXED_SEED else Random.new():NextInteger(1, 2 ^ 30)
	local t0 = os.clock()
	grid = IslandGenerator.generate(diameter, seed)
	local ms = math.floor((os.clock() - t0) * 1000 + 0.5)
	checksum = grid:checksum()
	print(`[Island] 섬 만들기 {ms}ms (지름 {diameter}, 씨앗 {seed})`)

	-- 비행 경계 (클라이언트 비행 코드가 읽음)
	ReplicatedStorage:SetAttribute("WorldRadius", airspaceRadius())
	ReplicatedStorage:SetAttribute("Ceiling", Islands.CEILING)
	ReplicatedStorage:SetAttribute("Floor", Islands.FLOOR)

	buildSpawn()
	setupSky()
end

function IslandService:Start()
	Net.func("GetIslandInfo").OnServerInvoke = function(_player: Player)
		local dIdx, dStage = {}, {}
		for idx, stage in damaged do
			table.insert(dIdx, idx)
			table.insert(dStage, stage)
		end
		return {
			diameter = diameter,
			seed = seed,
			checksum = checksum,
			removed = removed,
			damagedIdx = dIdx,
			damagedStage = dStage,
		}
	end
	-- 클라이언트가 만든 섬이 서버와 다를 때만 쓰는 예비 길 (한 사람당 한 번)
	Net.func("GetIslandData").OnServerInvoke = function(player: Player)
		if dataAsked[player] then
			return nil
		end
		dataAsked[player] = true
		warn(`[Island] {player.Name} 의 섬이 서버와 달라서 섬 배열을 통째로 보냅니다`)
		return { W = grid.W, H = grid.H, D = grid.D, data = grid.data }
	end
	Players.PlayerRemoving:Connect(function(player)
		dataAsked[player] = nil
	end)
end

return IslandService
