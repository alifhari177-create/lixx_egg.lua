--================================================================================--
--                         LIXX EGG SCRIPT - ROBLOX ENGINE                        --
--================================================================================--

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

------------------------------------------------------------------------------------
-- CONFIGURATION & STATE MANAGEMENT
------------------------------------------------------------------------------------
local Config = {
    AutoStealEnabled = false,
    SpeedBoostEnabled = false,
    SpeedValue = 50,
    DuelTarget = nil,
    TelegramEnabled = false,
    BotToken = "",
    ChatID = "",
    EggHistory = {}
}

local RarityPriority = {
    ["Divine"] = 3,
    ["Eternal"] = 2,
    ["Secret"] = 1
}

------------------------------------------------------------------------------------
-- NOTIFICATION & TELEGRAM UTILITIES
------------------------------------------------------------------------------------
local function SendTelegramNotification(eggName, rarity)
    if not Config.TelegramEnabled or Config.BotToken == "" or Config.ChatID == "" then return end
    
    local url = "https://api.telegram.org/bot" .. Config.BotToken .. "/sendMessage"
    local payload = {
        chat_id = Config.ChatID,
        text = "🎉 [LIXX EGG] Berhasil Mengambil Telur!\n\nNama Telur: " .. eggName .. "\nRarity: " .. rarity .. "\nPlayer: " .. LocalPlayer.Name,
        parse_mode = "HTML"
    }
    
    local success, response = pcall(function()
        local req = (syn and syn.request) or (http and http.request) or http_request or request
        if req then
            req({
                Url = url,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(payload)
            })
        end
    end)
end

local function AddHistory(eggName, rarity)
    local timestamp = os.date("%X")
    table.insert(Config.EggHistory, 1, {name = eggName, rarity = rarity, time = timestamp})
end

------------------------------------------------------------------------------------
-- GAME MECHANICS & STEAL SYSTEM
------------------------------------------------------------------------------------
local function FindForestAndBase()
    local forest = Workspace:FindFirstChild("Forest") or Workspace:FindFirstChild("ForestZone")
    local base = Workspace:FindFirstChild("Bases") and Workspace.Bases:FindFirstChild(LocalPlayer.Name) or Workspace:FindFirstChild("Base")
    return forest, base
end

local function TeleportSequence(eggModel)
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    local hrp = character.HumanoidRootPart

    local forest, base = FindForestAndBase()

    -- 1. Pindah cepat ke posisi telur / ambil
    if eggModel and eggModel:FindFirstChild("TouchInterest") or eggModel:IsA("BasePart") then
        hrp.CFrame = eggModel.CFrame
        task.wait(0.1)
    end

    -- 2. Teleport membawa telur ke wilayah Forest
    if forest then
        local forestCFrame = forest:IsA("Model") and forest:GetPrimaryPartCFrame() or forest.CFrame
        hrp.CFrame = forestCFrame + Vector3.new(0, 3, 0)
    end

    -- 3. Berhenti selama 2 detik
    task.wait(2)

    -- 4. Teleport lanjut ke Base Player
    if base then
        local baseCFrame = base:IsA("Model") and base:GetPrimaryPartCFrame() or base.CFrame
        hrp.CFrame = baseCFrame + Vector3.new(0, 3, 0)
    end
end

local function ExecuteAutoSteal()
    if not Config.AutoStealEnabled then return end

    local targetEgg = nil
    local highestPriority = 0

    -- Cari telur di Workspace (Divine > Eternal > Secret)
    local eggFolder = Workspace:FindFirstChild("Eggs") or Workspace
    for _, obj in pairs(eggFolder:GetChildren()) do
        local rarity = obj:GetAttribute("Rarity") or "Common"
        if RarityPriority[rarity] then
            if RarityPriority[rarity] > highestPriority then
                highestPriority = RarityPriority[rarity]
                targetEgg = obj
            end
        end
    end

    if targetEgg then
        local eggRarity = targetEgg:GetAttribute("Rarity") or "Unknown"
        TeleportSequence(targetEgg)
        AddHistory(targetEgg.Name, eggRarity)
        SendTelegramNotification(targetEgg.Name, eggRarity)
    end
end

-- Thread Loop Auto Steal
task.spawn(function()
    while true do
        task.wait(1)
        if Config.AutoStealEnabled then
            ExecuteAutoSteal()
        end
    end
end)

