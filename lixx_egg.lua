--[[
    LIXX EGG - Steal an Egg
    UI: Rayfield
    Menu: Auto Egg | History Egg | Duel Player | Notifikasi | Setting
    Catatan: nama object game bisa beda, atur di bagian CONFIG di bawah.
]]

------------------------------------------------------------
-- CONFIG (ubah kalau struktur map beda)
------------------------------------------------------------
local CONFIG = {
    EggFolder = nil,            -- contoh: workspace.Eggs  (nil = scan seluruh workspace)
    EggNamePattern = "egg",     -- nama object telur mengandung kata ini (huruf kecil)
    ClubPattern = {"club", "bat", "wood", "stick", "pentung"}, -- nama tool pentungan kayu
    TargetRarities = {"Divine", "Eternal", "Secret"}, -- urutan prioritas auto steal
    PanelOrder = {"Divine","Eternal","Secret","Mythic","Legendary","Epic","Rare","Uncommon","Common"},
    ForestWait = 2,
}

------------------------------------------------------------
-- SERVICES
------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local CoreGui = (gethui and gethui()) or game:GetService("CoreGui")
local LP = Players.LocalPlayer

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local S = {
    Steal = false, Speed = false, SpeedValue = 50, Duel = false, Notif = false,
    Forest = nil, Base = nil,
    Token = "", ChatId = "",
    History = {}, Busy = false,
}

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------
local function char() return LP.Character or LP.CharacterAdded:Wait() end
local function hrp() return char():WaitForChild("HumanoidRootPart") end
local function hum() return char():WaitForChild("Humanoid") end

local function tp(pos)
    pcall(function() hrp().CFrame = CFrame.new(pos + Vector3.new(0, 3, 0)) end)
end

local function rankOf(r)
    for i, v in ipairs(CONFIG.PanelOrder) do
        if v:lower() == tostring(r):lower() then return i end
    end
    return 99
end

local function rarityOf(obj)
    local r = obj:GetAttribute("Rarity") or obj:GetAttribute("Tier")
    if r then return tostring(r) end
    local rv = obj:FindFirstChild("Rarity") or obj:FindFirstChild("Tier")
    if rv and rv:IsA("ValueBase") then return tostring(rv.Value) end
    for _, name in ipairs(CONFIG.PanelOrder) do
        if obj.Name:lower():find(name:lower()) then return name end
    end
    return "Unknown"
end

local function contentOf(obj)
    local c = obj:GetAttribute("Pet") or obj:GetAttribute("Content") or obj:GetAttribute("Contents")
    if c then return tostring(c) end
    local v = obj:FindFirstChild("Pet") or obj:FindFirstChild("Content")
    if v and v:IsA("ValueBase") then return tostring(v.Value) end
    return "?"
end

local function partOf(obj)
    if obj:IsA("BasePart") then return obj end
    if obj:IsA("Model") then return obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true) end
end

local function promptOf(obj)
    return obj:FindFirstChildWhichIsA("ProximityPrompt", true)
end

local function isInsideCharacter(obj)
    for _, p in ipairs(Players:GetPlayers()) do
        if p.Character and obj:IsDescendantOf(p.Character) then return true end
    end
    return false
end

-- scan telur yang bisa diambil
local function scanEggs()
    local list = {}
    local root = CONFIG.EggFolder or workspace
    for _, o in ipairs(root:GetDescendants()) do
        if (o:IsA("Model") or o:IsA("BasePart")) and o.Name:lower():find(CONFIG.EggNamePattern)
            and not isInsideCharacter(o) then
            local pr = promptOf(o)
            local pt = partOf(o)
            if pr and pt then
                table.insert(list, {Obj = o, Prompt = pr, Part = pt, Rarity = rarityOf(o), Content = contentOf(o)})
            end
        end
    end
    table.sort(list, function(a, b) return rankOf(a.Rarity) < rankOf(b.Rarity) end)
    return list
end

local function carryingEgg(plr)
    local c = plr.Character
    if not c then return false end
    if c:GetAttribute("CarryingEgg") or plr:GetAttribute("CarryingEgg") then return true end
    for _, ch in ipairs(c:GetChildren()) do
        if (ch:IsA("Model") or ch:IsA("Tool") or ch:IsA("BasePart")) and ch.Name:lower():find(CONFIG.EggNamePattern) then
            return true
        end
    end
    return false
