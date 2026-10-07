--[[
    LIXX EGG - Roblox Script
    Game: Steal an Egg
    UI Theme: Minecraft Green Pixel Style
--]]

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local requestFunc = (syn and syn.request) or (http and http.request) or http_request or request

---------------------------------------------------------
-- CONFIGURATIONS & STATE
---------------------------------------------------------
local Config = {
    AutoSteal = false,
    SpeedBoost = false,
    SpeedValue = 32,
    DuelPlayer = false,
    TelegramNotif = false,
    BotToken = "",
    ChatID = ""
}

local HistoryLogs = {}

---------------------------------------------------------
-- HELPER FUNCTIONS (MAP & POSITIONS)
---------------------------------------------------------
local function getForestPosition()
    local forestZone = Workspace:FindFirstChild("Forest", true) or Workspace:FindFirstChild("ForestZone", true)
    if forestZone then
        return forestZone:GetPivot().Position + Vector3.new(0, 5, 0)
    end
    return Vector3.new(0, 50, 0)
end

local function getBasePosition()
    local bases = Workspace:FindFirstChild("Bases") or Workspace:FindFirstChild("Plots")
    if bases then
        for _, base in pairs(bases:GetChildren()) do
            if base.Name:lower():find(LocalPlayer.Name:lower()) or (base:FindFirstChild("Owner") and base.Owner.Value == LocalPlayer) then
                return base:GetPivot().Position + Vector3.new(0, 5, 0)
            end
        end
    end
    return LocalPlayer.Character and LocalPlayer.Character:GetPivot().Position or Vector3.new(0, 10, 0)
end

local function sendTelegramNotif(eggName)
    if not Config.TelegramNotif or Config.BotToken == "" or Config.ChatID == "" then return end
    if not requestFunc then return end

    local textMsg = "🥚 *LIXX EGG NOTIFICATION*\n" ..
                    "👤 Player: " .. LocalPlayer.Name .. "\n" ..
                    "🎉 Berhasil mengambil telur: *" .. tostring(eggName) .. "*\n" ..
                    "⏰ Waktu: " .. os.date("%H:%M:%S")

    pcall(function()
        requestFunc({
            Url = "https://api.telegram.org/bot" .. Config.BotToken .. "/sendMessage",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode({
                chat_id = Config.ChatID,
                text = textMsg,
                parse_mode = "Markdown"
            })
        })
    end)
end

local function executeStealProcess(eggObject)
    if not eggObject or not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    
    local hrp = LocalPlayer.Character.HumanoidRootPart
    local targetPos = eggObject:GetPivot().Position

    -- 1. Lari / Teleport cepat ke telur
    hrp.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
    task.wait(0.15)

    -- 2. Ambil telur instan
    local prompt = eggObject:FindFirstChildOfClass("ProximityPrompt", true)
    if prompt then
        fireproximityprompt(prompt)
    end
    task.wait(0.2)

    -- 3. Teleport ke Forest & berhenti 2 detik
    hrp.CFrame = CFrame.new(getForestPosition())
    task.wait(2)

    -- 4. Teleport ke Base
    hrp.CFrame = CFrame.new(getBasePosition())

    -- Catat History & Kirim Notif Telegram
    local eggName = eggObject.Name
    table.insert(HistoryLogs, {Name = eggName, Time = os.date("%H:%M:%S")})
    sendTelegramNotif(eggName)
end

---------------------------------------------------------
-- SPEED BOOST LOOP
---------------------------------------------------------
RunService.Stepped:Connect(function()
    if Config.SpeedBoost and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = tonumber(Config.SpeedValue) or 16
    end
end)

---------------------------------------------------------
-- UI CREATION (MINECRAFT GREEN STYLE)
---------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LixxEggGui"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")

