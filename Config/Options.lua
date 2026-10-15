-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Options
--
-- LibConfig-1.0 options tree. LibConfig renders an AceConfig-format table in
-- its own window (the native Interface Options, AceGUI and AceConfigDialog do
-- not work on Unreal Azeroth). Non-inline groups become pages in the sidebar.
--
-- Rules:
--   * option keys are the profile keys, read and written through group-level
--     get/set where possible;
--   * classic "...Disabled" flags are shown as positive checkboxes;
--   * a font/size override stored as false means "inherit" (AceDB keeps a
--     false value, while nil would fall back to the built-in default);
--   * destructive buttons ask through a StaticPopup, because LibConfig does
--     not implement `confirm`;
--   * lists that change (scroll areas, triggers, item lists) are rebuilt by
--     Config.Rebuild() and redrawn with NotifyChange.
-------------------------------------------------------------------------------

local _G = _G or getfenv()

local module = {}
MikSBT.Config = module

local L = MikSBT.L
local Compat = MikSBT.Compat
local Util = MikSBT.Util

local APP_NAME = "MikScrollingBattleText"

-- Shared option builders, also used by the other Config files.
local O = {}
module.O = O

local options
local initialized = false


-------------------------------------------------------------------------------
-- Accessors.
-------------------------------------------------------------------------------

function O.P()
	return MikSBT.Profiles.currentProfile
end

function O.Last(info)
	return info[Compat.getn(info)]
end

-- Applies changes that affect the display.
function O.ApplyDisplay()
	MikSBT.Animations.UpdateScrollAreas()
	if MikSBT.Movers then MikSBT.Movers.Refresh() end
end

function O.ApplyTriggers()
	MikSBT.Triggers.UpdateTriggers()
end

function O.ApplyCooldowns()
	MikSBT.Cooldowns.UpdateRegisteredEvents()
end


-------------------------------------------------------------------------------
-- Confirmation popup.
-------------------------------------------------------------------------------

local pendingAccept

StaticPopupDialogs["MSBT_CONFIRM"] = {
	text = "%s",
	button1 = _G.ACCEPT or "Accept",
	button2 = _G.CANCEL or "Cancel",
	OnAccept = function()
		local callback = pendingAccept
		pendingAccept = nil
		if callback then
			callback()
		end
	end,
	OnCancel = function()
		pendingAccept = nil
	end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
}

function O.Confirm(text, callback)
	pendingAccept = callback
	StaticPopup_Show("MSBT_CONFIRM", text)
end


-------------------------------------------------------------------------------
-- Value lists.
-------------------------------------------------------------------------------

function O.FontValues()
	local values = {}
	local name
	for name in MikSBT.Media.IterateFonts() do
		values[name] = name
	end
	return values
end

-- Fonts with an extra "inherit" entry (stored as false).
function O.FontValuesInherit()
	local values = O.FontValues()
	values[""] = L["Inherit"]
	return values
end

function O.SoundValues()
	local values = { [""] = L["None"] }
	local name
	for name in MikSBT.Media.IterateSounds() do
		values[name] = name
	end
	return values
end

function O.OutlineValues(withInherit)
	local values = {
		[1] = L["None"], [2] = L["Thin"], [3] = L["Thick"],
		[4] = L["Monochrome"], [5] = L["Monochrome Thin"], [6] = L["Monochrome Thick"],
	}
	if withInherit then values[0] = L["Inherit"] end
	return values
end

function O.AlignValues()
	return { [1] = L["Left"], [2] = L["Center"], [3] = L["Right"] }
end

-- Scroll area anchor points (MikSBT.Animations scroll area anchoring).
function O.AnchorPointValues()
	return {
		CENTER = L["Center"],
		TOPLEFT = L["Top Left"], TOP = L["Top"], TOPRIGHT = L["Top Right"],
		BOTTOMLEFT = L["Bottom Left"], BOTTOM = L["Bottom"], BOTTOMRIGHT = L["Bottom Right"],
	}
end

function O.ScrollAreaValues()
	local values = {}
	local key, settings
	for key, settings in pairs(O.P().scrollAreas) do
		if type(settings) == "table" then
			values[key] = settings.name or key
		end
	end
	return values
