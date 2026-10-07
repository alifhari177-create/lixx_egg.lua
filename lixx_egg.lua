-- [[ SCRIPT LIXX EGG - MAP STEAL AND EGG ]] --

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

-- Global Configuration & State
local Config = {
    TelegramBotToken = "",
    TelegramChatID = "",
    SpeedValue = 50,
    SpeedEnabled = false,
    StealEnabled = false,
    NotificationEnabled = false,
    History = {}
}

-- Rarity Priorities
local RarityPriority = {
    ["Divine"] = 3,
    ["Eternal"] = 2,
    ["Secret"] = 1
}

-- UI Root Creation
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LIXX_EGG_GUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

-- Custom Logo L Button (Toggle Open UI)
local LogoLBtn = Instance.new("TextButton")
LogoLBtn.Name = "LogoL"
LogoLBtn.Size = UDim2.new(0, 45, 0, 45)
LogoLBtn.Position = UDim2.new(0, 15, 0.4, 0)
LogoLBtn.BackgroundColor3 = Color3.fromRGB(34, 139, 34)
LogoLBtn.Text = "L"
LogoLBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoLBtn.TextSize = 24
LogoLBtn.Font = Enum.Font.FredokaOne
LogoLBtn.Parent = ScreenGui

local UICornerL = Instance.new("UICorner")
UICornerL.CornerRadius = UDim me.new(0, 8) if UICornerL then UICornerL.Parent = LogoLBtn end

-- Main Frame (Minecraft Style UI - Dark Gray with Green Accents)
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 580, 0, 360)
MainFrame.Position = UDim2.new(0.5, -290, 0.5, -180)
MainFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = ScreenGui

local MainCorner = Instance.new("UICorner")
MainCorner.CornerRadius = UDim.new(0, 10)
MainCorner.Parent = MainFrame

-- Close Button (X)
local CloseBtn = Instance.new("TextButton")
CloseBtn.Name = "CloseBtn"
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 5)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 18
CloseBtn.Font = Enum.Font.SourceSansBold
CloseBtn.Parent = MainFrame

local CloseCorner = Instance.new("UICorner")
CloseCorner.CornerRadius = UDim.new(0, 6)
CloseCorner.Parent = CloseBtn

CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

LogoLBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)

-- Sidebar (Left Menu Navigation)
local Sidebar = Instance.new("Frame")
Sidebar.Size = UDim2.new(0, 160, 1, 0)
Sidebar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Sidebar.Parent = MainFrame

local SideCorner = Instance.new("UICorner")
SideCorner.CornerRadius = UDim.new(0, 10)
SideCorner.Parent = Sidebar

local SideLayout = Instance.new("UIListLayout")
SideLayout.Parent = Sidebar
SideLayout.SortOrder = Enum.SortOrder.LayoutOrder
SideLayout.Padding = UDim.new(0, 5)

-- Title Banner inside Sidebar
local TitleLabel = Instance.new("TextLabel")
TitleLabel.Size = UDim2.new(1, 0, 0, 40)
TitleLabel.BackgroundTransparency = 1
TitleLabel.Text = "LIXX EGG"
TitleLabel.TextColor3 = Color3.fromRGB(85, 255, 85)
TitleLabel.TextSize = 20
TitleLabel.Font = Enum.Font.FredokaOne
TitleLabel.Parent = Sidebar

-- Content Frame (Right Container for 5 Pages)
local Container = Instance.new("Frame")
Container.Size = UDim2.new(1, -170, 1, -10)
Container.Position = UDim2.new(0, 165, 0, 5)
Container.BackgroundTransparency = 1
Container.Parent = MainFrame

-- Create 5 Pages
local Pages = {}
local Menus = {"Auto Egg", "History Egg", "Duel Player", "Notification", "Settings"}

