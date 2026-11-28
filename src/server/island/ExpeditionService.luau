--!strict
-- 원정 진행. 2단계: 섬에 도착하면 바로 비행기에 태우고, "허브로" 버튼으로 돌아가기.
-- (15분 타이머·섬 붕괴·보상은 뒤 단계에서)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local ARRIVE_DELAY = 1.5 -- 캐릭터가 나타난 뒤 비행기에 태우기까지
local HOME_COOLDOWN = 3

local ExpeditionService = {}

local DataService: any
local PlaneService: any
local TravelService: any
local lastHome: { [Player]: number } = {}

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
		if now - (lastHome[player] or 0) < HOME_COOLDOWN then
			return
		end
		lastHome[player] = now
		TravelService:Send(player, "hub")
	end)
	Players.PlayerRemoving:Connect(function(player)
		lastHome[player] = nil
	end)
end

return ExpeditionService
