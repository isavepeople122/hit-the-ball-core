-- core/procedural_swords.lua
-- Procedural Seed-Based Sword Generator & Collection Book System (Massive Expanded Pools)

local ProceduralSwords = {}

local PREFIXES = {
	-- Quality & Condition
	"Deep-Fried", "Radioactive", "Low-FPS", "Cosmic", "Scuffed",
	"Slightly Bent", "Blessed", "Cursed", "Glitched", "Neon",
	"Tactical", "Cardboard", "Spicy", "Unstable", "Illegal",
	"Soggy", "Hyper-Realistic", "Polished", "Budget", "God-Tier",
	"Lootbox", "Laggy", "Air-Fried", "Quantum", "Suspicious",
	"Overclocked", "Waterproof", "Bluetooth", "Unrendered", "Stolen",
	"Handmade", "Bootleg", "Pre-Owned", "Diamond-Encrusted",
	"Zero-Gravity", "Sentient", "Depressed", "Angry", "Caffeine-Addicted",

	-- Absurd & Meme Modifiers
	"Certified Hood", "Speedrunning", "Nerfed", "Buffed", "Pay-to-Win",
	"Free-to-Play", "Tryhard", "Casual", "Toxic", "Whale",
	"AFK", "Ping-Spike", "Dial-Up", "Fiber-Optic", "Cracked",
	"Doomed", "Ancient", "Modern", "Futuristic", "Prehistoric"
}

local SUB_MODIFIERS = {
	"Deluxe Edition", "GOTY", "Director's Cut", "Remastered", "Beta",
	"Alpha", "Hotfix v1.2", "Collector's Item", "Bragging Rights", "Found In A Dumpster",
	"Certified Fresh", "Expired", "Without Instructions", "Missing Parts", "Glow-In-The-Dark"
}

local NOUNS = {
	-- Traditional / Weapon-ish
	"Stick", "Katana", "Spoon", "Greatsword", "Pool Noodle",
	"Metal Pipe", "Keyboard", "Spatula", "Baguette", "Plunger",
	"Banjo", "Stop Sign", "Brick", "Lawnmower Blade", "Toothbrush",
	"Flip-Flop", "Yardstick", "Wrench", "Traffic Cone", "Backscratcher",

	-- Household & Chaotic Objects
	"Couch Cushion", "Extension Cord", "Expired Coupon", "Cardboard Box", "Rolling Pin",
	"Folder of Tax Forms", "Bag of Chips", "Squeaky Hammer", "Broken Pencil", "Dry Marker",
	"Gaming Chair", "Microwave", "Toaster", "Socks", "Frying Pan",
	"Pillow", "Remote Control", "Stapler", "Tape Measure", "Safety Scissors"
}

-- Format numbers into clean abbreviations (K, M, B, T)
local SUFFIXES = { "", "K", "M", "B", "T", "Qa" }
function ProceduralSwords.FormatNumber(n)
	if n < 1000 then return tostring(math.floor(n)) end
	local tier = math.floor(math.log10(n) / 3)
	local suffix = SUFFIXES[tier + 1] or "e" + (tier * 3)
	local scaled = n / (1000 ^ tier)
	return string.format("%.2f%s", scaled, suffix)
end

-- Generate a player's unique, deterministic sword variant based on their PlayerId and the Sword Index
function ProceduralSwords.GenerateSword(playerSeed, index)
	if index == 1 then
		return {
			Index = 1,
			TierName = "Tier 1",
			FullName = "Dumb Stick",
			HitsReq = 0,
			FormattedReq = "0",
			Multiplier = 1.0,
			ColorTint = Color3.fromRGB(150, 100, 50),
			ScaleOffset = Vector3.new(1, 1, 1)
		}
	end

	-- Use player seed + index for unique random stream
	local rng = Random.new(playerSeed + (index * 997))

	local prefix = PREFIXES[rng:NextInteger(1, #PREFIXES)]
	local noun = NOUNS[rng:NextInteger(1, #NOUNS)]

	local fullName
	if rng:NextInteger(1, 100) <= 30 then
		local subMod = SUB_MODIFIERS[rng:NextInteger(1, #SUB_MODIFIERS)]
		fullName = string.format("#%d %s %s (%s)", index, prefix, noun, subMod)
	else
		fullName = string.format("#%d %s %s", index, prefix, noun)
	end

	local colorTint = Color3.fromRGB(rng:NextInteger(50, 255), rng:NextInteger(50, 255), rng:NextInteger(50, 255))
	local scaleOffset = Vector3.new(
		rng:NextNumber(0.85, 1.25),
		rng:NextNumber(0.90, 1.15),
		rng:NextNumber(0.85, 1.25)
	)

	-- Exponential price scaling with leap spikes
	local baseCost = 15
	local growthRate = 1.08
	local rawPrice = math.floor(baseCost * (growthRate ^ (index - 1)))

	if index >= 50 then rawPrice = math.floor(rawPrice * 4) end
	if index >= 100 then rawPrice = math.floor(rawPrice * 6) end
	if index >= 175 then rawPrice = math.floor(rawPrice * 10) end
	if index >= 1000 then rawPrice = math.floor(rawPrice * 25) end

	-- Multiplier scaling: Capped at 6x for anything under sword #10,000
	local swordMultiplier = 1.0
	if index <= 10000 then
		swordMultiplier = 1.0 + (5.0 * ((index - 1) / 9999))
	else
		local excess = index - 10000
		swordMultiplier = 6.0 * (1.15 ^ excess)
	end

	local tierIndex = math.min(8, math.ceil(index / 25))

	return {
		Index = index,
		TierName = "Tier " .. tierIndex,
		FullName = fullName,
		HitsReq = rawPrice,
		FormattedReq = ProceduralSwords.FormatNumber(rawPrice),
		Multiplier = swordMultiplier,
		ColorTint = colorTint,
		ScaleOffset = scaleOffset
	}
end

return ProceduralSwords
