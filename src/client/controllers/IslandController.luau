--!strict
-- (원정 섬에서만) 서버에게 씨앗을 받아 섬을 직접 만들고 화면에 그린다.
-- 그 뒤로는 서버가 알려 주는 "사라진 칸·금 간 칸"만 반영한다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local Signal = require(ReplicatedStorage.Shared.Util.Signal)
local IslandGenerator = require(ReplicatedStorage.Shared.Island.IslandGenerator)
local IslandGrid = require(ReplicatedStorage.Shared.Island.IslandGrid)
local IslandRenderer = require(script.Parent.Parent.island.IslandRenderer)
local getPlaceKind = require(script.Parent.Parent.util.PlaceKind)

local IslandController = {}
IslandController.Ready = Signal.new() -- (grid)

local grid: any = nil
local renderer: IslandRenderer.Renderer? = nil

-- 섬 배열 (아직 준비 전이면 기다림)
function IslandController:WaitGrid(): any
	while not grid do
		task.wait(0.1)
	end
	return grid
end

function IslandController:GetGrid(): any
	return grid
end

local function applyChanges(r: IslandRenderer.Renderer, g: any, removed: { number }, dIdx: { number }, dStage: { number })
	for _, idx in removed do
		g:setIdx(idx, 0)
		r:changed(idx)
	end
	for i, idx in dIdx do
		r:setCrack(idx, dStage[i])
	end
end

function IslandController:Init(_controllers) end

function IslandController:Start()
	if getPlaceKind() ~= "island" then
		return
	end

	-- 준비되는 동안 온 변화는 모아 뒀다가 나중에 반영
	local pending: { { any } } = {}
	Net.event("BlocksChanged").OnClientEvent:Connect(function(removed, dIdx, dStage)
		local r = renderer
		if r and grid then
			applyChanges(r, grid, removed, dIdx, dStage)
		else
			table.insert(pending, { removed, dIdx, dStage })
		end
	end)

	local info = nil
	while not info do
		info = Net.func("GetIslandInfo"):InvokeServer()
		if not info then
			task.wait(1)
		end
	end

	local t0 = os.clock()
	local g = IslandGenerator.generate(info.diameter, info.seed)
	local genMs = math.floor((os.clock() - t0) * 1000 + 0.5)
	local fromServer = false
	if g:checksum() ~= info.checksum then
		-- 드물게 계산 결과가 다르면 서버 배열을 통째로 받는다 (사라진 칸까지 반영돼 있음)
		local data = Net.func("GetIslandData"):InvokeServer()
		if data then
			g = IslandGrid.new(data.W, data.H, data.D, data.data)
			fromServer = true
		end
	end
	if not fromServer then
		for _, idx in info.removed do
			g:setIdx(idx, 0)
		end
	end

	local t1 = os.clock()
	local r = IslandRenderer.new(g)
	r:buildAll()
	local drawMs = math.floor((os.clock() - t1) * 1000 + 0.5)
	print(`[Island] 섬 만들기 {genMs}ms, 그리기 {drawMs}ms{if fromServer then " (서버 배열 사용)" else ""}`)

	for i, idx in info.damagedIdx do
		r:setCrack(idx, info.damagedStage[i])
	end
	grid = g
	renderer = r
	for _, ch in pending do
		applyChanges(r, g, ch[1], ch[2], ch[3])
	end
	pending = {}
	IslandController.Ready:Fire(g)
end

return IslandController
