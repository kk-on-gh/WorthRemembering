local ns = WorthRemembering

local popup
local currentKey
local autoCloseOnSubmit
local layoutPresets -- refresh() above calls this

local function refresh()
	local record = currentKey and ns.GetPlayerRecord(currentKey, false)
	if not record then
		popup:Hide()
		return
	end

	local cr, cg, cb = ns.ClassColor(record.classFile)
	local bracket = ns.GetBracket(record.standing or 0)

	popup.title:SetText(ns.DisplayName(record, currentKey))
	popup.title:SetTextColor(cr, cg, cb)
	popup.standing:SetText("Standing: " .. (record.standing or 0) .. "  (" .. bracket.name .. ")")
	popup.standing:SetTextColor(unpack(bracket.color))
	layoutPresets()
end

-- A single entry can carry both a note and a standing delta at once (e.g. "+5, ninja
-- looted the mats"). Submits whichever of the two fields is filled in; does nothing if
-- both are empty.
local function submitEntry()
	local text = popup.noteBox:GetText()
	local delta = tonumber(popup.repBox:GetText())
	if not currentKey or (text == "" and (not delta or delta == 0)) then
		return
	end

	local record = ns.GetPlayerRecord(currentKey, false)
	if not record then
		return
	end

	local identity, unit = ns.LiveIdentityForRecord(record)
	local entry = ns.CaptureContext(unit)
	entry.text = text ~= "" and text or nil
	entry.delta = delta and delta ~= 0 and delta or nil
	entry.featured = (popup.featuredCheck:GetChecked() and entry.text) and true or nil
	entry.source = "manual"
	ns.AddEntry(currentKey, identity, entry)

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
	if not currentKey then
		return
	end
	-- placeholders ({{loc}} etc) resolved here, at click time, so the note box shows
	-- the actual filled-in text before it submits, not the literal placeholder.
	local record = ns.GetPlayerRecord(currentKey, false)
	local identity, unit
	if record then
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
local PRESETS_TOP_Y = -92
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
	local noteLabelY = PRESETS_TOP_Y - presetsHeight - AFTER_PRESETS_GAP
	popup.noteLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 38, noteLabelY)
	local deltaRowBottomY = noteLabelY - CHAIN_HEIGHT_AFTER_NOTE_LABEL
	popup:SetHeight(-deltaRowBottomY + BOTTOM_GAP + BOTTOM_ROW_HEIGHT + BOTTOM_PAD)
end

