-- ==========================================
-- SCRIPT NAME: LIXX EGG
-- THEME: MINECRAFT GREEN
-- ==========================================

local CoreGui = game:GetService("CoreGui")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local player = Players.LocalPlayer

-- [!!!] VARIABEL LOKASI & FUNGSI GAME YANG HARUS DIGANTI [!!!]
local Base_CFrame = CFrame.new(0, 50, 0) -- GANTI dengan kordinat Base kamu
local Forest_CFrame = CFrame.new(100, 50, 100) -- GANTI dengan kordinat Forest
local function PukulPlayer()
    -- GANTI dengan script remote event untuk memukul (menggunakan pentungan kayu)
    -- Contoh: game:GetService("ReplicatedStorage").Remotes.Attack:FireServer()
end
local function AmbilTelur(telur_instance)
    -- GANTI dengan script remote event untuk claim telur instan
    -- Contoh: game:GetService("ReplicatedStorage").Remotes.ClaimEgg:FireServer(telur_instance)
end

-- ==========================================
-- UI SETUP (TEMA MINECRAFT / HIJAU)
-- ==========================================
local LIXX_EGG = Instance.new("ScreenGui")
LIXX_EGG.Name = "LIXX_EGG"
LIXX_EGG.Parent = CoreGui
LIXX_EGG.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

-- Tombol Logo 'L' untuk membuka menu
local LogoL = Instance.new("TextButton")
LogoL.Name = "LogoL"
LogoL.Parent = LIXX_EGG
LogoL.BackgroundColor3 = Color3.fromRGB(34, 139, 34)
LogoL.Position = UDim2.new(0, 20, 0, 20)
LogoL.Size = UDim2.new(0, 50, 0, 50)
LogoL.Font = Enum.Font.Arcade
LogoL.Text = "L"
LogoL.TextColor3 = Color3.fromRGB(255, 255, 255)
LogoL.TextSize = 30
LogoL.BorderSizePixel = 3
LogoL.BorderColor3 = Color3.fromRGB(0, 0, 0)

-- Main Frame
local MainFrame = Instance.new("Frame")
MainFrame.Name = "MainFrame"
MainFrame.Parent = LIXX_EGG
MainFrame.BackgroundColor3 = Color3.fromRGB(46, 125, 50) -- Hijau tua ala MC
MainFrame.Position = UDim2.new(0.5, -250, 0.5, -175)
MainFrame.Size = UDim2.new(0, 500, 0, 350)
MainFrame.BorderSizePixel = 4
MainFrame.BorderColor3 = Color3.fromRGB(27, 94, 32)
MainFrame.Visible = false

-- Title & Close Button
local Title = Instance.new("TextLabel")
Title.Parent = MainFrame
Title.BackgroundTransparency = 1
Title.Size = UDim2.new(1, -40, 0, 30)
Title.Font = Enum.Font.Arcade
Title.Text = " LIXX EGG HUB"
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.TextSize = 24
Title.TextXAlignment = Enum.TextXAlignment.Left

local CloseBtn = Instance.new("TextButton")
CloseBtn.Parent = MainFrame
CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
CloseBtn.Position = UDim2.new(1, -30, 0, 0)
CloseBtn.Size = UDim2.new(0, 30, 0, 30)
CloseBtn.Font = Enum.Font.Arcade
CloseBtn.Text = "X"
CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
CloseBtn.TextSize = 20
CloseBtn.BorderSizePixel = 2

-- Toggle UI Logic
LogoL.MouseButton1Click:Connect(function()
    MainFrame.Visible = not MainFrame.Visible
end)
CloseBtn.MouseButton1Click:Connect(function()
    MainFrame.Visible = false
end)

-- Menu Container
local MenuContainer = Instance.new("Frame")
MenuContainer.Parent = MainFrame
MenuContainer.BackgroundTransparency = 1
MenuContainer.Position = UDim2.new(0, 0, 0, 30)
MenuContainer.Size = UDim2.new(1, 0, 1, -30)

-- ==========================================
-- TAB SYSTEM (5 FITUR)
-- ==========================================
local Tabs = {"Auto Egg", "History Egg", "Duel Player", "Telegram", "Info"}
local TabFrames = {}
local TabButtons = {}

