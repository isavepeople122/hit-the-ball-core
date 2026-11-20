-- zones/zx_zone.lua

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- 1. Find the trigger part
local zoneFolder = Workspace:WaitForChild("2xZone", 10)
if not zoneFolder then
	warn("[2xZone] Could not find '2xZone' in Workspace!")
	return
end

local triggerPart = zoneFolder:FindFirstChildWhichIsA("BasePart", true)
if not triggerPart then
	warn("[2xZone] No BasePart found inside '2xZone' to act as the X trigger!")
	return
end

local clickDetector = triggerPart:FindFirstChildWhichIsA("ClickDetector")
if not clickDetector then
	clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 16
	clickDetector.Parent = triggerPart
end

-- 2. Create a lightweight RemoteEvent for the soft white screen flash
local flashEvent = ReplicatedStorage:FindFirstChild("ZoneFlashEvent")
if not flashEvent then
	flashEvent = Instance.new("RemoteEvent")
	flashEvent.Name = "ZoneFlashEvent"
	flashEvent.Parent = ReplicatedStorage
end

local function setupPlayerFlash(player)
	local playerGui = player:WaitForChild("PlayerGui")
	if playerGui:FindFirstChild("ZoneFlashGui") then return end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "ZoneFlashGui"
	screenGui.IgnoreGuiInset = true
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "FlashFrame"
	frame.Size = UDim2.new(1, 0, 1, 0)
	frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Parent = screenGui
end

Players.PlayerAdded:Connect(setupPlayerFlash)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(setupPlayerFlash, p)
end

local starterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
if not starterPlayerScripts:FindFirstChild("ZoneFlashClient") then
	local clientScript = Instance.new("LocalScript")
	clientScript.Name = "ZoneFlashClient"
	clientScript.Source = [[
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local TweenService = game:GetService("TweenService")
		local Players = game:GetService("Players")

		local flashEvent = ReplicatedStorage:WaitForChild("ZoneFlashEvent")
		local player = Players.LocalPlayer

		flashEvent.OnClientEvent:Connect(function()
			local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("ZoneFlashGui")
			local frame = gui and gui:FindFirstChild("FlashFrame")
			if frame then
				frame.BackgroundTransparency = 0.25
				local tween = TweenService:Create(frame, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					BackgroundTransparency = 1
				})
				tween:Play()
			end
		end)
	]]
	clientScript.Parent = starterPlayerScripts
end

-- 3. Multiplier Roll Table
local function rollMultiplier()
	local roll = math.random(1, 200)

	if roll == 1 then
		local pi12 = 3.14159265358
		return pi12, "πx", Color3.fromRGB(255, 255, 255), true
	elseif roll <= 9 then
		return 3.0, "3x", Color3.fromRGB(0, 170, 255), false
	elseif roll <= 29 then
		local decimal = 1 + (math.random(100000000, 999999999) / 1000000000) + (math.random(100000, 999999) / 1e15)
		local formatted = string.format("%.15fx", decimal)
		return decimal, formatted, Color3.fromRGB(220, 255, 220), false
	elseif roll <= 109 then
		return 2.0, "2x", Color3.fromRGB(50, 255, 100), false
	elseif roll <= 159 then
		return 1.1, "1.1x", Color3.fromRGB(210, 210, 210), false
	else
		return 0.5, "0.5x", Color3.fromRGB(255, 60, 60), false
	end
end

-- 4. Build the Beam Box dynamically
local activeZoneModel = nil
local isCooldown = false

local function spawnBeamBox(centerCFrame, multValue, labelText, zoneColor, isPi)
	if activeZoneModel then
		activeZoneModel:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = "ActiveMultiplierZone"

	local boxSize = Vector3.new(24, 14, 24)
	local zonePart = Instance.new("Part")
	zonePart.Name = "ZoneBounds"
	zonePart.Size = boxSize
	zonePart.CFrame = centerCFrame * CFrame.new(0, boxSize.Y / 2, 0)
	zonePart.Anchored = true
	zonePart.CanCollide = false
	zonePart.Transparency = 1
	zonePart.Parent = model

	zonePart:SetAttribute("Multiplier", multValue)

	local halfX = boxSize.X / 2
	local halfY = boxSize.Y / 2
	local halfZ = boxSize.Z / 2

	local corners = {
		{ Vector3.new(-halfX, -halfY, -halfZ), Vector3.new(-halfX, halfY, -halfZ) },
		{ Vector3.new( halfX, -halfY, -halfZ), Vector3.new( halfX, halfY, -halfZ) },
		{ Vector3.new( halfX, -halfY,  halfZ), Vector3.new( halfX, halfY,  halfZ) },
		{ Vector3.new(-halfX, -halfY,  halfZ), Vector3.new(-halfX, halfY,  halfZ) },
	}

	local bottomAtts = {}
	local topAtts = {}

	for i, pair in ipairs(corners) do
		local bAtt = Instance.new("Attachment")
		bAtt.Position = pair[1]
		bAtt.Parent = zonePart
		bottomAtts[i] = bAtt

		local tAtt = Instance.new("Attachment")
		tAtt.Position = pair[2]
		tAtt.Parent = zonePart
		topAtts[i] = tAtt
	end

	for i = 1, 4 do
		local nextIdx = (i % 4) + 1
		local beam = Instance.new("Beam")
		beam.Attachment0 = bottomAtts[i]
		beam.Attachment1 = bottomAtts[nextIdx]
		beam.Color = ColorSequence.new(zoneColor)
		beam.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.35),
			NumberSequenceKeypoint.new(1, 1)
		})
		beam.Width0 = 0.2
		beam.Width1 = 0.2
		beam.FaceCamera = false
		beam.LightEmission = 0.6
		beam.Parent = zonePart
	end

	local selectionBox = Instance.new("SelectionBox")
	selectionBox.Adornee = zonePart
	selectionBox.Color3 = zoneColor
	selectionBox.LineThickness = 0.04
	selectionBox.SurfaceTransparency = 0.92
	selectionBox.SurfaceColor3 = zoneColor
	selectionBox.Parent = zonePart

	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 260, 0, 60)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = false
	billboard.Parent = zonePart

	local textLabel = Instance.new("TextLabel")
	textLabel.Size = UDim2.new(1, 0, 1, 0)
	textLabel.BackgroundTransparency = 1
	textLabel.Font = Enum.Font.Arial
	textLabel.TextScaled = true
	textLabel.TextColor3 = zoneColor
	textLabel.TextStrokeTransparency = 0.5
	textLabel.Text = isPi and "πx zone" or ("stand here for " .. labelText .. " hits")
	textLabel.Parent = billboard

	model.Parent = Workspace
	activeZoneModel = model
end

-- 5. Connect the X Trigger Click
clickDetector.MouseClick:Connect(function(player)
	if isCooldown then return end
	isCooldown = true

	-- Increment zone roll tracker for the catboy quest system!
	local currentRolls = player:GetAttribute("ZoneRolls_QuestProgress") or 0
	player:SetAttribute("ZoneRolls_QuestProgress", currentRolls + 1)

	local multValue, labelText, zoneColor, isPi = rollMultiplier()

	flashEvent:FireClient(player)
	spawnBeamBox(triggerPart.CFrame, multValue, labelText, zoneColor, isPi)

	triggerPart.Transparency = 1
	clickDetector.MaxActivationDistance = 0

	task.wait(0.5)
	isCooldown = false
end)

print("[2xZone] Loaded successfully from GitHub!")
