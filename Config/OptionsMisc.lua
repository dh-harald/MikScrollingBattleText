-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Options - Spam Control, Cooldowns, Loot,
-- Skill Icons, Custom Media and Profiles.
-------------------------------------------------------------------------------

local _G = _G or getfenv()

local module = MikSBT.Config
local O = module.O
local L = MikSBT.L
local Compat = MikSBT.Compat


-------------------------------------------------------------------------------
-- Spam control.
-------------------------------------------------------------------------------

function module.BuildSpamControl()
	local P = O.P
	return {
		type = "group", order = 5, name = L["Spam Control"],
		args = {
			mergeSwings = O.InvToggle(1, L["Merge Swings"], L["Merge melee swings on the same target."], "mergeSwingsDisabled"),
			mergeTrailer = O.InvToggle(2, L["Merge Trailer"], L["Show the number of merged hits and crits."], "hideMergeTrailer"),
			hideFullOverheals = O.Toggle(3, L["Hide Full Overheals"], L["Hide heals that healed nothing."], "hideFullOverheals"),
			hideFullHoTOverheals = O.Toggle(4, L["Hide Full HoT Overheals"], L["Hide heal over time ticks that healed nothing."], "hideFullHoTOverheals"),
			showAllPowerGains = O.Toggle(5, L["Show All Power Gains"], L["Show every power gain, including regeneration, instead of only the ones in the combat log."], "showAllPowerGains"),
			thresholds = {
				type = "group", inline = true, order = 10, name = L["Thresholds"],
				args = {
					damageThreshold = O.Range(1, L["Damage"], L["Minimum damage to show."], "damageThreshold", 0, 5000, 1),
					healThreshold = O.Range(2, L["Healing"], L["Minimum healing to show."], "healThreshold", 0, 5000, 1),
					powerThreshold = O.Range(3, L["Power"], L["Minimum power change to show."], "powerThreshold", 0, 5000, 1),
				},
			},
			throttles = {
				type = "group", inline = true, order = 11, name = L["Throttle Durations"],
				args = {
					dotThrottleDuration = O.Range(1, L["Damage Over Time"], nil, "dotThrottleDuration", 0, 5, 1),
					hotThrottleDuration = O.Range(2, L["Heal Over Time"], nil, "hotThrottleDuration", 0, 5, 1),
					powerThrottleDuration = O.Range(3, L["Power Change"], nil, "powerThrottleDuration", 0, 5, 1),
				},
			},
			throttleList = O.ListEditor(20, L["Throttled Skills"], L["Skills merged over the given number of seconds."],
				function() return P().throttleList end, L["Seconds"], true),
			mergeExclusions = O.ListEditor(21, L["Merge Exclusions"], L["Skills that are never merged."],
				function() return P().mergeExclusions end),
			abilitySuppressions = O.ListEditor(22, L["Skill Suppressions"], L["Skills that are never shown."],
				function() return P().abilitySuppressions end),
			abilitySubstitutions = O.ListEditor(23, L["Skill Substitutions"], L["Skill names replaced with the given text."],
				function() return P().abilitySubstitutions end, L["Replacement"], false),
		},
	}
end


-------------------------------------------------------------------------------
-- Cooldowns.
-------------------------------------------------------------------------------

function module.BuildCooldowns()
	local P = O.P
	local function eventToggle(order, name, key)
		return O.InvToggle(order, name, nil, "disabled", function() return P().events[key] end, O.ApplyCooldowns)
	end
	return {
		type = "group", order = 6, name = L["Cooldowns"],
		args = {
			player = eventToggle(1, L["Skill Cooldowns"], "NOTIFICATION_COOLDOWN"),
			pet = eventToggle(2, L["Pet Skill Cooldowns"], "NOTIFICATION_PET_COOLDOWN"),
			item = eventToggle(3, L["Item Cooldowns"], "NOTIFICATION_ITEM_COOLDOWN"),
			cooldownThreshold = O.Range(4, L["Cooldown Threshold"], L["Only cooldowns at least this long (seconds) are reported."], "cooldownThreshold", 2, 300, 1, nil, O.ApplyCooldowns),
			cooldownExclusions = O.ListEditor(10, L["Cooldown Exclusions"], L["Skills and items whose cooldowns are never reported."],
				function() return P().cooldownExclusions end),
			ignoreCooldownThreshold = O.ListEditor(11, L["Ignore Threshold"], L["Skills and items reported even when their cooldown is below the threshold."],
				function() return P().ignoreCooldownThreshold end),
		},
	}
