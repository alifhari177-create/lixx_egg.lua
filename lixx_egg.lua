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
    PanelOrder = {"Divine","Eternal","Secret","Exotic","Exclusive","Limited","Cosmic","Squishy God","Rainbow","Celestial","Mythic","Legendary","SuperRare","Epic","Rare","Uncommon","Common"},
    PromptName = "CarryAreaEgg", -- nama ProximityPrompt untuk ambil telur (dari analisa game)
    ForestWait = 2,
    ScanInterval = 1,           -- detik antar scan analyzer
    Teleport = false,           -- false = jalan kaki (aman dari anti-teleport), true = teleport
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

-- ANALYZER: scan workspace tiap detik. Deteksi utama = ProximityPrompt "CarryAreaEgg"
local RARITY_WORDS = {}
for _, r in ipairs(CONFIG.PanelOrder) do RARITY_WORDS[r:lower()] = r end
local EggCache = {}
local Banner

local function cleanText(t)
    t = tostring(t):gsub("<[^>]+>", "")
    t = t:gsub("^%s+", ""):gsub("%s+$", "")
    return t
end

local function matchRarity(text)
    local t = cleanText(text):lower()
    if #t == 0 or #t > 40 then return nil end
    if RARITY_WORDS[t] then return RARITY_WORDS[t] end
    for w in t:gmatch("%a+") do
        if RARITY_WORDS[w] then return RARITY_WORDS[w] end
    end
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

local function ownerFrom(d)
    local g = d:FindFirstAncestorWhichIsA("BillboardGui") or d:FindFirstAncestorWhichIsA("SurfaceGui")
    local o = g and (g.Adornee or g.Parent) or d.Parent
    if o and o:IsA("Attachment") then o = o.Parent end
    if o and o:IsA("BasePart") and o.Parent and o.Parent:IsA("Model")
        and o.Parent ~= workspace and smallModel(o.Parent) then
        o = o.Parent
    end
    return o, g
end

-- data rarity resmi game: ReplicatedStorage.Data.Assets.Directory[kategori].Rarity.DisplayName
local AssetsDir
local function getAssetsDir()
    if AssetsDir ~= nil then return AssetsDir end
    AssetsDir = false
    pcall(function()
        AssetsDir = require(game:GetService("ReplicatedStorage").Data.Assets).Directory
    end)
    return AssetsDir
end

local function rarityFromAssets(key)
    local dir = getAssetsDir()
    if not dir or type(key) ~= "string" then return nil end
    local ok, r = pcall(function() return dir[key].Rarity.DisplayName end)
    if ok and r then return tostring(r) end
end

local function resolveRarity(owner)
    local node = owner
    for _ = 1, 3 do
        if not node or node == workspace then break end
        local r = node:GetAttribute("Rarity") or node:GetAttribute("Tier")
        if r then return tostring(r), "attribute" end
        for _, v in pairs(node:GetAttributes()) do
            if type(v) == "string" then
                local rr = rarityFromAssets(v)
                if rr then return rr, "assets:" .. v end
                if RARITY_WORDS[v:lower()] then return RARITY_WORDS[v:lower()], "attrvalue" end
            end
        end
        local rn = rarityFromAssets(node.Name)
        if rn then return rn, "assets:name" end
        for _, c in ipairs(node:GetChildren()) do
            if c:IsA("ValueBase") then
                if c.Name == "Rarity" or c.Name == "Tier" then return tostring(c.Value), "value" end
                local rv = rarityFromAssets(c.Value)
                if rv then return rv, "assets:value" end
            end
        end
        node = node.Parent
    end
    for _, d in ipairs(owner:GetDescendants()) do
        if d:IsA("TextLabel") then
            local x = matchRarity(d.Text)
            if x then return x, "text" end
        end
    end
    return "Unknown", "none"
end

