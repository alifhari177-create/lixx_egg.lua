local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local guiParent = player:WaitForChild("PlayerGui")

local system = ReplicatedStorage:WaitForChild("SteelEggSystem")
local Action = system.Remotes:WaitForChild("Action")
local Result = system.Remotes:WaitForChild("Result")

local old = guiParent:FindFirstChild("SteelEggHub")
if old then old:Destroy() end

local C = {
    bg = Color3.fromRGB(15,13,21),
    panel = Color3.fromRGB(24,20,33),
    panel2 = Color3.fromRGB(31,25,43),
    purple = Color3.fromRGB(157,88,255),
    purple2 = Color3.fromRGB(91,48,145),
    text = Color3.fromRGB(245,240,255),
    muted = Color3.fromRGB(165,154,184),
    green = Color3.fromRGB(91,210,130)
}

local function new(class, props, parent)
    local o = Instance.new(class)
    for k,v in pairs(props) do o[k] = v end
    o.Parent = parent
    return o
end

local gui = new("ScreenGui", {
    Name = "SteelEggHub",
    ResetOnSpawn = false,
    IgnoreGuiInset = true
}, guiParent)

local main = new("Frame", {
    Size = UDim2.fromOffset(720, 470),
    Position = UDim2.new(.5,-360,.5,-235),
    BackgroundColor3 = C.bg,
    BorderSizePixel = 0
}, gui)
new("UICorner",{CornerRadius=UDim.new(0,13)},main)
new("UIStroke",{Color=C.purple,Transparency=.5,Thickness=1},main)

local top = new("Frame", {
    Size=UDim2.new(1,0,0,66),
    BackgroundColor3=C.panel,
    BorderSizePixel=0
},main)
new("UICorner",{CornerRadius=UDim.new(0,13)},top)

new("TextLabel",{
    Position=UDim2.fromOffset(20,9),
    Size=UDim2.new(1,-100,0,28),
    BackgroundTransparency=1,
    Text="STEEL & EGG",
    TextColor3=C.text,
    Font=Enum.Font.GothamBold,
    TextSize=22,
    TextXAlignment=Enum.TextXAlignment.Left
},top)

new("TextLabel",{
    Position=UDim2.fromOffset(21,37),
    Size=UDim2.new(1,-100,0,18),
    BackgroundTransparency=1,
    Text="TEST HUB  •  DARK PURPLE",
    TextColor3=C.muted,
    Font=Enum.Font.GothamMedium,
    TextSize=10,
    TextXAlignment=Enum.TextXAlignment.Left
},top)

local minimize = new("TextButton",{
    Position=UDim2.new(1,-82,0,17),
    Size=UDim2.fromOffset(30,30),
    Text="—",
    TextColor3=C.text,
    TextSize=18,
    Font=Enum.Font.GothamBold,
    BackgroundColor3=C.panel2,
    BorderSizePixel=0
},top)
new("UICorner",{CornerRadius=UDim.new(0,7)},minimize)

local close = new("TextButton",{
    Position=UDim2.new(1,-45,0,17),
    Size=UDim2.fromOffset(30,30),
    Text="×",
    TextColor3=C.text,
    TextSize=21,
    Font=Enum.Font.GothamBold,
    BackgroundColor3=C.panel2,
    BorderSizePixel=0
},top)
new("UICorner",{CornerRadius=UDim.new(0,7)},close)

local nav = new("Frame",{
    Position=UDim2.fromOffset(12,78),
    Size=UDim2.new(0,155,1,-90),
    BackgroundColor3=C.panel,
    BorderSizePixel=0
},main)
new("UICorner",{CornerRadius=UDim.new(0,10)},nav)
new("UIPadding",{PaddingTop=UDim.new(0,12),PaddingLeft=UDim.new(0,9),PaddingRight=UDim.new(0,9)},nav)
new("UIListLayout",{Padding=UDim.new(0,6)},nav)

local content = new("ScrollingFrame",{
    Position=UDim2.fromOffset(178,78),
    Size=UDim2.new(1,-190,1,-90),
    BackgroundColor3=C.panel,
    BorderSizePixel=0,
    ScrollBarThickness=3,
    ScrollBarImageColor3=C.purple,
    AutomaticCanvasSize=Enum.AutomaticSize.Y,
    CanvasSize=UDim2.new()
},main)
new("UICorner",{CornerRadius=UDim.new(0,10)},content)
new("UIPadding",{PaddingTop=UDim.new(0,14),PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14),PaddingBottom=UDim.new(0,14)},content)
new("UIListLayout",{Padding=UDim.new(0,9)},content)

local reopen = new("TextButton",{
    Size=UDim2.fromOffset(112,38),
    Position=UDim2.new(0,18,.5,0),
    Text="OPEN HUB",
    TextColor3=C.text,
    Font=Enum.Font.GothamBold,
    TextSize=12,
    BackgroundColor3=C.purple2,
    BorderSizePixel=0,
    Visible=false
},gui)
new("UICorner",{CornerRadius=UDim.new(0,9)},reopen)

