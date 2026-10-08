-- INI script LIXX EGG
local Rayfield = loadstring(game:HttpGet('https://sirius.menu/rayfield'))()

local Window = Rayfield:CreateWindow({
   Name = "INI script LIXX EGG",
   LoadingTitle = "LIXX EGG Loader",
   LoadingSubtitle = "Steal an Egg Script",
   ConfigurationSaving = {
      Enabled = false,
   },
   Discord = {
      Enabled = false
   },
   KeySystem = false
})

-- Services
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local LocalPlayer = Players.LocalPlayer
local HttpService = game:GetService("HttpService")

-- Variables
local StealEnabled = false
local SpeedBoostEnabled = false
local SpeedValue = 16
local DuelEnabled = false
local TelegramNotifEnabled = false
local TelegramToken = ""
local TelegramChatID = ""

local EggHistory = {}

-- Priority Order
local Priority = {
    ["Divine"] = 1,
    ["Eternal"] = 2,
    ["Secret"] = 3
}

-- Safe Teleport / Position Helper
local function getForestPos()
    local forest = Workspace:FindFirstChild("Forest", true) or Workspace:FindFirstChild("ForestArea", true)
    if forest then
        return forest:IsA("BasePart") and forest.Position or forest:GetPivot().Position
    end
    return Vector3.new(0, 50, 0) -- Default fallback
end

local function getBasePos()
    local base = Workspace:FindFirstChild("Base_" .. LocalPlayer.Name, true) or Workspace:FindFirstChild(LocalPlayer.Name .. "_Base", true)
    if base then
        return base:IsA("BasePart") and base.Position or base:GetPivot().Position
    end
    return LocalPlayer.Character and LocalPlayer.Character:GetPivot().Position or Vector3.new(0, 10, 0)
end

-- Teleport Method
local function teleportTo(targetPos)
    if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("HumanoidRootPart") then
        LocalPlayer.Character.HumanoidRootPart.CFrame = CFrame.new(targetPos + Vector3.new(0, 3, 0))
    end
end

-- Telegram Sender
local function sendTelegramNotif(eggName, rarity)
    if not TelegramNotifEnabled or TelegramToken == "" or TelegramChatID == "" then return end
    
    local url = "https://api.telegram.org/bot" .. TelegramToken .. "/sendMessage"
    local message = "🎉 *LIXX EGG NOTIFICATION*\n\nPlayer: " .. LocalPlayer.Name .. "\nTelur didapat: " .. eggName .. "\nRarity: " .. rarity
    
    local payload = HttpService:JSONEncode({
        chat_id = TelegramChatID,
        text = message,
        parse_mode = "Markdown"
    })

    local request = (syn and syn.request) or (http and http.request) or http_request or fluxus and fluxus.request
    if request then
        request({
            Url = url,
            Method = "POST",
            Headers = {["Content-Type"] = "application/json"},
            Body = payload
        })
    end
end

-- Dynamic Egg Scanner Algorithm
local function detectEggs()
    local foundEggs = {}
    
    -- Teleport & Scan Workspace Descendants
    for _, obj in pairs(Workspace:GetDescendants()) do
        if obj:IsA("Model") or obj:IsA("BasePart") then
            local rarity = "Unknown"
            local eggName = obj.Name
            local isEgg = false
            
            -- Check 1: Attributes
            if obj:GetAttribute("Rarity") then
                rarity = tostring(obj:GetAttribute("Rarity"))
                isEgg = true
            elseif obj:GetAttribute("Tier") then
                rarity = tostring(obj:GetAttribute("Tier"))
                isEgg = true
            end
            
            -- Check 2: ValueObjects
            local rarityVal = obj:FindFirstChild("Rarity") or obj:FindFirstChild("Tier")
            if rarityVal and rarityVal:IsA("ValueBase") then
                rarity = tostring(rarityVal.Value)
                isEgg = true
            end
            
            -- Check 3: BillboardGui Text
            for _, child in pairs(obj:GetDescendants()) do
                if child:IsA("TextLabel") then
                    local text = child.Text
                    if text:find("Divine") or text:find("Eternal") or text:find("Secret") then
                        isEgg = true
                        if text:find("Divine") then rarity = "Divine"
                        elseif text:find("Eternal") then rarity = "Eternal"
                        elseif text:find("Secret") then rarity = "Secret" end
                    end
                end
            end
            
            -- Check 4: Name Inspection
            local lowerName = obj.Name:lower()
            if lowerName:find("egg") or lowerName:find("divine") or lowerName:find("eternal") or lowerName:find("secret") then
                isEgg = true
                if lowerName:find("divine") then rarity = "Divine"
                elseif lowerName:find("eternal") then rarity = "Eternal"
                elseif lowerName:find("secret") then rarity = "Secret" end
            end
            
            if isEgg and (rarity == "Divine" or rarity == "Eternal" or rarity == "Secret") then
                table.insert(foundEggs, {
                    Object = obj,
                    Name = eggName,
                    Rarity = rarity,
                    Priority = Priority[rarity] or 99
                })
            end
        end
    end
    
    -- Sort by Priority (Divine > Eternal > Secret)
    table.sort(foundEggs, function(a, b)
        return a.Priority < b.Priority
    end)
    
    return foundEggs
