-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Loot
-- Author: Mikord (original), 1.12.1 / Unreal Azeroth port
--
-- Looted items and money. The 1.12 client has no GetItemCount, so the total
-- carried count comes from a bag scan (see "Carried item counts" below).
-------------------------------------------------------------------------------

local _G = _G or getfenv()

local module = {}
MikSBT.Loot = module

local Compat = MikSBT.Compat
local Util = MikSBT.Util
local MSBTProfiles = MikSBT.Profiles

local string_gsub = string.gsub
local string_format = string.format
local math_ceil = math.ceil
local math_min = math.min

-- Coin names as they appear in the money line.
local GOLD = _G.GOLD or "Gold"
local SILVER = _G.SILVER or "Silver"
local COPPER = _G.COPPER or "Copper"

-- Localized item class name of quest items (5th GetItemInfo return on 1.12).
-- The client has no global string for it, so it comes from the locale files.
local function QuestItemType()
	return MikSBT.L["Quest"]
end

local qualityPatterns = {}


local function ItemString(itemLink)
	return Compat.match(itemLink, "(item:%d+:%d+:%d+:%d+)") or Compat.match(itemLink, "(item:%d+)")
end


-------------------------------------------------------------------------------
-- Carried item counts.
--
-- CHAT_MSG_LOOT and the bag update of the looted item come in no fixed order:
-- the bags may already hold the item when the message arrives, or get it a
-- few frames later. The bags are rescanned shortly after every BAG_UPDATE
-- (container data on the real 1.12.1 client can lag one event behind) and on
-- every loot message; each per-item increase is kept for a few seconds as an
-- arrival. A loot message claims the recent arrivals of its item, which are
-- already in the count; the rest is added to the count and reserved, so the
-- increase that brings it later is not taken as an arrival for the next loot.
-------------------------------------------------------------------------------

-- Seconds an arrival or a reservation stays matchable.
local MATCH_WINDOW = 2
-- Delay of the rescan after a BAG_UPDATE; further updates meanwhile join it.
local RESCAN_DELAY = 0.2

-- counts: itemID -> carried count at the last scan (nil until the first one).
-- arrived / reserved: itemID -> { amount, time }.
local tracker = { arrived = {}, reserved = {} }

local function ScanBags()
	local counts = {}
	local bag, slot
	for bag = 0, 4 do
		for slot = 1, (GetContainerNumSlots(bag) or 0) do
			local link = GetContainerItemLink(bag, slot)
			local itemID = link and Compat.match(link, "item:(%d+)")
			if itemID then
				local _, count = GetContainerItemInfo(bag, slot)
				counts[itemID] = (counts[itemID] or 0) + (count or 1)
			end
		end
	end
	return counts
end

-- Amount of a still matchable entry; an expired entry is dropped.
local function Recent(list, itemID, now)
	local entry = list[itemID]
	if entry and now - entry.time <= MATCH_WINDOW then
		return entry.amount
	end
	list[itemID] = nil
	return 0
end

local function AddRecent(list, itemID, amount, now)
	list[itemID] = { amount = Recent(list, itemID, now) + amount, time = now }
end

-- Removes amount from an entry that Recent() has just reported.
local function TakeRecent(list, itemID, amount)
	local entry = list[itemID]
	entry.amount = entry.amount - amount
	if entry.amount <= 0 then
		list[itemID] = nil
	end
end

-- Rescans the bags. Increases fill reservations first, the rest become
-- arrivals. The first scan only sets the baseline.
local function RefreshCounts()
	tracker.rescanAt = nil
	local counts = ScanBags()
	local old = tracker.counts
	tracker.counts = counts
	if not old then
		return
	end
	local now = GetTime()
	local itemID, count
	for itemID, count in pairs(counts) do
		local increase = count - (old[itemID] or 0)
		if increase > 0 then
			local claimed = math_min(increase, Recent(tracker.reserved, itemID, now))
			if claimed > 0 then
				TakeRecent(tracker.reserved, itemID, claimed)
			end
			if increase > claimed then
				AddRecent(tracker.arrived, itemID, increase - claimed, now)
			end
		end
	end
end