end


-------------------------------------------------------------------------------
-- Loot.
-------------------------------------------------------------------------------

function module.BuildLoot()
	local P = O.P
	local qualityArgs = {}
	local q
	for q = 0, 5 do
		local quality = q
		local color = ITEM_QUALITY_COLORS and ITEM_QUALITY_COLORS[quality]
		local label = _G["ITEM_QUALITY" .. quality .. "_DESC"] or tostring(quality)
		if color then
			label = MikSBT.Util.ColorText(label, color.r, color.g, color.b)
		end
		qualityArgs["q" .. quality] = {
			type = "toggle", order = quality, name = label,
			get = function() return not P().qualityExclusions[quality] end,
			set = function(info, value) P().qualityExclusions[quality] = (not value) or nil end,
		}
	end
	return {
		type = "group", order = 7, name = L["Loot Alerts"],
		args = {
			loot = O.InvToggle(1, L["Show Looted Items"], nil, "disabled", function() return P().events.NOTIFICATION_LOOT end),
			money = O.InvToggle(2, L["Show Looted Money"], nil, "disabled", function() return P().events.NOTIFICATION_MONEY end),
			alwaysShowQuestItems = O.Toggle(3, L["Always Show Quest Items"], nil, "alwaysShowQuestItems"),
			qualities = { type = "group", inline = true, order = 4, name = L["Shown Item Qualities"], args = qualityArgs },
			questItemColor = {
				type = "group", inline = true, order = 5, name = L["Quest Item Color"],
				args = {
					enabled = O.InvToggle(1, L["Enable"], nil, "disabled", function() return P().questItemColor end),
					color = O.Color(2, L["Color"], function() return P().questItemColor end),
				},
			},
			itemsAllowed = O.ListEditor(10, L["Items Allowed"], L["Items that are always shown."],
				function() return P().itemsAllowed end),
			itemExclusions = O.ListEditor(11, L["Item Exclusions"], L["Items that are never shown."],
				function() return P().itemExclusions end),
		},
	}
end


-------------------------------------------------------------------------------
-- Skill icons.
-------------------------------------------------------------------------------

function module.BuildSkillIcons()
	return {
		type = "group", order = 8, name = L["Skill Icons"],
		args = {
			skillIcons = O.InvToggle(1, L["Show Skill Icons"], L["Show the icon of the skill next to the text."], "skillIconsDisabled"),
			exclusiveSkills = O.InvToggle(2, L["Exclusive Skill Names"], L["Show the skill name only when there is no icon for it."], "exclusiveSkillsDisabled"),
			hideSkills = O.Toggle(3, L["Hide Skill Names"], L["Never show skill names."], "hideSkills"),
		},
	}
end


-------------------------------------------------------------------------------
-- Custom media.
-------------------------------------------------------------------------------

local newFontName, newFontPath, newSoundName, newSoundPath = "", "", "", ""

local function MediaList(args, baseOrder, savedTable, removeFunc)
	local names = {}
	local name
	for name in pairs(savedTable) do
		table.insert(names, name)
	end
	table.sort(names)
	local i
	for i = 1, Compat.getn(names) do
		local entry = names[i]
		args["entry" .. baseOrder .. "_" .. i] = {
			type = "execute", order = baseOrder + i, name = L["Remove"] .. ": " .. entry,
			func = function() removeFunc(entry) module.Rebuild() end,
		}
	end
end

