-- ========================================================
-- SCRIPT LIXX EGG - STEAL AND EGG
-- UI Style: Minecraft Theme (Green & Blocky)
-- ========================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- State Variables
local AutoStealActive = false
local SpeedBoostActive = false
local SpeedValue = 50
local DuelActive = false
local NotifActive = false
local TelegramToken = ""
local TelegramChatID = ""
local HistoryLogs = {}

-- Priority Order for Auto Steal
local RarityPriority = {
    ["Divine"] = 1,
    ["Eternal"] = 2,
    ["Secret"] = 3
}

-- Target Locations (Sesuaikan koordinat jika diperlukan)
local ForestCFrame = CFrame.new(120, 15, -350) -- Koordinat wilayah Forest
local BaseCFrame = CFrame.new(0, 10, 0)        -- Koordinat Base Player

-- HttpRequest function helper
local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

-- Telegram Notification Function
local function sendTelegramNotif(eggName, rarity)
    if not NotifActive or TelegramToken == "" or TelegramChatID == "" then return end
    if not httpRequest then return end
    
    local message = "🎉 **LIXX EGG NOTIFICATION** 🎉\n" ..
                    "👤 Player: " .. LocalPlayer.Name .. "\n" ..
                    "🥚 Telur Diberhasilkan: " .. eggName .. "\n" ..
                    "⭐ Rarity: " .. rarity
                    
    local payload = HttpService:JSONEncode({
        chat_id = TelegramChatID,
        text = message,
        parse_mode = "Markdown"
    })
    
    httpRequest({
        Url = "https://api.telegram.org/bot" .. TelegramToken .. "/sendMessage",
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = payload
    })
end

-- History Logger
local function addHistory(eggName, rarity)
    local timeStr = os.date("%X")
    table.insert(HistoryLogs, 1, "[" .. timeStr .. "] " .. eggName .. " (" .. rarity .. ")")
end

-- ========================================================
-- CREATE UI (MINECRAFT STYLE)
-- ========================================================

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LixxEggGui"
ScreenGui.ResetOnSpawn = false
if gethui then
    ScreenGui.Parent = gethui()
else
    ScreenGui.Parent = game:GetService("CoreGui")
end

-- Floating Logo 'L'
local LogoButton = Instance.new("TextButton")
LogoButton.Name = "LogoButton"
LogoButton.Size = UDim2.new(0, 45, 0, 45)
LogoButton.Position = UDim2.new(0, 15, 0.4, 0)
LogoButton.BackgroundColor3 = Color3.fromRGB(45, 80, 30)
LogoButton.BorderColor3 = Color3.fromRGB(20, 40, 15)
LogoButton.BorderSizePixel = 3
LogoButton.Text = "L"
LogoButton.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoButton.TextSize = 24
LogoButton.Font = Enum.Font.Arcade
LogoButton.Active = true
LogoButton.Draggable = true
LogoButton.Parent = ScreenGui

-- Main UI Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 520, 0, 340)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -170)
MainFrame.BackgroundColor3 = Color3.fromRGB(35, 60, 25) -- Minecraft Dark Green
MainFrame.BorderColor3 = Color3.fromRGB(15, 30, 10)
MainFrame.BorderSizePixel = 4
MainFrame.Visible = true
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- Header Title Bar
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundColor3 = Color3.fromRGB(25, 45, 18)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -40, 1, 0)
TitleText.Position = UDim2.new(0, 10, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "LIXX EGG - MAP STEAL AND EGG"
TitleText.TextColor3 = Color3.fromRGB(120, 235, 80)
TitleText.TextSize = 16
TitleText.Font = Enum.Font.Arcade
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = Header

-- Close Button 'X'
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 25)
CloseBtn.Position = UDim2.new(1, -32, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.BorderColor3 = Color3.fromRGB(100, 20, 20)
CloseBtn.BorderSizePixel = 2
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.Arcade
CloseBtn.TextSize = 16
CloseBtn.Parent = Header

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

LogoButton.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Sidebar Menu Container
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 120, 1, -35)
Sidebar.Position = UDim2.new(0, 0, 0, 35)
Sidebar.BackgroundColor3 = Color3.fromRGB(20, 35, 15)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

