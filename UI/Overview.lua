local ns = WorthRemembering

local MIN_WIDTH, MIN_HEIGHT = 960, 480
-- size the window collapses to via the minimize button
local MINIMIZED_WIDTH, MINIMIZED_HEIGHT = 280, 56
local CONTENT_TOP = 68

-- right-click a Players row to delete that player's entire record, confirmed first
StaticPopupDialogs["WR_CONFIRM_DELETE_PLAYER"] = {
	text = "Delete all Worth Remembering notes and standing history for %s? This cannot be undone.",
	button1 = "Delete",
	button2 = "Cancel",
	OnAccept = function(self, key)
		ns.DeletePlayerRecord(key)
		ns.RefreshAllTabs()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

StaticPopupDialogs["WR_CONFIRM_DELETE_SELECTED_PLAYERS"] = {
	text = "Delete records for all %d selected player(s)? This cannot be undone.",
	button1 = "Delete",
	button2 = "Cancel",
	OnAccept = function(self, keys)
		for _, key in ipairs(keys) do
			ns.DeletePlayerRecord(key)
		end
		ns.ClearPlayerSelection()
		ns.RefreshAllTabs()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

StaticPopupDialogs["WR_CONFIRM_PRUNE_SHOWN"] = {
	text = "Delete records for all %d player(s) currently shown on the Players tab? This cannot be undone.",
	button1 = "Prune",
	button2 = "Cancel",
	OnAccept = function(self, keys)
		for _, key in ipairs(keys) do
			ns.DeletePlayerRecord(key)
		end
		ns.RefreshAllTabs()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

local mainFrame
local playersTable
local filterBar
local charBar
local classRaceBar
local search = ""
local currentCharOnly = false
local lastSeenInvert = false

-- multi-select state (Options > General): key -> true for each checked row. cleared
-- whenever the mode gets toggled off/on, or after a bulk delete removes those keys.
local selectedKeys = {}
local selectedCount = 0

local function setKeySelected(key, selected)
	if selected and not selectedKeys[key] then
		selectedKeys[key] = true
		selectedCount = selectedCount + 1
	elseif not selected and selectedKeys[key] then
		selectedKeys[key] = nil
		selectedCount = selectedCount - 1
	end
end

function ns.ClearPlayerSelection()
	wipe(selectedKeys)
	selectedCount = 0
	if playersTable then
		playersTable.Refresh()
	end
end

-- called from History's own Multi-Select checkbox so this tab's copy of the same
-- checkbox doesn't go stale until this tab happens to rebuild
function ns.SyncPlayersMultiSelectCheckbox(checked)
	if charBar and charBar.rightCheckbox then
		charBar.rightCheckbox:SetChecked(checked)
	end
end

-- every dropdown filter on this tab is multi-select, see ns.CreateFilterSet
local signFilter = ns.CreateFilterSet()
local characterFilter = ns.CreateFilterSet()
local lastSeenFilter = ns.CreateFilterSet()
local classFilter = ns.CreateFilterSet()
local raceFilter = ns.CreateFilterSet()
local factionFilter = ns.CreateFilterSet()
local bracketFilter = ns.CreateFilterSet()
local notesFilter = ns.CreateFilterSet()

local SIGN_OPTIONS = {
	{ value = "positive", text = "Positive" },
	{ value = "negative", text = "Negative" },
	{ value = "zero", text = "Zero" },
	{ value = "nonzero", text = "Non-zero" },
}

local NOTES_OPTIONS = {
	{ value = "noted", text = "Noted characters" },
	{ value = "unnoted", text = "Un-noted characters" },
	{ value = "featured", text = "Featured notes" },
	{ value = "unfeatured", text = "Un-featured notes" },
}

local LAST_SEEN_OPTIONS = {
	{ value = "hour", text = "Last hour" },
	{ value = "day", text = "Last day" },
	{ value = "week", text = "Last week" },
	{ value = "month", text = "Last month" },
	{ value = "year", text = "Last year" },
}
local LAST_SEEN_SECONDS = {
	hour = 3600,
	day = 86400,
	week = 7 * 86400,
	month = 30 * 86400,
	year = 365 * 86400,
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

local function getBracketOptions()
	local options = {}
	for _, bracketKey in ipairs(ns.BRACKET_KEY_ORDER) do
		options[#options + 1] = { value = bracketKey, text = (ns.GetBracketDisplay(bracketKey)) }
	end
	return options
end

-- display only, sort uses the raw timestamp (see sortValue below)
local function relativeDate(ts)
	local seconds = math.max(0, time() - ts)
	if seconds < 60 then
		return "just now"
	elseif seconds < 3600 then
		local minutes = math.floor(seconds / 60)
		return minutes .. (minutes == 1 and " minute ago" or " minutes ago")
	elseif seconds < 86400 then
		local hours = math.floor(seconds / 3600)
		return hours .. (hours == 1 and " hour ago" or " hours ago")
	elseif seconds < 7 * 86400 then
		local days = math.floor(seconds / 86400)
		return days .. (days == 1 and " day ago" or " days ago")
	elseif seconds < 30 * 86400 then
		local weeks = math.floor(seconds / (7 * 86400))
		return weeks .. (weeks == 1 and " week ago" or " weeks ago")
	elseif seconds < 365 * 86400 then
		local months = math.floor(seconds / (30 * 86400))
		return months .. (months == 1 and " month ago" or " months ago")
	end
	local years = math.floor(seconds / (365 * 86400))
	return years .. (years == 1 and " year ago" or " years ago")
end
ns.RelativeDate = relativeDate

local RELATIVE_UNITS = {
	{ seconds = 365 * 86400, word = "year" },
	{ seconds = 30 * 86400, word = "month" },
	{ seconds = 7 * 86400, word = "week" },
	{ seconds = 86400, word = "day" },
	{ seconds = 3600, word = "hour" },
	{ seconds = 60, word = "minute" },
	{ seconds = 1, word = "second" },
}

-- three units of precision instead of one, starting at the first non-zero unit and
-- always showing the next two after it, even if zero.
function ns.RelativeDatePrecise(ts)
	local seconds = math.max(0, time() - ts)
	if seconds < 60 then
		return "just now"
	end

	local values = {}
	local remaining = seconds
	for i, unit in ipairs(RELATIVE_UNITS) do
		values[i] = math.floor(remaining / unit.seconds)
		remaining = remaining % unit.seconds
	end

	local startIndex = #RELATIVE_UNITS
	for i, v in ipairs(values) do
		if v > 0 then
			startIndex = i
			break
		end
	end

	local parts = {}
	for i = startIndex, math.min(startIndex + 2, #RELATIVE_UNITS) do
		local n = values[i]
		parts[#parts + 1] = n .. " " .. RELATIVE_UNITS[i].word .. (n == 1 and "" or "s")
	end

	return table.concat(parts, ", ") .. " ago"
end

-- record.lastSeen reflects an actual nameplate sighting, see ns.TouchLastSeen. falls
-- back to the last logged entry's time if unset.
local function lastSeenTime(record)
	if record.lastSeen then
		return record.lastSeen
	end
	local lastEntry = record.entries[#record.entries]
	return lastEntry and lastEntry.time or nil
end

-- most recent entry with actual note text, not necessarily the last entry overall
local function lastNoteText(record)
	for i = #record.entries, 1, -1 do
		local entry = record.entries[i]
		if entry.text and entry.text ~= "" then
			return entry.text
		end
	end
	return nil
end

local function countNotes(record)
	local count = 0
	for _, entry in ipairs(record.entries) do
		if entry.text and entry.text ~= "" then
			count = count + 1
		end
	end
	return count
end

-- true if any entry was logged by a character currently selected in the filter
local function hasEntryFromCharacter(record)
	if currentCharOnly then
		local wantName = ns.GetMyFullName()
		for _, entry in ipairs(record.entries) do
			if entry.loggedBy == wantName then
				return true
			end
		end
		return false
	end
	for _, entry in ipairs(record.entries) do
		if characterFilter:Matches(entry.loggedBy) then
			return true
		end
	end
	return false
end

-- Matches if the record's standing satisfies ANY selected sign (e.g. "Positive" +
-- "Negative" selected together behaves like "Non-zero").
local function matchesSign(record)
	if signFilter.count == 0 then
		return true
	end
	local standing = record.standing or 0
	local selected = signFilter.selected
	return (selected.positive and standing > 0)
		or (selected.negative and standing < 0)
		or (selected.zero and standing == 0)
		or (selected.nonzero and standing ~= 0)
		or false
end

-- matches ANY selected notes criterion. "Un-featured" means has notes but none featured,
-- doesn't overlap with "Un-noted" (zero notes).
local function matchesNotes(record)
	if notesFilter.count == 0 then
		return true
	end
	local noteCount = countNotes(record)
	local hasFeatured = false
	for _, entry in ipairs(record.entries) do
		if entry.featured and entry.text and entry.text ~= "" then
			hasFeatured = true
			break
		end
	end
	local selected = notesFilter.selected
	return (selected.noted and noteCount > 0)
		or (selected.unnoted and noteCount == 0)
		or (selected.featured and hasFeatured)
		or (selected.unfeatured and noteCount > 0 and not hasFeatured)
		or false
end

-- Matches if the record's last-seen time falls within ANY selected window.
local function matchesLastSeen(record)
	if lastSeenFilter.count == 0 then
		return true
	end
	local seen = lastSeenTime(record)
	local withinAny = false
	for value in pairs(lastSeenFilter.selected) do
		if seen ~= nil and (time() - seen) <= LAST_SEEN_SECONDS[value] then
			withinAny = true
			break
		end
	end
	if lastSeenInvert then
		-- "Not seen in the last X": a record with no known last-seen time at all
		-- (e.g. a manually /wr noted player never spotted on-screen) counts as
		-- not-seen too, same as one whose last sighting falls outside every window.
		return not withinAny
	end
	return withinAny
end

-- comma-separated search terms act as "or": "sonaro, cowe" matches either name, not just
-- a single literal substring containing a comma. empty terms (from a trailing/doubled
-- comma) are skipped rather than matching everything.
local function matchesSearch(record, key)
	local name = ns.DisplayName(record, key):lower()
	for rawTerm in search:gmatch("[^,]+") do
		local term = rawTerm:match("^%s*(.-)%s*$")
		if term ~= "" and name:find(term, 1, true) then
			return true
		end
	end
	return false
end

local function matchesFilters(record, key)
	if search ~= "" and not matchesSearch(record, key) then
		return false
	end
	if not matchesSign(record) then
		return false
	end
	if not matchesNotes(record) then
		return false
	end
	if (currentCharOnly or characterFilter.count > 0) and not hasEntryFromCharacter(record) then
		return false
	end
	if not classFilter:Matches(record.classFile) then
		return false
	end
	if not raceFilter:Matches(ns.SimplifyRace(record.race)) then
		return false
	end
	if not factionFilter:Matches(record.faction) then
		return false
	end
	if not bracketFilter:Matches(ns.GetBracketKey(record.standing or 0)) then
		return false
	end
	if not matchesLastSeen(record) then
		return false
	end
	return true
end

local function hasActiveFilters()
	return search ~= ""
		or signFilter.count > 0
		or notesFilter.count > 0
		or currentCharOnly
		or characterFilter.count > 0
		or classFilter.count > 0
		or raceFilter.count > 0
		or factionFilter.count > 0
		or bracketFilter.count > 0
		or lastSeenFilter.count > 0
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

-- clears every Players-tab filter and syncs filter widgets back to "all". shared by
-- the "Clear Filters" button and every ns.FilterPlayersBy*() navigation setter.
local function resetAllPlayerFilters()
	search = ""
	signFilter:Clear()
	notesFilter:Clear()
	characterFilter:Clear()
	currentCharOnly = false
	lastSeenFilter:Clear()
	lastSeenInvert = false
	classFilter:Clear()
	raceFilter:Clear()
	factionFilter:Clear()
	bracketFilter:Clear()

	if filterBar then
		if filterBar.searchBox then
			filterBar.searchBox:SetText("")
		end
		if filterBar.dropdowns[1] then
			filterBar.dropdowns[1]:SetText(signFilter:SummaryText(SIGN_OPTIONS, "All standings"))
		end
		if filterBar.dropdowns[2] then
			filterBar.dropdowns[2]:SetText(bracketFilter:SummaryText(getBracketOptions(), "All brackets"))
		end
		if filterBar.dropdowns[3] then
			filterBar.dropdowns[3]:SetText(notesFilter:SummaryText(NOTES_OPTIONS, "Notes"))
		end
	end
	if charBar then
		if charBar.dropdowns[1] then
			charBar.dropdowns[1]:SetText(characterFilter:SummaryText(getCharacterOptions(), "All characters"))
		end
		if charBar.dropdowns[2] then
			charBar.dropdowns[2]:SetText(lastSeenFilter:SummaryText(LAST_SEEN_OPTIONS, "Any time"))
		end
		if charBar.checkboxes[1] then
			charBar.checkboxes[1]:SetChecked(false)
		end
		if charBar.checkboxes[2] then
			charBar.checkboxes[2]:SetChecked(false)
		end
	end
	syncClassRaceDropdowns()
end

-- click a Class/Race/Faction cell to filter to just that value, click the already-sole-
-- selected value again to clear it. stays in sync with the dropdowns above.
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
	ns.RefreshOverview()
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
	ns.RefreshOverview()
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
	ns.RefreshOverview()
end

-- click a Bracket cell to toggle just that bracket in the filter, clicking an
-- already-selected one clears it, same as every other click-to-filter column.
local function onBracketCellClick(item)
	bracketFilter:Toggle(ns.GetBracketKey(item.record.standing or 0))
	if filterBar and filterBar.dropdowns[2] then
		filterBar.dropdowns[2]:SetText(bracketFilter:SummaryText(getBracketOptions(), "All brackets"))
	end
	ns.RefreshOverview()
end

local COLUMNS = {
	{ key = "select", label = "", width = 26, min = 26, cellType = "checkbox", noSort = true,
		isVisible = function() return ns.GetSettings().multiSelectEnabled end,
		onCheckboxClick = function(item, checked) setKeySelected(item.key, checked) end },
	{ key = "name", label = "Name", width = 140, min = 100, onCellClick = function(item) ns.ShowPlayerDetails(item.key) end },
	{ key = "race", label = "Race", width = 90, min = 70, onCellClick = onRaceCellClick },
	{ key = "class", label = "Class", width = 90, min = 70, onCellClick = onClassCellClick },
	{ key = "faction", label = "Faction", width = 80, min = 60, onCellClick = onFactionCellClick },
	{ key = "standing", label = "Standing", width = 130, min = 100 },
	{ key = "bracket", label = "Bracket", width = 110, min = 80, onCellClick = onBracketCellClick },
	{ key = "entries", label = "Entries", width = 90, min = 50 },
	{ key = "notes", label = "Notes", width = 110, min = 90 },
	{ key = "seenCount", label = "Times Seen", width = 100, min = 60 },
	{ key = "lastSeen", label = "Last Seen", width = 130, min = 100 },
	{ key = "lastLocation", label = "Last Location", width = 120, min = 70 },
	{ key = "lastNote", label = "Last Note", width = 0 }, -- flex, always last
}

local function getItems()
	local list = {}
	for _, key in ipairs(ns.GetAllPlayerKeys()) do
		local record = ns.GetPlayerRecord(key, false)
		if ns.HasEntries(record) and matchesFilters(record, key) then
			list[#list + 1] = { key = key, record = record }
		end
	end
	return list
end

local PRUNE_TOOLTIP_ACTIVE = "Used to clean up your player database."
local PRUNE_TOOLTIP_DISABLED = "Select at least one filter before pruning. Otherwise, visit \"Options -> General -> Danger Zone\" to clear the entire database."

local function pruneShownPlayers()
	if not hasActiveFilters() then
		return
	end
	local items = getItems()
	if #items == 0 then
		return
	end
	local keys = {}
	for _, item in ipairs(items) do
		keys[#keys + 1] = item.key
	end
	StaticPopup_Show("WR_CONFIRM_PRUNE_SHOWN", #keys, nil, keys)
end

local function sortValue(item, key)
	if key == "name" then
		return ns.DisplayName(item.record, item.key):lower()
	elseif key == "standing" or key == "bracket" then
		return item.record.standing or 0
	elseif key == "class" then
		return ns.ClassDisplayName(item.record.classFile)
	elseif key == "race" then
		return ns.SimplifyRace(item.record.race) or ""
	elseif key == "faction" then
		return item.record.faction or ""
	elseif key == "entries" then
		return #item.record.entries
	elseif key == "notes" then
		return countNotes(item.record)
	elseif key == "seenCount" then
		return item.record.seenCount or 0
	elseif key == "lastSeen" then
		return lastSeenTime(item.record) or 0
	elseif key == "lastLocation" then
		return (item.record.lastLocation or ""):lower()
	else -- lastNote
		return (lastNoteText(item.record) or ""):lower()
	end
end

local function render(row, item)
	local record = item.record
	local cr, cg, cb = ns.ClassColor(record.classFile)

	row.cells.select.checkbox:SetChecked(selectedKeys[item.key] or false)

	-- optimistic: includes any pending +/- click not yet committed, see
	-- ns.QuickAdjustStanding
	local pending = ns.GetPendingAdjustment(item.key)
	local displayStanding = (record.standing or 0) + pending
	-- cumulative standing uses the reputation-bracket color (9 tiers), not the plain
	-- green/red/grey ns.StandingColor used for per-entry delta coloring
	local sr, sg, sb = unpack(ns.GetBracket(displayStanding).color)

	row.cells.name:SetText(ns.DisplayName(record, item.key))
	row.cells.name:SetTextColor(cr, cg, cb)

	row.cells.class:SetText(ns.ClassDisplayName(record.classFile))
	row.cells.class:SetTextColor(cr, cg, cb)
	row.cells.race:SetText(ns.SimplifyRace(record.race) or "-")

	local fr, fg, fb = ns.FactionColor(record.faction)
	row.cells.faction:SetText(record.faction or "-")
	row.cells.faction:SetTextColor(fr, fg, fb)

	row.cells.standing:SetText(displayStanding .. (pending ~= 0 and " *" or ""))
	row.cells.standing:SetTextColor(sr, sg, sb)

	row.cells.bracket:SetText(ns.GetBracket(displayStanding).name)
	row.cells.bracket:SetTextColor(sr, sg, sb)

	row.cells.entries:SetText(#record.entries)
	row.cells.notes:SetText(countNotes(record))
	row.cells.seenCount:SetText(record.seenCount or 0)

	local lastSeen = lastSeenTime(record)
	row.cells.lastSeen:SetText(lastSeen and relativeDate(lastSeen) or "-")
	row.cells.lastLocation:SetText(record.lastLocation or "-")
	row.cells.lastNote:SetText(lastNoteText(record) or "")

	-- inline +/- quick-adjust buttons after the Standing number, and a "New" entry
	-- button after the Notes count. cells span the row's full height (see Widgets.lua)
	-- so anchoring "LEFT" to one centers correctly.
	if not row.minusButton then
		-- the minus/plus pair rides on the Standing cell, so it's wrapped in one
		-- container frame and registered under row.cellButtons.standing: the table's
		-- generic column-visibility logic (see relayout() in Widgets.lua) hides/shows
		-- whatever's at row.cellButtons[col.key] right alongside the cell itself, on
		-- every toggle, not just the next full data refresh. registering each button
		-- directly under row.cellButtons.standing would only keep the last one (one
		-- slot per column key), hence the wrapper.
		row.standingButtons = CreateFrame("Frame", nil, row)
		row.standingButtons:SetPoint("LEFT", row.cells.standing, "LEFT", 36, 0)
		row.standingButtons:SetSize(42, 18)

		-- tinted via a colored overlay texture rather than a +/- icon asset.
		row.minusButton = CreateFrame("Button", nil, row.standingButtons, "UIPanelButtonTemplate")
		row.minusButton:SetSize(20, 18)
		row.minusButton:SetText("-")
		row.minusButton:SetPoint("LEFT", 0, 0)
		local minusTint = row.minusButton:CreateTexture(nil, "ARTWORK", nil, -1)
		minusTint:SetPoint("TOPLEFT", 3, -3)
		minusTint:SetPoint("BOTTOMRIGHT", -3, 3)
		minusTint:SetColorTexture(0.6, 0.18, 0.18, 0.65)

		row.plusButton = CreateFrame("Button", nil, row.standingButtons, "UIPanelButtonTemplate")
		row.plusButton:SetSize(20, 18)
		row.plusButton:SetText("+")
		row.plusButton:SetPoint("LEFT", row.minusButton, "RIGHT", 2, 0)
		local plusTint = row.plusButton:CreateTexture(nil, "ARTWORK", nil, -1)
		plusTint:SetPoint("TOPLEFT", 3, -3)
		plusTint:SetPoint("BOTTOMRIGHT", -3, 3)
		plusTint:SetColorTexture(0.2, 0.45, 0.2, 0.65)

		row.newButton = CreateFrame("Button", nil, row, "UIPanelButtonTemplate")
		row.newButton:SetSize(44, 18)
		row.newButton:SetText("New")
		row.newButton:SetPoint("LEFT", row.cells.notes, "LEFT", 26, 0)

		row.cellButtons.standing = row.standingButtons
		row.cellButtons.notes = row.newButton
	end
	-- re-bound every render since rows are reused across refreshes for different players
	row.minusButton:SetScript("OnClick", function()
		local amount = IsShiftKeyDown() and ns.GetSettings().shiftClickAmount or 1
		ns.QuickAdjustStanding(item.key, -amount)
	end)
	row.plusButton:SetScript("OnClick", function()
		local amount = IsShiftKeyDown() and ns.GetSettings().shiftClickAmount or 1
		ns.QuickAdjustStanding(item.key, amount)
	end)
	row.newButton:SetScript("OnClick", function() ns.ShowQuickAdd(item.key) end)
end

-- "Notable players" uses the strict ns.IsNotable count (a note or non-neutral standing).
-- "Total entries" counts literally every entry ever logged for anyone, including
-- auto-nearby-only players, so the two totals are tallied independently rather than one
-- being a byproduct of the other's loop.
-- `shownText`, when given, is a tab-specific third segment (e.g. "42 players shown" on
-- Players, "12 entries shown" on History). the "notable players" total before it is
-- account-wide regardless of tab. `totalText` overrides the middle segment (default
-- "N total entries"); Players passes "N total players" instead to stay comparable.
function ns.RefreshFooter(shownText, totalText)
	if not mainFrame then
		return
	end
	local totalPlayers, totalEntries = 0, 0
	for _, key in ipairs(ns.GetAllPlayerKeys()) do
		local record = ns.GetPlayerRecord(key, false)
		if record then
			totalEntries = totalEntries + #record.entries
			if ns.IsNotable(record) then
				totalPlayers = totalPlayers + 1
			end
		end
	end
	local text = totalPlayers .. " notable players  \124\124  " .. (totalText or (totalEntries .. " total entries"))
	if shownText then
		text = text .. "  \124\124  " .. shownText
	end
	mainFrame.footer:SetText(text)
end

function ns.RefreshOverview()
	if not (mainFrame and mainFrame:IsShown() and mainFrame.selectedTab == 1) then
		return
	end
	playersTable.Refresh()
	local shown = #getItems()
	-- counts distinct players (one row each), a different unit than the footer's
	-- "total entries" (every logged entry across everyone).
	local shownText = shown == 1 and "1 player" or (shown .. " players")
	filterBar.countLabel:SetText(shownText)

	if filterBar.actionButton then
		-- SetEnabled(false) also blocks OnEnter/OnLeave on this client, which would kill
		-- the tooltip explaining why it's disabled. dim via alpha instead and leave
		-- clicking itself a no-op (see pruneShownPlayers' own guard).
		local active = hasActiveFilters()
		filterBar.actionButton:SetAlpha(active and 1 or 0.4)
		ns.AttachTooltip(filterBar.actionButton, active and PRUNE_TOOLTIP_ACTIVE or PRUNE_TOOLTIP_DISABLED)
	end

	-- every player with at least one logged entry, not just "notable" ones, the same
	-- population "shown" is filtered down from.
	local totalWithEntries = 0
	for _, key in ipairs(ns.GetAllPlayerKeys()) do
		local record = ns.GetPlayerRecord(key, false)
		if record and ns.HasEntries(record) then
			totalWithEntries = totalWithEntries + 1
		end
	end
	local totalText = totalWithEntries == 1 and "1 total player" or (totalWithEntries .. " total players")
	ns.RefreshFooter(shownText .. " shown", totalText)
end

local function selectTab(index)
	mainFrame.playersContent:SetShown(index == 1)
	mainFrame.historyContent:SetShown(index == 2)
	mainFrame.detailsContent:SetShown(index == 3)
	mainFrame.statisticsContent:SetShown(index == 4)
	mainFrame.optionsContent:SetShown(index == 5)
	mainFrame.aboutContent:SetShown(index == 6)
	if index == 1 then
		ns.RefreshOverview()
	elseif index == 2 and ns.RefreshHistory then
		ns.RefreshHistory()
	else
		-- Details/Statistics/Options/About have no filtered list, footer's third
		-- segment is omitted while one of them is active.
		if index == 3 and ns.RefreshDetails then
			ns.RefreshDetails()
		elseif index == 4 and ns.RefreshStatistics then
			ns.RefreshStatistics()
		end
		ns.RefreshFooter()
	end
end

local function setTab(index)
	if PanelTemplates_SetTab then
		PanelTemplates_SetTab(mainFrame, index)
	end
	mainFrame.selectedTab = index
	selectTab(index)
end

local function createTabs()
	local tabDefs = { "Players", "History", "Details", "Statistics", "Options", "About" }
	local tabs = {}
	local prevTab
	for i, label in ipairs(tabDefs) do
		local tab = CreateFrame("Button", "WRFrameTab" .. i, mainFrame, "PanelTabButtonTemplate")
		tab:SetText(label)
		tab:SetID(i)
		if prevTab then
			tab:SetPoint("LEFT", prevTab, "RIGHT", -8, 0)
		else
			tab:SetPoint("TOPLEFT", 14, -36)
		end
		tab:SetScript("OnClick", function(self) setTab(self:GetID()) end)
		prevTab = tab
		tabs[i] = tab
	end

	if PanelTemplates_SetNumTabs then
		PanelTemplates_SetNumTabs(mainFrame, #tabDefs)
		PanelTemplates_SetTab(mainFrame, 1)
	else
		mainFrame.selectedTab = 1
	end

	return tabs
end

local function createPlayersContent()
	local content = CreateFrame("Frame", nil, mainFrame)
	content:SetPoint("TOPLEFT", 0, -CONTENT_TOP)
	content:SetPoint("BOTTOMRIGHT", 0, 44)
	mainFrame.playersContent = content

	filterBar = ns.CreateFilterBar(content, {
		search = { onChange = function(text) search = text; ns.RefreshOverview() end },
		dropdowns = {
			{
				multi = true,
				options = SIGN_OPTIONS,
				isSelected = function(value) return signFilter.selected[value] == true end,
				toggle = function(value) signFilter:Toggle(value); ns.RefreshOverview() end,
				getSummaryText = function() return signFilter:SummaryText(SIGN_OPTIONS, "All standings") end,
				clearText = "All standings",
				onClear = function() signFilter:Clear(); ns.RefreshOverview() end,
				width = 150,
			},
			{
				multi = true,
				options = getBracketOptions(),
				isSelected = function(value) return bracketFilter.selected[value] == true end,
				toggle = function(value) bracketFilter:Toggle(value); ns.RefreshOverview() end,
				getSummaryText = function() return bracketFilter:SummaryText(getBracketOptions(), "All brackets") end,
				clearText = "All brackets",
				onClear = function() bracketFilter:Clear(); ns.RefreshOverview() end,
				width = 220,
			},
			{
				multi = true,
				options = NOTES_OPTIONS,
				isSelected = function(value) return notesFilter.selected[value] == true end,
				toggle = function(value) notesFilter:Toggle(value); ns.RefreshOverview() end,
				getSummaryText = function() return notesFilter:SummaryText(NOTES_OPTIONS, "Notes") end,
				clearText = "Notes",
				onClear = function() notesFilter:Clear(); ns.RefreshOverview() end,
				width = 170,
			},
		},
		actionButton = { text = "Prune", width = 70, onClick = pruneShownPlayers },
	})
	filterBar:SetPoint("TOPLEFT", 12, -4)
	filterBar:SetPoint("TOPRIGHT", -12, -4)

	-- account-wide DB shared across your characters, lets you narrow the roster down
	-- to players noted by one (or just your current) character.
	charBar = ns.CreateFilterBar(content, {
		-- Ordered explicitly (character dropdown, its checkbox, last-seen dropdown, its
		-- checkbox) so each checkbox sits directly beside the control it modifies,
		-- rather than every dropdown grouping before every checkbox.
		items = {
			{
				type = "dropdown",
				multi = true,
				options = getCharacterOptions(),
				isSelected = function(value) return characterFilter.selected[value] == true end,
				toggle = function(value) characterFilter:Toggle(value); ns.RefreshOverview() end,
				getSummaryText = function() return characterFilter:SummaryText(getCharacterOptions(), "All characters") end,
				clearText = "All characters",
				onClear = function() characterFilter:Clear(); ns.RefreshOverview() end,
				width = 170,
			},
			{
				type = "checkbox",
				label = "Current character only",
				initial = currentCharOnly,
				onChange = function(checked) currentCharOnly = checked; ns.RefreshOverview() end,
			},
			{
				type = "dropdown",
				multi = true,
				options = LAST_SEEN_OPTIONS,
				isSelected = function(value) return lastSeenFilter.selected[value] == true end,
				toggle = function(value) lastSeenFilter:Toggle(value); ns.RefreshOverview() end,
				getSummaryText = function() return lastSeenFilter:SummaryText(LAST_SEEN_OPTIONS, "Any time") end,
				clearText = "Any time",
				onClear = function() lastSeenFilter:Clear(); ns.RefreshOverview() end,
				width = 140,
			},
			{
				type = "checkbox",
				label = "Invert (not seen)",
				initial = lastSeenInvert,
				onChange = function(checked) lastSeenInvert = checked; ns.RefreshOverview() end,
			},
		},
		rightCheckbox = {
			label = "Multi-Select",
			initial = ns.GetSettings().multiSelectEnabled,
			tooltip = "Adds a checkbox column for checking several rows at once. Right-click with more than one checked for a bulk delete option.",
			onChange = function(checked)
				ns.GetSettings().multiSelectEnabled = checked
				ns.ClearPlayerSelection()
				if ns.ClearHistorySelection then
					ns.ClearHistorySelection()
				end
				-- History has its own instance of this same checkbox on its own charBar;
				-- keep it in sync rather than leaving it stale until that tab rebuilds
				if ns.SyncHistoryMultiSelectCheckbox then
					ns.SyncHistoryMultiSelectCheckbox(checked)
				end
			end,
		},
	})
	charBar:SetPoint("TOPLEFT", 12, -34)
	charBar:SetPoint("TOPRIGHT", -12, -34)

	-- Explicit Class/Race/Faction dropdowns for the same state the table's click-to-filter
	-- cells control, kept in sync via syncClassRaceDropdowns.
	classRaceBar = ns.CreateFilterBar(content, {
		dropdowns = {
			{
				multi = true,
				options = getClassOptions(),
				isSelected = function(value) return classFilter.selected[value] == true end,
				toggle = function(value) classFilter:Toggle(value); syncClassRaceDropdowns(); ns.RefreshOverview() end,
				getSummaryText = function() return classFilter:SummaryText(getClassOptions(), "All classes") end,
				clearText = "All classes",
				onClear = function() classFilter:Clear(); syncClassRaceDropdowns(); ns.RefreshOverview() end,
				width = 140,
			},
			{
				multi = true,
				options = getRaceOptions(),
				isSelected = function(value) return raceFilter.selected[value] == true end,
				toggle = function(value) raceFilter:Toggle(value); syncClassRaceDropdowns(); ns.RefreshOverview() end,
				getSummaryText = function() return raceFilter:SummaryText(getRaceOptions(), "All races") end,
				clearText = "All races",
				onClear = function() raceFilter:Clear(); syncClassRaceDropdowns(); ns.RefreshOverview() end,
				width = 140,
			},
			{
				multi = true,
				options = FACTION_OPTIONS,
				isSelected = function(value) return factionFilter.selected[value] == true end,
				toggle = function(value) factionFilter:Toggle(value); syncClassRaceDropdowns(); ns.RefreshOverview() end,
				getSummaryText = function() return factionFilter:SummaryText(FACTION_OPTIONS, "All factions") end,
				clearText = "All factions",
				onClear = function() factionFilter:Clear(); syncClassRaceDropdowns(); ns.RefreshOverview() end,
				width = 130,
			},
		},
	})
	local clearFiltersButton = CreateFrame("Button", nil, classRaceBar, "UIPanelButtonTemplate")
	clearFiltersButton:SetSize(100, 20)
	clearFiltersButton:SetText("Clear Filters")
	clearFiltersButton:SetPoint("RIGHT", -8, 0)
	clearFiltersButton:SetScript("OnClick", function()
		resetAllPlayerFilters()
		ns.RefreshOverview()
	end)

	classRaceBar:SetPoint("TOPLEFT", 12, -64)
	classRaceBar:SetPoint("TOPRIGHT", -12, -64)

	playersTable = ns.CreateSortableTable(content, {
		tableId = "players",
		columns = COLUMNS,
		rowHeight = 22,
		getItems = getItems,
		sortValue = sortValue,
		render = render,
		onClick = function(item) ns.ShowPlayerDetails(item.key) end,
		onRightClick = function(item, rowFrame)
			MenuUtil.CreateContextMenu(rowFrame, function(_, rootDescription)
				local name = ns.DisplayName(item.record, item.key)
				rootDescription:CreateTitle(name)
				rootDescription:CreateButton("View Details", function() ns.ShowPlayerDetails(item.key) end)
				rootDescription:CreateButton("View Full History", function() ns.SelectHistoryTab(item.key) end)
				rootDescription:CreateButton("Add Entry", function() ns.ShowQuickAdd(item.key) end)
				rootDescription:CreateDivider()
				rootDescription:CreateButton("Delete Player Record", function()
					StaticPopup_Show("WR_CONFIRM_DELETE_PLAYER", name, nil, item.key)
				end)
				-- multi-select's own bulk option, only once there's actually a group
				-- worth acting on together; a single checked row is no different from
				-- just using the row's own delete button above.
				if selectedCount > 1 then
					local keys = {}
					for key in pairs(selectedKeys) do
						keys[#keys + 1] = key
					end
					rootDescription:CreateButton("Delete " .. #keys .. " Selected Players", function()
						StaticPopup_Show("WR_CONFIRM_DELETE_SELECTED_PLAYERS", #keys, nil, keys)
					end)
				end
			end)
		end,
		defaultSort = { key = "standing", dir = "desc" },
		pageSize = "auto",
	})
	playersTable.container:SetPoint("TOPLEFT", 12, -96)
	playersTable.container:SetPoint("BOTTOMRIGHT", -12, 0)

	local function columnOptions()
		local opts = {}
		for _, col in ipairs(COLUMNS) do
			if playersTable.IsColumnHideable(col.key) then
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
			if playersTable.IsColumnHideable(col.key) then
				playersTable.SetColumnVisible(col.key, true)
			end
		end
	end

	local columnsDropdown = ns.CreateMultiSelectDropdown(classRaceBar, columnOptions(),
		function(value) return playersTable.IsColumnVisible(value) end,
		function(value) playersTable.SetColumnVisible(value, not playersTable.IsColumnVisible(value)) end,
		columnsSummaryText, 150, "Show All Columns", showAllColumns)
	columnsDropdown:SetPoint("RIGHT", clearFiltersButton, "LEFT", -8, 0)
end

-- window position/size are saved on every move/resize and restored at creation,
-- plain WoW frames don't persist this on their own.
local function savePosition()
	local settings = ns.GetSettings()
	local point, _, relativePoint, x, y = mainFrame:GetPoint()
	settings.windowPoint, settings.windowRelativePoint, settings.windowX, settings.windowY = point, relativePoint, x, y
end

local function saveSize()
	local settings = ns.GetSettings()
	settings.windowWidth, settings.windowHeight = mainFrame:GetSize()
end

-- SetClampedToScreen only enforces during an interactive move/resize, not on a scale
-- change. Shrinks stored size first, then repositions: once scaled size exceeds the
-- screen outright, no translation satisfies both edges at once, it just swaps which
-- edge is off-screen.
function ns.ReclampMainFrame()
	if not mainFrame then
		return
	end

	local scale = mainFrame:GetScale()
	local width, height = mainFrame:GetSize()
	local maxWidth = UIParent:GetWidth() / scale
	local maxHeight = UIParent:GetHeight() / scale
	local newWidth = math.max(MIN_WIDTH, math.min(width, maxWidth))
	local newHeight = math.max(MIN_HEIGHT, math.min(height, maxHeight))
	if newWidth ~= width or newHeight ~= height then
		mainFrame:SetSize(newWidth, newHeight)
		saveSize()
	end

	local left, right = mainFrame:GetLeft(), mainFrame:GetRight()
	local bottom, top = mainFrame:GetBottom(), mainFrame:GetTop()
	if not (left and right and bottom and top) then
		return
	end

	local dx, dy = 0, 0
	if right > UIParent:GetWidth() then
		dx = UIParent:GetWidth() - right
	end
	if left + dx < 0 then
		dx = -left
	end
	if top > UIParent:GetHeight() then
		dy = UIParent:GetHeight() - top
	end
	if bottom + dy < 0 then
		dy = -bottom
	end

	if dx ~= 0 or dy ~= 0 then
		local x, y = left + dx, top + dy
		mainFrame:ClearAllPoints()
		mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, y)
		savePosition()
	end
end

local resizing = false
local resizeStartX, resizeStartY, resizeStartWidth, resizeStartHeight

local function createResizeGrip()
	local grip = CreateFrame("Button", nil, mainFrame)
	grip:SetSize(16, 16)
	grip:SetPoint("BOTTOMRIGHT", -4, 4)
	grip:SetNormalTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up")
	grip:SetHighlightTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Highlight")
	grip:SetPushedTexture("Interface/ChatFrame/UI-ChatIM-SizeGrabber-Down")
	-- hand-rolled instead of StartSizing, whose cursor-delta math breaks under this
	-- frame's configurable SetScale, turning a small drag into an instant huge resize
	-- (see the identical fix in NearbyWindow.lua).
	grip:SetScript("OnMouseDown", function()
		local left, top = mainFrame:GetLeft(), mainFrame:GetTop()
		mainFrame:ClearAllPoints()
		mainFrame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", left, top)

		resizing = true
		local scale = mainFrame:GetEffectiveScale()
		local x, y = GetCursorPosition()
		resizeStartX, resizeStartY = x / scale, y / scale
		resizeStartWidth, resizeStartHeight = mainFrame:GetWidth(), mainFrame:GetHeight()
	end)
	grip:SetScript("OnUpdate", function()
		if not resizing then
			return
		end
		local scale = mainFrame:GetEffectiveScale()
		local x, y = GetCursorPosition()
		x, y = x / scale, y / scale
		local newWidth = math.max(MIN_WIDTH, math.min(UIParent:GetWidth(), resizeStartWidth + (x - resizeStartX)))
		local newHeight = math.max(MIN_HEIGHT, math.min(UIParent:GetHeight(), resizeStartHeight - (y - resizeStartY)))
		mainFrame:SetSize(newWidth, newHeight)
	end)
	grip:SetScript("OnMouseUp", function()
		resizing = false
		saveSize()
	end)
	return grip
end

local function createMainFrame()
	mainFrame = CreateFrame("Frame", "WRFrame", UIParent, "BackdropTemplate")
	-- Lets Escape close this window, like Blizzard's own panels.
	tinsert(UISpecialFrames, "WRFrame")

	local settings = ns.GetSettings()
	-- clamp to both bounds, not just the minimum, so a size saved before a later
	-- version raised MIN_WIDTH/HEIGHT or from a bad resize doesn't persist out of range.
	local savedWidth = math.max(settings.windowWidth or MIN_WIDTH, MIN_WIDTH)
	local savedHeight = math.max(settings.windowHeight or MIN_HEIGHT, MIN_HEIGHT)
	mainFrame:SetSize(math.min(savedWidth, UIParent:GetWidth()), math.min(savedHeight, UIParent:GetHeight()))
	if settings.windowPoint then
		mainFrame:SetPoint(settings.windowPoint, UIParent, settings.windowRelativePoint or settings.windowPoint, settings.windowX, settings.windowY)
	else
		mainFrame:SetPoint("CENTER")
	end
	-- plain frames default to MEDIUM strata, same as many unit-frame/HUD addons, so
	-- without this a dialog-style window can end up drawn behind them.
	mainFrame:SetFrameStrata("HIGH")
	mainFrame:SetToplevel(true)
	mainFrame:SetMovable(true)
	mainFrame:SetResizable(true)
	mainFrame:SetClampedToScreen(true)
	-- a max bound matters too: without it a resize-grip drag from an odd cursor/frame
	-- offset can jump to an enormous size in one motion.
	local maxWidth, maxHeight = UIParent:GetWidth(), UIParent:GetHeight()
	if mainFrame.SetResizeBounds then
		mainFrame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT, maxWidth, maxHeight)
	else
		mainFrame:SetMinResize(MIN_WIDTH, MIN_HEIGHT)
		mainFrame:SetMaxResize(maxWidth, maxHeight)
	end
	mainFrame:EnableMouse(true)
	mainFrame:RegisterForDrag("LeftButton")
	mainFrame:SetScript("OnDragStart", mainFrame.StartMoving)
	mainFrame:SetScript("OnDragStop", function()
		mainFrame:StopMovingOrSizing()
		savePosition()
	end)
	-- Border only, no bgFile: a tooltip-style bgFile stays slightly translucent even at
	-- full backdrop-color alpha, so opacity comes entirely from the separate fill
	-- texture below instead.
	mainFrame:SetBackdrop({
		edgeFile = "Interface/DialogFrame/UI-DialogBox-Border",
		edgeSize = 32,
		insets = { left = 11, right = 12, top = 12, bottom = 11 },
	})
	-- untinted, this border reads as plain stone gray. gold matches the rest of the
	-- addon's accent color (tab borders, scrollbar divider, etc).
	mainFrame:SetBackdropBorderColor(0.85, 0.68, 0.3, 1)
	mainFrame:SetAlpha(ns.GetSettings().windowAlpha)
	mainFrame:SetScale(ns.GetSettings().uiScale)
	mainFrame:Hide()
	-- self-heals a saved position/size/scale combo from before ns.ReclampMainFrame
	-- existed that would otherwise load already hanging off the bottom of the screen
	ns.ReclampMainFrame()

	-- top/right/bottom pulled in a few px less than the backdrop's own declared insets:
	-- at those insets exactly, a thin sliver of whatever's behind the window showed
	-- through between the border art and this fill (left wasn't affected, left alone)
	local fill = mainFrame:CreateTexture(nil, "BACKGROUND", nil, -8)
	fill:SetPoint("TOPLEFT", 11, -9)
	fill:SetPoint("BOTTOMRIGHT", -9, 8)
	fill:SetColorTexture(0.1, 0.08, 0.06, 1)

	-- Banded header/footer: flat color fills (no texture assets needed) so the title bar
	-- and status footer read as distinct bands from the body. The header covers only the
	-- title row, not the tabs below it.
	local headerBand = mainFrame:CreateTexture(nil, "BACKGROUND", nil, -4)
	headerBand:SetPoint("TOPLEFT", 14, -12)
	headerBand:SetPoint("TOPRIGHT", -14, -12)
	headerBand:SetHeight(22)
	headerBand:SetColorTexture(0.42, 0.3, 0.14, 1)

	local footerBand = mainFrame:CreateTexture(nil, "BACKGROUND", nil, -4)
	footerBand:SetPoint("BOTTOMLEFT", 14, 12)
	footerBand:SetPoint("BOTTOMRIGHT", -14, 12)
	footerBand:SetHeight(22)
	footerBand:SetColorTexture(0.42, 0.3, 0.14, 1)

	-- stock Blizzard art (Achievement UI's parchment grain), not custom, laid over the
	-- flat band color as a subtle texture instead of a flat fill.
	local headerGrain = mainFrame:CreateTexture(nil, "BACKGROUND", nil, -3)
	headerGrain:SetAllPoints(headerBand)
	headerGrain:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
	headerGrain:SetVertexColor(0.75, 0.6, 0.35, 0.75)

	local footerGrain = mainFrame:CreateTexture(nil, "BACKGROUND", nil, -3)
	footerGrain:SetAllPoints(footerBand)
	footerGrain:SetTexture("Interface\\AchievementFrame\\UI-Achievement-Parchment-Horizontal")
	footerGrain:SetVertexColor(0.75, 0.6, 0.35, 0.75)

	local title = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOP", 0, -14)
	title:SetText("Worth Remembering")

	-- both close and minimize use the same plain UIPanelButtonTemplate at the same size
	-- so they line up off each other. UIPanelCloseButton's hit-box padding doesn't match
	-- its visible X glyph, which misaligns anchoring relative to it.
	local close = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
	close:SetSize(20, 20)
	-- The header band spans TOPLEFT(14,-12) to TOPRIGHT(-14,-12) at height 22 (see above);
	-- this keeps both buttons vertically centered inside it instead of straddling its top
	-- edge, and inset from its right edge instead of overhanging the window's own border.
	close:SetPoint("TOPRIGHT", -18, -13)
	close:SetText("X")
	close:SetScript("OnClick", function() mainFrame:Hide() end)

	local minimizeButton = CreateFrame("Button", nil, mainFrame, "UIPanelButtonTemplate")
	minimizeButton:SetSize(20, 20)
	minimizeButton:SetPoint("RIGHT", close, "LEFT", -4, 0)
	minimizeButton:SetText("_")

	-- dark text, not the usual light GameFontDisableSmall gray, since it sits on the
	-- light gold footer band, gray-on-gold read as low contrast.
	mainFrame.footer = mainFrame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	mainFrame.footer:SetPoint("BOTTOMLEFT", 20, 18)
	mainFrame.footer:SetTextColor(0.06, 0.04, 0.02, 1)
	-- GameFontNormalSmall's baked-in dark shadow is meant for light text on a dark
	-- background; with dark text on this band it just reads as smudged. Clear it.
	mainFrame.footer:SetShadowOffset(0, 0)
	mainFrame.footer:SetText("")

	local tabButtons = createTabs()
	createPlayersContent()

	mainFrame.historyContent = CreateFrame("Frame", nil, mainFrame)
	mainFrame.historyContent:SetPoint("TOPLEFT", 0, -CONTENT_TOP)
	mainFrame.historyContent:SetPoint("BOTTOMRIGHT", 0, 44)
	mainFrame.historyContent:Hide()
	if ns.BuildHistoryPanel then
		ns.BuildHistoryPanel(mainFrame.historyContent)
	end

	mainFrame.detailsContent = CreateFrame("Frame", nil, mainFrame)
	mainFrame.detailsContent:SetPoint("TOPLEFT", 0, -CONTENT_TOP)
	mainFrame.detailsContent:SetPoint("BOTTOMRIGHT", 0, 44)
	mainFrame.detailsContent:Hide()
	if ns.BuildDetailsPanel then
		ns.BuildDetailsPanel(mainFrame.detailsContent)
	end

	mainFrame.statisticsContent = CreateFrame("Frame", nil, mainFrame)
	mainFrame.statisticsContent:SetPoint("TOPLEFT", 0, -CONTENT_TOP)
	mainFrame.statisticsContent:SetPoint("BOTTOMRIGHT", 0, 44)
	mainFrame.statisticsContent:Hide()
	if ns.BuildStatisticsPanel then
		ns.BuildStatisticsPanel(mainFrame.statisticsContent)
	end

	mainFrame.optionsContent = CreateFrame("Frame", nil, mainFrame)
	mainFrame.optionsContent:SetPoint("TOPLEFT", 0, -CONTENT_TOP)
	mainFrame.optionsContent:SetPoint("BOTTOMRIGHT", 0, 44)
	mainFrame.optionsContent:Hide()
	if ns.BuildOptionsPanel then
		ns.BuildOptionsPanel(mainFrame.optionsContent)
	end

	mainFrame.aboutContent = CreateFrame("Frame", nil, mainFrame)
	mainFrame.aboutContent:SetPoint("TOPLEFT", 0, -CONTENT_TOP)
	mainFrame.aboutContent:SetPoint("BOTTOMRIGHT", 0, 44)
	mainFrame.aboutContent:Hide()
	if ns.BuildAboutPanel then
		ns.BuildAboutPanel(mainFrame.aboutContent)
	end

	local resizeGrip = createResizeGrip()

	-- collapses the window to a small draggable title bar, for getting it out of the
	-- way without closing it outright. session-only, window always opens expanded.
	local minimized = false
	local expandedWidth, expandedHeight

	local function setMinimized(min)
		minimized = min
		mainFrame.isMinimized = min
		mainFrame:SetResizable(not min)
		resizeGrip:SetShown(not min)
		for _, tab in ipairs(tabButtons) do
			tab:SetShown(not min)
		end
		footerBand:SetShown(not min)
		mainFrame.footer:SetShown(not min)

		if min then
			expandedWidth, expandedHeight = mainFrame:GetSize()
			mainFrame.playersContent:Hide()
			mainFrame.historyContent:Hide()
			mainFrame.detailsContent:Hide()
			mainFrame.statisticsContent:Hide()
			mainFrame.optionsContent:Hide()
			mainFrame.aboutContent:Hide()
			mainFrame:SetSize(MINIMIZED_WIDTH, MINIMIZED_HEIGHT)
			minimizeButton:SetText("+")
		else
			mainFrame:SetSize(expandedWidth or MIN_WIDTH, expandedHeight or MIN_HEIGHT)
			selectTab(mainFrame.selectedTab or 1)
			minimizeButton:SetText("_")
		end
	end

	minimizeButton:SetScript("OnClick", function() setMinimized(not minimized) end)
	mainFrame.SetMinimized = setMinimized

	mainFrame:SetScript("OnShow", function()
		if not minimized then
			selectTab(mainFrame.selectedTab or 1)
		end
	end)
end

function ns.EnsureMainFrame()
	if not mainFrame then
		createMainFrame()
	end
	return mainFrame
end

-- lets other tabs' Refresh* functions check whether they're the one on screen before
-- touching shared chrome like the footer, since those run on every ns.RefreshAllTabs()
-- call, not just while that tab is visible.
function ns.GetSelectedTab()
	return mainFrame and mainFrame.selectedTab
end

function ns.ToggleOverview()
	local f = ns.EnsureMainFrame()
	f:SetShown(not f:IsShown())
end

function ns.ShowOverview()
	ns.EnsureMainFrame():Show()
end

-- A minimized window hides every tab's content frame; navigating to a specific tab
-- while minimized would otherwise force that content visible again inside the
-- collapsed pill without restoring the rest of the window around it.
local function restoreIfMinimized()
	if mainFrame and mainFrame.isMinimized then
		mainFrame.SetMinimized(false)
	end
end

-- Used by the context menu/slash commands so opening a quick-add popup always starts
-- from the Players tab, even if History was last active.
function ns.SelectPlayersTab()
	ns.EnsureMainFrame()
	ns.ShowOverview()
	restoreIfMinimized()
	if mainFrame.selectedTab ~= 1 then
		setTab(1)
	end
end

-- Used by the quick-add popup's "View Full History" link.
function ns.SelectHistoryTab(key)
	ns.EnsureMainFrame()
	ns.ShowOverview()
	restoreIfMinimized()
	if mainFrame.selectedTab ~= 2 then
		setTab(2)
	end
	if key and ns.FilterHistoryByPlayer then
		ns.FilterHistoryByPlayer(key)
	end
end

-- Used by ns.ShowPlayerDetails (Players tab name click) and the quick-add popup.
function ns.SelectDetailsTab()
	ns.EnsureMainFrame()
	ns.ShowOverview()
	restoreIfMinimized()
	if mainFrame.selectedTab ~= 3 then
		setTab(3)
	end
end

-- Used by the minimap button's right-click menu.
function ns.SelectOptionsTab()
	ns.EnsureMainFrame()
	ns.ShowOverview()
	restoreIfMinimized()
	if mainFrame.selectedTab ~= 5 then
		setTab(5)
	end
end

-- deep-links from Statistics. each sets exactly the one filter named, leaves the rest
-- untouched, then jumps to the Players tab.

function ns.FilterPlayersByClass(classFile)
	resetAllPlayerFilters()
	classFilter:Set(classFile)
	syncClassRaceDropdowns()
	ns.SelectPlayersTab()
	ns.RefreshOverview()
end

function ns.FilterPlayersByRace(race)
	resetAllPlayerFilters()
	raceFilter:Set(race)
	syncClassRaceDropdowns()
	ns.SelectPlayersTab()
	ns.RefreshOverview()
end

function ns.FilterPlayersByFaction(faction)
	resetAllPlayerFilters()
	factionFilter:Set(faction)
	syncClassRaceDropdowns()
	ns.SelectPlayersTab()
	ns.RefreshOverview()
end

function ns.FilterPlayersByCharacter(name)
	resetAllPlayerFilters()
	characterFilter:Set(name)
	if charBar and charBar.dropdowns[1] then
		charBar.dropdowns[1]:SetText(characterFilter:SummaryText(getCharacterOptions(), "All characters"))
	end
	ns.SelectPlayersTab()
	ns.RefreshOverview()
end

function ns.FilterPlayersByBracket(bracketKey)
	resetAllPlayerFilters()
	bracketFilter:Set(bracketKey)
	if filterBar and filterBar.dropdowns[2] then
		filterBar.dropdowns[2]:SetText(bracketFilter:SummaryText(getBracketOptions(), "All brackets"))
	end
	ns.SelectPlayersTab()
	ns.RefreshOverview()
end

-- `names` is a plain array of full display names (e.g. an LFG listing's roster); joined
-- into the same comma-separated search the box itself accepts, so either source lands on
-- identical filter state.
function ns.FilterPlayersByNames(names)
	resetAllPlayerFilters()
	search = table.concat(names, ","):lower()
	if filterBar and filterBar.searchBox then
		filterBar.searchBox:SetText(table.concat(names, ", "))
	end
	ns.SelectPlayersTab()
	ns.RefreshOverview()
end

-- refreshes every tab's display after any data change (add/edit/delete an entry or a
-- whole player record).
function ns.RefreshAllTabs()
	ns.RefreshOverview()
	if ns.RefreshHistory then
		ns.RefreshHistory()
	end
	if ns.RefreshDetails then
		ns.RefreshDetails()
	end
	if ns.RefreshStatistics then
		ns.RefreshStatistics()
	end
	if ns.RefreshNearbyWindow then
		ns.RefreshNearbyWindow()
	end
	if ns.RefreshNameplateIcons then
		ns.RefreshNameplateIcons()
	end
end
