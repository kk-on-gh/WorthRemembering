local ns = WorthRemembering
local Skin = ns.Skin

local popup
local currentKey
local autoCloseOnSubmit
local layoutPresets -- refresh() above calls this

local refreshAddMode -- add-player mode, see below

local function refresh()
	if popup.addMode then
		refreshAddMode()
		return
	end
	local record = currentKey and ns.GetPlayerRecord(currentKey, false)
	if not record then
		popup:Hide()
		return
	end

	local cr, cg, cb = ns.ClassColor(record.classFile)
	local bracket = ns.GetBracket(record.standing or 0)

	popup.title:SetText(ns.DisplayName(record, currentKey))
	popup.title:SetTextColor(cr, cg, cb)
	local ignoredHint = ns.GetIgnoreSource(currentKey, record.guid)
	ignoredHint = (ignoredHint and ignoredHint ~= "exempt") and "  |cff888888(on your ignore list)|r" or ""
	popup.standing:SetText("Standing: " .. (record.standing or 0) .. "  (" .. bracket.name .. ")" .. ignoredHint)
	popup.standing:SetTextColor(unpack(bracket.color))
	layoutPresets()
end

-- A single entry can carry both a note and a standing delta at once (e.g. "+5, ninja
-- looted the mats"). Submits whichever of the two fields is filled in; does nothing if
-- both are empty.
local function submitEntry()
	local text = popup.noteBox:GetText()
	local delta = tonumber(popup.repBox:GetText())
	if text == "" and (not delta or delta == 0) then
		return
	end

	local identity, unit
	if popup.addMode then
		identity, unit = ns.ResolveTypedName(popup.firstBox:GetText(), popup.lastBox:GetText())
		if not identity then
			popup.nameMissing()
			return
		end
	else
		local record = currentKey and ns.GetPlayerRecord(currentKey, false)
		if not record then
			return
		end
		identity, unit = ns.LiveIdentityForRecord(record)
		identity.key = currentKey
	end
	local entry = ns.CaptureContext(unit)
	entry.text = text ~= "" and text or nil
	entry.delta = delta and delta ~= 0 and delta or nil
	entry.featured = (popup.featuredCheck:GetChecked() and entry.text) and true or nil
	entry.source = "manual"
	ns.AddEntry(identity.key, identity, entry)
	if popup.addMode then
		currentKey = identity.key
		popup.setAddMode(false)
	end

	popup.noteBox:SetText("")
	popup.repBox:SetText("")
	popup.featuredCheck:SetChecked(false)
	popup.noteBox:ClearFocus()
	popup.repBox:ClearFocus()

	ns.RefreshAllTabs()

	-- macro/keybind/context-menu entry points close immediately after one add. the
	-- in-window ones (Players row, Details tab) stay open for adding several in a row.
	if autoCloseOnSubmit then
		popup:Hide()
	else
		refresh()
	end
end

-- one-click preset entries ("Good Healer", "Resource Hog", etc). fills the note/delta
-- fields with the preset's values and submits immediately. user-editable list in
-- Options -> Quick Presets, can be disabled there too.
local presetButtonPool = {}

local function applyPresetAndSubmit(preset)
	-- placeholders ({{loc}} etc) resolved here, at click time, so the note box shows
	-- the actual filled-in text before it submits, not the literal placeholder.
	local identity, unit
	if popup.addMode then
		identity, unit = ns.ResolveTypedName(popup.firstBox:GetText(), popup.lastBox:GetText())
		if not identity then
			popup.nameMissing()
			return
		end
	else
		local record = currentKey and ns.GetPlayerRecord(currentKey, false)
		if not record then
			return
		end
		identity, unit = ns.LiveIdentityForRecord(record)
	end
	local ctx = ns.CaptureContext(unit)
	popup.noteBox:SetText(preset.text and ns.FillPlaceholders(preset.text, ctx) or "")
	popup.repBox:SetText(preset.delta and preset.delta ~= 0 and tostring(preset.delta) or "")
	submitEntry()
end

-- flows buttons left-to-right, wrapping to a new row when one wouldn't fit. preset
-- labels are user-editable and variable-width, so a fixed grid doesn't work.
local PRESET_ROW_WIDTH = 320
local PRESET_ROW_HEIGHT = 24
local PRESET_MIN_ROWS = 2

-- resizes presetsArea to fit however many rows it used (floored at PRESET_MIN_ROWS),
-- then relayouts everything below it.
function layoutPresets()
	local settings = ns.GetSettings().quickPresets
	local items = settings.enabled and settings.items or {}

	local x, y = 0, 0
	local rows = items[1] and 1 or 0
	for i, preset in ipairs(items) do
		local btn = presetButtonPool[i]
		if not btn then
			btn = CreateFrame("Button", nil, popup.presetsArea, "UIPanelButtonTemplate")
			btn:SetHeight(20)
			Skin.Button(btn)
			presetButtonPool[i] = btn
		end
		btn:SetText(preset.label)
		btn:SetWidth(math.max(70, btn:GetFontString():GetStringWidth() + 24))
		if x > 0 and x + btn:GetWidth() > PRESET_ROW_WIDTH then
			x = 0
			y = y - PRESET_ROW_HEIGHT
			rows = rows + 1
		end
		btn:ClearAllPoints()
		btn:SetPoint("TOPLEFT", popup.presetsArea, "TOPLEFT", x, y)
		btn:SetScript("OnClick", function() applyPresetAndSubmit(preset) end)
		btn:Show()
		x = x + btn:GetWidth() + 6
	end

	for i = #items + 1, #presetButtonPool do
		presetButtonPool[i]:Hide()
	end

	local usedRows = math.max(rows, PRESET_MIN_ROWS)
	popup.presetsArea:SetHeight(usedRows * PRESET_ROW_HEIGHT)
	popup.relayout(usedRows * PRESET_ROW_HEIGHT)
end

local DELTA_BUTTONS = { -10, -5, -1, 1, 5, 10 }

local function nudgeDelta(amount)
	local current = tonumber(popup.repBox:GetText()) or 0
	popup.repBox:SetText(tostring(ns.ClampDelta(current + amount)))
end

-- vertical chain below the presets area, in anchor order. named constants so
-- popup.relayout can sum them to resize the whole popup.
local PRESETS_TOP_Y = -70
local AFTER_PRESETS_GAP = 14
local NOTE_LABEL_HEIGHT = 12
local NOTE_LABEL_GAP = 4
local NOTE_BOX_HEIGHT = 128
local REP_LABEL_GAP = 14
local REP_LABEL_HEIGHT = 12
local REP_BOX_GAP = 6
local REP_BOX_HEIGHT = 20
local DELTA_ROW_GAP = 10
local DELTA_ROW_HEIGHT = 20
local FEATURED_ROW_GAP = 10
local FEATURED_ROW_HEIGHT = 20
local BOTTOM_GAP = 20
local BOTTOM_ROW_HEIGHT = 24
local BOTTOM_PAD = 16

local CHAIN_HEIGHT_AFTER_NOTE_LABEL = NOTE_LABEL_HEIGHT + NOTE_LABEL_GAP + NOTE_BOX_HEIGHT
	+ REP_LABEL_GAP + REP_LABEL_HEIGHT + REP_BOX_GAP + REP_BOX_HEIGHT + DELTA_ROW_GAP + DELTA_ROW_HEIGHT
	+ FEATURED_ROW_GAP + FEATURED_ROW_HEIGHT

-- repositions the note label (everything below chains relatively) and resizes the
-- popup to fit, given however tall the presets area ended up (see layoutPresets).
local function relayout(presetsHeight)
	local noteLabelY = (popup.presetsTop or PRESETS_TOP_Y) - presetsHeight - AFTER_PRESETS_GAP
	popup.noteLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 38, noteLabelY)
	local deltaRowBottomY = noteLabelY - CHAIN_HEIGHT_AFTER_NOTE_LABEL
	popup:SetHeight(-deltaRowBottomY + BOTTOM_GAP + BOTTOM_ROW_HEIGHT + BOTTOM_PAD)
