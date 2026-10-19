local ns = WorthRemembering

-- Appends a "[+10]"-style standing tag right after a notable player's name in chat, via
-- ChatFrame_AddMessageEventFilter.
local EVENTS = {
	"CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_EMOTE", "CHAT_MSG_TEXT_EMOTE",
	"CHAT_MSG_PARTY", "CHAT_MSG_PARTY_LEADER",
	"CHAT_MSG_RAID", "CHAT_MSG_RAID_LEADER", "CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_GUILD", "CHAT_MSG_OFFICER",
	"CHAT_MSG_WHISPER", "CHAT_MSG_WHISPER_INFORM",
	"CHAT_MSG_CHANNEL",
	"CHAT_MSG_INSTANCE_CHAT", "CHAT_MSG_INSTANCE_CHAT_LEADER",
}

local function resolveKey(playerName)
	if not playerName or playerName == "" then
		return nil
	end
	local name, suffix = ns.SplitNameSuffix(playerName)
	return ns.BuildKey(name, suffix)
end

-- Plain text, no color codes: playerName feeds the sender's clickable hyperlink, and a
-- "|" in it (from a color code) corrupts that hyperlink's parsing.
local function buildTag(record)
	local standing = record.standing or 0
	local sign = standing > 0 and "+" or ""
	return " [" .. sign .. standing .. "]"
end

local function chatFilter(self, event, msg, playerName, ...)
	if not ns.GetSettings().chatIndicator.enabled then
		return false
	end
	local key = resolveKey(playerName)
	local record = key and ns.GetPlayerRecord(key, false)
	if not record or not ns.IsNotable(record) then
		return false
	end
	return false, msg, playerName .. buildTag(record), ...
end

for _, event in ipairs(EVENTS) do
	ChatFrame_AddMessageEventFilter(event, chatFilter)
end
