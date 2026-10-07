-- =================================================================
-- SCRIPT NAME: LIXX EGG
-- GAME: Steal and Egg / Steal a Baby
-- AUTHOR: LIXX
-- =================================================================

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local LocalPlayer = Players.LocalPlayer

-- Configuration Defaults
local Config = {
    TelegramToken = "",
    TelegramChatID = "",
    SpeedBoost = 50,
    SpeedActive = false,
    AutoStealActive = false,
    NotifActive = false,
    EggHistory = {}
}

-- Target Rarity Priority Order
local RarityPriority = {
    ["Divine"] = 1,
    ["Eternal"] = 2,
    ["Secret"] = 3
}

-- Locations setup (Adjust CFrame according to the game map coordinates)
local ForestCFrame = CFrame.new(100, 10, 200) -- Ganti koordinat Forest sesuai map
local BaseCFrame = CFrame.new(0, 10, 0)       -- Ganti koordinat Base sesuai map

-- =================================================================
-- UI INITIALIZATION (Rayfield Style Layout matching Image)
-- =================================================================
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "LIXX EGG",
   LoadingTitle = "LIXX EGG Script Loading...",
   LoadingSubtitle = "by LIXX",
   ConfigurationSaving = {
      Enabled = true,
      FolderName = "LIXX_EGG_Config",
      FileName = "LixxConfig"
   },
   Discord = {
      Enabled = false
   },
   KeySystem = false
})

-- UI Toggle Button Logic (Logo L Floating Button)
local ScreenGui = Instance.new("ScreenGui", game.CoreGui)
local ToggleButton = Instance.new("TextButton", ScreenGui)
ToggleButton.Size = UDim2.new(0, 45, 0, 45)
ToggleButton.Position = UDim2.new(0, 10, 0.5, -22)
ToggleButton.BackgroundColor3 = Color3.fromRGB(0, 180, 0) -- Tema Hijau Minecraft
ToggleButton.Text = "L"
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.TextSize = 24
ToggleButton.Font = Enum.Font.SourceSansBold
ToggleButton.UICorner = Instance.new("UICorner", ToggleButton)

ToggleButton.MouseButton1Click:Connect(function()
    Rayfield:ToggleUI()
end)

-- =================================================================
-- TABS CREATION (5 MENUS)
-- =================================================================
local AutoEggTab = Window:CreateTab("Auto Egg", 4483362458)
local HistoryTab = Window:CreateTab("History Egg", 4483362458)
local DuelTab = Window:CreateTab("Duel Player", 4483362458)
local NotifTab = Window:CreateTab("Notification", 4483362458)
local SettingsTab = Window:CreateTab("Settings", 4483362458)

-- =================================================================
-- LOGIC & FUNCTIONS
-- =================================================================

-- Teleport Function Sequence
local function ExecuteStealSequence(eggTarget)
    if not eggTarget or not eggTarget:FindFirstChild("HumanoidRootPart") then return end
    
    local character = LocalPlayer.Character
    if not character or not character:FindFirstChild("HumanoidRootPart") then return end
    
    -- 1. Move/Teleport to Egg Position Instantly
    character.HumanoidRootPart.CFrame = eggTarget.HumanoidRootPart.CFrame
    task.wait(0.1)
    
    -- Pick up egg logic (fire proximity prompt or touch)
    if eggTarget:FindFirstChildOfClass("ProximityPrompt") then
        fireproximityprompt(eggTarget:FindFirstChildOfClass("ProximityPrompt"))
    end
    
    -- 2. Teleport to Forest & Pause 2 Seconds
    task.wait(0.2)
    character.HumanoidRootPart.CFrame = ForestCFrame
    task.wait(2)
    
    -- 3. Teleport to Base
    character.HumanoidRootPart.CFrame = BaseCFrame
    
    -- Save to History & Send Telegram Notification
    local eggName = eggTarget.Name or "Unknown Egg"
    table.insert(Config.EggHistory, os.date("%X") .. " - " .. eggName)
    
    if Config.NotifActive and Config.TelegramToken ~= "" and Config.TelegramChatID ~= "" then
        local payload = {
            chat_id = Config.TelegramChatID,
            text = "🎉 [LIXX EGG] Berhasil Mengambil Telur!\nEgg: " .. eggName .. "\nWaktu: " .. os.date("%X")
        }
        pcall(function()
            request({
                Url = "https://api.telegram.org/bot" .. Config.TelegramToken .. "/sendMessage",
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(payload)
            })
        end)
    end
