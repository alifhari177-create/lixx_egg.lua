-- =================================================================
-- SCRIPT NAME: LIXX EGG (FIXED FULL ENGINE)
-- AUTHOR: LIXX
-- MAP: Steal an Egg (Roblox)
-- =================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Master Configuration
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
local IsStealing = false

-- Safe Teleport / Tween Movement (Anti-Desync & Anti-Cheat Bypass)
local function SmoothMoveTo(targetCFrame, speed)
	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end
	local root = char.HumanoidRootPart
	
	local distance = (root.Position - targetCFrame.Position).Magnitude
	local timeToTravel = math.max(distance / (speed or 80), 0.1)

	local tweenInfo = TweenInfo.new(timeToTravel, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(root, tweenInfo, {CFrame = targetCFrame})
	
	-- Matikan physics benturan saat teleport
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then part.CanCollide = false end
	end
	
	tween:Play()
	tween.Completed:Wait()
end

-- Deteksi Seluruh Telur & Rarity
local function GetWorldEggs()
	local eggsList = {}
	for _, v in ipairs(workspace:GetDescendants()) do
		if v:IsA("ProximityPrompt") and (v.ObjectText:find("Egg") or v.ActionText:find("Mencuri") or v.ActionText:find("Steal") or v.Parent.Name:find("Egg")) then
			local eggModel = v.Parent
			while eggModel and not eggModel:IsA("Model") and eggModel.Parent ~= workspace do
				eggModel = eggModel.Parent
			end
			if eggModel then
				local rarity = eggModel:GetAttribute("Rarity") or eggModel:GetAttribute("Tier") or "Secret"
				local name = eggModel.Name
				table.insert(eggsList, {
					Model = eggModel,
					Prompt = v,
					Name = name,
					Rarity = tostring(rarity)
				})
			end
		end
	end
	return eggsList
end

-- Bobot Rarity: Divine (3) > Eternal (2) > Secret (1)
local function GetRarityPriority(rarityStr)
	local s = string.lower(rarityStr)
	if s:find("divine") then return 3
	elseif s:find("eternal") then return 2
	elseif s:find("secret") then return 1
	end
	return 0
end

-- EKSEKUSI STEAL TELUR (SEQUENCE LENGKAP)
local function DoStealEgg(eggData)
	if IsStealing or not eggData or not eggData.Prompt then return end
	IsStealing = true

	local char = LocalPlayer.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then 
		IsStealing = false 
		return 
	end

	local targetPart = eggData.Prompt.Parent
	if targetPart:IsA("Model") then targetPart = targetPart.PrimaryPart or targetPart:FindFirstChildWhichPart("BasePart") end
	if not targetPart then IsStealing = false return end

	-- 1. Bergerak Cepat ke Telur
	SmoothMoveTo(targetPart.CFrame * CFrame.new(0, 2, 3), Config.SpeedValue)
	task.wait(0.1)

	-- 2. Trigger Ambil Telur (Fire Proximity Prompt)
	pcall(function()
		fireproximityprompt(eggData.Prompt)
	end)
	task.wait(0.3)

	-- Catat ke History
	table.insert(Config.History, {
		Name = eggData.Name,
		Rarity = eggData.Rarity,
		Time = os.date("%H:%M:%S")
	})

	-- Kirim Telegram Notifikasi jika aktif
	if Config.NotifEnabled and Config.TelegramToken ~= "" and Config.TelegramChatID ~= "" then
		task.spawn(function()
			local url = "https://api.telegram.org/bot" .. Config.TelegramToken .. "/sendMessage"
			local body = HttpService:JSONEncode({
				chat_id = Config.TelegramChatID,
				text = "🔥 *LIXX EGG NOTIFIER*\n\n✅ Berhasil mencuri: *" .. eggData.Name .. "*\n⭐ Rarity: *" .. eggData.Rarity .. "*\n⏰ Jam: " .. os.date("%X"),
				parse_mode = "Markdown"
			})
			pcall(function()
				request({
					Url = url,
					Method = "POST",
					Headers = {["Content-Type"] = "application/json"},
					Body = body
				})
			end)
		end)
	end

	-- 3. Teleport ke Wilayah Forest
	local forest = workspace:FindFirstChild("Forest", true) or workspace:FindFirstChild("ForestZone", true)
	if forest then
		local fPart = forest:IsA("BasePart") and forest or forest:FindFirstChildWhichPart("BasePart")
		if fPart then SmoothMoveTo(fPart.CFrame * CFrame.new(0, 3, 0), 120) end
	end

	-- 4. Berhenti 2 Detik di Forest
	task.wait(2)

	-- 5. Teleport ke Base
	local bases = workspace:FindFirstChild("Bases", true) or workspace:FindFirstChild("Plots", true)
	if bases then
		local myBase = bases:FindFirstChild(LocalPlayer.Name, true)
		if myBase then
			local bPart = myBase:IsA("BasePart") and myBase or myBase:FindFirstChildWhichPart("BasePart")
			if bPart then SmoothMoveTo(bPart.CFrame * CFrame.new(0, 4, 0), 150) end
		end
	end

	IsStealing = false
end

-- =================================================================
-- CREATION OF GLASSMORPHISM UI (LIXX EGG)
-- =================================================================
local CoreGui = game:GetService("CoreGui")
if CoreGui:FindFirstChild("LixxEggUI") then CoreGui.LixxEggUI:Destroy() end

local LixxEggUI = Instance.new("ScreenGui")
LixxEggUI.Name = "LixxEggUI"
LixxEggUI.Parent = CoreGui

-- Logo Floating "L"
local LogoL = Instance.new("TextButton", LixxEggUI)
LogoL.Name = "LogoL"
LogoL.Size = UDim2.new(0, 45, 0, 45)
LogoL.Position = UDim2.new(0.02, 0, 0.45, 0)
LogoL.BackgroundColor3 = Color3.fromRGB(15, 20, 35)
LogoL.BackgroundTransparency = 0.25
LogoL.Text = "L"
LogoL.TextColor3 = Color3.fromRGB(0, 230, 255)
LogoL.TextSize = 22
LogoL.Font = Enum.Font.FredokaOne
LogoL.Draggable = true
Instance.new("UICorner", LogoL).CornerRadius = UDim.new(0, 10)
local lStroke = Instance.new("UIStroke", LogoL)
lStroke.Color = Color3.fromRGB(0, 230, 255)
lStroke.Thickness = 1.5

-- Window Frame Utama
local MainFrame = Instance.new("Frame", LixxEggUI)
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 560, 0, 350)
MainFrame.Position = UDim2.new(0.3, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 15, 25)
MainFrame.BackgroundTransparency = 0.2
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 14)

