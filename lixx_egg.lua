-- =================================================================
-- SCRIPT LIXX EGG - Roblox Executable (Minecraft UI Style)
-- Author: LIXX EGG Team
-- =================================================================

local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- State Global & Konfigurasi
local Config = {
    AutoSteal = false,
    WalkSpeed = 16,
    SpeedBoostActive = false,
    DuelPlayer = false,
    NotifyTelegram = false,
    BotToken = "",
    ChatID = "",
    EggHistory = {}
}

-- Urutan Rarity
local RarityPriority = {
    ["Divine"] = 3,
    ["Eternal"] = 2,
    ["Secret"] = 1
}

-- Target Teleport Coordinates (Dapat disesuaikan dengan koordinat aktual game)
local Pos_Forest = Vector3.new(0, 5, 0) 
local Pos_Base = Vector3.new(100, 5, 100)

-- Function Teleportasi
local function TeleportTo(position, speed)
    local char = LocalPlayer.Character
    if char and char:FindFirstChild("HumanoidRootPart") then
        if speed and speed > 0 then
            local distance = (char.HumanoidRootPart.Position - position).Magnitude
            local duration = distance / (speed * 5)
            local tween = TweenService:Create(char.HumanoidRootPart, TweenInfo.new(duration, Enum.EasingStyle.Linear), {CFrame = CFrame.new(position)})
            tween:Play()
            tween.Completed:Wait()
        else
            char.HumanoidRootPart.CFrame = CFrame.new(position)
        end
    end
end

-- Simpan History Egg
local function AddHistory(eggName, rarity)
    local entry = {
        name = eggName,
        rarity = rarity,
        time = os.date("%X")
    }
    table.insert(Config.EggHistory, entry)
end

-- Kirim Notifikasi Telegram
local function SendTelegramNotification(eggName, rarity, imgUrl)
    if not Config.NotifyTelegram or Config.BotToken == "" or Config.ChatID == "" then return end
    
    local url = "https://api.telegram.org/bot" .. Config.BotToken .. "/sendPhoto"
    local payload = {
        chat_id = Config.ChatID,
        photo = imgUrl or "https://via.placeholder.com/150",
        caption = "🎉 *LIXX EGG NOTIFICATION*\n\nPemain: " .. LocalPlayer.Name .. "\nMendapatkan Telur: *" .. eggName .. "*\nRarity: *" .. rarity .. "*",
        parse_mode = "Markdown"
    }
    
    local success, response = pcall(function()
        return request({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(payload)
        })
    end)
end

-- Algoritma Eksekusi Pengambilan Telur (Steal Sequence)
local function ExecuteStealSequence(eggObject, rarityName)
    if not eggObject then return end
    
    -- Lari mendekati telur
    if eggObject:IsA("BasePart") then
        TeleportTo(eggObject.Position, LocalPlayer.Character.Humanoid.WalkSpeed)
    elseif eggObject:FindFirstChild("TouchInterest") or eggObject:FindFirstChild("HumanoidRootPart") then
        local targetPos = eggObject:FindFirstChild("HumanoidRootPart") and eggObject.HumanoidRootPart.Position or eggObject.Position
        TeleportTo(targetPos, LocalPlayer.Character.Humanoid.WalkSpeed)
    end
    
    -- Ambil telur (Interact/Touch)
    firetouchinterest(LocalPlayer.Character.HumanoidRootPart, eggObject, 0)
    task.wait(0.1)
    firetouchinterest(LocalPlayer.Character.HumanoidRootPart, eggObject, 1)
    
    -- Teleportasi Cepat ke Forest
    TeleportTo(Pos_Forest, 500)
    task.wait(2) -- Berhenti 2 Detik di Forest
    
    -- Teleportasi Cepat ke Base
    TeleportTo(Pos_Base, 500)
    
    -- Catat History & Telegram
    AddHistory(eggObject.Name, rarityName or "Unknown")
    SendTelegramNotification(eggObject.Name, rarityName or "Unknown", "https://via.placeholder.com/150")
end

-- GUI MASTER (Minecraft Theme)
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LIXX_EGG_UI"
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ResetOnSpawn = false