end

-- Add-player mode: the same popup with name boxes under the title, for someone who isn't
-- your target. The record is only created by Add Entry (or a preset).
local NAME_ROW_HEIGHT = 20
local ADD_MODE_EXTRA = 32 -- the name row pushes the presets down this far
local SUGGESTION_ROWS = 6
local SUGGESTION_HEIGHT = 18
local NAME_BOX_WIDTH = 136

local function addPlaceholder(box, text)
	local hint = Skin.Text(box, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("LEFT", 4, 0)
	hint:SetText(text)
	box:HookScript("OnTextChanged", function(self)
		hint:SetShown(self:GetText() == "")
	end)
end

-- saved players whose name starts with what's typed, best known first
local function findSuggestions(first, last)
	local typed = (first .. (last ~= "" and (" " .. last) or "")):lower()
	if typed == "" then
		return {}
	end
	local exactKey = ns.TypedNameKey(first, last)
	local matches = {}
	for _, key in ipairs(ns.GetAllPlayerKeys()) do
		local record = ns.GetPlayerRecord(key, false)
		if record and record.name and key ~= exactKey then
			local full = (record.name .. (record.realmOrSurname and (" " .. record.realmOrSurname) or "")):lower()
			if full:sub(1, #typed) == typed then
				matches[#matches + 1] = { key = key, record = record, full = full }
			end
		end
	end
	table.sort(matches, function(a, b)
		local sa, sb = math.abs(a.record.standing or 0), math.abs(b.record.standing or 0)
		if sa ~= sb then
			return sa > sb
		end
		return a.full < b.full
	end)
	return matches
end

local function updateSuggestions()
	local list = popup.suggestions
	local focused = popup.firstBox:HasFocus() or popup.lastBox:HasFocus()
	local matches = focused and findSuggestions(popup.firstBox:GetText(), popup.lastBox:GetText()) or {}
	for i = 1, SUGGESTION_ROWS do
		local row, match = list.rows[i], matches[i]
		row:SetShown(match ~= nil)
		if match then
			row.record = match.record
			row.text:SetText(ns.DisplayName(match.record, match.key))
			row.text:SetTextColor(ns.ClassColor(match.record.classFile))
			local standing = match.record.standing or 0
			row.standing:SetText((standing > 0 and "+" or "") .. standing)
			row.standing:SetTextColor(unpack(ns.GetBracket(standing).color))
		end
	end
	local shown = math.min(#matches, SUGGESTION_ROWS)
	list:SetHeight(shown * SUGGESTION_HEIGHT + 4)
	list:SetShown(shown > 0)
end

function refreshAddMode()
	popup.title:SetText("Add Player")
	popup.title:SetTextColor(Skin.AccentColor())
	local first, last = popup.firstBox:GetText(), popup.lastBox:GetText()
	local key = ns.TypedNameKey(first, last)
	local record = key and ns.GetPlayerRecord(key, false)
	popup.matchKey = record and key or nil
	popup.historyButton:SetEnabled(record ~= nil)
	popup.detailsButton:SetEnabled(record ~= nil)
	if not key then
		popup.standing:SetText(ns.UsesSurnames() and "Type their first and last name." or "Type their name. Leave the realm blank for your own.")
		popup.standing:SetTextColor(0.6, 0.6, 0.6)
	elseif record then
		local standing = record.standing or 0
		local bracket = ns.GetBracket(standing)
		popup.standing:SetText("Already in your list: standing " .. standing .. "  (" .. bracket.name .. ")")
		popup.standing:SetTextColor(unpack(bracket.color))
	else
		local _, unit = ns.ResolveTypedName(first, last)
		popup.standing:SetText(unit == "target" and "New player (your target)" or "New player")
		popup.standing:SetTextColor(0.6, 0.6, 0.6)
	end
	layoutPresets()
end

local function buildNameRow()
	local row = CreateFrame("Frame", nil, popup)
	row:SetSize(2 * NAME_BOX_WIDTH + 12, NAME_ROW_HEIGHT)
	row:SetPoint("TOP", popup.title, "BOTTOM", 0, -14)
	row:Hide()
	popup.nameRow = row

	popup.firstBox = ns.CreateSmallEditBox(row, NAME_BOX_WIDTH, 18)
	popup.firstBox:SetJustifyH("LEFT")
	popup.firstBox:SetTextInsets(4, 4, 0, 0)
	popup.firstBox:SetPoint("LEFT")
	popup.lastBox = ns.CreateSmallEditBox(row, NAME_BOX_WIDTH, 18)
	popup.lastBox:SetJustifyH("LEFT")
	popup.lastBox:SetTextInsets(4, 4, 0, 0)
	popup.lastBox:SetPoint("RIGHT")
	if ns.UsesSurnames() then
		addPlaceholder(popup.firstBox, "First name")
		addPlaceholder(popup.lastBox, "Last name")
	else
		addPlaceholder(popup.firstBox, "Name")
		addPlaceholder(popup.lastBox, "Realm (blank = yours)")
	end

	local function onChanged()
		if popup.addMode then
			refreshAddMode()
			updateSuggestions()
		end
	end
	for _, box in ipairs({ popup.firstBox, popup.lastBox }) do
		box:HookScript("OnTextChanged", onChanged)
		box:HookScript("OnEditFocusGained", updateSuggestions)
		box:SetScript("OnEditFocusLost", function()
			-- a frame later, so a click on a suggestion lands first
			C_Timer.After(0.1, updateSuggestions)
		end)
		box:SetScript("OnEscapePressed", function(self)
			self:ClearFocus()
			popup:Hide()
		end)
	end
	local function toLast() popup.lastBox:SetFocus() end
	local function toNote() popup.noteBox:SetFocus() end
	popup.firstBox:SetScript("OnEnterPressed", toLast)
	popup.firstBox:SetScript("OnTabPressed", toLast)
	popup.lastBox:SetScript("OnEnterPressed", toNote)
	popup.lastBox:SetScript("OnTabPressed", toNote)

	-- the status line sits under the name row in this mode, see setAddMode
	popup.nameMissing = function()
		popup.firstBox:SetFocus()
		popup.standing:SetTextColor(1, 0.38, 0.38)
	end

	local list = CreateFrame("Frame", nil, popup, "BackdropTemplate")
	list:SetPoint("TOPLEFT", row, "BOTTOMLEFT", 0, -2)
	list:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", 0, -2)
	list:SetFrameLevel(popup:GetFrameLevel() + 20)
	if not Skin.Panel(list, "float") then
		list:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8X8", edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1 })
		list:SetBackdropColor(0.06, 0.05, 0.03, 0.98)
		list:SetBackdropBorderColor(1, 0.82, 0, 0.6)
	end
	list:Hide()
	list.rows = {}
	for i = 1, SUGGESTION_ROWS do
		local button = CreateFrame("Button", nil, list)
		button:SetHeight(SUGGESTION_HEIGHT)
		button:SetPoint("TOPLEFT", 2, -2 - (i - 1) * SUGGESTION_HEIGHT)
		button:SetPoint("TOPRIGHT", -2, -2 - (i - 1) * SUGGESTION_HEIGHT)
		local highlight = button:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		Skin.Accent(highlight, 0.15)
		button.text = Skin.Text(button, "ARTWORK", "GameFontHighlightSmall")
		button.text:SetPoint("LEFT", 6, 0)
		button.standing = Skin.Text(button, "ARTWORK", "GameFontHighlightSmall")
		button.standing:SetPoint("RIGHT", -6, 0)
		button:SetScript("OnClick", function(self)
			popup.firstBox:SetText(self.record.name or "")
			popup.lastBox:SetText(self.record.realmOrSurname or "")
			list:Hide()
			popup.noteBox:SetFocus()
		end)
		list.rows[i] = button
	end
	popup.suggestions = list

	popup.setAddMode = function(on)
		popup.addMode = on and true or nil
		row:SetShown(on)
		if not on then
			list:Hide()
			popup.matchKey = nil
			popup.historyButton:Enable()
			popup.detailsButton:Enable()
		end
		popup.standing:ClearAllPoints()
		if on then
			popup.standing:SetPoint("TOP", row, "BOTTOM", 0, -8)
		else
			popup.standing:SetPoint("TOP", popup.title, "BOTTOM", 0, -6)
		end
		popup.presetsTop = on and (PRESETS_TOP_Y - ADD_MODE_EXTRA) or PRESETS_TOP_Y
		popup.presetsArea:ClearAllPoints()
		popup.presetsArea:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, popup.presetsTop)
	end
end

local function createPopup()
	popup = CreateFrame("Frame", "WRQuickAddPopup", UIParent, "BackdropTemplate")
	-- Lets Escape close this window, like Blizzard's own panels.
	tinsert(UISpecialFrames, "WRQuickAddPopup")
	popup:SetSize(360, 460)
	-- above the main window (HIGH strata). toplevel so clicking this popup while Edit
	-- Entry is also open brings it to the front.
	popup:SetFrameStrata("DIALOG")
	popup:SetToplevel(true)
	popup:SetClampedToScreen(true)
	popup:SetScale(ns.GetSettings().uiScale)
	ns.RestorePopupPosition(popup, "quickAdd")
	ns.MakePopupDraggable(popup, "quickAdd")
	popup:SetScript("OnMouseDown", function() popup:Raise() end)
	-- closing without saving discards whatever was typed, so it doesn't carry over to
	-- the next player
	popup:SetScript("OnHide", function()
		popup.noteBox:SetText("")
		popup.repBox:SetText("")
		popup.featuredCheck:SetChecked(false)
		if popup.addMode then
			popup.setAddMode(false)
		end
	end)
	popup.relayout = relayout
	-- border only, no bgFile, see Overview.lua's mainFrame backdrop. opacity comes
	-- from the separate fill texture below.
	if not Skin.Window(popup) then
		popup:SetBackdrop({
			edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
			edgeSize = 24,
			insets = { left = 8, right = 8, top = 8, bottom = 8 },
		})

		local fill = popup:CreateTexture(nil, "BACKGROUND", nil, -8)
		fill:SetPoint("TOPLEFT", 8, -8)
		fill:SetPoint("BOTTOMRIGHT", -8, 8)
		fill:SetColorTexture(0.1, 0.08, 0.06, 1)
	end

	local close = CreateFrame("Button", nil, popup, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", 2, 2)
	close:SetScript("OnClick", function() popup:Hide() end)
	Skin.CloseButton(close, popup)

	popup.title = Skin.Text(popup, "ARTWORK", "GameFontNormalLarge")
	popup.title:SetPoint("TOP", 0, -18)
	Skin.Title(popup.title, popup)

	popup.standing = Skin.Text(popup, "ARTWORK", "GameFontNormal")
	popup.standing:SetPoint("TOP", popup.title, "BOTTOM", 0, -6)

	-- one-click preset buttons. layoutPresets resizes this (floored at PRESET_MIN_ROWS)
	-- to however many rows are used, then calls relayout() to push the rest down.
	popup.presetsArea = CreateFrame("Frame", nil, popup)
	popup.presetsArea:SetSize(1, PRESET_ROW_HEIGHT * PRESET_MIN_ROWS)
	popup.presetsArea:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, PRESETS_TOP_Y)

	-- fixed absolute position, set for real by relayout() once the presets height is
	-- known. not chained off the text above since it's all centered.
	popup.noteLabel = Skin.Text(popup, "ARTWORK", "GameFontNormalSmall")
	popup.noteLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 38, PRESETS_TOP_Y - PRESET_ROW_HEIGHT * 2 - AFTER_PRESETS_GAP)
	popup.noteLabel:SetText("Note")
	local noteLabel = popup.noteLabel

	-- multi-line, so built by hand (InputBoxTemplate is single-line-only art).
	-- plain EditBox with its own backdrop border, matching the input-box look.
	local noteBoxBorder = CreateFrame("Frame", nil, popup, "BackdropTemplate")
	noteBoxBorder:SetSize(284, NOTE_BOX_HEIGHT)
	noteBoxBorder:SetPoint("TOPLEFT", noteLabel, "BOTTOMLEFT", 2, -NOTE_LABEL_GAP)
	if not Skin.Panel(noteBoxBorder, "field") then
		noteBoxBorder:SetBackdrop({
			bgFile = "Interface/Tooltips/UI-Tooltip-Background",
			edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
			edgeSize = 10,
			insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		noteBoxBorder:SetBackdropColor(0, 0, 0, 0.6)
	end

	-- Wrapped in a scroll frame: a plain EditBox neither clips nor scrolls overflow on
	-- its own, so a note longer than the box just bled out past its border with no way
	-- to see or reach the rest of it.
	local noteScroll = CreateFrame("ScrollFrame", nil, noteBoxBorder, "UIPanelScrollFrameTemplate")
	noteScroll:SetPoint("TOPLEFT", 6, -6)
	noteScroll:SetPoint("BOTTOMRIGHT", -26, 6)
	Skin.ScrollBar(noteScroll)
	-- The EditBox's own click-to-position-cursor hit test only seemed to register on
	-- its first visible line; forwarding focus explicitly on any click in the visible
	-- area is a reliable fallback regardless of where exactly that falls short.
	noteScroll:EnableMouse(true)
	noteScroll:HookScript("OnMouseDown", function()
		popup.noteBox:SetFocus()
	end)

	popup.noteBox = CreateFrame("EditBox", nil, noteScroll)
	ns.EnableDoubleClickSelectAll(popup.noteBox)
	popup.noteBox:SetMultiLine(true)
	Skin.SetFont(popup.noteBox, ChatFontNormal)
	popup.noteBox:SetAutoFocus(false)
	popup.noteBox:SetWidth(noteScroll:GetWidth())
	-- EditBox has no text-height query, so the scroll child gets a fixed height
	-- generous enough for anything. scrollbar and OnCursorChanged handle the rest.
	popup.noteBox:SetHeight(600)
	noteScroll:SetScrollChild(popup.noteBox)
	noteScroll:SetScript("OnSizeChanged", function(self, width)
		popup.noteBox:SetWidth(width)
	end)
	-- Keeps the cursor on-screen while typing/arrowing past the visible area.
	popup.noteBox:SetScript("OnCursorChanged", function(self, _, y, _, height)
		local scroll = noteScroll:GetVerticalScroll()
		local visible = noteScroll:GetHeight()
		if -y < scroll then
			noteScroll:SetVerticalScroll(-y)
		elseif -y + height > scroll + visible then
			noteScroll:SetVerticalScroll(-y + height - visible)
		end
	end)
	-- Enter inserts a newline; Add Entry submits. an EditBox's default Escape just
	-- clears focus and swallows the keypress, which ate every Escape since this box
	-- auto-focuses on open. close the popup instead.
	popup.noteBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		popup:Hide()
	end)
	-- a featured note needs actual text, keeps the checkbox from implying a state
	-- that gets silently dropped on submit (see submitEntry).
	popup.noteBox:SetScript("OnTextChanged", function(self)
		local hasText = self:GetText() ~= ""
		if not hasText then
			popup.featuredCheck:SetChecked(false)
		end
		if hasText then
			popup.featuredCheck:Enable()
		else
			popup.featuredCheck:Disable()
		end
	end)

	popup.featuredCheck = CreateFrame("CheckButton", nil, popup, "UICheckButtonTemplate")
	popup.featuredCheck:SetSize(20, 20)
	Skin.Checkbox(popup.featuredCheck)
	popup.featuredCheck:SetPoint("TOPLEFT", noteBoxBorder, "BOTTOMLEFT", 0, -FEATURED_ROW_GAP)

	local featuredLabel = Skin.Text(popup, "ARTWORK", "GameFontHighlightSmall")
	featuredLabel:SetPoint("LEFT", popup.featuredCheck, "RIGHT", 2, 0)
	featuredLabel:SetText("Featured")

	local repLabel = Skin.Text(popup, "ARTWORK", "GameFontNormalSmall")
	repLabel:SetPoint("TOPLEFT", popup.featuredCheck, "BOTTOMLEFT", -2, -REP_LABEL_GAP)
	repLabel:SetText("Standing +/-")

	popup.repBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
	ns.EnableDoubleClickSelectAll(popup.repBox)
	popup.repBox:SetSize(70, REP_BOX_HEIGHT)
	popup.repBox:SetPoint("TOPLEFT", repLabel, "BOTTOMLEFT", 4, -REP_BOX_GAP)
	popup.repBox:SetAutoFocus(false)
	Skin.EditBox(popup.repBox)
	popup.repBox:SetScript("OnEnterPressed", submitEntry)
	popup.repBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		popup:Hide()
	end)
	-- clamps on focus-lost rather than every keystroke, so typing e.g. "-100" doesn't
	-- get fought mid-entry; still catches it before Enter/the Add Entry button can submit
	-- it, since OnEditFocusLost fires either way
	popup.repBox:SetScript("OnEditFocusLost", function(self)
		local value = tonumber(self:GetText())
		if value then
			self:SetText(tostring(ns.ClampDelta(value)))
		end
	end)

	-- each button adds its value to whatever's already typed (e.g. "2" then +10 -> "12")
	-- rather than replacing it, so a few clicks can build up an exact delta.
	local deltaRow = CreateFrame("Frame", nil, popup)
	deltaRow:SetSize(1, DELTA_ROW_HEIGHT)
	deltaRow:SetPoint("TOPLEFT", popup.repBox, "BOTTOMLEFT", 0, -DELTA_ROW_GAP)
	local prevDeltaButton
	for _, amount in ipairs(DELTA_BUTTONS) do
		local button = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
		button:SetSize(42, 20)
		button:SetText((amount > 0 and "+" or "") .. amount)
		if prevDeltaButton then
			button:SetPoint("LEFT", prevDeltaButton, "RIGHT", 4, 0)
		else
			button:SetPoint("LEFT", deltaRow, "LEFT", 0, 0)
		end
		button:SetScript("OnClick", function() nudgeDelta(amount) end)
		Skin.Button(button)
		-- Same red/green tint as the Players tab's inline +/- buttons.
		local tint = Skin.CreateArtHost(button):CreateTexture(nil, "ARTWORK", nil, -1)
		tint:SetPoint("TOPLEFT", 3, -3)
		tint:SetPoint("BOTTOMRIGHT", -3, 3)
		if amount > 0 then
			tint:SetColorTexture(0.2, 0.45, 0.2, 0.65)
		else
			tint:SetColorTexture(0.6, 0.18, 0.18, 0.65)
		end
		prevDeltaButton = button
	end

	popup.addButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
	Skin.Button(popup.addButton)
	popup.addButton:SetSize(100, 24)
	popup.addButton:SetPoint("BOTTOMLEFT", 20, 16)
	popup.addButton:SetText("Add Entry")
	popup.addButton:SetScript("OnClick", submitEntry)

	popup.historyButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
	Skin.Button(popup.historyButton)
	popup.historyButton:SetSize(110, 24)
	popup.historyButton:SetPoint("BOTTOMRIGHT", -20, 16)
	popup.historyButton:SetText("History")
	popup.historyButton:SetScript("OnClick", function()
		local key = popup.addMode and popup.matchKey or currentKey
		popup:Hide()
		ns.SelectHistoryTab(key)
	end)

	popup.detailsButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
	Skin.Button(popup.detailsButton)
	popup.detailsButton:SetSize(90, 24)
	popup.detailsButton:SetPoint("RIGHT", popup.historyButton, "LEFT", -6, 0)
	popup.detailsButton:SetText("Details")
	popup.detailsButton:SetScript("OnClick", function()
		local key = popup.addMode and popup.matchKey or currentKey
		popup:Hide()
		if ns.ShowPlayerDetails then
			ns.ShowPlayerDetails(key)
		end
	end)

	buildNameRow()
end

-- `autoClose`, when true, hides the popup right after a successful Add Entry. used by
-- the macro/keybind/context-menu entry points, not the in-window ones (Players row
-- click, Details tab), which stay open for adding several in a row.
function ns.ShowQuickAdd(key, autoClose, noFocus)
	if not popup then
		createPopup()
	end

	if popup:IsShown() and key ~= currentKey then
		popup.noteBox:SetText("")
		popup.repBox:SetText("")
		popup.featuredCheck:SetChecked(false)
	end
	if popup.addMode then
		popup.setAddMode(false)
	end
	currentKey = key
	autoCloseOnSubmit = autoClose and true or false
	if not ns.GetPlayerRecord(key, false) then
		popup:Hide()
		return
	end
	refresh()
	popup:Show()
	if noFocus then
		return
	end
	-- deferred a frame: focusing synchronously in response to a keybind still lets that
	-- same keystroke's character land in the box, since the key event hasn't finished
	-- processing yet when the binding handler runs
	C_Timer.After(0, function()
		if popup:IsShown() then
			popup.noteBox:SetFocus()
		end
	end)
end

-- one-click +1/-1 standing nudges from the Players table row, without opening the
-- popup. rapid clicks batch into a single entry (commits 2s after the last click).
-- the running total shows immediately via ns.GetPendingAdjustment even though nothing
-- is written to the DB until the batch commits.
local pendingAdjust = {}

function ns.GetPendingAdjustment(key)
	local pending = pendingAdjust[key]
	return pending and pending.delta or 0
end

local function commitPendingAdjust(key)
	local pending = pendingAdjust[key]
	pendingAdjust[key] = nil
	if not pending or pending.delta == 0 then
		return
	end

	local record = ns.GetPlayerRecord(key, false)
	if not record then
		return
	end

	local identity, unit = ns.LiveIdentityForRecord(record)
	local entry = ns.CaptureContext(unit)
	entry.delta = pending.delta
	entry.source = "manual"
	ns.AddEntry(key, identity, entry)

	if popup and popup:IsShown() and currentKey == key then
		refresh()
	end
	ns.RefreshAllTabs()
end

function ns.QuickAdjustStanding(key, delta)
	local pending = pendingAdjust[key]
	if pending then
		pending.delta = pending.delta + delta
		pending.timer:Cancel()
	else
		pending = { delta = delta }
		pendingAdjust[key] = pending
	end
	pending.timer = C_Timer.NewTimer(2, function() commitPendingAdjust(key) end)

	ns.RefreshOverview()
	if ns.RefreshNearbyWindow then
		ns.RefreshNearbyWindow()
	end
end

function ns.SetQuickAddScale(value)
	if popup then
		popup:SetScale(value)
	end
end

-- shared by ns.ApplyPresetToUnit and the radial menu's own OnPick, which captures
-- identity/context ahead of time (see UI/RadialMenu.lua) instead of re-resolving a live
-- unit token at pick time: a hover-opened radial needs the cursor to leave the hovered
-- unit's frame to reach most wedges, so "mouseover" is usually already stale by release.
function ns.ApplyPresetToIdentity(identity, context, preset)
	if not identity then
		return
	end
	local entry = context or {}
	entry.text = (preset.text and preset.text ~= "") and ns.FillPlaceholders(preset.text, entry) or nil
	entry.delta = (preset.delta and preset.delta ~= 0) and preset.delta or nil
	entry.source = "manual"
	ns.AddEntry(identity.key, identity, entry)
	ns.RefreshAllTabs()
end

-- applies a preset directly to the current target, no popup. see UI/RadialMenu.lua
function ns.ApplyPresetToUnit(unit, preset)
	if not (unit and UnitExists(unit) and UnitIsPlayer(unit)) then
		return
	end
	local identity = ns.IdentifyUnit(unit)
	if not identity then
		return
	end
	ns.ApplyPresetToIdentity(identity, ns.CaptureContext(unit), preset)
end

function ns.ApplyPresetToTarget(preset)
	ns.ApplyPresetToUnit("target", preset)
end

-- opens quick-add for an already-resolved identity, skipping target/mouseover
-- resolution entirely. shared by ns.QuickNoteTarget's own tail and the radial menu's tap
-- handler (UI/RadialMenu.lua), which captures identity early (at keydown, via the same
-- resolveActiveUnit it uses for holds) rather than re-resolving "mouseover" fresh at tap
-- release: reaching the tap-vs-drag decision takes a round trip through the secure
-- tap-detection probe, and by then a hover-opened tap's "mouseover" is often already
-- stale (confirmed live), the same staleness class already handled for drag picks.
function ns.QuickNoteIdentity(identity)
	if not identity then
		return
	end
	ns.TouchIdentity(identity.key, identity)
	ns.ShowQuickAdd(identity.key, true)
end

-- dispatches a resolved identity to whichever action a tap-target-action/tap-hover-action
-- setting picked. shared by ns.QuickNoteTarget below and the radial menu's tap handler.
function ns.PerformTapAction(action, identity)
	if not identity then
		return
	end
	if action == "history" then
		ns.TouchIdentity(identity.key, identity)
		ns.SelectHistoryTab(identity.key)
	elseif action == "details" then
		ns.TouchIdentity(identity.key, identity)
		ns.ShowPlayerDetails(identity.key)
	else
		ns.QuickNoteIdentity(identity)
	end
end

-- quick-add for current target. macro/keybind entry point, see Bindings.xml and
-- /wrnote in Slash.lua
function ns.QuickNoteTarget()
	if ns.IsSuppressed() then
		ns.NotifySuppressed()
		return
	end
	-- hovering a group listing in the LFG window takes over the same keybind entirely:
	-- there's no real unit to quick-note there anyway (it's a UI panel, not a world
	-- target/mouseover), so this can't collide with the normal target/mouseover/window
	-- fallback below, which only ever runs when this returns nil.
	if ns.GetHoveredLFGRoster then
		local roster = ns.GetHoveredLFGRoster()
		if roster then
			ns.FilterPlayersByNames(roster)
			return
		end
	end

	local unit, isHover
	if ns.GetSettings().tapTargetEnabled ~= false and UnitExists("target") and UnitIsPlayer("target") then
		unit = "target"
	elseif ns.GetSettings().quickNoteHoverEnabled and UnitExists("mouseover") and UnitIsPlayer("mouseover") then
		unit = "mouseover"
		isHover = true
	end

	if not unit then
		-- == false, not `not ...`: a brand-new settings key reads as nil (not yet
		-- merged in) until the next reload for anyone who had the addon loaded before
		-- this setting existed, and nil has to mean "default (on)", not "off", or the
		-- whole fallback silently breaks for everyone until their next /reload
		if ns.GetSettings().quickNoteFallbackEnabled == false then
			return
		end
		-- no one to quick-note, open the main window instead of just printing to chat.
		-- pressing it again while already open closes it instead of doing nothing
		local mainFrame = ns.EnsureMainFrame()
		if mainFrame:IsShown() then
			mainFrame:Hide()
			return
		end
		if ns.GetSettings().quickNoteFallbackTab == "history" then
			ns.SelectHistoryTab()
		else
			ns.SelectPlayersTab()
		end
		return
	end
	local action = isHover and ns.GetSettings().tapHoverAction or ns.GetSettings().tapTargetAction
	ns.PerformTapAction(action, ns.IdentifyUnit(unit))
end

-- tour preview: shown next to `anchor` without taking keyboard focus; its saved spot
-- is put back on hide
local previewPoints

function ns.ShowQuickAddPreview(key, anchor)
	ns.ShowQuickAdd(key, false, true)
	if not (popup and popup:IsShown()) then
		return
	end
	if not previewPoints then
		previewPoints = {}
		for i = 1, popup:GetNumPoints() do
			previewPoints[i] = { popup:GetPoint(i) }
		end
	end
	popup:ClearAllPoints()
	popup:SetPoint("LEFT", anchor, "RIGHT", 24, 0)
end

function ns.HideQuickAddPreview()
	if not popup then
		return
	end
	popup:Hide()
	if previewPoints then
		popup:ClearAllPoints()
		for _, point in ipairs(previewPoints) do
			popup:SetPoint(unpack(point))
		end
		previewPoints = nil
	end
end

-- quick-add for someone typed by name, from the Players tab, the minimap menu or /wr add
function ns.ShowAddPlayer(first, last)
	if not popup then
		createPopup()
	end
	popup.noteBox:SetText("")
	popup.repBox:SetText("")
	popup.featuredCheck:SetChecked(false)
	currentKey = nil
	autoCloseOnSubmit = false
	popup.setAddMode(true)
	popup.firstBox:SetText(first or "")
	popup.lastBox:SetText(last or "")
	refresh()
	popup:Show()
	C_Timer.After(0, function()
		if popup:IsShown() and popup.addMode then
			if ns.TypedNameKey(popup.firstBox:GetText(), popup.lastBox:GetText()) then
				popup.noteBox:SetFocus()
			else
				popup.firstBox:SetFocus()
			end
		end
	end)
end
