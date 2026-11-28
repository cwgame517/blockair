--!strict
-- 플레이스 사이 이동 (허브 → 원정 섬, 섬 → 허브).
-- 이동 직전에 저장 데이터를 저장한 뒤 잠금을 풀어 다음 서버가 바로 불러오게 한다.
-- (섬에서 격납고에 맡기지 않은 화물은 가져가지 않는다)
-- Studio 테스트에서는 텔레포트가 안 되므로 알림만 띄운다.
local AssetService = game:GetService("AssetService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local TravelService = {}

local services: { [string]: any }
local traveling: { [Player]: boolean } = {}
local otherPlaceId: number? = nil

local function notify(player: Player, text: string, warn: boolean?)
	Net.event("Notify"):FireClient(player, text, warn == true)
end

-- 같은 경험 안의 "다른" 플레이스 번호 (플레이스가 2개라고 가정)
local function findOtherPlace(): number?
	if otherPlaceId then
		return otherPlaceId
	end
	local ok, pages = pcall(function()
		return AssetService:GetGamePlacesAsync()
	end)
	if not ok then
		warn(`[TravelService] 플레이스 목록을 못 읽음: {pages}`)
		return nil
	end
	while true do
		for _, place in pages:GetCurrentPage() do
			if place.PlaceId ~= game.PlaceId then
				otherPlaceId = place.PlaceId
				return otherPlaceId
			end
		end
		if pages.IsFinished then
			break
		end
		local okNext = pcall(function()
			pages:AdvanceToNextPageAsync()
		end)
		if not okNext then
			break
		end
	end
	return nil
end

local function targetOf(dest: string): number?
	local fixed = if dest == "island" then Config.Places.ISLAND_PLACE_ID else Config.Places.HUB_PLACE_ID
	if fixed ~= 0 then
		return fixed
	end
	return findOtherPlace()
end

local function failed(player: Player, why: string)
	if not traveling[player] then
		return
	end
	traveling[player] = nil
	services.DataService:Unrelease(player)
	warn(`[TravelService] {player.Name} 이동 실패: {why}`)
	notify(player, "이동하지 못했어요. 잠시 후 다시 해 주세요.", true)
end

-- dest: "island" (원정 섬, 나만의 새 서버) | "hub"
function TravelService:Send(player: Player, dest: string)
	if traveling[player] then
		return
	end
	if RunService:IsStudio() then
		notify(player, "Studio 테스트에서는 플레이스 이동이 안 돼요. 게시 후 Roblox 앱에서 해 보세요.", true)
		return
	end
	local placeId = targetOf(dest)
	if not placeId then
		notify(player, if dest == "island" then "원정 섬 플레이스를 찾지 못했어요." else "허브 플레이스를 찾지 못했어요.", true)
		return
	end
	traveling[player] = true
	notify(player, if dest == "island" then "하늘 섬으로 출발!" else "허브로 돌아가요")

	services.PlaneService:Despawn(player, false)
	services.DataService:SaveAndRelease(player)

	local options = Instance.new("TeleportOptions")
	options.ShouldReserveServer = dest == "island"
	local ok, err = pcall(function()
		TeleportService:TeleportAsync(placeId, { player }, options)
	end)
	if not ok then
		failed(player, tostring(err))
	end
end

function TravelService:Init(all)
	services = all
end

function TravelService:Start()
	TeleportService.TeleportInitFailed:Connect(function(player: Player, _result, message: string)
		failed(player, message)
	end)
	Players.PlayerRemoving:Connect(function(player)
		traveling[player] = nil
	end)
end

return TravelService
