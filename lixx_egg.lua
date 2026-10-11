--[[
    LIXX EGG v5 - Steal an Egg
    UI   : Rayfield
    Menu : Auto Egg | History Egg | Duel Player | Notifikasi | Setting
]]

------------------------------------------------------------
-- SATU INSTANCE SAJA (execute ulang = script lama dimatikan dulu)
------------------------------------------------------------
local genv = (getgenv and getgenv()) or _G
if genv.LIXX_EGG_STOP then pcall(genv.LIXX_EGG_STOP) end
local RUN = {on = true}
local StopHooks, Conns = {}, {}
genv.LIXX_EGG_STOP = function()
    RUN.on = false
    for _, c in ipairs(Conns) do pcall(function() c:Disconnect() end) end
    for _, f in ipairs(StopHooks) do pcall(f) end
end
local function track(conn)
    Conns[#Conns + 1] = conn
    return conn
end

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local CONFIG = {
    PromptName = "CarryAreaEgg",
    EggFolder = nil,
    EggNamePattern = "egg",
    TargetRarities = {"Divine", "Eternal", "Secret"}, -- prioritas auto steal
    -- urutan: paling bagus di atas
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
    BaseWait = 2,     -- detik diam di base setelah sampai
    ScanInterval = 1,
    MaxRetry = 8,
    FlyMax = 1600,   -- kecepatan terbang maksimum; otomatis turun kalau server menahan
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
    Steal = false, Speed = false, SpeedValue = 150, FlySpeed = 450, FakeVisual = false, FlyApproach = true,
    Duel = false, Notif = false, GCScan = true,
    AntiHit = false, AntiTrap = false, AntiGuard = true, Flying = false,
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
    parent = parent or game:GetService("CoreGui")
    pcall(function()
        local old = parent:FindFirstChild("LIXX_EGG_GUI")
        if old then old:Destroy() end
    end)
    if not pcall(function() Gui.Parent = parent end) or not Gui.Parent then
        Gui.Parent = LP:WaitForChild("PlayerGui")
    end
end
StopHooks[#StopHooks + 1] = function() Gui:Destroy() end

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
-- DATA GAME: ReplicatedStorage.Data.Assets.Directory
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
local GCRecs = setmetatable({}, {__mode = "k"})
local Failed = {}
local GCRunning = false
local lastGC = -999
local FakeChar, FakeHum
local FlyFails = 0
local flyLeg

local function findData(name)
    local c = DataCache[name]
    if c and tick() - c.T < 30 then return c.V end
    local v = nil
    pcall(function() v = ReplicatedStorage:FindFirstChild(name, true) end)
    DataCache[name] = {T = tick(), V = v}
    return v
end

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

local function isUid(name)
    return #name == 32 and not name:find("%X")
end

------------------------------------------------------------
-- BACA DATA DARI MEMORI GAME (getgc)
-- Sumber utama: tabel "Record" milik tiap telur (AssetCategory, AreaId, NestId, Uid, ...)
------------------------------------------------------------
local function addRec(recs, key, t)
    local l = recs[key]
    if not l then
        l = {}
        recs[key] = l
    end
    if #l < 6 then l[#l + 1] = t end
end

local function gcScan(items)
    if not getgc or #items == 0 then return end
    local set, uidMap = {}, {}
    for _, e in ipairs(items) do
        set[e.Part] = e.Part
        if e.Prompt then set[e.Prompt] = e.Part end
        local nl = nearbyNodes(e.Part)
        for _, x in ipairs(nl) do
            if x:IsA("Model") and isUid(x.Name) then
                uidMap[x.Name] = e.Part
                set[x] = e.Part
                e.Uid = x.Name
                break
            end
        end
    end
    local skip = {[set] = true, [uidMap] = true, [Prompts] = true, [OwnerCache] = true, [InfoCache] = true,
        [AdorneeMap] = true, [GCRecs] = true, [EggCache] = true, [AllCache] = true, [Failed] = true,
        [DataCache] = true}
    local recs = {}
    local count = 0
    local ok = pcall(function()
        for _, t in ipairs(getgc(true)) do
            if type(t) == "table" and not skip[t] then
                count += 1
                if count % 30000 == 0 then task.wait() end
                if rawget(t, "Src") == nil and rawget(t, "Obj") == nil then
                    local u = rawget(t, "Uid")
                    if type(u) == "string" and uidMap[u] then addRec(recs, uidMap[u], t) end
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
    if ok then
        for k, v in pairs(recs) do GCRecs[k] = v end
    end
end

local function findAsset(t, depth)
    if type(t) ~= "table" or depth > 3 then return nil end
    if type(rawget(t, "AssetCategory")) == "string" then return t end
    local n = 0
    for _, v in next, t do
        n += 1
        if n > 30 then break end
        if type(v) == "table" then
            local r = findAsset(v, depth + 1)
            if r then return r end
        end
    end
    return nil
end

local function findRecordFor(part)
    local recs = part and GCRecs[part]
    if not recs then return nil end
    for _, r in ipairs(recs) do
        local R = findAsset(r, 0)
        if R then return R end
    end
    return nil
end

local function fillFromRecord(info, R)
    local cat = rawget(R, "AssetCategory")
    local ent = entryOf(cat)
    if ent then
        applyEntry(info, ent, cat)
    else
        info.Name = cat
        info.Content = cat
        info.Type = "Egg"
    end
    local area = rawget(R, "AreaId")
    if type(area) == "string" and area ~= "" then info.Area = area end
    local nest = rawget(R, "NestId")
    if type(nest) == "string" then info.Slot = nest end
    local sc = rawget(R, "AssetScale")
    if type(sc) == "number" then info.SizeAttr = ("%.2f"):format(sc) end
    local muts = rawget(R, "Mutations")
    if type(muts) == "table" then
        local names = {}
        for k, v in pairs(muts) do
            names[#names + 1] = type(v) == "string" and v or tostring(k)
        end
        if #names > 0 then info.Mutation = table.concat(names, ", ") end
    end
    info.RecordTable = R
    info.Src = "record"
end

------------------------------------------------------------
-- RESOLVE INFO TELUR
------------------------------------------------------------
-- cadangan kalau Record belum terbaca (tanpa mencocokkan nama objek sekitar: itu yang bikin semua jadi Cerberus)
local function legacyResolve(info, owner, prompt, part)
    if prompt then
        local ot, at = "", ""
        pcall(function()
            ot = prompt.ObjectText
            at = prompt.ActionText
        end)
        info.PromptText = tostring(ot) .. " | " .. tostring(at)
        for _, t in ipairs({ot, at}) do
            local tt = cleanText(t)
            if #tt > 0 then
                local rr = matchRarity(tt)
                if rr then info.Rarity = info.Rarity or rr end
            end
        end
    end
    local nodes = {owner}
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
            end
        end
    end
    for _, node in ipairs(nodes) do
        for k, v in pairs(node:GetAttributes()) do
            local lk = tostring(k):lower()
            if type(v) == "string" and v ~= "" then
                if not nearSet[node] then
                    local ent = entryOf(v)
                    if ent then applyEntry(info, ent, v) end
                end
                if lk:find("rarity") or lk:find("tier") then info.Rarity = info.Rarity or normRarity(v) end
                if not info.Area and (lk:find("area") or lk:find("zone") or lk:find("biome")) then info.Area = v end
            end
        end
        if node == owner or nearSet[node] then
            local sa, sn = node.Name:match("_([^_:]+):Slot_(%d+)$")
            if sa then
                info.Area = info.Area or sa
                info.Slot = sn
            end
        end
        if node:IsA("TextLabel") then
            local t = cleanText(node.Text)
            local r = matchRarity(t)
            if r then info.Rarity = info.Rarity or r end
        elseif node:IsA("ImageLabel") and node.Image ~= "" then
            info.Image = info.Image or node.Image
        end
    end
    info.Src = "fallback"
end

local function resolveInfo(owner, prompt)
    local c = InfoCache[owner]
    if c and tick() - c.T < 5 then return c end
    local info = {T = tick(), Src = ""}
    local part = partOf(owner)
    local R = findRecordFor(part)
    if R then
        fillFromRecord(info, R)
    else
        legacyResolve(info, owner, prompt, part)
    end
    info.Rarity = info.Rarity or "Unknown"
    if not info.Name then
        if info.Slot then
            info.Name = ("Egg %s %s"):format(info.Area or "?", info.Slot)
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

local Guards = {}

local function trackPrompt(d)
    if d:IsA("ProximityPrompt") and d.Name == CONFIG.PromptName then Prompts[d] = true end
end

local function trackGuard(d)
    if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid")
        and (d.Name:lower():find("guard", 1, true) or d:GetAttribute("GuardState") ~= nil) then
        Guards[d] = true
    elseif d:IsA("Humanoid") and d.Parent and d.Parent:IsA("Model")
        and (d.Parent.Name:lower():find("guard", 1, true) or d.Parent:GetAttribute("GuardState") ~= nil) then
        Guards[d.Parent] = true
    end
end

local function trackAdded(d)
    trackPrompt(d)
    trackGuard(d)
end

track(PromptRoot.DescendantAdded:Connect(trackAdded))
track(PromptRoot.DescendantRemoving:Connect(function(d)
    Prompts[d] = nil
    Guards[d] = nil
end))
task.spawn(function()
    local i = 0
    for _, d in ipairs(PromptRoot:GetDescendants()) do
        trackAdded(d)
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
            e.PriceNum = tonumber(info.Price) or 0
            e.SizeAttr, e.Mutation, e.Slot = info.SizeAttr, info.Mutation, info.Slot
            e.Record = info.RecordTable
            e.Area = info.Area or areaOf(e.Part.Position)
            all[#all + 1] = e
            if S.OnlyRoot and e.Zone ~= "(root)" then return end
            if S.IgnoreBase and isBaseEgg(e) then return end
            if next(S.AllowedZones) and not S.AllowedZones[e.Zone] then return end
            result[#result + 1] = e
        end)
    end
    -- paling bagus di atas: Divine > Eternal > Secret > ... lalu income terbesar
    table.sort(result, function(a, b)
        local ra, rb = rankOf(a.Rarity), rankOf(b.Rarity)
        if ra ~= rb then return ra < rb end
        if a.PriceNum ~= b.PriceNum then return a.PriceNum > b.PriceNum end
        if a.Name ~= b.Name then return a.Name < b.Name end
        local pa, pb = a.Part.Position, b.Part.Position
        if pa.X ~= pb.X then return pa.X < pb.X end
        return pa.Z < pb.Z
    end)
    EggCache, AllCache, ZoneCounts = result, all, zc
end

task.spawn(function()
    while RUN.on do
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

local function runGC()
    if not getgc or #AllCache == 0 or GCRunning then return end
    GCRunning = true
    lastGC = tick()
    pcall(gcScan, AllCache)
    InfoCache = setmetatable({}, {__mode = "k"})
    GCRunning = false
end

-- baca data game: mulai cepat, ulangi hanya kalau masih ada telur tanpa record (dengan backoff)
task.spawn(function()
    task.wait(2)
    local interval = 6
    while RUN.on do
        if S.GCScan and getgc and #AllCache > 0 and not GCRunning then
            local missing = 0
            for _, e in ipairs(AllCache) do
                if e.Src ~= "record" then missing += 1 end
            end
            if missing > 0 and tick() - lastGC > interval then
                runGC()
                task.wait(1.5)
                local after = 0
                for _, e in ipairs(AllCache) do
                    if e.Src ~= "record" then after += 1 end
                end
                if after >= missing then
                    interval = math.min(interval * 2, 60)
                else
                    interval = 6
                end
            end
        end
        task.wait(1)
    end
end)

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

local function dumpInfo()
    if DumpBox then DumpBox.Text = "Memproses data game, tunggu beberapa detik..." end
    if DumpFrame then DumpFrame.Visible = true end
    runGC()
    local out = {"== LIXX EGG DUMP v5 ==",
        ("OnlyRoot=%s IgnoreBase=%s Terbang gagal=%d"):format(tostring(S.OnlyRoot), tostring(S.IgnoreBase), FlyFails),
        ("Lolos filter: %d | Semua prompt: %d"):format(#EggCache, #AllCache),
        "Deteksi ambil terakhir: " .. tostring(S.LastPick) .. " | Terbang terakhir: " .. tostring(S.LastFly)}
    local rec, fb = 0, 0
    for _, e in ipairs(AllCache) do
        if e.Src == "record" then rec += 1 else fb += 1 end
    end
    out[#out + 1] = ("Sumber data: record=%d fallback=%d"):format(rec, fb)
    out[#out + 1] = "-- ZONA --"
    for k, nn in pairs(ZoneCounts) do
        out[#out + 1] = ("%s = %d%s"):format(k, nn, S.BaseKeys[k] and "  [BASE]" or "")
    end
    local gcount = 0
    for g in pairs(Guards) do
        if g.Parent then
            gcount += 1
            if gcount <= 6 then
                out[#out + 1] = ("guard %s | state=%s | sleeping=%s | target=%s"):format(g:GetFullName(),
                    tostring(g:GetAttribute("GuardState")), tostring(g:GetAttribute("Sleeping")),
                    tostring(g:GetAttribute("TargetPlayer")))
            end
        end
    end
    out[#out + 1] = "Penjaga terdeteksi: " .. gcount
    out[#out + 1] = "-- 12 telur teratas (urutan panel) --"
    for i, e in ipairs(EggCache) do
        if i > 12 then break end
        out[#out + 1] = ("[%d] %s | %s | tipe=%s | berat=%s | income=%s | wilayah=%s | slot=%s | mutasi=%s | src=%s | state=%s")
            :format(i, e.Name, e.Rarity, tostring(e.Type), tostring(e.Weight), tostring(e.Price),
                tostring(e.Area), tostring(e.Slot), tostring(e.Mutation), e.Src, e.Record and tostring(rawget(e.Record, "State")) or "-")
    end
    local firstFb
    for _, e in ipairs(AllCache) do
        if e.Src ~= "record" then
            firstFb = e
            break
        end
    end
    if firstFb then
        out[#out + 1] = "-- contoh telur TANPA record --"
        out[#out + 1] = tostring(firstFb.PromptText)
        local nl = nearbyNodes(firstFb.Part)
        for ni, x in ipairs(nl) do
            if ni > 10 then break end
            out[#out + 1] = describe(x, 1)
        end
    end
    local c = LP.Character
    if c then
        local kids = {}
        for _, k in ipairs(c:GetChildren()) do kids[#kids + 1] = k.Name .. ":" .. k.ClassName end
        out[#out + 1] = "karakter: " .. table.concat(kids, ",")
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
    if e and e.Record and e.CarryState ~= nil then
        return rawget(e.Record, "State") == e.CarryState
    end
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
-- KONTROL AMAN: lepas semua kunci (kamera, terbang, kembaran) kapan saja
------------------------------------------------------------
local function releaseControl()
    S.Abort = true
    S.Flying = false
    pcall(function()
        for _, d in ipairs(workspace:GetChildren()) do
            if d.Name == "LIXX_FAKE" then d:Destroy() end
        end
        FakeChar, FakeHum = nil, nil
        local c = LP.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        local cam = workspace.CurrentCamera
        if h then
            cam.CameraSubject = h
            h.PlatformStand = false
        end
        if cam.CameraType == Enum.CameraType.Scriptable then cam.CameraType = Enum.CameraType.Custom end
        local r = c and c:FindFirstChild("HumanoidRootPart")
        if r then
            for _, x in ipairs(r:GetChildren()) do
                if x.Name == "LIXX_BV" then x:Destroy() end
            end
            r.AssemblyLinearVelocity = Vector3.zero
            r.Anchored = false
        end
    end)
end
StopHooks[#StopHooks + 1] = releaseControl

-- watchdog kamera: kalau kamera nyangkut ke kembaran / humanoid mati, kembalikan otomatis
task.spawn(function()
    while RUN.on do
        task.wait(0.5)
        pcall(function()
            if FakeChar then return end
            local cam = workspace.CurrentCamera
            local sub = cam.CameraSubject
            if sub and sub:IsA("Humanoid") then
                local bad = (not sub.Parent) or sub.Parent.Name == "LIXX_FAKE"
                if bad then
                    local c = LP.Character
                    local h = c and c:FindFirstChildOfClass("Humanoid")
                    if h then cam.CameraSubject = h end
                end
            end
            for _, d in ipairs(workspace:GetChildren()) do
                if d.Name == "LIXX_FAKE" then d:Destroy() end
            end
        end)
    end
end)

local function hookCharacter(c)
    task.spawn(function()
        local h = c:WaitForChild("Humanoid", 10)
        if h then
            track(h.Died:Connect(function() S.Abort = true end))
        end
    end)
end
track(LP.CharacterAdded:Connect(function(c)
    releaseControl()
    hookCharacter(c)
end))
if LP.Character then hookCharacter(LP.Character) end

------------------------------------------------------------
-- AMBIL TELUR
------------------------------------------------------------
local lastDeliver = 0
local HintShown = false
local lastJump = 0

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- lari lurus dengan kecepatan player (dipaksa lewat velocity supaya tidak melambat)
local function stepRun(tpos, speedOverride)
    local root, h = hrp(), hum()
    local flat = Vector3.new(tpos.X - root.Position.X, 0, tpos.Z - root.Position.Z)
    if flat.Magnitude <= 2.5 then return end
    local dir = flat.Unit
    local speed = speedOverride or S.SpeedValue
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

-- cari telur YANG SAMA: objek lama, slot asal, atau prompt baru di titik jatuh. Tidak pernah telur lain.
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

local function firePrompt(e)
    local pr = e.Prompt
    if not pr then return end
    pcall(function()
        pr.HoldDuration = 0
        pr.RequiresLineOfSight = false
        pr.MaxActivationDistance = 30
    end)
    if fireproximityprompt then pcall(fireproximityprompt, pr) end
end

-- model telur asli (diberi nama Uid) supaya gerakannya bisa dipantau
local function findEggModel(e)
    local uid = e.Record and rawget(e.Record, "Uid")
    if type(uid) == "string" then
        local ok, m = pcall(function() return workspace:FindFirstChild(uid, true) end)
        if ok and m then return m end
    end
    local nl = nearbyNodes(e.Part)
    for _, x in ipairs(nl) do
        if x:IsA("Model") and isUid(x.Name) then return x end
    end
    return nil
end

local function prepareEgg(e)
    e.Home = e.Part.Position
    e.Model = e.Model or findEggModel(e)
    e.ModelHome, e.ModelParent0, e.ModelFollowed = nil, nil, false
    if e.Model then
        e.ModelParent0 = e.Model.Parent
        local ok, pv = pcall(function() return e.Model:GetPivot().Position end)
        if ok then e.ModelHome = pv end
    end
end

-- telur sudah terambil? return ok, state, nama sinyal
local function pickedUp(e, before, enabled0)
    if e.Record and e.State0 ~= nil then
        local st = rawget(e.Record, "State")
        if st ~= nil and st ~= e.State0 then return true, st, "status-record" end
    end
    local m = e.Model
    if m then
        if not m.Parent then return true, nil, "model-hilang" end
        if m.Parent ~= e.ModelParent0 then return true, nil, "model-pindah-parent" end
        local ok, pv = pcall(function() return m:GetPivot().Position end)
        if ok and e.ModelHome and (pv - e.ModelHome).Magnitude > 3.5 then
            local rt = LP.Character and LP.Character:FindFirstChild("HumanoidRootPart")
            if rt and (pv - rt.Position).Magnitude < 12 then e.ModelFollowed = true end
            return true, nil, "model-bergerak"
        end
    end
    if e.Part and e.Part.Parent and e.Home and (e.Part.Position - e.Home).Magnitude > 3.5 then
        return true, nil, "part-bergerak"
    end
    if enabled0 and e.Prompt and (not e.Prompt:IsDescendantOf(workspace) or not e.Prompt.Enabled) then
        return true, nil, "prompt-mati"
    end
    if before and #newCarried(before) > 0 then return true, nil, "objek-baru" end
    if carryingEgg(LP) then return true, nil, "nama-egg" end
    return false
end

local function chaseAndGrab(e0)
    local cur = e0
    prepareEgg(cur)
    local dist0 = (e0.Part.Position - hrp().Position).Magnitude
    local limit = math.clamp(dist0 / math.max(S.SpeedValue, 16) * 1.6 + 15, 25, 150)
    local t0, lastFire, closeFires = tick(), 0, 0
    local before, enabled0
    while tick() - t0 < limit and not S.Abort and RUN.on do
        if not cur.Part or not cur.Part.Parent then
            if before and tick() - lastFire < 0.6 then
                S.LastPick = "part-hilang"
                return true, cur, before
            end
            local nx = relocate(cur)
            if not nx then return false end
            nx.OrigPos, nx.Known = cur.OrigPos, cur.Known
            prepareEgg(nx)
            cur = nx
            before, enabled0, closeFires = nil, nil, 0
        end
        local root = hrp()
        local tpos = cur.Part.Position
        cur.LastPos = tpos
        local dist = (tpos - root.Position).Magnitude
        if dist <= 26 then
            if not before then
                before = snapChar()
                enabled0 = cur.Prompt and cur.Prompt.Enabled
                cur.State0 = cur.Record and rawget(cur.Record, "State") or nil
            end
            if tick() - lastFire >= 0.12 then
                lastFire = tick()
                if dist <= 14 then closeFires += 1 end
                firePrompt(cur)
            end
            local ok, st, sig = pickedUp(cur, before, enabled0)
            if ok then
                if st ~= nil then cur.CarryState = st end
                S.LastPick = sig
                return true, cur, before
            end
            -- pengaman: sudah beberapa kali ditekan dari jarak dekat = anggap terambil, JANGAN muter-muter di dekat penjaga
            if closeFires >= 5 then
                S.LastPick = "diasumsikan"
                return true, cur, before
            end
        end
        if S.FlyApproach and FlyFails < 2 and dist > 40 and not before then
            local okF, whyF = flyLeg(tpos, nil)
            if okF then
                FlyFails = 0
            elseif whyF ~= "abort" then
                FlyFails += 1
            end
        else
            stepRun(tpos)
        end
        task.wait()
    end
    return false
end

-- penjaga: tunggu sampai penjaga di dekat telur tidur dulu (kurangi kena hit)
local function guardAwakeNear(pos)
    for g in pairs(Guards) do
        if g.Parent then
            local p = g.PrimaryPart or g:FindFirstChild("HumanoidRootPart")
            if p and (p.Position - pos).Magnitude < 90 then
                local st = g:GetAttribute("GuardState")
                local sl = g:GetAttribute("Sleeping")
                if (st ~= nil and st ~= "Sleeping") or sl == false then return true end
            end
        else
            Guards[g] = nil
        end
    end
    return false
end

local function waitGuardAsleep(pos, maxWait)
    local t0 = tick()
    local noted = false
    while guardAwakeNear(pos) and tick() - t0 < maxWait and not S.Abort and RUN.on do
        if not noted then
            noted = true
            showError("Penjaga sedang bangun, menunggu tidur...")
        end
        task.wait(0.3)
    end
end

-- visual lokal (opsional): kamera menempel ke kembaran yang diam di base
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
    FakeChar, FakeHum = nil, nil
    releaseControl()
    S.Abort = false
end

-- terbang LURUS & secepat mungkin. Kecepatan otomatis turun kalau server menahan (rubberband),
-- jadi selalu menemukan kecepatan tertinggi yang diterima. return arrived, alasan
function flyLeg(pos, abortFn)
    local root, h = hrp(), hum()
    local parts, orig = {}, {}
    for _, p in ipairs(char():GetDescendants()) do
        if p:IsA("BasePart") then
            parts[#parts + 1] = p
            orig[p] = p.CanCollide
        end
    end
    local bv = Instance.new("BodyVelocity")
    bv.Name = "LIXX_BV"
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Velocity = Vector3.zero
    bv.Parent = root
    h.PlatformStand = true
    S.Flying = true
    local target = pos + Vector3.new(0, 3, 0)
    local spd = math.min(CONFIG.FlyMax, (S.FlyGood or CONFIG.FlyMax) * 2)
    local spd0 = spd
    local t0 = tick()
    local arrived, why = false, "timeout"
    local checkT, checkD = tick(), (target - root.Position).Magnitude
    while tick() - t0 < 60 do
        if S.Abort or not RUN.on then
            why = "abort"
            break
        end
        if abortFn and abortFn() then
            why = "abort"
            break
        end
        if not root.Parent then
            why = "abort"
            break
        end
        local diff = target - root.Position
        local d = diff.Magnitude
        if d < 6 then
            arrived, why = true, "arrived"
            break
        end
        local v = diff.Unit * math.min(spd, math.max(d * 20, 30))
        -- efek glitch halus lewat noise kecepatan (tanpa memutar karakter)
        v = v + Vector3.new((math.random() - 0.5) * 30, (math.random() - 0.5) * 30, (math.random() - 0.5) * 30)
        bv.Velocity = v
        for i = 1, #parts do parts[i].CanCollide = false end
        if FakeHum then
            local cam = workspace.CurrentCamera
            if cam.CameraSubject ~= FakeHum then cam.CameraSubject = FakeHum end
        end
        -- governor: tiap 0.5 detik cek kemajuan nyata; kalau ditahan server, turunkan kecepatan
        if tick() - checkT >= 0.5 then
            local progressed = checkD - d
            local expected = math.min(spd, math.max(d * 20, 30)) * 0.5
            if progressed < expected * 0.3 then
                spd = spd * 0.5
                if spd < 40 then
                    why = "stuck"
                    break
                end
            end
            checkT, checkD = tick(), d
        end
        task.wait()
    end
    if arrived then S.FlyGood = spd end
    S.LastFly = ("mulai=%d akhir=%d hasil=%s"):format(spd0, spd, why)
    pcall(function() bv.Velocity = Vector3.zero end)
    pcall(function() bv:Destroy() end)
    S.Flying = false
    pcall(function() h.PlatformStand = false end)
    for _, p in ipairs(parts) do
        pcall(function() p.CanCollide = orig[p] end)
    end
    if root.Parent then
        root.AssemblyLinearVelocity = Vector3.zero
        if arrived then
            root.CFrame = CFrame.new(target)
        end
    end
    return arrived, why
end

-- lari lurus (cadangan kalau terbang diblokir / macet)
local function runLeg(pos, abortFn)
    local dist0 = (hrp().Position - pos).Magnitude
    local limit = math.clamp(dist0 / math.max(S.SpeedValue, 16) * 1.6 + 15, 20, 180)
    local t0 = tick()
    while tick() - t0 < limit and RUN.on do
        if S.Abort then return false, "abort" end
        if abortFn and abortFn() then return false, "abort" end
        if (hrp().Position - pos).Magnitude <= 8 then return true, "arrived" end
        stepRun(pos, math.max(S.SpeedValue, 150))
        task.wait()
    end
    return (hrp().Position - pos).Magnitude <= 12, "timeout"
end

-- terbang dulu; kalau macet 2x berturut-turut, pakai lari saja. Tidak pernah diam di jalan.
local function moveLeg(pos, abortFn)
    if FlyFails < 2 then
        local ok, why = flyLeg(pos, abortFn)
        if ok then
            FlyFails = 0
            return true, why
        end
        if why == "abort" then return false, why end
        FlyFails += 1
    end
    return runLeg(pos, abortFn)
end

local function isFreeState(st, st0)
    if st == nil then return false end
    if st0 ~= nil and st == st0 then return true end
    local l = tostring(st):lower()
    return (l:find("slot", 1, true) or l:find("drop", 1, true) or l:find("free", 1, true)
        or l:find("ground", 1, true) or l:find("loose", 1, true)) ~= nil
end

-- telur dianggap lepas HANYA dengan bukti kuat:
--  (1) status Record kembali ke slot/jatuh (padahal tadi berubah saat diambil), atau
--  (2) model telur yang tadi benar-benar ikut kita kini balik ke slot asal sementara kita jauh.
-- Tidak ada lagi tebakan lemah (darah berkurang / objek hilang) yang bikin karakter putar balik.
local function lostWatcher(e)
    local t0 = tick()
    local since
    local c = LP.Character
    return function()
        if not e then return false end
        local lostNow = false
        if e.Record and e.CarryState ~= nil then
            local st = rawget(e.Record, "State")
            if st ~= e.CarryState and isFreeState(st, e.State0) then lostNow = true end
        elseif e.Model and e.ModelFollowed and e.ModelHome then
            local ok, pv = pcall(function() return e.Model:GetPivot().Position end)
            local root = c and c:FindFirstChild("HumanoidRootPart")
            if ok and root and (pv - e.ModelHome).Magnitude < 3
                and (root.Position - e.ModelHome).Magnitude > 40 then
                lostNow = true
            end
        end
        if not lostNow then
            since = nil
            return false
        end
        since = since or tick()
        return tick() - since > 1.0 and tick() - t0 > 1.0
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
        ok = moveLeg(S.Forest, abort)
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
    if ok then ok = moveLeg(S.Base, abort) end

    local status = "done"
    if ok then
        local w0 = tick()
        while tick() - w0 < CONFIG.BaseWait do
            if S.Abort then break end
            if e and ((e.Carried and #e.Carried > 0) or e.CarryState ~= nil) and not holding(e) then break end
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
    local wasAbort = S.Abort
    stopFake()
    S.Abort = wasAbort and not lost
    return status
end

-- kalau perjalanan ke base gagal tapi telur TIDAK terbukti lepas: paksa lanjut ke base, JANGAN balik ke telur
local function pushToBase(e)
    if not S.Base then return "abort" end
    for _ = 1, 3 do
        if S.Abort or not RUN.on then return "abort" end
        local ok = runLeg(S.Base, nil)
        if ok then
            task.wait(CONFIG.BaseWait)
            return "done"
        end
    end
    return "abort"
end

local function stealEgg(e0)
    if S.Busy then return end
    if not e0.Part or not e0.Part.Parent then
        showError("Telur sudah tidak ada (diambil player lain / reset).")
        return
    end
    S.Busy, S.Abort = true, false
    local ok, err = pcall(function()
        local e = e0
        e.OrigPos = e.OrigPos or e.Part.Position
        local known = {}
        for _, c in ipairs(AllCache) do known[c.Part] = true end
        e.Known = known
        if S.AntiGuard then waitGuardAsleep(e.Part.Position, 4) end
        for _ = 1, CONFIG.MaxRetry do
            if S.Abort or not RUN.on then break end
            e.Home, e.CarryState, e.Carried = nil, nil, nil
            local got, cur, before = chaseAndGrab(e)
            if not got then break end
            local ce = cur or e
            -- langsung berangkat ke base (tanpa menunggu), daftar objek yang dibawa dicatat sambil jalan
            local snap = before or {}
            task.delay(0.35, function() ce.Carried = newCarried(snap) end)
            local status
            for _ = 1, 2 do
                status = carryHome(ce)
                if status ~= "retry" then break end
            end
            if status == "retry" then status = pushToBase(ce) end
            if status == "done" then
                addHistory(ce)
                return
            elseif status == "abort" then
                return
            end
            -- status "lost" = telur TERBUKTI lepas (kena hit): kejar telur yang SAMA lagi
            task.wait(0.3)
            local ne = relocate(ce)
            if not ne then break end
            ne.OrigPos, ne.Known, ne.LostPos = ce.OrigPos, ce.Known, ce.LostPos
            e = ne
        end
        Failed[e0.Obj] = tick()
    end)
    if not ok then
        showError("steal error: " .. tostring(err))
    end
    releaseControl()
    S.Abort = false
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
    while RUN.on do
        task.wait(0.1)
        if S.Steal and not S.Busy then
            if carryingEgg(LP) and tick() - lastDeliver > 20 then
                S.Busy = true
                S.Abort = false
                pcall(carryHome, nil)
                releaseControl()
                S.Abort = false
                S.Busy = false
            else
                local e = pickByPriority()
                if e then stealEgg(e) end
            end
        end
    end
end)

track(RunService.Heartbeat:Connect(function()
    if S.Speed then
        local c = LP.Character
        local h = c and c:FindFirstChildOfClass("Humanoid")
        if h then h.WalkSpeed = S.SpeedValue end
    end
end))

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
StopHooks[#StopHooks + 1] = function() setAntiTrap(false) end

task.spawn(function()
    local lastChar
    while RUN.on do
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

local GuardOrig = {}
local function setAntiGuard(on)
    S.AntiGuard = on
    if not on then
        for p, o in pairs(GuardOrig) do
            pcall(function()
                p.CanCollide = o[1]
                p.CanTouch = o[2]
            end)
        end
        GuardOrig = {}
    end
end
StopHooks[#StopHooks + 1] = function() setAntiGuard(false) end

task.spawn(function()
    while RUN.on do
        task.wait(1)
        if S.AntiGuard then
            pcall(function()
                for g in pairs(Guards) do
                    if g.Parent then
                        for _, p in ipairs(g:GetDescendants()) do
                            if p:IsA("BasePart") and not GuardOrig[p] then
                                GuardOrig[p] = {p.CanCollide, p.CanTouch}
                                p.CanCollide = false
                                p.CanTouch = false
                            end
                        end
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
                if st == "done" then addHistory(e) end
            end
        end
    end)
    if not ok then showError("duel error: " .. tostring(err)) end
    releaseControl()
    S.Abort = false
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

-- tombol bekukan / lanjutkan refresh otomatis panel
local PanelFrozen = false
local freezeBtn = Instance.new("TextButton")
freezeBtn.Size = UDim2.new(0, 84, 0, 20)
freezeBtn.Position = UDim2.new(1, -118, 0, 3)
freezeBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 60)
freezeBtn.TextColor3 = Color3.new(1, 1, 1)
freezeBtn.Font = Enum.Font.GothamBold
freezeBtn.TextSize = 10
freezeBtn.Text = "Auto refresh: ON"
freezeBtn.Parent = PanelFrame
Instance.new("UICorner", freezeBtn)

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

local lastSig, lastBuild = "", 0
local function refreshPanel(force)
    if not PanelFrame.Visible then return end
    if PanelFrozen and not force then return end
    if not force and tick() - lastBuild < 0.7 then return end
    local eggs = EggCache
    local parts = {}
    for idx, e in ipairs(eggs) do
        if idx > 120 then break end
        parts[#parts + 1] = ("%d:%d:%s:%s:%s"):format(e.Part.Position.X, e.Part.Position.Z, e.Name, e.Rarity, tostring(e.Image))
    end
    local sig = table.concat(parts, "|")
    if sig == lastSig and not force then return end
    lastSig = sig
    lastBuild = tick()
    local scrollPos = PanelList.CanvasPosition
    clear(PanelList)
    for idx, e in ipairs(eggs) do
        if idx > 120 then break end
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
        local mut = e.Mutation and ("\nMutasi: " .. e.Mutation) or ""
        lbl.Text = "<b>" .. e.Name .. "</b> <font color=\"" .. rarityColor(e.Rarity) .. "\">[" .. e.Rarity ..
            "]</font>\nTipe: " .. tostring(e.Type) .. " | Berat: " .. tostring(e.Weight) ..
            "\nWilayah: " .. tostring(e.Area) .. inc .. mut
        lbl.Parent = row

        mkRowButton(row, "STEAL", Color3.fromRGB(40, 160, 70), function()
            task.spawn(stealEgg, e)
        end)
    end
    task.defer(function() PanelList.CanvasPosition = scrollPos end)
end

freezeBtn.MouseButton1Click:Connect(function()
    PanelFrozen = not PanelFrozen
    freezeBtn.Text = PanelFrozen and "Auto refresh: OFF" or "Auto refresh: ON"
    freezeBtn.BackgroundColor3 = PanelFrozen and Color3.fromRGB(150, 60, 60) or Color3.fromRGB(50, 50, 60)
    if not PanelFrozen then pcall(refreshPanel, true) end
end)

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
    while RUN.on do
        task.wait(0.5)
        pcall(refreshPanel, false)
    end
end)
task.spawn(function()
    while RUN.on do
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
StopHooks[#StopHooks + 1] = function() Rayfield:Destroy() end

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
        if not v then
            S.Abort = true
            task.delay(0.3, releaseControl)
        end
        if v and not S.Forest then
            Rayfield:Notify({Title = "LIXX EGG", Content = "Forest belum di-set (Setting). Tanpa Forest langsung ke base.", Duration = 5})
        end
    end,
})
TabEgg:CreateButton({
    Name = "Panel (buka panel steal)",
    Callback = function()
        PanelFrame.Visible = true
        pcall(refreshPanel, true)
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
    Name = "Speed Boost / Kecepatan Lari (cadangan & dasar)", Range = {16, 400}, Increment = 1, Suffix = " speed",
    CurrentValue = 150, Flag = "SpeedSlider",
    Callback = function(v) S.SpeedValue = v end,
})
TabEgg:CreateToggle({
    Name = "Speed Boost On/Off", CurrentValue = false, Flag = "SpeedToggle",
    Callback = function(v)
        S.Speed = v
        if not v then pcall(function() hum().WalkSpeed = 16 end) end
    end,
})
TabEgg:CreateToggle({
    Name = "Mendekati telur dengan terbang (lebih cepat, otomatis turun kalau ditahan)", CurrentValue = true, Flag = "FlyApproach",
    Callback = function(v) S.FlyApproach = v end,
})
TabEgg:CreateToggle({
    Name = "Visual lokal: kamera diam di base saat terbang (eksperimen)", CurrentValue = false, Flag = "FakeVisual",
    Callback = function(v) S.FakeVisual = v end,
})
TabEgg:CreateToggle({
    Name = "Baca data game (getgc) untuk nama/rarity/berat", CurrentValue = true, Flag = "GCScan",
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
TabSet:CreateSection("Darurat")
TabSet:CreateButton({
    Name = "RESET / Lepas Kontrol (kalau karakter atau kamera nyangkut)",
    Callback = function()
        S.Steal = false
        S.Busy = false
        releaseControl()
        task.delay(0.5, function() S.Abort = false end)
        Rayfield:Notify({Title = "LIXX EGG", Content = "Kontrol dilepas. Steal dimatikan.", Duration = 4})
    end,
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
TabSet:CreateToggle({
    Name = "Anti Penjaga (tunggu penjaga tidur + netralkan tubuh penjaga lokal)", CurrentValue = true, Flag = "AntiGuard",
    Callback = function(v) setAntiGuard(v) end,
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
