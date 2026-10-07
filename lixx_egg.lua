-- LIXX EGG SCRIPT (Roblox Lua)
-- Auto Egg, History Egg, Duel Player, Notification Telegram, & Panel UI

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Global Configuration & State Management
getgenv().LixxConfig = {
    TelegramBotToken = "",
    TelegramChatID = "",
    SpeedBoostValue = 50,
    SpeedBoostEnabled = false,
    AutoStealEnabled = false,
    NotificationEnabled = false
}

local HistoryData = {}
local CurrentRarityPriority = { ["Divine"] = 1, ["Eternal"] = 2, ["Secret"] = 3 }

-- Utility Functions
local function getCharacter()
    return LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
end

local function getRootPart()
    local char = getCharacter()
    return char:WaitForChild("HumanoidRootPlayer", 5) or char:WaitForChild("HumanoidRootPart")
end

local function sendTelegramNotification(eggName, rarity)
    if not getgenv().LixxConfig.NotificationEnabled then return end
    if getgenv().LixxConfig.TelegramBotToken == "" or getgenv().LixxConfig.TelegramChatID == "" then return end

    local message = string.format("🎉 **LIXX EGG ALERT** 🎉\n\nPlayer: %s\nBerhasil Mengambil Egg: %s\nRarity: %s", LocalPlayer.Name, eggName, rarity)
    local url = "https://api.telegram.org/bot" .. getgenv().LixxConfig.TelegramBotToken .. "/sendMessage"
    
    local requestBody = HttpService:JSONEncode({
        chat_id = getgenv().LixxConfig.TelegramChatID,
        text = message,
        parse_mode = "Markdown"
    })

    if syn and syn.request then
        syn.request({Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = requestBody})
    elseif request then
        request({Url = url, Method = "POST", Headers = {["Content-Type"] = "application/json"}, Body = requestBody})
    end
end

local function logEggHistory(eggName, rarity)
    table.insert(HistoryData, {Name = eggName, Rarity = rarity, Time = os.date("%X")})
    sendTelegramNotification(eggName, rarity)
end

-- Teleport Logic Execution
local function executeStealRoutine(eggObject)
    if not eggObject or not eggObject:FindFirstChild("HumanoidRootPart") and not eggObject:IsA("BasePart") then return end
    
    local root = getRootPart()
    local targetPos = eggObject:IsA("BasePart") and eggObject.CFrame or eggObject.HumanoidRootPart.CFrame
    
    -- Lari/Move menuju telur
    root.CFrame = targetPos
    task.wait(0.1)
    
    -- Ambil Telur (Fire Touch / Interaction)
    if firetouchinterest and eggObject:IsA("BasePart") then
        firetouchinterest(root, eggObject, 0)
        firetouchinterest(root, eggObject, 1)
    end
    
    -- Teleport ke Forest
    local forestLocation = workspace:FindFirstChild("Forest") or workspace:FindFirstChild("ForestZone")
    if forestLocation then
        root.CFrame = forestLocation:IsA("Model") and forestLocation:GetPivot() or forestLocation.CFrame
    end
    
    -- Jeda 2 Detik
    task.wait(2)
    
    -- Teleport Ke Base
    local baseLocation = workspace:FindFirstChild("Bases") and workspace.Bases:FindFirstChild(LocalPlayer.Name)
    if baseLocation then
        root.CFrame = baseLocation:GetPivot()
    end
    
    logEggHistory(eggObject.Name, eggObject:GetAttribute("Rarity") or "Unknown")
end

-- Priority Auto Steal Target Scanner
local function getPriorityEgg()
    local eggsFolder = workspace:FindFirstChild("Eggs") or workspace:FindFirstChild("SpawnedEggs")
    if not eggsFolder then return nil end

    local bestEgg = nil
    local highestPriority = 999

    for _, egg in pairs(eggsFolder:GetChildren()) do
        local rarity = egg:GetAttribute("Rarity") or egg.Name
        if CurrentRarityPriority[rarity] then
            if CurrentRarityPriority[rarity] < highestPriority then
                highestPriority = CurrentRarityPriority[rarity]
                bestEgg = egg
            end
        end
    end
    return bestEgg
end

