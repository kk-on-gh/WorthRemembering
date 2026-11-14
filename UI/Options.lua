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

-- data is the function that does the replacing
StaticPopupDialogs["WR_CONFIRM_RESET_CUSTOM_BRACKETS"] = {
	text = "Replace your custom bracket %s with the \"%s\" preset? This can't be undone.",
	button1 = "Replace",
	button2 = "Cancel",
	OnAccept = function(_, data)
		if data then
			data()
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

StaticPopupDialogs["WR_CONFIRM_RESET_UI"] = {
	text = "Reset every Worth Remembering window (position, size, scale, opacity, visibility), column layouts, Nearby window layout, minimap button, and nameplate icon size/offset? Your UI will reload.",
	button1 = "Reset UI",
	button2 = "Cancel",
	OnAccept = function()
		ns.ResetUISettings()
		ReloadUI()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

StaticPopupDialogs["WR_CONFIRM_RESET_OPTIONS"] = {
	text = "Reset ALL Worth Remembering options to their defaults? Your players, notes, and standings are kept. Your UI will reload.",
	button1 = "Reset Options",
	button2 = "Cancel",
	OnAccept = function()
		ns.ResetAllSettings()
		ReloadUI()
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
	elseif objType == "Slider" then
		-- dimming alone left a grayed-out slider still draggable
		container:EnableMouse(enabled)
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

	-- the parts too, for callers that gray the whole slider out or set it from elsewhere
	return valueBox, { label = label, slider = slider, lowText = lowText, highText = highText, valueBox = valueBox }
end

-- a bordered, titled box matching the grouped-section look used throughout Options.
-- spans the panel's full width (12px side margins), fixed height, title in top-left.
-- the most recently created section box, so wrapCollapsible can find the box a builder
-- just made without every builder having to return it
local lastSectionBox

local function createSectionBox(parent, y, height, title)
	local box = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	box:SetPoint("TOPLEFT", 12, y)
	box:SetPoint("TOPRIGHT", -12, y)
	box:SetHeight(height)
	ns.ApplyPanelBackdrop(box, 0.4)

	local titleText = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	titleText:SetPoint("TOPLEFT", 8, -6)
	titleText:SetText(title)
	box.titleText = titleText

	lastSectionBox = box
	return box, titleText
end

-- height of a collapsed box (just its title row); an expanded box's content starts at
-- -COLLAPSED_HEIGHT, right under the title
local COLLAPSED_HEIGHT = 24

-- a +/- toggle at the start of a box's title row. clicking the title toggles too
local function createDisclosure(box, expanded, onClick)
	-- same tinted-UIPanelButtonTemplate look as the Players tab's +/- buttons
	local toggleButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	toggleButton:SetSize(18, 16)
	toggleButton:SetPoint("TOPLEFT", 5, -4)
	local toggleTint = toggleButton:CreateTexture(nil, "ARTWORK", nil, -1)
	toggleTint:SetPoint("TOPLEFT", 3, -3)
	toggleTint:SetPoint("BOTTOMRIGHT", -3, 3)
	toggleTint:SetColorTexture(0.6, 0.18, 0.18, 0.65)
	toggleButton:SetText(expanded and "-" or "+")
	toggleButton:SetScript("OnClick", onClick)

	local title = box.titleText
	if title then
		title:ClearAllPoints()
		title:SetPoint("LEFT", toggleButton, "RIGHT", 5, 0)
		local titleButton = CreateFrame("Button", nil, box)
		titleButton:SetPoint("TOPLEFT", title, "TOPLEFT", -2, 3)
		titleButton:SetPoint("BOTTOMRIGHT", title, "BOTTOMRIGHT", 2, -3)
		titleButton:SetScript("OnClick", onClick)
	end
	return toggleButton
end

local BACKDROP_PIECES = {
	"TopLeftCorner", "TopRightCorner", "BottomLeftCorner", "BottomRightCorner",
	"TopEdge", "BottomEdge", "LeftEdge", "RightEdge", "Center",
}

-- turns any existing section-box builder into a collapsible one: builds it normally,
-- then (collapsed) hides everything but the title and border and shrinks it to the
-- title row. expandedState[key] is session-only, so every box starts collapsed
local function wrapCollapsible(expandedState, key, builder, parent, y, onToggle)
	local nextY = builder(parent, y)
	local box = lastSectionBox
	local expanded = expandedState[key] == true

	if not expanded then
		local keep = { [box.titleText] = true }
		for _, pieceName in ipairs(BACKDROP_PIECES) do
			if box[pieceName] then
				keep[box[pieceName]] = true
			end
		end
		for _, child in ipairs({ box:GetChildren() }) do
			child:Hide()
		end
		for _, region in ipairs({ box:GetRegions() }) do
			if not keep[region] then
				region:Hide()
			end
		end
		box:SetHeight(COLLAPSED_HEIGHT)
		nextY = y - COLLAPSED_HEIGHT - 6
	end

	createDisclosure(box, expanded, function()
		expandedState[key] = not expanded
		onToggle()
	end)
	return nextY
end

local function buildWindowBox(parent, y)
	local height = 228
	local box = createSectionBox(parent, y, height, "Main")

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

	local bodyStyleLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	bodyStyleLabel:SetPoint("TOPLEFT", 10, -134)
	bodyStyleLabel:SetText("Body type display")
	local bodyStyleDropdown = ns.CreateDropdown(box, {
		{ value = "binary", text = "Male/Female" },
		{ value = "numbered", text = "1/2" },
	},
		function(value) return ns.GetSettings().bodyTypeStyle == value end,
		function(value)
			ns.GetSettings().bodyTypeStyle = value
			ns.RefreshAllTabs()
		end,
		140, 20)
	bodyStyleDropdown:SetPoint("TOPLEFT", bodyStyleLabel, "BOTTOMLEFT", 2, -4)
	setTooltip(bodyStyleDropdown, "How a player's body type is shown on the Players and History tabs.")

	local bodyLabelLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	bodyLabelLabel:SetPoint("TOPLEFT", 190, -134)
	bodyLabelLabel:SetText("Body label")
	local bodyLabelDropdown = ns.CreateDropdown(box, {
		{ value = "bodyType", text = "Body Type" },
		{ value = "sex", text = "Sex" },
	},
		function(value) return ns.GetSettings().bodyTypeLabel == value end,
		function(value)
			ns.GetSettings().bodyTypeLabel = value
			ns.RefreshAllTabs()
		end,
		140, 20)
	bodyLabelDropdown:SetPoint("TOPLEFT", bodyLabelLabel, "BOTTOMLEFT", 2, -4)
	setTooltip(bodyLabelDropdown, "What that column is titled.")

	buildCheckbox(box, 10, -176, "Hide the +/- standing buttons (Players tab)",
		ns.GetSettings().hidePlayersStandingButtons,
		function(checked)
			ns.GetSettings().hidePlayersStandingButtons = checked
			-- re-enabling: if the Standing column got shrunk below the
			-- buttons-shown minimum while they were hidden, widen it back out so
			-- the buttons don't float over the Bracket column next to it
			if not checked and ns.EnforcePlayersColumnMinWidth then
				ns.EnforcePlayersColumnMinWidth("standing", 100)
			elseif ns.RefreshOverview then
				ns.RefreshOverview()
			end
		end)

	buildCheckbox(box, 10, -198, "Hide the New entry button (Players tab)",
		ns.GetSettings().hidePlayersNewButton,
		function(checked)
			ns.GetSettings().hidePlayersNewButton = checked
			if not checked and ns.EnforcePlayersColumnMinWidth then
				ns.EnforcePlayersColumnMinWidth("notes", 90)
			elseif ns.RefreshOverview then
				ns.RefreshOverview()
			end
		end)

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
		if ns.RefreshBracketRangeLabels then
			ns.RefreshBracketRangeLabels()
		end
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
	setTooltip(shiftBox, "Shift-click the +/- buttons on the Players tab or the instance survey to adjust standing by this amount instead of 1.")
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

	-- width works in both modes; height only with a static size, since auto-sizing sets
	-- its own height from the player count. kept in step with the window's own resize grip
	local SIZE_ROW_Y = -104
	local syncingSize = false
	local _, widthParts = buildSlider(box, {
		x = 10, y = SIZE_ROW_Y, label = "Width", min = ns.NEARBY_MIN_WIDTH, max = 300, step = 1, width = 150,
		getValue = function() return math.floor((ns.GetNearbyWindowSize()) + 0.5) end,
		setValue = function(value)
			if not syncingSize then
				ns.SetNearbyWindowSize(value, nil)
			end
		end,
	})
	local _, heightParts = buildSlider(box, {
		x = 190, y = SIZE_ROW_Y, label = "Height", min = ns.NEARBY_MIN_HEIGHT, max = 600, step = 1, width = 150,
		getValue = function() return math.floor(select(2, ns.GetNearbyWindowSize()) + 0.5) end,
		setValue = function(value)
			if not syncingSize then
				ns.SetNearbyWindowSize(nil, value)
			end
		end,
	})
	local function setHeightEnabled(enabled)
		for _, part in pairs(heightParts) do
			setContainerEnabled(part, enabled)
		end
	end
	ns.OnNearbyWindowResized = function(width, height)
		syncingSize = true
		widthParts.slider:SetValue(math.floor(width + 0.5))
		heightParts.slider:SetValue(math.floor(height + 0.5))
		syncingSize = false
	end

	local SCALE_ROW_Y = -164

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
	-- the row limit only applies while auto-sizing, so it grays out with a fixed size
	local limitLabel, limitBox
	local function setLimitEnabled(enabled)
		setContainerEnabled(limitLabel, enabled)
		setContainerEnabled(limitBox, enabled)
	end
	local staticCheck = buildCheckbox(box, 8, staticCheckY,
		"Use a static, resizable size (drag the corner grip) instead of auto-sizing",
		ns.GetSettings().nearbyStaticSize,
		function(checked)
			if ns.SetNearbyStaticSize then ns.SetNearbyStaticSize(checked) end
			growDropdown:SetEnabled(not checked)
			setLimitEnabled(not checked)
			setHeightEnabled(checked)
		end)
	setHeightEnabled(ns.GetSettings().nearbyStaticSize)
	-- growth direction only matters while the window auto-sizes to its content, a
	-- fixed/resizable window doesn't grow in either direction, so it's meaningless
	-- while static size is on.
	growDropdown:SetEnabled(not ns.GetSettings().nearbyStaticSize)

	limitLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	limitLabel:SetPoint("TOPLEFT", 10, staticCheckY - 27)
	limitLabel:SetText("Visible row limit |cffffffff(scrolls beyond this; ignored when using a static size)|r")

	limitBox = ns.CreateSmallEditBox(box, 30, 14, true)
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
	setLimitEnabled(not ns.GetSettings().nearbyStaticSize)

	local ROW_CLICK_OPTIONS = {
		{ value = "details", text = "Details" },
		{ value = "quickadd", text = "Quick-Add" },
		{ value = "nothing", text = "Nothing" },
	}

	local singleLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	singleLabel:SetPoint("TOPLEFT", 10, staticCheckY - 57)
	singleLabel:SetText("Single click")
	local singleDropdown = ns.CreateDropdown(box, ROW_CLICK_OPTIONS,
		function(value) return (ns.GetSettings().nearbySingleClick or "quickadd") == value end,
		function(value) ns.GetSettings().nearbySingleClick = value end,
		120, 20)
	singleDropdown:SetPoint("LEFT", singleLabel, "RIGHT", 6, 0)
	setTooltip(singleDropdown, "What clicking a player's row in the Nearby window opens.")

	local doubleLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	doubleLabel:SetPoint("LEFT", singleDropdown, "RIGHT", 24, 0)
	doubleLabel:SetText("Double click")
	local doubleDropdown = ns.CreateDropdown(box, ROW_CLICK_OPTIONS,
		function(value) return (ns.GetSettings().nearbyDoubleClick or "details") == value end,
		function(value) ns.GetSettings().nearbyDoubleClick = value end,
		120, 20)
	doubleDropdown:SetPoint("LEFT", doubleLabel, "RIGHT", 6, 0)
	setTooltip(doubleDropdown, "What double-clicking a player's row opens. Set to Nothing and a single click responds instantly, with no wait for a possible second click.")

	local speedLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	speedLabel:SetPoint("TOPLEFT", 10, staticCheckY - 85)
	speedLabel:SetText("Double-click speed (ms)")
	local speedBox = ns.CreateSmallEditBox(box, 40, 14, true)
	speedBox:SetPoint("LEFT", speedLabel, "RIGHT", 6, 0)
	speedBox:SetText(tostring(ns.GetSettings().nearbyDoubleClickMs or 300))
	setTooltip(speedBox, "How quickly the second click has to follow the first to count as a double click. It's also how long a single click waits before acting, so lower feels snappier but needs faster double clicks. Default 300.")
	local function applySpeed()
		local value = math.max(100, math.min(1000, tonumber(speedBox:GetText()) or 300))
		ns.GetSettings().nearbyDoubleClickMs = value
		speedBox:SetText(tostring(value))
		speedBox:ClearFocus()
	end
	speedBox:SetScript("OnEnterPressed", applySpeed)
	speedBox:SetScript("OnEditFocusLost", applySpeed)
	speedBox:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(ns.GetSettings().nearbyDoubleClickMs or 300))
		self:ClearFocus()
	end)

	local height = 332
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
	local height = 100
	local box = createSectionBox(parent, y, height, "Chat & Minimap")

	local chatSettings = ns.GetSettings().chatIndicator
	buildCheckbox(box, 8, -22, "Show a standing tag, e.g. [+10], after notable players' names in chat",
		chatSettings.enabled,
		function(checked) chatSettings.enabled = checked end)

	local minimapSettings = ns.GetSettings().minimapIcon
	buildCheckbox(box, 8, -46, "Show the minimap icon",
		not minimapSettings.hide,
		function(checked) ns.SetMinimapIconShown(checked) end)

	buildCheckbox(box, 8, -70, "Show \"Entry created\" message in chat window",
		ns.GetSettings().showEntryCreatedMessage,
		function(checked) ns.GetSettings().showEntryCreatedMessage = checked end)

	return y - height - 6
end

local FILTER_TABS = {
	{ tab = "players", label = "Players tab" },
	{ tab = "history", label = "History tab" },
}

local function buildFiltersBox(parent, y)
	local height = 81
	local box = createSectionBox(parent, y, height, "Filters")
	local hiddenFilters = ns.GetSettings().hiddenFilters

	local labels = {}
	for i, def in ipairs(FILTER_TABS) do
		local label = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		label:SetPoint("TOPLEFT", 12, -28 - (i - 1) * 26)
		label:SetText(def.label)
		labels[i] = label
	end
	local labelWidth = 0
	for _, label in ipairs(labels) do
		labelWidth = math.max(labelWidth, label:GetStringWidth())
	end

	for i, def in ipairs(FILTER_TABS) do
		local hidden = hiddenFilters[def.tab]
		local options = ns.FILTER_TOGGLES[def.tab]
		local dropdown = ns.CreateMultiSelectDropdown(box, options,
			function(value) return not hidden[value] end,
			function(value)
				hidden[value] = not hidden[value] or nil
				ns.ApplyHiddenFilters(def.tab)
			end,
			function()
				local count = 0
				for _, option in ipairs(options) do
					if hidden[option.value] then
						count = count + 1
					end
				end
				return count == 0 and "All shown" or (count .. " hidden")
			end, 160, "Show all", function()
				wipe(hidden)
				ns.ApplyHiddenFilters(def.tab)
			end)
		dropdown:SetPoint("LEFT", labels[i], "LEFT", labelWidth + 10, 0)
		ns.AttachHookTooltip(dropdown, "Uncheck a filter to hide it from the " .. def.label .. "'s filter bar. Hiding a filter also clears it.")
	end

	return y - height - 6
end

local TOOLTIP_CONTENT_OPTIONS = {
	{ value = "rating", text = "Rating" },
	{ value = "bracket", text = "Bracket" },
	{ value = "lastNote", text = "Last Note" },
	{ value = "featuredNote", text = "Featured Note" },
	{ value = "timesSeen", text = "Times Seen" },
	{ value = "noteCount", text = "Note Count" },
}

local function tooltipContentSummary()
	local content = ns.GetSettings().tooltipContent
	local names = {}
	for _, option in ipairs(TOOLTIP_CONTENT_OPTIONS) do
		if content[option.value] then
			names[#names + 1] = option.text
		end
	end
	return #names > 0 and table.concat(names, ", ") or "None"
end

local function buildTooltipContextBox(parent, y)
	local height = 81
	local box = createSectionBox(parent, y, height, "Tooltip & Context Menu")

	local tooltipDropdown, tooltipLabel
	local tooltipCheck = ns.CreateSmallCheckbox(box, 24, ns.GetSettings().tooltipEnabled,
		function(checked)
			ns.GetSettings().tooltipEnabled = checked
			setContainerEnabled(tooltipDropdown, checked)
			setContainerEnabled(tooltipLabel, checked)
		end)
	tooltipCheck:SetPoint("TOPLEFT", 8, -22)
	ns.AttachTooltip(tooltipCheck, "Adds a line to notable players' tooltips, showing whichever info is selected here.")

	tooltipLabel = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	tooltipLabel:SetPoint("LEFT", tooltipCheck, "RIGHT", 4, 0)
	tooltipLabel:SetText("Tooltip")

	tooltipDropdown = ns.CreateMultiSelectDropdown(box, TOOLTIP_CONTENT_OPTIONS,
		function(value) return ns.GetSettings().tooltipContent[value] end,
		function(value)
			local content = ns.GetSettings().tooltipContent
			content[value] = not content[value]
		end,
		tooltipContentSummary, 160)
	tooltipDropdown:SetPoint("LEFT", tooltipLabel, "RIGHT", 8, 0)
	setContainerEnabled(tooltipDropdown, ns.GetSettings().tooltipEnabled)
	setContainerEnabled(tooltipLabel, ns.GetSettings().tooltipEnabled)

	local menuLabel
	local menuCheck = ns.CreateSmallCheckbox(box, 24, ns.GetSettings().contextMenuEnabled,
		function(checked)
			ns.GetSettings().contextMenuEnabled = checked
			setContainerEnabled(menuLabel, checked)
		end)
	menuCheck:SetPoint("TOPLEFT", tooltipCheck, "BOTTOMLEFT", 0, -5)
	ns.AttachTooltip(menuCheck, "Adds Add Note/Show Details/Delete Player to a notable player's right-click menu.")

	menuLabel = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	menuLabel:SetPoint("LEFT", menuCheck, "RIGHT", 4, 0)
	menuLabel:SetText("Right-click \"Worth Remembering\" menu")
	setContainerEnabled(menuLabel, ns.GetSettings().contextMenuEnabled)

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

local TAP_ACTION_OPTIONS = {
	{ value = "quicknote", text = "Quick-Note" },
	{ value = "history", text = "History Tab" },
	{ value = "details", text = "Details Tab" },
}

local function buildKeybindControl(parent, y)
	local height = 176
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
	local fallbackDropdown, fallbackLabel

	local fallbackCheck = ns.CreateSmallCheckbox(box, 24, ns.GetSettings().quickNoteFallbackEnabled,
		function(checked)
			ns.GetSettings().quickNoteFallbackEnabled = checked
			setContainerEnabled(fallbackDropdown, checked)
			setContainerEnabled(fallbackLabel, checked)
		end)
	fallbackCheck:SetPoint("TOPLEFT", hint, "BOTTOMLEFT", 0, -12)

	fallbackLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
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
	setContainerEnabled(fallbackLabel, ns.GetSettings().quickNoteFallbackEnabled)

	-- forward-declared, same reason as fallbackDropdown/hoverDropdown below
	local targetDropdown, targetLabel

	local targetCheck = ns.CreateSmallCheckbox(box, 24, ns.GetSettings().tapTargetEnabled,
		function(checked)
			ns.GetSettings().tapTargetEnabled = checked
			setContainerEnabled(targetDropdown, checked)
			setContainerEnabled(targetLabel, checked)
		end)
	targetCheck:SetPoint("TOPLEFT", fallbackCheck, "BOTTOMLEFT", 0, -10)
	targetLabel = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	targetLabel:SetPoint("LEFT", targetCheck, "RIGHT", 4, 0)
	targetLabel:SetText("With a target, open")

	targetDropdown = ns.CreateDropdown(box, TAP_ACTION_OPTIONS,
		function(value) return ns.GetSettings().tapTargetAction == value end,
		function(value) ns.GetSettings().tapTargetAction = value end,
		110, 20)
	targetDropdown:SetPoint("LEFT", targetLabel, "RIGHT", 8, 0)
	setContainerEnabled(targetDropdown, ns.GetSettings().tapTargetEnabled)
	setContainerEnabled(targetLabel, ns.GetSettings().tapTargetEnabled)

	-- forward-declared, same reason as fallbackDropdown above
	local hoverDropdown, hoverLabel

	local hoverCheck = ns.CreateSmallCheckbox(box, 24, ns.GetSettings().quickNoteHoverEnabled,
		function(checked)
			ns.GetSettings().quickNoteHoverEnabled = checked
			setContainerEnabled(hoverDropdown, checked)
			setContainerEnabled(hoverLabel, checked)
		end)
	-- chained off the checkbox above it (not a guessed fixed y): a checkbox row is
	-- taller than a plain text line, so a fixed offset sized for the old label-only
	-- layout overlapped this with the row above it
	hoverCheck:SetPoint("TOPLEFT", targetCheck, "BOTTOMLEFT", 0, -10)
	hoverLabel = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	hoverLabel:SetPoint("LEFT", hoverCheck, "RIGHT", 4, 0)
	hoverLabel:SetText("While hovering (not targeting), open")

	hoverDropdown = ns.CreateDropdown(box, TAP_ACTION_OPTIONS,
		function(value) return ns.GetSettings().tapHoverAction == value end,
		function(value) ns.GetSettings().tapHoverAction = value end,
		110, 20)
	hoverDropdown:SetPoint("LEFT", hoverLabel, "RIGHT", 8, 0)
	setContainerEnabled(hoverDropdown, ns.GetSettings().quickNoteHoverEnabled)
	setContainerEnabled(hoverLabel, ns.GetSettings().quickNoteHoverEnabled)

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

-- session-only: collapsed on every fresh Options open
local dangerZoneExpanded = false

local DANGER_ZONE_ACTIONS = {
	{ text = "Reset UI", popup = "WR_CONFIRM_RESET_UI",
		hint = "Every window's position, size, scale, opacity, and layout, plus columns and the minimap button. Reloads your UI." },
	{ text = "Reset All Options", popup = "WR_CONFIRM_RESET_OPTIONS",
		hint = "Puts every option back to its default. Your players, notes, and standings are kept. Reloads your UI." },
	{ text = "Clear Non-Notable", popup = "WR_CONFIRM_CLEAR_NONNOTABLE", countNonNotable = true,
		hint = "Deletes players with exactly 0 standing and no notes (e.g. bare auto-tracked entries)." },
	{ text = "Clear Database", popup = "WR_CONFIRM_CLEAR_DATABASE",
		hint = "Deletes every note and standing for every player, on every character. Cannot be undone." },
}
local DANGER_ZONE_ROW_HEIGHT = 26

-- returns the next y and the box, so the caller can rebuild it in place on toggle
local function buildDangerZoneBox(parent, y, onToggle)
	local height = COLLAPSED_HEIGHT
	if dangerZoneExpanded then
		height = height + 2 + #DANGER_ZONE_ACTIONS * DANGER_ZONE_ROW_HEIGHT
	end
	local box = createSectionBox(parent, y, height, "Danger Zone")
	createDisclosure(box, dangerZoneExpanded, function()
		dangerZoneExpanded = not dangerZoneExpanded
		onToggle()
	end)

	if dangerZoneExpanded then
		local rowY = -COLLAPSED_HEIGHT - 2
		for _, action in ipairs(DANGER_ZONE_ACTIONS) do
			local button = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
			button:SetSize(140, 20)
			button:SetText(action.text)
			button:SetPoint("TOPLEFT", 10, rowY)
			button:SetScript("OnClick", function()
				if action.countNonNotable then
					StaticPopup_Show(action.popup, ns.CountNonNotablePlayers())
				else
					StaticPopup_Show(action.popup)
				end
			end)

			local hint = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
			hint:SetPoint("LEFT", button, "RIGHT", 8, 0)
			hint:SetText(action.hint)

			rowY = rowY - DANGER_ZONE_ROW_HEIGHT
		end
	end

	return y - height - 6, box
end

local AUTO_PRUNE_CRITERIA_OPTIONS = {
	{ value = "unnoted", text = "No notes" },
	{ value = "unrepped", text = "Zero standing" },
	{ value = "neutral", text = "Neutral-band standing" },
	{ value = "notSeenDays", text = "Not seen in X days" },
}

local function buildAutoPruneControl(parent, y)
	local height = 100
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
	swatch.Refresh = refresh

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
	{ group = "positive", index = 1, row = 1, col = 1 },
	{ group = "positive", index = 2, row = 1, col = 2 },
	{ group = "positive", index = 3, row = 1, col = 3 },
	{ group = "positive", index = 4, row = 1, col = 4 },
	{ group = "zero", row = 2, col = 1 },
	{ group = "negative", index = 1, row = 3, col = 1 },
	{ group = "negative", index = 2, row = 3, col = 2 },
	{ group = "negative", index = 3, row = 3, col = 3 },
	{ group = "negative", index = 4, row = 3, col = 4 },
}

-- each bracket's standing range, from the live neutral band: the first bracket on each
-- side starts just past it (band 3: neutral is -3 to 3, then 4 to 25 / -4 to -25).
-- negative ranges read from the mild end outward, matching the positive row
local BRACKET_LOWER = { 1, 26, 51, 76 }
local BRACKET_UPPER = { 25, 50, 75, 100 }

local function bracketRangeText(field)
	local band = ns.GetSettings().neutralBand
	if field.group == "zero" then
		return band == 0 and "0" or (-band .. " to " .. band)
	end
	local lower = math.max(BRACKET_LOWER[field.index], band + 1)
	local upper = BRACKET_UPPER[field.index]
	if lower > upper then
		return "(inside neutral band)"
	end
	if field.group == "negative" then
		return -lower .. " to " .. -upper
	end
	return lower .. " to " .. upper
end
local ROW_LABELS = { "Positive", "Neutral", "Negative" }
local BOX_WIDTH, BOX_GAP, ROW_HEIGHT, LABEL_WIDTH = 120, 10, 44, 70
-- The edit box is narrower than the column pitch (BOX_WIDTH) so a color swatch fits
-- beside it within the same column slot, without widening the overall grid.
local EDIT_WIDTH, SWATCH_SIZE, SWATCH_GAP = 92, 20, 6

-- reset label + picker under the dropdowns, when either is on "Custom"
local RESET_ROW_HEIGHT = 44

local function presetDisplayName(key)
	return key:sub(1, 1):upper() .. key:sub(2)
end

-- a "Reset custom to: [dropdown]" picker. nothing is selected; picking a preset asks
-- for confirmation, then calls onPick
local function createResetPicker(parent, options, what, onPick)
	local picker
	picker = ns.CreateDropdown(parent, options,
		function() return false end,
		function(value, text)
			picker:SetText("Choose a preset")
			StaticPopup_Show("WR_CONFIRM_RESET_CUSTOM_BRACKETS", what, text, function() onPick(value) end)
		end,
		200)
	picker:SetText("Choose a preset")
	return picker
end

local function buildRepBracketControl(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	ns.SetGentleScroll(scroll)
	scroll:SetPoint("TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", -34, 0)

	local scrollChild = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(scrollChild)
	scroll:SetScript("OnSizeChanged", function(self, width)
		scrollChild:SetWidth(width)
	end)
	scrollChild:SetWidth(parent:GetWidth())

	-- rebuilt whenever either dropdown switches to or from "Custom", since that adds or
	-- removes the reset line and shifts everything below it
	local layout

	local function relayoutSoon()
		C_Timer.After(0, layout)
	end

	function layout()
		for _, child in ipairs({ scrollChild:GetChildren() }) do
			child:Hide()
			child:SetParent(nil)
		end

		local settings = ns.GetSettings()
		local labelsCustom = settings.repBracketPreset == "custom"
		local colorsCustom = settings.repBracketColorPreset == "custom"
		local showResetRow = labelsCustom or colorsCustom

		local y = -8
		local boxHeight = 80 + ROW_HEIGHT * 3 + 10 + (showResetRow and RESET_ROW_HEIGHT or 0)
		local box = createSectionBox(scrollChild, y, boxHeight, "Reputation Brackets")
		y = y - boxHeight - 6

		y = buildStandingBox(scrollChild, y)
		scrollChild:SetHeight(-y + 10)

		-- just the preset name, the always-visible 9 fields below already show the
		-- actual labels for whichever preset is selected.
		local options = {}
		for _, key in ipairs(ns.REP_BRACKET_PRESET_ORDER) do
			options[#options + 1] = { value = key, text = presetDisplayName(key) }
		end
		local labelPresetOptions = { unpack(options) }
		options[#options + 1] = { value = "custom", text = "Custom" }

		local colorOptions = {}
		for _, key in ipairs(ns.REP_COLOR_PRESET_ORDER) do
			colorOptions[#colorOptions + 1] = { value = key, text = ns.REP_COLOR_PRESETS[key].label }
		end
		local colorPresetOptions = { unpack(colorOptions) }
		colorOptions[#colorOptions + 1] = { value = "custom", text = "Custom" }

		-- 9 text fields across 3 rows (Positive/Neutral/Negative), always visible (not
		-- just for "Custom"), showing whichever preset is currently active. editing any
		-- field auto-promotes to "Custom" (copying the active preset's labels first, so
		-- the other 8 fields keep their values).
		local customRow = CreateFrame("Frame", nil, box)
		customRow:SetSize(1, ROW_HEIGHT * 3)

		local boxes = {}
		local swatches = {}
		local rangeLabels = {}
		-- the neutral band (Standing box, same tab) shifts these ranges
		ns.RefreshBracketRangeLabels = function()
			for _, entry in ipairs(rangeLabels) do
				entry.label:SetText(bracketRangeText(entry.field))
			end
		end

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

		local function refreshSwatches()
			for _, swatch in ipairs(swatches) do
				swatch.Refresh()
			end
		end

		local function promoteToCustom()
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
			relayoutSoon()
		end

		local function setFieldValue(field, text)
			promoteToCustom()
			local labels = settings.repBracketCustomLabels
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
			rangeLabel:SetText(bracketRangeText(field))
			rangeLabels[#rangeLabels + 1] = { label = rangeLabel, field = field }

			local editBox = ns.CreateSmallEditBox(customRow, EDIT_WIDTH, 16)
			local x = LABEL_WIDTH + (field.col - 1) * (BOX_WIDTH + BOX_GAP)
			local rowY = -(field.row - 1) * ROW_HEIGHT - 14
			editBox:SetPoint("TOPLEFT", customRow, "TOPLEFT", x, rowY)
			rangeLabel:SetPoint("BOTTOMLEFT", editBox, "TOPLEFT", 2, 2)
			editBox:SetScript("OnEnterPressed", function(self)
				setFieldValue(field, self:GetText())
				self:ClearFocus()
				refreshAllBracketDisplays()
			end)
			editBox:SetScript("OnEditFocusLost", function(self)
				setFieldValue(field, self:GetText())
				refreshAllBracketDisplays()
			end)
			boxes[i] = editBox

			local swatch = createColorSwatch(customRow,
				function() return unpack(ns.GetBracketColor(field.group, field.index)) end,
				function(r, g, b)
					local wasCustom = settings.repBracketColorPreset == "custom"
					ns.SetBracketColor(field.group, field.index, r, g, b)
					refreshAllBracketDisplays()
					if not wasCustom then
						relayoutSoon()
					end
				end)
			swatch:SetPoint("LEFT", editBox, "RIGHT", SWATCH_GAP, 0)
			swatches[#swatches + 1] = swatch
		end

		local presetLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		presetLabel:SetPoint("TOPLEFT", 10, -24)
		presetLabel:SetText("Preset")

		local dropdown = ns.CreateDropdown(box, options,
			function(value) return settings.repBracketPreset == value end,
			function(value)
				local changedCustom = (value == "custom") ~= labelsCustom
				settings.repBracketPreset = value
				refreshFieldDisplay()
				refreshAllBracketDisplays()
				if changedCustom then
					relayoutSoon()
				end
			end,
			200)
		dropdown:SetPoint("TOPLEFT", presetLabel, "BOTTOMLEFT", 4, -4)

		local colorsLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		colorsLabel:SetPoint("LEFT", presetLabel, "LEFT", 240, 0)
		colorsLabel:SetText("Colors")

		local colorDropdown = ns.CreateDropdown(box, colorOptions,
			function(value) return settings.repBracketColorPreset == value end,
			function(value)
				local changedCustom = (value == "custom") ~= colorsCustom
				ns.ApplyBracketColorPreset(value)
				refreshSwatches()
				refreshAllBracketDisplays()
				if changedCustom then
					relayoutSoon()
				end
			end,
			200)
		colorDropdown:SetPoint("TOPLEFT", colorsLabel, "BOTTOMLEFT", 4, -4)

		-- under whichever dropdown is on "Custom": overwrites that custom set with a
		-- built-in one, staying on Custom so it can be edited from there
		if labelsCustom then
			local labelReset = createResetPicker(box, labelPresetOptions, "labels", function(key)
				ns.ResetCustomBracketLabels(key)
				refreshFieldDisplay()
				refreshAllBracketDisplays()
			end)
			labelReset:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", 0, -22)
			local labelResetText = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			labelResetText:SetPoint("BOTTOMLEFT", labelReset, "TOPLEFT", -4, 3)
			labelResetText:SetText("Reset custom labels to:")
		end

		if colorsCustom then
			local colorReset = createResetPicker(box, colorPresetOptions, "colors", function(key)
				ns.ResetCustomBracketColors(key)
				refreshSwatches()
				refreshAllBracketDisplays()
			end)
			colorReset:SetPoint("TOPLEFT", colorDropdown, "BOTTOMLEFT", 0, -22)
			local colorResetText = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			colorResetText:SetPoint("BOTTOMLEFT", colorReset, "TOPLEFT", -4, 3)
			colorResetText:SetText("Reset custom colors to:")
		end

		customRow:SetPoint("TOPLEFT", dropdown, "BOTTOMLEFT", -4, -16 - (showResetRow and RESET_ROW_HEIGHT or 0))

		refreshFieldDisplay()
	end

	layout()
end

-- wrapped in a scroll frame, enough rows have accumulated (opacity/scale, formats,
-- neutral band, shift-click, and the whole Nearby-window section) that this tab can
-- run taller than the window's minimum height, same as Statistics.lua.
-- each build*(parent, y) call below returns the y to start the next box at, threading a
-- single top-level cursor through fixed-height boxes, not derived from any previous
-- box's live GetHeight(), so it avoids the chained-anchor mismatch that template
-- children (e.g. UICheckButtonTemplate) cause elsewhere.
-- session-only: every General box starts collapsed on a fresh Options open
local generalBoxesExpanded = {}

local function buildGeneralPanel(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	ns.SetGentleScroll(scroll)
	scroll:SetPoint("TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", -34, 0)

	local scrollChild = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(scrollChild)
	scroll:SetScript("OnSizeChanged", function(self, width)
		scrollChild:SetWidth(width)
	end)
	scrollChild:SetWidth(parent:GetWidth())

	-- every box is collapsible, so the whole panel rebuilds when one is toggled
	local boxes = {
		{ key = "keybind", build = buildKeybindControl },
		{ key = "window", build = buildWindowBox },
		{ key = "filters", build = buildFiltersBox },
		{ key = "nearby", build = buildNearbyWindowControl },
		{ key = "nameplate", build = buildNameplateIconControl },
		{ key = "chatMinimap", build = buildChatMinimapBox },
		{ key = "tooltip", build = buildTooltipContextBox },
		{ key = "lfg", build = buildLFGIntegrationControl },
		{ key = "autoPrune", build = buildAutoPruneControl },
	}

	local layout
	function layout()
		for _, child in ipairs({ scrollChild:GetChildren() }) do
			child:Hide()
			child:SetParent(nil)
		end
		local y = -8
		for _, def in ipairs(boxes) do
			y = wrapCollapsible(generalBoxesExpanded, def.key, def.build, scrollChild, y, layout)
		end
		y = buildDangerZoneBox(scrollChild, y, layout)
		scrollChild:SetHeight(-y + 10)
	end
	layout()
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

GLOBAL_HOTKEY_HELP_TEXT = "Tap: runs the action set below for your target, or (if hover's enabled) whoever you're hovering if nothing's targeted. With neither, opens the window to the tab set below, or does nothing if that's turned off.\n\n"
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

-- edit box bound to option[field]: applies on Enter/focus loss, reverts on Escape
local function bindTextBox(editBox, option, field)
	editBox:SetText(option[field] or "")
	local function apply()
		option[field] = editBox:GetText()
		editBox:ClearFocus()
	end
	editBox:SetScript("OnEnterPressed", apply)
	editBox:SetScript("OnEditFocusLost", apply)
	editBox:SetScript("OnEscapePressed", function(self)
		self:SetText(option[field] or "")
		self:ClearFocus()
	end)
end

local function bindMinutesBox(editBox, option, field)
	editBox:SetText(tostring(option[field]))
	local function apply()
		local value = math.max(0, tonumber(editBox:GetText()) or option[field])
		option[field] = value
		editBox:SetText(tostring(value))
		editBox:ClearFocus()
	end
	editBox:SetScript("OnEnterPressed", apply)
	editBox:SetScript("OnEditFocusLost", apply)
	editBox:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(option[field]))
		self:ClearFocus()
	end)
end

local function autoTrackRowHeight(def)
	local lines = (def.hasMinGrouped or def.hasDuelResult) and 2 or 1
	return 30 + lines * 20
end

-- One row's checkbox + indented Rep gain/Note/(optional) Cooldown fields, plus an
-- optional second line. Shared by the General and Directed Emotes boxes.
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

	-- blank means no note gets logged, just the rep change
	local noteBox = ns.CreateSmallEditBox(detailRow, 240, 16)
	noteBox:SetJustifyH("LEFT")
	noteBox:SetPoint("LEFT", noteLabel, "RIGHT", 6, 0)
	bindTextBox(noteBox, option, "note")

	if def.hasCooldown then
		local cooldownLabel = detailRow:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		cooldownLabel:SetPoint("LEFT", noteBox, "RIGHT", 16, 0)
		cooldownLabel:SetText("Cooldown")

		local cooldownBox = ns.CreateSmallEditBox(detailRow, 30, 14, true)
		cooldownBox:SetPoint("LEFT", cooldownLabel, "RIGHT", 6, 0)
		bindMinutesBox(cooldownBox, option, "cooldownMinutes")
		setTooltip(cooldownBox, "Minutes before this can log again for the same player.")
		detailRow.cooldownBox = cooldownBox
	end

	if def.hasMinGrouped then
		local minGroupedLabel = detailRow:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		minGroupedLabel:SetPoint("TOPLEFT", 0, -20)
		minGroupedLabel:SetText("Min. time grouped (minutes, 0 = off)")

		local minGroupedBox = ns.CreateSmallEditBox(detailRow, 30, 14, true)
		minGroupedBox:SetPoint("LEFT", minGroupedLabel, "RIGHT", 6, 0)
		bindMinutesBox(minGroupedBox, option, "minGroupedMinutes")
		setTooltip(minGroupedBox, "Only logs for a party/raid member once they've been grouped with you this long. 0 logs for anyone currently grouped, regardless of when they joined.")
	end

	if def.hasDuelResult then
		local resultLabel = detailRow:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		resultLabel:SetPoint("TOPLEFT", 0, -20)
		resultLabel:SetText("{{duelresult}}")

		local victoryLabel = detailRow:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		victoryLabel:SetPoint("LEFT", resultLabel, "RIGHT", 12, 0)
		victoryLabel:SetText("Victory")
		local victoryBox = ns.CreateSmallEditBox(detailRow, 110, 16)
		victoryBox:SetJustifyH("LEFT")
		victoryBox:SetPoint("LEFT", victoryLabel, "RIGHT", 6, 0)
		bindTextBox(victoryBox, option, "victoryText")
		setTooltip(victoryBox, "What {{duelresult}} becomes in the note when you win.")

		local lossLabel = detailRow:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		lossLabel:SetPoint("LEFT", victoryBox, "RIGHT", 16, 0)
		lossLabel:SetText("Loss")
		local lossBox = ns.CreateSmallEditBox(detailRow, 110, 16)
		lossBox:SetJustifyH("LEFT")
		lossBox:SetPoint("LEFT", lossLabel, "RIGHT", 6, 0)
		bindTextBox(lossBox, option, "lossText")
		setTooltip(lossBox, "What {{duelresult}} becomes in the note when you lose or flee.")
	end

	setContainerEnabled(detailRow, option.enabled)
	return check, detailRow
end

-- session-only: reset on every fresh Options open, not persisted to settings
local autoTrackGeneralExpanded = false
local autoTrackEmotesExpanded = false

-- a collapsible box of buildAutoTrackRow rows
local function buildAutoTrackRowsBox(parent, y, title, defs, expanded, onClick)
	local settings = ns.GetSettings().autoTrack

	local height = COLLAPSED_HEIGHT
	if expanded then
		for _, def in ipairs(defs) do
			height = height + autoTrackRowHeight(def)
		end
	end

	local box = createSectionBox(parent, y, height, title)
	createDisclosure(box, expanded, onClick)

	if expanded then
		local rowY = -COLLAPSED_HEIGHT
		for _, def in ipairs(defs) do
			buildAutoTrackRow(box, def, settings[def.key], rowY)
			rowY = rowY - autoTrackRowHeight(def)
		end
	end

	return y - height - 6
end

local function buildAutoTrackGeneralBox(parent, y, onToggle)
	return buildAutoTrackRowsBox(parent, y, "General", ns.AUTO_TRACK_DEFS, autoTrackGeneralExpanded, function()
		autoTrackGeneralExpanded = not autoTrackGeneralExpanded
		onToggle()
	end)
end

local EMOTE_RULE_DEF = { label = "", hasCooldown = true }
-- extra space between a rule's Match line and its Rep gain/Note line
local EMOTE_RULE_LINE_GAP = 5
local EMOTE_RULE_HEIGHT = autoTrackRowHeight(EMOTE_RULE_DEF) + EMOTE_RULE_LINE_GAP

-- user-editable list of autoTrack.emoteRules, each a match phrase plus the usual
-- rep/note/cooldown row
local function buildAutoTrackEmotesBox(parent, y, onToggle)
	local rules = ns.GetSettings().autoTrack.emoteRules

	local height = COLLAPSED_HEIGHT
	if autoTrackEmotesExpanded then
		height = height + #rules * EMOTE_RULE_HEIGHT + 28
	end

	local box, titleText = createSectionBox(parent, y, height, "Directed Emotes")
	createDisclosure(box, autoTrackEmotesExpanded, function()
		autoTrackEmotesExpanded = not autoTrackEmotesExpanded
		onToggle()
	end)
	setTooltip(titleText, "Logged when another player's emote in your chat contains a phrase you choose, e.g. \"salute\" or \"cheers at you\". Add one rule per emote you care about.")

	if not autoTrackEmotesExpanded then
		return y - height - 6
	end

	local rowY = -COLLAPSED_HEIGHT
	for i, rule in ipairs(rules) do
		local check, detailRow = buildAutoTrackRow(box, EMOTE_RULE_DEF, rule, rowY)
		detailRow:SetPoint("TOPLEFT", 44, rowY - 24 - EMOTE_RULE_LINE_GAP)

		local matchLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		matchLabel:SetPoint("LEFT", check, "RIGHT", 4, 0)
		matchLabel:SetText("Match")

		local matchBox = ns.CreateSmallEditBox(box, 120, 16)
		matchBox:SetJustifyH("LEFT")
		matchBox:SetPoint("LEFT", matchLabel, "RIGHT", 6, 0)
		bindTextBox(matchBox, rule, "match")
		setTooltip(matchBox, "Logs when another player's emote contains this text (not case-sensitive), e.g. \"wave\" or \"salutes you\". It matches the emote as your chat shows it, so use your game language's wording.")

		local youCheck = buildCheckbox(box, 0, 0, "Must say \"you\"", rule.requireYou,
			function(checked) rule.requireYou = checked end)
		youCheck:ClearAllPoints()
		youCheck:SetPoint("LEFT", matchBox, "RIGHT", 12, 0)
		setTooltip(youCheck, "Only counts emotes aimed at you (\"waves at you.\"), not ones aimed at nobody (\"waves.\"). Turn off if your game language doesn't use the word \"you\".")

		local deleteButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
		deleteButton:SetSize(22, 18)
		deleteButton:SetText("X")
		deleteButton:SetPoint("LEFT", detailRow.cooldownBox, "RIGHT", 12, 0)
		setTooltip(deleteButton, "Remove this rule.")
		deleteButton:SetScript("OnClick", function()
			table.remove(rules, i)
			onToggle()
		end)

		rowY = rowY - EMOTE_RULE_HEIGHT
	end

	local addButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	addButton:SetSize(100, 20)
	addButton:SetText("+ Add Emote")
	addButton:SetPoint("TOPLEFT", 8, rowY - 2)
	addButton:SetScript("OnClick", function()
		table.insert(rules, { match = "", requireYou = true, enabled = true, repGain = 1, note = "", cooldownMinutes = 5 })
		onToggle()
	end)
	if #rules >= ns.MAX_EMOTE_RULES then
		addButton:Disable()
		setTooltip(addButton, "Up to " .. ns.MAX_EMOTE_RULES .. " emote rules.")
	end

	return y - height - 6
end

-- session-only: collapsed on every fresh Options open, same as autoTrackEmotesExpanded
local dungeonTrackingExpanded = false
local DUNGEON_AUTOLOG_HEIGHT = 26 + 44 + 6

-- dungeon/raid auto-logging. the post-run survey is manual and lives on its own tab
-- (buildSurveyPanel)
local function buildDungeonTrackingBox(parent, y, onToggle)
	local autoLog = ns.GetSettings().dungeonTracking.autoLog

	local height = COLLAPSED_HEIGHT + (dungeonTrackingExpanded and DUNGEON_AUTOLOG_HEIGHT or 0)
	local box = createSectionBox(parent, y, height, "Dungeon/Raid Tracking")
	-- re-applies this box's own enabled/grayed state, called by the panel's layout
	local refreshEnabled = function() setContainerEnabled(box, true) end

	createDisclosure(box, dungeonTrackingExpanded, function()
		dungeonTrackingExpanded = not dungeonTrackingExpanded
		onToggle()
	end)

	if not dungeonTrackingExpanded then
		return y - height - 6, refreshEnabled
	end

	local rowY = -COLLAPSED_HEIGHT

	local autoLogDetail
	local autoLogCheck = buildCheckbox(box, 8, rowY, "Auto-log dungeon/raid runs", autoLog.enabled,
		function(checked)
			autoLog.enabled = checked
			setContainerEnabled(autoLogDetail, checked)
		end)
	setTooltip(autoLogCheck,
		"Logs an entry for each party/raid member when you enter the instance together, or (with the checkbox below) when you leave it instead.")

	autoLogDetail = CreateFrame("Frame", nil, box)
	autoLogDetail:SetPoint("TOPLEFT", 44, rowY - 24)
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
	local noteBox = ns.CreateSmallEditBox(autoLogDetail, 240, 16)
	noteBox:SetJustifyH("LEFT")
	noteBox:SetPoint("LEFT", noteLabel, "RIGHT", 6, 0)
	bindTextBox(noteBox, autoLog, "note")

	buildCheckbox(autoLogDetail, 0, -22, "Only log on completion (otherwise logs on entering)",
		autoLog.onlyOnCompletion,
		function(checked) autoLog.onlyOnCompletion = checked end)

	setContainerEnabled(autoLogDetail, autoLog.enabled)
	refreshEnabled = function()
		setContainerEnabled(box, true)
		setContainerEnabled(autoLogDetail, autoLog.enabled)
	end

	return y - height - 6, refreshEnabled
end

local function buildSurveySettingsBox(parent, y)
	local survey = ns.GetSettings().dungeonTracking.survey
	local height = 24 + 26 + 44 + 4
	local box = createSectionBox(parent, y, height, "Dungeon/Raid Survey")

	local surveyDetail
	local surveyCheck = buildCheckbox(box, 8, -22, "Show a survey popup on completion", survey.enabled,
		function(checked)
			survey.enabled = checked
			setContainerEnabled(surveyDetail, checked)
		end)
	setTooltip(surveyCheck,
		"Pops a window listing your party/raid when you leave the instance, with a note box, preset dropdown, and standing +/- per member.")

	surveyDetail = CreateFrame("Frame", nil, box)
	surveyDetail:SetPoint("TOPLEFT", 8, -22 - 26)
	surveyDetail:SetSize(1, 1)

	local prefixLabel = surveyDetail:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	prefixLabel:SetPoint("TOPLEFT", 0, 0)
	prefixLabel:SetText("Note prefix")
	local prefixBox = ns.CreateSmallEditBox(surveyDetail, 220, 16)
	prefixBox:SetJustifyH("LEFT")
	prefixBox:SetPoint("LEFT", prefixLabel, "RIGHT", 6, 0)
	bindTextBox(prefixBox, survey, "notePrefix")
	setTooltip(prefixBox,
		"Prepended to whatever you type in each survey row's note box. Supports {{loc}}/{{yourlvl}}/{{theirlvl}} like any other note template.")

	local skipConfirmCheck = buildCheckbox(surveyDetail, 0, -22,
		"Skip the \"fill out survey?\" prompt (go straight to the survey)",
		survey.skipConfirmation,
		function(checked) survey.skipConfirmation = checked end)
	setTooltip(skipConfirmCheck,
		"Same as checking \"Don't ask me again\" and choosing Open Survey on that prompt. The prompt's own checkbox sets this too.")

	setContainerEnabled(surveyDetail, survey.enabled)
	return y - height - 6
end

local ROLE_PRESET_ROW_HEIGHT = 22

local function buildRolePresetsBox(parent, y, onChange)
	local rolePresets = ns.GetSettings().dungeonTracking.rolePresets
	local height = 24 + 14 + #rolePresets * ROLE_PRESET_ROW_HEIGHT + 24 + 8
	local box, titleText = createSectionBox(parent, y, height, "Survey Presets")
	setTooltip(titleText,
		"Shown in a dropdown next to each survey row's note box; picking one fills that row's note and rep delta (both still editable after).")

	local rowY = -22
	local labelHeader = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	labelHeader:SetPoint("TOPLEFT", 8, rowY)
	labelHeader:SetText("Label")

	local noteHeader = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	noteHeader:SetPoint("LEFT", labelHeader, "LEFT", 120, 0)
	noteHeader:SetText("Note text")

	local repHeader = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	repHeader:SetPoint("LEFT", noteHeader, "LEFT", 248, 0)
	repHeader:SetText("Rep")

	rowY = rowY - 14

	-- same widths as the Quick-Add Presets tab's own editor (buildPresetsPanel), so the
	-- two preset-list editors read as the same kind of control
	for i, preset in ipairs(rolePresets) do
		local labelBox = ns.CreateSmallEditBox(box, 112, 16)
		labelBox:SetPoint("TOPLEFT", 8, rowY)
		bindTextBox(labelBox, preset, "label")

		local textBox = ns.CreateSmallEditBox(box, 240, 16)
		textBox:SetJustifyH("LEFT")
		textBox:SetPoint("LEFT", labelBox, "RIGHT", 8, 0)
		bindTextBox(textBox, preset, "text")

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
			table.remove(rolePresets, i)
			onChange()
		end)

		rowY = rowY - ROLE_PRESET_ROW_HEIGHT
	end

	local addPresetButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	addPresetButton:SetSize(100, 20)
	addPresetButton:SetText("+ Add Preset")
	addPresetButton:SetPoint("TOPLEFT", 8, rowY - 2)
	addPresetButton:SetScript("OnClick", function()
		table.insert(rolePresets, { label = "New Role", text = "", delta = 0 })
		onChange()
	end)

	return y - height - 6
end

-- manual, so not under Auto-Track and not affected by its module switch
local function buildSurveyPanel(parent)
	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	ns.SetGentleScroll(scroll)
	scroll:SetPoint("TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", -34, 0)

	local scrollChild = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(scrollChild)
	scroll:SetScript("OnSizeChanged", function(_, width)
		scrollChild:SetWidth(width)
	end)
	scrollChild:SetWidth(parent:GetWidth())

	-- rebuilt from scratch when a role preset is added/removed, since that changes the
	-- presets box's height
	local function layout()
		for _, child in ipairs({ scrollChild:GetChildren() }) do
			child:Hide()
			child:SetParent(nil)
		end
		local y = -8
		y = buildSurveySettingsBox(scrollChild, y)
		y = buildRolePresetsBox(scrollChild, y, layout)
		scrollChild:SetHeight(-y + 10)
	end

	layout()
	-- the survey prompt itself can change these settings, so re-read them on every visit
	parent:HookScript("OnShow", layout)
end

local recentAlliesExpanded = false

local RECENT_ALLY_TYPE_OPTIONS = {}
for _, def in ipairs(ns.RECENT_ALLY_TYPE_DEFS) do
	RECENT_ALLY_TYPE_OPTIONS[#RECENT_ALLY_TYPE_OPTIONS + 1] = { value = def.key, text = def.label }
end

local function recentAllyTypeSummary()
	local types = ns.GetSettings().recentAllies.types
	local selected = {}
	for _, option in ipairs(RECENT_ALLY_TYPE_OPTIONS) do
		if types[option.value] then
			selected[#selected + 1] = option.text
		end
	end
	if #selected == 0 then
		return "None"
	elseif #selected == #RECENT_ALLY_TYPE_OPTIONS then
		return "All"
	elseif #selected <= 2 then
		return table.concat(selected, ", ")
	end
	return #selected .. " types"
end

local function buildRecentAlliesBox(parent, y, onToggle)
	local settings = ns.GetSettings().recentAllies
	local supported = ns.IsRecentAlliesSupported()
	local WARNING_HEIGHT = supported and 0 or 30
	local DETAIL_HEIGHT = 51

	local height = COLLAPSED_HEIGHT
	if recentAlliesExpanded then
		height = height + WARNING_HEIGHT + 26 + DETAIL_HEIGHT + 10
	end

	local box = createSectionBox(parent, y, height, "Recent Allies")
	local refreshEnabled = function() setContainerEnabled(box, true) end

	createDisclosure(box, recentAlliesExpanded, function()
		recentAlliesExpanded = not recentAlliesExpanded
		onToggle()
	end)

	if not recentAlliesExpanded then
		return y - height - 6, refreshEnabled
	end

	local rowY = -COLLAPSED_HEIGHT

	if not supported then
		local warning = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		warning:SetPoint("TOPLEFT", 8, rowY)
		warning:SetPoint("RIGHT", -10, 0)
		warning:SetJustifyH("LEFT")
		warning:SetWordWrap(true)
		warning:SetTextColor(1, 0.25, 0.25)
		warning:SetText("Blizzard's Recent Allies system isn't available on this client, so this can't log anything.")
		rowY = rowY - WARNING_HEIGHT
	end

	local detail
	local enableCheck = buildCheckbox(box, 8, rowY, "Log interactions from Blizzard's Recent Allies list", settings.enabled,
		function(checked)
			settings.enabled = checked
			if checked then
				ns.ResetRecentAlliesWatermark()
			end
			setContainerEnabled(detail, checked)
		end)
	setTooltip(enableCheck,
		"The game keeps its own history of players you've done things with (dungeons, boss kills, trades, etc). This logs an entry whenever a new one of the selected kinds shows up there. Only interactions from after you turn this on are logged.\n\nThe game only refreshes that list when you open its Recent Allies tab (Social window), or on login, so entries appear then, dated to when the interaction actually happened.")

	detail = CreateFrame("Frame", nil, box)
	detail:SetPoint("TOPLEFT", 8, rowY - 29)
	detail:SetSize(1, 1)

	local gainLabel = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	gainLabel:SetPoint("TOPLEFT", 0, 0)
	gainLabel:SetText("Rep gain")
	local gainBox = ns.CreateSmallEditBox(detail, 34, 14)
	gainBox:SetPoint("LEFT", gainLabel, "RIGHT", 6, 0)
	gainBox:SetText(tostring(settings.repGain))
	local function applyGain()
		local value = math.max(-ns.STANDING_MAX, math.min(ns.STANDING_MAX, tonumber(gainBox:GetText()) or 0))
		settings.repGain = value
		gainBox:SetText(tostring(value))
		gainBox:ClearFocus()
	end
	gainBox:SetScript("OnEnterPressed", applyGain)
	gainBox:SetScript("OnEditFocusLost", applyGain)
	gainBox:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(settings.repGain))
		self:ClearFocus()
	end)

	local noteLabel = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	noteLabel:SetPoint("LEFT", gainBox, "RIGHT", 16, 0)
	noteLabel:SetText("Note")
	local noteBox = ns.CreateSmallEditBox(detail, 220, 16)
	noteBox:SetJustifyH("LEFT")
	noteBox:SetPoint("LEFT", noteLabel, "RIGHT", 6, 0)
	noteBox:SetText(settings.note or "")
	local function applyNote()
		settings.note = noteBox:GetText()
		noteBox:ClearFocus()
	end
	noteBox:SetScript("OnEnterPressed", applyNote)
	noteBox:SetScript("OnEditFocusLost", applyNote)
	noteBox:SetScript("OnEscapePressed", function(self)
		self:SetText(settings.note or "")
		self:ClearFocus()
	end)
	setTooltip(noteBox,
		"{{interaction}} becomes the game's own description of what happened (e.g. \"Fought Together\"). {{loc}} is where it happened. {{yourlvl}}/{{theirlvl}} work too.")

	local typesLabel = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	typesLabel:SetPoint("TOPLEFT", 0, -26)
	typesLabel:SetText("Log for")
	local typesDropdown = ns.CreateMultiSelectDropdown(detail, RECENT_ALLY_TYPE_OPTIONS,
		function(value) return settings.types[value] end,
		function(value) settings.types[value] = not settings.types[value] end,
		recentAllyTypeSummary, 200)
	typesDropdown:SetPoint("LEFT", typesLabel, "RIGHT", 8, 0)

	local cooldownLabel = detail:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	cooldownLabel:SetPoint("LEFT", typesDropdown, "RIGHT", 16, 0)
	cooldownLabel:SetText("Cooldown")
	local cooldownBox = ns.CreateSmallEditBox(detail, 30, 14, true)
	cooldownBox:SetPoint("LEFT", cooldownLabel, "RIGHT", 6, 0)
	cooldownBox:SetText(tostring(settings.cooldownMinutes))
	setTooltip(cooldownBox, "Minutes before the same kind of interaction can log again for the same player.")
	local function applyCooldown()
		local value = math.max(0, tonumber(cooldownBox:GetText()) or settings.cooldownMinutes)
		settings.cooldownMinutes = value
		cooldownBox:SetText(tostring(value))
		cooldownBox:ClearFocus()
	end
	cooldownBox:SetScript("OnEnterPressed", applyCooldown)
	cooldownBox:SetScript("OnEditFocusLost", applyCooldown)
	cooldownBox:SetScript("OnEscapePressed", function(self)
		self:SetText(tostring(settings.cooldownMinutes))
		self:ClearFocus()
	end)

	refreshEnabled = function()
		setContainerEnabled(box, true)
		setContainerEnabled(enableCheck, supported)
		setContainerEnabled(enableCheck.label, supported)
		setContainerEnabled(detail, supported and settings.enabled)
	end

	return y - height - 6, refreshEnabled
end

local function buildNearbyAutoAddBox(parent, y)
	local height = 122
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

	local mouseoverCheck = buildCheckbox(box, 8, -92, "Require a mouseover",
		autoAdd.requireMouseover,
		function(checked) autoAdd.requireMouseover = checked end)
	setTooltip(mouseoverCheck, "Only auto-add players you mouse over (in the world, their nameplate, or a unit frame), instead of every nameplated player.")

	local function setRestCheckEnabled(enabled)
		setContainerEnabled(restCheck, enabled)
		setContainerEnabled(restCheck.label, enabled)
		setContainerEnabled(mouseoverCheck, enabled)
		setContainerEnabled(mouseoverCheck.label, enabled)
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

-- session-only, every box starts collapsed (same as the General tab's)
local autoTrackBoxesExpanded = {}

local function buildAutoTrackPanel(parent)
	local settings = ns.GetSettings().autoTrack

	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")

	ns.SetGentleScroll(scroll)
	scroll:SetPoint("TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", -34, 0)

	local scrollChild = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(scrollChild)
	scroll:SetScript("OnSizeChanged", function(self, width)
		scrollChild:SetWidth(width)
	end)
	scrollChild:SetWidth(parent:GetWidth())

	-- scrolls with the boxes below it, but survives layout()'s rebuilds and is never
	-- grayed by the master switch it holds
	local HEADER_HEIGHT = 56
	local header = CreateFrame("Frame", nil, scrollChild)
	header:SetPoint("TOPLEFT", 0, 0)
	header:SetSize(1, HEADER_HEIGHT)

	local layout

	local enableCheck = buildCheckbox(header, 16, -8, "Enable auto-add module",
		settings.enabled,
		function(checked)
			settings.enabled = checked
			layout()
		end)
	setTooltip(enableCheck, "Completely enable/disable all automatic entries.")

	-- covers every note field on this panel, so it sits up here rather than in one box
	local helpButton = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
	helpButton:SetSize(20, 20)
	helpButton:SetText("?")
	helpButton:SetPoint("TOPLEFT", enableCheck, "BOTTOMLEFT", 2, -4)
	helpButton:SetScript("OnClick", showPresetHelpPopup)
	ns.AttachHookTooltip(helpButton, presetHelpPlainText())

	local helpLabel = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	helpLabel:SetPoint("LEFT", helpButton, "RIGHT", 6, 0)
	helpLabel:SetText("Notes")

	-- rebuilds every box from scratch, since expanding/collapsing a box changes its
	-- height and everything below it has to shift to match
	function layout()
		for _, child in ipairs({ scrollChild:GetChildren() }) do
			if child ~= header then
				child:Hide()
				child:SetParent(nil)
			end
		end
		local y = -HEADER_HEIGHT
		y = buildAutoTrackGeneralBox(scrollChild, y, layout)
		y = buildAutoTrackEmotesBox(scrollChild, y, layout)
		local dungeonTrackingRefresh
		y, dungeonTrackingRefresh = buildDungeonTrackingBox(scrollChild, y, layout)
		local recentAlliesRefresh
		y, recentAlliesRefresh = buildRecentAlliesBox(scrollChild, y, layout)
		y = wrapCollapsible(autoTrackBoxesExpanded, "nearby", buildNearbyAutoAddBox, scrollChild, y, layout)
		y = wrapCollapsible(autoTrackBoxesExpanded, "seenCount", buildSeenCountBox, scrollChild, y, layout)
		scrollChild:SetHeight(-y + 10)
		-- each row/box already grayed its own unchecked parts while building, so only
		-- the off state needs a blanket pass; a blanket enable would un-gray them
		if settings.enabled then
			dungeonTrackingRefresh()
			recentAlliesRefresh()
		else
			for _, child in ipairs({ scrollChild:GetChildren() }) do
				if child ~= header then
					setContainerEnabled(child, false)
				end
			end
		end
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
	local height = 105
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
	local height = 59
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
	ns.SetGentleScroll(scroll)
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

	ns.SetGentleScroll(scroll)
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

	-- only hides the popup's buttons; the presets stay editable since the radial menu
	-- uses them either way
	buildCheckbox(box, 8, -24, "Show one-click preset buttons in the quick-add popup",
		settings.enabled,
		function(checked) settings.enabled = checked end)
end

-- single-radial mode (second radial off) offers the whole preset list for ring 1 (and
-- GetRadialPresetSet's own default/cap matches: whole list uncapped). dual-radial
-- Positive/Negative mode splits the options themselves by delta sign too, not just the
-- default selection, so a positive-only preset can't even be picked for the negative
-- ring or vice versa. Everything mode offers the whole list to both.
local function radialPresetOptions(ring)
	local options = {}
	local signSplit = ns.IsRadialSignSplit()
	for _, preset in ipairs(ns.GetSettings().quickPresets.items) do
		local include = true
		if signSplit then
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
	local key = ns.RadialLabelsKey(ring)
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
	local height = 368
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

	local nameColorLabel = body:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	nameColorLabel:SetPoint("LEFT", holdBox, "RIGHT", 30, 0)
	nameColorLabel:SetText("Character name color")
	local nameColorDropdown = ns.CreateDropdown(body, {
		{ value = "bracket", text = "Bracket color" },
		{ value = "class", text = "Class color" },
	},
		function(value) return (settings.nameColor or "class") == value end,
		function(value) settings.nameColor = value end,
		130, 20)
	nameColorDropdown:SetPoint("LEFT", nameColorLabel, "RIGHT", 6, 0)
	ns.AttachHookTooltip(nameColorDropdown, "Color of the target's name shown above the radial: their standing's bracket color, or their class color.")

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

	local ring2Label
	local ring1Dropdown, ring2Dropdown

	local function updateRingLabels()
		local signed = settings.splitMode ~= "all"
		if not settings.secondEnabled then
			ring1Label:SetText("Radial presets")
		else
			ring1Label:SetText(signed and "Radial 1 (positive) presets" or "Radial 1 presets")
		end
		if ring2Label then
			ring2Label:SetText(signed and "Radial 2 (negative) presets" or "Radial 2 presets")
		end
	end

	local function onRadialModeChanged()
		refillRadialOptions(ring1Options, 1)
		refillRadialOptions(ring2Options, 2)
		updateRingLabels()
		for _, dropdown in ipairs({ ring1Dropdown, ring2Dropdown }) do
			if dropdown.RefreshText then
				dropdown.RefreshText()
			end
		end
		if ns.RefreshRadialMenuBinding then
			ns.RefreshRadialMenuBinding()
		end
	end

	local secondCheck = buildCheckbox(body, 8, -96, "Enable a second radial",
		settings.secondEnabled,
		function(checked)
			settings.secondEnabled = checked
			setContainerEnabled(secondBody, checked)
			onRadialModeChanged()
		end)

	ring1Options = radialPresetOptions(1)
	ring1Dropdown = ns.CreateMultiSelectDropdown(body, ring1Options,
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

	-- on the checkbox's own line, but part of secondBody so it grays out with it
	local splitLabel = secondBody:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	splitLabel:SetPoint("LEFT", secondCheck.label, "RIGHT", 20, 0)
	splitLabel:SetText("Multiple radial behavior:")

	local splitDropdown = ns.CreateDropdown(secondBody, {
		{ value = "signed", text = "Positive/Negative" },
		{ value = "all", text = "Everything" },
	},
		function(value) return (settings.splitMode or "signed") == value end,
		function(value)
			settings.splitMode = value
			onRadialModeChanged()
		end,
		150, 20)
	splitDropdown:SetPoint("LEFT", splitLabel, "RIGHT", 6, 0)
	ns.AttachHookTooltip(splitDropdown,
		"Positive/Negative: radial 1 only offers presets that add rep, radial 2 only ones that take it away.\n\nEverything: either radial can hold any preset.\n\nEach choice remembers its own preset selections, so switching back and forth doesn't lose either.")

	local modLabel = secondBody:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	modLabel:SetPoint("TOPLEFT", 8, 0)
	modLabel:SetText("Modifier for the second radial")

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

	ring2Label = secondBody:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	ring2Label:SetPoint("TOPLEFT", modDropdown, "BOTTOMLEFT", 0, -14)
	updateRingLabels()

	ring2Options = radialPresetOptions(2)
	ring2Dropdown = ns.CreateMultiSelectDropdown(secondBody, ring2Options,
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

local IGNORE_RULE_TIPS = {
	guild = "Everyone in your current guild, online or offline.",
	friends = "Everyone you added with Add WoW Friend. Only applies while they're online.",
	bnet = "Whatever character your BattleTag friends are playing in this version of WoW, so all their alts are covered. Only applies while they're online.",
}

local IGNORE_LABEL_WIDTH = 170
local IGNORE_COL_WIDTH = 110
local IGNORE_ROW_HEIGHT = 22

local function buildIgnoreRulesBox(parent, y)
	local rules = ns.GetSettings().ignore
	local gridTop = -24
	local rowsTop = gridTop - 18
	local helpTop = rowsTop - #ns.IGNORE_RULES * IGNORE_ROW_HEIGHT - 6
	local height = -helpTop + 34
	local box = createSectionBox(parent, y, height, "Ignore by Relationship")

	local function columnCenter(i)
		return IGNORE_LABEL_WIDTH + (i - 0.5) * IGNORE_COL_WIDTH
	end

	for i, flag in ipairs(ns.IGNORE_FLAGS) do
		local label = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		label:SetPoint("TOP", box, "TOPLEFT", columnCenter(i), gridTop)
		label:SetText(flag.label)
		setTooltip(label, flag.tip)
	end

	for r, rule in ipairs(ns.IGNORE_RULES) do
		local rowMid = rowsTop - (r - 0.5) * IGNORE_ROW_HEIGHT
		local label = box:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		label:SetPoint("LEFT", box, "TOPLEFT", 14, rowMid)
		label:SetText(rule.label)
		setTooltip(label, IGNORE_RULE_TIPS[rule.key])
		for i, flag in ipairs(ns.IGNORE_FLAGS) do
			local check = ns.CreateSmallCheckbox(box, 22, rules[rule.key][flag.key], function(checked)
				ns.SetIgnoreRuleFlag(rule.key, flag.key, checked)
			end)
			check:SetPoint("CENTER", box, "TOPLEFT", columnCenter(i), rowMid)
		end
	end

	local help = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	help:SetPoint("TOPLEFT", 14, helpTop)
	help:SetPoint("RIGHT", -14, 0)
	help:SetJustifyH("LEFT")
	help:SetWordWrap(true)
	help:SetText("Players on the list below override these rules. To keep tracking someone a rule would catch, add them below and uncheck all their boxes.")

	return y - height - 6
end

local function buildIgnoreListBox(parent, y)
	local box = createSectionBox(parent, y, 100, "Ignored Players")
	box:SetPoint("BOTTOM", parent, "BOTTOM", 0, 8)

	local addTarget = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	addTarget:SetSize(90, 20)
	addTarget:SetPoint("TOPLEFT", 8, -22)
	addTarget:SetText("Add Target")
	addTarget:SetScript("OnClick", function()
		local identity = UnitIsPlayer("target") and not UnitIsUnit("target", "player") and ns.IdentifyUnit("target")
		if not identity then
			ns.Print("Target a player first.")
			return
		end
		if ns.IsOnIgnoreList(identity.key) then
			ns.Print(ns.DisplayName(identity, identity.key) .. " is already on your ignore list.")
			return
		end
		ns.AddToIgnoreList(identity.key, identity)
	end)

	local nameLabel = box:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	nameLabel:SetPoint("LEFT", addTarget, "RIGHT", 14, 0)
	nameLabel:SetText("Add by name")

	local nameBox = ns.CreateSmallEditBox(box, 180, 18)
	nameBox:SetJustifyH("LEFT")
	nameBox:SetPoint("LEFT", nameLabel, "RIGHT", 6, 0)
	setTooltip(nameBox, "Their full name, like Name Surname. Shortcut: just the first name works if only one saved player has it.")

	local addButton = CreateFrame("Button", nil, box, "UIPanelButtonTemplate")
	addButton:SetSize(50, 20)
	addButton:SetPoint("LEFT", nameBox, "RIGHT", 6, 0)
	addButton:SetText("Add")

	local function addByName()
		local key, identityOrError = ns.ResolveIgnoreName(nameBox:GetText())
		if not key then
			if identityOrError then
				ns.Print(identityOrError)
			end
			return
		end
		if ns.IsOnIgnoreList(key) then
			ns.Print("Already on your ignore list.")
		else
			ns.AddToIgnoreList(key, identityOrError)
		end
		nameBox:SetText("")
		nameBox:ClearFocus()
	end
	addButton:SetScript("OnClick", addByName)
	nameBox:SetScript("OnEnterPressed", addByName)
	nameBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)

	local countLabel = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	countLabel:SetPoint("TOPRIGHT", -12, -26)

	local refresh
	local search = ""
	local searchBox = CreateFrame("EditBox", nil, box, "SearchBoxTemplate")
	searchBox:SetSize(160, 20)
	searchBox:SetPoint("RIGHT", countLabel, "LEFT", -12, 0)
	searchBox:HookScript("OnTextChanged", function(self)
		search = self:GetText():lower()
		if refresh then
			refresh()
		end
	end)

	-- comma-separated terms match any, same as the Players tab
	local function matchesSearch(name)
		if search == "" then
			return true
		end
		name = name:lower()
		for rawTerm in search:gmatch("[^,]+") do
			local term = rawTerm:match("^%s*(.-)%s*$")
			if term ~= "" and name:find(term, 1, true) then
				return true
			end
		end
		return false
	end

	local columns = {
		{ key = "name", label = "Name", width = 0, min = 100, flex = true },
	}
	for _, flag in ipairs(ns.IGNORE_FLAGS) do
		columns[#columns + 1] = {
			key = flag.key, label = flag.label, width = 100, min = 80, cellType = "checkbox",
			onCheckboxClick = function(item, checked) ns.SetIgnoreFlag(item.key, flag.key, checked) end,
		}
	end
	columns[#columns + 1] = { key = "added", label = "Added", width = 100, min = 70 }
	columns[#columns + 1] = { key = "remove", label = "", width = 70, min = 60, noSort = true,
		onCellClick = function(item) ns.RemoveFromIgnoreList(item.key) end }

	local ignoreTable = ns.CreateSortableTable(box, {
		tableId = "ignore",
		columns = columns,
		rowHeight = 22,
		getItems = function()
			local items = {}
			for key, row in pairs(ns.GetIgnoreList()) do
				local record = ns.GetPlayerRecord(key, false)
				if matchesSearch(ns.DisplayName(record or row, key)) then
					items[#items + 1] = { key = key, row = row, record = record }
				end
			end
			return items
		end,
		sortValue = function(item, col)
			if col == "name" then
				return ns.DisplayName(item.record or item.row, item.key):lower()
			elseif col == "added" then
				return item.row.addedAt or 0
			elseif col == "remove" then
				return 0
			end
			return item.row[col] and 1 or 0
		end,
		render = function(row, item)
			local source = item.record or item.row
			row.cells.name:SetText(ns.DisplayName(source, item.key))
			row.cells.name:SetTextColor(ns.ClassColor(source.classFile))
			for _, flag in ipairs(ns.IGNORE_FLAGS) do
				row.cells[flag.key].checkbox:SetChecked(item.row[flag.key] == true)
			end
			row.cells.added:SetText(item.row.addedAt and ns.FormatDate(item.row.addedAt) or "-")
			row.cells.remove:SetText("Remove")
			row.cells.remove:SetTextColor(1, 0.45, 0.45)
		end,
		onRightClick = function(item, rowFrame)
			MenuUtil.CreateContextMenu(rowFrame, function(_, rootDescription)
				rootDescription:CreateTitle(ns.DisplayName(item.record or item.row, item.key))
				if item.record then
					rootDescription:CreateButton("View Details", function() ns.ShowPlayerDetails(item.key) end)
				end
				rootDescription:CreateButton("Remove from Ignore List", function() ns.RemoveFromIgnoreList(item.key) end)
			end)
		end,
		defaultSort = { key = "added", dir = "desc" },
		pageSize = "auto",
	})
	ignoreTable.container:SetPoint("TOPLEFT", 8, -50)
	ignoreTable.container:SetPoint("BOTTOMRIGHT", -8, 6)

	local emptyText = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	emptyText:SetPoint("TOP", ignoreTable.container, "TOP", 0, -40)

	refresh = function()
		ignoreTable.Refresh()
		local shown = ignoreTable.GetItemCount()
		local total = 0
		for _ in pairs(ns.GetIgnoreList()) do
			total = total + 1
		end
		if search ~= "" then
			countLabel:SetText(shown .. " of " .. total)
		else
			countLabel:SetText(total == 1 and "1 player" or (total .. " players"))
		end
		emptyText:SetText(total == 0 and "No one yet. Right-click a player and pick Ignore Player, or add someone above."
			or "No matches.")
		emptyText:SetShown(shown == 0)
	end
	ns.RefreshIgnorePanel = function()
		if box:IsVisible() then
			refresh()
		end
	end
	parent:HookScript("OnShow", refresh)
	refresh()
end

local function buildIgnorePanel(parent)
	local y = buildIgnoreRulesBox(parent, -8)
	buildIgnoreListBox(parent, y)
end

local HEART_TEXTURE = "Interface\\AddOns\\WorthRemembering\\Media\\Heart.png"

local creditPopup

local function showCreditPopup(credits)
	if not creditPopup then
		local popup = createHelpPopupFrame("WRCreditPopup", 340, 140, "Community Credit")
		popup.body = popup:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		popup.body:SetPoint("TOPLEFT", 20, -46)
		popup.body:SetPoint("RIGHT", -20, 0)
		popup.body:SetJustifyH("LEFT")
		popup.body:SetWordWrap(true)
		popup.footer = popup:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		popup.footer:SetPoint("TOPLEFT", popup.body, "BOTTOMLEFT", 0, -14)
		popup.footer:SetText("Thanks for helping make Worth Remembering better!")
		creditPopup = popup
	end
	local lines = {}
	for _, credit in ipairs(credits) do
		lines[#lines + 1] = ns.CreditTextTwoLine(credit)
	end
	creditPopup.body:SetText(table.concat(lines, "\n\n"))
	creditPopup:SetHeight(46 + creditPopup.body:GetStringHeight() + 14 + creditPopup.footer:GetStringHeight() + 26)
	creditPopup:Show()
end

-- one heart per sub-tab page, top right. hover for the credit, click for the popup.
-- inset defaults past a scrollbar, non-scrolling pages pass their own
local function attachCreditHeart(content, page, inset)
	local credits = page and ns.GetCreditsForPage(page) or {}
	if #credits == 0 then
		return
	end
	local heart = CreateFrame("Button", nil, content)
	heart:SetSize(14, 14)
	heart:SetPoint("TOPRIGHT", -(inset or 48), -12)
	heart:SetFrameLevel(content:GetFrameLevel() + 20)
	heart:SetNormalTexture(HEART_TEXTURE)
	heart:SetHighlightTexture(HEART_TEXTURE, "ADD")
	local lines = {}
	for _, credit in ipairs(credits) do
		lines[#lines + 1] = ns.CreditTextTwoLine(credit)
	end
	setTooltip(heart, table.concat(lines, "\n\n"))
	heart:SetScript("OnClick", function() showCreditPopup(credits) end)
end

-- Each sub-tab panel is built lazily on first visit, same pattern as the main window's
-- own tabs.
local SUB_TABS = {
	{ label = "General", build = buildGeneralPanel },
	{ label = "Reputation", build = buildRepBracketControl },
	{ label = "Auto-Track", build = buildAutoTrackPanel },
	{ label = "Survey", build = buildSurveyPanel },
	{ label = "Alerts", build = buildNearbySoundControl },
	{ label = "Presets", build = buildPresetsPanel },
	{ label = "Radial Menu", build = buildRadialMenuPanel },
	{ label = "Ignore", build = buildIgnorePanel, page = "ignore", heartInset = 22 },
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
		attachCreditHeart(content, def.page, def.heartInset)
		contents[i] = content
	end

	selectSubTab(1)
end