function module.BuildMedia()
	local Media = MikSBT.Media
	local saved = Media.savedMedia or { fonts = {}, sounds = {} }
	local args = {
		desc = { type = "description", order = 1, name = L["Custom fonts and sounds must be inside the Interface folder, for example Interface\\AddOns\\MyMedia\\font.ttf. The Unreal Azeroth client currently renders only the game's own fonts."] },
		fontName = {
			type = "input", order = 2, name = L["Font Name"],
			get = function() return newFontName end, set = function(info, value) newFontName = value end,
		},
		fontPath = {
			type = "input", order = 3, name = L["Font Path"], width = "full",
			get = function() return newFontPath end, set = function(info, value) newFontPath = value end,
		},
		addFont = {
			type = "execute", order = 4, name = L["Add Font"],
			func = function()
				if newFontName ~= "" and newFontPath ~= "" and Media.AddCustomFont(newFontName, newFontPath) then
					newFontName, newFontPath = "", ""
					module.Rebuild()
				end
			end,
		},
		soundName = {
			type = "input", order = 20, name = L["Sound Name"],
			get = function() return newSoundName end, set = function(info, value) newSoundName = value end,
		},
		soundPath = {
			type = "input", order = 21, name = L["Sound Path"], width = "full",
			get = function() return newSoundPath end, set = function(info, value) newSoundPath = value end,
		},
		addSound = {
			type = "execute", order = 22, name = L["Add Sound"],
			func = function()
				if newSoundName ~= "" and newSoundPath ~= "" and Media.AddCustomSound(newSoundName, newSoundPath) then
					newSoundName, newSoundPath = "", ""
					module.Rebuild()
				end
			end,
		},
		testSound = {
			type = "select", dialogControl = "LSM30_Sound", order = 40, name = L["Play Sound"], values = O.SoundValues,
			get = function() return "" end,
			set = function(info, value) if value ~= "" then Media.PlaySound(value) end end,
		},
	}
	MediaList(args, 5, saved.fonts, Media.RemoveCustomFont)
	MediaList(args, 23, saved.sounds, Media.RemoveCustomSound)
	return { type = "group", order = 9, name = L["Custom Media"], args = args }
end


-------------------------------------------------------------------------------
-- Profiles.
-------------------------------------------------------------------------------

-- AceDBOptions-3.0's own table. Its delete and copy selections rely on
-- `confirm`, which LibConfig does not implement, so both setters are wrapped
-- in a confirmation popup.
function module.BuildProfiles()
	local AceDBOptions = LibStub("AceDBOptions-3.0", true)
	if not AceDBOptions or not MikSBT.db then
		return { type = "group", order = -10, name = L["Profiles"], args = {
			desc = { type = "description", order = 1, name = L["AceDBOptions-3.0 is missing."] },
		} }
	end
	-- The args table returned by AceDBOptions is shared with every other addon
	-- using it, so the wrapped entries are copies.
	local source = AceDBOptions:GetOptionsTable(MikSBT.db)
	local profiles = { type = "group", order = -10, name = source.name, desc = source.desc, handler = source.handler, args = {} }
	local key, entry
	for key, entry in pairs(source.args) do
		profiles.args[key] = entry
	end
	local function wrap(name, text)
		local original = profiles.args[name]
		if type(original) ~= "table" then
			return
		end
		local entry = {}
		local k, v
		for k, v in pairs(original) do
			entry[k] = v
		end
		profiles.args[name] = entry
		local handler = profiles.handler
		local originalSet = original.set
		entry.set = function(info, value)
			O.Confirm(string.format(text, tostring(value)), function()
				if type(originalSet) == "function" then
					originalSet(info, value)
				elseif handler and handler[originalSet] then
					handler[originalSet](handler, info, value)
				end
				module.Rebuild()
			end)
		end
		entry.confirm = nil
	end
	wrap("delete", L["Delete the profile '%s'?"])
	wrap("copyfrom", L["Copy the profile '%s' over the current profile?"])
	return profiles
end
