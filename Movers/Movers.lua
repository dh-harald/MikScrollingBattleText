-------------------------------------------------------------------------------
-- Title: Mik's Scrolling Battle Text Movers
--
-- Move mode for the scroll areas (/msbt move), modelled on ElvUI-UA's
-- /moveui: one draggable, labelled box per scroll area, an alignment grid,
-- arrow key nudging and a small control panel with a mouse-clickable exit.
--
-- A dropped or nudged area is anchored to the nearest screen edge or corner
-- (point + offsetX/offsetY, see MikSBT.Animations.AnchorScrollArea), the way
-- ElvUI's movers save their positions. The drop position is measured from the
-- box's edges, never from GetPoint (which returns the anchor frame as a name
-- on Unreal Azeroth), and the box is left where it was released.
--
-- Each box shows the area's real footprint, not just its anchor column: text
-- is anchored to the column's left edge, middle or right edge by its
-- alignment and grows outward from there, so the box is widened by a measured
-- sample message (plus the skill icon) on the side the text grows to, and
-- raised by a line of text above the top edge. The column itself is not
-- drawn; positions are always saved for it, offset by the box's reach.
--
-- Dragging (ElvUI-UA / UnrealUI recipe): the move starts from OnMouseDown
-- with a throwaway StartMoving/StopMovingOrSizing pair first, which collapses
-- any multi-point anchor, and the engine delivers the stop.
-------------------------------------------------------------------------------

local _G = _G or getfenv()

local module = {}
MikSBT.Movers = module

local L = MikSBT.L
local Compat = MikSBT.Compat
local Util = MikSBT.Util
local MSBTAnimations = MikSBT.Animations

local math_floor = math.floor

local HANDLE_LEVEL = 100
local PANEL_WIDTH = 320
local PANEL_HEIGHT = 190

local COLOR_NORMAL = { 0.5, 0.5, 0.6 }
local COLOR_SELECTED = { 1, 0.1, 0.1 }
local COLOR_HOVER = { 1, 1, 0 }

-- Representative combat text for the footprint estimate. Measured, never shown.
local SAMPLE_TEXT = "-12345 (Shadow Bolt)"
local FALLBACK_FONT_PATH = "Fonts\\FRIZQT__.TTF"

local boxes = {}
local unlocked = false
local selectedKey
local panel, keyFrame, grid, readoutFrame
local draggingBox


-------------------------------------------------------------------------------
-- Helpers.
-------------------------------------------------------------------------------

local function Round(value)
	return math_floor(value + 0.5)
end

local function Profile()
	return MikSBT.Profiles.currentProfile
end

local function SetBorder(box, color)
	pcall(box.SetBackdropBorderColor, box, color[1], color[2], color[3], 1)
end

local function BoxColor(key)
	return key == selectedKey and COLOR_SELECTED or COLOR_NORMAL
end

-- Bottom-left corner of a frame relative to the screen centre, from its edges.
local function MeasureOffsets(frame)
	local screenWidth, screenHeight = MSBTAnimations.GetScreenSize()
	local left, bottom = frame:GetLeft(), frame:GetBottom()
	if not left or not bottom then
		return nil
	end
	return Round(left - screenWidth / 2), Round(bottom - screenHeight / 2)
end

-- Bottom-left corner of a box's anchor column relative to the screen centre.
local function AreaOffsets(box)
	local x, y = MeasureOffsets(box)
	if not x then
		return nil
	end
	return x + (box.reachLeft or 0), y
end

-- "POINT  x, y" as saved for a scroll area.
local function PositionText(settings)
	return string.format("%s  %d, %d", settings.point or "CENTER", settings.offsetX or 0, settings.offsetY or 0)
end

local function IsLeftMouseButton(a, b)
	local button
	if type(a) == "string" then
		button = a
	elseif type(b) == "string" then
		button = b
	else
		button = _G.arg1
	end
	return button == nil or button == "LeftButton"
end

local function ResolveKey(a, b)
	if type(a) == "string" then return a end
	if type(b) == "string" then return b end
	if type(_G.arg1) == "string" then return _G.arg1 end
end


-------------------------------------------------------------------------------
-- Boxes.
-------------------------------------------------------------------------------

