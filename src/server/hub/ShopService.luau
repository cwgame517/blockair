--!strict
-- 허브 격납고 메뉴: 창고에 맡긴 블록 팔기(블록 판매가 × 개수 = 코인), 코인으로 강화(화물칸·채굴 폭탄).
-- 강화 규칙: 한 번에 한 단계, 레벨이 열어 준 단계까지만, 값은 코인. 서버가 모두 검사한다.
-- 섬에서 돌아오면 원정 결과(저장 데이터 lastRun)를 결과 화면으로 한 번 보여 준다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Upgrades = Config.Upgrades
local Levels = Config.Levels
local REQUEST_COOLDOWN = 0.15

local ShopService = {}

local DataService: any
local ProgressService: any
local EditorService: any
local priceOf: { [number]: number } = {}
local lastRequest: { [Player]: number } = {}

for _, b in Config.Blocks.list do
	priceOf[b.id] = b.price
end

local function isOpen(item: string): boolean
	return table.find(Upgrades.OPEN, item) ~= nil
end

local function throttled(player: Player): boolean
	local now = os.clock()
	if now - (lastRequest[player] or 0) < REQUEST_COOLDOWN then
		return true
	end
	lastRequest[player] = now
	return false
end

-- 클라이언트에 보낼 창고·강화 상태
local function snapshot(data: any)
	local blocks = {}
	for key, n in data.inventory do
		local id = tonumber(key)
		if id and n > 0 and priceOf[id] then
			table.insert(blocks, { id = id, count = n, price = priceOf[id] })
		end
	end
	table.sort(blocks, function(a, b)
		return a.id < b.id
	end)
	local steps = {}
	for _, item in Upgrades.OPEN do
		steps[item] = data.upgrades[item] or 1
	end
	return {
		blocks = blocks,
		upgrades = steps,
		cap = Levels.upgradeCap(data.level),
		coins = data.coins,
		level = data.level,
	}
end

-- 블록 팔기. id 가 없으면 창고의 블록을 전부 판다.
local function sell(player: Player, id: any)
	local data = DataService:Get(player)
	if not data then
		return { ok = false }
	end
	if throttled(player) then
		return { ok = false, state = snapshot(data) }
	end
	local earned, sold = 0, 0
	local function sellOne(blockId: number)
		local key = tostring(blockId)
		local n = data.inventory[key] or 0
		local price = priceOf[blockId]
		if n > 0 and price then
			earned += n * price
			sold += n
			data.inventory[key] = nil
		end
	end
	if id == nil then
		local keys = {}
		for key in data.inventory do
			table.insert(keys, key)
		end
		for _, key in keys do
			local blockId = tonumber(key)
			if blockId then
				sellOne(blockId)
			end
		end
	elseif typeof(id) == "number" then
		sellOne(id)
	end
	if earned > 0 then
		ProgressService:AddCoins(player, earned)
		EditorService:Push(player) -- 에디터 단축바의 블록 개수도 맞춘다
	end
	return { ok = sold > 0, sold = sold, earned = earned, state = snapshot(data) }
end

-- 강화 한 단계. 실패하면 이유: "max" | "level" | "coins"
local function buy(player: Player, item: any)
	local data = DataService:Get(player)
	if not data or typeof(item) ~= "string" or not isOpen(item) then
		return { ok = false }
	end
	if throttled(player) then
		return { ok = false, state = snapshot(data) }
	end
	local step = data.upgrades[item] or 1
	local nextStep = step + 1
	local why: string? = nil
	if nextStep > #Upgrades.ITEMS[item].values then
		why = "max"
	elseif nextStep > Levels.upgradeCap(data.level) then
		why = "level"
	elseif not ProgressService:AddCoins(player, -Upgrades.STEP_COST[nextStep]) then
		why = "coins"
	end
	if why then
		return { ok = false, why = why, state = snapshot(data) }
	end
	data.upgrades[item] = nextStep
	return { ok = true, item = item, step = nextStep, state = snapshot(data) }
end

function ShopService:Init(services)
	DataService = services.DataService
	ProgressService = services.ProgressService
	EditorService = services.EditorService
end

function ShopService:Start()
	DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		if type(data.lastRun) == "table" then
			Net.event("RunResult"):FireClient(player, data.lastRun)
			data.lastRun = false
		end
	end)
	Net.func("GetHangar").OnServerInvoke = function(player: Player)
		local data = DataService:Get(player)
		return if data then snapshot(data) else nil
	end
	Net.func("SellBlocks").OnServerInvoke = sell
	Net.func("BuyUpgrade").OnServerInvoke = buy
	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)
end

return ShopService
