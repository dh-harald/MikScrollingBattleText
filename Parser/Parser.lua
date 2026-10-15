-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Parser
--
-- Turns 1.12.1 combat log chat lines into the classic MSBT `parserEvent`
-- table and sends it to the registered handlers.
--
-- Every global string in ParserTables is converted once into an anchored Lua
-- pattern built from the CLIENT'S OWN localized text, together with the order
-- in which its arguments are captured (localized strings may use "%2$s"). All
-- strings of a channel are tried from the most to the least specific (longest
-- literal text first), each behind a plain-text pre-check for its rarest word.
--
-- The combat log carries names only. Unit IDs ("player", "pet") are derived
-- by comparing names with the player's and the pet's, and the classic combat
-- log unit flags are synthesized from what the client knows about the name,
-- so classic trigger conditions keep working.
-------------------------------------------------------------------------------

local _G = _G or getfenv()

local module = MikSBT:NewModule("Parser", "AceEvent-3.0")
MikSBT.Parser = module

local Compat = MikSBT.Compat
local Util = MikSBT.Util
local T = MikSBT.ParserTables

local string_find = string.find
local string_gsub = string.gsub
local string_len = string.len
local tonumber = tonumber
local getn = Compat.getn
local gmatch = Compat.gmatch


-------------------------------------------------------------------------------
-- Constants.
-------------------------------------------------------------------------------

-- Classic combat log unit flags.
local AFFILIATION_MINE = 1
local AFFILIATION_PARTY = 2
local AFFILIATION_RAID = 4
local AFFILIATION_OUTSIDER = 8
local REACTION_FRIENDLY = 16
local REACTION_NEUTRAL = 32
local REACTION_HOSTILE = 64
local CONTROL_HUMAN = 256
local CONTROL_SERVER = 512
local UNITTYPE_PLAYER = 1024
local UNITTYPE_NPC = 2048
local UNITTYPE_PET = 4096
local UNITTYPE_GUARDIAN = 8192
local TARGET_TARGET = 65536

-- Channels the client reserves for the player's own pet and guardians
-- (totems included). A totem is not the "pet" unit, so its lines can only be
-- attributed to the player through the channel they arrive on.
local PET_CHANNELS = {
	CHAT_MSG_COMBAT_PET_HITS = true,
	CHAT_MSG_COMBAT_PET_MISSES = true,
	CHAT_MSG_SPELL_PET_DAMAGE = true,
	CHAT_MSG_SPELL_PET_BUFF = true,
}

-- Damage school bits (classic values).
local DAMAGETYPE_PHYSICAL = 1

-- Seconds after a player cast within which a "removed" aura on the target is
-- attributed to the player's dispel.
local DISPEL_WINDOW = 1.5


-------------------------------------------------------------------------------
-- Private variables.
-------------------------------------------------------------------------------

local handlers = {}
local parserEvent = {}
local captureTable = {}

-- Converted strings: name -> pattern / capture order / rare word / spec.
local searchPatterns = {}
local captureOrders = {}
local rareWords = {}
local specs = {}

-- Ordered lists of global string names per channel.
local combatList = {}
local notificationLists = {}

-- Trailer patterns: { pattern, field, hasAmount }.
local trailerPatterns = {}

-- Localized name lookups.
local damageTypeByName = {}
local powerTypeByName = {}

-- Aura type of every aura the player gained, for the fade lines that do not
-- say whether a buff or a debuff faded.
local playerAuraTypes = {}

local gameEventHandlers
local lastPlayerCastTime = 0

-- Debug log (/msbt eventlog).
local logEnabled = false
local LOG_MAX_LINES = 2000


-------------------------------------------------------------------------------
-- Handler registration.
-------------------------------------------------------------------------------

local function RegisterHandler(handler)
	handlers[handler] = true
end

local function UnregisterHandler(handler)
	handlers[handler] = nil
end

local function SendParserEvent()
	local handler
	for handler in pairs(handlers) do
		local ok, err = pcall(handler, parserEvent)
		if not ok then
			geterrorhandler()(err)
		end
	end
end


-------------------------------------------------------------------------------
-- Global string conversion.
-------------------------------------------------------------------------------

