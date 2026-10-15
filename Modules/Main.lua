-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Main
-- Author: Mikord (original), 1.12.1 / Unreal Azeroth port
--
-- Maps parser events to the classic event settings keys (INCOMING_DAMAGE,
-- OUTGOING_SPELL_DOT_CRIT, NOTIFICATION_BUFF, ...), formats the message and
-- hands it to the display, with merging and throttling in between.
--
-- 1.12 differences from classic MSBT:
--   * a skill is identified by name, not by spell ID;
--   * overheal is estimated from the recipient's health deficit, which is
--     only exact for the player, the pet and group members;
--   * power comes from UnitMana and the UNIT_MANA/RAGE/ENERGY/FOCUS events,
--     combo points from PLAYER_COMBO_POINTS.
-------------------------------------------------------------------------------

local _G = _G or getfenv()

local module = MikSBT:NewModule("Main", "AceEvent-3.0")
MikSBT.Main = module

local L = MikSBT.L
local Compat = MikSBT.Compat
local Util = MikSBT.Util
local MSBTAnimations = MikSBT.Animations
local MSBTParser = MikSBT.Parser
local MSBTTriggers = MikSBT.Triggers
local MSBTProfiles = MikSBT.Profiles

local table_remove = table.remove
local string_find = string.find
local string_gsub = string.gsub
local string_format = string.format
local math_abs = math.abs
local getn = Compat.getn

local DisplayEvent = MSBTAnimations.DisplayEvent
local IsScrollAreaActive = MSBTAnimations.IsScrollAreaActive
local IsScrollAreaIconShown = MSBTAnimations.IsScrollAreaIconShown
local triggerSuppressions = MSBTTriggers.triggerSuppressions


-------------------------------------------------------------------------------
-- Constants.
-------------------------------------------------------------------------------

local MERGE_DELAY_TIME = 0.3
local THROTTLE_UPDATE_TIME = 0.5
local EMOTE_HOLD_TIME = 1
local ENEMY_BUFF_HOLD_TIME = 5

-- A health change this recent is taken to be the heal being reported.
local HEALTH_CHANGE_WINDOW = 0.5

local MAX_COMBO_POINTS = 5

local DAMAGETYPE_PHYSICAL = 1

-- Damage school bit -> profile color entry.
local damageColorProfileEntries = {
	[1] = "physical", [2] = "holy", [4] = "fire", [8] = "nature",
	[16] = "frost", [32] = "shadow", [64] = "arcane",
}

-- 1.12 power type -> Blizzard global with its name.
local powerTokens = { [0] = "MANA", [1] = "RAGE", [2] = "FOCUS", [3] = "ENERGY", [4] = "HAPPINESS" }
local POWER_EVENTS = { UNIT_MANA = 0, UNIT_RAGE = 1, UNIT_FOCUS = 2, UNIT_ENERGY = 3 }


-------------------------------------------------------------------------------
-- Private variables.
-------------------------------------------------------------------------------

local gameEventHandlers, mergeFrame, throttleFrame

local damageTypeMap = {}
local combatEventCache = {}
local throttledAbilities = {}
local unmergedEvents = {}
local mergedEvents = {}
local lastMergeUpdate = 0
local lastThrottleUpdate = 0

local isEnglish
local lastPowerAmounts = {}
local lastComboPoints = 0
local recentEmotes = {}
local recentEnemyBuffs = {}
local ignoreAuras = {}
local autoShotName

-- unit -> { previous, current, time } of the last UNIT_HEALTH change.
local healthHistory = {}


-------------------------------------------------------------------------------
-- Formatting.
-------------------------------------------------------------------------------

local function CreateDamageMaps()
	local i
	local bitValue = 1
	for i = 0, 6 do
		damageTypeMap[bitValue] = _G["SPELL_SCHOOL" .. i .. "_CAP"]
		bitValue = bitValue * 2
	end
end

local function AbbreviateSkillName(skillName)
	if string_find(skillName, "[%s%-]") then
		skillName = string_gsub(skillName, "(%a)[%l%p]*[%s%-]*", "%1")
	end
	return skillName
end

local function ColorEntry(settings, text)
	return Util.ColorText(text, settings.colorR, settings.colorG, settings.colorB)
end

