--!strict
-- 설계 데이터 → 비행기 능력치. 서버(소환·감시)와 클라이언트(에디터 막대)가 같은 식을 쓴다.
-- 가벼운 블록 = 빠르고 잘 돔, 단단한 블록 = HP 높음, 좋은 블록 = 채굴력 높음.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlaneBuilder = require(ReplicatedStorage.Shared.PlaneBuilder)

local Flight = Config.Flight
local Editor = Config.Editor

export type Stats = {
	cells: number,
	weight: number,
	speedMul: number, -- 무게로 정해지는 속도 배율 (1 = 기준 무게)
	hp: number,
	maxSpeed: number,
	minSpeed: number,
	turnRate: number, -- 도/초
	minePower: number, -- 비행기 블록들의 평균 채굴력 (기본 나무 = 1)
	firepower: number, -- 초당 피해 합 (무기 칸 수 × 무기 초당 피해). 무기는 6단계에서 실제로 쏜다
	heavy: boolean, -- 너무 무거워서 느림 (에디터 경고)
}

export type Bars = { speed: number, hp: number, fire: number, mine: number } -- 0~1

local PlaneStats = {}

local function weaponDps(weapon: string): number
	local w = (Config.Weapons :: any)[weapon]
	if not w or not w.damage or not w.fireRate then
		return 0
	end
	return w.damage * w.fireRate
end

function PlaneStats.compute(rawDesign: any): Stats
	local design = PlaneBuilder.sanitize(rawDesign)
	local shape = Config.FrameShapes.byId[design.frameId]
	local frame = Config.Frames.byId[shape.class]

	local count = 0
	local weight = 0
	local hardness = 0
	local power = 0
	for _, placed in PlaneBuilder.layout(design.frameId, design.parts) do
		local block = PlaneBuilder.blockAt(design, placed.key)
		count += 1
		weight += block.weight
		hardness += block.hardness
		power += block.minePower
	end

	-- 기준 무게 = 칸 수 × REF_WEIGHT_PER_CELL. 이보다 가벼우면 빨라지고 무거우면 느려진다.
	local ref = math.max(count, 1) * Flight.REF_WEIGHT_PER_CELL
	local ratio = ref / math.max(weight, 0.1)
	local speedMul = math.clamp(ratio ^ Flight.WEIGHT_SPEED_EXP, Flight.SPEED_MUL_MIN, Flight.SPEED_MUL_MAX)
	local turnMul = math.clamp(ratio ^ Flight.WEIGHT_TURN_EXP, Flight.SPEED_MUL_MIN, Flight.SPEED_MUL_MAX)

	return {
		cells = count,
		weight = weight,
		speedMul = speedMul,
		hp = frame.pveBaseHp + hardness * Config.Frames.PVE_HP_PER_HARDNESS,
		maxSpeed = Flight.BASE_MAX_SPEED * speedMul,
		minSpeed = Flight.MIN_SPEED,
		turnRate = Flight.BASE_TURN_RATE * turnMul,
		minePower = if count > 0 then power / count else 1,
		firepower = frame.weaponSlots * weaponDps(design.weapon),
		heavy = speedMul < Editor.HEAVY_WARN_MUL,
	}
end

-- 에디터 막대 4개 (0~1). 속도·튼튼함은 같은 틀에서 가능한 범위 안의 위치,
-- 화력은 무기 칸 × 가장 센 무기 기준, 채굴력은 최고 블록 기준(로그 눈금: 낮은 단계에서도 차이가 보이게).
function PlaneStats.bars(stats: Stats, frameId: string?): Bars
	local shape = Config.FrameShapes.byId[frameId or Config.FrameShapes.DEFAULT_DESIGN.frameId]
	local frame = Config.Frames.byId[shape.class]
	local maxHardness = 0
	for _, b in Config.Blocks.list do
		maxHardness = math.max(maxHardness, b.hardness)
	end
	local defaultBlock = Config.Blocks.byKey[Flight.DEFAULT_BLOCK]
	local perCell = Config.Frames.PVE_HP_PER_HARDNESS
	local hpLow = frame.pveBaseHp + stats.cells * defaultBlock.hardness * perCell
	local hpHigh = frame.pveBaseHp + stats.cells * maxHardness * perCell
	local function ratio(v: number, lo: number, hi: number): number
		if hi <= lo then
			return 1
		end
		return math.clamp((v - lo) / (hi - lo), 0, 1)
	end
	local floor = 0.06 -- 막대가 아주 비어 보이지 않게
	return {
		speed = math.max(floor, ratio(stats.speedMul, Flight.SPEED_MUL_MIN, Flight.SPEED_MUL_MAX)),
		hp = math.max(floor, ratio(stats.hp, hpLow, hpHigh)),
		fire = math.max(floor, ratio(stats.firepower, 0, frame.weaponSlots * Editor.FIRE_REF_DPS)),
		mine = math.max(floor, ratio(math.log(math.max(stats.minePower, 1)), 0, math.log(Editor.MINE_REF))),
	}
end

return PlaneStats
