--!strict
-- 출격 버튼 → 원정 섬으로 보낸다.
-- 2단계는 혼자 출격(나만의 섬 서버). 여럿이 모여 카운트다운하는 매칭은 협동 전투 단계에서 붙인다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local COOLDOWN = 3

local MatchService = {}

local TravelService: any
local last: { [Player]: number } = {}

function MatchService:Init(services)
	TravelService = services.TravelService
end

function MatchService:Start()
	Net.event("Sortie").OnServerEvent:Connect(function(player: Player)
		local now = os.clock()
		if now - (last[player] or 0) < COOLDOWN then
			return
		end
		last[player] = now
		TravelService:Send(player, "island")
	end)
	Players.PlayerRemoving:Connect(function(player)
		last[player] = nil
	end)
end

return MatchService
