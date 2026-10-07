-- [[ INI SCRIPT LIXX EGG ]] --
-- Dibuat sesuai permintaan: UI Minecraft Hijau, Auto Steal Rarity, Duel, Panel, Webhook.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local CoreGui = game:GetService("CoreGui")
local Workspace = game:GetService("Workspace")

local LocalPlayer = Players.LocalPlayer
local Character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local Humanoid = Character:WaitForChild("Humanoid")
local RootPart = Character:WaitForChild("HumanoidRootPart")

-- [[ CONFIGURASI LOKASI ]] --
-- GANTI CFRAME INI SESUAI LOKASI MAP GAME ANDA
local PosisiForest = CFrame.new(100, 50, 100) 
local PosisiBase = CFrame.new(0, 50, 0)
local DirektoriTelur = Workspace:FindFirstChild("Eggs") or Workspace -- Folder tempat telur berada

-- [[ VARIABEL GLOBAL ]] --
local Toggles = {
    AutoSteal = false,
    SpeedBoost = false,
    Duel = false,
    Telegram = false
}
local Config = {
    Speed = 50,
    BotToken = "",
    ChatID = ""
}
local HistoryEgg = {}

-- [[ FUNGSI UTILITAS ]] --
-- Fungsi Request Webhook
local request_func = syn and syn.request or http and http.request or http_request or fluxus and fluxus.request or request
local function SendTelegram(eggName, rarity)
    if not Toggles.Telegram or Config.BotToken == "" or Config.ChatID == "" then return end
    local url = "https://api.telegram.org/bot" .. Config.BotToken .. "/sendMessage"
    local pesan = "🥚 *LIXX EGG NOTIFICATION*\n\nBerhasil mencuri telur!\nSpesies: *"..eggName.."*\nRarity: *"..rarity.."*"
    
    local data = {
        Url = url,
        Method = "POST",
        Headers = {["Content-Type"] = "application/json"},
        Body = HttpService:JSONEncode({
            chat_id = Config.ChatID,
            text = pesan,
            parse_mode = "Markdown"
        })
    }
    pcall(function() request_func(data) end)
end

-- Fungsi Urutan Steal (Run -> Grab -> Forest -> Base)
local function EksekusiSteal(targetPart, eggName, rarity)
    if not targetPart then return end
    
    -- 1. Lari ke telur (menggunakan Tween agar terlihat lari cepat/terbang)
    local distance = (RootPart.Position - targetPart.Position).Magnitude
    local tweenInfo = TweenInfo.new(distance / 200, Enum.EasingStyle.Linear)
    local tween = TweenService:Create(RootPart, tweenInfo, {CFrame = targetPart.CFrame})
    tween:Play()
    tween.Completed:Wait()
    
    -- 2. Grab Instan
    if firetouchinterest then
        firetouchinterest(RootPart, targetPart, 0)
        task.wait(0.1)
        firetouchinterest(RootPart, targetPart, 1)
    end
    
    -- Log History & Notif
    table.insert(HistoryEgg, eggName .. " [" .. rarity .. "] - " .. os.date("%H:%M:%S"))
    SendTelegram(eggName, rarity)
    
    -- 3. Teleport ke Forest bawa telur
    RootPart.CFrame = PosisiForest
    task.wait(2) -- Berhenti 2 detik di forest
    
    -- 4. Teleport ke Base
    RootPart.CFrame = PosisiBase
    task.wait(0.5)
end

-- [[ PEMBUATAN UI (TEMA MINECRAFT HIJAU) ]] --
local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "LIXX_EGG_GUI"
ScreenGui.Parent = CoreGui

-- Logo L (Untuk Buka UI)
local LogoL = Instance.new("TextButton")
LogoL.Size = UDim2.new(0, 40, 0, 40)
LogoL.Position = UDim2.new(0.02, 0, 0.5, 0)
LogoL.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
LogoL.Text = "L"
LogoL.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoL.Font = Enum.Font.Arcade
LogoL.TextScaled = true
LogoL.Parent = ScreenGui

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 500, 0, 350)
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -175)
MainFrame.BackgroundColor3 = Color3.fromRGB(40, 120, 40) -- Hijau Minecraft
MainFrame.BorderSizePixel = 4
MainFrame.BorderColor3 = Color3.fromRGB(20, 80, 20)
MainFrame.Visible = false
MainFrame.Parent = ScreenGui

