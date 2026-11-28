--!strict
-- 화물칸: 캔 몸통 블록이 들어가는 곳. 가득 차면 더 못 담고 블록은 사라진다.
-- 보물(금광석·보석)은 화물칸 대신 바로 코인, 연료 블록(석탄·석유·우라늄)은 연료 저장분으로 (FuelService).
-- 비행기 아래에 작은 상자가 매달려 차오를수록 커지고, 가득 차면 금빛이 된다 (남들도 보임).
-- 격납고의 빛나는 구역에 들어가면 화물이 창고(저장 데이터 inventory)로 맡겨진다 (HangarService).
-- 맡기지 않고 허브로 돌아가거나 게임을 나가면 화물은 사라진다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local BlockInfo = require(ReplicatedStorage.Shared.Island.BlockInfo)

local Upgrades = Config.Upgrades
local FULL_WARN_INTERVAL = 4

local CargoService = {}

type Cargo = { count: number, items: { [number]: number }, box: BasePart?, weld: Weld?, warnedAt: number }

local DataService: any
local PlaneService: any
local ProgressService: any
local ExpeditionService: any
local FuelService: any
local cargo: { [Player]: Cargo } = {}

local function stateOf(player: Player): Cargo
	local c = cargo[player]
	if not c then
		c = { count = 0, items = {}, box = nil, weld = nil, warnedAt = 0 }
		cargo[player] = c
	end
	return c
end

function CargoService:GetCap(player: Player): number
	local data = DataService:Get(player)
	local values = Upgrades.ITEMS.cargo.values
	local step = data and data.upgrades and data.upgrades.cargo or 1
	return values[math.clamp(step, 1, #values)]
end

-- 비행기 아래 상자 크기·색을 화물 양에 맞춘다
local function updateBox(player: Player, c: Cargo)
	local box, weld = c.box, c.weld
	if not box or not weld or not box.Parent then
		return
	end
	local cap = CargoService:GetCap(player)
	local ratio = math.clamp(c.count / cap, 0, 1)
	local s = 1.4 + 2.6 * ratio
	box.Size = Vector3.new(s, s * 0.8, s * 1.2)
	weld.C0 = CFrame.new(0, -3.2 - s * 0.4, 1.5)
	local full = c.count >= cap
	box.Color = if full then Color3.fromRGB(255, 200, 50) else Color3.fromRGB(150, 105, 60)
	box.Material = if full then Enum.Material.Foil else Enum.Material.WoodPlanks
end

local function push(player: Player)
	local c = stateOf(player)
	Net.event("CargoChanged"):FireClient(player, { count = c.count, cap = CargoService:GetCap(player) })
	updateBox(player, c)
end

local function attachBox(player: Player, model: Model)
	local root = model.PrimaryPart
	if not root then
		return
	end
	local box = Instance.new("Part")
	box.Name = "CargoBox"
	box.CanCollide = false
	box.CanTouch = false
	box.CanQuery = false
	box.Massless = true
	box.TopSurface = Enum.SurfaceType.Smooth
	box.BottomSurface = Enum.SurfaceType.Smooth
	box.CFrame = root.CFrame
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = box
	weld.Parent = box
	box.Parent = model
	local c = stateOf(player)
	c.box, c.weld = box, weld
	push(player)
end

-- 캔 블록 받기. items = { {idx, id} }. 결과는 캔 사람 화면에 블록이 날아오는 연출로 보낸다.
function CargoService:AddLoot(player: Player, items: { { number } })
	local c = stateOf(player)
	local cap = CargoService:GetCap(player)
	local result = {}
	local coins = 0
	local fuel = 0
	local lost = false
	for _, it in items do
		local idx, id = it[1], it[2]
		local info = BlockInfo.byId[id]
		local ok = true
		if info and info.kind == "treasure" then
			coins += info.coins or 0
		elseif info and info.kind == "fuel" then
			fuel += info.fuel or 0 -- 화물칸을 차지하지 않고 연료 저장분으로
		elseif c.count < cap then
			c.count += 1
			c.items[id] = (c.items[id] or 0) + 1
		else
			ok = false
			lost = true
		end
		table.insert(result, { idx, id, ok })
	end
	Net.event("BlockLoot"):FireClient(player, result)
	local mined = 0
	for _, r in result do
		if r[3] then
			mined += 1
		end
	end
	ExpeditionService:AddStat(player, "mined", mined)
	ExpeditionService:AddStat(player, "coins", coins)
	if lost then
		ExpeditionService:AddStat(player, "lost", #result - mined)
	end
	if coins > 0 then
		ProgressService:AddCoins(player, coins)
	end
	if fuel > 0 then
		FuelService:AddReserve(player, fuel)
	end
	if lost and os.clock() - c.warnedAt > FULL_WARN_INTERVAL then
		c.warnedAt = os.clock()
		Net.event("Notify"):FireClient(player, "화물칸이 가득 찼어요! 블록이 사라져요", true)
	end
	push(player)
end

-- 화물을 창고(저장 데이터 inventory)로 맡긴다. 맡긴 개수를 돌려준다.
function CargoService:Deposit(player: Player): number
	local c = cargo[player]
	local data = DataService:Get(player)
	if not c or not data or c.count == 0 then
		return 0
	end
	local n = c.count
	for id, k in c.items do
		local key = tostring(id)
		data.inventory[key] = (data.inventory[key] or 0) + k
	end
	c.count = 0
	c.items = {}
	push(player)
	return n
end

-- 지금 화물칸에 든 블록 수
function CargoService:GetCount(player: Player): number
	local c = cargo[player]
	return if c then c.count else 0
end

function CargoService:Init(services)
	DataService = services.DataService
	PlaneService = services.PlaneService
	ProgressService = services.ProgressService
	ExpeditionService = services.ExpeditionService
	FuelService = services.FuelService
end

function CargoService:Start()
	PlaneService.Spawned:Connect(attachBox)
	PlaneService.Despawned:Connect(function(player: Player)
		local c = cargo[player]
		if c then
			c.box, c.weld = nil, nil
		end
	end)
	DataService.ProfileLoaded:Connect(function(player: Player)
		push(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			cargo[player] = nil
		end)
	end)
end

return CargoService
