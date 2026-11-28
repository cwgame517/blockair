--!strict
-- 이 서버가 어떤 플레이스인지 클라이언트에 알린다. 클라이언트는 이 값을 보고 UI를 고른다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlaceService = {}
PlaceService.KIND = "hub"

function PlaceService:Init(_services)
	ReplicatedStorage:SetAttribute("PlaceKind", PlaceService.KIND)
end

return PlaceService