end

local STYLE_WORDS = {
	Straight = "Straight", Parabola = "Parabola", Angled = "Angled", Horizontal = "Horizontal",
	Static = "Static", Pow = "Pow", Up = "Up", Down = "Down", Left = "Left", Right = "Right",
	Alternate = "Alternate", CurvedLeft = "Curved Left", CurvedRight = "Curved Right",
	AngleUp = "Angle Up", AngleDown = "Angle Down", GrowUp = "Grow Up", GrowDown = "Grow Down",
	Normal = "Normal", Jiggle = "Jiggle",
}

function O.StyleLabel(word)
	return L[STYLE_WORDS[word] or word]
end

function O.StyleValues(sticky)
	local styles = sticky and MikSBT.Animations.stickyAnimationStyles or MikSBT.Animations.animationStyles
	local values = {}
	local styleID
	for styleID in pairs(styles) do
		values[styleID] = O.StyleLabel(styleID)
	end
	return values
end

-- Directions or behaviors a style offers ("Up;Down").
function O.StyleOptionValues(sticky, styleID, field)
	local styles = sticky and MikSBT.Animations.stickyAnimationStyles or MikSBT.Animations.animationStyles
	local style = styles[styleID]
	local values = {}
	if style and style[field] then
		local _, word
		for _, word in ipairs(Compat.split(style[field], ";")) do
			values[word] = O.StyleLabel(word)
		end
	end
	return values
end


-------------------------------------------------------------------------------
-- Generic option makers.
-------------------------------------------------------------------------------

-- Positive checkbox for a classic "...Disabled" flag in tableGetter().
function O.InvToggle(order, name, desc, key, tableGetter, onSet)
	return {
		type = "toggle", order = order, name = name, desc = desc,
		get = function() return not (tableGetter or O.P)()[key] end,
		set = function(info, value)
			(tableGetter or O.P)()[key] = not value
			if onSet then onSet() end
		end,
	}
end

function O.Toggle(order, name, desc, key, tableGetter, onSet)
	return {
		type = "toggle", order = order, name = name, desc = desc,
		get = function() return (tableGetter or O.P)()[key] and true or false end,
		set = function(info, value)
			(tableGetter or O.P)()[key] = value and true or false
			if onSet then onSet() end
		end,
	}
end

function O.Range(order, name, desc, key, minValue, maxValue, step, tableGetter, onSet)
	return {
		type = "range", order = order, name = name, desc = desc, min = minValue, max = maxValue, step = step,
		get = function() return (tableGetter or O.P)()[key] or minValue end,
		set = function(info, value)
			(tableGetter or O.P)()[key] = value
			if onSet then onSet() end
		end,
	}
end

-- Color of a settings table with colorR/colorG/colorB (defaults 1).
function O.Color(order, name, tableGetter, prefix, onSet)
	prefix = prefix or "color"
	return {
		type = "color", order = order, name = name,
		get = function()
			local t = tableGetter()
			return t[prefix .. "R"] or 1, t[prefix .. "G"] or 1, t[prefix .. "B"] or 1, 1
		end,
		set = function(info, r, g, b)
			local t = tableGetter()
			t[prefix .. "R"], t[prefix .. "G"], t[prefix .. "B"] = r, g, b
			if onSet then onSet() end
		end,
	}
end

