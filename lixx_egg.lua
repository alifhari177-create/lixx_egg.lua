-- ====================================================================
-- SCRIPT NAME: LIXX EGG
-- GAME: MAP STEAL AND EGG
-- DESIGN: MINECRAFT GREEN THEME WITH LOGO 'L' & TOGGLE BUTTON
-- ====================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer

-- Global Configuration & State
local Config = {
    TelegramToken = "",
    TelegramChatID = "",
    SpeedValue = 50,
    SpeedEnabled = false,
    AutoStealEnabled = false,
    NotificationEnabled = false
}

local HistoryData = {}
local PriorityRarity = { ["Divine"] = 1, ["Eternal"] = 2, ["Secret"] = 3 }

-- ====================================================================
-- UI BUILDING (MINECRAFT STYLE WITH GREEN ACCENTS)
-- ====================================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LIXX_EGG_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Logo Toggle Button (Tombol L)
local ToggleButton = Instance.new("TextButton")
ToggleButton.Name = "LogoL_Toggle"
ToggleButton.Size = UDim2.new(0, 50, 0, 50)
ToggleButton.Position = UDim2.new(0, 15, 0.4, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(34, 139, 34)
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Text = "L"
ToggleButton.Font = Enum.Font.FredokaOne
ToggleButton.TextSize = 30
ToggleButton.Parent = ScreenGui

local UICornerL = Instance.new("UICorner")
UICornerL.CornerRadius = UDim.new(0, 10)
UICornerL.Parent = ToggleButton

local UIBorderL = Instance.new("UIStroke")
UIBorderL.Color = Color3.fromRGB(0, 255, 127)
UIBorderL.Thickness = 3
UIBorderL.Parent = ToggleButton

-- Main Window Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 620, 0, 360)
MainFrame.Position = UDim2.new(0.5, -310, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(25, 30, 25)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 12)
MainCorner.Parent = MainFrame

local MainStroke = Instance.new("UIStroke")
MainStroke.Color = Color3.fromRGB(46, 139, 87)
MainStroke.Thickness = 2
MainStroke.Parent = MainFrame

-- Top Bar / Header
local TopBar = Instance.new("Frame")
TopBar.Name = "TopBar"
TopBar.Size = UDim2.new(1, 0, 0, 40)
TopBar.BackgroundColor3 = Color3.fromRGB(15, 20, 15)
TopBar.Parent = MainFrame

local TopBarCorner = Instance.new("UICorner")
TopBarCorner.CornerRadius = UDim.new(0, 12)
TopBarCorner.Parent = TopBar

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(0, 200, 1, 0)
TitleLabel.Position = UDim2.new(0, 15, 0, 0)
TitleLabel.Text = "LIXX EGG"
TitleLabel.Font = Enum.Font.FredokaOne
TitleLabel.TextSize = 22
TitleLabel.TextColor3 = Color3.fromRGB(50, 205, 50)
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.BackgroundTransparency = 1
TitleLabel.Parent = TopBar

-- Tombol Close X
local CloseButton = Instance.new("TextButton")
CloseButton.Name = "CloseButton"
CloseButton.Size = UDim2.new(0, 30, 0, 30)
CloseButton.Position = UDim2.new(1, -35, 0, 5)
CloseButton.Text = "X"
CloseButton.Font = Enum.Font.FredokaOne
CloseButton.TextSize = 18
CloseButton.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseButton.BackgroundColor3 = Color3.fromRGB(178, 34, 34)
CloseButton.Parent = TopBar

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseButton

-- Navigation SideBar
local SideBar = Instance.new("Frame")
SideBar.Name = "SideBar"
SideBar.Size = UDim2.new(0, 160, 1, -40)
SideBar.Position = UDim2.new(0, 0, 0, 40)
SideBar.BackgroundColor3 = Color3.fromRGB(20, 25, 20)
SideBar.Parent = MainFrame

