-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Animations
-- Display engine (classic MSBT 6.0 port): pooled font strings and icons on one
-- animation frame, animated by the registered animation styles.
--
-- Font face, size and outline go through FontString:SetFont on every client.
-- The Unreal Azeroth client currently renders only its stock fonts and cannot
-- resize text; the calls are kept so the text follows the settings wherever
-- the client supports them, and layout always uses measured string widths.
-------------------------------------------------------------------------------

local _G = _G or getfenv()

local module = {}
MikSBT.Animations = module

local Compat = MikSBT.Compat
local Util = MikSBT.Util
local MSBTMedia = MikSBT.Media
local MSBTProfiles = MikSBT.Profiles

local table_remove = table.remove
local getn = Compat.getn


-------------------------------------------------------------------------------
-- Constants.
-------------------------------------------------------------------------------

local MAX_ANIMATIONS_PER_AREA = 15
local DEFAULT_SCROLL_TIME = 3
local DEFAULT_FADE_PERCENT = 0.8
local ANIMATION_DELAY = 0.015

local TEXT_ALIGN_MAP = { "BOTTOMLEFT", "BOTTOM", "BOTTOMRIGHT" }
local OUTLINE_MAP = { "", "OUTLINE", "THICKOUTLINE", "MONOCHROME", "MONOCHROME,OUTLINE", "MONOCHROME,THICKOUTLINE" }

local DEFAULT_FONT_SIZE = 18
local DEFAULT_TEXT_ALIGN = TEXT_ALIGN_MAP[2]
local DEFAULT_OUTLINE = OUTLINE_MAP[1]
local DEFAULT_SCROLL_HEIGHT = 260
local DEFAULT_SCROLL_WIDTH = 40
-- Gap between a message and its skill icon.
local ICON_GAP = 4
local DEFAULT_ANIMATION_STYLE = "Straight"
local DEFAULT_STICKY_ANIMATION_STYLE = "Pow"

-- Blizzard's placeholder icon for unknown skills.
local TEMP_TEXTURE_PATH = "Interface\\Icons\\Temp"

-- Stock font every string is reset to before the configured one is applied,
-- so an invalid font path falls back to readable text.
local FALLBACK_FONT_PATH = "Fonts\\FRIZQT__.TTF"


-------------------------------------------------------------------------------
-- Private variables.
-------------------------------------------------------------------------------

local animationFrame
local fontLoaderFrame

local displayEventCache = {}
local textureCache = {}
local animationData = { normal = {}, sticky = {} }

local animationStyles = {}
local stickyAnimationStyles = {}
local scrollAreas = {}
local externalScrollAreas = {}
local loadedFontStrings = {}

local numFontObjects = 0


-------------------------------------------------------------------------------
-- Scroll areas and styles.
-------------------------------------------------------------------------------

local function DefaultScrollAreaKey()
	return MikSBT.DEFAULT_SCROLL_AREA
end

local function IsScrollAreaActive(scrollArea)
	local saSettings = scrollAreas[scrollArea] or scrollAreas[DefaultScrollAreaKey()]
	return saSettings and not saSettings.disabled and true or false
end

local function IsScrollAreaIconShown(scrollArea)
	local saSettings = scrollAreas[scrollArea] or scrollAreas[DefaultScrollAreaKey()]
	return saSettings and not saSettings.skillIconsDisabled or false
end

-- Rebuilds the scroll area lookups from the current profile. A key set to
-- false in the profile marks a deleted built-in area.
local function UpdateScrollAreas()
	Compat.wipe(scrollAreas)
	Compat.wipe(externalScrollAreas)
	local profile = MSBTProfiles.currentProfile
	if not profile then
		return
	end
	local saKey, saSettings
	for saKey, saSettings in pairs(profile.scrollAreas) do
		if type(saSettings) == "table" then
			scrollAreas[saKey] = saSettings
			externalScrollAreas[saKey] = saSettings.name or saKey
		end
	end
