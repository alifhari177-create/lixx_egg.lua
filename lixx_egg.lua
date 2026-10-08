-- [[ STEEL AND EGG - GLASS UI SCRIPT ]] --

local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "Steel and Egg | Glass Edition",
   LoadingTitle = "Steel and Egg Hub",
   LoadingSubtitle = "by Assistant",
   ConfigurationSaving = { Enabled = false },
   Discord = { Enabled = false },
   KeySystem = false
})

-- STYLING GLASS / KACA BENING --
local MainGui = game:GetService("CoreGui"):FindFirstChild("Rayfield") or game:GetService("Players").LocalPlayer.PlayerGui:FindFirstChild("Rayfield")
if MainGui then
    for _, v in pairs(MainGui:GetDescendants()) do
        if v:IsA("Frame") or v:IsA("ScrollingFrame") then
            v.BackgroundTransparency = 0.45 -- Efek Kaca Transparan
            v.BorderSizePixel = 0
        end
    end
end

-- TAB 1: MAIN FARMING
local FarmTab = Window:CreateTab("Main Farm", 4483362458)

local AutoFarmToggle = FarmTab:CreateToggle({
   Name = "Auto Collect / Farm Eggs",
   CurrentValue = false,
   Flag = "AutoFarm",
   Callback = function(Value)
      _G.AutoFarm = Value
      task.spawn(function()
         while _G.AutoFarm do
            task.wait(0.1)
            -- Jalankan fungsi pengumpulan telur di game
            pcall(function()
               for _, egg in pairs(workspace:GetChildren()) do
                  if egg.Name:find("Egg") and egg:FindFirstChild("TouchInterest") then
                     firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, egg, 0)
                     firetouchinterest(game.Players.LocalPlayer.Character.HumanoidRootPart, egg, 1)
                  end
               end
            end)
         end
      end)
   end,
})

local AutoUpgradeToggle = FarmTab:CreateToggle({
   Name = "Auto Upgrade Stats & Tools",
   CurrentValue = false,
   Flag = "AutoUpgrade",
   Callback = function(Value)
      _G.AutoUpgrade = Value
      task.spawn(function()
         while _G.AutoUpgrade do
            task.wait(1)
            -- Menjalankan remote event upgrade otomatis jika ada
            pcall(function()
               game:GetService("ReplicatedStorage"):FindFirstChild("UpgradeEvent"):FireServer()
            end)
         end
      end)
   end,
})

-- TAB 2: EGGS & HATCHING
local HatchTab = Window:CreateTab("Egg Hatching", 4483362458)

local AutoHatchToggle = HatchTab:CreateToggle({
   Name = "Auto Hatch Selected Egg",
   CurrentValue = false,
   Flag = "AutoHatch",
   Callback = function(Value)
      _G.AutoHatch = Value
      task.spawn(function()
         while _G.AutoHatch do
            task.wait(0.5)
            pcall(function()
               game:GetService("ReplicatedStorage"):FindFirstChild("HatchEggEvent"):FireServer("BasicEgg")
            end)
         end
      end)
   end,
})

-- TAB 3: TELEPORT
local TeleportTab = Window:CreateTab("Teleport", 4483362458)

TeleportTab:CreateButton({
   Name = "Teleport to Spawn Area",
   Callback = function()
      game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(0, 10, 0)
   end,
})

TeleportTab:CreateButton({
   Name = "Teleport to Main Egg Zone",
   Callback = function()
      game.Players.LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(100, 10, 100)
   end,
})

-- TAB 4: PLAYER MODS & UTILITIES (FITUR TAMBAHAN)
local UtilityTab = Window:CreateTab("Player & Utility", 4483362458)

UtilityTab:CreateSlider({
   Name = "WalkSpeed Multiplier",
   Range = {16, 200},
   Increment = 1,
   Suffix = "Speed",
   CurrentValue = 16,
   Flag = "SpeedSlider",
   Callback = function(Value)
      game.Players.LocalPlayer.Character.Humanoid.WalkSpeed = Value
   end,
})

UtilityTab:CreateSlider({
   Name = "JumpPower Multiplier",
   Range = {50, 300},
   Increment = 5,
   Suffix = "Jump",
   CurrentValue = 50,
   Flag = "JumpSlider",
   Callback = function(Value)
      game.Players.LocalPlayer.Character.Humanoid.JumpPower = Value
   end,
})

UtilityTab:CreateToggle({
   Name = "Anti-AFK (Prevent Kick)",
   CurrentValue = true,
   Flag = "AntiAFK",
   Callback = function(Value)
      _G.AntiAFK = Value
      if Value then
         local VirtualUser = game:GetService("VirtualUser")
         game:GetService("Players").LocalPlayer.Idled:Connect(function()
            if _G.AntiAFK then
               VirtualUser:CaptureController()
               VirtualUser:ClickButton2(Vector2.new())
            end
         end)
      end
   end,
})

UtilityTab:CreateButton({
   Name = "Rejoin Server",
   Callback = function()
      game:GetService("TeleportService"):TeleportToPlaceInstance(game.PlaceId, game.JobId, game.Players.LocalPlayer)
   end,
})

Rayfield:Notify({
   Title = "Steel and Egg Script Loaded",
   Content = "UI Kaca Bening Berhasil Dimuat!",
   Duration = 5,
   Image = 4483362458,
})