local function rescan()
    local found, byOwner = {}, {}
    local root = CONFIG.EggFolder or workspace
    local function add(owner, rarity, src, gui)
        if not owner or owner == workspace or not owner:IsDescendantOf(workspace) then return nil end
        if byOwner[owner] or isInsideCharacter(owner) then return nil end
        local e = {Obj = owner, Rarity = rarity, Source = src, Gui = gui}
        byOwner[owner] = e
        table.insert(found, e)
        return e
    end
    local i = 0
    for _, d in ipairs(root:GetDescendants()) do
        i += 1
        if i % 3000 == 0 then task.wait() end
        pcall(function()
            -- 1) deteksi utama: prompt ambil telur
            if d:IsA("ProximityPrompt") and d.Name == CONFIG.PromptName then
                local o = d.Parent
                if o and o:IsA("Attachment") then o = o.Parent end
                if o and o:IsA("BasePart") and o.Parent and o.Parent:IsA("Model")
                    and o.Parent ~= workspace and smallModel(o.Parent) then
                    o = o.Parent
                end
                if o and not byOwner[o] then
                    local r, src = resolveRarity(o)
                    local e = add(o, r, "prompt/" .. src)
                    if e then e.Prompt = d end
                end
                return
            end
            -- 2) cadangan: attribute / value / teks rarity
            local r = d:GetAttribute("Rarity") or d:GetAttribute("Tier")
            if r then add(d, tostring(r), "attribute") return end
            if d:IsA("ValueBase") and (d.Name == "Rarity" or d.Name == "Tier") then
                add(d.Parent, tostring(d.Value), "value")
                return
            end
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local rr = matchRarity(d.Text)
                if rr then
                    local o, g = ownerFrom(d)
                    add(o, rr, "text", g)
                end
            end
        end)
    end
    local result = {}
    for _, e in ipairs(found) do
        pcall(function()
            local o = e.Obj
            e.Part = partOf(o) or (o:IsA("Model") and o:FindFirstChildWhichIsA("BasePart", true)) or nil
            if not e.Part then return end
            e.Prompt = e.Prompt or o:FindFirstChildWhichIsA("ProximityPrompt", true)
            if not e.Prompt and o.Parent and o.Parent ~= workspace and o.Parent:IsA("Model") then
                e.Prompt = o.Parent:FindFirstChildWhichIsA("ProximityPrompt", true)
            end
            e.Content = contentOf(o)
            e.Name = tostring(o:GetAttribute("EggName") or o:GetAttribute("DisplayName") or o:GetAttribute("Name") or "")
            local img = o:GetAttribute("ImageId") or o:GetAttribute("Image")
            if img then e.Image = tostring(img) end
            if e.Gui then
                for _, d in ipairs(e.Gui:GetDescendants()) do
                    if d:IsA("ImageLabel") and d.Image ~= "" and not e.Image then e.Image = d.Image end
                    if d:IsA("TextLabel") and e.Name == "" then
                        local t = cleanText(d.Text)
                        if #t > 0 and not matchRarity(t) and not t:find("^%d") then e.Name = t end
                    end
                end
            end
            if e.Name == "" then e.Name = o.Name end
            table.insert(result, e)
        end)
    end
    table.sort(result, function(a, b) return rankOf(a.Rarity) < rankOf(b.Rarity) end)
    EggCache = result
end

local function scanEggs() return EggCache end

