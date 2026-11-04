local ns = WorthRemembering

if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) then
	return
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
		return
	end
	if not ns.GetSettings().tooltipEnabled then
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
	if content.lastNote then
		local lastEntry = record.entries[#record.entries]
		if lastEntry and lastEntry.text and lastEntry.text ~= "" then
			lines[#lines + 1] = { lastEntry.text, 0.8, 0.8, 0.8 }
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