-- Font name / size / outline / alpha settings on tableGetter() with a field
-- prefix ("normal", "crit" or "" for events). With `inherit`, each value
-- can fall back to the next level (stored as false).
function O.FontGroup(order, name, tableGetter, prefix, inherit, onSet)
	local function field(suffix)
		if prefix == "" then
			return string.lower(string.sub(suffix, 1, 1)) .. string.sub(suffix, 2)
		end
		return prefix .. suffix
	end
	local nameKey, sizeKey, outlineKey, alphaKey = field("FontName"), field("FontSize"), field("OutlineIndex"), field("FontAlpha")
	local function store(key, value)
		tableGetter()[key] = value
		if onSet then onSet() end
	end
	local group = {
		type = "group", inline = true, order = order, name = name,
		args = {
			fontName = {
				type = "select", order = 1, name = L["Font"], dialogControl = "LSM30_Font",
				values = inherit and O.FontValuesInherit or O.FontValues,
				get = function() return tableGetter()[nameKey] or (inherit and "" or MikSBT.DEFAULT_FONT_NAME) end,
				set = function(info, value)
					if value == "" then value = false end
					store(nameKey, value)
					if value then MikSBT.Animations.LoadFont(value) end
				end,
			},
			outlineIndex = {
				type = "select", order = 2, name = L["Outline"],
				values = function() return O.OutlineValues(inherit) end,
				get = function() return tableGetter()[outlineKey] or (inherit and 0 or 1) end,
				set = function(info, value)
					if value == 0 then value = false end
					store(outlineKey, value)
				end,
			},
			fontSize = {
				type = "range", order = 3, name = L["Font Size"], min = 4, max = 38, step = 1,
				disabled = function() return inherit and not tableGetter()[sizeKey] end,
				get = function() return tableGetter()[sizeKey] or 18 end,
				set = function(info, value) store(sizeKey, value) end,
			},
			fontAlpha = {
				type = "range", order = 5, name = L["Opacity"], min = 1, max = 100, step = 1,
				disabled = function() return inherit and not tableGetter()[alphaKey] end,
				get = function() return tableGetter()[alphaKey] or 100 end,
				set = function(info, value) store(alphaKey, value) end,
			},
		},
	}
	if inherit then
		group.args.inheritSize = {
			type = "toggle", order = 4, name = L["Inherit Font Size"],
			get = function() return not tableGetter()[sizeKey] end,
			set = function(info, value) store(sizeKey, (not value) and 18 or false) end,
		}
		group.args.inheritAlpha = {
			type = "toggle", order = 6, name = L["Inherit Opacity"],
			get = function() return not tableGetter()[alphaKey] end,
			set = function(info, value) store(alphaKey, (not value) and 100 or false) end,
		}
	end
	return group
end

-- Editor for a name-keyed profile table (item lists, suppressions, ...).
-- `valueName` adds a value field (seconds, replacement text) per entry.
function O.ListEditor(order, name, desc, tableGetter, valueName, valueIsNumber, onChange)
	local newName, newValue = "", ""
	local group = { type = "group", order = order, name = name, args = {} }
	local function rebuild()
		local args = {}
		group.args = args
		args.desc = { type = "description", order = 1, name = desc }
		args.newName = {
			type = "input", order = 2, name = L["Name"], width = valueName and nil or "full",
			get = function() return newName end,
			set = function(info, value) newName = value end,
		}
		if valueName then
			args.newValue = {
				type = "input", order = 3, name = valueName,
				get = function() return newValue end,
				set = function(info, value) newValue = value end,
			}
		end
		args.add = {
			type = "execute", order = 4, name = L["Add"],
			func = function()
				if newName == "" then return end
				local value = true
				if valueName then
					value = valueIsNumber and tonumber(newValue) or newValue
					if value == nil or value == "" then return end
				end
				tableGetter()[newName] = value
				newName, newValue = "", ""
				rebuild()
				if onChange then onChange() end
				module.NotifyChange()
			end,
		}
		local entries = {}
		local key
		for key in pairs(tableGetter()) do
			table.insert(entries, key)
		end
		table.sort(entries, function(a, b) return tostring(a) < tostring(b) end)
		local i
		for i = 1, Compat.getn(entries) do
			local entryKey = entries[i]
			local value = tableGetter()[entryKey]
			local label = tostring(entryKey)
			if valueName then label = label .. "  |cffffd100" .. tostring(value) .. "|r" end
			args["entry" .. i] = {
				type = "execute", order = 10 + i, name = L["Remove"] .. ": " .. label,
				func = function()
					tableGetter()[entryKey] = nil
					rebuild()
					if onChange then onChange() end
					module.NotifyChange()
				end,
			}
		end
	end
	rebuild()
	group.rebuild = rebuild
	return group
end


-------------------------------------------------------------------------------
-- Root page.
-------------------------------------------------------------------------------