end

------------------------------------------------------------
-- TELEGRAM
------------------------------------------------------------
local function sendTelegram(text, imageUrl)
    if S.Token == "" or S.ChatId == "" or not httpRequest then return end
    local base = "https://api.telegram.org/bot" .. S.Token
    local ok = pcall(function()
        if imageUrl then
            httpRequest({
                Url = base .. "/sendPhoto", Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode({chat_id = S.ChatId, photo = imageUrl, caption = text}),
            })
        else
            httpRequest({
                Url = base .. "/sendMessage", Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode({chat_id = S.ChatId, text = text}),
            })
        end
    end)
    return ok
end

local function eggImageUrl(obj)
    local id = obj:GetAttribute("ImageId") or obj:GetAttribute("Image") or obj:GetAttribute("AssetId")
    if not id or not httpRequest then return nil end
    id = tostring(id):match("%d+")
    if not id then return nil end
    local ok, url = pcall(function()
        local r = httpRequest({Url = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. id ..
            "&size=420x420&format=Png", Method = "GET"})
        return HttpService:JSONDecode(r.Body).data[1].imageUrl
    end)
    return ok and url or nil
end

------------------------------------------------------------
-- HISTORY
------------------------------------------------------------
local HistoryParagraph
local function refreshHistory()
    if not HistoryParagraph then return end
    local lines = {}
    for i = #S.History, 1, -1 do
        local h = S.History[i]
        table.insert(lines, ("[%s] %s | %s | %s"):format(h.Time, h.Name, h.Rarity, h.Content))
    end
    HistoryParagraph:Set({
        Title = "History (" .. #S.History .. ")",
        Content = #lines > 0 and table.concat(lines, "\n") or "Belum ada history.",
    })
end

local function addHistory(e)
    table.insert(S.History, {
        Time = os.date("%H:%M:%S"), Name = e.Obj.Name, Rarity = e.Rarity, Content = e.Content,
    })
    refreshHistory()
    if S.Notif then
        sendTelegram(("LIXX EGG\nTelur: %s\nRarity: %s\nIsi: %s\nPlayer: %s")
            :format(e.Obj.Name, e.Rarity, e.Content, LP.Name), eggImageUrl(e.Obj))
    end
end

------------------------------------------------------------
-- STEAL CORE
------------------------------------------------------------
local function runTo(part, timeout)
    local h = hum()
    local t0 = tick()
    while tick() - t0 < (timeout or 15) do
        if not part or not part.Parent then return false end
        h:MoveTo(part.Position)
        if (hrp().Position - part.Position).Magnitude < 7 then return true end
        task.wait(0.1)
    end
    return false
end

local function grab(e)
    local pr = e.Prompt
    pcall(function() pr.HoldDuration = 0 end)
    for _ = 1, 5 do
        if fireproximityprompt then fireproximityprompt(pr) end
        task.wait(0.1)
        if carryingEgg(LP) then return true end
    end
    return carryingEgg(LP)
end

local function deliver()
    if S.Forest then tp(S.Forest) end
    task.wait(CONFIG.ForestWait)
    if S.Base then tp(S.Base) end
end

local function stealEgg(e)
    if S.Busy then return end
    S.Busy = true
    local ok = pcall(function()
        if not runTo(e.Part, 20) then return end
        if grab(e) then
            deliver()
            addHistory(e)
        end
    end)
    S.Busy = false
    return ok
end

local function pickByPriority()
    local eggs = scanEggs()
    for _, rar in ipairs(CONFIG.TargetRarities) do
        for _, e in ipairs(eggs) do
            if e.Rarity:lower() == rar:lower() then return e end
        end
    end
end

task.spawn(function()
    while true do
        task.wait(0.5)
        if S.Steal and not S.Busy then
            local e = pickByPriority()
            if e then stealEgg(e) end
        end
    end
end)

-- speed boost
RunService.Heartbeat:Connect(function()
    if S.Speed then
        local c = LP.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = S.SpeedValue end
    end
end)

------------------------------------------------------------
-- DUEL
------------------------------------------------------------
local function findClub()
    local function match(t)
        if not t:IsA("Tool") then return false end
        local n = t.Name:lower()
        for _, p in ipairs(CONFIG.ClubPattern) do if n:find(p) then return true end end
    end
    for _, t in ipairs(char():GetChildren()) do if match(t) then return t end end
    for _, t in ipairs(LP.Backpack:GetChildren()) do if match(t) then return t end end
