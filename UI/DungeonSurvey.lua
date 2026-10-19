local ns = WorthRemembering

-- Popup shown after a dungeon/raid completion (see Core/AutoTrack.lua's
-- onInstanceTransition), listing every party/raid member with a note box, a
-- role-preset dropdown, and standing +/- buttons, so richer per-player feedback can be
-- logged right after a run instead of hunting each of them down later. Independent of
-- (and additional to) the plain auto-log option, both configurable separately under
-- Options > Auto-Track > Dungeon/Raid Tracking.

local popup
local rows = {}
local members = {}
local instanceName
local presetHeader, repHeader

local ROW_HEIGHT = 30
local VISIBLE_ROWS = 8
local POPUP_WIDTH = 700
local DEFAULT_POPUP_HEIGHT = 72 + VISIBLE_ROWS * ROW_HEIGHT + 60

-- every column except Name and the note box is a fixed width. Name is sized to the
-- longest name actually showing (see updateNameColumnWidth), clamped to
-- [NAME_MIN_WIDTH, NAME_MAX_WIDTH]; the note box absorbs whatever width is left over
-- after that, same "one flex column" idea as the Players/History tables (see
-- Widgets.lua's relayout). column order: icon, name, note, preset, minus, delta, plus.
local ICON_W, ICON_GAP = 18, 4
local NAME_MIN_WIDTH, NAME_MAX_WIDTH, NAME_GAP = 80, 260, 6
local NOTE_GAP = 6
local PRESET_W, PRESET_GAP = 90, 6
local MINUS_W, MINUS_GAP = 20, 4
local DELTA_W, DELTA_GAP = 36, 4
local PLUS_W = 20
local NOTE_MIN_WIDTH = 80

-- current Name column width, recomputed per refreshRows() call (see
-- updateNameColumnWidth) since it depends on whichever members are actually showing;
-- starts at the floor until the first refresh sets it for real
local nameColWidth = NAME_MIN_WIDTH

local function fixedColsWidth()
	return ICON_W + ICON_GAP + nameColWidth + NAME_GAP + NOTE_GAP
		+ PRESET_W + PRESET_GAP + MINUS_W + MINUS_GAP + DELTA_W + DELTA_GAP + PLUS_W
end

-- scroll:SetPoint insets below are 20 (left) and 34 (right, clears the scrollbar), so
-- this is the viewport's actual usable width -- rows and the scroll child both need to
-- match THIS, not the popup's own width, or content runs under the scrollbar and gets
-- clipped (confirmed live: the row's +/- buttons and delta were getting cut off).
-- MIN_WIDTH/MIN_HEIGHT floor the resize grip: wide enough for every fixed column (at
-- Name's own floor, not whatever it's currently sized to) plus a usable minimum note
-- box, tall enough for the header plus at least one row.
local MIN_WIDTH = ICON_W + ICON_GAP + NAME_MIN_WIDTH + NAME_GAP + NOTE_GAP
	+ PRESET_W + PRESET_GAP + MINUS_W + MINUS_GAP + DELTA_W + DELTA_GAP + PLUS_W
	+ NOTE_MIN_WIDTH + 20 + 34
local MIN_HEIGHT = 72 + ROW_HEIGHT + 60

-- a row's standing delta is held here, nudged by its own +/- buttons, and only actually
-- written (paired with that row's note) when Save All is clicked -- same idea as Quick
-- Add's repBox, not the Players tab's own immediately-committing +/- buttons, since each
-- row needs its delta and note to land in one entry together.
local function setRowDelta(row, value)
	row.pendingDelta = ns.ClampDelta(value)
	row.deltaBox:SetText(row.pendingDelta ~= 0 and tostring(row.pendingDelta) or "")
end

local function nudgeRowDelta(row, amount)
	setRowDelta(row, (row.pendingDelta or 0) + amount)
end

local function noteBoxWidthFor(totalWidth)
	return math.max(NOTE_MIN_WIDTH, totalWidth - fixedColsWidth())
end

local function acquireRow(index)
	local row = rows[index]
	if row then
		return row
	end

	local totalWidth = popup.scroll:GetWidth()
	row = CreateFrame("Frame", nil, popup.scrollChild)
	row:SetSize(totalWidth, ROW_HEIGHT)
	row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

	row.classIcon = row:CreateTexture(nil, "ARTWORK")
	row.classIcon:SetSize(ICON_W, 18)
	row.classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
	row.classIcon:SetPoint("LEFT", 2, 0)
	row.classIcon:EnableMouse(true)

	row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", row.classIcon, "RIGHT", ICON_GAP, 0)
	row.name:SetWidth(nameColWidth)
	row.name:SetJustifyH("LEFT")
	row.name:SetWordWrap(false)

	-- width is the one thing that changes on resize (see relayoutColumns), everything
	-- else chained off it (preset/minus/delta/plus) just follows automatically since
	-- they're anchored relative to its own RIGHT edge
	row.noteBox = CreateFrame("EditBox", nil, row, "InputBoxTemplate")
	row.noteBox:SetSize(noteBoxWidthFor(totalWidth), 18)
	row.noteBox:SetPoint("LEFT", row.name, "RIGHT", NAME_GAP, 0)
	row.noteBox:SetAutoFocus(false)

	-- isSelected always false: this is a one-shot "pick to fill the note box and rep
	-- delta" action, not a persistent per-row selection worth highlighting afterward.
	-- `value` is the whole preset table (not just its text), so onChange can pull both
	-- the note text and the rep delta out of the same pick.
	row.roleOptions = {}
	row.roleDropdown = ns.CreateDropdown(row, row.roleOptions,
		function() return false end,
		function(value)
			row.noteBox:SetText(value.text or "")
			setRowDelta(row, value.delta or 0)
		end, PRESET_W, 20)
	row.roleDropdown:SetPoint("LEFT", row.noteBox, "RIGHT", NOTE_GAP, 0)

	row.minusButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.minusButton:SetSize(MINUS_W, 18)
	row.minusButton:SetText("-")
	row.minusButton:SetPoint("LEFT", row.roleDropdown, "RIGHT", PRESET_GAP, 0)
	local minusTint = row.minusButton:CreateTexture(nil, "ARTWORK", nil, -1)
	minusTint:SetPoint("TOPLEFT", 3, -3)
	minusTint:SetPoint("BOTTOMRIGHT", -3, 3)
	minusTint:SetColorTexture(0.6, 0.18, 0.18, 0.65)

	-- typeable, not just +/- nudgeable: no numeric flag (same reasoning as every other
	-- delta box in the addon, e.g. Quick Add's repBox), since EditBox:SetNumeric doesn't
	-- play nice with a leading "-" for negative values, tonumber() validation instead
	row.deltaBox = ns.CreateSmallEditBox(row, DELTA_W, 16, false)
	row.deltaBox:SetJustifyH("CENTER")
	row.deltaBox:SetPoint("LEFT", row.minusButton, "RIGHT", MINUS_GAP, 0)
	local function applyDeltaBox(self)
		setRowDelta(row, tonumber(self:GetText()) or 0)
		self:ClearFocus()
	end
	row.deltaBox:SetScript("OnEnterPressed", applyDeltaBox)
	row.deltaBox:SetScript("OnEditFocusLost", applyDeltaBox)
	row.deltaBox:SetScript("OnEscapePressed", function(self)
		self:SetText(row.pendingDelta ~= 0 and tostring(row.pendingDelta) or "")
		self:ClearFocus()
	end)

	row.plusButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
	row.plusButton:SetSize(PLUS_W, 18)
	row.plusButton:SetText("+")
	row.plusButton:SetPoint("LEFT", row.deltaBox, "RIGHT", DELTA_GAP, 0)
	local plusTint = row.plusButton:CreateTexture(nil, "ARTWORK", nil, -1)
	plusTint:SetPoint("TOPLEFT", 3, -3)
	plusTint:SetPoint("BOTTOMRIGHT", -3, 3)
	plusTint:SetColorTexture(0.2, 0.45, 0.2, 0.65)

	rows[index] = row
	return row
end

-- re-fits every row's width and note box, plus the Preset/Rep header positions, to
-- whatever the scroll viewport's current width actually is. called on every resize
-- (live during a grip drag, via popup.scroll's OnSizeChanged) and once after a saved
-- size is restored, so a wider/narrower window always reflows instead of either
-- clipping or leaving the extra width as dead space.
local function relayoutColumns()
	if not popup then
		return
	end
	local totalWidth = popup.scroll:GetWidth()
	popup.scrollChild:SetWidth(totalWidth)
	local noteWidth = noteBoxWidthFor(totalWidth)
	for _, row in ipairs(rows) do
		row:SetWidth(totalWidth)
		row.name:SetWidth(nameColWidth)
		row.noteBox:SetWidth(noteWidth)
	end
	if presetHeader then
		local presetX = 20 + ICON_W + ICON_GAP + nameColWidth + NAME_GAP + noteWidth + NOTE_GAP
		presetHeader:SetPoint("TOPLEFT", presetX, -58)
		repHeader:SetPoint("TOPLEFT", presetX + PRESET_W + PRESET_GAP + MINUS_W + MINUS_GAP, -58)
	end
end

local measureName = UIParent:CreateFontString(nil, "BACKGROUND", "GameFontHighlightSmall")
measureName:Hide()

-- sized to the longest name actually showing (including the "(standing)" suffix when
-- present), clamped to [NAME_MIN_WIDTH, NAME_MAX_WIDTH] -- otherwise it's either a wide
-- fixed column leaving dead space when every name's short, or too narrow and clipping
-- when one isn't.
local function updateNameColumnWidth()
	local longest = NAME_MIN_WIDTH
	for _, member in ipairs(members) do
		local identity = member.identity
		local text = ns.DisplayName(identity, identity.key)
		local record = ns.GetPlayerRecord(identity.key, false)
		if record then
			text = text .. "  (" .. (record.standing or 0) .. ")"
		end
		measureName:SetText(text)
		longest = math.max(longest, measureName:GetStringWidth())
	end
	nameColWidth = math.min(NAME_MAX_WIDTH, math.ceil(longest) + 4)
end

-- WowStyle1DropdownTemplate's CreateRadio (and the plain-button fallback) just render
-- `text` as-is, same as any other FontString, so plain |c inline color codes work with
-- no special menu support needed.
local PRESET_COLOR_POSITIVE = "ff8cd98c"
local PRESET_COLOR_NEGATIVE = "ffe68080"

local function presetGroup(delta)
	if delta and delta > 0 then
		return 1
	elseif delta and delta < 0 then
		return 2
	end
	return 3
end

-- same sorted/colored list for every row this refresh (group order never depends on
-- which member the row belongs to), computed once and copied into each row's own
-- options table rather than resorting per row
local function buildRoleOptions()
	local sorted = {}
	for _, preset in ipairs(ns.GetSettings().dungeonTracking.rolePresets) do
		sorted[#sorted + 1] = preset
	end
	table.sort(sorted, function(a, b)
		local groupA, groupB = presetGroup(a.delta), presetGroup(b.delta)
		if groupA ~= groupB then
			return groupA < groupB
		end
		return a.label < b.label
	end)

	local options = {}
	for _, preset in ipairs(sorted) do
		local label = preset.label
		if preset.delta and preset.delta > 0 then
			label = "|c" .. PRESET_COLOR_POSITIVE .. label .. "|r"
		elseif preset.delta and preset.delta < 0 then
			label = "|c" .. PRESET_COLOR_NEGATIVE .. label .. "|r"
		end
		options[#options + 1] = { value = preset, text = label }
	end
	return options
end

local function refreshRows()
	-- decided once up front, not per-row: every row in the list needs to agree on the
	-- same column width, so this has to see every member first, not just the one
	-- currently being laid out
	updateNameColumnWidth()
	local roleOptions = buildRoleOptions()

	for i, member in ipairs(members) do
		local row = acquireRow(i)
		local identity = member.identity
		local r, g, b = ns.ClassColor(identity.classFile)
		-- ns.DisplayName expects a record-shaped table ({name, realmOrSurname}), which
		-- identity already is, so this gives "First Last" (Forever's surname identity),
		-- not just the first name
		local displayName = ns.DisplayName(identity, identity.key)
		row.name:SetText(displayName)
		row.name:SetTextColor(r, g, b)
		if identity.classFile and CLASS_ICON_TCOORDS[identity.classFile] then
			row.classIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[identity.classFile]))
			row.classIcon:Show()
			-- AttachTooltip re-applies its OnEnter/OnLeave each call (SetScript, not
			-- Hook), so re-calling it here per refresh correctly replaces whatever
			-- class the icon's tooltip showed for a previous row/member reusing it
			ns.AttachTooltip(row.classIcon, ns.ClassDisplayName(identity.classFile))
		else
			row.classIcon:Hide()
		end

		-- current standing shown only if a record already exists: a brand new player
		-- showing "(0)" would read as an earned-and-verified zero, not "nothing logged
		-- yet" (same reasoning as the Players tab's own treatment of this)
		local record = ns.GetPlayerRecord(identity.key, false)
		if record then
			local standing = record.standing or 0
			local bracket = ns.GetBracket(standing)
			local standingHex = ns.ToHex(unpack(bracket.color))
			row.name:SetText(displayName .. "  |c" .. standingHex .. "(" .. standing .. ")|r")
			row.name:SetTextColor(r, g, b)
		end

		row.noteBox:SetText("")
		setRowDelta(row, 0)

		-- row.roleOptions is the exact table CreateDropdown's menu closure iterates
		-- (passed by reference at row creation, see acquireRow): refilling its contents
		-- in place updates the already-built dropdown without recreating the frame.
		-- same precomputed, colored, group-sorted list (buildRoleOptions) copied into
		-- every row, not recomputed per row.
		wipe(row.roleOptions)
		for _, option in ipairs(roleOptions) do
			row.roleOptions[#row.roleOptions + 1] = option
		end
		row.roleDropdown:SetText("Preset...")

		row.minusButton:SetScript("OnClick", function()
			local amount = IsShiftKeyDown() and ns.GetSettings().shiftClickAmount or 1
			nudgeRowDelta(row, -amount)
		end)
		row.plusButton:SetScript("OnClick", function()
			local amount = IsShiftKeyDown() and ns.GetSettings().shiftClickAmount or 1
			nudgeRowDelta(row, amount)
		end)

		row.member = member
		row:Show()
	end
	for i = #members + 1, #rows do
		rows[i]:Hide()
	end
	popup.scrollChild:SetHeight(math.max(#members * ROW_HEIGHT, 1))
	-- applies nameColWidth (just possibly changed by updateNameColumnWidth above) to
	-- every row, including ones created on an earlier call with a different width
	relayoutColumns()
end

local function saveAll()
	local settings = ns.GetSettings().dungeonTracking.survey
	for i = 1, #members do
		local row = rows[i]
		local member = row.member
		local noteText = row.noteBox:GetText()
		local delta = row.pendingDelta or 0
		if noteText ~= "" or delta ~= 0 then
			ns.TouchIdentity(member.identity.key, member.identity)
			local entry = {}
			for k, v in pairs(member.context) do
				entry[k] = v
			end
			entry.zone = instanceName
			entry.delta = delta ~= 0 and delta or nil
			entry.source = "manual"
			if noteText ~= "" then
				-- both the prefix AND the row's own note text get filled (a role
				-- preset's text, or whatever was typed/edited by hand, can use {{loc}}
				-- etc too): entry.zone is already the dungeon/raid's own name above,
				-- not wherever you've scattered to by save time
				local prefix = ns.FillPlaceholders(settings.notePrefix or "", entry)
				entry.text = prefix .. ns.FillPlaceholders(noteText, entry)
			end
			ns.AddEntry(member.identity.key, member.identity, entry)
		end
	end
	ns.RefreshAllTabs()
	popup:Hide()
end

-- resize grip, hand-rolled the same way as the main window's (UI/Overview.lua's
-- createResizeGrip): StartSizing's cursor-delta math breaks under this popup's own
-- SetScale, turning a small drag into an instant huge resize, so this tracks the cursor
-- in unscaled coordinates itself instead.
local resizing = false
local resizeStartX, resizeStartY, resizeStartWidth, resizeStartHeight

local function createResizeGrip()
	local grip = CreateFrame("Button", nil, popup)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -4, 4)
	grip:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
	grip:SetScript("OnMouseDown", function()
		-- re-anchored to a fixed TOPLEFT before resizing starts: the popup normally
		-- opens CENTER-anchored, and resizing a CENTER-anchored frame grows it from the
		-- middle outward instead of from this bottom-right grip, same fix as the main
		-- window's own resize grip.
		local left, top = popup:GetLeft(), popup:GetTop()
		popup:ClearAllPoints()
		popup:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)

		resizing = true
		local scale = popup:GetEffectiveScale()
		local x, y = GetCursorPosition()
		resizeStartX, resizeStartY = x / scale, y / scale
		resizeStartWidth, resizeStartHeight = popup:GetWidth(), popup:GetHeight()
	end)
	grip:SetScript("OnUpdate", function()
		if not resizing then
			return
		end
		local scale = popup:GetEffectiveScale()
		local x, y = GetCursorPosition()
		x, y = x / scale, y / scale
		local newWidth = math.max(MIN_WIDTH, math.min(UIParent:GetWidth(), resizeStartWidth + (x - resizeStartX)))
		local newHeight = math.max(MIN_HEIGHT, math.min(UIParent:GetHeight(), resizeStartHeight - (y - resizeStartY)))
		popup:SetSize(newWidth, newHeight)
	end)
	grip:SetScript("OnMouseUp", function()
		resizing = false
		local s = ns.GetSettings().dungeonTracking.survey
		s.windowWidth, s.windowHeight = popup:GetSize()
	end)
	return grip
end

local function createPopup()
	popup = CreateFrame("Frame", "WRDungeonSurveyPopup", UIParent, "BackdropTemplate")
	tinsert(UISpecialFrames, "WRDungeonSurveyPopup")

	-- clamp to both bounds, not just the minimum, so a size saved before a later
	-- version raised MIN_WIDTH/HEIGHT doesn't persist out of range (same reasoning as
	-- the main window's own saved-size clamp)
	local saved = ns.GetSettings().dungeonTracking.survey
	local savedWidth = math.max(saved.windowWidth or POPUP_WIDTH, MIN_WIDTH)
	local savedHeight = math.max(saved.windowHeight or DEFAULT_POPUP_HEIGHT, MIN_HEIGHT)
	popup:SetSize(math.min(savedWidth, UIParent:GetWidth()), math.min(savedHeight, UIParent:GetHeight()))
	popup:SetPoint("CENTER")
	popup:SetFrameStrata("DIALOG")
	popup:SetToplevel(true)
	popup:SetClampedToScreen(true)
	popup:SetScale(ns.GetSettings().uiScale)
	popup:SetMovable(true)
	popup:SetResizable(true)
	if popup.SetResizeBounds then
		popup:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, UIParent:GetWidth(), UIParent:GetHeight())
	else
		popup:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
		popup:SetMaxResize(UIParent:GetWidth(), UIParent:GetHeight())
	end
	popup:EnableMouse(true)
	popup:RegisterForDrag("LeftButton")
	popup:SetScript("OnDragStart", popup.StartMoving)
	popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
	popup:SetScript("OnMouseDown", function() popup:Raise() end)
	popup:SetBackdrop({
		edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
		edgeSize = 24,
		insets = { left = 8, right = 8, top = 8, bottom = 8 },
	})

	local fill = popup:CreateTexture(nil, "BACKGROUND", nil, -8)
	fill:SetPoint("TOPLEFT", 8, -8)
	fill:SetPoint("BOTTOMRIGHT", -8, 8)
	fill:SetColorTexture(0.1, 0.08, 0.06, 1)

	local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	close:SetScript("OnClick", function() popup:Hide() end)

	popup.title = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	popup.title:SetPoint("TOP", 0, -16)

	popup.hint = popup:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	popup.hint:SetPoint("TOP", popup.title, "BOTTOM", 0, -6)
	popup.hint:SetText("A row left blank (no note, no standing change) is skipped on save.")

	-- column headers: x-offsets match each widget's own position in acquireRow below
	-- (scrollChild starts at the scroll frame's own TOPLEFT, 20px in from popup's own
	-- left edge, same inset used here)
	local nameHeader = popup:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	nameHeader:SetPoint("TOPLEFT", 44, -58)
	nameHeader:SetText("Name")

	local noteHeader = popup:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	noteHeader:SetPoint("TOPLEFT", 250, -58)
	noteHeader:SetText("Note")

	-- presetHeader/repHeader are the module-level forward-declared locals (not new
	-- ones): their x position depends on the note box's current width, so
	-- relayoutColumns repositions them on every resize instead of them staying fixed
	presetHeader = popup:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	presetHeader:SetText("Preset")

	repHeader = popup:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	repHeader:SetText("Rep")

	popup.scroll = CreateFrame("ScrollFrame", nil, popup, "UIPanelScrollFrameTemplate")
	popup.scroll:SetPoint("TOPLEFT", 20, -72)
	popup.scroll:SetPoint("BOTTOMRIGHT", -34, 46)
	-- fires on every resize (live during a grip drag, and once right after this
	-- SetSize call establishes the restored/default size), keeping row/header layout
	-- in sync with however wide the window actually is
	popup.scroll:SetScript("OnSizeChanged", relayoutColumns)

	popup.scrollChild = CreateFrame("Frame", nil, popup.scroll)
	popup.scroll:SetScrollChild(popup.scrollChild)

	createResizeGrip()

	popup.skipButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
	popup.skipButton:SetSize(90, 24)
	popup.skipButton:SetPoint("BOTTOMLEFT", 20, 14)
	popup.skipButton:SetText("Skip")
	popup.skipButton:SetScript("OnClick", function() popup:Hide() end)

	popup.saveButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
	popup.saveButton:SetSize(110, 24)
	popup.saveButton:SetPoint("BOTTOMRIGHT", -20, 14)
	popup.saveButton:SetText("Save All")
	popup.saveButton:SetScript("OnClick", saveAll)

	relayoutColumns()
end

-- `members`: array of { identity = ns.IdentifyUnit()-shaped table, context =
-- ns.CaptureContext()-shaped table }, captured together while units were still valid
-- (see Core/AutoTrack.lua's snapshotPartyMembers). `zoneName` is the dungeon/raid's own
-- name, used instead of whatever zone you're standing in by the time this shows.
function ns.ShowDungeonSurvey(memberList, zoneName)
	if not memberList or #memberList == 0 then
		return
	end
	if not popup then
		createPopup()
	end

	members = memberList
	instanceName = zoneName
	popup.title:SetText("Dungeon/Raid Survey: " .. (zoneName or "?"))

	refreshRows()

	-- only auto-fits height to the member count until the user manually resizes the
	-- window once (see createResizeGrip): past that point, their chosen size is the
	-- source of truth, so a 40-man roster doesn't keep snapping back to a tall window
	-- every time after they've deliberately shrunk it
	if not ns.GetSettings().dungeonTracking.survey.windowHeight then
		local visible = math.max(1, math.min(#members, VISIBLE_ROWS))
		popup:SetHeight(72 + visible * ROW_HEIGHT + 60)
	end
	popup:Show()
end

-- A small gate in front of the full survey, so it doesn't just pop open in your face
-- right as a run ends. "Don't ask me again" (unchecked by default) skips straight to
-- the survey on future completions instead of asking first, see
-- dungeonTracking.survey.skipConfirmation.
local confirmPrompt
local confirmMembers, confirmZoneName

local function saveConfirmPosition()
	local anchor = "TOPLEFT"
	ns.GetSettings().dungeonTracking.survey.confirmPoint = {
		anchor = anchor,
		x = confirmPrompt:GetLeft(),
		y = confirmPrompt:GetTop(),
	}
end

local function restoreConfirmPosition()
	local p = ns.GetSettings().dungeonTracking.survey.confirmPoint
	confirmPrompt:ClearAllPoints()
	if p and p.anchor then
		confirmPrompt:SetPoint(p.anchor, UIParent, "BOTTOMLEFT", p.x, p.y)
	else
		confirmPrompt:SetPoint("CENTER", UIParent, "CENTER", 0, 120)
	end
end

local function createConfirmPrompt()
	confirmPrompt = CreateFrame("Frame", "WRDungeonSurveyConfirm", UIParent, "BackdropTemplate")
	tinsert(UISpecialFrames, "WRDungeonSurveyConfirm")
	confirmPrompt:SetSize(280, 120)
	confirmPrompt:SetFrameStrata("DIALOG")
	confirmPrompt:SetToplevel(true)
	confirmPrompt:SetClampedToScreen(true)
	confirmPrompt:SetScale(ns.GetSettings().uiScale)
	confirmPrompt:SetMovable(true)
	confirmPrompt:EnableMouse(true)
	confirmPrompt:RegisterForDrag("LeftButton")
	confirmPrompt:SetScript("OnDragStart", confirmPrompt.StartMoving)
	confirmPrompt:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		saveConfirmPosition()
	end)
	confirmPrompt:SetScript("OnMouseDown", function() confirmPrompt:Raise() end)
	confirmPrompt:SetBackdrop({
		edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
		edgeSize = 24,
		insets = { left = 8, right = 8, top = 8, bottom = 8 },
	})

	local fill = confirmPrompt:CreateTexture(nil, "BACKGROUND", nil, -8)
	fill:SetPoint("TOPLEFT", 8, -8)
	fill:SetPoint("BOTTOMRIGHT", -8, 8)
	fill:SetColorTexture(0.1, 0.08, 0.06, 1)

	local close = CreateFrame("Button", nil, confirmPrompt, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	close:SetScript("OnClick", function() confirmPrompt:Hide() end)

	confirmPrompt.title = confirmPrompt:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	confirmPrompt.title:SetPoint("TOP", 0, -16)
	confirmPrompt.title:SetText("Worth Remembering")

	confirmPrompt.body = confirmPrompt:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	confirmPrompt.body:SetPoint("TOP", confirmPrompt.title, "BOTTOM", 0, -10)
	confirmPrompt.body:SetPoint("LEFT", 16, 0)
	confirmPrompt.body:SetPoint("RIGHT", -16, 0)
	confirmPrompt.body:SetJustifyH("CENTER")
	confirmPrompt.body:SetWordWrap(true)
	confirmPrompt.body:SetText("Would you like to fill out the post-instance survey?")

	-- deliberately NOT applied on the checkbox's own click: what "don't ask me again"
	-- actually means depends on which button follows it. checked + Open Survey means
	-- "always open it, stop asking"; checked + Skip means "stop asking AND stop
	-- surveying", not "stop asking but keep forcing it open" (which skipConfirmation
	-- alone, without also disabling survey.enabled, would otherwise do).
	confirmPrompt.skipCheck = CreateFrame("CheckButton", nil, confirmPrompt, "UICheckButtonTemplate")
	confirmPrompt.skipCheck:SetSize(20, 20)
	confirmPrompt.skipCheck:SetPoint("BOTTOMLEFT", 16, 44)

	local skipLabel = confirmPrompt:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	skipLabel:SetPoint("LEFT", confirmPrompt.skipCheck, "RIGHT", 2, 0)
	skipLabel:SetText("Don't ask me again")

	confirmPrompt.noButton = CreateFrame("Button", nil, confirmPrompt, "UIPanelButtonTemplate")
	confirmPrompt.noButton:SetSize(90, 24)
	confirmPrompt.noButton:SetPoint("BOTTOMLEFT", 16, 14)
	confirmPrompt.noButton:SetText("Skip")
	confirmPrompt.noButton:SetScript("OnClick", function()
		if confirmPrompt.skipCheck:GetChecked() then
			ns.GetSettings().dungeonTracking.survey.enabled = false
		end
		confirmPrompt:Hide()
	end)

	confirmPrompt.yesButton = CreateFrame("Button", nil, confirmPrompt, "UIPanelButtonTemplate")
	confirmPrompt.yesButton:SetSize(110, 24)
	confirmPrompt.yesButton:SetPoint("BOTTOMRIGHT", -16, 14)
	confirmPrompt.yesButton:SetText("Open Survey")
	confirmPrompt.yesButton:SetScript("OnClick", function()
		if confirmPrompt.skipCheck:GetChecked() then
			ns.GetSettings().dungeonTracking.survey.skipConfirmation = true
		end
		confirmPrompt:Hide()
		ns.ShowDungeonSurvey(confirmMembers, confirmZoneName)
	end)
end

-- the entry point Core/AutoTrack.lua actually calls: gates ns.ShowDungeonSurvey behind
-- this small confirm step, unless skipConfirmation is on, in which case it goes straight
-- through.
function ns.ShowDungeonSurveyPrompt(memberList, zoneName)
	if not memberList or #memberList == 0 then
		return
	end
	if ns.GetSettings().dungeonTracking.survey.skipConfirmation then
		ns.ShowDungeonSurvey(memberList, zoneName)
		return
	end

	if not confirmPrompt then
		createConfirmPrompt()
	end
	confirmMembers, confirmZoneName = memberList, zoneName
	-- always starts unchecked: it's a one-shot "apply this choice" checkbox read by the
	-- two buttons above, not a persistent reflection of a stored setting (if
	-- skipConfirmation were ever true, this prompt wouldn't be showing at all)
	confirmPrompt.skipCheck:SetChecked(false)
	restoreConfirmPosition()
	confirmPrompt:Show()
end
