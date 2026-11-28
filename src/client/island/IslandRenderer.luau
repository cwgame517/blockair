--!strict
-- 섬 블록 배열을 화면에 그린다. 16×16×16 칸(청크)마다 "겉면이 보이는 블록"만 부품으로 만든다.
-- 같은 블록이 나란히 있으면 한 부품으로 합친다 (층마다 가로·세로로 넓게 묶기). 속에 묻힌 블록은 그리지 않는다.
-- 블록이 사라지면 그 청크(와 맞닿은 옆 청크)만 다시 그린다.
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local BlockInfo = require(ReplicatedStorage.Shared.Island.BlockInfo)

local CH = Config.Islands.CHUNK
local REBUILDS_PER_FRAME = 6
local CRACK_TRANSPARENCY = { 0.7, 0.55, 0.38 } -- 균열 단계별 어두운 정도

local IslandRenderer = {}
IslandRenderer.__index = IslandRenderer

export type Renderer = typeof(setmetatable(
	{} :: {
		grid: any,
		folder: Folder,
		crackFolder: Folder,
		chunks: { [number]: Model },
		cracks: { [number]: BasePart },
		dirty: { [number]: boolean },
		ncx: number,
		ncy: number,
		ncz: number,
		conn: RBXScriptConnection?,
	},
	IslandRenderer
))

function IslandRenderer.new(grid: any): Renderer
	local old = workspace:FindFirstChild("IslandBlocks")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "IslandBlocks"
	folder.Parent = workspace
	local crackFolder = Instance.new("Folder")
	crackFolder.Name = "Cracks"
	crackFolder.Parent = folder
	return setmetatable({
		grid = grid,
		folder = folder,
		crackFolder = crackFolder,
		chunks = {},
		cracks = {},
		dirty = {},
		ncx = math.ceil(grid.W / CH),
		ncy = math.ceil(grid.H / CH),
		ncz = math.ceil(grid.D / CH),
		conn = nil,
	}, IslandRenderer)
end

local function key(self: Renderer, cx: number, cy: number, cz: number): number
	return cx + self.ncx * (cz + self.ncz * cy)
end

local function makePart(grid: any, id: number, x: number, y: number, z: number, w: number, d: number, parent: Instance)
	local info = BlockInfo.byId[id]
	local bs = grid.BS
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(w * bs, bs, d * bs)
	p.CFrame = CFrame.new(grid.corner + Vector3.new(x + w / 2, y + 0.5, z + d / 2) * bs)
	if info then
		p.Color = info.color
		p.Material = info.material
	end
	p.Parent = parent
end

function IslandRenderer.buildChunk(self: Renderer, cx: number, cy: number, cz: number)
	local k = key(self, cx, cy, cz)
	local old = self.chunks[k]
	if old then
		old:Destroy()
		self.chunks[k] = nil
	end
	local grid = self.grid
	local W, H, D = grid.W, grid.H, grid.D
	local x0, y0, z0 = cx * CH, cy * CH, cz * CH
	local model: Model? = nil
	local mask = table.create(CH * CH, 0)

	for ly = 0, CH - 1 do
		local y = y0 + ly
		if y >= H then
			break
		end
		-- 이 층에서 겉면이 보이는 블록 표시
		local any = false
		for lz = 0, CH - 1 do
			local z = z0 + lz
			for lx = 0, CH - 1 do
				local x = x0 + lx
				local i = lx + lz * CH + 1
				local id = if x < W and z < D then grid:get(x, y, z) else 0
				if id ~= 0 and (
					grid:get(x + 1, y, z) == 0 or grid:get(x - 1, y, z) == 0
					or grid:get(x, y + 1, z) == 0 or grid:get(x, y - 1, z) == 0
					or grid:get(x, y, z + 1) == 0 or grid:get(x, y, z - 1) == 0
				) then
					mask[i] = id
					any = true
				else
					mask[i] = 0
				end
			end
		end
		if not any then
			continue
		end
		if not model then
			local m = Instance.new("Model")
			m.Name = `Chunk_{cx}_{cy}_{cz}`
			model = m
		end
		-- 같은 블록끼리 사각형으로 묶기
		for lz = 0, CH - 1 do
			for lx = 0, CH - 1 do
				local i = lx + lz * CH + 1
				local id = mask[i]
				if id == 0 then
					continue
				end
				local w = 1
				while lx + w < CH and mask[i + w] == id do
					w += 1
				end
				local d = 1
				while lz + d < CH do
					local row = i + d * CH
					local same = true
					for k2 = 0, w - 1 do
						if mask[row + k2] ~= id then
							same = false
							break
						end
					end
					if not same then
						break
					end
					d += 1
				end
				for dz = 0, d - 1 do
					for dx = 0, w - 1 do
						mask[i + dx + dz * CH] = 0
					end
				end
				makePart(grid, id, x0 + lx, y, z0 + lz, w, d, model :: Model)
			end
		end
	end

	if model then
		model.Parent = self.folder
		self.chunks[k] = model
	end
