--!strict
-- XP·레벨·코인. 코인을 바꾸는 곳은 이 서비스 하나뿐이다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local ProgressService = {}
ProgressService.LeveledUp = Signal.new() -- (player, newLevel)

local DataService

local function summary(data: any)
	return {
		level = data.level,
		xp = data.xp,
		xpToNext = if data.level >= Config.Levels.MAX_LEVEL then 0 else Config.Levels.xpToNext(data.level), -- 0 = 최고 레벨
		coins = data.coins,
	}
end

local function setupLeaderstats(player: Player, data: any)
	local ls = Instance.new("Folder")
	ls.Name = "leaderstats"
	local lv = Instance.new("IntValue")
	lv.Name = "레벨"
	lv.Value = data.level
	lv.Parent = ls
	local coins = Instance.new("IntValue")
	coins.Name = "코인"
	coins.Value = data.coins
	coins.Parent = ls
	ls.Parent = player
end

local function push(player: Player, data: any)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		(ls:FindFirstChild("레벨") :: IntValue).Value = data.level;
		(ls:FindFirstChild("코인") :: IntValue).Value = data.coins
	end
	Net.event("StatsChanged"):FireClient(player, summary(data))
end

function ProgressService:Init(services)
	DataService = services.DataService
end

function ProgressService:Start()
	DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		setupLeaderstats(player, data)
		Net.event("ProfileLoaded"):FireClient(player, summary(data))
	end)
	Net.func("GetProfile").OnServerInvoke = function(player: Player)
		local data = DataService:Get(player)
		return if data then summary(data) else nil
	end
end

-- 코인을 더하거나(양수) 뺀다(음수). 모자라면 아무것도 바꾸지 않고 false.
function ProgressService:AddCoins(player: Player, amount: number): boolean
	local data = DataService:Get(player)
	if not data then
		return false
	end
	amount = math.floor(amount)
	if data.coins + amount < 0 then
		return false
	end
	data.coins += amount
	push(player, data)
	return true
end

function ProgressService:GetCoins(player: Player): number
	local data = DataService:Get(player)
	return if data then data.coins else 0
end

function ProgressService:AddXp(player: Player, amount: number)
	local data = DataService:Get(player)
	if not data or amount <= 0 then
		return
	end
	data.xp += math.floor(amount)
	while data.level < Config.Levels.MAX_LEVEL and data.xp >= Config.Levels.xpToNext(data.level) do
		data.xp -= Config.Levels.xpToNext(data.level)
		data.level += 1
		Net.event("LevelUp"):FireClient(player, data.level, Config.Levels.UNLOCKS[data.level])
		ProgressService.LeveledUp:Fire(player, data.level)
	end
	if data.level >= Config.Levels.MAX_LEVEL then
		data.xp = 0
	end
	push(player, data)
end

-- 레벨을 바로 정하기 (Studio 테스트 명령 /level 전용)
function ProgressService:SetLevel(player: Player, level: number)
	local data = DataService:Get(player)
	if not data then
		return
	end
	data.level = math.clamp(math.floor(level), 1, Config.Levels.MAX_LEVEL)
	data.xp = 0
	push(player, data)
end

function ProgressService:GetLevel(player: Player): number
	local data = DataService:Get(player)
	return if data then data.level else 1
end

return ProgressService
