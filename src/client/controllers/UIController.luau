--!strict
-- 지금 어느 화면을 띄울지 관리하고, 서버 데이터를 화면에 넘겨 준다.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Net = require(ReplicatedStorage.Shared.Net)
local getPlaceKind = require(script.Parent.Parent.util.PlaceKind)

local UIController = {}

local ui = script.Parent.Parent:WaitForChild("ui")
local hud: any = nil
local FlightController: any
local MiningController: any

function UIController:Init(controllers)
	FlightController = controllers.FlightController
	MiningController = controllers.MiningController
end

function UIController:Start()
	local kind = getPlaceKind()

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local screen = if kind == "island" then ui:WaitForChild("IslandHUD") else ui:WaitForChild("HubHUD")
	hud = require(screen :: ModuleScript)
	hud.Mount(playerGui)
	hud.Show()

	-- 두 화면 공통: 비행기 타기 버튼, 날 때 버튼 숨기기
	hud.OnFly(function()
		FlightController:RequestToggle()
	end)
	FlightController.FlyingChanged:Connect(function(flying: boolean)
		hud.SetFlying(flying)
	end)
	hud.SetFlying(FlightController:IsFlying())

	if kind == "island" then
		hud.OnHome(function()
			Net.event("GoHome"):FireServer()
		end)
		hud.OnBomb(function()
			MiningController:Drop()
		end)
		MiningController.CooldownStarted:Connect(function(seconds: number)
			hud.StartCooldown(seconds)
		end)
		Net.event("CargoChanged").OnClientEvent:Connect(function(c)
			hud.SetCargo(c.count, c.cap)
		end)
		Net.event("Hangar").OnClientEvent:Connect(function(kind: string, value: number?)
			if kind == "deposit" then
				hud.Toast(`+{value} 블록 보관됨!`)
			elseif kind == "repairStart" then
				hud.StartRepair(value or 3)
			elseif kind == "repairStop" then
				hud.StopRepair()
			elseif kind == "repairDone" then
				hud.StopRepair()
				hud.Toast("수리 완료! HP 가득")
			end
		end)
	else
		local menu = require(ui:WaitForChild("HangarMenu") :: ModuleScript) :: any
		menu.Mount(playerGui)
		hud.OnSortie(function()
			menu.Close()
			Net.event("Sortie"):FireServer()
		end)
		hud.OnHangar(function()
			menu.Toggle()
		end)
		FlightController.FlyingChanged:Connect(function(flying: boolean)
			if flying then
				menu.Close()
			end
		end)
		Net.event("StatsChanged").OnClientEvent:Connect(function(stats)
			menu.SetCoins(stats.coins)
		end)
	end

	-- 비행기 HP (허브 화면은 아직 HP 막대가 없어서 무시)
	Net.event("PlaneHp").OnClientEvent:Connect(function(hp: number, maxHp: number)
		if hud.SetHp then
			hud.SetHp(hp, maxHp)
		end
	end)
	Net.event("Notify").OnClientEvent:Connect(function(text: string, warn: boolean?)
		hud.Toast(text, warn)
	end)
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
