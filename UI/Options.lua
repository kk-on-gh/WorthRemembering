local ns = WorthRemembering

StaticPopupDialogs["WR_CONFIRM_CLEAR_DATABASE"] = {
	text = "Delete ALL Worth Remembering notes and standing history for every player, on every character? This cannot be undone.",
	button1 = "Clear Everything",
	button2 = "Cancel",
	OnAccept = function()
		ns.ClearDatabase()
		ns.RefreshAllTabs()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

StaticPopupDialogs["WR_CONFIRM_CLEAR_NONNOTABLE"] = {
	text = "Delete %d player(s) with 0 standing and no notes? This cannot be undone.",
	button1 = "Clear Non-Notable",
	button2 = "Cancel",
	OnAccept = function()
		ns.ClearNonNotablePlayers()
		ns.RefreshAllTabs()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- Shared by every slider in Options: a label, a compact slider, and a numeric entry box
-- underneath it for precise values. `opts`:
--   x, y, label, min, max, step, width, isPercent (display/enter as a 0-100 percent
--   instead of the raw 0-1 fraction), getValue, setValue,
--   commitOnRelease (apply only on mouse-up, e.g. UI scale, where applying mid-drag would
--   move the slider out from under the cursor), onLiveChange (optional, called on every
--   drag tick even when commitOnRelease, for a live preview before release/commit).
-- `anchor` is either a plain number (TOPLEFT y-offset from `parent`'s own top) or a frame
-- Dims `container` and recursively disables every interactive descendant inside it
-- (editboxes, checkboxes, buttons, dropdowns), used to gray out a whole section when a
-- master checkbox above it is unchecked, without each box-builder having to track its own
-- widget list.
local function setContainerEnabled(container, enabled)
	container:SetAlpha(enabled and 1 or 0.4)
	local objType = container:GetObjectType()
	if objType == "EditBox" then
		container:EnableMouse(enabled)
		container:EnableKeyboard(enabled)
	elseif objType == "CheckButton" or objType == "Button" then
		if container.SetEnabled then
			container:SetEnabled(enabled)
		elseif enabled then
			container:Enable()
		else
			container:Disable()
		end
	end
	if container.GetChildren then
		for _, child in ipairs({ container:GetChildren() }) do
			setContainerEnabled(child, enabled)
		end
	end
end

local function buildCheckbox(parent, x, y, text, checked, onClick)
	local check = ns.CreateSmallCheckbox(parent, 24, checked, onClick)
	check:SetPoint("TOPLEFT", x, y)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	label:SetPoint("LEFT", check, "RIGHT", 4, 0)
	label:SetText(text)
	check.label = label
	return check
end

-- Vertical space a buildSlider() block occupies, measured from its label's own TOPLEFT
-- (the y passed into buildSlider) down to the bottom of its value box.
local SLIDER_BLOCK_HEIGHT = 52

local setTooltip = ns.AttachTooltip

local function buildSlider(parent, opts)
	local label = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", opts.x, opts.y)
	label:SetText(opts.label)

	local function formatValue(v)
		return tostring(opts.isPercent and math.floor(v * 100 + 0.5) or v)
	end

	local width = opts.width or 150

	local slider = ns.CreateSmallSlider(parent, width, opts.min, opts.max, opts.step,
		opts.getValue, function() end)
	slider:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 2, -12)

	local lowText = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	lowText:SetPoint("TOPLEFT", slider, "BOTTOMLEFT", 0, -2)
	lowText:SetText(formatValue(opts.min) .. (opts.isPercent and "%" or ""))

	local highText = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	highText:SetPoint("TOPRIGHT", slider, "BOTTOMRIGHT", 0, -2)
	highText:SetText(formatValue(opts.max) .. (opts.isPercent and "%" or ""))

	local valueBox = ns.CreateSmallEditBox(parent, 32, 14)
	valueBox:SetPoint("TOP", slider, "BOTTOM", 0, -2)
	valueBox:SetText(formatValue(opts.getValue()))

	slider:SetScript("OnValueChanged", function(_, value)
		valueBox:SetText(formatValue(value))
		if opts.commitOnRelease then
			if opts.onLiveChange then
				opts.onLiveChange(value)
			end
		else
			opts.setValue(value)
		end
	end)
	if opts.commitOnRelease then
		slider:SetScript("OnMouseUp", function(self)
			opts.setValue(self:GetValue())
		end)
	end

	local function applyBox()
		local num = tonumber(valueBox:GetText())
		if num then
			if opts.isPercent then
				num = num / 100
			end
			num = math.max(opts.min, math.min(opts.max, num))
			slider:SetValue(num)
			opts.setValue(num)
		end
		valueBox:SetText(formatValue(opts.getValue()))
		valueBox:ClearFocus()
	end
	valueBox:SetScript("OnEnterPressed", applyBox)
	valueBox:SetScript("OnEditFocusLost", applyBox)
	valueBox:SetScript("OnEscapePressed", function(self)
		self:SetText(formatValue(opts.getValue()))
		self:ClearFocus()
	end)

	return valueBox
end

-- a bordered, titled box matching the grouped-section look used throughout Options.
-- spans the panel's full width (12px side margins), fixed height, title in top-left.
local function createSectionBox(parent, y, height, title)
	local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	box:SetPoint("TOPLEFT", 12, y)
	box:SetPoint("TOPRIGHT", -12, y)
	box:SetHeight(height)
	ns.ApplyPanelBackdrop(box, 0.4)

	local titleText = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	titleText:SetPoint("TOPLEFT", 8, -6)
	titleText:SetText(title)

	return box, titleText
end

local function buildWindowBox(parent, y)
	local height = 144
	local box = createSectionBox(parent, y, height, "Window")

	buildSlider(box, {
		x = 10, y = -26, label = "Opacity", min = 0.3, max = 1.0, step = 0.05, width = 150,
		isPercent = true,
		getValue = function() return ns.GetSettings().windowAlpha end,
		setValue = function(value)
			ns.GetSettings().windowAlpha = value
			ns.EnsureMainFrame():SetAlpha(value)
		end,
	})

	buildSlider(box, {
		x = 190, y = -26, label = "UI scale", min = 0.6, max = 1.6, step = 0.1, width = 150,
		isPercent = true, commitOnRelease = true,
		getValue = function() return ns.GetSettings().uiScale end,
		setValue = function(value)
			ns.GetSettings().uiScale = value
			ns.EnsureMainFrame():SetScale(value)
			if ns.SetQuickAddScale then
				ns.SetQuickAddScale(value)
			end
			-- a larger scale on an already-tall window can push its bottom edge (and
			-- the resize grip with it) off the bottom of the screen with no way to drag
			-- it back; this pulls it back on-screen if that just happened
			if ns.ReclampMainFrame then
				ns.ReclampMainFrame()
			end
		end,
	})

	local timeLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	timeLabel:SetPoint("TOPLEFT", 10, -90)
	timeLabel:SetText("Time format")
	local timeDropdown = ns.CreateDropdown(box, {
		{ value = "24h", text = "24-hour" },
		{ value = "12h", text = "12-hour" },
	},
		function(value) return ns.GetSettings().timeFormat == value end,
		function(value)
			ns.GetSettings().timeFormat = value
			if ns.RefreshHistory then
				ns.RefreshHistory()
			end
		end,
		140, 20)
	timeDropdown:SetPoint("TOPLEFT", timeLabel, "BOTTOMLEFT", 2, -4)

	local dateLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	dateLabel:SetPoint("TOPLEFT", 190, -90)
	dateLabel:SetText("Date format")
	local dateDropdown = ns.CreateDropdown(box, {
		{ value = "ymd", text = "YYYY-MM-DD" },
		{ value = "mdy", text = "MM-DD-YYYY" },
		{ value = "dmy", text = "DD-MM-YYYY" },
	},
		function(value) return ns.GetSettings().dateFormat == value end,
		function(value)
			ns.GetSettings().dateFormat = value
			if ns.RefreshHistory then
				ns.RefreshHistory()
			end
		end,
		140, 20)
	dateDropdown:SetPoint("TOPLEFT", dateLabel, "BOTTOMLEFT", 2, -4)

	return y - height - 6
end

local function buildStandingBox(parent, y)
	local height = 64
	local box = createSectionBox(parent, y, height, "Standing")

	local neutralLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	neutralLabel:SetPoint("TOPLEFT", 10, -26)
	neutralLabel:SetText("Neutral band (+/-)")
	local neutralBox = ns.CreateSmallEditBox(box, 30, 14, true)
	neutralBox:SetPoint("TOPLEFT", neutralLabel, "BOTTOMLEFT", 4, -4)
	neutralBox:SetText(tostring(ns.GetSettings().neutralBand))
	setTooltip(neutralBox, "Standing within this range of 0 shows as neutral.")
	local function applyNeutral()
		local value = math.max(0, math.min(ns.STANDING_MAX, tonumber(neutralBox:GetText()) or 0))
		ns.GetSettings().neutralBand = value
		neutralBox:SetText(tostring(value))
		neutralBox:ClearFocus()
		ns.RefreshOverview()
		if ns.RefreshHistory then
			ns.RefreshHistory()
		end
	end
	neutralBox:SetScript("OnEnterPressed", applyNeutral)
	neutralBox:SetScript("OnEditFocusLost", applyNeutral)
	neutralBox:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(ns.GetSettings().neutralBand))
		self:ClearFocus()
	end)

	local shiftLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	shiftLabel:SetPoint("TOPLEFT", 190, -26)
	shiftLabel:SetText("Shift-click +/- amount")
	local shiftBox = ns.CreateSmallEditBox(box, 30, 14, true)
	shiftBox:SetPoint("TOPLEFT", shiftLabel, "BOTTOMLEFT", 4, -4)
	shiftBox:SetText(tostring(ns.GetSettings().shiftClickAmount))
	setTooltip(shiftBox, "Shift-click the +/- buttons on the Players tab to adjust standing by this amount instead of 1.")
	local function applyShift()
		local value = math.max(1, math.min(ns.STANDING_MAX, tonumber(shiftBox:GetText()) or 1))
		ns.GetSettings().shiftClickAmount = value
		shiftBox:SetText(tostring(value))
		shiftBox:ClearFocus()
	end
	shiftBox:SetScript("OnEnterPressed", applyShift)
	shiftBox:SetScript("OnEditFocusLost", applyShift)
	shiftBox:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(ns.GetSettings().shiftClickAmount))
		self:ClearFocus()
	end)

	return y - height - 6
end

-- Boxed with its own border/title so every scale/direction/row-limit control here reads
-- as belonging to the Nearby window, rather than blending into the General tab's rows.
local function buildNearbyWindowControl(parent, y)
	local box = createSectionBox(parent, y, 234, "Nearby Window")

	buildCheckbox(box, 8, -22, "Show the Nearby window (notable players with a visible nameplate)",
		ns.GetSettings().nearbyWindowEnabled,
		function(checked) ns.SetNearbyWindowShown(checked) end)

	buildSlider(box, {
		x = 10, y = -44, label = "Idle opacity", min = 0.1, max = 1.0, step = 0.05,
		width = 150, isPercent = true,
		getValue = function() return ns.GetSettings().nearbyIdleAlpha end,
		setValue = function(value)
			ns.GetSettings().nearbyIdleAlpha = value
			if ns.ApplyNearbyAlphaSettings then ns.ApplyNearbyAlphaSettings() end
		end,
	})

	buildSlider(box, {
		x = 190, y = -44, label = "Hover opacity", min = 0.1, max = 1.0, step = 0.05,
		width = 150, isPercent = true,
		getValue = function() return ns.GetSettings().nearbyHoverAlpha end,
		setValue = function(value)
			ns.GetSettings().nearbyHoverAlpha = value
			if ns.ApplyNearbyAlphaSettings then ns.ApplyNearbyAlphaSettings() end
		end,
	})

	local SCALE_ROW_Y = -104

	local growDropdown
	buildSlider(box, {
		x = 10, y = SCALE_ROW_Y, label = "Scale", min = 0.6, max = 1.6, step = 0.1,
		width = 150, isPercent = true,
		getValue = function() return ns.GetSettings().nearbyScale end,
		setValue = function(value)
			if ns.SetNearbyScale then ns.SetNearbyScale(value) end
		end,
	})

	local growLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	growLabel:SetPoint("TOPLEFT", 190, SCALE_ROW_Y)
	growLabel:SetText("Growth direction")
	growDropdown = ns.CreateDropdown(box, {
		{ value = "down", text = "Down" },
		{ value = "up", text = "Up" },
	},
		function(value) return ns.GetSettings().nearbyGrowDirection == value end,
		function(value)
			if ns.SetNearbyGrowDirection then ns.SetNearbyGrowDirection(value) end
		end,
		90, 20)
	growDropdown:SetPoint("TOPLEFT", growLabel, "BOTTOMLEFT", 2, -14)
	setTooltip(growDropdown, "Down: header on top, list grows downward.\nUp: header on bottom, list grows upward.")
	-- Lets NearbyWindow.lua refresh this dropdown's label when it flips the setting itself
	-- (switching to a fixed size forces grow direction to "down").
	ns.RefreshNearbyGrowDropdown = function() growDropdown:Refresh() end

	local staticCheckY = SCALE_ROW_Y - SLIDER_BLOCK_HEIGHT - 10
	local staticCheck = buildCheckbox(box, 8, staticCheckY,
		"Use a fixed, resizable size (drag the corner grip) instead of auto-sizing",
		ns.GetSettings().nearbyStaticSize,
		function(checked)
			if ns.SetNearbyStaticSize then ns.SetNearbyStaticSize(checked) end
			growDropdown:SetEnabled(not checked)
		end)
	-- growth direction only matters while the window auto-sizes to its content, a
	-- fixed/resizable window doesn't grow in either direction, so it's meaningless
	-- while static size is on.
	growDropdown:SetEnabled(not ns.GetSettings().nearbyStaticSize)

	local limitLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	limitLabel:SetPoint("TOPLEFT", 10, staticCheckY - 22)
	limitLabel:SetText("Visible row limit (scrolls beyond this; ignored when using a fixed size)")

	local limitBox = ns.CreateSmallEditBox(box, 30, 14, true)
	limitBox:SetPoint("LEFT", limitLabel, "RIGHT", 6, 0)
	limitBox:SetText(tostring(ns.GetSettings().nearbyVisibleRowLimit))
	local function applyLimit()
		local value = tonumber(limitBox:GetText()) or 8
		value = math.max(1, math.min(50, value))
		ns.GetSettings().nearbyVisibleRowLimit = value
		limitBox:SetText(tostring(value))
		limitBox:ClearFocus()
		if ns.RefreshNearbyWindow then
			ns.RefreshNearbyWindow()
		end
	end
	limitBox:SetScript("OnEnterPressed", applyLimit)
	limitBox:SetScript("OnEditFocusLost", applyLimit)
	limitBox:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(ns.GetSettings().nearbyVisibleRowLimit))
		self:ClearFocus()
	end)

	local height = 220
	box:SetHeight(height)
	return y - height - 6