local function clear()
    for _,x in ipairs(content:GetChildren()) do
        if x:IsA("GuiObject") then x:Destroy() end
    end
end

local function label(text,size,height,color)
    return new("TextLabel",{
        Size=UDim2.new(1,-3,0,height or 30),
        BackgroundTransparency=1,
        Text=text,
        TextColor3=color or C.text,
        TextSize=size or 14,
        Font=Enum.Font.Gotham,
        TextWrapped=true,
        TextXAlignment=Enum.TextXAlignment.Left
    },content)
end

local function button(text,callback)
    local b=new("TextButton",{
        Size=UDim2.new(1,-3,0,42),
        BackgroundColor3=C.panel2,
        Text=text,
        TextColor3=C.text,
        TextSize=13,
        Font=Enum.Font.GothamSemibold,
        BorderSizePixel=0,
        AutoButtonColor=false
    },content)
    new("UICorner",{CornerRadius=UDim.new(0,8)},b)
    new("UIStroke",{Color=C.purple,Transparency=.75},b)
    b.MouseEnter:Connect(function()
        TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=Color3.fromRGB(59,42,80)}):Play()
    end)
    b.MouseLeave:Connect(function()
        TweenService:Create(b,TweenInfo.new(.12),{BackgroundColor3=C.panel2}):Play()
    end)
    b.MouseButton1Click:Connect(callback)
    return b
end

local toggles = {}
local function toggle(text, callback)
    local state=false
    local b=button(text.."   •   OFF",function()
        state=not state
        b.Text=text.."   •   "..(state and "ON" or "OFF")
        b.BackgroundColor3=state and C.purple2 or C.panel2
        callback(state)
    end)
    toggles[text]=function(v)
        state=v
        b.Text=text.."   •   "..(state and "ON" or "OFF")
        b.BackgroundColor3=state and C.purple2 or C.panel2
    end
end

local toast
local function notify(msg)
    if toast then toast:Destroy() end
    toast=new("TextLabel",{
        Size=UDim2.fromOffset(300,42),
        Position=UDim2.new(1,-320,1,-65),
        BackgroundColor3=C.panel2,
        Text="  "..msg,
        TextColor3=C.text,
        Font=Enum.Font.GothamSemibold,
        TextSize=12,
        TextXAlignment=Enum.TextXAlignment.Left,
        BorderSizePixel=0,
        ZIndex=20
    },gui)
    new("UICorner",{CornerRadius=UDim.new(0,9)},toast)
    new("UIStroke",{Color=C.purple,Transparency=.45},toast)
    task.delay(2.2,function()
        if toast then
            TweenService:Create(toast,TweenInfo.new(.2),{TextTransparency=1,BackgroundTransparency=1}):Play()
            task.wait(.25)
            if toast then toast:Destroy(); toast=nil end
        end
    end)
end

local loops={}
local function setLoop(name,on,fn,delayTime)
    loops[name]=on
    if on then
        task.spawn(function()
            while loops[name] do
                fn()
                task.wait(delayTime)
            end
        end)
    end
end

local function tab(name)
    clear()
    label(string.upper(name),19,30,C.text)
    label("Steel & Egg / "..name,11,28,C.muted)

    if name=="Dashboard" then
        local ls=player:WaitForChild("leaderstats")
        local steel=ls:WaitForChild("Steel")
        local coins=ls:WaitForChild("Coins")
        local stat=label("STEEL:  "..steel.Value.."\nCOINS:  "..coins.Value,14,58,C.text)
        local function update()
            if stat.Parent then stat.Text="STEEL:  "..steel.Value.."\nCOINS:  "..coins.Value end
        end
        steel.Changed:Connect(update); coins.Changed:Connect(update)
        button("Mine nearest node",function() Action:FireServer("Mine") end)
        button("Collect nearby drops",function() Action:FireServer("Collect") end)
        button("Sell steel",function() Action:FireServer("Sell") end)

    elseif name=="Farm" then
        toggle("Auto Farm",function(on)
            setLoop("AutoFarm",on,function() Action:FireServer("Mine") end,.22)
        end)
        toggle("Auto Collect",function(on)
            setLoop("AutoCollect",on,function() Action:FireServer("Collect") end,.12)
        end)
        toggle("Auto Sell",function(on)
            setLoop("AutoSell",on,function() Action:FireServer("Sell") end,1)
        end)
        label("Auto Farm mines a nearby node. Walk into the steel field or use Teleport.",11,42,C.muted)

    elseif name=="Egg" then
        toggle("Auto Hatch",function(on)
            setLoop("AutoHatch",on,function() Action:FireServer("Hatch","Basic") end,.65)
        end)
        button("Hatch Basic Egg",function() Action:FireServer("Hatch","Basic") end)
        label("Basic Egg costs 50 Steel in this test implementation.",11,36,C.muted)

    elseif name=="Teleport" then
        local destinations={"Spawn","SteelField","EggMachine","SellZone","Treadmill"}
        for _,dest in ipairs(destinations) do
            button("Teleport • "..dest,function()
                Action:FireServer("Teleport",dest)
            end)
        end

    elseif name=="ESP" then
        toggle("Player ESP",function(on)
            loops.PlayerESP=on
        end)
        toggle("Steel ESP",function(on)
            loops.SteelESP=on
        end)
        toggle("Drop ESP",function(on)
            loops.DropESP=on
        end)
        label("ESP is client-side Highlight for testing/debugging.",11,35,C.muted)

    elseif name=="Player" then
        button("WalkSpeed 24",function()
            local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed=24 end
        end)
        button("WalkSpeed 16",function()
            local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if h then h.WalkSpeed=16 end
        end)
        button("JumpPower 60",function()
            local h=player.Character and player.Character:FindFirstChildOfClass("Humanoid")
            if h then h.UseJumpPower=true; h.JumpPower=60 end
        end)

    elseif name=="Settings" then
        button("Hide Hub",function()
            main.Visible=false
            reopen.Visible=true
        end)
        button("Destroy Hub",function()
            gui:Destroy()
        end)
        label("Steel & Egg test build. Server validates gameplay actions.",11,38,C.muted)
    end
