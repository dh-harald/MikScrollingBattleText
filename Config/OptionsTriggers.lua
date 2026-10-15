-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Options - Triggers
--
-- Trigger editor. Triggers are stored in the classic string format
-- ("EVENT{cond;;rel;;value;;...}&&..." and "cond;;rel;;value;;..."); the
-- editor parses it into main events and condition rows, and writes the string
-- back after every change. A raw text field per trigger edits the stored
-- strings directly.
-------------------------------------------------------------------------------

local module = MikSBT.Config
local O = module.O
local L = MikSBT.L
local Compat = MikSBT.Compat
local gmatch = Compat.gmatch
local getn = Compat.getn

local MAIN_EVENTS = {
	GENERIC_DAMAGE = "Damage (any)", GENERIC_MISSED = "Miss (any)",
	SWING_DAMAGE = "Melee Damage", SWING_MISSED = "Melee Miss",
	SPELL_DAMAGE = "Skill Damage", SPELL_PERIODIC_DAMAGE = "Skill Damage Over Time", SPELL_MISSED = "Skill Miss",
	DAMAGE_SHIELD = "Damage Shield", ENVIRONMENTAL_DAMAGE = "Environmental Damage",
	SPELL_HEAL = "Heal", SPELL_PERIODIC_HEAL = "Heal Over Time",
	SPELL_ENERGIZE = "Power Gain", SPELL_DRAIN = "Power Drain", SPELL_LEECH = "Power Leech",
	SPELL_INTERRUPT = "Interrupt", SPELL_DISPEL = "Dispel", SPELL_EXTRA_ATTACKS = "Extra Attacks",
	SPELL_AURA_APPLIED = "Aura Gain", SPELL_AURA_REMOVED = "Aura Fade",
	ENCHANT_APPLIED = "Item Buff Gain", ENCHANT_REMOVED = "Item Buff Fade",
	PARTY_KILL = "Killing Blow", UNIT_DIED = "Unit Death",
	SPELL_CAST_START = "Cast Start", SPELL_CAST_SUCCESS = "Cast Success", SPELL_CAST_FAILED = "Cast Failure",
	UNIT_HEALTH = "Health Change", UNIT_POWER_UPDATE = "Power Change",
	SKILL_COOLDOWN = "Skill Cooldown Complete", PET_COOLDOWN = "Pet Cooldown Complete", ITEM_COOLDOWN = "Item Cooldown Complete",
}

local CONDITIONS = {
	sourceName = "Source Name", sourceAffiliation = "Source Affiliation", sourceReaction = "Source Reaction",
	sourceControl = "Source Control", sourceUnitType = "Source Unit Type",
	recipientName = "Recipient Name", recipientAffiliation = "Recipient Affiliation", recipientReaction = "Recipient Reaction",
	recipientControl = "Recipient Control", recipientUnitType = "Recipient Unit Type",
	skillName = "Skill Name", skillSchool = "Skill School", extraSkillName = "Extra Skill Name",
	amount = "Amount", damageType = "Damage Type", resistAmount = "Resist Amount", blockAmount = "Block Amount",
	absorbAmount = "Absorb Amount", isCrit = "Crit", isGlancing = "Glancing", isCrushing = "Crushing",
	missType = "Miss Type", hazardType = "Hazard Type", powerType = "Power Type", extraAmount = "Extra Amount",
	auraType = "Aura Type", threshold = "Threshold (%)", unitID = "Unit ID", unitReaction = "Unit Reaction",
	itemName = "Item Name",
}

local EXCEPTIONS = {
	buffActive = "Buff Active", buffInactive = "Buff Inactive", currentCP = "Current Combo Points",
	currentPower = "Current Power", inCombat = "In Combat", recentlyFired = "Recently Fired (seconds)",
	unavailableSkill = "Skill Unavailable", warriorStance = "Warrior Stance", zoneName = "Zone Name", zoneType = "Zone Type",
}

