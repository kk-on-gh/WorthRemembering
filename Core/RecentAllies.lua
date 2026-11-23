local ns = WorthRemembering

-- logs entries from Blizzard's Recent Allies history (C_RecentAllies). see
-- settings.recentAllies (Namespace.lua) and ns.RECENT_ALLY_TYPE_DEFS

local typeKeyByEnum = {}
for _, def in ipairs(ns.RECENT_ALLY_TYPE_DEFS) do
	for _, enumValue in ipairs(def.types) do
		typeKeyByEnum[enumValue] = def.key
	end
end

local function isSecret(v)
	return issecretvalue and issecretvalue(v)
end

function ns.IsRecentAlliesSupported()
	if not (C_RecentAllies and C_RecentAllies.IsSystemSupported and C_RecentAllies.IsSystemEnabled) then
		return false
	end
	local ok, supported, enabled = pcall(function()
		return C_RecentAllies.IsSystemSupported(), C_RecentAllies.IsSystemEnabled()
	end)
	return ok and supported and enabled or false
end

-- called when the feature is switched on, so only interactions from then on get logged
function ns.ResetRecentAlliesWatermark()
	local settings = ns.GetSettings().recentAllies
	settings.since = time()
	wipe(settings.seen)
end

-- guid -> key over every saved player, built once per scan instead of walking every
-- record per ally. cleared after each scan so it never goes stale
local guidIndex

local function findKeyByGUID(guid)
	if not guidIndex then
		guidIndex = {}
		for _, key in ipairs(ns.GetAllPlayerKeys()) do
			local record = ns.GetPlayerRecord(key)
			if record and record.guid then
				guidIndex[record.guid] = key
			end
		end
	end
	local key = guidIndex[guid]
	if key then
		return key, ns.GetPlayerRecord(key)
	end
end

-- an existing record keeps its own name fields: Forever's fullName format here is
-- unconfirmed, and a mis-split shouldn't overwrite a record's known-good name
local function buildIdentity(character)
	local classInfo = C_CreatureInfo and character.classID and C_CreatureInfo.GetClassInfo(character.classID)
	local raceInfo = C_CreatureInfo and character.raceID and C_CreatureInfo.GetRaceInfo(character.raceID)
	local identity = {
		guid = character.guid,
		classFile = classInfo and classInfo.classFile,
		race = raceInfo and ns.SimplifyRace(raceInfo.raceName),
		raceID = character.raceID,
		sex = ns.SexFromEnum(character.sex),
		sexRaw = ns.RawSexTag("enum", character.sex),
	}

	local key, record = findKeyByGUID(character.guid)
	if key then
		identity.key, identity.name, identity.realmOrSurname = key, record.name, record.realmOrSurname
		return identity
	end

	local first, last = ns.SplitNameSuffix(character.fullName or character.name or "")
	identity.key = ns.BuildKey(first, last, character.guid)
	identity.name, identity.realmOrSurname = first, last
	return identity
end

-- per player + type key, session-only like the other auto-track cooldowns. compared
-- against interaction timestamps rather than now, since interactions can arrive late
local lastLoggedAt = {}

local function logInteraction(identity, character, interaction, typeKey, settings)
	if ns.IsIgnored(identity.key, "auto", identity.guid) then
		return
	end
	local context = interaction.contextData or {}
	local zone = context.locationName
	if not zone or zone == "" or isSecret(zone) then
		zone = GetZoneText()
	end

	local entry = {
		time = interaction.timestamp,
		yourLevel = UnitLevel("player"),
		theirLevel = character.level,
		zone = zone,
		source = "auto-recentally",
		delta = (settings.repGain and settings.repGain ~= 0) and settings.repGain or nil,
	}

	if settings.note and settings.note ~= "" then
		local description = interaction.description
		if not description or isSecret(description) then
			description = typeKey
		end
		local text = settings.note:gsub("{{%s*interaction%s*}}", (description:gsub("%%", "%%%%")))
		entry.text = ns.FillPlaceholders(text, entry)
	end

	ns.AddEntry(identity.key, identity, entry)
