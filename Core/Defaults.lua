-------------------------------------------------------------------------------
-- Default settings (MikSBT.Defaults), in AceDB-3.0 defaults format.
--
-- The profile section is the classic MSBT 6.0 master profile restricted to
-- what exists on the 1.12.1 client: no Chi/Holy Power/Arcane Charges/Essence,
-- no alternate power, no currency, only the seven base damage schools and the
-- nine vanilla classes. Key names are the classic ones, so classic option
-- semantics carry over unchanged.
--
-- Every value here is the ONLY place a default lives. Code reads db.profile
-- and relies on AceDB to fill in whatever the user has not changed.
-------------------------------------------------------------------------------

local _G = _G or getfenv()
local L = MikSBT.L

-- Blizzard strings used in default messages, with English fallbacks in case a
-- client does not define one of them.
local MISS = _G.MISS or "Miss"
local DODGE = _G.DODGE or "Dodge"
local PARRY = _G.PARRY or "Parry"
local BLOCK = _G.BLOCK or "Block"
local DEFLECT = _G.DEFLECT or "Deflect"
local ABSORB = _G.ABSORB or "Absorb"
local IMMUNE = _G.IMMUNE or "Immune"
local RESIST = _G.RESIST or "Resist"
local REFLECT = _G.REFLECT or "Reflect"
local INTERRUPT = _G.INTERRUPT or "Interrupt"
local EVADE = _G.EVADE or "Evade"
local PET = _G.PET or "Pet"
local HONOR = _G.HONOR or "Honor"
local REPUTATION = _G.REPUTATION or "Reputation"
local XP = _G.XP or "XP"

-- Converts a Blizzard partial-effect trailer such as " (%d absorbed)" into the
-- MSBT form " <%a absorbed>".
local function Trailer(globalName, fallback)
	local text = _G[globalName] or fallback
	text = string.gsub(text, "%((.+)%)", "<%1>")
	text = string.gsub(text, "%%d", "%%a")
	return text
end

-- Class colors come from the client table when it has the class.
local function ClassColor(class, r, g, b)
	local c = _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class]
	if c then
		return { colorR = c.r, colorG = c.g, colorB = c.b }
	end
	return { colorR = r, colorG = g, colorB = b }
end

-- Combat log flag value the triggers use for "the player". Written as a
-- decimal number: hexadecimal literals are not portable to every Lua 5.0 build.
local FLAG_YOU = "4026531840"
local REACTION_HOSTILE = "64"

MikSBT.DEFAULT_FONT_NAME = "MSBT Porky"
MikSBT.DEFAULT_SCROLL_AREA = "Notification"

local profile = {}
MikSBT.Defaults = {
	profile = profile,
	global = {
		userDisabled = false,
		moverPanel = {},
		moverBindings = {},
		gridSize = 64,
	},
}

profile.scrollAreas = {
	Incoming = {
		name = L["Incoming"],
		offsetX = -140,
		offsetY = -160,
		animationStyle = "Parabola",
		direction = "Down",
		behavior = "CurvedLeft",
		stickyBehavior = "Jiggle",
		textAlignIndex = 3,
		stickyTextAlignIndex = 3,
	},
	Outgoing = {
		name = L["Outgoing"],
		offsetX = 100,
		offsetY = -160,
		animationStyle = "Parabola",
		direction = "Down",
		behavior = "CurvedRight",
		stickyBehavior = "Jiggle",
		textAlignIndex = 1,
		stickyTextAlignIndex = 1,
		iconAlign = "Right",
	},
	Notification = {
		name = L["Notification"],
		offsetX = -175,
		offsetY = 120,
		scrollHeight = 200,
		scrollWidth = 350,
	},
	Static = {
		name = L["Static"],
		offsetX = -20,
		offsetY = -300,
		scrollHeight = 125,
		animationStyle = "Static",
		direction = "Down",
	},
}

