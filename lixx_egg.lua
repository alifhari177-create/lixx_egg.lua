-- =================================================================
-- SCRIPT NAME: LIXX EGG
-- GAME: Steal and Egg
-- THEME: Minecraft Style (Green Accent)
-- =================================================================

local Fluent = loadstring(game:HttpGet("https://github.com/dawid-scripts/Fluent/releases/latest/download/main.lua"))()
local SaveManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/SaveManager.lua"))()
local InterfaceManager = loadstring(game:HttpGet("https://raw.githubusercontent.com/dawid-scripts/Fluent/master/Addons/InterfaceManager.lua"))()

-- Players & Services
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")

-- Configuration & State Variables
local Config = {
    AutoSteal = false,
    SpeedBoost = false,
    WalkSpeedValue = 16,
    DuelPlayer = false,
    TelegramNotif = false,
    BotToken = "",
    ChatID = "",
    EggHistory = {}
}

-- Rarity Priority Hierarchy
local RarityPriority = {
    ["Divine"] = 3,
    ["Eternal"] = 2,
    ["Secret"] = 1
}

-- Helper Functions
local function GetBasePosition()
    if workspace:FindFirstChild("Bases") then
        for _, base in pairs(workspace.Bases:GetChildren()) do
            if base:FindFirstChild("Owner") and base.Owner.Value == LocalPlayer.Name then
                return base:GetPivot().Position
            end
        end
    end
    return LocalPlayer.Character and LocalPlayer.Character:GetPivot().Position or Vector3.new(0,0,0)
end

local function GetForestPosition()
    if workspace:FindFirstChild("Forest") then
        return workspace.Forest:GetPivot().Position
    end
    return Vector3.new(100, 10, 100) -- Fallback position
end

local function InstantStealSequence(eggTarget)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local hrp = LocalPlayer.Character.HumanoidRootPart

    -- Run to Egg using current walkspeed
    local targetPos = eggTarget:GetPivot().Position
    hrp.CFrame = CFrame.new(targetPos)
    task.wait(0.1)

    -- Interaction trigger (Fire Touch / Proximity)
    if eggTarget:FindFirstChildOfClass("ProximityPrompt") then
        fireproximityprompt(eggTarget:FindFirstChildOfClass("ProximityPrompt"))
    end

    -- Teleport sequence: Forest (2s wait) -> Base
    task.wait(0.1)
    hrp.CFrame = CFrame.new(GetForestPosition())
    task.wait(2)
    hrp.CFrame = CFrame.new(GetBasePosition())
end

local function SendTelegramNotification(eggName, rarity)
    if not Config.TelegramNotif or Config.BotToken == "" or Config.ChatID == "" then return end
    local payload = HttpService:JSONEncode({
        chat_id = Config.ChatID,
        text = string.format("🎉 [LIXX EGG] Player %s berhasil mengambil telur!\n🥚 Nama: %s\n✨ Rarity: %s", LocalPlayer.Name, eggName, rarity)
    })
    
    local request = (syn and syn.request) or (http and http.request) or http_request or request
    if request then
        request({
            Url = "https://api.telegram.org/bot" .. Config.BotToken .. "/sendMessage",
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = payload
        })
    end
end