local UIListNav = Instance.new("UIListLayout")
UIListNav.Padding = UDim.new(0, 5)
UIListNav.HorizontalAlignment = Enum.HorizontalAlignment.Center
UIListNav.SortOrder = Enum.SortOrder.LayoutOrder
UIListNav.Parent = SideBar

-- Content Area
local ContentArea = Instance.new("Frame")
ContentArea.Name = "ContentArea"
ContentArea.Size = UDim2.new(1, -170, 1, -50)
ContentArea.Position = UDim2.new(0, 165, 0, 45)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

-- Sub-Frames (Pages)
local Pages = {}

local function CreatePage(name)
    local Page = Instance.new("ScrollingFrame")
    Page.Name = name .. "_Page"
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.Visible = false
    Page.CanvasSize = UDim2.new(0, 0, 2, 0)
    Page.ScrollBarThickness = 4
    Page.Parent = ContentArea
    Pages[name] = Page
    return Page
end

-- Membuat 5 Halaman Menu
local AutoEggPage = CreatePage("AutoEgg")
local HistoryPage = CreatePage("HistoryEgg")
local DuelPage    = CreatePage("DuelPlayer")
local NotifPage   = CreatePage("Notification")
local SettingsPage= CreatePage("Settings")

AutoEggPage.Visible = true -- Default Halaman 1

-- Sistem Navigasi Menu
local MenuButtons = {
    {Name = "Auto Egg", Page = "AutoEgg"},
    {Name = "History Egg", Page = "HistoryEgg"},
    {Name = "Duel Player", Page = "DuelPlayer"},
    {Name = "Notification", Page = "Notification"},
    {Name = "Settings", Page = "Settings"}
}

local function SwitchPage(targetPageName)
    for name, page in pairs(Pages) do
        page.Visible = (name == targetPageName)
    end
end

for i, menu in ipairs(MenuButtons) do
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0.9, 0, 0, 40)
    Btn.Text = menu.Name
    Btn.Font = Enum.Font.SourceSansBold
    Btn.TextSize = 16
    Btn.TextColor3 = Color3.fromRGB(220, 220, 220)
    Btn.BackgroundColor3 = Color3.fromRGB(35, 45, 35)
    Btn.Parent = SideBar

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 6)
    BtnCorner.Parent = Btn

    Btn.MouseButton1Click:Connect(function()
        SwitchPage(menu.Page)
    end)
end

-- Toggle Trigger Logika Buka/Tutup GUI
ToggleButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

CloseButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- ====================================================================
-- MENU 1: AUTO EGG FEATURES
-- ====================================================================

local LayoutAuto = Instance.new("UIListLayout")
LayoutAuto.Padding = UDim.new(0, 10)
LayoutAuto.Parent = AutoEggPage

-- 1. Steal On/Off Toggle Button
local StealContainer = Instance.new("Frame")
StealContainer.Size = UDim2.new(1, -10, 0, 45)
StealContainer.BackgroundColor3 = Color3.fromRGB(30, 40, 30)
StealContainer.Parent = AutoEggPage

local StealLabel = Instance.new("TextLabel")
StealLabel.Text = "  Steal On/Off"
StealLabel.Size = UDim2.new(0.6, 0, 1, 0)
StealLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
StealLabel.Font = Enum.Font.SourceSansBold
StealLabel.TextSize = 16
StealLabel.TextXAlignment = Enum.TextXAlignment.Left
StealLabel.BackgroundTransparency = 1
StealLabel.Parent = StealContainer

local StealBtn = Instance.new("TextButton")
StealBtn.Size = UDim2.new(0.3, 0, 0.7, 0)
StealBtn.Position = UDim2.new(0.65, 0, 0.15, 0)
StealBtn.Text = "OFF"
StealBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
StealBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
StealBtn.Font = Enum.Font.SourceSansBold
StealBtn.Parent = StealContainer

StealBtn.MouseButton1Click:Connect(function()
    Config.AutoStealEnabled = not Config.AutoStealEnabled
    if Config.AutoStealEnabled then
        StealBtn.Text = "ON"
        StealBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
    else
        StealBtn.Text = "OFF"
        StealBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    end
end)

