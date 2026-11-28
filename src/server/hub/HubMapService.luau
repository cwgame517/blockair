--!strict
-- 허브 대용 맵. Studio 에서 만든 진짜 맵(workspace.HubMap)이 없을 때만 코드로 간단한 공항 섬을 만든다.
-- 나중에 Studio 에서 맵을 만들어 이름을 "HubMap" 으로 두면 이 코드는 아무것도 하지 않는다.
local Lighting = game:GetService("Lighting")

local HubMapService = {}

local map: Model

local function block(name: string, size: Vector3, pos: Vector3, color: Color3, material: Enum.Material, parent: Instance?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Position = pos
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent or map
	return p
end

local GRASS = Color3.fromRGB(106, 176, 76)
local DIRT = Color3.fromRGB(122, 88, 60)
local STONE = Color3.fromRGB(120, 120, 128)

-- 떠 있는 섬: 위는 잔디, 아래로 갈수록 좁아지는 흙·돌 층
local function floatingIsland(name: string, center: Vector3, width: number)
	local folder = Instance.new("Model")
	folder.Name = name
	folder.Parent = map
	block("Top", Vector3.new(width, 6, width), center + Vector3.new(0, -3, 0), GRASS, Enum.Material.Grass, folder)
	local layers = {
		{ 0.92, 10, DIRT, Enum.Material.Ground },
		{ 0.75, 14, STONE, Enum.Material.Slate },
		{ 0.55, 16, STONE, Enum.Material.Rock },
		{ 0.32, 18, DIRT, Enum.Material.Rock },
		{ 0.14, 16, STONE, Enum.Material.Slate },
	}
	local y = -6
	for i, l in layers do
		local w = width * (l[1] :: number)
		local h = (l[2] :: number) * width / 360
		h = math.max(h, 3)
		block("Layer" .. i, Vector3.new(w, h, w), center + Vector3.new(0, y - h / 2, 0), l[3] :: Color3, l[4] :: Enum.Material, folder)
		y -= h
	end
end

local function tree(pos: Vector3, rng: Random)
	local h = rng:NextInteger(6, 11)
	block("Trunk", Vector3.new(2, h, 2), pos + Vector3.new(0, h / 2, 0), Color3.fromRGB(110, 75, 45), Enum.Material.Wood)
	local s = rng:NextInteger(6, 9)
	block("Leaves", Vector3.new(s, s, s), pos + Vector3.new(0, h + s / 2 - 1, 0), Color3.fromRGB(60, 140, 60), Enum.Material.Grass)
end

-- 날아서 통과해 보는 네모 고리 (장식)
local function ring(center: Vector3, yaw: number, size: number)
	local model = Instance.new("Model")
	model.Name = "Ring"
	model.Parent = map
	local t = 3
	local color = Color3.fromRGB(255, 200, 60)
	local cf = CFrame.new(center) * CFrame.Angles(0, yaw, 0)
	local pieces = {
		{ Vector3.new(size, t, t), Vector3.new(0, size / 2, 0) },
		{ Vector3.new(size, t, t), Vector3.new(0, -size / 2, 0) },
		{ Vector3.new(t, size, t), Vector3.new(size / 2, 0, 0) },
		{ Vector3.new(t, size, t), Vector3.new(-size / 2, 0, 0) },
	}
	for i, pc in pieces do
		local p = block("Side" .. i, pc[1], Vector3.zero, color, Enum.Material.Neon, model)
		p.CFrame = cf * CFrame.new(pc[2])
		p.CanCollide = false
		p.CanQuery = false -- 비행기 충돌 피하기 검사에도 걸리지 않게 (통과용)
	end
end

local function build()
	map = Instance.new("Model")
	map.Name = "HubMap"

	-- 공항 섬 (가운데)
	floatingIsland("AirportIsland", Vector3.zero, 360)

	-- 활주로
	local runwayX = -90
	block("Runway", Vector3.new(36, 0.4, 280), Vector3.new(runwayX, 0.2, 0), Color3.fromRGB(55, 58, 64), Enum.Material.Asphalt)
	for z = -120, 120, 24 do
		block("Line", Vector3.new(1.2, 0.42, 10), Vector3.new(runwayX, 0.21, z), Color3.fromRGB(240, 240, 240), Enum.Material.SmoothPlastic)
	end

	-- 격납고 두 동 + 관제탑 (장식)
	for i, z in { -60, 10 } do
		local base = Vector3.new(-20, 0, z)
		block("Hangar" .. i, Vector3.new(34, 18, 44), base + Vector3.new(0, 9, 0), Color3.fromRGB(200, 205, 212), Enum.Material.Concrete)
		block("HangarDoor" .. i, Vector3.new(0.6, 14, 34), base + Vector3.new(-17.2, 7, 0), Color3.fromRGB(70, 90, 120), Enum.Material.CorrodedMetal)
	end
	block("Tower", Vector3.new(8, 30, 8), Vector3.new(30, 15, -110), Color3.fromRGB(220, 220, 225), Enum.Material.Concrete)
	block("TowerTop", Vector3.new(14, 8, 14), Vector3.new(30, 34, -110), Color3.fromRGB(150, 200, 230), Enum.Material.Glass).Transparency = 0.3

	-- 시작 위치
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HubSpawn"
	spawn.Size = Vector3.new(14, 1, 14)
	spawn.Position = Vector3.new(60, 0.5, 40)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(80, 170, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = map

	-- 나무 (항상 같은 자리에 나오도록 씨앗 고정)
	local rng = Random.new(517)
	for _ = 1, 26 do
		local x = rng:NextNumber(20, 165)
		local z = rng:NextNumber(-165, 165)
		if math.abs(x - 60) < 20 and math.abs(z - 40) < 20 then
			continue
		end
		tree(Vector3.new(x, 0, z), rng)
	end

	-- 주변의 작은 하늘 섬들
	for i = 1, 9 do
		local a = (i / 9) * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local r = rng:NextNumber(380, 720)
		local center = Vector3.new(math.cos(a) * r, rng:NextNumber(20, 220), math.sin(a) * r)
		floatingIsland("SkyIsland" .. i, center, rng:NextNumber(50, 110))
	end

	-- 비행 연습용 고리
	for i = 1, 8 do
		local a = (i / 8) * math.pi * 2
		local r = 260
		ring(Vector3.new(math.cos(a) * r, 70 + math.sin(a * 2) * 40, math.sin(a) * r), -a, 34)
	end

	map.Parent = workspace
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
		clouds.Cover = 0.55
		clouds.Density = 0.6
		clouds.Parent = terrain
	end
end

function HubMapService:Init(_services)
	if workspace:FindFirstChild("HubMap") then
		return
	end
	-- 새 플레이스 기본 바닥(Baseplate)이 있으면 치운다: 공항 섬과 겹치기 때문
	local baseplate = workspace:FindFirstChild("Baseplate")
	if baseplate then
		baseplate:Destroy()
		local defaultSpawn = workspace:FindFirstChild("SpawnLocation")
		if defaultSpawn then
			defaultSpawn:Destroy()
		end
	end
	build()
	setupSky()
end

return HubMapService