-- Content Frame Container
local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -125, 1, -40)
ContentFrame.Position = UDim2.new(0, 125, 0, 38)
ContentFrame.BackgroundTransparency = 1
ContentFrame.Parent = MainFrame

-- Menu Frames Table
local Menus = {}
local MenuButtons = {}

local MenuNames = {
    "AUTO EGG",
    "PANEL EGG",
    "SPEED BOOST",
    "HISTORY EGG",
    "DUEL & NOTIF"
}

local function SwitchTab(tabIndex)
    for i, frame in ipairs(Menus) do
        frame.Visible = (i == tabIndex)
    end
    for i, btn in ipairs(MenuButtons) do
        if i == tabIndex then
            btn.BackgroundColor3 = Color3.fromRGB(70, 130, 45)
        else
            btn.BackgroundColor3 = Color3.fromRGB(30, 55, 20)
        end
    end
end

for i, name in ipairs(MenuNames) do
    -- Menu Button
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(0.9, 0, 0, 30)
    btn.Position = UDim2.new(0.05, 0, 0, (i - 1) * 36 + 10)
    btn.BackgroundColor3 = Color3.fromRGB(30, 55, 20)
    btn.BorderColor3 = Color3.fromRGB(10, 25, 8)
    btn.BorderSizePixel = 2
    btn.Text = name
    btn.TextColor3 = Color3.fromRGB(220, 255, 200)
    btn.Font = Enum.Font.Arcade
    btn.TextSize = 12
    btn.Parent = Sidebar
    table.insert(MenuButtons, btn)

    -- Tab Content Frame
    local page = Instance.new("Frame")
    page.Size = UDim2.new(1, 0, 1, 0)
    page.BackgroundTransparency = 1
    page.Visible = (i == 1)
    page.Parent = ContentFrame
    table.insert(Menus, page)

    btn.MouseButton1Click:Connect(function()
        SwitchTab(i)
    end)
end

-- ========================================================
-- TAB 1: AUTO EGG
-- ========================================================
local Tab1 = Menus[1]

local AutoStealBtn = Instance.new("TextButton")
AutoStealBtn.Size = UDim2.new(0.9, 0, 0, 40)
AutoStealBtn.Position = UDim2.new(0.05, 0, 0.1, 0)
AutoStealBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
AutoStealBtn.BorderColor3 = Color3.fromRGB(80, 20, 20)
AutoStealBtn.BorderSizePixel = 2
AutoStealBtn.Text = "STEAL: OFF"
AutoStealBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
AutoStealBtn.Font = Enum.Font.Arcade
AutoStealBtn.TextSize = 16
AutoStealBtn.Parent = Tab1

local PriorityLabel = Instance.new("TextLabel")
PriorityLabel.Size = UDim2.new(0.9, 0, 0, 100)
PriorityLabel.Position = UDim2.new(0.05, 0, 0.35, 0)
PriorityLabel.BackgroundColor3 = Color3.fromRGB(25, 45, 18)
PriorityLabel.BorderColor3 = Color3.fromRGB(10, 25, 8)
PriorityLabel.BorderSizePixel = 2
PriorityLabel.Text = "PRIORITAS AUTO STEAL:\n1. Divine\n2. Eternal\n3. Secret"
PriorityLabel.TextColor3 = Color3.fromRGB(200, 255, 180)
PriorityLabel.Font = Enum.Font.Arcade
PriorityLabel.TextSize = 14
PriorityLabel.Parent = Tab1

-- Core Teleport / Steal Execution Routine
local function ExecuteStealProcess(eggObject, eggName, rarity)
    if not eggObject or not eggObject:FindFirstChild("HumanoidRootPart") and not eggObject.PrimaryPart then return end
    
    local targetPos = (eggObject.PrimaryPart and eggObject.PrimaryPart.Position) or eggObject:FindFirstChildWhichIsA("BasePart").Position
    
    -- 1. Lari ke telur
    Humanoid:MoveTo(targetPos)
    task.wait(0.3)
    
    -- 2. Ambil instan
    RootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 2, 0))
    task.wait(0.2)
    
    -- 3. Teleport ke Forest & Berhenti 2 detik
    RootPart.CFrame = ForestCFrame
    task.wait(2)
    
    -- 4. Teleport ke Base
    RootPart.CFrame = BaseCFrame
    
    -- Record & Notif
    addHistory(eggName or "Unknown Egg", rarity or "Common")
    sendTelegramNotif(eggName or "Unknown Egg", rarity or "Common")
