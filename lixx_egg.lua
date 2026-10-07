-- =================================================================
-- SCRIPT NAME: LIXX EGG
-- SYSTEM: Auto Egg Stealer, History, Panel, Duel Player & Notifier
-- DESIGN: Glassmorphism (Kaca) + Toggle Button "L"
-- =================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Global Configuration & State Management
getgenv().LixxEggConfig = getgenv().LixxEggConfig or {
	AutoSteal = false,
	SpeedBoost = false,
	SpeedValue = 50,
	DuelMode = false,
	NotifEnabled = false,
	TelegramToken = "",
	TelegramChatID = "",
	History = {}
}

local Config = getgenv().LixxEggConfig

-- Utility: Safe Workspace Queries
local function GetEggsInWorkspace()
	local eggs = {}
	for _, obj in ipairs(workspace:GetDescendants()) do
		if obj:IsA("Model") and (obj.Name:find("Egg") or obj:FindFirstChild("ProximityPrompt") or obj:FindFirstChild("TouchInterest")) then
			local rarity = obj:GetAttribute("Rarity") or obj.Name
			table.insert(eggs, {Instance = obj, Name = obj.Name, Rarity = tostring(rarity)})
		end
	end
	return eggs
end

-- Rarity Weight System: Divine > Eternal > Secret
local function GetRarityWeight(rarityName)
	local str = string.lower(rarityName)
	if str:find("divine") then return 3 end
	if str:find("eternal") then return 2 end
	if str:find("secret") then return 1 end
	return 0
end

-- Teleport & Steal Sequence Execution
local function ExecuteStealSequence(targetEggModel)
	if not targetEggModel or not targetEggModel:IsDescendantOf(workspace) then return end
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end

	local root = char.HumanoidRootPart
	local targetPart = targetEggModel.PrimaryPart or targetEggModel:FindFirstChildWhichPart("BasePart")
	if not targetPart then return end

	-- 1. Lari/Teleport Cepat ke Telur & Ambil
	root.CFrame = targetPart.CFrame * CFrame.new(0, 2, 0)
	task.wait(0.1)

	-- Trigger Interaksi/ProximityPrompt jika ada
	for _, prompt in ipairs(targetEggModel:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			fireproximityprompt(prompt)
		end
	end

	-- Record History
	table.insert(Config.History, {
		Name = targetEggModel.Name,
		Time = os.date("%X"),
		Rarity = targetEggModel:GetAttribute("Rarity") or "Unknown"
	})

	-- Send Telegram Notification jika diaktifkan
	if Config.NotifEnabled and Config.TelegramToken ~= "" and Config.TelegramChatID ~= "" then
		task.spawn(function()
			local msg = "🎉 **LIXX EGG NOTIFIER**\nBerhasil Mencuri: " .. targetEggModel.Name .. "\nWaktu: " .. os.date("%X")
			local url = "https://api.telegram.org/bot" .. Config.TelegramToken .. "/sendMessage"
			local data = HttpService:JSONEncode({
				chat_id = Config.TelegramChatID,
				text = msg,
				parse_mode = "Markdown"
			})
			pcall(function()
				request({
					Url = url,
					Method = "POST",
					Headers = {["Content-Type"] = "application/json"},
					Body = data
				})
			end)
		end)
	end

	-- 2. Lari otomatis ke Wilayah Forest
	local forest = workspace:FindFirstChild("Forest") or workspace:FindFirstChild("ForestZone")
	if forest then
		local forestPart = forest:IsA("BasePart") and forest or forest:FindFirstChildWhichPart("BasePart")
		if forestPart then
			root.CFrame = forestPart.CFrame
		end
	end

	-- 3. Berhenti 2 Detik di Forest
	task.wait(2)

	-- 4. Teleport ke Base
	local base = workspace:FindFirstChild("Bases") or workspace:FindFirstChild("PlayerBases")
	if base then
		local myBase = base:FindFirstChild(LocalPlayer.Name) or base:FindFirstChildWhichPart("BasePart")
		if myBase then
			root.CFrame = (myBase.PrimaryPart or myBase).CFrame * CFrame.new(0, 3, 0)
		end
	end
end

-- UI CREATION SYSTEM (Glassmorphism Concept)
local CoreGui = game:GetService("CoreGui")
if CoreGui:FindFirstChild("LixxEggUI") then CoreGui.LixxEggUI:Destroy() end

local LixxEggUI = Instance.new("ScreenGui")
LixxEggUI.Name = "LixxEggUI"
LixxEggUI.Parent = CoreGui
LixxEggUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Open Button Logo "L"
local LogoL = Instance.new("TextButton")
LogoL.Name = "LogoL"
LogoL.Parent = LixxEggUI
LogoL.Size = UDim2.new(0, 45, 0, 45)
LogoL.Position = UDim2.new(0.02, 0, 0.4, 0)
LogoL.BackgroundColor3 = Color3.fromRGB(20, 20, 35)
LogoL.BackgroundTransparency = 0.2
LogoL.Text = "L"
LogoL.TextColor3 = Color3.fromRGB(0, 230, 255)
LogoL.TextSize = 24
LogoL.Font = Enum.Font.FredokaOne
LogoL.Draggable = true

local LogoCorner = Instance.new("UICorner", LogoL)
LogoCorner.CornerRadius = UDim.new(0, 12)
local LogoStroke = Instance.new("UIStroke", LogoL)
LogoStroke.Color = Color3.fromRGB(0, 230, 255)
LogoStroke.Thickness = 2

-- Main Frame (Glass Style)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = LixxEggUI
MainFrame.Size = UDim2.new(0, 580, 0, 360)
MainFrame.Position = UDim2.new(0.3, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(15, 18, 28)
MainFrame.BackgroundTransparency = 0.25
MainFrame.Active = true
MainFrame.Draggable = true

local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 16)
local MainStroke = Instance.new("UIStroke", MainFrame)
MainStroke.Color = Color3.fromRGB(255, 255, 255)
MainStroke.Transparency = 0.7
MainStroke.Thickness = 1.5

-- Header Title & Close Button "X"
local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(0, 200, 0, 40)
Title.Position = UDim2.new(0, 20, 0, 5)
Title.Text = "LIXX EGG v1.0"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BackgroundTransparency = 1

local CloseBtn = Instance.new("TextButton", MainFrame)
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -40, 0, 8)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 16
CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
CloseBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 20)
CloseBtn.BackgroundTransparency = 0.5
local CloseCorner = Instance.new("UICorner", CloseBtn)
CloseCorner.CornerRadius = UDim.new(0, 8)