-- Character Speed Controller
RunService.Stepped:Connect(function()
    if Config.SpeedBoostEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = Config.SpeedValue
    end
end)

------------------------------------------------------------------------------------
-- USER INTERFACE BUILDER (MINECRAFT DARK-GREEN THEME)
------------------------------------------------------------------------------------
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LIXX_EGG_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = PlayerGui

-- Logo "L" Re-open Button
local OpenBtn = Instance.new("TextButton")
OpenBtn.Name = "OpenLogo"
OpenBtn.Size = UDim2.new(0, 45, 0, 45)
OpenBtn.Position = UDim2.new(0, 15, 0.4, 0)
OpenBtn.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
OpenBtn.BorderSizePixel = 2
OpenBtn.BorderColor3 = Color3.fromRGB(76, 175, 80)
OpenBtn.Text = "L"
OpenBtn.TextColor3 = Color3.fromRGB(76, 175, 80)
OpenBtn.TextSize = 26
OpenBtn.Font = Enum.Font.FredokaOne
OpenBtn.Visible = false
OpenBtn.Parent = ScreenGui

-- Main Container Window
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 620, 0, 360)
MainFrame.Position = UDim2.new(0.5, -310, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 24)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
MainFrame.Active = true
MainFrame.Draggable = true
MainFrame.Parent = ScreenGui

local UICorner = Instance.new("UICorner")
UICorner.CornerRadius = UDim.new(0, 10)
UICorner.Parent = MainFrame

-- Top Close Button (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 8)
CloseBtn.BackgroundTransparency = 1
CloseBtn.Text = "✕"
CloseBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
CloseBtn.TextSize = 18
CloseBtn.Font = Enum.Font.GothamBold
CloseBtn.Parent = MainFrame

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
    OpenBtn.Visible = true
end)

OpenBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = true
    OpenBtn.Visible = false
end)

-- Sidebar Menu Frame
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 160, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(18, 18, 18)
Sidebar.BorderSizePixel = 0
Sidebar.Parent = MainFrame

local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 45)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "LIXX EGG"
TitleLabel.TextColor3 = Color3.fromRGB(76, 175, 80)
TitleLabel.TextSize = 20
TitleLabel.Font = Enum.Font.GothamBlack
TitleLabel.Parent = Sidebar

local MenuLayout = Instance.new("UIListLayout")
MenuLayout.SortOrder = Enum.SortOrder.LayoutOrder
MenuLayout.Padding = UDim.new(0, 6)
MenuLayout.Parent = Sidebar

TitleLabel.LayoutOrder = 0

-- Content Panels Area
local ContentArea = Instance.new("Frame")
ContentArea.Size = UDim2.new(1, -170, 1, -10)
ContentArea.Position = UDim2.new(0, 165, 0, 5)
ContentArea.BackgroundTransparency = 1
ContentArea.Parent = MainFrame

local Pages = {}

local function CreateMenuButton(name, iconText, order)
    local Btn = Instance.new("TextButton")
    Btn.Size = UDim2.new(0.9, 0, 0, 38)
    Btn.Position = UDim2.new(0.05, 0, 0, 0)
    Btn.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
    Btn.BorderSizePixel = 0
    Btn.Text = "   " .. iconText .. "  " .. name
    Btn.TextColor3 = Color3.fromRGB(180, 180, 180)
    Btn.TextXAlignment = Enum.TextXAlignment.Left
    Btn.Font = Enum.Font.GothamMedium
    Btn.TextSize = 13
    Btn.LayoutOrder = order
    Btn.Parent = Sidebar

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 6)
    BtnCorner.Parent = Btn

    local Page = Instance.new("ScrollingFrame")
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.BorderSizePixel = 0
    Page.ScrollBarThickness = 4
    Page.Visible = false
    Page.Parent = ContentArea

    Pages[name] = {Button = Btn, Page = Page}

    Btn.MouseButton1Click:Connect(function()
        for _, item in pairs(Pages) do
            item.Page.Visible = false
            item.Button.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
            item.Button.TextColor3 = Color3.fromRGB(180, 180, 180)
        end
        Page.Visible = true
        Btn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
        Btn.TextColor3 = Color3.fromRGB(76, 175, 80)
    end)

    return Page
end

