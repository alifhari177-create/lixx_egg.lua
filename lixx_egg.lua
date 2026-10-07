-- =================================================================
-- SCRIPT NAME: LIXX EGG v2.0 (FULL REBUILD ENGINE)
-- AUTHOR: LIXX
-- GAME: Steal an Egg (Roblox)
-- =================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Configuration Storage
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

-- =================================================================
-- HELPER FUNCTIONS (DETEKSI WORKSPACE & MOVEMENT)
-- =================================================================

-- 1. Mendapatkan Karakter & HumanoidRootPart secara Aman
local function GetRoot()
	local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
	return char:FindFirstChild("HumanoidRootPart")
end

-- 2. Movement / Tweening ke Target
local function MoveToTarget(targetPos, speed)
	local root = GetRoot()
	if not root then return end
	
	local distance = (root.Position - targetPos).Magnitude
	local travelTime = math.clamp(distance / (speed or 60), 0.1, 5)
	
	local tweenInfo = TweenInfo.new(travelTime, Enum.EasingStyle.Linear)
	local tween = TweenService:Create(root, tweenInfo, {CFrame = CFrame.new(targetPos)})
	
	-- Nonaktifkan Kanali Benturan Karakter
	if LocalPlayer.Character then
		for _, part in ipairs(LocalPlayer.Character:GetChildren()) do
			if part:IsA("BasePart") then part.CanCollide = false end
		end
	end
	
	tween:Play()
	tween.Completed:Wait()
end

-- 3. Scanner Telur Akurat untuk "Steal an Egg"
local function ScanWorldEggs()
	local detectedEggs = {}
	
	-- Cari di seluruh workspace yang memiliki ProximityPrompt
	for _, obj in ipairs(Workspace:GetDescendants()) do
		if obj:IsA("ProximityPrompt") then
			local parentModel = obj.Parent
			while parentModel and not parentModel:IsA("Model") and parentModel ~= Workspace do
				parentModel = parentModel.Parent
			end
			
			if parentModel then
				-- Tentukan Nama Telur
				local realName = parentModel.Name
				if realName == "Model" or realName:find("Part") or realName == "Workspace" then
					realName = obj.ObjectText ~= "" and obj.ObjectText or obj.ActionText
				end
				if realName == "" or not realName then realName = "Egg" end

				-- Tentukan Rarity
				local rarity = parentModel:GetAttribute("Rarity") 
					or parentModel:GetAttribute("Tier") 
					or parentModel:GetAttribute("Type") 
					or "Secret"
				
				table.insert(detectedEggs, {
					Name = tostring(realName),
					Rarity = tostring(rarity),
					Prompt = obj,
					Part = obj.Parent:IsA("BasePart") and obj.Parent or parentModel:FindFirstChildWhichPart("BasePart")
				})
			end
		end
	end
	return detectedEggs
end

-- 4. Prioritas Rarity: Divine > Eternal > Secret
local function GetRarityWeight(rarityName)
	local str = string.lower(tostring(rarityName))
	if str:find("divine") then return 3
	elseif str:find("eternal") then return 2
	elseif str:find("secret") then return 1
	end
	return 0
end

