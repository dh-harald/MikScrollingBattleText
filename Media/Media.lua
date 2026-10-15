-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Media
-- Font and sound registry, kept in sync with LibSharedMedia-3.0.
--
-- Media paths are case-sensitive on Unreal Azeroth, so every shipped path
-- below matches the file name on disk byte for byte. SavedVariables only ever
-- store media NAMES; custom media paths are stored with "/" separators and
-- converted back on load, because the Unreal Azeroth SavedVariables writer
-- does not escape backslashes reliably.
-------------------------------------------------------------------------------

local module = {}
MikSBT.Media = module

local LSM = LibStub("LibSharedMedia-3.0")
local LSM_LANG_MASK_ALL = 255

local MEDIA_PATH = "Interface\\AddOns\\MikScrollingBattleText\\Media\\"

local DEFAULT_FONT_FILES = {
	["MSBT Adventure"] = MEDIA_PATH .. "Fonts\\adventure.ttf",
	["MSBT Bazooka"] = MEDIA_PATH .. "Fonts\\bazooka.ttf",
	["MSBT Cooline"] = MEDIA_PATH .. "Fonts\\cooline.ttf",
	["MSBT Die Die Die"] = MEDIA_PATH .. "Fonts\\diediedie.ttf",
	["MSBT Diogenes"] = MEDIA_PATH .. "Fonts\\diogenes.ttf",
	["MSBT Ginko"] = MEDIA_PATH .. "Fonts\\ginko.ttf",
	["MSBT Heroic"] = MEDIA_PATH .. "Fonts\\heroic.ttf",
	["MSBT Porky"] = MEDIA_PATH .. "Fonts\\porky.ttf",
	["MSBT Talisman"] = MEDIA_PATH .. "Fonts\\talisman.ttf",
	["MSBT Transformers"] = MEDIA_PATH .. "Fonts\\transformers.ttf",
	["MSBT Yellowjacket"] = MEDIA_PATH .. "Fonts\\yellowjacket.ttf",
	-- Fonts shipped with the game client; the only faces Unreal Azeroth can
	-- currently render.
	["Friz Quadrata"] = "Fonts\\FRIZQT__.TTF",
	["Arial Narrow"] = "Fonts\\ARIALN.TTF",
	["Morpheus"] = "Fonts\\MORPHEUS.TTF",
	["Skurri"] = "Fonts\\SKURRI.TTF",
}

local DEFAULT_SOUND_FILES = {
	["MSBT Low Health"] = MEDIA_PATH .. "Sounds\\LowHealth.mp3",
	["MSBT Low Mana"] = MEDIA_PATH .. "Sounds\\LowMana.mp3",
	["MSBT Cooldown"] = MEDIA_PATH .. "Sounds\\Cooldown.ogg",
}

-- Unreal Azeroth plays .ogg but not .mp3, so there the defaults use
-- .ogg conversions of the mp3s. Saved settings store only the names, so they
-- keep working unchanged on both clients.
if MikSBT.Compat.isUA then
	DEFAULT_SOUND_FILES["MSBT Low Health"] = MEDIA_PATH .. "Sounds\\LowHealth.ogg"
	DEFAULT_SOUND_FILES["MSBT Low Mana"] = MEDIA_PATH .. "Sounds\\LowMana.ogg"
end

local fonts = {}
local sounds = {}

local function RegisterFont(fontName, fontPath)
	if type(fontName) ~= "string" or type(fontPath) ~= "string" or fontName == "" or fontPath == "" then
		return
	end
	fonts[fontName] = fontPath
	LSM:Register("font", fontName, fontPath, LSM_LANG_MASK_ALL)
end

local function IterateFonts()
	return pairs(fonts)
end

-- Sound paths must point into Interface\ and end in .mp3, .ogg or .wav.
local function RegisterSound(soundName, soundPath)
	if type(soundName) ~= "string" or type(soundPath) ~= "string" or soundName == "" or soundPath == "" then
		return
	end
	local lower = string.lower(soundPath)
	if string.find(lower, "interface", 1, true) ~= 1 and string.find(lower, "sound", 1, true) ~= 1 then
		return
	end
	if not (string.find(lower, "%.mp3$") or string.find(lower, "%.ogg$") or string.find(lower, "%.wav$")) then
		return
	end
	sounds[soundName] = soundPath
	LSM:Register("sound", soundName, soundPath)