end

local function byTimestamp(a, b)
	return a.timestamp < b.timestamp
end

-- returns true if anything was logged
local function processAlly(ally, settings)
	local character = ally and ally.characterData
	local interactionData = ally and ally.interactionData
	local interactions = interactionData and interactionData.interactions
	if not character or type(interactions) ~= "table" then
		return false
	end
	local guid = character.guid
	if not guid or isSecret(guid) or guid == UnitGUID("player") then
		return false
	end

	local threshold = math.max(settings.seen[guid] or 0, settings.since or 0)
	local fresh = {}
	for _, interaction in ipairs(interactions) do
		local ts = interaction.timestamp
		if type(ts) == "number" and not isSecret(ts) and ts > threshold then
			fresh[#fresh + 1] = interaction
		end
	end
	if #fresh == 0 then
		return false
	end
	table.sort(fresh, byTimestamp)
	settings.seen[guid] = fresh[#fresh].timestamp

	local identity
	local logged = false
	local cooldownSeconds = (settings.cooldownMinutes or 0) * 60
	for _, interaction in ipairs(fresh) do
		local typeKey = typeKeyByEnum[interaction.type]
		if typeKey and settings.types[typeKey] and not ns.IsAllyKindDisabled(typeKey) then
			identity = identity or buildIdentity(character)
			if identity.key then
				local trackKey = typeKey .. ":" .. identity.key
				local last = lastLoggedAt[trackKey]
				if not last or (interaction.timestamp - last) >= cooldownSeconds then
					lastLoggedAt[trackKey] = interaction.timestamp
					logInteraction(identity, character, interaction, typeKey, settings)
					logged = true
				end
			end
		end
	end
	return logged
end

local function activeSettings()
	local settings = ns.GetSettings().recentAllies
	if not settings.enabled or not ns.GetSettings().autoTrack.enabled or not ns.IsRecentAlliesSupported() then
		return nil
	end
	if not settings.since then
		ns.ResetRecentAlliesWatermark()
	end
	return settings
end

local function scanAll()
	local settings = activeSettings()
	if not settings or not C_RecentAllies.IsRecentAllyDataReady() then
		return
	end
	local ok, allies = pcall(C_RecentAllies.GetRecentAllies)
	if not ok or type(allies) ~= "table" then
		return
	end
	local logged = false
	ns.RunEntryBatch(function()
		for _, ally in ipairs(allies) do
			local allyOk, allyLogged = pcall(processAlly, ally, settings)
			logged = logged or (allyOk and allyLogged)
		end
	end)
	guidIndex = nil
	if logged then
		ns.RefreshAllTabs()
	end
end

local function scanOne(guid)
	local settings = activeSettings()
	if not settings or not guid or isSecret(guid) then
		return
	end
	local ok, ally = pcall(C_RecentAllies.GetRecentAllyByGUID, guid)
	if not ok or not ally then
		return
	end
	local processOk, logged
	ns.RunEntryBatch(function()
		processOk, logged = pcall(processAlly, ally, settings)
	end)
	guidIndex = nil
	if processOk and logged then
		ns.RefreshAllTabs()
	end
end

local pendingScan
local function queueScanAll()
	if pendingScan then
		pendingScan:Cancel()
	end
	pendingScan = C_Timer.NewTimer(1, scanAll)
end

-- passive only: the client fetches new data when Blizzard's own panel asks for it, and
-- TryRequestRecentAlliesData is blocked from addon code (confirmed live)
local frame = CreateFrame("Frame")
ns.GateEvents(frame, {
	"PLAYER_ENTERING_WORLD", "RECENT_ALLIES_DATA_READY", "RECENT_ALLIES_CACHE_UPDATE",
	"RECENT_ALLIES_SYSTEM_STATUS_UPDATED", "RECENT_ALLY_DATA_UPDATED",
}, function(_, event, arg1)
	if event == "RECENT_ALLY_DATA_UPDATED" then
		scanOne(arg1)
	else
		queueScanAll()
	end
end, true)
