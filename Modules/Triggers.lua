-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Triggers
-- Author: Mikord (original), 1.12.1 / Unreal Azeroth port
--
-- Classic MSBT 6.0 trigger engine. Trigger settings keep the classic string
-- format ("EVENT{cond;;rel;;value;;...}&&EVENT2{...}" plus an exceptions
-- list), so classic default and user triggers carry over.
--
-- Classic main events were combat log (CLEU) event names. The 1.12 parser
-- produces parser events instead; each one is mapped back to the CLEU name it
-- corresponds to (SPELL_DAMAGE, SWING_MISSED, SPELL_AURA_APPLIED, ...), and
-- the unit flags the conditions test are synthesized by the parser.
-------------------------------------------------------------------------------

local _G = _G or getfenv()

local module = MikSBT:NewModule("Triggers", "AceEvent-3.0")
MikSBT.Triggers = module

local Compat = MikSBT.Compat
local Util = MikSBT.Util
local MSBTProfiles = MikSBT.Profiles
local MSBTParser = MikSBT.Parser

local string_find = string.find
local string_gsub = string.gsub
local getn = Compat.getn
local gmatch = Compat.gmatch


-------------------------------------------------------------------------------
-- Constants.
-------------------------------------------------------------------------------

-- Special flag value for "the player" in affiliation conditions.
local FLAG_YOU = 4026531840

local MAX_PARTY_MEMBERS = 4
local MAX_RAID_MEMBERS = 40

-- Health triggers with the unitID condition on these units follow the unit's
-- percentage (exact for group units, a percentage anyway for the target).
local POWER_EVENTS = { UNIT_MANA = 0, UNIT_RAGE = 1, UNIT_FOCUS = 2, UNIT_ENERGY = 3, UNIT_HAPPINESS = 4 }


-------------------------------------------------------------------------------
-- Private variables.
-------------------------------------------------------------------------------

local gameEventHandlers
local playerClass

local listenEvents = {}
local categorizedTriggers = {}
local triggerExceptions = {}
local lookupTable = {}
local lastPercentages = {}
local firedTimes = {}
local triggersToFire = {}
local triggerSuppressions = {}

-- Power type tokens used by trigger settings -> 1.12 power type numbers.
local powerTypes = { MANA = 0, RAGE = 1, FOCUS = 2, ENERGY = 3, HAPPINESS = 4 }

local testFuncs, eventConditionFuncs, exceptionConditionFuncs


-------------------------------------------------------------------------------
-- Helpers.
-------------------------------------------------------------------------------

-- Tooltip used to read buff names (1.12 UnitBuff only returns the texture).
local scanTooltip
local function GetScanTooltip()
	if not scanTooltip then
		scanTooltip = CreateFrame("GameTooltip", "MSBTTriggerScanTooltip", nil, "GameTooltipTemplate")
		scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	end
	return scanTooltip
end

-- Whether the player has a buff with the given name.
local function HasPlayerBuff(buffName)
	if not buffName then
		return false
	end
	local tooltip = GetScanTooltip()
	local i
	for i = 0, 31 do
		local index = GetPlayerBuff(i, "HELPFUL")
		if not index or index < 0 then
			break
		end
		tooltip:SetOwner(UIParent, "ANCHOR_NONE")
		tooltip:ClearLines()
		tooltip:SetPlayerBuff(index)
		local text = _G["MSBTTriggerScanTooltipTextLeft1"]
		text = text and text:GetText()
		if text == buffName then
			return true
		end
	end
	return false
end

-- Spellbook lookup for the unavailableSkill exception.
local function FindSpellBookIndex(spellName)
	local i = 1
	while true do
		local name = GetSpellName(i, "spell")
		if not name then
			return nil
		end
		if name == spellName then
			local lastIndex = i
			-- Keep walking to the highest rank of the spell.
			while GetSpellName(i + 1, "spell") == spellName do
				i = i + 1
				lastIndex = i
			end
			return lastIndex
		end
		i = i + 1
	end