local RELATIONS = {
	eq = "Is Equal To", ne = "Is Not Equal To", like = "Contains", unlike = "Does Not Contain",
	lt = "Is Less Than", gt = "Is Greater Than",
}

local VALUE_HELP = "Affiliation: 4026531840 you, 1 mine, 2 party, 4 raid, 8 outsider. Reaction: 16 friendly, 32 neutral, 64 hostile. Control: 256 player, 512 server. Unit type: 1024 player, 2048 NPC, 4096 pet, 8192 guardian. Miss type: MISS, DODGE, PARRY, BLOCK, DEFLECT, RESIST, ABSORB, IMMUNE, EVADE, REFLECT. Aura type: BUFF, DEBUFF. Power type: 0 mana, 1 rage, 2 focus, 3 energy. Unit ID: player, pet, target, party, raid."

local CLASSES = {
	{ "DRUID", "Druid" }, { "HUNTER", "Hunter" }, { "MAGE", "Mage" }, { "PALADIN", "Paladin" }, { "PRIEST", "Priest" },
	{ "ROGUE", "Rogue" }, { "SHAMAN", "Shaman" }, { "WARLOCK", "Warlock" }, { "WARRIOR", "Warrior" },
}

local function Localized(map)
	local values = {}
	local key, label
	for key, label in pairs(map) do
		values[key] = L[label]
	end
	return values
end


-------------------------------------------------------------------------------
-- String format.
-------------------------------------------------------------------------------

local function ParseMainEvents(text)
	local list = {}
	local mainEvent, conditionsString
	for mainEvent, conditionsString in gmatch((text or "") .. "&&", "(.-)%{(.-)%}&&") do
		local entry = { event = mainEvent, conditions = {} }
		local value
		if conditionsString ~= "" then
			for value in gmatch(conditionsString .. ";;", "(.-);;") do
				table.insert(entry.conditions, value)
			end
		end
		table.insert(list, entry)
	end
	return list
end

local function SerializeMainEvents(list)
	local parts = {}
	local i
	for i = 1, getn(list) do
		table.insert(parts, list[i].event .. "{" .. table.concat(list[i].conditions, ";;") .. "}")
	end
	return table.concat(parts, "&&")
end

local function ParseExceptions(text)
	local list = {}
	local value
	if text and text ~= "" then
		for value in gmatch(text .. ";;", "(.-);;") do
			table.insert(list, value)
		end
	end
	return list
end


-------------------------------------------------------------------------------
-- Pages.
-------------------------------------------------------------------------------

local newTriggerName = ""

-- Rows of condition triplets stored in `list` (a flat array), written back
-- through `save`.
local function ConditionRows(args, baseOrder, list, names, save)
	local count = math.floor(getn(list) / 3)
	local row
	for row = 1, count do
		local index = (row - 1) * 3
		args["cond" .. baseOrder .. "_" .. row] = {
			type = "group", inline = true, order = baseOrder + row, name = "",
			args = {
				condition = {
					type = "select", order = 1, name = L["Condition"], values = function() return Localized(names) end,
					get = function() return list[index + 1] end,
					set = function(info, value) list[index + 1] = value save() end,
				},
				relation = {
					type = "select", order = 2, name = L["Relation"], values = function() return Localized(RELATIONS) end,
					get = function() return list[index + 2] end,
					set = function(info, value) list[index + 2] = value save() end,
				},
				value = {
					type = "input", order = 3, name = L["Value"], desc = L[VALUE_HELP],
					get = function() return list[index + 3] or "" end,
					set = function(info, value) list[index + 3] = value save() end,
				},
				remove = {
					type = "execute", order = 4, name = L["Remove"],
					func = function()
						table.remove(list, index + 1)
						table.remove(list, index + 1)
						table.remove(list, index + 1)
						save(true)
					end,
				},
			},
		}
	end
	args["addCond" .. baseOrder] = {
		type = "execute", order = baseOrder + count + 1, name = L["Add Condition"],
		func = function()
			local first = next(names)
			table.insert(list, first)
			table.insert(list, "eq")
			table.insert(list, "")
			save(true)
		end,
	}