-- 5. Eksekusi Mencuri Telur (Full Sequence)
local function ExecuteSteal(eggData)
	if IsStealing or not eggData or not eggData.Prompt or not eggData.Part then return end
	IsStealing = true

	local root = GetRoot()
	if not root then IsStealing = false return end

	-- Bypass Jarak & Waktu Tahan ProximityPrompt
	eggData.Prompt.HoldDuration = 0
	eggData.Prompt.MaxActivationDistance = 9999

	-- A. Teleport / Move ke Dekat Telur
	MoveToTarget(eggData.Part.Position + Vector3.new(0, 2, 0), Config.SpeedValue)
	task.wait(0.1)

	-- B. Fire Proximity Prompt
	pcall(function()
		fireproximityprompt(eggData.Prompt)
	end)
	task.wait(0.2)

	-- Catat Riwayat
	table.insert(Config.History, 1, {
		Name = eggData.Name,
		Rarity = eggData.Rarity,
		Time = os.date("%H:%M:%S")
	})

	-- Kirim Notifikasi Telegram
	if Config.NotifEnabled and Config.TelegramToken ~= "" and Config.TelegramChatID ~= "" then
		task.spawn(function()
			local url = "https://api.telegram.org/bot" .. Config.TelegramToken .. "/sendMessage"
			local body = HttpService:JSONEncode({
				chat_id = Config.TelegramChatID,
				text = "🎉 *LIXX EGG STEALER*\n\n✅ Telur Ditemukan: *" .. eggData.Name .. "*\n⭐ Tier: *" .. eggData.Rarity .. "*\n⏰ Jam: " .. os.date("%X"),
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

	-- C. Teleport Kembali ke Forest / Base Safe Area
	local forest = Workspace:FindFirstChild("Forest", true) or Workspace:FindFirstChild("ForestZone", true)
	if forest then
		local fPart = forest:IsA("BasePart") and forest or forest:FindFirstChildWhichPart("BasePart")
		if fPart then MoveToTarget(fPart.Position + Vector3.new(0, 3, 0), 100) end
	end

	task.wait(2) -- Delay 2 detik di Forest

	-- D. Teleport ke Base
	local bases = Workspace:FindFirstChild("Bases", true) or Workspace:FindFirstChild("Plots", true)
	if bases then
		local myBase = bases:FindFirstChild(LocalPlayer.Name, true)
		if myBase then
			local bPart = myBase:IsA("BasePart") and myBase or myBase:FindFirstChildWhichPart("BasePart")
			if bPart then MoveToTarget(bPart.Position + Vector3.new(0, 4, 0), 120) end
		end
	end

	IsStealing = false
end

-- =================================================================
-- GLASSMORPHISM USER INTERFACE (UI)
-- =================================================================
local CoreGui = game:GetService("CoreGui")
if CoreGui:FindFirstChild("LixxEggUI") then CoreGui.LixxEggUI:Destroy() end

local LixxEggUI = Instance.new("ScreenGui")
LixxEggUI.Name = "LixxEggUI"
LixxEggUI.Parent = CoreGui

-- Floating Logo "L"
local LogoL = Instance.new("TextButton", LixxEggUI)
LogoL.Name = "LogoL"
LogoL.Size = UDim2.new(0, 45, 0, 45)
LogoL.Position = UDim2.new(0.02, 0, 0.45, 0)
LogoL.BackgroundColor3 = Color3.fromRGB(15, 20, 35)
LogoL.BackgroundTransparency = 0.2
LogoL.Text = "L"
LogoL.TextColor3 = Color3.fromRGB(0, 230, 255)
LogoL.TextSize = 22
LogoL.Font = Enum.Font.FredokaOne
LogoL.Draggable = true
Instance.new("UICorner", LogoL).CornerRadius = UDim.new(0, 10)
local lStroke = Instance.new("UIStroke", LogoL)
lStroke.Color = Color3.fromRGB(0, 230, 255)
lStroke.Thickness = 1.5

-- Main Frame UI
local MainFrame = Instance.new("Frame", LixxEggUI)
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 560, 0, 350)
MainFrame.Position = UDim2.new(0.3, 0, 0.25, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(12, 15, 25)
MainFrame.BackgroundTransparency = 0.15
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 12)

local mStroke = Instance.new("UIStroke", MainFrame)
mStroke.Color = Color3.fromRGB(255, 255, 255)
mStroke.Transparency = 0.8

-- Title Bar
local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(0, 200, 0, 40)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.Text = "LIXX EGG v2.0"
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

-- Sidebar Navigation
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

local function RegisterTab(tabName)
	local btn = Instance.new("TextButton", Sidebar)
	btn.Size = UDim2.new(1, 0, 0, 32)
	btn.Text = tabName
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

	Pages[tabName] = page

	btn.MouseButton1Click:Connect(function()
		for _, p in pairs(Pages) do p.Visible = false end
		page.Visible = true
	end)
	return page
end

-- Tab Windows
local TabAuto = RegisterTab("AUTO EGG")
local TabPanel = RegisterTab("PANEL")
local TabHist = RegisterTab("HISTORY EGG")
local TabDuel = RegisterTab("DUEL PLAYER")
local TabNotif = RegisterTab("NOTIFICATION")

Pages["AUTO EGG"].Visible = true

-- Component: Toggle Switch
local function CreateToggle(parent, textTitle, defaultState, callback)
	local f = Instance.new("Frame", parent)
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
	btn.Text = defaultState and "ON" or "OFF"
	btn.Font = Enum.Font.GothamBold
	btn.TextSize = 11
	btn.TextColor3 = defaultState and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(255, 70, 70)
	btn.BackgroundColor3 = Color3.fromRGB(10, 15, 25)
	Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 5)

	local currentState = defaultState
	btn.MouseButton1Click:Connect(function()
		currentState = not currentState
		btn.Text = currentState and "ON" or "OFF"
		btn.TextColor3 = currentState and Color3.fromRGB(0, 255, 140) or Color3.fromRGB(255, 70, 70)
		callback(currentState)
	end)
end

-- TAB 1: AUTO EGG
CreateToggle(TabAuto, "Steal On/Off (Divine > Eternal > Secret)", Config.AutoSteal, function(val)
	Config.AutoSteal = val
end)

CreateToggle(TabAuto, "Speed Boost On/Off", Config.SpeedBoost, function(val)
	Config.SpeedBoost = val
	if not val and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
		LocalPlayer.Character.Humanoid.WalkSpeed = 16
	end
end)

-- Speed Box Input
local SpdFrame = Instance.new("Frame", TabAuto)
SpdFrame.Size = UDim2.new(1, -8, 0, 38)
SpdFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
SpdFrame.BackgroundTransparency = 0.3
Instance.new("UICorner", SpdFrame).CornerRadius = UDim.new(0, 6)

local spdLabel = Instance.new("TextLabel", SpdFrame)
spdLabel.Size = UDim2.new(0.5, 0, 1, 0)
spdLabel.Position = UDim2.new(0, 8, 0, 0)
spdLabel.Text = "Set Speed Boost:"
spdLabel.Font = Enum.Font.Gotham
spdLabel.TextSize = 11
spdLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
spdLabel.TextXAlignment = Enum.TextXAlignment.Left
spdLabel.BackgroundTransparency = 1

local spdInput = Instance.new("TextBox", SpdFrame)
spdInput.Size = UDim2.new(0, 75, 0, 24)
spdInput.Position = UDim2.new(1, -83, 0.5, -12)
spdInput.Text = tostring(Config.SpeedValue)
spdInput.Font = Enum.Font.GothamBold
spdInput.TextSize = 11
spdInput.TextColor3 = Color3.fromRGB(255, 255, 255)
spdInput.BackgroundColor3 = Color3.fromRGB(10, 15, 25)
Instance.new("UICorner", spdInput).CornerRadius = UDim.new(0, 5)

spdInput.FocusLost:Connect(function()
	local val = tonumber(spdInput.Text)
	if val then Config.SpeedValue = val end
end)

-- TAB 2: PANEL (Manual Steal List)
local RefreshPanelBtn = Instance.new("TextButton", TabPanel)
RefreshPanelBtn.Size = UDim2.new(1, -8, 0, 32)
RefreshPanelBtn.Text = "🔄 Refresh Telur Server"
RefreshPanelBtn.Font = Enum.Font.GothamBold
RefreshPanelBtn.TextSize = 11
RefreshPanelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RefreshPanelBtn.BackgroundColor3 = Color3.fromRGB(30, 90, 160)
Instance.new("UICorner", RefreshPanelBtn).CornerRadius = UDim.new(0, 6)

local PanelHolder = Instance.new("Frame", TabPanel)
PanelHolder.Size = UDim2.new(1, -8, 1, -40)
PanelHolder.BackgroundTransparency = 1
local pHolderLayout = Instance.new("UIListLayout", PanelHolder) pHolderLayout.Padding = UDim.new(0, 5)

local function PopulatePanel()
	for _, c in ipairs(PanelHolder:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end

	local list = ScanWorldEggs()
	table.sort(list, function(a, b)
		return GetRarityWeight(a.Rarity) > GetRarityWeight(b.Rarity)
	end)

	for _, item in ipairs(list) do
		local row = Instance.new("Frame", PanelHolder)
		row.Size = UDim2.new(1, 0, 0, 40)
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
		stlBtn.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
		Instance.new("UICorner", stlBtn).CornerRadius = UDim.new(0, 5)

		stlBtn.MouseButton1Click:Connect(function()
			task.spawn(function()
				ExecuteSteal(item)
			end)
		end)
	end
end

RefreshPanelBtn.MouseButton1Click:Connect(PopulatePanel)

-- TAB 3: HISTORY EGG
local ClearHistBtn = Instance.new("TextButton", TabHist)
ClearHistBtn.Size = UDim2.new(1, -8, 0, 32)
ClearHistBtn.Text = "🗑️ Hapus History"
ClearHistBtn.Font = Enum.Font.GothamBold
ClearHistBtn.TextSize = 11
ClearHistBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ClearHistBtn.BackgroundColor3 = Color3.fromRGB(170, 40, 40)
Instance.new("UICorner", ClearHistBtn).CornerRadius = UDim.new(0, 6)

local HistHolder = Instance.new("Frame", TabHist)
HistHolder.Size = UDim2.new(1, -8, 1, -40)
HistHolder.BackgroundTransparency = 1
local hHolderLayout = Instance.new("UIListLayout", HistHolder) hHolderLayout.Padding = UDim.new(0, 4)

local function RenderHistory()
	for _, c in ipairs(HistHolder:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
	end
	for _, log in ipairs(Config.History) do
		local f = Instance.new("Frame", HistHolder)
		f.Size = UDim2.new(1, 0, 0, 28)
		f.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
		f.BackgroundTransparency = 0.4
		Instance.new("UICorner", f).CornerRadius = UDim.new(0, 5)

		local txt = Instance.new("TextLabel", f)
		txt.Size = UDim2.new(1, -10, 1, 0)
		txt.Position = UDim2.new(0, 8, 0, 0)
		txt.Text = "[" .. log.Time .. "] " .. log.Name .. " - " .. log.Rarity
		txt.Font = Enum.Font.Gotham
		txt.TextSize = 10
		txt.TextColor3 = Color3.fromRGB(200, 200, 200)
		txt.TextXAlignment = Enum.TextXAlignment.Left
		txt.BackgroundTransparency = 1
	end
end

ClearHistBtn.MouseButton1Click:Connect(function()
	Config.History = {}
	RenderHistory()
end)

-- TAB 4: DUEL PLAYER
CreateToggle(TabDuel, "Duel Mode On/Off", Config.DuelMode, function(val) Config.DuelMode = val end)

local DuelHolder = Instance.new("Frame", TabDuel)
DuelHolder.Size = UDim2.new(1, -8, 1, -45)
DuelHolder.BackgroundTransparency = 1
local dLayout = Instance.new("UIListLayout", DuelHolder) dLayout.Padding = UDim.new(0, 5)

local function PopulateDuelList()
	for _, c in ipairs(DuelHolder:GetChildren()) do
		if c:IsA("Frame") then c:Destroy() end
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

			local stBtn = Instance.new("TextButton", f)
			stBtn.Size = UDim2.new(0, 60, 0, 24)
			stBtn.Position = UDim2.new(1, -68, 0.5, -12)
			stBtn.Text = "ATTACK"
			stBtn.Font = Enum.Font.GothamBold
			stBtn.TextSize = 10
			stBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
			stBtn.BackgroundColor3 = Color3.fromRGB(220, 60, 60)
			Instance.new("UICorner", stBtn).CornerRadius = UDim.new(0, 5)

			stBtn.MouseButton1Click:Connect(function()
				if p.Character and p.Character:FindFirstChild("HumanoidRootPart") then
					local myRoot = GetRoot()
					if myRoot then
						myRoot.CFrame = p.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 2)
					end
				end
			end)
		end
	end
end

-- TAB 5: TELEGRAM NOTIFIER
CreateToggle(TabNotif, "Telegram Notifier On/Off", Config.NotifEnabled, function(val) Config.NotifEnabled = val end)

local function CreateInputField(parent, placeholderText, defaultVal, callback)
	local box = Instance.new("TextBox", parent)
	box.Size = UDim2.new(1, -8, 0, 34)
	box.PlaceholderText = placeholderText
	box.Text = defaultVal
	box.Font = Enum.Font.Gotham
	box.TextSize = 11
	box.TextColor3 = Color3.fromRGB(255, 255, 255)
	box.BackgroundColor3 = Color3.fromRGB(20, 25, 40)
	box.BackgroundTransparency = 0.3
	Instance.new("UICorner", box).CornerRadius = UDim.new(0, 6)
	box.FocusLost:Connect(function() callback(box.Text) end)
end

CreateInputField(TabNotif, "Isi Bot Token Telegram...", Config.TelegramToken, function(t) Config.TelegramToken = t end)
CreateInputField(TabNotif, "Isi ID Chat Telegram...", Config.TelegramChatID, function(t) Config.TelegramChatID = t end)

-- =================================================================
-- MAIN THREAD LOOPS
-- =================================================================

-- 1. Loop Speed Boost Engine
RunService.Stepped:Connect(function()
	if Config.SpeedBoost and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
		LocalPlayer.Character.Humanoid.WalkSpeed = Config.SpeedValue
	end
end)

-- 2. Loop Auto Steal (Divine > Eternal > Secret)
task.spawn(function()
	while task.wait(0.5) do
		if Config.AutoSteal and not IsStealing then
			local eggs = ScanWorldEggs()
			local bestTarget = nil
			local highestPriority = -1

			for _, egg in ipairs(eggs) do
				local weight = GetRarityWeight(egg.Rarity)
				if weight > highestPriority then
					highestPriority = weight
					bestTarget = egg
				end
			end

			if bestTarget then
				ExecuteSteal(bestTarget)
				RenderHistory()
			end
		end
	end
end)

-- 3. Loop Auto-Refresh UI Panel & Duel List saat UI terbuka
task.spawn(function()
	while task.wait(2) do
		if MainFrame.Visible then
			if Pages["PANEL"].Visible then PopulatePanel() end
			if Pages["DUEL PLAYER"].Visible then PopulateDuelList() end
		end
	end
end)