end

-- Passes when the skill is unknown or cooling down (ignoring the global
-- cooldown).
local function IsSkillUnavailable(skillName)
	if not skillName or skillName == "" then
		return true
	end
	local index = FindSpellBookIndex(skillName)
	if not index then
		return true
	end
	local start, duration = GetSpellCooldown(index, "spell")
	if start and start > 0 and duration and duration > 1.5 then
		return true
	end
end

local function CurrentStance()
	local i
	for i = 1, (GetNumShapeshiftForms and GetNumShapeshiftForms() or 0) do
		local _, _, isActive = GetShapeshiftFormInfo(i)
		if Compat.bool(isActive) then
			return i
		end
	end
	return 0
end

local function CreateTestFuncs()
	testFuncs = {
		eq = function(l, r) return l == r end,
		ne = function(l, r) return l ~= r end,
		like = function(l, r) return type(l) == "string" and type(r) == "string" and string_find(l, r) and true or false end,
		unlike = function(l, r) return type(l) == "string" and type(r) == "string" and not string_find(l, r) end,
		lt = function(l, r) return type(l) == "number" and type(r) == "number" and l < r end,
		gt = function(l, r) return type(l) == "number" and type(r) == "number" and l > r end,
	}
end

local function AffiliationTest(f, unit, flags, v)
	if v == FLAG_YOU then
		return f(unit, "player")
	end
	return f(Util.TestFlagsAny(flags, v), true)
end

local function CreateConditionFuncs()
	eventConditionFuncs = {
		sourceName = function(f, t, v) return f(t.sourceName, v) end,
		sourceAffiliation = function(f, t, v) return AffiliationTest(f, t.sourceUnit, t.sourceFlags, v) end,
		sourceReaction = function(f, t, v) return f(Util.TestFlagsAny(t.sourceFlags, v), true) end,
		sourceControl = function(f, t, v) return f(Util.TestFlagsAny(t.sourceFlags, v), true) end,
		sourceUnitType = function(f, t, v) return f(Util.TestFlagsAny(t.sourceFlags, v), true) end,
		recipientName = function(f, t, v) return f(t.recipientName, v) end,
		recipientAffiliation = function(f, t, v) return AffiliationTest(f, t.recipientUnit, t.recipientFlags, v) end,
		recipientReaction = function(f, t, v) return f(Util.TestFlagsAny(t.recipientFlags, v), true) end,
		recipientControl = function(f, t, v) return f(Util.TestFlagsAny(t.recipientFlags, v), true) end,
		recipientUnitType = function(f, t, v) return f(Util.TestFlagsAny(t.recipientFlags, v), true) end,
		skillName = function(f, t, v) return f(t.skillName, v) end,
		skillSchool = function(f, t, v) return f(t.skillSchool or t.damageType, v) end,
		extraSkillName = function(f, t, v) return f(t.extraSkillName, v) end,
		amount = function(f, t, v) return f(t.amount, v) end,
		damageType = function(f, t, v) return f(t.damageType, v) end,
		resistAmount = function(f, t, v) return f(t.resistAmount, v) end,
		blockAmount = function(f, t, v) return f(t.blockAmount, v) end,
		absorbAmount = function(f, t, v) return f(t.absorbAmount, v) end,
		isCrit = function(f, t, v) return f(t.isCrit and true or false, v) end,
		isGlancing = function(f, t, v) return f(t.isGlancing and true or false, v) end,
		isCrushing = function(f, t, v) return f(t.isCrushing and true or false, v) end,
		missType = function(f, t, v) return f(t.missType, v) end,
		hazardType = function(f, t, v) return f(t.hazardType, v) end,
		powerType = function(f, t, v) return f(t.powerType, v) end,
		extraAmount = function(f, t, v) return f(t.extraAmount, v) end,
		auraType = function(f, t, v) return f(t.auraType, v) end,
		threshold = function(f, t, v)
			if type(v) == "number" and t.currentPercentage and t.lastPercentage then
				return f(t.currentPercentage, v / 100) and not f(t.lastPercentage, v / 100)
			end
		end,
		unitID = function(f, t, v)
			if (v == "party" and string_find(t.unitID or "", "^party%d+")) or (v == "raid" and (string_find(t.unitID or "", "^raid%d+") or string_find(t.unitID or "", "^party%d+"))) then
				v = t.unitID
			end
			return f(t.unitID, v)
		end,
		unitReaction = function(f, t, v)
			if v == MSBTParser.REACTION_HOSTILE then
				return f(Compat.bool(UnitIsFriend(t.unitID, "player")), false)
			end
			return f(Compat.bool(UnitIsFriend(t.unitID, "player")), true)
		end,
		itemName = function(f, t, v) return f(t.itemName, v) end,
	}

	exceptionConditionFuncs = {
		buffActive = function(f, t, v) local ok, has = pcall(HasPlayerBuff, v) return ok and has end,
		buffInactive = function(f, t, v) local ok, has = pcall(HasPlayerBuff, v) return ok and not has end,
		currentCP = function(f, t, v) return f(GetComboPoints(), v) end,
		currentPower = function(f, t, v) return f(UnitMana("player"), v) end,
		inCombat = function(f, t, v) return f(Compat.bool(UnitAffectingCombat("player")), v) end,
		recentlyFired = function(f, t, v) return f(GetTime() - (firedTimes[t] or 0), v) end,
		unavailableSkill = function(f, t, v) return IsSkillUnavailable(v) and true or false end,
		warriorStance = function(f, t, v) if playerClass == "WARRIOR" then return f(CurrentStance(), v) end end,
		zoneName = function(f, t, v) return f(GetRealZoneText(), v) end,
		zoneType = function(f, t, v)
			if not IsInInstance then return false end
			local _, zoneType = IsInInstance()
			return f(zoneType, v)
		end,
	}
