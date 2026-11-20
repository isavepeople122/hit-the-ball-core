-- zones/shop_zone.lua
-- Self-contained Shop UI & Linear Sword Progression for hit the ball

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 1. Linear Weapon Tiers (Strictly ordered per GDD: no skipping tiers, cosmetic spectacle only)
local SWORD_TIERS = {
	{ Tier = 1, Name = "Dumb Stick", HitsReq = 0 },
	{ Tier = 2, Name = "Slightly Cooler Stick", HitsReq = 15 },
	{ Tier = 3, Name = "Cardboard Katana", HitsReq = 50 },
	{ Tier = 4, Name = "Plastic Lightsaber", HitsReq = 150 },
	{ Tier = 5, Name = "Glowing Neon Bat", HitsReq = 400 },
	{ Tier = 6, Name = "Anime Greatblade", HitsReq = 1000 },
	{ Tier = 7, Name = "Cosmic Void Slicer", HitsReq = 2500 },
	{ Tier = 8, Name = "Literally The Sun On A Handle", HitsReq = 6000 },
}

-- Funny lines for the smiley block's speech bubble
local SHOP_LINES = {
	"pls buy something my laptop is running at 4 fps",
	"no refunds. actually no previews either.",
	"this sword does literally the exact same damage (0)",
	"hitting a ball is peak game design trust me",
	"buy this so i can afford a graphics card",
	"only 1 left in stock (i lied there are infinite)",
	"press the button bro it has a cool gradient",
}

-- 2. Find the 'shop' block in Workspace
local shopFolder = Workspace:WaitForChild("shop", 10)
if not shopFolder then
	warn("[ShopZone] Could not find 'shop' in Workspace!")
	return
end

local shopPart = shopFolder:IsA("BasePart") and shopFolder or shopFolder:FindFirstChildWhichIsA("BasePart", true)
if not shopPart then
	warn("[ShopZone] No BasePart found inside 'shop'!")
	return
end

local clickDetector = shopPart:FindFirstChildWhichIsA("ClickDetector")
if not clickDetector then
	clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 16
	clickDetector.Parent = shopPart
end

-- 3. Setup RemoteEvents for Client <-> Server Shop Communication
local openShopEvent = ReplicatedStorage:FindFirstChild("OpenShopEvent")
if not openShopEvent then
	openShopEvent = Instance.new("RemoteEvent")
	openShopEvent.Name = "OpenShopEvent"
	openShopEvent.Parent = ReplicatedStorage
end

local buySwordEvent = ReplicatedStorage:FindFirstChild("BuySwordEvent")
if not buySwordEvent then
	buySwordEvent = Instance.new("RemoteEvent")
	buySwordEvent.Name = "BuySwordEvent"
	buySwordEvent.Parent = ReplicatedStorage
end

-- Ensure players have Hits and CurrentTier attributes/leaderstats
local function initPlayerStats(player)
	if player:GetAttribute("Hits") == nil then
		player:SetAttribute("Hits", 0)
	end
	if player:GetAttribute("UnlockedTier") == nil then
		player:SetAttribute("UnlockedTier", 1) -- Starts with Dumb Stick
	end
	if player:GetAttribute("EquippedTier") == nil then
		player:SetAttribute("EquippedTier", 1)
	end
end

Players.PlayerAdded:Connect(initPlayerStats)
for _, p in ipairs(Players:GetPlayers()) do
	initPlayerStats(p)
end