-- Partial effect trailer text (absorb/block/resist/vulnerable, then
-- glancing/crushing).
local function FormatPartialEffects(absorbAmount, blockAmount, resistAmount, vulnerableAmount, isGlancing, isCrushing)
	local profile = MSBTProfiles.currentProfile
	local effectSettings, amount
	local partialEffectText = ""

	if absorbAmount then
		effectSettings, amount = profile.absorb, absorbAmount
	elseif blockAmount then
		effectSettings, amount = profile.block, blockAmount
	elseif resistAmount then
		effectSettings, amount = profile.resist, resistAmount
	elseif vulnerableAmount then
		effectSettings, amount = profile.vulnerable, vulnerableAmount
	end

	local trailer = effectSettings and effectSettings.trailer
	if trailer and not effectSettings.disabled then
		trailer = string_gsub(trailer, "%%a", Util.FormatNumber(amount, profile))
		if not profile.partialColoringDisabled then
			partialEffectText = ColorEntry(effectSettings, trailer)
		else
			partialEffectText = trailer
		end
	end

	effectSettings = nil
	if isGlancing then
		effectSettings = profile.glancing
	elseif isCrushing then
		effectSettings = profile.crushing
	end
	trailer = effectSettings and effectSettings.trailer
	if trailer and not effectSettings.disabled then
		if not profile.partialColoringDisabled then
			partialEffectText = partialEffectText .. ColorEntry(effectSettings, trailer)
		else
			partialEffectText = partialEffectText .. trailer
		end
	end
	return partialEffectText
end

local function FormatEvent(message, amount, damageType, overhealAmount, powerType, name, class, effectName, partialEffects, mergeTrailer, ignoreDamageColoring, hideSkills, hideNames)
	local profile = MSBTProfiles.currentProfile
	local checkParens

	if amount and string_find(message, "%a", 1, true) then
		local partialAmount = ""
		if overhealAmount and overhealAmount > 0 and not profile.overheal.disabled then
			amount = amount - overhealAmount
			partialAmount = string_gsub(profile.overheal.trailer, "%%a", Util.FormatNumber(overhealAmount, profile))
			if not profile.partialColoringDisabled then
				partialAmount = ColorEntry(profile.overheal, partialAmount)
			end
		end
		local formattedAmount = Util.FormatNumber(amount, profile)
		if damageType and not ignoreDamageColoring and not profile.damageColoringDisabled then
			local damageSettings = profile[damageColorProfileEntries[damageType] or ""]
			if damageSettings and not damageSettings.disabled then
				formattedAmount = ColorEntry(damageSettings, formattedAmount)
			end
		end
		message = string_gsub(message, "%%a", formattedAmount .. partialAmount)
	elseif string_find(message, "%a", 1, true) then
		-- An amount code with no amount (a 1.12 full absorb, or a user message
		-- on an amountless event) disappears instead of showing literally.
		message = string_gsub(message, "%%a", "")
		checkParens = true
	end

	if powerType and string_find(message, "%p", 1, true) then
		message = string_gsub(message, "%%p", _G[powerTokens[powerType] or "UNKNOWN"] or UNKNOWN or "")
	end

	if name and string_find(message, "%n", 1, true) then
		if hideNames then
			message = string_gsub(message, "%s?%-?%s?%%n", "")
			checkParens = true
		else
			if string_find(name, "-", 1, true) then
				name = string_gsub(name, "(.-)%-.*", "%1")
			end
			if class and not profile.classColoringDisabled then
				local classSettings = profile[class]
				if classSettings and not classSettings.disabled then
					name = ColorEntry(classSettings, name)
				end
			end
			message = string_gsub(message, "%%n", name)
		end
	else
		message = string_gsub(message, "%%n", "")
		checkParens = true
	end

	if effectName and string_find(message, "%e", 1, true) then
		message = string_gsub(message, "%%e", effectName)
	end

	if effectName then
		if string_find(message, "%s", 1, true) then
			if hideSkills then
				message = string_gsub(message, "%s?%-?%s?%%sl?%s?%-?%s?", "")
				checkParens = true
			else
				local isChanged
				if profile.abilitySubstitutions[effectName] then
					effectName = profile.abilitySubstitutions[effectName]
					isChanged = true
				end
				if string_find(message, "%sl", 1, true) then
					message = string_gsub(message, "%%sl", effectName)
				end
				if isEnglish and not isChanged and profile.abbreviateAbilities then
					effectName = AbbreviateSkillName(effectName)
				end
				message = string_gsub(message, "%%s", effectName)
			end
		end
	else
		-- A skill code with no skill (for example a swing) disappears.
		if string_find(message, "%s", 1, true) then
			message = string_gsub(message, "%s?%-?%s?%%sl?%s?%-?%s?", "")
			checkParens = true
		end
	end

	if checkParens then
		message = string_gsub(message, "%(%)", "")
		message = string_gsub(message, "%[%]", "")
		message = string_gsub(message, "%{%}", "")
		message = string_gsub(message, "%<%>", "")
		message = string_gsub(message, "%s%s+", " ")
		message = string_gsub(message, "^%s+", "")
		message = string_gsub(message, "%s+$", "")
	end

	if damageType and string_find(message, "%t", 1, true) then
		message = string_gsub(message, "%%t", damageTypeMap[damageType] or UNKNOWN or "")
	end
	if partialEffects then
		message = message .. partialEffects
	end
	if mergeTrailer then
		message = message .. mergeTrailer
	end
	return message
