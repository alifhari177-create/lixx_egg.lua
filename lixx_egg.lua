-- =======================================================
-- SCRIPT LIXX EGG - MAP STEEL AND EGG
-- Created for execution via GitHub / Roblox Executor
-- =======================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Config Default Telegram
local TelegramConfig = {
    BotToken = "YOUR_BOT_TOKEN_HERE",
    ChatID = "YOUR_CHAT_ID_HERE",
    Enabled = false
}

-- System History Storage
local HistoryLogs = {}

-- State System
local Flags = {
    AutoSteal = false,
    SpeedBoost = false,
    SpeedValue = 50,
    Notification = false
}

-- Base Coordinates (Disesuaikan otomatis jika ada area base player)
local ForestCFrame = CFrame.new(100, 10, 200) -- Ganti dengan CFrame Forest yang presisi di map
local BaseCFrame = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") and LocalPlayer.Character.HumanoidRootPart.CFrame or CFrame.new(0, 10, 0)

-- Function Safe Movement (Anti-Detection / Anti-Kick)
local function SafeMoveTo(targetCFrame, speedMultiplier)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart

    local distance = (hrp.Position - targetCFrame.Position).Magnitude
    local duration = math.clamp(distance / (30 * (speedMultiplier or 1)), 0.3, 3) -- Gerakan smooth, tidak terlalu kencang

    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = targetCFrame})
    
    -- Temporarily bypass collision/fall detection
    hrp.Velocity = Vector3.zero
    tween:Play()
    tween.Completed:Wait()
end

-- Teleport Sequence (Lari -> Ambil -> Forest (2s) -> Base)
local function ExecuteStealSequence(eggObject)
    if not eggObject or not eggObject:IsA("Model") and not eggObject:IsA("BasePart") then return end
    
    local targetPos = eggObject:GetPivot()
    
    -- 1. Lari ke Telur secara halus
    SafeMoveTo(targetPos, 1.5)
    
    -- 2. Ambil Telur (Fire Touch / ProximityPrompt / Interaction Event)
    firetouchinterest(LocalPlayer.Character.HumanoidRootPart, eggObject:IsA("Model") and eggObject.PrimaryPart or eggObject, 0)
    task.wait(0.1)
    firetouchinterest(LocalPlayer.Character.HumanoidRootPart, eggObject:IsA("Model") and eggObject.PrimaryPart or eggObject, 1)
    
    -- Log History
    table.insert(HistoryLogs, {
        Time = os.date("%X"),
        Name = eggObject.Name,
        Rarity = eggObject:GetAttribute("Rarity") or "Unknown"
    })
    
    -- Send Telegram Notification if Enabled
    if Flags.Notification and TelegramConfig.BotToken ~= "YOUR_BOT_TOKEN_HERE" then
        task.spawn(function()
            local msg = "🎉 **LIXX EGG NOTIFICATION**\nBerhasil mengambil telur: " .. eggObject.Name
            local url = "https://api.telegram.org/bot" .. TelegramConfig.BotToken .. "/sendMessage"
            local payload = HttpService:JSONEncode({
                chat_id = TelegramConfig.ChatID,
                text = msg,
                parse_mode = "Markdown"
            })
            pcall(function()
                request({
                    Url = url,
                    Method = "POST",
                    Headers = {["Content-Type"] = "application/json"},
                    Body = payload
                })
            end)
        end)
    end

    -- 3. Teleport Smooth ke Forest & Berhenti 2 Detik
    SafeMoveTo(ForestCFrame, 2)
    task.wait(2)

    -- 4. Teleport ke Base
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        SafeMoveTo(BaseCFrame, 2)
    end
end

