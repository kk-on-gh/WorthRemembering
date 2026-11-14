local ns = WorthRemembering

-- true if this client uses Name Surname (Forever) instead of Name-Realm. probed once
local usesSurnameIdentity = (Constants ~= nil and Constants.CharacterNameSeparatorConsts ~= nil)

-- Forever's actual separator (a space), not retail's hyphen. chat/context-menu senders
-- need to split on this
local SURNAME_SEPARATOR = Constants and Constants.CharacterNameSeparatorConsts
	and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR

-- full name as /targetexact expects it: "Name Surname" on Forever, "Name-Realm" on retail
function ns.TargetNameFor(record)
	if not (record and record.name) then
		return nil
	end
	local suffix = record.realmOrSurname
	if not suffix or suffix == "" then
		return record.name
	end
	return record.name .. (usesSurnameIdentity and (SURNAME_SEPARATOR or " ") or "-") .. suffix
end

-- splits a joined sender string into name/suffix for ns.BuildKey, regardless of separator
function ns.SplitNameSuffix(fullName)
	if SURNAME_SEPARATOR then
		local idx = fullName:find(SURNAME_SEPARATOR, 1, true)
		if idx then
			return fullName:sub(1, idx - 1), fullName:sub(idx + #SURNAME_SEPARATOR)
		end
		return fullName, nil
	end
	local name, suffix = fullName:match("^([^%-]+)%-(.+)$")
	return name or fullName, suffix
end

local function normalizeRealm(realm)
	if not realm or realm == "" then
		if GetNormalizedRealmName then
			realm = GetNormalizedRealmName()
		end
		if not realm or realm == "" then
			realm = (GetRealmName() or ""):gsub("%s+", "")
		end
	end
	return realm
end

-- builds the record key: Name-Realm, or Name-Surname on Forever. falls back to
-- guid:XXXX if neither is known yet (e.g. chat line before the name resolved).
-- callers should repair a guid-only record later, never by name match alone.
-- lowercased, display casing lives in record.name/realmOrSurname (Database.AddEntry)
function ns.BuildKey(name, realmOrSurname, guid)
	if name and name ~= "" then
		if usesSurnameIdentity then
			if realmOrSurname and realmOrSurname ~= "" then
				return (name .. "-" .. realmOrSurname):lower()
			end
		else
			local realm = normalizeRealm(realmOrSurname)
			if realm and realm ~= "" then
				return (name .. "-" .. realm):lower()
			end
		end
	end

	if guid and guid ~= "" then
		return "guid:" .. guid
	end

	return nil
end

-- full display name for the logged-in character. UnitName("player") returns two values
-- on Forever, call sites that only grabbed the first were silently dropping the surname
function ns.GetMyFullName()
	local name, surnameOrRealm = UnitName("player")
	if usesSurnameIdentity and surnameOrRealm and surnameOrRealm ~= "" then
		return name .. " " .. surnameOrRealm
	end
	return name
end

-- record name for UI display. falls back to just the name, then the raw key
function ns.DisplayName(record, key)
	if not record or not record.name then
		return key
	end
	if record.realmOrSurname and record.realmOrSurname ~= "" then
		return record.name .. " " .. record.realmOrSurname
	end
	return record.name
end

-- live unit token for this name, else nil. checks target first, then nameplates
-- (ns.FindNameplateUnit). used to snapshot level into manual or auto-tracked entries
function ns.FindLiveUnit(name, realmOrSurname)
	if UnitExists("target") and UnitIsPlayer("target") then
		local targetName, targetSurnameOrRealm = UnitName("target")
		if targetName == name and (not realmOrSurname or targetSurnameOrRealm == realmOrSurname) then
			return "target"
		end
	end
	if ns.FindNameplateUnit then
		return ns.FindNameplateUnit(name, realmOrSurname)
	end
	return nil
end

-- resolves a bare name like /wr does: real identity if a live unit matches, else
-- name-only with no realm/GUID to confirm. 2nd return is the unit token, if any
function ns.ResolveDisplayName(firstName, lastName)
	local unit = ns.FindLiveUnit(firstName, lastName)
	if unit then
		-- nameplate can go stale between the name match and this re-query, which used to
		-- return nil here and crash every caller on identity.key
		local identity = ns.IdentifyUnit(unit)
		if identity then
			return identity, unit
		end
	end
	local key = ns.BuildKey(firstName, lastName, nil) or firstName
	return { key = key, name = firstName, realmOrSurname = lastName, guid = nil }, nil
end

-- identity for an existing record. prefers live unit data if it matches your target,
-- else cached fields. shared by quick-add popup and the inline +/- buttons
function ns.LiveIdentityForRecord(record)
	local unit = ns.FindLiveUnit(record.name, record.realmOrSurname)
	if unit then
		return ns.IdentifyUnit(unit), unit
	end
	return {
		name = record.name,
		realmOrSurname = record.realmOrSurname,
		guid = record.guid,
		classFile = record.classFile,
		race = record.race,
		raceID = record.raceID,
		faction = record.faction,
		sex = record.sex,
		sexRaw = record.sexRaw,
	}, nil
end

-- every race name the client knows, longest first, built on first use
local knownRaceNames

local function getKnownRaceNames()
	if knownRaceNames then
		return knownRaceNames
	end
	knownRaceNames = {}
	if C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
		local seen = {}
		for id = 1, 200 do
			local info = C_CreatureInfo.GetRaceInfo(id)
			local raceName = info and info.raceName
			if raceName and raceName ~= "" and not seen[raceName] then
				seen[raceName] = true
				knownRaceNames[#knownRaceNames + 1] = raceName
			end
		end
	end
	table.sort(knownRaceNames, function(a, b) return #a > #b end)
	return knownRaceNames
end

local function endsWithRace(text, raceName)
	return text == raceName or text:sub(-(#raceName + 1)) == " " .. raceName
end

-- Forever races come back as "<Epithet> <Race>" (e.g. "Windshaper Skyborne"), strips
-- the epithet while keeping multi-word races whole ("Blood Elf", "Kul Tiran"). raceID
-- (UnitRace's 3rd return) pins the exact race when known. also used at display time so
-- older records normalize without a migration
function ns.SimplifyRace(race, raceID)
	if not race then
		return nil
	end
	if raceID and C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
		local info = C_CreatureInfo.GetRaceInfo(raceID)
		if info and info.raceName and endsWithRace(race, info.raceName) then
			return info.raceName
		end
	end
	for _, raceName in ipairs(getKnownRaceNames()) do
		if endsWithRace(race, raceName) then
			return raceName
		end
	end
	return race:match("(%S+)$") or race
end

local raceNameByID = {}

-- the race to show for a record: looked up from its raceID in the client's own language
-- when it has one, else the saved name (older records, until they're seen again)
function ns.RaceDisplay(record)
	local raceID = record.raceID
	if raceID then
		local name = raceNameByID[raceID]
		if not name and C_CreatureInfo and C_CreatureInfo.GetRaceInfo then
			local info = C_CreatureInfo.GetRaceInfo(raceID)
			name = info and info.raceName
			raceNameByID[raceID] = name
		end
		if name and name ~= "" then
			return name
		end
	end
	return ns.SimplifyRace(record.race)
end

-- unit token to {key, name, realmOrSurname, guid, classFile, race, faction}, nil if
-- invalid or not a player. classFile/race/faction only ever set from a live unit,
-- display code must tolerate any of them being nil
function ns.IdentifyUnit(unit)
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then
		return nil
	end

	local name, realmOrSurname = UnitName(unit)
	local guid = UnitGUID(unit)
	local key = ns.BuildKey(name, realmOrSurname, guid)
	if not key then
		return nil
	end

	local _, classFile = UnitClass(unit)
	local raceName, _, raceID = UnitRace(unit)
	local race = ns.SimplifyRace(raceName, raceID)
	local faction = UnitFactionGroup(unit)

	return {
		key = key,
		name = name,
		realmOrSurname = realmOrSurname,
		guid = guid,
		classFile = classFile,
		race = race,
		raceID = raceID,
		faction = faction,
		sex = ns.NormalizeUnitSex(ns.SafeUnitSex(unit)),
		sexRaw = ns.RawSexTag("unit", ns.SafeUnitSex(unit)),
	}
end