end

local function NewStyle(initHandler, availableDirections, availableBehaviors, localizationTable)
	return {
		initHandler = initHandler,
		availableDirections = availableDirections,
		availableBehaviors = availableBehaviors,
		localizationTable = localizationTable,
	}
end

local function RegisterAnimationStyle(styleID, initHandler, availableDirections, availableBehaviors, localizationTable)
	if not animationStyles[styleID] and initHandler then
		animationStyles[styleID] = NewStyle(initHandler, availableDirections, availableBehaviors, localizationTable)
	end
end

local function RegisterStickyAnimationStyle(styleID, initHandler, availableDirections, availableBehaviors, localizationTable)
	if not stickyAnimationStyles[styleID] and initHandler then
		stickyAnimationStyles[styleID] = NewStyle(initHandler, availableDirections, availableBehaviors, localizationTable)
	end
end

local function IterateScrollAreas()
	return pairs(externalScrollAreas)
end


-------------------------------------------------------------------------------
-- Scroll area anchoring.
--
-- A scroll area's saved position is `point`, `offsetX`, `offsetY`:
--   * point nil or "CENTER": the MSBT scheme, the area's bottom-left corner
--     relative to the centre of UIParent (built-in defaults use this);
--   * one of TOPLEFT, TOP, TOPRIGHT, BOTTOMLEFT, BOTTOM, BOTTOMRIGHT: the
--     area's own `point` relative to the same point of UIParent, as a
--     SetPoint(point, UIParent, point, x, y) would place it.
-- Move mode picks the point the ElvUI way (E:CalculateMoverPoints): the
-- vertical half and the horizontal third the area's centre lies in, so the
-- stored offset is small and measured from the nearest edge or corner and
-- survives a resolution or UI scale change far better than a centre offset.
-- The display always works in the MSBT scheme; ResolveScrollAreaOffsets
-- converts at display time against the current screen size.
-------------------------------------------------------------------------------

-- UIParent size from its edges: on the 1.12.1 client GetWidth/GetHeight of an
-- anchor-sized frame comes back multiplied by the UI scale.
local function GetScreenSize()
	local width = UIParent:GetRight() or 0
	local height = UIParent:GetTop() or 0
	return width - (UIParent:GetLeft() or 0), height - (UIParent:GetBottom() or 0)
end

local function ScrollAreaSize(saSettings)
	return saSettings.scrollWidth or DEFAULT_SCROLL_WIDTH, saSettings.scrollHeight or DEFAULT_SCROLL_HEIGHT
end

-- Converts a point-relative position to the bottom-left corner relative to the
-- screen centre, for an area of the given size.
local function PointToCenterOffsets(point, x, y, width, height)
	if not point or point == "CENTER" then
		return x, y
	end
	local screenWidth, screenHeight = GetScreenSize()
	local left, bottom
	if string.find(point, "^TOP") then
		bottom = screenHeight + y - height
	else
		bottom = y
	end
	if string.find(point, "LEFT$") then
		left = x
	elseif string.find(point, "RIGHT$") then
		left = screenWidth + x - width
	else
		left = screenWidth / 2 + x - width / 2
	end
	return left - screenWidth / 2, bottom - screenHeight / 2
end

-- Offsets of an area's `point` from the same point of the screen, given the
-- area's absolute bottom-left corner.
local function OffsetsFromPoint(point, left, bottom, width, height, screenWidth, screenHeight)
	local x, y
	if string.find(point, "^TOP") then
		y = bottom + height - screenHeight
	else
		y = bottom
	end
	if string.find(point, "LEFT$") then
		x = left
	elseif string.find(point, "RIGHT$") then
		x = left + width - screenWidth
	else
		x = left + width / 2 - screenWidth / 2
	end
	return math.floor(x + 0.5), math.floor(y + 0.5)
end

