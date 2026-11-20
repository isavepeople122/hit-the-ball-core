-- zones/quest_zone.lua
-- Procedural Catboy Quest Generator for hit the ball (Physical Part & Attribute Trackers)

local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Actionable Quest Types tied to real game attribute trackers
local QUEST_TYPES = {
	{
		ActionKey = "Hits",
		BaseTarget = 25,
		Template = "Hit the ball %d times"
	},
	{
		ActionKey = "ZoneRolls",
		BaseTarget = 5,
		Template = "Roll a multiplier in the 2x zone %d times"
	},
	{
		ActionKey = "ShopVisits",
		BaseTarget = 3,
		Template = "Open the shop interface %d times"
	}
}

local CATBOY_SNARK = {
	"...hurry nya.",
	"...lock in already.",
	"you're literally throwing.",
	"notice me and hit the ball.",
	"tick tock bestie.",
	"skill issue honestly."
}

-- Find the physical 'quest' part in Workspace
local questFolder = Workspace:WaitForChild("quest", 10)
if not questFolder then
	warn("[QuestZone] Could not find 'quest' in Workspace!")
	return
end

local questPart = questFolder:IsA("BasePart") and questFolder or questFolder:FindFirstChildWhichIsA("BasePart", true)
if not questPart then
	warn("[QuestZone] No BasePart found inside 'quest'!")
	return
end

local clickDetector = questPart:FindFirstChildWhichIsA("ClickDetector")
if not clickDetector then
	clickDetector = Instance.new("ClickDetector")
	clickDetector.MaxActivationDistance = 16
	clickDetector.Parent = questPart
end

local openQuestEvent = ReplicatedStorage:FindFirstChild("OpenQuestEvent")
if not openQuestEvent then
	openQuestEvent = Instance.new("RemoteEvent")
	openQuestEvent.Name = "OpenQuestEvent"
	openQuestEvent.Parent = ReplicatedStorage
end

local function generateProceduralQuest(player, questIndex)
	local seed = player.UserId + (questIndex * 733)
	local rng = Random.new(seed)

	local qType = QUEST_TYPES[rng:NextInteger(1, #QUEST_TYPES)]
	local targetCount = qType.BaseTarget * questIndex
	local description = string.format(qType.Template, targetCount)
	local rewardHits = targetCount * 20

	if not player:GetAttribute(qType.ActionKey .. "_QuestProgress") then
		player:SetAttribute(qType.ActionKey .. "_QuestProgress", 0)
	end

	return {
		Index = questIndex,
		ActionKey = qType.ActionKey,
		TargetCount = targetCount,
		Description = string.format("Quest #%d: %s.", questIndex, description),
		RewardHits = rewardHits
	}
end

local playerQuestState = {}

Players.PlayerAdded:Connect(function(player)
	playerQuestState[player.UserId] = {
		Data = generateProceduralQuest(player, 1),
		State = "ACTIVE"
	}
end)

Players.PlayerRemoving:Connect(function(player)
	playerQuestState[player.UserId] = nil
end)

clickDetector.MouseClick:Connect(function(player)
	local userId = player.UserId

	if not playerQuestState[userId] then
		local newQ = generateProceduralQuest(player, 1)
		playerQuestState[userId] = { Data = newQ, State = "ACTIVE" }
		openQuestEvent:FireClient(player, "NEW QUEST (nya):\n" .. newQ.Description, "ACCEPTED")
		return
	end

	local qInfo = playerQuestState[userId]
	local data = qInfo.Data

	local currentProgress = player:GetAttribute(data.ActionKey .. "_QuestProgress") or 0

	if currentProgress >= data.TargetCount then
		qInfo.State = "COMPLETED"
	else
		qInfo.State = "ACTIVE"
	end

	if qInfo.State == "ACTIVE" then
		local randomSnark = CATBOY_SNARK[math.random(1, #CATBOY_SNARK)]
		local statusMsg = string.format("REMINDER:\n%s\nProgress: %d / %d\n\n%s", data.Description, currentProgress, data.TargetCount, randomSnark)
		openQuestEvent:FireClient(player, statusMsg, "REMIND")

	elseif qInfo.State == "COMPLETED" then
		local currentHits = player:GetAttribute("Hits") or 0
		player:SetAttribute("Hits", currentHits + data.RewardHits)

		player:SetAttribute(data.ActionKey .. "_QuestProgress", 0)

		local nextQuest = generateProceduralQuest(player, data.Index + 1)
		playerQuestState[userId] = { Data = nextQuest, State = "ACTIVE" }

		local rewardMsg = string.format("PRIZE CLAIMED! (+%d hits)\n\nNext quest auto-accepted:\n%s", data.RewardHits, nextQuest.Description)
		openQuestEvent:FireClient(player, rewardMsg, "REWARD")
	end
end)

print("[QuestZone] Loaded successfully!")
