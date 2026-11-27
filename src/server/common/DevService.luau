--!strict
-- Studio 테스트 전용 채팅 명령. 실제 서버에서는 아무것도 하지 않는다.
--   /coins 1000   코인 더하기 (음수면 빼기)
--   /xp 500       XP 더하기
--   /stats        내 레벨·코인 출력
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DevService = {}
local ProgressService
local DataService

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
	elseif cmd == "stats" then
		local d = DataService:Get(player)
		if d then
			print(`[Dev] {player.Name}: 레벨 {d.level}, XP {d.xp}, 코인 {d.coins}`)
		end
	end
end

function DevService:Init(services)
	ProgressService = services.ProgressService
	DataService = services.DataService
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
