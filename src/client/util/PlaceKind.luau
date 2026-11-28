--!strict
-- 지금 서버가 허브인지 원정 섬인지 ("hub" | "island"). 서버가 정해 줄 때까지 기다린다.
local ReplicatedStorage = game:GetService("ReplicatedStorage")

return function(): string
	local kind = ReplicatedStorage:GetAttribute("PlaceKind")
	while kind == nil do
		ReplicatedStorage:GetAttributeChangedSignal("PlaceKind"):Wait()
		kind = ReplicatedStorage:GetAttribute("PlaceKind")
	end
	return kind :: string
end