-- Built-in event settings (classic master profile, 1.12 subset).
profile.events = {
	INCOMING_DAMAGE = {
		colorG = 0,
		colorB = 0,
		message = "(%n) -%a",
		scrollArea = "Incoming",
	},
	INCOMING_DAMAGE_CRIT = {
		colorG = 0,
		colorB = 0,
		message = "(%n) -%a",
		scrollArea = "Incoming",
		isCrit = true,
	},
	INCOMING_MISS = {
		colorR = 0,
		colorG = 0,
		message = MISS .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_DODGE = {
		colorR = 0,
		colorG = 0,
		message = DODGE .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_PARRY = {
		colorR = 0,
		colorG = 0,
		message = PARRY .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_BLOCK = {
		colorR = 0,
		colorG = 0,
		message = BLOCK .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_DEFLECT = {
		colorR = 0,
		colorG = 0,
		message = DEFLECT .. "!",
		scrollArea = "Incoming",
	},
	-- Full absorbs carry no amount on 1.12 ("%s attacks. You absorb all the
	-- damage.", "You absorb %s's %s."), so the *_ABSORB messages have no %a
	-- code, unlike MSBT classic.
	INCOMING_ABSORB = {
		colorB = 0,
		message = ABSORB .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_IMMUNE = {
		colorB = 0,
		message = IMMUNE .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_SPELL_DAMAGE = {
		colorG = 0,
		colorB = 0,
		message = "(%s) -%a",
		scrollArea = "Incoming",
	},
	INCOMING_SPELL_DAMAGE_CRIT = {
		colorG = 0,
		colorB = 0,
		message = "(%s) -%a",
		scrollArea = "Incoming",
		isCrit = true,
	},
	INCOMING_SPELL_DAMAGE_SHIELD = {
		colorG = 0,
		colorB = 0,
		message = "(%s) -%a",
		scrollArea = "Incoming",
	},
	INCOMING_SPELL_DAMAGE_SHIELD_CRIT = {
		colorG = 0,
		colorB = 0,
		message = "(%s) -%a",
		scrollArea = "Incoming",
		isCrit = true,
	},
	INCOMING_SPELL_DOT = {
		colorG = 0,
		colorB = 0,
		message = "(%s) -%a",
		scrollArea = "Incoming",
	},
	INCOMING_SPELL_DOT_CRIT = {
		colorG = 0,
		colorB = 0,
		message = "(%s) -%a",
		scrollArea = "Incoming",
		isCrit = true,
	},
	INCOMING_SPELL_MISS = {
		colorR = 0,
		colorG = 0,
		message = "(%s) " .. MISS .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_SPELL_DODGE = {
		colorR = 0,
		colorG = 0,
		message = "(%s) " .. DODGE .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_SPELL_PARRY = {
		colorR = 0,
		colorG = 0,
		message = "(%s) " .. PARRY .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_SPELL_BLOCK = {
		colorR = 0,
		colorG = 0,
		message = "(%s) " .. BLOCK .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_SPELL_DEFLECT = {
		colorR = 0,
		colorG = 0,
		message = "(%s) " .. DEFLECT .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_SPELL_RESIST = {
		colorR = 0.5,
		colorG = 0,
		colorB = 0.5,
		message = "(%s) " .. RESIST .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_SPELL_ABSORB = {
		colorB = 0,
		message = "(%s) " .. ABSORB .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_SPELL_IMMUNE = {
		colorB = 0,
		message = "(%s) " .. IMMUNE .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_SPELL_REFLECT = {
		colorR = 0.5,
		colorG = 0,
		colorB = 0.5,
		message = "(%s) " .. REFLECT .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_SPELL_INTERRUPT = {
		colorB = 0,
		message = "(%s) " .. INTERRUPT .. "!",
		scrollArea = "Incoming",
	},
	INCOMING_HEAL = {
		colorR = 0,
		colorB = 0,
		message = "(%s - %n) +%a",
		scrollArea = "Incoming",
	},
	INCOMING_HEAL_CRIT = {
		colorR = 0,
		colorB = 0,
		message = "(%s - %n) +%a",
		fontSize = 22,
		scrollArea = "Incoming",
		isCrit = true,
	},
	INCOMING_HOT = {
		colorR = 0,
		colorB = 0,
		message = "(%s - %n) +%a",
		scrollArea = "Incoming",
	},
	INCOMING_HOT_CRIT = {
		colorR = 0,
		colorB = 0,
		message = "(%s - %n) +%a",
		scrollArea = "Incoming",
		isCrit = true,
	},
	SELF_HEAL = {
		colorR = 0,
		colorB = 0,
		message = "(%s - %n) +%a",
		scrollArea = "Incoming",
	},
	SELF_HEAL_CRIT = {
		colorR = 0,
		colorB = 0,
		message = "(%s - %n) +%a",
		fontSize = 22,
		scrollArea = "Incoming",
		isCrit = true,
	},
	SELF_HOT = {
		colorR = 0,
		colorB = 0,
		message = "(%s - %n) +%a",
		scrollArea = "Incoming",
	},
	SELF_HOT_CRIT = {
		colorR = 0,
		colorB = 0,
		message = "(%s - %n) +%a",
		scrollArea = "Incoming",
		isCrit = true,
	},
	INCOMING_ENVIRONMENTAL = {
		colorG = 0,
		colorB = 0,
		message = "-%a %e",
		scrollArea = "Incoming",
	},
	OUTGOING_DAMAGE = {
		message = "%a",
		scrollArea = "Outgoing",
	},
	OUTGOING_DAMAGE_CRIT = {
		message = "%a",
		scrollArea = "Outgoing",
		isCrit = true,
	},
	OUTGOING_MISS = {
		message = MISS .. "!",
		scrollArea = "Outgoing",
	},
	OUTGOING_DODGE = {
		message = DODGE .. "!",
		scrollArea = "Outgoing",
	},
	OUTGOING_PARRY = {
		message = PARRY .. "!",
		scrollArea = "Outgoing",
	},
	OUTGOING_BLOCK = {
		message = BLOCK .. "!",
		scrollArea = "Outgoing",
	},
	OUTGOING_DEFLECT = {
		message = DEFLECT.. "!",
		scrollArea = "Outgoing",
	},
	OUTGOING_ABSORB = {
		colorB = 0,
		message = ABSORB .. "!",
		scrollArea = "Outgoing",
	},
	OUTGOING_IMMUNE = {
		colorB = 0,
		message = IMMUNE .. "!",
		scrollArea = "Outgoing",
	},
	OUTGOING_EVADE = {
		colorG = 0.5,
		colorB = 0,
		message = EVADE .. "!",
		fontSize = 22,
		scrollArea = "Outgoing",
	},
	OUTGOING_SPELL_DAMAGE = {
		colorB = 0,
		message = "%a (%s)",
		scrollArea = "Outgoing",
	},
	OUTGOING_SPELL_DAMAGE_CRIT = {
		colorB = 0,
		message = "%a (%s)",
		scrollArea = "Outgoing",
		isCrit = true,
	},
	OUTGOING_SPELL_DAMAGE_SHIELD = {
		colorB = 0,
		message = "%a (%s)",
		scrollArea = "Outgoing",
	},
	OUTGOING_SPELL_DAMAGE_SHIELD_CRIT = {
		colorB = 0,
		message = "%a (%s)",
		scrollArea = "Outgoing",
		isCrit = true,
	},
	OUTGOING_SPELL_DOT = {
		colorB = 0,
		message = "%a (%s)",
		scrollArea = "Outgoing",
	},
	OUTGOING_SPELL_DOT_CRIT = {
		colorB = 0,
		message = "%a (%s)",
		scrollArea = "Outgoing",
		isCrit = true,
	},
	OUTGOING_SPELL_MISS = {
		message = MISS .. "! (%s)",
		scrollArea = "Outgoing",
	},
	OUTGOING_SPELL_DODGE = {
		message = DODGE .. "! (%s)",
		scrollArea = "Outgoing",
	},
	OUTGOING_SPELL_PARRY = {
		message = PARRY .. "! (%s)",
		scrollArea = "Outgoing",
	},
	OUTGOING_SPELL_BLOCK = {
		message = BLOCK .. "! (%s)",
		scrollArea = "Outgoing",
	},
	OUTGOING_SPELL_DEFLECT = {
		message = DEFLECT .. "! (%s)",
		scrollArea = "Outgoing",
	},
	OUTGOING_SPELL_RESIST = {
		colorR = 0.5,
		colorG = 0.5,
		colorB = 0.698,
		message = RESIST .. "! (%s)",
		scrollArea = "Outgoing",
	},
	OUTGOING_SPELL_ABSORB = {
		colorB = 0,
		message = ABSORB .. "! (%s)",
		scrollArea = "Outgoing",
	},
	OUTGOING_SPELL_IMMUNE = {
		colorB = 0,
		message = IMMUNE .. "! (%s)",
		scrollArea = "Outgoing",
	},
	OUTGOING_SPELL_REFLECT = {
		colorB = 0,
		message = REFLECT .. "! (%s)",
		scrollArea = "Outgoing",
	},
	OUTGOING_SPELL_INTERRUPT = {
		colorB = 0,
		message = INTERRUPT .. "! (%s)",
		scrollArea = "Outgoing",
	},
	OUTGOING_SPELL_EVADE = {
		colorG = 0.5,
		colorB = 0,
		message = EVADE .. "! (%s)",
		fontSize = 22,
		scrollArea = "Outgoing",
	},
	OUTGOING_HEAL = {
		colorR = 0,
		colorB = 0,
		message = "+%a (%s - %n)",
		scrollArea = "Outgoing",
	},
	OUTGOING_HEAL_CRIT = {
		colorR = 0,
		colorB = 0,
		message = "+%a (%s - %n)",
		fontSize = 22,
		scrollArea = "Outgoing",
		isCrit = true,
	},
	OUTGOING_HOT = {
		colorR = 0,
		colorB = 0,
		message = "+%a (%s - %n)",
		scrollArea = "Outgoing",
	},
	OUTGOING_HOT_CRIT = {
		colorR = 0,
		colorB = 0,
		message = "+%a (%s - %n)",
		scrollArea = "Outgoing",
		isCrit = true,
	},
	OUTGOING_DISPEL = {
		colorB = 0.5,
		message = L["Dispel"] .. "! (%s)",
		scrollArea = "Outgoing",
	},
	PET_INCOMING_DAMAGE = {
		colorG = 0.41,
		colorB = 0.41,
		message = "(%n) " .. PET .. " -%a",
		scrollArea = "Incoming",
	},
	PET_INCOMING_DAMAGE_CRIT = {
		colorG = 0.41,
		colorB = 0.41,
		message = "(%n) " .. PET .. " -%a",
		scrollArea = "Incoming",
		isCrit = true,
	},
	PET_INCOMING_MISS = {
		colorR = 0.57,
		colorG = 0.58,
		message = PET .. " " .. MISS .. "!",
		scrollArea = "Incoming",
	},
	PET_INCOMING_DODGE = {
		colorR = 0.57,
		colorG = 0.58,
		message = PET .. " " .. DODGE .. "!",
		scrollArea = "Incoming",
	},
	PET_INCOMING_PARRY = {
		colorR = 0.57,
		colorG = 0.58,
		message = PET .. " " .. PARRY .. "!",
		scrollArea = "Incoming",
	},
	PET_INCOMING_BLOCK = {
		colorR = 0.57,
		colorG = 0.58,
		message = PET .. " " .. BLOCK .. "!",
		scrollArea = "Incoming",
	},
	PET_INCOMING_DEFLECT = {
		colorR = 0.57,
		colorG = 0.58,
		message = PET .. " " .. DEFLECT .. "!",
		scrollArea = "Incoming",
	},
	PET_INCOMING_ABSORB = {
		colorB = 0.57,
		message = PET .. " " .. ABSORB .. "!",
		scrollArea = "Incoming",
	},
	PET_INCOMING_IMMUNE = {
		colorB = 0.57,
		message = PET .. " " .. IMMUNE .. "!",
		scrollArea = "Incoming",
	},
	PET_INCOMING_SPELL_DAMAGE = {
		colorG = 0.41,
		colorB = 0.41,
		message = "(%s) " .. PET .. " -%a",
		scrollArea = "Incoming",
	},
	PET_INCOMING_SPELL_DAMAGE_CRIT = {
		colorG = 0.41,
		colorB = 0.41,
		message = "(%s) " .. PET .. " -%a",
		scrollArea = "Incoming",
		isCrit = true,
	},
	PET_INCOMING_SPELL_DAMAGE_SHIELD = {
		colorG = 0.41,
		colorB = 0.41,
		message = "(%s) " .. PET .. " -%a",
		scrollArea = "Incoming",
	},
	PET_INCOMING_SPELL_DAMAGE_SHIELD_CRIT = {
		colorG = 0.41,
		colorB = 0.41,
		message = "(%s) " .. PET .. " -%a",
		scrollArea = "Incoming",
		isCrit = true,
	},
	PET_INCOMING_SPELL_DOT = {
		colorG = 0.41,
		colorB = 0.41,
		message = "(%s) " .. PET .. " -%a",
		scrollArea = "Incoming",
	},
	PET_INCOMING_SPELL_DOT_CRIT = {
		colorG = 0.41,
		colorB = 0.41,
		message = "(%s) " .. PET .. " -%a",
		scrollArea = "Incoming",
		isCrit = true,
	},
	PET_INCOMING_SPELL_MISS = {
		colorR = 0.57,
		colorG = 0.58,
		message = "(%s) " .. PET .. " " .. MISS .. "!",
		scrollArea = "Incoming",
	},
	PET_INCOMING_SPELL_DODGE = {
		colorR = 0.57,
		colorG = 0.58,
		message = "(%s) " .. PET .. " " .. DODGE .. "!",
		scrollArea = "Incoming",
	},
	PET_INCOMING_SPELL_PARRY = {
		colorR = 0.57,
		colorG = 0.58,
		message = "(%s) " .. PET .. " " .. PARRY .. "!",
		scrollArea = "Incoming",
	},
	PET_INCOMING_SPELL_BLOCK = {
		colorR = 0.57,
		colorG = 0.58,
		message = "(%s) " .. PET .. " " .. BLOCK .. "!",
		scrollArea = "Incoming",
	},
	PET_INCOMING_SPELL_DEFLECT = {
		colorR = 0.57,
		colorG = 0.58,
		message = "(%s) " .. PET .. " " .. DEFLECT .. "!",
		scrollArea = "Incoming",
	},
	PET_INCOMING_SPELL_RESIST = {
		colorR = 0.94,
		colorG = 0,
		colorB = 0.94,
		message = "(%s) " .. PET .. " " .. RESIST .. "!",
		scrollArea = "Incoming",
	},
	PET_INCOMING_SPELL_ABSORB = {
		colorB = 0.57,
		message = "(%s) " .. PET .. " " .. ABSORB .. "!",
		scrollArea = "Incoming",
	},
	PET_INCOMING_SPELL_IMMUNE = {
		colorB = 0.57,
		message = "(%s) " .. PET .. " " .. IMMUNE .. "!",
		scrollArea = "Incoming",
	},
	PET_INCOMING_HEAL = {
		colorR = 0.57,
		colorB = 0.57,
		message = "(%s - %n) " .. PET .. " +%a",
		scrollArea = "Incoming",
	},
	PET_INCOMING_HEAL_CRIT = {
		colorR = 0.57,
		colorB = 0.57,
		message = "(%s - %n) " .. PET .. " +%a",
		scrollArea = "Incoming",
		isCrit = true,
	},
	PET_INCOMING_HOT = {
		colorR = 0.57,
		colorB = 0.57,
		message = "(%s - %n) " .. PET .. " +%a",
		scrollArea = "Incoming",
	},
	PET_INCOMING_HOT_CRIT = {
		colorR = 0.57,
		colorB = 0.57,
		message = "(%s - %n) " .. PET .. " +%a",
		scrollArea = "Incoming",
		isCrit = true,
	},
	PET_OUTGOING_DAMAGE = {
		colorG = 0.5,
		colorB = 0,
		message = PET .. " %a",
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_DAMAGE_CRIT = {
		colorG = 0.5,
		colorB = 0,
		message = PET .. " %a",
		scrollArea = "Outgoing",
		isCrit = true,
	},
	PET_OUTGOING_MISS = {
		colorG = 0.5,
		colorB = 0,
		message = PET .. " " .. MISS,
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_DODGE = {
		colorG = 0.5,
		colorB = 0,
		message = PET .. " " .. DODGE,
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_PARRY = {
		colorG = 0.5,
		colorB = 0,
		message = PET .. " " .. PARRY,
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_BLOCK = {
		colorG = 0.5,
		colorB = 0,
		message = PET .. " " .. BLOCK,
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_DEFLECT = {
		colorG = 0.5,
		colorB = 0,
		message = PET .. " " .. DEFLECT,
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_ABSORB = {
		colorR = 0.5,
		colorG = 0.5,
		message = PET .. " " .. ABSORB,
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_IMMUNE = {
		colorR = 0.5,
		colorG = 0.5,
		message = PET .. " " .. IMMUNE,
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_EVADE = {
		colorG = 0.77,
		colorB = 0.57,
		message = PET .. " " .. EVADE,
		fontSize = 22,
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_SPELL_DAMAGE = {
		colorR = 0.33,
		colorG = 0.33,
		message = PET .. " %a (%s)",
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_SPELL_DAMAGE_CRIT = {
		colorR = 0.33,
		colorG = 0.33,
		message = PET .. " %a (%s)",
		scrollArea = "Outgoing",
		isCrit = true,
	},
	PET_OUTGOING_SPELL_DAMAGE_SHIELD = {
		colorR = 0.33,
		colorG = 0.33,
		message = PET .. " %a (%s)",
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_SPELL_DAMAGE_SHIELD_CRIT = {
		colorR = 0.33,
		colorG = 0.33,
		message = PET .. " %a (%s)",
		scrollArea = "Outgoing",
		isCrit = true,
	},
	PET_OUTGOING_SPELL_DOT = {
		colorR = 0.33,
		colorG = 0.33,
		message = PET .. " %a (%s)",
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_SPELL_DOT_CRIT = {
		colorR = 0.33,
		colorG = 0.33,
		message = PET .. " %a (%s)",
		scrollArea = "Outgoing",
		isCrit = true,
	},
	PET_OUTGOING_SPELL_MISS = {
		colorR = 0.33,
		colorG = 0.33,
		message = PET .. " " .. MISS .. "! (%s)",
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_SPELL_DODGE = {
		colorR = 0.33,
		colorG = 0.33,
		message = PET .. " " .. DODGE .. "! (%s)",
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_SPELL_PARRY = {
		colorR = 0.33,
		colorG = 0.33,
		message = PET .. " " .. PARRY .. "! (%s)",
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_SPELL_BLOCK = {
		colorR = 0.33,
		colorG = 0.33,
		message = PET .. " " .. BLOCK .. "! (%s)",
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_SPELL_DEFLECT = {
		colorR = 0.33,
		colorG = 0.33,
		message = PET .. " " .. DEFLECT .. "! (%s)",
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_SPELL_RESIST = {
		colorR = 0.73,
		colorG = 0.73,
		colorB = 0.84,
		message = PET .. " " .. RESIST .. "! (%s)",
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_SPELL_ABSORB = {
		colorR = 0.5,
		colorG = 0.5,
		message = PET .. " " .. ABSORB .. "! (%s)",
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_SPELL_IMMUNE = {
		colorR = 0.5,
		colorG = 0.5,
		message = PET .. " " .. IMMUNE .. "! (%s)",
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_SPELL_EVADE = {
		colorG = 0.77,
		colorB = 0.57,
		message = PET .. " " .. EVADE .. "! (%s)",
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_HEAL = {
		colorR = 0.57,
		colorB = 0.57,
		message = PET .. " " .. "+%a (%s - %n)",
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_HEAL_CRIT = {
		colorR = 0.57,
		colorB = 0.57,
		message = PET .. " " .. "+%a (%s - %n)",
		fontSize = 22,
		scrollArea = "Outgoing",
		isCrit = true,
	},
	PET_OUTGOING_HOT = {
		colorR = 0.57,
		colorB = 0.57,
		message = PET .. " " .. "+%a (%s - %n)",
		scrollArea = "Outgoing",
	},
	PET_OUTGOING_HOT_CRIT = {
		colorR = 0.57,
		colorB = 0.57,
		message = PET .. " " .. "+%a (%s - %n)",
		scrollArea = "Outgoing",
		isCrit = true,
	},
	PET_OUTGOING_DISPEL = {
		colorB = 0.73,
		message = PET .. " " .. L["Dispel"] .. "! (%s)",
		scrollArea = "Outgoing",
	},
	NOTIFICATION_DEBUFF = {
		colorR = 0,
		colorG = 0.5,
		colorB = 0.5,
		message = "[%sl]",
	},
	NOTIFICATION_DEBUFF_STACK = {
		colorR = 0,
		colorG = 0.5,
		colorB = 0.5,
		message = "[%sl %a]",
	},
	NOTIFICATION_BUFF = {
		colorR = 0.698,
		colorG = 0.698,
		colorB = 0,
		message = "[%sl]",
	},
	NOTIFICATION_BUFF_STACK = {
		colorR = 0.698,
		colorG = 0.698,
		colorB = 0,
		message = "[%sl %a]",
	},
	NOTIFICATION_ITEM_BUFF = {
		colorR = 0.698,
		colorG = 0.698,
		colorB = 0.698,
		message = "[%sl]",
	},
	NOTIFICATION_DEBUFF_FADE = {
		colorR = 0,
		colorG = 0.835,
		colorB = 0.835,
		message = "-[%sl]",
	},
	NOTIFICATION_BUFF_FADE = {
		colorR = 0.918,
		colorG = 0.918,
		colorB = 0,
		message = "-[%sl]",
	},
	NOTIFICATION_ITEM_BUFF_FADE = {
		colorR = 0.831,
		colorG = 0.831,
		colorB = 0.831,
		message = "-[%sl]",
	},
	NOTIFICATION_COMBAT_ENTER = {
		message = "+" .. L["Combat"],
	},
	NOTIFICATION_COMBAT_LEAVE = {
		message = "-" .. L["Combat"],
	},
	NOTIFICATION_POWER_GAIN = {
		colorB = 0,
		message = "+%a %p",
	},
	NOTIFICATION_POWER_LOSS = {
		colorB = 0,
		message = "-%a %p",
	},
	NOTIFICATION_CP_GAIN = {
		colorG = 0.5,
		colorB = 0,
		message = "%a " .. L["CP"],
	},
	NOTIFICATION_CP_FULL = {
		colorR = 0.8,
		colorG = 0,
		colorB = 0,
		message = L["Finish It"] .. "!",
		alwaysSticky = true,
		fontSize = 26,
	},
	NOTIFICATION_HONOR_GAIN = {
		colorR = 0.5,
		colorG = 0.5,
		colorB = 0.698,
		message = "+%a " .. HONOR,
	},
	NOTIFICATION_REP_GAIN = {
		colorR = 0.5,
		colorG = 0.5,
		colorB = 0.698,
		message = "+%a " .. REPUTATION .. " (%e)",
	},
	NOTIFICATION_REP_LOSS = {
		colorR = 0.5,
		colorG = 0.5,
		colorB = 0.698,
		message = "-%a " .. REPUTATION .. " (%e)",
	},
	NOTIFICATION_SKILL_GAIN = {
		colorR = 0.333,
		colorG = 0.333,
		message = "%sl: %a",
	},
	NOTIFICATION_EXPERIENCE_GAIN = {
		disabled = true,
		colorR = 0.756,
		colorG = 0.270,
		colorB = 0.823,
		message = "%a " .. XP,
		alwaysSticky = true,
		fontSize = 26,
	},
	NOTIFICATION_PC_KILLING_BLOW = {
		colorR = 0.333,
		colorG = 0.333,
		message = L["Killing Blow"] .. "! (%n)",
		alwaysSticky = true,
		fontSize = 26,
	},
	NOTIFICATION_NPC_KILLING_BLOW = {
		disabled = true,
		colorR = 0.333,
		colorG = 0.333,
		message = L["Killing Blow"] .. "! (%n)",
		alwaysSticky = true,
		fontSize = 26,
	},
	NOTIFICATION_EXTRA_ATTACK = {
		colorB = 0,
		message = "%sl!",
		alwaysSticky = true,
		fontSize = 26,
	},
	NOTIFICATION_ENEMY_BUFF = {
		colorB = 0.5,
		message = "%n: [%sl]",
		scrollArea = "Static",
	},
	NOTIFICATION_MONSTER_EMOTE = {
		colorG = 0.5,
		colorB = 0,
		message = "%e",
		scrollArea = "Static",
	},
	NOTIFICATION_MONEY = {
		message = "+%e",
		scrollArea = "Static",
	},
	NOTIFICATION_COOLDOWN = {
		message = "%e " .. L["Ready Now"] .. "!",
		scrollArea = "Static",
		fontSize = 22,
		soundFile = "MSBT Cooldown",
		skillColorR = 1,
		skillColorG = 0,
		skillColorB = 0,
	},
	NOTIFICATION_PET_COOLDOWN = {
		colorR = 0.57,
		colorG = 0.58,
		message = PET .. " %e " .. L["Ready Now"] .. "!",
		scrollArea = "Static",
		fontSize = 22,
		soundFile = "MSBT Cooldown",
		skillColorR = 1,
		skillColorG = 0.41,
		skillColorB = 0.41,
	},
	NOTIFICATION_ITEM_COOLDOWN = {
		colorR = 0.784,
		colorG = 0.784,
		colorB = 0,
		message = " %e " .. L["Ready Now"] .. "!",
		scrollArea = "Static",
		fontSize = 22,
		soundFile = "MSBT Cooldown",
		skillColorR = 1,
		skillColorG = 0.588,
		skillColorB = 0.588,
	},
	NOTIFICATION_LOOT = {
		colorB = 0,
		message = "+%a %e (%t)",
		scrollArea = "Static",
	},

}

-- Built-in triggers. Spell names come from LibBabble-Spell-2.2 at runtime
-- (Core/Profiles.lua fills `message`, the mainEvents skill names and
-- `iconSkill`), because the triggers must match the client's own spell names.
-- `spell` holds the English base name; a trigger whose spell the library
-- cannot translate is not installed.
profile.triggers = {
	MSBT_TRIGGER_CLEARCASTING = {
		colorB = 0,
		spell = "Clearcasting",
		messageFormat = "%s!",
		alwaysSticky = true,
		fontSize = 26,
		classes = "DRUID,MAGE,SHAMAN",
		mainEventsFormat = "SPELL_AURA_APPLIED{skillName;;eq;;%s;;recipientAffiliation;;eq;;" .. FLAG_YOU .. "}",
	},
	MSBT_TRIGGER_EXECUTE = {
		colorB = 0,
		spell = "Execute",
		messageFormat = "%s!",
		alwaysSticky = true,
		fontSize = 26,
		classes = "WARRIOR",
		mainEvents = "UNIT_HEALTH{unitID;;eq;;target;;threshold;;lt;;20;;unitReaction;;eq;;" .. REACTION_HOSTILE .. "}",
		exceptionsFormat = "unavailableSkill;;eq;;%s",
		iconSkillFormat = "%s",
	},
	MSBT_TRIGGER_HAMMER_OF_WRATH = {
		colorB = 0,
		spell = "Hammer of Wrath",
		messageFormat = "%s!",
		alwaysSticky = true,
		fontSize = 26,
		classes = "PALADIN",
		mainEvents = "UNIT_HEALTH{unitID;;eq;;target;;threshold;;lt;;20;;unitReaction;;eq;;" .. REACTION_HOSTILE .. "}",
		exceptionsFormat = "unavailableSkill;;eq;;%s",
		iconSkillFormat = "%s",
	},
	MSBT_TRIGGER_LOW_HEALTH = {
		colorG = 0.5,
		colorB = 0.5,
		message = L["Low Health"] .. "! (%a)",
		alwaysSticky = true,
		fontSize = 26,
		soundFile = "MSBT Low Health",
		mainEvents = "UNIT_HEALTH{unitID;;eq;;player;;threshold;;lt;;35}",
		exceptions = "recentlyFired;;lt;;5",
		spell = "First Aid",
		iconSkillFormat = "%s",
	},
	MSBT_TRIGGER_LOW_MANA = {
		colorR = 0.5,
		colorG = 0.5,
		message = L["Low Mana"] .. "! (%a)",
		alwaysSticky = true,
		fontSize = 26,
		soundFile = "MSBT Low Mana",
		classes = "DRUID,MAGE,PALADIN,PRIEST,SHAMAN,WARLOCK,HUNTER",
		mainEvents = "UNIT_POWER_UPDATE{powerType;;eq;;0;;unitID;;eq;;player;;threshold;;lt;;35}",
		exceptions = "recentlyFired;;lt;;5",
	},
	MSBT_TRIGGER_LOW_PET_HEALTH = {
		colorG = 0.5,
		colorB = 0.5,
		message = L["Low Pet Health"] .. "! (%a)",
		fontSize = 26,
		classes = "HUNTER,WARLOCK",
		mainEvents = "UNIT_HEALTH{unitID;;eq;;pet;;threshold;;lt;;40}",
		exceptions = "recentlyFired;;lt;;5",
	},
	MSBT_TRIGGER_REVENGE = {
		colorB = 0,
		spell = "Revenge",
		messageFormat = "%s!",
		alwaysSticky = true,
		fontSize = 26,
		classes = "WARRIOR",
		mainEvents = "GENERIC_MISSED{recipientAffiliation;;eq;;" .. FLAG_YOU .. ";;missType;;eq;;BLOCK}&&GENERIC_MISSED{recipientAffiliation;;eq;;" .. FLAG_YOU .. ";;missType;;eq;;DODGE}&&GENERIC_MISSED{recipientAffiliation;;eq;;" .. FLAG_YOU .. ";;missType;;eq;;PARRY}",
		exceptionsFormat = "warriorStance;;ne;;2;;unavailableSkill;;eq;;%s;;recentlyFired;;lt;;2",
		iconSkillFormat = "%s",
	},
	-- The following come from the vanilla MSBT 4.43 default triggers.
	MSBT_TRIGGER_OVERPOWER = {
		colorB = 0,
		spell = "Overpower",
		messageFormat = "%s!",
		alwaysSticky = true,
		fontSize = 26,
		classes = "WARRIOR",
		mainEvents = "GENERIC_MISSED{sourceAffiliation;;eq;;" .. FLAG_YOU .. ";;missType;;eq;;DODGE}",
		exceptionsFormat = "unavailableSkill;;eq;;%s;;recentlyFired;;lt;;2",
		iconSkillFormat = "%s",
	},
	MSBT_TRIGGER_RIPOSTE = {
		colorB = 0,
		spell = "Riposte",
		messageFormat = "%s!",
		alwaysSticky = true,
		fontSize = 26,
		classes = "ROGUE",
		mainEvents = "GENERIC_MISSED{recipientAffiliation;;eq;;" .. FLAG_YOU .. ";;missType;;eq;;PARRY}",
		exceptionsFormat = "unavailableSkill;;eq;;%s;;recentlyFired;;lt;;2",
		iconSkillFormat = "%s",
	},
	MSBT_TRIGGER_COUNTERATTACK = {
		colorB = 0,
		spell = "Counterattack",
		messageFormat = "%s!",
		alwaysSticky = true,
		fontSize = 26,
		classes = "HUNTER",
		mainEvents = "GENERIC_MISSED{recipientAffiliation;;eq;;" .. FLAG_YOU .. ";;missType;;eq;;PARRY}",
		exceptionsFormat = "unavailableSkill;;eq;;%s;;recentlyFired;;lt;;2",
		iconSkillFormat = "%s",
	},
	MSBT_TRIGGER_MONGOOSE_BITE = {
		colorB = 0,
		spell = "Mongoose Bite",
		messageFormat = "%s!",
		alwaysSticky = true,
		fontSize = 26,
		classes = "HUNTER",
		mainEvents = "GENERIC_MISSED{sourceAffiliation;;eq;;" .. FLAG_YOU .. ";;missType;;eq;;DODGE}",
		exceptionsFormat = "unavailableSkill;;eq;;%s;;recentlyFired;;lt;;2",
		iconSkillFormat = "%s",
	},
	MSBT_TRIGGER_NIGHTFALL = {
		colorR = 0.709,
		colorG = 0,
		colorB = 0.709,
		spell = "Shadow Trance",
		messageFormat = "%s!",
		alwaysSticky = true,
		fontSize = 26,
		classes = "WARLOCK",
		mainEventsFormat = "SPELL_AURA_APPLIED{skillName;;eq;;%s;;recipientAffiliation;;eq;;" .. FLAG_YOU .. "}",
	},
}

-- Master font settings.
profile.normalFontName = MikSBT.DEFAULT_FONT_NAME
profile.normalOutlineIndex = 1
profile.normalFontSize = 18
profile.normalFontAlpha = 100
profile.critFontName = MikSBT.DEFAULT_FONT_NAME
profile.critOutlineIndex = 1
profile.critFontSize = 26
profile.critFontAlpha = 100

profile.animationSpeed = 100

-- Partial effect settings.
profile.crushing = { colorR = 0.5, colorG = 0, colorB = 0, trailer = Trailer("CRUSHING_TRAILER", " (crushing)") }
profile.glancing = { colorR = 1, colorG = 0, colorB = 0, trailer = Trailer("GLANCING_TRAILER", " (glancing)") }
profile.absorb = { colorR = 1, colorG = 1, colorB = 0, trailer = Trailer("ABSORB_TRAILER", " (%d absorbed)") }
profile.block = { colorR = 0.5, colorG = 0, colorB = 1, trailer = Trailer("BLOCK_TRAILER", " (%d blocked)") }
profile.resist = { colorR = 0.5, colorG = 0, colorB = 0.5, trailer = Trailer("RESIST_TRAILER", " (%d resisted)") }
profile.vulnerable = { colorR = 1, colorG = 0.5, colorB = 0, trailer = Trailer("VULNERABLE_TRAILER", " (+%d vulnerability bonus)") }
profile.overheal = { colorR = 0, colorG = 0.705, colorB = 0.5, trailer = " <%a>" }

-- Damage color settings (the seven 1.12 schools).
profile.physical = { colorR = 1, colorG = 1, colorB = 1 }
profile.arcane = { colorR = 0.956, colorG = 0.658, colorB = 0.894 }
profile.fire = { colorR = 0.933, colorG = 0.490, colorB = 0.501 }
profile.frost = { colorR = 0.462, colorG = 0.792, colorB = 0.929 }
profile.holy = { colorR = 0.976, colorG = 0.945, colorB = 0.631 }
profile.nature = { colorR = 0.631, colorG = 0.858, colorB = 0.396 }
profile.shadow = { colorR = 0.356, colorG = 0.290, colorB = 0.596 }

-- Class color settings.
profile.DRUID = ClassColor("DRUID", 1, 0.49, 0.04)
profile.HUNTER = ClassColor("HUNTER", 0.67, 0.83, 0.45)
profile.MAGE = ClassColor("MAGE", 0.41, 0.8, 0.94)
profile.PALADIN = ClassColor("PALADIN", 0.96, 0.55, 0.73)
profile.PRIEST = ClassColor("PRIEST", 1, 1, 1)
profile.ROGUE = ClassColor("ROGUE", 1, 0.96, 0.41)
profile.SHAMAN = ClassColor("SHAMAN", 0.96, 0.55, 0.73)
profile.WARLOCK = ClassColor("WARLOCK", 0.58, 0.51, 0.79)
profile.WARRIOR = ClassColor("WARRIOR", 0.78, 0.61, 0.43)

-- Throttle settings. The Vampiric Embrace entry is keyed by the localized
-- name at runtime (Core/Profiles.lua), so only the duration lives here.
profile.dotThrottleDuration = 3
profile.hotThrottleDuration = 3
profile.powerThrottleDuration = 3
profile.throttleList = {}
MikSBT.DEFAULT_THROTTLED_SPELLS = { ["Vampiric Embrace"] = 5 }

-- Spam control settings.
profile.mergeExclusions = {}
profile.abilitySubstitutions = {}
profile.abilitySuppressions = {}
profile.damageThreshold = 0
profile.healThreshold = 0
profile.powerThreshold = 0
profile.hideFullHoTOverheals = true
profile.shortenNumbers = false
profile.shortenNumberPrecision = 0
profile.groupNumbers = false

-- Cooldown settings.
profile.cooldownExclusions = {}
profile.ignoreCooldownThreshold = {}
profile.cooldownThreshold = 5

-- Loot settings. Keys are item quality indices (0 = Poor).
profile.qualityExclusions = { [0] = true }
profile.alwaysShowQuestItems = true
profile.questItemColor = { colorR = 1, colorG = 1, colorB = 0 }
profile.itemsAllowed = {}
profile.itemExclusions = {}

-- Blizzard floating combat damage (the CombatDamage CVar).
profile.enableBlizzardDamage = false
