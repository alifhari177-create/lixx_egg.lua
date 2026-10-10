--[[
    LIXX EGG v3 - Steal an Egg
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
    -- urutan panel: paling bagus di atas
    PanelOrder = {"Divine", "Eternal", "Secret", "Cosmic", "Mythic", "Exotic", "Exclusive", "Limited",
        "Squishy God", "Rainbow", "Celestial", "Legendary", "SuperRare", "Epic", "Rare", "Uncommon", "Common"},
    ClubPattern = {"club", "bat", "wood", "stick", "pentung"},
    BaseNamePatterns = {"plot", "homestead"},
    AreaWords = {"snow", "volcano", "abyss", "ocean", "prehistoric", "cosmic", "sakura", "titan",
        "enchanted", "forest", "desert", "jungle", "lava", "candy"},
    ForestWait = 2,   -- detik berhenti di Forest
    BaseWait = 3,     -- detik diam di base setelah sampai
    ScanInterval = 1,
    MaxRetry = 15,    -- maksimal ulang ambil telur yang sama (kena hit penjaga)
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
-- DATA GAME (rarity, nama, gambar resmi: ReplicatedStorage.Data.Assets)
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

local function entryRarity(e)
    local ok, r = pcall(function() return e.Rarity.DisplayName end)
    if ok and r then return normRarity(r) end
    ok, r = pcall(function() return e.Rarity end)
    if ok and type(r) == "string" then return normRarity(r) end
    return nil
end

-- baca tabel data telur langsung dari memori game (getgc), jalan jarang & ringan
local ID_FIELDS = {"Id", "ID", "id", "UUID", "Uuid", "Guid", "GUID", "EggId", "EggID", "Uid", "UID"}
local GCDicts, GCRecs = {}, {}

local function gcRecordFor(name)
    local r = GCRecs[name]
    if r then return r end
    for _, d in ipairs(GCDicts) do
        local v = rawget(d, name)
        if type(v) == "table" then return v end
    end
    return nil
end

local function gcScan(names)
    if not getgc or #names == 0 then return end
    local set, samples = {}, {}
    for i, n in ipairs(names) do
        set[n] = true
        if i <= 3 then samples[#samples + 1] = n end
    end
    local dicts, recs = {}, {}
    local count = 0
    local ok = pcall(function()
        for _, t in ipairs(getgc(true)) do
            if type(t) == "table" then
                count += 1
                if count % 15000 == 0 then task.wait() end
                if rawget(t, "Src") == nil and rawget(t, "Obj") == nil and t ~= set then
                    for i = 1, #samples do
                        local v = rawget(t, samples[i])
                        if type(v) == "table" and v ~= t then
                            dicts[#dicts + 1] = t
                            break
                        end
                    end
                    for i = 1, #ID_FIELDS do
                        local v = rawget(t, ID_FIELDS[i])
                        if type(v) == "string" and set[v] then
                            recs[v] = t
                            break
                        end
                    end
                end
            end
        end
    end)
    if ok then GCDicts, GCRecs = dicts, recs end
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
            if lk:find("rarity") or lk:find("tier") then
                if tv == "string" then info.Rarity = info.Rarity or normRarity(sv) end
            elseif lk:find("weight") or lk:find("mass") then
                info.Weight = info.Weight or sv
            elseif lk:find("price") or lk:find("cost") or lk:find("worth") or lk:find("sell") or lk == "value" then
                info.Price = info.Price or sv
            elseif lk:find("size") or lk:find("scale") then
                info.SizeAttr = info.SizeAttr or sv
            elseif lk:find("area") or lk:find("zone") or lk:find("biome") or lk:find("spawn")
                or lk:find("location") or lk:find("region") then
                if tv == "string" then info.Area = info.Area or sv end
            elseif lk:find("image") or lk:find("icon") or lk:find("thumb") then
                info.Image = info.Image or (tv == "number" and ("rbxassetid://" .. sv) or sv)
            elseif lk:find("pet") or lk:find("content") or lk:find("reward") then
                info.Content = info.Content or sv
            elseif tv == "string" and (lk:find("category") or lk:find("species") or lk:find("type")
                or lk:find("asset") or lk:find("egg")) then
                info.Type = info.Type or sv
                local ent = entryOf(sv)
                if ent then
                    info.Rarity = info.Rarity or entryRarity(ent)
                    info.Name = info.Name or entryField(ent, {"DisplayName", "Name"}) or sv
                    info.Image = info.Image or entryField(ent, {"Image", "Icon", "ImageId", "Thumbnail"})
                end
            elseif tv == "string" and lk:find("name") then
                info.Name = info.Name or sv
            end
        end
    end
end

local InfoCache = setmetatable({}, {__mode = "k"})
local AdorneeMap = {}
local DataCache = {}

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
                local nm = c.Name:lower()
                for _, w in ipairs(CONFIG.AreaWords) do
                    if nm:find(w, 1, true) then
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
                        break
                    end
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

local function resolveInfo(owner)
    local c = InfoCache[owner]
    if c and tick() - c.T < 5 then return c end

    local info = {T = tick(), Src = ""}
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
    if #owner.Name >= 4 and (owner.Name:find("%d") or #owner.Name >= 12) then
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

    for _, node in ipairs(nodes) do
        for k, v in pairs(node:GetAttributes()) do
            local lk = tostring(k):lower()
            if not info.Area and type(v) == "string" and v ~= ""
                and (lk:find("area") or lk:find("zone") or lk:find("biome") or lk:find("world")
                    or lk:find("spawn") or lk:find("location") or lk:find("region")) then
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
                    info.Rarity = info.Rarity or entryRarity(ent)
                    info.Name = info.Name or entryField(ent, {"DisplayName", "Name"}) or v
                    info.Image = info.Image or entryField(ent, {"Image", "Icon", "ImageId", "Thumbnail"})
                    info.Type = info.Type or v
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
                if ent then
                    info.Rarity = info.Rarity or entryRarity(ent)
                    info.Name = info.Name or entryField(ent, {"DisplayName", "Name"}) or node.Value
                    info.Image = info.Image or entryField(ent, {"Image", "Icon", "ImageId", "Thumbnail"})
                end
            end
        end
    end

    do
        local rec = gcRecordFor(owner.Name)
        if rec then
            info.Src = info.Src .. "gc "
            pcall(applyRecord, info, rec, 0)
        end
    end

    local byName = entryOf(owner.Name)
    if byName then
        info.Rarity = info.Rarity or entryRarity(byName)
        info.Name = info.Name or entryField(byName, {"DisplayName", "Name"}) or owner.Name
        info.Image = info.Image or entryField(byName, {"Image", "Icon", "ImageId", "Thumbnail"})
    end

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

    if not info.Rarity then
        local rn = matchRarity(owner.Name)
        if rn then info.Rarity = rn end
    end
    info.Rarity = info.Rarity or "Unknown"
    info.Name = info.Name or info.Type or ("Egg " .. owner.Name:sub(1, 6))
    info.Content = info.Content or "-"
    InfoCache[owner] = info
    return info
end

------------------------------------------------------------
-- ANALYZER (scan telur tiap detik, ringan: pakai daftar prompt yang dilacak)
------------------------------------------------------------
local EggCache, AllCache, ZoneCounts = {}, {}, {}
local Banner, DumpBox, DumpFrame, PanelFrame

local Prompts = {}
local OwnerCache = setmetatable({}, {__mode = "k"})
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
            local info = resolveInfo(o)
            e.Rarity, e.Name, e.Image = info.Rarity, info.Name, info.Image
            e.Content, e.Src = info.Content, info.Src
            e.Type, e.Weight, e.Price = info.Type or "-", info.Weight or "-", info.Price or "-"
            e.SizeAttr = info.SizeAttr
            local okS, sz = pcall(function()
                if o:IsA("Model") then return o:GetExtentsSize() end
                return e.Part.Size
            end)
            e.Size = (okS and sz) and ("%.1f x %.1f x %.1f"):format(sz.X, sz.Y, sz.Z) or "-"
            e.Area = info.Area or areaOf(e.Part.Position)
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
            if top then
                Banner.Text = "Tertinggi: " .. top.Name .. " [" .. top.Rarity .. "] | total " .. #EggCache
            else
                Banner.Text = "Analyzer: tidak ada telur (semua " .. #AllCache .. " terfilter)"
            end
        end
        task.wait(CONFIG.ScanInterval)
    end
end)

------------------------------------------------------------
-- DUMP / KALIBRASI
------------------------------------------------------------
local function describe(inst, depth)
    local kids = {}
    for _, c in ipairs(inst:GetChildren()) do kids[#kids + 1] = c.Name .. ":" .. c.ClassName end
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

local function runGC()
    if not getgc or #AllCache == 0 then return end
    local nm = {}
    for _, e in ipairs(AllCache) do nm[#nm + 1] = e.Obj.Name end
    pcall(gcScan, nm)
    InfoCache = setmetatable({}, {__mode = "k"})
end

local function dumpInfo()
    runGC()
    local out = {"== LIXX EGG DUMP v3 ==",
        ("OnlyRoot=%s IgnoreBase=%s"):format(tostring(S.OnlyRoot), tostring(S.IgnoreBase)),
        ("Lolos filter: %d | Semua prompt: %d"):format(#EggCache, #AllCache)}
    out[#out + 1] = "-- ZONA (key = jumlah) --"
    for k, n in pairs(ZoneCounts) do
        out[#out + 1] = ("%s = %d%s"):format(k, n, S.BaseKeys[k] and "  [BASE]" or "")
    end
    out[#out + 1] = "-- 6 telur pertama (semua zona) --"
    for i, e in ipairs(AllCache) do
        if i > 6 then break end
        out[#out + 1] = ("%s | zona=%s | %s | nama=%s | tipe=%s | berat=%s | harga=%s | src=%s | img=%s"):format(
            e.Obj:GetFullName(), e.Zone, e.Rarity, e.Name, tostring(e.Type), tostring(e.Weight),
            tostring(e.Price), e.Src, tostring(e.Image))
        out[#out + 1] = ("  area=%s | ukuran=%s | sizeAttr=%s | isi=%s"):format(
            tostring(e.Area), tostring(e.Size), tostring(e.SizeAttr), tostring(e.Content))
        out[#out + 1] = describe(e.Obj, 1)
        local gl = AdorneeMap[e.Part] or AdorneeMap[e.Obj]
        if gl then
            for _, g in ipairs(gl) do
                out[#out + 1] = "  ADORNEE GUI: " .. g:GetFullName()
                for _, dd in ipairs(g:GetDescendants()) do
                    if dd:IsA("TextLabel") then
                        out[#out + 1] = "    text: " .. cleanText(dd.Text)
                    elseif dd:IsA("ImageLabel") then
                        out[#out + 1] = "    image: " .. dd.Image
                    end
                end
            end
        end
        if #e.Obj.Name >= 4 then
            local ex = findData(e.Obj.Name)
            if ex then
                out[#out + 1] = "  RS MATCH: " .. ex:GetFullName()
                out[#out + 1] = describe(ex, 2)
            end
        end
        local n = 0
        for _, d in ipairs(e.Obj:GetDescendants()) do
            n += 1
            if n > 10 then break end
            out[#out + 1] = describe(d, 2)
        end
        if e.Obj.Parent then out[#out + 1] = describe(e.Obj.Parent, 1) end
    end
    local recCount = 0
    for _ in pairs(GCRecs) do recCount += 1 end
    out[#out + 1] = ("-- GC: getgc=%s | dict=%d | rec=%d --"):format(tostring(getgc ~= nil), #GCDicts, recCount)
    local firstEgg = AllCache[1]
    if firstEgg then
        local rec = gcRecordFor(firstEgg.Obj.Name)
        out[#out + 1] = "REKAM DATA telur pertama: " .. (rec and "ADA" or "TIDAK ADA")
        if rec then dumpTable(rec, out, 1, {n = 80}, 1) end
    end
    local dir = getDir()
    if dir then
        local cnt = 0
        for k, v in pairs(dir) do
            cnt += 1
            if cnt > 8 then break end
            local kv = {}
            if type(v) == "table" then
                for kk, vv in pairs(v) do
                    kv[#kv + 1] = tostring(kk) .. "=" .. tostring(vv)
                    if #kv >= 12 then break end
                end
            end
            out[#out + 1] = "DIR " .. tostring(k) .. ": " .. table.concat(kv, ", ")
        end
    end
    local names = {}
    for d in pairs(Prompts) do names[d.Name] = (names[d.Name] or 0) + 1 end
    for k, v in pairs(names) do out[#out + 1] = "prompt '" .. k .. "' x" .. v end
    local c = LP.Character
    if c then
        local kids = {}
        for _, k in ipairs(c:GetChildren()) do kids[#kids + 1] = k.Name .. ":" .. k.ClassName end
        out[#out + 1] = "karakter: " .. table.concat(kids, ",") .. " attr{" .. attrStr(c) .. "}"
    end
    local txt = table.concat(out, "\n")
    if setclipboard then pcall(setclipboard, txt) end
    if DumpBox then DumpBox.Text = txt end
    if DumpFrame then DumpFrame.Visible = true end
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

-- apakah telur e sedang kita bawa?
local function hasEgg(e)
    local c = LP.Character
    if not c then return false end
    if e and e.Obj and e.Obj.Parent and e.Obj:IsDescendantOf(c) then return true end
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
            sendTelegram(("LIXX EGG\nTelur: %s\nRarity: %s\nTipe: %s\nBerat: %s\nHarga: %s\nArea: %s\nPlayer: %s")
                :format(e.Name, e.Rarity, tostring(e.Type), tostring(e.Weight), tostring(e.Price),
                    tostring(e.Area), LP.Name), eggImageUrl(e))
        end)
    end
end

------------------------------------------------------------
-- AMBIL TELUR: LARI KE TELUR (fokus 1 telur) -> TERBANG GLITCH KE BASE
------------------------------------------------------------
-- 1) lari ke telur sesuai kecepatan player (dipaksa lewat velocity supaya tidak melambat)
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
    return hasEgg(e) or not e.Obj.Parent or not pr:IsDescendantOf(workspace) or not pr.Enabled
end

local function grab(e)
    for _ = 1, 20 do
        if grabOnce(e) then return true end
    end
    return hasEgg(e)
end

-- cari telur yang sama kalau objek lama hilang/jatuh (di wilayah mana pun)
local function relocate(e, fromPos)
    local best, bd
    for _, c in ipairs(AllCache) do
        if c.Prompt and c.Part and c.Part.Parent and not isInsideCharacter(c.Obj) then
            if c.Obj == e.Obj or c.Obj.Name == e.Obj.Name then return c end
            if c.Rarity == e.Rarity then
                local d = (c.Part.Position - fromPos).Magnitude
                if d < 150 and (not bd or d < bd) then best, bd = c, d end
            end
        end
    end
    return best
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function chaseAndGrab(e, timeout)
    local t0 = tick()
    local cur = e
    local lastPos = e.Part.Position
    local lastJump = 0
    while tick() - t0 < timeout and not S.Abort do
        if not cur.Part or not cur.Part.Parent then
            cur = relocate(cur, lastPos)
            if not cur then return false end
        end
        local root, h = hrp(), hum()
        local tpos = cur.Part.Position
        lastPos = tpos
        local dist = (tpos - root.Position).Magnitude
        if dist <= 26 then
            if grabOnce(cur) then return true, cur end
        end
        local flat = Vector3.new(tpos.X - root.Position.X, 0, tpos.Z - root.Position.Z)
        if flat.Magnitude > 2.5 then
            local dir = flat.Unit
            local speed = S.SpeedValue
            h.WalkSpeed = speed
            h:MoveTo(tpos)
            local v = root.AssemblyLinearVelocity
            root.AssemblyLinearVelocity = Vector3.new(dir.X * speed, v.Y, dir.Z * speed)
            -- lompat kalau ada penghalang
            if tick() - lastJump > 0.4 then
                rayParams.FilterDescendantsInstances = {char()}
                local hit = workspace:Raycast(root.Position, dir * 5, rayParams)
                if hit and hit.Instance.CanCollide or (tpos.Y - root.Position.Y > 5) then
                    h.Jump = true
                    lastJump = tick()
                end
            end
        end
        task.wait()
    end
    return false
end

-- 2) visual lokal: kamera menempel ke "kembaran" kita yang diam di base
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

-- 3) terbang LURUS & sangat cepat (tampak glitch bagi player lain)
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
    local target = pos + Vector3.new(0, 3, 0)
    local t0 = tick()
    local arrived = false
    while tick() - t0 < 60 and not S.Abort do
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
    h.PlatformStand = false
    root.AssemblyLinearVelocity = Vector3.zero
    if arrived then root.CFrame = CFrame.new(target) end
    return arrived
end

local lastDeliver = 0
local HintShown = false

-- bawa telur ke (Forest ->) Base. return true kalau sampai tanpa kehilangan telur
local function carryHome(e, detectable)
    lastDeliver = tick()
    if not S.Base then
        showError("Base belum di-set! Menu Setting > Set Posisi Base")
        return false
    end
    local h = hum()
    local hp0 = h.Health
    local lost = false
    local conn = h.HealthChanged:Connect(function(hp)
        if hp < hp0 - 0.5 then lost = true end
        if hp > hp0 then hp0 = hp end
    end)
    local t0 = tick()
    local function abort()
        if lost then return true end
        if detectable and tick() - t0 > 0.8 and not hasEgg(e) then return true end
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
    if ok then
        -- diam di base beberapa detik, telur masuk otomatis
        local w0 = tick()
        while tick() - w0 < CONFIG.BaseWait do
            if detectable and not hasEgg(e) then break end
            task.wait(0.1)
        end
    end
    conn:Disconnect()
    stopFake()
    return ok
end

local Failed = {}

local function stealEgg(e0)
    if S.Busy then return end
    S.Busy, S.Abort = true, false
    local ok, err = pcall(function()
        local e = e0
        for _ = 1, CONFIG.MaxRetry do
            if S.Abort then break end
            if not e.Part or not e.Part.Parent then
                e = relocate(e, hrp().Position)
                if not e then break end
            end
            local got, cur = chaseAndGrab(e, 40)
            if not got then break end
            e = cur or e
            task.wait(0.15)
            local detectable = hasEgg(e)
            if carryHome(e, detectable) then
                addHistory(e)
                return
            end
            -- kena hit penjaga / telur lepas: ambil lagi telur yang sama sampai dapat
            task.wait(0.3)
            local ne = relocate(e, hrp().Position)
            if not ne then break end
            e = ne
        end
        Failed[e0.Obj] = tick()
    end)
    if not ok then
        pcall(stopFake)
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
                pcall(carryHome, nil, false)
                S.Busy = false
            else
                local e = pickByPriority()
                if e then stealEgg(e) end
            end
        end
    end
end)

-- GC ringan: hanya kalau panel dibuka / steal aktif, tiap 45 detik
task.spawn(function()
    task.wait(6)
    while true do
        if S.GCScan and getgc and (S.Steal or (PanelFrame and PanelFrame.Visible)) then
            runGC()
        end
        task.wait(45)
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
            if grab(e) then
                task.wait(0.15)
                if carryHome(e, hasEgg(e)) then addHistory(e) end
            end
        end
    end)
    if not ok then
        pcall(stopFake)
        showError("duel error: " .. tostring(err))
    end
    duelBusy, S.Busy = false, false
end

------------------------------------------------------------
-- GUI KUSTOM (Panel telur, Duel list, banner, dump, tombol L)
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

-- gambar telur: ikon cadangan selalu ada, gambar/viewport ditumpuk di atasnya
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
    else
        local vp = Instance.new("ViewportFrame")
        vp.Size = UDim2.new(1, 0, 1, 0)
        vp.BackgroundTransparency = 1
        vp.Ambient = Color3.fromRGB(200, 200, 200)
        vp.LightColor = Color3.fromRGB(255, 255, 255)
        vp.Parent = holder
        pcall(function()
            local src = e.Obj:IsA("Model") and e.Obj or e.Part
            local was = src.Archivable
            src.Archivable = true
            local clone = src:Clone()
            src.Archivable = was
            if not clone then return end
            for _, d in ipairs(clone:GetDescendants()) do
                if d:IsA("BaseScript") or d:IsA("BillboardGui") or d:IsA("SurfaceGui")
                    or d:IsA("ProximityPrompt") then
                    d:Destroy()
                end
            end
            clone.Parent = vp
            local cf, size
            if clone:IsA("Model") then
                cf, size = clone:GetBoundingBox()
            else
                cf, size = clone.CFrame, clone.Size
            end
            local cam = Instance.new("Camera")
            cam.Parent = vp
            vp.CurrentCamera = cam
            local dist = math.max(size.Magnitude, 1) * 1.1
            cam.CFrame = CFrame.new(cf.Position + Vector3.new(dist * 0.6, dist * 0.5, dist), cf.Position)
        end)
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
        lbl.Text = "<b>" .. e.Name .. "</b> <font color=\"" .. rarityColor(e.Rarity) .. "\">[" .. e.Rarity ..
            "]</font>\nTipe: " .. tostring(e.Type) .. " | Berat: " .. tostring(e.Weight) ..
            "\nWilayah: " .. tostring(e.Area)
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
    for k, n in pairs(ZoneCounts) do opts[#opts + 1] = k .. " (" .. n .. ")" end
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
    Name = "Baca data game (getgc) untuk berat/tipe/harga", CurrentValue = true, Flag = "GCScan",
    Callback = function(v) S.GCScan = v end,
})
TabEgg:CreateButton({
    Name = "Dump Analisa (tampil + copy)",
    Callback = function() pcall(dumpInfo) end,
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