CloseBtn.MouseButton1Click:Connect(function()
	MainFrame.Visible = false
end)

LogoL.MouseButton1Click:Connect(function()
	MainFrame.Visible = not MainFrame.Visible
end)

-- Sidebar Navigation (5 Menus)
local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size = UDim2.new(0, 130, 1, -50)
Sidebar.Position = UDim2.new(0, 10, 0, 45)
Sidebar.BackgroundTransparency = 0.9
Sidebar.BackgroundColor3 = Color3.fromRGB(255, 255, 255)

local SidebarLayout = Instance.new("UIListLayout", Sidebar)
SidebarLayout.Padding = UDim.new(0, 6)

local Container = Instance.new("Frame", MainFrame)
Container.Size = UDim2.new(1, -165, 1, -55)
Container.Position = UDim2.new(0, 150, 0, 45)
Container.BackgroundTransparency = 1

local Pages = {}

local function CreateTab(name)
	local btn = Instance.new("TextButton", Sidebar)
	btn.Size = UDim2.new(1, 0, 0, 35)
	btn.Text = name
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 13
	btn.TextColor3 = Color3.fromRGB(200, 200, 200)
	btn.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
	btn.BackgroundTransparency = 0.4
	local c = Instance.new("UICorner", btn)
	c.CornerRadius = UDim.new(0, 8)

	local page = Instance.new("ScrollingFrame", Container)
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.CanvasSize = UDim2.new(0, 0, 2, 0)
	page.ScrollBarThickness = 3

	local pLayout = Instance.new("UIListLayout", page)
	pLayout.Padding = UDim.new(0, 8)

	Pages[name] = page

	btn.MouseButton1Click:Connect(function()
		for _, p in pairs(Pages) do p.Visible = false end
		page.Visible = true
	end)

	return page
end

-- Build 5 Tab Windows
local TabAutoEgg = CreateTab("AUTO EGG")
local TabPanel = CreateTab("PANEL")
local TabHistory = CreateTab("HISTORY EGG")
local TabDuel = CreateTab("DUEL PLAYER")
local TabNotif = CreateTab("NOTIFICATION")

Pages["AUTO EGG"].Visible = true

