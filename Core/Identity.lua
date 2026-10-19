local ns = WorthRemembering

-- true if this client uses Name Surname (Forever) instead of Name-Realm. probed once
local usesSurnameIdentity = (Constants ~= nil and Constants.CharacterNameSeparatorConsts ~= nil)

-- Forever's actual separator (a space), not retail's hyphen. chat/context-menu senders
-- need to split on this
local SURNAME_SEPARATOR = Constants and Constants.CharacterNameSeparatorConsts
	and Constants.CharacterNameSeparatorConsts.CHARACTERNAME_SURNAME_SEPARATOR

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
		faction = record.faction,
	}, nil
end

-- Forever races come back as "<Epithet> <Race>" (e.g. "Windshaper Skyborne"), keep
-- just the last word. exposed so old records normalize without a migration
function ns.SimplifyRace(race)
	if not race then
		return nil
	end
	return race:match("(%S+)$") or race
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
	local race = ns.SimplifyRace(UnitRace(unit))
	local faction = UnitFactionGroup(unit)

	return {
		key = key,
		name = name,
		realmOrSurname = realmOrSurname,
		guid = guid,
		classFile = classFile,
		race = race,
		faction = faction,
	}
end