-- Minecraft Palette Colors
local MC_Green = Color3.fromRGB(85, 139, 47)
local MC_DarkGreen = Color3.fromRGB(46, 92, 19)
local MC_Gray = Color3.fromRGB(60, 60, 60)
local MC_DarkGray = Color3.fromRGB(35, 35, 35)
local MC_Border = Color3.fromRGB(19, 19, 19)
local MC_White = Color3.fromRGB(255, 255, 255)

-- Main Frame UI
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 520, 0, 340)
MainFrame.Position = UDim2.new(0.5, -260, 0.5, -170)
MainFrame.BackgroundColor3 = MC_DarkGray
MainFrame.BorderColor3 = MC_Border
MainFrame.BorderSizePixel = 4
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

-- Header Title Bar
local HeaderFrame = Instance.new("Frame")
HeaderFrame.Size = UDim2.new(1, 0, 0, 35)
HeaderFrame.BackgroundColor3 = MC_Green
HeaderFrame.BorderColor3 = MC_Border
HeaderFrame.BorderSizePixel = 2
HeaderFrame.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, -40, 1, 0)
TitleLabel.Position = UDim2.new(0, 10, 0, 0)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "⛏️ LIXX EGG SCRIPT"
TitleLabel.TextColor3 = MC_White
TitleLabel.TextSize = 18
TitleLabel.Font = Enum.Font.Code
TitleLabel.TextXAlignment = Enum.TextXAlignment.Left
TitleLabel.Parent = HeaderFrame

-- Close Button (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 25, 0, 25)
CloseBtn.Position = UDim2.new(1, -30, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
CloseBtn.BorderColor3 = MC_Border
CloseBtn.BorderSizePixel = 2
CloseBtn.Text = "X"
CloseBtn.TextColor3 = MC_White
CloseBtn.Font = Enum.Font.Code
CloseBtn.TextSize = 16
CloseBtn.Parent = HeaderFrame

-- Floating Logo "L" Button (Toggle GUI)
local LogoBtn = Instance.new("TextButton")
LogoBtn.Name = "LogoL_Button"
LogoBtn.Size = UDim2.new(0, 45, 0, 45)
LogoBtn.Position = UDim2.new(0, 20, 0.5, -22)
LogoBtn.BackgroundColor3 = MC_Green
LogoBtn.BorderColor3 = MC_Border
LogoBtn.BorderSizePixel = 3
LogoBtn.Text = "L"
LogoBtn.TextColor3 = MC_White
LogoBtn.Font = Enum.Font.Code
LogoBtn.TextSize = 28
LogoBtn.Visible = false
LogoBtn.Parent = ScreenGui

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    LogoBtn.Visible = true
end)

LogoBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    LogoBtn.Visible = false
end)

-- Left Sidebar Navigation Menu (5 Menus)
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 130, 1, -45)
Sidebar.Position = UDim2.new(0, 5, 0, 40)
Sidebar.BackgroundColor3 = MC_Gray
Sidebar.BorderColor3 = MC_Border
Sidebar.BorderSizePixel = 2
Sidebar.Parent = MainFrame

local ContentFrame = Instance.new("Frame")
ContentFrame.Size = UDim2.new(1, -145, 1, -45)
ContentFrame.Position = UDim2.new(0, 140, 0, 40)
ContentFrame.BackgroundColor3 = MC_Gray
ContentFrame.BorderColor3 = MC_Border
ContentFrame.BorderSizePixel = 2
ContentFrame.Parent = MainFrame

-- Containers untuk 5 Menu Pages
local Pages = {}
local MenuNames = {"AUTO EGG", "HISTORY EGG", "DUEL PLAYER", "NOTIFIKASI", "SETTINGS"}

for i = 1, 5 do
    local page = Instance.new("ScrollingFrame")
    page.Size = UDim2.new(1, -10, 1, -10)
    page.Position = UDim2.new(0, 5, 0, 5)
    page.BackgroundTransparency = 1
    page.ScrollBarThickness = 6
    page.Visible = (i == 1)
    page.Parent = ContentFrame
    Pages[i] = page
end

local function SwitchTab(tabIndex)
    for i, page in ipairs(Pages) do
        page.Visible = (i == tabIndex)
    end
end