-- Floating Logo Button 'L'
local FloatingL = Instance.new("TextButton")
FloatingL.Name = "FloatingL"
FloatingL.Size = UDim2.new(0, 45, 0, 45)
FloatingL.Position = UDim2.new(0, 15, 0.4, 0)
FloatingL.BackgroundColor3 = Color3.fromRGB(56, 142, 60)
FloatingL.BorderColor3 = Color3.fromRGB(20, 80, 20)
FloatingL.BorderSizePixel = 3
FloatingL.Text = "L"
FloatingL.TextColor3 = Color3.fromRGB(255, 255, 255)
FloatingL.TextSize = 24
FloatingL.Font = Enum.Font.Code
FloatingL.Active = true
FloatingL.Draggable = true
FloatingL.Parent = ScreenGui

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 520, 0, 340)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -170)
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 35, 30)
MainFrame.BorderColor3 = Color3.fromRGB(76, 175, 80)
MainFrame.BorderSizePixel = 4
MainFrame.Visible = true
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- Header Title
local Header = Instance.new("Frame")
Header.Size = UDim2.new(1, 0, 0, 35)
Header.BackgroundColor3 = Color3.fromRGB(56, 142, 60)
Header.BorderSizePixel = 0
Header.Parent = MainFrame

local TitleText = Instance.new("TextLabel")
TitleText.Size = UDim2.new(1, -40, 1, 0)
TitleText.Position = UDim2.new(0, 10, 0, 0)
TitleText.BackgroundTransparency = 1
TitleText.Text = "🟩 LIXX EGG HUB [MINECRAFT EDITION]"
TitleText.TextColor3 = Color3.fromRGB(255, 255, 255)
TitleText.TextSize = 15
TitleText.Font = Enum.Font.Code
TitleText.TextXAlignment = Enum.TextXAlignment.Left
TitleText.Parent = Header

-- Close Button 'X'
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -32, 0, 2)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.BorderColor3 = Color3.fromRGB(100, 0, 0)
CloseBtn.BorderSizePixel = 2
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.Font = Enum.Font.Code
CloseBtn.TextSize = 18
CloseBtn.Parent = Header

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

FloatingL.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Sidebar Container
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(0, 130, 1, -35)
TabContainer.Position = UDim2.new(0, 0, 0, 35)
TabContainer.BackgroundColor3 = Color3.fromRGB(20, 25, 20)
TabContainer.BorderSizePixel = 0
TabContainer.Parent = MainFrame

-- Content Frame
local ContentContainer = Instance.new("Frame")
ContentContainer.Size = UDim2.new(1, -135, 1, -40)
ContentContainer.Position = UDim2.new(0, 132, 0, 38)
ContentContainer.BackgroundTransparency = 1
ContentContainer.Parent = MainFrame

local MenuFrames = {}
local MenuButtons = {}

local MenuNames = {
    "1. AUTO EGG",
    "2. HISTORY EGG",
    "3. DUEL PLAYER",
    "4. NOTIFIKASI",
    "5. SETTINGS"
}

for i, name in ipairs(MenuNames) do
    local tabBtn = Instance.new("TextButton")
    tabBtn.Size = UDim2.new(1, -10, 0, 45)
    tabBtn.Position = UDim2.new(0, 5, 0, (i - 1) * 50 + 5)
    tabBtn.BackgroundColor3 = (i == 1) and Color3.fromRGB(56, 142, 60) or Color3.fromRGB(40, 45, 40)
    tabBtn.BorderColor3 = Color3.fromRGB(80, 80, 80)
    tabBtn.BorderSizePixel = 2
    tabBtn.Text = name
    tabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabBtn.Font = Enum.Font.Code
    tabBtn.TextSize = 12
    tabBtn.Parent = TabContainer
    MenuButtons[i] = tabBtn

    local pageFrame = Instance.new("ScrollingFrame")
    pageFrame.Size = UDim2.new(1, 0, 1, 0)
    pageFrame.BackgroundTransparency = 1
    pageFrame.ScrollBarThickness = 6
    pageFrame.Visible = (i == 1)
    pageFrame.Parent = ContentContainer
    MenuFrames[i] = pageFrame

    tabBtn.MouseButton1Click:Connect(function()
        for idx, frame in ipairs(MenuFrames) do
            frame.Visible = (idx == i)
            MenuButtons[idx].BackgroundColor3 = (idx == i) and Color3.fromRGB(56, 142, 60) or Color3.fromRGB(40, 45, 40)
        end
    end)
end

---------------------------------------------------------
-- MENU 1: AUTO EGG
---------------------------------------------------------
local autoEggFrame = MenuFrames[1]

-- Auto Steal Button
local StealToggle = Instance.new("TextButton")
StealToggle.Size = UDim2.new(1, -20, 0, 35)
StealToggle.Position = UDim2.new(0, 10, 0, 10)
StealToggle.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
StealToggle.Text = "STEAL AUTO: OFF"
StealToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
StealToggle.Font = Enum.Font.Code
StealToggle.BorderSizePixel = 2
StealToggle.Parent = autoEggFrame

