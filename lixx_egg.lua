-- =================================================================
-- LIXX EGG FIX ENGINE - ROBLOX STEAL AN EGG
-- =================================================================

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local LocalPlayer = Players.LocalPlayer

local IsStealing = false

-- 1. FUNGSI ANALISA SEBAGAI DETEKSI TELUR MAP
local function ScanMapEggs()
	local detectedEggs = {}
	
	-- Scan seluruh ProximityPrompt aktif di map
	for _, prompt in ipairs(Workspace:GetDescendants()) do
		if prompt:IsA("ProximityPrompt") then
			local parent = prompt.Parent
			local eggModel = parent
			
			-- Cari model utama telur
			while eggModel and not eggModel:IsA("Model") and eggModel ~= Workspace do
				eggModel = eggModel.Parent
			end

			if eggModel and eggModel ~= Workspace then
				-- Deteksi Nama Telur Akurat
				local eggName = prompt.ObjectText ~= "" and prompt.ObjectText or prompt.ActionText
				if eggName == "" or not eggName then
					eggName = eggModel.Name
				end

				-- Deteksi Rarity
				local rarity = eggModel:GetAttribute("Rarity") 
					or eggModel:GetAttribute("Tier") 
					or "Secret"

				local targetPart = parent:IsA("BasePart") and parent or eggModel:FindFirstChildWhichPart("BasePart")

				if targetPart then
					table.insert(detectedEggs, {
						Name = tostring(eggName),
						Rarity = tostring(rarity),
						Prompt = prompt,
						Part = targetPart
					})
				end
			end
		end
	end
	return detectedEggs
end

-- 2. FUNGSI MOVEMENT SAFE (BYPASS ANTI-TELEPORT)
local function SafeMoveTo(targetPos)
	local char = LocalPlayer.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end

	-- Bypass Collision
	for _, part in ipairs(char:GetChildren()) do
		if part:IsA("BasePart") then part.CanCollide = false end
	end

	local dist = (root.Position - targetPos).Magnitude
	local speed = 60 -- Kecepatan gerak aman
	local duration = math.clamp(dist / speed, 0.1, 4)

	local tween = TweenService:Create(root, TweenInfo.new(duration, Enum.EasingStyle.Linear), {
		CFrame = CFrame.new(targetPos + Vector3.new(0, 2, 0))
	})
	tween:Play()
	tween.Completed:Wait()
end

-- 3. EKSEKUSI MENCURI TELUR (STEAL SEQUENCE)
local function StealEgg(eggData)
	if IsStealing or not eggData then return end
	IsStealing = true

	print("[LIXX] Bergerak menuju: " .. eggData.Name)

	-- Move ke posisi telur
	SafeMoveTo(eggData.Part.Position)
	task.wait(0.1)

	-- Modifikasi ProximityPrompt agar instant
	eggData.Prompt.HoldDuration = 0
	eggData.Prompt.MaxActivationDistance = 30

	-- Picu ProximityPrompt
	pcall(function()
		fireproximityprompt(eggData.Prompt)
	end)
	task.wait(0.3)

	-- Teleport kembali ke Plot/Base milik Player
	local plots = Workspace:FindFirstChild("Plots") or Workspace:FindFirstChild("Bases")
	if plots then
		local myPlot = plots:FindFirstChild(LocalPlayer.Name, true)
		if myPlot then
			local plotPart = myPlot:FindFirstChildWhichPart("BasePart")
			if plotPart then
				SafeMoveTo(plotPart.Position + Vector3.new(0, 3, 0))
			end
		end
	end

	IsStealing = false
end

-- UI DENGAN DETEKSI OTOMATIS
local CoreGui = game:GetService("CoreGui")
if CoreGui:FindFirstChild("LixxEggFixUI") then CoreGui.LixxEggFixUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui", CoreGui)
ScreenGui.Name = "LixxEggFixUI"

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Size = UDim2.new(0, 320, 0, 300)
MainFrame.Position = UDim2.new(0.35, 0, 0.3, 0)
MainFrame.BackgroundColor3 = Color3.fromRGB(18, 22, 32)
MainFrame.Active = true
MainFrame.Draggable = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 10)

local Title = Instance.new("TextLabel", MainFrame)
Title.Size = UDim2.new(1, 0, 0, 35)
Title.Text = "LIXX EGG - MAP SCANNER FIX"
Title.TextColor3 = Color3.fromRGB(0, 230, 255)
Title.Font = Enum.Font.GothamBold
Title.TextSize = 13
Title.BackgroundTransparency = 1

local Scroll = Instance.new("ScrollingFrame", MainFrame)
Scroll.Size = UDim2.new(1, -20, 1, -50)
Scroll.Position = UDim2.new(0, 10, 0, 40)
Scroll.BackgroundTransparency = 1
Scroll.CanvasSize = UDim2.new(0, 0, 3, 0)
Scroll.ScrollBarThickness = 4
local Layout = Instance.new("UIListLayout", Scroll)
Layout.Padding = UDim.new(0, 5)

local function RefreshUI()
	for _, child in ipairs(Scroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end

	local eggList = ScanMapEggs()
	for _, item in ipairs(eggList) do
		local card = Instance.new("Frame", Scroll)
		card.Size = UDim2.new(1, -5, 0, 36)
		card.BackgroundColor3 = Color3.fromRGB(28, 34, 50)
		Instance.new("UICorner", card).CornerRadius = UDim.new(0, 6)

		local label = Instance.new("TextLabel", card)
		label.Size = UDim2.new(0.65, 0, 1, 0)
		label.Position = UDim2.new(0, 8, 0, 0)
		label.Text = item.Name .. " [" .. item.Rarity .. "]"
		label.TextColor3 = Color3.fromRGB(255, 255, 255)
		label.Font = Enum.Font.Gotham
		label.TextSize = 10
		label.TextXAlignment = Enum.TextXAlignment.Left
		label.BackgroundTransparency = 1

		local btn = Instance.new("TextButton", card)
		btn.Size = UDim2.new(0, 60, 0, 24)
		btn.Position = UDim2.new(1, -65, 0.5, -12)
		btn.Text = "STEAL"
		btn.Font = Enum.Font.GothamBold
		btn.TextSize = 10
		btn.TextColor3 = Color3.fromRGB(255, 255, 255)
		btn.BackgroundColor3 = Color3.fromRGB(0, 180, 90)
		Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)

		btn.MouseButton1Click:Connect(function()
			task.spawn(function()
				StealEgg(item)
			end)
		end)
	end
end

-- Refresh scanner setiap 3 detik
task.spawn(function()
	while task.wait(3) do
		if MainFrame.Visible then
			RefreshUI()
		end
	end
end)

RefreshUI()
