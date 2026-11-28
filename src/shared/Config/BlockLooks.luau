--!strict
-- 섬에 놓인 블록의 겉모습 (색, 재질). key 는 Blocks 또는 MapBlocks 의 key.
-- 여기 없는 블록은 계열(family) 기본 모습을 쓴다. 디자인은 8단계에서 다듬는다.
local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local M = Enum.Material

return {
	byKey = {
		grass = { color = rgb(106, 176, 76), material = M.Grass },
		dirt = { color = rgb(122, 88, 60), material = M.Ground },
		sand = { color = rgb(222, 206, 150), material = M.Sand },
		stone = { color = rgb(128, 128, 134), material = M.Slate },
		stone1 = { color = rgb(104, 104, 112), material = M.Rock },
		limestone = { color = rgb(204, 198, 176), material = M.Limestone },
		granite = { color = rgb(150, 122, 116), material = M.Granite },
		marble = { color = rgb(226, 226, 232), material = M.Marble },
		wood = { color = rgb(110, 75, 45), material = M.Wood },
		tree = { color = rgb(60, 140, 60), material = M.Grass },
		Copper_1 = { color = rgb(196, 112, 60), material = M.Metal },
		Iron_1 = { color = rgb(176, 166, 156), material = M.Metal },
		nikel_1 = { color = rgb(150, 172, 160), material = M.Metal },
		coal = { color = rgb(40, 40, 46), material = M.Slate },
		oil = { color = rgb(30, 24, 40), material = M.SmoothPlastic },
		uranium = { color = rgb(100, 235, 90), material = M.Neon },
		goldOre = { color = rgb(240, 200, 60), material = M.Foil },
		gem = { color = rgb(80, 200, 255), material = M.Glass },
		bigGem = { color = rgb(255, 80, 200), material = M.Neon },
	},
	byFamily = {
		["경량"] = { color = rgb(170, 130, 90), material = M.WoodPlanks },
		["구조"] = { color = rgb(150, 150, 155), material = M.Concrete },
		["장갑"] = { color = rgb(160, 160, 170), material = M.DiamondPlate },
		["특수"] = { color = rgb(160, 210, 240), material = M.Glass },
	},
	DEFAULT = { color = rgb(200, 0, 200), material = M.SmoothPlastic },
}
