-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Cooldowns
--
-- "Skill ready" notifications for player spells, pet spells and items.
--
-- The 1.12 client reports no spell ID for a cast, so cooldowns are found by
-- scanning instead: every SPELL_UPDATE_COOLDOWN / PET_BAR_UPDATE_COOLDOWN /
-- BAG_UPDATE_COOLDOWN rescans the spellbook (one entry per spell name), the
-- pet spellbook, or the bags and equipped items for cooldowns longer than the
-- threshold. A tracked cooldown that ends much earlier than expected was
-- reset (Cold Snap, Preparation, ...) and is dropped without a notification.
-------------------------------------------------------------------------------

local _G = _G or getfenv()

local module = MikSBT:NewModule("Cooldowns", "AceEvent-3.0")
MikSBT.Cooldowns = module

local Compat = MikSBT.Compat
local Util = MikSBT.Util
local MSBTProfiles = MikSBT.Profiles

local string_gsub = string.gsub

-- Cooldowns up to this long are the global cooldown and never tracked.
local GLOBAL_COOLDOWN = 1.5
-- A cooldown ending this many seconds early counts as reset.
local RESET_TOLERANCE = 1
local MIN_UPDATE_DELAY = 0.1
local MAX_UPDATE_DELAY = 1

local gameEventHandlers, updateFrame

-- name -> spellbook index of its highest rank, per book.
local bookIndices = { spell = {}, pet = {} }
-- type -> name -> { endTime, texture, index/bag/slot }.
local activeCooldowns = { player = {}, pet = {}, item = {} }

local playerEnabled, petEnabled, itemEnabled
local lastUpdate, updateDelay = 0, MIN_UPDATE_DELAY


-------------------------------------------------------------------------------
-- Scanning.
-------------------------------------------------------------------------------

local function RebuildBook(bookType)
	local indices = bookIndices[bookType]
	Compat.wipe(indices)
	local i = 1
	while true do
		local name = GetSpellName(i, bookType)
		if not name then
			break
		end
		indices[name] = i
		i = i + 1
	end
end

local function RebuildBooks()
	pcall(RebuildBook, "spell")
	if UnitExists("pet") then
		pcall(RebuildBook, "pet")
	else
		Compat.wipe(bookIndices.pet)
	end
end

local function IsTracked(profile, name, duration)
	if profile.cooldownExclusions[name] then
		return false
	end
	if profile.ignoreCooldownThreshold[name] then
		return duration > GLOBAL_COOLDOWN
	end
	return duration >= profile.cooldownThreshold and duration > GLOBAL_COOLDOWN
end

local function StartUpdates()
	updateDelay = MIN_UPDATE_DELAY
	if not updateFrame:IsVisible() then
		updateFrame:Show()
	end
end

local function ScanSpells(cooldownType, bookType)
	local profile = MSBTProfiles.currentProfile
	local active = activeCooldowns[cooldownType]
	local now = GetTime()
	local name, index
	for name, index in pairs(bookIndices[bookType]) do
		local start, duration, enabled = GetSpellCooldown(index, bookType)
		if start and start > 0 and duration and Compat.bool(enabled) and not active[name] and IsTracked(profile, name, duration) then
			local endTime = start + duration
			if endTime > now then
				active[name] = { endTime = endTime, index = index, bookType = bookType, texture = GetSpellTexture(index, bookType) }
				StartUpdates()
			end
		end
	end
end

local function TrackItem(profile, active, now, link, start, duration, enabled, texture, checkFunc)
	if not link or not start or start <= 0 or not duration or not Compat.bool(enabled) then
		return
	end
	local name = Compat.match(link, "%[(.-)%]")
	if not name or active[name] or not IsTracked(profile, name, duration) then
		return
	end
	local endTime = start + duration
	if endTime > now then
		active[name] = { endTime = endTime, texture = texture, check = checkFunc }
		MikSBT.Icons.Learn(name, texture)
		StartUpdates()
	end
end

local function ScanItems()
	local profile = MSBTProfiles.currentProfile
	local active = activeCooldowns.item
	local now = GetTime()
	local bag, slot
	for bag = 0, 4 do
		for slot = 1, (GetContainerNumSlots(bag) or 0) do
			local start, duration, enabled = GetContainerItemCooldown(bag, slot)
			if start and start > 0 then
				local texture = GetContainerItemInfo(bag, slot)
				local b, s = bag, slot
				TrackItem(profile, active, now, GetContainerItemLink(bag, slot), start, duration, enabled, texture,
					function() return GetContainerItemCooldown(b, s) end)
			end
		end
	end
	for slot = 1, 19 do
		local start, duration, enabled = GetInventoryItemCooldown("player", slot)
		if start and start > 0 then
			local s = slot
			TrackItem(profile, active, now, GetInventoryItemLink("player", slot), start, duration, enabled,
				GetInventoryItemTexture("player", slot), function() return GetInventoryItemCooldown("player", s) end)
		end
	end
end