-- Generate 5 Main Menus
local AutoEggPage   = CreateMenuButton("Auto Egg", "⭕", 1)
local HistoryPage   = CreateMenuButton("History Egg", "🕒", 2)
local DuelPage      = CreateMenuButton("Duel Player", "⚔️", 3)
local NotificationPage = CreateMenuButton("Notification", "🔔", 4)
local SettingsPage  = CreateMenuButton("Settings", "⚙️", 5)

-- Default Open First Menu
Pages["Auto Egg"].Page.Visible = true
Pages["Auto Egg"].Button.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
Pages["Auto Egg"].Button.TextColor3 = Color3.fromRGB(76, 175, 80)

------------------------------------------------------------------------------------
-- HELPER COMPONENTS BUILDER
------------------------------------------------------------------------------------
local function CreateToggle(parent, title, subtitle, callback)
    local Frame = Instance.new("Frame")
    Frame.Size = UDim2.new(0.96, 0, 0, 55)
    Frame.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    Frame.BorderSizePixel = 0
    Frame.Parent = parent

    local Corner = Instance.new("UICorner")
    Corner.CornerRadius = UDim.new(0, 6)
    Corner.Parent = Frame

    local TName = Instance.new("TextLabel")
    TName.Size = UDim2.new(0.7, 0, 0, 25)
    TName.Position = UDim2.new(0, 12, 0, 6)
    TName.BackgroundTransparency = 1
    TName.Text = title
    TName.TextColor3 = Color3.fromRGB(230, 230, 230)
    TName.TextXAlignment = Enum.TextXAlignment.Left
    TName.Font = Enum.Font.GothamBold
    TName.TextSize = 14
    TName.Parent = Frame

    if subtitle then
        local TSub = Instance.new("TextLabel")
        TSub.Size = UDim2.new(0.7, 0, 0, 18)
        TSub.Position = UDim2.new(0, 12, 0, 28)
        TSub.BackgroundTransparency = 1
        TSub.Text = subtitle
        TSub.TextColor3 = Color3.fromRGB(140, 140, 140)
        TSub.TextXAlignment = Enum.TextXAlignment.Left
        TSub.Font = Enum.Font.Gotham
        TSub.TextSize = 11
        TSub.Parent = Frame
    end

    local ToggleBtn = Instance.new("TextButton")
    ToggleBtn.Size = UDim2.new(0, 45, 0, 22)
    ToggleBtn.Position = UDim2.new(1, -55, 0.5, -11)
    ToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
    ToggleBtn.Text = ""
    ToggleBtn.Parent = Frame

    local ToggleCorner = Instance.new("UICorner")
    ToggleCorner.CornerRadius = UDim.new(1, 0)
    ToggleCorner.Parent = ToggleBtn

    local Circle = Instance.new("Frame")
    Circle.Size = UDim2.new(0, 16, 0, 16)
    Circle.Position = UDim2.new(0, 3, 0.5, -8)
    Circle.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
    Circle.Parent = ToggleBtn

    local CircleCorner = Instance.new("UICorner")
    CircleCorner.CornerRadius = UDim.new(1, 0)
    CircleCorner.Parent = Circle

    local state = false
    ToggleBtn.MouseButton1Click:Connect(function()
        state = not state
        if state then
            TweenService:Create(Circle, TweenInfo.new(0.2), {Position = UDim2.new(1, -19, 0.5, -8)}):Play()
            ToggleBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
        else
            TweenService:Create(Circle, TweenInfo.new(0.2), {Position = UDim2.new(0, 3, 0.5, -8)}):Play()
            ToggleBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
        end
        callback(state)
    end)
end

------------------------------------------------------------------------------------
-- MENU 1: AUTO EGG
------------------------------------------------------------------------------------
local AutoEggLayout = Instance.new("UIListLayout")
AutoEggLayout.Padding = UDim.new(0, 10)
AutoEggLayout.Parent = AutoEggPage

CreateToggle(AutoEggPage, "Steal On/Off", "Prioritasi: Divine > Eternal > Secret", function(val)
    Config.AutoStealEnabled = val
end)

-- Panel Egg Sub-UI Trigger
local PanelFrame = Instance.new("Frame")
PanelFrame.Size = UDim2.new(0.96, 0, 0, 50)
PanelFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
PanelFrame.Parent = AutoEggPage

local PanelCorner = Instance.new("UICorner")
PanelCorner.CornerRadius = UDim.new(0, 6)
PanelCorner.Parent = PanelFrame