-- Loop Auto Steal
task.spawn(function()
    while task.wait(0.5) do
        if getgenv().LixxConfig.AutoStealEnabled then
            local targetEgg = getPriorityEgg()
            if targetEgg then
                executeStealRoutine(targetEgg)
            end
        end
    end
end)

-- Speed Boost Loop
RunService.Stepped:Connect(function()
    if getgenv().LixxConfig.SpeedBoostEnabled then
        local char = getCharacter()
        local hum = char:FindFirstChildOfClass("Humanoid")
        if hum then
            hum.WalkSpeed = getgenv().LixxConfig.SpeedBoostValue
        end
    end
end)

--------------------------------------------------------------------------------
-- UI CONSTRUCTION (Minecraft Styled Green Theme)
--------------------------------------------------------------------------------

local ScreenGui = Instance.GuiTemplate or Instance.new("ScreenGui")
ScreenGui.Name = "LIXX_EGG_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Toggle Logo Button (L Button)
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "LogoL_Button"
ToggleButton.Size = UDim2.new(0, 45, 0, 45)
ToggleButton.Position = UDim2.new(0, 15, 0.4, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(45, 120, 45)
ToggleButton.BorderColor3 = Color3.fromRGB(20, 60, 20)
ToggleButton.BorderSizePixel = 3
ToggleButton.Text = "L"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 24
ToggleButton.Font = Enum.Font.FredokaOne
ToggleButton.Parent = ScreenGui

-- Main Container Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 650, 0, 380)
MainFrame.Position = UDim2.new(0.5, -325, 0.5, -190)
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
MainFrame.BorderColor3 = Color3.fromRGB(45, 120, 45)
MainFrame.BorderSizePixel = 4
MainFrame.Parent = ScreenGui

-- Sidebar Frame (Menu Navigasi 5 Item)
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 180, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local SideLayout = Instance.new("UIListLayout")
SideLayout.SortOrder = Enum.SortOrder.LayoutOrder
SideLayout.Padding = UDim.new(0, 5)
SideLayout.Parent = Sidebar

-- Content Container
local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -180, 1, 0)
ContentFrame.Position = UDim2.new(0, 180, 0, 0)
ContentFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
ContentFrame.BorderSizePixel = 0
ContentFrame.Parent = MainFrame

-- Close Button (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.FredokaOne
CloseBtn.TextSize = 18
CloseBtn.Parent = MainFrame

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Menu Pages Management
local Pages = {}
local MenuNames = {"Auto Egg", "History Egg", "Duel Player", "Notification", "Settings"}

local function createPage(name)
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -20, 1, -50)
    page.Position = UDim2.new(0, 10, 0, 40)
    page.BackgroundTransparency = 1
    page.Visible = false
    page.ScrollBarThickness = 6
    page.Parent = ContentFrame
    Pages[name] = page
    return page
end

for _, name in ipairs(MenuNames) do
    createPage(name)
    
    local navBtn = Instance.new("TextButton")
    navBtn.Size = UDim2.new(1, -10, 0, 45)
    navBtn.BackgroundColor3 = Color3.fromRGB(45, 100, 45)
    navBtn.BorderColor3 = Color3.fromRGB(20, 60, 20)
    navBtn.BorderSizePixel = 2
    navBtn.Text = name
    navBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    navBtn.Font = Enum.Font.SourceSansBold
    navBtn.TextSize = 16
    navBtn.Parent = Sidebar
    
    navBtn.MouseButton1Click:Connect(function()
        for pageName, pageFrame in pairs(Pages) do
            pageFrame.Visible = (pageName == name)
        end
    end)
end

-- Default View
Pages["Auto Egg"].Visible = true

--------------------------------------------------------------------------------
-- 1. AUTO EGG PAGE FITUR
--------------------------------------------------------------------------------
local AutoEggPage = Pages["Auto Egg"]
local AutoEggLayout = Instance.new("UIListLayout")
AutoEggLayout.Padding = UDim.new(0, 10)
AutoEggLayout.Parent = AutoEggPage

-- Steal On/Off Toggle
local StealToggle = Instance.new("TextButton")
StealToggle.Size = UDim2.new(1, -10, 0, 40)
StealToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
StealToggle.Text = "Steal On/Off : OFF"
StealToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
StealToggle.Font = Enum.Font.SourceSansBold
StealToggle.TextSize = 16
StealToggle.Parent = AutoEggPage