local function BuildRoot()
	return {
		header = { type = "header", order = 1, name = "MikScrollingBattleText " .. MikSBT.VERSION_STRING },
		desc = { type = "description", order = 2, name = L["Scrolling combat text for the 1.12.1 client and Unreal Azeroth. Choose a page on the left."] },
		move = {
			type = "execute", order = 3, name = L["Move Scroll Areas"],
			func = function() MikSBT.Movers.Unlock() end,
		},
		test = {
			type = "execute", order = 4, name = L["Test Display"],
			func = function() MikSBT.Commands.RunTest() end,
		},
	}
end


-------------------------------------------------------------------------------
-- General.
-------------------------------------------------------------------------------

local function PartialEffectGroup(order, key, name)
	local getter = function() return O.P()[key] end
	return {
		type = "group", inline = true, order = order, name = name,
		args = {
			enabled = O.InvToggle(1, L["Enable"], nil, "disabled", getter),
			color = O.Color(2, L["Color"], getter),
			trailer = {
				type = "input", order = 3, name = L["Trailer"],
				desc = L["Text appended to the event. %a is the amount."],
				get = function() return getter().trailer or "" end,
				set = function(info, value) getter().trailer = value end,
			},
		},
	}
end

local function ColorsGroup(order, name, keys, labels, flagKey, flagName)
	local group = { type = "group", order = order, name = name, args = {} }
	group.args.enabled = O.InvToggle(1, flagName, nil, flagKey)
	local i
	for i = 1, Compat.getn(keys) do
		local key = keys[i]
		group.args[key] = {
			type = "group", inline = true, order = 10 + i, name = labels[i],
			args = {
				enabled = O.InvToggle(1, L["Enable"], nil, "disabled", function() return O.P()[key] end),
				color = O.Color(2, L["Color"], function() return O.P()[key] end),
			},
		}
	end
	return group
end

local function BuildGeneral()
	local classKeys = { "DRUID", "HUNTER", "MAGE", "PALADIN", "PRIEST", "ROGUE", "SHAMAN", "WARLOCK", "WARRIOR" }
	local classLabels = { L["Druid"], L["Hunter"], L["Mage"], L["Paladin"], L["Priest"], L["Rogue"], L["Shaman"], L["Warlock"], L["Warrior"] }
	local i
	local schoolKeys = { "physical", "holy", "fire", "nature", "frost", "shadow", "arcane" }
	local schoolLabels = {}
	for i = 0, 6 do
		schoolLabels[i + 1] = _G["SPELL_SCHOOL" .. i .. "_CAP"] or schoolKeys[i + 1]
	end

	return {
		type = "group", order = 1, name = L["General"],
		args = {
			enableMod = {
				type = "toggle", order = 1, name = L["Enable Mik's Scrolling Battle Text"],
				get = function() return not MikSBT.Profiles.IsModDisabled() end,
				set = function(info, value) MikSBT.Profiles.SetOptionUserDisabled(not value) end,
			},
			stickyCrits = O.InvToggle(2, L["Sticky Crits"], L["Display crits using the sticky style."], "stickyCritsDisabled"),
			sounds = O.InvToggle(3, L["Enable Sounds"], L["Play sounds that are assigned to events and triggers."], "soundsDisabled"),
			textShadowing = O.InvToggle(4, L["Text Shadowing"], L["Apply a shadow effect to the text."], "textShadowingDisabled"),
			blizzardDamage = O.Toggle(5, L["Blizzard Damage"], L["Show the game's own damage numbers over the target."], "enableBlizzardDamage", nil, MikSBT.Profiles.ApplyBlizzardDamage),
			hideNames = O.Toggle(6, L["Hide Names"], L["Hide unit names in events."], "hideNames"),
			abbreviate = O.Toggle(7, L["Abbreviate Skills"], L["Abbreviate skill names (English clients only)."], "abbreviateAbilities"),
			shortenNumbers = O.Toggle(8, L["Shorten Numbers"], L["Show large numbers with k/M suffixes."], "shortenNumbers"),
			shortenNumberPrecision = O.Range(9, L["Shorten Precision"], nil, "shortenNumberPrecision", 0, 3, 1),
			groupNumbers = O.Toggle(10, L["Group Numbers"], L["Separate digits into groups of three."], "groupNumbers"),
			animationSpeed = O.Range(11, L["Animation Speed"], L["Percentage of the normal animation speed."], "animationSpeed", 20, 250, 1),
			masterFonts = {
				type = "group", order = 20, name = L["Master Fonts"],
				args = {
					normal = O.FontGroup(1, L["Normal"], O.P, "normal", false),
					crit = O.FontGroup(2, L["Crit"], O.P, "crit", false),
				},
			},
			partialEffects = {
				type = "group", order = 21, name = L["Partial Effects"],
				args = {
					coloring = O.InvToggle(1, L["Color Partial Effects"], nil, "partialColoringDisabled"),
					crushing = PartialEffectGroup(2, "crushing", L["Crushing Blows"]),
					glancing = PartialEffectGroup(3, "glancing", L["Glancing Hits"]),
					absorb = PartialEffectGroup(4, "absorb", L["Partial Absorbs"]),
					block = PartialEffectGroup(5, "block", L["Partial Blocks"]),
					resist = PartialEffectGroup(6, "resist", L["Partial Resists"]),
					vulnerable = PartialEffectGroup(7, "vulnerable", L["Vulnerability Bonuses"]),
					overheal = PartialEffectGroup(8, "overheal", L["Overheals"]),
				},
			},
			damageColors = ColorsGroup(22, L["Damage Colors"], schoolKeys, schoolLabels, "damageColoringDisabled", L["Color Damage Amounts"]),
			classColors = ColorsGroup(23, L["Class Colors"], classKeys, classLabels, "classColoringDisabled", L["Color Unit Names"]),
			advanced = {
				type = "group", order = 24, name = L["Advanced"],
				args = {
					privateFontObjects = {
						type = "toggle", order = 1, name = L["Separate Font Objects"],
						desc = L["Give every text line its own font object. Enable it if lines shown at the same time take on each other's color. Takes effect after /reload."],
						get = function() return MikSBT.db.global.privateFontObjects and true or false end,
						set = function(info, value) MikSBT.db.global.privateFontObjects = value and true or false end,
					},
					eventLog = {
						type = "toggle", order = 2, name = L["Combat Log Recording"],
						desc = L["Record every combat log line into the MSBTDebugLog saved variable (for bug reports)."],
						get = function() return MikSBT.Parser.IsLogging() end,
						set = function(info, value) MikSBT.Parser.SetLogging(value) end,
					},
				},
			},
		},
	}