-- While dragging, the label shows the anchor the drop would save.
local function UpdateLabel(box)
	local settings = MSBTAnimations.scrollAreas[box.key]
	if not settings or not box.label then
		return
	end
	local shown = settings
	local x, y = AreaOffsets(box)
	if draggingBox == box and x then
		shown = { scrollWidth = settings.scrollWidth, scrollHeight = settings.scrollHeight }
		MSBTAnimations.AnchorScrollArea(shown, x, y)
	end
	box.label:SetText(string.format("%s\n%s", settings.name or box.key, PositionText(shown)))
end

-- Width of the sample text in the given font. The font string lives on the
-- shown box at zero alpha, so it measures on both clients; an estimate stands
-- in when the client reports no width (a font that failed to load).
local function SampleWidth(box, fontName, fontSize, outlineIndex)
	local fontString = box.measure
	if not fontString then
		fontString = box:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
		fontString:SetPoint("BOTTOMLEFT", box, "BOTTOMLEFT", 0, 0)
		fontString:SetAlpha(0)
		box.measure = fontString
	end
	local fontPath = MikSBT.Media.fonts[fontName or ""] or FALLBACK_FONT_PATH
	MSBTAnimations.ApplyFont(fontString, fontPath, fontSize, MSBTAnimations.OUTLINE_MAP[outlineIndex or 1] or "")
	fontString:SetText(SAMPLE_TEXT)
	local ok, width = pcall(fontString.GetStringWidth, fontString)
	if not ok or type(width) ~= "number" or width <= 0 then
		width = string.len(SAMPLE_TEXT) * fontSize * 0.55
	end
	return width
end

-- How far normal (isSticky false) or sticky (crit) messages reach beyond the
-- anchor column: left, right and above. The alignment anchor sits on the
-- column's left edge, middle or right edge (MikSBT.Animations), alternating
-- Angled and Horizontal styles use both edge anchors, and the icon adds its
-- size plus the gap on its side, or half of that on both sides under centre
-- alignment, which centres text and icon together.
local function MessageReach(box, settings, isSticky)
	local profile = Profile()
	local fontName, fontSize, outlineIndex, alignIndex, style, direction
	if isSticky then
		fontName = settings.critFontName or profile.critFontName
		fontSize = settings.critFontSize or profile.critFontSize
		outlineIndex = settings.critOutlineIndex or profile.critOutlineIndex
		alignIndex = settings.stickyTextAlignIndex
		style = settings.stickyAnimationStyle
		direction = settings.stickyDirection
	else
		fontName = settings.normalFontName or profile.normalFontName
		fontSize = settings.normalFontSize or profile.normalFontSize
		outlineIndex = settings.normalOutlineIndex or profile.normalOutlineIndex
		alignIndex = settings.textAlignIndex
		style = settings.animationStyle
		direction = settings.direction
	end
	fontSize = fontSize or 18
	local width = SampleWidth(box, fontName, fontSize, outlineIndex)

	local left, right = 0, 0
	local anchor = MSBTAnimations.TEXT_ALIGN_MAP[alignIndex or 2]
	-- Alternating styles move the anchor to either edge, so the alignment's
	-- centre case never applies to them.
	local isAlternating = (style == "Angled" or style == "Horizontal") and direction ~= "Left" and direction ~= "Right"
	if isAlternating then
		left, right = width, width
	elseif anchor == "BOTTOMLEFT" then
		right = width
	elseif anchor == "BOTTOMRIGHT" then
		left = width
	else
		left, right = width / 2, width / 2
	end

	if not profile.skillIconsDisabled and MSBTAnimations.IsScrollAreaIconShown(box.key) then
		local iconWidth = fontSize + MSBTAnimations.ICON_GAP
		if anchor == "BOTTOM" and not isAlternating then
			left, right = left + iconWidth / 2, right + iconWidth / 2
		elseif settings.iconAlign == "Right" then
			right = right + iconWidth
		else
			left = left + iconWidth
		end
	end
	return left, right, fontSize
end

