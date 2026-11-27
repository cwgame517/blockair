--!strict
-- 기체 틀 등급. 원본: 성장 수치표 '기체 틀' 시트 (임시값)
export type FrameClass = {
	id: string, name: string, unlockLevel: number, cells: number, weaponSlots: number,
	pvpHp: number, pveBaseHp: number, hitSphereDiameter: number,
}

local classes: { FrameClass } = {
	{ id = "small", name = "소형", unlockLevel = 1, cells = 50, weaponSlots = 1, pvpHp = 1000, pveBaseHp = 1000, hitSphereDiameter = 6 },
	{ id = "medium", name = "중형", unlockLevel = 5, cells = 150, weaponSlots = 2, pvpHp = 1150, pveBaseHp = 1600, hitSphereDiameter = 9 },
	{ id = "large", name = "대형", unlockLevel = 15, cells = 300, weaponSlots = 3, pvpHp = 1300, pveBaseHp = 2500, hitSphereDiameter = 12 },
	{ id = "xlarge", name = "초대형", unlockLevel = 30, cells = 500, weaponSlots = 4, pvpHp = 1500, pveBaseHp = 3600, hitSphereDiameter = 15 },
}

local byId: { [string]: FrameClass } = {}
for _, c in classes do
	byId[c.id] = c
end

-- PvE HP = 기본 HP + Σ(칸마다 블록 단단함 × 2)
local PVE_HP_PER_HARDNESS = 2

return { classes = classes, byId = byId, PVE_HP_PER_HARDNESS = PVE_HP_PER_HARDNESS }
