--!strict
--[[
	Dekor paneli (kozmetik yerleştirme ızgarası) + "Bahçeler" ziyaret/beğeni paneli.
	Sohbet YOK: sadece hazır emoji tepkileri. Tüm doğrulama sunucuda.
]]

local Players = game:GetService("Players")

local SocialPanels = {}

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

local function panel(gui: ScreenGui, name: string, title: string): (Frame, ScrollingFrame)
	local f = Instance.new("Frame")
	f.Name = name
	f.Size = UDim2.new(0, 380, 0, 440)
	f.Position = UDim2.new(0.5, -190, 0.5, -220)
	f.BackgroundColor3 = Color3.fromRGB(35, 55, 45)
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

function SocialPanels.Create(remotes: Folder, notify: (string, string?) -> ())
	local gui = Instance.new("ScreenGui")
	gui.Name = "MinikBahceSocial"
	gui.ResetOnSpawn = false
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")

	local side = Instance.new("Frame")
	side.Size = UDim2.fromOffset(120, 96)
	side.Position = UDim2.new(0, 10, 0.5, -48)
	side.BackgroundTransparency = 1
	side.Parent = gui
	local btnDecor = button(side, "Dekor", UDim2.new(1, 0, 0, 44), Color3.fromRGB(150, 110, 60))
	local btnGardens = button(side, "Bahçeler", UDim2.new(1, 0, 0, 44), Color3.fromRGB(70, 120, 170))
	btnGardens.Position = UDim2.fromOffset(0, 52)

	local decorFrame, decorList = panel(gui, "DecorPanel", "Dekor (sadece süs)")
	local gardensFrame, gardensList = panel(gui, "GardensPanel", "Bahçeler")

	local function ev(name: string): RemoteEvent
		return remotes:WaitForChild(name) :: RemoteEvent
	end

	local decorState: any = nil
	local selectedId: string? = nil
	local moveFrom: number? = nil
	local rot = 0
	local renderDecor: () -> ()

	renderDecor = function()
		clear(decorList)
		local d = decorState
		if typeof(d) ~= "table" then
			return
		end
		local placedBy: { [number]: any } = {}
		local used: { [string]: number } = {}
		for _, p in d.placed or {} do
			placedBy[p.slot] = p
			used[p.id] = (used[p.id] or 0) + 1
		end
		local names: { [string]: string } = {}
		for i, it in d.items or {} do
			names[it.id] = it.displayName
			local owned = (d.owned or {})[it.id] or 0
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -8, 0, 34)
			row.BackgroundTransparency = 1
			row.LayoutOrder = i
			row.Parent = decorList
			local sel = button(
				row,
				string.format("%s  (%d/%d)", it.displayName, owned - (used[it.id] or 0), owned),
				UDim2.new(0.6, -4, 1, 0),
				if selectedId == it.id then Color3.fromRGB(200, 150, 60) else Color3.fromRGB(80, 110, 90)
			)
			sel.MouseButton1Click:Connect(function()
				selectedId = if selectedId == it.id then nil else it.id
				moveFrom = nil
				renderDecor()
			end)
			local buy =
				button(row, string.format("Al %d", it.price), UDim2.new(0.4, 0, 1, 0), Color3.fromRGB(60, 90, 130))
			buy.Position = UDim2.new(0.6, 0, 0, 0)
			buy.MouseButton1Click:Connect(function()
				ev("BuyDecor"):FireServer(it.id, 1)
			end)
		end

		local hint = Instance.new("TextLabel")
		hint.Size = UDim2.new(1, -8, 0, 36)
		hint.BackgroundTransparency = 1
		hint.TextWrapped = true
		hint.TextScaled = true
		hint.Font = Enum.Font.Gotham
		hint.TextColor3 = Color3.fromRGB(220, 220, 190)
		hint.LayoutOrder = 100
		hint.Text = if moveFrom
			then "Taşımak için boş bir yer seç."
			elseif selectedId then "Yerleştirmek için boş bir yer seç."
			else "Bir dekor seç ya da taşımak için dolu yere dokun. Kenar halkası = parselinin çevresi."
		hint.Parent = decorList

		-- 5x5 ızgara: kenar 16 yuva (Decor.SLOTS sırası), orta = tarla
		local grid = Instance.new("Frame")
		grid.Size = UDim2.new(1, -8, 0, 230)
		grid.BackgroundTransparency = 1
		grid.LayoutOrder = 101
		grid.Parent = decorList
		local slot = 0
		for row = 0, 4 do
			for col = 0, 4 do
				local edge = row == 0 or row == 4 or col == 0 or col == 4
				local pos = UDim2.new(col * 0.2, 2, 0, row * 46)
				if not edge then
					if row == 2 and col == 2 then
						local mid = Instance.new("TextLabel")
						mid.Size = UDim2.new(0.2, -4, 0, 42)
						mid.Position = pos
						mid.BackgroundTransparency = 1
						mid.Text = "Tarla"
						mid.TextScaled = true
						mid.TextColor3 = Color3.fromRGB(160, 200, 140)
						mid.Parent = grid
					end
					continue
				end
				slot += 1
				local s = slot
				local p = placedBy[s]
				local b = button(
					grid,
					if p then (names[p.id] or p.id) else "+",
					UDim2.new(0.2, -4, 0, 42),
					if moveFrom == s
						then Color3.fromRGB(200, 150, 60)
						elseif p then Color3.fromRGB(110, 90, 60)
						else Color3.fromRGB(60, 80, 70)
				)
				b.Position = pos
				b.MouseButton1Click:Connect(function()
					if moveFrom then
						if moveFrom == s then
							moveFrom = nil
						else
							ev("MoveDecor"):FireServer(moveFrom, s)
							moveFrom = nil
						end
					elseif p then
						moveFrom = s
						selectedId = nil
					elseif selectedId then
						ev("PlaceDecor"):FireServer(selectedId, s, rot)
					end
					renderDecor()
				end)
			end
		end

		local tools = Instance.new("Frame")
		tools.Size = UDim2.new(1, -8, 0, 36)
		tools.BackgroundTransparency = 1
		tools.LayoutOrder = 102
		tools.Parent = decorList
		local rotB = button(
			tools,
			"Döndür (" .. tostring(rot * 90) .. "°)",
			UDim2.new(0.5, -4, 1, 0),
			Color3.fromRGB(80, 100, 140)
		)
		rotB.MouseButton1Click:Connect(function()
			rot = (rot + 1) % 4
			if moveFrom then
				ev("MoveDecor"):FireServer(moveFrom, moveFrom, rot)
			end
			renderDecor()
		end)
		local rem = button(tools, "Kaldır", UDim2.new(0.5, -4, 1, 0), Color3.fromRGB(150, 80, 70))
		rem.Position = UDim2.new(0.5, 4, 0, 0)
		rem.MouseButton1Click:Connect(function()
			if moveFrom then
				ev("RemoveDecor"):FireServer(moveFrom)
				moveFrom = nil
				renderDecor()
			else
				notify("Önce kaldırılacak dekora dokun.", "warn")
			end
		end)
	end

	local reactions: { string } = { "🌸", "👍", "⭐" }

	local function refreshGardens()
		clear(gardensList)
		local fn = remotes:WaitForChild("ListGardens") :: RemoteFunction
		local ok, list = pcall(function()
			return fn:InvokeServer()
		end)
		if not ok or typeof(list) ~= "table" then
			return
		end
		local home =
			button(gardensList, "🏠 Kendi bahçeme dön", UDim2.new(1, -8, 0, 36), Color3.fromRGB(70, 130, 80))
		home.MouseButton1Click:Connect(function()
			ev("ReturnHome"):FireServer()
		end)
		for i, g in list do
			local row = Instance.new("Frame")
			row.Size = UDim2.new(1, -8, 0, 70)
			row.BackgroundColor3 = Color3.fromRGB(50, 75, 60)
			row.LayoutOrder = i
			row.Parent = gardensList
			corner(row, 8)
			local name = Instance.new("TextLabel")
			name.Size = UDim2.new(0.6, 0, 0, 30)
			name.Position = UDim2.fromOffset(6, 2)
			name.BackgroundTransparency = 1
			name.Text = string.format("%s%s  💚 %d", g.name, if g.isMe then " (sen)" else "", g.likes or 0)
			name.TextScaled = true
			name.Font = Enum.Font.GothamBold
			name.TextColor3 = Color3.new(1, 1, 1)
			name.TextXAlignment = Enum.TextXAlignment.Left
			name.Parent = row
			if g.isMe then
				continue
			end
			local visit = button(row, "Ziyaret", UDim2.new(0.38, -6, 0, 30), Color3.fromRGB(70, 120, 170))
			visit.Position = UDim2.new(0.62, 0, 0, 2)
			visit.MouseButton1Click:Connect(function()
				ev("VisitGarden"):FireServer(g.userId)
			end)
			local like = button(
				row,
				if g.likedToday then "Beğenildi ✓" else "Beğen 💚",
				UDim2.new(0.34, 0, 0, 30),
				if g.likedToday then Color3.fromRGB(90, 90, 90) else Color3.fromRGB(80, 150, 90)
			)
			like.Position = UDim2.fromOffset(6, 36)
			like.MouseButton1Click:Connect(function()
				ev("LikeGarden"):FireServer(g.userId)
				task.delay(0.6, refreshGardens)
			end)
			for j, e in reactions do
				local rb = button(row, e, UDim2.new(0.12, 0, 0, 30), Color3.fromRGB(90, 80, 120))
				rb.Position = UDim2.new(0.36 + (j - 1) * 0.14, 6, 0, 36)
				rb.MouseButton1Click:Connect(function()
					ev("SendReaction"):FireServer(g.userId, e)
				end)
			end
		end
	end

	btnDecor.MouseButton1Click:Connect(function()
		decorFrame.Visible = not decorFrame.Visible
		gardensFrame.Visible = false
		renderDecor()
	end)
	btnGardens.MouseButton1Click:Connect(function()
		gardensFrame.Visible = not gardensFrame.Visible
		decorFrame.Visible = false
		if gardensFrame.Visible then
			refreshGardens()
		end
	end)

	return {
		refresh = function(state: any)
			decorState = state.decor
			if typeof(state.reactions) == "table" then
				reactions = { state.reactions[1], state.reactions[2], state.reactions[3] }
			end
			if decorFrame.Visible then
				renderDecor()
			end
		end,
	}
end

return SocialPanels