end


-------------------------------------------------------------------------------
-- Scroll areas.
-------------------------------------------------------------------------------

local newScrollAreaName = ""

local function ScrollAreaPage(key, order)
	local getter = function() return O.P().scrollAreas[key] end
	local function setField(field, value)
		getter()[field] = value
		O.ApplyDisplay()
	end
	local function styleSelect(ord, name, field, sticky)
		return {
			type = "select", order = ord, name = name,
			values = function() return O.StyleValues(sticky) end,
			get = function() return getter()[field] or (sticky and "Pow" or "Straight") end,
			set = function(info, value) setField(field, value) end,
		}
	end
	local function optionSelect(ord, name, field, sticky, styleField, listField)
		return {
			type = "select", order = ord, name = name,
			values = function()
				return O.StyleOptionValues(sticky, getter()[styleField] or (sticky and "Pow" or "Straight"), listField)
			end,
			hidden = function()
				local style = getter()[styleField] or (sticky and "Pow" or "Straight")
				return not next(O.StyleOptionValues(sticky, style, listField))
			end,
			get = function() return getter()[field] end,
			set = function(info, value) setField(field, value) end,
		}
	end
	local function number(ord, name, field, minValue, maxValue, default)
		return {
			type = "range", order = ord, name = name, min = minValue, max = maxValue, step = 1,
			get = function() return getter()[field] or default end,
			set = function(info, value) setField(field, value) end,
		}
	end

	return {
		type = "group", order = order,
		name = function() return (getter() and getter().name) or key end,
		args = {
			name = {
				type = "input", order = 1, name = L["Name"],
				get = function() return getter().name or key end,
				set = function(info, value) setField("name", value) module.Rebuild() end,
			},
			enabled = O.InvToggle(2, L["Enable"], nil, "disabled", getter, O.ApplyDisplay),
			preview = {
				type = "execute", order = 3, name = L["Preview"],
				func = function()
					MikSBT.DisplayMessage(getter().name or key, key, false, 255, 255, 255)
					MikSBT.DisplayMessage((getter().name or key) .. " " .. L["Sticky"], key, true, 255, 210, 0)
				end,
			},
			normal = {
				type = "group", inline = true, order = 10, name = L["Normal"],
				args = {
					animationStyle = styleSelect(1, L["Animation Style"], "animationStyle", false),
					direction = optionSelect(2, L["Direction"], "direction", false, "animationStyle", "availableDirections"),
					behavior = optionSelect(3, L["Behavior"], "behavior", false, "animationStyle", "availableBehaviors"),
					textAlignIndex = {
						type = "select", order = 4, name = L["Text Align"], values = O.AlignValues,
						get = function() return getter().textAlignIndex or 2 end,
						set = function(info, value) setField("textAlignIndex", value) end,
					},
				},
			},
			sticky = {
				type = "group", inline = true, order = 11, name = L["Sticky"],
				args = {
					stickyAnimationStyle = styleSelect(1, L["Animation Style"], "stickyAnimationStyle", true),
					stickyDirection = optionSelect(2, L["Direction"], "stickyDirection", true, "stickyAnimationStyle", "availableDirections"),
					stickyBehavior = optionSelect(3, L["Behavior"], "stickyBehavior", true, "stickyAnimationStyle", "availableBehaviors"),
					stickyTextAlignIndex = {
						type = "select", order = 4, name = L["Text Align"], values = O.AlignValues,
						get = function() return getter().stickyTextAlignIndex or 2 end,
						set = function(info, value) setField("stickyTextAlignIndex", value) end,
					},
				},
			},
			geometry = {
				type = "group", inline = true, order = 12, name = L["Position and Size"],
				args = {
					point = {
						type = "select", order = 1, name = L["Anchor Point"],
						desc = L["The screen edge or corner the X and Y offsets are measured from. Move mode picks the nearest one automatically; changing it here keeps the scroll area in place. Center measures the bottom-left corner of the scroll area from the screen center."],
						values = O.AnchorPointValues,
						get = function() return getter().point or "CENTER" end,
						set = function(info, value)
							MikSBT.Animations.SetScrollAreaPoint(getter(), value)
							O.ApplyDisplay()
						end,
					},
					offsetX = number(2, L["X Offset"], "offsetX", -1500, 1500, 0),
					offsetY = number(3, L["Y Offset"], "offsetY", -1000, 1000, 0),
					scrollHeight = number(4, L["Scroll Height"], "scrollHeight", 50, 600, MikSBT.Animations.DEFAULT_SCROLL_HEIGHT),
					scrollWidth = number(5, L["Scroll Width"], "scrollWidth", 10, 800, MikSBT.Animations.DEFAULT_SCROLL_WIDTH),
					move = {
						type = "execute", order = 6, name = L["Move Scroll Areas"],
						func = function() MikSBT.Movers.Unlock() end,
					},
				},
			},
			speed = {
				type = "group", inline = true, order = 13, name = L["Animation Speed"],
				args = {
					inherit = {
						type = "toggle", order = 1, name = L["Inherit"],
						get = function() return not getter().animationSpeed end,
						set = function(info, value) setField("animationSpeed", (not value) and 100 or nil) end,
					},
					animationSpeed = {
						type = "range", order = 2, name = L["Animation Speed"], min = 20, max = 250, step = 1,
						disabled = function() return not getter().animationSpeed end,
						get = function() return getter().animationSpeed or O.P().animationSpeed end,
						set = function(info, value) setField("animationSpeed", value) end,
					},
				},
			},
			icons = {
				type = "group", inline = true, order = 14, name = L["Icons"],
				args = {
					showIcons = O.InvToggle(1, L["Show Icons"], nil, "skillIconsDisabled", getter, O.ApplyDisplay),
					iconAlign = {
						type = "select", order = 2, name = L["Icon Align"],
						values = function() return { Left = L["Left"], Right = L["Right"] } end,
						get = function() return getter().iconAlign or "Left" end,
						set = function(info, value) setField("iconAlign", value) end,
					},
				},
			},
			normalFont = O.FontGroup(20, L["Normal Font"], getter, "normal", true, O.ApplyDisplay),
			critFont = O.FontGroup(21, L["Crit Font"], getter, "crit", true, O.ApplyDisplay),
			delete = {
				type = "execute", order = 30, name = L["Delete Scroll Area"],
				hidden = function() return key == MikSBT.DEFAULT_SCROLL_AREA end,
				func = function()
					O.Confirm(string.format(L["Delete the scroll area '%s'?"], getter().name or key), function()
						if MikSBT.Defaults.profile.scrollAreas[key] then
							O.P().scrollAreas[key] = false
						else
							O.P().scrollAreas[key] = nil
						end
						O.ApplyDisplay()
						module.Rebuild()
					end)
				end,
			},
		},
	}
