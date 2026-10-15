-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Icons
--
-- The 1.12 client has no spell-name-to-icon API, so skill icons come from a
-- chain of providers, first hit wins:
--   1. the player's and the pet's spellbook (GetSpellName / GetSpellTexture),
--   2. LibBabble-Spell-2.2's icon table (also covers other units' spells),
--   3. the player's current buffs and debuffs (tooltip name -> texture),
--   4. the textures learned from item lines (loot, item cooldowns).
-- Results, including misses, are cached per name.
-------------------------------------------------------------------------------

local _G = _G or getfenv()

local module = MikSBT:NewModule("Icons", "AceEvent-3.0")
MikSBT.Icons = module

local Compat = MikSBT.Compat
local Util = MikSBT.Util

-- Seconds a failed lookup is remembered before the buff scan is tried again.
local MISS_RETRY_TIME = 10

local spellbookIcons = {}
local learnedIcons = {}
local missTimes = {}

local scanTooltip

local function GetScanTooltip()
	if not scanTooltip then
		scanTooltip = CreateFrame("GameTooltip", "MSBTIconScanTooltip", nil, "GameTooltipTemplate")
		scanTooltip:SetOwner(UIParent, "ANCHOR_NONE")
	end
	return scanTooltip
end

local function ScanBook(bookType)
	local i = 1
	while true do
		local name = GetSpellName(i, bookType)
		if not name then
			break
		end
		if not spellbookIcons[name] then
			local texture = GetSpellTexture(i, bookType)
			if texture then
				spellbookIcons[name] = texture
			end
		end
		i = i + 1
	end
end

local function RebuildSpellbook()
	Compat.wipe(spellbookIcons)
	Compat.wipe(missTimes)
	pcall(ScanBook, "spell")
	if UnitExists("pet") then
		pcall(ScanBook, "pet")
	end
end
module.RebuildSpellbook = RebuildSpellbook

-- Buff and debuff textures of the player, keyed by the tooltip name.
local function ScanAurasWith(tooltip, wanted)
	local _, filter, i
	for _, filter in ipairs({ "HELPFUL", "HARMFUL" }) do
		for i = 0, 31 do
			local index = GetPlayerBuff(i, filter)
			if not index or index < 0 then
				break
			end
			tooltip:SetOwner(UIParent, "ANCHOR_NONE")
			tooltip:ClearLines()
			tooltip:SetPlayerBuff(index)
			local line = _G["MSBTIconScanTooltipTextLeft1"]
			local name = line and line:GetText()
			local texture = GetPlayerBuffTexture(index)
			if name and texture then
				learnedIcons[name] = texture
				if name == wanted then
					return texture
				end
			end
		end
	end
end

-- SetPlayerBuff shows the scan tooltip, and with ANCHOR_NONE it stays drawn
-- at the bottom-left screen corner, so it is hidden after every scan. Hiding
-- drops its owner; ScanAurasWith sets the owner again before each fill. The
-- scan is pcall'd so the tooltip is hidden even when a Set call errors.
local function ScanPlayerAuras(wanted)
	local tooltip = GetScanTooltip()
	local ok, texture = pcall(ScanAurasWith, tooltip, wanted)
	tooltip:Hide()
	if ok then
		return texture
	end
end

-- Remembers an icon from another source (item links, cooldown scans).
function module.Learn(name, texture)
	if name and texture then
		learnedIcons[name] = texture
		missTimes[name] = nil
	end
end

-- Icon texture path for a skill, buff or item name, or nil.
function module.GetSkillIcon(name)
	if not name or name == "" then
		return nil
	end
	local texture = spellbookIcons[name] or learnedIcons[name]
	if texture then
		return texture
	end

	local now = GetTime()
	if missTimes[name] and now - missTimes[name] < MISS_RETRY_TIME then
		return nil
	end

	local BS = LibStub("LibBabble-Spell-2.2", true)
	if BS then
		local ok, icon = pcall(BS.GetSpellIcon, BS, name)
		if ok and icon then
			learnedIcons[name] = icon
			return icon
		end
	end

	local ok, found = pcall(ScanPlayerAuras, name)
	if ok and found then
		return found
	end

	missTimes[name] = now
	return nil
end

-- Texture of an item from its link or "item:" string (9th GetItemInfo return
-- on the 1.12 client).
function module.GetItemIcon(itemLink)
	if not itemLink then
		return nil
	end
	local itemString = Compat.match(itemLink, "(item:%d+:%d+:%d+:%d+)") or Compat.match(itemLink, "(item:%d+)")
	if not itemString then
		return nil
	end
	local name, _, _, _, _, _, _, _, texture = GetItemInfo(itemString)
	if name and texture then
		learnedIcons[name] = texture
	end
	return texture
end


local gameEventHandlers = {
	SPELLS_CHANGED = RebuildSpellbook,
	LEARNED_SPELL_IN_TAB = RebuildSpellbook,
	UNIT_PET = function(unit) if unit == "player" then RebuildSpellbook() end end,
}

function module:OnEnable()
	RebuildSpellbook()
	Util.RegisterEvents(self, gameEventHandlers)
end
