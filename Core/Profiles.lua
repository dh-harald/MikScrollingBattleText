-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Profiles
-- AceDB-3.0 database (MSBTDB), profile switching, enable/disable and the
-- addon's AceAddon-3.0 lifecycle (OnInitialize / OnEnable / OnDisable).
--
-- MikSBT.Profiles.currentProfile always points at db.profile, so the ported
-- classic modules keep reading `MSBTProfiles.currentProfile.<key>`.
-------------------------------------------------------------------------------

local _G = _G or getfenv()

local module = {}
MikSBT.Profiles = module

local L = MikSBT.L
local Compat = MikSBT.Compat
local Util = MikSBT.Util

local string_format = string.format

local DB_NAME = "MSBTDB"
local DEFAULT_PROFILE_NAME = "Default"

local db
local isFirstLoad


-------------------------------------------------------------------------------
-- Localized defaults.
-------------------------------------------------------------------------------

-- Returns the client's name for an English spell name, or nil when
-- LibBabble-Spell-2.2 is missing, does not know the spell, or only has an
-- empty placeholder for this locale.
local function LocalizedSpell(englishName)
	local BS = LibStub("LibBabble-Spell-2.2", true)
	if not BS or not englishName or not BS:HasTranslation(englishName) then
		return nil
	end
	local localized = BS[englishName]
	if not localized or localized == "" then
		return nil
	end
	return localized
end
module.LocalizedSpell = LocalizedSpell

-- Turns the "*Format" template fields of the default triggers into final
-- settings using the client's spell names. A trigger whose spell cannot be
-- localized is removed from the defaults: it could never match.
local function ResolveDefaultTriggers(triggers)
	local key, settings
	local toRemove = {}
	for key, settings in pairs(triggers) do
		if settings.spell then
			local spell = LocalizedSpell(settings.spell)
			local needsSpell = settings.messageFormat or settings.mainEventsFormat or settings.exceptionsFormat
			if not spell and needsSpell then
				table.insert(toRemove, key)
			else
				if settings.messageFormat then
					settings.message = string_format(settings.messageFormat, spell)
				end
				if settings.mainEventsFormat then
					settings.mainEvents = string_format(settings.mainEventsFormat, spell)
				end
				if settings.exceptionsFormat then
					settings.exceptions = string_format(settings.exceptionsFormat, spell)
				end
				if settings.iconSkillFormat and spell then
					settings.iconSkill = string_format(settings.iconSkillFormat, spell)
				end
			end
		end
		settings.spell = nil
		settings.messageFormat = nil
		settings.mainEventsFormat = nil
		settings.exceptionsFormat = nil
		settings.iconSkillFormat = nil
	end
	local i
	for i = 1, Compat.getn(toRemove) do
		triggers[toRemove[i]] = nil
	end
end

local function ResolveDefaultThrottles(profile)
	local english, duration
	for english, duration in pairs(MikSBT.DEFAULT_THROTTLED_SPELLS) do
		local spell = LocalizedSpell(english)
		if spell then
			profile.throttleList[spell] = duration
		end
	end
end


-------------------------------------------------------------------------------
-- Enable / disable.
-------------------------------------------------------------------------------

local function IsModDisabled()
	return db and db.global.userDisabled
end

-- The addon's enabled state mirrors the option; OnEnable / OnDisable switch
-- the modules.
local function SetOptionUserDisabled(isDisabled)
	db.global.userDisabled = isDisabled and true or false
	if isDisabled then
		MikSBT:Disable()
	else
		MikSBT:Enable()
	end
end

-- Turns off the Blizzard_CombatText floating combat text (1.12 uses the
-- SHOW_COMBAT_TEXT UI variable for it).
local function DisableBlizzardCombatText()
	SHOW_COMBAT_TEXT = "0"
	if CombatText_UpdateDisplayedMessages then
		pcall(CombatText_UpdateDisplayedMessages)
	end
end

-- The CombatDamage CVar controls the damage numbers over the target's head.
local function ApplyBlizzardDamage()
	pcall(SetCVar, "CombatDamage", db.profile.enableBlizzardDamage and "1" or "0")
end
module.ApplyBlizzardDamage = ApplyBlizzardDamage


-------------------------------------------------------------------------------
-- Profile application.
-------------------------------------------------------------------------------