-- Prioritas Auto Steal: Divine > Eternal > Secret
task.spawn(function()
    while task.wait(1) do
        if Flags.AutoSteal then
            local workspaceEggs = workspace:FindFirstChild("Eggs") or workspace
            local targetEgg = nil

            -- Prioritas 1: Divine
            for _, egg in pairs(workspaceEggs:GetChildren()) do
                if egg:GetAttribute("Rarity") == "Divine" or egg.Name:find("Divine") then
                    targetEgg = egg
                    break
                end
            end

            -- Prioritas 2: Eternal
            if not targetEgg then
                for _, egg in pairs(workspaceEggs:GetChildren()) do
                    if egg:GetAttribute("Rarity") == "Eternal" or egg.Name:find("Eternal") then
                        targetEgg = egg
                        break
                    end
                end
            end

            -- Prioritas 3: Secret
            if not targetEgg then
                for _, egg in pairs(workspaceEggs:GetChildren()) do
                    if egg:GetAttribute("Rarity") == "Secret" or egg.Name:find("Secret") then
                        targetEgg = egg
                        break
                    end
                end
            end

            if targetEgg then
                ExecuteStealSequence(targetEgg)
            end
        end
    end
end)

-- Speed Boost Handling
RunService.Stepped:Connect(function()
    if Flags.SpeedBoost and LocalPlayer.Character and LocalPlayer.Character:FindFirstChildOfClass("Humanoid") then
        LocalPlayer.Character:FindFirstChildOfClass("Humanoid").WalkSpeed = Flags.SpeedValue
    end
end)

-- =======================================================
-- BUILD UI INTERFACE (Minecraft Style Dark/Green Theme)
-- =======================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LIXX_EGG_UI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Logo Toggle Widget (L)
local LogoBtn = Instance.new("TextButton")
LogoBtn.Size = UDim2.new(0, 45, 0, 45)
LogoBtn.Position = UDim2.new(0.02, 0, 0.4, 0)
LogoBtn.BackgroundColor3 = Color3.fromRGB(35, 140, 35)
LogoBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoBtn.Text = "L"
LogoBtn.Font = Enum.Font.SourceSansBold
LogoBtn.TextSize = 28
LogoBtn.Visible = false
LogoBtn.Parent = ScreenGui

local UICornerLogo = Instance.new("UICorner", LogoBtn)
UICornerLogo.CornerRadius = UDim.new(0, 8)

-- Main Frame UI
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 620, 0, 360)
MainFrame.Position = UDim2.new(0.5, -310, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner", MainFrame)
MainCorner.CornerRadius = UDim.new(0, 10)

-- Header Title & Close (X)
local TitleBar = Instance.new("Frame")
TitleBar.Size = UDim2.new(1, 0, 0, 40)
TitleBar.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
TitleBar.Parent = MainFrame

local TitleText = Instance.new("TextLabel")
TitleText.Text = "SCRIPT LIXX EGG"
TitleText.TextColor3 = Color3.fromRGB(85, 255, 85)
TitleText.Font = Enum.Font.SourceSansBold
TitleText.TextSize = 20
TitleText.Position = UDim2.new(0, 15, 0, 0)
TitleText.Size = UDim2.new(0, 200, 1, 0)
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.BackgroundTransparency = 1
TitleText.Parent = TitleBar

local CloseBtn = Instance.new("TextButton")
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 85, 85)
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.TextSize = 22
CloseBtn.Size = UDim2.new(0, 40, 1, 0)
CloseBtn.Position = UDim2.new(1, -40, 0, 0)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Parent = TitleBar

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    LogoBtn.Visible = true
end)

LogoBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    LogoBtn.Visible = false
end)

-- Sidebar Menu (5 Menu Navigasi)
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 160, 1, -40)
Sidebar.Position = UDim2.new(0, 0, 0, 40)
Sidebar.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
Sidebar.Parent = MainFrame

local UIListLayoutSide = Instance.new("UIListLayout", Sidebar)
UIListLayoutSide.Padding = UDim.new(0, 5)

-- Container Halaman
local ContentFolder = Instance.new("Frame")
ContentFolder.Size = UDim2.new(1, -170, 1, -50)
ContentFolder.Position = UDim2.new(0, 165, 0, 45)
ContentFolder.BackgroundTransparency = 1
ContentFolder.Parent = MainFrame

local Pages = {}