end

-- Scan Spawned Eggs by Priority (Divine > Eternal > Secret)
local function GetBestEgg()
    local foundEggs = {}
    
    -- Ganti "Workspace.Eggs" sesuai lokasi folder model/telur di game
    local eggFolder = workspace:FindFirstChild("Eggs") or workspace 
    
    for _, obj in pairs(eggFolder:GetChildren()) do
        local rarity = obj:GetAttribute("Rarity") or obj.Name
        if RarityPriority[rarity] then
            table.insert(foundEggs, {Object = obj, Priority = RarityPriority[rarity]})
        end
    end
    
    table.sort(foundEggs, function(a, b) return a.Priority < b.Priority end)
    
    if #foundEggs > 0 then
        return foundEggs[1].Object
    end
    return nil
end

-- =================================================================
-- TAB 1: AUTO EGG FEATURES
-- =================================================================
AutoEggTab:CreateToggle({
   Name = "Steal On/Off",
   CurrentValue = false,
   Callback = function(Value)
      Config.AutoStealActive = Value
      task.spawn(function()
          while Config.AutoStealActive do
              local targetEgg = GetBestEgg()
              if targetEgg then
                  ExecuteStealSequence(targetEgg)
              end
              task.wait(1)
          end
      end)
   end,
})

AutoEggTab:CreateButton({
   Name = "Buka Panel Telur",
   Callback = function()
      -- Custom Panel UI untuk daftar telur berdasarkan Rarity
      local PanelGui = Instance.new("ScreenGui", game.CoreGui)
      local Frame = Instance.new("Frame", PanelGui)
      Frame.Size = UDim2.new(0, 300, 0, 400)
      Frame.Position = UDim2.new(0.5, -150, 0.5, -200)
      Frame.BackgroundColor3 = Color3.fromRGB(35, 35, 35)
      
      local CloseBtn = Instance.new("TextButton", Frame)
      CloseBtn.Size = UDim2.new(0, 30, 0, 30)
      CloseBtn.Position = UDim2.new(1, -35, 0, 5)
      CloseBtn.Text = "X"
      CloseBtn.BackgroundColor3 = Color3.fromRGB(200, 0, 0)
      CloseBtn.MouseButton1Click:Connect(function() PanelGui:Destroy() end)
      
      local Scroll = Instance.new("ScrollingFrame", Frame)
      Scroll.Size = UDim2.new(1, -20, 1, -50)
      Scroll.Position = UDim2.new(0, 10, 0, 40)
      Scroll.CanvasSize = UDim2.new(0, 0, 2, 0)
      
      local UIList = Instance.new("UIListLayout", Scroll)
      UIList.SortOrder = Enum.SortOrder.LayoutOrder
      
      local eggFolder = workspace:FindFirstChild("Eggs") or workspace
      for _, egg in pairs(eggFolder:GetChildren()) do
          if egg:IsA("Model") then
              local Row = Instance.new("Frame", Scroll)
              Row.Size = UDim2.new(1, 0, 0, 40)
              Row.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
              
              local Label = Instance.new("TextLabel", Row)
              Label.Size = UDim2.new(0.6, 0, 1, 0)
              Label.Text = egg.Name
              Label.TextColor3 = Color3.fromRGB(255, 255, 255)
              
              local StealBtn = Instance.new("TextButton", Row)
              StealBtn.Size = UDim2.new(0.35, 0, 0.8, 0)
              StealBtn.Position = UDim2.new(0.62, 0, 0.1, 0)
              StealBtn.Text = "STEAL"
              StealBtn.BackgroundColor3 = Color3.fromRGB(0, 170, 0)
              StealBtn.MouseButton1Click:Connect(function()
                  ExecuteStealSequence(egg)
              end)
          end
      end
   end,
})

