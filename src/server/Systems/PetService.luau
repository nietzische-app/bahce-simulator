--!strict
--[[
	Pets: coin-only eggs, public odds + pity, equip up to 3, no trading.
	Data: data.pets = {
	  owned = { { uid, petId, obtainedAt } },
	  equipped = { uid, ... }, -- max 3
	  pity = { [eggId] = number },
	}
]]

local Pets = require(game.ReplicatedStorage.Shared.Config.Pets)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)

local PetService = {}
PetService.rng = Random.new() :: any
PetService._uidCounter = 0

local function newUid(): string
	PetService._uidCounter += 1
	return string.format("pet_%d_%d", os.time(), PetService._uidCounter)
end

function PetService.Ensure(data: Types.PlayerData): any
	local p: any = (data :: any).pets
	if typeof(p) ~= "table" then
		p = {}
		(data :: any).pets = p
	end
	if typeof(p.owned) ~= "table" then
		p.owned = {}
	end
	if typeof(p.equipped) ~= "table" then
		p.equipped = {}
	end
	if typeof(p.pity) ~= "table" then
		p.pity = {}
	end
	-- Drop unknown pets / invalid equipped refs
	local byUid: { [string]: any } = {}
	local cleanOwned = {}
	for _, o in p.owned do
		if
			typeof(o) == "table"
			and typeof(o.uid) == "string"
			and typeof(o.petId) == "string"
			and Pets.GetPet(o.petId)
		then
			table.insert(cleanOwned, {
				uid = o.uid,
				petId = o.petId,
				obtainedAt = if typeof(o.obtainedAt) == "number" then o.obtainedAt else 0,
			})
			byUid[o.uid] = true
		end
	end
	p.owned = cleanOwned
	local cleanEq = {}
	local seen = {}
	for _, uid in p.equipped do
		if typeof(uid) == "string" and byUid[uid] and not seen[uid] and #cleanEq < Pets.MAX_EQUIPPED then
			seen[uid] = true
			table.insert(cleanEq, uid)
		end
	end
	p.equipped = cleanEq
	return p
end

local function findOwned(p: any, uid: string): (number?, any)
	for i, o in p.owned do
		if o.uid == uid then
			return i, o
		end
	end
	return nil, nil
end

function PetService.GrowthMultiplier(data: Types.PlayerData): number
	local p = PetService.Ensure(data)
	local m = 1
	for _, uid in p.equipped do
		local _, o = findOwned(p, uid)
		if o then
			local cfg = Pets.GetPet(o.petId)
			if cfg and cfg.bonus.growth then
				m *= cfg.bonus.growth
			end
		end
	end
	return m
end

function PetService.SellMultiplier(data: Types.PlayerData): number
	local p = PetService.Ensure(data)
	local m = 1
	for _, uid in p.equipped do
		local _, o = findOwned(p, uid)
		if o then
			local cfg = Pets.GetPet(o.petId)
			if cfg and cfg.bonus.sell then
				m *= cfg.bonus.sell
			end
		end
	end
	return m
end

local function rollPet(egg: any, pity: number, rng: any): (string, number)
	local nextPity = pity + 1
	if nextPity >= egg.pity then
		return egg.pityPetId, 0
	end
	local roll = rng:NextNumber()
	local acc = 0
	for _, o in egg.outcomes do
		acc += o.chance
		if roll < acc then
			if o.petId == egg.pityPetId then
				return o.petId, 0
			end
			return o.petId, nextPity
		end
	end
	-- Fallback: first outcome (every egg gives something useful)
	local first = egg.outcomes[1].petId
	if first == egg.pityPetId then
		return first, 0
	end
	return first, nextPity
end

function PetService.BuyEgg(data: Types.PlayerData, eggId: string): (boolean, string, string?)
	local p = PetService.Ensure(data)
	local egg = Pets.GetEgg(eggId)
	if not egg then
		return false, "Geçersiz yumurta.", nil
	end
	if #p.owned >= Pets.MAX_OWNED then
		return false, "Pet koleksiyonun dolu.", nil
	end
	if data.coins < egg.price then
		return false, "Yeterli coin yok.", nil
	end
	data.coins -= egg.price
	local pity = p.pity[eggId] or 0
	local petId, newPity = rollPet(egg, pity, PetService.rng)
	p.pity[eggId] = newPity
	local cfg = Pets.GetPet(petId)
	if not cfg then
		-- Should never happen; refund
		data.coins += egg.price
		return false, "Pet yapılandırması eksik.", nil
	end
	local uid = newUid()
	table.insert(p.owned, { uid = uid, petId = petId, obtainedAt = os.time() })
	local pityLeft = egg.pity - newPity
	return true,
		string.format(
			"%s çıktı! (%s)  — %s garantisine %d yumurta",
			cfg.displayName,
			cfg.description,
			(Pets.GetPet(egg.pityPetId) :: any).displayName,
			math.max(0, pityLeft)
		),
		petId
