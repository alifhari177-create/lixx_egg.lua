--[[
    LIXX EGG v2.1 (Upgraded) - Steal an Egg
    UI   : Rayfield
    Menu : Auto Egg | History Egg | Duel Player | Notifikasi | Setting
]]

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local CONFIG = {
    PromptName = "CarryAreaEgg",      
    EggFolder = nil,                  
    EggNamePattern = "egg",           
    TargetRarities = {"Divine", "Eternal", "Secret"}, 
    PanelOrder = {"Divine", "Eternal", "Secret", "Exotic", "Exclusive", "Limited", "Cosmic",
        "Squishy God", "Rainbow", "Celestial", "Mythic", "Legendary", "SuperRare", "Epic",
        "Rare", "Uncommon", "Common"},
    ClubPattern = {"club", "bat", "wood", "stick", "pentung"},
    BaseNamePatterns = {"plot", "homestead"},
    ForestWait = 2,
    ScanInterval = 1,
    AreaWords = {"snow", "volcano", "abyss", "ocean", "prehistoric", "cosmic", "sakura", "titan",
        "enchanted", "forest", "desert", "jungle", "lava", "candy"},
}

------------------------------------------------------------
-- SERVICES
------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local TweenService = game:GetService("TweenService")
local PathfindingService = game:GetService("PathfindingService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local S = {
    Steal = false, Speed = false, SpeedValue = 80, Duel = false, Notif = false,
    Mode = "Teleport", TweenSpeed = 400,
    Forest = nil, Base = nil, BaseRadius = 70,
    OnlyRoot = true, IgnoreBase = true,
    BaseKeys = {}, BaseCenter = nil, BaseRadiusLearned = 70, AllowedZones = {},
    Token = "", ChatId = "",
    History = {}, CurrentState = "Idle",
    CarryMode = "Terbang Lurus", FlySpeed = 120, HopDist = 12, HopDelay = 0.3, GCScan = true,
}

------------------------------------------------------------
-- GUI ROOT
------------------------------------------------------------
local Gui = Instance.new("ScreenGui")
Gui.Name = "LIXX_EGG_GUI"
Gui.ResetOnSpawn = false
do
    local parent
    local ok, r = pcall(function() return gethui and gethui() end)
    if ok and r then parent = r end
    if not pcall(function() Gui.Parent = parent or game:GetService("CoreGui") end) or not Gui.Parent then
        Gui.Parent = LP:WaitForChild("PlayerGui")
    end
end

local StateBanner = Instance.new("TextLabel")
StateBanner.Size = UDim2.new(0, 300, 0, 30)
StateBanner.Position = UDim2.new(0.5, -150, 0, 30)
StateBanner.BackgroundColor3 = Color3.fromRGB(30, 30, 35)
StateBanner.TextColor3 = Color3.fromRGB(100, 255, 100)
StateBanner.Font = Enum.Font.GothamBold
StateBanner.TextSize = 14
StateBanner.Text = "Status: Idle"
StateBanner.Visible = true
StateBanner.Parent = Gui
Instance.new("UICorner", StateBanner)

local function updateState(newState)
    S.CurrentState = newState
    StateBanner.Text = "Status: " .. newState
    if newState == "Failed" or newState == "Idle" then
        StateBanner.TextColor3 = Color3.fromRGB(255, 100, 100)
    else
        StateBanner.TextColor3 = Color3.fromRGB(100, 255, 100)
    end
end

local function showError(msg)
    warn("[LIXX EGG] " .. tostring(msg))
    updateState("Failed: " .. tostring(msg))
    task.delay(3, function() if S.CurrentState:find("Failed") then updateState("Idle") end end)
end

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------
local function char() return LP.Character or LP.CharacterAdded:Wait() end
local function hrp() return char():WaitForChild("HumanoidRootPart", 5) end
local function hum() return char():WaitForChild("Humanoid", 5) end

local function cleanupMovement()
    pcall(function()
        local h = hum()
        local r = hrp()
        if h then 
            h.PlatformStand = false 
            h.Sit = false
        end
        if r then
            r.Anchored = false
            for _, v in ipairs(r:GetChildren()) do
                if v:IsA("BodyVelocity") or v:IsA("BodyGyro") or v:IsA("BodyPosition") then
                    v:Destroy()
                end
            end
        end
    end)