local mStroke = Instance.new("UIStroke", MainFrame)
mStroke.Color = Color3.fromRGB(255, 255, 255)
mStroke.Transparency = 0.75

-- Top Header
local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(0, 200, 0, 40)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.Text = "LIXX EGG v1.0"
Title.Font = Enum.Font.GothamBold
Title.TextSize = 16
Title.TextColor3 = Color3.fromRGB(0, 230, 255)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.BackgroundTransparency = 1

local CloseBtn = Instance.new("TextButton", MainFrame)
CloseBtn.Size = UDim2.new(0, 28, 0, 28)
CloseBtn.Position = UDim2.new(1, -36, 0, 6)
CloseBtn.Text = "X"
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.TextSize = 14
CloseBtn.TextColor3 = Color3.fromRGB(255, 80, 80)
CloseBtn.BackgroundColor3 = Color3.fromRGB(40, 20, 25)
CloseBtn.BackgroundTransparency = 0.3
Instance.new("UICorner", CloseBtn).CornerRadius = UDim.new(0, 6)

CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)
LogoL.MouseButton1Click:Connect(function() MainFrame.Visible = not MainFrame.Visible end)

-- Sidebar Menu Navigasi
local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size = UDim2.new(0, 130, 1, -50)
Sidebar.Position = UDim2.new(0, 10, 0, 42)
Sidebar.BackgroundTransparency = 1
local sLayout = Instance.new("UIListLayout", Sidebar) sLayout.Padding = UDim.new(0, 5)

local Container = Instance.new("Frame", MainFrame)
Container.Size = UDim2.new(1, -155, 1, -50)
Container.Position = UDim2.new(0, 145, 0, 42)
Container.BackgroundTransparency = 1

local Pages = {}

local function RegisterMenu(menuName)
	local btn = Instance.new("TextButton", Sidebar)
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.Text = menuName
	btn.Font = Enum.Font.GothamMedium
	btn.TextSize = 11
	btn.TextColor3 = Color3.fromRGB(220, 220, 220)
	btn.BackgroundColor3 = Color3.fromRGB(25, 30, 45)
	btn.BackgroundTransparency = 0.4
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)

	local page = Instance.new("ScrollingFrame", Container)
	page.Size = UDim2.new(1, 0, 1, 0)
	page.BackgroundTransparency = 1
	page.Visible = false
	page.CanvasSize = UDim2.new(0, 0, 2, 0)
	page.ScrollBarThickness = 2
	local pLayout = Instance.new("UIListLayout", page) pLayout.Padding = UDim.new(0, 6)

	Pages[menuName] = page

	btn.MouseButton1Click:Connect(function()
		for _, p in pairs(Pages) do p.Visible = false end
		page.Visible = true
	end)
	return page