-- Picks the nearest edge/corner point for an area whose bottom-left corner is
-- at (centerOffsetX, centerOffsetY) from the screen centre, and returns the
-- point with its rounded offsets. Same thresholds as ElvUI: top/bottom half,
-- left/middle/right third, judged by the area's centre.
local function CalculateAnchor(centerOffsetX, centerOffsetY, width, height)
	local screenWidth, screenHeight = GetScreenSize()
	local left = screenWidth / 2 + centerOffsetX
	local bottom = screenHeight / 2 + centerOffsetY
	local centerX = left + width / 2
	local point
	if bottom + height / 2 >= screenHeight / 2 then
		point = "TOP"
	else
		point = "BOTTOM"
	end
	if centerX >= screenWidth * 2 / 3 then
		point = point .. "RIGHT"
	elseif centerX <= screenWidth / 3 then
		point = point .. "LEFT"
	end
	local x, y = OffsetsFromPoint(point, left, bottom, width, height, screenWidth, screenHeight)
	return point, x, y
end

-- The area's bottom-left corner relative to the screen centre.
local function ResolveScrollAreaOffsets(saSettings)
	local width, height = ScrollAreaSize(saSettings)
	return PointToCenterOffsets(saSettings.point, saSettings.offsetX or 0, saSettings.offsetY or 0, width, height)
end

-- Stores a new position given as the bottom-left corner relative to the
-- screen centre, anchored to the nearest edge/corner.
local function AnchorScrollArea(saSettings, centerOffsetX, centerOffsetY)
	local width, height = ScrollAreaSize(saSettings)
	saSettings.point, saSettings.offsetX, saSettings.offsetY = CalculateAnchor(centerOffsetX, centerOffsetY, width, height)
end

-- Re-expresses the current position relative to another point without moving
-- the area (nil or "CENTER" selects the MSBT scheme).
local function SetScrollAreaPoint(saSettings, point)
	local centerOffsetX, centerOffsetY = ResolveScrollAreaOffsets(saSettings)
	if not point or point == "CENTER" then
		saSettings.point = nil
		saSettings.offsetX = math.floor(centerOffsetX + 0.5)
		saSettings.offsetY = math.floor(centerOffsetY + 0.5)
		return
	end
	local width, height = ScrollAreaSize(saSettings)
	local screenWidth, screenHeight = GetScreenSize()
	saSettings.point = point
	saSettings.offsetX, saSettings.offsetY = OffsetsFromPoint(point, screenWidth / 2 + centerOffsetX,
		screenHeight / 2 + centerOffsetY, width, height, screenWidth, screenHeight)
end


-------------------------------------------------------------------------------
-- Font strings.
-------------------------------------------------------------------------------

-- Creates a pooled font string. When db.global.privateFontObjects is set, the
-- string gets its own Font object: on a client where SetTextColor writes
-- through to the shared font object, this keeps the colors of simultaneous
-- strings apart. The Font object always gets the stock fallback face, never a
-- configured path: Unreal Azeroth's Font:SetFont only looks up a face the
-- client already has loaded, and an addon font path leaves a fresh Font object
-- without any face, so its strings render nothing (width 0).
local function CreateDisplayFontString()
	local fontString = animationFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	local db = MikSBT.db
	if db and db.global.privateFontObjects and CreateFont then
		numFontObjects = numFontObjects + 1
		local fontObject = CreateFont("MSBTFontObject" .. numFontObjects)
		pcall(fontObject.SetFont, fontObject, FALLBACK_FONT_PATH, DEFAULT_FONT_SIZE)
		pcall(fontString.SetFontObject, fontString, fontObject)
	end
	return fontString
end

local function ApplyFont(fontString, fontPath, fontSize, fontOutline)
	if fontPath ~= FALLBACK_FONT_PATH then
		pcall(fontString.SetFont, fontString, FALLBACK_FONT_PATH, fontSize, fontOutline)
	end
	pcall(fontString.SetFont, fontString, fontPath, fontSize, fontOutline)
end
module.ApplyFont = ApplyFont