for i, tabName in ipairs(Tabs) do
    -- Bikin Tombol Tab
    local btn = Instance.new("TextButton")
    btn.Parent = MainFrame
    btn.BackgroundColor3 = Color3.fromRGB(56, 142, 60)
    btn.Position = UDim2.new(0, (i-1) * 100, 0, 30)
    btn.Size = UDim2.new(0, 100, 0, 25)
    btn.Font = Enum.Font.Code
    btn.Text = tabName
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.TextSize = 12
    btn.BorderSizePixel = 1
    
    -- Bikin Frame Isi Tab
    local frame = Instance.new("ScrollingFrame")
    frame.Parent = MenuContainer
    frame.BackgroundTransparency = 1
    frame.Position = UDim2.new(0, 10, 0, 35)
    frame.Size = UDim2.new(1, -20, 1, -45)
    frame.Visible = (i == 1) -- Tampilkan menu 1 default
    frame.ScrollBarThickness = 5
    
    TabFrames[tabName] = frame
    TabButtons[tabName] = btn
    
    btn.MouseButton1Click:Connect(function()
        for name, f in pairs(TabFrames) do f.Visible = false end
        frame.Visible = true
    end)
end

-- ==========================================
-- FITUR 1: AUTO EGG (Steal, Panel, Speed)
-- ==========================================
local AutoEggFrame = TabFrames["Auto Egg"]
local AutoLayout = Instance.new("UIListLayout")
AutoLayout.Parent = AutoEggFrame
AutoLayout.Padding = UDim.new(0, 10)

-- Auto Steal Toggle
local StealToggle = Instance.new("TextButton")
StealToggle.Parent = AutoEggFrame
StealToggle.Size = UDim2.new(1, 0, 0, 35)
StealToggle.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
StealToggle.Text = "Auto Steal: OFF"
StealToggle.Font = Enum.Font.Code
StealToggle.TextColor3 = Color3.new(1,1,1)
StealToggle.TextSize = 18

local isAutoSteal = false
StealToggle.MouseButton1Click:Connect(function()
    isAutoSteal = not isAutoSteal
    StealToggle.BackgroundColor3 = isAutoSteal and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
    StealToggle.Text = "Auto Steal: " .. (isAutoSteal and "ON" or "OFF")
    
    if isAutoSteal then
        task.spawn(function()
            while isAutoSteal do
                task.wait(1)
                -- [LOGIKA STEAL PRIORITAS]
                -- Sistem Prioritas: Divine -> Eternal -> Secret
                -- Karena ini dummy, logika teleportasinya seperti ini:
                -- 1. Deteksi Telur di map (Ganti 'Workspace.Eggs' dengan path game asli)
                -- 2. player.Character.HumanoidRootPart.CFrame = Telur.CFrame
                -- 3. AmbilTelur(Telur)
                -- 4. player.Character.HumanoidRootPart.CFrame = Forest_CFrame
                -- 5. task.wait(2)
                -- 6. player.Character.HumanoidRootPart.CFrame = Base_CFrame
            end
        end)
    end
end)

-- Speed Boost
local SpeedToggle = Instance.new("TextButton")
SpeedToggle.Parent = AutoEggFrame
SpeedToggle.Size = UDim2.new(1, 0, 0, 35)
SpeedToggle.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
SpeedToggle.Text = "Speed Boost: OFF (Set 50)"
SpeedToggle.Font = Enum.Font.Code
SpeedToggle.TextColor3 = Color3.new(1,1,1)
SpeedToggle.TextSize = 18

local isSpeed = false
local currentSpeed = 50 -- Default speed yg diatur
SpeedToggle.MouseButton1Click:Connect(function()
    isSpeed = not isSpeed
    SpeedToggle.BackgroundColor3 = isSpeed and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
    SpeedToggle.Text = "Speed Boost: " .. (isSpeed and "ON" or "OFF")
    
    if isSpeed and player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.WalkSpeed = currentSpeed
    elseif player.Character and player.Character:FindFirstChild("Humanoid") then
        player.Character.Humanoid.WalkSpeed = 16
    end
end)

-- Manual Steal Panel UI (Contoh 1 Item)
local PanelTitle = Instance.new("TextLabel", AutoEggFrame)
PanelTitle.Size = UDim2.new(1, 0, 0, 20)
PanelTitle.BackgroundTransparency = 1
PanelTitle.Text = "--- STEAL PANEL (Manual) ---"
PanelTitle.TextColor3 = Color3.new(1,1,1)
PanelTitle.Font = Enum.Font.Code
PanelTitle.TextSize = 14

local DummyEgg = Instance.new("Frame", AutoEggFrame)
DummyEgg.Size = UDim2.new(1, 0, 0, 40)
DummyEgg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)