end
module.FormatEvent = FormatEvent

local function GetInOutEventData(p)
	if p.recipientUnit == "player" then
		return "INCOMING", p.sourceName, p.sourceClass
	elseif p.sourceUnit == "player" then
		return "OUTGOING", p.recipientName, p.recipientClass
	elseif p.recipientUnit == "pet" then
		return "PET_INCOMING", p.sourceName, p.sourceClass
	elseif p.sourceUnit == "pet" then
		return "PET_OUTGOING", p.recipientName, p.recipientClass
	end
end


-------------------------------------------------------------------------------
-- Overheal estimation.
-------------------------------------------------------------------------------

local function OnUnitHealth(unit)
	local current = UnitHealth(unit)
	local entry = healthHistory[unit]
	if not entry then
		entry = {}
		healthHistory[unit] = entry
		entry.current = current
	end
	entry.previous = entry.current
	entry.current = current
	entry.time = GetTime()
end

-- Estimates the overheal of a heal on a unit with exact health values. The
-- health update may arrive before or after the heal line; a rise seen within
-- the last half second is taken to be this heal.
local function EstimateOverheal(p)
	local unit = p.recipientName and Util.unitByName[p.recipientName]
	if not unit or not p.amount or p.amount <= 0 then
		return
	end
	local maxHealth = UnitHealthMax(unit)
	local health = UnitHealth(unit)
	if not maxHealth or maxHealth <= 0 then
		return
	end
	local deficit = maxHealth - health
	local entry = healthHistory[unit]
	if entry and entry.time and GetTime() - entry.time <= HEALTH_CHANGE_WINDOW and entry.current == health and entry.previous and entry.previous < health then
		deficit = maxHealth - entry.previous
	end
	if deficit < 0 then
		deficit = 0
	end
	if p.amount > deficit then
		p.overhealAmount = p.amount - deficit
	end
end


-------------------------------------------------------------------------------
-- Power and combo points.
-------------------------------------------------------------------------------

local function DetectPowerGain(powerAmount, powerType)
	local eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_POWER_GAIN
	if eventSettings.disabled or not powerType then
		return
	end
	local lastPowerAmount = lastPowerAmounts[powerType] or 65535
	if powerAmount > lastPowerAmount then
		local gain = powerAmount - lastPowerAmount
		if gain >= MSBTProfiles.currentProfile.powerThreshold then
			DisplayEvent(eventSettings, FormatEvent(eventSettings.message, gain, nil, nil, powerType, nil, nil, UNKNOWN))
		end
	end
end

local function OnPowerUpdate(unit, powerType)
	if unit ~= "player" or UnitPowerType("player") ~= powerType then
		return
	end
	local powerAmount = UnitMana("player")
	if MSBTProfiles.currentProfile.showAllPowerGains then
		DetectPowerGain(powerAmount, powerType)
	end
	lastPowerAmounts[powerType] = powerAmount
end

local function OnComboPoints()
	local amount = GetComboPoints() or 0
	local previous = lastComboPoints
	lastComboPoints = amount
	if amount <= 0 or amount <= previous then
		return
	end
	local events = MSBTProfiles.currentProfile.events
	local eventSettings = events.NOTIFICATION_CP_GAIN
	if amount >= MAX_COMBO_POINTS then
		eventSettings = events.NOTIFICATION_CP_FULL
	end
	if not eventSettings.disabled then
		DisplayEvent(eventSettings, FormatEvent(eventSettings.message, amount))
	end
end