-- Helper UI Components
local function AddToggle(parent, title, defaultState, callback)
	local frame = Instance.new("Frame", parent)
	frame.Size = UDim2.new(1, -10, 0, 40)
	frame.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
	frame.BackgroundTransparency = 0.3
	local c = Instance.new("UICorner", frame) c.CornerRadius = UDim.new(0, 8)

	local lbl = Instance.new("TextLabel", frame)
	lbl.Size = UDim2.new(0.7, 0, 1, 0)
	lbl.Position = UDim2.new(0, 10, 0, 0)
	lbl.Text = title
	lbl.Font = Enum.Font.Gotham
	lbl.TextSize = 13
	lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
	lbl.TextXAlignment = Enum.TextXAlignment.Left
	lbl.BackgroundTransparency = 1

	local tBtn = Instance.new("TextButton", frame)
	tBtn.Size = UDim2.new(0, 60, 0, 26)
	tBtn.Position = UDim2.new(1, -70, 0.5, -13)
	tBtn.Text = defaultState and "ON" or "OFF"
	tBtn.Font = Enum.Font.GothamBold
	tBtn.TextSize = 12
	tBtn.TextColor3 = defaultState and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(255, 80, 80)
	tBtn.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
	local tc = Instance.new("UICorner", tBtn) tc.CornerRadius = UDim.new(0, 6)

	local state = defaultState
	tBtn.MouseButton1Click:Connect(function()
		state = not state
		tBtn.Text = state and "ON" or "OFF"
		tBtn.TextColor3 = state and Color3.fromRGB(0, 255, 150) or Color3.fromRGB(255, 80, 80)
		callback(state)
	end)
end

-- TAB 1: AUTO EGG FEATURES
AddToggle(TabAutoEgg, "Steal On/Off (Divine > Eternal > Secret)", Config.AutoSteal, function(v)
	Config.AutoSteal = v
end)

AddToggle(TabAutoEgg, "Speed Boost On/Off", Config.SpeedBoost, function(v)
	Config.SpeedBoost = v
	if not v and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
		LocalPlayer.Character.Humanoid.WalkSpeed = 16
	end
end)

-- Speed Box
local SpeedFrame = Instance.new("Frame", TabAutoEgg)
SpeedFrame.Size = UDim2.new(1, -10, 0, 40)
SpeedFrame.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
SpeedFrame.BackgroundTransparency = 0.3
local sCorner = Instance.new("UICorner", SpeedFrame) sCorner.CornerRadius = UDim.new(0, 8)

local sLbl = Instance.new("TextLabel", SpeedFrame)
sLbl.Size = UDim2.new(0.5, 0, 1, 0)
sLbl.Position = UDim2.new(0, 10, 0, 0)
sLbl.Text = "Set Speed Value:"
sLbl.Font = Enum.Font.Gotham
sLbl.TextSize = 13
sLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
sLbl.TextXAlignment = Enum.TextXAlignment.Left
sLbl.BackgroundTransparency = 1

local sBox = Instance.new("TextBox", SpeedFrame)
sBox.Size = UDim2.new(0, 80, 0, 26)
sBox.Position = UDim2.new(1, -90, 0.5, -13)
sBox.Text = tostring(Config.SpeedValue)
sBox.Font = Enum.Font.GothamBold
sBox.TextSize = 12
sBox.TextColor3 = Color3.fromRGB(255, 255, 255)
sBox.BackgroundColor3 = Color3.fromRGB(15, 20, 30)
local sBoxC = Instance.new("UICorner", sBox) sBoxC.CornerRadius = UDim.new(0, 6)

sBox.FocusLost:Connect(function()
	local val = tonumber(sBox.Text)
	if val then Config.SpeedValue = val end
end)

-- TAB 2: PANEL (Manual Steal & Refresh Server)
local RefreshBtn = Instance.new("TextButton", TabPanel)
RefreshBtn.Size = UDim2.new(1, -10, 0, 35)
RefreshBtn.Text = "🔄 Refresh Eggs Display"
RefreshBtn.Font = Enum.Font.GothamBold
RefreshBtn.TextSize = 12
RefreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RefreshBtn.BackgroundColor3 = Color3.fromRGB(40, 90, 160)
local rCorner = Instance.new("UICorner", RefreshBtn) rCorner.CornerRadius = UDim.new(0, 8)

local PanelList = Instance.new("Frame", TabPanel)
PanelList.Size = UDim2.new(1, -10, 1, -45)
PanelList.BackgroundTransparency = 1
local pListLayout = Instance.new("UIListLayout", PanelList) pListLayout.Padding = UDim.new(0, 6)

