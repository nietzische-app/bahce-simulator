--!strict
--[[
	Shared type aliases for Minik Bahçe / Bahce Simulator core.
	Keep sim-agnostic where possible so other sims can reuse Core.
]]

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic"

export type SeedConfig = {
	id: string,
	displayName: string,
	rarity: Rarity,
	growTimeSeconds: number,
	sellPrice: number,
	buyPrice: number,
	color: Color3,
	-- Asset hook: replace placeholder with Studio/AI mesh later
	assetId: string?,
}

export type PlantInstance = {
	seedId: string,
	plantedAt: number, -- unix seconds (os.time)
	slotIndex: number,
}

export type UpgradeState = {
	extraSlots: number,
	growthSpeedLevel: number,
}

export type PurchaseRecord = {
	purchaseId: string,
	productId: number,
	boughtAt: number,
}

export type PlayerData = {
	coins: number,
	inventory: { [string]: number }, -- seedId -> count
	plants: { PlantInstance },
	upgrades: UpgradeState,
	ownedGamepasses: { [string]: boolean },
	purchaseHistory: { PurchaseRecord },
	lastDailyClaim: number, -- unix day index or timestamp
	totalHarvested: number,
	totalEarned: number,
	plotIndex: number?, -- assigned plot (persisted preference)
	sessionLockId: string?,
	sessionLockExpires: number?,
	dataVersion: number,
}

export type WeatherEvent = {
	id: string,
	displayName: string,
	description: string,
	growthMultiplier: number,
	sellMultiplier: number,
	durationSeconds: number,
	weight: number, -- relative chance when rolling weekly event
}

return {}
