-------------------------------------------------------------------------------
-- Shared helpers (MikSBT.Util): event registration, update frames, hooks,
-- number formatting, name/class/unit bookkeeping.
-------------------------------------------------------------------------------

local _G = _G or getfenv()

local Compat = MikSBT.Compat
local Util = {}
MikSBT.Util = Util

local string_format = string.format
local string_gsub = string.gsub
local math_floor = math.floor


-------------------------------------------------------------------------------
-- Tables.
-------------------------------------------------------------------------------

function Util.CopyTable(src)
	local copy = {}
	for k, v in pairs(src) do
		if type(v) == "table" then
			v = Util.CopyTable(v)
		end
		copy[k] = v
	end
	return copy
end

Util.EraseTable = Compat.wipe


-------------------------------------------------------------------------------
-- Events (AceEvent-3.0).
--
-- The Ace3v AceEvent-3.0 calls a callback with the event name only. Handlers
-- here get the event arguments as parameters, read from the 1.12 arg1..arg9
-- globals, which are still set while the event is being dispatched.
-- Unregistration goes through the callback registry, so a handler stops
-- running even if the client ignores UnregisterEvent on AceEvent's frame.
-------------------------------------------------------------------------------

local eventCallbacks = setmetatable({}, { __mode = "k" })

local function EventCallback(handler)
	local callback = eventCallbacks[handler]
	if not callback then
		callback = function()
			handler(arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9)
		end
		eventCallbacks[handler] = callback
	end
	return callback
end

-- Registers one handler on an object that embeds AceEvent-3.0.
function Util.RegisterEvent(target, eventName, handler)
	target:RegisterEvent(eventName, EventCallback(handler))
end

-- Registers every eventName = handler pair of the table.
function Util.RegisterEvents(target, handlers)
	local eventName, handler
	for eventName, handler in pairs(handlers) do
		Util.RegisterEvent(target, eventName, handler)
	end
end

-- A frame whose OnUpdate runs only while it is shown. The callback receives
-- the elapsed time, computed from GetTime() instead of the handler argument.
function Util.CreateUpdateFrame(callback, name)
	local frame = CreateFrame("Frame", name, UIParent)
	frame:Hide()
	local last
	frame:SetScript("OnShow", function()
		last = GetTime()
	end)
	frame:SetScript("OnUpdate", function()
		local now = GetTime()
		local elapsed = now - (last or now)
		last = now
		callback(frame, elapsed)
	end)
	return frame
end


-------------------------------------------------------------------------------
-- Global function hooks. hooksecurefunc does not exist on Unreal Azeroth, so
-- the global is replaced by a wrapper that calls the original first and the
-- hook afterwards; a failing hook never breaks the original call.
-------------------------------------------------------------------------------

function Util.PostHookGlobal(globalName, hook)
	local original = _G[globalName]
	if type(original) ~= "function" then
		return false
	end
	_G[globalName] = function(a1, a2, a3, a4, a5, a6, a7, a8)
		local r1, r2, r3, r4 = original(a1, a2, a3, a4, a5, a6, a7, a8)
		pcall(hook, a1, a2, a3, a4, a5, a6, a7, a8)
		return r1, r2, r3, r4
	end
	return true
end

-- Runs the hook before the original.
function Util.PreHookGlobal(globalName, hook)
	local original = _G[globalName]
	if type(original) ~= "function" then
		return false
	end
	_G[globalName] = function(a1, a2, a3, a4, a5, a6, a7, a8)
		pcall(hook, a1, a2, a3, a4, a5, a6, a7, a8)
		return original(a1, a2, a3, a4, a5, a6, a7, a8)
	end
	return true
end


-------------------------------------------------------------------------------
-- Formatting.
-------------------------------------------------------------------------------

-- "|cFFrrggbb<text>|r" from 0..1 color components.
function Util.ColorText(text, r, g, b)
	return string_format("|cFF%02x%02x%02x%s|r", math_floor((r or 1) * 255 + 0.5), math_floor((g or 1) * 255 + 0.5), math_floor((b or 1) * 255 + 0.5), text)
end

-- SI-suffixed short number (k, M, G, T).
function Util.ShortenNumber(number, precision)
	number = tonumber(number)
	if not number then
		return 0
	end
	local formatter = "%." .. (precision or 0) .. "f"
	if number >= 1e12 then
		return string_format(formatter, number / 1e12) .. "T"
	elseif number >= 1e9 then
		return string_format(formatter, number / 1e9) .. "G"
	elseif number >= 1e6 then
		return string_format(formatter, number / 1e6) .. "M"
	elseif number >= 1e3 then
		return string_format(formatter, number / 1e3) .. "k"
	end
	return number