end

-- 처음 한 번 전부 그리기 (몇 청크마다 한 프레임 쉬어서 화면이 멈추지 않게)
function IslandRenderer.buildAll(self: Renderer)
	local n = 0
	for cy = self.ncy - 1, 0, -1 do -- 위쪽(땅 표면)부터
		for cz = 0, self.ncz - 1 do
			for cx = 0, self.ncx - 1 do
				self:buildChunk(cx, cy, cz)
				n += 1
				if n % 4 == 0 then
					task.wait()
				end
			end
		end
	end
	self.conn = RunService.Heartbeat:Connect(function()
		local done = 0
		for k in self.dirty do
			self.dirty[k] = nil
			local cx = k % self.ncx
			local rest = k // self.ncx
			local cz = rest % self.ncz
			local cy = rest // self.ncz
			self:buildChunk(cx, cy, cz)
			done += 1
			if done >= REBUILDS_PER_FRAME then
				break
			end
		end
	end)
end

local function markChunk(self: Renderer, cx: number, cy: number, cz: number)
	if cx >= 0 and cy >= 0 and cz >= 0 and cx < self.ncx and cy < self.ncy and cz < self.ncz then
		self.dirty[key(self, cx, cy, cz)] = true
	end
end

-- 칸 하나가 바뀌었다: 그 청크와, 경계에 있으면 옆 청크도 다시 그리기
function IslandRenderer.changed(self: Renderer, idx: number)
	local x, y, z = self.grid:coords(idx)
	local cx, cy, cz = x // CH, y // CH, z // CH
	markChunk(self, cx, cy, cz)
	local lx, ly, lz = x % CH, y % CH, z % CH
	if lx == 0 then markChunk(self, cx - 1, cy, cz) end
	if lx == CH - 1 then markChunk(self, cx + 1, cy, cz) end
	if ly == 0 then markChunk(self, cx, cy - 1, cz) end
	if ly == CH - 1 then markChunk(self, cx, cy + 1, cz) end
	if lz == 0 then markChunk(self, cx, cy, cz - 1) end
	if lz == CH - 1 then markChunk(self, cx, cy, cz + 1) end
	local crack = self.cracks[idx]
	if crack and self.grid:getIdx(idx) == 0 then
		crack:Destroy()
		self.cracks[idx] = nil
	end
end

-- 금 간 블록 위에 어두운 막을 씌운다 (단계가 오를수록 진해짐)
function IslandRenderer.setCrack(self: Renderer, idx: number, stage: number)
	if self.grid:getIdx(idx) == 0 then
		return
	end
	local p = self.cracks[idx]
	if not p then
		local grid = self.grid
		local x, y, z = grid:coords(idx)
		local np = Instance.new("Part")
		np.Anchored = true
		np.CanCollide = false
		np.CanTouch = false
		np.CanQuery = false
		np.CastShadow = false
		np.Size = Vector3.one * (grid.BS + 0.1)
		np.CFrame = CFrame.new(grid:cellCenter(x, y, z))
		np.Color = Color3.fromRGB(20, 16, 12)
		np.Material = Enum.Material.Slate
		np.Parent = self.crackFolder
		self.cracks[idx] = np
		p = np
	end
	(p :: BasePart).Transparency = CRACK_TRANSPARENCY[math.clamp(stage, 1, #CRACK_TRANSPARENCY)]
end

return IslandRenderer
