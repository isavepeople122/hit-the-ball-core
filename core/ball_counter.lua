-- core/ball_counter.lua
-- Handles the incoming ball approach, red circle target, swing window, and multiplier integration

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BallCounter = {}

-- Setup UI and Remotes for the Ball loop
local function setupClientBallUI(player)
	local playerGui = player:WaitForChild("PlayerGui")
	if playerGui:FindFirstChild("BallWarningGui") then return end

	local screenGui = Instance.new("ScreenGui")
	screenGui.Name = "BallWarningGui"
	screenGui.ResetOnSpawn = false
	screenGui.Parent = playerGui

	-- Top-center flashing "!!" warning
	local warningLabel = Instance.new("TextLabel")
	warningLabel.Name = "WarningLabel"
	warningLabel.Size = UDim2.new(0, 200, 0, 50)
	warningLabel.Position = UDim2.new(0.5, -100, 0, 20)
	warningLabel.BackgroundTransparency = 1
	warningLabel.Font = Enum.Font.Cartoon
	warningLabel.TextSize = 36
	warningLabel.TextColor3 = Color3.fromRGB(255, 50, 50)
	warningLabel.TextStrokeTransparency = 0.2
	warningLabel.Text = "!!"
	warningLabel.TextTransparency = 1 -- Hidden by default
	warningLabel.Parent = screenGui
end

Players.PlayerAdded:Connect(setupClientBallUI)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(setupClientBallUI, p)
end

-- Remote event to trigger the warning flash on client
local warningEvent = ReplicatedStorage:FindFirstChild("BallWarningEvent")
if not warningEvent then
	warningEvent = Instance.new("RemoteEvent")
	warningEvent.Name = "BallWarningEvent"
	warningEvent.Parent = ReplicatedStorage
end

-- Client-side script injector for the warning flash animation
local starterPlayerScripts = game:GetService("StarterPlayer"):WaitForChild("StarterPlayerScripts")
if not starterPlayerScripts:FindFirstChild("BallWarningClient") then
	local clientScript = Instance.new("LocalScript")
	clientScript.Name = "BallWarningClient"
	clientScript.Source = [[
		local ReplicatedStorage = game:GetService("ReplicatedStorage")
		local Players = game:GetService("Players")
		local TweenService = game:GetService("TweenService")

		local event = ReplicatedStorage:WaitForChild("BallWarningEvent")
		local player = Players.LocalPlayer

		event.OnClientEvent:Connect(function()
			local gui = player:FindFirstChild("PlayerGui") and player.PlayerGui:FindFirstChild("BallWarningGui")
			local label = gui and gui:FindFirstChild("WarningLabel")
			if label then
				-- Quick flash animation
				label.TextTransparency = 0
				task.wait(0.2)
				label.TextTransparency = 1
			end
		end)
	]]
	clientScript.Parent = starterPlayerScripts
end

-- Function to check if a player is standing inside the active multiplier zone
local function getActiveMultiplierForPlayer(player)
	local activeZone = Workspace:FindFirstChild("ActiveMultiplierZone")
	if not activeZone then return 1.0 end -- Default 1x hits if no zone is spawned

	local zoneBounds = activeZone:FindFirstChild("ZoneBounds")
	local char = player.Character
	local rootPart = char and char:FindFirstChild("HumanoidRootPart")

	if zoneBounds and rootPart then
		-- Check if player position is within the bounding box (approximate check using distance)
		local distance = (rootPart.Position - zoneBounds.Position).Magnitude
		if distance <= 14 then -- Half of box size
			return zoneBounds:GetAttribute("Multiplier") or 1.0
		end
	end

	return 1.0
end

-- Core function to spawn and run the incoming ball loop
function BallCounter.SpawnIncomingBall(spawnCFrame, targetPosition, player)
	-- 1. Trigger the flashing "!!" warning
	warningEvent:FireClient(player)

	-- 2. Create the Ball far away with transparency fade
	local ball = Instance.new("Part")
	ball.Name = "IncomingBall"
	ball.Shape = Enum.PartType.Ball
	ball.Size = Vector3.new(3, 3, 3)
	ball.Position = spawnCFrame.Position
	ball.Material = Enum.Material.SmoothPlastic
	ball.Color = Color3.fromRGB(240, 240, 240)
	ball.Transparency = 1
	ball.Anchored = true
	ball.CanCollide = false
	ball.Parent = Workspace

	-- Add the red circle billboard so the player can track it easily
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 40, 0, 40)
	billboard.AlwaysOnTop = true
	billboard.Parent = ball

	local redCircle = Instance.new("Frame")
	redCircle.Size = UDim2.new(1, 0, 1, 0)
	redCircle.BackgroundColor3 = Color3.fromRGB(255, 50, 50)
	redCircle.BackgroundTransparency = 0.2
	redCircle.BorderSizePixel = 0
	redCircle.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = redCircle

	-- Fade ball in
	TweenService:Create(ball, TweenInfo.new(0.3), { Transparency = 0 }):Play()

	-- 3. Move ball toward the player/target position
	local tweenInfo = TweenInfo.new(1.2, Enum.EasingStyle.Linear)
	local travelTween = TweenService:Create(ball, tweenInfo, { Position = targetPosition })
	travelTween:Play()

	-- Return ball object and check function for when the player swings
	return ball, function()
		-- This is called when the player clicks/swings their sword
		local distanceToTarget = (ball.Position - targetPosition).Magnitude

		-- Check if swing is within proximity window (e.g., 3.5 studs)
		if distanceToTarget <= 3.5 then
			-- SUCCESSFUL HIT!
			travelTween:Cancel()
			ball:Destroy()

			-- Calculate multiplier (checking if they are standing in the zx_zone)
			local mult = getActiveMultiplierForPlayer(player)
			local currentHits = player:GetAttribute("Hits") or 0

			-- Add hits (multiplying or dividing based on zx_zone roll!)
			local earned = 1 * mult
			player:SetAttribute("Hits", currentHits + earned)

			print(player.Name .. " hit the ball! Multiplier applied: " .. tostring(mult))
			return true
		end

		return false
	end
end

return BallCounter
