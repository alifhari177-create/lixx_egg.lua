local Players = game:GetService("Players")
local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Bikin ScreenGui Utama
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "StealEggGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = playerGui

-- 1. FRAME / PANEL UI UTAMA
local mainFrame = Instance.new("Frame")
mainFrame.Name = "MainFrame"
mainFrame.Size = UDim2.new(0, 350, 0, 220)
mainFrame.Position = UDim2.new(0.5, -175, 0.5, -110)
mainFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
mainFrame.BorderSizePixel = 0
mainFrame.ClipsDescendants = true
mainFrame.Parent = screenGui

local frameCorner = Instance.new("UICorner")
frameCorner.CornerRadius = UDim.new(0, 12)
frameCorner.Parent = mainFrame

-- Judul UI (Map Steal & Egg)
local titleLabel = Instance.new("TextLabel")
titleLabel.Name = "Title"
titleLabel.Size = UDim2.new(1, -40, 0, 45)
titleLabel.Position = UDim2.new(0, 15, 0, 0)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = "STEAL & EGG SYSTEM"
titleLabel.TextColor3 = Color3.fromRGB(255, 215, 0) -- Warna Emas
titleLabel.TextSize = 18
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.Parent = mainFrame

-- Status Informasi di Dalam UI
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(1, -30, 0, 80)
statusLabel.Position = UDim2.new(0, 15, 0, 50)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "Telur Pegasus Abadi / Ubur-ubur Murni\nSiap Mencuri atau Ambil Egg!"
statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
statusLabel.TextSize = 14
statusLabel.Font = Enum.Font.SourceSansBold
statusLabel.TextWrapped = true
statusLabel.Parent = mainFrame

-- 2. TOMBOL CLOSE (X)
local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.Size = UDim2.new(0, 30, 0, 30)
closeButton.Position = UDim2.new(1, -38, 0, 8)
closeButton.BackgroundColor3 = Color3.fromRGB(220, 50, 50)
closeButton.Text = "X"
closeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
closeButton.TextSize = 16
closeButton.Font = Enum.Font.FredokaOne
closeButton.Parent = mainFrame

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 8)
closeCorner.Parent = closeButton

-- 3. TOMBOL LOGO L (BUAT BUKA UI RE-OPEN)
local openButton = Instance.new("TextButton")
openButton.Name = "OpenButtonL"
openButton.Size = UDim2.new(0, 50, 0, 50)
openButton.Position = UDim2.new(0, 15, 0.5, -25) -- Di sebelah kiri layar
openButton.BackgroundColor3 = Color3.fromRGB(40, 120, 220)
openButton.Text = "L"
openButton.TextColor3 = Color3.fromRGB(255, 255, 255)
openButton.TextSize = 24
openButton.Font = Enum.Font.FredokaOne
openButton.Visible = false -- Sembunyi secara default saat UI terbuka
openButton.Parent = screenGui

local openCorner = Instance.new("UICorner")
openCorner.CornerRadius = UDim.new(0, 25) -- Bentuk lingkaran
openCorner.Parent = openButton

local openStroke = Instance.new("UIStroke")
openStroke.Thickness = 3
openStroke.Color = Color3.fromRGB(255, 255, 255)
openStroke.Parent = openButton

-- 4. LOGIK AKSI FUNGSI (OPEN / CLOSE)
closeButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = false
	openButton.Visible = true
end)

openButton.MouseButton1Click:Connect(function()
	mainFrame.Visible = true
	openButton.Visible = false
end)