local PanelBtn = Instance.new("TextButton")
PanelBtn.Size = UDim2.new(1, 0, 1, 0)
PanelBtn.BackgroundTransparency = 1
PanelBtn.Text = "  Buka Panel Telur (Manual Steal UI)"
PanelBtn.TextColor3 = Color3.fromRGB(76, 175, 80)
PanelBtn.Font = Enum.Font.GothamBold
PanelBtn.TextXAlignment = Enum.TextXAlignment.Left
PanelBtn.TextSize = 13
PanelBtn.Parent = PanelFrame

-- Speed Slider
local SpeedFrame = Instance.new("Frame")
SpeedFrame.Size = UDim2.new(0.96, 0, 0, 60)
SpeedFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
SpeedFrame.Parent = AutoEggPage

local SpeedCorner = Instance.new("UICorner")
SpeedCorner.CornerRadius = UDim.new(0, 6)
SpeedCorner.Parent = SpeedFrame

local SpeedTitle = Instance.new("TextLabel")
SpeedTitle.Size = UDim2.new(1, -20, 0, 20)
SpeedTitle.Position = UDim2.new(0, 10, 0, 5)
SpeedTitle.BackgroundTransparency = 1
SpeedTitle.Text = "Speed Boost Value: 50"
SpeedTitle.TextColor3 = Color3.fromRGB(220, 220, 220)
SpeedTitle.Font = Enum.Font.GothamBold
SpeedTitle.TextXAlignment = Enum.TextXAlignment.Left
SpeedTitle.TextSize = 12
SpeedTitle.Parent = SpeedFrame

local SliderBtn = Instance.new("TextButton")
SliderBtn.Size = UDim2.new(0.9, 0, 0, 8)
SliderBtn.Position = UDim2.new(0.05, 0, 0, 35)
SliderBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
SliderBtn.Text = ""
SliderBtn.Parent = SpeedFrame

local SliderFill = Instance.new("Frame")
SliderFill.Size = UDim2.new(0.3, 0, 1, 0)
SliderFill.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
SliderFill.BorderSizePixel = 0
SliderFill.Parent = SliderBtn

CreateToggle(AutoEggPage, "Speed Boost On/Off", "Aktifkan peningkatan kecepatan lari", function(val)
    Config.SpeedBoostEnabled = val
end)

------------------------------------------------------------------------------------
-- SUB-UI: PANEL EGG DISPLAY (Sederhana + Rarity Sorted)
------------------------------------------------------------------------------------
local SubPanelGui = Instance.new("Frame")
SubPanelGui.Name = "EggPanelSubUI"
SubPanelGui.Size = UDim2.new(0, 400, 0, 280)
SubPanelGui.Position = UDim2.new(0.5, -200, 0.5, -140)
SubPanelGui.BackgroundColor3 = Color3.fromRGB(28, 28, 28)
SubPanelGui.BorderSizePixel = 2
SubPanelGui.BorderColor3 = Color3.fromRGB(76, 175, 80)
SubPanelGui.Visible = false
SubPanelGui.Active = true
SubPanelGui.Draggable = true
SubPanelGui.Parent = ScreenGui

local SubPanelCorner = Instance.new("UICorner")
SubPanelCorner.CornerRadius = UDim.new(0, 8)
SubPanelCorner.Parent = SubPanelGui

local SubPanelTitle = Instance.new("TextLabel")
SubPanelTitle.Size = UDim2.new(1, -40, 0, 35)
SubPanelTitle.Position = UDim2.new(0, 10, 0, 0)
SubPanelTitle.BackgroundTransparency = 1
SubPanelTitle.Text = "PANEL TELUR TERSEDIA"
SubPanelTitle.TextColor3 = Color3.fromRGB(76, 175, 80)
SubPanelTitle.Font = Enum.Font.GothamBold
SubPanelTitle.TextXAlignment = Enum.TextXAlignment.Left
SubPanelTitle.TextSize = 13
SubPanelTitle.Parent = SubPanelGui

local SubPanelClose = Instance.new("TextButton")
SubPanelClose.Size = UDim2.new(0, 30, 0, 30)
SubPanelClose.Position = UDim2.new(1, -30, 0, 2)
SubPanelClose.BackgroundTransparency = 1
SubPanelClose.Text = "✕"
SubPanelClose.TextColor3 = Color3.fromRGB(200, 200, 200)
SubPanelClose.TextSize = 16
SubPanelClose.Parent = SubPanelGui