end

-- "true"/"false"/"nil"/numbers stored as strings back to their types.
local function ConvertType(value)
	if type(value) == "string" then
		if value == "true" then return true end
		if value == "false" then return false end
		if value == "nil" then return nil end
		if tonumber(value) then return tonumber(value) end
	end
	return value
end


-------------------------------------------------------------------------------
-- Categorization.
-------------------------------------------------------------------------------

local function AddConditions(mainEvent, conditions)
	if not categorizedTriggers[mainEvent] then
		categorizedTriggers[mainEvent] = {}
	end
	table.insert(categorizedTriggers[mainEvent], conditions)
end

-- Registers a health or power trigger under every unit its unitID condition
-- names ("party" and "raid" expand to the individual units).
local function AddUnitConditions(container, conditions)
	local x
	for x = 1, getn(conditions), 3 do
		if conditions[x] == "unitID" then
			local value = conditions[x + 2]
			local units = {}
			local i
			if value == "party" then
				for i = 1, MAX_PARTY_MEMBERS do table.insert(units, "party" .. i) end
			elseif value == "raid" then
				for i = 1, MAX_RAID_MEMBERS do table.insert(units, "raid" .. i) end
			else
				table.insert(units, value)
			end
			local _, unit
			for _, unit in ipairs(units) do
				container[unit] = container[unit] or {}
				table.insert(container[unit], conditions)
			end
		end
	end
end

