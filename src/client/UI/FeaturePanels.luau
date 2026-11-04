--!strict
--[[
	Evcil hayvan / Etkinlik / Üretim / Yeniden Doğuş panelleri (Türkçe UI).
	Yumurta oranları ve pity açıkça gösterilir. Rebirth onay diyaloğu zorunlu.
]]

local Players = game:GetService("Players")

local FeaturePanels = {}

local function corner(p: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local function button(parent: Instance, text: string, size: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.BackgroundColor3 = color
	b.Text = text
	b.TextScaled = true
	b.TextWrapped = true
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = parent
	corner(b, 8)
	return b
end

local function label(parent: Instance, text: string, h: number, bold: boolean?, color: Color3?): TextLabel
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -8, 0, h)
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextWrapped = true
	t.TextScaled = true
	t.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	t.TextColor3 = color or Color3.new(1, 1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = parent
	return t
end

local function panel(gui: ScreenGui, name: string, title: string): (Frame, ScrollingFrame)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.new(0, 400, 0, 460)
	f.Position = UDim2.new(0.5, -200, 0.5, -230)
	f.BackgroundColor3 = Color3.fromRGB(40, 48, 55)
	f.Visible = false
	f.Parent = gui
	corner(f, 12)
	local t = Instance.new("TextLabel")
	t.Size = UDim2.new(1, -50, 0, 34)
	t.Position = UDim2.fromOffset(10, 4)
	t.BackgroundTransparency = 1
	t.Text = title
	t.TextScaled = true
	t.Font = Enum.Font.GothamBold
	t.TextColor3 = Color3.new(1, 1, 1)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = f
	local close = button(f, "X", UDim2.fromOffset(32, 32), Color3.fromRGB(150, 70, 70))
	close.Position = UDim2.new(1, -38, 0, 4)
	close.MouseButton1Click:Connect(function()
		f.Visible = false
	end)
	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -16, 1, -48)
	list.Position = UDim2.fromOffset(8, 42)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = f
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = list
	return f, list
end

local function clear(list: Instance)
	for _, c in list:GetChildren() do
		if c:IsA("GuiObject") then
			c:Destroy()
		end
	end
end

function FeaturePanels.Create(remotes: Folder, _notify: (string, string?) -> ())
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("MinikBahceFeatures")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MinikBahceFeatures"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 6
	gui.Parent = pg

	local side = Instance.new("Frame")
	side.Name = "FeatureButtons"
	side.Size = UDim2.new(0, 140, 0, 200)
	side.Position = UDim2.new(0, 10, 0.5, -20)
	side.BackgroundTransparency = 1
	side.Parent = gui
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 8)
	lay.Parent = side

	local petsFrame, petsList = panel(gui, "Pets", "Evcil Hayvanlar")
	local eventsFrame, eventsList = panel(gui, "Events", "Etkinlikler")
	local craftFrame, craftList = panel(gui, "Craft", "Üretim")
	local rebirthFrame, rebirthList = panel(gui, "Rebirth", "Yeniden Doğuş")

	-- Confirm overlay for rebirth
	local confirm = Instance.new("Frame")
	confirm.Name = "RebirthConfirm"
	confirm.Size = UDim2.new(0, 360, 0, 220)
	confirm.Position = UDim2.new(0.5, -180, 0.5, -110)
	confirm.BackgroundColor3 = Color3.fromRGB(60, 35, 35)
	confirm.Visible = false
	confirm.ZIndex = 10
	confirm.Parent = gui
	corner(confirm, 12)
	local confirmLabel = label(confirm, "", 120, false)
	confirmLabel.Position = UDim2.fromOffset(12, 10)
	confirmLabel.Size = UDim2.new(1, -24, 0, 120)
	confirmLabel.TextXAlignment = Enum.TextXAlignment.Center
	local yesBtn = button(confirm, "Evet, Yeniden Doğ", UDim2.new(0.45, 0, 0, 40), Color3.fromRGB(160, 60, 60))
	yesBtn.Position = UDim2.new(0.05, 0, 1, -55)
	local noBtn = button(confirm, "Vazgeç", UDim2.new(0.45, 0, 0, 40), Color3.fromRGB(70, 90, 80))
	noBtn.Position = UDim2.new(0.5, 0, 1, -55)
	noBtn.MouseButton1Click:Connect(function()
		confirm.Visible = false
	end)

	local pendingPhrase = ""
	yesBtn.MouseButton1Click:Connect(function()
		confirm.Visible = false
		(remotes:WaitForChild("Rebirth") :: RemoteEvent):FireServer(pendingPhrase)
	end)

	local btnPets = button(side, "Petler", UDim2.new(1, 0, 0, 40), Color3.fromRGB(180, 120, 80))
	local btnEvents = button(side, "Etkinlik", UDim2.new(1, 0, 0, 40), Color3.fromRGB(80, 140, 160))
	local btnCraft = button(side, "Üretim", UDim2.new(1, 0, 0, 40), Color3.fromRGB(100, 130, 90))
	local btnRebirth = button(side, "Yeniden Doğuş", UDim2.new(1, 0, 0, 40), Color3.fromRGB(140, 70, 90))

	local function hideAll()
		petsFrame.Visible = false
		eventsFrame.Visible = false
		craftFrame.Visible = false
		rebirthFrame.Visible = false
		confirm.Visible = false
	end

	btnPets.MouseButton1Click:Connect(function()
		local v = not petsFrame.Visible
		hideAll()
		petsFrame.Visible = v
	end)
	btnEvents.MouseButton1Click:Connect(function()
		local v = not eventsFrame.Visible
		hideAll()
		eventsFrame.Visible = v
	end)
	btnCraft.MouseButton1Click:Connect(function()
		local v = not craftFrame.Visible
		hideAll()
		craftFrame.Visible = v
	end)
	btnRebirth.MouseButton1Click:Connect(function()
		local v = not rebirthFrame.Visible
		hideAll()
		rebirthFrame.Visible = v
	end)

	local state: any = {}

	local function refreshPets()
		clear(petsList)
		local pets = state.pets
		if typeof(pets) ~= "table" then
			label(petsList, "Pet verisi yok.", 24)
			return
		end
		label(petsList, "Yumurtalar (sadece coin — takas yok)", 24, true, Color3.fromRGB(255, 230, 160))
		for _, e in pets.eggs or {} do
			local row = button(
				petsList,
				string.format(
					"%s — %d coin\nOranlar: %s\nGarantiye %d yumurta kaldı",
					e.displayName,
					e.price,
					e.odds,
					e.pityLeft
				),
				UDim2.new(1, -8, 0, 72),
				Color3.fromRGB(120, 90, 50)
			)
			row.MouseButton1Click:Connect(function()
				(remotes:WaitForChild("BuyEgg") :: RemoteEvent):FireServer(e.id)
			end)
		end
		label(
			petsList,
			string.format(
				"Kuşatılan: %d/%d  (büyüme ×%.2f, satış ×%.2f)",
				#(pets.equipped or {}),
				pets.maxEquipped or 3,
				pets.growthMult or 1,
				pets.sellMult or 1
			),
			28,
			true
		)
		label(petsList, "Koleksiyonun (takas / hediye yok)", 22, true, Color3.fromRGB(200, 220, 255))
		for _, o in pets.owned or {} do
			local txt = string.format(
				"%s [%s] — %s%s",
				o.displayName,
				o.rarity,
				o.description,
				if o.equipped then "  ✓ kuşatılı" else ""
			)
			local row = button(
				petsList,
				txt,
				UDim2.new(1, -8, 0, 44),
				if o.equipped then Color3.fromRGB(70, 120, 90) else Color3.fromRGB(60, 70, 90)
			)
			row.MouseButton1Click:Connect(function()
				if o.equipped then
					(remotes:WaitForChild("UnequipPet") :: RemoteEvent):FireServer(o.uid)
				else
					(remotes:WaitForChild("EquipPet") :: RemoteEvent):FireServer(o.uid)
				end
			end)
		end
		if #(pets.owned or {}) == 0 then
			label(petsList, "Henüz petin yok. Coin ile yumurta al!", 22)
		end
	end

	local function refreshEvents()
		clear(eventsList)
		local ev = state.events
		if typeof(ev) ~= "table" then
			label(eventsList, "Etkinlik verisi yok.", 24)
			return
		end
		if #(ev.active or {}) == 0 then
			label(eventsList, "Şu an aktif etkinlik yok. FOMO yok — ödüller sonra da alınır.", 36)
		end
		for _, a in ev.active or {} do
			label(eventsList, a.displayName, 26, true, Color3.fromRGB(180, 230, 255))
			label(eventsList, a.description, 36)
			label(
				eventsList,
				string.format("%s: %d (hasatta +%d)", a.currencyName, a.balance or 0, a.harvestCurrency or 0),
				24,
				true
			)
			for _, item in a.shop or {} do
				local row = button(
					eventsList,
					string.format(
						"%s — %d %s\n%s",
						item.displayName,
						item.eventCost,
						a.currencyName,
						item.description
					),
					UDim2.new(1, -8, 0, 52),
					Color3.fromRGB(60, 110, 140)
				)
				row.MouseButton1Click:Connect(function()
					(remotes:WaitForChild("BuyEventItem") :: RemoteEvent):FireServer(a.id, item.id)
				end)
			end
		end
		label(eventsList, "Eski Etkinlikler (coin ile hâlâ alınabilir)", 26, true, Color3.fromRGB(255, 210, 140))
		if #(ev.legacy or {}) == 0 then
			label(eventsList, "Henüz bitmiş etkinlik yok.", 22)
		end
		for _, leg in ev.legacy or {} do
			label(eventsList, leg.displayName, 24, true)
			for _, item in leg.shop or {} do
				local row = button(
					eventsList,
					string.format("%s — %d coin\n%s", item.displayName, item.legacyCoinCost, item.description),
					UDim2.new(1, -8, 0, 52),
					Color3.fromRGB(100, 90, 60)
				)
				row.MouseButton1Click:Connect(function()
					(remotes:WaitForChild("BuyLegacyEventItem") :: RemoteEvent):FireServer(leg.id, item.id)
				end)
			end
		end
	end

	local function refreshCraft()
		clear(craftList)
		local c = state.crafting
		label(craftList, "Tarifler (ürün + coin → alet/dekor/tohum)", 28, true)
		label(craftList, "Loot box yok; sunucu doğrular.", 20)
		if typeof(c) ~= "table" then
			return
		end
		for _, r in c.recipes or {} do
			local row = button(
				craftList,
				string.format("%s — %d coin\n%s", r.displayName, r.coinCost, r.description),
				UDim2.new(1, -8, 0, 56),
				Color3.fromRGB(70, 110, 80)
			)
			row.MouseButton1Click:Connect(function()
				(remotes:WaitForChild("Craft") :: RemoteEvent):FireServer(r.id)
			end)
		end
	end

	local function refreshRebirth()
		clear(rebirthList)
		local r = state.rebirth
		if typeof(r) ~= "table" then
			label(rebirthList, "Veri yok.", 24)
			return
		end
		label(rebirthList, "Yeniden Doğuş (Robux ile ALINAMAZ)", 28, true, Color3.fromRGB(255, 180, 180))
		label(
			rebirthList,
			string.format(
				"Şu an: ×%d  | satış ×%.2f%s\nSonraki: satış ×%.2f",
				r.count or 0,
				r.sellMult or 1,
				if (r.badge or "") ~= "" then "  (" .. r.badge .. ")" else "",
				r.nextSellMult or 1.25
			),
			56,
			true
		)
		label(
			rebirthList,
			string.format(
				"Gereksinim: ≥%d coin ve ≥%d hasat.\nSıfırlanır: coin, bitkiler, tohum/ürün, yükseltmeler, aletler.\nKalır: koleksiyon, dekor, petler, beğeniler.",
				r.minCoins or 500,
				r.minHarvested or 25
			),
			80
		)
		if r.can then
			local row =
				button(rebirthList, "Yeniden Doğuşu Başlat…", UDim2.new(1, -8, 0, 48), Color3.fromRGB(160, 60, 70))
			row.MouseButton1Click:Connect(function()
				pendingPhrase = r.confirmPhrase or "YENİDEN DOĞ"
				confirmLabel.Text = string.format(
					"Emin misin?\n\nCoin, bitkiler ve yükseltmeler sıfırlanır.\nKoleksiyon, dekor ve petlerin kalır.\nYeni çarpan: ×%.2f\n\nBu işlem Robux ile satılmaz.",
					r.nextSellMult or 1.25
				)
				confirm.Visible = true
			end)
		else
			label(rebirthList, r.why or "Şu an yeniden doğulamaz.", 36, false, Color3.fromRGB(255, 200, 150))
		end
	end

	return {
		refresh = function(s: any)
			state = s or {}
			refreshPets()
			refreshEvents()
			refreshCraft()
			refreshRebirth()
		end,
	}
end

return FeaturePanels