for i, menuName in ipairs(Menus) do
    local Page = Instance.new("ScrollingFrame")
    Page.Name = menuName
    Page.Size = UDim2.new(1, 0, 1, 0)
    Page.BackgroundTransparency = 1
    Page.Visible = (i == 1)
    Page.ScrollBarThickness = 4
    Page.Parent = Container
    Pages[menuName] = Page

    local PageLayout = Instance.new("UIListLayout")
    PageLayout.Parent = Page
    PageLayout.SortOrder = Enum.SortOrder.LayoutOrder
    PageLayout.Padding = UDim.new(0, 10)

    -- Sidebar Button
    local MenuBtn = Instance.new("TextButton")
    MenuBtn.Size = UDim2.new(1, -10, 0, 35)
    MenuBtn.Position = UDim2.new(0, 5, 0, 0)
    MenuBtn.BackgroundColor3 = (i == 1) and Color3.fromRGB(45, 120, 45) or Color3.fromRGB(35, 35, 35)
    MenuBtn.Text = menuName
    MenuBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    MenuBtn.Font = Enum.Font.SourceSansBold
    MenuBtn.TextSize = 16
    MenuBtn.Parent = Sidebar

    local BtnCorner = Instance.new("UICorner")
    BtnCorner.CornerRadius = UDim.new(0, 6)
    BtnCorner.Parent = MenuBtn

    MenuBtn.MouseButton1Click:Connect(function()
        for _, p in pairs(Pages) do p.Visible = false end
        for _, b in pairs(Sidebar:GetChildren()) do
            if b:IsA("TextButton") then b.BackgroundColor3 = Color3.fromRGB(35, 35, 35) end
        end
        Page.Visible = true
        MenuBtn.BackgroundColor3 = Color3.fromRGB(45, 120, 45)
    end)
end

-- ==========================================
-- helper function: Teleport with Egg
-- ==========================================
local function StealEggProcess(eggObject)
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    
    -- Fast Move to Egg
    char.HumanoidRootPart.CFrame = eggObject.CFrame
    task.wait(0.1)
    
    -- Pickup Egg Logic (Fire ProximityPrompt / Touch)
    if eggObject:FindFirstChildOfClass("ProximityPrompt") then
        fireproximityprompt(eggObject:FindFirstChildOfClass("ProximityPrompt"))
    end
    
    -- Teleport to Forest
    local forestCFrame = CFrame.new(100, 10, 200) -- Sesuaikan koordinat Forest map
    if workspace:FindFirstChild("Forest") then
        forestCFrame = workspace.Forest.CFrame
    end
    char.HumanoidRootPart.CFrame = forestCFrame
    
    -- Stop 2 seconds
    task.wait(2)
    
    -- Teleport to Personal Base
    local baseCFrame = CFrame.new(0, 10, 0) -- Sesuaikan koordinat Base
    if workspace:FindFirstChild("Bases") and workspace.Bases:FindFirstChild(LocalPlayer.Name) then
        baseCFrame = workspace.Bases[LocalPlayer.Name].CFrame
    end
    char.HumanoidRootPart.CFrame = baseCFrame

    -- Log History
    table.insert(Config.History, {Name = eggObject.Name, Time = os.date("%X")})
    
    -- Telegram Notification
    if Config.NotificationEnabled and Config.TelegramBotToken ~= "" then
        local msg = "Player " .. LocalPlayer.Name .. " berhasil mengambil telur: " .. eggObject.Name
        pcall(function()
            request({
                Url = "https://api.telegram.org/bot" .. Config.TelegramBotToken .. "/sendMessage",
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode({chat_id = Config.TelegramChatID, text = msg})
            })
        end)
    end
end

-- ==========================================
-- MENU 1: AUTO EGG
-- ==========================================
local AutoEggPage = Pages["Auto Egg"]

-- 1. Steal On/Off Toggle
local StealToggle = Instance.new("TextButton")
StealToggle.Size = UDim2.new(1, -10, 0, 40)
StealToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
StealToggle.Text = "Steal On/Off : OFF"
StealToggle.TextColor3 = Color3.fromRGB(255, 100, 100)
StealToggle.Font = Enum.Font.SourceSansBold
StealToggle.TextSize = 16
StealToggle.Parent = AutoEggPage

StealToggle.MouseButton1Click:Connect(function()
    Config.StealEnabled = not Config.StealEnabled
    StealToggle.Text = "Steal On/Off : " .. (Config.StealEnabled and "ON" or "OFF")
    StealToggle.TextColor3 = Config.StealEnabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
end)

-- Main Steal Loop (Divine > Eternal > Secret)
task.spawn(function()
    while task.wait(1) do
        if Config.StealEnabled then
            local eggs = workspace:FindFirstChild("Eggs") and workspace.Eggs:GetChildren() or {}
            local targetEgg = nil
            local highestPriority = 0

            for _, egg in ipairs(eggs) do
                local rarity = egg:GetAttribute("Rarity") or "Secret"
                local priority = RarityPriority[rarity] or 0
                if priority > highestPriority then
                    highestPriority = priority
                    targetEgg = egg
                end
            end

            if targetEgg then
                StealEggProcess(targetEgg)
            end
        end
    end
end)

