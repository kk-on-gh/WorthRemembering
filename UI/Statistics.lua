local ns = WorthRemembering

local panel

local DAY_SECONDS = 24 * 60 * 60

local function computeStats()
	local stats = {
		totalPlayers = 0,
		totalEntries = 0,
		totalNotes = 0,
		oldest = nil,
		newest = nil,
		totalPositive = 0,
		totalNegative = 0, -- stored as a positive magnitude
		entriesWeek = 0,
		entriesMonth = 0,
		entriesYear = 0,
	}

	local classStanding, raceStanding, factionStanding = {}, {}, {}
	local classCount, raceCount, factionCount = {}, {}, {}
	local classPosCount, racePosCount, factionPosCount = {}, {}, {}
	local classNegCount, raceNegCount, factionNegCount = {}, {}, {}
	-- keyed "negative4".."negative1", "zero", "positive1".."positive4"
	local bracketCounts = {}
	-- keyed by logging character's full name
	local characterCounts = {}

	local now = time()
	local weekCutoff, monthCutoff, yearCutoff = now - 7 * DAY_SECONDS, now - 30 * DAY_SECONDS, now - 365 * DAY_SECONDS

	for _, key in ipairs(ns.GetAllPlayerKeys()) do
		local record = ns.GetPlayerRecord(key, false)
		if record then
			-- Entry-level aggregates (total/notes/dates/activity/busiest-character/
			-- most-noted) count every entry for everyone logged, including auto-nearby-only
			-- players. Only the notable-player count and the class/race/faction standing
			-- groupings below stay scoped to ns.IsNotable, since those are specifically
			-- about reputation opinions, not raw activity volume.
			stats.totalEntries = stats.totalEntries + #record.entries

			-- "Most-noted player" = most entries logged against a single player.
			if not stats.mostNotedCount or #record.entries > stats.mostNotedCount then
				stats.mostNotedCount = #record.entries
				stats.mostNotedName = ns.DisplayName(record, key)
				stats.mostNotedKey = key
			end

			for _, entry in ipairs(record.entries) do
				if entry.text and entry.text ~= "" then
					stats.totalNotes = stats.totalNotes + 1
				end
				if entry.delta then
					if entry.delta > 0 then
						stats.totalPositive = stats.totalPositive + entry.delta
					elseif entry.delta < 0 then
						stats.totalNegative = stats.totalNegative - entry.delta
					end
				end
				if not stats.oldest or entry.time < stats.oldest then
					stats.oldest = entry.time
					stats.oldestKey = key
				end
				if not stats.newest or entry.time > stats.newest then
					stats.newest = entry.time
					stats.newestKey = key
				end
				if entry.time >= weekCutoff then
					stats.entriesWeek = stats.entriesWeek + 1
				end
				if entry.time >= monthCutoff then
					stats.entriesMonth = stats.entriesMonth + 1
				end
				if entry.time >= yearCutoff then
					stats.entriesYear = stats.entriesYear + 1
				end
				if entry.loggedBy then
					characterCounts[entry.loggedBy] = (characterCounts[entry.loggedBy] or 0) + 1
				end
			end
		end

		if record and ns.IsNotable(record) then
			stats.totalPlayers = stats.totalPlayers + 1

			-- "Most liked/disliked class/race/faction" = highest/lowest *current* standing
			-- summed across all players of that group, not a sum of deltas ever logged
			-- (which could include standing that's since been reversed).
			local standing = record.standing or 0
			local bracket = ns.GetBracket(standing)
			local bracketKey = bracket.index == 0 and "zero" or ((standing > 0 and "positive" or "negative") .. bracket.index)
			bracketCounts[bracketKey] = (bracketCounts[bracketKey] or 0) + 1

			if record.classFile then
				classStanding[record.classFile] = (classStanding[record.classFile] or 0) + standing
				classCount[record.classFile] = (classCount[record.classFile] or 0) + 1
				if standing > 0 then
					classPosCount[record.classFile] = (classPosCount[record.classFile] or 0) + 1
				elseif standing < 0 then
					classNegCount[record.classFile] = (classNegCount[record.classFile] or 0) + 1
				end
			end
			local race = ns.SimplifyRace(record.race)
			if race then
				raceStanding[race] = (raceStanding[race] or 0) + standing
				raceCount[race] = (raceCount[race] or 0) + 1
				if standing > 0 then
					racePosCount[race] = (racePosCount[race] or 0) + 1
				elseif standing < 0 then
					raceNegCount[race] = (raceNegCount[race] or 0) + 1
				end
			end
			if record.faction then
				factionStanding[record.faction] = (factionStanding[record.faction] or 0) + standing
				factionCount[record.faction] = (factionCount[record.faction] or 0) + 1
				if standing > 0 then
					factionPosCount[record.faction] = (factionPosCount[record.faction] or 0) + 1
				elseif standing < 0 then
					factionNegCount[record.faction] = (factionNegCount[record.faction] or 0) + 1
				end
			end
		end
	end

	stats.busiestCharacter, stats.busiestCharacterCount = nil, nil
	for name, count in pairs(characterCounts) do
		if not stats.busiestCharacterCount or count > stats.busiestCharacterCount then
			stats.busiestCharacter, stats.busiestCharacterCount = name, count
		end
	end

	local function extremes(map)
		local bestKey, bestVal, worstKey, worstVal
		for k, v in pairs(map) do
			if not bestVal or v > bestVal then
				bestKey, bestVal = k, v
			end
			if not worstVal or v < worstVal then
				worstKey, worstVal = k, v
			end
		end
		return bestKey, bestVal, worstKey, worstVal
	end

	-- highest count only. "most frequently liked/disliked" each come from their own
	-- separate count map, not two ends of one map.
	local function topCount(map)
		local bestKey, bestVal
		for k, v in pairs(map) do
			if not bestVal or v > bestVal then
				bestKey, bestVal = k, v
			end
		end
		return bestKey, bestVal
	end

	local function averages(sumMap, countMap)
		local avgMap = {}
		for k, sum in pairs(sumMap) do
			avgMap[k] = sum / countMap[k]
		end
		return avgMap
	end

	stats.bestClass, stats.bestClassVal, stats.worstClass, stats.worstClassVal = extremes(classStanding)
	stats.bestRace, stats.bestRaceVal, stats.worstRace, stats.worstRaceVal = extremes(raceStanding)
	stats.bestFaction, stats.bestFactionVal, stats.worstFaction, stats.worstFactionVal = extremes(factionStanding)

	-- average standing per player, a separate ranking from the raw sum above
	stats.bestAvgClass, stats.bestAvgClassVal, stats.worstAvgClass, stats.worstAvgClassVal = extremes(averages(classStanding, classCount))
	stats.bestAvgRace, stats.bestAvgRaceVal, stats.worstAvgRace, stats.worstAvgRaceVal = extremes(averages(raceStanding, raceCount))
	stats.bestAvgFaction, stats.bestAvgFactionVal, stats.worstAvgFaction, stats.worstAvgFactionVal = extremes(averages(factionStanding, factionCount))

	stats.freqLikedClass, stats.freqLikedClassVal = topCount(classPosCount)
	stats.freqLikedRace, stats.freqLikedRaceVal = topCount(racePosCount)
	stats.freqLikedFaction, stats.freqLikedFactionVal = topCount(factionPosCount)
	stats.freqDislikedClass, stats.freqDislikedClassVal = topCount(classNegCount)
	stats.freqDislikedRace, stats.freqDislikedRaceVal = topCount(raceNegCount)
	stats.freqDislikedFaction, stats.freqDislikedFactionVal = topCount(factionNegCount)

	stats.bracketCounts = bracketCounts

	return stats
end

local function fmtGroup(name, value, suffix)
	return name and (name .. "  (" .. value .. (suffix or "") .. ")") or "-"
end

local function fmtAvg(name, value)
	if not name then
		return "-"
	end
	return name .. "  (" .. string.format("%+.1f", value) .. ")"
end

-- Each def: {label, getValue(stats), color = {r,g,b} | function(stats) r,g,b end,
-- onClick = function(stats) end (optional, omit for a non-navigable tile)}
local OVERVIEW_TILES = {
	{ label = "Notable Players", getValue = function(s) return s.totalPlayers end },
	{ label = "Total Entries", getValue = function(s) return s.totalEntries end },
	{ label = "Total Notes", getValue = function(s) return s.totalNotes end },
	{ label = "Oldest Entry", getValue = function(s) return s.oldest and ns.FormatDate(s.oldest) or "-" end,
		onClick = function(s) if s.oldestKey then ns.ShowPlayerDetails(s.oldestKey) end end },
	{ label = "Most Recent Entry", getValue = function(s) return s.newest and ns.FormatDate(s.newest) or "-" end,
		onClick = function(s) if s.newestKey then ns.ShowPlayerDetails(s.newestKey) end end },
	{ label = "Busiest Character", getValue = function(s) return fmtGroup(s.busiestCharacter, s.busiestCharacterCount, " entries") end,
		onClick = function(s) if s.busiestCharacter then ns.FilterPlayersByCharacter(s.busiestCharacter) end end },
	{ label = "Most-Noted Player", getValue = function(s) return fmtGroup(s.mostNotedName, s.mostNotedCount, " entries") end,
		onClick = function(s) if s.mostNotedKey then ns.ShowPlayerDetails(s.mostNotedKey) end end },
}
local ACTIVITY_TILES = {
	{ label = "Entries This Week", getValue = function(s) return s.entriesWeek end },
	{ label = "Entries This Month", getValue = function(s) return s.entriesMonth end },
	{ label = "Entries This Year", getValue = function(s) return s.entriesYear end },
}
local REP_TILES = {
	{ label = "Total Positive Standing Given", getValue = function(s) return "+" .. s.totalPositive end, color = { 0.2, 0.9, 0.2 } },
	{ label = "Total Negative Standing Given", getValue = function(s) return "-" .. s.totalNegative end, color = { 0.9, 0.2, 0.2 } },
	{
		label = "Net Standing",
		getValue = function(s) return s.totalPositive - s.totalNegative end,
		color = function(s) return ns.StandingColor(s.totalPositive - s.totalNegative, 0) end,
	},
}
-- By total standing summed across the group.
local GROUP_TILES = {
	{ label = "Most Liked Class", getValue = function(s) return fmtGroup(s.bestClass and ns.ClassDisplayName(s.bestClass), s.bestClassVal) end,
		onClick = function(s) if s.bestClass then ns.FilterPlayersByClass(s.bestClass) end end },
	{ label = "Most Liked Race", getValue = function(s) return fmtGroup(s.bestRace, s.bestRaceVal) end,
		onClick = function(s) if s.bestRace then ns.FilterPlayersByRace(s.bestRace) end end },
	{ label = "Most Liked Faction", getValue = function(s) return fmtGroup(s.bestFaction, s.bestFactionVal) end,
		onClick = function(s) if s.bestFaction then ns.FilterPlayersByFaction(s.bestFaction) end end },
	{ label = "Most Disliked Class", getValue = function(s) return fmtGroup(s.worstClass and ns.ClassDisplayName(s.worstClass), s.worstClassVal) end,
		onClick = function(s) if s.worstClass then ns.FilterPlayersByClass(s.worstClass) end end },
	{ label = "Most Disliked Race", getValue = function(s) return fmtGroup(s.worstRace, s.worstRaceVal) end,
		onClick = function(s) if s.worstRace then ns.FilterPlayersByRace(s.worstRace) end end },
	{ label = "Most Disliked Faction", getValue = function(s) return fmtGroup(s.worstFaction, s.worstFactionVal) end,
		onClick = function(s) if s.worstFaction then ns.FilterPlayersByFaction(s.worstFaction) end end },
}

-- by average standing per player, not the raw sum
local AVG_GROUP_TILES = {
	{ label = "Highest Average Standing Class", getValue = function(s) return fmtAvg(s.bestAvgClass and ns.ClassDisplayName(s.bestAvgClass), s.bestAvgClassVal) end,
		onClick = function(s) if s.bestAvgClass then ns.FilterPlayersByClass(s.bestAvgClass) end end },
	{ label = "Highest Average Standing Race", getValue = function(s) return fmtAvg(s.bestAvgRace, s.bestAvgRaceVal) end,
		onClick = function(s) if s.bestAvgRace then ns.FilterPlayersByRace(s.bestAvgRace) end end },
	{ label = "Highest Average Standing Faction", getValue = function(s) return fmtAvg(s.bestAvgFaction, s.bestAvgFactionVal) end,
		onClick = function(s) if s.bestAvgFaction then ns.FilterPlayersByFaction(s.bestAvgFaction) end end },
	{ label = "Lowest Average Standing Class", getValue = function(s) return fmtAvg(s.worstAvgClass and ns.ClassDisplayName(s.worstAvgClass), s.worstAvgClassVal) end,
		onClick = function(s) if s.worstAvgClass then ns.FilterPlayersByClass(s.worstAvgClass) end end },
	{ label = "Lowest Average Standing Race", getValue = function(s) return fmtAvg(s.worstAvgRace, s.worstAvgRaceVal) end,
		onClick = function(s) if s.worstAvgRace then ns.FilterPlayersByRace(s.worstAvgRace) end end },
	{ label = "Lowest Average Standing Faction", getValue = function(s) return fmtAvg(s.worstAvgFaction, s.worstAvgFactionVal) end,
		onClick = function(s) if s.worstAvgFaction then ns.FilterPlayersByFaction(s.worstAvgFaction) end end },
}

-- by number of distinct players with positive/negative standing, not total standing
local FREQ_GROUP_TILES = {
	{ label = "Most Frequently Liked Class", getValue = function(s) return fmtGroup(s.freqLikedClass and ns.ClassDisplayName(s.freqLikedClass), s.freqLikedClassVal, " players") end,
		onClick = function(s) if s.freqLikedClass then ns.FilterPlayersByClass(s.freqLikedClass) end end },
	{ label = "Most Frequently Liked Race", getValue = function(s) return fmtGroup(s.freqLikedRace, s.freqLikedRaceVal, " players") end,
		onClick = function(s) if s.freqLikedRace then ns.FilterPlayersByRace(s.freqLikedRace) end end },
	{ label = "Most Frequently Liked Faction", getValue = function(s) return fmtGroup(s.freqLikedFaction, s.freqLikedFactionVal, " players") end,
		onClick = function(s) if s.freqLikedFaction then ns.FilterPlayersByFaction(s.freqLikedFaction) end end },
	{ label = "Most Frequently Disliked Class", getValue = function(s) return fmtGroup(s.freqDislikedClass and ns.ClassDisplayName(s.freqDislikedClass), s.freqDislikedClassVal, " players") end,
		onClick = function(s) if s.freqDislikedClass then ns.FilterPlayersByClass(s.freqDislikedClass) end end },
	{ label = "Most Frequently Disliked Race", getValue = function(s) return fmtGroup(s.freqDislikedRace, s.freqDislikedRaceVal, " players") end,
		onClick = function(s) if s.freqDislikedRace then ns.FilterPlayersByRace(s.freqDislikedRace) end end },
	{ label = "Most Frequently Disliked Faction", getValue = function(s) return fmtGroup(s.freqDislikedFaction, s.freqDislikedFactionVal, " players") end,
		onClick = function(s) if s.freqDislikedFaction then ns.FilterPlayersByFaction(s.freqDislikedFaction) end end },
}

-- Same 3-row (Positive/Neutral/Negative) x 4-column (mild -> extreme) layout as the
-- Options tab's bracket label editor, so the two match visually instead of the Positive
-- row needing a mental flip to read against the Negative row below it. Label text and
-- color come from the live bracket settings (ns.GetActiveBracketLabels/repBracketColors)
-- rather than being baked in here, since the user can switch presets or recolor brackets
-- at any time and this section needs to reflect whatever's currently active.
local BRACKET_ROW_LABELS = { "Positive", "Neutral", "Negative" }
local BRACKET_SLOTS = {
	{ sign = "positive", index = 1, row = 1, col = 1 },
	{ sign = "positive", index = 2, row = 1, col = 2 },
	{ sign = "positive", index = 3, row = 1, col = 3 },
	{ sign = "positive", index = 4, row = 1, col = 4 },
	{ sign = "zero", row = 2, col = 1 },
	{ sign = "negative", index = 1, row = 3, col = 1 },
	{ sign = "negative", index = 2, row = 3, col = 2 },
	{ sign = "negative", index = 3, row = 3, col = 3 },
	{ sign = "negative", index = 4, row = 3, col = 4 },
}

local function bracketSlotKey(slot)
	return slot.sign == "zero" and "zero" or (slot.sign .. slot.index)
end

local function bracketSlotLabel(slot)
	local labels = ns.GetActiveBracketLabels()
	if slot.sign == "zero" then
		return labels.zero
	end
	return labels[slot.sign][slot.index]
end

local function bracketSlotColor(slot)
	if slot.sign == "zero" then
		return 0.8, 0.8, 0.8
	end
	local c = ns.GetSettings().repBracketColors[slot.sign][slot.index]
	return c[1], c[2], c[3]
end

-- Wide enough that longer values (Busiest Character, Most-Noted Player, etc) don't
-- truncate.
local TILE_WIDTH, TILE_HEIGHT, TILE_GAP = 280, 44, 14

-- Set at the top of every refresh() so a tile's onClick handler always acts on the
-- current data, not whatever was true when the panel was first built.
local currentStats = {}

local SECTION_HEADER_HEIGHT = 28

-- Lays out sections top-down using plain pixel offsets from `parent`'s TOPLEFT (rather
-- than chaining each piece's anchor off the previous frame's rendered geometry), so the
-- total content height needed for the scroll frame is exact arithmetic, not something
-- read back out of frame anchors after the fact.
local function createSection(parent, title, topOffset)
	local header = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	header:SetPoint("TOPLEFT", 16, -topOffset)
	header:SetText(title)

	local divider = parent:CreateTexture(nil, "ARTWORK")
	divider:SetColorTexture(1, 0.82, 0, 0.3)
	divider:SetHeight(1)
	divider:SetPoint("TOPLEFT", 16, -(topOffset + 22))
	divider:SetPoint("RIGHT", parent, "RIGHT", -16, 0)

	return topOffset + SECTION_HEADER_HEIGHT
