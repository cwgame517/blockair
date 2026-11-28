--!strict
-- 채굴 폭탄: 떨어뜨리기 요청 → 서버가 궤도를 계산해 착탄 → 범위 안 블록에 1타씩.
-- 다 깨진 블록은 가장 많이 때린 사람의 것 (그 사람 화면에만 블록이 날아감). 플레이어는 다치지 않는다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local BlockInfo = require(ReplicatedStorage.Shared.Island.BlockInfo)
local Trajectory = require(ReplicatedStorage.Shared.Island.Trajectory)

local Mining = Config.Mining
local Upgrades = Config.Upgrades

local MiningService = {}

local DataService: any
local PlaneService: any
local IslandService: any
local CargoService: any

type Damage = { progress: number, by: { [number]: number } }

local lastDrop: { [Player]: number } = {}
local devPower: { [Player]: number } = {} -- Studio 테스트 명령 /power
local damage: { [number]: Damage } = {}

local function upgradeValue(player: Player, item: string): number
	local data = DataService:Get(player)
	local values = Upgrades.ITEMS[item].values
	local step = data and data.upgrades and data.upgrades[item] or 1
	return values[math.clamp(step, 1, #values)]
end

-- 지금 내 폭탄: 반지름(칸), 재장전(초), 채굴력
function MiningService:GetStats(player: Player): (number, number, number)
	local _, stats = PlaneService:Get(player)
	local base = if stats then stats.minePower else 1
	local power = devPower[player] or (base + upgradeValue(player, "bombPower"))
	return upgradeValue(player, "bombRadius"), upgradeValue(player, "bombReload"), power
end

function MiningService:SetDevPower(player: Player, power: number?)
	devPower[player] = power
	MiningService:PushStats(player)
end

function MiningService:PushStats(player: Player)
	local radius, reload, power = MiningService:GetStats(player)
	Net.event("MiningStats"):FireClient(player, { radius = radius, reload = reload, power = power })
end

local function explode(player: Player, pos: Vector3, radius: number, power: number)
	local grid = IslandService:GetGrid()
	local c = (pos - grid.corner) / grid.BS
	local uid = player.UserId
	local removedNow, dIdx, dStage = {}, {}, {}
	local loot: { [number]: { { number } } } = {} -- [UserId] = { {idx, id} }

	for y = math.floor(c.Y - radius), math.floor(c.Y + radius) do
		for z = math.floor(c.Z - radius), math.floor(c.Z + radius) do
			for x = math.floor(c.X - radius), math.floor(c.X + radius) do
				local id = grid:get(x, y, z)
				if id == 0 then
					continue
				end
				local dx, dy, dz = x + 0.5 - c.X, y + 0.5 - c.Y, z + 0.5 - c.Z
				if dx * dx + dy * dy + dz * dz > radius * radius then
					continue
				end
				local idx = grid:index(x, y, z)
				local info = BlockInfo.byId[id]
				local need = Mining.hitsFor(if info then info.minePower else 1, power)
				local d = damage[idx]
				if not d then
					d = { progress = 0, by = {} }
					damage[idx] = d
				end
				d.progress += 1 / need
				d.by[uid] = (d.by[uid] or 0) + 1 / need
				if d.progress >= 1 - 1e-6 then
					damage[idx] = nil
					table.insert(removedNow, idx)
					-- 가장 많이 때린 사람이 가져간다
					local owner, best = uid, -1
					for who, amount in d.by do
						if amount > best then
							owner, best = who, amount
						end
					end
					loot[owner] = loot[owner] or {}
					table.insert(loot[owner], { idx, id })
				else
					table.insert(dIdx, idx)
					table.insert(dStage, math.clamp(math.ceil(d.progress * Mining.CRACK_STAGES - 1e-6), 1, Mining.CRACK_STAGES))
				end
			end
		end
	end

	IslandService:Apply(removedNow, dIdx, dStage)
	Net.event("BombExploded"):FireAllClients(pos, radius * grid.BS)
	for owner, items in loot do
		local p = Players:GetPlayerByUserId(owner)
		if p then
			CargoService:AddLoot(p, items)
		end
	end
end

local function onDrop(player: Player)
	local model = PlaneService:Get(player)
	local root = model and model.PrimaryPart
	if not root then
		return
	end
	local radius, reload, power = MiningService:GetStats(player)
	local now = os.clock()
	if now - (lastDrop[player] or 0) < reload - 0.1 then -- 0.1초는 통신 지연 여유
		return
	end
	lastDrop[player] = now

	local start, vel = Trajectory.launch(root.Position, root.AssemblyLinearVelocity)
	Net.event("BombDropped"):FireAllClients(player.UserId, start, vel)
	local hit, t = Trajectory.impact(IslandService:GetGrid(), start, vel)
	if hit then
		task.delay(t, explode, player, hit, radius, power)
	end
end

function MiningService:Init(services)
	DataService = services.DataService
	PlaneService = services.PlaneService
	IslandService = services.IslandService
	CargoService = services.CargoService
end

function MiningService:Start()
	Net.event("BombDrop").OnServerEvent:Connect(onDrop)
	PlaneService.Spawned:Connect(function(player: Player)
		MiningService:PushStats(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastDrop[player] = nil
		devPower[player] = nil
	end)
end

return MiningService
