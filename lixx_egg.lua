--[[
    LIXX EGG v2 - Steal an Egg
    UI   : Rayfield
    Menu : Auto Egg | History Egg | Duel Player | Notifikasi | Setting
]]

------------------------------------------------------------
-- CONFIG
------------------------------------------------------------
local CONFIG = {
    PromptName = "CarryAreaEgg",      -- nama ProximityPrompt untuk ambil telur
    EggFolder = nil,                  -- nil = scan seluruh workspace
    EggNamePattern = "egg",           -- dipakai untuk deteksi player bawa telur
    TargetRarities = {"Divine", "Eternal", "Secret"}, -- prioritas auto steal
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
    History = {}, Busy = false,
    CarryMode = "Terbang Cepat", FlySpeed = 150, HopDist = 20, HopDelay = 0.25,
}

------------------------------------------------------------
-- GUI ROOT (dibuat paling awal supaya error bisa ditampilkan)
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
    t.Size = UDim2.new(0.8, 0, 0, 60)
    t.Position = UDim2.new(0.1, 0, 0.05, 0)
    t.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
    t.TextColor3 = Color3.new(1, 1, 1)
    t.TextWrapped = true
    t.TextSize = 14
    t.Font = Enum.Font.GothamBold
    t.Text = "LIXX EGG: " .. tostring(msg)
    t.Parent = Gui
    task.delay(15, function() t:Destroy() end)
end

------------------------------------------------------------
-- HELPERS
------------------------------------------------------------
local function char() return LP.Character or LP.CharacterAdded:Wait() end
local function hrp() return char():WaitForChild("HumanoidRootPart") end
local function hum() return char():WaitForChild("Humanoid") end

local function tp(pos)
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

------------------------------------------------------------
-- DATA GAME (rarity, nama, gambar resmi dari ReplicatedStorage.Data.Assets)
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

-- area / wilayah: cari object bernama area (Snow, Volcano, dst) lalu ambil yang terdekat
local Anchors, lastAnchor = {}, 0
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
    if c and tick() - c.T < 3 then return c end

    local info = {T = tick(), Rarity = nil, Name = nil, Image = nil, Content = nil, Src = ""}
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

    -- GUI (Billboard/Surface) di PlayerGui yang menempel ke telur lewat Adornee
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
    -- data telur di ReplicatedStorage dengan nama sama (biasanya ID unik)
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
            if not info.SizeAttr and type(v) ~= "table"
                and (lk:find("size") or lk:find("weight") or lk:find("scale")) then
                info.SizeAttr = tostring(v)
            end
            if type(v) == "string" and v ~= "" then
                local ent = entryOf(v)
                if ent then
                    info.Rarity = info.Rarity or entryRarity(ent)
                    info.Name = info.Name or entryField(ent, {"DisplayName", "Name"}) or v
                    info.Image = info.Image or entryField(ent, {"Image", "Icon", "ImageId", "Thumbnail"})
                    info.Src = info.Src .. "assets:" .. v .. " "
                elseif lk:find("rarity") or lk:find("tier") then
                    info.Rarity = info.Rarity or normRarity(v)
                    info.Src = info.Src .. "attr:" .. tostring(k) .. " "
                elseif lk:find("pet") or lk:find("content") then
                    info.Content = info.Content or v
                elseif lk:find("name") then
                    info.Name = info.Name or v
                end
            elseif (lk:find("rarity") or lk:find("tier")) and v ~= nil then
                info.Rarity = info.Rarity or normRarity(v)
            end
        end
        if node:IsA("ValueBase") then
            local lk = node.Name:lower()
            if lk:find("rarity") or lk:find("tier") then
                info.Rarity = info.Rarity or normRarity(node.Value)
                info.Src = info.Src .. "value "
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
    info.Name = info.Name or owner.Name
    info.Content = info.Content or "-"
    InfoCache[owner] = info
    return info
end