-- 2. Open Panel Egg UI Button
local PanelBtn = Instance.new("TextButton")
PanelBtn.Size = UDim2.new(1, -10, 0, 45)
PanelBtn.Text = "Buka Panel Telur\nTampilkan UI Telur & Isi Rarity"
PanelBtn.BackgroundColor3 = Color3.fromRGB(30, 40, 30)
PanelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PanelBtn.Font = Enum.Font.SourceSansBold
PanelBtn.TextSize = 14
PanelBtn.Parent = AutoEggPage

-- Frame Popup Mini Panel
local EggPanelFrame = Instance.new("Frame")
EggPanelFrame.Size = UDim2.new(0, 300, 0, 350)
EggPanelFrame.Position = UDim2.new(0.5, -150, 0.5, -175)
EggPanelFrame.BackgroundColor3 = Color3.fromRGB(20, 25, 20)
EggPanelFrame.Visible = false
EggPanelFrame.Parent = ScreenGui

local PanelTitle = Instance.new("TextLabel")
PanelTitle.Size = UDim2.new(1, 0, 0, 30)
PanelTitle.Text = "PANEL TELUR SERVER"
PanelTitle.TextColor3 = Color3.fromRGB(0, 255, 127)
PanelTitle.Font = Enum.Font.SourceSansBold
PanelTitle.Parent = EggPanelFrame

local PanelClose = Instance.new("TextButton")
PanelClose.Size = UDim2.new(0, 25, 0, 25)
PanelClose.Position = UDim2.new(1, -30, 0, 2)
PanelClose.Text = "X"
PanelClose.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
PanelClose.Parent = EggPanelFrame

PanelClose.MouseButton1Click:Connect(function()
    EggPanelFrame.Visible = false
end)

PanelBtn.MouseButton1Click:Connect(function()
    EggPanelFrame.Visible = true
end)

-- 3. Speed Boost Value & Slider UI
local SpeedBox = Instance.new("TextBox")
SpeedBox.Size = UDim2.new(1, -10, 0, 35)
SpeedBox.Text = "Speed Boost Value: " .. tostring(Config.SpeedValue)
SpeedBox.BackgroundColor3 = Color3.fromRGB(30, 40, 30)
SpeedBox.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedBox.Font = Enum.Font.SourceSansBold
SpeedBox.Parent = AutoEggPage

SpeedBox.FocusLost:Connect(function()
    local val = tonumber(SpeedBox.Text)
    if val then
        Config.SpeedValue = val
    end
    SpeedBox.Text = "Speed Boost Value: " .. tostring(Config.SpeedValue)
end)

local SpeedToggleBtn = Instance.new("TextButton")
SpeedToggleBtn.Size = UDim2.new(1, -10, 0, 35)
SpeedToggleBtn.Text = "Speed Boost: OFF"
SpeedToggleBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
SpeedToggleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedToggleBtn.Font = Enum.Font.SourceSansBold
SpeedToggleBtn.Parent = AutoEggPage

SpeedToggleBtn.MouseButton1Click:Connect(function()
    Config.SpeedEnabled = not Config.SpeedEnabled
    if Config.SpeedEnabled then
        SpeedToggleBtn.Text = "Speed Boost: ON"
        SpeedToggleBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
    else
        SpeedToggleBtn.Text = "Speed Boost: OFF"
        SpeedToggleBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    end
end)

-- ====================================================================
-- MENU 2: HISTORY EGG
-- ====================================================================

local HistoryList = Instance.new("ScrollingFrame")
HistoryList.Size = UDim2.new(1, -10, 0.8, 0)
HistoryList.BackgroundTransparency = 1
HistoryList.Parent = HistoryPage

local HistLayout = Instance.new("UIListLayout")
HistLayout.Parent = HistoryList