end

local function TriggerPage(key, order)
	local getter = function() return O.P().triggers[key] end
	local page = { type = "group", order = order, args = {} }
	page.name = function()
		local settings = getter()
		return (type(settings) == "table" and settings.message and settings.message ~= "" and settings.message) or key
	end

	local function build()
		local settings = getter()
		if type(settings) ~= "table" then
			page.args = {}
			return
		end
		local mainEvents = ParseMainEvents(settings.mainEvents)
		local exceptions = ParseExceptions(settings.exceptions)
		local args = {}
		page.args = args

		local function saveMain(structural)
			settings.mainEvents = SerializeMainEvents(mainEvents)
			O.ApplyTriggers()
			if structural then build() module.NotifyChange() end
		end
		local function saveExceptions(structural)
			settings.exceptions = table.concat(exceptions, ";;")
			O.ApplyTriggers()
			if structural then build() module.NotifyChange() end
		end

		args.enabled = O.InvToggle(1, L["Enable"], nil, "disabled", getter, O.ApplyTriggers)
		args.message = {
			type = "input", order = 2, name = L["Message"], width = "full",
			desc = L["%n source, %r recipient, %s skill, %e extra skill, %a amount."],
			get = function() return settings.message or "" end,
			set = function(info, value) settings.message = value module.NotifyChange() end,
		}
		args.color = O.Color(3, L["Color"], getter)
		args.scrollArea = {
			type = "select", order = 4, name = L["Scroll Area"], values = O.ScrollAreaValues,
			get = function() return settings.scrollArea or MikSBT.DEFAULT_SCROLL_AREA end,
			set = function(info, value) settings.scrollArea = value end,
		}
		args.alwaysSticky = O.Toggle(5, L["Always Sticky"], nil, "alwaysSticky", getter)
		args.soundFile = {
			type = "select", dialogControl = "LSM30_Sound", order = 6, name = L["Sound"], values = O.SoundValues,
			get = function() return settings.soundFile or "" end,
			set = function(info, value)
				if value == "" then value = false end
				settings.soundFile = value
				if value then MikSBT.Media.PlaySound(value) end
			end,
		}
		args.iconSkill = {
			type = "input", order = 7, name = L["Icon Skill"], desc = L["Name of the skill whose icon is shown (%s and %e allowed)."],
			get = function() return settings.iconSkill or "" end,
			set = function(info, value) settings.iconSkill = (value ~= "") and value or false end,
		}
		args.font = O.FontGroup(8, L["Font"], getter, "", true)

		local classArgs = {}
		local i
		for i = 1, getn(CLASSES) do
			local token, label = CLASSES[i][1], CLASSES[i][2]
			classArgs[token] = {
				type = "toggle", order = i, name = L[label],
				get = function()
					return not settings.classes or settings.classes == "" or string.find(settings.classes, token, 1, true) and true or false
				end,
				set = function(info, value)
					local selected = {}
					local j
					for j = 1, getn(CLASSES) do
						local t = CLASSES[j][1]
						local on
						if t == token then
							on = value
						else
							on = not settings.classes or settings.classes == "" or string.find(settings.classes, t, 1, true)
						end
						if on then table.insert(selected, t) end
					end
					settings.classes = (getn(selected) < getn(CLASSES)) and table.concat(selected, ",") or false
					O.ApplyTriggers()
				end,
			}
		end
		args.classes = { type = "group", inline = true, order = 10, name = L["Classes"], args = classArgs }

		local m
		for m = 1, getn(mainEvents) do
			local entry = mainEvents[m]
			local eventArgs = {
				event = {
					type = "select", order = 1, name = L["Main Event"], values = function() return Localized(MAIN_EVENTS) end,
					get = function() return entry.event end,
					set = function(info, value) entry.event = value saveMain() end,
				},
				removeEvent = {
					type = "execute", order = 2, name = L["Remove Main Event"],
					func = function() table.remove(mainEvents, m) saveMain(true) end,
				},
			}
			ConditionRows(eventArgs, 10, entry.conditions, CONDITIONS, saveMain)
			args["main" .. m] = {
				type = "group", inline = true, order = 20 + m,
				name = string.format(L["Main Event %d"], m), args = eventArgs,
			}
		end
		args.addMain = {
			type = "execute", order = 60, name = L["Add Main Event"],
			func = function()
				table.insert(mainEvents, { event = "GENERIC_DAMAGE", conditions = {} })
				saveMain(true)
			end,
		}

		local exceptionArgs = {}
		ConditionRows(exceptionArgs, 0, exceptions, EXCEPTIONS, saveExceptions)
		args.exceptions = { type = "group", inline = true, order = 70, name = L["Exceptions"], args = exceptionArgs }

		args.raw = {
			type = "group", inline = true, order = 80, name = L["Raw Settings"],
			args = {
				mainEvents = {
					type = "input", order = 1, name = L["Main Events"], width = "full", multiline = 3,
					get = function() return settings.mainEvents or "" end,
					set = function(info, value) settings.mainEvents = value O.ApplyTriggers() build() module.NotifyChange() end,
				},
				exceptions = {
					type = "input", order = 2, name = L["Exceptions"], width = "full", multiline = 2,
					get = function() return settings.exceptions or "" end,
					set = function(info, value) settings.exceptions = value O.ApplyTriggers() build() module.NotifyChange() end,
				},
			},
		}
		args.delete = {
			type = "execute", order = 90, name = L["Delete Trigger"],
			func = function()
				O.Confirm(L["Delete this trigger?"], function()
					if MikSBT.Defaults.profile.triggers[key] then
						O.P().triggers[key] = false
					else
						O.P().triggers[key] = nil
					end
					O.ApplyTriggers()
					module.Rebuild()
				end)
			end,
		}
	end
	build()
	return page
