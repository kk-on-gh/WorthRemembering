local ns = WorthRemembering

-- a single dropdown "selection" control: modern DropdownButton/SetupMenu when
-- available, falling back to a plain cycle-button on clients without
-- WowStyle1DropdownTemplate. an unknown template name makes CreateFrame throw
-- immediately, so this is pcall'd rather than feature-detected up front.
--
-- options = {{value=.., text=..}, ...}; isSelected(value) / onChange(value, text).
function ns.CreateDropdown(parent, options, isSelected, onChange, width, height)
	local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")

	if ok and dropdown and dropdown.SetupMenu then
		dropdown:SetupMenu(function(_, rootDescription)
			for _, option in ipairs(options) do
				rootDescription:CreateRadio(option.text, function() return isSelected(option.value) end, function()
					dropdown:SetText(option.text)
					onChange(option.value, option.text)
				end)
			end
		end)
	else
		dropdown = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		dropdown:SetScript("OnClick", function(self)
			local currentIndex = 1
			for i, option in ipairs(options) do
				if isSelected(option.value) then
					currentIndex = i
					break
				end
			end
			local option = options[(currentIndex % #options) + 1]
			self:SetText(option.text)
			onChange(option.value, option.text)
		end)
	end

	function dropdown:Refresh()
		for _, option in ipairs(options) do
			if isSelected(option.value) then
				self:SetText(option.text)
				return
			end
		end
	end
	dropdown:Refresh()

	dropdown:SetSize(width or 150, height or 22)

	return dropdown
end

-- Compact widgets drawn from scratch (flat-color backdrop, no Blizzard template) for
-- Options panels that want exact, small pixel sizes instead of whatever a stock template's
-- baked-in art allows.
local SMALL_BACKDROP = {
	bgFile = "Interface/Buttons/WHITE8X8",
	edgeFile = "Interface/Buttons/WHITE8X8",
	edgeSize = 1,
}

local function applySmallBackdrop(frame)
	frame:SetBackdrop(SMALL_BACKDROP)
	frame:SetBackdropColor(0.08, 0.06, 0.03, 0.9)
	frame:SetBackdropBorderColor(1, 0.82, 0, 0.5)
end

local smallTooltip
local SMALL_TOOLTIP_MAX_WIDTH = 260

local function getSmallTooltip()
	if not smallTooltip then
		smallTooltip = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
		smallTooltip:SetFrameStrata("TOOLTIP")
		smallTooltip:SetBackdrop(SMALL_BACKDROP)
		smallTooltip:SetBackdropColor(0.04, 0.03, 0.02, 0.98)
		smallTooltip:SetBackdropBorderColor(1, 0.82, 0, 0.6)
		smallTooltip.text = smallTooltip:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		smallTooltip.text:SetPoint("TOPLEFT", 6, -5)
		smallTooltip.text:SetJustifyH("LEFT")
		smallTooltip.text:SetJustifyV("TOP")
	end
	return smallTooltip
end

-- Own small bordered popup instead of the shared global GameTooltip, so its opacity and
-- width aren't shared/constrained by whatever else in the UI uses GameTooltip.
function ns.AttachTooltip(frame, text)
	frame:SetScript("OnEnter", function(self)
		local tip = getSmallTooltip()
		tip.text:SetText(text)
		local rawWidth = tip.text:GetStringWidth()
		local width = math.min(SMALL_TOOLTIP_MAX_WIDTH, rawWidth)
		tip.text:SetWidth(width)
		tip:SetWidth(width + 12)
		tip:SetHeight(tip.text:GetStringHeight() + 10)
		tip:ClearAllPoints()
		tip:SetPoint("BOTTOM", self, "TOP", 0, 4)
		tip:Show()
	end)
	frame:SetScript("OnLeave", function()
		if smallTooltip then
			smallTooltip:Hide()
		end
	end)
end

-- Same small popup as ns.AttachTooltip, but via HookScript instead of SetScript: for
-- widgets (like the dropdown template) that already have their own OnEnter/OnLeave
-- driving hover visuals, so attaching a tooltip doesn't clobber that behavior.
function ns.AttachHookTooltip(frame, text)
	frame:HookScript("OnEnter", function(self)
		local tip = getSmallTooltip()
		tip.text:SetText(text)
		local rawWidth = tip.text:GetStringWidth()
		local width = math.min(SMALL_TOOLTIP_MAX_WIDTH, rawWidth)
		tip.text:SetWidth(width)
		tip:SetWidth(width + 12)
		tip:SetHeight(tip.text:GetStringHeight() + 10)
		tip:ClearAllPoints()
		tip:SetPoint("BOTTOM", self, "TOP", 0, 4)
		tip:Show()
	end)
	frame:HookScript("OnLeave", function()
		if smallTooltip then
			smallTooltip:Hide()
		end
	end)
end

-- Blizzard's own checkbox art, same as UICheckButtonTemplate uses, just not inheriting
-- that template, which bakes in a fixed ~32px size we can't shrink.
function ns.CreateSmallCheckbox(parent, size, checked, onClick)
	size = size or 16
	local btn = CreateFrame("CheckButton", nil, parent)
	btn:SetSize(size, size)
	btn:SetNormalTexture("Interface\\Buttons\\UI-CheckBox-Up")
	btn:SetPushedTexture("Interface\\Buttons\\UI-CheckBox-Down")
	btn:SetHighlightTexture("Interface\\Buttons\\UI-CheckBox-Highlight")
	btn:SetCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check")
	btn:SetDisabledCheckedTexture("Interface\\Buttons\\UI-CheckBox-Check-Disabled")
	btn:SetChecked(checked)
	btn:SetScript("OnClick", function(self)
		onClick(self:GetChecked() and true or false)
	end)

	return btn
end

function ns.CreateSmallEditBox(parent, width, height, numeric)
	local box = CreateFrame("EditBox", nil, parent, "BackdropTemplate")
	box:SetSize(width, height or 16)
	applySmallBackdrop(box)
	box:SetAutoFocus(false)
	box:SetFontObject(GameFontHighlightSmall)
	box:SetJustifyH("CENTER")
	box:SetTextInsets(2, 2, 0, 0)
	if numeric then
		box:SetNumeric(true)
	end
	return box
end

-- width is the full slider track width; the returned frame is the slider itself (use
-- SetPoint relative to it for labels/value boxes).
function ns.CreateSmallSlider(parent, width, min, max, step, getValue, setValue)
	local slider = CreateFrame("Slider", nil, parent)
	slider:SetOrientation("HORIZONTAL")
	slider:SetSize(width, 12)
	slider:SetMinMaxValues(min, max)
	slider:SetValueStep(step)
	slider:SetObeyStepOnDrag(true)
	slider:EnableMouse(true)

	local track = slider:CreateTexture(nil, "BACKGROUND")
	track:SetPoint("LEFT", 0, 0)
	track:SetPoint("RIGHT", 0, 0)
	track:SetHeight(2)
	track:SetColorTexture(1, 0.82, 0, 0.35)

	local thumb = slider:CreateTexture(nil, "OVERLAY")
	thumb:SetSize(8, 12)
	thumb:SetColorTexture(1, 0.82, 0, 1)
	slider:SetThumbTexture(thumb)

	slider:SetValue(getValue())
	slider:SetScript("OnValueChanged", function(self, value)
		setValue(value)
	end)

	return slider
end

-- Multi-select variant of ns.CreateDropdown: checkboxes instead of radios, so any number
-- of options can be active at once and clicking one doesn't close the menu. Used for the
-- Players tab's bracket filter (several brackets at a time, e.g. "both extremes").
--
-- options = {{value=.., text=..}, ...}; isSelected(value) / toggle(value) / getSummaryText()
-- (called after every toggle to refresh the button's own label, e.g. "3 brackets" or a
-- joined list, since multi-select has no single option to show).
-- clearText/onClear are optional: when given, a button for them is added above a divider
-- at the top of the menu, for an obvious one-click "back to no filter", since unlike
-- single-select there's no option that's inherently "the unfiltered one".
-- WowStyle1DropdownTemplate's visible label normally tracks whichever CreateRadio item is
-- "selected" automatically; CreateCheckbox-only menus have no such item, so a plain
-- :SetText() call alone was landing blank. :SetDefaultText() is the actual API this
-- template uses for "the label when nothing else is driving it", setting both covers
-- whichever one this template build actually reads from.
local function setDropdownDisplayText(dropdown, text)
	dropdown:SetText(text)
	if dropdown.SetDefaultText then
		dropdown:SetDefaultText(text)
	end
end

-- shared state container for a ns.CreateMultiSelectDropdown filter. every Players/History
-- filter (sign, character, class, race, faction, last-seen, bracket, ...) is one of these,
-- rather than each hand-rolling its own toggle/clear/summary trio.
-- :Toggle(value) flips just that value. :Set(value) replaces the whole selection with just
-- that one value (used by click-to-filter table cells and the Statistics-tile jumps, which
-- replace rather than add to whatever filter was already active). :Clear() empties it.
-- :Matches(value) is true when unfiltered (nothing selected) or value is selected.
-- :SummaryText(options, allLabel) joins the selected options' .text values, or allLabel if
-- none are selected.
function ns.CreateFilterSet()
	local set = { selected = {}, count = 0 }

	function set:Toggle(value)
		if self.selected[value] then
			self.selected[value] = nil
			self.count = self.count - 1
		else
			self.selected[value] = true
			self.count = self.count + 1
		end
	end

	function set:Set(value)
		wipe(self.selected)
		self.selected[value] = true
		self.count = 1
	end

	function set:Clear()
		wipe(self.selected)
		self.count = 0
	end

	function set:Matches(value)
		return self.count == 0 or self.selected[value] == true
	end

	function set:SummaryText(options, allLabel)
		if self.count == 0 then
			return allLabel
		end
		local names = {}
		for _, option in ipairs(options) do
			if self.selected[option.value] then
				names[#names + 1] = option.text
			end
		end
		return table.concat(names, ", ")
	end

	return set
end

function ns.CreateMultiSelectDropdown(parent, options, isSelected, toggle, getSummaryText, width, clearText, onClear)
	local ok, dropdown = pcall(CreateFrame, "DropdownButton", nil, parent, "WowStyle1DropdownTemplate")

	-- deferred, not just an immediate setDropdownDisplayText call: this template
	-- auto-generates its own "joined list of checked items" label for checkbox-only
	-- menus sometime after the click handler returns, break whatever was just
	-- set. re-applying a tick later wins that race.
	local function refreshDisplayText()
		setDropdownDisplayText(dropdown, getSummaryText())
		C_Timer.After(0, function()
			setDropdownDisplayText(dropdown, getSummaryText())
		end)
	end

	if ok and dropdown and dropdown.SetupMenu then
		dropdown:SetupMenu(function(_, rootDescription)
			if clearText then
				rootDescription:CreateButton(clearText, function()
					onClear()
					refreshDisplayText()
				end)
				rootDescription:CreateDivider()
			end
			for _, option in ipairs(options) do
				rootDescription:CreateCheckbox(option.text, function() return isSelected(option.value) end, function()
					toggle(option.value)
					refreshDisplayText()
				end)
			end
		end)
	else
		-- No good multi-select fallback shape for a plain button; degrades to
		-- single-select-by-cycling, same as CreateDropdown's own fallback, rather than
		-- leaving the filter entirely inoperable on a client without the modern template.
		dropdown = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
		dropdown:SetScript("OnClick", function(self)
			local currentIndex = 0
			for i, option in ipairs(options) do
				if isSelected(option.value) then
					currentIndex = i
					break
				end
			end
			local option = options[(currentIndex % #options) + 1]
			toggle(option.value)
			self:SetText(getSummaryText())
		end)
	end

	refreshDisplayText()
	-- also re-applied on every show, since the auto-generated label re-asserts itself
	-- again when the dropdown becomes visible (e.g. switching tabs away and back).
	dropdown:HookScript("OnShow", refreshDisplayText)
	dropdown:SetSize(width or 180, 22)
	return dropdown
end

-- Builds a themed filter bar: optional search box, one or more dropdowns, and a
-- checkbox, left to right, plus a right-aligned count label. Shared by the Players and
-- History tabs, which need the same filter controls wired to different filter state.
--
-- config = {
--   search = { onChange = function(lowerText) end },
--   dropdown = { options = {{value=.., text=..}, ...}, isSelected = function(value) end,
--                onChange = function(value, text) end, width = 150 },  -- single dropdown
--   dropdowns = { {options=.., isSelected=.., onChange=.., width=..}, ... },  -- multiple
--     each entry can instead set `multi = true` with `toggle = function(value) end` and
--     `getSummaryText = function() end` in place of `onChange`, to get a
--     ns.CreateMultiSelectDropdown instead of a single-select one.
--   checkbox = { label = "...", initial = false, onChange = function(checked) end },
-- }
-- bar.dropdowns is an array of the created dropdown widgets, in order, so callers can
-- sync a dropdown's displayed text externally (e.g. when a click-to-filter table cell
-- changes the same filter state the dropdown controls).
function ns.CreateFilterBar(parent, config)
	local bar = CreateFrame("Frame", nil, parent, "BackdropTemplate")
	bar:SetHeight(28)
	ns.ApplyPanelBackdrop(bar, 0.75)

	local prevWidget
	bar.dropdowns = {}

	if config.search then
		local searchBox = CreateFrame("EditBox", nil, bar, "SearchBoxTemplate")
		searchBox:SetSize(150, 20)
		searchBox:SetPoint("LEFT", 8, 0)
		searchBox:HookScript("OnTextChanged", function(self)
			config.search.onChange(self:GetText():lower())
		end)
		prevWidget = searchBox
		bar.searchBox = searchBox
	end

	bar.checkboxes = {}

	local function addDropdown(dc)
		local dropdown
		if dc.multi then
			dropdown = ns.CreateMultiSelectDropdown(bar, dc.options, dc.isSelected, dc.toggle, dc.getSummaryText, dc.width, dc.clearText, dc.onClear)
		else
			dropdown = ns.CreateDropdown(bar, dc.options, dc.isSelected, dc.onChange, dc.width)
		end
		dropdown:SetPoint("LEFT", prevWidget or bar, prevWidget and "RIGHT" or "LEFT", prevWidget and 10 or 8, 0)
		prevWidget = dropdown
		bar.dropdowns[#bar.dropdowns + 1] = dropdown
	end

	local function addCheckbox(cc)
		local check = CreateFrame("CheckButton", nil, bar, "UICheckButtonTemplate")
		check:SetSize(20, 20)
		check:SetChecked(cc.initial)
		check:SetPoint("LEFT", prevWidget or bar, prevWidget and "RIGHT" or "LEFT", prevWidget and 6 or 8, 0)
		check:SetScript("OnClick", function(self)
			cc.onChange(self:GetChecked() and true or false)
		end)

		local label = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		label:SetPoint("LEFT", check, "RIGHT", 2, 0)
		label:SetText(cc.label)
		prevWidget = label
		bar.checkboxes[#bar.checkboxes + 1] = check
	end

	-- `items`: an ordered list of { type = "dropdown"|"checkbox", ... } for callers that
	-- need dropdowns and checkboxes interleaved in a specific order, rather than every
	-- dropdown grouped before every checkbox (which is all the config.dropdowns/
	-- config.checkboxes grouping below can express).
	if config.items then
		for _, item in ipairs(config.items) do
			if item.type == "checkbox" then
				addCheckbox(item)
			else
				addDropdown(item)
			end
		end
	else
		local dropdownConfigs = config.dropdowns or (config.dropdown and { config.dropdown })
		if dropdownConfigs then
			for _, dc in ipairs(dropdownConfigs) do
				addDropdown(dc)
			end
		end

		local checkboxConfigs = config.checkboxes or (config.checkbox and { config.checkbox })
		if checkboxConfigs then
			for _, cc in ipairs(checkboxConfigs) do
				addCheckbox(cc)
			end
		end
	end
	-- Kept for existing single-checkbox callers (e.g. resetAllPlayerFilters).
	bar.checkbox = bar.checkboxes[1]

	if config.actionButton then
		local btn = CreateFrame("Button", nil, bar, "UIPanelButtonTemplate")
		btn:SetSize(config.actionButton.width or 80, 20)
		btn:SetPoint("RIGHT", -8, 0)
		btn:SetText(config.actionButton.text)
		btn:SetScript("OnClick", config.actionButton.onClick)
		bar.actionButton = btn
	end

	-- a checkbox pinned to the bar's own right edge instead of flowing left-to-right
	-- with the rest of config.items/dropdowns/checkboxes: for a toggle that belongs on
	-- the bar but reads as separate from the left-aligned filter controls, e.g.
	-- multi-select mode (not a filter at all).
	if config.rightCheckbox then
		local rc = config.rightCheckbox
		local label = bar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		label:SetPoint("RIGHT", -8, 0)
		label:SetText(rc.label)
		local check = CreateFrame("CheckButton", nil, bar, "UICheckButtonTemplate")
		check:SetSize(20, 20)
		check:SetChecked(rc.initial)
		check:SetPoint("RIGHT", label, "LEFT", -2, 0)
		check:SetScript("OnClick", function(self)
			rc.onChange(self:GetChecked() and true or false)
		end)
		if rc.tooltip then
			ns.AttachHookTooltip(check, rc.tooltip)
		end
		bar.rightCheckbox = check
	end

	bar.countLabel = bar:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	if bar.actionButton then
		bar.countLabel:SetPoint("RIGHT", bar.actionButton, "LEFT", -10, 0)
	elseif bar.rightCheckbox then
		bar.countLabel:SetPoint("RIGHT", bar.rightCheckbox, "LEFT", -10, 0)
	else
		bar.countLabel:SetPoint("RIGHT", -8, 0)
	end

	return bar
end

-- Generic sortable/resizable multi-column table in a scroll frame: a themed header row
-- (click to sort, drag the gap between columns to resize) above reused row frames.
-- Columns are left-to-right fixed-width except the *last*, which always flexes to fill
-- remaining row width. Shared by the Players, History, and Details tabs.
--
-- config = {
--   columns = { {key, label, width, min}, ... },  -- last entry is always the flex column
--   rowHeight = 20,
--   getItems = function() return {item, ...} end,  -- re-filtered fresh on every refresh
--   sortValue = function(item, key) end,
--   render = function(row, item) end,  -- set row.cells[key]:SetText()/SetTextColor()
--   onClick = function(item, rowFrame) end,  -- optional; omit for a non-clickable table
--   defaultSort = { key = "...", dir = "desc" },
--   pageSize = 100,  -- optional; when set, only this many rows exist/render at once,
--                    -- with Prev/Next controls, instead of one row frame per item ever
--                    -- matched. keeps a long (Players/History-scale) log from creating
--                    -- thousands of frames and paying a full-relayout cost per refresh.
--                    -- pageSize = "auto" instead fits however many rows the scroll
--                    -- area's current height allows, recomputed on resize.
-- }
-- Returns { container = frame, Refresh = function() end }
function ns.CreateSortableTable(parent, config)
	local HANDLE_WIDTH = 6
	local columns = config.columns
	-- Defaults to the last column (original behavior), but a column can set `flex = true`
	-- to claim the stretchy slot while still having other fixed-width columns positioned
	-- after it (e.g. a narrow checkbox column that belongs at the very end, after the
	-- flex text column).
	local flexKey = columns[#columns].key
	for _, col in ipairs(columns) do
		if col.flex then
			flexKey = col.key
		end
	end

	-- the first column always stays visible, so there's always at least one identifying
	-- column shown. the flex (last) column can still be hidden, the row/header just
	-- leave unused space where it would have stretched to fill.
	local function isHideable(key)
		return key ~= columns[1].key
	end

	-- a column can set `isVisible = function() end` to be shown/hidden by its own
	-- runtime condition instead of (or even despite) the usual per-user persisted
	-- settings below -- e.g. a multi-select checkbox column that only exists while that
	-- mode is on, not something a user would individually toggle via the column picker.
	local function isColumnVisible(key)
		for _, col in ipairs(columns) do
			if col.key == key then
				if col.isVisible then
					return col.isVisible()
				end
				break
			end
		end
		if not config.tableId or not isHideable(key) then
			return true
		end
		local vis = ns.GetSettings().columnVisibility[config.tableId]
		return not (vis and vis[key] == false)
	end

	-- a column's min can be a plain number, or a function for a floor that depends on
	-- live settings (e.g. a column that needs less room once some per-row button
	-- riding on it is hidden via its own Options checkbox)
	local function resolveMin(col)
		if type(col.min) == "function" then
			return col.min()
		end
		return col.min or 30
	end

	-- Applies any previously user-resized widths (see the resize handle below) before the
	-- header/rows are ever laid out, so a saved width takes effect from the first draw.
	if config.tableId then
		local saved = ns.GetSettings().columnWidths[config.tableId]
		if saved then
			for _, col in ipairs(columns) do
				if col.key ~= flexKey and saved[col.key] then
					col.width = math.max(resolveMin(col), saved[col.key])
				end
			end
		end
	end
	local sortKey = config.defaultSort and config.defaultSort.key or columns[1].key
	local sortDir = config.defaultSort and config.defaultSort.dir or "desc"
	-- pageSize = "auto" fits however many rows the scroll area's current height allows,
	-- recomputed on resize, instead of a fixed count.
	local autoPageSize = config.pageSize == "auto"
	local pageSize = config.pageSize
	local currentPage = 1
	local totalPages = 1

	local container = CreateFrame("Frame", nil, parent)

	-- autoPageSize always fits content to the visible height (see computeAutoPageSize
	-- below), so there's never anything to scroll within a page. no need to reserve
	-- width for a scrollbar that'll never have a thumb to show.
	local scrollbarInset = autoPageSize and 0 or 22

	local header = CreateFrame("Frame", nil, container, "BackdropTemplate")
	header:SetPoint("TOPLEFT", 0, 0)
	header:SetPoint("TOPRIGHT", -scrollbarInset, 0)
	header:SetHeight(20)
	-- a table with enough columns can have combined minimum widths wider than the
	-- window's own minimum width, so column content can run past the header's right
	-- edge even with every individual label correctly clipped to its own column. this
	-- catches that case too, clipping the whole row to the header's own bounds.
	header:SetClipsChildren(true)
	header:SetBackdrop({
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 8,
		insets = { left = 2, right = 2, top = 2, bottom = 2 },
	})
	header:SetBackdropBorderColor(1, 0.82, 0, 0.5)
	local headerFill = header:CreateTexture(nil, "BACKGROUND")
	headerFill:SetAllPoints()
	headerFill:SetColorTexture(0.32, 0.22, 0.09, 1)

	-- Pagination bar (only when config.pageSize is set) reserves its own strip at the
	-- bottom of the container, so the scrollframe gets a shorter BOTTOMRIGHT anchor than
	-- the no-paging case.
	local PAGE_BAR_HEIGHT = 26
	local pageBar, pageLabel, prevButton, nextButton
	if pageSize then
		pageBar = CreateFrame("Frame", nil, container)
		pageBar:SetHeight(PAGE_BAR_HEIGHT)
		pageBar:SetPoint("BOTTOMLEFT", 0, 0)
		pageBar:SetPoint("BOTTOMRIGHT", 0, 0)

		prevButton = CreateFrame("Button", nil, pageBar, "UIPanelButtonTemplate")
		prevButton:SetSize(70, 20)
		prevButton:SetText("< Prev")
		prevButton:SetPoint("LEFT", 2, 0)

		nextButton = CreateFrame("Button", nil, pageBar, "UIPanelButtonTemplate")
		nextButton:SetSize(70, 20)
		nextButton:SetText("Next >")
		nextButton:SetPoint("RIGHT", -24, 0)

		pageLabel = pageBar:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		pageLabel:SetPoint("CENTER", 0, 0)
	end

	local scroll = CreateFrame("ScrollFrame", nil, container, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, -24)
	scroll:SetPoint("BOTTOMRIGHT", -scrollbarInset, pageSize and PAGE_BAR_HEIGHT or 0)
	local scrollChild = CreateFrame("Frame", nil, scroll)
	scrollChild:SetSize(1, 1)

	if autoPageSize then
		-- Blizzard's own template re-Shows the scrollbar on its own whenever the
		-- content range changes (every refresh), overriding a one-time Hide() here.
		-- HookScript re-hides it every time that happens instead.
		if scroll.ScrollBar then
			scroll.ScrollBar:Hide()
			scroll.ScrollBar:HookScript("OnShow", function(self) self:Hide() end)
		end
	else
		-- anchored to the template's own real scrollbar widget (scroll.ScrollBar), not a
		-- guessed pixel offset, which kept landing visibly misaligned. falls back to a
		-- guessed offset only if that field isn't exposed.
		local scrollDivider = container:CreateTexture(nil, "ARTWORK")
		scrollDivider:SetWidth(1)
		scrollDivider:SetColorTexture(1, 0.82, 0, 0.3)
		if scroll.ScrollBar then
			scrollDivider:SetPoint("TOP", scroll.ScrollBar, "TOP", 0, 0)
			scrollDivider:SetPoint("BOTTOM", scroll.ScrollBar, "BOTTOM", 0, 0)
			scrollDivider:SetPoint("RIGHT", scroll.ScrollBar, "LEFT", -4, 0)
		else
			scrollDivider:SetPoint("TOPRIGHT", container, "TOPRIGHT", 0, -24)
			scrollDivider:SetPoint("BOTTOMRIGHT", container, "BOTTOMRIGHT", -22, 0)
		end
	end
	scroll:SetScrollChild(scrollChild)
	scroll:SetScript("OnSizeChanged", function(self, width) scrollChild:SetWidth(width) end)
	scrollChild:SetWidth(scroll:GetWidth())

	local headerCells, headerLabels, headerArrows, headerHandles = {}, {}, {}, {}
	local rows = {}
	local items = {}

	-- the flex column never shrinks below this, even when every visible column's widths
	-- added up don't fit the table's actual width, see relayout() below.
	local FLEX_MIN_WIDTH = 40

	local function relayout()
		-- Total width needed for every visible column AFTER the flex column, so the flex
		-- column's own width can be computed as "whatever's left."
		local trailing = 0
		do
			local passedFlex = false
			for _, col in ipairs(columns) do
				if col.key == flexKey then
					passedFlex = true
				elseif passedFlex and isColumnVisible(col.key) then
					trailing = trailing + col.width
				end
			end
		end

		-- everything is positioned in one single left-to-right chain, including columns
		-- after the flex one. the flex column's width is computed (clamped to a minimum)
		-- rather than anchored from the right as a second, independent system, which used
		-- to collide with the left-accumulated columns once the table got narrower than
		-- every column's width added up. computing the flex width from "whatever's
		-- actually left, floored at a minimum" means content runs past the right edge
		-- instead of overlapping itself when the table truly can't fit everything.
		local availableWidth = header:GetWidth()
		local x = 4
		for _, col in ipairs(columns) do
			local isFlex = col.key == flexKey
			local cell = headerCells[col.key]
			local handle = headerHandles[col.key]

			if not isColumnVisible(col.key) then
				cell:Hide()
				if handle then
					handle:Hide()
				end
				for _, row in ipairs(rows) do
					row.cells[col.key]:Hide()
					if row.cellButtons and row.cellButtons[col.key] then
						row.cellButtons[col.key]:Hide()
					end
				end
			else
				local width = isFlex and math.max(FLEX_MIN_WIDTH, availableWidth - x - trailing) or (col.width - 6)
				-- row cells that run past the table's width are clipped for free (they
				-- live inside a ScrollFrame, which clips to its own bounds automatically).
				-- the header row is a plain Frame with no such clipping, so a header cell
				-- pushed past the visible width has to be hidden by hand.
				local offScreen = x >= availableWidth

				cell:SetShown(not offScreen)
				cell:ClearAllPoints()
				cell:SetPoint("LEFT", header, "LEFT", x, 0)
				cell:SetWidth(width)

				if handle then
					-- the handle sits a few pixels past the cell's own right edge, so it
					-- can still poke out past the visible width even when the cell itself
					-- comfortably fits. check the handle's own projected right edge
					-- instead of reusing the cell's offScreen flag.
					local handleOffScreen = (x + width + 6 + HANDLE_WIDTH / 2) > availableWidth
					handle:SetShown(not handleOffScreen)
					handle:ClearAllPoints()
					-- relative to the cell's own live right edge, not a computed x.
					-- the +6 undoes the cell's own -6 width inset, so this lands where
					-- the old x-based math did for every pre-existing column.
					handle:SetPoint("LEFT", cell, "RIGHT", 6 - HANDLE_WIDTH / 2, 0)
				end

				for _, row in ipairs(rows) do
					local rc = row.cells[col.key]
					rc:Show()
					if row.cellButtons and row.cellButtons[col.key] then
						row.cellButtons[col.key]:Show()
					end
					rc:ClearAllPoints()
					-- anchored TOPLEFT+BOTTOMLEFT (full row height), not just a TOPLEFT
					-- point. a cell with only its text's own near-zero height (for
					-- short/empty strings) was why the "New" button rendered above the
					-- row bounds when anchored to it.
					rc:SetPoint("TOPLEFT", row, "TOPLEFT", x, 0)
					rc:SetPoint("BOTTOMLEFT", row, "BOTTOMLEFT", x, 0)
					rc:SetWidth(width)
				end

				-- non-flex columns advance by their full slot (col.width), which is 6px
				-- wider than their rendered cell: that gap is where the resize handle/
				-- divider sits. the flex column's width is computed, not fixed, so it
				-- adds that same gap explicitly instead.
				x = x + (isFlex and (width + 6) or col.width)
			end
		end
	end

	local function computeAutoPageSize()
		return math.max(1, math.floor(scroll:GetHeight() / config.rowHeight))
	end

	local function updateArrows()
		for _, col in ipairs(columns) do
			local active = col.key == sortKey
			local label = headerLabels[col.key]
			label:SetText(col.label)
			if active then
				label:SetTextColor(1, 1, 1)
			else
				label:SetTextColor(1, 0.82, 0)
			end

			local arrowIcon = headerArrows[col.key]
			if arrowIcon then
				arrowIcon:SetShown(active)
				if active then
					-- Two separate up/down textures, not one texture flipped by texcoord.
					arrowIcon:SetTexture(sortDir == "desc" and "Interface/Buttons/Arrow-Down-Up" or "Interface/Buttons/Arrow-Up-Up")
				end
			end
		end
	end

	local function refresh()
		items = config.getItems()
		table.sort(items, function(a, b)
			local av, bv = config.sortValue(a, sortKey), config.sortValue(b, sortKey)
			if av == bv then
				return false
			elseif sortDir == "asc" then
				return av < bv
			end
			return av > bv
		end)

		if autoPageSize then
			pageSize = computeAutoPageSize()
		end

		-- with pagination, only the current page's slice ever gets a row frame. the
		-- full (filtered+sorted) `items` list still drives page-count math, but row
		-- creation/render below only sees `pageItems`, capped at pageSize entries.
		local pageItems = items
		if pageSize then
			totalPages = math.max(1, math.ceil(#items / pageSize))
			currentPage = math.max(1, math.min(currentPage, totalPages))
			pageItems = {}
			local startIndex = (currentPage - 1) * pageSize + 1
			for i = startIndex, math.min(#items, startIndex + pageSize - 1) do
				pageItems[#pageItems + 1] = items[i]
			end
			pageLabel:SetText(("Page %d / %d"):format(currentPage, totalPages))
			prevButton:SetEnabled(currentPage > 1)
			nextButton:SetEnabled(currentPage < totalPages)
		end

		for i = #rows + 1, #pageItems do
			local row = CreateFrame((config.onClick or config.onRightClick) and "Button" or "Frame", nil, scrollChild)
			row:SetHeight(config.rowHeight)
			row:SetPoint("TOPLEFT", scrollChild, "TOPLEFT", 0, -(i - 1) * config.rowHeight)
			row:SetPoint("RIGHT", scrollChild, "RIGHT", 0, 0)

			row.stripe = row:CreateTexture(nil, "BACKGROUND", nil, -1)
			row.stripe:SetAllPoints()
			row.stripe:SetColorTexture(0, 0, 0, i % 2 == 0 and 0.18 or 0)

			row.cells = {}
			row.cellButtons = {}

			-- manually shown/hidden, not an automatic "HIGHLIGHT"-layer texture, so a
			-- click-to-filter cell button sitting on top of part of the row can still
			-- light up the *whole* row on hover. a HIGHLIGHT-layer texture only
			-- auto-shows when the row itself is the actual mouse-over target.
			local rowHighlight

			for _, col in ipairs(columns) do
				local cell
				if col.cellType == "checkbox" then
					-- the cell itself is a plain container, so it still participates
					-- normally in relayout()'s generic Show/Hide/SetWidth/SetPoint handling.
					-- the actual checkbox is a fixed-size child anchored inside it, so a
					-- wide column doesn't stretch/distort it.
					cell = CreateFrame("Frame", nil, row)
					local check = CreateFrame("CheckButton", nil, cell, "UICheckButtonTemplate")
					check:SetSize(18, 18)
					check:SetPoint("LEFT", 0, 0)
					check:SetScript("OnClick", function(self)
						if col.onCheckboxClick then
							col.onCheckboxClick(row.item, self:GetChecked() and true or false)
						end
					end)
					cell.checkbox = check
				else
					cell = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
					cell:SetJustifyH("LEFT")
					cell:SetJustifyV("MIDDLE")
					-- word wrap ON but capped to one line, not wrap-off: wrap-off lets a
					-- too-long single line bleed past the cell's own bounds into
					-- whatever's next (e.g. a checkbox column). this clips the overflow
					-- at the cell's own width instead.
					cell:SetWordWrap(true)
					cell:SetMaxLines(1)
				end
				row.cells[col.key] = cell

				-- optional per-column click-to-filter (e.g. click a class/race cell to
				-- filter to just that value). a sibling button anchored to the cell's
				-- own frame region tracks the cell automatically on resize/relayout.
				-- a mouse-enabled frame on top claims the hit regardless of which
				-- buttons it's registered for, so right-click must be explicitly
				-- forwarded to the row's own handler or it's silently swallowed, which
				-- is why right-click only worked reliably over columns with no
				-- click-to-filter cell (e.g. Time).
				if col.onCellClick then
					local cellButton = CreateFrame("Button", nil, row)
					cellButton:SetAllPoints(cell)
					cellButton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
					cellButton:SetScript("OnClick", function(self, button)
						if button == "RightButton" then
							if config.onRightClick then
								config.onRightClick(row.item, row)
							end
						else
							col.onCellClick(row.item)
						end
					end)
					cellButton:SetScript("OnEnter", function()
						if rowHighlight then
							rowHighlight:Show()
						end
					end)
					cellButton:SetScript("OnLeave", function()
						if rowHighlight then
							rowHighlight:Hide()
						end
					end)
					row.cellButtons[col.key] = cellButton
				end
			end

			if config.onClick or config.onRightClick then
				local clicks = {}
				if config.onClick then
					clicks[#clicks + 1] = "LeftButtonUp"
				end
				if config.onRightClick then
					clicks[#clicks + 1] = "RightButtonUp"
				end
				row:RegisterForClicks(unpack(clicks))
				row:SetScript("OnClick", function(self, button)
					if button == "RightButton" and config.onRightClick then
						config.onRightClick(self.item, self)
					elseif config.onClick then
						config.onClick(self.item, self)
					end
				end)
				rowHighlight = row:CreateTexture(nil, "ARTWORK")
				rowHighlight:SetAllPoints()
				rowHighlight:SetColorTexture(1, 1, 1, 0.08)
				rowHighlight:Hide()
				row:SetScript("OnEnter", function() rowHighlight:Show() end)
				row:SetScript("OnLeave", function() rowHighlight:Hide() end)
			end

			rows[i] = row
		end

		relayout()

		for i, row in ipairs(rows) do
			local item = pageItems[i]
			if item then
				row.item = item
				config.render(row, item)
				row:Show()
			else
				row:Hide()
			end
		end

		scrollChild:SetHeight(math.max(1, #pageItems * config.rowHeight))
	end

	-- re-run relayout whenever the table's actual available width/height changes (window
	-- resize, column visibility toggle, etc), not just on a data-driven refresh(),
	-- otherwise cell positions stay stale. cheap, so it runs on every tick live.
	-- autoPageSize's row-count recompute is debounced instead: it rebuilds rows, and
	-- doing that on every pixel of a live window drag is what caused the flicker and
	-- the stray 1-row readings (scroll:GetHeight() mid-drag isn't the settled size).
	local lastAutoPageSize
	local autoPageSizeTimer
	container:SetScript("OnSizeChanged", function()
		relayout()
		if not autoPageSize then
			return
		end
		if autoPageSizeTimer then
			autoPageSizeTimer:Cancel()
		end
		autoPageSizeTimer = C_Timer.NewTimer(0.2, function()
			autoPageSizeTimer = nil
			local newSize = computeAutoPageSize()
			if newSize ~= lastAutoPageSize then
				lastAutoPageSize = newSize
				refresh()
			end
		end)
	end)

	if pageSize then
		prevButton:SetScript("OnClick", function()
			currentPage = math.max(1, currentPage - 1)
			refresh()
		end)
		nextButton:SetScript("OnClick", function()
			currentPage = currentPage + 1
			refresh()
		end)
	end

	-- a resize handle drags `targetCol.width`. `invert` is true only for the handle on
	-- the flex column's right edge, which drags the WIDTH OF THE NEXT COLUMN instead of
	-- its own (the flex column has no fixed width to drag), so dragging left (shrinking
	-- the flex region) has to GROW that column, not shrink it.
	local function createResizeHandle(ownerKey, targetCol, invert)
		local handle = CreateFrame("Button", nil, header)
		handle:SetSize(HANDLE_WIDTH, 18)
		handle:EnableMouse(true)
		local divider = handle:CreateTexture(nil, "ARTWORK")
		divider:SetPoint("TOP", 0, 0)
		divider:SetPoint("BOTTOM", 0, 0)
		divider:SetWidth(1)
		divider:SetColorTexture(1, 0.82, 0, 0.3)
		local hoverHighlight = handle:CreateTexture(nil, "ARTWORK")
		hoverHighlight:SetAllPoints()
		hoverHighlight:SetColorTexture(1, 0.82, 0, 0.6)
		hoverHighlight:Hide()
		handle:SetScript("OnEnter", function() hoverHighlight:Show() end)
		handle:SetScript("OnLeave", function() hoverHighlight:Hide() end)
		handle:SetScript("OnMouseDown", function()
			local startX = GetCursorPosition()
			local startWidth = targetCol.width
			handle:SetScript("OnUpdate", function()
				local scale = UIParent:GetEffectiveScale()
				local dx = (GetCursorPosition() - startX) / scale
				targetCol.width = math.max(resolveMin(targetCol), startWidth + (invert and -dx or dx))
				relayout()
			end)
		end)
		handle:SetScript("OnMouseUp", function()
			handle:SetScript("OnUpdate", nil)
			if config.tableId then
				local widths = ns.GetSettings().columnWidths
				widths[config.tableId] = widths[config.tableId] or {}
				widths[config.tableId][targetCol.key] = targetCol.width
			end
		end)
		headerHandles[ownerKey] = handle
	end

	for i, col in ipairs(columns) do
		local isFlex = col.key == flexKey
		local button = CreateFrame("Button", nil, header)
		button:SetHeight(18)
		if not isFlex then
			button:SetWidth(col.width - 6)
		end

		-- word wrap alone can't break a single too-long word (e.g. "Location") to fit a
		-- narrow column, so it still bled past the button's own bounds. SetClipsChildren
		-- only clips child *frames*, not a frame's own directly-owned regions, so the
		-- label lives in its own child frame instead of directly on the button, to
		-- actually get clipped by it.
		button:SetClipsChildren(true)
		local labelClip = CreateFrame("Frame", nil, button)
		labelClip:SetPoint("TOPLEFT")
		labelClip:SetPoint("BOTTOMRIGHT", -12, 0)

		local fs = labelClip:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		fs:SetAllPoints()
		fs:SetJustifyH("LEFT")
		fs:SetWordWrap(true)
		fs:SetMaxLines(1)
		fs:SetText(col.label)

		if not col.noSort then
			local arrowIcon = button:CreateTexture(nil, "ARTWORK")
			arrowIcon:SetSize(10, 10)
			arrowIcon:SetPoint("RIGHT", -1, 0)
			arrowIcon:Hide()
			headerArrows[col.key] = arrowIcon

			button:RegisterForClicks("LeftButtonUp")
			button:SetScript("OnClick", function()
				if sortKey == col.key then
					sortDir = (sortDir == "desc") and "asc" or "desc"
				else
					sortKey = col.key
					sortDir = "desc"
				end
				updateArrows()
				refresh()
			end)
		end
		headerCells[col.key] = button
		headerLabels[col.key] = fs

		if not isFlex then
			createResizeHandle(col.key, col, false)
		elseif columns[i + 1] then
			createResizeHandle(col.key, columns[i + 1], true)
		end
	end

	updateArrows()

	local function setColumnVisible(key, visible)
		if not config.tableId or not isHideable(key) then
			return
		end
		local vis = ns.GetSettings().columnVisibility
		vis[config.tableId] = vis[config.tableId] or {}
		-- not the `cond and a or b` idiom, which breaks when `a` itself is `false`
		-- (falls through to `b` regardless of `cond`). that's exactly the value being
		-- stored here, so every "hide this column" write was silently discarded as nil.
		if visible then
			vis[config.tableId][key] = nil
		else
			vis[config.tableId][key] = false
		end
		relayout()
	end

	return {
		container = container,
		Refresh = refresh,
		IsColumnVisible = isColumnVisible,
		SetColumnVisible = setColumnVisible,
		IsColumnHideable = isHideable,
	}
end