end

-- Inisialisasi 5 Menu Utama
local PageAuto = RegisterMenu("AUTO EGG")
local PagePanel = RegisterMenu("PANEL")
local PageHist = RegisterMenu("HISTORY EGG")
local PageDuel = RegisterMenu("DUEL PLAYER")
local PageNotif = RegisterMenu("NOTIFICATION")

Pages["AUTO EGG"].Visible = true

-- Helper Component UI Toggle
local function AddToggleUI(parentPage, textTitle, defaultVal, onToggle)
	local f = Instance.new("Frame", parentPage)
	f.Size = UDim2.new(1, -8, 0, 38)
	f.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
	f.BackgroundTransparency = 0.3
	Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

	local t = Instance.new("TextLabel", f)
	t.Size = UDim2.new(0.7, 0, 1, 0)
	t.Position = UDim2.new(0, 8, 0, 0)
	t.Text = textTitle
	t.Font = Enum.Font.Gotham
	t.TextSize = 11
	t.TextColor3 = Color3.fromRGB(255, 255, 255)
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.BackgroundTransparency = 1

	local btn = Instance.new("TextButton", f)
	btn.Size = UDim2.new(0, 55, 0, 24)
	btn.Position = UDim2.new(1, -63, 0.5, -12)
	btn.Text = defaultVal and "ON" or "OFF"
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.TextColor3 = defaultVal and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(255, 70, 70)
	btn.BackgroundColor3 = Color3.fromRGB(10, 15, 25)
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

	local state = defaultVal
	btn.MouseButton1Click:Connect(function()
		state = not state
		btn.Text = state and "ON" or "OFF"
		btn.TextColor3 = state and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(255, 70, 70)
		onToggle(state)
	end)
end

-- MENU 1: AUTO EGG
AddToggleUI(PageAuto, "Steal On/Off (Divine > Eternal > Secret)", Config.AutoSteal, function(v) Config.AutoSteal = v end)
AddToggleUI(PageAuto, "Speed Boost On/Off", Config.SpeedBoost, function(v)
	Config.SpeedBoost = v
	if not v and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
		LocalPlayer.Character.Humanoid.WalkSpeed = 16
	end
end)

-- Speed Value Box
local SpdBoxFrame = Instance.new("Frame", PageAuto)
SpdBoxFrame.Size = UDim2.new(1, -8, 0, 38)
SpdBoxFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
SpdBoxFrame.BackgroundTransparency = 0.3
Instance.new("UICorner", SpdBoxFrame).CornerRadius = UDim.new(0, 6)

local spdLabel = Instance.new("TextLabel", SpdBoxFrame)
spdLabel.Size = UDim2.new(0.5, 0, 1, 0)
spdLabel.Position = UDim2.new(0, 8, 0, 0)
spdLabel.Text = "Set Speed Boost:"
spdLabel.Font = Enum.Font.Gotham
spdLabel.TextSize = 11
spdLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
spdLabel.TextXAlignment = Enum.TextXAlignment.Left
spdLabel.BackgroundTransparency = 1

local spdInput = Instance.new("TextBox", SpdBoxFrame)
spdInput.Size = UDim2.new(0, 75, 0, 24)
spdInput.Position = UDim2.new(1, -83, 0.5, -12)
spdInput.Text = tostring(Config.SpeedValue)
spdInput.Font = Enum.Font.GothamBold
spdInput.TextSize = 11
spdInput.TextColor3 = Color3.fromRGB(255, 255, 255)
spdInput.BackgroundColor3 = Color3.fromRGB(10, 15, 25)
Instance.new("UICorner", spdInput).CornerRadius = UDim.new(0, 5)

spdInput.FocusLost:Connect(function()
	local num = tonumber(spdInput.Text)
	if num then Config.SpeedValue = num end
end)

-- MENU 2: PANEL (Steal Manual per Egg)
local RefreshPanelBtn = Instance.new("TextButton", PagePanel)
RefreshPanelBtn.Size = UDim2.new(1, -8, 0, 32)
RefreshPanelBtn.Text = "🔄 Refresh Eggs Server"
RefreshPanelBtn.Font = Enum.Font.GothamBold
RefreshPanelBtn.TextSize = 11
RefreshPanelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RefreshPanelBtn.BackgroundColor3 = Color3.fromRGB(30, 80, 150)
Instance.new("UICorner", RefreshPanelBtn).CornerRadius = UDim.new(0, 6)