StealToggle.MouseButton1Click:Connect(function()
    getgenv().LixxConfig.AutoStealEnabled = not getgenv().LixxConfig.AutoStealEnabled
    StealToggle.Text = "Steal On/Off : " .. (getgenv().LixxConfig.AutoStealEnabled and "ON" or "OFF")
    StealToggle.BackgroundColor3 = getgenv().LixxConfig.AutoStealEnabled and Color3.fromRGB(45, 150, 45) or Color3.fromRGB(60, 60, 60)
end)

-- Buka Panel Button
local PanelBtn = Instance.new("TextButton")
PanelBtn.Size = UDim2.new(1, -10, 0, 40)
PanelBtn.BackgroundColor3 = Color3.fromRGB(45, 120, 45)
PanelBtn.Text = "Buka Panel Telur (Manual Rarity UI)"
PanelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PanelBtn.Font = Enum.Font.SourceSansBold
PanelBtn.TextSize = 16
PanelBtn.Parent = AutoEggPage

-- Floating Egg Panel UI
local EggPanelFrame = Instance.new("Frame")
EggPanelFrame.Size = UDim2.new(0, 300, 0, 350)
EggPanelFrame.Position = UDim2.new(0.5, -150, 0.5, -175)
EggPanelFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
EggPanelFrame.BorderColor3 = Color3.fromRGB(45, 120, 45)
EggPanelFrame.BorderSizePixel = 3
EggPanelFrame.Visible = false
EggPanelFrame.Parent = ScreenGui

local PanelClose = Instance.new("TextButton")
PanelClose.Size = UDim2.new(0, 25, 0, 25)
PanelClose.Position = UDim2.new(1, -28, 0, 3)
PanelClose.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
PanelClose.Text = "X"
PanelClose.TextColor3 = Color3.fromRGB(255, 255, 255)
PanelClose.Parent = EggPanelFrame

PanelClose.MouseButton1Click:Connect(function() EggPanelFrame.Visible = false end)
PanelBtn.MouseButton1Click:Connect(function() EggPanelFrame.Visible = true end)

-- Speed Boost UI
local SpeedToggle = Instance.new("TextButton")
SpeedToggle.Size = UDim2.new(1, -10, 0, 40)
SpeedToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
SpeedToggle.Text = "Speed Boost On/Off : OFF"
SpeedToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedToggle.Font = Enum.Font.SourceSansBold
SpeedToggle.TextSize = 16
SpeedToggle.Parent = AutoEggPage

SpeedToggle.MouseButton1Click:Connect(function()
    getgenv().LixxConfig.SpeedBoostEnabled = not getgenv().LixxConfig.SpeedBoostEnabled
    SpeedToggle.Text = "Speed Boost On/Off : " .. (getgenv().LixxConfig.SpeedBoostEnabled and "ON" or "OFF")
    SpeedToggle.BackgroundColor3 = getgenv().LixxConfig.SpeedBoostEnabled and Color3.fromRGB(45, 150, 45) or Color3.fromRGB(60, 60, 60)
end)

--------------------------------------------------------------------------------
-- 2. HISTORY EGG PAGE FITUR
--------------------------------------------------------------------------------
local HistoryPage = Pages["History Egg"]
local HistoryList = Instance.new("UIListLayout")
HistoryList.Parent = HistoryPage

local DeleteHistoryBtn = Instance.new("TextButton")
DeleteHistoryBtn.Size = UDim2.new(1, -10, 0, 35)
DeleteHistoryBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
DeleteHistoryBtn.Text = "DELETED / HAPUS HISTORY"
DeleteHistoryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DeleteHistoryBtn.Font = Enum.Font.SourceSansBold
DeleteHistoryBtn.TextSize = 14
DeleteHistoryBtn.Parent = HistoryPage

