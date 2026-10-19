local ns = WorthRemembering

local panel
local table_
local detailsKey

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
	{ key = "time", label = "Time", width = 130, min = 90 },
	{ key = "character", label = "Character", width = 110, min = 60 },
	{ key = "source", label = "Source", width = 60, min = 50 },
	{ key = "delta", label = "+/-", width = 50, min = 30 },
	{ key = "yourLevel", label = "Your Lvl", width = 82, min = 50 },
	{ key = "theirLevel", label = "Their Lvl", width = 86, min = 50 },
	{ key = "zone", label = "Zone", width = 110, min = 60 },
	{ key = "note", label = "Note", width = 0, flex = true },
	{ key = "featured", label = "Featured", width = 60, min = 50, cellType = "checkbox", onCheckboxClick = onFeaturedCheckboxClick },
}

local function getItems()
	local record = detailsKey and ns.GetPlayerRecord(detailsKey, false)
	if not record then
		return {}
	end
	local list = {}
	for _, entry in ipairs(record.entries) do
		list[#list + 1] = { entry = entry }
	end
	return list
end

local function sortValue(item, key)
	if key == "character" then
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
	local entry = item.entry
	row.cells.time:SetText(ns.FormatTime(entry.time))
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

local function refresh()
	-- The Details panel is only built once the main window has been shown at least
	-- once; every AddEntry refreshes every tab, so bail out if this fires first
	-- (e.g. /wrnote's quick-add, never opens the main window)
	if not panel then
		return
	end

	local record = detailsKey and ns.GetPlayerRecord(detailsKey, false)
	panel.newEntryButton:SetShown(record ~= nil)
	panel.deleteButton:SetShown(record ~= nil)
	-- "Select a player" links back to the Players tab, since that's the only place to
	-- act on it from here; a real player's name shouldn't double as a navigation link.
	panel.nameButton:SetShown(record == nil)
	if not record then
		panel.name:SetText("Select a player")
		panel.name:SetTextColor(1, 0.82, 0)
		panel.subline:SetText("")
		panel.statsLine1:SetText("")
		panel.featuredNote:SetText("")
		panel.statsLine2:SetText("")
		panel.statsLine3Prefix:SetText("")
		panel.statsLine3Time:SetText("")
		panel.statsLine3Suffix:SetText("")
		panel.statsLine3:SetWidth(1)
		panel.statsLine3Hover:Hide()
		panel.classIcon:Hide()
		panel.factionIcon:Hide()
		table_.Refresh()
		return
	end

	local cr, cg, cb = ns.ClassColor(record.classFile)
	local fr, fg, fb = ns.FactionColor(record.faction)
	local bracket = ns.GetBracket(record.standing or 0)

	panel.name:SetText(ns.DisplayName(record, detailsKey))
	panel.name:SetTextColor(cr, cg, cb)

	local race = ns.SimplifyRace(record.race) or "Unknown race"
	local class = ns.ClassDisplayName(record.classFile)
	local faction = record.faction or "Unknown faction"
	local classHex = ns.ToHex(cr, cg, cb)
	local pipe = "|c" .. ns.ToHex(1, 0.82, 0) .. "\124\124|r"
	panel.subline:SetText("|c" .. classHex .. race .. "|r  |c" .. classHex .. class .. "|r  " .. pipe .. "  |c" .. ns.ToHex(fr, fg, fb) .. faction .. "|r")

	if CLASS_ICON_TCOORDS[record.classFile] then
		panel.classIcon:SetTexCoord(unpack(CLASS_ICON_TCOORDS[record.classFile]))
		panel.classIcon:Show()
	else
		panel.classIcon:Hide()
	end
	if record.faction == "Horde" or record.faction == "Alliance" then
		panel.factionIcon:SetTexCoord(0, 1, 0, 1)
		panel.factionIcon:SetAtlas("UI-HUD-UnitFrame-Player-PVP-" .. record.faction .. "Icon", false, nil, true)
		panel.factionIcon:Show()
	else
		panel.factionIcon:Hide()
	end

	local noteCount = 0
	for _, entry in ipairs(record.entries) do
		if entry.text and entry.text ~= "" then
			noteCount = noteCount + 1
		end
	end

	local entryCount = #record.entries
	local entryWord = entryCount == 1 and " entry" or " entries"
	local noteWord = noteCount == 1 and " note" or " notes"
	local seenCount = record.seenCount or 0
	local seenWord = seenCount == 1 and " time" or " times"
	panel.statsLine1:SetText("Standing: |c" .. ns.ToHex(unpack(bracket.color)) .. (record.standing or 0) .. " (" .. bracket.name .. ")|r")

	-- Re-rolled on every refresh (not just when the player changes), so switching to
	-- another tab and back re-randomizes it, same as walking away and coming back.
	local candidates = {}
	for _, entry in ipairs(record.entries) do
		if entry.featured and entry.text and entry.text ~= "" then
			candidates[#candidates + 1] = entry
		end
	end
	local chosen = candidates[1] and candidates[math.random(#candidates)] or nil
	panel.featuredNote:SetText(chosen and ("\"" .. chosen.text .. "\"") or "")

	panel.statsLine2:SetText(entryCount .. entryWord .. "   \124\124   " .. noteCount .. noteWord
		.. "   \124\124   seen " .. seenCount .. seenWord)

	-- lastSeen is from an actual nameplate sighting. records predating that, or never
	-- seen on-screen, fall back to the last logged entry's time. lastLocation only
	-- exists going forward, older records won't have one until seen again
	local lastSeen = record.lastSeen or (record.entries[#record.entries] and record.entries[#record.entries].time)
	if lastSeen then
		local location = record.lastLocation
		panel.statsLine3Prefix:SetText("Last seen ")
		panel.statsLine3Time:SetText(ns.RelativeDatePrecise(lastSeen))
		panel.statsLine3Suffix:SetText((location and location ~= "") and (" in " .. location) or "")
		ns.AttachTooltip(panel.statsLine3Hover, ns.FormatTime(lastSeen))
		panel.statsLine3Hover:Show()
	else
		panel.statsLine3Prefix:SetText("Never seen")
		panel.statsLine3Time:SetText("")
		panel.statsLine3Suffix:SetText("")
		panel.statsLine3Hover:Hide()
	end
	panel.statsLine3:SetWidth(math.max(1, panel.statsLine3Prefix:GetStringWidth()
		+ panel.statsLine3Time:GetStringWidth() + panel.statsLine3Suffix:GetStringWidth()))

	table_.Refresh()
end
ns.RefreshDetails = refresh

function ns.ShowPlayerDetails(key)
	detailsKey = key
	ns.ShowOverview()
	ns.SelectDetailsTab()
	refresh()
end

function ns.BuildDetailsPanel(parent)
	panel = {}

	-- extra top gap plus centered name/icons/stats, reads like a character sheet rather
	-- than a table
	panel.name = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
	panel.name:SetPoint("TOP", parent, "TOP", 0, -26)
	panel.name:SetFont(select(1, panel.name:GetFont()), 22, "OUTLINE")
	panel.name:SetText("Select a player")
	panel.name:SetTextColor(1, 0.82, 0)

	-- clickable only while showing the placeholder, see refresh()
	panel.nameButton = CreateFrame("Button", nil, parent)
	panel.nameButton:SetAllPoints(panel.name)
	panel.nameButton:SetScript("OnClick", function() ns.SelectPlayersTab() end)
	local nameHighlight = panel.nameButton:CreateTexture(nil, "HIGHLIGHT")
	nameHighlight:SetAllPoints()
	nameHighlight:SetColorTexture(1, 0.82, 0, 0.15)

	-- flanks the name rather than inline below. Blizzard has class/faction icon atlases
	-- but nothing for race, so race stays as colored text in the subline
	panel.classIcon = parent:CreateTexture(nil, "ARTWORK")
	panel.classIcon:SetSize(28, 28)
	panel.classIcon:SetTexture("Interface\\TargetingFrame\\UI-Classes-Circles")
	panel.classIcon:SetPoint("RIGHT", panel.name, "LEFT", -10, 0)

	-- atlas confirmed via EllesmereUI's nameplate faction badges. earlier guesses (raw
	-- PvP shield, groupfinder atlas, character-create crest) were each wrong
	panel.factionIcon = parent:CreateTexture(nil, "ARTWORK")
	panel.factionIcon:SetSize(35, 35)
	panel.factionIcon:SetPoint("LEFT", panel.name, "RIGHT", 6, -1)

	panel.subline = parent:CreateFontString(nil, "ARTWORK", "GameFontHighlightLarge")
	panel.subline:SetPoint("TOP", panel.name, "BOTTOM", 0, -6)

	panel.statsLine1 = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	panel.statsLine1:SetPoint("TOP", panel.subline, "BOTTOM", 0, -10)

	-- random featured note text, between standing and entries/notes/seen. fixed height
	-- so layout doesn't shift when nothing's featured
	panel.featuredNote = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	-- this client errors on an unrecognized SetFont flag instead of ignoring it, which
	-- silently aborted the rest of BuildDetailsPanel. pcall and fall back to upright text
	if not pcall(panel.featuredNote.SetFont, panel.featuredNote, select(1, panel.featuredNote:GetFont()), 14, "ITALIC") then
		panel.featuredNote:SetFont(select(1, panel.featuredNote:GetFont()), 14)
	end
	panel.featuredNote:SetTextColor(0.75, 0.75, 0.75)
	panel.featuredNote:SetHeight(14)
	panel.featuredNote:SetPoint("TOP", panel.statsLine1, "BOTTOM", 0, -8)

	-- Entries/notes/seen count: between the standing line's size and the last-seen line's.
	panel.statsLine2 = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	panel.statsLine2:SetFont(select(1, panel.statsLine2:GetFont()), 14)
	panel.statsLine2:SetPoint("TOP", panel.featuredNote, "BOTTOM", 0, -8)

	-- three pieces, not one FontString, so hover can be scoped to just the relative-time
	-- part. container sized to the sum of all three widths each refresh so the line
	-- still reads centered
	panel.statsLine3 = CreateFrame("Frame", nil, parent)
	panel.statsLine3:SetPoint("TOP", panel.statsLine2, "BOTTOM", 0, -10)
	panel.statsLine3:SetHeight(14)

	panel.statsLine3Prefix = panel.statsLine3:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	panel.statsLine3Prefix:SetPoint("LEFT", 0, 0)

	panel.statsLine3Time = panel.statsLine3:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	panel.statsLine3Time:SetPoint("LEFT", panel.statsLine3Prefix, "RIGHT", 0, 0)

	panel.statsLine3Suffix = panel.statsLine3:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	panel.statsLine3Suffix:SetPoint("LEFT", panel.statsLine3Time, "RIGHT", 0, 0)

	-- Hovering just the relative-time piece reveals the exact timestamp as a tooltip,
	-- instead of cluttering the line itself with it.
	panel.statsLine3Hover = CreateFrame("Frame", nil, parent)
	panel.statsLine3Hover:SetAllPoints(panel.statsLine3Time)
	panel.statsLine3Hover:EnableMouse(true)

	local divider = parent:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(1, 0.82, 0, 0.3)
	divider:SetHeight(1)
	divider:SetPoint("TOPLEFT", 12, -216)
	divider:SetPoint("TOPRIGHT", -12, -216)

	local historyLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	historyLabel:SetPoint("TOPLEFT", divider, "BOTTOMLEFT", 2, -8)
	historyLabel:SetText("Full history for this player")

	panel.deleteButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	panel.deleteButton:SetSize(100, 22)
	panel.deleteButton:SetPoint("RIGHT", divider, "RIGHT", 0, 0)
	panel.deleteButton:SetPoint("TOP", historyLabel, "TOP", 0, 6)
	panel.deleteButton:SetText("Delete Player")
	panel.deleteButton:SetScript("OnClick", function()
		if not detailsKey then
			return
		end
		local record = ns.GetPlayerRecord(detailsKey, false)
		if record then
			StaticPopup_Show("WR_CONFIRM_DELETE_PLAYER", ns.DisplayName(record, detailsKey), nil, detailsKey)
		end
	end)

	panel.newEntryButton = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	panel.newEntryButton:SetSize(100, 22)
	panel.newEntryButton:SetPoint("RIGHT", panel.deleteButton, "LEFT", -8, 0)
	panel.newEntryButton:SetPoint("TOP", historyLabel, "TOP", 0, 6)
	panel.newEntryButton:SetText("New Entry")
	panel.newEntryButton:SetScript("OnClick", function()
		if detailsKey then
			ns.ShowQuickAdd(detailsKey)
		end
	end)

	table_ = ns.CreateSortableTable(parent, {
		tableId = "details",
		columns = COLUMNS,
		rowHeight = 20,
		getItems = getItems,
		sortValue = sortValue,
		render = render,
		onRightClick = function(item, rowFrame)
			MenuUtil.CreateContextMenu(rowFrame, function(_, rootDescription)
				rootDescription:CreateTitle(ns.FormatTime(item.entry.time))
				rootDescription:CreateButton("Edit Entry", function() ns.ShowEditEntry(detailsKey, ns.GetPlayerRecord(detailsKey, false), item.entry) end)
				rootDescription:CreateButton("Delete Entry", function() ns.ConfirmDeleteEntry(detailsKey, item.entry) end)
			end)
		end,
		defaultSort = { key = "time", dir = "desc" },
		pageSize = 100,
	})
	table_.container:SetPoint("TOPLEFT", historyLabel, "BOTTOMLEFT", -2, -6)
	table_.container:SetPoint("BOTTOMRIGHT", -12, 0)

	refresh()
end