-- Footprint reach of an area: the larger of its normal and sticky messages.
local function AreaReach(box, settings)
	local left, right, top = MessageReach(box, settings, false)
	local stickyLeft, stickyRight, stickyTop = MessageReach(box, settings, true)
	return Round(math.max(left, stickyLeft)), Round(math.max(right, stickyRight)), Round(math.max(top, stickyTop))
end

local function PlaceBox(box)
	local settings = MSBTAnimations.scrollAreas[box.key]
	if not settings then
		return
	end
	local width = settings.scrollWidth or MSBTAnimations.DEFAULT_SCROLL_WIDTH
	local height = settings.scrollHeight or MSBTAnimations.DEFAULT_SCROLL_HEIGHT
	local left, right, top = AreaReach(box, settings)
	box.reachLeft = left

	box:ClearAllPoints()
	box:SetWidth(width + left + right)
	box:SetHeight(height + top)
	local x, y = MSBTAnimations.ResolveScrollAreaOffsets(settings)
	box:SetPoint("BOTTOMLEFT", UIParent, "CENTER", x - left, y)
	UpdateLabel(box)
end

local function SaveBox(box)
	local settings = MSBTAnimations.scrollAreas[box.key]
	local x, y = AreaOffsets(box)
	if settings and x then
		MSBTAnimations.AnchorScrollArea(settings, x, y)
	end
	UpdateLabel(box)
	if panel then
		module.UpdatePanel()
	end
	if MikSBT.Config then
		MikSBT.Config.NotifyChange()
	end
end

local function StartDrag(box)
	if draggingBox then
		return
	end
	if not pcall(box.SetMovable, box, true) then
		return
	end
	if pcall(box.StartMoving, box) then
		pcall(box.StopMovingOrSizing, box)
	end
	if pcall(box.StartMoving, box) then
		draggingBox = box
		readoutFrame:Show()
	end
end

local function StopDrag(box)
	if draggingBox ~= box then
		return
	end
	draggingBox = nil
	readoutFrame:Hide()
	pcall(box.StopMovingOrSizing, box)
	SaveBox(box)
end

local function Select(key)
	selectedKey = key
	local k, box
	for k, box in pairs(boxes) do
		SetBorder(box, BoxColor(k))
	end
	if panel then
		module.UpdatePanel()
	end
end

