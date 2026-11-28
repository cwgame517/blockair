--!strict
-- 서버 시작점. common 과 place(허브 또는 섬) 폴더의 서비스를 모두 불러와
-- 먼저 전부 Init(services) 하고, 그다음 전부 Start() 한다.
local Server = script.Parent

type Service = { Init: ((Service, { [string]: any }) -> ())?, Start: ((Service) -> ())? }

local services: { [string]: any } = {}
local order: { string } = {}

local function collect(folder: Instance?)
	if not folder then
		return
	end
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") then
			local ok, mod = pcall(require, child)
			if not ok then
				warn(`[Server] {child.Name} 불러오기 실패: {mod}`)
				continue
			end
			services[child.Name] = mod
			table.insert(order, child.Name)
		end
	end
end

collect(Server:FindFirstChild("common"))
collect(Server:FindFirstChild("place"))

for _, name in order do
	local s = services[name] :: Service
	if s.Init then
		s:Init(services)
	end
end
for _, name in order do
	local s = services[name] :: Service
	if s.Start then
		task.spawn(s.Start, s)
	end
end

print(`[Server] 서비스 {#order}개 시작: {table.concat(order, ", ")}`)
