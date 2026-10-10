--[[
    LIXX EGG v4 - Steal an Egg
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
    TargetRarities = {"Divine", "Eternal", "Secret"}, -- prioritas auto steal
    PanelOrder = {"Divine", "Eternal", "Secret", "Cosmic", "Mythic", "Exotic", "Exclusive", "Limited",
        "Squishy God", "Rainbow", "Celestial", "Legendary", "SuperRare", "Epic", "Rare", "Uncommon", "Common"},
    ClubPattern = {"club", "bat", "wood", "stick", "pentung"},
    BaseNamePatterns = {"plot", "homestead"},
    AreaWords = {"snow", "volcano", "abyss", "ocean", "prehistoric", "cosmic", "sakura", "titan",
        "enchanted", "forest", "desert", "jungle", "lava", "candy"},
    HazardWords = {"trap", "spike", "bear", "laser", "lava", "kill", "damage", "hazard", "saw", "mine",
        "thorn", "poison", "shock", "electric", "zap", "blade"},
    StatusWords = {"stun", "ragdoll", "freeze", "frozen", "stagger", "knock", "slow", "root", "trap", "paralyz"},
    ForestWait = 2,   -- detik berhenti di Forest
    BaseWait = 3,     -- detik diam di base setelah sampai
    ScanInterval = 1,
    MaxRetry = 15,    -- maksimal ulang ambil telur yang sama
}

------------------------------------------------------------
-- SERVICES
------------------------------------------------------------
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LP = Players.LocalPlayer

local httpRequest = (syn and syn.request) or (http and http.request) or http_request or request

------------------------------------------------------------
-- STATE
------------------------------------------------------------
local S = {
    Steal = false, Speed = false, SpeedValue = 70, FlySpeed = 450, FakeVisual = true,
    Duel = false, Notif = false, GCScan = true,
    AntiHit = false, AntiTrap = false, Flying = false,
    Forest = nil, Base = nil, BaseRadius = 70,
    OnlyRoot = true, IgnoreBase = true,
    BaseKeys = {}, BaseCenter = nil, BaseRadiusLearned = 70, AllowedZones = {},
    Token = "", ChatId = "",
    History = {}, Busy = false, Abort = false,
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

local function showError(msg)
    warn("[LIXX EGG] " .. tostring(msg))
    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(0.8, 0, 0, 44)
    t.Position = UDim2.new(0.1, 0, 0.06, 0)
    t.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
    t.TextColor3 = Color3.new(1, 1, 1)
    t.TextWrapped = true
    t.TextSize = 13
    t.Font = Enum.Font.GothamBold
    t.Text = "LIXX EGG: " .. tostring(msg)
    t.Parent = Gui
    task.delay(8, function() t:Destroy() end)
end

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------
local function char() return LP.Character or LP.CharacterAdded:Wait() end
local function hrp() return char():WaitForChild("HumanoidRootPart") end
local function hum() return char():WaitForChild("Humanoid") end

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
    return nil
end

local function nameHas(name, words)
    local l = tostring(name):lower()
    for _, w in ipairs(words) do
        if l:find(w, 1, true) then return true end
    end
    return false
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

local function fmtVal(v)
    if type(v) == "number" then
        if v % 1 == 0 then return tostring(v) end
        return ("%.2f"):format(v)
    end
    return tostring(v)
end

------------------------------------------------------------
-- DATA GAME: ReplicatedStorage.Data.Assets.Directory (data hewan: Rarity, Icon, ModelWeight, dst)
------------------------------------------------------------
local AssetsDir
local function getDir()
    if AssetsDir ~= nil then return AssetsDir end
    AssetsDir = false
    pcall(function()
        AssetsDir = require(ReplicatedStorage.Data.Assets).Directory
    end)
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

local function entryNum(e, field)
    local ok, v = pcall(function() return e[field] end)
    if ok and type(v) == "number" then return fmtVal(v) end
    return nil
end

local function entryRarity(e)
    local ok, r = pcall(function() return e.Rarity.DisplayName end)
    if ok and r then return normRarity(r) end
    ok, r = pcall(function() return e.Rarity end)
    if ok and type(r) == "string" then return normRarity(r) end
    return nil
end

local function entryEggName(e)
    local ok, v = pcall(function() return e.Egg end)
    if not ok then return nil end
    if type(v) == "string" then return v end
    if type(v) == "table" then
        for _, f in ipairs({"DisplayName", "Name", "_id", "Id"}) do
            local ok2, s = pcall(function() return v[f] end)
            if ok2 and type(s) == "string" and s ~= "" then return s end
        end
    end
    return nil
end

local function applyEntry(info, ent, key)
    local disp = entryField(ent, {"DisplayName", "Name"}) or key
    info.Rarity = info.Rarity or entryRarity(ent)
    info.Name = info.Name or disp
    info.Content = info.Content or disp
    info.Image = info.Image or entryField(ent, {"Icon", "Image", "ImageId", "Thumbnail"})
    info.Weight = info.Weight or entryNum(ent, "ModelWeight")
    info.Price = info.Price or entryNum(ent, "EarningRate")
    info.Type = info.Type or entryEggName(ent) or "Pet"
    info.Pet = key
end

------------------------------------------------------------
-- TABEL BERSAMA
------------------------------------------------------------
local EggCache, AllCache, ZoneCounts = {}, {}, {}
local Banner, DumpBox, DumpFrame, PanelFrame
local Prompts = {}
local OwnerCache = setmetatable({}, {__mode = "k"})
local InfoCache = setmetatable({}, {__mode = "k"})
local AdorneeMap = {}
local DataCache = {}
local GCRecs = {}
local Failed = {}
local GCRunning = false

local function findData(name)
    local c = DataCache[name]
    if c and tick() - c.T < 30 then return c.V end
    local v = nil
    pcall(function() v = ReplicatedStorage:FindFirstChild(name, true) end)
    DataCache[name] = {T = tick(), V = v}
    return v
end

-- wilayah: cari object bernama area (Snow, Volcano, dst), ambil yang terdekat
local Anchors, lastAnchor = {}, -999
local function scanAnchors()
    local list = {}
    local function visit(inst, depth)
        for _, c in ipairs(inst:GetChildren()) do
            if c:IsA("Model") or c:IsA("Folder") or c:IsA("BasePart") then
                if nameHas(c.Name, CONFIG.AreaWords) then
                    local pos
                    if c:IsA("BasePart") then
                        pos = c.Position
                    elseif c:IsA("Model") then
                        pos = c:GetPivot().Position
                    else
                        local bp = c:FindFirstChildWhichIsA("BasePart", true)
                        pos = bp and bp.Position
                    end
                    if pos then list[#list + 1] = {Name = c.Name, Pos = pos} end
                end
                if depth < 3 then visit(c, depth + 1) end
            end
        end
    end
    visit(workspace, 1)
    Anchors = list
end

local function areaOf(pos)
    local best, bd
    for _, a in ipairs(Anchors) do
        local d = (a.Pos - pos).Magnitude
        if not bd or d < bd then best, bd = a, d end
    end
    if best and bd < 500 then return best.Name end
    return ("%d, %d, %d"):format(pos.X, pos.Y, pos.Z)
end

-- objek di sekitar part prompt (visual telur / slot telur ada di sini)
local nearParams = OverlapParams.new()
nearParams.FilterType = Enum.RaycastFilterType.Exclude

local function nearbyNodes(part)
    local list, seen = {}, {}
    if not part then return list, seen end
    local excl = {part}
    if LP.Character then excl[#excl + 1] = LP.Character end
    nearParams.FilterDescendantsInstances = excl
    local ok, found = pcall(function()
        return workspace:GetPartBoundsInRadius(part.Position, 3.5, nearParams)
    end)
    if not ok or not found then return list, seen end
    local origin = part.Position
    table.sort(found, function(a, b)
        return (a.Position - origin).Magnitude < (b.Position - origin).Magnitude
    end)
    local function add(x)
        if x and x ~= workspace and not seen[x] then
            seen[x] = true
            list[#list + 1] = x
        end
    end
    for i = 1, math.min(#found, 5) do
        local el, lvl = found[i], 0
        while el and el ~= workspace and lvl < 3 do
            if #el:GetChildren() <= 60 then
                add(el)
                local cc = 0
                for _, c in ipairs(el:GetChildren()) do
                    cc += 1
                    if cc > 15 then break end
                    add(c)
                end
            end
            el = el.Parent
            lvl += 1
        end
    end
    return list, seen
end

------------------------------------------------------------
-- BACA DATA DARI MEMORI GAME (getgc): cari tabel yang MENUNJUK part/prompt telur ini
------------------------------------------------------------
local function addRec(recs, key, t)
    local l = recs[key]
    if not l then
        l = {}
        recs[key] = l
    end
    if #l < 4 then l[#l + 1] = t end
end

local function gcScan(items)
    if not getgc or #items == 0 then return end
    local set = {}
    for _, e in ipairs(items) do
        set[e.Part] = e.Part
        if e.Prompt then set[e.Prompt] = e.Part end
    end
    local skip = {[set] = true, [Prompts] = true, [OwnerCache] = true, [InfoCache] = true,
        [AdorneeMap] = true, [GCRecs] = true, [EggCache] = true, [AllCache] = true, [Failed] = true,
        [DataCache] = true}
    local recs = {}
    local count = 0
    local ok = pcall(function()
        for _, t in ipairs(getgc(true)) do
            if type(t) == "table" and not skip[t] then
                count += 1
                if count % 12000 == 0 then task.wait() end
                if rawget(t, "Src") == nil and rawget(t, "Obj") == nil then
                    local n = 0
                    for k, v in next, t do
                        n += 1
                        if n > 40 then break end
                        local pk = set[k]
                        if pk and type(v) == "table" then
                            addRec(recs, pk, v)
                        else
                            local pv = set[v]
                            if pv and #t == 0 then addRec(recs, pv, t) end
                        end
                    end
                end
            end
        end
    end)
    if ok then GCRecs = recs end
end

local function applyRecord(info, rec, depth)
    if type(rec) ~= "table" or depth > 2 then return end
    local n = 0
    for k, v in pairs(rec) do
        n += 1
        if n > 80 then break end
        local lk = tostring(k):lower()
        local tv = type(v)
        if tv == "table" then
            if lk:find("rarity") then
                local dn = rawget(v, "DisplayName") or rawget(v, "Name")
                if dn then info.Rarity = info.Rarity or normRarity(dn) end
            end
            applyRecord(info, v, depth + 1)
        elseif tv == "string" or tv == "number" then
            local sv = fmtVal(v)
            local ent = tv == "string" and entryOf(sv) or nil
            if ent then
                applyEntry(info, ent, sv)
            elseif lk:find("rarity") or lk:find("tier") then
                if tv == "string" then info.Rarity = info.Rarity or normRarity(sv) end
            elseif lk:find("weight") or lk:find("mass") then
                info.Weight = info.Weight or sv
            elseif lk:find("price") or lk:find("cost") or lk:find("worth") then
                info.Price = info.Price or sv
            elseif lk:find("size") or lk:find("scale") then
                info.SizeAttr = info.SizeAttr or sv
            elseif lk:find("area") or lk:find("zone") or lk:find("biome") or lk:find("region") then
                if tv == "string" then info.Area = info.Area or sv end
            elseif lk:find("image") or lk:find("icon") or lk:find("thumb") then
                info.Image = info.Image or (tv == "number" and ("rbxassetid://" .. sv) or sv)
            elseif lk:find("pet") or lk:find("content") or lk:find("reward") then
                info.Content = info.Content or sv
            elseif tv == "string" and (lk:find("category") or lk:find("species") or lk:find("type")) then
                info.Type = info.Type or sv
            end
        end
    end
end

------------------------------------------------------------
-- RESOLVE INFO TELUR
------------------------------------------------------------
local function resolveInfo(owner, prompt)
    local c = InfoCache[owner]
    if c and tick() - c.T < 5 then return c end

    local info = {T = tick(), Src = ""}
    local part = partOf(owner)

    -- 1) teks prompt (ObjectText / ActionText)
    if prompt then
        local ot, at = "", ""
        pcall(function()
            ot = prompt.ObjectText
            at = prompt.ActionText
        end)
        info.PromptText = tostring(ot) .. " | " .. tostring(at)
        for _, t in ipairs({ot, at}) do
            t = cleanText(t)
            if #t > 0 then
                local ent = entryOf(t)
                if ent then
                    applyEntry(info, ent, t)
                    info.Src = info.Src .. "prompt:data "
                end
                local rr = matchRarity(t)
                if rr then
                    info.Rarity = info.Rarity or rr
                    info.Src = info.Src .. "prompt:rarity "
                end
            end
        end
        local o2 = cleanText(ot)
        if #o2 > 0 and #o2 <= 40 then info.EggLabel = o2 end
    end

    -- 2) kumpulkan node: egg, sekitar egg, GUI yang menempel
    local nodes = {owner}
    local a = owner.Parent
    for _ = 1, 2 do
        if a and a ~= workspace and a ~= game then
            nodes[#nodes + 1] = a
            a = a.Parent
        end
    end
    local n = 0
    for _, d in ipairs(owner:GetDescendants()) do
        n += 1
        if n > 120 then break end
        nodes[#nodes + 1] = d
    end
    local nearList, nearSet = nearbyNodes(part)
    for _, x in ipairs(nearList) do nodes[#nodes + 1] = x end

    local base = #nodes
    for idx = 1, base do
        local gl = AdorneeMap[nodes[idx]]
        if gl then
            for _, g in ipairs(gl) do
                nodes[#nodes + 1] = g
                local cnt = 0
                for _, dd in ipairs(g:GetDescendants()) do
                    cnt += 1
                    if cnt > 40 then break end
                    nodes[#nodes + 1] = dd
                end
                info.Src = info.Src .. "gui "
            end
        end
    end
    if #owner.Name >= 4 and owner.Name ~= "SmartPromptPart" and (owner.Name:find("%d") or #owner.Name >= 12) then
        local ex = findData(owner.Name)
        if ex then
            info.Src = info.Src .. "RS:" .. ex.Name .. " "
            nodes[#nodes + 1] = ex
            local cnt = 0
            for _, dd in ipairs(ex:GetDescendants()) do
                cnt += 1
                if cnt > 40 then break end
                nodes[#nodes + 1] = dd
            end
        end
    end

    -- 3) baca nilai dari semua node
    for _, node in ipairs(nodes) do
        for k, v in pairs(node:GetAttributes()) do
            local lk = tostring(k):lower()
            if not info.Area and type(v) == "string" and v ~= ""
                and (lk:find("area") or lk:find("zone") or lk:find("biome") or lk:find("world")
                    or lk:find("location") or lk:find("region")) then
                info.Area = v
            end
            if type(v) ~= "table" then
                if not info.Weight and (lk:find("weight") or lk:find("mass")) then info.Weight = fmtVal(v) end
                if not info.Price and (lk:find("price") or lk:find("cost") or lk:find("worth")) then
                    info.Price = fmtVal(v)
                end
                if not info.SizeAttr and (lk:find("size") or lk:find("scale")) then info.SizeAttr = fmtVal(v) end
                if not info.Type and type(v) == "string"
                    and (lk:find("type") or lk:find("species") or lk:find("category")) then
                    info.Type = v
                end
            end
            if type(v) == "string" and v ~= "" then
                local ent = entryOf(v)
                if ent then
                    applyEntry(info, ent, v)
                    info.Src = info.Src .. "assets:" .. v .. " "
                elseif lk:find("rarity") or lk:find("tier") then
                    info.Rarity = info.Rarity or normRarity(v)
                    info.Src = info.Src .. "attr:" .. tostring(k) .. " "
                elseif lk:find("pet") or lk:find("content") then
                    info.Content = info.Content or v
                elseif lk:find("name") then
                    info.Name = info.Name or v
                end
            elseif (lk:find("rarity") or lk:find("tier")) and v ~= nil and type(v) ~= "table" then
                info.Rarity = info.Rarity or normRarity(v)
            end
        end
        if node:IsA("ValueBase") then
            local lk = node.Name:lower()
            if lk:find("rarity") or lk:find("tier") then
                info.Rarity = info.Rarity or normRarity(node.Value)
                info.Src = info.Src .. "value "
            elseif lk:find("weight") or lk:find("mass") then
                info.Weight = info.Weight or fmtVal(node.Value)
            elseif lk:find("price") or lk:find("cost") or lk:find("worth") then
                info.Price = info.Price or fmtVal(node.Value)
            elseif type(node.Value) == "string" then
                local ent = entryOf(node.Value)
                if ent then applyEntry(info, ent, node.Value) end
            end
        end
        if node == owner or nearSet[node] then
            local ent = entryOf(node.Name)
            if ent then
                applyEntry(info, ent, node.Name)
                info.Src = info.Src .. "near:" .. node.Name .. " "
            end
            if node.Name:lower():find("egg", 1, true) then
                local rn = matchRarity(node.Name)
                if rn then
                    info.Rarity = info.Rarity or rn
                    info.Src = info.Src .. "near:rarity "
                end
                if node.Name ~= "SmartPromptPart" then info.EggLabel = info.EggLabel or node.Name end
            end
            local sa, sn = node.Name:match("_([^_:]+):Slot_(%d+)$")
            if sa then
                info.AreaFromSlot = sa
                info.Slot = sn
            end
        end
    end

    -- 4) data dari memori game
    local recs = GCRecs[part]
    if recs then
        info.Src = info.Src .. "gc "
        for _, r in ipairs(recs) do pcall(applyRecord, info, r, 0) end
    end

    -- 5) teks & gambar GUI
    for _, node in ipairs(nodes) do
        if node:IsA("TextLabel") then
            local t = cleanText(node.Text)
            if #t > 0 then
                local r = matchRarity(t)
                if r then
                    info.Rarity = info.Rarity or r
                    info.Src = info.Src .. "text "
                elseif not info.Name and not t:find("^[%d%p%s]+$") then
                    info.Name = t
                end
            end
        elseif node:IsA("ImageLabel") and node.Image ~= "" then
            info.Image = info.Image or node.Image
        end
    end

    info.Rarity = info.Rarity or "Unknown"
    if not info.Name then
        if info.EggLabel then
            info.Name = info.EggLabel
        elseif info.Slot then
            info.Name = ("Egg %s #%s"):format(info.AreaFromSlot or "?", info.Slot)
        else
            info.Name = "Egg"
        end
    end
    info.Content = info.Content or "-"
    InfoCache[owner] = info
    return info
end

------------------------------------------------------------
-- ANALYZER
------------------------------------------------------------
local PromptRoot = CONFIG.EggFolder or workspace

local function trackPrompt(d)
    if d:IsA("ProximityPrompt") and d.Name == CONFIG.PromptName then Prompts[d] = true end
end
PromptRoot.DescendantAdded:Connect(trackPrompt)
PromptRoot.DescendantRemoving:Connect(function(d) Prompts[d] = nil end)
task.spawn(function()
    local i = 0
    for _, d in ipairs(PromptRoot:GetDescendants()) do
        trackPrompt(d)
        i += 1
        if i % 4000 == 0 then task.wait() end
    end
end)

local function ownerOfPrompt(d)
    local o = OwnerCache[d]
    if o and o.Parent then return o end
    o = d.Parent
    if o and o:IsA("Attachment") then o = o.Parent end
    if o and o:IsA("BasePart") and o.Parent and o.Parent:IsA("Model")
        and o.Parent ~= workspace and smallModel(o.Parent) then
        o = o.Parent
    end
    OwnerCache[d] = o
    return o
end

local function zoneKeyOf(obj)
    if obj.Parent == workspace then return "(root)" end
    local segs = {}
    for seg in obj:GetFullName():gmatch("[^%.]+") do segs[#segs + 1] = seg end
    if segs[1] == "Workspace" then table.remove(segs, 1) end
    table.remove(segs)
    while #segs > 1 do
        local last = segs[#segs]
        if last:find("%d") or #last > 20 or last:find("%-") then table.remove(segs) else break end
    end
    if #segs == 0 then return "(root)" end
    return table.concat(segs, ".")
end

local function isBaseEgg(e)
    if e.Zone and S.BaseKeys[e.Zone] then return true end
    if S.BaseCenter and (e.Part.Position - S.BaseCenter).Magnitude < S.BaseRadiusLearned then return true end
    if S.Base and (e.Part.Position - S.Base).Magnitude < S.BaseRadius then return true end
    local node = e.Obj
    for _ = 1, 6 do
        if not node or node == workspace then break end
        local nm = node.Name:lower()
        for _, pat in ipairs(CONFIG.BaseNamePatterns) do
            if nm:find(pat, 1, true) then return true end
        end
        if nm == LP.Name:lower() or nm == LP.DisplayName:lower() then return true end
        for _, v in pairs(node:GetAttributes()) do
            if v == LP.UserId or v == LP.Name or v == LP.DisplayName then return true end
        end
        node = node.Parent
    end
    return false
end

local lastAdornee = -999
local function rescan()
    if tick() - lastAnchor > 60 then
        lastAnchor = tick()
        pcall(scanAnchors)
    end
    if tick() - lastAdornee > 3 then
        lastAdornee = tick()
        local amap = {}
        pcall(function()
            for _, g in ipairs(LP.PlayerGui:GetDescendants()) do
                if (g:IsA("BillboardGui") or g:IsA("SurfaceGui")) and g.Adornee then
                    local l = amap[g.Adornee]
                    if not l then
                        l = {}
                        amap[g.Adornee] = l
                    end
                    l[#l + 1] = g
                end
            end
        end)
        AdorneeMap = amap
    end

    local found, byOwner = {}, {}
    for d in pairs(Prompts) do
        if d.Parent and d:IsDescendantOf(workspace) then
            local o = ownerOfPrompt(d)
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
            local info = resolveInfo(o, e.Prompt)
            e.Rarity, e.Name, e.Image = info.Rarity, info.Name, info.Image
            e.Content, e.Src, e.PromptText = info.Content, info.Src, info.PromptText
            e.Type, e.Weight, e.Price = info.Type or "-", info.Weight or "-", info.Price or "-"
            e.SizeAttr = info.SizeAttr
            local okS, sz = pcall(function()
                if o:IsA("Model") then return o:GetExtentsSize() end
                return e.Part.Size
            end)
            e.Size = (okS and sz) and ("%.1f x %.1f x %.1f"):format(sz.X, sz.Y, sz.Z) or "-"
            e.Area = info.Area or info.AreaFromSlot or areaOf(e.Part.Position)
            all[#all + 1] = e
            if S.OnlyRoot and e.Zone ~= "(root)" then return end
            if S.IgnoreBase and isBaseEgg(e) then return end
            if next(S.AllowedZones) and not S.AllowedZones[e.Zone] then return end
            result[#result + 1] = e
        end)
    end
    table.sort(result, function(a, b)
        local ra, rb = rankOf(a.Rarity), rankOf(b.Rarity)
        if ra ~= rb then return ra < rb end
        return a.Name < b.Name
    end)
    EggCache, AllCache, ZoneCounts = result, all, zc
end

task.spawn(function()
    while true do
        local ok, err = pcall(rescan)
        if not ok then warn("[LIXX EGG] scan error: " .. tostring(err)) end
        if Banner then
            local top = EggCache[1]
            local txt
            if top then
                txt = "Tertinggi: " .. top.Name .. " [" .. top.Rarity .. "] | total " .. #EggCache
            else
                txt = "Analyzer: tidak ada telur (semua " .. #AllCache .. " terfilter)"
            end
            if GCRunning then txt = txt .. " | membaca data..." end
            Banner.Text = txt
        end
        task.wait(CONFIG.ScanInterval)
    end
end)

local lastGC = -999
local function runGC()
    if not getgc or #AllCache == 0 or GCRunning then return end
    GCRunning = true
    lastGC = tick()
    pcall(gcScan, AllCache)
    InfoCache = setmetatable({}, {__mode = "k"})
    GCRunning = false
end

------------------------------------------------------------
-- DUMP / KALIBRASI
------------------------------------------------------------
local function describe(inst, depth)
    local kids = {}
    for _, c in ipairs(inst:GetChildren()) do
        kids[#kids + 1] = c.Name .. ":" .. c.ClassName
        if #kids >= 12 then
            kids[#kids + 1] = "..."
            break
        end
    end
    return string.rep("  ", depth) .. inst.Name .. " (" .. inst.ClassName .. ") attr{" .. attrStr(inst)
        .. "} kids{" .. table.concat(kids, ",") .. "}"
end

local function dumpTable(t, out, indent, budget, depth)
    if depth > 3 then return end
    for k, v in pairs(t) do
        if budget.n <= 0 then return end
        budget.n -= 1
        if type(v) == "table" then
            out[#out + 1] = string.rep("  ", indent) .. tostring(k) .. " = {"
            dumpTable(v, out, indent + 1, budget, depth + 1)
            out[#out + 1] = string.rep("  ", indent) .. "}"
        else
            out[#out + 1] = string.rep("  ", indent) .. tostring(k) .. " = " .. tostring(v)
        end
    end
end

local function dumpFolder(name, out)
    local f = workspace:FindFirstChild(name)
    if not f then
        out[#out + 1] = "FOLDER " .. name .. ": (tidak ada)"
        return
    end
    local kids = f:GetChildren()
    out[#out + 1] = ("FOLDER %s: %d anak | attr{%s}"):format(name, #kids, attrStr(f))
    for i, c in ipairs(kids) do
        if i > 5 then break end
        out[#out + 1] = describe(c, 1)
        local n = 0
        for _, d in ipairs(c:GetDescendants()) do
            n += 1
            if n > 5 then break end
            out[#out + 1] = describe(d, 2)
        end
    end
end

local function dumpInfo()
    if DumpBox then DumpBox.Text = "Memproses data game, tunggu beberapa detik..." end
    if DumpFrame then DumpFrame.Visible = true end
    runGC()
    local out = {"== LIXX EGG DUMP v4 ==",
        ("OnlyRoot=%s IgnoreBase=%s"):format(tostring(S.OnlyRoot), tostring(S.IgnoreBase)),
        ("Lolos filter: %d | Semua prompt: %d"):format(#EggCache, #AllCache)}
    out[#out + 1] = "-- ZONA (key = jumlah) --"
    for k, nn in pairs(ZoneCounts) do
        out[#out + 1] = ("%s = %d%s"):format(k, nn, S.BaseKeys[k] and "  [BASE]" or "")
    end
    out[#out + 1] = "-- 6 telur pertama --"
    for i, e in ipairs(AllCache) do
        if i > 6 then break end
        out[#out + 1] = ("[%d] pos=%d,%d,%d | rarity=%s | nama=%s | tipe=%s | berat=%s | income=%s | area=%s | src=%s | img=%s")
            :format(i, e.Part.Position.X, e.Part.Position.Y, e.Part.Position.Z, e.Rarity, e.Name,
                tostring(e.Type), tostring(e.Weight), tostring(e.Price), tostring(e.Area), e.Src, tostring(e.Image))
        out[#out + 1] = "  prompt ObjectText|ActionText = " .. tostring(e.PromptText)
        local recs = GCRecs[e.Part]
        out[#out + 1] = "  gc rekaman = " .. tostring(recs and #recs or 0)
        if recs then
            for ri, r in ipairs(recs) do
                out[#out + 1] = "  gc rekaman " .. ri .. ":"
                dumpTable(r, out, 2, {n = 40}, 1)
            end
        end
        local nl = nearbyNodes(e.Part)
        out[#out + 1] = "  objek di sekitar (" .. #nl .. "):"
        for ni, x in ipairs(nl) do
            if ni > 14 then break end
            out[#out + 1] = describe(x, 2)
        end
        local gl = AdorneeMap[e.Part]
        if gl then
            for _, g in ipairs(gl) do
                out[#out + 1] = "  ADORNEE GUI: " .. g:GetFullName()
                for _, dd in ipairs(g:GetDescendants()) do
                    if dd:IsA("TextLabel") then out[#out + 1] = "    text: " .. cleanText(dd.Text) end
                end
            end
        end
    end
    out[#out + 1] = "-- STRUKTUR FOLDER --"
    for _, nm in ipairs({"AreaEggSlotsClient", "Eggs", "PlacedEggRenders", "ClientRenderedAssets", "_Guards", "Forest"}) do
        dumpFolder(nm, out)
    end
    local dir = getDir()
    if dir then
        local cnt = 0
        for k, v in pairs(dir) do
            cnt += 1
            if cnt > 4 then break end
            local kv = {}
            if type(v) == "table" then
                for kk, vv in pairs(v) do
                    kv[#kv + 1] = tostring(kk) .. "=" .. tostring(vv)
                    if #kv >= 14 then break end
                end
            end
            out[#out + 1] = "DIR " .. tostring(k) .. ": " .. table.concat(kv, ", ")
        end
    end
    local c = LP.Character
    if c then
        local kids = {}
        for _, k in ipairs(c:GetChildren()) do kids[#kids + 1] = k.Name .. ":" .. k.ClassName end
        out[#out + 1] = "karakter: " .. table.concat(kids, ",") .. " attr{" .. attrStr(c) .. "}"
    end
    local txt = table.concat(out, "\n")
    if setclipboard then pcall(setclipboard, txt) end
    if DumpBox then DumpBox.Text = txt end
    print(txt)
end

local function calibrateBase()
    local root = hrp().Position
    local near, far, count, maxd = {}, {}, 0, 0
    for _, e in ipairs(AllCache) do
        local d = (e.Part.Position - root).Magnitude
        if d <= S.BaseRadius then
            near[e.Zone] = true
            count += 1
            if d > maxd then maxd = d end
        else
            far[e.Zone] = true
        end
    end
    S.BaseKeys = {}
    local keys = {}
    for k in pairs(near) do
        if not far[k] then
            S.BaseKeys[k] = true
            keys[#keys + 1] = k
        end
    end
    S.BaseCenter = root
    S.BaseRadiusLearned = math.max(maxd + 25, S.BaseRadius)
    if not S.Base then S.Base = root end
    return count, table.concat(keys, ", ")
end

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

-- deteksi telur yang kita bawa: bandingkan isi karakter sebelum & sesudah ambil
local function snapChar()
    local s = {}
    local c = LP.Character
    if c then
        for _, d in ipairs(c:GetDescendants()) do s[d] = true end
    end
    return s
end

local function newCarried(before)
    local list = {}
    local c = LP.Character
    if not c then return list end
    for _, d in ipairs(c:GetDescendants()) do
        if not before[d] and (d:IsA("Model") or d:IsA("BasePart") or d:IsA("Tool") or d:IsA("Accessory")) then
            list[#list + 1] = d
            if #list >= 6 then break end
        end
    end
    return list
end

local function holding(e)
    local c = LP.Character
    if not c then return false end
    if e and e.Carried and #e.Carried > 0 then
        for _, o in ipairs(e.Carried) do
            if o.Parent and o:IsDescendantOf(c) then return true end
        end
        return false
    end
    return carryingEgg(LP)
end

------------------------------------------------------------
-- TELEGRAM
------------------------------------------------------------
local function sendTelegram(text, imageUrl)
    if S.Token == "" or S.ChatId == "" or not httpRequest then return end
    local base = "https://api.telegram.org/bot" .. S.Token
    pcall(function()
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
end

local function eggImageUrl(e)
    if not e.Image or not httpRequest then return nil end
    local id = tostring(e.Image):match("%d+")
    if not id then return nil end
    local ok, url = pcall(function()
        local r = httpRequest({
            Url = "https://thumbnails.roblox.com/v1/assets?assetIds=" .. id .. "&size=420x420&format=Png",
            Method = "GET",
        })
        return HttpService:JSONDecode(r.Body).data[1].imageUrl
    end)
    if ok then return url end
    return nil
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
        lines[#lines + 1] = ("[%s] %s | %s | %s | %s"):format(h.Time, h.Name, h.Rarity, h.Type, h.Weight)
    end
    HistoryParagraph:Set({
        Title = "History (" .. #S.History .. ")",
        Content = #lines > 0 and table.concat(lines, "\n") or "Belum ada history.",
    })
end

local function addHistory(e)
    S.History[#S.History + 1] = {
        Time = os.date("%H:%M:%S"), Name = e.Name, Rarity = e.Rarity,
        Type = tostring(e.Type), Weight = tostring(e.Weight),
    }
    pcall(refreshHistory)
    if S.Notif then
        task.spawn(function()
            sendTelegram(("LIXX EGG\nTelur: %s\nRarity: %s\nTipe: %s\nBerat: %s\nWilayah: %s\nPlayer: %s")
                :format(e.Name, e.Rarity, tostring(e.Type), tostring(e.Weight), tostring(e.Area), LP.Name),
                eggImageUrl(e))
        end)
    end
end

------------------------------------------------------------
-- AMBIL TELUR
------------------------------------------------------------
local lastDeliver = 0
local HintShown = false
local lastJump = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- lari lurus ke target dengan kecepatan player (dipaksa lewat velocity supaya tidak melambat)
local function stepRun(tpos)
    local root, h = hrp(), hum()
    local flat = Vector3.new(tpos.X - root.Position.X, 0, tpos.Z - root.Position.Z)
    if flat.Magnitude <= 2.5 then return end
    local dir = flat.Unit
    local speed = S.SpeedValue
    h.WalkSpeed = speed
    h:MoveTo(tpos)
    local v = root.AssemblyLinearVelocity
    root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, v.Y, dir.Z * speed)
    if tick() - lastJump > 0.4 then
        rayParams.FilterDescendantsInstances = {char()}
        local hit = workspace:Raycast(root.Position, dir * 5, rayParams)
        if (hit and hit.Instance.CanCollide) or (tpos.Y - root.Position.Y > 5) then
            h.Jump = true
            lastJump = tick()
        end
    end
end

local function grabOnce(e)
    local pr = e.Prompt
    if not pr then return false end
    pcall(function()
        pr.HoldDuration = 0
        pr.RequiresLineOfSight = false
        pr.MaxActivationDistance = 30
    end)
    if fireproximityprompt then pcall(fireproximityprompt, pr) end
    task.wait(0.05)
    return carryingEgg(LP) or not e.Part.Parent or not pr:IsDescendantOf(workspace) or not pr.Enabled
end

local function grab(e)
    for _ = 1, 20 do
        if grabOnce(e) then return true end
    end
    return carryingEgg(LP)
end

-- cari telur YANG SAMA (bukan telur lain): objek lama, slot asal, atau prompt baru di titik jatuh
local function relocate(e)
    if e.Part and e.Part.Parent and e.Prompt and e.Prompt:IsDescendantOf(workspace)
        and not isInsideCharacter(e.Obj) then
        return e
    end
    local origin = e.OrigPos or hrp().Position
    local lostPos = e.LostPos or hrp().Position
    local known = e.Known or {}
    local best, bd
    for _, c in ipairs(AllCache) do
        if c.Prompt and c.Part and c.Part.Parent and not isInsideCharacter(c.Obj) then
            local d0 = (c.Part.Position - origin).Magnitude
            if d0 <= 10 and (not bd or d0 < bd) then best, bd = c, d0 end
        end
    end
    if best then return best end
    for _, c in ipairs(AllCache) do
        if c.Prompt and c.Part and c.Part.Parent and not isInsideCharacter(c.Obj) and not known[c.Part] then
            local d1 = (c.Part.Position - lostPos).Magnitude
            if d1 <= 45 and (not bd or d1 < bd) then best, bd = c, d1 end
        end
    end
    return best
end

local function chaseAndGrab(e0)
    local cur = e0
    local lastPos = e0.Part.Position
    local dist0 = (lastPos - hrp().Position).Magnitude
    local limit = math.clamp(dist0 / math.max(S.SpeedValue, 16) * 1.6 + 15, 25, 150)
    local t0 = tick()
    local before
    while tick() - t0 < limit and not S.Abort do
        if not cur.Part or not cur.Part.Parent then
            local nx = relocate(cur)
            if not nx then return false end
            nx.OrigPos, nx.Known = cur.OrigPos, cur.Known
            cur = nx
        end
        local root = hrp()
        local tpos = cur.Part.Position
        lastPos = tpos
        cur.LastPos = tpos
        if (tpos - root.Position).Magnitude <= 26 then
            before = before or snapChar()
            if grabOnce(cur) then return true, cur, before end
        end
        stepRun(tpos)
        task.wait()
    end
    return false
end

-- visual lokal: kamera menempel ke "kembaran" kita yang diam di base
local FakeChar, FakeHum
local function startFake(basePos)
    if not S.FakeVisual then return end
    pcall(function()
        local c = char()
        c.Archivable = true
        local clone = c:Clone()
        if not clone then return end
        for _, d in ipairs(clone:GetDescendants()) do
            if d:IsA("BaseScript") then d:Destroy() end
            if d:IsA("BasePart") then d.Anchored = true end
        end
        clone.Name = "LIXX_FAKE"
        clone.Parent = workspace
        clone:PivotTo(CFrame.new(basePos + Vector3.new(0, 3, 0)))
        FakeChar = clone
        FakeHum = clone:FindFirstChildOfClass("Humanoid")
        if FakeHum then workspace.CurrentCamera.CameraSubject = FakeHum end
    end)
end

local function stopFake()
    pcall(function()
        if FakeChar then FakeChar:Destroy() end
        FakeChar, FakeHum = nil, nil
        workspace.CurrentCamera.CameraSubject = hum()
    end)
end

-- terbang LURUS & sangat cepat (tampak glitch bagi player lain)
local function flyLeg(pos, abortFn)
    local root, h = hrp(), hum()
    local parts = {}
    for _, p in ipairs(char():GetDescendants()) do
        if p:IsA("BasePart") then parts[#parts + 1] = p end
    end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Velocity = Vector3.zero
    bv.Parent = root
    h.PlatformStand = true
    S.Flying = true
    local target = pos + Vector3.new(0, 3, 0)
    local t0 = tick()
    local arrived = false
    while tick() - t0 < 90 and not S.Abort do
        if abortFn and abortFn() then break end
        local diff = target - root.Position
        local d = diff.Magnitude
        if d < 6 then
            arrived = true
            break
        end
        bv.Velocity = diff.Unit * math.min(S.FlySpeed, math.max(d * 20, 30))
        local j = 1.2
        root.CFrame = CFrame.new(root.Position + Vector3.new(
            (math.random() - 0.5) * j, (math.random() - 0.5) * j, (math.random() - 0.5) * j))
            * CFrame.Angles(math.random() * 6.28, math.random() * 6.28, math.random() * 6.28)
        for i = 1, #parts do parts[i].CanCollide = false end
        if FakeHum then
            local cam = workspace.CurrentCamera
            if cam.CameraSubject ~= FakeHum then cam.CameraSubject = FakeHum end
        end
        task.wait()
    end
    bv.Velocity = Vector3.zero
    bv:Destroy()
    S.Flying = false
    h.PlatformStand = false
    root.AssemblyLinearVelocity = Vector3.zero
    if arrived then root.CFrame = CFrame.new(target) end
    return arrived
end

-- telur dianggap lepas HANYA kalau terkonfirmasi tidak menempel lagi selama > 0.8 detik
local function lostWatcher(e)
    local since
    local t0 = tick()
    return function()
        if not (e and e.Carried and #e.Carried > 0) then return false end
        if tick() - t0 < 0.8 then return false end
        if holding(e) then
            since = nil
            return false
        end
        since = since or tick()
        return tick() - since > 0.8
    end
end

-- return: "done" | "lost" | "abort" | "retry"
local function carryHome(e)
    lastDeliver = tick()
    if not S.Base then
        showError("Base belum di-set! Menu Setting > Set Posisi Base")
        return "abort"
    end
    local isLost = lostWatcher(e)
    local lost = false
    local function abort()
        if S.Abort then return true end
        if isLost() then
            lost = true
            return true
        end
        return false
    end

    startFake(S.Base)
    local ok = true
    if S.Forest then
        ok = flyLeg(S.Forest, abort)
        if ok then
            local w0 = tick()
            while tick() - w0 < CONFIG.ForestWait do
                if abort() then
                    ok = false
                    break
                end
                task.wait(0.1)
            end
        end
    elseif not HintShown then
        HintShown = true
        showError("Forest belum di-set, langsung ke base (Setting > Set Posisi Forest)")
    end
    if ok then ok = flyLeg(S.Base, abort) end

    local status = "done"
    if ok then
        local w0 = tick()
        while tick() - w0 < CONFIG.BaseWait do
            if S.Abort then break end
            if e and e.Carried and #e.Carried > 0 and not holding(e) then break end
            task.wait(0.1)
        end
    elseif lost then
        status = "lost"
        if e then e.LostPos = hrp().Position end
    elseif S.Abort then
        status = "abort"
    else
        status = "retry"
    end
    stopFake()
    return status
end

-- cadangan terakhir: lari lurus ke base supaya tidak pernah diam di jalan sambil bawa telur
local function runHomeFallback(e)
    if not S.Base then return "abort" end
    local isLost = lostWatcher(e)
    local dist0 = (hrp().Position - S.Base).Magnitude
    local limit = math.clamp(dist0 / math.max(S.SpeedValue, 16) * 1.6 + 15, 20, 150)
    local t0 = tick()
    while tick() - t0 < limit and not S.Abort do
        if (hrp().Position - S.Base).Magnitude <= 8 then break end
        if isLost() then
            e.LostPos = hrp().Position
            return "lost"
        end
        stepRun(S.Base)
        task.wait()
    end
    if S.Abort then return "abort" end
    task.wait(CONFIG.BaseWait)
    return "done"
end

local function stealEgg(e0)
    if S.Busy then return end
    S.Busy, S.Abort = true, false
    local ok, err = pcall(function()
        local e = e0
        e.OrigPos = e.OrigPos or e.Part.Position
        local known = {}
        for _, c in ipairs(AllCache) do known[c.Part] = true end
        e.Known = known
        for _ = 1, CONFIG.MaxRetry do
            if S.Abort then break end
            local got, cur, before = chaseAndGrab(e)
            if not got then break end
            e = cur or e
            task.wait(0.2)
            e.Carried = newCarried(before or {})
            local status
            for _ = 1, 3 do
                status = carryHome(e)
                if status ~= "retry" then break end
            end
            if status == "retry" then status = runHomeFallback(e) end
            if status == "done" then
                addHistory(e)
                return
            elseif status == "abort" then
                return
            end
            -- "lost": telur lepas (kena hit) -> kejar telur yang SAMA, bukan telur lain
            task.wait(0.3)
            local ne = relocate(e)
            if not ne then break end
            ne.OrigPos, ne.Known, ne.LostPos = e.OrigPos, e.Known, e.LostPos
            e = ne
        end
        Failed[e0.Obj] = tick()
    end)
    if not ok then
        pcall(stopFake)
        S.Flying = false
        showError("steal error: " .. tostring(err))
    end
    S.Busy = false
end

local function pickByPriority()
    for _, rar in ipairs(CONFIG.TargetRarities) do
        for _, e in ipairs(EggCache) do
            if e.Rarity:lower() == rar:lower() and e.Prompt and e.Part and e.Part.Parent
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
        if S.Steal and not S.Busy then
            if carryingEgg(LP) and tick() - lastDeliver > 20 then
                S.Busy = true
                S.Abort = false
                pcall(function()
                    local st = carryHome(nil)
                    if st == "retry" then runHomeFallback(nil) end
                end)
                S.Busy = false
            else
                local e = pickByPriority()
                if e then stealEgg(e) end
            end
        end
    end
end)

-- baca data game (ringan): hanya saat panel dibuka / steal aktif, tiap 60 detik
task.spawn(function()
    task.wait(6)
    while true do
        if S.GCScan and getgc and (S.Steal or (PanelFrame and PanelFrame.Visible)) and tick() - lastGC > 60 then
            runGC()
        end
        task.wait(5)
    end
end)

RunService.Heartbeat:Connect(function()
    if S.Speed then
        local c = LP.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = S.SpeedValue end
    end
end)

------------------------------------------------------------
-- PROTEKSI (lapisan client-side)
------------------------------------------------------------
local Hazards = {}
local hazConn

local function hazardParent(d)
    local p = d.Parent
    for _ = 1, 2 do
        if p and p ~= workspace then
            if nameHas(p.Name, CONFIG.HazardWords) then return true end
            p = p.Parent
        end
    end
    return false
end

local function trackHazard(d)
    if d:IsA("BasePart") and (nameHas(d.Name, CONFIG.HazardWords) or hazardParent(d)) then
        Hazards[d] = true
        pcall(function() d.CanTouch = false end)
    end
end

local function setAntiTrap(on)
    S.AntiTrap = on
    if on and not hazConn then
        hazConn = workspace.DescendantAdded:Connect(trackHazard)
        task.spawn(function()
            local i = 0
            for _, d in ipairs(workspace:GetDescendants()) do
                if not S.AntiTrap then break end
                trackHazard(d)
                i += 1
                if i % 4000 == 0 then task.wait() end
            end
        end)
    elseif not on and hazConn then
        hazConn:Disconnect()
        hazConn = nil
        for p in pairs(Hazards) do
            pcall(function() p.CanTouch = true end)
        end
        Hazards = {}
    end
end

task.spawn(function()
    local lastChar
    while true do
        task.wait(0.1)
        if S.AntiHit then
            pcall(function()
                local c = LP.Character
                if not c then return end
                local h = c:FindFirstChildOfClass("Humanoid")
                if h then
                    if c ~= lastChar then
                        lastChar = c
                        for _, st in ipairs({Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.FallingDown}) do
                            pcall(function() h:SetStateEnabled(st, false) end)
                        end
                        h.BreakJointsOnDeath = false
                        h.RequiresNeck = false
                    end
                    if h.Health > 0 and h.Health < h.MaxHealth then h.Health = h.MaxHealth end
                    if h.PlatformStand and not S.Flying then h.PlatformStand = false end
                    if h.Sit then h.Sit = false end
                end
                for k, v in pairs(c:GetAttributes()) do
                    if nameHas(k, CONFIG.StatusWords) then
                        local t = type(v)
                        if t == "boolean" and v then
                            c:SetAttribute(k, false)
                        elseif t == "number" and v ~= 0 then
                            c:SetAttribute(k, 0)
                        end
                    end
                end
                for _, ch in ipairs(c:GetChildren()) do
                    if (ch:IsA("ValueBase") or ch:IsA("Constraint")) and nameHas(ch.Name, CONFIG.StatusWords) then
                        pcall(function() ch:Destroy() end)
                    end
                end
            end)
        end
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
        for _, p in ipairs(CONFIG.ClubPattern) do
            if n:find(p, 1, true) then return true end
        end
        return false
    end
    for _, t in ipairs(char():GetChildren()) do if match(t) then return t end end
    for _, t in ipairs(LP.Backpack:GetChildren()) do if match(t) then return t end end
    return nil
end

local BatRemote
local function swingAt(target, club)
    if BatRemote == nil then
        BatRemote = false
        pcall(function()
            BatRemote = ReplicatedStorage.Packages.Networking["RE/BatSwing/Trigger"]
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

local function nearestFreeEgg()
    local best, bd
    for _, e in ipairs(AllCache) do
        if e.Prompt and e.Part and e.Part.Parent then
            local d = (e.Part.Position - hrp().Position).Magnitude
            if not bd or d < bd then best, bd = e, d end
        end
    end
    return best, bd
end

local duelBusy = false
local function duelSteal(target)
    if duelBusy or S.Busy then return end
    duelBusy, S.Busy, S.Abort = true, true, false
    local ok, err = pcall(function()
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
        task.wait(0.3)
        local e, d = nearestFreeEgg()
        if e and d < 60 then
            hrp().CFrame = e.Part.CFrame + Vector3.new(0, 3, 0)
            local before = snapChar()
            if grab(e) then
                task.wait(0.2)
                e.Carried = newCarried(before)
                local st = carryHome(e)
                if st == "retry" then st = runHomeFallback(e) end
                if st == "done" then addHistory(e) end
            end
        end
    end)
    if not ok then
        pcall(stopFake)
        S.Flying = false
        showError("duel error: " .. tostring(err))
    end
    duelBusy, S.Busy = false, false
end

------------------------------------------------------------
-- GUI KUSTOM
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

    local t = Instance.new("TextLabel")
    t.Size = UDim2.new(1, -40, 0, 26)
    t.Position = UDim2.new(0, 8, 0, 0)
    t.BackgroundTransparency = 1
    t.Text = title
    t.TextColor3 = Color3.new(1, 1, 1)
    t.Font = Enum.Font.GothamBold
    t.TextSize = 13
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = f

    local x = Instance.new("TextButton")
    x.Size = UDim2.new(0, 28, 0, 26)
    x.Position = UDim2.new(1, -28, 0, 0)
    x.BackgroundTransparency = 1
    x.Text = "X"
    x.TextColor3 = Color3.fromRGB(255, 80, 80)
    x.Font = Enum.Font.GothamBold
    x.TextSize = 16
    x.Parent = f
    x.MouseButton1Click:Connect(function() f.Visible = false end)

    local sc = Instance.new("ScrollingFrame")
    sc.Position = UDim2.new(0, 4, 0, 28)
    sc.Size = UDim2.new(1, -8, 1, -32)
    sc.BackgroundTransparency = 1
    sc.ScrollBarThickness = 4
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.CanvasSize = UDim2.new()
    sc.Parent = f
    local l = Instance.new("UIListLayout", sc)
    l.Padding = UDim.new(0, 3)
    return f, sc
end

local PanelList
PanelFrame, PanelList = mkFrame("LIXX EGG - Panel Steal", UDim2.new(0.5, -150, 0.2, 0), UDim2.new(0, 300, 0, 270))
local DuelFrame, DuelList = mkFrame("LIXX EGG - Duel Player", UDim2.new(0.5, -140, 0.3, 0), UDim2.new(0, 280, 0, 260))

local dumpHolder
DumpFrame, dumpHolder = mkFrame("LIXX EGG - Dump (tekan lama lalu salin)", UDim2.new(0.5, -200, 0.15, 0), UDim2.new(0, 400, 0, 300))
dumpHolder.Visible = false
DumpBox = Instance.new("TextBox")
DumpBox.Size = UDim2.new(1, -8, 1, -32)
DumpBox.Position = UDim2.new(0, 4, 0, 28)
DumpBox.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
DumpBox.TextColor3 = Color3.new(1, 1, 1)
DumpBox.Font = Enum.Font.Code
DumpBox.TextSize = 11
DumpBox.TextXAlignment = Enum.TextXAlignment.Left
DumpBox.TextYAlignment = Enum.TextYAlignment.Top
DumpBox.MultiLine = true
DumpBox.ClearTextOnFocus = false
DumpBox.TextEditable = true
DumpBox.TextWrapped = true
DumpBox.Text = ""
DumpBox.Parent = DumpFrame

Banner = Instance.new("TextLabel")
Banner.Size = UDim2.new(0, 330, 0, 22)
Banner.Position = UDim2.new(0.5, -165, 0, 4)
Banner.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
Banner.BackgroundTransparency = 0.2
Banner.TextColor3 = Color3.fromRGB(255, 200, 60)
Banner.Font = Enum.Font.GothamBold
Banner.TextSize = 12
Banner.Text = "Analyzer: scanning..."
Banner.Parent = Gui
Instance.new("UICorner", Banner)

local function clear(sc)
    for _, c in ipairs(sc:GetChildren()) do
        if not c:IsA("UIListLayout") then c:Destroy() end
    end
end

local function mkRowButton(parent, text, color, cb)
    local b = Instance.new("TextButton")
    b.Size = UDim2.new(0, 56, 0, 24)
    b.Position = UDim2.new(1, -60, 0.5, -12)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 11
    b.Parent = parent
    Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(cb)
    return b
end

local function rarityColor(r)
    local k = rankOf(r)
    if k <= 5 then return "#FFC83C" elseif k <= 10 then return "#C080FF" end
    return "#FFFFFF"
end

local function mkEggIcon(row, e)
    local holder = Instance.new("Frame")
    holder.Size = UDim2.new(0, 48, 0, 48)
    holder.Position = UDim2.new(0, 3, 0.5, -24)
    holder.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
    holder.Parent = row
    Instance.new("UICorner", holder)

    local em = Instance.new("TextLabel")
    em.Size = UDim2.new(1, 0, 1, 0)
    em.BackgroundTransparency = 1
    em.Text = "🥚"
    em.TextSize = 28
    em.Parent = holder

    if e.Image then
        local im = Instance.new("ImageLabel")
        im.Size = UDim2.new(1, 0, 1, 0)
        im.BackgroundTransparency = 1
        im.ScaleType = Enum.ScaleType.Fit
        im.Image = e.Image
        im.Parent = holder
    end
end

local lastSig = ""
local function refreshPanel()
    if not PanelFrame.Visible then return end
    local eggs = EggCache
    local parts = {}
    for idx, e in ipairs(eggs) do
        if idx > 30 then break end
        parts[#parts + 1] = tostring(e.Obj) .. e.Name .. e.Rarity .. tostring(e.Area)
            .. tostring(e.Weight) .. tostring(e.Type) .. tostring(e.Image)
    end
    local sig = table.concat(parts, "|")
    if sig == lastSig then return end
    lastSig = sig
    clear(PanelList)
    for idx, e in ipairs(eggs) do
        if idx > 30 then break end
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 58)
        row.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
        row.Parent = PanelList
        Instance.new("UICorner", row)
        mkEggIcon(row, e)

        local lbl = Instance.new("TextLabel")
        lbl.Position = UDim2.new(0, 55, 0, 0)
        lbl.Size = UDim2.new(1, -118, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 10
        lbl.TextWrapped = true
        lbl.RichText = true
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        local inc = (e.Price ~= "-" and (" | Income: " .. tostring(e.Price)) or "")
        lbl.Text = "<b>" .. e.Name .. "</b> <font color=\"" .. rarityColor(e.Rarity) .. "\">[" .. e.Rarity ..
            "]</font>\nTipe: " .. tostring(e.Type) .. " | Berat: " .. tostring(e.Weight) ..
            "\nWilayah: " .. tostring(e.Area) .. inc
        lbl.Parent = row

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
            local row = Instance.new("Frame")
            row.Size = UDim2.new(1, -6, 0, 32)
            row.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
            row.Parent = DuelList
            Instance.new("UICorner", row)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -70, 1, 0)
            lbl.Position = UDim2.new(0, 8, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3 = Color3.new(1, 1, 1)
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 12
            lbl.Text = p.DisplayName
            lbl.TextXAlignment = Enum.TextXAlignment.Left
            lbl.Parent = row
            mkRowButton(row, "Steal", has and Color3.fromRGB(40, 170, 70) or Color3.fromRGB(190, 40, 40), function()
                if has and S.Duel then task.spawn(duelSteal, p) end
            end)
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
-- RAYFIELD
------------------------------------------------------------
local RAYFIELD_URLS = {
    "https://sirius.menu/rayfield",
    "https://raw.githubusercontent.com/SiegeHub/Rayfield/main/source.lua",
    "https://raw.githubusercontent.com/shlexware/Rayfield/main/source",
}
local Rayfield
for _, url in ipairs(RAYFIELD_URLS) do
    local ok, res = pcall(function() return loadstring(game:HttpGet(url))() end)
    if ok and res then
        Rayfield = res
        break
    end
    warn("[LIXX EGG] gagal load Rayfield dari " .. url .. " : " .. tostring(res))
end
if not Rayfield then
    showError("Rayfield gagal di-load. Cek koneksi / coba executor lain.")
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
        S.Steal = v
        if not v then S.Abort = true end
        if v and not S.Forest then
            Rayfield:Notify({Title = "LIXX EGG", Content = "Forest belum di-set (Setting). Tanpa Forest langsung ke base.", Duration = 5})
        end
    end,
})
TabEgg:CreateButton({
    Name = "Panel (buka panel steal)",
    Callback = function()
        PanelFrame.Visible = true
        lastSig = ""
        pcall(refreshPanel)
        if S.GCScan and tick() - lastGC > 30 then task.spawn(runGC) end
    end,
})
TabEgg:CreateToggle({
    Name = "Hanya telur lapangan (zona root, bukan base)", CurrentValue = true, Flag = "OnlyRoot",
    Callback = function(v) S.OnlyRoot = v end,
})
TabEgg:CreateToggle({
    Name = "Abaikan telur di base", CurrentValue = true, Flag = "IgnoreBase",
    Callback = function(v) S.IgnoreBase = v end,
})

local function zoneOptions()
    local opts = {}
    for k, nn in pairs(ZoneCounts) do opts[#opts + 1] = k .. " (" .. nn .. ")" end
    table.sort(opts)
    if #opts == 0 then opts = {"(belum ada zona)"} end
    return opts
end
local ZoneDropdown = TabEgg:CreateDropdown({
    Name = "Zona Steal (kosong = semua yang lolos filter)", Options = zoneOptions(),
    CurrentOption = {}, MultipleOptions = true, Flag = "ZoneSel",
    Callback = function(o)
        S.AllowedZones = {}
        local list = type(o) == "table" and o or {o}
        for _, label in ipairs(list) do
            local key = tostring(label):gsub(" %(%d+%)$", "")
            if key ~= "None" and not key:find("belum ada zona", 1, true) then S.AllowedZones[key] = true end
        end
    end,
})
TabEgg:CreateButton({
    Name = "Refresh Daftar Zona",
    Callback = function() pcall(function() ZoneDropdown:Refresh(zoneOptions()) end) end,
})
TabEgg:CreateSlider({
    Name = "Speed Boost / Kecepatan Lari ke Telur", Range = {16, 300}, Increment = 1, Suffix = " speed",
    CurrentValue = 70, Flag = "SpeedSlider",
    Callback = function(v) S.SpeedValue = v end,
})
TabEgg:CreateToggle({
    Name = "Speed Boost On/Off", CurrentValue = false, Flag = "SpeedToggle",
    Callback = function(v)
        S.Speed = v
        if not v then pcall(function() hum().WalkSpeed = 16 end) end
    end,
})
TabEgg:CreateSlider({
    Name = "Kecepatan Terbang ke Base (bawa telur)", Range = {100, 1000}, Increment = 10, Suffix = " studs/s",
    CurrentValue = 450, Flag = "FlySpeed",
    Callback = function(v) S.FlySpeed = v end,
})
TabEgg:CreateToggle({
    Name = "Visual lokal: kamera diam di base saat terbang", CurrentValue = true, Flag = "FakeVisual",
    Callback = function(v) S.FakeVisual = v end,
})
TabEgg:CreateToggle({
    Name = "Baca data game (getgc) untuk isi/berat/tipe", CurrentValue = true, Flag = "GCScan",
    Callback = function(v) S.GCScan = v end,
})
TabEgg:CreateButton({
    Name = "Dump Analisa (tampil + copy)",
    Callback = function() task.spawn(function() pcall(dumpInfo) end) end,
})

-- 2. HISTORY EGG
local TabHist = Window:CreateTab("History Egg", 4483362458)
HistoryParagraph = TabHist:CreateParagraph({Title = "History (0)", Content = "Belum ada history."})
TabHist:CreateButton({
    Name = "Deleted (hapus history)",
    Callback = function()
        S.History = {}
        refreshHistory()
    end,
})

-- 3. DUEL PLAYER
local TabDuel = Window:CreateTab("Duel Player", 4483362458)
TabDuel:CreateToggle({
    Name = "Duel Player On/Off", CurrentValue = false, Flag = "DuelToggle",
    Callback = function(v)
        S.Duel = v
        DuelFrame.Visible = v
        if v then pcall(refreshDuel) end
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
    Callback = function(t) S.Token = (t:gsub("%s", "")) end,
})
TabNotif:CreateInput({
    Name = "ID Penerima (Chat ID)", PlaceholderText = "123456789", RemoveTextAfterFocusLost = false,
    Callback = function(t) S.ChatId = (t:gsub("%s", "")) end,
})
TabNotif:CreateToggle({
    Name = "Notifikasi On/Off", CurrentValue = false, Flag = "NotifToggle",
    Callback = function(v) S.Notif = v end,
})
TabNotif:CreateButton({
    Name = "Test Kirim Notifikasi",
    Callback = function() sendTelegram("LIXX EGG: test notifikasi berhasil dari " .. LP.Name) end,
})

-- 5. SETTING
local TabSet = Window:CreateTab("Setting", 4483362458)
TabSet:CreateSection("Posisi")
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
TabSet:CreateButton({
    Name = "Kalibrasi Base (berdiri di tengah base dulu)",
    Callback = function()
        local n, keys = calibrateBase()
        Rayfield:Notify({
            Title = "LIXX EGG",
            Content = n .. " telur base dipelajari. Zona base: " .. (keys ~= "" and keys or "(pakai radius saja)"),
            Duration = 7,
        })
    end,
})
TabSet:CreateSlider({
    Name = "Radius area base (diabaikan)", Range = {20, 300}, Increment = 5, Suffix = " studs",
    CurrentValue = 70, Flag = "BaseRadius",
    Callback = function(v) S.BaseRadius = v end,
})
TabSet:CreateSection("Proteksi (lapisan client-side)")
TabSet:CreateToggle({
    Name = "Anti Hit (anti stun/ragdoll, kunci darah, hapus efek status)", CurrentValue = false, Flag = "AntiHit",
    Callback = function(v) S.AntiHit = v end,
})
TabSet:CreateToggle({
    Name = "Anti Trap (matikan sentuhan jebakan secara lokal)", CurrentValue = false, Flag = "AntiTrap",
    Callback = function(v) setAntiTrap(v) end,
})

------------------------------------------------------------
-- TOMBOL LOGO "L"
------------------------------------------------------------
local L = Instance.new("TextButton")
L.Size = UDim2.new(0, 40, 0, 40)
L.Position = UDim2.new(0, 10, 0.5, 0)
L.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
L.Text = "L"
L.TextColor3 = Color3.fromRGB(120, 200, 255)
L.Font = Enum.Font.GothamBlack
L.TextSize = 24
L.Active = true
L.Draggable = true
L.Parent = Gui
Instance.new("UICorner", L).CornerRadius = UDim.new(1, 0)
L.MouseButton1Click:Connect(function()
    pcall(function() Rayfield:SetVisibility(true) end)
    if S.Duel then DuelFrame.Visible = true end
end)

pcall(function()
    if not S.Base then S.Base = hrp().Position end
end)

Rayfield:Notify({
    Title = "LIXX EGG",
    Content = "Loaded! Base otomatis = posisi awal. Set Forest (dan Base kalau salah) di menu Setting.",
    Duration = 8,
})