end

-- Creates (once) the tile frames for tileDefs in a grid of `columns` starting at
-- `topOffset` pixels below `parent`'s top, storing each tile's widgets onto the def table
-- itself (`def._tile`) so refresh() can update values without rebuilding layout. Returns
-- the pixel offset where the next section should start.
local function createTileGrid(parent, topOffset, tileDefs, columns)
	local rows = math.ceil(#tileDefs / columns)
	for i, def in ipairs(tileDefs) do
		local col = (i - 1) % columns
		local row = math.floor((i - 1) / columns)

		-- Clickable tiles (def.onClick set) are Buttons with a hover highlight, so there's
		-- a visible affordance that they lead somewhere; others stay plain Frames.
		local box = CreateFrame(def.onClick and "Button" or "Frame", nil, parent, "BackdropTemplate")
		box:SetSize(TILE_WIDTH, TILE_HEIGHT)
		box:SetPoint("TOPLEFT", 16 + col * (TILE_WIDTH + TILE_GAP), -(topOffset + row * (TILE_HEIGHT + TILE_GAP)))
		ns.ApplyPanelBackdrop(box, 0.5)

		if def.onClick then
			local highlight = box:CreateTexture(nil, "HIGHLIGHT")
			highlight:SetAllPoints()
			highlight:SetColorTexture(1, 0.82, 0, 0.15)
			box:SetScript("OnClick", function() def.onClick(currentStats) end)
		end

		local label = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		label:SetPoint("TOPLEFT", 10, -6)
		label:SetPoint("TOPRIGHT", -10, -6)
		label:SetJustifyH("LEFT")
		label:SetText(def.label)

		local value = box:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		value:SetPoint("TOPLEFT", 10, -20)
		value:SetPoint("TOPRIGHT", -10, -20)
		value:SetJustifyH("LEFT")
		value:SetWordWrap(false)

		def._tile = { box = box, value = value }
	end

	return topOffset + rows * (TILE_HEIGHT + TILE_GAP)
end

local bracketTiles = {}
local BRACKET_ROW_LABEL_WIDTH = 70
-- its own narrower width, not the general TILE_WIDTH: this grid has 4 columns plus a
-- row-label column, the wider 3-column tile size would run past the window's min width.
local BRACKET_TILE_WIDTH = 190

-- separate from createTileGrid because each tile's *label*, not just its value, must
-- update on every refresh: the bracket name can change if the user edits label
-- presets/custom text in Options. positions by each slot's own row/col (fixed 3-row
-- Positive/Neutral/Negative layout) to match the Options tab's bracket editor layout.
-- clicking jumps to Players pre-filtered to that bracket.
local function createBracketGrid(parent, topOffset)
	for _, rowIndex in ipairs({ 1, 2, 3 }) do
		local rowLabel = parent:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		rowLabel:SetWidth(BRACKET_ROW_LABEL_WIDTH)
		rowLabel:SetJustifyH("LEFT")
		rowLabel:SetText(BRACKET_ROW_LABELS[rowIndex])
		rowLabel:SetPoint("TOPLEFT", 16, -(topOffset + (rowIndex - 1) * (TILE_HEIGHT + TILE_GAP) + TILE_HEIGHT / 2))
	end

	for _, slot in ipairs(BRACKET_SLOTS) do
		local x = 16 + BRACKET_ROW_LABEL_WIDTH + (slot.col - 1) * (BRACKET_TILE_WIDTH + TILE_GAP)
		local y = topOffset + (slot.row - 1) * (TILE_HEIGHT + TILE_GAP)

		local box = CreateFrame("Button", nil, parent, "BackdropTemplate")
		box:SetSize(BRACKET_TILE_WIDTH, TILE_HEIGHT)
		box:SetPoint("TOPLEFT", x, -y)
		ns.ApplyPanelBackdrop(box, 0.5)

		local highlight = box:CreateTexture(nil, "HIGHLIGHT")
		highlight:SetAllPoints()
		highlight:SetColorTexture(1, 0.82, 0, 0.15)
		box:SetScript("OnClick", function() ns.FilterPlayersByBracket(bracketSlotKey(slot)) end)

		local label = box:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
		label:SetPoint("TOPLEFT", 10, -6)
		label:SetPoint("TOPRIGHT", -10, -6)
		label:SetJustifyH("LEFT")
		label:SetWordWrap(false)

		local value = box:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
		value:SetPoint("TOPLEFT", 10, -20)
		value:SetPoint("TOPRIGHT", -10, -20)
		value:SetJustifyH("LEFT")
		value:SetWordWrap(false)

		bracketTiles[bracketSlotKey(slot)] = { slot = slot, label = label, value = value }
	end

	return topOffset + 3 * (TILE_HEIGHT + TILE_GAP)