StealToggle.MouseButton1Click:Connect(function()
    Config.AutoSteal = not Config.AutoSteal
    StealToggle.BackgroundColor3 = Config.AutoSteal and Color3.fromRGB(56, 142, 60) or Color3.fromRGB(150, 50, 50)
    StealToggle.Text = Config.AutoSteal and "STEAL AUTO: ON" or "STEAL AUTO: OFF"
end)

-- Open Panel Button
local OpenPanelBtn = Instance.new("TextButton")
OpenPanelBtn.Size = UDim2.new(1, -20, 0, 35)
OpenPanelBtn.Position = UDim2.new(0, 10, 0, 55)
OpenPanelBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
OpenPanelBtn.Text = "📋 BUKA PANEL TELUR"
OpenPanelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenPanelBtn.Font = Enum.Font.Code
OpenPanelBtn.BorderSizePixel = 2
OpenPanelBtn.Parent = autoEggFrame

-- Speed Boost Controls
local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(1, -20, 0, 20)
SpeedLabel.Position = UDim2.new(0, 10, 0, 100)
SpeedLabel.BackgroundTransparency = 1
SpeedLabel.Text = "⚡ Speed Boost Player:"
SpeedLabel.TextColor3 = Color3.fromRGB(85, 255, 85)
SpeedLabel.Font = Enum.Font.Code
SpeedLabel.TextXAlignment = Enum.TextXAlignment.Left
SpeedLabel.Parent = autoEggFrame

local SpeedInput = Instance.new("TextBox")
SpeedInput.Size = UDim2.new(0.5, -15, 0, 30)
SpeedInput.Position = UDim2.new(0, 10, 0, 125)
SpeedInput.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
SpeedInput.Text = "50"
SpeedInput.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedInput.Font = Enum.Font.Code
SpeedInput.BorderSizePixel = 2
SpeedInput.Parent = autoEggFrame

SpeedInput.FocusLost:Connect(function()
    Config.SpeedValue = tonumber(SpeedInput.Text) or 16
end)

local SpeedToggle = Instance.new("TextButton")
SpeedToggle.Size = UDim2.new(0.5, -15, 0, 30)
SpeedToggle.Position = UDim2.new(0.5, 5, 0, 125)
SpeedToggle.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
SpeedToggle.Text = "SPEED: OFF"
SpeedToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedToggle.Font = Enum.Font.Code
SpeedToggle.BorderSizePixel = 2
SpeedToggle.Parent = autoEggFrame

SpeedToggle.MouseButton1Click:Connect(function()
    Config.SpeedBoost = not Config.SpeedBoost
    SpeedToggle.BackgroundColor3 = Config.SpeedBoost and Color3.fromRGB(56, 142, 60) or Color3.fromRGB(150, 50, 50)
    SpeedToggle.Text = Config.SpeedBoost and "SPEED: ON" or "SPEED: OFF"
end)

---------------------------------------------------------
-- EGG PANEL UI (MANUAL SELECTION)
---------------------------------------------------------
local PanelUI = Instance.new("Frame")
PanelUI.Name = "EggPanelUI"
PanelUI.Size = UDim2.new(0, 320, 0, 380)
PanelUI.Position = UDim2.new(0.5, 270, 0.5, -190)
PanelUI.BackgroundColor3 = Color3.fromRGB(25, 30, 25)
PanelUI.BorderColor3 = Color3.fromRGB(56, 142, 60)
PanelUI.BorderSizePixel = 3
PanelUI.Visible = false
PanelUI.Active = true
PanelUI.Draggable = true
PanelUI.Parent = ScreenGui

local PanelHeader = Instance.new("Frame")
PanelHeader.Size = UDim2.new(1, 0, 0, 30)
PanelHeader.BackgroundColor3 = Color3.fromRGB(56, 142, 60)
PanelHeader.BorderSizePixel = 0
PanelHeader.Parent = PanelUI

local PanelTitle = Instance.new("TextLabel")
PanelTitle.Size = UDim2.new(1, -35, 1, 0)
PanelTitle.Position = UDim2.new(0, 8, 0, 0)
PanelTitle.BackgroundTransparency = 1
PanelTitle.Text = "🥚 PANEL DAFTAR TELUR"
PanelTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
PanelTitle.Font = Enum.Font.Code
PanelTitle.TextXAlignment = Enum.TextXAlignment.Left
PanelTitle.Parent = PanelHeader

