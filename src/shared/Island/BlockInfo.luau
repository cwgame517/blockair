--!strict
-- 섬 칸에 들어가는 블록 번호(1바이트) → 이름·종류·필요 채굴력·겉모습.
-- 몸통 블록(Blocks, 1~199)과 맵 블록(MapBlocks, 200번대)을 한 표로 합친다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

export type Info = {
	id: number,
	key: string,
	name: string,
	kind: string, -- "body"(화물칸으로) | "fuel"(연료) | "treasure"(바로 코인)
	minePower: number,
	color: Color3,
	material: Enum.Material,
	coins: number?,
	fuel: number?,
}

local Looks = Config.BlockLooks

local byId: { [number]: Info } = {}
local byKey: { [string]: Info } = {}

local function add(info: Info)
	byId[info.id] = info
	byKey[info.key] = info
end

for _, b in Config.Blocks.list do
	local look = Looks.byKey[b.key] or Looks.byFamily[b.family] or Looks.DEFAULT
	add({ id = b.id, key = b.key, name = b.name, kind = "body", minePower = b.minePower, color = look.color, material = look.material })
end
for _, b in Config.MapBlocks.fuel do
	local look = Looks.byKey[b.key] or Looks.DEFAULT
	add({ id = b.id, key = b.key, name = b.name, kind = "fuel", minePower = b.minePower, color = look.color, material = look.material, fuel = b.fuel })
end
for _, b in Config.MapBlocks.treasure do
	local look = Looks.byKey[b.key] or Looks.DEFAULT
	add({ id = b.id, key = b.key, name = b.name, kind = "treasure", minePower = b.minePower, color = look.color, material = look.material, coins = b.coins })
end

return { byId = byId, byKey = byKey }
