--!strict
-- 원정 섬 격납고 4곳: 섬 가장자리 바깥 동서남북에 섬 크기에 맞춰 놓는다.
-- 하는 일 세 가지: 화물 맡기기(빛나는 구역에 들어가면 바로), 무료 수리(구역 안에서 3초), 재출격 지점(스폰).
-- 착륙은 필요 없다. 날아서 들어가거나 제자리 비행으로 머물면 된다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Hangars = Config.Hangars
local Islands = Config.Islands

local HangarService = {}

type State = { inside: boolean, repairStart: number? }

local IslandService: any
local PlaneService: any
local CargoService: any
local centers: { Vector3 } = {} -- 각 격납고 발판 윗면 가운데
local states: { [Player]: State } = {}

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- 격납고 하나: 발판 + 바깥쪽 작은 건물 + 스폰 + 빛나는 원기둥 + 멀리서도 보이는 이름표
local function buildOne(index: number, center: Vector3, folder: Instance)
	local model = Instance.new("Model")
	model.Name = "Hangar" .. index
	model.Parent = folder

	local toIsland = (Vector3.new(0, center.Y, 0) - center).Unit
	local facing = CFrame.lookAt(center, center + toIsland) -- 섬 쪽을 본다
	local s = Hangars.PAD_SIZE

	part("Pad", Vector3.new(s, 3, s), facing * CFrame.new(0, -1.5, 0), Color3.fromRGB(70, 80, 95), Enum.Material.DiamondPlate, model)
	part("Base", Vector3.new(s * 0.7, 10, s * 0.7), facing * CFrame.new(0, -8, 0), Color3.fromRGB(110, 90, 70), Enum.Material.Rock, model)
	-- 섬 반대쪽(뒤)에 지붕 있는 작은 건물
	local back = facing * CFrame.new(0, 0, s / 2 - 5)
	part("WallL", Vector3.new(1.5, 14, 10), back * CFrame.new(-s / 2 + 1, 7, 0), Color3.fromRGB(200, 205, 215), Enum.Material.Metal, model)
	part("WallR", Vector3.new(1.5, 14, 10), back * CFrame.new(s / 2 - 1, 7, 0), Color3.fromRGB(200, 205, 215), Enum.Material.Metal, model)
	part("WallBack", Vector3.new(s, 14, 1.5), back * CFrame.new(0, 7, 4.5), Color3.fromRGB(200, 205, 215), Enum.Material.Metal, model)
	part("Roof", Vector3.new(s + 2, 1.5, 12), back * CFrame.new(0, 14.5, 0), Color3.fromRGB(230, 120, 50), Enum.Material.Metal, model)

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "HangarSpawn"
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = facing * CFrame.new(0, 0.5, -4)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(80, 170, 255)
	spawn.Material = Enum.Material.SmoothPlastic
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = model

	-- 빛나는 원기둥 (Roblox 원기둥은 X 축이 길이 방향이라 세워서 놓는다)
	local r, h = Hangars.ZONE_RADIUS, Hangars.ZONE_HEIGHT
	local upright = CFrame.Angles(0, 0, math.pi / 2)
	local zone = part("Zone", Vector3.new(h, r * 2, r * 2), CFrame.new(center + Vector3.new(0, h / 2, 0)) * upright, Hangars.ZONE_COLOR, Enum.Material.ForceField, model)
	zone.Shape = Enum.PartType.Cylinder
	zone.Transparency = 0.3
	local ring = part("Ring", Vector3.new(0.6, r * 2, r * 2), CFrame.new(center + Vector3.new(0, 0.4, 0)) * upright, Hangars.ZONE_COLOR, Enum.Material.Neon, model)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.6
	for _, p in { zone, ring } do
		p.CanCollide = false
		p.CanQuery = false -- 비행기 충돌 피하기 검사·폭탄 조준에 걸리지 않게
		p.CanTouch = false
		p.CastShadow = false
	end

	local tag = Instance.new("BillboardGui")
	tag.Name = "Tag"
	tag.Size = UDim2.fromOffset(160, 40)
	tag.StudsOffsetWorldSpace = Vector3.new(0, h + 6, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 5000
	tag.LightInfluence = 0
	tag.Adornee = zone
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextColor3 = Hangars.ZONE_COLOR
	label.TextStrokeTransparency = 0.3
	label.Text = "격납고"
	label.Parent = tag
	tag.Parent = zone
end

local function build()
	local folder = Instance.new("Folder")
	folder.Name = "Hangars"
	folder.Parent = workspace
	-- 섬 가장자리(들쭉날쭉한 만큼 여유) + GAP 만큼 바깥
	local edge = IslandService:GetDiameter() / 2 * Islands.BLOCK_SIZE * (1 + Islands.EDGE_WOBBLE)
	local dist = edge + Hangars.GAP
	for i = 1, Hangars.COUNT do
		local a = (i - 1) / Hangars.COUNT * math.pi * 2
		local c = Vector3.new(math.sin(a) * dist, Hangars.PAD_Y, math.cos(a) * dist)
		centers[i] = c
		buildOne(i, c, folder)
	end
end

local function inZone(pos: Vector3): boolean
	for _, c in centers do
		local dx, dz = pos.X - c.X, pos.Z - c.Z
		if dx * dx + dz * dz <= Hangars.ZONE_RADIUS ^ 2 and pos.Y >= c.Y - 4 and pos.Y <= c.Y + Hangars.ZONE_HEIGHT then
			return true
		end
	end
	return false
end

local function stopRepair(player: Player, st: State)
	if st.repairStart then
		st.repairStart = nil
		Net.event("Hangar"):FireClient(player, "repairStop")
	end
end

local function tick()
	local now = os.clock()
	for _, player in Players:GetPlayers() do
		local st = states[player]
		if not st then
			st = { inside = false, repairStart = nil }
			states[player] = st
		end
		local model = PlaneService:Get(player)
		local root = model and model.PrimaryPart
		local inside = root ~= nil and inZone(root.Position)
		if not inside then
			st.inside = false
			stopRepair(player, st)
			continue
		end
		st.inside = true

		-- 화물 맡기기: 구역 안에 있는 동안 화물이 생기면 바로 맡긴다
		if CargoService:GetCount(player) > 0 then
			local n = CargoService:Deposit(player)
			if n > 0 then
				Net.event("Hangar"):FireClient(player, "deposit", n)
			end
		end

		-- 수리: HP 가 덜 찼고, 맞은 지 5초가 지났으면 3초 뒤 가득
		local hp, maxHp, lastHit = PlaneService:GetHp(player)
		if not hp or not maxHp or not lastHit or hp >= maxHp then
			stopRepair(player, st)
			continue
		end
		if now - lastHit < Hangars.NO_REPAIR_AFTER_HIT or (st.repairStart and lastHit > st.repairStart) then
			stopRepair(player, st)
			continue
		end
		if not st.repairStart then
			st.repairStart = now
			Net.event("Hangar"):FireClient(player, "repairStart", Hangars.REPAIR_TIME)
		elseif now - st.repairStart >= Hangars.REPAIR_TIME then
			st.repairStart = nil
			PlaneService:Repair(player)
			Net.event("Hangar"):FireClient(player, "repairDone")
		end
	end
end

function HangarService:Init(services)
	IslandService = services.IslandService
	PlaneService = services.PlaneService
	CargoService = services.CargoService
end

function HangarService:Start()
	build()
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= Hangars.CHECK_INTERVAL then
			acc = 0
			tick()
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return HangarService
