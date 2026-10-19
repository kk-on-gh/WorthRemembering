local ns = WorthRemembering

-- logs an entry when a player joins your party/raid. gated by autoTrack.enabled +
-- autoTrack.party.enabled, see ns.AUTO_TRACK_DEFS (Namespace.lua)

local function getCurrentPartyUnits()
	local units = {}
	local n = GetNumGroupMembers()
	if IsInRaid() then
		for i = 1, n do
			units[#units + 1] = "raid" .. i
		end
	elseif n > 0 then
		for i = 1, n - 1 do
			units[#units + 1] = "party" .. i
		end
	end
	return units
end

-- GUIDs seen in the group, for detecting a genuinely new join. keyed by GUID since it
-- resolves reliably unlike UnitName/UnitRace. only cleared when the group goes fully
-- empty, so one roster event with a slow-resolving member can't drop them and get
-- re-logged as a new join. not for "is partied" queries, see ns.IsPlayerPartied
local partyGUIDs = {}

-- when each GUID was first seen grouped this session, for the "quest" trigger's
-- minimum-time-grouped option (autoTrack.quest.minGroupedMinutes). cleared alongside
-- partyGUIDs
local partyJoinedAt = {}

-- seeds partyGUIDs with whoever's already grouped at load, no entries logged for them.
-- otherwise a /reload resets this state and the next roster update looks like a batch
-- of fresh joins. seeded to 0 (always long enough) since we don't actually know when
-- an already-grouped member joined
for _, unit in ipairs(getCurrentPartyUnits()) do
	local guid = UnitGUID(unit)
	if guid then
		partyGUIDs[guid] = true
		partyJoinedAt[guid] = 0
	end
end

-- lets NearbyWindow skip partied players (sound alert and list). computed live, not
-- from partyGUIDs above, since that only updates on GROUP_ROSTER_UPDATE and would miss
-- someone already partied before the first roster event (e.g. across a /reload)
function ns.IsPlayerPartied(key)
	for _, unit in ipairs(getCurrentPartyUnits()) do
		local identity = ns.IdentifyUnit(unit)
		if identity and identity.key == key then
			return true
		end
	end
	return false
end

local function logAuto(key, identity, unit, source, repGain, note)
	if not identity then
		return
	end
	ns.TouchIdentity(key, identity)
	local entry = ns.CaptureContext(unit)
	entry.delta = (repGain and repGain ~= 0) and repGain or nil
	entry.source = source
	if note and note ~= "" then
		entry.text = ns.FillPlaceholders(note, entry)
	end
	ns.AddEntry(key, identity, entry)
	ns.RefreshAllTabs()
end

local function onRosterUpdate()
	local settings = ns.GetSettings().autoTrack
	local option = settings.party

	local units = getCurrentPartyUnits()
	if #units == 0 then
		-- fully ungrouped: only point tracking resets, rejoining later counts as fresh joins
		partyGUIDs = {}
		partyJoinedAt = {}
		return
	end

	for _, unit in ipairs(units) do
		local guid = UnitGUID(unit)
		if guid and not partyGUIDs[guid] then
			partyGUIDs[guid] = true
			partyJoinedAt[guid] = time()
			local identity = ns.IdentifyUnit(unit)
			if identity and settings.enabled and option.enabled then
				logAuto(identity.key, identity, unit, "auto-party", option.repGain, option.note)
			end
		end
	end
end

-- GROUP_ROSTER_UPDATE fires for any change, not just joins/leaves, often several times
-- per real change. debounced to the last event so we don't diff against a mid-burst
-- tick where identity hasn't resolved yet
local pendingRosterUpdate

local frame = CreateFrame("Frame")
frame:RegisterEvent("GROUP_ROSTER_UPDATE")
frame:SetScript("OnEvent", function(_, event)
	if event == "GROUP_ROSTER_UPDATE" then
		if pendingRosterUpdate then
			pendingRosterUpdate:Cancel()
		end
		pendingRosterUpdate = C_Timer.NewTimer(0.5, onRosterUpdate)
	end
end)

-- last log time per grouped player, session-only, independent of lastEmoteAt
local lastQuestAt = {}

-- logs for every current party/raid member when you turn in a quest while grouped with
-- them. QUEST_TURNED_IN only tells us that you turned one in, not who else did, so this
-- can't tell whether they were actually along for that specific quest
local function onQuestTurnedIn()
	local settings = ns.GetSettings().autoTrack
	local option = settings.quest
	if not (settings.enabled and option.enabled) then
		return
	end

	local units = getCurrentPartyUnits()
	local cooldownSeconds = (option.cooldownMinutes or 30) * 60
	local minGroupedSeconds = (option.minGroupedMinutes or 0) * 60
	local now = time()
	for _, unit in ipairs(units) do
		local identity = ns.IdentifyUnit(unit)
		if identity then
			local joinedAt = identity.guid and partyJoinedAt[identity.guid]
			local longEnoughGrouped = minGroupedSeconds == 0 or (joinedAt and (now - joinedAt) >= minGroupedSeconds)
			if longEnoughGrouped then
				local lastLoggedAt = lastQuestAt[identity.key]
				if not lastLoggedAt or (now - lastLoggedAt) >= cooldownSeconds then
					lastQuestAt[identity.key] = now
					logAuto(identity.key, identity, unit, "auto-quest", option.repGain, option.note)
				end
			end
		end
	end
end

local questFrame = CreateFrame("Frame")
questFrame:RegisterEvent("QUEST_TURNED_IN")
questFrame:SetScript("OnEvent", onQuestTurnedIn)

-- RESURRECT_REQUEST gives a bare name only, no unit token. you're dead so your target
-- could be anyone, resolved the same way /wr resolves a typed name: target first, then
-- nameplate, else name-only
local function onResurrectRequest(name)
	if not name or name == "" then
		return
	end

	local settings = ns.GetSettings().autoTrack
	local option = settings.rez
	if not (settings.enabled and option.enabled) then
		return
	end

	local first, last = ns.SplitNameSuffix(name)
	local identity, unit = ns.ResolveDisplayName(first, last)
	logAuto(identity.key, identity, unit, "auto-rez", option.repGain, option.note)
end

local rezFrame = CreateFrame("Frame")
rezFrame:RegisterEvent("RESURRECT_REQUEST")
rezFrame:SetScript("OnEvent", function(_, _, name)
	onResurrectRequest(name)
end)

-- retail fires CHAT_MSG_EMOTE for keyword emotes (/wave, /thank, /dance) and
-- CHAT_MSG_TEXT_EMOTE for custom /e text. confirmed live: wave/thank/bow come through
-- CHAT_MSG_TEXT_EMOTE instead. no "directed at you" flag either way, just
-- rendered text: "<name> waves at you." vs "<name> waves." registered on both events in
-- case something else uses the standard channel
local DIRECTED_EMOTE_DEFS = {
	{ key = "wave", keyword = "wave" },
	{ key = "thank", keyword = "thank" },
	{ key = "bow", keyword = "bow" },
}

-- last log time per player, session-only, keyed separately per emote type: waving then
-- thanking the same player logs both, each on its own cooldown
local lastEmoteAt = {}

local function onChatEmote(text, playerName, guid)
	if not text or not playerName or playerName == "" then
		return
	end
	-- a self-performed emote comes through with a blank playerName on this server
	-- (confirmed live), not your own name, so the name check below never catches it.
	-- guid does identify you correctly, so check that too.
	if playerName == ns.GetMyFullName() or (guid and guid == UnitGUID("player")) then
		return
	end

	-- matches "you" as a whole word anywhere, not just the end, since "at you" phrasing
	-- varies. free-form /e text also routes through this event, so a custom emote with
	-- both a keyword and "you" could rarely false-positive. acceptable for now
	local lower = text:lower()
	if not lower:match("%f[%a]you%f[%A]") then
		return
	end

	for _, def in ipairs(DIRECTED_EMOTE_DEFS) do
		if lower:find(def.keyword, 1, true) then
			local settings = ns.GetSettings().autoTrack
			local option = settings[def.key]
			if settings.enabled and option.enabled then
				local first, last = ns.SplitNameSuffix(playerName)
				local identity, unit = ns.ResolveDisplayName(first, last)
				local cooldownSeconds = (option.cooldownMinutes or 5) * 60
				local now = time()
				local trackKey = def.key .. ":" .. identity.key
				local lastLoggedAt = lastEmoteAt[trackKey]
				if not lastLoggedAt or (now - lastLoggedAt) >= cooldownSeconds then
					lastEmoteAt[trackKey] = now
					logAuto(identity.key, identity, unit, "auto-" .. def.key, option.repGain, option.note)
				end
			end
			return
		end
	end
end

local emoteFrame = CreateFrame("Frame")
emoteFrame:RegisterEvent("CHAT_MSG_EMOTE")
emoteFrame:RegisterEvent("CHAT_MSG_TEXT_EMOTE")
emoteFrame:SetScript("OnEvent", function(_, _, text, playerName, ...)
	-- scanned by pattern instead of a fixed arg position: this event's trailing args
	-- don't match the documented order on this server (confirmed live, see the
	-- playerName issue above), but a GUID always looks like "Player-...".
	local guid
	for i = 1, select("#", ...) do
		local value = select(i, ...)
		if type(value) == "string" and value:find("^Player%-") then
			guid = value
			break
		end
	end
	onChatEmote(text, playerName, guid)
end)

-- "completing" a dungeon/raid is approximated as leaving it, not a boss-kill event:
-- classic doesn't expose a reliable encounter-complete signal across every instance, but
-- everyone leaving together after a run is close enough. instanceID (from
-- GetInstanceInfo, not just the zone name) is tracked rather than just inInstance/zone,
-- so stepping out to repair and porting back into the SAME still-active instance doesn't
-- look like a fresh run.
local currentInstanceID
local currentInstanceName
local dungeonStartLogged = false

-- identity + context for every current party/raid member, captured together while their
-- unit tokens are still valid. used by both auto-log and the survey popup so each party
-- member's context (their level, etc) is resolved once, not re-derived per feature.
local function snapshotPartyMembers()
	local members = {}
	for _, unit in ipairs(getCurrentPartyUnits()) do
		local identity = ns.IdentifyUnit(unit)
		if identity then
			members[#members + 1] = { identity = identity, context = ns.CaptureContext(unit) }
		end
	end
	return members
end

local function logDungeonForParty(members, instanceName, option)
	for _, member in ipairs(members) do
		ns.TouchIdentity(member.identity.key, member.identity)
		-- member.context's own zone is whatever GetZoneText() said at snapshot time,
		-- which on the completion path is already back outside the instance by then.
		-- overridden with the instance name captured at entry so {{loc}} in the note
		-- reads as the dungeon/raid, not wherever everyone ended up.
		local entry = {}
		for k, v in pairs(member.context) do
			entry[k] = v
		end
		entry.zone = instanceName
		entry.delta = (option.repGain and option.repGain ~= 0) and option.repGain or nil
		entry.source = "auto-dungeon"
		if option.note and option.note ~= "" then
			entry.text = ns.FillPlaceholders(option.note, entry)
		end
		ns.AddEntry(member.identity.key, member.identity, entry)
	end
	ns.RefreshAllTabs()
end

local function onInstanceTransition()
	local settings = ns.GetSettings().dungeonTracking
	local inInstance, instanceType = IsInInstance()

	if inInstance and (instanceType == "party" or instanceType == "raid") then
		local name, _, _, _, _, _, _, instanceID = GetInstanceInfo()
		if instanceID ~= currentInstanceID then
			currentInstanceID = instanceID
			currentInstanceName = name
			dungeonStartLogged = false
		end
		if settings.autoLog.enabled and not settings.autoLog.onlyOnCompletion and not dungeonStartLogged then
			dungeonStartLogged = true
			logDungeonForParty(snapshotPartyMembers(), currentInstanceName, settings.autoLog)
		end
	elseif currentInstanceID then
		-- snapshotted once, used by whichever of the two features (both, either, or
		-- neither) is actually enabled, rather than re-deriving it per feature
		local needMembers = (settings.autoLog.enabled and settings.autoLog.onlyOnCompletion) or settings.survey.enabled
		local members = needMembers and snapshotPartyMembers() or nil

		if settings.autoLog.enabled and settings.autoLog.onlyOnCompletion then
			logDungeonForParty(members, currentInstanceName, settings.autoLog)
		end
		if settings.survey.enabled and members and #members > 0 and ns.ShowDungeonSurveyPrompt then
			ns.ShowDungeonSurveyPrompt(members, currentInstanceName)
		end

		currentInstanceID = nil
		currentInstanceName = nil
		dungeonStartLogged = false
	end
end

local instanceFrame = CreateFrame("Frame")
instanceFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
instanceFrame:SetScript("OnEvent", onInstanceTransition)