local function HandleMonsterEmote(message, sourceName)
	if not sourceName or sourceName ~= UnitName("target") then
		return
	end
	local eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_MONSTER_EMOTE
	if eventSettings.disabled then
		return
	end
	local emoteString = string_gsub(message or "", "%%s", sourceName)
	local now = GetTime()
	local emote, cleanupTime
	for emote, cleanupTime in pairs(recentEmotes) do
		if now >= cleanupTime then
			recentEmotes[emote] = nil
		end
	end
	if recentEmotes[emoteString] then
		return
	end
	DisplayEvent(eventSettings, FormatEvent(eventSettings.message, nil, nil, nil, nil, nil, nil, emoteString))
	recentEmotes[emoteString] = now + EMOTE_HOLD_TIME
end


-------------------------------------------------------------------------------
-- Merging and throttling.
-------------------------------------------------------------------------------

local function MergeEvents(numEvents, profile)
	local i
	for i = 1, numEvents do
		local unmergedEvent = unmergedEvents[i]
		local doMerge = false
		local _, mergedEvent
		for _, mergedEvent in ipairs(mergedEvents) do
			if unmergedEvent.eventType == mergedEvent.eventType then
				if not unmergedEvent.effectName then
					if unmergedEvent.name and unmergedEvent.name == mergedEvent.name and not mergedEvent.effectName then
						doMerge = true
					end
				elseif unmergedEvent.effectName == mergedEvent.effectName then
					if unmergedEvent.name ~= mergedEvent.name then
						mergedEvent.name = L["Multiple"]
					end
					if unmergedEvent.class ~= mergedEvent.class then
						mergedEvent.class = nil
					end
					doMerge = true
				end
			end
			if doMerge then
				mergedEvent.partialEffects = nil
				unmergedEvent.eventMerged = true
				if unmergedEvent.amount then
					mergedEvent.amount = (mergedEvent.amount or 0) + unmergedEvent.amount
				end
				if unmergedEvent.overhealAmount then
					mergedEvent.overhealAmount = (mergedEvent.overhealAmount or 0) + unmergedEvent.overhealAmount
				end
				mergedEvent.numMerged = mergedEvent.numMerged + 1
				if unmergedEvent.isCrit then
					mergedEvent.numCrits = mergedEvent.numCrits + 1
				else
					mergedEvent.isCrit = false
				end
				break
			end
		end
		if not doMerge then
			unmergedEvent.numMerged = 0
			unmergedEvent.numCrits = unmergedEvent.isCrit and 1 or 0
			table.insert(mergedEvents, unmergedEvent)
		end
	end

	if not profile.hideMergeTrailer then
		local _, mergedEvent
		for _, mergedEvent in ipairs(mergedEvents) do
			if mergedEvent.numMerged > 0 then
				local critTrailer = ""
				if mergedEvent.numCrits > 0 then
					critTrailer = string_format(", %d %s", mergedEvent.numCrits, mergedEvent.numCrits == 1 and L["Crit"] or L["Crits"])
				end
				mergedEvent.mergeTrailer = string_format(" [%d %s%s]", mergedEvent.numMerged + 1, L["Hits"], critTrailer)
			end
		end
	end

	for i = 1, numEvents do
		if unmergedEvents[1].eventMerged then
			Compat.wipe(unmergedEvents[1])
			table.insert(combatEventCache, unmergedEvents[1])
		end
		table_remove(unmergedEvents, 1)
	end
end

local function OnUpdateMergeFrame(frame, elapsed)
	lastMergeUpdate = lastMergeUpdate + elapsed
	if lastMergeUpdate < MERGE_DELAY_TIME then
		return
	end
	local profile = MSBTProfiles.currentProfile
	MergeEvents(getn(unmergedEvents), profile)

	local i
	for i = 1, getn(mergedEvents) do
		local combatEvent = mergedEvents[i]
		local eventSettings = profile.events[combatEvent.isCrit and combatEvent.eventType .. "_CRIT" or combatEvent.eventType]
			or profile.events[combatEvent.eventType]
		if eventSettings then
			local hideSkills = combatEvent.effectTexture and not profile.exclusiveSkillsDisabled or profile.hideSkills
			local outputMessage = FormatEvent(eventSettings.message, combatEvent.amount, combatEvent.damageType, combatEvent.overhealAmount,
				combatEvent.powerType, combatEvent.name, combatEvent.class, combatEvent.effectName, combatEvent.partialEffects,
				combatEvent.mergeTrailer, combatEvent.ignoreDamageColoring, hideSkills, profile.hideNames)
			DisplayEvent(eventSettings, outputMessage, combatEvent.effectTexture)
		end
		Compat.wipe(combatEvent)
		table.insert(combatEventCache, combatEvent)
	end
	Compat.wipe(mergedEvents)

	if getn(unmergedEvents) == 0 then
		frame:Hide()
	end
	lastMergeUpdate = 0