local function PopulatePanel()
	for _, child in ipairs(PanelList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local eggs = GetEggsInWorkspace()
	table.sort(eggs, function(a, b)
		return GetRarityWeight(a.Rarity) > GetRarityWeight(b.Rarity)
	end)

	for _, item in ipairs(eggs) do
		local f = Instance.new("Frame", PanelList)
		f.Size = UDim2.new(1, 0, 0, 45)
		f.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
		f.BackgroundTransparency = 0.3
		local fc = Instance.new("UICorner", f) fc.CornerRadius = UDim.new(0, 8)

		local img = Instance.new("ImageLabel", f)
		img.Size = UDim2.new(0, 35, 0, 35)
		img.Position = UDim2.new(0, 5, 0.5, -17)
		img.Image = "rbxassetid://6031075931" -- Placeholder Icon Mini Telur
		img.BackgroundTransparency = 1

		local txt = Instance.new("TextLabel", f)
		txt.Size = UDim2.new(0.5, 0, 1, 0)
		txt.Position = UDim2.new(0, 48, 0, 0)
		txt.Text = item.Name .. " [" .. item.Rarity .. "]"
		txt.Font = Enum.Font.Gotham
		txt.TextSize = 11
		txt.TextColor3 = Color3.fromRGB(255, 255, 255)
		txt.TextXAlignment = Enum.TextXAlignment.Left
		txt.BackgroundTransparency = 1

		local stlBtn = Instance.new("TextButton", f)
		stlBtn.Size = UDim2.new(0, 65, 0, 26)
		stlBtn.Position = UDim2.new(1, -75, 0.5, -13)
		stlBtn.Text = "STEAL"
		stlBtn.Font = Enum.Font.GothamBold
		stlBtn.TextSize = 11
		stlBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		stlBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 100)
		local stlC = Instance.new("UICorner", stlBtn) stlC.CornerRadius = UDim.new(0, 6)

		stlBtn.MouseButton1Click:Connect(function()
			ExecuteStealSequence(item.Instance)
		end)
	end
end

RefreshBtn.MouseButton1Click:Connect(PopulatePanel)

-- TAB 3: HISTORY EGG
local DelHistBtn = Instance.new("TextButton", TabHistory)
DelHistBtn.Size = UDim2.new(1, -10, 0, 35)
DelHistBtn.Text = "🗑️ Delete History"
DelHistBtn.Font = Enum.Font.GothamBold
DelHistBtn.TextSize = 12
DelHistBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DelHistBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
local dhCorner = Instance.new("UICorner", DelHistBtn) dhCorner.CornerRadius = UDim.new(0, 8)

local HistList = Instance.new("Frame", TabHistory)
HistList.Size = UDim2.new(1, -10, 1, -45)
HistList.BackgroundTransparency = 1
local hLayout = Instance.new("UIListLayout", HistList) hLayout.Padding = UDim.new(0, 4)