AutoEggTab:CreateSlider({
   Name = "Speed Boost Value",
   Range = {16, 200},
   Increment = 1,
   Suffix = "Speed",
   CurrentValue = 50,
   Callback = function(Value)
      Config.SpeedBoost = Value
      if Config.SpeedActive and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
          LocalPlayer.Character.Humanoid.WalkSpeed = Config.SpeedBoost
      end
   end,
})

AutoEggTab:CreateToggle({
   Name = "Speed Boost On/Off",
   CurrentValue = false,
   Callback = function(Value)
      Config.SpeedActive = Value
      game:GetService("RunService").RenderStepped:Connect(function()
          if Config.SpeedActive and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
              LocalPlayer.Character.Humanoid.WalkSpeed = Config.SpeedBoost
          elseif not Config.SpeedActive and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
              LocalPlayer.Character.Humanoid.WalkSpeed = 16
          end
      end)
   end,
})

-- =================================================================
-- TAB 2: HISTORY EGG
-- =================================================================
local HistoryParagraph = HistoryTab:CreateParagraph({Title = "Riwayat Pengambilan", Content = "Belum ada riwayat."})

HistoryTab:CreateButton({
   Name = "Refresh History",
   Callback = function()
      local text = table.concat(Config.EggHistory, "\n")
      if text == "" then text = "Belum ada riwayat." end
      HistoryParagraph:Set({Title = "Riwayat Pengambilan", Content = text})
   end,
})

HistoryTab:CreateButton({
   Name = "Delete History",
   Callback = function()
      Config.EggHistory = {}
      HistoryParagraph:Set({Title = "Riwayat Pengambilan", Content = "Riwayat telah dihapus."})
   end,
})

-- =================================================================
-- TAB 3: DUEL PLAYER
-- =================================================================
DuelTab:CreateButton({
   Name = "Refresh Player List",
   Callback = function()
      -- Refresh daftar pemain di server
      for _, plr in pairs(Players:GetPlayers()) do
          if plr ~= LocalPlayer then
              local hasEgg = plr.Character and plr.Character:FindFirstChild("CarriedEgg") ~= nil
              local btnColor = hasEgg and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(255, 0, 0)
              
              DuelTab:CreateButton({
                 Name = "Steal from: " .. plr.Name .. (hasEgg and " [Bawa Egg]" or " [No Egg]"),
                 Callback = function()
                    if plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") then
                        -- Teleport & Auto Attack
                        local char = LocalPlayer.Character
                        char.HumanoidRootPart.CFrame = plr.Character.HumanoidRootPart.CFrame * CFrame.new(0,0,-2)
                        
                        -- Simulasi Pukul dengan Pentungan/Tool
                        local tool = char:FindFirstChildOfClass("Tool")
                        if tool then tool:Activate() end
                    end
                 end,
              })
          end
      end
   end,
})

-- =================================================================
-- TAB 4: NOTIFICATION
-- =================================================================
NotifTab:CreateToggle({
   Name = "Notification On/Off",
   CurrentValue = false,
   Callback = function(Value)
      Config.NotifActive = Value
   end,
})

NotifTab:CreateInput({
   Name = "Bot Token Telegram",
   PlaceholderText = "Masukkan Bot Token...",
   RemoveTextOnFocusLost = false,
   Callback = function(Text)
      Config.TelegramToken = Text
   end,
})

NotifTab:CreateInput({
   Name = "ID Penerima Telegram",
   PlaceholderText = "Masukkan Chat ID...",
   RemoveTextOnFocusLost = false,
   Callback = function(Text)
      Config.TelegramChatID = Text
   end,
})

-- =================================================================
-- TAB 5: SETTINGS
-- =================================================================
SettingsTab:CreateButton({
   Name = "Rejoin Server",
   Callback = function()
      game:GetService("TeleportService"):Teleport(game.PlaceId, LocalPlayer)
   end,
})

SettingsTab:CreateButton({
   Name = "Unload Script UI",
   Callback = function()
      Rayfield:Destroy()
      ScreenGui:Destroy()
   end,
})
