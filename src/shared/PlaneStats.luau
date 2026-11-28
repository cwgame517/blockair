--!strict
-- 설계 데이터 → 비행기 능력치. 서버(소환·감시)와 클라이언트(에디터 막대)가 같은 식을 쓴다.
-- 1단계에서는 속도·회전·무게·HP 만 계산한다. 화력·채굴력은 5·6단계에서 더한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlaneBuilder = require(ReplicatedStorage.Shared.PlaneBuilder)

local Flight = Config.Flight

export type Stats = {
	cells: number,
	weight: number,
	hp: number,
	maxSpeed: number,
	minSpeed: number,
	turnRate: number, -- 도/초
}

local PlaneStats = {}

function PlaneStats.compute(rawDesign: any): Stats
	local design = PlaneBuilder.sanitize(rawDesign)
	local shape = Config.FrameShapes.byId[design.frameId]
	local frame = Config.Frames.byId[shape.class]

	local count = 0
	local weight = 0
	local hardness = 0
	for _, placed in PlaneBuilder.layout(design.frameId, design.parts) do
		local block = PlaneBuilder.blockAt(design, placed.index)
		count += 1
		weight += block.weight
		hardness += block.hardness
	end

	local ref = frame.cells * Flight.REF_WEIGHT_PER_CELL
	local ratio = ref / math.max(weight, 0.1)
	local speedMul = math.clamp(ratio ^ Flight.WEIGHT_SPEED_EXP, Flight.SPEED_MUL_MIN, Flight.SPEED_MUL_MAX)
	local turnMul = math.clamp(ratio ^ Flight.WEIGHT_TURN_EXP, Flight.SPEED_MUL_MIN, Flight.SPEED_MUL_MAX)

	return {
		cells = count,
		weight = weight,
		hp = frame.pveBaseHp + hardness * Config.Frames.PVE_HP_PER_HARDNESS,
		maxSpeed = Flight.BASE_MAX_SPEED * speedMul,
		minSpeed = Flight.MIN_SPEED,
		turnRate = Flight.BASE_TURN_RATE * turnMul,
	}
end

return PlaneStats