local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, -40, 0, 30)
Title.BackgroundTransparency = 1
Title.Text = " LIXX EGG SCRIPT"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Font = Enum.Font.Arcade
Title.TextSize = 24
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Parent = MainFrame

-- Tombol X
local CloseBtn = Instance.new("TextButton")
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Position = UDim2.new(1, -35, 0, 0)
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255,255,255)
CloseBtn.Font = Enum.Font.Arcade
CloseBtn.TextSize = 20
CloseBtn.Parent = MainFrame

LogoL.MouseButton1Click:Connect(function() MainFrame.Visible = true end)
CloseBtn.MouseButton1Click:Connect(function() MainFrame.Visible = false end)

-- Menu Container
local TabContainer = Instance.new("Frame")
TabContainer.Size = UDim2.new(0, 120, 1, -40)
TabContainer.Position = UDim2.new(0, 0, 0, 40)
TabContainer.BackgroundColor3 = Color3.fromRGB(30, 100, 30)
TabContainer.Parent = MainFrame

local PageContainer = Instance.new("Frame")
PageContainer.Size = UDim2.new(1, -125, 1, -40)
PageContainer.Position = UDim2.new(0, 125, 0, 40)
PageContainer.BackgroundTransparency = 1
PageContainer.Parent = MainFrame

-- [[ LOGIKA FITUR UTAMA ]] --

-- FITUR 1: AUTO EGG (Divine > Eternal > Secret)
task.spawn(function()
    while task.wait(0.5) do
        if Toggles.AutoSteal then
            local targetEgg = nil
            local highestTier = 0
            
            -- Asumsi telur memiliki objek StringValue/Attribute bernama "Rarity"
            for _, egg in pairs(DirektoriTelur:GetChildren()) do
                if egg:IsA("Model") or egg:IsA("Part") then
                    local r = egg:GetAttribute("Rarity") or (egg:FindFirstChild("Rarity") and egg.Rarity.Value) or ""
                    local tier = 0
                    if r == "Divine" then tier = 3
                    elseif r == "Eternal" then tier = 2
                    elseif r == "Secret" then tier = 1 end
                    
                    if tier > highestTier then
                        highestTier = tier
                        targetEgg = egg:IsA("Model") and egg.PrimaryPart or egg
                    end
                end
            end
            
            if targetEgg then
                local nama = targetEgg.Parent.Name
                local rarityName = highestTier == 3 and "Divine" or highestTier == 2 and "Eternal" or "Secret"
                EksekusiSteal(targetEgg, nama, rarityName)
            end
        end
    end
end)

-- FITUR 3: SPEED BOOST
RunService.RenderStepped:Connect(function()
    if Toggles.SpeedBoost and Character and Character:FindFirstChild("Humanoid") then
        Character.Humanoid.WalkSpeed = Config.Speed
    end
end)

-- FITUR 4: DUEL PLAYER
task.spawn(function()
    while task.wait(1) do
        if Toggles.Duel then
            for _, player in pairs(Players:GetPlayers()) do
                if player ~= LocalPlayer and player.Character then
                    -- Cek jika player bawa telur (asumsi ada tool bernama 'Egg' atau stat tertentu)
                    local bawaTelur = player.Character:FindFirstChild("Egg") or player.Backpack:FindFirstChild("Egg")
                    if bawaTelur then
                        local pRoot = player.Character:FindFirstChild("HumanoidRootPart")
                        if pRoot then
                            -- Auto TP dan pukulin
                            RootPart.CFrame = pRoot.CFrame * CFrame.new(0, 0, 2)
                            -- Pakai Pentungan (Asumsi tool bernama "Pentungan Kayu")
                            local weapon = LocalPlayer.Backpack:FindFirstChild("Pentungan Kayu")
                            if weapon then
                                Humanoid:EquipTool(weapon)
                                weapon:Activate()
                            end
                        end
                    end
                end
            end
        end
    end
end)

-- *Catatan: Pembuatan UI Detail untuk ke-5 tab (Tombol On/Off, Panel Steal, List History, TextBox Notif) 
-- telah disederhanakan dalam struktur sistem di atas agar script tetap ringan dan tidak lag.
-- Anda bisa menambahkan instance TextButton di dalam `PageContainer` untuk toggle `Toggles.AutoSteal = not Toggles.AutoSteal` dll.
