-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Commands
-- Slash commands, the display test and the combat log search.
-------------------------------------------------------------------------------

local _G = _G or getfenv()

local module = MikSBT:NewModule("Commands")
MikSBT.Commands = module

local L = MikSBT.L
local Compat = MikSBT.Compat

local searchText


-- Shows sample events through the normal event settings in every scroll area.
function module.RunTest()
	local profile = MikSBT.Profiles.currentProfile
	if not profile then
		return
	end
	local Format = MikSBT.Main.FormatEvent
	local samples = {
		{ "INCOMING_DAMAGE", 123, 1, L["Test"] },
		{ "INCOMING_SPELL_DAMAGE_CRIT", 456, 4, L["Test"], L["Fireball"] },
		{ "INCOMING_HEAL", 250, nil, L["Test"], L["Heal"] },
		{ "OUTGOING_DAMAGE", 321, 1, L["Test"] },
		{ "OUTGOING_SPELL_DAMAGE_CRIT", 987, 16, L["Test"], L["Frostbolt"] },
		{ "OUTGOING_SPELL_DOT", 42, 32, L["Test"], L["Shadow Word: Pain"] },
		{ "NOTIFICATION_BUFF", nil, nil, nil, L["Test"] },
		{ "NOTIFICATION_CP_FULL" },
		{ "NOTIFICATION_MONEY" },
	}
	local _, sample
	for _, sample in ipairs(samples) do
		local settings = profile.events[sample[1]]
		if settings and not settings.disabled then
			local message
			if sample[1] == "NOTIFICATION_MONEY" then
				message = string.gsub(settings.message, "%%e", "|cffffd7001 " .. (_G.GOLD or "Gold") .. "|r")
			else
				message = Format(settings.message, sample[2], sample[3], nil, nil, sample[4], nil, sample[5])
			end
			MikSBT.Animations.DisplayEvent(settings, message, MikSBT.Icons.GetSkillIcon(sample[5]))
		end
	end
	local key, settings
	for key, settings in pairs(MikSBT.Animations.scrollAreas) do
		MikSBT.DisplayMessage(settings.name or key, key, false, 255, 255, 255)
	end
end

-- Prints every combat log line containing the text (empty text stops).
function module.SetSearch(text)
	if text and text ~= "" then
		searchText = text
		MikSBT:Print(string.format(L["Printing combat log lines containing '%s'. /msbt search stops."], text))
	else
		searchText = nil
		MikSBT:Print(L["Combat log search stopped."])
	end
end

function module.OnCombatLine(eventName, message)
	if searchText and string.find(message, searchText, 1, true) then
		MikSBT:Print(eventName .. ": " .. message, 0.7, 0.7, 1)
	end
end

local function PrintUsage()
	local c = MikSBT.COMMAND
	MikSBT:Print(L["Usage:"] .. " " .. c .. " <command>")
	MikSBT:Print("  " .. c .. " - " .. L["Open the options."])
	MikSBT:Print("  " .. c .. " move - " .. L["Move the scroll areas."])
	MikSBT:Print("  " .. c .. " test - " .. L["Show test events."])
	MikSBT:Print("  " .. c .. " reset - " .. L["Reset the current profile to the default settings."])
	MikSBT:Print("  " .. c .. " enable | disable - " .. L["Enable or disable the mod."])
	MikSBT:Print("  " .. c .. " version - " .. L["Show the current version."])
	MikSBT:Print("  " .. c .. " search <text> - " .. L["Print combat log lines containing the text."])
	MikSBT:Print("  " .. c .. " eventlog on | off | clear - " .. L["Record combat log lines into MSBTDebugLog."])
end

local function CommandHandler(params)
	params = params or ""
	local s, e, command, rest = string.find(params, "^%s*(%S*)%s*(.-)%s*$")
	command = string.lower(command or "")

	if command == "" then
		MikSBT.Config.Open()
	elseif command == "move" then
		MikSBT.Movers.Toggle()
	elseif command == "test" then
		module.RunTest()
	elseif command == "reset" then
		MikSBT.Profiles.ResetProfile(true)
	elseif command == "disable" then
		MikSBT.Profiles.SetOptionUserDisabled(true)
		MikSBT:Print(L["Mod disabled."])
	elseif command == "enable" then
		MikSBT.Profiles.SetOptionUserDisabled(false)
		MikSBT:Print(L["Mod enabled."])
	elseif command == "version" then
		MikSBT:Print(MikSBT.VERSION_STRING)
	elseif command == "search" then
		module.SetSearch(rest)
	elseif command == "eventlog" then
		local option = string.lower(rest or "")
		if option == "on" then
			MikSBT.Parser.SetLogging(true)
			MikSBT:Print(L["Combat log recording on. /reload writes it to the saved variables."])
		elseif option == "off" then
			MikSBT.Parser.SetLogging(false)
			MikSBT:Print(L["Combat log recording off."])
		elseif option == "clear" then
			MikSBT.Parser.ClearLog()
			MikSBT:Print(L["Combat log recording cleared."])
		else
			MikSBT:Print(string.format(L["Combat log recording: %s, %d lines."], MikSBT.Parser.IsLogging() and "on" or "off", Compat.getn(MSBTDebugLog or {})))
		end
	else
		PrintUsage()
	end
end

MikSBT.Parser.lineObserver = module.OnCombatLine

-- AceConsole-3.0 registers /msbt as SlashCmdList.ACECONSOLE_MSBT.
function module:OnInitialize()
	MikSBT:RegisterChatCommand("msbt", CommandHandler)
end

module.CommandHandler = CommandHandler