-- Loads a font into a hidden font string so it is ready before first use.
local function LoadFont(fontName)
	local fontPath = MSBTMedia.fonts[fontName]
	if not fontPath or loadedFontStrings[fontName] then
		return
	end
	fontLoaderFrame:Show()
	local fontString = fontLoaderFrame:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	fontString:SetPoint("BOTTOM", fontLoaderFrame, "BOTTOM", 0, 0)
	fontString:SetText("Font Loader")
	pcall(fontString.SetFont, fontString, fontPath, DEFAULT_FONT_SIZE, DEFAULT_OUTLINE)
	fontString:SetText("")
	fontString:SetAlpha(0)
	loadedFontStrings[fontName] = fontString
	fontLoaderFrame:Hide()
end


-------------------------------------------------------------------------------
-- Display.
-------------------------------------------------------------------------------

local function HideDisplayEvent(displayEvent)
	displayEvent.fontString:SetAlpha(0)
	if displayEvent.texture then
		displayEvent.texture:SetAlpha(0)
	end
end

local function ReclaimTexture(displayEvent)
	local texture = displayEvent.texture
	if texture then
		texture:SetAlpha(0)
		texture:Hide()
		table.insert(textureCache, texture)
		displayEvent.texture = nil
	end
end

-- Positions a display event's text (the icon is anchored to the text).
local function PositionDisplayEvent(displayEvent)
	displayEvent.fontString:SetPoint(displayEvent.anchorPoint, animationFrame, "BOTTOM",
		displayEvent.offsetX + displayEvent.positionX, displayEvent.offsetY + displayEvent.positionY)
end

local function AttachIcon(displayEvent, saSettings, texturePath, fontSize, isSticky)
	local texture = displayEvent.texture
	if not texture then
		texture = table_remove(textureCache) or animationFrame:CreateTexture(nil, "ARTWORK")
	end
	texture:ClearAllPoints()
	texture:SetTexture(texturePath)
	texture:SetWidth(fontSize)
	texture:SetHeight(fontSize)
	texture:SetTexCoord(0.125, 0.875, 0.125, 0.875)
	if saSettings.iconAlign == "Right" then
		texture:SetPoint("LEFT", displayEvent.fontString, "RIGHT", ICON_GAP, 0)
	else
		texture:SetPoint("RIGHT", displayEvent.fontString, "LEFT", -ICON_GAP, 0)
	end
	pcall(texture.SetDrawLayer, texture, isSticky and "OVERLAY" or "ARTWORK")
	texture:SetAlpha(0)
	texture:Show()
	displayEvent.texture = texture
end