local function CreateBox(key)
	local box = CreateFrame("Button", "MSBTMover_" .. key, UIParent)
	box.key = key
	box:SetFrameStrata("DIALOG")
	box:SetFrameLevel(HANDLE_LEVEL)
	box:SetClampedToScreen(true)
	box:EnableMouse(true)
	pcall(box.RegisterForDrag, box, "LeftButton")
	pcall(box.SetBackdrop, box, {
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	pcall(box.SetBackdropColor, box, 0, 0.6, 1, 0.3)
	SetBorder(box, COLOR_NORMAL)

	local label = box:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	label:SetPoint("CENTER", box, "CENTER", 0, 0)
	label:SetJustifyH("CENTER")
	box.label = label

	box:SetScript("OnMouseDown", function(a, b)
		if not IsLeftMouseButton(a, b) then return end
		Select(box.key)
		StartDrag(box)
	end)
	box:SetScript("OnMouseUp", function(a, b)
		if not IsLeftMouseButton(a, b) then return end
		StopDrag(box)
	end)
	box:SetScript("OnDragStart", function()
		Select(box.key)
		StartDrag(box)
	end)
	box:SetScript("OnDragStop", function()
		StopDrag(box)
	end)
	box:SetScript("OnEnter", function() SetBorder(box, COLOR_HOVER) end)
	box:SetScript("OnLeave", function() SetBorder(box, BoxColor(box.key)) end)
	box:Hide()
	boxes[key] = box
	return box
end

-- Creates, places or hides the boxes to match the current scroll areas.
local function SyncBoxes()
	local key, box
	for key, box in pairs(boxes) do
		if not MSBTAnimations.scrollAreas[key] then
			box:Hide()
			boxes[key] = nil
		end
	end
	for key in pairs(MSBTAnimations.scrollAreas) do
		box = boxes[key] or CreateBox(key)
		if unlocked then
			box:Show()
			PlaceBox(box)
			SetBorder(box, BoxColor(key))
		end
	end
	if not selectedKey or not MSBTAnimations.scrollAreas[selectedKey] then
		selectedKey = next(MSBTAnimations.scrollAreas)
	end
end


-------------------------------------------------------------------------------
-- Nudging.
-------------------------------------------------------------------------------

-- The anchor is recomputed after every step, so a nudge across a third or
-- half boundary switches the area to the new nearest point.
local function Nudge(dx, dy)
	local settings = selectedKey and MSBTAnimations.scrollAreas[selectedKey]
	local box = selectedKey and boxes[selectedKey]
	if not settings or not box then
		return
	end
	local x, y = MSBTAnimations.ResolveScrollAreaOffsets(settings)
	MSBTAnimations.AnchorScrollArea(settings, x + dx, y + dy)
	PlaceBox(box)
	if panel then
		module.UpdatePanel()
	end
end

local function CreateKeyFrame()
	keyFrame = CreateFrame("Frame", "MSBTMoverKeys", UIParent)
	keyFrame:SetAllPoints(UIParent)
	keyFrame:SetFrameStrata("FULLSCREEN_DIALOG")
	pcall(keyFrame.EnableKeyboard, keyFrame, true)
	keyFrame:EnableMouse(false)
	keyFrame:SetScript("OnKeyDown", function(a, b)
		local key = ResolveKey(a, b)
		local step = (IsShiftKeyDown and IsShiftKeyDown()) and 10 or 1
		if key == "LEFT" then
			Nudge(-step, 0)
		elseif key == "RIGHT" then
			Nudge(step, 0)
		elseif key == "UP" then
			Nudge(0, step)
		elseif key == "DOWN" then
			Nudge(0, -step)
		elseif key == "ESCAPE" then
			module.Lock()
		end
	end)
	keyFrame:Hide()
end


-------------------------------------------------------------------------------
-- Grid.
-------------------------------------------------------------------------------

local function CreateGridLine(parent, isVertical, offset, isCentre)
	local tex = parent:CreateTexture(nil, "BACKGROUND")
	if isCentre then
		tex:SetTexture(1, 0, 0, 0.7)
	else
		tex:SetTexture(0, 0, 0, 0.5)
	end
	if isVertical then
		tex:SetWidth(1)
		tex:SetPoint("TOPLEFT", parent, "TOPLEFT", offset, 0)
		tex:SetPoint("BOTTOMLEFT", parent, "BOTTOMLEFT", offset, 0)
	else
		tex:SetHeight(1)
		tex:SetPoint("TOPLEFT", parent, "TOPLEFT", 0, -offset)
		tex:SetPoint("TOPRIGHT", parent, "TOPRIGHT", 0, -offset)
	end
end

local function GridDivisions()
	local divisions = tonumber(MikSBT.db.global.gridSize) or 64
	if divisions < 4 then divisions = 4 end
	if divisions > 256 then divisions = 256 end
	return divisions
end

-- Lines drawn outwards from the centre so the centre lines are exact.
local function BuildGrid()
	local divisions = GridDivisions()
	if grid and grid.builtFor == divisions then
		return
	end
	if grid then
		grid:Hide()
	end
	grid = CreateFrame("Frame", nil, UIParent)
	grid:SetAllPoints(UIParent)
	grid:SetFrameStrata("BACKGROUND")
	grid:EnableMouse(false)
	grid:Show()
	local width, height = MSBTAnimations.GetScreenSize()
	local step = width / divisions
	if step < 4 then step = 4 end
	local centreX, centreY = width / 2, height / 2
	local offset = 0
	while offset <= centreX do
		CreateGridLine(grid, true, centreX + offset, offset == 0)
		if offset ~= 0 then CreateGridLine(grid, true, centreX - offset, false) end
		offset = offset + step
	end
	offset = 0
	while offset <= centreY do
		CreateGridLine(grid, false, centreY + offset, offset == 0)
		if offset ~= 0 then CreateGridLine(grid, false, centreY - offset, false) end
		offset = offset + step
	end
	grid.builtFor = divisions
end


-------------------------------------------------------------------------------
-- Control panel.
-------------------------------------------------------------------------------

local function CreatePanelButton(parent, label, width, onClick)
	local button = CreateFrame("Button", nil, parent)
	button:SetWidth(width)
	button:SetHeight(22)
	button:EnableMouse(true)
	button:SetFrameLevel(parent:GetFrameLevel() + 10)
	pcall(button.SetBackdrop, button, {
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	pcall(button.SetBackdropColor, button, 0.15, 0.15, 0.15, 1)
	pcall(button.SetBackdropBorderColor, button, 0, 0, 0, 1)
	local text = button:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	text:SetPoint("CENTER", button, "CENTER", 0, 0)
	text:SetText(label)
	text:SetTextColor(1, 0.82, 0)
	button:SetScript("OnEnter", function() pcall(button.SetBackdropBorderColor, button, 1, 0.82, 0, 1) end)
	button:SetScript("OnLeave", function() pcall(button.SetBackdropBorderColor, button, 0, 0, 0, 1) end)
	button:SetScript("OnClick", onClick)
	return button
end

local function SavePanelPosition()
	local x, y = MeasureOffsets(panel)
	if x then
		MikSBT.db.global.moverPanel.x = x
		MikSBT.db.global.moverPanel.y = y
	end
end

local function PlacePanel()
	local saved = MikSBT.db.global.moverPanel
	panel:ClearAllPoints()
	if saved.x and saved.y then
		panel:SetPoint("BOTTOMLEFT", UIParent, "CENTER", saved.x, saved.y)
	else
		panel:SetPoint("TOP", UIParent, "TOP", 0, -120)
	end
end

-- Icon for the preview samples when the area shows skill icons, so the
-- samples cover the same footprint as the box (the icon hangs off the text on
-- the iconAlign side). Taken from the spellbook so the path is the client's
-- own, with the exact case Unreal Azeroth requires.
local function PreviewIcon()
	if Profile().skillIconsDisabled or not MSBTAnimations.IsScrollAreaIconShown(selectedKey) then
		return nil
	end
	if type(GetSpellTexture) ~= "function" then
		return nil
	end
	local ok, texture = pcall(GetSpellTexture, 1, "spell")
	if ok and type(texture) == "string" and texture ~= "" then
		return texture
	end
	return nil
end

local function PreviewSelected()
	local settings = selectedKey and MSBTAnimations.scrollAreas[selectedKey]
	if not settings then
		return
	end
	-- With an icon the samples alternate icon / no icon, so both layouts show.
	local name = settings.name or selectedKey
	local icon = PreviewIcon()
	local i
	for i = 1, 3 do
		MikSBT.DisplayMessage(name .. " " .. i, selectedKey, false, 255, 255, 255, nil, nil, nil, i ~= 2 and icon or nil)
	end
	MikSBT.DisplayMessage(name .. " " .. L["Sticky"], selectedKey, true, 255, 210, 0, nil, nil, nil, icon)
	if icon then
		MikSBT.DisplayMessage(name .. " " .. L["Sticky"], selectedKey, true, 255, 210, 0)
	end
end

local function ResetSelected()
	local defaults = MikSBT.Defaults.profile.scrollAreas[selectedKey or ""]
	local settings = selectedKey and MSBTAnimations.scrollAreas[selectedKey]
	if not settings then
		return
	end
	settings.point = defaults and defaults.point
	settings.offsetX = defaults and defaults.offsetX or 0
	settings.offsetY = defaults and defaults.offsetY or 0
	SyncBoxes()
	module.UpdatePanel()
end

local function ResetAll()
	local key, settings
	for key, settings in pairs(MSBTAnimations.scrollAreas) do
		local defaults = MikSBT.Defaults.profile.scrollAreas[key]
		settings.point = defaults and defaults.point
		settings.offsetX = defaults and defaults.offsetX or 0
		settings.offsetY = defaults and defaults.offsetY or 0
	end
	SyncBoxes()
	module.UpdatePanel()
	MikSBT:Print(L["All scroll area positions reset."])
end

local function CreatePanel()
	panel = CreateFrame("Frame", "MSBTMoverPanel", UIParent)
	panel:SetWidth(PANEL_WIDTH)
	panel:SetHeight(PANEL_HEIGHT)
	panel:SetFrameStrata("FULLSCREEN_DIALOG")
	panel:SetFrameLevel(200)
	panel:EnableMouse(true)
	panel:SetClampedToScreen(true)
	panel:SetMovable(true)
	pcall(panel.SetBackdrop, panel, {
		bgFile = "Interface\\Buttons\\WHITE8x8",
		edgeFile = "Interface\\Buttons\\WHITE8x8",
		edgeSize = 1,
	})
	pcall(panel.SetBackdropColor, panel, 0.06, 0.06, 0.06, 0.92)
	pcall(panel.SetBackdropBorderColor, panel, 0, 0, 0, 1)

	-- Full-panel drag handle, below the buttons.
	local dragHandle = CreateFrame("Button", nil, panel)
	dragHandle:SetAllPoints(panel)
	dragHandle:SetFrameLevel(panel:GetFrameLevel() + 1)
	dragHandle:EnableMouse(true)
	pcall(dragHandle.RegisterForDrag, dragHandle, "LeftButton")
	local function PanelStart()
		if pcall(panel.StartMoving, panel) then pcall(panel.StopMovingOrSizing, panel) end
		pcall(panel.StartMoving, panel)
	end
	local function PanelStop()
		pcall(panel.StopMovingOrSizing, panel)
		SavePanelPosition()
	end
	dragHandle:SetScript("OnMouseDown", function(a, b) if IsLeftMouseButton(a, b) then PanelStart() end end)
	dragHandle:SetScript("OnMouseUp", function(a, b) if IsLeftMouseButton(a, b) then PanelStop() end end)
	dragHandle:SetScript("OnDragStart", PanelStart)
	dragHandle:SetScript("OnDragStop", PanelStop)

	local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOP", panel, "TOP", 0, -8)
	title:SetText(L["MSBT Scroll Areas"])

	local hint = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
	hint:SetPoint("TOP", title, "BOTTOM", 0, -6)
	hint:SetWidth(PANEL_WIDTH - 20)
	hint:SetJustifyH("CENTER")
	hint:SetText(L["Drag a scroll area to move it. Click one to select it; the arrow keys nudge the selected area (Shift: 10 pixels)."])

	local selected = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	selected:SetPoint("TOP", hint, "BOTTOM", 0, -8)
	panel.selectedText = selected

	local x0 = 10
	local buttonWidth = (PANEL_WIDTH - 30) / 2
	local b1 = CreatePanelButton(panel, L["Preview"], buttonWidth, PreviewSelected)
	b1:SetPoint("TOPLEFT", panel, "TOPLEFT", x0, -96)
	local b2 = CreatePanelButton(panel, L["Settings"], buttonWidth, function()
		module.Lock()
		if MikSBT.Config then MikSBT.Config.OpenScrollArea(selectedKey) end
	end)
	b2:SetPoint("LEFT", b1, "RIGHT", 10, 0)
	local b3 = CreatePanelButton(panel, L["Reset Selected"], buttonWidth, ResetSelected)
	b3:SetPoint("TOPLEFT", b1, "BOTTOMLEFT", 0, -6)
	local b4 = CreatePanelButton(panel, L["Reset All"], buttonWidth, ResetAll)
	b4:SetPoint("LEFT", b3, "RIGHT", 10, 0)
	local b5 = CreatePanelButton(panel, L["Lock"], PANEL_WIDTH - 20, function() module.Lock() end)
	b5:SetPoint("TOPLEFT", b3, "BOTTOMLEFT", 0, -6)

	panel:Hide()
end

function module.UpdatePanel()
	if not panel then
		return
	end
	local settings = selectedKey and MSBTAnimations.scrollAreas[selectedKey]
	if settings then
		panel.selectedText:SetText(string.format("%s: %s  (%s)", L["Selected"], settings.name or selectedKey, PositionText(settings)))
	else
		panel.selectedText:SetText("")
	end
end


-------------------------------------------------------------------------------
-- Arrow key bindings (Unreal Azeroth).
-------------------------------------------------------------------------------

-- On Unreal Azeroth the key frame's OnKeyDown does not stop an arrow key from
-- also running its key binding, so every nudge would move or turn the
-- character too (ElvUI-UA). The legacy client consumes the key in the frame
-- and needs none of this.
--
-- The chords are unbound for the duration of move mode and rebound on exit.
-- SaveBindings is never called, so the change stays in the live key map and
-- never reaches the player's saved binding set. The removed commands are
-- recorded in db.global.moverBindings, so a /reload or disconnect during move
-- mode still gets them back at the next load (RestoreArrowBindings).
local ARROW_CHORDS = {
	"UP", "DOWN", "LEFT", "RIGHT",
	"SHIFT-UP", "SHIFT-DOWN", "SHIFT-LEFT", "SHIFT-RIGHT",
}

local function BindingStore()
	local db = MikSBT.db
	if not db or not db.global then
		return nil
	end
	if type(db.global.moverBindings) ~= "table" then
		db.global.moverBindings = {}
	end
	return db.global.moverBindings
end

local function SuppressArrowBindings()
	if not Compat.isUA then return end
	if type(GetBindingAction) ~= "function" or type(SetBinding) ~= "function" then return end
	local store = BindingStore()
	if not store then return end

	local i
	for i = 1, table.getn(ARROW_CHORDS) do
		local chord = ARROW_CHORDS[i]
		-- A chord already recorded is still unbound from an earlier unlock
		-- that never got its matching lock; reading it again would record
		-- "" and lose the real command.
		if not store[chord] then
			local ok, action = pcall(GetBindingAction, chord)
			if ok and type(action) == "string" and action ~= "" then
				store[chord] = action
				pcall(SetBinding, chord)
			end
		end
	end
end

-- Rebinds only chords that are still empty: if the client reloaded its saved
-- binding set in the meantime, the chord already carries its command and is
-- left alone. Runs on both clients, so a record left by an interrupted move
-- mode is always cleared.
function module.RestoreArrowBindings()
	local store = BindingStore()
	if not store then return end
	if type(GetBindingAction) == "function" and type(SetBinding) == "function" then
		local chord, action
		for chord, action in pairs(store) do
			local ok, current = pcall(GetBindingAction, chord)
			if ok and (current == nil or current == "") then
				pcall(SetBinding, chord, action)
			end
		end
	end
	Compat.wipe(store)
end


-------------------------------------------------------------------------------
-- Mode.
-------------------------------------------------------------------------------

function module.Unlock()
	if unlocked then
		return
	end
	unlocked = true
	if MikSBT.Config then
		MikSBT.Config.Close()
	end
	if not keyFrame then CreateKeyFrame() end
	if not panel then CreatePanel() end
	BuildGrid()
	grid:Show()
	SuppressArrowBindings()
	keyFrame:Show()
	PlacePanel()
	panel:Show()
	SyncBoxes()
	Select(selectedKey)
	MikSBT:Print(L["Scroll areas unlocked. Use Lock on the panel (or /msbt move) to finish."])
end

function module.Lock()
	if not unlocked then
		return
	end
	unlocked = false
	if draggingBox then
		StopDrag(draggingBox)
	end
	local _, box
	for _, box in pairs(boxes) do
		box:Hide()
	end
	if grid then grid:Hide() end
	if keyFrame then keyFrame:Hide() end
	module.RestoreArrowBindings()
	if panel then panel:Hide() end
	MikSBT:Print(L["Scroll areas locked."])
end

function module.Toggle()
	if unlocked then
		module.Lock()
	else
		module.Unlock()
	end
end

module.Preview = PreviewSelected

function module.IsUnlocked()
	return unlocked
end

-- Re-reads the scroll areas (profile switch, options change).
function module.Refresh()
	if unlocked then
		SyncBoxes()
		module.UpdatePanel()
	end
end

-- Rebuilds the grid when its size changed while move mode is on.
function module.RefreshGrid()
	if unlocked then
		BuildGrid()
		grid:Show()
	end
end


-- Live coordinate readout while dragging.
local readoutElapsed = 0
readoutFrame = Util.CreateUpdateFrame(function(frame, elapsed)
	readoutElapsed = readoutElapsed + elapsed
	if readoutElapsed >= 0.1 and draggingBox then
		readoutElapsed = 0
		UpdateLabel(draggingBox)
	end
end, "MSBTMoverReadout")