-- Pattern and capture order for a global string. captureOrder[argIndex] is the
-- capture number that holds that format argument (classic MSBTParser logic).
local function ConvertGlobalString(globalString)
	local captureOrder
	local numCaptures = 0
	local pattern = string_gsub(globalString, "([%^%(%)%.%[%]%*%+%-%?])", "%%%1")
	local index
	for index in gmatch(pattern, "%%(%d)%$[sd]") do
		captureOrder = captureOrder or {}
		numCaptures = numCaptures + 1
		captureOrder[tonumber(index)] = numCaptures
	end
	pattern = string_gsub(pattern, "%%%d?%$?s", "(.+)")
	pattern = string_gsub(pattern, "%%%d?%$?d", "(%%d+)")
	pattern = string_gsub(pattern, "%$", "%%$")
	return "^" .. pattern, captureOrder
end

-- Literal text of a global string without its format codes.
local function StripFormatCodes(globalString)
	return (string_gsub(globalString, "%%%d?%$?[sd]", ""))
end

local function CountCaptures(globalString)
	local count = 0
	local _
	for _ in gmatch(globalString, "%%%d?%$?[sd]") do
		count = count + 1
	end
	return count
end

-- Most specific first: longest literal text, then fewest captures.
local function CompareSpecificity(nameOne, nameTwo)
	local one, two = _G[nameOne], _G[nameTwo]
	local lenOne, lenTwo = string_len(StripFormatCodes(one)), string_len(StripFormatCodes(two))
	if lenOne == lenTwo then
		local capOne, capTwo = CountCaptures(one), CountCaptures(two)
		if capOne == capTwo then
			return nameOne < nameTwo
		end
		return capOne < capTwo
	end
	return lenOne > lenTwo
end

-- Picks the word of every string that occurs in the fewest of the strings.
local function FindRareWords(names)
	local counts = {}
	local _, name, word
	for _, name in pairs(names) do
		for word in gmatch(StripFormatCodes(_G[name]), "%w+") do
			counts[word] = (counts[word] or 0) + 1
		end
	end
	for _, name in pairs(names) do
		local rarest, seen
		local stripped = StripFormatCodes(_G[name])
		for word in gmatch(stripped, "%w+") do
			if not seen or counts[word] < seen then
				seen = counts[word]
				rarest = word
			end
		end
		if rarest and string_find(_G[name], rarest, 1, true) then
			rareWords[name] = rarest
		end
	end
end

-- Registers every spec whose global string exists on this client and returns
-- the sorted name list.
local function BuildList(specTable)
	local list = {}
	local name, spec
	for name, spec in pairs(specTable) do
		local text = _G[name]
		if type(text) == "string" and text ~= "" then
			local fields = {}
			local field
			for field in gmatch(spec[3], "%S+") do
				table.insert(fields, field)
			end
			spec.fields = fields
			specs[name] = spec
			searchPatterns[name], captureOrders[name] = ConvertGlobalString(text)
			table.insert(list, name)
		end
	end
	table.sort(list, CompareSpecificity)
	FindRareWords(list)
	return list
end

local function BuildTrailers()
	local _, entry
	for _, entry in ipairs(T.trailers) do
		local text = _G[entry[1]]
		if type(text) == "string" and text ~= "" then
			local pattern = string_gsub(text, "([%^%(%)%.%[%]%*%+%-%?])", "%%%1")
			local hasAmount = string_find(pattern, "%%d") and true or false
			pattern = string_gsub(pattern, "%%%d?%$?d", "(%%d+)")
			table.insert(trailerPatterns, { pattern, entry[2], hasAmount })
		end
	end
end

local function BuildNameLookups()
	-- 1.12 school order: 0 Physical, 1 Holy, 2 Fire, 3 Nature, 4 Frost,
	-- 5 Shadow, 6 Arcane; the classic bit is 2^index.
	local i
	local bitValue = 1
	for i = 0, 6 do
		local name = _G["SPELL_SCHOOL" .. i .. "_CAP"]
		if name then
			damageTypeByName[name] = bitValue
			damageTypeByName[string.lower(name)] = bitValue
		end
		bitValue = bitValue * 2
	end
	-- 1.12 power types: 0 mana, 1 rage, 2 focus, 3 energy, 4 happiness.
	local powers = { MANA = 0, RAGE = 1, FOCUS = 2, ENERGY = 3, HAPPINESS = 4 }
	local token, powerType
	for token, powerType in pairs(powers) do
		local name = _G[token]
		if name then
			powerTypeByName[name] = powerType
			powerTypeByName[string.lower(name)] = powerType
		end
	end