-- Number of the item carried once numLooted of it is in the bags.
local function CarriedTotal(itemID, numLooted)
	RefreshCounts()
	local now = GetTime()
	local arrived = math_min(numLooted, Recent(tracker.arrived, itemID, now))
	if arrived > 0 then
		TakeRecent(tracker.arrived, itemID, arrived)
	end
	local pending = numLooted - arrived
	if pending > 0 then
		AddRecent(tracker.reserved, itemID, pending, now)
	end
	return (tracker.counts[itemID] or 0) + pending
end

local function OnUpdate(frame)
	if tracker.rescanAt and GetTime() >= tracker.rescanAt then
		RefreshCounts()
	end
	if not tracker.rescanAt then
		frame:Hide()
	end
end

local updateFrame = Util.CreateUpdateFrame(OnUpdate, "MSBTLootUpdateFrame")

local function OnBagUpdate()
	if not tracker.rescanAt then
		tracker.rescanAt = GetTime() + RESCAN_DELAY
		updateFrame:Show()
	end
end


local function HandleMoney(parserEvent)
	local moneyString = parserEvent.moneyString or ""
	moneyString = string_gsub(moneyString, "(%d+ " .. GOLD .. ")", "|cffffd700%1|r")
	moneyString = string_gsub(moneyString, "(%d+ " .. SILVER .. ")", "|cff808080%1|r")
	moneyString = string_gsub(moneyString, "(%d+ " .. COPPER .. ")", "|cffeda55f%1|r")
	local eventSettings = MSBTProfiles.currentProfile.events.NOTIFICATION_MONEY
	if eventSettings and not eventSettings.disabled then
		MikSBT.Animations.DisplayEvent(eventSettings, string_gsub(eventSettings.message, "%%e", moneyString))
	end
end

local function HandleItems(parserEvent)
	if parserEvent.isCreate then
		return
	end
	local itemString = ItemString(parserEvent.itemLink or "")
	if not itemString then
		return
	end
	local itemName, _, itemQuality, _, itemType, _, _, _, itemTexture = GetItemInfo(itemString)
	if not itemName then
		itemName = Compat.match(parserEvent.itemLink, "%[(.-)%]") or parserEvent.itemLink
	end

	local profile = MSBTProfiles.currentProfile
	local isQuestItem = itemType and itemType == QuestItemType()
	local showEvent = true
	if itemQuality and profile.qualityExclusions[itemQuality] then
		showEvent = false
	end
	if isQuestItem and profile.alwaysShowQuestItems then
		showEvent = true
	end
	if profile.itemExclusions[itemName] then
		showEvent = false
	end
	if profile.itemsAllowed[itemName] then
		showEvent = true
	end
	if not showEvent then
		return
	end

	MikSBT.Icons.Learn(itemName, itemTexture)
	local displayName = itemName
	local questColor = profile.questItemColor
	-- Quest items get their own color instead of the quality color.
	if isQuestItem and questColor and not questColor.disabled then
		displayName = Util.ColorText("[" .. itemName .. "]", questColor.colorR, questColor.colorG, questColor.colorB)
	elseif itemQuality and qualityPatterns[itemQuality] then
		displayName = string_format(qualityPatterns[itemQuality], itemName)
	end

	local numLooted = parserEvent.amount or 1
	local numTotal = CarriedTotal(Compat.match(itemString, "item:(%d+)"), numLooted)

	local eventSettings = profile.events.NOTIFICATION_LOOT
	if eventSettings and not eventSettings.disabled then
		local message = eventSettings.message
		message = string_gsub(message, "%%e", displayName)
		message = string_gsub(message, "%%a", numLooted)
		message = string_gsub(message, "%%t", numTotal)
		MikSBT.Animations.DisplayEvent(eventSettings, message, itemTexture)
	end
end

local function ParserEventsHandler(parserEvent)
	if parserEvent.eventType ~= "loot" or parserEvent.recipientUnit ~= "player" then
		return
	end
	if parserEvent.isMoney then
		HandleMoney(parserEvent)
	elseif parserEvent.itemLink then
		HandleItems(parserEvent)
	end
end


local k, v
for k, v in pairs(ITEM_QUALITY_COLORS or {}) do
	qualityPatterns[k] = string_format("|cFF%02x%02x%02x[%%s]|r", math_ceil(v.r * 255), math_ceil(v.g * 255), math_ceil(v.b * 255))
end

LibStub("AceEvent-3.0"):Embed(module)
Util.RegisterEvent(module, "BAG_UPDATE", OnBagUpdate)
MikSBT.Parser.RegisterHandler(ParserEventsHandler)
