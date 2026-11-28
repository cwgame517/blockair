--!strict
-- 지금 어느 화면을 띄울지 관리하고, 서버 데이터를 화면에 넘겨 준다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)

local UIController = {}

local ui = script.Parent.Parent:WaitForChild("ui")
local hud: any = nil

function UIController:Init(_controllers) end

function UIController:Start()
	local kind = ReplicatedStorage:GetAttribute("PlaceKind")
	while kind == nil do
		ReplicatedStorage:GetAttributeChangedSignal("PlaceKind"):Wait()
		kind = ReplicatedStorage:GetAttribute("PlaceKind")
	end

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = if kind == "island" then ui:WaitForChild("IslandHUD") else ui:WaitForChild("HubHUD")
	hud = require(screen :: ModuleScript)
	hud.Mount(playerGui)
	hud.Show()

	Net.event("ProfileLoaded").OnClientEvent:Connect(function(stats)
		hud.SetStats(stats)
	end)
	Net.event("StatsChanged").OnClientEvent:Connect(function(stats)
		hud.SetStats(stats)
	end)
	Net.event("LevelUp").OnClientEvent:Connect(function(level, unlock)
		hud.ShowLevelUp(level, unlock)
	end)

	-- 이벤트보다 늦게 붙었을 때를 대비해 한 번 직접 받아 온다
	task.spawn(function()
		local stats = Net.func("GetProfile"):InvokeServer()
		if stats then
			hud.SetStats(stats)
		end
	end)
end

return UIController
