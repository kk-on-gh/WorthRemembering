local ns = WorthRemembering

-- Appends a "[+10]"-style standing tag right after a notable player's name in chat.
local function resolveKey(playerName)
	if not playerName or playerName == "" then
		return nil
	end
	local name, suffix = ns.SplitNameSuffix(playerName)
	return ns.BuildKey(name, suffix)
end

local function buildTag(record)
	local standing = record.standing or 0
	local sign = standing > 0 and "+" or ""
	return " [" .. sign .. standing .. "]"
end

-- Sender name filter only touches the displayed name; the player: hyperlink keeps the real name.
local function senderNameFilter(event, decoratedName, text, playerName)
	if not ns.GetSettings().chatIndicator.enabled then
		return nil
	end
	local key = resolveKey(playerName)
	local record = key and ns.GetPlayerRecord(key, false)
	if not record or not ns.IsNotable(record) then
		return nil
	end
	return decoratedName .. buildTag(record)
end

if ChatFrameUtil and ChatFrameUtil.AddSenderNameFilter then
	ChatFrameUtil.AddSenderNameFilter(senderNameFilter)
end