------------------------------------------------------------
-- ANALYZER (scan telur tiap detik)
------------------------------------------------------------
local EggCache, AllCache, ZoneCounts = {}, {}, {}
local Banner, DumpBox, DumpFrame

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

local function rescan()
    if tick() - lastAnchor > 15 then
        lastAnchor = tick()
        pcall(scanAnchors)
    end
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

    local found, byOwner = {}, {}
    local root = CONFIG.EggFolder or workspace
    local i = 0
    for _, d in ipairs(root:GetDescendants()) do
        i += 1
        if i % 4000 == 0 then task.wait() end
        if d:IsA("ProximityPrompt") and d.Name == CONFIG.PromptName then
            local o = d.Parent
            if o and o:IsA("Attachment") then o = o.Parent end
            if o and o:IsA("BasePart") and o.Parent and o.Parent:IsA("Model")
                and o.Parent ~= workspace and smallModel(o.Parent) then
                o = o.Parent
            end
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

local function scanEggs() return EggCache end

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

local function describe(inst, depth)
    local kids = {}
    for _, c in ipairs(inst:GetChildren()) do kids[#kids + 1] = c.Name .. ":" .. c.ClassName end
    return string.rep("  ", depth) .. inst.Name .. " (" .. inst.ClassName .. ") attr{" .. attrStr(inst)
        .. "} kids{" .. table.concat(kids, ",") .. "}"
end

local function dumpInfo()
    local out = {"== LIXX EGG DUMP v2 ==",
        ("Mode=%s OnlyRoot=%s IgnoreBase=%s"):format(S.Mode, tostring(S.OnlyRoot), tostring(S.IgnoreBase)),
        ("Lolos filter: %d | Semua prompt: %d"):format(#EggCache, #AllCache)}
    out[#out + 1] = "-- ZONA (key = jumlah) --"
    for k, n in pairs(ZoneCounts) do
        out[#out + 1] = ("%s = %d%s"):format(k, n, S.BaseKeys[k] and "  [BASE]" or "")
    end
    out[#out + 1] = "-- 8 telur pertama (semua zona) --"
    for i, e in ipairs(AllCache) do
        if i > 8 then break end
        out[#out + 1] = ("%s | zona=%s | %s | nama=%s | src=%s | img=%s"):format(
            e.Obj:GetFullName(), e.Zone, e.Rarity, e.Name, e.Src, tostring(e.Image))
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
            if n > 12 then break end
            out[#out + 1] = describe(d, 2)
        end
        if e.Obj.Parent then out[#out + 1] = describe(e.Obj.Parent, 1) end
    end
    local names = {}
    for _, d in ipairs(workspace:GetDescendants()) do
        if d:IsA("ProximityPrompt") then names[d.Name] = (names[d.Name] or 0) + 1 end
    end
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
        lines[#lines + 1] = ("[%s] %s | %s | %s"):format(h.Time, h.Name, h.Rarity, h.Content)
    end
    HistoryParagraph:Set({
        Title = "History (" .. #S.History .. ")",
        Content = #lines > 0 and table.concat(lines, "\n") or "Belum ada history.",
    })
end

local function addHistory(e)
    S.History[#S.History + 1] = {
        Time = os.date("%H:%M:%S"), Name = e.Name, Rarity = e.Rarity, Content = e.Content,
    }
    pcall(refreshHistory)
    if S.Notif then
        task.spawn(function()
            sendTelegram(("LIXX EGG\nTelur: %s\nRarity: %s\nUkuran: %s\nArea: %s\nIsi: %s\nPlayer: %s")
                :format(e.Name, e.Rarity, tostring(e.Size), tostring(e.Area), tostring(e.Content), LP.Name), eggImageUrl(e))
        end)
    end
end

------------------------------------------------------------
-- GERAK (Teleport -> Tween -> Jalan, otomatis fallback)
------------------------------------------------------------
local function dist2(pos) return (hrp().Position - pos).Magnitude end

local function walkTo(pos, timeout, stop)
    stop = stop or 6
    local t0 = tick()
    local points = {}
    pcall(function()
        local path = PathfindingService:CreatePath({AgentRadius = 2, AgentHeight = 5, AgentCanJump = true})
        path:ComputeAsync(hrp().Position, pos)
        if path.Status == Enum.PathStatus.Success then points = path:GetWaypoints() end
    end)
    if #points == 0 then
        points = {{Position = pos, Action = Enum.PathWaypointAction.Walk}}
    end
    for _, w in ipairs(points) do
        if tick() - t0 > timeout then break end
        if w.Action == Enum.PathWaypointAction.Jump then hum().Jump = true end
        hum().WalkSpeed = S.SpeedValue
        hum():MoveTo(w.Position)
        local t1 = tick()
        while tick() - t1 < 2.5 and (hrp().Position - w.Position).Magnitude > 4 do
            if dist2(pos) <= stop then return true end
            hum().WalkSpeed = S.SpeedValue
            task.wait(0.03)
        end
    end
    return dist2(pos) <= stop + 5
end

local function tweenTo(pos)
    local root = hrp()
    local d = (root.Position - pos).Magnitude
    local dur = math.max(d / math.max(S.TweenSpeed, 50), 0.03)
    local tw = TweenService:Create(root, TweenInfo.new(dur, Enum.EasingStyle.Linear),
        {CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))})
    local done = false
    tw.Completed:Connect(function() done = true end)
    tw:Play()
    local t0 = tick()
    while not done and tick() - t0 < dur + 1 do task.wait() end
end

local function moveTo(pos, timeout, stop)
    stop = stop or 8
    if S.Mode == "Teleport" then
        tp(pos)
        task.wait(0.1)
        if dist2(pos) <= 25 then return true end
    end
    if S.Mode ~= "Jalan" then
        tweenTo(pos)
        task.wait(0.05)
        if dist2(pos) <= 25 then return true end
    end
    return walkTo(pos, timeout or 40, stop)
end

-- gerak SAAT BAWA TELUR ------------------------------------
local function flyTo(pos, speed, timeout)
    local root, h = hrp(), hum()
    speed = math.max(speed, 20)
    local parts = {}
    for _, p in ipairs(char():GetDescendants()) do
        if p:IsA("BasePart") then parts[#parts + 1] = p end
    end
    local bv = Instance.new("BodyVelocity")
    bv.MaxForce = Vector3.new(1e9, 1e9, 1e9)
    bv.Velocity = Vector3.zero
    bv.Parent = root
    h.PlatformStand = true
    local t0 = tick()
    local cruise = math.max(root.Position.Y, pos.Y) + 30
    local wps = {
        Vector3.new(root.Position.X, cruise, root.Position.Z),
        Vector3.new(pos.X, cruise, pos.Z),
        pos + Vector3.new(0, 3, 0),
    }
    for _, wp in ipairs(wps) do
        while tick() - t0 < timeout do
            local diff = wp - root.Position
            if diff.Magnitude < 5 then break end
            bv.Velocity = diff.Unit * math.min(speed, diff.Magnitude * 8)
            for _, p in ipairs(parts) do p.CanCollide = false end
            task.wait()
        end
    end
    bv.Velocity = Vector3.zero
    bv:Destroy()
    h.PlatformStand = false
    root.AssemblyLinearVelocity = Vector3.zero
    return dist2(pos) <= 14
end

local function hopTo(pos, timeout)
    local t0 = tick()
    while tick() - t0 < timeout do
        local root = hrp()
        local diff = pos - root.Position
        if diff.Magnitude <= 8 then return true end
        pcall(function() hum():MoveTo(pos) end)
        local step = math.min(S.HopDist, diff.Magnitude)
        if step > 1 then
            local dir = diff.Unit
            local np = root.Position + dir * step
            root.CFrame = CFrame.new(np, np + Vector3.new(dir.X, 0, dir.Z))
        end
        task.wait(S.HopDelay)
    end
    return dist2(pos) <= 14
end

local function carryTo(pos, timeout)
    timeout = timeout or 90
    if S.CarryMode == "Terbang Cepat" then
        return flyTo(pos, S.FlySpeed, timeout)
    elseif S.CarryMode == "Lari + Hop Teleport" then
        return hopTo(pos, timeout)
    end
    return walkTo(pos, timeout, 6)
end

local function grab(e)
    local pr = e.Prompt
    if not pr then return false end
    pcall(function()
        pr.HoldDuration = 0
        pr.RequiresLineOfSight = false
        pr.MaxActivationDistance = 30
    end)
    for _ = 1, 20 do
        if fireproximityprompt then pcall(fireproximityprompt, pr) end
        task.wait(0.05)
        if carryingEgg(LP) or not e.Obj.Parent or isInsideCharacter(e.Obj)
            or not pr:IsDescendantOf(workspace) or not pr.Enabled then
            return true
        end
    end
    return carryingEgg(LP)
end

local function deliver()
    if S.Forest then carryTo(S.Forest, 90) end
    task.wait(CONFIG.ForestWait)
    if S.Base then carryTo(S.Base, 90) end
end

local function stealEgg(e)
    if S.Busy then return end
    S.Busy = true
    local ok, err = pcall(function()
        if not e.Part or not e.Part.Parent then return end
        moveTo(e.Part.Position, 45, 7)
        if grab(e) then
            deliver()
            addHistory(e)
        end
    end)
    if not ok then warn("[LIXX EGG] steal error: " .. tostring(err)) end
    S.Busy = false
end

local function pickByPriority()
    for _, rar in ipairs(CONFIG.TargetRarities) do
        for _, e in ipairs(EggCache) do
            if e.Rarity:lower() == rar:lower() and e.Prompt and e.Part and e.Part.Parent then return e end
        end
    end
    return nil
end

task.spawn(function()
    while true do
        task.wait(0.1)
        if S.Steal and not S.Busy then
            local e = pickByPriority()
            if e then stealEgg(e) end
        end
    end
end)

RunService.Heartbeat:Connect(function()
    if S.Speed or (S.Busy and S.Mode == "Jalan") then
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
    duelBusy, S.Busy = true, true
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
                deliver()
                addHistory(e)
            end
        end
    end)
    if not ok then warn("[LIXX EGG] duel error: " .. tostring(err)) end
    duelBusy, S.Busy = false, false
end

------------------------------------------------------------
-- GUI KUSTOM (Panel telur, Duel list, banner, tombol L)
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
    t.Size = UDim2.new(1, -40, 0, 30)
    t.Position = UDim2.new(0, 10, 0, 0)
    t.BackgroundTransparency = 1
    t.Text = title
    t.TextColor3 = Color3.new(1, 1, 1)
    t.Font = Enum.Font.GothamBold
    t.TextSize = 14
    t.TextXAlignment = Enum.TextXAlignment.Left
    t.Parent = f

    local x = Instance.new("TextButton")
    x.Size = UDim2.new(0, 30, 0, 30)
    x.Position = UDim2.new(1, -30, 0, 0)
    x.BackgroundTransparency = 1
    x.Text = "X"
    x.TextColor3 = Color3.fromRGB(255, 80, 80)
    x.Font = Enum.Font.GothamBold
    x.TextSize = 16
    x.Parent = f
    x.MouseButton1Click:Connect(function() f.Visible = false end)

    local sc = Instance.new("ScrollingFrame")
    sc.Position = UDim2.new(0, 5, 0, 32)
    sc.Size = UDim2.new(1, -10, 1, -37)
    sc.BackgroundTransparency = 1
    sc.ScrollBarThickness = 4
    sc.AutomaticCanvasSize = Enum.AutomaticSize.Y
    sc.CanvasSize = UDim2.new()
    sc.Parent = f
    local l = Instance.new("UIListLayout", sc)
    l.Padding = UDim.new(0, 4)
    return f, sc
end

local PanelFrame, PanelList = mkFrame("LIXX EGG - Panel Telur", UDim2.new(0.5, -170, 0.3, 0), UDim2.new(0, 340, 0, 340))
local DuelFrame, DuelList = mkFrame("LIXX EGG - Duel Player", UDim2.new(0.5, -150, 0.3, 0), UDim2.new(0, 300, 0, 300))

local dumpHolder
DumpFrame, dumpHolder = mkFrame("LIXX EGG - Dump (tekan lama lalu salin)", UDim2.new(0.5, -200, 0.15, 0), UDim2.new(0, 400, 0, 300))
dumpHolder.Visible = false
DumpBox = Instance.new("TextBox")
DumpBox.Size = UDim2.new(1, -10, 1, -37)
DumpBox.Position = UDim2.new(0, 5, 0, 32)
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
    b.Size = UDim2.new(0, 70, 0, 28)
    b.Position = UDim2.new(1, -75, 0.5, -14)
    b.BackgroundColor3 = color
    b.Text = text
    b.TextColor3 = Color3.new(1, 1, 1)
    b.Font = Enum.Font.GothamBold
    b.TextSize = 12
    b.Parent = parent
    Instance.new("UICorner", b)
    b.MouseButton1Click:Connect(cb)
    return b
end

local function rarityColor(r)
    local k = rankOf(r)
    if k <= 3 then return "#FFC83C" elseif k <= 9 then return "#C080FF" end
    return "#FFFFFF"
end

local lastSig = ""
local function refreshPanel()
    if not PanelFrame.Visible then return end
    local eggs = EggCache
    local parts = {}
    for _, e in ipairs(eggs) do parts[#parts + 1] = tostring(e.Obj) .. e.Name .. e.Rarity .. tostring(e.Area) end
    local sig = table.concat(parts, "|")
    if sig == lastSig then return end
    lastSig = sig
    clear(PanelList)
    for idx, e in ipairs(eggs) do
        if idx > 60 then break end
        local row = Instance.new("Frame")
        row.Size = UDim2.new(1, -6, 0, 76)
        row.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
        row.Parent = PanelList
        Instance.new("UICorner", row)

        if e.Image then
            local im = Instance.new("ImageLabel")
            im.Size = UDim2.new(0, 48, 0, 48)
            im.Position = UDim2.new(0, 4, 0, 4)
            im.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
            im.Image = e.Image
            im.Parent = row
        else
            local vp = Instance.new("ViewportFrame")
            vp.Size = UDim2.new(0, 48, 0, 48)
            vp.Position = UDim2.new(0, 4, 0, 4)
            vp.BackgroundColor3 = Color3.fromRGB(20, 20, 24)
            vp.Parent = row
            pcall(function()
                local clone = (e.Obj:IsA("Model") and e.Obj or e.Part):Clone()
                for _, d in ipairs(clone:GetDescendants()) do
                    if d:IsA("BaseScript") or d:IsA("BillboardGui") or d:IsA("SurfaceGui")
                        or d:IsA("ProximityPrompt") then
                        d:Destroy()
                    end
                end
                clone.Parent = vp
                local cam = Instance.new("Camera")
                cam.Parent = vp
                vp.CurrentCamera = cam
                local p = partOf(clone)
                local pos = p.Position
                cam.CFrame = CFrame.new(pos + Vector3.new(0, 1, 4) * math.max(p.Size.Magnitude, 2) / 2, pos)
            end)
        end

        local lbl = Instance.new("TextLabel")
        lbl.Position = UDim2.new(0, 58, 0, 0)
        lbl.Size = UDim2.new(1, -140, 1, 0)
        lbl.BackgroundTransparency = 1
        lbl.TextColor3 = Color3.new(1, 1, 1)
        lbl.Font = Enum.Font.Gotham
        lbl.TextSize = 11
        lbl.TextWrapped = true
        lbl.RichText = true
        lbl.TextXAlignment = Enum.TextXAlignment.Left
        lbl.Text = e.Name .. "  <font color=\"" .. rarityColor(e.Rarity) .. "\"><b>[" .. e.Rarity ..
            "]</b></font>\nUkuran: " .. (e.SizeAttr and (e.SizeAttr .. " | ") or "") .. tostring(e.Size) ..
            "\nArea: " .. tostring(e.Area) .. "\nIsi: " .. tostring(e.Content)
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
            row.Size = UDim2.new(1, -6, 0, 36)
            row.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
            row.Parent = DuelList
            Instance.new("UICorner", row)
            local lbl = Instance.new("TextLabel")
            lbl.Size = UDim2.new(1, -90, 1, 0)
            lbl.Position = UDim2.new(0, 8, 0, 0)
            lbl.BackgroundTransparency = 1
            lbl.TextColor3 = Color3.new(1, 1, 1)
            lbl.Font = Enum.Font.Gotham
            lbl.TextSize = 13
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
        if v and (not S.Forest or not S.Base) then
            Rayfield:Notify({Title = "LIXX EGG", Content = "Set posisi Forest & Base dulu di menu Setting!", Duration = 5})
        end
        S.Steal = v
    end,
})
TabEgg:CreateButton({
    Name = "Panel (buka panel telur)",
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
TabEgg:CreateDropdown({
    Name = "Mode Gerak (ke telur)", Options = {"Teleport", "Tween Cepat", "Jalan"},
    CurrentOption = {"Teleport"}, MultipleOptions = false, Flag = "MoveMode",
    Callback = function(o) S.Mode = type(o) == "table" and o[1] or o end,
})
TabEgg:CreateSlider({
    Name = "Kecepatan Tween", Range = {100, 1500}, Increment = 10, Suffix = " studs/s",
    CurrentValue = 400, Flag = "TweenSpeed",
    Callback = function(v) S.TweenSpeed = v end,
})
TabEgg:CreateDropdown({
    Name = "Mode Bawa Telur (ke base)", Options = {"Terbang Cepat", "Lari + Hop Teleport", "Jalan"},
    CurrentOption = {"Terbang Cepat"}, MultipleOptions = false, Flag = "CarryMode",
    Callback = function(o) S.CarryMode = type(o) == "table" and o[1] or o end,
})
TabEgg:CreateSlider({
    Name = "Kecepatan Terbang", Range = {30, 400}, Increment = 5, Suffix = " studs/s",
    CurrentValue = 150, Flag = "FlySpeed",
    Callback = function(v) S.FlySpeed = v end,
})
TabEgg:CreateSlider({
    Name = "Hop Teleport: jarak per lompatan", Range = {5, 60}, Increment = 1, Suffix = " studs",
    CurrentValue = 20, Flag = "HopDist",
    Callback = function(v) S.HopDist = v end,
})
TabEgg:CreateSlider({
    Name = "Hop Teleport: jeda antar lompatan", Range = {0.05, 1}, Increment = 0.05, Suffix = " detik",
    CurrentValue = 0.25, Flag = "HopDelay",
    Callback = function(v) S.HopDelay = v end,
})
TabEgg:CreateSlider({
    Name = "Speed Boost / Kecepatan Jalan", Range = {16, 300}, Increment = 1, Suffix = " speed",
    CurrentValue = 80, Flag = "SpeedSlider",
    Callback = function(v) S.SpeedValue = v end,
})
TabEgg:CreateToggle({
    Name = "Speed Boost On/Off", CurrentValue = false, Flag = "SpeedToggle",
    Callback = function(v)
        S.Speed = v
        if not v then pcall(function() hum().WalkSpeed = 16 end) end
    end,
})
TabEgg:CreateButton({
    Name = "Dump Analisa (copy ke clipboard)",
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

Rayfield:Notify({Title = "LIXX EGG", Content = "Loaded! Set Forest & Base di menu Setting.", Duration = 6})
