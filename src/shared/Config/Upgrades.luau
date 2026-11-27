--!strict
-- 격납고 강화. 원본: 성장 수치표 '격납고 강화' 시트 (임시값)
-- 단계 1 = 기본(무료), 단계 5 = 최대
local Upgrades = {}

Upgrades.STEP_COST = { 0, 1000, 10000, 80000, 400000 } -- 그 단계로 올리는 비용 (코인)
Upgrades.STEP_LEVEL = { 1, 3, 8, 15, 25 } -- 그 단계를 열 수 있는 레벨

Upgrades.ITEMS = {
	cargo = { name = "화물칸", unit = "칸", values = { 50, 70, 100, 140, 200 } },
	bombRadius = { name = "폭탄 범위", unit = "블록", values = { 2, 2.5, 3, 3.5, 4 } },
	bombReload = { name = "폭탄 재장전", unit = "초", values = { 1.5, 1.3, 1.1, 0.9, 0.7 } },
	bombPower = { name = "폭탄 위력", unit = "채굴력 +", values = { 0, 1, 2, 3, 5 } },
	missile = { name = "미사일 피해 (PvE)", unit = "%", values = { 0, 0.10, 0.25, 0.45, 0.70 } },
	cannon = { name = "기관포 피해 (PvE)", unit = "%", values = { 0, 0.10, 0.25, 0.45, 0.70 } },
	laser = { name = "레이저 피해 (PvE)", unit = "%", values = { 0, 0.10, 0.25, 0.45, 0.70 } },
}

-- 무기 강화 단계별 PvP 보너스 (최대 +20%)
Upgrades.WEAPON_PVP_BONUS = { 0, 0.05, 0.10, 0.15, 0.20 }

Upgrades.ORDER = { "cargo", "bombRadius", "bombReload", "bombPower", "missile", "cannon", "laser" }

return Upgrades