-- Create Menu Navigation Buttons
for i, name in ipairs(MenuNames) do
    local btn = Instance.new("TextButton")
    btn.Size = UDim2.new(1, -10, 0, 45)
    btn.Position = UDim2.new(0, 5, 0, 5 + (i - 1) * 50)
    btn.BackgroundColor3 = MC_DarkGreen
    btn.BorderColor3 = MC_Border
    btn.BorderSizePixel = 2
    btn.Text = name
    btn.TextColor3 = MC_White
    btn.Font = Enum.Font.Code
    btn.TextSize = 12
    btn.Parent = Sidebar
    
    btn.MouseButton1Click:Connect(function()
        SwitchTab(i)
    end)
end

-- =================================================================
-- MENU 1: AUTO EGG
-- =================================================================
local Page1 = Pages[1]

-- 1. Steal ON/OFF
local ToggleSteal = Instance.new("TextButton")
ToggleSteal.Size = UDim2.new(1, -10, 0, 35)
ToggleSteal.Position = UDim2.new(0, 5, 0, 5)
ToggleSteal.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
ToggleSteal.BorderColor3 = MC_Border
ToggleSteal.BorderSizePixel = 2
ToggleSteal.Text = "STEAL: OFF"
ToggleSteal.TextColor3 = MC_White
ToggleSteal.Font = Enum.Font.Code
ToggleSteal.Parent = Page1

ToggleSteal.MouseButton1Click:Connect(function()
    Config.AutoSteal = not Config.AutoSteal
    if Config.AutoSteal then
        ToggleSteal.BackgroundColor3 = MC_DarkGreen
        ToggleSteal.Text = "STEAL: ON"
    else
        ToggleSteal.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        ToggleSteal.Text = "STEAL: OFF"
    end
end)

-- Loop Utama Auto Steal berdasarkan Rarity Priority
task.spawn(function()
    while task.wait(0.5) do
        if Config.AutoSteal then
            -- Cari telur di Workspace
            local targetEgg = nil
            local highestPriority = 0
            local currentRarityName = ""
            
            for _, obj in ipairs(workspace:GetDescendants()) do
                if obj:IsA("Model") or obj:IsA("BasePart") then
                    for rarity, priority in pairs(RarityPriority) do
                        if string.find(obj.Name:lower(), rarity:lower()) then
                            if priority > highestPriority then
                                highestPriority = priority
                                targetEgg = obj
                                currentRarityName = rarity
                            end
                        end
                    end
                end
            end
            
            if targetEgg then
                ExecuteStealSequence(targetEgg, currentRarityName)
            end
        end
    end
end)

-- 2. Panel Window (Mini Egg Selector)
local PanelWindow = Instance.new("Frame")
PanelWindow.Size = UDim2.new(0, 320, 0, 220)
PanelWindow.Position = UDim2.new(0.5, -160, 0.5, -110)
PanelWindow.BackgroundColor3 = MC_DarkGray
PanelWindow.BorderColor3 = MC_Border
PanelWindow.BorderSizePixel = 3
PanelWindow.Visible = false
PanelWindow.Parent = ScreenGui

local PanelHeader = Instance.new("TextLabel")
PanelHeader.Size = UDim2.new(1, 0, 0, 25)
PanelHeader.BackgroundColor3 = MC_Green
PanelHeader.Text = " EGG PANEL "
PanelHeader.TextColor3 = MC_White
PanelHeader.Font = Enum.Font.Code
PanelHeader.Parent = PanelWindow

local PanelClose = Instance.new("TextButton")
PanelClose.Size = UDim2.new(0, 20, 0, 20)
PanelClose.Position = UDim2.new(1, -22, 0, 2)
PanelClose.Text = "X"
PanelClose.Parent = PanelHeader
PanelClose.MouseButton1Click:Connect(function() PanelWindow.Visible = false end)

local PanelScroll = Instance.new("ScrollingFrame")
PanelScroll.Size = UDim2.new(1, -10, 1, -35)
PanelScroll.Position = UDim2.new(0, 5, 0, 30)
PanelScroll.BackgroundTransparency = 1
PanelScroll.Parent = PanelWindow

local BtnOpenPanel = Instance.new("TextButton")
BtnOpenPanel.Size = UDim2.new(1, -10, 0, 35)
BtnOpenPanel.Position = UDim2.new(0, 5, 0, 45)
BtnOpenPanel.BackgroundColor3 = MC_DarkGreen
BtnOpenPanel.BorderColor3 = MC_Border
BtnOpenPanel.BorderSizePixel = 2
BtnOpenPanel.Text = "BUKA PANEL EGG"
BtnOpenPanel.TextColor3 = MC_White
BtnOpenPanel.Font = Enum.Font.Code
BtnOpenPanel.Parent = Page1