end

local function BuildScrollAreas()
	local group = {
		type = "group", order = 2, name = L["Scroll Areas"],
		args = {
			move = {
				type = "execute", order = 1, name = L["Move Scroll Areas"],
				func = function() MikSBT.Movers.Unlock() end,
			},
			newName = {
				type = "input", order = 2, name = L["New Scroll Area"],
				get = function() return newScrollAreaName end,
				set = function(info, value) newScrollAreaName = value end,
			},
			add = {
				type = "execute", order = 3, name = L["Add Scroll Area"],
				func = function()
					if newScrollAreaName == "" then return end
					local n = 1
					while O.P().scrollAreas["Custom" .. n] ~= nil do n = n + 1 end
					O.P().scrollAreas["Custom" .. n] = { name = newScrollAreaName, offsetX = 0, offsetY = 0 }
					newScrollAreaName = ""
					O.ApplyDisplay()
					module.Rebuild()
				end,
			},
		},
	}
	local keys = {}
	local key, settings
	for key, settings in pairs(O.P().scrollAreas) do
		if type(settings) == "table" then
			table.insert(keys, key)
		end
	end
	table.sort(keys)
	local i
	for i = 1, Compat.getn(keys) do
		group.args["area_" .. keys[i]] = ScrollAreaPage(keys[i], 10 + i)
	end
	return group
