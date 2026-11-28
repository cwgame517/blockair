--!strict
-- 연료 (5단계, 원정 섬 전용). 수치는 Config/Fuel.
-- 비행하는 동안 탱크가 줄고(무거울수록 빨리, 제자리 비행은 절반), 20% 아래면 저장분에서 자동 충전.
-- 탱크가 0 이면 비행기 속성 Gliding = true → 조종하는 클라이언트가 느린 활공으로 바꾼다.
-- 석탄·석유·우라늄을 캐면 저장분이 쌓이고(CargoService 가 부름), 격납고에서는 최소량을 무료로 채운다.
-- 원정마다 새로 시작한다 (저장하지 않음): 탱크 가득, 저장분 0.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local Net = require(ReplicatedStorage.Shared.Net)

local Fuel = Config.Fuel

local FuelService = {}

type State = { tank: number, reserve: number, gliding: boolean }

local PlaneService: any
local states: { [Player]: State } = {}

local function stateOf(player: Player): State
	local st = states[player]
	if not st then
		st = { tank = 1, reserve = 0, gliding = false }
		states[player] = st
	end
	return st
end

local function round(v: number): number
	return math.floor(v * 1000 + 0.5) / 1000
end

local function push(player: Player, st: State)
	Net.event("Fuel"):FireClient(player, { tank = round(st.tank), reserve = round(st.reserve), gliding = st.gliding })
end

-- 활공 상태를 비행기 모델에 적는다 (조종하는 클라이언트가 읽음)
local function setGliding(player: Player, st: State, on: boolean)
	if st.gliding == on then
		return
	end
	st.gliding = on
	local model = PlaneService:Get(player)
	if model then
		model:SetAttribute("Gliding", on)
	end
	if on then
		Net.event("Notify"):FireClient(player, "연료가 떨어졌어요! 활공 중... 격납고로 가거나 연료 블록을 캐세요", true)
	end
end

-- 탱크가 낮으면 저장분에서 채운다. 채웠으면 true
local function autoRefill(player: Player, st: State): boolean
	if st.tank >= Fuel.AUTO_REFILL_BELOW or st.reserve <= 0 then
		return false
	end
	local move = math.min(st.reserve, 1 - st.tank)
	st.tank += move
	st.reserve -= move
	if st.reserve < 1e-4 then
		st.reserve = 0
	end
	setGliding(player, st, false)
	Net.event("Notify"):FireClient(player, `저장 연료로 자동 충전! 연료 {math.floor(st.tank * 100 + 0.5)}%`)
	return true
end

-- 무게에 따른 연료 소모 배율 (가벼우면 덜, 무거우면 더)
local function burnMul(stats: any): number
	if not stats or not stats.cells or stats.cells <= 0 then
		return 1
	end
	local perCell = stats.weight / stats.cells / Config.Flight.REF_WEIGHT_PER_CELL
	return math.clamp(perCell ^ Fuel.WEIGHT_EXP, Fuel.BURN_MUL_MIN, Fuel.BURN_MUL_MAX)
end

local warnedLow: { [Player]: boolean } = {}

local function tick(dt: number)
	for _, player in Players:GetPlayers() do
		local model, stats = PlaneService:Get(player)
		local root = model and model.PrimaryPart
		if not root then
			continue
		end
		local st = stateOf(player)
		if st.tank > 0 then
			local hover = root.AssemblyLinearVelocity.Magnitude < Fuel.HOVER_SPEED
			local rate = burnMul(stats) / Fuel.TANK_TIME * (if hover then Fuel.HOVER_BURN else 1)
			st.tank = math.max(0, st.tank - rate * dt)
		end
		autoRefill(player, st)
		if st.tank <= 0 then
			setGliding(player, st, true)
		end
		if st.tank < Fuel.LOW_WARN and st.reserve <= 0 and st.tank > 0 then
			if not warnedLow[player] then
				warnedLow[player] = true
				Net.event("Notify"):FireClient(player, "연료가 얼마 안 남았어요! 격납고나 연료 블록(석탄·석유·우라늄)을 찾으세요", true)
			end
		elseif st.tank >= Fuel.LOW_WARN then
			warnedLow[player] = nil
		end
		push(player, st)
	end
end

-- 연료 블록을 캤을 때: 저장분에 더한다 (amount = 탱크의 몇 배, 석탄 0.1 = 10%)
function FuelService:AddReserve(player: Player, amount: number)
	if amount <= 0 then
		return
	end
	local st = stateOf(player)
	st.reserve += amount
	autoRefill(player, st)
	push(player, st)
end

-- 격납고: 탱크가 최소량보다 적으면 무료로 채운다. 채웠으면 true
function FuelService:RefillTo(player: Player, minimum: number): boolean
	local st = stateOf(player)
	if st.tank >= minimum then
		return false
	end
	st.tank = minimum
	setGliding(player, st, false)
	push(player, st)
	return true
end

-- Studio 테스트 명령 /fuel: 탱크를 percent% 로
function FuelService:SetTank(player: Player, percent: number)
	local st = stateOf(player)
	st.tank = math.clamp(percent / 100, 0, 1)
	setGliding(player, st, st.tank <= 0)
	push(player, st)
end

-- (탱크 0~1, 저장분)
function FuelService:Get(player: Player): (number, number)
	local st = stateOf(player)
	return st.tank, st.reserve
end

function FuelService:Init(services)
	PlaneService = services.PlaneService
end

function FuelService:Start()
	PlaneService.Spawned:Connect(function(player: Player, model: Model)
		local st = stateOf(player)
		model:SetAttribute("Gliding", st.gliding)
		push(player, st)
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
		warnedLow[player] = nil
	end)
	local acc = 0
	RunService.Heartbeat:Connect(function(dt)
		acc += dt
		if acc >= Fuel.TICK then
			tick(acc)
			acc = 0
		end
	end)
end

return FuelService