local function createPopup()
	popup = CreateFrame("Frame", "WRQuickAddPopup", UIParent, "BackdropTemplate")
	-- Lets Escape close this window, like Blizzard's own panels.
	tinsert(UISpecialFrames, "WRQuickAddPopup")
	popup:SetSize(360, 460)
	popup:SetPoint("CENTER")
	-- above the main window (HIGH strata). toplevel so clicking this popup while Edit
	-- Entry is also open brings it to the front.
	popup:SetFrameStrata("DIALOG")
	popup:SetToplevel(true)
	popup:SetClampedToScreen(true)
	popup:SetScale(ns.GetSettings().uiScale)
	popup:SetMovable(true)
	popup:EnableMouse(true)
	popup:RegisterForDrag("LeftButton")
	popup:SetScript("OnDragStart", popup.StartMoving)
	popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
	popup:SetScript("OnMouseDown", function() popup:Raise() end)
	popup.relayout = relayout
	-- border only, no bgFile, see Overview.lua's mainFrame backdrop. opacity comes
	-- from the separate fill texture below.
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
	popup.title:SetPoint("TOP", 0, -18)

	popup.standing = popup:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	popup.standing:SetPoint("TOP", popup.title, "BOTTOM", 0, -6)

	popup.hint = popup:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	popup.hint:SetPoint("TOP", popup.standing, "BOTTOM", 0, -22)
	popup.hint:SetText("Note and/or standing delta - fill either or both")

	-- one-click preset buttons. layoutPresets resizes this (floored at PRESET_MIN_ROWS)
	-- to however many rows are used, then calls relayout() to push the rest down.
	popup.presetsArea = CreateFrame("Frame", nil, popup)
	popup.presetsArea:SetSize(1, PRESET_ROW_HEIGHT * PRESET_MIN_ROWS)
	popup.presetsArea:SetPoint("TOPLEFT", popup, "TOPLEFT", 20, PRESETS_TOP_Y)

	-- fixed absolute position, set for real by relayout() once the presets height is
	-- known. not chained off popup.hint since everything above here is centered text.
	popup.noteLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	popup.noteLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 38, PRESETS_TOP_Y - PRESET_ROW_HEIGHT * 2 - AFTER_PRESETS_GAP)
	popup.noteLabel:SetText("Note")
	local noteLabel = popup.noteLabel

	-- multi-line, so built by hand (InputBoxTemplate is single-line-only art).
	-- plain EditBox with its own backdrop border, matching the input-box look.
	local noteBoxBorder = CreateFrame("Frame", nil, popup, "BackdropTemplate")
	noteBoxBorder:SetSize(284, NOTE_BOX_HEIGHT)
	noteBoxBorder:SetPoint("TOPLEFT", noteLabel, "BOTTOMLEFT", 2, -NOTE_LABEL_GAP)
	noteBoxBorder:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 10,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	noteBoxBorder:SetBackdropColor(0, 0, 0, 0.6)

	-- Wrapped in a scroll frame: a plain EditBox neither clips nor scrolls overflow on
	-- its own, so a note longer than the box just bled out past its border with no way
	-- to see or reach the rest of it.
	local noteScroll = CreateFrame("ScrollFrame", nil, noteBoxBorder, "UIPanelScrollFrameTemplate")
	noteScroll:SetPoint("TOPLEFT", 6, -6)
	noteScroll:SetPoint("BOTTOMRIGHT", -26, 6)
	-- The EditBox's own click-to-position-cursor hit test only seemed to register on
	-- its first visible line; forwarding focus explicitly on any click in the visible
	-- area is a reliable fallback regardless of where exactly that falls short.
	noteScroll:EnableMouse(true)
	noteScroll:HookScript("OnMouseDown", function()
		popup.noteBox:SetFocus()
	end)

	popup.noteBox = CreateFrame("EditBox", nil, noteScroll)
	popup.noteBox:SetMultiLine(true)
	popup.noteBox:SetFontObject(ChatFontNormal)
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
	popup.featuredCheck:SetPoint("TOPLEFT", noteBoxBorder, "BOTTOMLEFT", 0, -FEATURED_ROW_GAP)

	local featuredLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	featuredLabel:SetPoint("LEFT", popup.featuredCheck, "RIGHT", 2, 0)
	featuredLabel:SetText("Featured")

	local repLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	repLabel:SetPoint("TOPLEFT", popup.featuredCheck, "BOTTOMLEFT", -2, -REP_LABEL_GAP)
	repLabel:SetText("Standing +/-")

	popup.repBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
	popup.repBox:SetSize(70, REP_BOX_HEIGHT)
	popup.repBox:SetPoint("TOPLEFT", repLabel, "BOTTOMLEFT", 4, -REP_BOX_GAP)
	popup.repBox:SetAutoFocus(false)
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
		-- Same red/green tint as the Players tab's inline +/- buttons.
		local tint = button:CreateTexture(nil, "ARTWORK", nil, -1)
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
	popup.addButton:SetSize(100, 24)
	popup.addButton:SetPoint("BOTTOMLEFT", 20, 16)
	popup.addButton:SetText("Add Entry")
	popup.addButton:SetScript("OnClick", submitEntry)

	popup.historyButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
	popup.historyButton:SetSize(110, 24)
	popup.historyButton:SetPoint("BOTTOMRIGHT", -20, 16)
	popup.historyButton:SetText("History")
	popup.historyButton:SetScript("OnClick", function()
		popup:Hide()
		ns.SelectHistoryTab(currentKey)
	end)

	popup.detailsButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
	popup.detailsButton:SetSize(90, 24)
	popup.detailsButton:SetPoint("RIGHT", popup.historyButton, "LEFT", -6, 0)
	popup.detailsButton:SetText("Details")
	popup.detailsButton:SetScript("OnClick", function()
		popup:Hide()
		if ns.ShowPlayerDetails then
			ns.ShowPlayerDetails(currentKey)
		end
	end)
end

-- `autoClose`, when true, hides the popup right after a successful Add Entry. used by
-- the macro/keybind/context-menu entry points, not the in-window ones (Players row
-- click, Details tab), which stay open for adding several in a row.
function ns.ShowQuickAdd(key, autoClose)
	if not popup then
		createPopup()
	end

	currentKey = key
	autoCloseOnSubmit = autoClose and true or false
	if not ns.GetPlayerRecord(key, false) then
		popup:Hide()
		return
	end
	refresh()
	popup:Show()
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

-- quick-add for current target. macro/keybind entry point, see Bindings.xml and
-- /wrnote in Slash.lua
function ns.QuickNoteTarget()
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

	local unit
	if UnitExists("target") and UnitIsPlayer("target") then
		unit = "target"
	elseif ns.GetSettings().quickNoteHoverEnabled and UnitExists("mouseover") and UnitIsPlayer("mouseover") then
		unit = "mouseover"
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
	ns.QuickNoteIdentity(ns.IdentifyUnit(unit))
end