local function CategorizeTrigger(triggerSettings)
	if triggerSettings.disabled or not triggerSettings.mainEvents then
		return
	end
	if triggerSettings.classes and triggerSettings.classes ~= "" and not string_find(triggerSettings.classes, playerClass or "", 1, true) then
		return
	end

	local mainEvent, conditionsString
	for mainEvent, conditionsString in gmatch(triggerSettings.mainEvents .. "&&", "(.-)%{(.-)%}&&") do
		local conditions = { triggerSettings = triggerSettings }
		local entry
		if conditionsString and conditionsString ~= "" then
			for entry in gmatch(conditionsString .. ";;", "(.-);;") do
				table.insert(conditions, ConvertType(entry))
			end
		end

		if mainEvent == "GENERIC_MISSED" then
			AddConditions("SWING_MISSED", conditions)
			AddConditions("SPELL_MISSED", conditions)
		elseif mainEvent == "GENERIC_DAMAGE" then
			AddConditions("SWING_DAMAGE", conditions)
			AddConditions("SPELL_DAMAGE", conditions)
		elseif mainEvent == "SPELL_AURA_APPLIED" or mainEvent == "SPELL_AURA_REMOVED" then
			AddConditions(mainEvent, conditions)
			AddConditions(mainEvent .. "_DOSE", conditions)
			if mainEvent == "SPELL_AURA_APPLIED" then
				-- A trigger on the player gaining an aura replaces the normal
				-- buff notification for it.
				local skillName, isPlayer
				local x
				for x = 1, getn(conditions), 3 do
					if conditions[x] == "skillName" and conditions[x + 1] == "eq" then skillName = conditions[x + 2] end
					if conditions[x] == "recipientAffiliation" and conditions[x + 1] == "eq" and conditions[x + 2] == FLAG_YOU then isPlayer = true end
				end
				if skillName and isPlayer then
					triggerSuppressions[skillName] = true
				end
			end
		elseif mainEvent == "UNIT_HEALTH" then
			listenEvents.UNIT_HEALTH = true
			categorizedTriggers.UNIT_HEALTH = categorizedTriggers.UNIT_HEALTH or {}
			lastPercentages.UNIT_HEALTH = lastPercentages.UNIT_HEALTH or {}
			AddUnitConditions(categorizedTriggers.UNIT_HEALTH, conditions)
		elseif mainEvent == "UNIT_POWER_UPDATE" or mainEvent == "UNIT_POWER" then
			local powerType
			local x
			for x = 1, getn(conditions), 3 do
				if conditions[x] == "powerType" then
					powerType = conditions[x + 2]
					if type(powerType) == "string" then powerType = powerTypes[powerType] end
				end
			end
			if powerType then
				local eventName, value
				for eventName, value in pairs(POWER_EVENTS) do
					if value == powerType then listenEvents[eventName] = true end
				end
				categorizedTriggers.UNIT_POWER_UPDATE = categorizedTriggers.UNIT_POWER_UPDATE or {}
				categorizedTriggers.UNIT_POWER_UPDATE[powerType] = categorizedTriggers.UNIT_POWER_UPDATE[powerType] or {}
				lastPercentages[powerType] = lastPercentages[powerType] or {}
				AddUnitConditions(categorizedTriggers.UNIT_POWER_UPDATE[powerType], conditions)
			end
		else
			AddConditions(mainEvent, conditions)
		end
	end

	if not triggerSettings.exceptions or triggerSettings.exceptions == "" then
		return
	end
	local exceptionConditions = {}
	local value
	for value in gmatch(triggerSettings.exceptions .. ";;", "(.-);;") do
		table.insert(exceptionConditions, ConvertType(value))
	end
	local x
	for x = 1, getn(exceptionConditions), 3 do
		if exceptionConditions[x] == "recentlyFired" then
			firedTimes[triggerSettings] = firedTimes[triggerSettings] or 0
		end
	end
	triggerExceptions[triggerSettings] = exceptionConditions
end