SubPanelClose.MouseButton1Click:Connect(function()
    SubPanelGui.Visible = false
end)

PanelBtn.MouseButton1Click:Connect(function()
    SubPanelGui.Visible = not SubPanelGui.Visible
end)

local SubPanelScroll = Instance.new("ScrollingFrame")
SubPanelScroll.Size = UDim2.new(1, -20, 1, -45)
SubPanelScroll.Position = UDim2.new(0, 10, 0, 40)
SubPanelScroll.BackgroundTransparency = 1
SubPanelScroll.ScrollBarThickness = 4
SubPanelScroll.Parent = SubPanelGui

local SubPanelLayout = Instance.new("UIListLayout")
SubPanelLayout.Padding = UDim.new(0, 6)
SubPanelLayout.Parent = SubPanelScroll

------------------------------------------------------------------------------------
-- MENU 2: HISTORY EGG
------------------------------------------------------------------------------------
local HistLayout = Instance.new("UIListLayout")
HistLayout.Padding = UDim.new(0, 6)
HistLayout.Parent = HistoryPage

local DeleteHistBtn = Instance.new("TextButton")
DeleteHistBtn.Size = UDim2.new(0.96, 0, 0, 32)
DeleteHistBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
DeleteHistBtn.Text = "🗑️ Hapus Riwayat Egg"
DeleteHistBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
DeleteHistBtn.Font = Enum.Font.GothamBold
DeleteHistBtn.TextSize = 12
DeleteHistBtn.Parent = HistoryPage

local DeleteCorner = Instance.new("UICorner")
DeleteCorner.CornerRadius = UDim.new(0, 6)
DeleteCorner.Parent = DeleteHistBtn

local HistContainer = Instance.new("Frame")
HistContainer.Size = UDim2.new(0.96, 0, 0, 200)
HistContainer.BackgroundTransparency = 1
HistContainer.Parent = HistoryPage

DeleteHistBtn.MouseButton1Click:Connect(function()
    Config.EggHistory = {}
    for _, child in pairs(HistContainer:GetChildren()) do
        if child:IsA("Frame") then child:Destroy() end
    end
end)

------------------------------------------------------------------------------------
-- MENU 3: DUEL PLAYER
------------------------------------------------------------------------------------
local DuelLayout = Instance.new("UIListLayout")
DuelLayout.Padding = UDim.new(0, 8)
DuelLayout.Parent = DuelPage

CreateToggle(DuelPage, "Duel Player On/Off", "Otomatis pukuli pemegang telur sampai lepas", function(val)
    if not val then Config.DuelTarget = nil end
end)

local PlayerListContainer = Instance.new("ScrollingFrame")
PlayerListContainer.Size = UDim2.new(0.96, 0, 0, 220)
PlayerListContainer.BackgroundTransparency = 1
PlayerListContainer.ScrollBarThickness = 4
PlayerListContainer.Parent = DuelPage

local PListLayout = Instance.new("UIListLayout")
PListLayout.Padding = UDim.new(0, 4)
PListLayout.Parent = PlayerListContainer

local function RefreshPlayerList()
    for _, c in pairs(PlayerListContainer:GetChildren()) do
        if c:IsA("Frame") then c:Destroy() end
    end

    for _, p in pairs(Players:GetPlayers()) do
        if p ~= LocalPlayer then
            local PRow = Instance.new("Frame")
            PRow.Size = UDim2.new(1, -10, 0, 35)
            PRow.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
            PRow.Parent = PlayerListContainer

            local PCorner = Instance.new("UICorner")
            PCorner.CornerRadius = UDim.new(0, 4)
            PCorner.Parent = PRow

            local PName = Instance.new("TextLabel")
            PName.Size = UDim2.new(0.6, 0, 1, 0)
            PName.Position = UDim2.new(0, 10, 0, 0)
            PName.BackgroundTransparency = 1
            PName.Text = p.DisplayName .. " (@" .. p.Name .. ")"
            PName.TextColor3 = Color3.fromRGB(220, 220, 220)
            PName.Font = Enum.Font.Gotham
            PName.TextXAlignment = Enum.TextXAlignment.Left
            PName.TextSize = 11
            PName.Parent = PRow

            local HasEgg = p.Character and (p.Character:FindFirstChild("Egg") or p.Character:FindFirstChildWithClass("Tool"))
            
            local StealPBtn = Instance.new("TextButton")
            StealPBtn.Size = UDim2.new(0, 70, 0, 24)
            StealPBtn.Position = UDim2.new(1, -75, 0.5, -12)
            StealPBtn.Text = "STEAL"
            StealPBtn.Font = Enum.Font.GothamBold
            StealPBtn.TextSize = 10
            StealPBtn.Parent = PRow

            local SCorner = Instance.new("UICorner")
            SCorner.CornerRadius = UDim.new(0, 4)
            SCorner.Parent = StealPBtn

            if HasEgg then
                StealPBtn.BackgroundColor3 = Color3.fromRGB(76, 175, 80)
                StealPBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            else
                StealPBtn.BackgroundColor3 = Color3.fromRGB(180, 50, 50)
                StealPBtn.TextColor3 = Color3.fromRGB(200, 200, 200)
            end

            StealPBtn.MouseButton1Click:Connect(function()
                if HasEgg then
                    Config.DuelTarget = p
                    -- Logika serang target
                    task.spawn(function()
                        while Config.DuelTarget == p and p.Character and p.Character:FindFirstChild("HumanoidRootPart") do
                            local myHrp = LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart")
                            if myHrp then
                                myHrp.CFrame = p.Character.HumanoidRootPart.CFrame * CFrame.new(0, 0, 2)
                                local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                                if tool then tool:Activate() end
                            end
                            task.wait(0.1)
                        end
                    end)
                end
            end)
        end
    end
