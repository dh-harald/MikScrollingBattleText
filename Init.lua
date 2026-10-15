-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text
-- Author: Mikord (original), 1.12.1 / Unreal Azeroth port
--
-- Creates the global MikSBT engine table: the AceAddon-3.0 addon object.
-- Every module registers itself as a field on it (MikSBT.<ModuleName>),
-- exactly like the classic addon, so the classic public API
-- (MikSBT.DisplayMessage, MikSBT.RegisterFont, ...) keeps working for
-- third-party addons.
--
-- Lifecycle (AceAddon-3.0): OnInitialize runs on ADDON_LOADED, OnEnable on
-- PLAYER_LOGIN (Core/Profiles.lua). Modules are created disabled and follow
-- the addon's enabled state, which mirrors the user's enable/disable option.
-------------------------------------------------------------------------------

local _G = _G or getfenv()

local mod = LibStub("AceAddon-3.0"):NewAddon("MikScrollingBattleText", "AceConsole-3.0", "AceEvent-3.0")
_G.MikSBT = mod
mod:SetDefaultModuleState(false)

mod.ADDON_NAME = "MikScrollingBattleText"
mod.COMMAND = "/msbt"

-- Version from the .toc; the packager substitutes @project-version@.
local tocVersion = GetAddOnMetadata and GetAddOnMetadata(mod.ADDON_NAME, "Version")
if not tocVersion or tocVersion == "" or string.find(tocVersion, "project-version", 1, true) then
	tocVersion = "dev"
end
mod.VERSION_STRING = "v" .. tocVersion

-- Locale table. The locale files only register their strings with
-- AceLocale-3.0; the table is fetched here because a locale file can run
-- before any other file of the addon on Unreal Azeroth.
mod.L = LibStub("AceLocale-3.0"):GetLocale(mod.ADDON_NAME)

-- AceConsole-3.0 Print with an optional 0-1 color, white by default.
-- AceConsole passes no color to AddMessage and a client does not necessarily
-- fall back to white for that, so the text carries an explicit color code.
local AceConsole = LibStub("AceConsole-3.0")
function mod:Print(msg, r, g, b)
	local floor = math.floor
	local color = string.format("|cff%02x%02x%02x", floor((r or 1) * 255), floor((g or 1) * 255), floor((b or 1) * 255))
	AceConsole.Print(self, color .. tostring(msg) .. "|r")
end