local DummyName = Instance.new("TextLabel", DummyEgg)
DummyName.Size = UDim2.new(0.6, 0, 1, 0)
DummyName.BackgroundTransparency = 1
DummyName.Text = " [Divine] Dragon Egg"
DummyName.TextColor3 = Color3.new(1, 0.8, 0)
DummyName.TextXAlignment = Enum.TextXAlignment.Left

local BtnManualSteal = Instance.new("TextButton", DummyEgg)
BtnManualSteal.Size = UDim2.new(0.3, 0, 0.8, 0)
BtnManualSteal.Position = UDim2.new(0.65, 0, 0.1, 0)
BtnManualSteal.BackgroundColor3 = Color3.fromRGB(0, 150, 0)
BtnManualSteal.Text = "STEAL"
BtnManualSteal.TextColor3 = Color3.new(1,1,1)

BtnManualSteal.MouseButton1Click:Connect(function()
    -- Logika Manual Steal
    if player.Character and player.Character:FindFirstChild("HumanoidRootPart") then
        player.Character.HumanoidRootPart.CFrame = Forest_CFrame
        task.wait(2)
        player.Character.HumanoidRootPart.CFrame = Base_CFrame
        -- Panggil notif history & telegram (fungsi di bawah)
    end
end)

-- ==========================================
-- FITUR 2: HISTORY EGG
-- ==========================================
local HistoryFrame = TabFrames["History Egg"]
local HistLayout = Instance.new("UIListLayout", HistoryFrame)

local BtnDeleteHistory = Instance.new("TextButton", HistoryFrame)
BtnDeleteHistory.Size = UDim2.new(1, 0, 0, 30)
BtnDeleteHistory.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
BtnDeleteHistory.Text = "DELETE HISTORY"
BtnDeleteHistory.TextColor3 = Color3.new(1,1,1)
BtnDeleteHistory.Font = Enum.Font.Code

local HistList = Instance.new("Frame", HistoryFrame)
HistList.Size = UDim2.new(1, 0, 0, 200)
HistList.BackgroundTransparency = 1
local HistListLayout = Instance.new("UIListLayout", HistList)

BtnDeleteHistory.MouseButton1Click:Connect(function()
    for _, v in pairs(HistList:GetChildren()) do
        if v:IsA("TextLabel") then v:Destroy() end
    end
end)

local function AddHistory(nama_telur)
    local lbl = Instance.new("TextLabel", HistList)
    lbl.Size = UDim2.new(1, 0, 0, 25)
    lbl.BackgroundTransparency = 1
    lbl.Text = "[+] Berhasil mencuri: " .. nama_telur
    lbl.TextColor3 = Color3.new(0, 1, 0)
    lbl.Font = Enum.Font.Code
    lbl.TextXAlignment = Enum.TextXAlignment.Left
end

-- ==========================================
-- FITUR 3: DUEL PLAYER
-- ==========================================
local DuelFrame = TabFrames["Duel Player"]
local DuelLayout = Instance.new("UIListLayout", DuelFrame)
DuelLayout.Padding = UDim.new(0, 5)

local DuelToggle = Instance.new("TextButton", DuelFrame)
DuelToggle.Size = UDim2.new(1, 0, 0, 35)
DuelToggle.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
DuelToggle.Text = "Auto Duel (Pukul): OFF"
DuelToggle.TextColor3 = Color3.new(1,1,1)
DuelToggle.Font = Enum.Font.Code

local isAutoDuel = false
DuelToggle.MouseButton1Click:Connect(function()
    isAutoDuel = not isAutoDuel
    DuelToggle.BackgroundColor3 = isAutoDuel and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
    DuelToggle.Text = "Auto Duel (Pukul): " .. (isAutoDuel and "ON" or "OFF")
    
    if isAutoDuel then
        task.spawn(function()
            while isAutoDuel do
                task.wait(0.5)
                PukulPlayer() -- Memanggil fungsi pukul secara otomatis
            end
        end)
    end
end)