end

local function nearestFreeEgg()
    local best, bd
    for _, e in ipairs(scanEggs()) do
        local d = (e.Part.Position - hrp().Position).Magnitude
        if not bd or d < bd then best, bd = e, d end
    end
    return best
end

local duelBusy = false
local function duelSteal(target)
    if duelBusy or S.Busy then return end
    duelBusy = true; S.Busy = true
    pcall(function()
        local club = findClub()
        if club then club.Parent = char() end
        local t0 = tick()
        while S.Duel and carryingEgg(target) and tick() - t0 < 40 do
            local tr = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
            if not tr then break end
            hrp().CFrame = tr.CFrame * CFrame.new(0, 0, 3)
            if club then club:Activate() end
            task.wait(0.1)
        end
        task.wait(0.2)
        local e = nearestFreeEgg()
        if e and (e.Part.Position - hrp().Position).Magnitude < 60 then
            hrp().CFrame = e.Part.CFrame + Vector3.new(0, 3, 0)
            if grab(e) then
                deliver()
                addHistory(e)
            end
        end
    end)
    duelBusy = false; S.Busy = false
end

------------------------------------------------------------
-- CUSTOM GUI (Panel telur, Duel list, tombol L)
------------------------------------------------------------
local Gui = Instance.new("ScreenGui")
Gui.Name = "LIXX_EGG_GUI"; Gui.ResetOnSpawn = false
Gui.Parent = CoreGui

local function mkFrame(title, pos, size)
    local f = Instance.new("Frame", Gui)
    f.Position, f.Size = pos, size
    f.BackgroundColor3 = Color3.fromRGB(25, 25, 30); f.Visible = false
    f.Active = true; f.Draggable = true
    Instance.new("UICorner", f).CornerRadius = UDim.new(0, 8)
    local t = Instance.new("TextLabel", f)
    t.Size = UDim2.new(1, -40, 0, 30); t.Position = UDim2.new(0, 10, 0, 0)
    t.BackgroundTransparency = 1; t.Text = title; t.TextColor3 = Color3.new(1, 1, 1)
    t.Font = Enum.Font.GothamBold; t.TextSize = 14; t.TextXAlignment = Enum.TextXAlignment.Left
    local x = Instance.new("TextButton", f)
    x.Size = UDim2.new(0, 30, 0, 30); x.Position = UDim2.new(1, -30, 0, 0)
    x.BackgroundTransparency = 1; x.Text = "X"; x.TextColor3 = Color3.fromRGB(255, 80, 80)
    x.Font = Enum.Font.GothamBold; x.TextSize = 16
    x.MouseButton1Click:Connect(function() f.Visible = false end)
    local sc = Instance.new("ScrollingFrame", f)
    sc.Position = UDim2.new(0, 5, 0, 32); sc.Size = UDim2.new(1, -10, 1, -37)
    sc.BackgroundTransparency = 1; sc.ScrollBarThickness = 4
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y; sc.CanvasSize = UDim2.new()
    local l = Instance.new("UIListLayout", sc); l.Padding = UDim.new(0, 4)
    return f, sc
end

local PanelFrame, PanelList = mkFrame("LIXX EGG - Panel Telur", UDim2.new(0.5, -170, 0.3, 0), UDim2.new(0, 340, 0, 320))
local DuelFrame, DuelList = mkFrame("LIXX EGG - Duel Player", UDim2.new(0.5, -150, 0.3, 0), UDim2.new(0, 300, 0, 300))