local function RefreshEggPanel()
    for _, child in ipairs(PanelScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local yOffset = 0
    for _, obj in ipairs(workspace:GetDescendants()) do
        if obj:IsA("Model") and (string.find(obj.Name:lower(), "egg") or string.find(obj.Name:lower(), "divine") or string.find(obj.Name:lower(), "eternal") or string.find(obj.Name:lower(), "secret")) then
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, -10, 0, 40)
            card.Position = UDim2.new(0, 0, 0, yOffset)
            card.BackgroundColor3 = MC_Gray
            card.BorderColor3 = MC_Border
            card.Parent = PanelScroll
            
            local img = Instance.new("ImageLabel")
            img.Size = UDim2.new(0, 30, 0, 30)
            img.Position = UDim2.new(0, 5, 0, 5)
            img.Image = "rbxassetid://6031075931"
            img.Parent = card
            
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 150, 1, 0)
            lbl.Position = UDim2.new(0, 40, 0, 0)
            lbl.Text = obj.Name
            lbl.TextColor3 = MC_White
            lbl.Font = Enum.Font.Code
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = card
            
            local btnSteal = Instance.new("TextButton")
            btnSteal.Size = UDim2.new(0, 60, 0, 25)
            btnSteal.Position = UDim2.new(1, -65, 0, 7)
            btnSteal.BackgroundColor3 = MC_DarkGreen
            btnSteal.Text = "STEAL"
            btnSteal.TextColor3 = MC_White
            btnSteal.Font = Enum.Font.Code
            btnSteal.Parent = card
            
            btnSteal.MouseButton1Click:Connect(function()
                ExecuteStealSequence(obj, "Manual Panel")
            end)
            
            yOffset = yOffset + 45
        end
    end
    PanelScroll.CanvasSize = UDim2.new(0, 0, 0, yOffset)
end

BtnOpenPanel.MouseButton1Click:Connect(function()
    RefreshEggPanel()
    PanelWindow.Visible = true
end)

-- 3. Speed Boost Setting
local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(1, -10, 0, 20)
SpeedLabel.Position = UDim2.new(0, 5, 0, 90)
SpeedLabel.Text = "SPEED BOOST VALUE:"
SpeedLabel.TextColor3 = MC_White
SpeedLabel.Font = Enum.Font.Code
SpeedLabel.Parent = Page1

local SpeedInput = Instance.new("TextBox")
SpeedInput.Size = UDim2.new(1, -10, 0, 30)
SpeedInput.Position = UDim2.new(0, 5, 0, 115)
SpeedInput.BackgroundColor3 = MC_DarkGray
SpeedInput.BorderColor3 = MC_Border
SpeedInput.Text = "50"
SpeedInput.TextColor3 = MC_White
SpeedInput.Font = Enum.Font.Code
SpeedInput.Parent = Page1

local ToggleSpeed = Instance.new("TextButton")
ToggleSpeed.Size = UDim2.new(1, -10, 0, 30)
ToggleSpeed.Position = UDim2.new(0, 5, 0, 150)
ToggleSpeed.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
ToggleSpeed.BorderColor3 = MC_Border
ToggleSpeed.Text = "SPEED: OFF"
ToggleSpeed.TextColor3 = MC_White
ToggleSpeed.Font = Enum.Font.Code
ToggleSpeed.Parent = Page1

ToggleSpeed.MouseButton1Click:Connect(function()
    Config.SpeedBoostActive = not Config.SpeedBoostActive
    if Config.SpeedBoostActive then
        ToggleSpeed.BackgroundColor3 = MC_DarkGreen
        ToggleSpeed.Text = "SPEED: ON"
        local val = tonumber(SpeedInput.Text) or 16
        LocalPlayer.Character.Humanoid.WalkSpeed = val
    else
        ToggleSpeed.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        ToggleSpeed.Text = "SPEED: OFF"
        LocalPlayer.Character.Humanoid.WalkSpeed = 16
    end
end)

-- =================================================================
-- MENU 2: HISTORY EGG
-- =================================================================
local Page2 = Pages[2]