end

local function OnUpdateThrottleFrame(frame, elapsed)
	lastThrottleUpdate = lastThrottleUpdate + elapsed
	if lastThrottleUpdate < THROTTLE_UPDATE_TIME then
		return
	end
	local eventsThrottled
	local _, throttledAbility
	for _, throttledAbility in pairs(throttledAbilities) do
		if throttledAbility.throttleWindow > 0 then
			throttledAbility.throttleWindow = throttledAbility.throttleWindow - lastThrottleUpdate
			if throttledAbility.throttleWindow <= 0 then
				if getn(throttledAbility) > 0 then
					while getn(throttledAbility) > 0 do
						table.insert(unmergedEvents, table_remove(throttledAbility, 1))
					end
					if not mergeFrame:IsVisible() then
						mergeFrame:Show()
					end
				end
			else
				eventsThrottled = true
			end
		end
	end
	if not eventsThrottled then
		frame:Hide()
	end
	lastThrottleUpdate = 0
end

-- Returns true when the event was taken over by the throttle.
local function ThrottleEvent(combatEvent, parserEvent, profile)
	local effectName = combatEvent.effectName
	local throttleDuration = profile.throttleList[effectName]
	if not throttleDuration then
		if parserEvent.isDoT and profile.dotThrottleDuration > 0 then
			throttleDuration = profile.dotThrottleDuration
		elseif parserEvent.isHoT and profile.hotThrottleDuration > 0 then
			throttleDuration = profile.hotThrottleDuration
		elseif parserEvent.powerType and profile.powerThrottleDuration > 0 then
			throttleDuration = profile.powerThrottleDuration
		end
	end
	if not throttleDuration or throttleDuration <= 0 then
		return false
	end

	local throttledAbility = throttledAbilities[effectName]
	if not throttledAbility then
		throttledAbility = { throttleWindow = 0, lastEventTime = 0 }
		throttledAbilities[effectName] = throttledAbility
	end
	local now = GetTime()
	if throttledAbility.throttleWindow > 0 then
		throttledAbility.lastEventTime = now
		table.insert(throttledAbility, combatEvent)
		return true
	end
	throttledAbility.throttleWindow = throttleDuration
	if not throttleFrame:IsVisible() then
		throttleFrame:Show()
	end
	if now - throttledAbility.lastEventTime < throttleDuration then
		throttledAbility.lastEventTime = now
		table.insert(throttledAbility, combatEvent)
		return true
	end
	return false
end


-------------------------------------------------------------------------------
-- Parser event handlers. Each returns: event type key, effect name, affected
-- unit name, affected unit class, merge eligible and, optionally, the amount
-- to show when it differs from the event's own. The parser event is shared
-- with the other handlers and is never modified here.
-------------------------------------------------------------------------------

local function IsAutoShot(p)
	return autoShotName and p.skillName == autoShotName
end

local function DamageHandler(p, profile)
	local eventTypeString, name, class = GetInOutEventData(p)
	if not eventTypeString then
		return
	end
	if p.amount and p.amount < profile.damageThreshold then
		return
	end
	if p.skillName and not IsAutoShot(p) then
		eventTypeString = eventTypeString .. "_SPELL"
	end
	eventTypeString = eventTypeString .. (p.isDoT and "_DOT" or p.isDamageShield and "_DAMAGE_SHIELD" or "_DAMAGE")
	return eventTypeString, p.skillName, name, class, true
end

local function MissHandler(p, profile)
	local eventTypeString, name, class = GetInOutEventData(p)
	if not eventTypeString or not p.missType then
		return
	end
	if p.skillName and not IsAutoShot(p) then
		eventTypeString = eventTypeString .. "_SPELL"
	end
	return eventTypeString .. "_" .. p.missType, p.skillName, name, class, true
end

local function HealHandler(p, profile)
	local eventTypeString, name, class = GetInOutEventData(p)
	if not eventTypeString then
		return
	end
	local amount = p.amount
	if amount then
		if amount < profile.healThreshold then
			return
		end
		local effective = p.overhealAmount and (amount - p.overhealAmount) or amount
		if effective == 0 then
			if not p.isHoT and profile.hideFullOverheals then return end
			if p.isHoT and profile.hideFullHoTOverheals then return end
		end
	end
	if p.sourceName and p.sourceName == p.recipientName then
		eventTypeString = "SELF"
	end
	return eventTypeString .. (p.isHoT and "_HOT" or "_HEAL"), p.skillName, name, class, true