local function clear(sc)
    for _, c in ipairs(sc:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end

local function mkRowButton(parent, text, color, cb)
    local b = Instance.new("TextButton", parent)
    b.Size = UDim2.new(0, 70, 0, 28); b.Position = UDim2.new(1, -75, 0.5, -14)
    b.BackgroundColor3 = color; b.Text = text; b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold; b.TextSize = 12
    Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(cb)
    return b
end

local function refreshPanel()
    if not PanelFrame.Visible then return end
    clear(PanelList)
    for _, e in ipairs(scanEggs()) do
        local row = Instance.new("Frame", PanelList)
        row.Size = UDim2.new(1, -6, 0, 56); row.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
        Instance.new("UICorner", row)
        -- gambar mini
        local vp = Instance.new("ViewportFrame", row)
        vp.Size = UDim2.new(0, 48, 0, 48); vp.Position = UDim2.new(0, 4, 0, 4)
        vp.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
        pcall(function()
            local clone = (e.Obj:IsA("Model") and e.Obj or e.Part):Clone()
            for _, d in ipairs(clone:GetDescendants()) do
                if d:IsA("Script") or d:IsA("LocalScript") then d:Destroy() end
            end
            clone.Parent = vp
            local cam = Instance.new("Camera", vp); vp.CurrentCamera = cam
            local p = partOf(clone)
            local pos = p.Position
            cam.CFrame = CFrame.new(pos + Vector3.new(0, 1, 4) * math.max(p.Size.Magnitude, 2) / 2, pos)
        end)
        local lbl = Instance.new("TextLabel", row)
        lbl.Position = UDim2.new(0, 58, 0, 0); lbl.Size = UDim2.new(1, -140, 1, 0)
        lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12; lbl.TextWrapped = true
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = e.Obj.Name .. "\n[" .. e.Rarity .. "]\nIsi: " .. e.Content
        mkRowButton(row, "STEAL", Color3.fromRGB(40, 160, 70), function()
            task.spawn(stealEgg, e)
        end)
    end
end

local function refreshDuel()
    if not DuelFrame.Visible then return end
    clear(DuelList)
    for _, p in ipairs(Players:GetPlayers()) do
        if p ~= LP then
            local has = carryingEgg(p)
            local row = Instance.new("Frame", DuelList)
            row.Size = UDim2.new(1, -6, 0, 36); row.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
            Instance.new("UICorner", row)
            local lbl = Instance.new("TextLabel", row)
            lbl.Size = UDim2.new(1, -90, 1, 0); lbl.Position = UDim2.new(0, 8, 0, 0)
            lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.new(1, 1, 1)
            lbl.Font = Enum.Font.Gotham; lbl.TextSize = 13; lbl.Text = p.DisplayName
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            local b = mkRowButton(row, "Steal", has and Color3.fromRGB(40, 170, 70) or Color3.fromRGB(190, 40, 40), function()
                if has and S.Duel then task.spawn(duelSteal, p) end
            end)
            b.Position = UDim2.new(1, -75, 0.5, -14)
        end
    end
end

task.spawn(function()
    while true do
        task.wait(3)
        pcall(refreshPanel)
    end
end)
task.spawn(function()
    while true do
        task.wait(1.5)
        pcall(refreshDuel)
    end
end)

------------------------------------------------------------
-- RAYFIELD UI
------------------------------------------------------------
local function showError(msg)
    warn("[LIXX EGG] " .. tostring(msg))
    local t = Instance.new("TextLabel", Gui)
    t.Size = UDim2.new(0.8, 0, 0, 60); t.Position = UDim2.new(0.1, 0, 0.05, 0)
    t.BackgroundColor3 = Color3.fromRGB(120, 20, 20); t.TextColor3 = Color3.new(1, 1, 1)
    t.TextWrapped = true; t.TextSize = 14; t.Font = Enum.Font.GothamBold
    t.Text = "LIXX EGG ERROR: " .. tostring(msg)
    task.delay(15, function() t:Destroy() end)
end

local RAYFIELD_URLS = {
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/SiegeHub/Rayfield/main/source.lua",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
}
local Rayfield
for _, url in ipairs(RAYFIELD_URLS) do
    local ok, res = pcall(function()
        return loadstring(game:HttpGet(url))()
    end)
    if ok and res then Rayfield = res break end
    warn("[LIXX EGG] gagal load Rayfield dari " .. url .. " : " .. tostring(res))
end
if not Rayfield then
    showError("Rayfield gagal di-load dari semua link. Cek koneksi / coba executor lain.")
    return
end

local Window = Rayfield:CreateWindow({
    Name = "LIXX EGG",
    LoadingTitle = "LIXX EGG",
    LoadingSubtitle = "Steal an Egg",
    ConfigurationSaving = {Enabled = false},
    KeySystem = false,
})

-- 1. AUTO EGG
local TabEgg = Window:CreateTab("Auto Egg", 4483362458)
TabEgg:CreateToggle({
    Name = "Steal (Divine > Eternal > Secret)", CurrentValue = false, Flag = "StealToggle",
    Callback = function(v)
        if v and (not S.Forest or not S.Base) then
            Rayfield:Notify({Title = "LIXX EGG", Content = "Set posisi Forest & Base dulu di menu Setting!", Duration = 5})
        end
        S.Steal = v
    end,
})
TabEgg:CreateButton({
    Name = "Panel (buka panel telur)",
    Callback = function() PanelFrame.Visible = true; refreshPanel() end,
})
TabEgg:CreateSlider({
    Name = "Speed Boost", Range = {16, 300}, Increment = 1, Suffix = " speed",
    CurrentValue = 50, Flag = "SpeedSlider",
    Callback = function(v) S.SpeedValue = v end,
})
TabEgg:CreateToggle({
    Name = "Speed Boost On/Off", CurrentValue = false, Flag = "SpeedToggle",
    Callback = function(v)
        S.Speed = v
        if not v then pcall(function() hum().WalkSpeed = 16 end) end
    end,
})

-- 2. HISTORY EGG
local TabHist = Window:CreateTab("History Egg", 4483362458)
HistoryParagraph = TabHist:CreateParagraph({Title = "History (0)", Content = "Belum ada history."})
TabHist:CreateButton({
    Name = "Deleted (hapus history)",
    Callback = function() S.History = {}; refreshHistory() end,
})

-- 3. DUEL PLAYER
local TabDuel = Window:CreateTab("Duel Player", 4483362458)
TabDuel:CreateToggle({
    Name = "Duel Player On/Off", CurrentValue = false, Flag = "DuelToggle",
    Callback = function(v)
        S.Duel = v
        DuelFrame.Visible = v
        if v then refreshDuel() end
    end,
})
TabDuel:CreateParagraph({
    Title = "Cara pakai",
    Content = "Hijau = player bawa egg (bisa dipencet). Merah = tidak bawa egg.",
})

-- 4. NOTIFIKASI
local TabNotif = Window:CreateTab("Notifikasi", 4483362458)
TabNotif:CreateInput({
    Name = "Bot Token", PlaceholderText = "123456:ABC...", RemoveTextAfterFocusLost = false,
    Callback = function(t) S.Token = t:gsub("%s", "") end,
})
TabNotif:CreateInput({
    Name = "ID Penerima (Chat ID)", PlaceholderText = "123456789", RemoveTextAfterFocusLost = false,
    Callback = function(t) S.ChatId = t:gsub("%s", "") end,
})
TabNotif:CreateToggle({
    Name = "Notifikasi On/Off", CurrentValue = false, Flag = "NotifToggle",
    Callback = function(v) S.Notif = v end,
})
TabNotif:CreateButton({
    Name = "Test Kirim Notifikasi",
    Callback = function()
        sendTelegram("LIXX EGG: test notifikasi berhasil dari " .. LP.Name)
    end,
})

-- 5. SETTING
local TabSet = Window:CreateTab("Setting", 4483362458)
TabSet:CreateButton({
    Name = "Set Posisi Forest (posisi sekarang)",
    Callback = function()
        S.Forest = hrp().Position
        Rayfield:Notify({Title = "LIXX EGG", Content = "Forest tersimpan.", Duration = 3})
    end,
})
TabSet:CreateButton({
    Name = "Set Posisi Base (posisi sekarang)",
    Callback = function()
        S.Base = hrp().Position
        Rayfield:Notify({Title = "LIXX EGG", Content = "Base tersimpan.", Duration = 3})
    end,
})

------------------------------------------------------------
-- TOMBOL LOGO "L" (buka lagi UI)
------------------------------------------------------------
local L = Instance.new("TextButton", Gui)
L.Size = UDim2.new(0, 40, 0, 40); L.Position = UDim2.new(0, 10, 0.5, 0)
L.BackgroundColor3 = Color3.fromRGB(25, 25, 30); L.Text = "L"
L.TextColor3 = Color3.fromRGB(120, 200, 255); L.Font = Enum.Font.GothamBlack; L.TextSize = 24
L.Active = true; L.Draggable = true
Instance.new("UICorner", L).CornerRadius = UDim.new(1, 0)
L.MouseButton1Click:Connect(function()
    pcall(function() Rayfield:SetVisibility(true) end)
    if S.Duel then DuelFrame.Visible = true end
end)

Rayfield:Notify({Title = "LIXX EGG", Content = "Loaded! Set Forest & Base di menu Setting.", Duration = 6})
