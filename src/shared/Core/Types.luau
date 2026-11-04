--!strict
--[[
	Shared type aliases for Minik Bahçe / Bahce Simulator core.
	Keep sim-agnostic where possible so other sims can reuse Core.
]]

export type Rarity = "Common" | "Uncommon" | "Rare" | "Epic" | "Legendary"

export type SeedConfig = {
	id: string,
	displayName: string,
	rarity: Rarity,
	growTimeSeconds: number,
	sellPrice: number,
	buyPrice: number,
	color: Color3,
	-- Asset hook: Roblox asset id (optional) OR ReplicatedStorage.Models name
	assetId: string?,
	-- Model names under ReplicatedStorage/Models (imported FBX from assets/models)
	modelSeedling: string?,
	modelMature: string?,
}

export type PlantInstance = {
	seedId: string,
	plantedAt: number, -- unix seconds (os.time)
	watered: boolean?, -- Sulama Kabı used
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
	dailyStreak: number?, -- last claimed calendar day (1..7)
	quests: any?, -- { day: number, list: { {id, progress, claimed} } }
	goldenPity: number?, -- harvests since last Golden/Rainbow mutation
	gear: { [string]: number }?, -- gearId -> count
	sprinkler: { startAt: number, endAt: number }?,
	fertilizerCharges: number?,
	collection: { [string]: number }?, -- cropKey -> first harvest time (0 = backfilled)
	collectionClaimed: { [string]: boolean }?,
	lastSeenAt: number?,
	decor: any?, -- { owned = {id->count}, placed = { {id, slot, rot} } } (kozmetik)
	likes: number?, -- alınan toplam beğeni
	likesGiven: any?, -- { day, targets = {userIdStr=true} }
	pets: any?, -- { owned, equipped, pity } (PetService)
	eventCurrency: { [string]: number }?, -- seasonal event currencies
	rebirthCount: number?, -- permanent sell multiplier stack
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
