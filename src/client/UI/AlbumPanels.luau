--!strict
--[[
	"Sen yokken..." karşılama penceresi + Koleksiyon albümü paneli.
	Sadece UI çerçeve/metin; tohum ikonu varsa (rbxassetid) gösterilir.
]]

local Players = game:GetService("Players")

local AlbumPanels = {}

local function corner(p: Instance, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = p
end

local function label(parent: Instance, text: string, size: UDim2, bold: boolean?): TextLabel
	local t = Instance.new("TextLabel")
	t.Size = size
	t.BackgroundTransparency = 1
	t.Text = text
	t.TextWrapped = true
	t.TextScaled = true
	t.Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham
	t.TextColor3 = Color3.new(1, 1, 1)
	t.Parent = parent
	return t
end

local function button(parent: Instance, text: string, size: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Size = size
	b.BackgroundColor3 = color
	b.Text = text
	b.TextScaled = true
	b.Font = Enum.Font.GothamBold
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Parent = parent
	corner(b, 8)
	return b
end

local function makeGui(): ScreenGui
	local pg = Players.LocalPlayer:WaitForChild("PlayerGui")
	local old = pg:FindFirstChild("MinikBahceAlbum")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "MinikBahceAlbum"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = pg
	return gui
end

function AlbumPanels.Create(onClaim: (string) -> ())
	local gui = makeGui()

	-- Koleksiyon button (bottom-left, away from side actions)
	local open = button(gui, "Koleksiyon", UDim2.new(0, 140, 0, 40), Color3.fromRGB(150, 110, 170))
	open.Name = "KoleksiyonButton"
	open.Position = UDim2.new(1, -150, 0.5, 112)

	local panel = Instance.new("Frame")
	panel.Name = "Koleksiyon"
	panel.Size = UDim2.new(0, 400, 0, 420)
	panel.Position = UDim2.new(0.5, -200, 0.5, -210)
	panel.BackgroundColor3 = Color3.fromRGB(40, 38, 55)
	panel.Visible = false
	panel.Parent = gui
	corner(panel, 12)

	local title = label(panel, "Koleksiyon", UDim2.new(1, -60, 0, 30), true)
	title.Position = UDim2.new(0, 10, 0, 6)
	local close = button(panel, "X", UDim2.new(0, 30, 0, 30), Color3.fromRGB(120, 60, 60))
	close.Position = UDim2.new(1, -40, 0, 6)

	local list = Instance.new("ScrollingFrame")
	list.Size = UDim2.new(1, -20, 1, -50)
	list.Position = UDim2.new(0, 10, 0, 42)
	list.BackgroundTransparency = 1
	list.ScrollBarThickness = 6
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.CanvasSize = UDim2.new()
	list.Parent = panel
	local lay = Instance.new("UIListLayout")
	lay.Padding = UDim.new(0, 8)
	lay.SortOrder = Enum.SortOrder.LayoutOrder
	lay.Parent = list

	open.MouseButton1Click:Connect(function()
		panel.Visible = not panel.Visible
	end)
	close.MouseButton1Click:Connect(function()
		panel.Visible = false
	end)

	local function refresh(col: any)
		if typeof(col) ~= "table" then
			return
		end
		title.Text = string.format("Koleksiyon — %%%d", col.percent or 0)
		for _, c in list:GetChildren() do
			if c:IsA("GuiObject") then
				c:Destroy()
			end
		end
		for i, row in col.rows or {} do
			local card = Instance.new("Frame")
			card.Size = UDim2.new(1, -8, 0, 96)
			card.BackgroundColor3 = Color3.fromRGB(55, 52, 75)
			card.LayoutOrder = i
			card.Parent = list
			corner(card, 10)

			-- Seed icon if a real asset exists, else a plain colour swatch
			local icon: GuiObject
			if typeof(row.assetId) == "string" and string.sub(row.assetId, 1, 13) == "rbxassetid://" then
				local img = Instance.new("ImageLabel")
				img.Image = row.assetId
				img.BackgroundTransparency = 1
				icon = img
			else
				local sw = Instance.new("Frame")
				sw.BackgroundColor3 = if typeof(row.color) == "Color3" then row.color else Color3.new(0.6, 0.8, 0.5)
				icon = sw
			end
			icon.Size = UDim2.new(0, 36, 0, 36)
			icon.Position = UDim2.new(0, 8, 0, 8)
			icon.Parent = card
			corner(icon, 18)

			local head = label(
				card,
				string.format("%s  %d/%d  (%%%d)", row.displayName, row.have, row.total, row.percent),
				UDim2.new(1, -170, 0, 24),
				true
			)
			head.Position = UDim2.new(0, 52, 0, 8)
			head.TextXAlignment = Enum.TextXAlignment.Left

			local complete = row.have >= row.total
			local rb = button(
				card,
				if row.claimed
					then "Rozet ✓"
					elseif complete then string.format("Al +%d", row.reward)
					else string.format("Ödül %d", row.reward),
				UDim2.new(0, 100, 0, 28),
				if row.claimed
					then Color3.fromRGB(70, 120, 80)
					elseif complete then Color3.fromRGB(200, 160, 50)
					else Color3.fromRGB(80, 80, 90)
			)
			rb.Position = UDim2.new(1, -108, 0, 8)
			if complete and not row.claimed then
				rb.MouseButton1Click:Connect(function()
					onClaim(row.seedId)
				end)
			end

			local n = #(row.entries or {})
			for j, e in row.entries or {} do
				local chip = Instance.new("TextLabel")
				chip.Size = UDim2.new(1 / n, -6, 0, 34)
				chip.Position = UDim2.new((j - 1) / n, 4, 0, 52)
				chip.BackgroundColor3 = if e.unlocked then Color3.fromRGB(90, 150, 100) else Color3.fromRGB(45, 45, 55)
				chip.Text = if e.unlocked then e.displayName else "?"
				chip.TextScaled = true
				chip.Font = Enum.Font.Gotham
				chip.TextColor3 = Color3.new(1, 1, 1)
				chip.Parent = card
				corner(chip, 6)
			end
		end
	end

	local function showOffline(summary: any)
		if typeof(summary) ~= "table" then
			return
		end
		local box = Instance.new("Frame")
		box.Name = "SenYokken"
		box.Size = UDim2.new(0, 360, 0, 260)
		box.Position = UDim2.new(0.5, -180, 0.5, -130)
		box.BackgroundColor3 = Color3.fromRGB(40, 70, 55)
		box.Parent = gui
		corner(box, 14)
		local t = label(box, "Sen yokken...", UDim2.new(1, -20, 0, 34), true)
		t.Position = UDim2.new(0, 10, 0, 10)
		local lines = { string.format("%s uzaktaydın. Tekrar hoş geldin!", tostring(summary.awayText)) }
		if typeof(summary.ripened) == "table" and #summary.ripened > 0 then
			table.insert(lines, "Olgunlaşan bitkiler:")
			for _, r in summary.ripened do
				table.insert(lines, string.format("• %s ×%d", tostring(r.displayName), tonumber(r.count) or 1))
			end
			table.insert(lines, "Hazır olduğunda hasat edebilirsin.")
		elseif (tonumber(summary.growing) or 0) > 0 then
			table.insert(lines, "Bitkilerin büyümeye devam ediyor.")
		else
			table.insert(lines, "Bahçen seni bekliyor. İstediğin zaman tohum ekebilirsin.")
		end
		local body = label(box, table.concat(lines, "\n"), UDim2.new(1, -20, 1, -100))
		body.Position = UDim2.new(0, 10, 0, 48)
		body.TextScaled = false
		body.TextSize = 18
		body.TextYAlignment = Enum.TextYAlignment.Top
		local ok = button(box, "Tamam", UDim2.new(0, 120, 0, 36), Color3.fromRGB(80, 150, 100))
		ok.Position = UDim2.new(0.5, -60, 1, -46)
		ok.MouseButton1Click:Connect(function()
			box:Destroy()
		end)
	end

	return { refresh = refresh, showOffline = showOffline }
end

return AlbumPanels
