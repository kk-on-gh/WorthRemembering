local ns = WorthRemembering

-- per-feature ignore flags, by player (ns.GetIgnoreList) or by relationship rule
-- (settings.ignore). a player row overrides every rule

ns.IGNORE_FLAGS = {
	{ key = "auto", label = "Auto-Entries",
		tip = "No automatic entries: grouping, questing, buffs, rezzes, duels, emotes, dungeon logs, Recent Allies and Nearby auto-add." },
	{ key = "survey", label = "Survey",
		tip = "Left out of the dungeon/raid survey. If everyone in the group is ignored, the survey doesn't open." },
	{ key = "indicators", label = "Indicators",
		tip = "No nameplate icon, chat tag, or Nearby window entry or alert." },
}

ns.IGNORE_RULES = {
	{ key = "guild", label = "Guild" },
	{ key = "friends", label = "WoW friends" },
	{ key = "bnet", label = "BattleTag friends" },
}

local function isSecret(v)
	return issecretvalue and issecretvalue(v)
end

local function addGuid(set, guid)
	if type(guid) == "string" and not isSecret(guid) and guid ~= "" then
		set[guid] = true
	end
end

-- Forever lists "Add WoW Friend" entries in the BNet list with isBattleTagFriend false
local function addBNetFriends(set, battleTag)
	local wowClient = BNET_CLIENT_WOW or "WoW"
	local function addAccount(info)
		if info and info.clientProgram == wowClient and info.wowProjectID == WOW_PROJECT_ID then
			addGuid(set, info.playerGuid)
		end
	end
	local multi = C_BattleNet.GetFriendNumGameAccounts and C_BattleNet.GetFriendGameAccountInfo
	for i = 1, (BNGetNumFriends()) do
		local account = C_BattleNet.GetFriendAccountInfo(i)
		if account and (account.isBattleTagFriend ~= false) == battleTag then
			if multi then
				for j = 1, C_BattleNet.GetFriendNumGameAccounts(i) or 0 do
					addAccount(C_BattleNet.GetFriendGameAccountInfo(i, j))
				end
			else
				addAccount(account.gameAccountInfo)
			end
		end
	end
end

local builders = {
	guild = function(set)
		if not IsInGuild() then
			return
		end
		for i = 1, GetNumGuildMembers() do
			addGuid(set, (select(17, GetGuildRosterInfo(i))))
		end
	end,
	friends = function(set)
		for i = 1, C_FriendList.GetNumFriends() do
			local info = C_FriendList.GetFriendInfoByIndex(i)
			if info then
				addGuid(set, info.guid)
			end
		end
		addBNetFriends(set, false)
	end,
	bnet = function(set)
		addBNetFriends(set, true)
	end,
}

-- nil = stale, rebuilt on next lookup
local guidSets = {}

local function getSet(ruleKey)
	local set = guidSets[ruleKey]
	if not set then
		set = {}
		pcall(builders[ruleKey], set)
		guidSets[ruleKey] = set
	end
	return set
end

local function ruleActive(rule)
	return rule.auto or rule.survey or rule.indicators
end

local function guidFor(key, guid)
	if guid == nil then
		local record = ns.GetPlayerRecord(key, false)
		guid = record and record.guid
	end
	if guid == nil or isSecret(guid) then
		return nil
	end
	return guid
end

-- the rule (ns.IGNORE_RULES entry) that ignores this guid for flag, or nil
local function matchingRule(flag, guid)
	local rules = ns.GetSettings().ignore
	for _, def in ipairs(ns.IGNORE_RULES) do
		if rules[def.key][flag] and getSet(def.key)[guid] then
			return def
		end
	end
	return nil
end

-- guid optional, falls back to the stored record's
function ns.IsIgnored(key, flag, guid)
	if not key then
		return false
	end
	local row = ns.GetIgnoreList()[key]
	if row then
		return row[flag] == true
	end
	local rules = ns.GetSettings().ignore
	if not (rules.guild[flag] or rules.friends[flag] or rules.bnet[flag]) then
		return false
	end
	guid = guidFor(key, guid)
	return guid ~= nil and matchingRule(flag, guid) ~= nil
end

-- for the Players column. returns "list" | "exempt" | rule label | nil
function ns.GetIgnoreSource(key, guid)
	local row = ns.GetIgnoreList()[key]
	if row then
		return (row.auto or row.survey or row.indicators) and "list" or "exempt"
	end
	local rules = ns.GetSettings().ignore
	if not (ruleActive(rules.guild) or ruleActive(rules.friends) or ruleActive(rules.bnet)) then
		return nil
	end
	guid = guidFor(key, guid)
	if not guid then
		return nil
	end
	for _, flagDef in ipairs(ns.IGNORE_FLAGS) do
		local rule = matchingRule(flagDef.key, guid)
		if rule then
			return rule.label
		end
	end
	return nil
end

function ns.IsOnIgnoreList(key)
	return key ~= nil and ns.GetIgnoreList()[key] ~= nil
end

-- redraws everything an ignore change can affect
function ns.OnIgnoreChanged()
	if ns.RefreshNameplateIcons then
		ns.RefreshNameplateIcons()
	end
	if ns.RefreshNearbyWindow then
		ns.RefreshNearbyWindow()
	end
	if ns.RefreshAllTabs then
		ns.RefreshAllTabs()
	end
	if ns.RefreshIgnorePanel then
		ns.RefreshIgnorePanel()
	end