end

local function applyBracketValues(stats)
	for key, tile in pairs(bracketTiles) do
		tile.label:SetText(bracketSlotLabel(tile.slot))
		tile.value:SetText(tostring(stats.bracketCounts[key] or 0))
		tile.value:SetTextColor(bracketSlotColor(tile.slot))
	end
end

local function applyTileValues(tileDefs, stats)
	for _, def in ipairs(tileDefs) do
		local tile = def._tile
		local value = def.getValue(stats)
		tile.value:SetText(tostring(value))
		if def.color then
			if type(def.color) == "function" then
				tile.value:SetTextColor(def.color(stats))
			else
				tile.value:SetTextColor(unpack(def.color))
			end
		else
			tile.value:SetTextColor(1, 1, 1)
		end
	end
end

local function refresh()
	if not panel then
		return
	end
	local stats = computeStats()
	currentStats = stats
	applyTileValues(OVERVIEW_TILES, stats)
	applyTileValues(ACTIVITY_TILES, stats)
	applyTileValues(REP_TILES, stats)
	applyTileValues(GROUP_TILES, stats)
	applyTileValues(AVG_GROUP_TILES, stats)
	applyTileValues(FREQ_GROUP_TILES, stats)
	applyBracketValues(stats)
end
ns.RefreshStatistics = refresh