local HistoryScroll = Instance.new("ScrollingFrame")
HistoryScroll.Size = UDim2.new(1, -10, 1, -45)
HistoryScroll.Position = UDim2.new(0, 5, 0, 5)
HistoryScroll.BackgroundTransparency = 1
HistoryScroll.Parent = Page2

local function RefreshHistoryUI()
    for _, child in ipairs(HistoryScroll:GetChildren()) do
        if child:IsA("TextLabel") then child:Destroy() end
    end
    
    local yOff = 0
    for _, item in ipairs(Config.EggHistory) do
        local lbl = Instance.new("TextLabel")
        lbl.Size = UDim2.new(1, 0, 0, 20)
        lbl.Position = UDim2.new(0, 0, 0, yOff)
        lbl.Text = "[" .. item.time .. "] " .. item.name .. " (" .. item.rarity .. ")"
        lbl.TextColor3 = MC_White
        lbl.Font = Enum.Font.Code
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Parent = HistoryScroll
        yOff = yOff + 22
    end
    HistoryScroll.CanvasSize = UDim2.new(0, 0, 0, yOff)
end

local BtnDeleteHistory = Instance.new("TextButton")
BtnDeleteHistory.Size = UDim2.new(1, -10, 0, 30)
BtnDeleteHistory.Position = UDim2.new(0, 5, 1, -35)
BtnDeleteHistory.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
BtnDeleteHistory.Text = "DELETE HISTORY"
BtnDeleteHistory.TextColor3 = MC_White
BtnDeleteHistory.Font = Enum.Font.Code
BtnDeleteHistory.Parent = Page2

BtnDeleteHistory.MouseButton1Click:Connect(function()
    Config.EggHistory = {}
    RefreshHistoryUI()
end)

Page2.GetPropertyChangedSignal("Visible"):Connect(function()
    if Page2.Visible then RefreshHistoryUI() end
end)

-- =================================================================
-- MENU 3: DUEL PLAYER
-- =================================================================
local Page3 = Pages[3]

local PlayerScroll = Instance.new("ScrollingFrame")
PlayerScroll.Size = UDim2.new(1, -10, 1, -10)
PlayerScroll.Position = UDim2.new(0, 5, 0, 5)
PlayerScroll.BackgroundTransparency = 1
PlayerScroll.Parent = Page3

local function RefreshPlayersUI()
    for _, child in ipairs(PlayerScroll:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
    
    local yOff = 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            local card = Instance.new("Frame")
            card.Size = UDim2.new(1, -10, 0, 35)
            card.Position = UDim2.new(0, 0, 0, yOff)
            card.BackgroundColor3 = MC_Gray
            card.BorderColor3 = MC_Border
            card.Parent = PlayerScroll
            
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(0, 120, 1, 0)
            lbl.Position = UDim2.new(0, 5, 0, 0)
            lbl.Text = plr.Name
            lbl.TextColor3 = MC_White
            lbl.Font = Enum.Font.Code
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = card
            
            -- Cek apakah player membawa telur
            local hasEgg = false
            if plr.Character and (plr.Character:FindFirstChild("Egg") or plr.Character:FindFirstChildWithClass("Tool")) then
                hasEgg = true
            end
            
            local btnStealPlr = Instance.new("TextButton")
            btnStealPlr.Size = UDim2.new(0, 70, 0, 25)
            btnStealPlr.Position = UDim2.new(1, -75, 0, 5)
            btnStealPlr.Font = Enum.Font.Code
            btnStealPlr.Text = "STEAL"
            
            if hasEgg then
                btnStealPlr.BackgroundColor3 = MC_DarkGreen
                btnStealPlr.TextColor3 = MC_White
            else
                btnStealPlr.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
                btnStealPlr.TextColor3 = Color3.fromRGB(200, 200, 200)
            end
            btnStealPlr.Parent = card
            
            btnStealPlr.MouseButton1Click:Connect(function()
                if hasEgg and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                    -- Teleport dan serang player
                    LocalPlayer.Character.HumanoidRootPart.CFrame = plr.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 2)
                    
                    -- Pukul menggunakan Pentungan/Tool
                    local weapon = LocalPlayer.Character:FindFirstChildOfClass("Tool") or LocalPlayer.Backpack:FindFirstChildOfClass("Tool")
                    if weapon then
                        weapon.Parent = LocalPlayer.Character
                        weapon:Activate()
                    end
                    
                    task.wait(1)
                    
                    -- Cari telur yang jatuh lalu bawa ke Forest & Base
                    local droppedEgg = workspace:FindFirstChild("Egg") or workspace:FindFirstChild("DroppedEgg")
                    if droppedEgg then
                        ExecuteStealSequence(droppedEgg, "Duel Steal")
                    end
                end
            end)
            
            yOff = yOff + 40
        end
    end
    PlayerScroll.CanvasSize = UDim2.new(0, 0, 0, yOff)