-- Preloads the fonts used by the profile so the first text shows in the right
-- font on the legacy client.
local function LoadUsedFonts()
	local profile = db.profile
	local used = {}
	if profile.normalFontName then used[profile.normalFontName] = true end
	if profile.critFontName then used[profile.critFontName] = true end
	local _, settings
	for _, settings in pairs(profile.scrollAreas) do
		if type(settings) == "table" then
			if settings.normalFontName then used[settings.normalFontName] = true end
			if settings.critFontName then used[settings.critFontName] = true end
		end
	end
	for _, settings in pairs(profile.events) do
		if type(settings) == "table" and settings.fontName then used[settings.fontName] = true end
	end
	for _, settings in pairs(profile.triggers) do
		if type(settings) == "table" and settings.fontName then used[settings.fontName] = true end
	end
	local fontName
	for fontName in pairs(used) do
		MikSBT.Animations.LoadFont(fontName)
	end
end

-- Re-reads everything that caches profile data.
local function ApplyProfile()
	module.currentProfile = db.profile
	LoadUsedFonts()
	MikSBT.Animations.UpdateScrollAreas()
	MikSBT.Triggers.UpdateTriggers()
	MikSBT.Cooldowns.UpdateRegisteredEvents()
	if MikSBT.Movers then
		MikSBT.Movers.Refresh()
	end
	if MikSBT.Config then
		MikSBT.Config.Rebuild()
	end
end
module.ApplyProfile = ApplyProfile

local function ResetProfile(showOutput)
	db:ResetProfile()
	if showOutput then
		MikSBT:Print(db:GetCurrentProfile() .. " " .. L["Profile Reset"], 0, 1, 0)
	end
end


-------------------------------------------------------------------------------
-- Saved variables.
-------------------------------------------------------------------------------

-- On Unreal Azeroth PLAYER_LOGOUT is not delivered before the SavedVariables
-- are written, so AceDB never strips its defaults there. Running AceDB's own
-- logout handler just before ReloadUI keeps the saved profile limited to the
-- user's changes for the reload path; after a plain logout the file carries
-- the full defaults, which is harmless apart from its size.
local function InstallSaveHook()
	if not Compat.isUA then
		return
	end
	local AceDB = LibStub("AceDB-3.0")
	local handler = AceDB.frame and AceDB.frame:GetScript("OnEvent")
	if not handler then
		return
	end
	Util.PreHookGlobal("ReloadUI", function()
		local savedEvent = event
		event = "PLAYER_LOGOUT"
		pcall(handler)
		event = savedEvent
	end)
end

local function InitSavedVariables()
	ResolveDefaultTriggers(MikSBT.Defaults.profile.triggers)
	ResolveDefaultThrottles(MikSBT.Defaults.profile)

	isFirstLoad = (_G[DB_NAME] == nil)
	db = LibStub("AceDB-3.0"):New(DB_NAME, MikSBT.Defaults, DEFAULT_PROFILE_NAME)
	MikSBT.db = db
	module.db = db
	module.currentProfile = db.profile

	db.RegisterCallback(module, "OnProfileChanged", ApplyProfile)
	db.RegisterCallback(module, "OnProfileCopied", ApplyProfile)
	db.RegisterCallback(module, "OnProfileReset", ApplyProfile)

	InstallSaveHook()
end


-------------------------------------------------------------------------------
-- Lifecycle.
-------------------------------------------------------------------------------

-- ADDON_LOADED: saved variables, profile caches and the options registration,
-- so everything that only needs the addon's own data is ready before login and
-- independent of the enabled state.
function MikSBT:OnInitialize()
	InitSavedVariables()
	-- Arrow bindings left unbound by a move mode that a /reload interrupted.
	if MikSBT.Movers then
		pcall(MikSBT.Movers.RestoreArrowBindings)
	end
	MikSBT.Media.OnVariablesInitialized()
	ApplyProfile()
	if MikSBT.Config then
		MikSBT.Config.Initialize()
	end
	self:SetEnabledState(not IsModDisabled())
end

-- PLAYER_LOGIN, or later when the user enables the mod.
function MikSBT:OnEnable()
	local name, subModule
	for name, subModule in self:IterateModules() do
		subModule:Enable()
	end
	if isFirstLoad then
		isFirstLoad = false
		DisableBlizzardCombatText()
		ApplyBlizzardDamage()
	end
	-- Periodic damage and heal lines only appear in the combat log with this on.
	pcall(SetCVar, "CombatLogPeriodicSpells", "1")
	-- No argument: Lua 5.0 only accepts a number here, 5.1 defaults to a full collection.
	collectgarbage()
end

function MikSBT:OnDisable()
	local name, subModule
	for name, subModule in self:IterateModules() do
		subModule:Disable()
	end
end


module.DEFAULT_PROFILE_NAME = DEFAULT_PROFILE_NAME
module.IsModDisabled = IsModDisabled
module.SetOptionUserDisabled = SetOptionUserDisabled
module.ResetProfile = ResetProfile
module.DisableBlizzardCombatText = DisableBlizzardCombatText