end


-------------------------------------------------------------------------------
-- Unit resolution.
-------------------------------------------------------------------------------

local function UnitForName(name)
	if not name then
		return nil
	end
	if name == UnitName("player") then
		return "player"
	end
	if UnitExists("pet") and name == UnitName("pet") then
		return "pet"
	end
end

-- Classic combat log flags for a name.
local function FlagsFor(name, unit)
	if unit == "player" then
		return AFFILIATION_MINE + REACTION_FRIENDLY + CONTROL_HUMAN + UNITTYPE_PLAYER
	elseif unit == "pet" then
		return AFFILIATION_MINE + REACTION_FRIENDLY + CONTROL_HUMAN + UNITTYPE_PET
	elseif unit == "guardian" then
		return AFFILIATION_MINE + REACTION_FRIENDLY + CONTROL_HUMAN + UNITTYPE_GUARDIAN
	end
	if not name then
		return 0
	end
	local flags = 0
	local groupUnit = Util.unitByName[name]
	if groupUnit then
		if string_find(groupUnit, "^raid") then
			flags = flags + AFFILIATION_RAID
		else
			flags = flags + AFFILIATION_PARTY
		end
		flags = flags + REACTION_FRIENDLY + CONTROL_HUMAN
		if string_find(groupUnit, "pet") then
			flags = flags + UNITTYPE_PET
		else
			flags = flags + UNITTYPE_PLAYER
		end
		return flags
	end
	flags = AFFILIATION_OUTSIDER
	local isTarget = UnitExists("target") and UnitName("target") == name
	if isTarget then
		flags = flags + TARGET_TARGET
		if Compat.bool(UnitIsFriend("player", "target")) then
			flags = flags + REACTION_FRIENDLY
		elseif Compat.bool(UnitIsEnemy("player", "target")) then
			flags = flags + REACTION_HOSTILE
		else
			flags = flags + REACTION_NEUTRAL
		end
	end
	if Util.playerNames[name] then
		flags = flags + CONTROL_HUMAN + UNITTYPE_PLAYER
	else
		flags = flags + CONTROL_SERVER + UNITTYPE_NPC
	end
	return flags
end


-------------------------------------------------------------------------------
-- Parsing.
-------------------------------------------------------------------------------

local function CaptureData(matchStart, matchEnd, c1, c2, c3, c4, c5, c6, c7, c8, c9)
	if not matchStart then
		return nil
	end
	captureTable[1], captureTable[2], captureTable[3] = c1, c2, c3
	captureTable[4], captureTable[5], captureTable[6] = c4, c5, c6
	captureTable[7], captureTable[8], captureTable[9] = c7, c8, c9
	return matchEnd
end

local function ReorderCaptures(o)
	local t = captureTable
	t[1], t[2], t[3], t[4], t[5], t[6], t[7], t[8], t[9] =
		t[o[1] or 1], t[o[2] or 2], t[o[3] or 3], t[o[4] or 4], t[o[5] or 5],
		t[o[6] or 6], t[o[7] or 7], t[o[8] or 8], t[o[9] or 9]
end

-- Removes partial effect trailers from the message and records them in the
-- parser event. Returns the message without them.
local function ExtractTrailers(message)
	local _, entry
	for _, entry in ipairs(trailerPatterns) do
		local s, e, amount = string_find(message, entry[1])
		if s then
			if entry[3] then
				parserEvent[entry[2]] = tonumber(amount)
			else
				parserEvent[entry[2]] = true
			end
			message = string.sub(message, 1, s - 1) .. string.sub(message, e + 1)
		end
	end
	return message
end