local PanelScroll = Instance.new("Frame", PagePanel)
PanelScroll.Size = UDim2.new(1, -8, 1, -40)
PanelScroll.BackgroundTransparency = 1
local pScrollLayout = Instance.new("UIListLayout", PanelScroll) pScrollLayout.Padding = UDim.new(0, 5)

local function PopulateEggPanel()
	for _, child in ipairs(PanelScroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local eggs = GetWorldEggs()
	table.sort(eggs, function(a, b)
		return GetRarityPriority(a.Rarity) > GetRarityPriority(b.Rarity)
	end)

	for _, item in ipairs(eggs) do
		local row = Instance.new("Frame", PanelScroll)
		row.Size = UDim2.new(1, 0, 0, 42)
		row.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
		row.BackgroundTransparency = 0.3
		Instance.new("UICorner", row).CornerRadius = UDim.new(0, 6)

		local nameLbl = Instance.new("TextLabel", row)
		nameLbl.Size = UDim2.new(0.65, 0, 1, 0)
		nameLbl.Position = UDim2.new(0, 8, 0, 0)
		nameLbl.Text = item.Name .. " (" .. item.Rarity .. ")"
		nameLbl.Font = Enum.Font.Gotham
		nameLbl.TextSize = 11
		nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLbl.TextXAlignment = Enum.TextXAlignment.Left
		nameLbl.BackgroundTransparency = 1

		local stlBtn = Instance.new("TextButton", row)
		stlBtn.Size = UDim2.new(0, 60, 0, 24)
		stlBtn.Position = UDim2.new(1, -68, 0.5, -12)
		stlBtn.Text = "STEAL"
		stlBtn.Font = Enum.Font.GothamBold
		stlBtn.TextSize = 10
		stlBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		stlBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 90)
		Instance.new("UICorner", stlBtn).CornerRadius = UDim.new(0, 5)

		stlBtn.MouseButton1Click:Connect(function()
			task.spawn(function()
				DoStealEgg(item)
			end)
		end)
	end
end

RefreshPanelBtn.MouseButton1Click:Connect(PopulateEggPanel)

-- MENU 3: HISTORY EGG
local DelHistBtn = Instance.new("TextButton", PageHist)
DelHistBtn.Size = UDim2.new(1, -8, 0, 32)
DelHistBtn.Text = "🗑️ Clear History"
DelHistBtn.Font = Enum.Font.GothamBold
DelHistBtn.TextSize = 11
DelHistBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DelHistBtn.BackgroundColor3 = Color3.fromRGB(160, 40, 40)
Instance.new("UICorner", DelHistBtn).CornerRadius = UDim.new(0, 6)

local HistHolder = Instance.new("Frame", PageHist)
HistHolder.Size = UDim2.new(1, -8, 1, -40)
HistHolder.BackgroundTransparency = 1
local hHolderLayout = Instance.new("UIListLayout", HistHolder) hHolderLayout.Padding = UDim.new(0, 4)

local function RefreshHistoryList()
	for _, child in ipairs(HistHolder:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	for _, entry in ipairs(Config.History) do
		local f = Instance.new("Frame", HistHolder)
		f.Size = UDim2.new(1, 0, 0, 28)
		f.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
		f.BackgroundTransparency = 0.4
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 5)

		local txt = Instance.new("TextLabel", f)
		txt.Size = UDim2.new(1, -10, 1, 0)
		txt.Position = UDim2.new(0, 8, 0, 0)
		txt.Text = "[" .. entry.Time .. "] " .. entry.Name .. " - " .. entry.Rarity
		txt.Font = Enum.Font.Gotham
		txt.TextSize = 10
		txt.TextColor3 = Color3.fromRGB(200, 200, 200)
		txt.TextXAlignment = Enum.TextXAlignment.Left
		txt.BackgroundTransparency = 1
	end
end

DelHistBtn.MouseButton1Click:Connect(function()
	Config.History = {}
	RefreshHistoryList()
end)

-- MENU 4: DUEL PLAYER
AddToggleUI(PageDuel, "Duel Player On/Off", Config.DuelMode, function(v) Config.DuelMode = v end)

