local ns = WorthRemembering

local popup
local currentKey, currentEntry

local DELTA_BUTTONS = { -10, -5, -1, 1, 5, 10 }

local function nudgeDelta(amount)
	local current = tonumber(popup.repBox:GetText()) or 0
	popup.repBox:SetText(tostring(ns.ClampDelta(current + amount)))
end

-- Takes key/entry via StaticPopup's `data` arg (not the module's currentKey/currentEntry)
-- so a right-click context menu can trigger this directly without going through the
-- edit popup first.
StaticPopupDialogs["WR_CONFIRM_DELETE_ENTRY"] = {
	text = "Delete this entry? This cannot be undone.",
	button1 = "Delete",
	button2 = "Cancel",
	OnAccept = function(self, data)
		ns.DeleteEntry(data.key, data.entry)
		ns.RefreshAllTabs()
		if popup and popup:IsShown() and currentKey == data.key and currentEntry == data.entry then
			popup:Hide()
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

function ns.ConfirmDeleteEntry(key, entry)
	StaticPopup_Show("WR_CONFIRM_DELETE_ENTRY", nil, nil, { key = key, entry = entry })
end

local function save()
	if not (currentKey and currentEntry) then
		return
	end
	local text = popup.noteBox:GetText()
	local delta = tonumber(popup.repBox:GetText()) or 0
	local featured = popup.featuredCheck:GetChecked() and true or false
	ns.EditEntry(currentKey, currentEntry, text, delta, featured)
	ns.RefreshAllTabs()
	popup:Hide()
end

-- a featured note needs actual text, keeps the checkbox from implying a state that
-- gets silently dropped on save (see ns.EditEntry)
local function updateFeaturedAvailability()
	local hasText = popup.noteBox:GetText() ~= ""
	if not hasText then
		popup.featuredCheck:SetChecked(false)
	end
	if hasText then
		popup.featuredCheck:Enable()
	else
		popup.featuredCheck:Disable()
	end
end

local function createPopup()
	popup = CreateFrame("Frame", "WREditEntryPopup", UIParent, "BackdropTemplate")
	-- Lets Escape close this window, like Blizzard's own panels.
	tinsert(UISpecialFrames, "WREditEntryPopup")
	popup:SetSize(360, 380)
	popup:SetPoint("CENTER")
	popup:SetFrameStrata("DIALOG")
	-- Toplevel so clicking this popup while Quick Add is also open brings it to the front
	-- instead of whichever opened last/first always winning.
	popup:SetToplevel(true)
	popup:SetClampedToScreen(true)
	popup:SetScale(ns.GetSettings().uiScale)
	popup:SetMovable(true)
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
	popup.title:SetPoint("TOP", 0, -18)
	popup.title:SetText("Edit Entry")

	popup.meta = popup:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	popup.meta:SetPoint("TOP", popup.title, "BOTTOM", 0, -8)

	-- fixed position, not anchored off popup.meta: meta is center-anchored text whose
	-- width varies with the name/timestamp shown, floated off-window for longer names
	local noteLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	noteLabel:SetPoint("TOPLEFT", popup, "TOPLEFT", 38, -76)
	noteLabel:SetText("Note")

	local noteBoxBorder = CreateFrame("Frame", nil, popup, "BackdropTemplate")
	noteBoxBorder:SetSize(284, 128)
	noteBoxBorder:SetPoint("TOPLEFT", noteLabel, "BOTTOMLEFT", 2, -4)
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
	-- EditBox has no text-height query, so instead of measuring content the scroll
	-- child gets a fixed height generous enough for anything. scrollbar and
	-- OnCursorChanged below handle the rest
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
	-- See QuickAdd.lua's same fix: an auto-focused EditBox's default Escape behavior
	-- swallows the keypress before it reaches the close-on-Escape handler.
	popup.noteBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		popup:Hide()
	end)
	popup.noteBox:SetScript("OnTextChanged", updateFeaturedAvailability)

	popup.featuredCheck = CreateFrame("CheckButton", nil, popup, "UICheckButtonTemplate")
	popup.featuredCheck:SetSize(20, 20)
	popup.featuredCheck:SetPoint("TOPLEFT", noteBoxBorder, "BOTTOMLEFT", 0, -8)

	local featuredLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	featuredLabel:SetPoint("LEFT", popup.featuredCheck, "RIGHT", 2, 0)
	featuredLabel:SetText("Featured")

	local repLabel = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	repLabel:SetPoint("TOPLEFT", popup.featuredCheck, "BOTTOMLEFT", -2, -8)
	repLabel:SetText("Standing +/-")

	popup.repBox = CreateFrame("EditBox", nil, popup, "InputBoxTemplate")
	popup.repBox:SetSize(70, 20)
	popup.repBox:SetPoint("TOPLEFT", repLabel, "BOTTOMLEFT", 4, -6)
	popup.repBox:SetAutoFocus(false)
	popup.repBox:SetScript("OnEnterPressed", save)
	popup.repBox:SetScript("OnEscapePressed", function(self)
		self:ClearFocus()
		popup:Hide()
	end)
	-- clamps on focus-lost rather than every keystroke, so typing e.g. "-100" doesn't
	-- get fought mid-entry; still catches it before Enter/Save can submit it, since
	-- OnEditFocusLost fires either way
	popup.repBox:SetScript("OnEditFocusLost", function(self)
		local value = tonumber(self:GetText())
		if value then
			self:SetText(tostring(ns.ClampDelta(value)))
		end
	end)

	-- same delta row as Quick Add: each button adds its value to whatever's already
	-- typed rather than replacing it, so a few clicks can build up an exact delta.
	local deltaRow = CreateFrame("Frame", nil, popup)
	deltaRow:SetSize(1, 20)
	deltaRow:SetPoint("TOPLEFT", popup.repBox, "BOTTOMLEFT", 0, -10)
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
		-- same red/green tint as the Players tab's inline +/- buttons
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

	popup.saveButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
	popup.saveButton:SetSize(90, 24)
	popup.saveButton:SetPoint("BOTTOMLEFT", 20, 16)
	popup.saveButton:SetText("Save")
	popup.saveButton:SetScript("OnClick", save)

	popup.deleteButton = CreateFrame("Button", nil, popup, "UIPanelButtonTemplate")
	popup.deleteButton:SetSize(130, 24)
	popup.deleteButton:SetPoint("BOTTOMRIGHT", -20, 16)
	popup.deleteButton:SetText("Delete This Entry")
	popup.deleteButton:SetScript("OnClick", function()
		ns.ConfirmDeleteEntry(currentKey, currentEntry)
	end)
end

function ns.ShowEditEntry(key, record, entry)
	if not popup then
		createPopup()
	end

	currentKey = key
	currentEntry = entry

	popup.meta:SetText(ns.DisplayName(record, key) .. "  |  " .. ns.FormatTime(entry.time))
	popup.noteBox:SetText(entry.text or "")
	popup.repBox:SetText(entry.delta and tostring(entry.delta) or "")
	popup.featuredCheck:SetChecked(entry.featured and true or false)
	updateFeaturedAvailability()

	popup:Show()
	popup.noteBox:SetFocus()
end