-- Four sections' worth of tiles can run taller than the window's minimum height, so
-- everything is built onto a scrolling child frame rather than directly on the tab panel.
function ns.BuildStatisticsPanel(parent)
	panel = parent

	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 0, 0)
	scroll:SetPoint("BOTTOMRIGHT", -34, 0)

	local scrollChild = CreateFrame("Frame", nil, scroll)
	scrollChild:SetSize(1, 1)
	scroll:SetScrollChild(scrollChild)
	scroll:SetScript("OnSizeChanged", function(self, width)
		scrollChild:SetWidth(width)
	end)

	local y = 10
	y = createSection(scrollChild, "Overview", y)
	y = createTileGrid(scrollChild, y, OVERVIEW_TILES, 3)

	y = createSection(scrollChild, "Recent Activity", y + 14)
	y = createTileGrid(scrollChild, y, ACTIVITY_TILES, 3)

	y = createSection(scrollChild, "Reputation Given", y + 14)
	y = createTileGrid(scrollChild, y, REP_TILES, 3)

	y = createSection(scrollChild, "Most Liked / Disliked (by Standing)", y + 14)
	y = createTileGrid(scrollChild, y, GROUP_TILES, 3)

	y = createSection(scrollChild, "Most Liked / Disliked (by Average Standing)", y + 14)
	y = createTileGrid(scrollChild, y, AVG_GROUP_TILES, 3)

	y = createSection(scrollChild, "Most Liked / Disliked (by Player Count)", y + 14)
	y = createTileGrid(scrollChild, y, FREQ_GROUP_TILES, 3)

	y = createSection(scrollChild, "Players by Bracket", y + 14)
	y = createBracketGrid(scrollChild, y)

	scrollChild:SetPoint("TOPLEFT")
	scrollChild:SetWidth(parent:GetWidth())
	scrollChild:SetHeight(y + 20)

	refresh()
end