end

local tabs={"Dashboard","Farm","Egg","Player","Teleport","ESP","Settings"}
local tabButtons={}
for _,name in ipairs(tabs) do
    local b=new("TextButton",{
        Size=UDim2.new(1,0,0,39),
        BackgroundColor3=C.panel,
        Text="   "..name,
        TextColor3=C.text,
        TextSize=12,
        Font=Enum.Font.GothamSemibold,
        TextXAlignment=Enum.TextXAlignment.Left,
        BorderSizePixel=0,
        AutoButtonColor=false
    },nav)
    new("UICorner",{CornerRadius=UDim.new(0,7)},b)
    tabButtons[name]=b
    b.MouseButton1Click:Connect(function()
        for n,x in pairs(tabButtons) do x.BackgroundColor3=(n==name) and C.purple2 or C.panel end
        tab(name)
    end)
end

-- Highlight controller
local highlights={}
local function removeHighlight(obj)
    if highlights[obj] then highlights[obj]:Destroy(); highlights[obj]=nil end
end
local function applyHighlight(obj, fill)
    if not obj:IsA("Model") and not obj:IsA("BasePart") then return end
    if highlights[obj] then return end
    local h=Instance.new("Highlight")
    h.Name="SteelEggESP"
    h.FillColor=fill
    h.OutlineColor=C.purple
    h.FillTransparency=.65
    h.OutlineTransparency=.1
    h.DepthMode=Enum.HighlightDepthMode.AlwaysOnTop
    h.Adornee=obj
    h.Parent=obj:IsA("Model") and obj or obj.Parent
    highlights[obj]=h
end

RunService.RenderStepped:Connect(function()
    local w=workspace:FindFirstChild("SteelEggWorld")
    if not w then return end

    local desired={}
    if loops.PlayerESP then
        for _,p in ipairs(Players:GetPlayers()) do
            if p~=player and p.Character then
                desired[p.Character]=C.purple
                applyHighlight(p.Character,C.purple)
            end
        end
    end

    if loops.SteelESP then
        local f=w:FindFirstChild("SteelNodes")
        if f then for _,x in ipairs(f:GetChildren()) do
            desired[x]=C.purple
            applyHighlight(x,C.purple)
        end end
    end

    if loops.DropESP then
        local f=w:FindFirstChild("Drops")
        if f then for _,x in ipairs(f:GetChildren()) do
            desired[x]=C.green
            applyHighlight(x,C.green)
        end end
    end

    for obj in pairs(highlights) do
        if not desired[obj] or not obj.Parent then removeHighlight(obj) end
    end
end)

Result.OnClientEvent:Connect(function(kind,data)
    if kind=="Notify" then notify(tostring(data))
    elseif kind=="Hatch" then notify("🥚 "..tostring(data))
    end
end)

-- Drag window
local dragging=false
local dragStart,startPos
top.InputBegan:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then
        dragging=true; dragStart=input.Position; startPos=main.Position
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType==Enum.UserInputType.MouseMovement then
        local d=input.Position-dragStart
        main.Position=UDim2.new(startPos.X.Scale,startPos.X.Offset+d.X,startPos.Y.Scale,startPos.Y.Offset+d.Y)
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType==Enum.UserInputType.MouseButton1 then dragging=false end
end)

minimize.MouseButton1Click:Connect(function() main.Visible=false; reopen.Visible=true end)
close.MouseButton1Click:Connect(function() main.Visible=false; reopen.Visible=true end)
reopen.MouseButton1Click:Connect(function() main.Visible=true; reopen.Visible=false end)

tabButtons.Dashboard.BackgroundColor3=C.purple2
tab("Dashboard")

print("[SteelEgg] Client hub loaded.")