-- Creates a display event. When the scroll area already shows the maximum
-- number of animations, the oldest one is reused.
local function Display(message, saSettings, isSticky, colorR, colorG, colorB, fontSize, fontPath, outlineIndex, fontAlpha, texturePath)
	local animStyleSettings, direction, behavior, textAlignIndex
	if isSticky then
		animStyleSettings = stickyAnimationStyles[saSettings.stickyAnimationStyle or DEFAULT_STICKY_ANIMATION_STYLE] or stickyAnimationStyles[DEFAULT_STICKY_ANIMATION_STYLE]
		direction = saSettings.stickyDirection
		behavior = saSettings.stickyBehavior
		textAlignIndex = saSettings.stickyTextAlignIndex
	else
		animStyleSettings = animationStyles[saSettings.animationStyle or DEFAULT_ANIMATION_STYLE] or animationStyles[DEFAULT_ANIMATION_STYLE]
		direction = saSettings.direction
		behavior = saSettings.behavior
		textAlignIndex = saSettings.textAlignIndex
	end
	if not animStyleSettings then
		return
	end

	local group = isSticky and animationData.sticky or animationData.normal
	if not group[saSettings] then
		group[saSettings] = {}
	end
	local animationArray = group[saSettings]

	-- Shown before any region is created: regions created under a hidden
	-- parent may not render on Unreal Azeroth.
	if not animationFrame:IsVisible() then
		animationFrame:Show()
	end

	local displayEvent
	if getn(animationArray) >= MAX_ANIMATIONS_PER_AREA then
		displayEvent = table_remove(animationArray, 1)
		HideDisplayEvent(displayEvent)
	else
		displayEvent = table_remove(displayEventCache) or { fontString = CreateDisplayFontString() }
	end

	local currentProfile = MSBTProfiles.currentProfile

	displayEvent.offsetX, displayEvent.offsetY = ResolveScrollAreaOffsets(saSettings)
	displayEvent.anchorPoint = TEXT_ALIGN_MAP[textAlignIndex or 2] or DEFAULT_TEXT_ALIGN
	displayEvent.scrollHeight = saSettings.scrollHeight or DEFAULT_SCROLL_HEIGHT
	displayEvent.scrollWidth = saSettings.scrollWidth or DEFAULT_SCROLL_WIDTH
	displayEvent.animationSpeed = (saSettings.animationSpeed or currentProfile.animationSpeed or 100) / 100
	displayEvent.masterAlpha = (fontAlpha or 100) / 100
	displayEvent.alpha = 1
	displayEvent.positionX = 0
	displayEvent.positionY = 0
	displayEvent.fontSize = fontSize or DEFAULT_FONT_SIZE

	local fontString = displayEvent.fontString
	fontString:ClearAllPoints()
	ApplyFont(fontString, fontPath or FALLBACK_FONT_PATH, displayEvent.fontSize, OUTLINE_MAP[outlineIndex or 1] or DEFAULT_OUTLINE)
	fontString:SetTextColor(colorR, colorG, colorB)
	pcall(fontString.SetDrawLayer, fontString, isSticky and "OVERLAY" or "ARTWORK")
	if not currentProfile.textShadowingDisabled then
		fontString:SetShadowColor(0, 0, 0, 1)
		fontString:SetShadowOffset(1, -1)
	else
		fontString:SetShadowColor(0, 0, 0, 0)
		fontString:SetShadowOffset(0, 0)
	end
	fontString:SetAlpha(0)
	fontString:SetText(message)
	fontString:Show()

	if texturePath and texturePath ~= TEMP_TEXTURE_PATH and not saSettings.skillIconsDisabled and not currentProfile.skillIconsDisabled then
		AttachIcon(displayEvent, saSettings, texturePath, displayEvent.fontSize, isSticky)
	else
		ReclaimTexture(displayEvent)
	end

	displayEvent.elapsedTime = 0
	displayEvent.timeSinceLastUpdate = 0
	displayEvent.scrollTime = DEFAULT_SCROLL_TIME
	displayEvent.fadePercent = DEFAULT_FADE_PERCENT
	displayEvent.animationComplete = false

	animStyleSettings.initHandler(displayEvent, animationArray, direction, behavior)
	-- Centre alignment centres text and icon together, not the text alone:
	-- the text moves away from its icon by half the icon's width. Read after
	-- the style's init, which may switch the anchor to an edge.
	if displayEvent.texture and displayEvent.anchorPoint == "BOTTOM" then
		local shift = (displayEvent.fontSize + ICON_GAP) / 2
		if saSettings.iconAlign == "Right" then
			shift = -shift
		end
		displayEvent.offsetX = displayEvent.offsetX + shift
	end
	PositionDisplayEvent(displayEvent)
	displayEvent.scrollTime = displayEvent.scrollTime / displayEvent.animationSpeed

	table.insert(animationArray, displayEvent)
end

-- Resolves a scroll area key or display name.
local function FindScrollArea(scrollArea)
	local saSettings = scrollAreas[scrollArea]
	if not saSettings then
		local _, settings
		for _, settings in pairs(scrollAreas) do
			if scrollArea == settings.name then
				saSettings = settings
			end
		end
	end
	return saSettings or scrollAreas[DefaultScrollAreaKey()]
end