-- Fills the parser event from a matched spec.
local function Populate(spec)
	local fields = spec.fields
	local i
	for i = 1, getn(fields) do
		local field = fields[i]
		local value = captureTable[i]
		if field ~= "-" and value ~= nil then
			if field == "amount" or field == "extraAmount" or field == "amountStacks" then
				parserEvent[field] = tonumber(value)
			elseif field == "damageTypeName" then
				parserEvent.damageType = damageTypeByName[value] or damageTypeByName[string.lower(value)]
				parserEvent.damageTypeName = value
			elseif field == "powerTypeName" then
				parserEvent.powerType = powerTypeByName[value] or powerTypeByName[string.lower(value)]
			elseif field == "extraPowerTypeName" then
				parserEvent.extraPowerType = powerTypeByName[value] or powerTypeByName[string.lower(value)]
			else
				parserEvent[field] = value
			end
		end
	end

	local key, value
	for key, value in pairs(spec) do
		if type(key) == "string" and key ~= "fields" then
			parserEvent[key] = value
		end
	end
	parserEvent.eventType = spec[1]

	local playerName = UnitName("player")
	local who = spec[2]
	if who == "S" or who == "SR" then
		parserEvent.sourceName = playerName
	end
	if who == "R" or who == "SR" then
		parserEvent.recipientName = playerName
	end
end

-- Normalizes the event after population: units, flags, classes, defaults.
local function Finalize()
	local p = parserEvent
	p.sourceUnit = UnitForName(p.sourceName)
	p.recipientUnit = UnitForName(p.recipientName)
	p.sourceFlags = FlagsFor(p.sourceName, p.sourceUnit)
	-- An unresolved source on a pet channel is one of the player's guardians
	-- (e.g. "Searing Totem's Attack hits X"). Like MSBT classic, guardians are
	-- reported as the pet. A line on which the real pet is the recipient is
	-- left alone, its source is whoever hit the pet.
	if not p.sourceUnit and p.sourceName and PET_CHANNELS[p.chatEvent]
		and p.recipientUnit ~= "pet" then
		p.sourceUnit = "pet"
		p.sourceFlags = FlagsFor(p.sourceName, "guardian")
	end
	p.recipientFlags = FlagsFor(p.recipientName, p.recipientUnit)
	p.sourceClass = p.sourceName and Util.classByName[p.sourceName]
	p.recipientClass = p.recipientName and Util.classByName[p.recipientName]

	local eventType = p.eventType
	if eventType == "damage" then
		p.damageType = p.damageType or DAMAGETYPE_PHYSICAL
		if p.isDamageShield and not p.skillName then
			p.skillName = MikSBT.L["Damage Shield"]
		end
	elseif eventType == "miss" and p.skillName then
		p.skillSchool = p.damageType
	elseif eventType == "aura" then
		if p.isDose then
			p.amount = p.amountStacks
		end
		if p.recipientUnit == "player" then
			if p.isFade then
				p.auraType = p.auraType or playerAuraTypes[p.skillName] or "BUFF"
				playerAuraTypes[p.skillName] = nil
			else
				playerAuraTypes[p.skillName] = p.auraType
			end
		else
			p.auraType = p.auraType or "BUFF"
		end
	elseif eventType == "dispel" then
		-- The line never names the dispeller. A buff removed from the player's
		-- target right after the player cast something is taken as the
		-- player's dispel.
		if p.recipientUnit ~= "player" and GetTime() - lastPlayerCastTime <= DISPEL_WINDOW
			and UnitExists("target") and UnitName("target") == p.recipientName then
			p.sourceName = UnitName("player")
			p.sourceUnit = "player"
			p.sourceFlags = FlagsFor(p.sourceName, "player")
		end
	elseif eventType == "power" and p.isLeech then
		p.powerType = p.extraPowerType or p.powerType
	elseif eventType == "enchant" then
		p.auraType = "ITEM"
	end

	if p.eventType == "damage" or p.eventType == "heal" then
		if p.amount == nil then p.amount = 0 end
	end
end