end

-- Boxed the same way as the Nearby Window section above it. Size/offsetX/offsetY are
-- sliders rather than text fields, so the icon can be dialed in live against a real
-- nameplate instead of typing numbers and re-checking.
local function buildNameplateIconControl(parent, y)
	local settings = ns.GetSettings().nameplateIcon

	local box = createSectionBox(parent, y, 186, "Nameplate Icon")

	buildCheckbox(box, 8, -22, "Show a standing-colored icon above notable players' nameplates",
		settings.enabled,
		function(checked)
			settings.enabled = checked
			if ns.RefreshNameplateIcons then ns.RefreshNameplateIcons() end
		end)

	local function liveUpdate()
		if ns.RefreshNameplateIcons then ns.RefreshNameplateIcons() end
	end

	local SLIDER_WIDTH = 150
	local SLIDER_ROW_Y = -54

	buildSlider(box, {
		x = 10, y = SLIDER_ROW_Y, label = "Size", min = 4, max = 64, step = 1, width = SLIDER_WIDTH,
		getValue = function() return settings.size end,
		setValue = function(value) settings.size = math.floor(value + 0.5); liveUpdate() end,
	})

	buildSlider(box, {
		x = 180, y = SLIDER_ROW_Y, label = "Horizontal offset", min = -200, max = 200, step = 1,
		width = SLIDER_WIDTH,
		getValue = function() return settings.offsetX end,
		setValue = function(value) settings.offsetX = math.floor(value + 0.5); liveUpdate() end,
	})

	buildSlider(box, {
		x = 350, y = SLIDER_ROW_Y, label = "Vertical offset", min = -200, max = 200, step = 1,
		width = SLIDER_WIDTH,
		getValue = function() return settings.offsetY end,
		setValue = function(value) settings.offsetY = math.floor(value + 0.5); liveUpdate() end,
	})

	local neutralCheckY = SLIDER_ROW_Y - SLIDER_BLOCK_HEIGHT - 10
	buildCheckbox(box, 8, neutralCheckY, "Hide the icon for neutral-standing players",
		settings.hideNeutral,
		function(checked)
			settings.hideNeutral = checked
			liveUpdate()
		end)

	-- shows the icon (one fixed color) on every visible nameplate, notable or not, so the
	-- size/offset sliders can be tested without needing an actual notable one in range.
	-- not persisted, always off at login.
	buildCheckbox(box, 8, neutralCheckY - 20,
		"Preview on every nearby nameplate (for adjusting size/position)",
		false,
		function(checked)
			if ns.SetNameplateIconPreview then
				ns.SetNameplateIconPreview(checked)
			end
		end)

	local height = 170
	box:SetHeight(height)
	return y - height - 6
end

local function buildChatMinimapBox(parent, y)
	local height = 76
	local box = createSectionBox(parent, y, height, "Chat & Minimap")

	local chatSettings = ns.GetSettings().chatIndicator
	buildCheckbox(box, 8, -22, "Show a standing tag, e.g. [+10], after notable players' names in chat",
		chatSettings.enabled,
		function(checked) chatSettings.enabled = checked end)

	local minimapSettings = ns.GetSettings().minimapIcon
	buildCheckbox(box, 8, -46, "Show the minimap icon",
		not minimapSettings.hide,
		function(checked) ns.SetMinimapIconShown(checked) end)

	return y - height - 6
end

-- Matches the <Binding name="..."> in Bindings.xml.
local QUICKNOTE_BINDING = "WR_QUICKNOTE"

local function quickNoteKeyText()
	return GetBindingKey(QUICKNOTE_BINDING) or "Not Bound"
end

-- A binding can have more than one key assigned; clear all of them before assigning a
-- new one so this control always shows (and sets) a single key.
local function clearQuickNoteBinding()
	local key = GetBindingKey(QUICKNOTE_BINDING)
	while key do
		SetBinding(key, nil)
		key = GetBindingKey(QUICKNOTE_BINDING)
	end
end

-- defined further down (needs createHelpPopupFrame, declared later in this file);
-- forward-declared so buildKeybindControl below can still reference them
local showGlobalHotkeyHelpPopup
local GLOBAL_HOTKEY_HELP_TEXT

local function buildKeybindControl(parent, y)
	local height = 142
	local box, titleText = createSectionBox(parent, y, height, "Global Hotkey")

	local helpButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	helpButton:SetSize(16, 16)
	helpButton:SetText("?")
	helpButton:SetPoint("LEFT", titleText, "RIGHT", 4, 0)
	helpButton:SetScript("OnClick", function() showGlobalHotkeyHelpPopup() end)
	ns.AttachHookTooltip(helpButton, GLOBAL_HOTKEY_HELP_TEXT)

	local keyButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	keyButton:SetSize(130, 20)
	keyButton:SetPoint("TOPLEFT", 10, -24)
	keyButton:SetText(quickNoteKeyText())

	local clearButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	clearButton:SetSize(50, 20)
	clearButton:SetPoint("LEFT", keyButton, "RIGHT", 6, 0)
	clearButton:SetText("Clear")

	local hint = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", keyButton, "BOTTOMLEFT", -2, -4)
	hint:SetText("Click the key button, then press a key. Escape cancels.")

	-- forward-declared: the checkbox's own onClick (defined before this) needs to gray
	-- the dropdown out, but the dropdown itself is created after the checkbox so its
	-- label can anchor off the checkbox's own label
	local fallbackDropdown

	local fallbackCheck = ns.CreateSmallCheckbox(box, 24, ns.GetSettings().quickNoteFallbackEnabled,
		function(checked)
			ns.GetSettings().quickNoteFallbackEnabled = checked
			setContainerEnabled(fallbackDropdown, checked)
		end)
	fallbackCheck:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)

	local fallbackLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	fallbackLabel:SetPoint("LEFT", fallbackCheck, "RIGHT", 4, 0)
	fallbackLabel:SetText("With no target, open window to")

	fallbackDropdown = ns.CreateDropdown(box, {
		{ value = "players", text = "Players" },
		{ value = "history", text = "History" },
	},
		function(value) return ns.GetSettings().quickNoteFallbackTab == value end,
		function(value) ns.GetSettings().quickNoteFallbackTab = value end,
		100, 20)
	fallbackDropdown:SetPoint("LEFT", fallbackLabel, "RIGHT", 8, 0)
	setContainerEnabled(fallbackDropdown, ns.GetSettings().quickNoteFallbackEnabled)

	local hoverCheck = ns.CreateSmallCheckbox(box, 24, ns.GetSettings().quickNoteHoverEnabled,
		function(checked) ns.GetSettings().quickNoteHoverEnabled = checked end)
	-- chained off the checkbox above it (not a guessed fixed y): a checkbox row is
	-- taller than a plain text line, so a fixed offset sized for the old label-only
	-- layout overlapped this with the row above it
	hoverCheck:SetPoint("TOPLEFT", fallbackCheck, "BOTTOMLEFT", 0, -10)
	local hoverLabel = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	hoverLabel:SetPoint("LEFT", hoverCheck, "RIGHT", 4, 0)
	hoverLabel:SetText("Quick-Note a player on hover, not just when targeting")

	local function stopListening()
		keyButton:SetText(quickNoteKeyText())
		keyButton:EnableKeyboard(false)
		keyButton:SetScript("OnKeyDown", nil)
	end

	keyButton:SetScript("OnClick", function(self)
		self:SetText("Press a key...")
		self:EnableKeyboard(true)
		self:SetScript("OnKeyDown", function(_, key)
			if key == "ESCAPE" then
				stopListening()
				return
			end
			-- A bare modifier press isn't a usable binding on its own; wait for the
			-- actual key it's held down with.
			if key == "LSHIFT" or key == "RSHIFT" or key == "LCTRL" or key == "RCTRL"
				or key == "LALT" or key == "RALT" or key == "UNKNOWN" then
				return
			end
			local combo = key
			if IsAltKeyDown() then combo = "ALT-" .. combo end
			if IsControlKeyDown() then combo = "CTRL-" .. combo end
			if IsShiftKeyDown() then combo = "SHIFT-" .. combo end
			clearQuickNoteBinding()
			SetBinding(combo, QUICKNOTE_BINDING)
			SaveBindings(GetCurrentBindingSet())
			stopListening()
			if ns.RefreshRadialMenuBinding then
				ns.RefreshRadialMenuBinding()
			end
		end)
	end)

	clearButton:SetScript("OnClick", function()
		clearQuickNoteBinding()
		SaveBindings(GetCurrentBindingSet())
		stopListening()
		if ns.RefreshRadialMenuBinding then
			ns.RefreshRadialMenuBinding()
		end
	end)

	return y - height - 6
end

local function buildLFGIntegrationControl(parent, y)
	local height = 50
	local box = createSectionBox(parent, y, height, "Group Finder")

	local check = buildCheckbox(box, 8, -24, "Show WR standing on group finder listings",
		ns.GetSettings().lfgIntegrationEnabled,
		function(checked) ns.GetSettings().lfgIntegrationEnabled = checked end)
	ns.AttachHookTooltip(check,
		"Standing tags on the Browse tab's listings and their hover tooltips, plus the global keybind's \"pull up this group's roster\" shortcut while hovering one.")

	return y - height - 6
end

local function buildClearDatabaseControl(parent, y)
	local height = 84
	local box = createSectionBox(parent, y, height, "Danger Zone")

	local clearButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	clearButton:SetSize(130, 20)
	clearButton:SetText("Clear Database")
	clearButton:SetPoint("TOPLEFT", 10, -26)
	clearButton:SetScript("OnClick", function()
		StaticPopup_Show("WR_CONFIRM_CLEAR_DATABASE")
	end)

	local hint = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("LEFT", clearButton, "RIGHT", 8, 0)
	hint:SetText("Deletes every note and standing for every player, on every character. Cannot be undone.")

	local clearNonNotableButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	clearNonNotableButton:SetSize(140, 20)
	clearNonNotableButton:SetText("Clear Non-Notable")
	clearNonNotableButton:SetPoint("TOPLEFT", clearButton, "BOTTOMLEFT", 0, -6)
	clearNonNotableButton:SetScript("OnClick", function()
		StaticPopup_Show("WR_CONFIRM_CLEAR_NONNOTABLE", ns.CountNonNotablePlayers())
	end)

	local nonNotableHint = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	nonNotableHint:SetPoint("LEFT", clearNonNotableButton, "RIGHT", 8, 0)
	nonNotableHint:SetText("Deletes players with exactly 0 standing and no notes (e.g. bare auto-tracked entries).")

	return y - height - 6
end

local AUTO_PRUNE_CRITERIA_OPTIONS = {
	{ value = "unnoted", text = "No notes" },
	{ value = "unrepped", text = "Zero standing" },
	{ value = "neutral", text = "Neutral-band standing" },
	{ value = "notSeenDays", text = "Not seen in X days" },
}