local ClearHistoryBtn = Instance.new("TextButton")
ClearHistoryBtn.Size = UDim2.new(1, -10, 0, 35)
ClearHistoryBtn.Position = UDim2.new(0, 0, 0.85, 0)
ClearHistoryBtn.Text = "DELETE HISTORY"
ClearHistoryBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
ClearHistoryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ClearHistoryBtn.Font = Enum.Font.SourceSansBold
ClearHistoryBtn.Parent = HistoryPage

local function AddHistory(eggName, rarity)
    table.insert(HistoryData, {Name = eggName, Rarity = rarity, Time = os.date("%X")})
    local Item = Instance.new("TextLabel")
    Item.Size = UDim2.new(1, 0, 0, 25)
    Item.Text = "[" .. os.date("%X") .. "] Stole: " .. eggName .. " (" .. rarity .. ")"
    Item.TextColor3 = Color3.fromRGB(255, 255, 255)
    Item.Font = Enum.Font.SourceSans
    Item.BackgroundTransparency = 1
    Item.Parent = HistoryList
end

ClearHistoryBtn.MouseButton1Click:Connect(function()
    HistoryData = {}
    for _, child in pairs(HistoryList:GetChildren()) do
        if child:IsA("TextLabel") then
            child:Destroy()
        end
    end
end)

-- ====================================================================
-- MENU 3: DUEL PLAYER
-- ====================================================================

local DuelList = Instance.new("ScrollingFrame")
DuelList.Size = UDim2.new(1, -10, 1, 0)
DuelList.BackgroundTransparency = 1
DuelList.Parent = DuelPage

local DuelLayout = Instance.new("UIListLayout")
DuelLayout.Parent = DuelList