end

-- Steal Action Loop
local function stealEgg(eggData)
    if not eggData or not eggData.Object then return end
    local obj = eggData.Object
    local pos = obj:IsA("BasePart") and obj.Position or obj:GetPivot().Position
    
    -- 1. Fast TP to Egg
    teleportTo(pos)
    task.wait(0.1)
    
    -- Interact / Fire Prompt
    local prompt = obj:FindFirstChildOfClass("ProximityPrompt") or obj:FindFirstChild("ProximityPrompt", true)
    if prompt and fireproximityprompt then
        fireproximityprompt(prompt)
    elseif obj:IsA("BasePart") and firetouchinterest then
        firetouchinterest(LocalPlayer.Character.HumanoidRootPart, obj, 0)
        task.wait()
        firetouchinterest(LocalPlayer.Character.HumanoidRootPart, obj, 1)
    end
    
    -- 2. Teleport to Forest area & Hold 2 seconds
    teleportTo(getForestPos())
    task.wait(2)
    
    -- 3. Teleport to Base
    teleportTo(getBasePos())
    
    -- Log History & Telegram
    table.insert(EggHistory, {Name = eggData.Name, Rarity = eggData.Rarity, Time = os.date("%X")})
    sendTelegramNotif(eggData.Name, eggData.Rarity)
end

---------------------------------------------------------
-- UI TABS
---------------------------------------------------------

-- 1. Tab Auto Egg
local TabAutoEgg = Window:CreateTab("Auto Egg", 4483362458)

TabAutoEgg:CreateToggle({
   Name = "Steal ON/OFF (Priority Divine > Eternal > Secret)",
   CurrentValue = false,
   Callback = function(Value)
      StealEnabled = Value
      task.spawn(function()
          while StealEnabled do
              local detected = detectEggs()
              if #detected > 0 then
                  stealEgg(detected[1]) -- Take highest priority egg
              end
              task.wait(1)
          end
      end)
   end,
})

TabAutoEgg:CreateButton({
   Name = "Buka Panel Telur Server",
   Callback = function()
      local PanelWindow = Rayfield:CreateWindow({
         Name = "PANEL TELUR",
         LoadingTitle = "Scanning Server...",
         KeySystem = false
      })
      local PanelTab = PanelWindow:CreateTab("Telur Tersedia", 4483362458)
      
      local eggs = detectEggs()
      for _, eggInfo in ipairs(eggs) do
          PanelTab:CreateButton({
             Name = "[" .. eggInfo.Rarity .. "] " .. eggInfo.Name,
             Callback = function()
                stealEgg(eggInfo)
             end,
          })
      end
   end,
})

TabAutoEgg:CreateSlider({
   Name = "Speed Boost",
   Range = {16, 200},
   Increment = 1,
   Suffix = "Speed",
   CurrentValue = 16,
   Callback = function(Value)
      SpeedValue = Value
      if SpeedBoostEnabled and LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
          LocalPlayer.Character.Humanoid.WalkSpeed = SpeedValue
      end
   end,
})