local function buildAutoPruneControl(parent, y)
	local height = 120
	local box = createSectionBox(parent, y, height, "Auto-Prune (on login)")
	local settings = ns.GetSettings().autoPrune

	local daysBox

	local function summaryText()
		local names = {}
		for _, opt in ipairs(AUTO_PRUNE_CRITERIA_OPTIONS) do
			if settings.criteria[opt.value] then
				names[#names + 1] = opt.text
			end
		end
		return #names == 0 and "No criteria selected" or table.concat(names, ", ")
	end

	local dropdown = ns.CreateMultiSelectDropdown(box, AUTO_PRUNE_CRITERIA_OPTIONS,
		function(value) return settings.criteria[value] == true end,
		function(value)
			settings.criteria[value] = not settings.criteria[value]
			setContainerEnabled(daysBox, settings.criteria.notSeenDays)
		end,
		summaryText, 220)
	dropdown:SetPoint("TOPLEFT", 10, -48)

	local daysLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	daysLabel:SetPoint("LEFT", dropdown, "RIGHT", 16, 0)
	daysLabel:SetText("Days")

	daysBox = ns.CreateSmallEditBox(box, 40, 14, true)
	daysBox:SetPoint("LEFT", daysLabel, "RIGHT", 6, 0)
	daysBox:SetText(tostring(settings.notSeenDaysValue))
	local function applyDays()
		local value = math.max(1, tonumber(daysBox:GetText()) or 30)
		settings.notSeenDaysValue = value
		daysBox:SetText(tostring(value))
		daysBox:ClearFocus()
	end
	daysBox:SetScript("OnEnterPressed", applyDays)
	daysBox:SetScript("OnEditFocusLost", applyDays)
	daysBox:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(settings.notSeenDaysValue))
		self:ClearFocus()
	end)
	setContainerEnabled(daysBox, settings.criteria.notSeenDays)

	buildCheckbox(box, 8, -24, "Automatically delete matching players when the addon loads",
		settings.enabled,
		function(checked) settings.enabled = checked end)

	local hint = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", 10, -78)
	hint:SetPoint("RIGHT", -10, 0)
	hint:SetJustifyH("LEFT")
	hint:SetWordWrap(true)
	hint:SetText("Deletes only players matching every checked criterion above. No confirmation, runs silently on login.")

	return y - height - 6
end

-- Refreshes every tab after a bracket label/color edit, since standing displays
-- (colors, bracket names) appear throughout the addon, not just in Options.
local function refreshAllBracketDisplays()
	ns.RefreshAllTabs()
end