end


-------------------------------------------------------------------------------
-- Window.
-------------------------------------------------------------------------------

function module.Rebuild()
	if not options then
		return
	end
	local args = BuildRoot()
	args.general = BuildGeneral()
	args.scrollAreas = BuildScrollAreas()
	args.events = module.BuildEvents()
	args.triggers = module.BuildTriggers()
	args.spamControl = module.BuildSpamControl()
	args.cooldowns = module.BuildCooldowns()
	args.loot = module.BuildLoot()
	args.skillIcons = module.BuildSkillIcons()
	args.media = module.BuildMedia()
	args.profiles = module.BuildProfiles()
	options.args = args
	module.NotifyChange()
end

function module.Initialize()
	if initialized then
		return
	end
	local LC = LibStub("LibConfig-1.0", true)
	if not LC then
		return
	end
	options = { type = "group", name = APP_NAME, args = {} }
	module.Rebuild()
	LC:RegisterOptionsTable(APP_NAME, APP_NAME, options)
	initialized = true
end

function module.Open()
	module.Initialize()
	local LC = LibStub("LibConfig-1.0", true)
	if LC then
		LC:OpenToCategory(APP_NAME)
	else
		MikSBT:Print(L["The options library (LibConfig-1.0) is missing."])
	end
end

-- LibConfig cannot open a sub-page; the category opens and the page is named.
function module.OpenScrollArea(key)
	module.Open()
	local settings = key and MikSBT.Animations.scrollAreas[key]
	if settings then
		MikSBT:Print(string.format(L["Open 'Scroll Areas > %s' on the left."], settings.name or key))
	end
end

function module.Close()
	local LC = LibStub("LibConfig-1.0", true)
	if LC and LC.Close then
		LC:Close()
	end
end

function module.NotifyChange()
	local LC = LibStub("LibConfig-1.0", true)
	if LC and LC.NotifyChange then
		LC:NotifyChange(APP_NAME)
	end
end
