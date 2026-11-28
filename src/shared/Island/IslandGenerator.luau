--!strict
-- 하늘 섬 만들기: (지름, 씨앗) → 섬 블록 배열.
-- 같은 지름·씨앗이면 서버와 클라이언트에서 똑같은 섬이 나온다.
-- 그래서 서버는 씨앗만 알려 주고, 클라이언트가 직접 만들어 그린다 (내려받을 것이 거의 없음).
--
-- 순서: 1) 노이즈로 섬 모양(위는 언덕, 아래는 뾰족한 뿌리)  2) 깊이별 바탕 층
--       3) 광맥(석탄·구리·금광석…)  4) 나무
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local IslandGrid = require(script.Parent.IslandGrid)
local BlockInfo = require(script.Parent.BlockInfo)

local Islands = Config.Islands

local IslandGenerator = {}

local function idOf(key: string): number
	local info = BlockInfo.byKey[key]
	assert(info, `섬 블록 key 를 찾을 수 없음: {key}`)
	return info.id
end

function IslandGenerator.generate(diameter: number, seed: number): IslandGrid.Grid
	local chunk = Islands.CHUNK
	local W = math.ceil(diameter / chunk) * chunk
	local D = W
	local H = Islands.HEIGHT
	local grid = IslandGrid.new(W, H, D)
	local rng = Random.new(seed)

	-- 노이즈를 씨앗마다 다른 곳에서 읽도록 옮기는 값
	local oxHill, ozHill = rng:NextNumber(0, 1000), rng:NextNumber(0, 1000)
	local oEdge = rng:NextNumber(0, 1000)
	local oThick = rng:NextNumber(0, 1000)
	local oPatch = rng:NextNumber(0, 1000)

	local scale = (diameter / 96) ^ 2
	local R = diameter / 2 - 1
	local c = (W - 1) / 2
	local wobble = Islands.EDGE_WOBBLE
	local patchThreshold = 0.4 - Islands.PATCH_CHANCE

	-- 층 블록 번호를 미리 찾아 둔다
	local layers = {}
	for _, l in Islands.LAYERS do
		table.insert(layers, {
			maxDepth = l.maxDepth,
			id = idOf(l.block),
			edgeId = if l.edgeBlock then idOf(l.edgeBlock) else nil,
			patchId = if l.patch then idOf(l.patch) else nil,
		})
	end

	local tops: { [number]: number } = {} -- [x + W*z] = 표면 높이
	local bottoms: { [number]: number } = {}
	local radii: { [number]: number } = {}

	-- 1·2) 모양과 바탕 층
	for z = 0, D - 1 do
		for x = 0, W - 1 do
			local dx, dz = x - c, z - c
			local dist = math.sqrt(dx * dx + dz * dz)
			if dist > R + 1 then
				continue
			end
			local ux, uz = 0, 1
			if dist > 0.001 then
				ux, uz = dx / dist, dz / dist
			end
			local wob = math.clamp(math.noise(ux * 1.7 + oEdge, uz * 1.7 + oEdge, 0.37) * 2, -1, 1)
			local reff = R * (1 - wobble * (0.5 + 0.5 * wob))
			local r = dist / reff
			if r >= 1 then
				continue
			end
			local hill = math.noise(x / 18 + oxHill, z / 18 + ozHill, 0.5) * Islands.HILL_HEIGHT * 2 * (1 - r * r)
			local top = math.clamp(Islands.TOP + math.floor(hill + 0.5), 2, H - 8)
			local tn = math.noise(x / 14 + oThick, z / 14 + oThick, 1.5)
			local thick = Islands.MIN_THICKNESS
				+ (Islands.MAX_THICKNESS - Islands.MIN_THICKNESS) * (1 - r) ^ 1.4 * (0.85 + 0.3 * tn)
			local bottom = math.max(1, top - math.floor(thick + 0.5))
			local col = x + W * z
			tops[col] = top
			bottoms[col] = bottom
			radii[col] = r
			local edge = r > 0.88
			for y = bottom, top do
				local d = top - y
				local id = 0
				for _, l in layers do
					if d <= l.maxDepth then
						id = if edge and l.edgeId then l.edgeId else l.id
						if l.patchId and math.noise(x / 6 + oPatch, y / 6, z / 6 + oPatch) > patchThreshold then
							id = l.patchId
						end
						break
					end
				end
				grid:set(x, y, z, id)
			end
		end
	end

	-- 표면이 있는 기둥 목록 (광맥·나무 자리 고르기용)
	local cols: { number } = {}
	for z = 0, D - 1 do
		for x = 0, W - 1 do
			if tops[x + W * z] then
				table.insert(cols, x + W * z)
			end
		end
	end
	if #cols == 0 then
		return grid
	end

	-- 3) 광맥
	local dirs = { { 1, 0, 0 }, { -1, 0, 0 }, { 0, 1, 0 }, { 0, -1, 0 }, { 0, 0, 1 }, { 0, 0, -1 } }
	for _, ore in Islands.ORES do
		local oreId = idOf(ore.block)
		local count = math.max(if ore.veins > 0 then 1 else 0, math.floor(ore.veins * scale + 0.5))
		for _ = 1, count do
			-- 그 깊이까지 땅이 있는 기둥을 찾는다
			for _try = 1, 30 do
				local col = cols[rng:NextInteger(1, #cols)]
				local top, bottom = tops[col], bottoms[col]
				local maxD = math.min(ore.maxDepth, top - bottom)
				if maxD < ore.minDepth then
					continue
				end
				local x, z = col % W, col // W
				local y = top - rng:NextInteger(ore.minDepth, maxD)
				for _ = 1, ore.size do
					if grid:inside(x, y, z) and grid:get(x, y, z) ~= 0 then
						local ctop = tops[x + W * z]
						if ctop and y < ctop then -- 표면(잔디)은 그대로 둔다
							grid:set(x, y, z, oreId)
						end
					end
					local dir = dirs[rng:NextInteger(1, 6)]
					x, y, z = x + dir[1], y + dir[2], z + dir[3]
				end
				break
			end
		end
	end

	-- 4) 나무: 원목 기둥 + 나뭇잎(나무 블록)
	local woodId, leafId = idOf("wood"), idOf("tree")
	local grassId = idOf("grass")
	local trees = math.floor(Islands.TREES_PER_96 * scale + 0.5)
	for _ = 1, trees do
		for _try = 1, 20 do
			local col = cols[rng:NextInteger(1, #cols)]
			if radii[col] > 0.75 then
				continue
			end
			local x, z = col % W, col // W
			local top = tops[col]
			if grid:get(x, top, z) ~= grassId or top + 7 >= H then
				continue
			end
			local trunk = rng:NextInteger(3, 5)
			for y = top + 1, top + trunk do
				grid:set(x, y, z, woodId)
			end
			for y = top + trunk - 1, top + trunk + 1 do
				for lx = x - 1, x + 1 do
					for lz = z - 1, z + 1 do
						if grid:inside(lx, y, lz) and grid:get(lx, y, lz) == 0 then
							grid:set(lx, y, lz, leafId)
						end
					end
				end
			end
			grid:set(x, top + trunk + 2, z, leafId)
			break
		end
	end

	return grid
end

return IslandGenerator