-- Modern-API color swatch button: a colored square that opens the Blizzard color picker
-- on click. `getColor()`/`setColor(r,g,b)` read/write the live setting; cancel restores
-- whatever color was active before the picker opened (Blizzard's own cancelFunc contract).
local function createColorSwatch(parent, getColor, setColor)
	local swatch = CreateFrame("Button", nil, parent, "BackdropTemplate")
	swatch:SetSize(20, 20)
	swatch:SetBackdrop({
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 8,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	swatch:SetBackdropBorderColor(1, 0.82, 0, 0.5)

	local tex = swatch:CreateTexture(nil, "ARTWORK")
	tex:SetPoint("TOPLEFT", 3, -3)
	tex:SetPoint("BOTTOMRIGHT", -3, 3)

	local function refresh()
		tex:SetColorTexture(getColor())
	end

	swatch:SetScript("OnClick", function()
		local r, g, b = getColor()
		local info = {
			r = r, g = g, b = b,
			swatchFunc = function()
				setColor(ColorPickerFrame:GetColorRGB())
				refresh()
			end,
			cancelFunc = function()
				setColor(r, g, b)
				refresh()
			end,
		}
		if ColorPickerFrame.SetupColorPickerAndShow then
			ColorPickerFrame:SetupColorPickerAndShow(info)
		else
			ColorPickerFrame.func = info.swatchFunc
			ColorPickerFrame.cancelFunc = info.cancelFunc
			ColorPickerFrame:SetColorRGB(r, g, b)
			ShowUIPanel(ColorPickerFrame)
		end
	end)

	refresh()
	return swatch
end

-- 3 rows (Positive/Neutral/Negative) x up to 4 columns (mild -> extreme, matching
-- column position on both the positive and negative rows). wider boxes than the
-- original single 9-across row, which truncated longer words ("Blacklisted",
-- "Acquaintance", "Legendary").
local FIELDS = {
	{ group = "positive", index = 1, row = 1, col = 1, range = "0 to 25" },
	{ group = "positive", index = 2, row = 1, col = 2, range = "26 to 50" },
	{ group = "positive", index = 3, row = 1, col = 3, range = "51 to 75" },
	{ group = "positive", index = 4, row = 1, col = 4, range = "76 to 100" },
	{ group = "zero", row = 2, col = 1, range = "0" },
	{ group = "negative", index = 1, row = 3, col = 1, range = "-25 to 0" },
	{ group = "negative", index = 2, row = 3, col = 2, range = "-50 to -26" },
	{ group = "negative", index = 3, row = 3, col = 3, range = "-75 to -51" },
	{ group = "negative", index = 4, row = 3, col = 4, range = "-100 to -76" },
}
local ROW_LABELS = { "Positive", "Neutral", "Negative" }
local BOX_WIDTH, BOX_GAP, ROW_HEIGHT, LABEL_WIDTH = 120, 10, 44, 70
-- The edit box is narrower than the column pitch (BOX_WIDTH) so a color swatch fits
-- beside it within the same column slot, without widening the overall grid.
local EDIT_WIDTH, SWATCH_SIZE, SWATCH_GAP = 92, 20, 6

local function buildRepBracketControl(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", -34, 0)

	local scrollChild = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(scrollChild)
	scroll:SetScript("OnSizeChanged", function(self, width)
		scrollChild:SetWidth(width)
	end)
	scrollChild:SetWidth(parent:GetWidth())

	local y = -8

	local boxHeight = 80 + ROW_HEIGHT * 3 + 10
	local box = createSectionBox(scrollChild, y, boxHeight, "Reputation Brackets")
	y = y - boxHeight - 6

	y = buildStandingBox(scrollChild, y)
	scrollChild:SetHeight(-y + 10)

	-- just the preset name, the always-visible 9 fields below already show the
	-- actual labels for whichever preset is selected.
	local options = {}
	for _, key in ipairs(ns.REP_BRACKET_PRESET_ORDER) do
		options[#options + 1] = { value = key, text = key:sub(1, 1):upper() .. key:sub(2) }
	end
	options[#options + 1] = { value = "custom", text = "Custom" }

	-- 9 text fields across 3 rows (Positive/Neutral/Negative), always visible (not
	-- just for "Custom"), showing whichever preset is currently active. editing any
	-- field auto-promotes to "Custom" (copying the active preset's labels first, so the
	-- other 8 fields keep their values).
	local customRow = CreateFrame("Frame", nil, box)
	customRow:SetSize(1, ROW_HEIGHT * 3)

	local dropdown -- assigned below, read by field callbacks
	local boxes = {}

	local function getFieldValue(field, labels)
		if field.group == "zero" then
			return labels.zero
		end
		return labels[field.group][field.index]
	end

	local function refreshFieldDisplay()
		local labels = ns.GetActiveBracketLabels()
		for i, field in ipairs(FIELDS) do
			boxes[i]:SetText(getFieldValue(field, labels))
		end
	end

	local function promoteToCustom()
		local settings = ns.GetSettings()
		if settings.repBracketPreset == "custom" then
			return
		end
		local active = ns.GetActiveBracketLabels()
		settings.repBracketCustomLabels = {
			zero = active.zero,
			positive = { active.positive[1], active.positive[2], active.positive[3], active.positive[4] },
			negative = { active.negative[1], active.negative[2], active.negative[3], active.negative[4] },
		}
		settings.repBracketPreset = "custom"
		dropdown:SetText("Custom")
	end

	local function setFieldValue(field, text)
		promoteToCustom()
		local labels = ns.GetSettings().repBracketCustomLabels
		if field.group == "zero" then
			labels.zero = text
		else
			labels[field.group][field.index] = text
		end
	end

	for _, rowIndex in ipairs({ 1, 2, 3 }) do
		local rowLabel = customRow:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		rowLabel:SetWidth(LABEL_WIDTH)
		rowLabel:SetJustifyH("LEFT")
		rowLabel:SetText(ROW_LABELS[rowIndex])
		rowLabel:SetPoint("TOPLEFT", customRow, "TOPLEFT", 6, -(rowIndex - 1) * ROW_HEIGHT - 14)
	end

	for i, field in ipairs(FIELDS) do
		local rangeLabel = customRow:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		rangeLabel:SetText(field.range)

		local box = ns.CreateSmallEditBox(customRow, EDIT_WIDTH, 16)
		local x = LABEL_WIDTH + (field.col - 1) * (BOX_WIDTH + BOX_GAP)
		local y = -(field.row - 1) * ROW_HEIGHT - 14
		box:SetPoint("TOPLEFT", customRow, "TOPLEFT", x, y)
		rangeLabel:SetPoint("BOTTOMLEFT", box, "TOPLEFT", 2, 2)
		box:SetScript("OnEnterPressed", function(self)
			setFieldValue(field, self:GetText())
			self:ClearFocus()
			refreshAllBracketDisplays()
		end)
		box:SetScript("OnEditFocusLost", function(self)
			setFieldValue(field, self:GetText())
			refreshAllBracketDisplays()
		end)
		boxes[i] = box

		-- no color to edit for the neutral/zero bracket, it's always a fixed grey
		-- (see ns.GetBracket), not part of settings.repBracketColors.
		if field.group ~= "zero" then
			local swatch = createColorSwatch(customRow,
				function() return unpack(ns.GetSettings().repBracketColors[field.group][field.index]) end,
				function(r, g, b)
					ns.GetSettings().repBracketColors[field.group][field.index] = { r, g, b }
					refreshAllBracketDisplays()
				end)
			swatch:SetPoint("LEFT", box, "RIGHT", SWATCH_GAP, 0)
		end
	end

	local presetLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	presetLabel:SetPoint("TOPLEFT", 10, -24)
	presetLabel:SetText("Preset")

	dropdown = ns.CreateDropdown(box, options,
		function(value) return ns.GetSettings().repBracketPreset == value end,
		function(value)
			ns.GetSettings().repBracketPreset = value
			refreshFieldDisplay()
			refreshAllBracketDisplays()
		end,
		200)
	dropdown:SetPoint("TOPLEFT", presetLabel, "BOTTOMLEFT", 4, -4)
	customRow:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", -4, -16)

	refreshFieldDisplay()
end

-- wrapped in a scroll frame, enough rows have accumulated (opacity/scale, formats,
-- neutral band, shift-click, and the whole Nearby-window section) that this tab can
-- run taller than the window's minimum height, same as Statistics.lua.
-- each build*(parent, y) call below returns the y to start the next box at, threading a
-- single top-level cursor through fixed-height boxes, not derived from any previous
-- box's live GetHeight(), so it avoids the chained-anchor mismatch that template
-- children (e.g. UICheckButtonTemplate) cause elsewhere.
local function buildGeneralPanel(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", -34, 0)

	local scrollChild = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(scrollChild)
	scroll:SetScript("OnSizeChanged", function(self, width)
		scrollChild:SetWidth(width)
	end)
	scrollChild:SetWidth(parent:GetWidth())

	local y = -8
	y = buildKeybindControl(scrollChild, y)
	y = buildWindowBox(scrollChild, y)
	y = buildNearbyWindowControl(scrollChild, y)
	y = buildNameplateIconControl(scrollChild, y)
	y = buildChatMinimapBox(scrollChild, y)
	y = buildLFGIntegrationControl(scrollChild, y)
	y = buildAutoPruneControl(scrollChild, y)
	y = buildClearDatabaseControl(scrollChild, y)

	scrollChild:SetHeight(-y + 10)
end

-- built lazily (once) since it's only ever needed after the user clicks a "?" button.
-- shared by the Auto-Add note field (this tab) and the quick-add presets (Options >
-- Presets), since both support the same placeholders.
-- shared shell for the small informational popups in this file (placeholders, macro
-- usage, etc): backdrop, close button, title. caller fills in the body below `title`.
local function createHelpPopupFrame(globalName, width, height, title)
	local popup = CreateFrame("Frame", globalName, UIParent, "BackdropTemplate")
	tinsert(UISpecialFrames, globalName)
	popup:SetSize(width, height)
	popup:SetPoint("CENTER")
	popup:SetFrameStrata("DIALOG")
	popup:SetToplevel(true)
	popup:SetClampedToScreen(true)
	popup:SetMovable(true)
	popup:EnableMouse(true)
	popup:RegisterForDrag("LeftButton")
	popup:SetScript("OnDragStart", popup.StartMoving)
	popup:SetScript("OnDragStop", popup.StopMovingOrSizing)
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

	local titleText = popup:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	titleText:SetPoint("TOP", 0, -18)
	titleText:SetText(title)

	return popup
end

-- shared between the popup body and the [?] button's own hover tooltip (see the "Misc"
-- requirement that every help popup's text also be reachable on hover, not just on
-- click), so the two can never drift out of sync with each other.
local PRESET_HELP_INTRO = "Note text (quick-add presets and the Auto-Add note below) can include these. They're filled in with the real value when the note is logged:"
local PRESET_HELP_EXAMPLE = 'Example: "Healed me in {{loc}}" becomes "Healed me in The Barrens".'

local function presetHelpPlainText()
	local lines = { PRESET_HELP_INTRO }
	for _, placeholder in ipairs(ns.PRESET_PLACEHOLDERS) do
		lines[#lines + 1] = placeholder.label .. "  -  " .. placeholder.description
	end
	lines[#lines + 1] = PRESET_HELP_EXAMPLE
	return table.concat(lines, "\n")
end

local presetHelpPopup

local function showPresetHelpPopup()
	if not presetHelpPopup then
		local popup = createHelpPopupFrame("WRPresetHelpPopup", 340, 230, "Note Placeholders")

		local intro = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		intro:SetPoint("TOPLEFT", 20, -46)
		intro:SetPoint("RIGHT", -20, 0)
		intro:SetJustifyH("LEFT")
		intro:SetText(PRESET_HELP_INTRO)
		intro:SetWordWrap(true)

		local prevLine = intro
		for _, placeholder in ipairs(ns.PRESET_PLACEHOLDERS) do
			local line = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
			line:SetPoint("TOPLEFT", prevLine, "BOTTOMLEFT", 0, -10)
			line:SetJustifyH("LEFT")
			line:SetText("|cffffd100" .. placeholder.label .. "|r  -  " .. placeholder.description)
			prevLine = line
		end

		local example = popup:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		example:SetPoint("TOPLEFT", prevLine, "BOTTOMLEFT", 0, -16)
		example:SetPoint("RIGHT", -20, 0)
		example:SetJustifyH("LEFT")
		example:SetWordWrap(true)
		example:SetText(PRESET_HELP_EXAMPLE)

		presetHelpPopup = popup
	end
	presetHelpPopup:Show()
end

local MACRO_HELP_INTRO = "A preset's button label can be used in a macro, for a one-click button that applies it to your current target without opening the quick-add window at all. Put this in a macro:"
local MACRO_HELP_COMMAND = "/wrquick <label>"
local MACRO_HELP_NOTE = "Example: /wrquick Good Healer (quotes around the label are optional). Matched case-insensitively, and requires a player targeted."

local function macroHelpPlainText()
	return MACRO_HELP_INTRO .. "\n" .. MACRO_HELP_COMMAND .. "\n" .. MACRO_HELP_NOTE
end

local macroHelpPopup

local function showMacroHelpPopup()
	if not macroHelpPopup then
		local popup = createHelpPopupFrame("WRMacroHelpPopup", 340, 190, "Using Labels in a Macro")

		local intro = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		intro:SetPoint("TOPLEFT", 20, -46)
		intro:SetPoint("RIGHT", -20, 0)
		intro:SetJustifyH("LEFT")
		intro:SetText(MACRO_HELP_INTRO)
		intro:SetWordWrap(true)

		local command = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		command:SetPoint("TOPLEFT", intro, "BOTTOMLEFT", 0, -12)
		command:SetJustifyH("LEFT")
		command:SetText("|cffffd100/wrquick <label>|r")

		local note = popup:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		note:SetPoint("TOPLEFT", command, "BOTTOMLEFT", 0, -16)
		note:SetPoint("RIGHT", -20, 0)
		note:SetJustifyH("LEFT")
		note:SetWordWrap(true)
		note:SetText(MACRO_HELP_NOTE)

		macroHelpPopup = popup
	end
	macroHelpPopup:Show()
end

GLOBAL_HOTKEY_HELP_TEXT = "Tap: quick-notes your target, or whoever you're hovering if nothing's targeted (both toggleable below). With neither, opens the window to the tab set below, or does nothing if that's turned off.\n\n"
	.. "Hold: opens the radial quick-add menu at the cursor, if enabled (Options > Radial Menu).\n\n"
	.. "Hovering a Group Finder listing: pulls up the Players tab filtered to that group's roster instead, if Group Finder integration is enabled (below)."

local globalHotkeyHelpPopup

showGlobalHotkeyHelpPopup = function()
	if not globalHotkeyHelpPopup then
		local popup = createHelpPopupFrame("WRGlobalHotkeyHelpPopup", 340, 230, "Global Hotkey")

		local intro = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		intro:SetPoint("TOPLEFT", 20, -46)
		intro:SetPoint("RIGHT", -20, 0)
		intro:SetJustifyH("LEFT")
		intro:SetWordWrap(true)
		intro:SetText(GLOBAL_HOTKEY_HELP_TEXT)

		globalHotkeyHelpPopup = popup
	end
	globalHotkeyHelpPopup:Show()
end

-- One row's checkbox + indented Rep gain/Note/(optional) Cooldown fields. Shared by
-- buildAutoAddBox's top-level rows and its collapsible emote rows.
local function buildAutoTrackRow(box, def, option, rowY)
	local detailRow

	local check = buildCheckbox(box, 8, rowY, def.label, option.enabled,
		function(checked)
			option.enabled = checked
			setContainerEnabled(detailRow, checked)
		end)
	setTooltip(check, def.hint)

	detailRow = CreateFrame("Frame", nil, box)
	detailRow:SetPoint("TOPLEFT", 44, rowY - 24)
	detailRow:SetSize(1, 1)

	local gainLabel = detailRow:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	gainLabel:SetPoint("TOPLEFT", 0, 0)
	gainLabel:SetText("Rep gain")

	local gainBox = ns.CreateSmallEditBox(detailRow, 34, 14)
	gainBox:SetPoint("LEFT", gainLabel, "RIGHT", 6, 0)
	gainBox:SetText(tostring(option.repGain))

	local function applyGain()
		local value = tonumber(gainBox:GetText()) or 0
		value = math.max(-ns.STANDING_MAX, math.min(ns.STANDING_MAX, value))
		option.repGain = value
		gainBox:SetText(tostring(value))
		gainBox:ClearFocus()
	end
	gainBox:SetScript("OnEnterPressed", applyGain)
	gainBox:SetScript("OnEditFocusLost", applyGain)
	gainBox:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(option.repGain))
		self:ClearFocus()
	end)

	local noteLabel = detailRow:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	noteLabel:SetPoint("LEFT", gainBox, "RIGHT", 16, 0)
	noteLabel:SetText("Note")

	-- quest has both Cooldown and Min. time grouped, too much for one line together, so
	-- its Cooldown field moves to its own third line (below) instead of sharing this one
	local cooldownOnOwnLine = def.hasCooldown and def.hasMinGrouped

	-- same size as the quick-add preset note boxes (Options > Presets), narrower when a
	-- Cooldown field follows it on the same line. blank means no note gets logged, just
	-- the rep change.
	local noteBox = ns.CreateSmallEditBox(detailRow, (def.hasCooldown and not cooldownOnOwnLine) and 160 or 240, 16)
	noteBox:SetJustifyH("LEFT")
	noteBox:SetPoint("LEFT", noteLabel, "RIGHT", 6, 0)
	noteBox:SetText(option.note or "")

	local function applyNote()
		option.note = noteBox:GetText()
		noteBox:ClearFocus()
	end
	noteBox:SetScript("OnEnterPressed", applyNote)
	noteBox:SetScript("OnEditFocusLost", applyNote)
	noteBox:SetScript("OnEscapePressed", function(self)
		self:SetText(option.note or "")
		self:ClearFocus()
	end)

	local function buildCooldownField(anchorPoint, anchorFrame, anchorRelativePoint, offsetX, offsetY)
		local cooldownLabel = detailRow:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		cooldownLabel:SetPoint(anchorPoint, anchorFrame, anchorRelativePoint, offsetX, offsetY)
		cooldownLabel:SetText("Cooldown")

		local cooldownBox = ns.CreateSmallEditBox(detailRow, 30, 14, true)
		cooldownBox:SetPoint("LEFT", cooldownLabel, "RIGHT", 6, 0)
		cooldownBox:SetText(tostring(option.cooldownMinutes))
		setTooltip(cooldownBox, "Minutes before this can log again for the same player.")

		local function applyCooldown()
			local value = math.max(0, tonumber(cooldownBox:GetText()) or option.cooldownMinutes)
			option.cooldownMinutes = value
			cooldownBox:SetText(tostring(value))
			cooldownBox:ClearFocus()
		end
		cooldownBox:SetScript("OnEnterPressed", applyCooldown)
		cooldownBox:SetScript("OnEditFocusLost", applyCooldown)
		cooldownBox:SetScript("OnEscapePressed", function(self)
			self:SetText(tostring(option.cooldownMinutes))
			self:ClearFocus()
		end)
	end

	if def.hasCooldown and not cooldownOnOwnLine then
		buildCooldownField("LEFT", noteBox, "RIGHT", 16, 0)
	end

	-- second line: only grouped-time-gated triggers (currently just "quest") need this,
	-- cramming it onto the first line alongside Cooldown ran too wide for the box
	if def.hasMinGrouped then
		local minGroupedLabel = detailRow:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		minGroupedLabel:SetPoint("TOPLEFT", 0, -20)
		minGroupedLabel:SetText("Min. time grouped (minutes, 0 = off)")

		local minGroupedBox = ns.CreateSmallEditBox(detailRow, 30, 14, true)
		minGroupedBox:SetPoint("LEFT", minGroupedLabel, "RIGHT", 6, 0)
		minGroupedBox:SetText(tostring(option.minGroupedMinutes))
		setTooltip(minGroupedBox, "Only logs for a party/raid member once they've been grouped with you this long. 0 logs for anyone currently grouped, regardless of when they joined.")

		local function applyMinGrouped()
			local value = math.max(0, tonumber(minGroupedBox:GetText()) or option.minGroupedMinutes)
			option.minGroupedMinutes = value
			minGroupedBox:SetText(tostring(value))
			minGroupedBox:ClearFocus()
		end
		minGroupedBox:SetScript("OnEnterPressed", applyMinGrouped)
		minGroupedBox:SetScript("OnEditFocusLost", applyMinGrouped)
		minGroupedBox:SetScript("OnEscapePressed", function(self)
			self:SetText(tostring(option.minGroupedMinutes))
			self:ClearFocus()
		end)
	end

	-- third line: quest's Cooldown, moved here since it doesn't fit on the first line
	-- alongside the wide note box AND Min. time grouped below it on the second
	if cooldownOnOwnLine then
		buildCooldownField("TOPLEFT", detailRow, "TOPLEFT", 0, -40)
	end

	setContainerEnabled(detailRow, option.enabled)
end

-- session-only: collapsed on every fresh Options open, not persisted to settings
local autoTrackEmotesExpanded = false

local function buildAutoAddBox(parent, y, onToggle)
	local settings = ns.GetSettings().autoTrack

	local topDefs, emoteDefs = {}, {}
	for _, def in ipairs(ns.AUTO_TRACK_DEFS) do
		if def.isEmote then
			emoteDefs[#emoteDefs + 1] = def
		else
			topDefs[#topDefs + 1] = def
		end
	end

	-- only "quest" has hasMinGrouped, needing a taller row: Min. time grouped on its own
	-- line, plus Cooldown moved to a 3rd line underneath that (too much for one line
	-- alongside the wide note box otherwise)
	local function rowHeightFor(def)
		local lines = 1
		if def.hasMinGrouped then
			lines = lines + 1
		end
		if def.hasCooldown and def.hasMinGrouped then
			lines = lines + 1
		end
		return 30 + lines * 20
	end

	local DISCLOSURE_HEIGHT = 22
	local topHeight, emoteHeight = 0, 0
	for _, def in ipairs(topDefs) do
		topHeight = topHeight + rowHeightFor(def)
	end
	for _, def in ipairs(emoteDefs) do
		emoteHeight = emoteHeight + rowHeightFor(def)
	end
	local height = 24 + topHeight + DISCLOSURE_HEIGHT + (autoTrackEmotesExpanded and emoteHeight or 0) + 10
	local box, titleText = createSectionBox(parent, y, height, "Auto-Add")

	local helpButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	helpButton:SetSize(20, 20)
	helpButton:SetText("?")
	helpButton:SetPoint("LEFT", titleText, "RIGHT", 4, 0)
	helpButton:SetScript("OnClick", showPresetHelpPopup)
	ns.AttachHookTooltip(helpButton, presetHelpPlainText())

	local rowY = -24
	for _, def in ipairs(topDefs) do
		buildAutoTrackRow(box, def, settings[def.key], rowY)
		rowY = rowY - rowHeightFor(def)
	end

	local disclosure = CreateFrame("Button", nil, box)
	disclosure:SetSize(260, 18)
	disclosure:SetPoint("TOPLEFT", 6, rowY)

	-- same tinted-UIPanelButtonTemplate look as the Players tab's +/- buttons, same red
	-- tint as the minus button there
	local toggleButton = CreateFrame("Button", nil, disclosure, "UIPanelButtonTemplate")
	toggleButton:SetSize(20, 18)
	toggleButton:SetPoint("LEFT", 0, 0)
	local toggleTint = toggleButton:CreateTexture(nil, "ARTWORK", nil, -1)
	toggleTint:SetPoint("TOPLEFT", 3, -3)
	toggleTint:SetPoint("BOTTOMRIGHT", -3, 3)
	toggleTint:SetColorTexture(0.6, 0.18, 0.18, 0.65)

	local disclosureText = disclosure:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	disclosureText:SetPoint("LEFT", toggleButton, "RIGHT", 6, 0)
	disclosureText:SetText("Directed Emotes (Wave/Thank/Bow)")

	local function onToggleClick()
		autoTrackEmotesExpanded = not autoTrackEmotesExpanded
		if onToggle then
			onToggle()
		end
	end
	toggleButton:SetText(autoTrackEmotesExpanded and "-" or "+")
	toggleButton:SetScript("OnClick", onToggleClick)
	disclosure:SetScript("OnClick", onToggleClick)
	rowY = rowY - DISCLOSURE_HEIGHT

	if autoTrackEmotesExpanded then
		for _, def in ipairs(emoteDefs) do
			buildAutoTrackRow(box, def, settings[def.key], rowY)
			rowY = rowY - rowHeightFor(def)
		end
	end

	return y - height - 6
end

-- session-only: collapsed on every fresh Options open, same as autoTrackEmotesExpanded
local dungeonTrackingExpanded = false
local ROLE_PRESET_ROW_HEIGHT = 22
local DUNGEON_TRACKING_ROWS = {
	disclosureGap = 10,
	autoLogRow = 26,
	autoLogDetail = 44,
	surveyRow = 26,
	surveyDetail = 44,
	presetsGap = 10,
	presetsLabel = 18,
	presetsHeader = 14,
	addButtonRow = 24,
	bottomPad = 10,
}

-- separate from the generic autoTrack rows above: dungeon/raid tracking needs more
-- custom controls (a survey toggle, a note prefix, an editable role-preset list) than
-- buildAutoTrackRow's generic layout supports, so it's its own section with its own
-- collapsible disclosure, same idea as Directed Emotes above but for the whole block.
local function buildDungeonTrackingBox(parent, y, onToggle)
	local trackSettings = ns.GetSettings().dungeonTracking
	local DISCLOSURE_HEIGHT = 22

	local height = 24 + DISCLOSURE_HEIGHT
	if dungeonTrackingExpanded then
		local r = DUNGEON_TRACKING_ROWS
		height = height + r.disclosureGap + r.autoLogRow + r.autoLogDetail + r.surveyRow + r.surveyDetail
			+ r.presetsGap + r.presetsLabel + r.presetsHeader + #trackSettings.rolePresets * ROLE_PRESET_ROW_HEIGHT
			+ r.addButtonRow + r.bottomPad
	end

	local box = createSectionBox(parent, y, height, "Dungeon/Raid Tracking")
	-- this box lives in the same scroll child as the (unrelated) autoTrack rows above
	-- it, which get blanket-disabled by the "Enable auto-add module" master switch.
	-- dungeonTracking is its own independent system now, so the caller re-enables this
	-- box afterward via the returned function, rather than inheriting that switch's state.
	local refreshEnabled = function() setContainerEnabled(box, true) end

	local disclosure = CreateFrame("Button", nil, box)
	disclosure:SetSize(260, 18)
	disclosure:SetPoint("TOPLEFT", 6, -24)

	-- same tinted-UIPanelButtonTemplate look as Directed Emotes' own disclosure
	local toggleButton = CreateFrame("Button", nil, disclosure, "UIPanelButtonTemplate")
	toggleButton:SetSize(20, 18)
	toggleButton:SetPoint("LEFT", 0, 0)
	local toggleTint = toggleButton:CreateTexture(nil, "ARTWORK", nil, -1)
	toggleTint:SetPoint("TOPLEFT", 3, -3)
	toggleTint:SetPoint("BOTTOMRIGHT", -3, 3)
	toggleTint:SetColorTexture(0.6, 0.18, 0.18, 0.65)

	local disclosureText = disclosure:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	disclosureText:SetPoint("LEFT", toggleButton, "RIGHT", 6, 0)
	disclosureText:SetText(dungeonTrackingExpanded and "Hide settings" or "Show settings")

	local function onToggleClick()
		dungeonTrackingExpanded = not dungeonTrackingExpanded
		if onToggle then
			onToggle()
		end
	end
	toggleButton:SetText(dungeonTrackingExpanded and "-" or "+")
	toggleButton:SetScript("OnClick", onToggleClick)
	disclosure:SetScript("OnClick", onToggleClick)

	if not dungeonTrackingExpanded then
		return y - height - 6, refreshEnabled
	end

	local r = DUNGEON_TRACKING_ROWS
	local rowY = -24 - DISCLOSURE_HEIGHT - r.disclosureGap

	local autoLog = trackSettings.autoLog
	local autoLogDetail
	local autoLogCheck = buildCheckbox(box, 8, rowY, "Auto-log dungeon/raid runs", autoLog.enabled,
		function(checked)
			autoLog.enabled = checked
			setContainerEnabled(autoLogDetail, checked)
		end)
	setTooltip(autoLogCheck,
		"Logs an entry for each party/raid member when you enter the instance together, or (with the checkbox below) when you leave it instead.")

	autoLogDetail = CreateFrame("Frame", nil, box)
	-- not indented, same gap/layout as surveyDetail below it: those two sections read as
	-- parallel siblings, not one nested under its own checkbox
	autoLogDetail:SetPoint("TOPLEFT", 8, rowY - 26)
	autoLogDetail:SetSize(1, 1)

	local gainLabel = autoLogDetail:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	gainLabel:SetPoint("TOPLEFT", 0, 0)
	gainLabel:SetText("Rep gain")
	local gainBox = ns.CreateSmallEditBox(autoLogDetail, 34, 14)
	gainBox:SetPoint("LEFT", gainLabel, "RIGHT", 6, 0)
	gainBox:SetText(tostring(autoLog.repGain))
	local function applyGain()
		local value = math.max(-ns.STANDING_MAX, math.min(ns.STANDING_MAX, tonumber(gainBox:GetText()) or 0))
		autoLog.repGain = value
		gainBox:SetText(tostring(value))
		gainBox:ClearFocus()
	end
	gainBox:SetScript("OnEnterPressed", applyGain)
	gainBox:SetScript("OnEditFocusLost", applyGain)
	gainBox:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(autoLog.repGain))
		self:ClearFocus()
	end)

	local noteLabel = autoLogDetail:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	noteLabel:SetPoint("LEFT", gainBox, "RIGHT", 16, 0)
	noteLabel:SetText("Note")
	local noteBox = ns.CreateSmallEditBox(autoLogDetail, 200, 16)
	noteBox:SetJustifyH("LEFT")
	noteBox:SetPoint("LEFT", noteLabel, "RIGHT", 6, 0)
	noteBox:SetText(autoLog.note or "")
	local function applyNote()
		autoLog.note = noteBox:GetText()
		noteBox:ClearFocus()
	end
	noteBox:SetScript("OnEnterPressed", applyNote)
	noteBox:SetScript("OnEditFocusLost", applyNote)
	noteBox:SetScript("OnEscapePressed", function(self)
		self:SetText(autoLog.note or "")
		self:ClearFocus()
	end)

	-- a checkbox's own taller glyph reads as cramped against the Rep gain/Note line
	-- above at the same -20 offset every other detail line uses, so this one gets a bit
	-- more room; the section's total height budget stays the same (r.autoLogDetail
	-- isn't touched), so the gap before the next section (Show a survey popup) shrinks
	-- to match instead of also needing an edit
	buildCheckbox(autoLogDetail, 0, -22, "Only log on completion (otherwise logs on entering)",
		autoLog.onlyOnCompletion,
		function(checked) autoLog.onlyOnCompletion = checked end)

	setContainerEnabled(autoLogDetail, autoLog.enabled)
	rowY = rowY - r.autoLogRow - r.autoLogDetail

	local survey = trackSettings.survey
	local surveyDetail
	local surveyCheck = buildCheckbox(box, 8, rowY, "Show a survey popup on completion", survey.enabled,
		function(checked)
			survey.enabled = checked
			setContainerEnabled(surveyDetail, checked)
		end)
	setTooltip(surveyCheck,
		"Pops a window listing your party/raid when you leave the instance, with a note box, role-preset dropdown, and standing +/- per member.")

	surveyDetail = CreateFrame("Frame", nil, box)
	-- not indented under the checkbox like autoLogDetail's Rep gain/Note is: those read
	-- naturally as parameters of a single-line action, but Note prefix sitting alone,
	-- indented, under a checkbox with nothing else on its line just looked cramped/odd.
	-- flush-left instead, reading as its own sibling setting.
	surveyDetail:SetPoint("TOPLEFT", 8, rowY - 26)
	surveyDetail:SetSize(1, 1)

	local prefixLabel = surveyDetail:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	prefixLabel:SetPoint("TOPLEFT", 0, 0)
	prefixLabel:SetText("Note prefix")
	local prefixBox = ns.CreateSmallEditBox(surveyDetail, 220, 16)
	prefixBox:SetJustifyH("LEFT")
	prefixBox:SetPoint("LEFT", prefixLabel, "RIGHT", 6, 0)
	prefixBox:SetText(survey.notePrefix or "")
	local function applyPrefix()
		survey.notePrefix = prefixBox:GetText()
		prefixBox:ClearFocus()
	end
	prefixBox:SetScript("OnEnterPressed", applyPrefix)
	prefixBox:SetScript("OnEditFocusLost", applyPrefix)
	prefixBox:SetScript("OnEscapePressed", function(self)
		self:SetText(survey.notePrefix or "")
		self:ClearFocus()
	end)
	setTooltip(prefixBox,
		"Prepended to whatever you type in each survey row's note box. Supports {{loc}}/{{yourlvl}}/{{theirlvl}} like any other note template.")

	local skipConfirmCheck = buildCheckbox(surveyDetail, 0, -22,
		"Skip the \"fill out survey?\" prompt (go straight to the survey)",
		survey.skipConfirmation,
		function(checked) survey.skipConfirmation = checked end)
	setTooltip(skipConfirmCheck,
		"Same as checking \"Don't ask me again\" and choosing Open Survey on that prompt. The prompt's own checkbox sets this too.")

	setContainerEnabled(surveyDetail, survey.enabled)
	refreshEnabled = function()
		setContainerEnabled(box, true)
		setContainerEnabled(autoLogDetail, autoLog.enabled)
		setContainerEnabled(surveyDetail, survey.enabled)
	end
	rowY = rowY - r.surveyRow - r.surveyDetail - r.presetsGap

	local presetsLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	presetsLabel:SetPoint("TOPLEFT", 8, rowY)
	presetsLabel:SetText("Survey role presets")
	setTooltip(presetsLabel,
		"Shown in a dropdown next to each survey row's note box; picking one fills that row's note and rep delta (both still editable after).")
	rowY = rowY - r.presetsLabel

	local labelHeader = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	labelHeader:SetPoint("TOPLEFT", 8, rowY)
	labelHeader:SetText("Label")

	local noteHeader = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	noteHeader:SetPoint("LEFT", labelHeader, "LEFT", 120, 0)
	noteHeader:SetText("Note text")

	local repHeader = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	repHeader:SetPoint("LEFT", noteHeader, "LEFT", 248, 0)
	repHeader:SetText("Rep")

	rowY = rowY - r.presetsHeader

	-- same widths as the Quick-Add Presets tab's own editor (buildPresetsPanel), so the
	-- two preset-list editors read as the same kind of control
	for i, preset in ipairs(trackSettings.rolePresets) do
		local labelBox = ns.CreateSmallEditBox(box, 112, 16)
		labelBox:SetPoint("TOPLEFT", 8, rowY)
		labelBox:SetText(preset.label)
		local function applyLabel(self)
			preset.label = self:GetText()
		end
		labelBox:SetScript("OnEnterPressed", function(self)
			applyLabel(self)
			self:ClearFocus()
		end)
		labelBox:SetScript("OnEditFocusLost", applyLabel)
		labelBox:SetScript("OnEscapePressed", function(self)
			self:SetText(preset.label)
			self:ClearFocus()
		end)

		local textBox = ns.CreateSmallEditBox(box, 240, 16)
		textBox:SetJustifyH("LEFT")
		textBox:SetPoint("LEFT", labelBox, "RIGHT", 8, 0)
		textBox:SetText(preset.text or "")
		local function applyText(self)
			preset.text = self:GetText()
		end
		textBox:SetScript("OnEnterPressed", function(self)
			applyText(self)
			self:ClearFocus()
		end)
		textBox:SetScript("OnEditFocusLost", applyText)
		textBox:SetScript("OnEscapePressed", function(self)
			self:SetText(preset.text or "")
			self:ClearFocus()
		end)

		local deltaBox = ns.CreateSmallEditBox(box, 34, 16)
		deltaBox:SetPoint("LEFT", textBox, "RIGHT", 8, 0)
		deltaBox:SetText(tostring(preset.delta or 0))
		local function applyDelta(self)
			preset.delta = tonumber(self:GetText()) or 0
			self:SetText(tostring(preset.delta))
			self:ClearFocus()
		end
		deltaBox:SetScript("OnEnterPressed", applyDelta)
		deltaBox:SetScript("OnEditFocusLost", applyDelta)
		deltaBox:SetScript("OnEscapePressed", function(self)
			self:SetText(tostring(preset.delta or 0))
			self:ClearFocus()
		end)

		local deleteButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
		deleteButton:SetSize(22, 18)
		deleteButton:SetText("X")
		deleteButton:SetPoint("LEFT", deltaBox, "RIGHT", 8, 0)
		deleteButton:SetScript("OnClick", function()
			table.remove(trackSettings.rolePresets, i)
			if onToggle then
				onToggle()
			end
		end)

		rowY = rowY - ROLE_PRESET_ROW_HEIGHT
	end

	local addPresetButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	addPresetButton:SetSize(100, 20)
	addPresetButton:SetText("+ Add Role")
	addPresetButton:SetPoint("TOPLEFT", 8, rowY)
	addPresetButton:SetScript("OnClick", function()
		table.insert(trackSettings.rolePresets, { label = "New Role", text = "", delta = 0 })
		if onToggle then
			onToggle()
		end
	end)

	return y - height - 6, refreshEnabled
end

local function buildNearbyAutoAddBox(parent, y)
	local height = 98
	local box = createSectionBox(parent, y, height, "Nearby Players")
	local autoAdd = ns.GetSettings().autoAddNearby

	local warning = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	warning:SetPoint("TOPLEFT", 8, -24)
	warning:SetPoint("RIGHT", -10, 0)
	warning:SetJustifyH("LEFT")
	warning:SetWordWrap(true)
	warning:SetTextColor(1, 0.25, 0.25)
	warning:SetText("These settings can have a heavy impact on performance; enable carefully.")

	local restCheck = buildCheckbox(box, 8, -68, "Auto-add while resting (inns/cities) too",
		autoAdd.alsoWhileResting,
		function(checked) autoAdd.alsoWhileResting = checked end)
	setTooltip(restCheck, "FOR TESTING PURPOSES ONLY. This will have a MAJOR impact on performance if in a large city.")

	local function setRestCheckEnabled(enabled)
		setContainerEnabled(restCheck, enabled)
		setContainerEnabled(restCheck.label, enabled)
	end

	local addCheck = buildCheckbox(box, 8, -44, "Auto-add missing nearby players (added with 0 standing)",
		autoAdd.enabled,
		function(checked)
			autoAdd.enabled = checked
			setRestCheckEnabled(checked)
			if ns.RefreshNearbyWindow then
				ns.RefreshNearbyWindow()
			end
		end)
	setTooltip(addCheck, "This will add EVERY nameplated player, with no note or reputation.")
	setRestCheckEnabled(autoAdd.enabled)

	return y - height - 6
end

local function buildSeenCountBox(parent, y)
	local height = 78
	local box = createSectionBox(parent, y, height, "Seen-Count Tracking")

	local cooldownLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	cooldownLabel:SetPoint("TOPLEFT", 8, -24)
	cooldownLabel:SetText("Cooldown (minutes)")

	local cooldownBox = ns.CreateSmallEditBox(box, 30, 14, true)
	cooldownBox:SetPoint("LEFT", cooldownLabel, "RIGHT", 6, 0)
	cooldownBox:SetText(tostring(ns.GetSettings().seenCountCooldownMinutes))
	setTooltip(cooldownBox, "Seeing the same player again within this timeframe won't bump their seen count.")
	local function applyCooldown()
		local value = math.max(0, tonumber(cooldownBox:GetText()) or 5)
		ns.GetSettings().seenCountCooldownMinutes = value
		cooldownBox:SetText(tostring(value))
		cooldownBox:ClearFocus()
	end
	cooldownBox:SetScript("OnEnterPressed", applyCooldown)
	cooldownBox:SetScript("OnEditFocusLost", applyCooldown)
	cooldownBox:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(ns.GetSettings().seenCountCooldownMinutes))
		self:ClearFocus()
	end)

	buildCheckbox(box, 8, -48, "Don't count players as seen while resting (inns/cities)",
		ns.GetSettings().seenCountSkipWhileResting,
		function(checked) ns.GetSettings().seenCountSkipWhileResting = checked end)

	return y - height - 6
end

local function buildAutoTrackPanel(parent)
	local settings = ns.GetSettings().autoTrack

	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -28)
	scroll:SetPoint("BOTTOMRIGHT", -34, 0)

	local scrollChild = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(scrollChild)
	scroll:SetScript("OnSizeChanged", function(self, width)
		scrollChild:SetWidth(width)
	end)
	scrollChild:SetWidth(parent:GetWidth())

	buildCheckbox(parent, 16, -8, "Enable auto-add module",
		settings.enabled,
		function(checked)
			settings.enabled = checked
			setContainerEnabled(scrollChild, checked)
		end)

	-- rebuilds every box from scratch, since the emote disclosure toggle changes
	-- buildAutoAddBox's own height and everything below it has to shift to match
	local function layout()
		for _, child in ipairs({ scrollChild:GetChildren() }) do
			child:Hide()
			child:SetParent(nil)
		end
		local y = -8
		y = buildAutoAddBox(scrollChild, y, layout)
		local dungeonTrackingRefresh
		y, dungeonTrackingRefresh = buildDungeonTrackingBox(scrollChild, y, layout)
		y = buildNearbyAutoAddBox(scrollChild, y)
		y = buildSeenCountBox(scrollChild, y)
		scrollChild:SetHeight(-y + 10)
		setContainerEnabled(scrollChild, settings.enabled)
		dungeonTrackingRefresh()
	end

	layout()
end

-- stock Blizzard sound files as one-click presets. by FileDataID, not string path,
-- the string paths for these don't play.
local ENTRY_SOUND_FILE_PRESETS = {
	{ fileID = 567396, label = "Write Quest (scribble)" },
	{ fileID = 6938269, label = "Spellbook Open" },
	{ fileID = 567472, label = "Turn Page" },
	{ fileID = 6838412, label = "Enter Layout Mode" },
}

local POSITIVE_SOUND_FILE_PRESETS = {
	{ fileID = 567568, label = "Pick Up Gems" },
	{ fileID = 2113868, label = "Friend Starts Game" },
	{ fileID = 567518, label = "Friend Join" },
	{ fileID = 4956048, label = "Trading Post Menu Open" },
	{ fileID = 899283, label = "Dig Site Completion" },
}

local NEGATIVE_SOUND_FILE_PRESETS = {
	{ fileID = 4956084, label = "Trading Post Reward Tier" },
	{ fileID = 568197, label = "Pathfinding" },
	{ fileID = 2177534, label = "War Mode Activate" },
	{ fileID = 3748668, label = "Adventure Death (Enemy)" },
}

local function findSoundFilePreset(filePresets, fileID)
	for _, preset in ipairs(filePresets) do
		if preset.fileID == fileID then
			return preset
		end
	end
	return nil
end

-- shared by every sound picker (nearby positive/negative, new-entry): a dropdown of
-- `builtinOptions` (SOUNDKIT values) plus `filePresets` (FileDataID values) plus a
-- "Custom sound ID" entry that reveals a text box for a user-supplied FileDataID,
-- the only case that still goes through the customPath *string* mechanism, since the
-- presets above play by FileDataID instead. a Test button plays whatever is currently
-- configured on demand. `sound` is a {useCustom, kit, customPath} table, see
-- ns.PlayConfiguredSound. `builtinOptions` and `filePresets` differ per call site
-- (the new-entry sound doesn't need to offer e.g. "Raid Warning", and nearby
-- positive/negative don't offer the file presets below until they get their own).
-- returns the picker's own container frame (for graying out the whole picker from a
-- master checkbox elsewhere). `allowNone` adds a "None" entry that silently clears the
-- sound (ns.PlayConfiguredSound already no-ops when both useCustom and kit are unset).
local function buildSoundPicker(parent, x, y, labelText, sound, builtinOptions, filePresets, allowNone)
	filePresets = filePresets or {}

	local container = CreateFrame("Frame", nil, parent)
	container:SetPoint("TOPLEFT", x, y)
	container:SetSize(1, 1)

	local label = container:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	label:SetPoint("TOPLEFT", 0, 0)
	label:SetText(labelText)

	local options = {}
	for _, opt in ipairs(builtinOptions) do
		options[#options + 1] = opt
	end
	for _, preset in ipairs(filePresets) do
		options[#options + 1] = { value = preset.fileID, text = preset.label }
	end
	options[#options + 1] = { value = "custom", text = "Custom sound ID" }
	if allowNone then
		options[#options + 1] = { value = "none", text = "None" }
	end

	local pathBox

	local dropdown = ns.CreateDropdown(container, options,
		function(value)
			if value == "custom" then
				return sound.useCustom and not findSoundFilePreset(filePresets, sound.customPath)
			end
			if value == "none" then
				return not sound.useCustom and not sound.kit
			end
			if findSoundFilePreset(filePresets, value) then
				return sound.useCustom and sound.customPath == value
			end
			return not sound.useCustom and sound.kit == value
		end,
		function(value)
			if value == "custom" then
				-- clear any prior preset's FileDataID too, not just flip useCustom,
				-- otherwise customPath still matches whatever preset was selected before,
				-- so isSelected("custom") stays false (the old preset still reads as the
				-- active choice) and Test keeps playing that old sound until something is
				-- actually typed and submitted below.
				sound.useCustom = true
				sound.customPath = ""
				pathBox:Show()
				pathBox:SetText("")
				pathBox:SetCursorPosition(0)
			elseif value == "none" then
				sound.useCustom = false
				sound.kit = nil
				pathBox:Hide()
			elseif findSoundFilePreset(filePresets, value) then
				-- presets play by FileDataID, not a typed path, so there's nothing to
				-- show/edit in the path box for these, same as picking a SOUNDKIT below.
				sound.useCustom = true
				sound.customPath = value
				pathBox:Hide()
				ns.PlayConfiguredSound(sound, ns.GetSettings().soundChannel)
			else
				sound.useCustom = false
				sound.kit = value
				pathBox:Hide()
				PlaySound(value, ns.GetSettings().soundChannel)
			end
		end,
		170, 20)
	dropdown:SetPoint("TOPLEFT", label, "BOTTOMLEFT", 4, -6)

	pathBox = CreateFrame("EditBox", nil, container, "InputBoxTemplate")
	pathBox:SetSize(190, 16)
	pathBox:SetAutoFocus(false)
	pathBox:SetFontObject(GameFontHighlightSmall)
	pathBox:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -4)
	-- only a genuine "Custom" entry (not one of the FileDataID presets above, which may
	-- themselves be numbers) ever populates or shows this box, same check the dropdown
	-- itself uses to decide whether "Custom sound ID" is the active selection.
	local isTypedPath = sound.useCustom and not findSoundFilePreset(filePresets, sound.customPath)
	pathBox:SetText(isTypedPath and tostring(sound.customPath) or "")
	pathBox:SetCursorPosition(0) -- else it shows scrolled to the end of a long path
	pathBox:SetShown(isTypedPath)
	-- saves without test-playing the sound, used for both committing paths (Enter and
	-- clicking away should both save) and the focus-lost case specifically shouldn't
	-- also play a sound just because the user clicked elsewhere.
	local function savePath()
		local text = pathBox:GetText()
		-- a bare number is a FileDataID, not a literal path
		sound.customPath = tonumber(text) or text
		sound.useCustom = true
		pathBox:SetCursorPosition(0)
	end
	local function applyPath()
		savePath()
		pathBox:ClearFocus()
		ns.PlayConfiguredSound(sound, ns.GetSettings().soundChannel)
	end
	pathBox:SetScript("OnEnterPressed", applyPath)
	pathBox:SetScript("OnEditFocusLost", savePath)
	pathBox:SetScript("OnEscapePressed", function(self)
		self:SetText(isTypedPath and tostring(sound.customPath) or "")
		self:SetCursorPosition(0)
		self:ClearFocus()
	end)

	local testButton = CreateFrame("Button", nil, container, "UIPanelButtonTemplate")
	testButton:SetSize(44, 20)
	testButton:SetText("Test")
	testButton:SetPoint("LEFT", dropdown, "RIGHT", 6, 0)
	testButton:SetScript("OnClick", function()
		-- commit whatever's currently typed first, otherwise Test plays whatever was
		-- last actually saved (which, right after switching to Custom, is nothing valid,
		-- so it fell through to a stale leftover `kit` value instead of the typed entry).
		if pathBox:IsShown() then
			applyPath()
		else
			ns.PlayConfiguredSound(sound, ns.GetSettings().soundChannel)
		end
	end)

	return container
end

local INSTANCE_TYPE_DEFS = {
	{ key = "party", label = "Dungeons" },
	{ key = "raid", label = "Raids" },
	{ key = "pvp", label = "Battlegrounds" },
	{ key = "arena", label = "Arenas" },
}

-- wrapped in a scroll frame for the same reason as General: two sound pickers (each
-- with a collapsible custom-path field), a cooldown, four instance checkboxes, and the
-- new-entry sound section add up to more than the window's minimum height.
local function buildNearbyAlertsBox(parent, y)
	local nearbySound = ns.GetSettings().nearbySound
	local nearbyFlash = ns.GetSettings().nearbyFlash
	local height = 190
	local box = createSectionBox(parent, y, height, "Nearby Window Alerts")

	-- positive: only the file presets below for now, no SOUNDKIT options. none of the
	-- generic ones (Ready Check, Level Up, etc.) fit, and these were hand-picked.
	local positivePicker = buildSoundPicker(box, 8, -80, "Positive sound", nearbySound.positive,
		{}, POSITIVE_SOUND_FILE_PRESETS, true)
	local negativePicker = buildSoundPicker(box, 230, -80, "Negative sound", nearbySound.negative,
		{ { value = SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, text = "Raid Warning" } },
		NEGATIVE_SOUND_FILE_PRESETS, true)

	buildCheckbox(box, 8, -24, "Play a sound when a notable player becomes nearby",
		nearbySound.enabled,
		function(checked)
			nearbySound.enabled = checked
			setContainerEnabled(positivePicker, checked)
			setContainerEnabled(negativePicker, checked)
		end)
	setContainerEnabled(positivePicker, nearbySound.enabled)
	setContainerEnabled(negativePicker, nearbySound.enabled)

	buildCheckbox(box, 8, -50, "Flash the Nearby window too (independent of the sound)",
		nearbyFlash.enabled,
		function(checked) nearbyFlash.enabled = checked end)

	local ROW_Y = -140

	local cooldownLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	cooldownLabel:SetPoint("TOPLEFT", 8, ROW_Y)
	cooldownLabel:SetText("Cooldown per player (min)")

	-- stored internally as seconds (nearbySound.cooldownSeconds, compared directly
	-- against GetTime() in NearbyWindow.lua), but shown/edited here in minutes to match
	-- every other cooldown field in the addon (auto-track, seen-count). this field used
	-- to be the one outlier in seconds, easy to mistake for minutes and enter e.g. "2"
	-- meaning 2 minutes when it actually set a 2-second cooldown.
	local cooldownBox = ns.CreateSmallEditBox(box, 34, 14, true)
	cooldownBox:SetPoint("LEFT", cooldownLabel, "RIGHT", 6, 0)
	cooldownBox:SetText(tostring(nearbySound.cooldownSeconds / 60))
	setTooltip(cooldownBox, "A player leaving and returning within this timeframe won't re-trigger the alert.")
	local function applyCooldown()
		local minutes = math.max(0, tonumber(cooldownBox:GetText()) or 0)
		nearbySound.cooldownSeconds = minutes * 60
		cooldownBox:SetText(tostring(minutes))
		cooldownBox:ClearFocus()
	end
	cooldownBox:SetScript("OnEnterPressed", applyCooldown)
	cooldownBox:SetScript("OnEditFocusLost", applyCooldown)
	cooldownBox:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(nearbySound.cooldownSeconds / 60))
		self:ClearFocus()
	end)

	local instanceLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	instanceLabel:SetPoint("TOPLEFT", 230, ROW_Y)
	instanceLabel:SetText("Disable while in")

	local instanceOptions = {}
	for _, def in ipairs(INSTANCE_TYPE_DEFS) do
		instanceOptions[#instanceOptions + 1] = { value = def.key, text = def.label }
	end
	local function instanceSummaryText()
		local names = {}
		for _, def in ipairs(INSTANCE_TYPE_DEFS) do
			if nearbySound.disableInInstance[def.key] then
				names[#names + 1] = def.label
			end
		end
		return #names == 0 and "None" or table.concat(names, ", ")
	end
	local instanceDropdown = ns.CreateMultiSelectDropdown(box, instanceOptions,
		function(value) return nearbySound.disableInInstance[value] == true end,
		function(value) nearbySound.disableInInstance[value] = not nearbySound.disableInInstance[value] end,
		instanceSummaryText, 160)
	instanceDropdown:SetPoint("TOPLEFT", instanceLabel, "BOTTOMLEFT", 2, -4)

	return y - height - 6
end

local function buildEntryAlertBox(parent, y)
	local entrySound = ns.GetSettings().newEntrySound
	local height = 130
	local box = createSectionBox(parent, y, height, "New Entry Alert")

	-- only "Menu Open" carries over from the nearby-alert SOUNDKIT list, the rest
	-- (Ready Check, Raid Warning, etc.) don't suit a "you wrote something down" sound.
	local entryPicker = buildSoundPicker(box, 8, -54, "Entry sound", entrySound,
		{ { value = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN or 851, text = "Menu Open" } },
		ENTRY_SOUND_FILE_PRESETS)

	buildCheckbox(box, 8, -24, "Play a sound whenever a new entry is logged (manual or auto)",
		entrySound.enabled,
		function(checked)
			entrySound.enabled = checked
			setContainerEnabled(entryPicker, checked)
		end)
	setContainerEnabled(entryPicker, entrySound.enabled)

	return y - height - 6
end

local function buildSoundChannelBox(parent, y)
	local height = 74
	local box = createSectionBox(parent, y, height, "Sound Channel")

	local channelOptions = {}
	for _, channel in ipairs(ns.NEARBY_SOUND_CHANNELS) do
		channelOptions[#channelOptions + 1] = { value = channel, text = channel }
	end
	local channelDropdown = ns.CreateDropdown(box, channelOptions,
		function(value) return ns.GetSettings().soundChannel == value end,
		function(value)
			ns.GetSettings().soundChannel = value
			ns.PlayConfiguredSound(ns.GetSettings().nearbySound.positive, value)
		end,
		150, 20)
	channelDropdown:SetPoint("TOPLEFT", 8, -24)

	return y - height - 6
end

-- wrapped in a scroll frame: three boxes (alerts, entry sound, channel), each with their
-- own sound pickers, add up to more than the window's minimum height.
local function buildNearbySoundControl(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", -34, 0)

	local scrollChild = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(scrollChild)
	scroll:SetScript("OnSizeChanged", function(self, width)
		scrollChild:SetWidth(width)
	end)
	scrollChild:SetWidth(parent:GetWidth())

	local y = -8
	y = buildNearbyAlertsBox(scrollChild, y)
	y = buildEntryAlertBox(scrollChild, y)
	y = buildSoundChannelBox(scrollChild, y)

	scrollChild:SetHeight(-y + 10)
end

local PRESET_ROW_HEIGHT = 30

-- User-editable list of quick-add preset buttons (see QuickAdd.lua's layoutPresets).
-- Rebuilds its row widgets from scratch on every add/delete rather than diffing, since
-- the list is short and this only runs on an explicit user action, not a hot path.
local PRESETS_BOX_HEIGHT = 74

local function buildPresetsPanel(parent)
	local settings = ns.GetSettings().quickPresets

	local box = createSectionBox(parent, -8, PRESETS_BOX_HEIGHT, "Quick-Add Presets")

	local addButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	addButton:SetSize(100, 20)
	addButton:SetText("+ Add Preset")
	addButton:SetPoint("TOPLEFT", 8, -48)

	local headerY = -8 - PRESETS_BOX_HEIGHT - 8
	local headerLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	headerLabel:SetPoint("TOPLEFT", 20, headerY)
	headerLabel:SetText("Button label")

	local macroHelpButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	macroHelpButton:SetSize(16, 16)
	macroHelpButton:SetText("?")
	macroHelpButton:SetPoint("LEFT", headerLabel, "RIGHT", 4, 0)
	macroHelpButton:SetScript("OnClick", showMacroHelpPopup)
	ns.AttachHookTooltip(macroHelpButton, macroHelpPlainText())

	local headerText = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	headerText:SetPoint("LEFT", headerLabel, "LEFT", 124, 0)
	headerText:SetText("Note text")

	local placeholderHelpButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	placeholderHelpButton:SetSize(16, 16)
	placeholderHelpButton:SetText("?")
	placeholderHelpButton:SetPoint("LEFT", headerText, "RIGHT", 4, 0)
	placeholderHelpButton:SetScript("OnClick", showPresetHelpPopup)
	ns.AttachHookTooltip(placeholderHelpButton, presetHelpPlainText())

	local headerDelta = parent:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	headerDelta:SetPoint("LEFT", headerText, "LEFT", 256, 0)
	headerDelta:SetText("Rep")

	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, headerY - 16)
	scroll:SetPoint("BOTTOMRIGHT", -34, 0)
	local rowsFrame = CreateFrame("Frame", nil, scroll)
	rowsFrame:SetSize(1, 1)
	scroll:SetScrollChild(rowsFrame)
	scroll:SetScript("OnSizeChanged", function(self, width) rowsFrame:SetWidth(width) end)
	rowsFrame:SetWidth(parent:GetWidth())

	local rowWidgets = {}

	local function rebuild()
		for _, w in ipairs(rowWidgets) do
			w:Hide()
			w:SetParent(nil)
		end
		wipe(rowWidgets)

		for i, preset in ipairs(settings.items) do
			local y = -(i - 1) * PRESET_ROW_HEIGHT

			local labelBox = ns.CreateSmallEditBox(rowsFrame, 112, 16)
			-- x=20 to match the "Button label" header above, which is anchored to
			-- `parent` while this row lives inside the scroll child, whose own left
			-- edge sits at the scrollframe's x=0.
			labelBox:SetPoint("TOPLEFT", 20, y)
			labelBox:SetText(preset.label)
			-- keeps radial wheel labels short enough to not bleed into their neighbors
			-- (UI/RadialMenu.lua also outward-anchors and wraps them as a second line of
			-- defense, but a shorter label just plain fits better)
			labelBox:SetMaxLetters(20)
			local function applyLabel(self)
				preset.label = self:GetText()
			end
			labelBox:SetScript("OnEnterPressed", function(self)
				applyLabel(self)
				self:ClearFocus()
			end)
			-- also commits on clicking/tabbing away, not just Enter, otherwise a typed
			-- rename silently never reaches `preset.label` if Enter is never pressed.
			labelBox:SetScript("OnEditFocusLost", applyLabel)
			labelBox:SetScript("OnEscapePressed", function(self)
				self:SetText(preset.label)
				self:ClearFocus()
			end)

			local textBox = ns.CreateSmallEditBox(rowsFrame, 240, 16)
			textBox:SetJustifyH("LEFT")
			textBox:SetPoint("LEFT", labelBox, "RIGHT", 8, 0)
			textBox:SetText(preset.text or "")
			local function applyText(self)
				preset.text = self:GetText()
			end
			textBox:SetScript("OnEnterPressed", function(self)
				applyText(self)
				self:ClearFocus()
			end)
			textBox:SetScript("OnEditFocusLost", applyText)
			textBox:SetScript("OnEscapePressed", function(self)
				self:SetText(preset.text or "")
				self:ClearFocus()
			end)

			local deltaBox = ns.CreateSmallEditBox(rowsFrame, 34, 16)
			deltaBox:SetPoint("LEFT", textBox, "RIGHT", 8, 0)
			deltaBox:SetText(tostring(preset.delta or 0))
			local function applyDelta(self)
				preset.delta = tonumber(self:GetText()) or 0
				self:SetText(tostring(preset.delta))
				self:ClearFocus()
			end
			deltaBox:SetScript("OnEnterPressed", applyDelta)
			deltaBox:SetScript("OnEditFocusLost", applyDelta)
			deltaBox:SetScript("OnEscapePressed", function(self)
				self:SetText(tostring(preset.delta or 0))
				self:ClearFocus()
			end)

			local deleteButton = CreateFrame("Button", nil, rowsFrame, "UIPanelButtonTemplate")
			deleteButton:SetSize(22, 18)
			deleteButton:SetText("X")
			deleteButton:SetPoint("LEFT", deltaBox, "RIGHT", 8, 0)
			deleteButton:SetScript("OnClick", function()
				table.remove(settings.items, i)
				rebuild()
			end)

			rowWidgets[#rowWidgets + 1] = labelBox
			rowWidgets[#rowWidgets + 1] = textBox
			rowWidgets[#rowWidgets + 1] = deltaBox
			rowWidgets[#rowWidgets + 1] = deleteButton
		end

		rowsFrame:SetHeight(math.max(#settings.items * PRESET_ROW_HEIGHT, 1))
	end

	addButton:SetScript("OnClick", function()
		table.insert(settings.items, { label = "New Preset", text = "", delta = 0 })
		rebuild()
	end)

	rebuild()

	local function setRestEnabled(enabled)
		setContainerEnabled(addButton, enabled)
		setContainerEnabled(headerLabel, enabled)
		setContainerEnabled(headerText, enabled)
		setContainerEnabled(headerDelta, enabled)
		setContainerEnabled(rowsFrame, enabled)
	end

	buildCheckbox(box, 8, -24, "Show one-click preset buttons in the quick-add popup",
		settings.enabled,
		function(checked)
			settings.enabled = checked
			setRestEnabled(checked)
		end)
	setRestEnabled(settings.enabled)
end

-- single-radial mode (second radial off) offers the whole preset list for ring 1 (and
-- GetRadialPresetSet's own default/cap matches: whole list uncapped). dual-radial mode
-- splits the options themselves by delta sign too, not just the default selection, so a
-- positive-only preset can't even be picked for the negative ring or vice versa.
local function radialPresetOptions(ring)
	local options = {}
	local secondEnabled = ns.GetSettings().radialMenu.secondEnabled
	for _, preset in ipairs(ns.GetSettings().quickPresets.items) do
		local include = true
		if secondEnabled then
			local delta = preset.delta or 0
			include = (ring == 1 and delta > 0) or (ring == 2 and delta < 0)
		end
		if include then
			options[#options + 1] = { value = preset.label, text = preset.label }
		end
	end
	return options
end

-- refills an options table in place (same object identity the dropdown's menu closure
-- already captured), so toggling "second radial" updates what's offered without having
-- to rebuild the dropdown widget itself
local function refillRadialOptions(target, ring)
	wipe(target)
	for _, option in ipairs(radialPresetOptions(ring)) do
		target[#target + 1] = option
	end
end

local function isRadialPresetSelected(ring, label)
	for _, preset in ipairs(ns.GetRadialPresetSet(ring)) do
		if preset.label == label then
			return true
		end
	end
	return false
end

-- first edit to a ring's list materializes the current (default-computed) set into an
-- explicit one before toggling, so flipping one preset doesn't blow away the rest of
-- whatever the smart default had selected
local function toggleRadialPreset(ring, label)
	local settings = ns.GetSettings().radialMenu
	local key = ring == 1 and "radial1Labels" or "radial2Labels"
	if not settings[key] then
		local list = {}
		for _, preset in ipairs(ns.GetRadialPresetSet(ring)) do
			list[#list + 1] = preset.label
		end
		settings[key] = list
	end
	local list = settings[key]
	for i, existing in ipairs(list) do
		if existing == label then
			table.remove(list, i)
			return
		end
	end
	if #list >= ns.MAX_RADIAL_PRESETS then
		return
	end
	list[#list + 1] = label
end

-- the secure wheel button's own preset count (wr-count, see UI/RadialMenu.lua) only
-- updates via rebuild(), which only runs at login/combat-end or when this is called
-- explicitly -- every other control on this tab already calls it after a change, this
-- one didn't, leaving the secure click math running on a stale count after toggling a
-- preset here: the wheel would visually show the right number of slices (it reads
-- settings fresh every time it opens) but releasing on the newly added/removed slice's
-- position wouldn't resolve to it, since the secure side could never compute that index
local function toggleRadialPresetAndRefresh(ring, label)
	toggleRadialPreset(ring, label)
	if ns.RefreshRadialMenuBinding then
		ns.RefreshRadialMenuBinding()
	end
end

local function radialPresetSummary(ring)
	local count = #ns.GetRadialPresetSet(ring)
	return count == 0 and "None" or (count .. " preset" .. (count == 1 and "" or "s"))
end

local function buildRadialMenuPanel(parent)
	local settings = ns.GetSettings().radialMenu
	local height = 388
	local box = createSectionBox(parent, -8, height, "Radial Menu")

	local hint = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	hint:SetPoint("TOPLEFT", 8, -22)
	hint:SetPoint("RIGHT", -10, 0)
	hint:SetJustifyH("LEFT")
	hint:SetWordWrap(true)
	hint:SetText("Hold the global keybind to open a radial of your presets at the cursor. Drag toward one and release to apply it to your target (or whoever you're hovering), or release in the center to cancel.")

	-- forward-declared so the master checkbox's callback (defined before these frames
	-- exist) can still close over the real frames once they're assigned below
	local body, secondBody
	local ring1Options, ring2Options

	local enableCheck = buildCheckbox(box, 8, 0, "Enable radial menu (hold the global keybind instead of tapping it)",
		settings.enabled,
		function(checked)
			settings.enabled = checked
			setContainerEnabled(body, checked)
			if ns.RefreshRadialMenuBinding then
				ns.RefreshRadialMenuBinding()
			end
		end)
	enableCheck:ClearAllPoints()
	enableCheck:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -14)

	-- holds everything but the master checkbox, so toggling it can't disable itself
	body = CreateFrame("Frame", nil, box)
	body:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 0, -10)
	body:SetPoint("BOTTOMRIGHT", 0, 0)
	body:SetSize(1, 1)

	local holdLabel = body:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	holdLabel:SetPoint("TOPLEFT", 8, 0)
	holdLabel:SetText("Minimum hold time (ms)")

	local holdBox = ns.CreateSmallEditBox(body, 50, 16, true)
	holdBox:SetPoint("LEFT", holdLabel, "RIGHT", 6, 0)
	holdBox:SetText(tostring(settings.minHoldMs))
	ns.AttachHookTooltip(holdBox,
		"How long (in milliseconds) the global keybind has to be held before a release counts as a radial pick. A pick faster than this falls back to the tap behavior instead, in case a quick or imprecise press looked like a drag by accident. Default 500.")
	local function applyHoldMs()
		local value = math.max(0, tonumber(holdBox:GetText()) or settings.minHoldMs)
		settings.minHoldMs = value
		holdBox:SetText(tostring(value))
		holdBox:ClearFocus()
	end
	holdBox:SetScript("OnEnterPressed", applyHoldMs)
	holdBox:SetScript("OnEditFocusLost", applyHoldMs)
	holdBox:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(settings.minHoldMs))
		self:ClearFocus()
	end)

	buildCheckbox(body, 8, -24, "Disable the radial wheel while in combat",
		settings.disableInCombat,
		function(checked) settings.disableInCombat = checked end)

	buildCheckbox(body, 8, -48, "Hide the tooltip while the radial is open",
		settings.suppressTooltip,
		function(checked) settings.suppressTooltip = checked end)

	buildCheckbox(body, 8, -72, "Also work when hovering a player, not just targeting one",
		settings.hoverEnabled,
		function(checked) settings.hoverEnabled = checked end)

	local ring1Label = body:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	ring1Label:SetPoint("TOPLEFT", 8, -122)

	local function updateRing1LabelText()
		ring1Label:SetText(settings.secondEnabled and "Radial 1 (positive) presets" or "Radial presets")
	end
	updateRing1LabelText()

	buildCheckbox(body, 8, -96, "Enable a second (negative) radial",
		settings.secondEnabled,
		function(checked)
			settings.secondEnabled = checked
			setContainerEnabled(secondBody, checked)
			refillRadialOptions(ring1Options, 1)
			refillRadialOptions(ring2Options, 2)
			updateRing1LabelText()
			if ns.RefreshRadialMenuBinding then
				ns.RefreshRadialMenuBinding()
			end
		end)

	ring1Options = radialPresetOptions(1)
	local ring1Dropdown = ns.CreateMultiSelectDropdown(body, ring1Options,
		function(value) return isRadialPresetSelected(1, value) end,
		function(value) toggleRadialPresetAndRefresh(1, value) end,
		function() return radialPresetSummary(1) end,
		220)
	ring1Dropdown:SetPoint("TOPLEFT", ring1Label, "BOTTOMLEFT", 2, -4)
	ns.AttachHookTooltip(ring1Dropdown, "Up to " .. ns.MAX_RADIAL_PRESETS .. " presets per radial.")

	-- holds the second-radial-only controls (the modifier picker and ring 2's preset
	-- list), so toggling that checkbox can't disable its own self either. ring 1's
	-- dropdown is NOT in here: it's how presets get assigned at all, so it stays usable
	-- regardless, even though single-radial mode ignores the selection and shows
	-- everything (letting it be set up ahead of enabling the second radial).
	secondBody = CreateFrame("Frame", nil, body)
	secondBody:SetPoint("TOPLEFT", ring1Dropdown, "BOTTOMLEFT", -2, -16)
	secondBody:SetPoint("BOTTOMRIGHT", 0, 0)
	secondBody:SetSize(1, 1)

	local modLabel = secondBody:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	modLabel:SetPoint("TOPLEFT", 8, 0)
	modLabel:SetText("Modifier for the negative radial")

	local modDropdown = ns.CreateDropdown(secondBody, {
		{ value = "CTRL", text = "Ctrl" },
		{ value = "ALT", text = "Alt" },
		{ value = "SHIFT", text = "Shift" },
	},
		function(value) return settings.secondModifier == value end,
		function(value)
			settings.secondModifier = value
			if ns.RefreshRadialMenuBinding then
				ns.RefreshRadialMenuBinding()
			end
		end,
		100, 20)
	modDropdown:SetPoint("TOPLEFT", modLabel, "BOTTOMLEFT", 2, -4)

	local ring2Label = secondBody:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	ring2Label:SetPoint("TOPLEFT", modDropdown, "BOTTOMLEFT", 0, -14)
	ring2Label:SetText("Radial 2 (negative) presets")

	ring2Options = radialPresetOptions(2)
	local ring2Dropdown = ns.CreateMultiSelectDropdown(secondBody, ring2Options,
		function(value) return isRadialPresetSelected(2, value) end,
		function(value) toggleRadialPresetAndRefresh(2, value) end,
		function() return radialPresetSummary(2) end,
		220)
	ring2Dropdown:SetPoint("TOPLEFT", ring2Label, "BOTTOMLEFT", 2, -4)
	ns.AttachHookTooltip(ring2Dropdown, "Up to " .. ns.MAX_RADIAL_PRESETS .. " presets per radial.")

	setContainerEnabled(body, settings.enabled)
	setContainerEnabled(secondBody, settings.secondEnabled)

	-- every sub-tab panel is actually built once, eagerly, when Options first opens
	-- (see ns.BuildOptionsPanel below: switching tabs only shows/hides each one's
	-- already-built content, it doesn't rebuild anything) -- so these dropdowns'
	-- option lists were a one-time snapshot of quickPresets.items from whenever
	-- that first happened, never refreshed again even after editing presets on the
	-- Presets tab. refilled every time this tab is actually shown instead, which
	-- covers every way the preset list could have changed since the last visit
	-- without needing to hook every individual add/remove/rename call site.
	parent:SetScript("OnShow", function()
		refillRadialOptions(ring1Options, 1)
		refillRadialOptions(ring2Options, 2)
	end)
end

-- Each sub-tab panel is built lazily on first visit, same pattern as the main window's
-- own tabs.
local SUB_TABS = {
	{ label = "General", build = buildGeneralPanel },
	{ label = "Reputation", build = buildRepBracketControl },
	{ label = "Auto-Track", build = buildAutoTrackPanel },
	{ label = "Alerts", build = buildNearbySoundControl },
	{ label = "Presets", build = buildPresetsPanel },
	{ label = "Radial Menu", build = buildRadialMenuPanel },
}

function ns.BuildOptionsPanel(parent)
	local contents = {}
	local buttons = {}

	local function selectSubTab(index)
		for i, content in ipairs(contents) do
			content:SetShown(i == index)
		end
		for i, button in ipairs(buttons) do
			button:SetEnabled(i ~= index)
		end
	end

	local prevButton
	for i, def in ipairs(SUB_TABS) do
		local button = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		button:SetSize(100, 22)
		button:SetText(def.label)
		if prevButton then
			button:SetPoint("LEFT", prevButton, "RIGHT", 6, 0)
		else
			button:SetPoint("TOPLEFT", 10, -8)
		end
		button:SetScript("OnClick", function() selectSubTab(i) end)
		buttons[i] = button
		prevButton = button

		local content = CreateFrame("Frame", nil, parent)
		content:SetPoint("TOPLEFT", 0, -38)
		content:SetPoint("BOTTOMRIGHT", 0, 0)
		content:Hide()
		def.build(content)
		contents[i] = content
	end

	selectSubTab(1)
end