local function UpdateTriggers()
	if not gameEventHandlers then
		return
	end
	module:UnregisterAllEvents()
	Compat.wipe(listenEvents)
	Compat.wipe(categorizedTriggers)
	Compat.wipe(triggerExceptions)
	Compat.wipe(triggerSuppressions)

	local _, class = UnitClass("player")
	playerClass = class or playerClass

	local profile = MSBTProfiles.currentProfile
	if profile then
		local key, settings
		for key, settings in pairs(profile.triggers) do
			if type(settings) == "table" then
				CategorizeTrigger(settings)
			end
		end
	end

	if module:IsEnabled() then
		local eventName
		for eventName in pairs(listenEvents) do
			Util.RegisterEvent(module, eventName, gameEventHandlers[eventName])
		end
	end
	if MikSBT.Cooldowns then
		MikSBT.Cooldowns.UpdateRegisteredEvents()
	end
end


-------------------------------------------------------------------------------
-- Display.
-------------------------------------------------------------------------------

local function ColorName(name, class)
	local profile = MSBTProfiles.currentProfile
	if string_find(name, "-", 1, true) then
		name = string_gsub(name, "(.-)%-.*", "%1")
	end
	if class and not profile.classColoringDisabled then
		local classSettings = profile[class]
		if classSettings and not classSettings.disabled then
			name = Util.ColorText(name, classSettings.colorR, classSettings.colorG, classSettings.colorB)
		end
	end
	return name
end

local function DisplayTrigger(triggerSettings, sourceName, sourceClass, recipientName, recipientClass, skillName, extraSkillName, amount, effectTexture)
	local profile = MSBTProfiles.currentProfile
	local message = triggerSettings.message or ""
	local iconSkill = triggerSettings.iconSkill

	if sourceName and string_find(message, "%n", 1, true) then
		message = string_gsub(message, "%%n", ColorName(sourceName, sourceClass))
	end
	if recipientName and string_find(message, "%r", 1, true) then
		message = string_gsub(message, "%%r", ColorName(recipientName, recipientClass))
	end
	if skillName and string_find(message, "%s", 1, true) then
		message = string_gsub(message, "%%s", skillName)
	end
	if extraSkillName and string_find(message, "%e", 1, true) then
		message = string_gsub(message, "%%e", extraSkillName)
	end
	if amount and string_find(message, "%a", 1, true) then
		message = string_gsub(message, "%%a", Util.FormatNumber(amount, profile))
	end

	if iconSkill and iconSkill ~= "" then
		if skillName and string_find(iconSkill, "%s", 1, true) then
			iconSkill = string_gsub(iconSkill, "%%s", skillName)
		end
		if extraSkillName and string_find(iconSkill, "%e", 1, true) then
			iconSkill = string_gsub(iconSkill, "%%e", extraSkillName)
		end
		effectTexture = MikSBT.Icons.GetSkillIcon(iconSkill) or effectTexture
	end

	MikSBT.Animations.DisplayEvent(triggerSettings, message, effectTexture)
end


-------------------------------------------------------------------------------
-- Evaluation.
-------------------------------------------------------------------------------

-- True when an exception blocks the trigger. Records the fire time otherwise.
local function TestExceptions(triggerSettings)
	local exceptionConditions = triggerExceptions[triggerSettings]
	if exceptionConditions then
		local position
		for position = 1, getn(exceptionConditions), 3 do
			local conditionFunc = exceptionConditionFuncs[exceptionConditions[position]]
			local testFunc = testFuncs[exceptionConditions[position + 1]]
			if conditionFunc and testFunc and conditionFunc(testFunc, triggerSettings, exceptionConditions[position + 2]) then
				return true
			end
		end
	end
	if firedTimes[triggerSettings] then
		firedTimes[triggerSettings] = GetTime()
	end
end

-- Collects the triggers of a condition list whose conditions all pass.
local function CollectTriggers(conditionLists, data)
	Compat.wipe(triggersToFire)
	local _, eventConditions
	for _, eventConditions in ipairs(conditionLists) do
		if not triggersToFire[eventConditions.triggerSettings] then
			local doFire = true
			local position
			for position = 1, getn(eventConditions), 3 do
				local conditionFunc = eventConditionFuncs[eventConditions[position]]
				local testFunc = testFuncs[eventConditions[position + 1]]
				if conditionFunc and testFunc and not conditionFunc(testFunc, data, eventConditions[position + 2]) then
					doFire = false
					break
				end
			end
			if doFire then
				triggersToFire[eventConditions.triggerSettings] = true
			end
		end
	end
	return next(triggersToFire)
