--!strict
-- 플레이어 저장 데이터 불러오기·저장.
-- 한 플레이어 데이터를 두 서버가 동시에 쓰지 않도록 간단한 세션 잠금을 건다
-- (허브 ↔ 섬 텔레포트 때 데이터가 덮어써지는 사고 방지).
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Signal = require(ReplicatedStorage.Shared.Util.Signal)

local STORE_NAME = "PlayerData_v1"
local AUTOSAVE_INTERVAL = 120
local LOCK_TIMEOUT = 30 * 60 -- 잠금이 30분 넘게 갱신되지 않으면 죽은 서버로 보고 가져온다
local LOAD_RETRIES = 6
local LOAD_RETRY_WAIT = 5

local DataService = {}
DataService.ProfileLoaded = Signal.new() -- (player, data)
DataService.PlayerLeaving = Signal.new() -- (player, data) 나가기 직전, 마지막 저장 전에 (화물 옮기기 등)

local TEMPLATE = {
	version = 1,
	level = 1,
	xp = 0,
	coins = 0,
	inventory = {}, -- [blockId(string)] = 개수
	upgrades = { cargo = 1, bombRadius = 1, bombReload = 1, bombPower = 1, missile = 1, cannon = 1, laser = 1 },
	planes = {},
	activePlane = 1,
	ownedFrames = { "small_basic" },
	cosmetics = {},
	settings = {},
	stats = {},
	lastRun = false, -- 섬에서 돌아올 때 허브 결과 화면에 보여 줄 원정 결과 (보여 준 뒤 false)
}

local store: DataStore? = nil
local profiles: { [Player]: any } = {}
local noSave: { [Player]: boolean } = {}
local released: { [Player]: boolean } = {} -- 텔레포트하려고 잠금을 푼 플레이어: 더 저장하지 않는다

local function deepCopy(t: any): any
	if type(t) ~= "table" then
		return t
	end
	local c = {}
	for k, v in t do
		c[k] = deepCopy(v)
	end
	return c
end

-- 저장본에 없는 새 항목은 템플릿 값으로 채운다 (나중에 항목을 추가해도 안전)
local function reconcile(data: any, template: any)
	for k, v in template do
		if data[k] == nil then
			data[k] = deepCopy(v)
		elseif type(v) == "table" and type(data[k]) == "table" and next(v) ~= nil then
			reconcile(data[k], v)
		end
	end
end

local function keyOf(player: Player): string
	return "u_" .. player.UserId
end

local function tryLoad(player: Player): (boolean, any, string?)
	assert(store)
	local result = nil
	local blocked = false
	local ok, err = pcall(function()
		store:UpdateAsync(keyOf(player), function(old)
			local saved = old or {}
			local lock = saved._lock
			if lock and lock.jobId ~= game.JobId and os.time() - lock.time < LOCK_TIMEOUT then
				blocked = true
				return nil -- 다른 서버가 아직 쓰는 중: 바꾸지 않음
			end
			saved._lock = { jobId = game.JobId, time = os.time() }
			result = saved
			return saved
		end)
	end)
	if not ok then
		warn(`[DataService] 불러오기 오류 {player.Name}: {err}`)
		return false, nil, tostring(err)
	end
	if blocked then
		return false, nil
	end
	return true, result
end

local function save(player: Player, release: boolean)
	local data = profiles[player]
	if not data or noSave[player] or released[player] or not store then
		return
	end
	local ok, err = pcall(function()
		store:UpdateAsync(keyOf(player), function(old)
			local lock = old and old._lock
			if lock and lock.jobId ~= game.JobId then
				return nil -- 잠금을 다른 서버가 가져갔으면 덮어쓰지 않음
			end
			local copy = deepCopy(data)
			copy._lock = if release then nil else { jobId = game.JobId, time = os.time() }
			return copy
		end)
	end)
	if not ok then
		warn(`[DataService] 저장 오류 {player.Name}: {err}`)
	end
end

local function onPlayerAdded(player: Player)
	local data = nil
	if store then
		for _ = 1, LOAD_RETRIES do
			local ok, result, err = tryLoad(player)
			if ok then
				data = result
				break
			end
			-- Studio에서 API 접근이 꺼져 있으면(403) 기다려도 소용없으니 저장 없이 진행
			if RunService:IsStudio() and err and string.find(err, "403", 1, true) then
				warn("[DataService] Studio API 접근이 꺼져 있어 저장 없이 진행합니다. (게임 설정 > 보안 > API 서비스 접근 켜기)")
				noSave[player] = true
				data = {}
				break
			end
			if not player.Parent then
				return
			end
			task.wait(LOAD_RETRY_WAIT)
		end
		if data == nil then
			player:Kick("저장 데이터를 불러오지 못했습니다. 잠시 후 다시 들어와 주세요.")
			return
		end
	else
		-- Studio에서 API 접근이 꺼져 있으면 저장 없이 진행
		noSave[player] = true
		data = {}
	end
	if not player.Parent then
		return
	end
	data._lock = nil
	reconcile(data, TEMPLATE)
	profiles[player] = data
	DataService.ProfileLoaded:Fire(player, data)
end

function DataService:Init(_services)
	local ok, result = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if ok then
		store = result
	else
		warn("[DataService] DataStore를 쓸 수 없습니다. 저장 없이 진행합니다. (Studio: 게임 설정 > 보안 > API 서비스 접근 켜기)")
	end
end

function DataService:Start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end
	Players.PlayerRemoving:Connect(function(player)
		local data = profiles[player]
		if data then
			DataService.PlayerLeaving:Fire(player, data) -- 듣는 쪽은 기다리지 않고 바로 끝나야 한다
		end
		save(player, true)
		profiles[player] = nil
		noSave[player] = nil
		released[player] = nil
	end)
	game:BindToClose(function()
		if RunService:IsStudio() and not store then
			return
		end
		for player in profiles do
			task.spawn(save, player, true)
		end
		task.wait(3) -- 저장 요청이 끝날 시간을 준다
	end)
	task.spawn(function()
		while true do
			task.wait(AUTOSAVE_INTERVAL)
			for player in profiles do
				task.spawn(save, player, false)
			end
		end
	end)
end

-- 불러오기가 끝난 데이터 (없으면 nil)
function DataService:Get(player: Player): any
	return profiles[player]
end

-- 데이터가 준비될 때까지 기다린다 (플레이어가 나가면 nil)
function DataService:Wait(player: Player): any
	while player.Parent and not profiles[player] do
		task.wait(0.1)
	end
	return profiles[player]
end

-- 텔레포트 직전처럼 꼭 지금 저장해야 할 때 (잠금도 풂)
-- 이후로는 이 서버에서 저장하지 않는다 (다음 서버가 잠금을 가져가도록)
function DataService:SaveAndRelease(player: Player)
	save(player, true)
	released[player] = true
end

-- 텔레포트가 실패해서 이 서버에 남을 때: 다시 저장하기 시작한다 (다음 자동 저장이 잠금을 다시 건다)
function DataService:Unrelease(player: Player)
	released[player] = nil
end

return DataService