-------------------------------------------------------------------------------
-- Notifications.
-------------------------------------------------------------------------------

local EVENT_KEYS = { player = "NOTIFICATION_COOLDOWN", pet = "NOTIFICATION_PET_COOLDOWN", item = "NOTIFICATION_ITEM_COOLDOWN" }

local function Notify(cooldownType, name, texture)
	MikSBT.Triggers.HandleCooldowns(cooldownType, nil, name, texture)
	local eventSettings = MSBTProfiles.currentProfile.events[EVENT_KEYS[cooldownType]]
	if eventSettings and not eventSettings.disabled then
		local skillName = string_gsub(name, "%(.+%)$", "")
		local formatted = Util.ColorText(skillName, eventSettings.skillColorR or 1, eventSettings.skillColorG or 0, eventSettings.skillColorB or 0)
		local message = string_gsub(eventSettings.message, "%%e", formatted)
		MikSBT.Animations.DisplayEvent(eventSettings, message, texture)
	end
end

-- Current (start, duration) of a tracked cooldown.
local function Query(info)
	if info.check then
		return info.check()
	end
	return GetSpellCooldown(info.index, info.bookType)
end

local function OnUpdate(frame, elapsed)
	lastUpdate = lastUpdate + elapsed
	if lastUpdate < updateDelay then
		return
	end
	lastUpdate = 0
	updateDelay = MAX_UPDATE_DELAY

	local now = GetTime()
	local anyActive = false
	local cooldownType, cooldowns
	for cooldownType, cooldowns in pairs(activeCooldowns) do
		local name, info
		for name, info in pairs(cooldowns) do
			local start, duration = Query(info)
			local remaining
			if start and start > 0 and duration then
				remaining = start + duration - now
				info.endTime = start + duration
			else
				remaining = 0
			end
			if cooldownType == "pet" then
				-- Pet cooldowns are unreliable after the pet is dismissed; the
				-- time recorded at the start decides.
				remaining = info.endTime - now
			end
			if remaining <= 0 then
				if now >= info.endTime - RESET_TOLERANCE then
					Notify(cooldownType, name, info.texture)
				end
				cooldowns[name] = nil
			else
				anyActive = true
				if remaining < updateDelay then
					updateDelay = remaining
				end
			end
		end
	end
	if updateDelay < MIN_UPDATE_DELAY then
		updateDelay = MIN_UPDATE_DELAY
	end
	if not anyActive then
		frame:Hide()
	end
end


-------------------------------------------------------------------------------
-- Registration.
-------------------------------------------------------------------------------

local function UpdateRegisteredEvents()
	local profile = MSBTProfiles.currentProfile
	if not profile then
		return
	end
	local triggers = MikSBT.Triggers.categorizedTriggers
	local disabled = not module:IsEnabled()
	local events = profile.events

	playerEnabled = not disabled and (not events.NOTIFICATION_COOLDOWN.disabled or triggers.SKILL_COOLDOWN ~= nil)
	petEnabled = not disabled and (not events.NOTIFICATION_PET_COOLDOWN.disabled or triggers.PET_COOLDOWN ~= nil)
	itemEnabled = not disabled and (not events.NOTIFICATION_ITEM_COOLDOWN.disabled or triggers.ITEM_COOLDOWN ~= nil)

	local register = function(enabled, eventName)
		if enabled then
			Util.RegisterEvent(module, eventName, gameEventHandlers[eventName])
		else
			module:UnregisterEvent(eventName)
		end
	end
	register(playerEnabled, "SPELL_UPDATE_COOLDOWN")
	register(petEnabled, "PET_BAR_UPDATE_COOLDOWN")
	register(itemEnabled, "BAG_UPDATE_COOLDOWN")
	register(playerEnabled or petEnabled, "SPELLS_CHANGED")
	register(petEnabled, "UNIT_PET")
end

gameEventHandlers = {
	SPELL_UPDATE_COOLDOWN = function() ScanSpells("player", "spell") end,
	PET_BAR_UPDATE_COOLDOWN = function() ScanSpells("pet", "pet") end,
	BAG_UPDATE_COOLDOWN = function() ScanItems() end,
	SPELLS_CHANGED = RebuildBooks,
	UNIT_PET = function(unit) if unit == "player" then RebuildBooks() end end,
}
updateFrame = Util.CreateUpdateFrame(OnUpdate, "MSBTCooldownsUpdateFrame")


-------------------------------------------------------------------------------
-- Lifecycle.
-------------------------------------------------------------------------------

function module:OnEnable()
	RebuildBooks()
	UpdateRegisteredEvents()
end

-- AceEvent-3.0 unregisters every event of the module when it is disabled.
function module:OnDisable()
	updateFrame:Hide()
	local _, cooldowns
	for _, cooldowns in pairs(activeCooldowns) do
		Compat.wipe(cooldowns)
	end
end


module.UpdateRegisteredEvents = UpdateRegisteredEvents
module.activeCooldowns = activeCooldowns
module.ScanSpells = ScanSpells
module.ScanItems = ScanItems