end

local function HandleHealthAndPowerTriggers(unit, event, currentAmount, maxAmount, powerType)
	local eventTriggers = categorizedTriggers[event]
	if powerType and eventTriggers then
		eventTriggers = eventTriggers[powerType]
	end
	if not eventTriggers or not eventTriggers[unit] or not maxAmount or maxAmount <= 0 then
		return
	end

	local currentPercentage = currentAmount / maxAmount
	local lastEventPercentages = lastPercentages[powerType or event]
	local lastPercentage = lastEventPercentages[unit]
	if not lastPercentage then
		lastEventPercentages[unit] = currentPercentage
		return
	end
	if Compat.bool(UnitIsDeadOrGhost(unit)) then
		lastEventPercentages[unit] = nil
		return
	end

	Compat.wipe(lookupTable)
	lookupTable.amount = currentAmount
	lookupTable.currentPercentage = currentPercentage
	lookupTable.lastPercentage = lastPercentage
	lookupTable.unitID = unit
	lookupTable.powerType = powerType

	if CollectTriggers(eventTriggers[unit], lookupTable) then
		local recipientName = UnitName(unit)
		local _, recipientClass = UnitClass(unit)
		local triggerSettings
		for triggerSettings in pairs(triggersToFire) do
			if not TestExceptions(triggerSettings) then
				DisplayTrigger(triggerSettings, nil, nil, recipientName, recipientClass, nil, nil, currentAmount)
			end
		end
	end
	lastEventPercentages[unit] = currentPercentage
end

local function HandleCooldowns(cooldownType, cooldownID, cooldownName, effectTexture)
	local event = "SKILL_COOLDOWN"
	if cooldownType == "pet" then
		event = "PET_COOLDOWN"
	elseif cooldownType == "item" then
		event = "ITEM_COOLDOWN"
	end
	local eventTriggers = categorizedTriggers[event]
	if not eventTriggers then
		return
	end
	Compat.wipe(lookupTable)
	if cooldownType == "item" then
		lookupTable.itemName = cooldownName
	else
		lookupTable.skillName = cooldownName
	end
	if CollectTriggers(eventTriggers, lookupTable) then
		local triggerSettings
		for triggerSettings in pairs(triggersToFire) do
			if not TestExceptions(triggerSettings) then
				DisplayTrigger(triggerSettings, nil, nil, UnitName("player"), playerClass, cooldownName, nil, nil, effectTexture)
			end
		end
	end
end

-- CLEU-style name of a parser event.
local function MainEventForParserEvent(p)
	local eventType = p.eventType
	if eventType == "damage" then
		if p.isDamageShield then return "DAMAGE_SHIELD" end
		if p.isDoT then return "SPELL_PERIODIC_DAMAGE" end
		if p.skillName then return "SPELL_DAMAGE" end
		return "SWING_DAMAGE"
	elseif eventType == "miss" then
		if p.skillName then return "SPELL_MISSED" end
		return "SWING_MISSED"
	elseif eventType == "heal" then
		return p.isHoT and "SPELL_PERIODIC_HEAL" or "SPELL_HEAL"
	elseif eventType == "environmental" then
		return "ENVIRONMENTAL_DAMAGE"
	elseif eventType == "aura" then
		local base = p.isFade and "SPELL_AURA_REMOVED" or "SPELL_AURA_APPLIED"
		return p.isDose and base .. "_DOSE" or base
	elseif eventType == "enchant" then
		return p.isFade and "ENCHANT_REMOVED" or "ENCHANT_APPLIED"
	elseif eventType == "power" then
		if p.isLeech then return "SPELL_LEECH" end
		if p.isDrain then return "SPELL_DRAIN" end
		return "SPELL_ENERGIZE"
	elseif eventType == "interrupt" then
		return "SPELL_INTERRUPT"
	elseif eventType == "dispel" then
		return "SPELL_DISPEL"
	elseif eventType == "extraattacks" then
		return "SPELL_EXTRA_ATTACKS"
	elseif eventType == "kill" then
		return "PARTY_KILL"
	elseif eventType == "death" then
		return "UNIT_DIED"
	elseif eventType == "cast" then
		return "SPELL_CAST_" .. (p.castStage or "SUCCESS")
	end