local PanelClose = Instance.new("TextButton")
PanelClose.Size = UDim2.new(0, 26, 0, 26)
PanelClose.Position = UDim2.new(1, -28, 0, 2)
PanelClose.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
PanelClose.Text = "X"
PanelClose.TextColor3 = Color3.fromRGB(255, 255, 255)
PanelClose.Font = Enum.Font.Code
PanelClose.Parent = PanelHeader

PanelClose.MouseButton1Click:Connect(function()
    PanelUI.Visible = false
end)

OpenPanelBtn.MouseButton1Click:Connect(function()
    PanelUI.Visible = not PanelUI.Visible
end)

local PanelScroll = Instance.new("ScrollingFrame")
PanelScroll.Size = UDim2.new(1, -10, 1, -40)
PanelScroll.Position = UDim2.new(0, 5, 0, 35)
PanelScroll.BackgroundTransparency = 1
PanelScroll.ScrollBarThickness = 6
PanelScroll.Parent = PanelUI

local function refreshEggPanel()
    for _, child in pairs(PanelScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local eggFolder = Workspace:FindFirstChild("Eggs") or Workspace:FindFirstChild("SpawningEggs") or Workspace
    local detectedEggs = {}

    for _, obj in pairs(eggFolder:GetDescendants()) do
        if obj:IsA("Model") and (obj:FindFirstChild("Rarity") or obj:FindFirstChildOfClass("ProximityPrompt")) then
            local rarityVal = obj:FindFirstChild("Rarity") and obj.Rarity.Value or "Common"
            table.insert(detectedEggs, {Object = obj, Name = obj.Name, Rarity = rarityVal})
        end
    end

    -- Sorting berdasarkan Rarity (Divine > Eternal > Secret > Lainnya)
    table.sort(detectedEggs, function(a, b)
        local priorityMap = {Divine = 1, Eternal = 2, Secret = 3}
        local rankA = priorityMap[a.Rarity] or 99
        local rankB = priorityMap[b.Rarity] or 99
        return rankA < rankB
    end)

    local yOffset = 0
    for _, eggData in ipairs(detectedEggs) do
        local card = Instance.new("Frame")
        card.Size = UDim2.new(1, -10, 0, 50)
        card.Position = UDim2.new(0, 0, 0, yOffset)
        card.BackgroundColor3 = Color3.fromRGB(35, 40, 35)
        card.BorderColor3 = Color3.fromRGB(60, 60, 60)
        card.BorderSizePixel = 1
        card.Parent = PanelScroll

        local nameLabel = Instance.new("TextLabel")
        nameLabel.Size = UDim2.new(0.6, 0, 0.5, 0)
        nameLabel.Position = UDim2.new(0, 5, 0, 2)
        nameLabel.BackgroundTransparency = 1
        nameLabel.Text = eggData.Name
        nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
        nameLabel.Font = Enum.Font.Code
        nameLabel.TextXAlignment = Enum.TextXAlignment.Left
        nameLabel.Parent = card

        local rarityLabel = Instance.new("TextLabel")
        rarityLabel.Size = UDim2.new(0.6, 0, 0.5, 0)
        rarityLabel.Position = UDim2.new(0, 5, 0.5, 0)
        rarityLabel.BackgroundTransparency = 1
        rarityLabel.Text = "Rarity: " .. tostring(eggData.Rarity)
        rarityLabel.TextColor3 = Color3.fromRGB(85, 255, 85)
        rarityLabel.Font = Enum.Font.Code
        rarityLabel.TextXAlignment = Enum.TextXAlignment.Left
        rarityLabel.Parent = card

        local stealSingleBtn = Instance.new("TextButton")
        stealSingleBtn.Size = UDim2.new(0.35, -5, 0.8, 0)
        stealSingleBtn.Position = UDim2.new(0.65, 0, 0.1, 0)
        stealSingleBtn.BackgroundColor3 = Color3.fromRGB(56, 142, 60)
        stealSingleBtn.Text = "STEAL"
        stealSingleBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        stealSingleBtn.Font = Enum.Font.Code
        stealSingleBtn.BorderSizePixel = 2
        stealSingleBtn.Parent = card

        stealSingleBtn.MouseButton1Click:Connect(function()
            task.spawn(function()
                executeStealProcess(eggData.Object)
            end)
        end)

        yOffset = yOffset + 55
    end
    PanelScroll.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

task.spawn(function()
    while task.wait(4) do
        if PanelUI.Visible then
            refreshEggPanel()
        end
    end
end)

---------------------------------------------------------
-- MENU 2: HISTORY EGG
---------------------------------------------------------
local historyFrame = MenuFrames[2]

local ClearHistBtn = Instance.new("TextButton")
ClearHistBtn.Size = UDim2.new(1, -20, 0, 30)
ClearHistBtn.Position = UDim2.new(0, 10, 0, 10)
ClearHistBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
ClearHistBtn.Text = "🗑️ DELETED / CLEAR HISTORY"
ClearHistBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ClearHistBtn.Font = Enum.Font.Code
ClearHistBtn.BorderSizePixel = 2
ClearHistBtn.Parent = historyFrame

local HistoryScroll = Instance.new("ScrollingFrame")
HistoryScroll.Size = UDim2.new(1, -20, 1, -50)
HistoryScroll.Position = UDim2.new(0, 10, 0, 45)
HistoryScroll.BackgroundTransparency = 1
HistoryScroll.ScrollBarThickness = 6
HistoryScroll.Parent = historyFrame

local function updateHistoryUI()
    for _, child in pairs(HistoryScroll:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    local yPos = 0
    for _, log in ipairs(HistoryLogs) do
        local item = Instance.new("TextLabel")
        item.Size = UDim2.new(1, 0, 0, 25)
        item.Position = UDim2.new(0, 0, 0, yPos)
        item.BackgroundColor3 = Color3.fromRGB(30, 35, 30)
        item.Text = " [" .. log.Time .. "] Got: " .. log.Name
        item.TextColor3 = Color3.fromRGB(200, 255, 200)
        item.Font = Enum.Font.Code
        item.TextXAlignment = Enum.TextXAlignment.Left
        item.Parent = HistoryScroll
        yPos = yPos + 28
    end
    HistoryScroll.CanvasSize = UDim2.new(0, 0, 0, yPos)
end

ClearHistBtn.MouseButton1Click:Connect(function()
    HistoryLogs = {}
    updateHistoryUI()
end)

---------------------------------------------------------
-- MENU 3: DUEL PLAYER
---------------------------------------------------------
local duelFrame = MenuFrames[3]

local DuelToggle = Instance.new("TextButton")
DuelToggle.Size = UDim2.new(1, -20, 0, 35)
DuelToggle.Position = UDim2.new(0, 10, 0, 10)
DuelToggle.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
DuelToggle.Text = "DUEL PLAYER: OFF"
DuelToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
DuelToggle.Font = Enum.Font.Code
DuelToggle.BorderSizePixel = 2
DuelToggle.Parent = duelFrame

DuelToggle.MouseButton1Click:Connect(function()
    Config.DuelPlayer = not Config.DuelPlayer
    DuelToggle.BackgroundColor3 = Config.DuelPlayer and Color3.fromRGB(56, 142, 60) or Color3.fromRGB(150, 50, 50)
    DuelToggle.Text = Config.DuelPlayer and "DUEL PLAYER: ON" or "DUEL PLAYER: OFF"
end)

local PlayerScroll = Instance.new("ScrollingFrame")
PlayerScroll.Size = UDim2.new(1, -20, 1, -55)
PlayerScroll.Position = UDim2.new(0, 10, 0, 50)
PlayerScroll.BackgroundTransparency = 1
PlayerScroll.ScrollBarThickness = 6
PlayerScroll.Parent = duelFrame

local function updatePlayerListUI()
    for _, child in pairs(PlayerScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end

    local yPos = 0
    for _, targetPlayer in pairs(Players:GetPlayers()) do
        if targetPlayer ~= LocalPlayer then
            local pCard = Instance.new("Frame")
            pCard.Size = UDim2.new(1, 0, 0, 40)
            pCard.Position = UDim2.new(0, 0, 0, yPos)
            pCard.BackgroundColor3 = Color3.fromRGB(35, 40, 35)
            pCard.Parent = PlayerScroll

            local pName = Instance.new("TextLabel")
            pName.Size = UDim2.new(0.6, 0, 1, 0)
            pName.Position = UDim2.new(0, 5, 0, 0)
            pName.BackgroundTransparency = 1
            pName.Text = targetPlayer.DisplayName .. " (@" .. targetPlayer.Name .. ")"
            pName.TextColor3 = Color3.fromRGB(255, 255, 255)
            pName.Font = Enum.Font.Code
            pName.TextXAlignment = Enum.TextXAlignment.Left
            pName.Parent = pCard

            local char = targetPlayer.Character
            local isCarryingEgg = char and (char:FindFirstChild("CarriedEgg") or char:FindFirstChildOfClass("Tool"))

            local pStealBtn = Instance.new("TextButton")
            pStealBtn.Size = UDim2.new(0.35, -5, 0.7, 0)
            pStealBtn.Position = UDim2.new(0.65, 0, 0.15, 0)
            pStealBtn.Font = Enum.Font.Code
            pStealBtn.BorderSizePixel = 2
            pStealBtn.Parent = pCard

            if isCarryingEgg then
                pStealBtn.BackgroundColor3 = Color3.fromRGB(56, 142, 60)
                pStealBtn.Text = "STEAL"
                pStealBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
                pStealBtn.Active = true
            else
                pStealBtn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
                pStealBtn.Text = "NO EGG"
                pStealBtn.TextColor3 = Color3.fromRGB(180, 180, 180)
                pStealBtn.Active = false
            end

            pStealBtn.MouseButton1Click:Connect(function()
                if not isCarryingEgg or not LocalPlayer.Character then return end
                task.spawn(function()
                    local myHrp = LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                    local targetHrp = char and char:FindFirstChild("HumanoidRootPart")
                    if myHrp and targetHrp then
                        myHrp.CFrame = targetHrp.CFrame * CFrame.new(0, 0, 2)
                        
                        local tool = LocalPlayer.Backpack:FindFirstChildOfClass("Tool") or LocalPlayer.Character:FindFirstChildOfClass("Tool")
                        if tool then
                            tool.Parent = LocalPlayer.Character
                            tool:Activate()
                        end
                        task.wait(0.5)

                        local droppedEgg = Workspace:FindFirstChild("DroppedEgg") or Workspace:FindFirstChildOfClass("Model")
                        executeStealProcess(droppedEgg)
                    end
                end)
            end)

            yPos = yPos + 45
        end
    end
    PlayerScroll.CanvasSize = UDim2.new(0, 0, 0, yPos)
end

task.spawn(function()
    while task.wait(3) do
        if duelFrame.Visible then
            updatePlayerListUI()
        end
    end
end)

---------------------------------------------------------
-- MENU 4: NOTIFIKASI TELEGRAM
---------------------------------------------------------
local notifFrame = MenuFrames[4]

local NotifToggle = Instance.new("TextButton")
NotifToggle.Size = UDim2.new(1, -20, 0, 35)
NotifToggle.Position = UDim2.new(0, 10, 0, 10)
NotifToggle.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
NotifToggle.Text = "NOTIFIKASI TELEGRAM: OFF"
NotifToggle.TextColor3 = Color3.fromRGB(255, 255, 255)
NotifToggle.Font = Enum.Font.Code
NotifToggle.BorderSizePixel = 2
NotifToggle.Parent = notifFrame

NotifToggle.MouseButton1Click:Connect(function()
    Config.TelegramNotif = not Config.TelegramNotif
    NotifToggle.BackgroundColor3 = Config.TelegramNotif and Color3.fromRGB(56, 142, 60) or Color3.fromRGB(150, 50, 50)
    NotifToggle.Text = Config.TelegramNotif and "NOTIFIKASI TELEGRAM: ON" or "NOTIFIKASI TELEGRAM: OFF"
end)

local TokenLabel = Instance.new("TextLabel")
TokenLabel.Size = UDim2.new(1, -20, 0, 20)
TokenLabel.Position = UDim2.new(0, 10, 0, 55)
TokenLabel.BackgroundTransparency = 1
TokenLabel.Text = "🤖 Bot Token Telegram:"
TokenLabel.TextColor3 = Color3.fromRGB(85, 255, 85)
TokenLabel.Font = Enum.Font.Code
TokenLabel.TextXAlignment = Enum.TextXAlignment.Left
TokenLabel.Parent = notifFrame

local TokenInput = Instance.new("TextBox")
TokenInput.Size = UDim2.new(1, -20, 0, 30)
TokenInput.Position = UDim2.new(0, 10, 0, 80)
TokenInput.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
TokenInput.Text = Config.BotToken
TokenInput.PlaceholderText = "Isi Bot Token..."
TokenInput.TextColor3 = Color3.fromRGB(255, 255, 255)
TokenInput.Font = Enum.Font.Code
TokenInput.BorderSizePixel = 2
TokenInput.Parent = notifFrame

TokenInput.FocusLost:Connect(function()
    Config.BotToken = TokenInput.Text
end)

local ChatIDLabel = Instance.new("TextLabel")
ChatIDLabel.Size = UDim2.new(1, -20, 0, 20)
ChatIDLabel.Position = UDim2.new(0, 10, 0, 120)
ChatIDLabel.BackgroundTransparency = 1
ChatIDLabel.Text = "🆔 Chat ID Penerima:"
ChatIDLabel.TextColor3 = Color3.fromRGB(85, 255, 85)
ChatIDLabel.Font = Enum.Font.Code
ChatIDLabel.TextXAlignment = Enum.TextXAlignment.Left
ChatIDLabel.Parent = notifFrame

local ChatIDInput = Instance.new("TextBox")
ChatIDInput.Size = UDim2.new(1, -20, 0, 30)
ChatIDInput.Position = UDim2.new(0, 10, 0, 145)
ChatIDInput.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
ChatIDInput.Text = Config.ChatID
ChatIDInput.PlaceholderText = "Isi Chat ID..."
ChatIDInput.TextColor3 = Color3.fromRGB(255, 255, 255)
ChatIDInput.Font = Enum.Font.Code
ChatIDInput.BorderSizePixel = 2
ChatIDInput.Parent = notifFrame

ChatIDInput.FocusLost:Connect(function()
    Config.ChatID = ChatIDInput.Text
end)

---------------------------------------------------------
-- MENU 5: SETTINGS
---------------------------------------------------------
local settingsFrame = MenuFrames[5]

local RejoinBtn = Instance.new("TextButton")
RejoinBtn.Size = UDim2.new(1, -20, 0, 35)
RejoinBtn.Position = UDim2.new(0, 10, 0, 10)
RejoinBtn.BackgroundColor3 = Color3.fromRGB(70, 130, 180)
RejoinBtn.Text = "🔄 REJOIN / REFRESH SERVER"
RejoinBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
RejoinBtn.Font = Enum.Font.Code
RejoinBtn.BorderSizePixel = 2
RejoinBtn.Parent = settingsFrame

RejoinBtn.MouseButton1Click:Connect(function()
    game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
end)

---------------------------------------------------------
-- MAIN AUTO STEAL LOOP (PRIORITY SYSTEM: DIVINE > ETERNAL > SECRET)
---------------------------------------------------------
task.spawn(function()
    while task.wait(1) do
        if Config.AutoSteal then
            local eggFolder = Workspace:FindFirstChild("Eggs") or Workspace:FindFirstChild("SpawningEggs") or Workspace
            local targetEgg = nil

            -- 1. Prioritas Divine
            for _, obj in pairs(eggFolder:GetDescendants()) do
                if obj:IsA("Model") and obj:FindFirstChild("Rarity") and obj.Rarity.Value == "Divine" then
                    targetEgg = obj
                    break
                end
            end

            -- 2. Jika Divine tidak ada, cari Eternal
            if not targetEgg then
                for _, obj in pairs(eggFolder:GetDescendants()) do
                    if obj:IsA("Model") and obj:FindFirstChild("Rarity") and obj.Rarity.Value == "Eternal" then
                        targetEgg = obj
                        break
                    end
                end
            end

            -- 3. Jika Eternal tidak ada, cari Secret
            if not targetEgg then
                for _, obj in pairs(eggFolder:GetDescendants()) do
                    if obj:IsA("Model") and obj:FindFirstChild("Rarity") and obj.Rarity.Value == "Secret" then
                        targetEgg = obj
                        break
                    end
                end
            end

            -- Eksekusi pencurian jika telur ditemukan
            if targetEgg then
                executeStealProcess(targetEgg)
                updateHistoryUI()
            end
        end
    end
end)