TabAutoEgg:CreateToggle({
   Name = "Aktifkan Speed Boost",
   CurrentValue = false,
   Callback = function(Value)
      SpeedBoostEnabled = Value
      if LocalPlayer.Character and LocalPlayer.Character:FindFirstChild("Humanoid") then
          LocalPlayer.Character.Humanoid.WalkSpeed = SpeedBoostEnabled and SpeedValue or 16
      end
   end,
})

-- 2. Tab History Egg
local TabHistory = Window:CreateTab("HISTORY EGG", 4483362458)

local HistoryLabel = TabHistory:CreateLabel("Belum ada telur yang diambil.")

TabHistory:CreateButton({
   Name = "Refresh History",
   Callback = function()
      local str = "Daftar History:\n"
      for i, item in ipairs(EggHistory) do
          str = str .. i .. ". " .. item.Name .. " (" .. item.Rarity .. ") - " .. item.Time .. "\n"
      end
      HistoryLabel:Set(str)
   end,
})

TabHistory:CreateButton({
   Name = "Delete History",
   Callback = function()
      EggHistory = {}
      HistoryLabel:Set("History telah dihapus.")
   end,
})

-- 3. Tab Duel Player
local TabDuel = Window:CreateTab("Duel Player", 4483362458)

TabDuel:CreateToggle({
   Name = "Auto Duel Player Bawa Egg",
   CurrentValue = false,
   Callback = function(Value)
      DuelEnabled = Value
      task.spawn(function()
          while DuelEnabled do
              for _, plr in pairs(Players:GetPlayers()) do
                  if plr ~= LocalPlayer and plr.Character then
                      local hasEgg = plr.Character:FindFirstChild("Egg", true) or plr.Character:GetAttribute("HasEgg")
                      if hasEgg then
                          -- Teleport to Target Player
                          while hasEgg and DuelEnabled and plr.Character and plr.Character:FindFirstChild("HumanoidRootPart") do
                              teleportTo(plr.Character.HumanoidRootPart.Position)
                              -- Simulasi pukulan / tool hit
                              local tool = LocalPlayer.Character:FindFirstChildOfClass("Tool")
                              if tool then tool:Activate() end
                              task.wait(0.1)
                              hasEgg = plr.Character:FindFirstChild("Egg", true)
                          end
                          -- Ambil telur setelah terlepas & teleport Forest -> Base
                          local nearbyEggs = detectEggs()
                          if #nearbyEggs > 0 then stealEgg(nearbyEggs[1]) end
                      end
                  end
              end
              task.wait(0.5)
          end
      end)
   end,
})

-- Refresh Player List for Steal
TabDuel:CreateButton({
   Name = "Scan Player Bawa Egg",
   Callback = function()
      for _, plr in pairs(Players:GetPlayers()) do
          if plr ~= LocalPlayer and plr.Character then
              local carryingEgg = plr.Character:FindFirstChild("Egg", true) ~= nil
              local statusColor = carryingEgg and " [Bawa Egg - HIJAU]" or " [Tidak Bawa - MERAH]"
              TabDuel:CreateButton({
                 Name = plr.Name .. statusColor,
                 Callback = function()
                    if carryingEgg and plr.Character:FindFirstChild("HumanoidRootPart") then
                        teleportTo(plr.Character.HumanoidRootPart.Position)
                    end
                 end
              })
          end
      end
   end,
})

-- 4. Tab Telegram Notification
local TabNotif = Window:CreateTab("Notifications", 4483362458)

TabNotif:CreateToggle({
   Name = "Notifikasi Telegram ON/OFF",
   CurrentValue = false,
   Callback = function(Value)
      TelegramNotifEnabled = Value
   end,
})

TabNotif:CreateInput({
   Name = "Bot Token Telegram",
   PlaceholderText = "Masukkan Bot Token...",
   RemoveTextOnFocus = false,
   Callback = function(Text)
      TelegramToken = Text
   end,
})

TabNotif:CreateInput({
   Name = "ID Penerima (Chat ID)",
   PlaceholderText = "Masukkan Chat ID Telegram...",
   RemoveTextOnFocus = false,
   Callback = function(Text)
      TelegramChatID = Text
   end,
})