end

local function InterruptHandler(p, profile)
	local eventTypeString, name, class = GetInOutEventData(p)
	if not eventTypeString then
		return
	end
	return eventTypeString .. "_SPELL_INTERRUPT", p.extraSkillName, name, class
end

local function EnvironmentalHandler(p, profile)
	if p.recipientUnit ~= "player" then
		return
	end
	local hazardNames = {
		DROWNING = L["Drowning"], FALLING = L["Falling"], FATIGUE = L["Fatigue"],
		FIRE = L["Fire"], LAVA = L["Lava"], SLIME = L["Slime"],
	}
	return "INCOMING_ENVIRONMENTAL", hazardNames[p.hazardType] or p.hazardType
end

local function AuraHandler(p, profile)
	local effectName = p.skillName
	if not effectName then
		return
	end
	if p.recipientUnit == "player" then
		if ignoreAuras[effectName] or triggerSuppressions[effectName] then
			return
		end
		local eventTypeString = "NOTIFICATION_" .. (p.auraType or "BUFF")
		if p.isFade then
			eventTypeString = eventTypeString .. "_FADE"
		elseif p.isDose then
			eventTypeString = eventTypeString .. "_STACK"
		end
		return eventTypeString, effectName
	end

	-- A buff gained by the current hostile target.
	if triggerSuppressions[effectName] then
		return
	end
	if not Util.TestFlagsAll(p.recipientFlags, MSBTParser.TARGET_TARGET) then
		return
	end
	if not Compat.bool(UnitIsEnemy("player", "target")) then
		return
	end
	if p.auraType ~= "BUFF" or p.isFade then
		return
	end
	local now = GetTime()
	local buff, cleanupTime
	for buff, cleanupTime in pairs(recentEnemyBuffs) do
		if now >= cleanupTime then
			recentEnemyBuffs[buff] = nil
		end
	end
	if recentEnemyBuffs[effectName] then
		return
	end
	recentEnemyBuffs[effectName] = now + ENEMY_BUFF_HOLD_TIME
	return "NOTIFICATION_ENEMY_BUFF", effectName, p.recipientName, p.recipientClass
end

local function EnchantHandler(p, profile)
	if p.recipientUnit ~= "player" then
		return
	end
	return p.isFade and "NOTIFICATION_ITEM_BUFF_FADE" or "NOTIFICATION_ITEM_BUFF", p.skillName
end

local function DispelHandler(p, profile)
	if p.sourceUnit == "player" then
		return "OUTGOING_DISPEL", p.extraSkillName, p.recipientName, p.recipientClass
	elseif p.sourceUnit == "pet" then
		return "PET_OUTGOING_DISPEL", p.extraSkillName, p.recipientName, p.recipientClass
	end
end

local function PowerHandler(p, profile)
	if profile.showAllPowerGains then
		return
	end
	local amount
	if p.isLeech then
		if p.sourceUnit ~= "player" then
			return
		end
		amount = p.extraAmount
	else
		if p.recipientUnit ~= "player" then
			return
		end
		amount = p.amount
	end
	if not amount or amount == 0 or math_abs(amount) < profile.powerThreshold then
		return
	end
	return p.isDrain and "NOTIFICATION_POWER_LOSS" or "NOTIFICATION_POWER_GAIN", p.skillName, nil, nil, true, amount
end

local function KillHandler(p, profile)
	if p.sourceUnit ~= "player" or p.recipientUnit == "pet" then
		return
	end
	local isNPC = Util.TestFlagsAll(p.recipientFlags, MSBTParser.CONTROL_SERVER)
	return isNPC and "NOTIFICATION_NPC_KILLING_BLOW" or "NOTIFICATION_PC_KILLING_BLOW", nil, p.recipientName, p.recipientClass
end

local function HonorHandler(p, profile)
	if p.recipientUnit ~= "player" or not p.amount then
		return
	end
	return "NOTIFICATION_HONOR_GAIN"
end

local function ReputationHandler(p, profile)
	if p.recipientUnit ~= "player" then
		return
	end
	return p.isLoss and "NOTIFICATION_REP_LOSS" or "NOTIFICATION_REP_GAIN", p.factionName