-- =================================================================
-- UI CREATION (Minecraft Green Theme)
-- =================================================================
local Window = Fluent:CreateWindow({
    Title = "LIXX EGG",
    SubTitle = "by LIXX",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

-- Custom Minecraft Green Style Modifications
Window.Root.BackgroundColor3 = Color3.fromRGB(20, 35, 20)

-- Navigation Tabs (5 Menus)
local Tabs = {
    AutoEgg = Window:AddTab({ Title = "Auto Egg", Icon = "egg" }),
    HistoryEgg = Window:AddTab({ Title = "History Egg", Icon = "history" }),
    DuelPlayer = Window:AddTab({ Title = "Duel Player", Icon = "swords" }),
    Notification = Window:AddTab({ Title = "Notification", Icon = "bell" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- =================================================================
-- 1. MENU: AUTO EGG
-- =================================================================

-- Fitur 1: Steal On/Off (Priority: Divine > Eternal > Secret)
Tabs.AutoEgg:AddToggle("AutoStealToggle", {
    Title = "Steal On/Off",
    Default = false,
    Callback = function(Value)
        Config.AutoSteal = Value
        task.spawn(function()
            while Config.AutoSteal do
                task.wait(0.5)
                local bestEgg = nil
                local highestRank = 0

                if workspace:FindFirstChild("Eggs") then
                    for _, egg in pairs(workspace.Eggs:GetChildren()) do
                        local rarity = egg:GetAttribute("Rarity") or "Common"
                        local rank = RarityPriority[rarity] or 0
                        if rank > highestRank then
                            highestRank = rank
                            bestEgg = egg
                        end
                    end
                end

                if bestEgg then
                    InstantStealSequence(bestEgg)
                    table.insert(Config.EggHistory, {Name = bestEgg.Name, Time = os.date("%X")})
                    SendTelegramNotification(bestEgg.Name, bestEgg:GetAttribute("Rarity") or "Unknown")
                end
            end
        end)
    end
})

-- Fitur 2: Panel Visual (Grid UI Rarity)
Tabs.AutoEgg:AddButton({
    Title = "Buka Panel Telur",
    Description = "Tampilkan UI Telur & Isi Rarity",
    Callback = function()
        local PanelGui = Instance.new("ScreenGui", game.CoreGui)
        PanelGui.Name = "LIXX_EggPanel"

        local MainFrame = Instance.new("Frame", PanelGui)
        MainFrame.Size = UDim2.fromOffset(320, 400)
        MainFrame.Position = UDim2.fromScale(0.35, 0.25)
        MainFrame.BackgroundColor3 = Color3.fromRGB(35, 60, 35)
        MainFrame.BorderSizePixel = 3
        MainFrame.BorderColor3 = Color3.fromRGB(80, 160, 80)

        local Title = Instance.new("TextLabel", MainFrame)
        Title.Size = UDim2.new(1, -30, 0, 30)
        Title.Text = "EGG PANEL (MINECRAFT STYLE)"
        Title.TextColor3 = Color3.fromRGB(255, 255, 255)
        Title.BackgroundColor3 = Color3.fromRGB(20, 40, 20)

        -- Tombol [X] Tutup Panel
        local CloseBtn = Instance.new("TextButton", MainFrame)
        CloseBtn.Size = UDim2.fromOffset(30, 30)
        CloseBtn.Position = UDim2.new(1, -30, 0, 0)
        CloseBtn.Text = "X"
        CloseBtn.BackgroundColor3 = Color3.fromRGB(180, 40, 40)
        CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
        CloseBtn.MouseButton1Click:Connect(function()
            PanelGui:Destroy()
        end)

        local Scroll = Instance.new("ScrollingFrame", MainFrame)
        Scroll.Size = UDim2.new(1, 0, 1, -30)
        Scroll.Position = UDim2.fromOffset(0, 30)
        Scroll.CanvasSize = UDim2.new(0, 0, 2, 0)

        local Layout = Instance.new("UIListLayout", Scroll)
        Layout.SortOrder = Enum.SortOrder.LayoutOrder

        -- Render Eggs sorted by Rarity
        if workspace:FindFirstChild("Eggs") then
            local eggList = workspace.Eggs:GetChildren()
            table.sort(eggList, function(a, b)
                return (RarityPriority[a:GetAttribute("Rarity")] or 0) > (RarityPriority[b:GetAttribute("Rarity")] or 0)
            end)

            for _, egg in pairs(eggList) do
                local Item = Instance.new("Frame", Scroll)
                Item.Size = UDim2.new(1, -10, 0, 50)
                Item.BackgroundColor3 = Color3.fromRGB(45, 75, 45)

                local Label = Instance.new("TextLabel", Item)
                Label.Size = UDim2.new(0.6, 0, 1, 0)
                Label.Text = egg.Name .. " (" .. tostring(egg:GetAttribute("Rarity")) .. ")"
                Label.TextColor3 = Color3.fromRGB(255, 255, 255)

                local StealBtn = Instance.new("TextButton", Item)
                StealBtn.Size = UDim2.new(0.35, 0, 0.8, 0)
                StealBtn.Position = UDim2.new(0.62, 0, 0.1, 0)
                StealBtn.Text = "STEAL"
                StealBtn.BackgroundColor3 = Color3.fromRGB(60, 140, 60)
                StealBtn.MouseButton1Click:Connect(function()
                    InstantStealSequence(egg)
                end)
            end
        end
    end
})

-- Fitur 3: Speed Boost + Slider + Toggle On/Off
local SpeedSlider = Tabs.AutoEgg:AddSlider("SpeedSlider", {
    Title = "Speed Boost Value",
    Min = 16,
    Max = 200,
    Default = 50,
    Rounding = 0,
    Callback = function(Value)
        Config.WalkSpeedValue = Value
        if Config.SpeedBoost and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = Value
        end
    end
})

Tabs.AutoEgg:AddToggle("SpeedBoostToggle", {
    Title = "Speed Boost On/Off",
    Default = false,
    Callback = function(Value)
        Config.SpeedBoost = Value
        if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
            LocalPlayer.Character.Humanoid.WalkSpeed = Value and Config.WalkSpeedValue or 16
        end
    end
})

-- =================================================================
-- 2. MENU: HISTORY EGG
-- =================================================================
local HistoryParagraph = Tabs.HistoryEgg:AddParagraph({
    Title = "Catatan Pengambilan Telur",
    Content = "Belum ada history."
})

Tabs.HistoryEgg:AddButton({
    Title = "Refresh History",
    Callback = function()
        local text = ""
        for i, v in ipairs(Config.EggHistory) do
            text = text .. string.format("[%s] Telur: %s\n", v.Time, v.Name)
        end
        HistoryParagraph:SetDesc(text ~= "" and text or "Belum ada history.")
    end
})

Tabs.HistoryEgg:AddButton({
    Title = "Delete History",
    Callback = function()
        Config.EggHistory = {}
        HistoryParagraph:SetDesc("History berhasil dihapus.")
    end
})

-- =================================================================
-- 3. MENU: DUEL PLAYER
-- =================================================================
local PlayerListSection = Tabs.DuelPlayer:AddSection("Daftar Player Server")

local function RefreshDuelPanel()
    for _, targetPlayer in pairs(Players:GetPlayers()) do
        if targetPlayer ~= LocalPlayer then
            local hasEgg = targetPlayer.Character and targetPlayer.Character:FindFirstChild("CarriedEgg") ~= nil
            local btnColor = hasEgg and "[HIJAU - BAWA EGG]" or "[MERAH - NO EGG]"
            
            Tabs.DuelPlayer:AddButton({
                Title = targetPlayer.Name .. " " .. btnColor,
                Callback = function()
                    if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                        local hrp = LocalPlayer.Character.HumanoidRootPart
                        -- Sticky teleport to player
                        hrp.CFrame = targetPlayer.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,2)
                        
                        -- Equip Wooden Club & Attack
                        local club = LocalPlayer.Backpack:FindFirstChild("WoodenClub") or LocalPlayer.Character:FindFirstChild("WoodenClub")
                        if club then
                            club.Parent = LocalPlayer.Character
                            club:Activate()
                        end
                        
                        -- Auto pickup egg when dropped
                        task.wait(1)
                        local droppedEgg = workspace:FindFirstChild("DroppedEgg")
                        if droppedEgg then
                            InstantStealSequence(droppedEgg)
                        end
                    end
                end
            })
        end
    end
end

Tabs.DuelPlayer:AddButton({
    Title = "Refresh Player List",
    Callback = function()
        RefreshDuelPanel()
    end
})

-- =================================================================
-- 4. MENU: NOTIFIKASI TELEGRAM
-- =================================================================
Tabs.Notification:AddToggle("NotifToggle", {
    Title = "Telegram Notification On/Off",
    Default = false,
    Callback = function(Value)
        Config.TelegramNotif = Value
    end
})

Tabs.Notification:AddInput("BotTokenInput", {
    Title = "Bot Token Telegram",
    Default = "",
    Placeholder = "Masukkan Token Bot...",
    Callback = function(Value)
        Config.BotToken = Value
    end
})

Tabs.Notification:AddInput("ChatIDInput", {
    Title = "ID Penerima (Chat ID)",
    Default = "",
    Placeholder = "Masukkan Chat ID...",
    Callback = function(Value)
        Config.ChatID = Value
    end
})

-- =================================================================
-- 5. SETTINGS & INTERFACE MANAGER
-- =================================================================
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

-- =================================================================
-- LOGO TOGGLE [L] UI
-- =================================================================
local ToggleGui = Instance.new("ScreenGui", game.CoreGui)
ToggleGui.Name = "LIXX_Toggle"

local OpenBtn = Instance.new("TextButton", ToggleGui)
OpenBtn.Size = UDim2.fromOffset(45, 45)
OpenBtn.Position = UDim2.new(0, 15, 0.5, -22)
OpenBtn.Text = "L"
OpenBtn.TextSize = 24
OpenBtn.Font = Enum.Font.SourceSansBold
OpenBtn.BackgroundColor3 = Color3.fromRGB(35, 100, 35)
OpenBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
OpenBtn.BorderSizePixel = 2
OpenBtn.BorderColor3 = Color3.fromRGB(80, 200, 80)

OpenBtn.MouseButton1Click:Connect(function()
    Window:Minimize()
end)

Window:SelectTab(1)