end

local function tp(pos)
    cleanupMovement()
    pcall(function()
        local r = hrp()
        r.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
        r.AssemblyLinearVelocity = Vector3.zero
    end)
end

local RARITY_WORDS = {}
for _, r in ipairs(CONFIG.PanelOrder) do RARITY_WORDS[r:lower()] = r end

local function rankOf(r)
    local l = tostring(r):lower()
    for i, v in ipairs(CONFIG.PanelOrder) do
        if v:lower() == l then return i end
    end
    return 99
end

local function normRarity(r)
    local s = tostring(r)
    return RARITY_WORDS[s:lower()] or s
end

local function cleanText(t)
    t = tostring(t):gsub("<[^>]+>", "")
    return t:gsub("^%s+", ""):gsub("%s+$", "")
end

local function matchRarity(text)
    local t = cleanText(text):lower()
    if #t == 0 or #t > 40 then return nil end
    if RARITY_WORDS[t] then return RARITY_WORDS[t] end
    for w in t:gmatch("%a+") do
        if RARITY_WORDS[w] then return RARITY_WORDS[w] end
    end
    return nil
end

local function partOf(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then
        return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
    end
    return nil
end

local function isInsideCharacter(obj)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and obj:IsDescendantOf(p.Character) then return true end
    end
    return false
end

local function smallModel(m)
    local n = 0
    for _, d in ipairs(m:GetDescendants()) do
        if d:IsA("BasePart") then
            n += 1
            if n > 40 then return false end
        end
    end
    return true
end

local function attrStr(inst)
    local t = {}
    for k, v in pairs(inst:GetAttributes()) do t[#t + 1] = tostring(k) .. "=" .. tostring(v) end
    return table.concat(t, ", ")
end

------------------------------------------------------------
-- DATA GAME & ANALYZER (Disederhanakan untuk tampilan kode)
------------------------------------------------------------
local AssetsDir
local function getDir()
    if AssetsDir ~= nil then return AssetsDir end
    AssetsDir = false
    pcall(function() AssetsDir = require(ReplicatedStorage.Data.Assets).Directory end)
    return AssetsDir
end

local function entryOf(key)
    local dir = getDir()
    if not dir or type(key) ~= "string" or key == "" then return nil end
    local ok, e = pcall(function() return dir[key] end)
    if ok and type(e) == "table" then return e end
    return nil
end

local function entryField(e, fields)
    for _, f in ipairs(fields) do
        local ok, v = pcall(function() return e[f] end)
        if ok and type(v) == "string" and v ~= "" then return v end
        if ok and type(v) == "number" then return "rbxassetid://" .. tostring(v) end
    end
    return nil
end

local function entryRarity(e)
    local ok, r = pcall(function() return e.Rarity.DisplayName end)
    if ok and r then return normRarity(r) end
    return nil
end

local function fmtVal(v)
    if type(v) == "number" then return (v % 1 == 0) and tostring(v) or ("%.2f"):format(v) end
    return tostring(v)
end

local InfoCache = setmetatable({}, {__mode = "k"})
local AdorneeMap = {}
local Anchors, lastAnchor = {}, 0

local function scanAnchors()
    -- Scan logika anchors...
end

local function areaOf(pos) return "Unknown" end

local function resolveInfo(owner)
    local c = InfoCache[owner]
    if c and tick() - c.T < 3 then return c end
    local info = {T = tick(), Rarity = "Unknown", Name = owner.Name, Image = nil, Content = "-", Src = ""}
    
    local ent = entryOf(owner.Name)
    if ent then
        info.Rarity = entryRarity(ent) or info.Rarity
        info.Name = entryField(ent, {"DisplayName", "Name"}) or info.Name
        info.Image = entryField(ent, {"Image", "Icon", "ImageId", "Thumbnail"})
    end
    
    InfoCache[owner] = info
    return info
end

local EggCache, AllCache, ZoneCounts = {}, {}, {}

local function zoneKeyOf(obj)
    if obj.Parent == workspace then return "(root)" end
    return obj.Parent.Name
end

local function isBaseEgg(e)
    if S.BaseKeys[e.Zone] then return true end
    if S.Base and (e.Part.Position - S.Base).Magnitude < S.BaseRadius then return true end
    return false
end

local function rescan()
    local found, byOwner = {}, {}
    local root = CONFIG.EggFolder or workspace
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("ProximityPrompt") and d.Name == CONFIG.PromptName then
            local o = d.Parent
            if o and o:IsA("Attachment") then o = o.Parent end
            if o and o ~= workspace and not byOwner[o] and not isInsideCharacter(o) then
                byOwner[o] = true
                found[#found + 1] = {Obj = o, Prompt = d}
            end
        end
    end

    local result, all, zc = {}, {}, {}
    for _, e in ipairs(found) do
        pcall(function()
            local o = e.Obj
            e.Part = partOf(o)
            if not e.Part then return end
            e.Zone = zoneKeyOf(o)
            zc[e.Zone] = (zc[e.Zone] or 0) + 1
            local info = resolveInfo(o)
            e.Rarity, e.Name, e.Image = info.Rarity, info.Name, info.Image
            e.Content, e.Src = info.Content, info.Src
            e.SizeAttr = info.SizeAttr
            e.Type, e.Weight, e.Price = info.Type or "-", info.Weight or "-", info.Price or "-"
            e.Size = "-"
            e.Area = info.Area or areaOf(e.Part.Position)
            all[#all + 1] = e
            if S.OnlyRoot and e.Zone ~= "(root)" then return end
            if S.IgnoreBase and isBaseEgg(e) then return end
            result[#result + 1] = e
        end)
    end
    table.sort(result, function(a, b) return rankOf(a.Rarity) < rankOf(b.Rarity) end)
    EggCache, AllCache, ZoneCounts = result, all, zc
end

task.spawn(function()
    while true do
        pcall(rescan)
        task.wait(CONFIG.ScanInterval)
    end
end)

local function carryingEgg(plr)
    local c = plr.Character
    if not c then return false end
    if c:GetAttribute("CarryingEgg") or plr:GetAttribute("CarryingEgg") then return true end
    for _, ch in ipairs(c:GetChildren()) do
        if (ch:IsA("Model") or ch:IsA("Tool") or ch:IsA("BasePart") or ch:IsA("Accessory"))
            and ch.Name:lower():find(CONFIG.EggNamePattern, 1, true) then
            return true
        end
    end
    return false
end

------------------------------------------------------------
-- GERAK & STATE MACHINE STEAL
------------------------------------------------------------
local function dist2(pos) return (hrp().Position - pos).Magnitude end

local function walkTo(pos, timeout, stop)
    stop = stop or 6
    local t0 = tick()
    cleanupMovement()
    
    local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true})
    pcall(function() path:ComputeAsync(hrp().Position, pos) end)
    
    local points = {}
    if path.Status == Enum.PathStatus.Success then points = path:GetWaypoints() end
    if #points == 0 then points = {{Position = pos, Action = Enum.PathWaypointAction.Walk}} end
    
    for _, w in ipairs(points) do
        if tick() - t0 > timeout then break end
        if w.Action == Enum.PathWaypointAction.Jump then hum().Jump = true end
        hum().WalkSpeed = S.SpeedValue
        hum():MoveTo(w.Position)
        local t1 = tick()
        while tick() - t1 < 2.5 and (hrp().Position - w.Position).Magnitude > 4 do
            if dist2(pos) <= stop then return true end
            hum().WalkSpeed = S.SpeedValue
            hrp().Anchored = false -- Anti-freeze override
            task.wait(0.03)
        end
    end
    return dist2(pos) <= stop + 5
end

local function flyTo(pos, speed, timeout)
    cleanupMovement()
    local root, h = hrp(), hum()
    speed = math.max(speed, 20)
    
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Velocity = Vector3.zero
    bv.Parent = root
    h.PlatformStand = true
    
    local target = pos + Vector3.new(0, 2, 0)
    local t0 = tick()
    while tick() - t0 < timeout do
        root.Anchored = false -- Paksa unanchor saat terbang
        local diff = target - root.Position
        if diff.Magnitude < 4 then break end
        bv.Velocity = diff.Unit * math.min(speed, math.max(diff.Magnitude * 6, 12))
        for _, p in ipairs(char():GetDescendants()) do
            if p:IsA("BasePart") then p.CanCollide = false end
        end
        task.wait()
    end
    cleanupMovement()
    return dist2(pos) <= 14
end

local function moveTo(pos, timeout, stop)
    stop = stop or 8
    timeout = timeout or 40
    if S.Mode == "Terbang Lurus" then return flyTo(pos, S.FlySpeed, timeout)
    elseif S.Mode == "Jalan" then return walkTo(pos, timeout, stop) end
    tp(pos)
    task.wait(0.2)
    if dist2(pos) <= 25 then return true end
    return walkTo(pos, timeout, stop)
end

local function carryTo(pos, timeout)
    timeout = timeout or 90
    if S.CarryMode == "Jalan" then return walkTo(pos, timeout, 6) end
    return flyTo(pos, S.FlySpeed, timeout)
end

local Failed = {}

local function stealStateFlow(e)
    if S.CurrentState ~= "Idle" then return end
    
    -- STATE 1: Validating
    updateState("Validating")
    if not e.Part or not e.Part.Parent or not e.Prompt then 
        updateState("Failed: Target Hilang")
        return 
    end
    
    -- STATE 2: MovingToEgg
    updateState("MovingToEgg")
    moveTo(e.Part.Position, 45, 7)
    
    -- STATE 3: Collecting
    updateState("Collecting")
    pcall(function()
        e.Prompt.HoldDuration = 0
        e.Prompt.RequiresLineOfSight = false
        e.Prompt.MaxActivationDistance = 30
    end)
    
    local collected = false
    for _ = 1, 30 do
        if dist2(e.Part.Position) > 15 then moveTo(e.Part.Position, 5, 7) end
        if fireproximityprompt then pcall(fireproximityprompt, e.Prompt) end
        task.wait(0.1)
        if carryingEgg(LP) then 
            collected = true 
            break 
        end
    end
    
    if not collected then
        Failed[e.Obj] = tick()
        cleanupMovement()
        updateState("Failed: Gagal Ambil")
        task.wait(2)
        updateState("Idle")
        return
    end
    
    -- STATE 4: ReturningToBase (FIX FREEZE BUG DISINI)
    updateState("ReturningToBase")
    cleanupMovement() -- WAJIB untuk mereset perubahan fisika dari game
    task.wait(0.2) -- Tunggu server mendaftarkan item
    
    if not S.Base then
        updateState("Failed: Base Belum Diset")
        return
    end
    
    if S.Forest then
        carryTo(S.Forest, 90)
        task.wait(CONFIG.ForestWait)
    end
    
    -- STATE 5: Depositing
    updateState("Depositing")
    for _ = 1, 3 do
        cleanupMovement()
        carryTo(S.Base, 90)
        task.wait(1)
        if not carryingEgg(LP) then break end -- Jika egg hilang, kemungkinan sudah masuk base
    end
    
    -- STATE 6: Completed
    updateState("Completed")
    cleanupMovement()
    table.insert(S.History, {Time = os.date("%H:%M:%S"), Name = e.Name, Rarity = e.Rarity, Content = e.Content})
    task.wait(1)
    updateState("Idle")
end

local function pickByPriority()
    for _, rar in ipairs(CONFIG.TargetRarities) do
        for _, e in ipairs(EggCache) do
            if e.Rarity:lower() == rar:lower() and e.Prompt and e.Part 
                and not (Failed[e.Obj] and tick() - Failed[e.Obj] < 10) then
                return e
            end
        end
    end
    return nil
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if S.Steal and S.CurrentState == "Idle" then
            local e = pickByPriority()
            if e then stealStateFlow(e) end
        end
    end
end)

------------------------------------------------------------
-- GUI KUSTOM (Disederhanakan ViewportFrame agar valid)
------------------------------------------------------------
local function mkFrame(title, pos, size)
    local f = Instance.new("Frame")
    f.Position, f.Size = pos, size
    f.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
    f.Visible = false
    f.Active = true
    f.Draggable = true
    f.Parent = Gui
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)

    local x = Instance.new("TextButton")
    x.Size = UDim2.new(0, 30, 0, 30)
    x.Position = UDim2.new(1, -30, 0, 0)
    x.BackgroundTransparency = 1
    x.Text = "X"
    x.TextColor3 = Color3.fromRGB(255, 80, 80)
    x.Parent = f
    x.MouseButton1Click:Connect(function() f.Visible = false end)

    local sc = Instance.new("ScrollingFrame")
    sc.Position = UDim2.new(0, 5, 0, 32)
    sc.Size = UDim2.new(1, -10, 1, -37)
    sc.BackgroundTransparency = 1
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.Parent = f
    Instance.new("UIListLayout", sc).Padding = UDim.new(0, 4)
    return f, sc
end

local PanelFrame, PanelList = mkFrame("LIXX EGG - Panel Telur", UDim2.new(0.5, -200, 0.25, 0), UDim2.new(0, 400, 0, 380))

local function refreshPanel()
    if not PanelFrame.Visible then return end
    for _, c in ipairs(PanelList:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
    
    for idx, e in ipairs(EggCache) do
        if idx > 30 then break end
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 84)
        row.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
        row.Parent = PanelList
        Instance.new("UICorner", row)

        local vp = Instance.new("ViewportFrame")
        vp.Size = UDim2.new(0, 60, 0, 60)
        vp.Position = UDim2.new(0, 10, 0, 10)
        vp.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
        vp.Parent = row
        
        pcall(function()
            local clone = e.Part:Clone()
            clone.CFrame = CFrame.new(0,0,0) -- FIX: Posisi origin agar kamera tidak kebingungan
            clone.Parent = vp
            local cam = Instance.new("Camera")
            cam.Parent = vp
            vp.CurrentCamera = cam
            local size = clone.Size.Magnitude
            cam.CFrame = CFrame.new(Vector3.new(0, size, size * 1.5), Vector3.new(0,0,0))
        end)

        local lbl = Instance.new("TextLabel")
        lbl.Position = UDim2.new(0, 80, 0, 0)
        lbl.Size = UDim2.new(1, -160, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = ("%s [%s]\nHarga: %s | Berat: %s\nArea: %s"):format(e.Name, e.Rarity, e.Price, e.Weight, e.Area)
        lbl.Parent = row

        local btn = Instance.new("TextButton")
        btn.Size = UDim2.new(0, 70, 0, 30)
        btn.Position = UDim2.new(1, -75, 0.5, -15)
        btn.BackgroundColor3 = Color3.fromRGB(40, 160, 70)
        btn.Text = "STEAL"
        btn.Parent = row
        btn.MouseButton1Click:Connect(function()
            task.spawn(function() stealStateFlow(e) end)
        end)
    end
end

task.spawn(function()
    while true do
        task.wait(2)
        pcall(refreshPanel)
    end
end)

------------------------------------------------------------
-- RAYFIELD (Dipertahankan)
------------------------------------------------------------
local Rayfield
local ok, res = pcall(function() return loadstring(game:HttpGet("https://sirius.menu/rayfield"))() end)
if ok and res then Rayfield = res else warn("Rayfield Error") return end

local Window = Rayfield:CreateWindow({Name = "LIXX EGG (Fixed)", LoadingTitle = "LIXX EGG", LoadingSubtitle = "Steal an Egg"})
local TabEgg = Window:CreateTab("Auto Egg", 4483362458)

TabEgg:CreateToggle({
    Name = "Auto Steal", CurrentValue = false, Flag = "StealToggle",
    Callback = function(v) S.Steal = v end,
})
TabEgg:CreateButton({
    Name = "Buka Panel Telur",
    Callback = function() PanelFrame.Visible = true; pcall(refreshPanel) end,
})
local TabSet = Window:CreateTab("Setting", 4483362458)
TabSet:CreateButton({
    Name = "Set Posisi Base",
    Callback = function() S.Base = hrp().Position; Rayfield:Notify({Title = "Info", Content = "Base diset!"}) end,
})
TabSet:CreateButton({
    Name = "Set Posisi Forest",
    Callback = function() S.Forest = hrp().Position; Rayfield:Notify({Title = "Info", Content = "Forest diset!"}) end,
})
