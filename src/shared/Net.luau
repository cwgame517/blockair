--!strict
-- 모든 Remote 이름을 한곳에서 정의한다. 서버가 만들고 클라이언트는 기다려서 가져온다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

-- 서버 → 클라이언트, 클라이언트 → 서버 신호 목록
local EVENTS = {
	"ProfileLoaded", -- 서버 → 클라: 저장 데이터 요약 (레벨, 코인 등)
	"StatsChanged", -- 서버 → 클라: 바뀐 값만
	"LevelUp", -- 서버 → 클라: 새 레벨
}

local FUNCTIONS = {
	"GetProfile", -- 클라 → 서버: 내 데이터 요약 다시 받기
}

local folder: Folder
if RunService:IsServer() then
	local existing = ReplicatedStorage:FindFirstChild("Remotes")
	folder = if existing then existing :: Folder else Instance.new("Folder")
	folder.Name = "Remotes"
	for _, name in EVENTS do
		if not folder:FindFirstChild(name) then
			local e = Instance.new("RemoteEvent")
			e.Name = name
			e.Parent = folder
		end
	end
	for _, name in FUNCTIONS do
		if not folder:FindFirstChild(name) then
			local f = Instance.new("RemoteFunction")
			f.Name = name
			f.Parent = folder
		end
	end
	folder.Parent = ReplicatedStorage
else
	folder = ReplicatedStorage:WaitForChild("Remotes") :: Folder
end

function Net.event(name: string): RemoteEvent
	return folder:WaitForChild(name) :: RemoteEvent
end

function Net.func(name: string): RemoteFunction
	return folder:WaitForChild(name) :: RemoteFunction
end

return Net