end

local function ProficiencyHandler(p, profile)
	if p.recipientUnit ~= "player" then
		return
	end
	return "NOTIFICATION_SKILL_GAIN", p.skillName
end

local function ExperienceHandler(p, profile)
	if p.recipientUnit ~= "player" then
		return
	end
	return "NOTIFICATION_EXPERIENCE_GAIN"
end

local function ExtraAttacksHandler(p, profile)
	if p.sourceUnit ~= "player" then
		return
	end
	return "NOTIFICATION_EXTRA_ATTACK", p.skillName
end

local eventHandlers = {
	damage = DamageHandler,
	miss = MissHandler,
	heal = HealHandler,
	interrupt = InterruptHandler,
	environmental = EnvironmentalHandler,
	aura = AuraHandler,
	enchant = EnchantHandler,
	dispel = DispelHandler,
	power = PowerHandler,
	kill = KillHandler,
	honor = HonorHandler,
	reputation = ReputationHandler,
	proficiency = ProficiencyHandler,
	experience = ExperienceHandler,
	extraattacks = ExtraAttacksHandler,
}

local function QueueMergeEvent(p, profile, eventTypeString, effectName, name, class, effectTexture, damageType, partialEffects, ignoreDamageColoring, amount)
	local combatEvent = table_remove(combatEventCache) or {}
	combatEvent.eventType = eventTypeString
	combatEvent.isCrit = p.isCrit
	combatEvent.amount = amount
	combatEvent.effectName = effectName
	combatEvent.effectTexture = effectTexture
	combatEvent.name = name
	combatEvent.class = class
	combatEvent.damageType = damageType
	combatEvent.ignoreDamageColoring = ignoreDamageColoring
	combatEvent.partialEffects = partialEffects
	combatEvent.overhealAmount = p.overhealAmount
	combatEvent.powerType = p.powerType

	if effectName and ThrottleEvent(combatEvent, p, profile) then
		return
	end
	table.insert(unmergedEvents, combatEvent)
	if not mergeFrame:IsVisible() then
		mergeFrame:Show()
	end
end

local function ParserEventsHandler(p)
	local profile = MSBTProfiles.currentProfile
	local eventType = p.eventType
	local handler = eventHandlers[eventType]
	if not handler then
		return
	end
	if eventType == "heal" and not p.overhealAmount then
		EstimateOverheal(p)
	end

	local eventTypeString, effectName, name, class, mergeEligible, amount = handler(p, profile)
	if not eventTypeString then
		return
	end
	amount = amount or p.amount
	if effectName and profile.abilitySuppressions[effectName] then
		return
	end

	local isCrit = p.isCrit
	local eventSettings = profile.events[isCrit and eventTypeString .. "_CRIT" or eventTypeString]
	if not eventSettings or eventSettings.disabled or not IsScrollAreaActive(eventSettings.scrollArea) then
		return
	end

	if IsAutoShot(p) then
		effectName = nil
	end

	local damageType = p.damageType
	-- Outgoing physical skills are not colored, so they stand apart from swings.
	local ignoreDamageColoring
	if eventType == "damage" and p.sourceUnit == "player" and damageType == DAMAGETYPE_PHYSICAL and effectName then
		ignoreDamageColoring = true
	end
	if eventType == "miss" and p.missType == "ABSORB" then
		damageType = p.skillSchool or DAMAGETYPE_PHYSICAL
	end

	local partialEffects
	if eventType == "damage" or eventType == "environmental" then
		partialEffects = FormatPartialEffects(p.absorbAmount, p.blockAmount, p.resistAmount, p.vulnerableAmount, p.isGlancing, p.isCrushing)
	end

	local effectTexture
	if not profile.skillIconsDisabled and IsScrollAreaIconShown(eventSettings.scrollArea) then
		-- A guardian's ability names ("Attack" of a Searing Totem) collide with
		-- the player's spellbook, where "Attack" carries the main hand weapon
		-- icon, so a guardian shows the icon of the spell that summoned it.
		if p.sourceUnit == "pet" and Util.TestFlagsAll(p.sourceFlags, MSBTParser.UNITTYPE_GUARDIAN) then
			effectTexture = MikSBT.Icons.GetSkillIcon(p.sourceName)
		else
			effectTexture = MikSBT.Icons.GetSkillIcon(effectName)
		end
	end

	if not mergeEligible then
		DisplayEvent(eventSettings, FormatEvent(eventSettings.message, amount, damageType, nil, nil, name, class, effectName), effectTexture)
	elseif profile.mergeExclusions[effectName or ""] or (not effectName and profile.mergeSwingsDisabled) then
		local hideSkills = effectTexture and not profile.exclusiveSkillsDisabled or profile.hideSkills
		DisplayEvent(eventSettings, FormatEvent(eventSettings.message, amount, damageType, p.overhealAmount, p.powerType, name, class,
			effectName, partialEffects, nil, ignoreDamageColoring, hideSkills, profile.hideNames), effectTexture)
	else
		QueueMergeEvent(p, profile, eventTypeString, effectName, name, class, effectTexture, damageType, partialEffects, ignoreDamageColoring, amount)
	end
