--!strict
-- 원정 진행. 섬에 도착하면 바로 비행기에 태우고, "허브로" 버튼으로 돌아가기
-- (맡기지 않은 화물이 있으면 한 번 경고).
-- (15분 타이머·섬 붕괴·보상은 뒤 단계에서)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local ARRIVE_DELAY = 1.5 -- 캐릭터가 나타난 뒤 비행기에 태우기까지
local HOME_COOLDOWN = 3
local HOME_CONFIRM_TIME = 6 -- 화물이 있을 때 "한 번 더 누르면 출발" 을 기다리는 시간

local ExpeditionService = {}

local DataService: any
local PlaneService: any
local TravelService: any
local CargoService: any
local lastHome: { [Player]: number } = {}
local warnedAt: { [Player]: number } = {}

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
		TravelService:Send(player, "hub")
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastHome[player] = nil
		warnedAt[player] = nil
	end)
end

return ExpeditionService