end

Players.PlayerAdded:Connect(RefreshPlayerList)
Players.PlayerRemoving:Connect(RefreshPlayerList)
task.spawn(RefreshPlayerList)

------------------------------------------------------------------------------------
-- MENU 4: NOTIFICATION
------------------------------------------------------------------------------------
local NotifLayout = Instance.new("UIListLayout")
NotifLayout.Padding = UDim.new(0, 8)
NotifLayout.Parent = NotificationPage

CreateToggle(NotificationPage, "Notification On/Off", "Kirim notifikasi Telegram saat dapat telur", function(val)
    Config.TelegramEnabled = val
end)

local function CreateInputBox(parent, placeholder, callback)
    local InputFrame = Instance.new("Frame")
    InputFrame.Size = UDim2.new(0.96, 0, 0, 40)
    InputFrame.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    InputFrame.Parent = parent

    local ICorner = Instance.new("UICorner")
    ICorner.CornerRadius = UDim.new(0, 6)
    ICorner.Parent = InputFrame

    local TextBox = Instance.new("TextBox")
    TextBox.Size = UDim2.new(1, -20, 1, 0)
    TextBox.Position = UDim2.new(0, 10, 0, 0)
    TextBox.BackgroundTransparency = 1
    TextBox.PlaceholderText = placeholder
    TextBox.Text = ""
    TextBox.TextColor3 = Color3.fromRGB(220, 220, 220)
    TextBox.Font = Enum.Font.Gotham
    TextBox.TextSize = 12
    TextBox.TextXAlignment = Enum.TextXAlignment.Left
    TextBox.Parent = InputFrame

    TextBox.FocusLost:Connect(function()
        callback(TextBox.Text)
    end)
end

CreateInputBox(NotificationPage, "Masukkan Bot Token Telegram...", function(txt)
    Config.BotToken = txt
end)

CreateInputBox(NotificationPage, "Masukkan ID Penerima (Chat ID)...", function(txt)
    Config.ChatID = txt
end)

------------------------------------------------------------------------------------
-- MENU 5: SETTINGS
------------------------------------------------------------------------------------
local SettLayout = Instance.new("UIListLayout")
SettLayout.Padding = UDim.new(0, 8)
SettLayout.Parent = SettingsPage

local ResetBtn = Instance.new("TextButton")
ResetBtn.Size = UDim2.new(0.96, 0, 0, 40)
ResetBtn.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
ResetBtn.Text = "🔄 Refresh Server UI / Re-check Eggs"
ResetBtn.TextColor3 = Color3.fromRGB(220, 220, 220)
ResetBtn.Font = Enum.Font.GothamBold
ResetBtn.TextSize = 12
ResetBtn.Parent = SettingsPage

local RCorner = Instance.new("UICorner")
RCorner.CornerRadius = UDim.new(0, 6)
RCorner.Parent = ResetBtn

ResetBtn.MouseButton1Click:Connect(function()
    RefreshPlayerList()
end)

print("[LIXX EGG] Script Berhasil Dimuat.")