task.spawn(function()
    while true do
        pcall(rescan)
        if Banner then
            local top = EggCache[1]
            Banner.Text = top and ("Tertinggi: " .. top.Name .. " [" .. top.Rarity .. "]  |  total " .. #EggCache)
                or "Analyzer: belum ada telur terdeteksi"
        end
        task.wait(CONFIG.ScanInterval or 1)
    end
end)

local function attrStr(inst)
    local t = {}
    for k, v in pairs(inst:GetAttributes()) do t[#t + 1] = k .. "=" .. tostring(v) end
    return table.concat(t, ", ")
end

local function dumpInfo()
    local out = {"== LIXX EGG DUMP ==", "Terdeteksi: " .. #EggCache}
    for i, e in ipairs(EggCache) do
        if i > 40 then break end
        out[#out + 1] = ("%s | %s | %s | src=%s | prompt=%s | img=%s"):format(
            e.Obj:GetFullName(), e.Obj.ClassName, e.Rarity, e.Source, tostring(e.Prompt ~= nil), tostring(e.Image))
    end
    out[#out + 1] = "-- Prompt '" .. CONFIG.PromptName .. "' (maks 8) --"
    local n = 0
    local names = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then
            names[d.Name] = (names[d.Name] or 0) + 1
            if d.Name == CONFIG.PromptName then
                n += 1
                if n <= 8 then
                    out[#out + 1] = d:GetFullName()
                    local node = d.Parent
                    for lvl = 1, 3 do
                        if not node or node == workspace then break end
                        local kids = {}
                        for _, c in ipairs(node:GetChildren()) do kids[#kids + 1] = c.Name .. ":" .. c.ClassName end
                        out[#out + 1] = ("  [%d] %s (%s) attr{%s} kids{%s}"):format(
                            lvl, node.Name, node.ClassName, attrStr(node), table.concat(kids, ","))
                        node = node.Parent
                    end
                end
            end
        end
    end
    out[#out + 1] = "total prompt " .. CONFIG.PromptName .. ": " .. n
    for k, v in pairs(names) do out[#out + 1] = "prompt '" .. k .. "' x" .. v end
    local c = LP.Character
    if c then
        local kids = {}
        for _, k in ipairs(c:GetChildren()) do kids[#kids + 1] = k.Name .. ":" .. k.ClassName end
        out[#out + 1] = "karakter: " .. table.concat(kids, ",") .. " attr{" .. attrStr(c) .. "}"
    end
    local txt = table.concat(out, "\n")
    if setclipboard then setclipboard(txt) end
    print(txt)
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
local PathfindingService = game:GetService("PathfindingService")

local function walkTo(pos, timeout, stopDist)
    stopDist = stopDist or 6
    local t0 = tick()
    local points = {}
    pcall(function()
        local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true})
        path:ComputeAsync(hrp().Position, pos)
        if path.Status == Enum.PathStatus.Success then
            for _, w in ipairs(path:GetWaypoints()) do points[#points + 1] = w end
        end
    end)
    if #points == 0 then
        points = {{Position = pos, Action = Enum.PathWaypointAction.Walk}}
    end
    for _, w in ipairs(points) do
        if w.Action == Enum.PathWaypointAction.Jump then hum().Jump = true end
        hum():MoveTo(w.Position)
        local t1 = tick()
        while (hrp().Position - w.Position).Magnitude > 4 and tick() - t1 < 3 do
            if (hrp().Position - pos).Magnitude <= stopDist then return true end
            task.wait(0.05)
        end
        if tick() - t0 > (timeout or 30) then break end
    end
    return (hrp().Position - pos).Magnitude <= stopDist + 4
end

local function runTo(part, timeout)
    if not part or not part.Parent then return false end
    return walkTo(part.Position, timeout or 30, 7)
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

local function goTo(pos)
    if CONFIG.Teleport then tp(pos) else walkTo(pos, 90, 6) end
end

local function deliver()
    if S.Forest then goTo(S.Forest) end
    task.wait(CONFIG.ForestWait)
    if S.Base then goTo(S.Base) end
end

local function stealEgg(e)
    if S.Busy then return end
    S.Busy = true
    local ok = pcall(function()
        if not runTo(e.Part, 45) then return end
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
            if e.Rarity:lower() == rar:lower() and e.Prompt and e.Part then return e end
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
        if t:GetAttribute("ItemType") == "Gear" then return true end
        local n = t.Name:lower()
        for _, p in ipairs(CONFIG.ClubPattern) do if n:find(p) then return true end end
    end
    for _, t in ipairs(char():GetChildren()) do if match(t) then return t end end
    for _, t in ipairs(LP.Backpack:GetChildren()) do if match(t) then return t end end
end

local function nearestFreeEgg()
    local best, bd
    for _, e in ipairs(scanEggs()) do
        if e.Prompt and e.Part then
            local d = (e.Part.Position - hrp().Position).Magnitude
            if not bd or d < bd then best, bd = e, d end
        end
    end
    return best
end

local BatRemote
local function swingAt(target, club)
    if BatRemote == nil then
        BatRemote = false
        pcall(function()
            BatRemote = game:GetService("ReplicatedStorage").Packages.Networking["RE/BatSwing/Trigger"]
        end)
    end
    if BatRemote then
        pcall(function()
            local seed = ("%d:%d:%d"):format(LP.UserId, 100, math.floor(workspace:GetServerTimeNow() * 1000))
            BatRemote:FireServer(target, seed)
        end)
    end
    if club then pcall(function() club:Activate() end) end
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
            swingAt(target, club)
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

Banner = Instance.new("TextLabel", Gui)
Banner.Size = UDim2.new(0, 300, 0, 22); Banner.Position = UDim2.new(0.5, -150, 0, 4)
Banner.BackgroundColor3 = Color3.fromRGB(25, 25, 30); Banner.BackgroundTransparency = 0.2
Banner.TextColor3 = Color3.fromRGB(255, 200, 60); Banner.Font = Enum.Font.GothamBold
Banner.TextSize = 12; Banner.Text = "Analyzer: scanning..."
Instance.new("UICorner", Banner)

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

local lastSig = ""
local function rarityColor(r)
    local k = rankOf(r)
    if k <= 3 then return "#FFC83C" elseif k <= 6 then return "#C080FF" end
    return "#FFFFFF"
end

local function refreshPanel()
    if not PanelFrame.Visible then return end
    local eggs = scanEggs()
    local parts = {}
    for _, e in ipairs(eggs) do parts[#parts + 1] = e.Obj:GetFullName() .. e.Rarity end
    local sig = table.concat(parts, "|")
    if sig == lastSig then return end
    lastSig = sig
    clear(PanelList)
    for _, e in ipairs(eggs) do
        local row = Instance.new("Frame", PanelList)
        row.Size = UDim2.new(1, -6, 0, 56); row.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
        Instance.new("UICorner", row)
        if e.Image then
            local im = Instance.new("ImageLabel", row)
            im.Size = UDim2.new(0, 48, 0, 48); im.Position = UDim2.new(0, 4, 0, 4)
            im.BackgroundColor3 = Color3.fromRGB(20, 20, 24); im.Image = e.Image
        else
            local vp = Instance.new("ViewportFrame", row)
            vp.Size = UDim2.new(0, 48, 0, 48); vp.Position = UDim2.new(0, 4, 0, 4)
            vp.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
            pcall(function()
                local clone = (e.Obj:IsA("Model") and e.Obj or e.Part):Clone()
                for _, d in ipairs(clone:GetDescendants()) do
                    if d:IsA("BaseScript") or d:IsA("BillboardGui") or d:IsA("SurfaceGui") then d:Destroy() end
                end
                clone.Parent = vp
                local cam = Instance.new("Camera", vp); vp.CurrentCamera = cam
                local p = partOf(clone)
                local pos = p.Position
                cam.CFrame = CFrame.new(pos + Vector3.new(0, 1, 4) * math.max(p.Size.Magnitude, 2) / 2, pos)
            end)
        end
        local lbl = Instance.new("TextLabel", row)
        lbl.Position = UDim2.new(0, 58, 0, 0); lbl.Size = UDim2.new(1, -140, 1, 0)
        lbl.BackgroundTransparency = 1; lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.Font = Enum.Font.Gotham; lbl.TextSize = 12; lbl.TextWrapped = true
        lbl.RichText = true; lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = e.Name .. "\n<font color=\"" .. rarityColor(e.Rarity) .. "\"><b>[" .. e.Rarity ..
            "]</b></font>\nIsi: " .. tostring(e.Content)
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
        task.wait(1)
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
TabEgg:CreateButton({
    Name = "Dump Analisa (copy ke clipboard)",
    Callback = function() dumpInfo() end,
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
