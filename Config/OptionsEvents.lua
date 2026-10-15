-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Options - Events
--
-- One sidebar page per event, grouped by the classic categories. A page per
-- event keeps every rendered page small; a single page with all events would
-- create well over a thousand widgets at once.
-------------------------------------------------------------------------------

local module = MikSBT.Config
local O = module.O
local L = MikSBT.L
local Compat = MikSBT.Compat

local CODES_HELP = "%a, %n, %s, %sl, %e, %t, %p"

local function EventPage(eventKey, label, tooltip, order)
	local getter = function() return O.P().events[eventKey] end
	return {
		type = "group", order = order, name = L[label],
		args = {
			desc = { type = "description", order = 1, name = L[tooltip] },
			enabled = O.InvToggle(2, L["Enable"], nil, "disabled", getter, function()
				if string.find(eventKey, "COOLDOWN") then O.ApplyCooldowns() end
			end),
			color = O.Color(3, L["Color"], getter),
			message = {
				type = "input", order = 4, name = L["Message"], width = "full",
				desc = string.format(L["Event codes: %s"], CODES_HELP) .. "\n" .. L["%a amount, %n name, %s skill (%sl unabbreviated), %e effect, %t damage type, %p power type."],
				get = function() return getter().message or "" end,
				set = function(info, value) getter().message = value end,
			},
			scrollArea = {
				type = "select", order = 5, name = L["Scroll Area"], values = O.ScrollAreaValues,
				get = function() return getter().scrollArea or MikSBT.DEFAULT_SCROLL_AREA end,
				set = function(info, value) getter().scrollArea = value end,
			},
			alwaysSticky = O.Toggle(6, L["Always Sticky"], L["Always show the event with the sticky style."], "alwaysSticky", getter),
			soundFile = {
				type = "select", dialogControl = "LSM30_Sound", order = 7, name = L["Sound"], values = O.SoundValues,
				get = function() return getter().soundFile or "" end,
				set = function(info, value)
					if value == "" then value = false end
					getter().soundFile = value
					if value then MikSBT.Media.PlaySound(value) end
				end,
			},
			skillColor = {
				type = "group", inline = true, order = 8, name = L["Skill Color"],
				hidden = function() return not string.find(eventKey, "COOLDOWN") end,
				args = { color = O.Color(1, L["Color"], getter, "skillColor") },
			},
			font = O.FontGroup(10, L["Font"], getter, "", true),
		},
	}
end

function module.BuildEvents()
	local group = { type = "group", order = 3, name = L["Events"], args = {} }
	local events = O.P().events
	local c
	for c = 1, Compat.getn(MikSBT.EventLabels) do
		local category = MikSBT.EventLabels[c]
		local catGroup = { type = "group", order = c, name = L[category.category], args = {} }
		local i
		for i = 1, Compat.getn(category.events) do
			local entry = category.events[i]
			if type(events[entry[1]]) == "table" then
				catGroup.args[entry[1]] = EventPage(entry[1], entry[2], entry[3], i)
			end
		end
		group.args["category" .. c] = catGroup
	end
	return group
end
