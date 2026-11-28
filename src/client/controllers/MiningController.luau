--!strict
-- (원정 섬에서만) 채굴 폭탄 조작과 연출.
--   - 비행 중 땅에 폭탄이 떨어질 곳에 원을 그린다 (착탄 원)
--   - Space / 폭탄 버튼 → 서버에 요청. 판정은 서버가 한다.
--   - 폭탄이 떨어지는 모습·폭발은 모두에게, 부서진 블록이 내 비행기로 날아오는 모습은 캔 사람에게만
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local BlockInfo = require(ReplicatedStorage.Shared.Island.BlockInfo)
local Trajectory = require(ReplicatedStorage.Shared.Island.Trajectory)
local getPlaceKind = require(script.Parent.Parent.util.PlaceKind)

local Mining = Config.Mining
local Upgrades = Config.Upgrades
local MAX_LOOT_CUBES = 40 -- 한 번에 날아오는 블록 모습 최대 개수 (많으면 화면이 느려짐)

local MiningController = {}
MiningController.CooldownStarted = Signal.new() -- (seconds)

local FlightController: any
local InputController: any
local IslandController: any

local stats = {
	radius = Upgrades.ITEMS.bombRadius.values[1],
	reload = Upgrades.ITEMS.bombReload.values[1],
	power = 1,
}
local readyAt = 0
local fxFolder: Folder

local function fxPart(size: Vector3, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = false
	p.Size = size
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

function MiningController:Drop()
	if not FlightController:IsFlying() or not IslandController:GetGrid() then
		return
	end
	local now = os.clock()
	if now < readyAt then
		return
	end
	readyAt = now + stats.reload
	Net.event("BombDrop"):FireServer()
	MiningController.CooldownStarted:Fire(stats.reload)
end

-- 착탄 원: 매 프레임 내 비행기에서 폭탄 궤도를 계산해 땅 위에 원판을 놓는다
local function startPreview()
	local disc = fxPart(Vector3.new(0.3, 1, 1), Color3.new(1, 1, 1), Enum.Material.Neon)
	disc.Shape = Enum.PartType.Cylinder
	disc.Transparency = 1
	disc.Parent = fxFolder
	RunService.RenderStepped:Connect(function()
		local plane = FlightController:GetPlane()
		local root = plane and plane.PrimaryPart
		local grid = IslandController:GetGrid()
		if not root or not grid then
			disc.Transparency = 1
			return
		end
		local start, vel = Trajectory.launch(root.Position, root.AssemblyLinearVelocity)
		local hit = Trajectory.impact(grid, start, vel)
		if not hit then
			disc.Transparency = 1
			return
		end
		local _, cy, _ = grid:toCell(hit)
		local topY = grid.corner.Y + (cy + 1) * grid.BS
		local size = stats.radius * grid.BS * 2
		disc.Size = Vector3.new(0.3, size, size)
		disc.CFrame = CFrame.new(hit.X, topY + 0.3, hit.Z) * CFrame.Angles(0, 0, math.rad(90))
		local ready = os.clock() >= readyAt
		disc.Color = if ready then Color3.fromRGB(255, 255, 255) else Color3.fromRGB(150, 150, 150)
		disc.Transparency = if ready then 0.55 else 0.8
	end)
end

-- 폭탄이 떨어지는 모습 (모든 사람 화면)
local function showBomb(start: Vector3, vel: Vector3)
	local grid = IslandController:GetGrid()
	local _, endT = Trajectory.impact(grid, start, vel)
	local ball = fxPart(Vector3.one * 1.6, Color3.fromRGB(30, 30, 36), Enum.Material.SmoothPlastic)
	ball.Shape = Enum.PartType.Ball
	ball.CFrame = CFrame.new(start)
	ball.Parent = fxFolder
	local t = 0
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function(dt)
		t += dt
		if t >= endT then
			conn:Disconnect()
			ball:Destroy()
			return
		end
		ball.CFrame = CFrame.new(Trajectory.at(start, vel, t))
	end)
end

local function showExplosion(pos: Vector3, radiusStuds: number)
	local e = Instance.new("Explosion")
	e.Position = pos
	e.BlastRadius = radiusStuds
	e.BlastPressure = 0 -- 연출만: 아무것도 밀거나 부수지 않음
	e.DestroyJointRadiusPercent = 0
	e.ExplosionType = Enum.ExplosionType.NoCraters
	e.Parent = workspace
end

-- 내가 캔 블록이 비행기로 빨려 들어오는 모습. ok=false 면 빨갛게 변하며 사라짐 (화물칸 가득)
local function showLoot(items: { any })
	local grid = IslandController:GetGrid()
	if not grid then
		return
	end
	for n, it in items do
		if n > MAX_LOOT_CUBES then
			break
		end
		local idx, id, ok = it[1], it[2], it[3]
		local info = BlockInfo.byId[id]
		local x, y, z = grid:coords(idx)
		local from = grid:cellCenter(x, y, z)
		local cube = fxPart(Vector3.one * grid.BS * 0.5, if info then info.color else Color3.new(1, 1, 1), if info then info.material else Enum.Material.SmoothPlastic)
		cube.CFrame = CFrame.new(from)
		cube.Parent = fxFolder
		if not ok then
			cube.Color = Color3.fromRGB(230, 60, 60)
			local tw = TweenService:Create(cube, TweenInfo.new(0.7), { Transparency = 1, Size = Vector3.one * 0.3 })
			tw.Completed:Connect(function()
				cube:Destroy()
			end)
			tw:Play()
			continue
		end
		-- 잠깐 위로 튀었다가 비행기로 날아온다
		local t = 0
		local pop = from + Vector3.new(math.random(-3, 3), 4, math.random(-3, 3))
		local conn: RBXScriptConnection
		conn = RunService.RenderStepped:Connect(function(dt)
			t += dt
			local a = math.clamp(t / Mining.COLLECT_DELAY, 0, 1)
			local plane = FlightController:GetPlane()
			local target = if plane and plane.PrimaryPart then plane.PrimaryPart.Position else pop
			local mid = from:Lerp(pop, math.min(1, a * 3))
			cube.CFrame = CFrame.new(mid:Lerp(target, a * a)) * CFrame.Angles(t * 6, t * 4, 0)
			cube.Size = Vector3.one * grid.BS * 0.5 * (1 - 0.6 * a)
			if a >= 1 then
				conn:Disconnect()
				cube:Destroy()
			end
		end)
	end
end

function MiningController:Init(controllers)
	FlightController = controllers.FlightController
	InputController = controllers.InputController
	IslandController = controllers.IslandController
end

function MiningController:Start()
	if getPlaceKind() ~= "island" then
		return
	end
	fxFolder = Instance.new("Folder")
	fxFolder.Name = "MiningFX"
	fxFolder.Parent = workspace

	Net.event("MiningStats").OnClientEvent:Connect(function(s)
		stats.radius, stats.reload, stats.power = s.radius, s.reload, s.power
	end)
	InputController.BombPressed:Connect(function()
		MiningController:Drop()
	end)

	IslandController:WaitGrid()
	startPreview()
	Net.event("BombDropped").OnClientEvent:Connect(function(_ownerId: number, start: Vector3, vel: Vector3)
		showBomb(start, vel)
	end)
	Net.event("BombExploded").OnClientEvent:Connect(showExplosion)
	Net.event("BlockLoot").OnClientEvent:Connect(showLoot)
end

return MiningController