end

local function IterateSounds()
	return pairs(sounds)
end

local function OnLSMRegistered(event, mediaType, name)
	if mediaType == "font" then
		fonts[name] = LSM:Fetch("font", name)
	elseif mediaType == "sound" then
		sounds[name] = LSM:HashTable("sound")[name]
	end
end

-- Custom media are saved with "/" separators (see header).
local function ToSavedPath(path)
	return (string.gsub(path, "\\", "/"))
end

local function FromSavedPath(path)
	return (string.gsub(path, "/", "\\"))
end

-- Registers the user's custom media from MSBT_SavedMedia.
local function OnVariablesInitialized()
	if type(MSBT_SavedMedia) ~= "table" then
		MSBT_SavedMedia = {}
	end
	MSBT_SavedMedia.fonts = MSBT_SavedMedia.fonts or {}
	MSBT_SavedMedia.sounds = MSBT_SavedMedia.sounds or {}
	module.savedMedia = MSBT_SavedMedia
	for fontName, fontPath in pairs(MSBT_SavedMedia.fonts) do
		RegisterFont(fontName, FromSavedPath(fontPath))
	end
	for soundName, soundPath in pairs(MSBT_SavedMedia.sounds) do
		RegisterSound(soundName, FromSavedPath(soundPath))
	end
end

-- Custom media management for the options.
local function AddCustomFont(fontName, fontPath)
	RegisterFont(fontName, fontPath)
	if fonts[fontName] == fontPath then
		MSBT_SavedMedia.fonts[fontName] = ToSavedPath(fontPath)
		return true
	end
end

local function RemoveCustomFont(fontName)
	MSBT_SavedMedia.fonts[fontName] = nil
	fonts[fontName] = nil
end

local function AddCustomSound(soundName, soundPath)
	RegisterSound(soundName, soundPath)
	if sounds[soundName] == soundPath then
		MSBT_SavedMedia.sounds[soundName] = ToSavedPath(soundPath)
		return true
	end
end

local function RemoveCustomSound(soundName)
	MSBT_SavedMedia.sounds[soundName] = nil
	sounds[soundName] = nil
end

-- Plays a registered sound by name (or a raw path). `sounds` keeps every
-- path in the standard "Interface\AddOns\..." form, as registered (on Unreal
-- Azeroth LSM:Fetch hands out a different form, so it is not used to fill
-- `sounds`); LibSharedMedia turns it into the path the running client plays
-- (Unreal Azeroth plays an addon's sound file only from its own path form).
local function PlaySound(soundName)
	local path = sounds[soundName] or soundName
	if type(path) ~= "string" or path == "" then
		return
	end
	if LSM.GetClientSoundPath then
		path = LSM:GetClientSoundPath(path)
	end
	-- The 1.12.1 client takes a channel argument: "Master" plays even with the
	-- Sound Volume slider at zero, but stays silent while sound is disabled
	-- (MasterSoundEffects = 0), unlike later clients. UA takes the same call.
	pcall(PlaySoundFile, path, "Master")
end


for fontName, fontPath in pairs(DEFAULT_FONT_FILES) do
	RegisterFont(fontName, fontPath)
end
for soundName, soundPath in pairs(DEFAULT_SOUND_FILES) do
	RegisterSound(soundName, soundPath)
end
local _, name
for _, name in pairs(LSM:List("font")) do
	fonts[name] = LSM:Fetch("font", name)
end
for _, name in pairs(LSM:List("sound")) do
	sounds[name] = LSM:HashTable("sound")[name]
end
LSM.RegisterCallback("MSBTSharedMedia", "LibSharedMedia_Registered", OnLSMRegistered)


module.fonts = fonts
module.sounds = sounds
module.DEFAULT_FONT_FILES = DEFAULT_FONT_FILES
module.DEFAULT_SOUND_FILES = DEFAULT_SOUND_FILES
module.RegisterFont = RegisterFont
module.RegisterSound = RegisterSound
module.IterateFonts = IterateFonts
module.IterateSounds = IterateSounds
module.OnVariablesInitialized = OnVariablesInitialized
module.AddCustomFont = AddCustomFont
module.RemoveCustomFont = RemoveCustomFont
module.AddCustomSound = AddCustomSound
module.RemoveCustomSound = RemoveCustomSound
module.PlaySound = PlaySound