local function RefreshDuelList()
    for _, child in pairs(DuelList:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    for _, plr in pairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local Frame = Instance.new("Frame")
            Frame.Size = UDim2.new(1, 0, 0, 40)
            Frame.BackgroundColor3 = Color3.fromRGB(30, 35, 30)
            Frame.Parent = DuelList
            
            local NameLbl = Instance.new("TextLabel")
            NameLbl.Size = UDim2.new(0.6, 0, 1, 0)
            NameLbl.Text = " " .. plr.DisplayName
            NameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            NameLbl.TextXAlignment = Enum.TextXAlignment.Left
            NameLbl.BackgroundTransparency = 1
            NameLbl.Parent = Frame
            
            local StealPlrBtn = Instance.new("TextButton")
            StealPlrBtn.Size = UDim2.new(0.3, 0, 0.8, 0)
            StealPlrBtn.Position = UDim2.new(0.68, 0, 0.1, 0)
            
            -- Cek status egg player
            local hasEgg = plr.Character and plr.Character:FindFirstChild("CarriedEgg")
            if hasEgg then
                StealPlrBtn.Text = "STEAL"
                StealPlrBtn.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
            else
                StealPlrBtn.Text = "NO EGG"
                StealPlrBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
            end
            StealPlrBtn.Parent = Frame
        end
    end
end

-- ====================================================================
-- MENU 4: NOTIFICATION SETTINGS
-- ====================================================================

local TokenBox = Instance.new("TextBox")
TokenBox.Size = UDim2.new(1, -10, 0, 35)
TokenBox.PlaceholderText = "Input Telegram Bot Token..."
TokenBox.Text = Config.TelegramToken
TokenBox.BackgroundColor3 = Color3.fromRGB(30, 40, 30)
TokenBox.TextColor3 = Color3.fromRGB(255, 255, 255)
TokenBox.Parent = NotifPage

local IDBox = Instance.new("TextBox")
IDBox.Size = UDim2.new(1, -10, 0, 35)
IDBox.Position = UDim2.new(0, 0, 0.2, 0)
IDBox.PlaceholderText = "Input Chat ID..."
IDBox.Text = Config.TelegramChatID
IDBox.BackgroundColor3 = Color3.fromRGB(30, 40, 30)
IDBox.TextColor3 = Color3.fromRGB(255, 255, 255)
IDBox.Parent = NotifPage

local NotifToggle = Instance.new("TextButton")
NotifToggle.Size = UDim2.new(1, -10, 0, 35)
NotifToggle.Position = UDim2.new(0, 0, 0.4, 0)
NotifToggle.Text = "Telegram Notif: OFF"
NotifToggle.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
NotifToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
NotifToggle.Parent = NotifPage

NotifToggle.MouseButton1Click:Connect(function()
    Config.NotificationEnabled = not Config.NotificationEnabled
    Config.TelegramToken = TokenBox.Text
    Config.TelegramChatID = IDBox.Text
    
    if Config.NotificationEnabled then
        NotifToggle.Text = "Telegram Notif: ON"
        NotifToggle.BackgroundColor3 = Color3.fromRGB(50, 180, 50)
    else
        NotifToggle.Text = "Telegram Notif: OFF"
        NotifToggle.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
    end
end)

local function SendTelegramNotification(eggName)
    if not Config.NotificationEnabled or Config.TelegramToken == "" then return end
    local url = "https://api.telegram.org/bot" .. Config.TelegramToken .. "/sendMessage"
    local data = {
        chat_id = Config.TelegramChatID,
        text = "🎉 [LIXX EGG Notification]\nBerhasil mengambil telur: " .. eggName
    }
    local success, response = pcall(function()
        return HttpService:PostAsync(url, HttpService:JSONEncode(data), Enum.HttpContentType.ApplicationJson)
    end)
end

-- ====================================================================
-- CORE LOGIC & MOVEMENT ENGINE
-- ====================================================================

-- 1. Speed Controller Loop
RunService.Stepped:Connect(function()
    if Config.SpeedEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = Config.SpeedValue
    end
end)

-- 2. Teleport & Egg Steal Logic Sequence
local function ExecuteStealSequence(eggObject)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = char.HumanoidRootPart
    
    -- Lari/Bergerak ke lokasi Telur
    if eggObject and eggObject:FindFirstChild("TouchInterest") then
        firetouchinterest(hrp, eggObject, 0)
        firetouchinterest(hrp, eggObject, 1)
        wait(0.1)
    end
    
    -- Teleport Ke Forest
    local forestLocation = Workspace:FindFirstChild("Forest") or Vector3.new(100, 10, 100)
    if typeof(forestLocation) == "Instance" then
        hrp.CFrame = forestLocation.CFrame
    else
        hrp.CFrame = CFrame.new(forestLocation)
    end
    
    -- Berhenti 2 Detik di Forest
    wait(2)
    
    -- Teleport Ke Base Player
    local playerBase = Workspace:FindFirstChild("Bases") and Workspace.Bases:FindFirstChild(LocalPlayer.Name)
    if playerBase then
        hrp.CFrame = playerBase.CFrame
    else
        hrp.CFrame = CFrame.new(0, 10, 0) -- Default Home Base Fallback
    end
    
    -- Simpan Log History & Kirim Notifikasi
    local name = eggObject and eggObject.Name or "Unknown Egg"
    AddHistory(name, "Special")
    SendTelegramNotification(name)
end

-- 3. Auto-Scan Loop Server (Prioritas Divine > Eternal > Secret)
task.spawn(function()
    while true do
        wait(1)
        if Config.AutoStealEnabled then
            local eggsFolder = Workspace:FindFirstChild("Eggs")
            if eggsFolder then
                local bestEgg = nil
                local highestPriority = 999
                
                for _, egg in pairs(eggsFolder:GetChildren()) do
                    local rarity = egg:GetAttribute("Rarity") or egg.Name
                    if PriorityRarity[rarity] and PriorityRarity[rarity] < highestPriority then
                        highestPriority = PriorityRarity[rarity]
                        bestEgg = egg
                    end
                end
                
                if bestEgg then
                    ExecuteStealSequence(bestEgg)
                end
            end
        end
    end
end)

-- Refresh UI Periodic Updates
task.spawn(function()
    while true do
        wait(3)
        if DuelPage.Visible then
            RefreshDuelList()
        end
    end
end)
