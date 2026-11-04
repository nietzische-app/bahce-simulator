--!strict
--[[
	Code-built ScreenGui: coins, weather, daily, inventory, shop buttons.
]]

local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MainHud = {}

export type HudHandles = {
	gui: ScreenGui,
	coinsLabel: TextLabel,
	weatherLabel: TextLabel,
	notifyLabel: TextLabel,
	inventoryFrame: Frame,
	shopFrame: Frame,
	inventoryList: Frame,
	shopList: Frame,
	setNotify: (string, string?) -> (),
	refreshInventory: (state: any) -> (),
	refreshShop: (state: any, handlers: any) -> (),
	setCoins: (number) -> (),
	setWeather: (any) -> (),
	toggleInventory: () -> (),
	toggleShop: () -> (),
}

local function corner(parent: Instance, radius: number?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = parent
end

local function padding(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
end

local function makeButton(text: string, parent: Instance, size: UDim2, pos: UDim2?, color: Color3?): TextButton
	local b = Instance.new("TextButton")
	b.Text = text
	b.Size = size
	if pos then
		b.Position = pos
	end
	b.BackgroundColor3 = color or Color3.fromRGB(70, 140, 90)
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextScaled = true
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 8)
	return b
end

function MainHud.Create(handlers: {
	onSell: () -> (),
	onDaily: () -> (),
	onOpenLeaderboard: () -> (),
}): HudHandles
	local existing = playerGui:FindFirstChild("MinikBahceHud")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "MinikBahceHud"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	-- Top bar
	local top = Instance.new("Frame")
	top.Name = "TopBar"
	top.Size = UDim2.new(1, -20, 0, 56)
	top.Position = UDim2.new(0, 10, 0, 10)
	top.BackgroundColor3 = Color3.fromRGB(30, 50, 40)
	top.BackgroundTransparency = 0.2
	top.Parent = gui
	corner(top, 12)
	padding(top, 8)

	local coinsLabel = Instance.new("TextLabel")
	coinsLabel.Name = "Coins"
	coinsLabel.Size = UDim2.new(0.25, 0, 1, 0)
	coinsLabel.BackgroundTransparency = 1
	coinsLabel.Text = "Coin: 0"
	coinsLabel.TextColor3 = Color3.fromRGB(255, 220, 100)
	coinsLabel.Font = Enum.Font.GothamBold
	coinsLabel.TextScaled = true
	coinsLabel.TextXAlignment = Enum.TextXAlignment.Left
	coinsLabel.Parent = top

	local weatherLabel = Instance.new("TextLabel")
	weatherLabel.Name = "Weather"
	weatherLabel.Size = UDim2.new(0.4, 0, 1, 0)
	weatherLabel.Position = UDim2.new(0.28, 0, 0, 0)
	weatherLabel.BackgroundTransparency = 1
	weatherLabel.Text = "Hava: …"
	weatherLabel.TextColor3 = Color3.new(1, 1, 1)
	weatherLabel.Font = Enum.Font.Gotham
	weatherLabel.TextScaled = true
	weatherLabel.Parent = top

	local btnInv =
		makeButton("Envanter", top, UDim2.new(0.12, 0, 1, 0), UDim2.new(0.72, 0, 0, 0), Color3.fromRGB(60, 100, 150))
	local btnShop =
		makeButton("Dükkan", top, UDim2.new(0.12, 0, 1, 0), UDim2.new(0.86, 0, 0, 0), Color3.fromRGB(150, 100, 60))

	-- Side actions
	local side = Instance.new("Frame")
	side.Name = "SideActions"
	side.Size = UDim2.new(0, 140, 0, 160)
	side.Position = UDim2.new(1, -150, 0.5, -80)
	side.BackgroundTransparency = 1
	side.Parent = gui

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.Parent = side

	local btnSell = makeButton("Ürünleri Sat", side, UDim2.new(1, 0, 0, 40), nil, Color3.fromRGB(180, 140, 40))
	local btnDaily = makeButton("Günlük Ödül", side, UDim2.new(1, 0, 0, 40), nil, Color3.fromRGB(80, 140, 180))
	local btnBoard = makeButton("Sıralama", side, UDim2.new(1, 0, 0, 40), nil, Color3.fromRGB(100, 80, 160))

	btnSell.MouseButton1Click:Connect(handlers.onSell)
	btnDaily.MouseButton1Click:Connect(handlers.onDaily)
	btnBoard.MouseButton1Click:Connect(handlers.onOpenLeaderboard)

	-- Notify toast
	local notifyLabel = Instance.new("TextLabel")
	notifyLabel.Name = "Notify"
	notifyLabel.Size = UDim2.new(0.5, 0, 0, 36)
	notifyLabel.Position = UDim2.new(0.25, 0, 0, 74)
	notifyLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	notifyLabel.BackgroundTransparency = 0.3
	notifyLabel.Text = ""
	notifyLabel.TextColor3 = Color3.new(1, 1, 1)
	notifyLabel.Font = Enum.Font.Gotham
	notifyLabel.TextScaled = true
	notifyLabel.Visible = false
	notifyLabel.Parent = gui
	corner(notifyLabel, 8)

	-- Inventory panel
	local inventoryFrame = Instance.new("Frame")
	inventoryFrame.Name = "Inventory"
	inventoryFrame.Size = UDim2.new(0, 320, 0, 360)
	inventoryFrame.Position = UDim2.new(0, 16, 0.5, -180)
	inventoryFrame.BackgroundColor3 = Color3.fromRGB(35, 45, 40)
	inventoryFrame.Visible = false
	inventoryFrame.Parent = gui
	corner(inventoryFrame, 12)
	padding(inventoryFrame, 10)

	local invTitle = Instance.new("TextLabel")
	invTitle.Size = UDim2.new(1, 0, 0, 28)
	invTitle.BackgroundTransparency = 1
	invTitle.Text = "Envanter"
	invTitle.Font = Enum.Font.GothamBold
	invTitle.TextScaled = true
	invTitle.TextColor3 = Color3.new(1, 1, 1)
	invTitle.Parent = inventoryFrame

	local inventoryList = Instance.new("ScrollingFrame")
	inventoryList.Name = "List"
	inventoryList.Size = UDim2.new(1, 0, 1, -36)
	inventoryList.Position = UDim2.new(0, 0, 0, 32)
	inventoryList.BackgroundTransparency = 1
	inventoryList.ScrollBarThickness = 6
	inventoryList.CanvasSize = UDim2.new(0, 0, 0, 0)
	inventoryList.Parent = inventoryFrame
	local invLayout = Instance.new("UIListLayout")
	invLayout.Padding = UDim.new(0, 6)
	invLayout.Parent = inventoryList

	-- Shop panel
	local shopFrame = Instance.new("Frame")
	shopFrame.Name = "Shop"
	shopFrame.Size = UDim2.new(0, 360, 0, 420)
	shopFrame.Position = UDim2.new(1, -380, 0.5, -210)
	shopFrame.BackgroundColor3 = Color3.fromRGB(45, 40, 35)
	shopFrame.Visible = false
	shopFrame.Parent = gui
	corner(shopFrame, 12)
	padding(shopFrame, 10)

	local shopTitle = Instance.new("TextLabel")
	shopTitle.Size = UDim2.new(1, 0, 0, 28)
	shopTitle.BackgroundTransparency = 1
	shopTitle.Text = "Dükkan"
	shopTitle.Font = Enum.Font.GothamBold
	shopTitle.TextScaled = true
	shopTitle.TextColor3 = Color3.new(1, 1, 1)
	shopTitle.Parent = shopFrame

	local shopList = Instance.new("ScrollingFrame")
	shopList.Name = "List"
	shopList.Size = UDim2.new(1, 0, 1, -36)
	shopList.Position = UDim2.new(0, 0, 0, 32)
	shopList.BackgroundTransparency = 1
	shopList.ScrollBarThickness = 6
	shopList.CanvasSize = UDim2.new(0, 0, 0, 0)
	shopList.Parent = shopFrame
	local shopLayout = Instance.new("UIListLayout")
	shopLayout.Padding = UDim.new(0, 6)
	shopLayout.Parent = shopList

	local selectedSeed: string? = nil

	local handles: HudHandles
	handles = {
		gui = gui,
		coinsLabel = coinsLabel,
		weatherLabel = weatherLabel,
		notifyLabel = notifyLabel,
		inventoryFrame = inventoryFrame,
		shopFrame = shopFrame,
		inventoryList = inventoryList,
		shopList = shopList,
		setNotify = function(msg: string, kind: string?)
			notifyLabel.Text = msg
			notifyLabel.Visible = true
			if kind == "ok" then
				notifyLabel.BackgroundColor3 = Color3.fromRGB(30, 90, 50)
			elseif kind == "warn" then
				notifyLabel.BackgroundColor3 = Color3.fromRGB(120, 80, 20)
			elseif kind == "error" then
				notifyLabel.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
			else
				notifyLabel.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
			end
			task.delay(3, function()
				if notifyLabel.Text == msg then
					notifyLabel.Visible = false
				end
			end)
		end,
		setCoins = function(n: number)
			coinsLabel.Text = string.format("Coin: %d", math.floor(n))
		end,
		setWeather = function(w: any)
			if typeof(w) == "table" then
				weatherLabel.Text = string.format("%s — %s", w.displayName or "?", w.description or "")
			end
		end,
		toggleInventory = function()
			inventoryFrame.Visible = not inventoryFrame.Visible
			if inventoryFrame.Visible then
				shopFrame.Visible = false
			end
		end,
		toggleShop = function()
			shopFrame.Visible = not shopFrame.Visible
			if shopFrame.Visible then
				inventoryFrame.Visible = false
			end
		end,
		refreshInventory = function(state: any)
			for _, child in inventoryList:GetChildren() do
				if child:IsA("TextButton") or child:IsA("TextLabel") then
					child:Destroy()
				end
			end
			local inv = state.inventory or {}
			local y = 0
			for key, count in pairs(inv) do
				if count > 0 then
					local isCrop = string.sub(key, 1, 5) == "crop:"
					local label = if isCrop then ("Ürün: " .. string.sub(key, 6)) else ("Tohum: " .. key)
					local row = makeButton(
						string.format("%s  ×%d%s", label, count, if not isCrop then " (seç)" else ""),
						inventoryList,
						UDim2.new(1, -8, 0, 36),
						nil,
						if isCrop then Color3.fromRGB(120, 100, 40) else Color3.fromRGB(50, 90, 70)
					)
					if not isCrop then
						row.MouseButton1Click:Connect(function()
							selectedSeed = key
							handles.setNotify("Seçili tohum: " .. key .. " — yatağa yaklaş ve ek.", "info")
						end)
					end
					y += 42
				end
			end
			inventoryList.CanvasSize = UDim2.new(0, 0, 0, y + 8);
			(handles :: any)._selectedSeed = selectedSeed
		end,
		refreshShop = function(state: any, shopHandlers: any)
			for _, child in shopList:GetChildren() do
				if child:IsA("TextButton") or child:IsA("TextLabel") or child:IsA("Frame") then
					child:Destroy()
				end
			end
			local y = 0
			local function addSection(title: string)
				local t = Instance.new("TextLabel")
				t.Size = UDim2.new(1, -8, 0, 24)
				t.BackgroundTransparency = 1
				t.Text = title
				t.TextColor3 = Color3.fromRGB(220, 220, 180)
				t.Font = Enum.Font.GothamBold
				t.TextScaled = true
				t.TextXAlignment = Enum.TextXAlignment.Left
				t.Parent = shopList
				y += 30
			end

			addSection("Tohumlar")
			for _, seed in state.seeds or {} do
				local row = makeButton(
					string.format("%s — %d coin  [%s]", seed.displayName, seed.buyPrice, seed.rarity),
					shopList,
					UDim2.new(1, -8, 0, 36),
					nil,
					Color3.fromRGB(70, 110, 80)
				)
				row.MouseButton1Click:Connect(function()
					shopHandlers.buySeed(seed.id, 1)
				end)
				y += 42
			end

			addSection("Yükseltmeler")
			if state.shop and state.shop.slotUpgradeCost then
				local row = makeButton(
					string.format("Ekstra Yatak — %d coin", state.shop.slotUpgradeCost),
					shopList,
					UDim2.new(1, -8, 0, 36),
					nil,
					Color3.fromRGB(80, 100, 140)
				)
				row.MouseButton1Click:Connect(function()
					shopHandlers.buyUpgrade("slots")
				end)
				y += 42
			end
			if state.shop and state.shop.growthUpgradeCost then
				local row = makeButton(
					string.format("Hızlı Büyüme — %d coin", state.shop.growthUpgradeCost),
					shopList,
					UDim2.new(1, -8, 0, 36),
					nil,
					Color3.fromRGB(80, 100, 140)
				)
				row.MouseButton1Click:Connect(function()
					shopHandlers.buyUpgrade("growth")
				end)
				y += 42
			end

			addSection("Gamepass (opsiyonel)")
			if state.shop and state.shop.gamepasses then
				for key, gp in pairs(state.shop.gamepasses) do
					local owned = state.ownedGamepasses and state.ownedGamepasses[key]
					local row = makeButton(
						string.format("%s%s — %s", gp.displayName, if owned then " ✓" else "", gp.description),
						shopList,
						UDim2.new(1, -8, 0, 48),
						nil,
						Color3.fromRGB(100, 80, 120)
					)
					if not owned then
						row.MouseButton1Click:Connect(function()
							shopHandlers.promptGamepass(key)
						end)
					end
					y += 54
				end
			end

			addSection("Robux Ürünleri (zorunlu değil)")
			if state.shop and state.shop.products then
				for key, prod in pairs(state.shop.products) do
					local extra = ""
					if key == "SeedPack" and state.shop.seedPackOdds then
						extra = "\nOranlar: " .. state.shop.seedPackOdds
					end
					local row = makeButton(
						prod.displayName .. " — " .. prod.description .. extra,
						shopList,
						UDim2.new(1, -8, 0, if key == "SeedPack" then 64 else 48),
						nil,
						Color3.fromRGB(120, 90, 60)
					)
					row.MouseButton1Click:Connect(function()
						shopHandlers.promptProduct(key)
					end)
					y += if key == "SeedPack" then 70 else 54
				end
			end

			shopList.CanvasSize = UDim2.new(0, 0, 0, y + 8)
		end,
	}

	btnInv.MouseButton1Click:Connect(handles.toggleInventory)
	btnShop.MouseButton1Click:Connect(handles.toggleShop);
	(handles :: any).GetSelectedSeed = function(): string?
		return (handles :: any)._selectedSeed
	end

	return handles
end

return MainHud