local function CreateMenuButton(name, pageName)
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 40)
    btn.Position = UDim2.new(0, 5, 0, 0)
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    btn.Font = Enum.Font.SourceSans
    btn.TextSize = 16
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.Parent = Sidebar

    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.Parent = ContentFolder
    page.ScrollBarThickness = 4
    Pages[pageName] = page

    btn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end
        page.Visible = true
    end)
    return page
end

-- 1. Auto Egg Page
local AutoEggPage = CreateMenuButton("Auto Egg", "AutoEgg")
AutoEggPage.Visible = true

-- Toggle Auto Steal
local StealToggle = Instance.new("TextButton")
StealToggle.Size = UDim2.new(1, -10, 0, 40)
StealToggle.Text = "Steal On/Off: OFF"
StealToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
StealToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
StealToggle.Parent = AutoEggPage

StealToggle.MouseButton1Click:Connect(function()
    Flags.AutoSteal = not Flags.AutoSteal
    StealToggle.Text = "Steal On/Off: " .. (Flags.AutoSteal and "ON" or "OFF")
    StealToggle.BackgroundColor3 = Flags.AutoSteal and Color3.fromRGB(35, 140, 35) or Color3.fromRGB(40, 40, 40)
end)

-- Speed Boost UI
local SpeedFrame = Instance.new("Frame")
SpeedFrame.Size = UDim2.new(1, -10, 0, 80)
SpeedFrame.Position = UDim2.new(0, 0, 0, 50)
SpeedFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
SpeedFrame.Parent = AutoEggPage

local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Text = "Speed Boost Value: 50"
SpeedLabel.Size = UDim2.new(1, 0, 0, 30)
SpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Parent = SpeedFrame

local SpeedToggle = Instance.new("TextButton")
SpeedToggle.Size = UDim2.new(1, -20, 0, 35)
SpeedToggle.Position = UDim2.new(0, 10, 0, 35)
SpeedToggle.Text = "Speed Boost On/Off: OFF"
SpeedToggle.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
SpeedToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedToggle.Parent = SpeedFrame

SpeedToggle.MouseButton1Click:Connect(function()
    Flags.SpeedBoost = not Flags.SpeedBoost
    SpeedToggle.Text = "Speed Boost On/Off: " .. (Flags.SpeedBoost and "ON" or "OFF")
    SpeedToggle.BackgroundColor3 = Flags.SpeedBoost and Color3.fromRGB(35, 140, 35) or Color3.fromRGB(50, 50, 50)
end)

-- 2. History Egg Page
local HistoryPage = CreateMenuButton("History Egg", "History")
local ClearHistBtn = Instance.new("TextButton")
ClearHistBtn.Size = UDim2.new(1, -10, 0, 35)
ClearHistBtn.Text = "Delete History"
ClearHistBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
ClearHistBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ClearHistBtn.Parent = HistoryPage

-- 3. Duel Player Page
local DuelPage = CreateMenuButton("Duel Player", "Duel")
local RefreshPlayersBtn = Instance.new("TextButton")
RefreshPlayersBtn.Size = UDim2.new(1, -10, 0, 35)
RefreshPlayersBtn.Text = "Refresh Server Players"
RefreshPlayersBtn.BackgroundColor3 = Color3.fromRGB(35, 140, 35)
RefreshPlayersBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RefreshPlayersBtn.Parent = DuelPage

-- 4. Notification Page
local NotifPage = CreateMenuButton("Notification", "Notification")
local NotifToggle = Instance.new("TextButton")
NotifToggle.Size = UDim2.new(1, -10, 0, 40)
NotifToggle.Text = "Notification On/Off: OFF"
NotifToggle.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
NotifToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
NotifToggle.Parent = NotifPage

NotifToggle.MouseButton1Click:Connect(function()
    Flags.Notification = not Flags.Notification
    NotifToggle.Text = "Notification On/Off: " .. (Flags.Notification and "ON" or "OFF")
    NotifToggle.BackgroundColor3 = Flags.Notification and Color3.fromRGB(35, 140, 35) or Color3.fromRGB(40, 40, 40)
end)

-- 5. Settings Page
local SettingsPage = CreateMenuButton("Settings", "Settings")
