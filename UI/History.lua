local ns = WorthRemembering

StaticPopupDialogs["WR_CONFIRM_DELETE_SELECTED_ENTRIES"] = {
	text = "Delete %d selected entries? This cannot be undone.",
	button1 = "Delete",
	button2 = "Cancel",
	OnAccept = function(self, selections)
		for _, selection in ipairs(selections) do
			ns.DeleteEntry(selection.key, selection.entry)
		end
		ns.ClearHistorySelection()
		ns.RefreshAllTabs()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local table_ -- the ns.CreateSortableTable instance
local filterBar
local charBar
local classRaceBar
local search = ""
local notesOnly = false
local currentCharOnly = false

-- multi-select state (Options > General): entry (table identity) -> owning player key,
-- for every checked row. cleared whenever the mode gets toggled off/on, or after a bulk
-- delete removes those entries. keyed by the entry table itself, not a synthetic id,
-- since ns.DeleteEntry already identifies an entry that same way.
local selectedEntries = {}
local selectedCount = 0

local function setEntrySelected(item, selected)
	if selected and not selectedEntries[item.entry] then
		selectedEntries[item.entry] = item.key
		selectedCount = selectedCount + 1
	elseif not selected and selectedEntries[item.entry] then
		selectedEntries[item.entry] = nil
		selectedCount = selectedCount - 1
	end
end

function ns.ClearHistorySelection()
	wipe(selectedEntries)
	selectedCount = 0
	if table_ then
		table_.Refresh()
	end
end

-- called from Players' own Multi-Select checkbox so this tab's copy of the same
-- checkbox doesn't go stale until this tab happens to rebuild
function ns.SyncHistoryMultiSelectCheckbox(checked)
	if charBar and charBar.rightCheckbox then
		charBar.rightCheckbox:SetChecked(checked)
	end
end

-- Every dropdown filter on this tab is multi-select (see ns.CreateFilterSet), matching
-- the Players tab and the "All Brackets" dropdown that originated the pattern.
local signFilter = ns.CreateFilterSet()
local sourceFilter = ns.CreateFilterSet()
local characterFilter = ns.CreateFilterSet()
local classFilter = ns.CreateFilterSet()
local raceFilter = ns.CreateFilterSet()
local factionFilter = ns.CreateFilterSet()

local SIGN_OPTIONS = {
	{ value = "positive", text = "Positive" },
	{ value = "negative", text = "Negative" },
}

local SOURCE_OPTIONS = {
	{ value = "manual", text = "Manual" },
	{ value = "auto", text = "Auto" },
}

local function getCharacterOptions()
	local options = {}
	for _, name in ipairs(ns.GetKnownCharacters()) do
		options[#options + 1] = { value = name, text = name }
	end
	return options
end

local function getClassOptions()
	local options = {}
	for _, classFile in ipairs(ns.GetKnownClasses()) do
		options[#options + 1] = { value = classFile, text = ns.ClassDisplayName(classFile) }
	end
	return options
end

local function getRaceOptions()
	local options = {}
	for _, race in ipairs(ns.GetKnownRaces()) do
		options[#options + 1] = { value = race, text = race }
	end
	return options
end

local FACTION_OPTIONS = {
	{ value = "Horde", text = "Horde" },
	{ value = "Alliance", text = "Alliance" },
}

local function matchesSearch(record, key, entry)
	if search == "" then
		return true
	end
	local haystack = (ns.DisplayName(record, key) .. " " .. (entry.zone or "") .. " " .. (entry.text or "")):lower()
	return haystack:find(search, 1, true) ~= nil
end

-- Matches if the entry's delta sign satisfies ANY selected sign (e.g. "Positive" +
-- "Negative" selected together matches every nonzero delta).
local function matchesSign(entry)
	if signFilter.count == 0 then
		return true
	end
	local selected = signFilter.selected
	return (selected.positive and entry.delta and entry.delta > 0)
		or (selected.negative and entry.delta and entry.delta < 0)
		or false
end

local function matchesNotesOnly(entry)
	return not notesOnly or (entry.text and entry.text ~= "")
end

local function matchesSource(entry)
	if sourceFilter.count == 0 then
		return true
	end
	local value = ns.IsAutoSource(entry.source) and "auto" or "manual"
	return sourceFilter:Matches(value)
end

local function matchesCharacter(entry)
	if currentCharOnly then
		return entry.loggedBy == ns.GetMyFullName()
	end
	return characterFilter:Matches(entry.loggedBy)
end

local function matchesClassRace(record)
	if not classFilter:Matches(record.classFile) then
		return false
	end
	if not raceFilter:Matches(ns.SimplifyRace(record.race)) then
		return false
	end
	if not factionFilter:Matches(record.faction) then
		return false
	end
	return true
end

-- Keeps the Class/Race/Faction dropdowns in sync when a table cell click changes the
-- same filter state they control.
local function syncClassRaceDropdowns()
	if not classRaceBar then
		return
	end
	classRaceBar.dropdowns[1]:SetText(classFilter:SummaryText(getClassOptions(), "All classes"))
	classRaceBar.dropdowns[2]:SetText(raceFilter:SummaryText(getRaceOptions(), "All races"))
	classRaceBar.dropdowns[3]:SetText(factionFilter:SummaryText(FACTION_OPTIONS, "All factions"))
end

-- Clears every History filter and syncs every filter widget back to its "all" display.
local function resetAllHistoryFilters()
	search = ""
	signFilter:Clear()
	sourceFilter:Clear()
	notesOnly = false
	characterFilter:Clear()
	currentCharOnly = false
	classFilter:Clear()
	raceFilter:Clear()
	factionFilter:Clear()

	if filterBar then
		if filterBar.searchBox then
			filterBar.searchBox:SetText("")
		end
		if filterBar.checkbox then
			filterBar.checkbox:SetChecked(false)
		end
		if filterBar.dropdowns[1] then
			filterBar.dropdowns[1]:SetText(signFilter:SummaryText(SIGN_OPTIONS, "All standing changes"))
		end
		if filterBar.dropdowns[2] then
			filterBar.dropdowns[2]:SetText(sourceFilter:SummaryText(SOURCE_OPTIONS, "Manual & auto"))
		end
	end
	if charBar then
		if charBar.dropdowns[1] then
			charBar.dropdowns[1]:SetText(characterFilter:SummaryText(getCharacterOptions(), "All characters"))
		end
		if charBar.checkbox then
			charBar.checkbox:SetChecked(false)
		end
	end
	syncClassRaceDropdowns()
end

local function getItems()
	local list = {}
	for _, key in ipairs(ns.GetAllPlayerKeys()) do
		local record = ns.GetPlayerRecord(key, false)
		if record and matchesClassRace(record) then
			for _, entry in ipairs(record.entries) do
				if matchesSign(entry) and matchesSource(entry) and matchesNotesOnly(entry) and matchesCharacter(entry) and matchesSearch(record, key, entry) then
					list[#list + 1] = { key = key, record = record, entry = entry }
				end
			end
		end
	end
	return list
end

-- Click a Class/Race/Faction cell to filter to just that value; click the already-sole-
-- selected value again to clear it. The dropdowns above the table do the same thing and
-- stay in sync either way.
local function onClassCellClick(item)
	local value = item.record.classFile
	if not value then
		return
	end
	if classFilter.count == 1 and classFilter.selected[value] then
		classFilter:Clear()
	else
		classFilter:Set(value)
	end
	syncClassRaceDropdowns()
	ns.RefreshHistory()
end

local function onRaceCellClick(item)
	local value = ns.SimplifyRace(item.record.race)
	if not value then
		return
	end
	if raceFilter.count == 1 and raceFilter.selected[value] then
		raceFilter:Clear()
	else
		raceFilter:Set(value)
	end
	syncClassRaceDropdowns()
	ns.RefreshHistory()
end

local function onFactionCellClick(item)
	local value = item.record.faction
	if not value then
		return
	end
	if factionFilter.count == 1 and factionFilter.selected[value] then
		factionFilter:Clear()
	else
		factionFilter:Set(value)
	end
	syncClassRaceDropdowns()
	ns.RefreshHistory()
end

-- Click a Player name to jump to their Details page, same as the Players tab's own
-- name column. Click a Character cell to filter by who logged it, kept in sync with the
-- "Current character"/character dropdown bar above.
local function onPlayerCellClick(item)
	ns.ShowPlayerDetails(item.key)
end

-- Click a Source cell to filter to just Manual or just Auto; click the already-sole-
-- selected value again to clear it, same toggle convention as the other click-to-filter
-- columns.
local function onSourceCellClick(item)
	local value = ns.IsAutoSource(item.entry.source) and "auto" or "manual"
	if sourceFilter.count == 1 and sourceFilter.selected[value] then
		sourceFilter:Clear()
	else
		sourceFilter:Set(value)
	end
	if filterBar and filterBar.dropdowns[2] then
		filterBar.dropdowns[2]:SetText(sourceFilter:SummaryText(SOURCE_OPTIONS, "Manual & auto"))
	end
	ns.RefreshHistory()
end

local function onCharacterCellClick(item)
	local value = item.entry.loggedBy
	if not value then
		return
	end
	if characterFilter.count == 1 and characterFilter.selected[value] then
		characterFilter:Clear()
	else
		characterFilter:Set(value)
	end
	currentCharOnly = false
	if charBar then
		if charBar.dropdowns[1] then
			charBar.dropdowns[1]:SetText(characterFilter:SummaryText(getCharacterOptions(), "All characters"))
		end
		if charBar.checkbox then
			charBar.checkbox:SetChecked(false)
		end
	end
	ns.RefreshHistory()
end

-- Click a Zone cell to filter the search box to just that zone's name; click the same
-- zone again to clear it, same toggle convention as the Player cell. Shares the `search`
-- field with the free-text search box (matchesSearch already checks zone text), so this
-- doesn't need its own separate filter variable.
local function onZoneCellClick(item)
	local zone = item.entry.zone
	if not zone or zone == "" then
		return
	end
	local target = zone:lower()
	search = (search == target) and "" or target
	if filterBar.searchBox then
		filterBar.searchBox:SetText(search ~= "" and zone or "")
	end
	ns.RefreshHistory()
end

-- Clicking the checkbox toggles entry.featured directly; AddEntry/EditEntry already
-- enforce that a featured entry must have note text, but the checkbox itself only ever
-- renders at all when render() below confirms the entry has one.
local function onFeaturedCheckboxClick(item, checked)
	if not (item.entry.text and item.entry.text ~= "") then
		return
	end
	item.entry.featured = checked or nil
	ns.RefreshAllTabs()
end

local COLUMNS = {
	{ key = "select", label = "", width = 26, min = 26, cellType = "checkbox", noSort = true,
		isVisible = function() return ns.GetSettings().multiSelectEnabled end,
		onCheckboxClick = function(item, checked) setEntrySelected(item, checked) end },
	{ key = "time", label = "Time", width = 130, min = 90 },
	{ key = "player", label = "Player", width = 110, min = 80, onCellClick = onPlayerCellClick },
	{ key = "race", label = "Race", width = 80, min = 60, onCellClick = onRaceCellClick },
	{ key = "class", label = "Class", width = 80, min = 60, onCellClick = onClassCellClick },
	{ key = "faction", label = "Faction", width = 70, min = 60, onCellClick = onFactionCellClick },
	{ key = "character", label = "Character", width = 90, min = 60, onCellClick = onCharacterCellClick },
	{ key = "source", label = "Source", width = 60, min = 50, onCellClick = onSourceCellClick },
	{ key = "delta", label = "+/-", width = 40, min = 30 },
	{ key = "yourLevel", label = "Your Lvl", width = 82, min = 50 },
	{ key = "theirLevel", label = "Their Lvl", width = 86, min = 50 },
	{ key = "zone", label = "Location", width = 110, min = 60, onCellClick = onZoneCellClick },
	{ key = "note", label = "Note", width = 0, flex = true },
	{ key = "featured", label = "Featured", width = 60, min = 50, cellType = "checkbox", onCheckboxClick = onFeaturedCheckboxClick },
}

local function sortValue(item, key)
	if key == "player" then
		return ns.DisplayName(item.record, item.key):lower()
	elseif key == "class" then
		return ns.ClassDisplayName(item.record.classFile)
	elseif key == "race" then
		return ns.SimplifyRace(item.record.race) or ""
	elseif key == "faction" then
		return item.record.faction or ""
	elseif key == "character" then
		return (item.entry.loggedBy or ""):lower()
	elseif key == "source" then
		return ns.SourceLabel(item.entry.source)
	elseif key == "zone" then
		return (item.entry.zone or ""):lower()
	elseif key == "note" then
		return (item.entry.text or ""):lower()
	elseif key == "featured" then
		return item.entry.featured and 1 or 0
	else
		return item.entry[key] or -math.huge
	end
end

local function render(row, item)
	local entry, record, key = item.entry, item.record, item.key
	row.cells.select.checkbox:SetChecked(selectedEntries[entry] ~= nil)
	row.cells.time:SetText(ns.FormatTime(entry.time))

	local cr, cg, cb = ns.ClassColor(record.classFile)
	row.cells.player:SetText(ns.DisplayName(record, key))
	row.cells.player:SetTextColor(cr, cg, cb)

	row.cells.class:SetText(ns.ClassDisplayName(record.classFile))
	row.cells.class:SetTextColor(cr, cg, cb)
	row.cells.race:SetText(ns.SimplifyRace(record.race) or "-")

	local fr, fg, fb = ns.FactionColor(record.faction)
	row.cells.faction:SetText(record.faction or "-")
	row.cells.faction:SetTextColor(fr, fg, fb)

	row.cells.character:SetText(entry.loggedBy or "-")

	if ns.IsAutoSource(entry.source) then
		row.cells.source:SetText("Auto")
		row.cells.source:SetTextColor(0.55, 0.75, 1)
	else
		row.cells.source:SetText("Manual")
		row.cells.source:SetTextColor(0.8, 0.8, 0.8)
	end

	if entry.delta and entry.delta ~= 0 then
		local r, g, b = ns.StandingColor(entry.delta, 0)
		row.cells.delta:SetText((entry.delta > 0 and "+" or "") .. entry.delta)
		row.cells.delta:SetTextColor(r, g, b)
	else
		row.cells.delta:SetText("-")
		row.cells.delta:SetTextColor(0.6, 0.6, 0.6)
	end

	row.cells.yourLevel:SetText(entry.yourLevel or "-")
	row.cells.theirLevel:SetText(entry.theirLevel or "-")
	row.cells.zone:SetText(entry.zone or "-")
	row.cells.note:SetText(entry.text or "")

	-- no checkbox at all on entries with no note, nothing to show a featured flag for
	local hasNote = entry.text and entry.text ~= ""
	row.cells.featured.checkbox:SetShown(hasNote)
	if hasNote then
		row.cells.featured.checkbox:SetChecked(entry.featured and true or false)
	end
end

function ns.RefreshHistory()
	if not table_ then
		return
	end
	table_.Refresh()
	local count = #getItems()
	local countText = count == 1 and "1 entry" or (count .. " entries")
	filterBar.countLabel:SetText(countText)
	-- runs on every RefreshAllTabs call, not just while History is visible. without
	-- this guard it'd stomp the footer with History's wording on any other tab
	if ns.RefreshFooter and ns.GetSelectedTab and ns.GetSelectedTab() == 2 then
		ns.RefreshFooter(countText .. " shown")
	end
end

-- Deep-link from the Players tab: jump to History pre-filtered to one player.
function ns.FilterHistoryByPlayer(key)
	local record = ns.GetPlayerRecord(key, false)
	local name = record and ns.DisplayName(record, key) or key
	search = name:lower()
	if filterBar.searchBox then
		filterBar.searchBox:SetText(name)
	end
	ns.RefreshHistory()
end

function ns.BuildHistoryPanel(parent)
	filterBar = ns.CreateFilterBar(parent, {
		search = { onChange = function(text) search = text; ns.RefreshHistory() end },
		dropdowns = {
			{
				multi = true,
				options = SIGN_OPTIONS,
				isSelected = function(value) return signFilter.selected[value] == true end,
				toggle = function(value) signFilter:Toggle(value); ns.RefreshHistory() end,
				getSummaryText = function() return signFilter:SummaryText(SIGN_OPTIONS, "All standing changes") end,
				clearText = "All standing changes",
				onClear = function() signFilter:Clear(); ns.RefreshHistory() end,
				width = 170,
			},
			{
				multi = true,
				options = SOURCE_OPTIONS,
				isSelected = function(value) return sourceFilter.selected[value] == true end,
				toggle = function(value) sourceFilter:Toggle(value); ns.RefreshHistory() end,
				getSummaryText = function() return sourceFilter:SummaryText(SOURCE_OPTIONS, "Manual & auto") end,
				clearText = "Manual & auto",
				onClear = function() sourceFilter:Clear(); ns.RefreshHistory() end,
				width = 140,
			},
		},
		checkbox = {
			label = "Notes only",
			initial = notesOnly,
			onChange = function(checked) notesOnly = checked; ns.RefreshHistory() end,
		},
	})
	filterBar:SetPoint("TOPLEFT", 12, -4)
	filterBar:SetPoint("TOPRIGHT", -12, -4)

	-- account-wide DB shared across characters, this row narrows the log to one (or
	-- your current) character's entries
	charBar = ns.CreateFilterBar(parent, {
		dropdown = {
			multi = true,
			options = getCharacterOptions(),
			isSelected = function(value) return characterFilter.selected[value] == true end,
			toggle = function(value) characterFilter:Toggle(value); ns.RefreshHistory() end,
			getSummaryText = function() return characterFilter:SummaryText(getCharacterOptions(), "All characters") end,
			clearText = "All characters",
			onClear = function() characterFilter:Clear(); ns.RefreshHistory() end,
			width = 170,
		},
		checkbox = {
			label = "Current character only",
			initial = currentCharOnly,
			onChange = function(checked) currentCharOnly = checked; ns.RefreshHistory() end,
		},
		rightCheckbox = {
			label = "Multi-Select",
			initial = ns.GetSettings().multiSelectEnabled,
			tooltip = "Adds a checkbox column for checking several rows at once. Right-click with more than one checked for a bulk delete option.",
			onChange = function(checked)
				ns.GetSettings().multiSelectEnabled = checked
				ns.ClearHistorySelection()
				if ns.ClearPlayerSelection then
					ns.ClearPlayerSelection()
				end
				-- Players has its own instance of this same checkbox on its own
				-- charBar; keep it in sync rather than leaving it stale until that tab
				-- happens to rebuild
				if ns.SyncPlayersMultiSelectCheckbox then
					ns.SyncPlayersMultiSelectCheckbox(checked)
				end
			end,
		},
	})
	charBar:SetPoint("TOPLEFT", 12, -34)
	charBar:SetPoint("TOPRIGHT", -12, -34)

	-- Explicit Class/Race/Faction dropdowns for the same state the table's click-to-filter
	-- cells control, kept in sync via syncClassRaceDropdowns.
	classRaceBar = ns.CreateFilterBar(parent, {
		dropdowns = {
			{
				multi = true,
				options = getClassOptions(),
				isSelected = function(value) return classFilter.selected[value] == true end,
				toggle = function(value) classFilter:Toggle(value); syncClassRaceDropdowns(); ns.RefreshHistory() end,
				getSummaryText = function() return classFilter:SummaryText(getClassOptions(), "All classes") end,
				clearText = "All classes",
				onClear = function() classFilter:Clear(); syncClassRaceDropdowns(); ns.RefreshHistory() end,
				width = 140,
			},
			{
				multi = true,
				options = getRaceOptions(),
				isSelected = function(value) return raceFilter.selected[value] == true end,
				toggle = function(value) raceFilter:Toggle(value); syncClassRaceDropdowns(); ns.RefreshHistory() end,
				getSummaryText = function() return raceFilter:SummaryText(getRaceOptions(), "All races") end,
				clearText = "All races",
				onClear = function() raceFilter:Clear(); syncClassRaceDropdowns(); ns.RefreshHistory() end,
				width = 140,
			},
			{
				multi = true,
				options = FACTION_OPTIONS,
				isSelected = function(value) return factionFilter.selected[value] == true end,
				toggle = function(value) factionFilter:Toggle(value); syncClassRaceDropdowns(); ns.RefreshHistory() end,
				getSummaryText = function() return factionFilter:SummaryText(FACTION_OPTIONS, "All factions") end,
				clearText = "All factions",
				onClear = function() factionFilter:Clear(); syncClassRaceDropdowns(); ns.RefreshHistory() end,
				width = 130,
			},
		},
	})
	local clearFiltersButton = CreateFrame("Button", nil, classRaceBar, "UIPanelButtonTemplate")
	clearFiltersButton:SetSize(100, 20)
	clearFiltersButton:SetText("Clear Filters")
	clearFiltersButton:SetPoint("RIGHT", -8, 0)
	clearFiltersButton:SetScript("OnClick", function()
		resetAllHistoryFilters()
		ns.RefreshHistory()
	end)

	classRaceBar:SetPoint("TOPLEFT", 12, -64)
	classRaceBar:SetPoint("TOPRIGHT", -12, -64)

	table_ = ns.CreateSortableTable(parent, {
		tableId = "history",
		columns = COLUMNS,
		rowHeight = 22,
		getItems = getItems,
		sortValue = sortValue,
		render = render,
		onRightClick = function(item, rowFrame)
			MenuUtil.CreateContextMenu(rowFrame, function(_, rootDescription)
				rootDescription:CreateTitle(ns.DisplayName(item.record, item.key) .. "  |  " .. ns.FormatTime(item.entry.time))
				rootDescription:CreateButton("Edit Entry", function() ns.ShowEditEntry(item.key, item.record, item.entry) end)
				rootDescription:CreateButton("Delete Entry", function() ns.ConfirmDeleteEntry(item.key, item.entry) end)
				-- multi-select's own bulk option, only once there's actually a group
				-- worth acting on together; a single checked row is no different from
				-- just using the row's own delete button above.
				if selectedCount > 1 then
					local selections = {}
					for entry, entryKey in pairs(selectedEntries) do
						selections[#selections + 1] = { key = entryKey, entry = entry }
					end
					rootDescription:CreateButton("Delete " .. #selections .. " Selected Entries", function()
						StaticPopup_Show("WR_CONFIRM_DELETE_SELECTED_ENTRIES", #selections, nil, selections)
					end)
				end
			end)
		end,
		defaultSort = { key = "time", dir = "desc" },
		pageSize = 100,
	})
	table_.container:SetPoint("TOPLEFT", 12, -96)
	table_.container:SetPoint("BOTTOMRIGHT", -12, 0)

	local function columnOptions()
		local opts = {}
		for _, col in ipairs(COLUMNS) do
			if table_.IsColumnHideable(col.key) then
				opts[#opts + 1] = { value = col.key, text = col.label }
			end
		end
		return opts
	end

	local function columnsSummaryText()
		return "Columns"
	end

	local function showAllColumns()
		for _, col in ipairs(COLUMNS) do
			if table_.IsColumnHideable(col.key) then
				table_.SetColumnVisible(col.key, true)
			end
		end
	end

	local columnsDropdown = ns.CreateMultiSelectDropdown(classRaceBar, columnOptions(),
		function(value) return table_.IsColumnVisible(value) end,
		function(value) table_.SetColumnVisible(value, not table_.IsColumnVisible(value)) end,
		columnsSummaryText, 150, "Show All Columns", showAllColumns)
	columnsDropdown:SetPoint("RIGHT", clearFiltersButton, "LEFT", -8, 0)

	ns.RefreshHistory()
end
