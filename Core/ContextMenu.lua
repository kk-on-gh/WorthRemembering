local ns = WorthRemembering

-- modern (11.0+) menu API, no unregister. skip if unavailable instead of erroring
if not (Menu and Menu.ModifyMenu) then
	return
end

-- tagged by relationship to the unit, not the frame clicked, so each needs its own hook
local MENU_TAGS = {
	"MENU_UNIT_PLAYER",
	"MENU_UNIT_ENEMY_PLAYER",
	"MENU_UNIT_TARGET",
	"MENU_UNIT_FOCUS",
	"MENU_UNIT_PARTY",
	"MENU_UNIT_RAID",
	"MENU_UNIT_RAID_PLAYER",
	"MENU_UNIT_FRIEND",
	"MENU_UNIT_FRIEND_OFFLINE",
	"MENU_UNIT_COMMUNITIES_GUILD_MEMBER",
	"MENU_UNIT_COMMUNITIES_WOW_MEMBER",
	"MENU_UNIT_GUILD",
	"MENU_UNIT_GUILD_OFFLINE",
	"MENU_UNIT_CHAT_ROSTER",
}

-- chat name links give lineID, not a unit or name/server pair. same shape as
-- ns.IdentifyUnit minus class/race/faction
local function identityFromChatLine(lineID)
	if not C_ChatInfo or not C_ChatInfo.GetChatLineSenderName then
		return nil
	end
	local sender = C_ChatInfo.GetChatLineSenderName(lineID)
	local guid = C_ChatInfo.GetChatLineSenderGUID and C_ChatInfo.GetChatLineSenderGUID(lineID)
	if not sender or sender == "" then
		return nil
	end
	local name, suffix = ns.SplitNameSuffix(sender)
	local key = ns.BuildKey(name, suffix, guid)
	if not key then
		return nil
	end
	return { key = key, name = name, realmOrSurname = suffix, guid = guid }
end

local function identityFromContext(contextData)
	if contextData.unit then
		return ns.IdentifyUnit(contextData.unit)
	end

	if contextData.lineID then
		local identity = identityFromChatLine(contextData.lineID)
		if identity then
			return identity
		end
	end

	if contextData.name and contextData.name ~= "" then
		local key = ns.BuildKey(contextData.name, contextData.server, nil)
		if key then
			return { key = key, name = contextData.name, realmOrSurname = contextData.server, guid = nil }
		end
	end

	return nil
end

local function onMenuOpen(_, rootDescription, contextData)
	local identity = identityFromContext(contextData)
	if not identity then
		return
	end

	rootDescription:CreateDivider()
	rootDescription:CreateTitle("Worth Remembering")
	rootDescription:CreateButton("Add Note", function()
		ns.TouchIdentity(identity.key, identity)
		-- quick popup only, closes after one add. same as /wrnote
		ns.ShowQuickAdd(identity.key, true)
	end)

	local record = ns.GetPlayerRecord(identity.key, false)
	if record then
		rootDescription:CreateButton("Show Details", function()
			ns.ShowPlayerDetails(identity.key)
		end)
		rootDescription:CreateButton("Delete Player", function()
			StaticPopup_Show("WR_CONFIRM_DELETE_PLAYER", ns.DisplayName(record, identity.key), nil, identity.key)
		end)
	end
end

for _, tag in ipairs(MENU_TAGS) do
	Menu.ModifyMenu(tag, onMenuOpen)
end