end

function module.BuildTriggers()
	local group = {
		type = "group", order = 4, name = L["Triggers"],
		args = {
			desc = { type = "description", order = 1, name = L["Triggers show a message when their main event happens and all of its conditions are true, unless an exception applies."] },
			newName = {
				type = "input", order = 2, name = L["New Trigger Message"],
				get = function() return newTriggerName end,
				set = function(info, value) newTriggerName = value end,
			},
			add = {
				type = "execute", order = 3, name = L["Add Trigger"],
				func = function()
					if newTriggerName == "" then return end
					local n = 1
					while O.P().triggers["MSBT_CUSTOM_TRIGGER_" .. n] ~= nil do n = n + 1 end
					O.P().triggers["MSBT_CUSTOM_TRIGGER_" .. n] = {
						message = newTriggerName, alwaysSticky = true, fontSize = 26,
						mainEvents = "SPELL_AURA_APPLIED{skillName;;eq;;;;recipientAffiliation;;eq;;" .. MikSBT.Triggers.FLAG_YOU .. "}",
					}
					newTriggerName = ""
					O.ApplyTriggers()
					module.Rebuild()
				end,
			},
			restore = {
				type = "execute", order = 4, name = L["Restore Default Triggers"],
				func = function()
					O.Confirm(L["Restore the deleted default triggers?"], function()
						local key, value
						for key, value in pairs(O.P().triggers) do
							if value == false then O.P().triggers[key] = nil end
						end
						O.ApplyTriggers()
						module.Rebuild()
					end)
				end,
			},
		},
	}
	local keys = {}
	local key, settings
	for key, settings in pairs(O.P().triggers) do
		if type(settings) == "table" then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	local i
	for i = 1, getn(keys) do
		group.args["trigger_" .. keys[i]] = TriggerPage(keys[i], 10 + i)
	end
	return group
end
