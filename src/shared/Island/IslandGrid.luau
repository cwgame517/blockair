--!strict
-- 섬 블록 배열. 칸마다 블록 번호 1바이트 (0 = 빈 칸).
-- 서버와 클라이언트가 같은 모듈을 쓴다. 서버는 이 배열만 갖고, 클라이언트는 이걸 보고 겉면만 그린다.
--
-- 좌표: x(0..W-1), y(0..H-1, 위로 +), z(0..D-1). 번호(idx) = x + W*(z + D*y)
-- 월드 위치: 섬 가운데가 X=0, Z=0. TOP 높이 칸의 윗면이 Y=0.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local Islands = Config.Islands

local IslandGrid = {}
IslandGrid.__index = IslandGrid

export type Grid = typeof(setmetatable(
	{} :: { W: number, H: number, D: number, BS: number, data: buffer, corner: Vector3 },
	IslandGrid
))

function IslandGrid.new(W: number, H: number, D: number, data: buffer?): Grid
	local BS = Islands.BLOCK_SIZE
	local self = setmetatable({
		W = W,
		H = H,
		D = D,
		BS = BS,
		data = data or buffer.create(W * H * D),
		corner = Vector3.new(-W / 2 * BS, -(Islands.TOP + 1) * BS, -D / 2 * BS),
	}, IslandGrid)
	return self
end

function IslandGrid.inside(self: Grid, x: number, y: number, z: number): boolean
	return x >= 0 and y >= 0 and z >= 0 and x < self.W and y < self.H and z < self.D
end

function IslandGrid.index(self: Grid, x: number, y: number, z: number): number
	return x + self.W * (z + self.D * y)
end

function IslandGrid.coords(self: Grid, idx: number): (number, number, number)
	local x = idx % self.W
	local rest = idx // self.W
	return x, rest // self.D, rest % self.D
end

-- 칸 밖은 빈 칸(0)
function IslandGrid.get(self: Grid, x: number, y: number, z: number): number
	if x < 0 or y < 0 or z < 0 or x >= self.W or y >= self.H or z >= self.D then
		return 0
	end
	return buffer.readu8(self.data, x + self.W * (z + self.D * y))
end

function IslandGrid.set(self: Grid, x: number, y: number, z: number, id: number)
	buffer.writeu8(self.data, x + self.W * (z + self.D * y), id)
end

function IslandGrid.getIdx(self: Grid, idx: number): number
	return buffer.readu8(self.data, idx)
end

function IslandGrid.setIdx(self: Grid, idx: number, id: number)
	buffer.writeu8(self.data, idx, id)
end

-- 월드 위치 → 칸 좌표 (정수, 칸 밖일 수도 있음)
function IslandGrid.toCell(self: Grid, pos: Vector3): (number, number, number)
	local p = (pos - self.corner) / self.BS
	return math.floor(p.X), math.floor(p.Y), math.floor(p.Z)
end

-- 칸 가운데의 월드 위치
function IslandGrid.cellCenter(self: Grid, x: number, y: number, z: number): Vector3
	return self.corner + Vector3.new(x + 0.5, y + 0.5, z + 0.5) * self.BS
end

function IslandGrid.solidAt(self: Grid, pos: Vector3): boolean
	local x, y, z = self:toCell(pos)
	return self:get(x, y, z) ~= 0
end

-- 같은 섬인지 확인하는 짧은 지문 (서버와 클라이언트가 똑같이 만들었는지 비교)
function IslandGrid.checksum(self: Grid): number
	local h = 0
	local data = self.data
	for i = 0, buffer.len(data) - 1 do
		h = (h * 31 + buffer.readu8(data, i)) % 2147483647
	end
	return h
end

return IslandGrid
