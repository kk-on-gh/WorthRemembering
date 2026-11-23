local ns = WorthRemembering

if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) then
	return
end

local FEATURED_MAX_CHARS = 120

-- the post-call reruns on every tooltip refresh, so the featured pick is held per
-- tooltip until it hides or shows a different player
local featuredPick = {}

local function clearPick(tooltip)
	featuredPick[tooltip] = nil
end
GameTooltip:HookScript("OnHide", clearPick)
ItemRefTooltip:HookScript("OnHide", clearPick)

-- byte cut backed off to a UTF-8 lead byte so a multibyte char never gets split
local function truncate(text, maxChars)
	if #text <= maxChars then
		return text
	end
	local cut = maxChars
	while cut > 1 and text:byte(cut + 1) and text:byte(cut + 1) >= 0x80 and text:byte(cut + 1) < 0xC0 do
		cut = cut - 1
	end
	return text:sub(1, cut) .. "..."
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
		return
	end
	if not ns.GetSettings().tooltipEnabled or ns.IsSuppressed() then
		return
	end

	local _, unit = tooltip:GetUnit()
	if not unit then
		return
	end

	-- tooltip:GetUnit() can return a "secret" opaque unit value for some tooltip
	-- sources (confirmed live: the world-cursor hover tooltip, SetWorldCursor), which
	-- UnitExists (called inside IdentifyUnit) can't even be given from addon code,
	-- throwing instead of just returning false. Every other IdentifyUnit caller passes
	-- a known-safe token (target/mouseover/partyN), only this one's unit comes from an
	-- external API that can hand back something unsafe to inspect at all.
	local ok, identity = pcall(ns.IdentifyUnit, unit)
	if not ok or not identity then
		return
	end

	local record = ns.GetPlayerRecord(identity.key, false)
	if not ns.IsNotable(record) then
		return
	end

	local content = ns.GetSettings().tooltipContent
	local standing = record.standing or 0
	local lines = {}

	if content.rating then
		local sign = standing > 0 and "+" or ""
		lines[#lines + 1] = { "WR Rep: " .. sign .. standing .. "  (" .. #record.entries .. " entries)", unpack(ns.GetBracket(standing).color) }
	end
	if content.bracket then
		local bracket = ns.GetBracket(standing)
		lines[#lines + 1] = { bracket.name, unpack(bracket.color) }
	end
	local lastEntry = record.entries[#record.entries]
	local lastNoteShown = content.lastNote and lastEntry and lastEntry.text and lastEntry.text ~= ""
	if lastNoteShown then
		lines[#lines + 1] = { lastEntry.text, 0.8, 0.8, 0.8 }
	end
	if content.featuredNote then
		local pick = featuredPick[tooltip]
		if not pick or pick.key ~= identity.key then
			pick = { key = identity.key, entry = ns.PickFeaturedEntry(record, lastNoteShown and lastEntry or nil) }
			featuredPick[tooltip] = pick
		end
		if pick.entry then
			lines[#lines + 1] = { "\"" .. truncate(pick.entry.text, FEATURED_MAX_CHARS) .. "\"", 0.75, 0.75, 0.75 }
		end
	end
	if content.timesSeen then
		local seenCount = record.seenCount or 0
		lines[#lines + 1] = { "Seen " .. seenCount .. (seenCount == 1 and " time" or " times"), 0.8, 0.8, 0.8 }
	end
	if content.noteCount then
		local noteCount = 0
		for _, entry in ipairs(record.entries) do
			if entry.text and entry.text ~= "" then
				noteCount = noteCount + 1
			end
		end
		lines[#lines + 1] = { noteCount .. (noteCount == 1 and " note" or " notes"), 0.8, 0.8, 0.8 }
	end

	if #lines == 0 then
		return
	end
	tooltip:AddLine(" ")
	for _, line in ipairs(lines) do
		tooltip:AddLine(line[1], line[2], line[3], line[4], true)
	end
end)