DeleteHistoryBtn.MouseButton1Click:Connect(function()
    HistoryData = {}
    for _, child in pairs(HistoryPage:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
end)

--------------------------------------------------------------------------------
-- 3. DUEL PLAYER PAGE FITUR
--------------------------------------------------------------------------------
local DuelPage = Pages["Duel Player"]
local DuelLayout = Instance.new("UIListLayout")
DuelLayout.Parent = DuelPage

local function refreshDuelList()
    for _, child in pairs(DuelPage:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for _, targetPlayer in pairs(Players:GetPlayers()) do
        if targetPlayer ~= LocalPlayer then
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, -10, 0, 40)
            card.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
            card.Parent = DuelPage

            local pName = Instance.new("TextLabel")
            pName.Size = UDim2.new(0.6, 0, 1, 0)
            pName.Text = targetPlayer.DisplayName
            pName.TextColor3 = Color3.fromRGB(255, 255, 255)
            pName.BackgroundTransparency = 1
            pName.Parent = card

            local stealBtn = Instance.new("TextButton")
            stealBtn.Size = UDim2.new(0.35, 0, 0.8, 0)
            stealBtn.Position = UDim2.new(0.62, 0, 0.1, 0)
            stealBtn.Font = Enum.Font.SourceSansBold
            stealBtn.Text = "STEAL"
            stealBtn.Parent = card

            -- Deteksi apakah Player Membawa Telur
            local hasEgg = targetPlayer.Character and targetPlayer.Character:FindFirstChild("Egg")
            if hasEgg then
                stealBtn.BackgroundColor3 = Color3.fromRGB(45, 180, 45)
            else
                stealBtn.BackgroundColor3 = Color3.fromRGB(180, 45, 45)
            end

            stealBtn.MouseButton1Click:Connect(function()
                if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                    local root = getRootPart()
                    root.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 2)
                    
                    -- Pukul menggunakan Pentungan kayu
                    local tool = LocalPlayer.Backpack:FindFirstChild("Wooden Club") or LocalPlayer.Character:FindFirstChild("Wooden Club")
                    if tool then
                        tool.Parent = LocalPlayer.Character
                        tool:Activate()
                    end
                end
            end)
        end
    end
end

task.spawn(function()
    while task.wait(3) do
        if Pages["Duel Player"].Visible then
            refreshDuelList()
        end
    end
end)

--------------------------------------------------------------------------------
-- 4. NOTIFICATION PAGE CONFIG FITUR
--------------------------------------------------------------------------------
local NotifPage = Pages["Notification"]
local NotifLayout = Instance.new("UIListLayout")
NotifLayout.Padding = UDim.new(0, 8)
NotifLayout.Parent = NotifPage

local TokenBox = Instance.new("TextBox")
TokenBox.Size = UDim2.new(1, -10, 0, 35)
TokenBox.PlaceholderText = "Masukkan Bot Telegram Token..."
TokenBox.Text = getgenv().LixxConfig.TelegramBotToken
TokenBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
TokenBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TokenBox.Parent = NotifPage

local IDBox = Instance.new("TextBox")
IDBox.Size = UDim2.new(1, -10, 0, 35)
IDBox.PlaceholderText = "Masukkan Telegram Chat ID..."
IDBox.Text = getgenv().LixxConfig.TelegramChatID
IDBox.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
IDBox.TextColor3 = Color3.fromRGB(255, 255, 255)
IDBox.Parent = NotifPage

TokenBox.FocusLost:Connect(function() getgenv().LixxConfig.TelegramBotToken = TokenBox.Text end)
IDBox.FocusLost:Connect(function() getgenv().LixxConfig.TelegramChatID = IDBox.Text end)

local NotifToggle = Instance.new("TextButton")
NotifToggle.Size = UDim2.new(1, -10, 0, 40)
NotifToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
NotifToggle.Text = "Notification On/Off : OFF"
NotifToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
NotifToggle.Font = Enum.Font.SourceSansBold
NotifToggle.TextSize = 16
NotifToggle.Parent = NotifPage

NotifToggle.MouseButton1Click:Connect(function()
    getgenv().LixxConfig.NotificationEnabled = not getgenv().LixxConfig.NotificationEnabled
    NotifToggle.Text = "Notification On/Off : " .. (getgenv().LixxConfig.NotificationEnabled and "ON" or "OFF")
    NotifToggle.BackgroundColor3 = getgenv().LixxConfig.NotificationEnabled and Color3.fromRGB(45, 150, 45) or Color3.fromRGB(60, 60, 60)
end)