-- 2. Panel Egg Button & Frame
local PanelBtn = Instance.new("TextButton")
PanelBtn.Size = UDim2.new(1, -10, 0, 40)
PanelBtn.BackgroundColor3 = Color3.fromRGB(45, 120, 45)
PanelBtn.Text = "Buka Panel Telur"
PanelBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
PanelBtn.Font = Enum.Font.SourceSansBold
PanelBtn.TextSize = 16
PanelBtn.Parent = AutoEggPage

local EggPanelUI = Instance.new("Frame")
EggPanelUI.Size = UDim2.new(0, 300, 0, 350)
EggPanelUI.Position = UDim2.new(0.5, 300, 0.5, -175)
EggPanelUI.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
EggPanelUI.Visible = false
EggPanelUI.Parent = ScreenGui

local PanelScroll = Instance.new("ScrollingFrame")
PanelScroll.Size = UDim2.new(1, -10, 1, -40)
PanelScroll.Position = UDim2.new(0, 5, 0, 35)
PanelScroll.BackgroundTransparency = 1
PanelScroll.Parent = EggPanelUI

local PanelLayout = Instance.new("UIListLayout")
PanelLayout.Parent = PanelScroll
PanelLayout.Padding = UDim.new(0, 5)

PanelBtn.MouseButton1Click:Connect(function()
    EggPanelUI.Visible = not EggPanelUI.Visible
    -- Refresh items inside Panel sorted by Rarity
    for _, c in ipairs(PanelScroll:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end
    
    local eggs = workspace:FindFirstChild("Eggs") and workspace.Eggs:GetChildren() or {}
    table.sort(eggs, function(a, b)
        local rA = RarityPriority[a:GetAttribute("Rarity") or "Secret"] or 0
        local rB = RarityPriority[b:GetAttribute("Rarity") or "Secret"] or 0
        return rA > rB
    end)

    for _, egg in ipairs(eggs) do
        local Item = Instance.new("Frame")
        Item.Size = UDim2.new(1, 0, 0, 50)
        Item.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
        Item.Parent = PanelScroll

        local Img = Instance.new("ImageLabel")
        Img.Size = UDim2.new(0, 40, 0, 40)
        Img.Position = UDim2.new(0, 5, 0, 5)
        Img.Image = "rbxassetid://6031075929" -- Placeholder gambar
        Img.Parent = Item

        local Lbl = Instance.new("TextLabel")
        Lbl.Position = UDim2.new(0, 50, 0, 10)
        Lbl.Text = egg.Name .. " (" .. (egg:GetAttribute("Rarity") or "Unknown") .. ")"
        Lbl.TextColor3 = Color3.fromRGB(255, 255, 255)
        Lbl.TextXAlignment = Enum.TextXAlignment.Left
        Lbl.Parent = Item

        local StealBtn = Instance.new("TextButton")
        StealBtn.Size = UDim2.new(0, 60, 0, 30)
        StealBtn.Position = UDim2.new(1, -65, 0, 10)
        StealBtn.BackgroundColor3 = Color3.fromRGB(34, 139, 34)
        StealBtn.Text = "STEAL"
        StealBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        StealBtn.Parent = Item

        StealBtn.MouseButton1Click:Connect(function()
            StealEggProcess(egg)
        end)
    end
end)

-- 3. Speed Boost Value Slider & Toggle
local SpeedLabel = Instance.new("TextLabel")
SpeedLabel.Size = UDim2.new(1, -10, 0, 20)
SpeedLabel.Text = "Speed Boost Value: " .. Config.SpeedValue
SpeedLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
SpeedLabel.Parent = AutoEggPage

local SpeedToggle = Instance.new("TextButton")
SpeedToggle.Size = UDim2.new(1, -10, 0, 35)
SpeedToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
SpeedToggle.Text = "Speed Boost : OFF"
SpeedToggle.TextColor3 = Color3.fromRGB(255, 100, 100)
SpeedToggle.Parent = AutoEggPage

SpeedToggle.MouseButton1Click:Connect(function()
    Config.SpeedEnabled = not Config.SpeedEnabled
    SpeedToggle.Text = "Speed Boost : " .. (Config.SpeedEnabled and "ON" or "OFF")
    SpeedToggle.TextColor3 = Config.SpeedEnabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
end)

RunService.RenderStepped:Connect(function()
    if Config.SpeedEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
        LocalPlayer.Character.Humanoid.WalkSpeed = Config.SpeedValue
    end
end)

-- ==========================================
-- MENU 2: HISTORY EGG
-- ==========================================
local HistoryPage = Pages["History Egg"]

local ClearHistoryBtn = Instance.new("TextButton")
ClearHistoryBtn.Size = UDim2.new(1, -10, 0, 35)
ClearHistoryBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
ClearHistoryBtn.Text = "Delete History"
ClearHistoryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
ClearHistoryBtn.Parent = HistoryPage

ClearHistoryBtn.MouseButton1Click:Connect(function()
    Config.History = {}
    for _, child in ipairs(HistoryPage:GetChildren()) do
        if child:IsA("TextLabel") and child.Name == "HistItem" then
            child:Destroy()
        end
    end
end)

-- ==========================================
-- MENU 3: DUEL PLAYER
-- ==========================================
local DuelPage = Pages["Duel Player"]

local function RefreshDuelList()
    for _, c in ipairs(DuelPage:GetChildren()) do if c:IsA("Frame") then c:Destroy() end end

    for _, player in ipairs(Players:GetPlayers()) do
        if player ~= LocalPlayer then
            local Item = Instance.new("Frame")
            Item.Size = UDim2.new(1, -10, 0, 40)
            Item.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
            Item.Parent = DuelPage

            local NameLbl = Instance.new("TextLabel")
            NameLbl.Size = UDim2.new(0.6, 0, 1, 0)
            NameLbl.Text = player.DisplayName
            NameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
            NameLbl.Parent = Item

            local HasEgg = player.Character and player.Character:FindFirstChild("CarriedEgg") ~= nil
            local StealPBtn = Instance.new("TextButton")
            StealPBtn.Size = UDim2.new(0, 80, 0, 30)
            StealPBtn.Position = UDim2.new(1, -85, 0, 5)
            StealPBtn.BackgroundColor3 = HasEgg and Color3.fromRGB(34, 139, 34) or Color3.fromRGB(150, 40, 40)
            StealPBtn.Text = "Steal"
            StealPBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
            StealPBtn.Parent = Item

            StealPBtn.MouseButton1Click:Connect(function()
                if HasEgg and player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
                    -- Sticky follow & attack with wooden club
                    local char = LocalPlayer.Character
                    char.HumanoidRootPart.CFrame = player.Character.HumanoidRootPart.CFrame
                    -- Attack logic
                    local club = char:FindFirstChild("WoodenClub") or LocalPlayer.Backpack:FindFirstChild("WoodenClub")
                    if club then
                        club.Parent = char
                        club:Activate()
                    end
                end
            end)
        end
    end
end

task.spawn(function()
    while task.wait(3) do
        if Pages["Duel Player"].Visible then
            RefreshDuelList()
        end
    end
end)

-- ==========================================
-- MENU 4 & 5: NOTIFICATION & SETTINGS
-- ==========================================
local NotifPage = Pages["Notification"]

local TokenInput = Instance.new("TextBox")
TokenInput.Size = UDim2.new(1, -10, 0, 35)
TokenInput.PlaceholderText = "Masukkan Telegram Bot Token..."
TokenInput.Text = Config.TelegramBotToken
TokenInput.Parent = NotifPage

TokenInput.FocusLost:Connect(function()
    Config.TelegramBotToken = TokenInput.Text
end)

local ChatIDInput = Instance.new("TextBox")
ChatIDInput.Size = UDim2.new(1, -10, 0, 35)
ChatIDInput.PlaceholderText = "Masukkan Telegram Chat ID..."
ChatIDInput.Text = Config.TelegramChatID
ChatIDInput.Parent = NotifPage

ChatIDInput.FocusLost:Connect(function()
    Config.TelegramChatID = ChatIDInput.Text
end)

local NotifToggle = Instance.new("TextButton")
NotifToggle.Size = UDim2.new(1, -10, 0, 35)
NotifToggle.BackgroundColor3 = Color3.fromRGB(60, 60, 60)
NotifToggle.Text = "Telegram Notification : OFF"
NotifToggle.TextColor3 = Color3.fromRGB(255, 100, 100)
NotifToggle.Parent = NotifPage

NotifToggle.MouseButton1Click:Connect(function()
    Config.NotificationEnabled = not Config.NotificationEnabled
    NotifToggle.Text = "Telegram Notification : " .. (Config.NotificationEnabled and "ON" or "OFF")
    NotifToggle.TextColor3 = Config.NotificationEnabled and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(255, 100, 100)
end)
