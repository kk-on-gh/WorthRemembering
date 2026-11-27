local ns = WorthRemembering

-- community credits. page = an Options sub-tab key, or "players" (shows a heart there), optional.
-- shown as "<what> <kind> by <who>"
ns.CREDITS = {
	{ kind = "suggested", what = "Ignoring functionality", who = "Reddit user /u/Ksir73", page = "ignore", version = "1.1" },
	{ kind = "suggested", what = "Adding players by name", who = "CurseForge user Serdon", page = "players", version = "1.3.1" },
}

function ns.CreditText(credit)
	return credit.what .. " " .. credit.kind .. " by " .. credit.who .. "."
end

-- name on its own line: wrapping breaks on "/" and would split "/u/name"
function ns.CreditTextTwoLine(credit)
	local line = credit.what .. " " .. credit.kind .. " by\n|c" .. ns.ToHex(ns.Skin.AccentColor()) .. credit.who .. "|r"
	if credit.version then
		line = line .. "  |cff888888(v" .. credit.version .. ")|r"
	end
	return line
end

function ns.GetCreditsForPage(page)
	local list = {}
	for _, credit in ipairs(ns.CREDITS) do
		if credit.page == page then
			list[#list + 1] = credit
		end
	end
	return list
end