end

AutoStealBtn.MouseButton1Click:Connect(function()
    AutoStealActive = not AutoStealActive
    if AutoStealActive then
        AutoStealBtn.Text = "STEAL: ON"
        AutoStealBtn.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
    else
        AutoStealBtn.Text = "STEAL: OFF"
        AutoStealBtn.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
    end
end)

-- Auto Steal Loop Thread
task.spawn(function()
    while true do
        task.wait(1)
        if AutoStealActive then
            local bestEgg = nil
            local highestPriority = 99
            local chosenRarity = ""
            local chosenName = ""

            -- Scan Workspace Eggs (Disesuaikan dengan folder telur di map)
            local eggFolder = Workspace:FindFirstChild("Eggs") or Workspace
            for _, obj in ipairs(eggFolder:GetChildren()) do
                local rarity = obj:GetAttribute("Rarity") or (obj:FindFirstChild("Rarity") and obj.Rarity.Value)
                if rarity and RarityPriority[rarity] then
                    if RarityPriority[rarity] < highestPriority then
                        highestPriority = RarityPriority[rarity]
                        bestEgg = obj
                        chosenRarity = rarity
                        chosenName = obj.Name
                    end
                end
            end

            if bestEgg then
                ExecuteStealProcess(bestEgg, chosenName, chosenRarity)
            end
        end
    end
end)

-- ========================================================
-- TAB 2: PANEL EGG (Manual Select & Refresh)
-- ========================================================
local Tab2 = Menus[2]

local ScrollPanel = Instance.new("ScrollingFrame")
ScrollPanel.Size = UDim2.new(0.95, 0, 0.8, 0)
ScrollPanel.Position = UDim2.new(0.025, 0, 0.025, 0)
ScrollPanel.BackgroundColor3 = Color3.fromRGB(20, 35, 15)
ScrollPanel.BorderColor3 = Color3.fromRGB(10, 20, 8)
ScrollPanel.BorderSizePixel = 2
ScrollPanel.ScrollBarThickness = 6
ScrollPanel.Parent = Tab2

local UIListLayout = Instance.new("UIListLayout")
UIListLayout.Padding = UDim.new(0, 5)
UIListLayout.Parent = ScrollPanel

local RefreshBtn = Instance.new("TextButton")
RefreshBtn.Size = UDim2.new(0.95, 0, 0.12, 0)
RefreshBtn.Position = UDim2.new(0.025, 0, 0.85, 0)
RefreshBtn.BackgroundColor3 = Color3.fromRGB(45, 90, 120)
RefreshBtn.BorderColor3 = Color3.fromRGB(20, 40, 60)
RefreshBtn.BorderSizePixel = 2
RefreshBtn.Text = "REFRESH LIST TELUR"
RefreshBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RefreshBtn.Font = Enum.Font.Arcade
RefreshBtn.TextSize = 14
RefreshBtn.Parent = Tab2