end


-------------------------------------------------------------------------------
-- Events.
-------------------------------------------------------------------------------

local function OnCombatState(eventKey)
	local eventSettings = MSBTProfiles.currentProfile.events[eventKey]
	if eventSettings and not eventSettings.disabled then
		DisplayEvent(eventSettings, eventSettings.message)
	end
end

local function BuildEventHandlers()
	gameEventHandlers = {
		PLAYER_REGEN_ENABLED = function() OnCombatState("NOTIFICATION_COMBAT_LEAVE") end,
		PLAYER_REGEN_DISABLED = function() OnCombatState("NOTIFICATION_COMBAT_ENTER") end,
		CHAT_MSG_MONSTER_EMOTE = HandleMonsterEmote,
		PLAYER_COMBO_POINTS = OnComboPoints,
		PLAYER_TARGET_CHANGED = function() lastComboPoints = GetComboPoints() or 0 end,
		UNIT_HEALTH = OnUnitHealth,
		UNIT_DISPLAYPOWER = function(unit) if unit == "player" then Compat.wipe(lastPowerAmounts) end end,
	}
	local eventName, powerType
	for eventName, powerType in pairs(POWER_EVENTS) do
		local capturedType = powerType
		gameEventHandlers[eventName] = function(unit) OnPowerUpdate(unit, capturedType) end
	end
end


-------------------------------------------------------------------------------
-- Lifecycle.
-------------------------------------------------------------------------------

-- Spell names used by the event filters, from LibBabble-Spell-2.2.
function module:OnInitialize()
	local LocalizedSpell = MSBTProfiles.LocalizedSpell
	autoShotName = LocalizedSpell("Auto Shot")
	local blink, rainOfFire = LocalizedSpell("Blink"), LocalizedSpell("Rain of Fire")
	if blink then ignoreAuras[blink] = true end
	if rainOfFire then ignoreAuras[rainOfFire] = true end
end

function module:OnEnable()
	Util.RegisterEvents(self, gameEventHandlers)
	MSBTParser.RegisterHandler(ParserEventsHandler)
end

-- AceEvent-3.0 unregisters every event of the module when it is disabled.
function module:OnDisable()
	mergeFrame:Hide()
	throttleFrame:Hide()
	MSBTParser.UnregisterHandler(ParserEventsHandler)
end

BuildEventHandlers()
mergeFrame = Util.CreateUpdateFrame(OnUpdateMergeFrame, "MSBTMergeFrame")
throttleFrame = Util.CreateUpdateFrame(OnUpdateThrottleFrame, "MSBTThrottleFrame")
CreateDamageMaps()
isEnglish = string_find(GetLocale(), "^en") and true or false


module.damageTypeMap = damageTypeMap
module.damageColorProfileEntries = damageColorProfileEntries
module.powerTokens = powerTokens
module.ParserEventsHandler = ParserEventsHandler

-- Public API (classic MSBTMain.lua).
MikSBT.DISPLAYTYPE_INCOMING = "Incoming"
MikSBT.DISPLAYTYPE_OUTGOING = "Outgoing"
MikSBT.DISPLAYTYPE_NOTIFICATION = "Notification"
MikSBT.DISPLAYTYPE_STATIC = "Static"
MikSBT.RegisterFont = MikSBT.Media.RegisterFont
MikSBT.RegisterSound = MikSBT.Media.RegisterSound
MikSBT.IterateFonts = MikSBT.Media.IterateFonts
MikSBT.IterateSounds = MikSBT.Media.IterateSounds
MikSBT.IterateScrollAreas = MSBTAnimations.IterateScrollAreas
MikSBT.DisplayMessage = MSBTAnimations.DisplayMessage
MikSBT.IsModDisabled = MSBTProfiles.IsModDisabled