-- Displays a message with the passed event (or trigger) settings, applying
-- the event -> scroll area -> profile font inheritance.
local function DisplayEvent(eventSettings, message, texturePath)
	local currentProfile = MSBTProfiles.currentProfile
	local saSettings = scrollAreas[eventSettings.scrollArea] or scrollAreas[DefaultScrollAreaKey()]
	if not saSettings or saSettings.disabled or not message then
		return
	end

	local fontSize, fontName, outlineIndex, fontAlpha, isSticky
	if eventSettings.isCrit then
		fontSize = eventSettings.fontSize or saSettings.critFontSize or currentProfile.critFontSize
		fontName = eventSettings.fontName or saSettings.critFontName or currentProfile.critFontName
		outlineIndex = eventSettings.outlineIndex or saSettings.critOutlineIndex or currentProfile.critOutlineIndex
		fontAlpha = eventSettings.fontAlpha or saSettings.critFontAlpha or currentProfile.critFontAlpha
		if not currentProfile.stickyCritsDisabled then
			isSticky = true
		end
	else
		fontSize = eventSettings.fontSize or saSettings.normalFontSize or currentProfile.normalFontSize
		fontName = eventSettings.fontName or saSettings.normalFontName or currentProfile.normalFontName
		outlineIndex = eventSettings.outlineIndex or saSettings.normalOutlineIndex or currentProfile.normalOutlineIndex
		fontAlpha = eventSettings.fontAlpha or saSettings.normalFontAlpha or currentProfile.normalFontAlpha
	end
	isSticky = isSticky or eventSettings.alwaysSticky

	if eventSettings.soundFile and eventSettings.soundFile ~= "" and not currentProfile.soundsDisabled then
		MSBTMedia.PlaySound(eventSettings.soundFile)
	end

	Display(message, saSettings, isSticky, eventSettings.colorR or 1, eventSettings.colorG or 1, eventSettings.colorB or 1,
		fontSize, MSBTMedia.fonts[fontName], outlineIndex, fontAlpha, texturePath)
end

-- Public API: displays a message from an external source. Colors are 0-255.
local function DisplayMessage(message, scrollArea, isSticky, colorR, colorG, colorB, fontSize, fontName, outlineIndex, texturePath)
	if not message or MSBTProfiles.IsModDisabled() or not MSBTProfiles.currentProfile then
		return
	end
	local saSettings = FindScrollArea(scrollArea)
	if not saSettings or saSettings.disabled then
		return
	end

	if colorR == nil or colorR < 0 or colorR > 255 then colorR = 255 end
	if colorG == nil or colorG < 0 or colorG > 255 then colorG = 255 end
	if colorB == nil or colorB < 0 or colorB > 255 then colorB = 255 end

	local currentProfile = MSBTProfiles.currentProfile
	if fontSize == nil or fontSize < 4 or fontSize > 38 then
		fontSize = saSettings.normalFontSize or currentProfile.normalFontSize
	end
	local fontPath = MSBTMedia.fonts[fontName] or MSBTMedia.fonts[saSettings.normalFontName or currentProfile.normalFontName]
	if not OUTLINE_MAP[outlineIndex or 0] then
		outlineIndex = saSettings.normalOutlineIndex or currentProfile.normalOutlineIndex
	end
	local fontAlpha = saSettings.normalFontAlpha or currentProfile.normalFontAlpha

	Display(message, saSettings, isSticky, colorR / 255, colorG / 255, colorB / 255, fontSize, fontPath, outlineIndex, fontAlpha, texturePath)
end


-------------------------------------------------------------------------------
-- Animation.
-------------------------------------------------------------------------------