end

StaticPopupDialogs["WR_CONFIRM_IGNORE_CLEANUP"] = {
	text = "%s is now on your ignore list.\n\nAlso delete their %d existing auto-tracked entries? Manual notes and survey entries are kept.",
	button1 = "Delete",
	button2 = "Keep",
	OnAccept = function(self, key)
		local removed = ns.DeleteAutoEntries(key)
		ns.Print(("Deleted %d auto-tracked entries."):format(removed))
		ns.RefreshAllTabs()
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

-- identity optional, falls back to the stored record for display fields
function ns.AddToIgnoreList(key, identity)
	if not key or ns.IsOnIgnoreList(key) then
		return
	end
	local record = ns.GetPlayerRecord(key, false)
	-- the saved record has proper casing even when the name was typed
	local source = record or identity or {}
	ns.GetIgnoreList()[key] = {
		auto = true, survey = true, indicators = true,
		name = source.name, realmOrSurname = source.realmOrSurname,
		classFile = source.classFile or (identity and identity.classFile),
		guid = source.guid or (identity and identity.guid),
		addedAt = time(),
	}
	local name = ns.DisplayName(record or source, key)
	ns.Print(name .. " added to your ignore list.")
	ns.OnIgnoreChanged()

	local autoCount = ns.CountAutoEntries(key)
	if autoCount > 0 then
		StaticPopup_Show("WR_CONFIRM_IGNORE_CLEANUP", name, autoCount, key)
	end
end

-- typed name to key + identity. first name alone is a shortcut to a saved player when
-- exactly one has it. returns nil, errorText on failure
function ns.ResolveIgnoreName(text)
	text = strtrim(text or "")
	if text == "" then
		return nil
	end
	local first, last = ns.SplitNameSuffix(text)
	if not last or last == "" then
		local lowerFirst, match = first:lower(), nil
		for _, key in ipairs(ns.GetAllPlayerKeys()) do
			local record = ns.GetPlayerRecord(key, false)
			if record.name and record.name:lower() == lowerFirst then
				if match then
					return nil, "More than one saved player is named " .. first .. ". Enter their full name."
				end
				match = key
			end
		end
		if match then
			return match, nil
		end
		last = nil
	end
	local key = ns.BuildKey(first, last, nil)
	if not key then
		return nil, "No saved player named " .. first .. ". Enter their full name."
	end
	return key, { name = first, realmOrSurname = last }
end

function ns.RemoveFromIgnoreList(key)
	local row = key and ns.GetIgnoreList()[key]
	if not row then
		return
	end
	ns.GetIgnoreList()[key] = nil
	ns.Print(ns.DisplayName(ns.GetPlayerRecord(key, false) or row, key) .. " removed from your ignore list.")
	ns.OnIgnoreChanged()
end

function ns.SetIgnoreFlag(key, flag, value)
	local row = ns.GetIgnoreList()[key]
	if row then
		row[flag] = value and true or false
		ns.OnIgnoreChanged()
	end
end

function ns.SetIgnoreRuleFlag(ruleKey, flag, value)
	ns.GetSettings().ignore[ruleKey][flag] = value and true or false
	ns.RequestIgnoreRosters()
	ns.OnIgnoreChanged()
end

-- for every WR player menu
function ns.AddIgnoreMenuButton(rootDescription, key, identity)
	if ns.IsOnIgnoreList(key) then
		rootDescription:CreateButton("Unignore Player", function() ns.RemoveFromIgnoreList(key) end)
	else
		rootDescription:CreateButton("Ignore Player", function() ns.AddToIgnoreList(key, identity) end)
	end
end

-- asks the server for roster data the active rules need. guild roster includes
-- offline members, the Players column relies on that
function ns.RequestIgnoreRosters()
	local rules = ns.GetSettings().ignore
	if ruleActive(rules.guild) and IsInGuild() and C_GuildInfo and C_GuildInfo.GuildRoster then
		C_GuildInfo.GuildRoster()
	end
	if ruleActive(rules.friends) and C_FriendList.ShowFriends then
		C_FriendList.ShowFriends()
	end
end

local FRIENDS_BOTH = { "friends", "bnet" }
local STALE_ON = {
	GUILD_ROSTER_UPDATE = { "guild" },
	PLAYER_GUILD_UPDATE = { "guild" },
	FRIENDLIST_UPDATE = { "friends" },
	BN_FRIEND_INFO_CHANGED = FRIENDS_BOTH,
	BN_FRIEND_LIST_SIZE_CHANGED = FRIENDS_BOTH,
	BN_FRIEND_ACCOUNT_ONLINE = FRIENDS_BOTH,
	BN_FRIEND_ACCOUNT_OFFLINE = FRIENDS_BOTH,
}

local frame = CreateFrame("Frame")
for event in pairs(STALE_ON) do
	pcall(frame.RegisterEvent, frame, event)
end
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function(_, event)
	if event == "PLAYER_LOGIN" then
		ns.RequestIgnoreRosters()
		return
	end
	for _, ruleKey in ipairs(STALE_ON[event]) do
		guidSets[ruleKey] = nil
	end
end)