-- Parses a line against an ordered list of global string names. Returns true
-- when a string matched.
local function ParseAgainst(list, message)
	local i
	for i = 1, getn(list) do
		local name = list[i]
		local rare = rareWords[name]
		if not rare or string_find(message, rare, 1, true) then
			if CaptureData(string_find(message, searchPatterns[name])) then
				if captureOrders[name] then
					ReorderCaptures(captureOrders[name])
				end
				Populate(specs[name])
				Finalize()
				SendParserEvent()
				return true
			end
		end
	end
end

local function AppendLog(eventName, message)
	if type(MSBTDebugLog) ~= "table" then
		MSBTDebugLog = {}
	end
	local count = getn(MSBTDebugLog)
	if count >= LOG_MAX_LINES then
		table.remove(MSBTDebugLog, 1)
	end
	table.insert(MSBTDebugLog, string.format("%.1f %s %s", GetTime(), eventName, message))
end

-- Entry point for one chat line. `eventName` selects the string list.
local function ParseMessage(eventName, message)
	if type(message) ~= "string" or message == "" then
		return
	end
	if logEnabled then
		AppendLog(eventName, message)
	end
	if module.lineObserver then
		module.lineObserver(eventName, message)
	end

	Compat.wipe(parserEvent)
	parserEvent.chatEvent = eventName
	parserEvent.chatMessage = message

	local list = notificationLists[eventName]
	if list then
		ParseAgainst(list, message)
		return
	end
	message = ExtractTrailers(message)
	ParseAgainst(combatList, message)
end


-------------------------------------------------------------------------------
-- Events.
-------------------------------------------------------------------------------

local function OnSpellcastStop()
	lastPlayerCastTime = GetTime()
end

local function BuildEventHandlers()
	gameEventHandlers = {}
	local _, eventName
	for _, eventName in ipairs(T.combatEvents) do
		local captured = eventName
		gameEventHandlers[captured] = function(message) ParseMessage(captured, message) end
	end
	for eventName in pairs(T.notification) do
		local captured = eventName
		gameEventHandlers[captured] = function(message) ParseMessage(captured, message) end
	end
	gameEventHandlers.SPELLCAST_STOP = OnSpellcastStop
end

-- AceEvent-3.0 unregisters every event of the module when it is disabled.
function module:OnEnable()
	Util.RegisterEvents(self, gameEventHandlers)
end

local function SetLogging(enabled)
	logEnabled = enabled and true or false
	if logEnabled and type(MSBTDebugLog) ~= "table" then
		MSBTDebugLog = {}
	end
end

local function ClearLog()
	MSBTDebugLog = {}
end


-------------------------------------------------------------------------------
-- Initialization.
-------------------------------------------------------------------------------

BuildNameLookups()
combatList = BuildList(T.combat)
local eventName, specTable
for eventName, specTable in pairs(T.notification) do
	notificationLists[eventName] = BuildList(specTable)
end
BuildTrailers()
BuildEventHandlers()


module.RegisterHandler = RegisterHandler
module.UnregisterHandler = UnregisterHandler
module.ParseMessage = ParseMessage
module.SetLogging = SetLogging
module.ClearLog = ClearLog
module.IsLogging = function() return logEnabled end
module.FlagsFor = FlagsFor
module.UnitForName = UnitForName
module.combatList = combatList
module.searchPatterns = searchPatterns

module.AFFILIATION_MINE = AFFILIATION_MINE
module.AFFILIATION_PARTY = AFFILIATION_PARTY
module.AFFILIATION_RAID = AFFILIATION_RAID
module.AFFILIATION_OUTSIDER = AFFILIATION_OUTSIDER
module.REACTION_FRIENDLY = REACTION_FRIENDLY
module.REACTION_NEUTRAL = REACTION_NEUTRAL
module.REACTION_HOSTILE = REACTION_HOSTILE
module.CONTROL_HUMAN = CONTROL_HUMAN
module.CONTROL_SERVER = CONTROL_SERVER
module.UNITTYPE_PLAYER = UNITTYPE_PLAYER
module.UNITTYPE_NPC = UNITTYPE_NPC
module.UNITTYPE_PET = UNITTYPE_PET
module.UNITTYPE_GUARDIAN = UNITTYPE_GUARDIAN
module.TARGET_TARGET = TARGET_TARGET
