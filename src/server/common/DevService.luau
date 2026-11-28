--!strict
-- Studio 테스트 전용 채팅 명령. 실제 서버에서는 아무것도 하지 않는다.
--   /coins 1000   코인 더하기 (음수면 빼기)
--   /xp 500       XP 더하기
--   /stats        내 레벨·코인 출력
--   /speed 70     비행 속도를 기본의 70% 로 (10~300, 숫자 없이 쓰면 지금 값 출력)
--   /power 5      (섬) 내 채굴력을 5로. 숫자 없이 쓰면 원래대로
--   /give 100     창고(맡긴 블록)에 여러 가지 블록 100개 넣기 (팔기 테스트)
--   /hurt 300     내 비행기 HP 300 깎기 (격납고 수리 테스트)
--   /level 5      레벨을 5로 (부위 교체 테스트)
--   /freepass     (허브) 자유틀 게임패스를 가진 것처럼 켜기/끄기
--   /allblocks 20 (허브) 36종 블록을 종류마다 20개씩 창고에 넣기 (에디터 테스트)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)

local DevService = {}
local ProgressService
local DataService
local PlaneService
local MiningService
local EditorService

-- 허브 에디터 화면이 바뀐 창고·레벨을 바로 보이게
local function refreshEditor(player: Player)
	if EditorService then
		EditorService:Push(player)
	end
end

local function onChat(player: Player, message: string)
	local cmd, arg = string.match(message, "^/(%a+)%s*(%-?%d*)")
	if not cmd then
		return
	end
	local n = tonumber(arg) or 0
	if cmd == "coins" then
		local ok = ProgressService:AddCoins(player, n)
		print(`[Dev] {player.Name} 코인 {n} → {ok and "성공" or "실패(코인 부족)"}`)
	elseif cmd == "xp" then
		ProgressService:AddXp(player, n)
		print(`[Dev] {player.Name} XP +{n}`)
	elseif cmd == "speed" then
		if arg ~= "" then
			PlaneService:SetSpeedPercent(n)
		end
		print(`[Dev] 비행 속도 {PlaneService:GetSpeedPercent()}%`)
	elseif cmd == "power" then
		if not MiningService then
			print("[Dev] /power 는 원정 섬에서만 됩니다")
			return
		end
		MiningService:SetDevPower(player, if arg ~= "" then math.max(n, 0.1) else nil)
		local _, _, power = MiningService:GetStats(player)
		print(`[Dev] {player.Name} 채굴력 {power}`)
	elseif cmd == "give" then
		local d = DataService:Get(player)
		if not d then
			return
		end
		local count = if arg ~= "" then math.clamp(n, 1, 100000) else 100
		local rng = Random.new()
		local list = Config.Blocks.list
		local pool = math.min(#list, 12) -- 앞쪽(흔한) 블록 위주
		for _ = 1, count do
			local b = list[rng:NextInteger(1, pool)]
			local key = tostring(b.id)
			d.inventory[key] = (d.inventory[key] or 0) + 1
		end
		print(`[Dev] {player.Name} 창고에 블록 {count}개`)
		refreshEditor(player)
	elseif cmd == "allblocks" then
		local d = DataService:Get(player)
		if not d then
			return
		end
		local each = if arg ~= "" then math.clamp(n, 1, 10000) else 20
		for _, b in Config.Blocks.list do
			local key = tostring(b.id)
			d.inventory[key] = (d.inventory[key] or 0) + each
		end
		print(`[Dev] {player.Name} 창고에 블록 36종 × {each}개`)
		refreshEditor(player)
	elseif cmd == "freepass" then
		if not EditorService then
			print("[Dev] /freepass 는 허브에서만 됩니다")
			return
		end
		local on = not EditorService:HasPass(player)
		EditorService:SetDevPass(player, on)
		print(`[Dev] {player.Name} 자유틀 게임패스 {if on then "켬" else "끔"}`)
	elseif cmd == "level" then
		ProgressService:SetLevel(player, if arg ~= "" then n else 5)
		print(`[Dev] {player.Name} 레벨 {ProgressService:GetLevel(player)}`)
		refreshEditor(player)
	elseif cmd == "hurt" then
		PlaneService:Damage(player, if arg ~= "" then n else 300)
		local hp, maxHp = PlaneService:GetHp(player)
		print(`[Dev] {player.Name} HP {hp or 0}/{maxHp or 0}`)
	elseif cmd == "stats" then
		local d = DataService:Get(player)
		if d then
			local blocks = 0
			for _, k in d.inventory do
				blocks += k
			end
			print(`[Dev] {player.Name}: 레벨 {d.level}, XP {d.xp}, 코인 {d.coins}, 창고 블록 {blocks}개`)
		end
	end
end

function DevService:Init(services)
	ProgressService = services.ProgressService
	DataService = services.DataService
	PlaneService = services.PlaneService
	MiningService = services.MiningService -- 섬에만 있음
	EditorService = services.EditorService -- 허브에만 있음
end

function DevService:Start()
	if not RunService:IsStudio() then
		return
	end
	local function hook(player: Player)
		player.Chatted:Connect(function(msg)
			onChat(player, msg)
		end)
	end
	Players.PlayerAdded:Connect(hook)
	for _, p in Players:GetPlayers() do
		hook(p)
	end
end

return DevService