end

local function ParserEventsHandler(parserEvent)
	local mainEvent = MainEventForParserEvent(parserEvent)
	local conditionLists = mainEvent and categorizedTriggers[mainEvent]
	if not conditionLists then
		return
	end
	if CollectTriggers(conditionLists, parserEvent) then
		local effectTexture = MikSBT.Icons.GetSkillIcon(parserEvent.extraSkillName or parserEvent.skillName)
		local triggerSettings
		for triggerSettings in pairs(triggersToFire) do
			if not TestExceptions(triggerSettings) then
				DisplayTrigger(triggerSettings, parserEvent.sourceName, parserEvent.sourceClass,
					parserEvent.recipientName, parserEvent.recipientClass, parserEvent.skillName,
					parserEvent.extraSkillName, parserEvent.amount, effectTexture)
			end
		end
	end
end


-------------------------------------------------------------------------------
-- Events.
-------------------------------------------------------------------------------

local function OnUnitHealth(unit)
	local eventTriggers = categorizedTriggers.UNIT_HEALTH
	if not eventTriggers or not eventTriggers[unit] then
		return
	end
	HandleHealthAndPowerTriggers(unit, "UNIT_HEALTH", UnitHealth(unit), UnitHealthMax(unit))
end

local function OnUnitPower(unit, powerType)
	local byPower = categorizedTriggers.UNIT_POWER_UPDATE
	if not byPower or not byPower[powerType] or not byPower[powerType][unit] then
		return
	end
	if UnitPowerType(unit) ~= powerType then
		return
	end
	HandleHealthAndPowerTriggers(unit, "UNIT_POWER_UPDATE", UnitMana(unit), UnitManaMax(unit), powerType)
end

local function BuildEventHandlers()
	gameEventHandlers = { UNIT_HEALTH = OnUnitHealth }
	local eventName, powerType
	for eventName, powerType in pairs(POWER_EVENTS) do
		local capturedType = powerType
		gameEventHandlers[eventName] = function(unit) OnUnitPower(unit, capturedType) end
	end
end


-------------------------------------------------------------------------------
-- Lifecycle.
-------------------------------------------------------------------------------

-- Recategorizes on enable as well: the player's class is only certain to be
-- known once the player has logged in.
function module:OnEnable()
	UpdateTriggers()
	MSBTParser.RegisterHandler(ParserEventsHandler)
end

-- AceEvent-3.0 unregisters every event of the module when it is disabled.
function module:OnDisable()
	MSBTParser.UnregisterHandler(ParserEventsHandler)
end

BuildEventHandlers()
CreateTestFuncs()
CreateConditionFuncs()


module.triggerSuppressions = triggerSuppressions
module.categorizedTriggers = categorizedTriggers
module.powerTypes = powerTypes
module.FLAG_YOU = FLAG_YOU
module.HandleCooldowns = HandleCooldowns
module.ConvertType = ConvertType
module.UpdateTriggers = UpdateTriggers
module.MainEventForParserEvent = MainEventForParserEvent
module.eventConditionFuncs = function() return eventConditionFuncs end
module.exceptionConditionFuncs = function() return exceptionConditionFuncs end