end

-- Grant a rolled pet without charging (event shop egg grant)
function PetService.GrantRolledEgg(data: Types.PlayerData, eggId: string): (boolean, string)
	local p = PetService.Ensure(data)
	local egg = Pets.GetEgg(eggId)
	if not egg then
		return false, "Geçersiz yumurta."
	end
	if #p.owned >= Pets.MAX_OWNED then
		return false, "Pet koleksiyonun dolu."
	end
	local pity = p.pity[eggId] or 0
	local petId, newPity = rollPet(egg, pity, PetService.rng)
	p.pity[eggId] = newPity
	local cfg = Pets.GetPet(petId)
	if not cfg then
		return false, "Pet yapılandırması eksik."
	end
	table.insert(p.owned, {
		uid = newUid(),
		petId = petId,
		obtainedAt = os.time(),
	})
	return true, string.format("%s çıktı! (%s)", cfg.displayName, cfg.description)
end

function PetService.Equip(data: Types.PlayerData, uid: string): (boolean, string)
	local p = PetService.Ensure(data)
	if typeof(uid) ~= "string" or #uid > 64 then
		return false, "Geçersiz pet."
	end
	local _, o = findOwned(p, uid)
	if not o then
		return false, "Bu pet sende yok."
	end
	for _, e in p.equipped do
		if e == uid then
			return false, "Zaten kuşatılmış."
		end
	end
	if #p.equipped >= Pets.MAX_EQUIPPED then
		return false, string.format("En fazla %d pet kuşatabilirsin.", Pets.MAX_EQUIPPED)
	end
	table.insert(p.equipped, uid)
	local cfg = Pets.GetPet(o.petId)
	return true, string.format("%s kuşatıldı!", if cfg then cfg.displayName else o.petId)
end

function PetService.Unequip(data: Types.PlayerData, uid: string): (boolean, string)
	local p = PetService.Ensure(data)
	for i, e in p.equipped do
		if e == uid then
			table.remove(p.equipped, i)
			return true, "Pet bırakıldı."
		end
	end
	return false, "Bu pet kuşatılı değil."
end

function PetService.Serialize(data: Types.PlayerData)
	local p = PetService.Ensure(data)
	local owned = {}
	for _, o in p.owned do
		local cfg = Pets.GetPet(o.petId)
		table.insert(owned, {
			uid = o.uid,
			petId = o.petId,
			displayName = if cfg then cfg.displayName else o.petId,
			description = if cfg then cfg.description else "",
			modelName = if cfg then cfg.modelName else "",
			rarity = if cfg then cfg.rarity else "",
			bonus = if cfg then cfg.bonus else {},
			equipped = table.find(p.equipped, o.uid) ~= nil,
		})
	end
	local eggs = {}
	for _, e in Pets.ListEggs() do
		local pity = p.pity[e.id] or 0
		table.insert(eggs, {
			id = e.id,
			displayName = e.displayName,
			price = e.price,
			odds = Pets.FormatOdds(e.id),
			pityLeft = math.max(0, e.pity - pity),
			pity = e.pity,
		})
	end
	return {
		owned = owned,
		equipped = p.equipped,
		eggs = eggs,
		maxEquipped = Pets.MAX_EQUIPPED,
		growthMult = PetService.GrowthMultiplier(data),
		sellMult = PetService.SellMultiplier(data),
		catalog = Pets.ListPets(),
	}
end

-- Equipped pet descriptors for follower visuals
function PetService.EquippedVisuals(
	data: Types.PlayerData
): { { uid: string, petId: string, modelName: string, color: Color3 } }
	local p = PetService.Ensure(data)
	local out = {}
	for _, uid in p.equipped do
		local _, o = findOwned(p, uid)
		if o then
			local cfg = Pets.GetPet(o.petId)
			if cfg then
				table.insert(out, {
					uid = uid,
					petId = o.petId,
					modelName = cfg.modelName,
					color = cfg.placeholderColor,
				})
			end
		end
	end
	return out
end

return PetService
