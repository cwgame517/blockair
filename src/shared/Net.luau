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
	"PlaneRequest", -- 클라 → 서버: 비행기 타기(true) / 내리기(false)
	"Notify", -- 서버 → 클라: 화면 가운데 알림 문구 (문구, 경고인지)
	"Sortie", -- 클라 → 서버 (허브): 출격 (원정 섬으로 이동)
	"GoHome", -- 클라 → 서버 (섬): 허브로 돌아가기
	"BombDrop", -- 클라 → 서버 (섬): 채굴 폭탄 떨어뜨리기
	"BombDropped", -- 서버 → 모두: 누가 폭탄을 떨어뜨림 (주인 UserId, 시작 위치, 속도)
	"BombExploded", -- 서버 → 모두: 폭탄이 터짐 (위치, 반지름 스터드)
	"BlocksChanged", -- 서버 → 모두: 사라진 칸 번호 목록, 금 간 칸 번호·단계 목록
	"BlockLoot", -- 서버 → 캔 사람: 내가 얻은 블록 { {idx, id, ok} } (ok=false 면 화물칸이 가득 차 사라짐)
	"CargoChanged", -- 서버 → 클라: 화물칸 { count, cap }
	"MiningStats", -- 서버 → 클라: 내 폭탄 { radius(칸), reload(초), power(채굴력) }
	"PlaneHp", -- 서버 → 주인: 내 비행기 HP (지금, 최대)
	"Hangar", -- 서버 → 클라 (섬): 격납고 일 ("deposit", 개수) | ("repairStart", 초) | ("repairStop") | ("repairDone")
}

local FUNCTIONS = {
	"GetProfile", -- 클라 → 서버: 내 데이터 요약 다시 받기
	"GetIslandInfo", -- 클라 → 서버 (섬): 섬 지름·씨앗·지문, 지금까지 사라진 칸·금 간 칸
	"GetIslandData", -- 클라 → 서버 (섬): 섬 블록 배열 통째로 (클라가 만든 섬이 서버와 다를 때만)
	"GetHangar", -- 클라 → 서버 (허브): 창고 블록·강화 단계·코인·레벨
	"SellBlocks", -- 클라 → 서버 (허브): 블록 팔기 (블록 번호, 없으면 전부) → 결과
	"BuyUpgrade", -- 클라 → 서버 (허브): 강화 한 단계 올리기 (항목 이름) → 결과
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