local function RefreshEggPanel()
    for _, child in ipairs(ScrollPanel:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local eggFolder = Workspace:FindFirstChild("Eggs") or Workspace
    local itemList = {}
    
    for _, egg in ipairs(eggFolder:GetChildren()) do
        if egg:IsA("Model") or egg:IsA("BasePart") then
            local rarity = egg:GetAttribute("Rarity") or "Common"
            table.insert(itemList, {Object = egg, Name = egg.Name, Rarity = rarity})
        end
    end
    
    -- Sort Highest Rarity First
    table.sort(itemList, function(a, b)
        local pA = RarityPriority[a.Rarity] or 99
        local pB = RarityPriority[b.Rarity] or 99
        return pA < pB
    end)
    
    for _, item in ipairs(itemList) do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(0.98, 0, 0, 45)
        card.BackgroundColor3 = Color3.fromRGB(30, 55, 20)
        card.BorderColor3 = Color3.fromRGB(15, 30, 10)
        card.BorderSizePixel = 2
        card.Parent = ScrollPanel
        
        local img = Instance.new("ImageLabel")
        img.Size = UDim2.new(0, 35, 0, 35)
        img.Position = UDim2.new(0, 5, 0, 5)
        img.BackgroundColor3 = Color3.fromRGB(15, 25, 10)
        img.Image = "rbxassetid://6031075931" -- Placeholder Icon Telur
        img.Parent = card
        
        local info = Instance.new("TextLabel")
        info.Size = UDim2.new(0.5, 0, 1, 0)
        info.Position = UDim2.new(0, 45, 0, 0)
        info.BackgroundTransparency = 1
        info.Text = item.Name .. "\n[" .. item.Rarity .. "]"
        info.TextColor3 = Color3.fromRGB(220, 255, 200)
        info.Font = Enum.Font.Arcade
        info.TextSize = 11
        info.TextXAlignment = Enum.TextXAlignment.Left
        info.Parent = card
        
        local stealBtn = Instance.new("TextButton")
        stealBtn.Size = UDim2.new(0, 70, 0, 28)
        stealBtn.Position = UDim2.new(1, -75, 0.2, 0)
        stealBtn.BackgroundColor3 = Color3.fromRGB(40, 140, 40)
        stealBtn.BorderColor3 = Color3.fromRGB(15, 60, 15)
        stealBtn.BorderSizePixel = 2
        stealBtn.Text = "STEAL"
        stealBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        stealBtn.Font = Enum.Font.Arcade
        stealBtn.TextSize = 12
        stealBtn.Parent = card
        
        stealBtn.MouseButton1Click:Connect(function()
            ExecuteStealProcess(item.Object, item.Name, item.Rarity)
        end)
    end
end

RefreshBtn.MouseButton1Click:Connect(RefreshEggPanel)

-- ========================================================
-- TAB 3: SPEED BOOST
-- ========================================================
local Tab3 = Menus[3]

local SpeedToggle = Instance.new("TextButton")
SpeedToggle.Size = UDim2.new(0.9, 0, 0, 40)
SpeedToggle.Position = UDim2.new(0.05, 0, 0.15, 0)
SpeedToggle.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
SpeedToggle.BorderColor3 = Color3.fromRGB(80, 20, 20)
SpeedToggle.BorderSizePixel = 2
SpeedToggle.Text = "SPEED BOOST: OFF"
SpeedToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedToggle.Font = Enum.Font.Arcade
SpeedToggle.TextSize = 15
SpeedToggle.Parent = Tab3

local SpeedInput = Instance.new("TextBox")
SpeedInput.Size = UDim2.new(0.9, 0, 0, 35)
SpeedInput.Position = UDim2.new(0.05, 0, 0.35, 0)
SpeedInput.BackgroundColor3 = Color3.fromRGB(20, 35, 15)
SpeedInput.BorderColor3 = Color3.fromRGB(10, 20, 8)
SpeedInput.BorderSizePixel = 2
SpeedInput.Text = "50"
SpeedInput.TextColor3 = Color3.fromRGB(255, 255, 100)
SpeedInput.Font = Enum.Font.Arcade
SpeedInput.TextSize = 16
SpeedInput.Parent = Tab3

SpeedToggle.MouseButton1Click:Connect(function()
    SpeedBoostActive = not SpeedBoostActive
    if SpeedBoostActive then
        SpeedToggle.Text = "SPEED BOOST: ON"
        SpeedToggle.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
        SpeedValue = tonumber(SpeedInput.Text) or 50
    else
        SpeedToggle.Text = "SPEED BOOST: OFF"
        SpeedToggle.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
        Humanoid.WalkSpeed = 16
    end
end)

RunService.RenderStepped:Connect(function()
    if SpeedBoostActive and Humanoid then
        Humanoid.WalkSpeed = tonumber(SpeedInput.Text) or SpeedValue
    end
end)

-- ========================================================
-- TAB 4: HISTORY EGG
-- ========================================================
local Tab4 = Menus[4]

local HistoryScroll = Instance.new("ScrollingFrame")
HistoryScroll.Size = UDim2.new(0.95, 0, 0.75, 0)
HistoryScroll.Position = UDim2.new(0.025, 0, 0.025, 0)
HistoryScroll.BackgroundColor3 = Color3.fromRGB(20, 35, 15)
HistoryScroll.BorderColor3 = Color3.fromRGB(10, 20, 8)
HistoryScroll.BorderSizePixel = 2
HistoryScroll.ScrollBarThickness = 6
HistoryScroll.Parent = Tab4

local HistoryLayout = Instance.new("UIListLayout")
HistoryLayout.Padding = UDim.new(0, 4)
HistoryLayout.Parent = HistoryScroll

local DeleteHistBtn = Instance.new("TextButton")
DeleteHistBtn.Size = UDim2.new(0.95, 0, 0.15, 0)
DeleteHistBtn.Position = UDim2.new(0.025, 0, 0.8, 0)
DeleteHistBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
DeleteHistBtn.BorderColor3 = Color3.fromRGB(100, 20, 20)
DeleteHistBtn.BorderSizePixel = 2
DeleteHistBtn.Text = "DELETE HISTORY"
DeleteHistBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DeleteHistBtn.Font = Enum.Font.Arcade
DeleteHistBtn.TextSize = 14
DeleteHistBtn.Parent = Tab4

local function RefreshHistoryUI()
    for _, child in ipairs(HistoryScroll:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    for _, entry in ipairs(HistoryLogs) do
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(0.98, 0, 0, 22)
        lbl.BackgroundColor3 = Color3.fromRGB(30, 55, 20)
        lbl.BorderSizePixel = 0
        lbl.Text = " " .. entry
        lbl.TextColor3 = Color3.fromRGB(200, 255, 180)
        lbl.Font = Enum.Font.Arcade
        lbl.TextSize = 11
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = HistoryScroll
    end
end

DeleteHistBtn.MouseButton1Click:Connect(function()
    HistoryLogs = {}
    RefreshHistoryUI()
end)

-- Auto Refresh History UI saat membuka Tab 4
MenuButtons[4].MouseButton1Click:Connect(RefreshHistoryUI)

-- ========================================================
-- TAB 5: DUEL PLAYER & NOTIFIKASI TELEGRAM
-- ========================================================
local Tab5 = Menus[5]

-- Telegram Config Inputs
local TokenBox = Instance.new("TextBox")
TokenBox.Size = UDim2.new(0.9, 0, 0, 30)
TokenBox.Position = UDim2.new(0.05, 0, 0.05, 0)
TokenBox.BackgroundColor3 = Color3.fromRGB(20, 35, 15)
TokenBox.Text = "BOT TOKEN TELEGRAM"
TokenBox.TextColor3 = Color3.fromRGB(180, 180, 180)
TokenBox.Font = Enum.Font.Arcade
TokenBox.TextSize = 11
TokenBox.Parent = Tab5

local ChatIdBox = Instance.new("TextBox")
ChatIdBox.Size = UDim2.new(0.9, 0, 0, 30)
ChatIdBox.Position = UDim2.new(0.05, 0, 0.17, 0)
ChatIdBox.BackgroundColor3 = Color3.fromRGB(20, 35, 15)
ChatIdBox.Text = "ID PENERIMA / CHAT ID"
ChatIdBox.TextColor3 = Color3.fromRGB(180, 180, 180)
ChatIdBox.Font = Enum.Font.Arcade
ChatIdBox.TextSize = 11
ChatIdBox.Parent = Tab5

local NotifToggle = Instance.new("TextButton")
NotifToggle.Size = UDim2.new(0.9, 0, 0, 32)
NotifToggle.Position = UDim2.new(0.05, 0, 0.29, 0)
NotifToggle.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
NotifToggle.Text = "NOTIFIKASI TELEGRAM: OFF"
NotifToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
NotifToggle.Font = Enum.Font.Arcade
NotifToggle.TextSize = 12
NotifToggle.Parent = Tab5

NotifToggle.MouseButton1Click:Connect(function()
    NotifActive = not NotifActive
    TelegramToken = TokenBox.Text
    TelegramChatID = ChatIdBox.Text
    if NotifActive then
        NotifToggle.Text = "NOTIFIKASI TELEGRAM: ON"
        NotifToggle.BackgroundColor3 = Color3.fromRGB(40, 150, 40)
    else
        NotifToggle.Text = "NOTIFIKASI TELEGRAM: OFF"
        NotifToggle.BackgroundColor3 = Color3.fromRGB(150, 40, 40)
    end
end)

-- Duel Player Section
local DuelScroll = Instance.new("ScrollingFrame")
DuelScroll.Size = UDim2.new(0.9, 0, 0.5, 0)
DuelScroll.Position = UDim2.new(0.05, 0, 0.45, 0)
DuelScroll.BackgroundColor3 = Color3.fromRGB(20, 35, 15)
DuelScroll.BorderSizePixel = 2
DuelScroll.Parent = Tab5

local DuelLayout = Instance.new("UIListLayout")
DuelLayout.Padding = UDim.new(0, 3)
DuelLayout.Parent = DuelScroll

local function RefreshDuelPlayers()
    for _, child in ipairs(DuelScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    for _, targetPlayer in ipairs(Players:GetPlayers()) do
        if targetPlayer ~= LocalPlayer then
            local card = Instance.new("Frame")
            card.Size = UDim2.new(0.98, 0, 0, 30)
            card.BackgroundColor3 = Color3.fromRGB(30, 55, 20)
            card.BorderSizePixel = 0
            card.Parent = DuelScroll

            local nameLbl = Instance.new("TextLabel")
            nameLbl.Size = UDim2.new(0.6, 0, 1, 0)
            nameLbl.Position = UDim2.new(0, 5, 0, 0)
            nameLbl.BackgroundTransparency = 1
            nameLbl.Text = targetPlayer.DisplayName
            nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            nameLbl.Font = Enum.Font.Arcade
            nameLbl.TextSize = 11
            nameLbl.TextXAlignment = Enum.TextXAlignment.Left
            nameLbl.Parent = card

            -- Cek apakah target membawa telur
            local targetChar = targetPlayer.Character
            local isCarryingEgg = targetChar and (targetChar:FindFirstChild("Egg") or targetChar:FindFirstChildWithClass("Tool"))

            local duelBtn = Instance.new("TextButton")
            duelBtn.Size = UDim2.new(0, 60, 0, 22)
            duelBtn.Position = UDim2.new(1, -65, 0.12, 0)
            duelBtn.BorderSizePixel = 0
            duelBtn.Font = Enum.Font.Arcade
            duelBtn.TextSize = 10
            duelBtn.Parent = card

            if isCarryingEgg then
                duelBtn.Text = "STEAL"
                duelBtn.BackgroundColor3 = Color3.fromRGB(40, 180, 40) -- Hijau
                duelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                duelBtn.Text = "NO EGG"
                duelBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40) -- Merah
                duelBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
            end

            -- Fitur Pukul Pentungan & Ambil Telur
            duelBtn.MouseButton1Click:Connect(function()
                if not isCarryingEgg or not targetChar or not targetChar:FindFirstChild("HumanoidRootPart") then return end

                -- Equip Pentungan Kayu
                local club = LocalPlayer.Backpack:FindFirstChild("Wooden Club") or LocalPlayer.Backpack:FindFirstChildWhichIsA("Tool")
                if club then Humanoid:EquipTool(club) end

                -- Teleport ke player & Pukul
                RootPart.CFrame = targetChar.HumanoidRootPart.CFrame * CFrame.new(0, 0, 2)
                task.wait(0.2)
                
                if club then club:Activate() end
                task.wait(0.5)

                -- Ambil Telur Jatuh
                local droppedEgg = Workspace:FindFirstChild("DroppedEgg") or Workspace:FindFirstChild("Egg")
                if droppedEgg then
                    ExecuteStealProcess(droppedEgg, "Stolen Egg", "Secret")
                end
            end)
        end
    end
end

MenuButtons[5].MouseButton1Click:Connect(RefreshDuelPlayers)
print("LIXX EGG Loaded Successfully!")