local function AnimateEvent(displayEvent)
	local fontString = displayEvent.fontString
	local texture = displayEvent.texture
	local percentDone = displayEvent.elapsedTime / displayEvent.scrollTime

	if percentDone <= 1 then
		displayEvent.animationHandler(displayEvent, percentDone)
		local fadePercent = displayEvent.fadePercent
		if percentDone >= fadePercent then
			displayEvent.alpha = (1 - percentDone) / (1 - fadePercent)
		end
		PositionDisplayEvent(displayEvent)
		local alpha = displayEvent.masterAlpha * displayEvent.alpha
		fontString:SetAlpha(alpha)
		if texture then
			texture:SetAlpha(alpha)
		end
	else
		HideDisplayEvent(displayEvent)
		displayEvent.animationComplete = true
	end
end

local function OnUpdateAnimationFrame(frame, elapsed)
	local allInactive = true
	local _, animationArray, displayEvents
	for _, animationArray in pairs(animationData) do
		for _, displayEvents in pairs(animationArray) do
			local numEvents = getn(displayEvents)
			local i
			for i = 1, numEvents do
				local displayEvent = displayEvents[i]
				displayEvent.timeSinceLastUpdate = displayEvent.timeSinceLastUpdate + elapsed
				if displayEvent.timeSinceLastUpdate >= ANIMATION_DELAY then
					displayEvent.elapsedTime = displayEvent.elapsedTime + displayEvent.timeSinceLastUpdate
					AnimateEvent(displayEvent)
					displayEvent.timeSinceLastUpdate = 0
				end
				allInactive = false
			end
			for i = numEvents, 1, -1 do
				local displayEvent = displayEvents[i]
				if displayEvent.animationComplete then
					table_remove(displayEvents, i)
					ReclaimTexture(displayEvent)
					displayEvent.animationComplete = false
					table.insert(displayEventCache, displayEvent)
				end
			end
		end
	end
	if allInactive then
		frame:Hide()
	end
end


-------------------------------------------------------------------------------
-- Initialization.
-------------------------------------------------------------------------------

animationFrame = Util.CreateUpdateFrame(OnUpdateAnimationFrame, "MSBTAnimationFrame")
animationFrame:SetFrameStrata("HIGH")
animationFrame:SetWidth(1)
animationFrame:SetHeight(1)
animationFrame:SetPoint("BOTTOM", UIParent, "CENTER", 0, 0)

fontLoaderFrame = CreateFrame("Frame", nil, UIParent)
fontLoaderFrame:SetPoint("BOTTOM", UIParent, "BOTTOM", 0, 0)
fontLoaderFrame:SetWidth(1)
fontLoaderFrame:SetHeight(1)
fontLoaderFrame:Hide()


module.scrollAreas = scrollAreas
module.animationStyles = animationStyles
module.stickyAnimationStyles = stickyAnimationStyles
module.OUTLINE_MAP = OUTLINE_MAP
module.TEXT_ALIGN_MAP = TEXT_ALIGN_MAP
module.DEFAULT_SCROLL_HEIGHT = DEFAULT_SCROLL_HEIGHT
module.DEFAULT_SCROLL_WIDTH = DEFAULT_SCROLL_WIDTH
module.ICON_GAP = ICON_GAP
module.IsScrollAreaActive = IsScrollAreaActive
module.IsScrollAreaIconShown = IsScrollAreaIconShown
module.GetScreenSize = GetScreenSize
module.ResolveScrollAreaOffsets = ResolveScrollAreaOffsets
module.AnchorScrollArea = AnchorScrollArea
module.SetScrollAreaPoint = SetScrollAreaPoint
module.UpdateScrollAreas = UpdateScrollAreas
module.RegisterAnimationStyle = RegisterAnimationStyle
module.RegisterStickyAnimationStyle = RegisterStickyAnimationStyle
module.IterateScrollAreas = IterateScrollAreas
module.LoadFont = LoadFont
module.DisplayMessage = DisplayMessage
module.DisplayEvent = DisplayEvent
module.FindScrollArea = FindScrollArea

MikSBT.RegisterAnimationStyle = RegisterAnimationStyle
MikSBT.RegisterStickyAnimationStyle = RegisterStickyAnimationStyle
