--!strict
-- 클라이언트 시작점. controllers 폴더의 컨트롤러를 모두 Init 한 뒤 Start 한다.
local Client = script.Parent

local controllers: { [string]: any } = {}
local order: { string } = {}

for _, child in (Client:WaitForChild("controllers")):GetChildren() do
	if child:IsA("ModuleScript") then
		local ok, mod = pcall(require, child)
		if ok then
			controllers[child.Name] = mod
			table.insert(order, child.Name)
		else
			warn(`[Client] {child.Name} 불러오기 실패: {mod}`)
		end
	end
end

for _, name in order do
	local c = controllers[name]
	if c.Init then
		c:Init(controllers)
	end
end
for _, name in order do
	local c = controllers[name]
	if c.Start then
		task.spawn(c.Start, c)
	end
end