local DuelHolder = Instance.new("Frame", PageDuel)
DuelHolder.Size = UDim2.new(1, -8, 1, -45)
DuelHolder.BackgroundTransparency = 1
local dHolderLayout = Instance.new("UIListLayout", DuelHolder) dHolderLayout.Padding = UDim.new(0, 5)

local function RenderDuelPlayers()
	for _, child in ipairs(DuelHolder:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= LocalPlayer then
			local f = Instance.new("Frame", DuelHolder)
			f.Size = UDim2.new(1, 0, 0, 38)
			f.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
			f.BackgroundTransparency = 0.3
			Instance.new("UICorner", f).CornerRadius = UDim.new(0, 6)

			local pName = Instance.new("TextLabel", f)
			pName.Size = UDim2.new(0.6, 0, 1, 0)
			pName.Position = UDim2.new(0, 8, 0, 0)
			pName.Text = p.DisplayName
			pName.Font = Enum.Font.Gotham
			pName.TextSize = 11
			pName.TextColor3 = Color3.fromRGB(255, 255, 255)
			pName.TextXAlignment = Enum.TextXAlignment.Left
			pName.BackgroundTransparency = 1

			local hasEgg = p.Character and (p.Character:FindFirstChild("CarriedEgg") or p.Character:FindFirstChild("Egg") or p.Character:FindFirstChildWhichPart("Egg"))

			local stBtn = Instance.new("TextButton", f)
			stBtn.Size = UDim2.new(0, 60, 0, 24)
			stBtn.Position = UDim2.new(1, -68, 0.5, -12)
			stBtn.Text = "STEAL"
			stBtn.Font = Enum.Font.GothamBold
			stBtn.TextSize = 10
			stBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			stBtn.BackgroundColor3 = hasEgg and Color3.fromRGB(0, 190, 90) or Color3.fromRGB(200, 50, 50)
			Instance.new("UICorner", stBtn).CornerRadius = UDim.new(0, 5)

			stBtn.MouseButton1Click:Connect(function()
				if hasEgg and p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
					local myChar = LocalPlayer.Character
					if myChar and myChar:FindFirstChild("HumanoidRootPart") then
						myChar.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 1.5)
						local weapon = myChar:FindFirstChildOfClass("Tool") or LocalPlayer.Backpack:FindFirstChildOfClass("Tool")
						if weapon then
							weapon.Parent = myChar
							weapon:Activate()
						end
					end
				end
			end)
		end
	end
end

-- MENU 5: NOTIFICATION TELEGRAM
AddToggleUI(PageNotif, "Telegram Notifier On/Off", Config.NotifEnabled, function(v) Config.NotifEnabled = v end)

local function MakeInputBox(parent, placeholder, defText, onUpdate)
	local b = Instance.new("TextBox", parent)
	b.Size = UDim2.new(1, -8, 0, 34)
	b.PlaceholderText = placeholder
	b.Text = defText
	b.Font = Enum.Font.Gotham
	b.TextSize = 11
	b.TextColor3 = Color3.fromRGB(255, 255, 255)
	b.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
	b.BackgroundTransparency = 0.3
	Instance.new("UICorner", b).CornerRadius = UDim.new(0, 6)
	b.FocusLost:Connect(function() onUpdate(b.Text) end)
end

MakeInputBox(PageNotif, "Isi Bot Token Telegram...", Config.TelegramToken, function(t) Config.TelegramToken = t end)
MakeInputBox(PageNotif, "Isi ID Chat Penerima...", Config.TelegramChatID, function(t) Config.TelegramChatID = t end)

-- LOOPS SYSTEM UTAMA
RunService.Stepped:Connect(function()
	if Config.SpeedBoost and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
		LocalPlayer.Character.Humanoid.WalkSpeed = Config.SpeedValue
	end
end)

-- Loop Auto Steal (Divine > Eternal > Secret)
task.spawn(function()
	while task.wait(0.5) do
		if Config.AutoSteal and not IsStealing then
			local eggs = GetWorldEggs()
			local target = nil
			local maxPriority = -1

			for _, e in ipairs(eggs) do
				local priority = GetRarityPriority(e.Rarity)
				if priority > 0 and priority > maxPriority then
					maxPriority = priority
					target = e
				end
			end

			if target then
				DoStealEgg(target)
				RefreshHistoryList()
			end
		end
	end
end)

-- Background Refresh UI Panel & Duel List
task.spawn(function()
	while task.wait(2) do
		if MainFrame.Visible then
			if Pages["PANEL"].Visible then PopulateEggPanel() end
			if Pages["DUEL PLAYER"].Visible then RenderDuelPlayers() end
		end
	end
end)