end

Page3.GetPropertyChangedSignal("Visible"):Connect(function()
    if Page3.Visible then RefreshPlayersUI() end
end)

-- =================================================================
-- MENU 4: NOTIFIKASI TELEGRAM
-- =================================================================
local Page4 = Pages[4]

local ToggleNotif = Instance.new("TextButton")
ToggleNotif.Size = UDim2.new(1, -10, 0, 30)
ToggleNotif.Position = UDim2.new(0, 5, 0, 5)
ToggleNotif.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
ToggleNotif.Text = "TELEGRAM NOTIF: OFF"
ToggleNotif.TextColor3 = MC_White
ToggleNotif.Font = Enum.Font.Code
ToggleNotif.Parent = Page4

ToggleNotif.MouseButton1Click:Connect(function()
    Config.NotifyTelegram = not Config.NotifyTelegram
    if Config.NotifyTelegram then
        ToggleNotif.BackgroundColor3 = MC_DarkGreen
        ToggleNotif.Text = "TELEGRAM NOTIF: ON"
    else
        ToggleNotif.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        ToggleNotif.Text = "TELEGRAM NOTIF: OFF"
    end
end)

local TokenLabel = Instance.new("TextLabel")
TokenLabel.Size = UDim2.new(1, -10, 0, 20)
TokenLabel.Position = UDim2.new(0, 5, 0, 45)
TokenLabel.Text = "BOT TOKEN:"
TokenLabel.TextColor3 = MC_White
TokenLabel.Font = Enum.Font.Code
TokenLabel.Parent = Page4

local TokenInput = Instance.new("TextBox")
TokenInput.Size = UDim2.new(1, -10, 0, 30)
TokenInput.Position = UDim2.new(0, 5, 0, 70)
TokenInput.BackgroundColor3 = MC_DarkGray
TokenInput.BorderColor3 = MC_Border
TokenInput.Text = Config.BotToken
TokenInput.TextColor3 = MC_White
TokenInput.Font = Enum.Font.Code
TokenInput.Parent = Page4
TokenInput.FocusLost:Connect(function() Config.BotToken = TokenInput.Text end)

local IDLabel = Instance.new("TextLabel")
IDLabel.Size = UDim2.new(1, -10, 0, 20)
IDLabel.Position = UDim2.new(0, 5, 0, 105)
IDLabel.Text = "CHAT ID / PENERIMA:"
IDLabel.TextColor3 = MC_White
IDLabel.Font = Enum.Font.Code
IDLabel.Parent = Page4

local IDInput = Instance.new("TextBox")
IDInput.Size = UDim2.new(1, -10, 0, 30)
IDInput.Position = UDim2.new(0, 5, 0, 130)
IDInput.BackgroundColor3 = MC_DarkGray
IDInput.BorderColor3 = MC_Border
IDInput.Text = Config.ChatID
IDInput.TextColor3 = MC_White
IDInput.Font = Enum.Font.Code
IDInput.Parent = Page4
IDInput.FocusLost:Connect(function() Config.ChatID = IDInput.Text end)

-- =================================================================
-- MENU 5: SETTINGS
-- =================================================================
local Page5 = Pages[5]

local InfoLabel = Instance.new("TextLabel")
InfoLabel.Size = UDim2.new(1, -10, 0, 100)
InfoLabel.Position = UDim2.new(0, 5, 0, 5)
InfoLabel.Text = "SCRIPT LIXX EGG\n\nVersion: 1.0 (Minecraft Style)\nCreated for Executor Delta & Mobile/PC"
InfoLabel.TextColor3 = MC_White
InfoLabel.Font = Enum.Font.Code
InfoLabel.Parent = Page5

print("LIXX EGG Script Loaded Successfully!")
