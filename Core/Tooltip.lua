local ns = WorthRemembering

if not (TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall) then
	return
end

local function standingColor(standing, band)
	if math.abs(standing) <= band then
		return 0.8, 0.8, 0.8
	elseif standing > 0 then
		return 0.2, 0.9, 0.2
	end
	return 0.9, 0.2, 0.2
end

TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Unit, function(tooltip)
	if tooltip ~= GameTooltip and tooltip ~= ItemRefTooltip then
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

	local band = ns.GetSettings().neutralBand
	local r, g, b = standingColor(record.standing or 0, band)

	local standing = record.standing or 0
	local sign = standing > 0 and "+" or ""

	tooltip:AddLine(" ")
	tooltip:AddLine("WR Rep: " .. sign .. standing .. "  (" .. #record.entries .. " entries)", r, g, b, true)

	local lastEntry = record.entries[#record.entries]
	if lastEntry and lastEntry.text and lastEntry.text ~= "" then
		tooltip:AddLine(lastEntry.text, 0.8, 0.8, 0.8, true)
	end
end)
