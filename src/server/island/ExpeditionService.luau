--!strict
-- 원정 진행. 섬에 도착하면 바로 비행기에 태우고, "허브로" 버튼으로 돌아가기
-- (맡기지 않은 화물이 있으면 한 번 경고).
-- 한 판 기록(캔 블록·맡긴 블록·코인·XP·레벨)을 모아 두었다가, 돌아갈 때 저장 데이터 lastRun 에 적는다
-- → 허브가 결과 화면으로 보여 준다. (15분 타이머·섬 붕괴·완주 보상은 뒤 단계에서)
-- 원정 XP(5단계): 돌아갈 때 (300 + 50×레벨) × 머문 시간/15분. 블록을 하나도 맡기지 않았으면 0.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local ARRIVE_DELAY = 1.5 -- 캐릭터가 나타난 뒤 비행기에 태우기까지
local HOME_COOLDOWN = 3
local HOME_CONFIRM_TIME = 6 -- 화물이 있을 때 "한 번 더 누르면 출발" 을 기다리는 시간

local ExpeditionService = {}

local DataService: any
local PlaneService: any
local TravelService: any
local CargoService: any
local ProgressService: any
local lastHome: { [Player]: number } = {}
local warnedAt: { [Player]: number } = {}

type Run = {
	mined: number, lost: number, deposited: number, coins: number, xp: number, levelFrom: number,
	startedAt: number, awarded: boolean,
}
local runs: { [Player]: Run } = {}

local function newRun(level: number): Run
	return {
		mined = 0, lost = 0, deposited = 0, coins = 0, xp = 0, levelFrom = level,
		startedAt = os.clock(), awarded = false,
	}
end

-- 한 판 기록에 더하기 (CargoService·HangarService 가 부름)
function ExpeditionService:AddStat(player: Player, key: string, n: number)
	local run = runs[player] :: any
	if run and n ~= 0 then
		run[key] += n
	end
end

-- 지금까지의 결과 (맡기지 않은 화물은 사라진 것으로 센다)
local function resultOf(player: Player): any?
	local run = runs[player]
	local data = DataService:Get(player)
	if not run or not data then
		return nil
	end
	return {
		mined = run.mined,
		lost = run.lost + CargoService:GetCount(player),
		deposited = run.deposited,
		coins = run.coins,
		xp = run.xp,
		levelFrom = run.levelFrom,
		levelTo = data.level,
	}
end

-- 원정 XP 주기 (한 판에 한 번)
local function awardXp(player: Player)
	local run = runs[player]
	local data = DataService:Get(player)
	if not run or not data or run.awarded or run.deposited <= 0 then
		return
	end
	run.awarded = true
	local xp = Config.Levels.expeditionXp(data.level, os.clock() - run.startedAt)
	if xp > 0 then
		ProgressService:AddXp(player, xp)
		run.xp += xp
	end
end

-- 돌아가기 직전(또는 나가기 직전): 결과를 저장 데이터에 적어 허브가 보여 주게 한다
local function writeResult(player: Player)
	awardXp(player)
	local data = DataService:Get(player)
	local result = resultOf(player)
	if data and result and result.mined > 0 then
		data.lastRun = result
	end
end

local function onCharacter(player: Player, char: Model)
	char:WaitForChild("HumanoidRootPart", 10)
	DataService:Wait(player)
	task.wait(ARRIVE_DELAY)
	if player.Character == char and not PlaneService:Get(player) then
		PlaneService:Spawn(player)
	end
end

function ExpeditionService:Init(services)
	DataService = services.DataService
	PlaneService = services.PlaneService
	TravelService = services.TravelService
	CargoService = services.CargoService
	ProgressService = services.ProgressService
end

function ExpeditionService:Start()
	local function hook(player: Player)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
	Net.event("GoHome").OnServerEvent:Connect(function(player: Player)
		local now = os.clock()
		-- 맡기지 않은 화물이 있으면 한 번 경고하고, 한 번 더 누르면 출발 (화물은 사라짐)
		local n = CargoService:GetCount(player)
		if n > 0 and now - (warnedAt[player] or -99) > HOME_CONFIRM_TIME then
			warnedAt[player] = now
			Net.event("Notify"):FireClient(player, `화물 {n}개는 격납고에 맡겨야 가져가요! 그냥 가려면 한 번 더 누르세요`, true)
			return
		end
		if now - (lastHome[player] or 0) < HOME_COOLDOWN then
			return
		end
		lastHome[player] = now
		warnedAt[player] = nil
		awardXp(player)
		if RunService:IsStudio() then
			-- Studio 에서는 이동이 안 되니 결과 화면만 미리 보여 준다
			Net.event("RunResult"):FireClient(player, resultOf(player))
		end
		writeResult(player)
		TravelService:Send(player, "hub")
		if RunService:IsStudio() then
			-- Studio 는 이동하지 않고 남으니 여기서 새 원정을 시작한 것으로 친다 (원정 XP 를 다시 시험할 수 있게)
			local data = DataService:Get(player)
			if data then
				runs[player] = newRun(data.level)
			end
		end
	end)
	DataService.ProfileLoaded:Connect(function(player: Player, data: any)
		runs[player] = newRun(data.level)
	end)
	DataService.PlayerLeaving:Connect(function(player: Player)
		writeResult(player) -- 그냥 나가도 다음에 허브에서 결과를 본다
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.defer(function()
			runs[player] = nil
		end)
		lastHome[player] = nil
		warnedAt[player] = nil
	end)
end

return ExpeditionService