-- Tombol list player untuk Steal Duel
local function RefreshPlayerList()
    -- Clear old
    for _, v in pairs(DuelFrame:GetChildren()) do
        if v:IsA("Frame") then v:Destroy() end
    end
    
    for _, p in pairs(Players:GetPlayers()) do
        if p ~= player then
            local pFrame = Instance.new("Frame", DuelFrame)
            pFrame.Size = UDim2.new(1, 0, 0, 30)
            pFrame.BackgroundColor3 = Color3.fromRGB(40,40,40)
            
            local pName = Instance.new("TextLabel", pFrame)
            pName.Size = UDim2.new(0.6, 0, 1, 0)
            pName.BackgroundTransparency = 1
            pName.Text = p.Name
            pName.TextColor3 = Color3.new(1,1,1)
            
            local btnStealPlayer = Instance.new("TextButton", pFrame)
            btnStealPlayer.Size = UDim2.new(0.3, 0, 0.8, 0)
            btnStealPlayer.Position = UDim2.new(0.65, 0, 0.1, 0)
            
            -- LOGIKA DUMMY: Cek apakah player bawa telur
            local bawaTelur = true -- [GANTI INI DENGAN PENGECEKAN GAME ASLI]
            
            if bawaTelur then
                btnStealPlayer.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
                btnStealPlayer.Text = "STEAL"
                btnStealPlayer.MouseButton1Click:Connect(function()
                    -- Teleport ke player tersebut
                    if p.Character and p.Character:FindFirstChild("HumanoidRootPart") and player.Character then
                        player.Character.HumanoidRootPart.CFrame = p.Character.HumanoidRootPart.CFrame
                        task.wait(1)
                        PukulPlayer()
                        task.wait(0.5)
                        player.Character.HumanoidRootPart.CFrame = Forest_CFrame
                        task.wait(2)
                        player.Character.HumanoidRootPart.CFrame = Base_CFrame
                    end
                end)
            else
                btnStealPlayer.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
                btnStealPlayer.Text = "KOSONG"
            end
        end
    end
end
RefreshPlayerList() -- Panggil pertama kali

-- ==========================================
-- FITUR 4: TELEGRAM NOTIFIKASI
-- ==========================================
local TeleFrame = TabFrames["Telegram"]
local TeleLayout = Instance.new("UIListLayout", TeleFrame)
TeleLayout.Padding = UDim.new(0, 5)

local TokenInput = Instance.new("TextBox", TeleFrame)
TokenInput.Size = UDim2.new(1, 0, 0, 30)
TokenInput.PlaceholderText = "Masukkan Bot Token Telegram..."
TokenInput.Text = ""
TokenInput.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TokenInput.TextColor3 = Color3.new(1,1,1)

local IDInput = Instance.new("TextBox", TeleFrame)
IDInput.Size = UDim2.new(1, 0, 0, 30)
IDInput.PlaceholderText = "Masukkan Chat ID Penerima..."
IDInput.Text = ""
IDInput.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
IDInput.TextColor3 = Color3.new(1,1,1)

local TeleToggle = Instance.new("TextButton", TeleFrame)
TeleToggle.Size = UDim2.new(1, 0, 0, 35)
TeleToggle.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
TeleToggle.Text = "Notifikasi: OFF"
TeleToggle.TextColor3 = Color3.new(1,1,1)
TeleToggle.Font = Enum.Font.Code

local isTeleOn = false
TeleToggle.MouseButton1Click:Connect(function()
    isTeleOn = not isTeleOn
    TeleToggle.BackgroundColor3 = isTeleOn and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(150, 50, 50)
    TeleToggle.Text = "Notifikasi: " .. (isTeleOn and "ON" or "OFF")
end)

-- Fungsi kirim Webhook Telegram
local function SendTelegram(nama_telur)
    if not isTeleOn or TokenInput.Text == "" or IDInput.Text == "" then return end
    
    local url = "https://api.telegram.org/bot" .. TokenInput.Text .. "/sendMessage"
    local data = {
        ["chat_id"] = IDInput.Text,
        ["text"] = "🥚 *LIXX EGG BOT*\nBerhasil mencuri telur: *" .. nama_telur .. "*\nStatus: Aman di Base!",
        ["parse_mode"] = "Markdown"
    }
    
    -- Memerlukan Executor yang support HTTP Request (Synapse, Krnl, Fluxus dll)
    local request = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request
    if request then
        request({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = HttpService:JSONEncode(data)
        })
    end
end

-- ==========================================
-- FITUR 5: INFO / SETTINGS
-- ==========================================
local InfoFrame = TabFrames["Info"]
local InfoText = Instance.new("TextLabel", InfoFrame)
InfoText.Size = UDim2.new(1, 0, 1, 0)
InfoText.BackgroundTransparency = 1
InfoText.Text = "LIXX EGG SCRIPT\nCreated Custom for You\n\n- Tema Minecraft\n- Auto Teleport Forest -> Base\n- Prioritas: Divine > Eternal > Secret\n- Jangan lupa set CFrame di Script!"
InfoText.TextColor3 = Color3.new(1,1,1)
InfoText.Font = Enum.Font.Code
InfoText.TextSize = 14

print("LIXX EGG HUB Loaded Successfully!")