local function UpdateHistoryUI()
	for _, child in ipairs(HistList:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	for _, entry in ipairs(Config.History) do
		local f = Instance.new("Frame", HistList)
		f.Size = UDim2.new(1, 0, 0, 30)
		f.BackgroundColor3 = Color3.fromRGB(20, 25, 35)
		f.BackgroundTransparency = 0.4
		local c = Instance.new("UICorner", f) c.CornerRadius = UDim.new(0, 6)

		local lbl = Instance.new("TextLabel", f)
		lbl.Size = UDim2.new(1, -10, 1, 0)
		lbl.Position = UDim2.new(0, 10, 0, 0)
		lbl.Text = "[" .. entry.Time .. "] Stolen: " .. entry.Name .. " (" .. entry.Rarity .. ")"
		lbl.Font = Enum.Font.Gotham
		lbl.TextSize = 11
		lbl.TextColor3 = Color3.fromRGB(220, 220, 220)
		lbl.TextXAlignment = Enum.TextXAlignment.Left
		lbl.BackgroundTransparency = 1
	end
end

DelHistBtn.MouseButton1Click:Connect(function()
	Config.History = {}
	UpdateHistoryUI()
end)

-- TAB 4: DUEL PLAYER
AddToggle(TabDuel, "Duel Player On/Off", Config.DuelMode, function(v)
	Config.DuelMode = v
end)

local PlayerListFrame = Instance.new("Frame", TabDuel)
PlayerListFrame.Size = UDim2.new(1, -10, 1, -50)
PlayerListFrame.BackgroundTransparency = 1
local plLayout = Instance.new("UIListLayout", PlayerListFrame) plLayout.Padding = UDim.new(0, 6)

local function UpdatePlayerList()
	for _, child in ipairs(PlayerListFrame:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local f = Instance.new("Frame", PlayerListFrame)
			f.Size = UDim2.new(1, 0, 0, 40)
			f.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
			f.BackgroundTransparency = 0.3
			local c = Instance.new("UICorner", f) c.CornerRadius = UDim.new(0, 8)

			local lbl = Instance.new("TextLabel", f)
			lbl.Size = UDim2.new(0.6, 0, 1, 0)
			lbl.Position = UDim2.new(0, 10, 0, 0)
			lbl.Text = p.DisplayName .. " (@" .. p.Name .. ")"
			lbl.Font = Enum.Font.Gotham
			lbl.TextSize = 12
			lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
			lbl.TextXAlignment = Enum.TextXAlignment.Left
			lbl.BackgroundTransparency = 1

			local hasEgg = p.Character and (p.Character:FindFirstChild("CarriedEgg") or p.Character:FindFirstChild("Egg"))

			local sBtn = Instance.new("TextButton", f)
			sBtn.Size = UDim2.new(0, 65, 0, 26)
			sBtn.Position = UDim2.new(1, -75, 0.5, -13)
			sBtn.Text = "Steal"
			sBtn.Font = Enum.Font.GothamBold
			sBtn.TextSize = 11
			sBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			sBtn.BackgroundColor3 = hasEgg and Color3.fromRGB(0, 200, 100) or Color3.fromRGB(200, 50, 50)
			local sc = Instance.new("UICorner", sBtn) sc.CornerRadius = UDim.new(0, 6)

			sBtn.MouseButton1Click:Connect(function()
				if hasEgg and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
					local myChar = LocalPlayer.Character
					if myChar and myChar:FindFirstChild("HumanoidRootPart") then
						-- Lengket ke Player & Pukul Pentungan
						myChar.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 2)
						local tool = myChar:FindFirstChildOfClass("Tool") or LocalPlayer.Backpack:FindFirstChildOfClass("Tool")
						if tool then
							tool.Parent = myChar
							tool:Activate()
						end
					end
				end
			end)
		end
	end
end

-- TAB 5: NOTIFICATION TELEGRAM CONFIG
AddToggle(TabNotif, "Telegram Notifier On/Off", Config.NotifEnabled, function(v)
	Config.NotifEnabled = v
end)

local function AddInput(parent, placeholder, defaultText, callback)
	local box = Instance.new("TextBox", parent)
	box.Size = UDim2.new(1, -10, 0, 35)
	box.PlaceholderText = placeholder
	box.Text = defaultText
	box.Font = Enum.Font.Gotham
	box.TextSize = 12
	box.TextColor3 = Color3.fromRGB(255, 255, 255)
	box.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
	box.BackgroundTransparency = 0.3
	local c = Instance.new("UICorner", box) c.CornerRadius = UDim.new(0, 8)

	box.FocusLost:Connect(function()
		callback(box.Text)
	end)
end

AddInput(TabNotif, "Bot Token Telegram...", Config.TelegramToken, function(t) Config.TelegramToken = t end)
AddInput(TabNotif, "ID Penerima (Chat ID)...", Config.TelegramChatID, function(t) Config.TelegramChatID = t end)

-- MAIN BACKGROUND LOOPS
RunService.Stepped:Connect(function()
	if Config.SpeedBoost and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
		LocalPlayer.Character.Humanoid.WalkSpeed = Config.SpeedValue
	end
end)

-- Main Loop Logic: Priority Auto Steal
task.spawn(function()
	while task.wait(1) do
		if Config.AutoSteal then
			local eggs = GetEggsInWorkspace()
			local bestEgg = nil
			local highestWeight = -1

			for _, egg in ipairs(eggs) do
				local w = GetRarityWeight(egg.Rarity)
				if w > 0 and w > highestWeight then
					highestWeight = w
					bestEgg = egg.Instance
				end
			end

			if bestEgg then
				ExecuteStealSequence(bestEgg)
				UpdateHistoryUI()
			end
		end
	end
end)

-- Periodically update Panel & Duel lists
task.spawn(function()
	while task.wait(3) do
		if MainFrame.Visible then
			PopulatePanel()
			UpdatePlayerList()
		end
	end
end)
