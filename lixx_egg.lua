-- =================================================================
-- SCRIPT NAME: LIXX EGG (BAC SAFE / BYPASS VERSION)
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

-- Safe Smooth Movement (Pengganti Teleport Instan agar BAC tidak Kick)
local function SafeMoveTo(targetPosition, speed)
    if not LocalPlayer.Character or not LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then return end
    local hrp = LocalPlayer.Character.HumanoidRootPart
    local distance = (targetPosition - hrp.Position).Magnitude
    local timeToTravel = math.clamp(distance / (speed or 30), 0.3, 5) -- Batas kecepatan aman

    local tweenInfo = TweenInfo.new(timeToTravel, Enum.EasingStyle.Linear, Enum.EasingDirection.Out)
    local tween = TweenService:Create(hrp, tweenInfo, {CFrame = CFrame.new(targetPosition)})
    
    -- Temporarily disable collision to prevent physics velocity detection
    for _, part in pairs(LocalPlayer.Character:GetChildren()) do
        if part:IsA("BasePart") then part.CanCollide = false end
    end
    
    tween:Play()
    tween.Completed:Wait()

    for _, part in pairs(LocalPlayer.Character:GetChildren()) do
        if part:IsA("BasePart") then part.CanCollide = true end
    end
end

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
    return Vector3.new(100, 10, 100)
end

-- Safe Steal Sequence (BAC Safe)
local function SafeStealSequence(eggTarget)
    if not eggTarget or not eggTarget:IsDescendantOf(workspace) then return end
    
    -- Smooth Walk/Fly to Egg
    SafeMoveTo(eggTarget:GetPivot().Position, Config.WalkSpeedValue)
    task.wait(0.2)

    -- Safe Trigger Interaction
    local prompt = eggTarget:FindFirstChildOfClass("ProximityPrompt") or eggTarget:FindFirstChild("ProximityPrompt", true)
    if prompt then
        fireproximityprompt(prompt)
    end
    task.wait(0.3)

    -- Smooth Move to Forest -> Wait 2s -> Smooth Move to Base
    SafeMoveTo(GetForestPosition(), 40)
    task.wait(2)
    SafeMoveTo(GetBasePosition(), 40)
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

-- UI CREATION
local Window = Fluent:CreateWindow({
    Title = "LIXX EGG (BAC SAFE)",
    SubTitle = "by LIXX",
    TabWidth = 160,
    Size = UDim2.fromOffset(580, 460),
    Acrylic = false,
    Theme = "Darker",
    MinimizeKey = Enum.KeyCode.LeftControl
})

Window.Root.BackgroundColor3 = Color3.fromRGB(20, 35, 20)

local Tabs = {
    AutoEgg = Window:AddTab({ Title = "Auto Egg", Icon = "egg" }),
    HistoryEgg = Window:AddTab({ Title = "History Egg", Icon = "history" }),
    DuelPlayer = Window:AddTab({ Title = "Duel Player", Icon = "swords" }),
    Notification = Window:AddTab({ Title = "Notification", Icon = "bell" }),
    Settings = Window:AddTab({ Title = "Settings", Icon = "settings" })
}

-- 1. AUTO EGG
Tabs.AutoEgg:AddToggle("AutoStealToggle", {
    Title = "Steal On/Off (BAC Safe)",
    Default = false,
    Callback = function(Value)
        Config.AutoSteal = Value
        task.spawn(function()
            while Config.AutoSteal do
                task.wait(1) -- Delay aman agar tidak terdeteksi spamming
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
                    SafeStealSequence(bestEgg)
                    table.insert(Config.EggHistory, {Name = bestEgg.Name, Time = os.date("%X")})
                    SendTelegramNotification(bestEgg.Name, bestEgg:GetAttribute("Rarity") or "Unknown")
                end
            end
        end)
    end
})

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
                    SafeStealSequence(egg)
                end)
            end
        end
    end
})

-- Speed Boost dibatasi max 45 agar tidak memicu BAC
local SpeedSlider = Tabs.AutoEgg:AddSlider("SpeedSlider", {
    Title = "Speed Boost Value (Max 45 untuk BAC Safe)",
    Min = 16,
    Max = 45,
    Default = 30,
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

-- 2. HISTORY EGG
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

-- 3. DUEL PLAYER
Tabs.DuelPlayer:AddButton({
    Title = "Refresh Player List",
    Callback = function()
        for _, targetPlayer in pairs(Players:GetPlayers()) do
            if targetPlayer ~= LocalPlayer then
                local hasEgg = targetPlayer.Character and targetPlayer.Character:FindFirstChild("CarriedEgg") ~= nil
                local btnColor = hasEgg and "[HIJAU - BAWA EGG]" or "[MERAH - NO EGG]"
                
                Tabs.DuelPlayer:AddButton({
                    Title = targetPlayer.Name .. " " .. btnColor,
                    Callback = function()
                        if targetPlayer.Character and targetPlayer.Character:FindFirstChild("HumanoidRootPart") then
                            SafeMoveTo(targetPlayer.Character.HumanoidRootPart.Position, Config.WalkSpeedValue)
                            
                            local club = LocalPlayer.Backpack:FindFirstChild("WoodenClub") or LocalPlayer.Character:FindFirstChild("WoodenClub")
                            if club then
                                club.Parent = LocalPlayer.Character
                                club:Activate()
                            end
                            
                            task.wait(1)
                            local droppedEgg = workspace:FindFirstChild("DroppedEgg")
                            if droppedEgg then
                                SafeStealSequence(droppedEgg)
                            end
                        end
                    end
                })
            end
        end
    end
})

-- 4. TELEGRAM NOTIFICATION
Tabs.Notification:AddToggle("NotifToggle", {
    Title = "Telegram Notification On/Off",
    Default = false,
    Callback = function(Value) Config.TelegramNotif = Value end
})

Tabs.Notification:AddInput("BotTokenInput", {
    Title = "Bot Token Telegram",
    Default = "",
    Placeholder = "Masukkan Token Bot...",
    Callback = function(Value) Config.BotToken = Value end
})

Tabs.Notification:AddInput("ChatIDInput", {
    Title = "ID Penerima (Chat ID)",
    Default = "",
    Placeholder = "Masukkan Chat ID...",
    Callback = function(Value) Config.ChatID = Value end
})

-- 5. SETTINGS
InterfaceManager:BuildInterfaceSection(Tabs.Settings)
SaveManager:BuildConfigSection(Tabs.Settings)

-- LOGO TOGGLE [L] UI
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