-- 4. Handle Purchase Requests on the Server
buySwordEvent.OnServerEvent:Connect(function(player)
	local currentUnlocked = player:GetAttribute("UnlockedTier") or 1
	local nextTierData = SWORD_TIERS[currentUnlocked + 1]

	if not nextTierData then
		-- Player already owns every single sword!
		openShopEvent:FireClient(player, nil, "you bought everything bro go outside")
		return
	end

	local playerHits = player:GetAttribute("Hits") or 0
	if playerHits >= nextTierData.HitsReq then
		player:SetAttribute("Hits", playerHits - nextTierData.HitsReq)
		player:SetAttribute("UnlockedTier", nextTierData.Tier)
		player:SetAttribute("EquippedTier", nextTierData.Tier)

		local afterNext = SWORD_TIERS[nextTierData.Tier + 1]
		local randomLine = SHOP_LINES[math.random(1, #SHOP_LINES)]
		openShopEvent:FireClient(player, afterNext, randomLine)
	end
end)

-- Open shop when clicking the smiley block
clickDetector.MouseClick:Connect(function(player)
	-- Increment shop visit tracker for the catboy quest system!
	local currentVisits = player:GetAttribute("ShopVisits_QuestProgress") or 0
	player:SetAttribute("ShopVisits_QuestProgress", currentVisits + 1)

	local currentUnlocked = player:GetAttribute("UnlockedTier") or 1
	local nextTierData = SWORD_TIERS[currentUnlocked + 1]
	local randomLine = SHOP_LINES[math.random(1, #SHOP_LINES)]
	openShopEvent:FireClient(player, nextTierData, randomLine)
end)

-- 5. Inject the Client UI Generator (Matches your hand-drawn mockup!)
local starterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
if not starterPlayerScripts:FindFirstChild("ShopClientUI") then
	local clientScript = Instance.new("LocalScript")
	clientScript.Name = "ShopClientUI"
	clientScript.Source = [[
		local Players = game:GetService("Players")
		local ReplicatedStorage = game:GetService("ReplicatedStorage")

		local player = Players.LocalPlayer
		local playerGui = player:WaitForChild("PlayerGui")
		local openShopEvent = ReplicatedStorage:WaitForChild("OpenShopEvent")
		local buySwordEvent = ReplicatedStorage:WaitForChild("BuySwordEvent")

		-- Build the exact Shop ScreenGui
		local screenGui = Instance.new("ScreenGui")
		screenGui.Name = "HitTheBallShopGui"
		screenGui.ResetOnSpawn = false
		screenGui.Enabled = false
		screenGui.Parent = playerGui

		-- Helper to make your purple-to-red gradient
		local function applyCoolGradient(parent)
			local grad = Instance.new("UIGradient")
			grad.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(115, 0, 255)), -- Purple
				ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 0, 50))   -- Red
			})
			grad.Parent = parent
		end

		-- Main Container
		local container = Instance.new("Frame")
		container.Size = UDim2.new(0, 460, 0, 360)
		container.Position = UDim2.new(0.5, -230, 0.5, -160)
		container.BackgroundTransparency = 1
		container.Parent = screenGui

		-- Top Speech Bubble Row
		local npcIcon = Instance.new("TextLabel")
		npcIcon.Size = UDim2.new(0, 75, 0, 75)
		npcIcon.Position = UDim2.new(0, 0, 0, 0)
		npcIcon.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		npcIcon.BorderColor3 = Color3.fromRGB(0, 0, 0)
		npcIcon.BorderSizePixel = 3
		npcIcon.Font = Enum.Font.Cartoon
		npcIcon.Text = ":)"
		npcIcon.TextSize = 36
		npcIcon.TextColor3 = Color3.fromRGB(0, 0, 0)
		npcIcon.Parent = container

		local speechBubble = Instance.new("TextLabel")
		speechBubble.Size = UDim2.new(0, 365, 0, 65)
		speechBubble.Position = UDim2.new(0, 90, 0, 5)
		speechBubble.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		speechBubble.BorderColor3 = Color3.fromRGB(0, 0, 0)
		speechBubble.BorderSizePixel = 3
		speechBubble.Font = Enum.Font.Cartoon
		speechBubble.TextWrapped = true
		speechBubble.TextSize = 18
		speechBubble.TextColor3 = Color3.fromRGB(0, 0, 0)
		speechBubble.Text = "[generic tip / funny line here]"
		speechBubble.Parent = container

		local bubbleCorner = Instance.new("UICorner")
		bubbleCorner.CornerRadius = UDim.new(0, 16)
		bubbleCorner.Parent = speechBubble

		-- Main Light Gray Shop Box
		local mainBox = Instance.new("Frame")
		mainBox.Size = UDim2.new(1, 0, 0, 245)
		mainBox.Position = UDim2.new(0, 0, 0, 88)
		mainBox.BackgroundColor3 = Color3.fromRGB(235, 235, 235)
		mainBox.BorderColor3 = Color3.fromRGB(205, 205, 205)
		mainBox.BorderSizePixel = 4
		mainBox.Parent = container

		-- Close Button ("X")
		local closeBtn = Instance.new("TextButton")
		closeBtn.Size = UDim2.new(0, 28, 0, 28)
		closeBtn.Position = UDim2.new(1, -34, 0, 6)
		closeBtn.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
		closeBtn.Font = Enum.Font.Cartoon
		closeBtn.Text = "X"
		closeBtn.TextSize = 18
		closeBtn.TextColor3 = Color3.fromRGB(80, 80, 80)
		closeBtn.Parent = mainBox
		closeBtn.MouseButton1Click:Connect(function()
			screenGui.Enabled = false
		end)

		-- "BUY NOW!!" Gradient Title
		local titleLabel = Instance.new("TextLabel")
		titleLabel.Size = UDim2.new(0, 260, 0, 48)
		titleLabel.Position = UDim2.new(0.5, -130, 0, 12)
		titleLabel.BackgroundTransparency = 1
		titleLabel.Font = Enum.Font.Cartoon
		titleLabel.Text = "BUY NOW!!"
		titleLabel.TextScaled = true
		titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		titleLabel.Parent = mainBox
		applyCoolGradient(titleLabel)

		-- Gradient Underline
		local underline = Instance.new("Frame")
		underline.Size = UDim2.new(0, 250, 0, 4)
		underline.Position = UDim2.new(0.5, -125, 0, 60)
		underline.BorderSizePixel = 0
		underline.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		underline.Parent = mainBox
		applyCoolGradient(underline)

		-- Fake Urgency Small Text on the Right
		local urgencyLabel = Instance.new("TextLabel")
		urgencyLabel.Size = UDim2.new(0, 95, 0, 45)
		urgencyLabel.Position = UDim2.new(1, -100, 0, 48)
		urgencyLabel.BackgroundTransparency = 1
		urgencyLabel.Font = Enum.Font.Arial
		urgencyLabel.Text = "(only 1 left in stock)\n(buy b4 this deal expires)"
		urgencyLabel.TextWrapped = true
		urgencyLabel.TextSize = 10
		urgencyLabel.TextColor3 = Color3.fromRGB(40, 40, 40)
		urgencyLabel.Parent = mainBox

		-- "[swordName] (no preview on purpose)" Box
		local previewBox = Instance.new("TextLabel")
		previewBox.Size = UDim2.new(0, 220, 0, 68)
		previewBox.Position = UDim2.new(0.5, -110, 0, 82)
		previewBox.BackgroundColor3 = Color3.fromRGB(205, 205, 205)
		previewBox.BorderSizePixel = 0
		previewBox.Font = Enum.Font.Cartoon
		previewBox.TextWrapped = true
		previewBox.TextSize = 20
		previewBox.TextColor3 = Color3.fromRGB(20, 20, 20)
		previewBox.Text = "[swordName] (no preview on purpose)"
		previewBox.Parent = mainBox

		-- "buy - [hitsReq]" Button with Gradient Border
		local buyBorder = Instance.new("Frame")
		buyBorder.Size = UDim2.new(0, 190, 0, 48)
		buyBorder.Position = UDim2.new(0.5, -95, 0, 172)
		buyBorder.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		buyBorder.BorderSizePixel = 0
		buyBorder.Parent = mainBox
		applyCoolGradient(buyBorder)

		local buyBtn = Instance.new("TextButton")
		buyBtn.Size = UDim2.new(1, -8, 1, -8)
		buyBtn.Position = UDim2.new(0, 4, 0, 4)
		buyBtn.BackgroundColor3 = Color3.fromRGB(245, 245, 245)
		buyBtn.BorderSizePixel = 0
		buyBtn.Font = Enum.Font.Cartoon
		buyBtn.TextSize = 22
		buyBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		buyBtn.Text = "buy - [hitsReq]"
		buyBtn.Parent = buyBorder
		applyCoolGradient(buyBtn)

		-- Bottom Meta Disclaimer
		local disclaimer = Instance.new("TextLabel")
		disclaimer.Size = UDim2.new(1, 0, 0, 20)
		disclaimer.Position = UDim2.new(0, 0, 0, 340)
		disclaimer.BackgroundTransparency = 1
		disclaimer.Font = Enum.Font.Arial
		disclaimer.TextSize = 11
		disclaimer.TextColor3 = Color3.fromRGB(30, 30, 30)
		disclaimer.Text = "this whole game is ai generated i need money bro"
		disclaimer.Parent = container

		-- Connect Buy Button Click
		buyBtn.MouseButton1Click:Connect(function()
			buySwordEvent:FireServer()
		end)

		-- Update UI when Server tells it to open/refresh
		openShopEvent.OnClientEvent:Connect(function(nextTierData, funnyLine)
			speechBubble.Text = funnyLine or "buy something pls"
			if nextTierData then
				previewBox.Text = nextTierData.Name .. "\n(no preview on purpose)"
				buyBtn.Text = "buy - " .. tostring(nextTierData.HitsReq)
			else
				previewBox.Text = "MAX TIER REACHED\n(no more swords left)"
				buyBtn.Text = "sold out lol"
			end
			screenGui.Enabled = true
		end)
	]]
	clientScript.Parent = starterPlayerScripts
end

print("[ShopZone] Loaded successfully from GitHub!")