end

-- Digit grouping with a comma (the 1.12 client has no FormatLargeNumber).
function Util.GroupNumber(number)
	local formatted = tostring(number)
	local count
	repeat
		formatted, count = string_gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
	until count == 0
	return formatted
end

-- Applies the profile's number formatting options.
function Util.FormatNumber(number, profile)
	if profile.shortenNumbers then
		return Util.ShortenNumber(number, profile.shortenNumberPrecision)
	elseif profile.groupNumbers then
		return Util.GroupNumber(number)
	end
	return number
end

-- Escapes Lua pattern magic characters.
function Util.EscapePattern(text)
	return (string_gsub(text, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end


-------------------------------------------------------------------------------
-- Player, pet, group and class bookkeeping by name.
--
-- The 1.12 combat log carries only names. Unit IDs, classes and "is a player"
-- are learned from every unit the client exposes (player, pet, party, raid,
-- target, mouseover) and remembered by name.
-------------------------------------------------------------------------------

local classByName = {}
local playerNames = {}
local unitByName = {}
Util.classByName = classByName
Util.playerNames = playerNames
Util.unitByName = unitByName

function Util.PlayerName()
	return UnitName("player")
end

function Util.PetName()
	if UnitExists("pet") then
		return UnitName("pet")
	end
end

local function Learn(unit)
	if not UnitExists(unit) then
		return
	end
	local name = UnitName(unit)
	if not name then
		return
	end
	if Compat.bool(UnitIsPlayer(unit)) then
		playerNames[name] = true
		local _, class = UnitClass(unit)
		if class then
			classByName[name] = class
		end
	end
	return name
end
Util.LearnUnit = Learn

-- Rebuilds the name -> unit ID map of units whose health is exact (player,
-- pet, party, raid). Target and mouseover are only learned, never mapped:
-- their health is a percentage for units outside the group.
function Util.UpdateRoster()
	Compat.wipe(unitByName)
	local name = Learn("player")
	if name then unitByName[name] = "player" end
	name = UnitExists("pet") and UnitName("pet")
	if name then unitByName[name] = "pet" end
	local i
	local numRaid = GetNumRaidMembers and GetNumRaidMembers() or 0
	if numRaid > 0 then
		for i = 1, numRaid do
			name = Learn("raid" .. i)
			if name and not unitByName[name] then unitByName[name] = "raid" .. i end
			name = UnitExists("raidpet" .. i) and UnitName("raidpet" .. i)
			if name and not unitByName[name] then unitByName[name] = "raidpet" .. i end
		end
	else
		for i = 1, (GetNumPartyMembers and GetNumPartyMembers() or 0) do
			name = Learn("party" .. i)
			if name and not unitByName[name] then unitByName[name] = "party" .. i end
			name = UnitExists("partypet" .. i) and UnitName("partypet" .. i)
			if name and not unitByName[name] then unitByName[name] = "partypet" .. i end
		end
	end
end

-- Keeps the name/unit/class bookkeeping current while the addon is enabled.
local Roster = MikSBT:NewModule("Roster", "AceEvent-3.0")

local rosterHandlers = {
	PLAYER_ENTERING_WORLD = function() Util.UpdateRoster() end,
	PARTY_MEMBERS_CHANGED = function() Util.UpdateRoster() end,
	RAID_ROSTER_UPDATE = function() Util.UpdateRoster() end,
	UNIT_PET = function() Util.UpdateRoster() end,
	PLAYER_TARGET_CHANGED = function() Learn("target") end,
	UPDATE_MOUSEOVER_UNIT = function() Learn("mouseover") end,
}

function Roster:OnEnable()
	Util.UpdateRoster()
	Util.RegisterEvents(self, rosterHandlers)
end


-------------------------------------------------------------------------------
-- Bit tests. The WoW clients provide the `bit` library; the arithmetic
-- fallback only covers the non-negative flag values MSBT uses.
-------------------------------------------------------------------------------

local band = bit and bit.band or function(a, b)
	local result, value = 0, 1
	a, b = a or 0, b or 0
	while a > 0 and b > 0 do
		if Compat.mod(a, 2) == 1 and Compat.mod(b, 2) == 1 then
			result = result + value
		end
		a, b = math_floor(a / 2), math_floor(b / 2)
		value = value * 2
	end
	return result
end
Util.band = band

function Util.TestFlagsAny(flags, test)
	return band(flags or 0, test or 0) > 0
end

function Util.TestFlagsAll(flags, test)
	return band(flags or 0, test or 0) == test
end
