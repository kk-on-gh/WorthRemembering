local ns = WorthRemembering

local db

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local copy = {}
	for k, v in pairs(value) do
		copy[k] = deepCopy(v)
	end
	return copy
end

-- deep-merges missing defaults into target without touching existing values. array-like
-- defaults (quickPresets.items) are only filled in wholesale if missing entirely, never
-- merged index by index, or deleting an item would resurrect whatever default sat there
local function isArrayLike(t)
	return t[1] ~= nil
end

local function applyDefaults(target, defaults)
	for k, v in pairs(defaults) do
		if target[k] == nil then
			target[k] = deepCopy(v)
		elseif type(v) == "table" and type(target[k]) == "table" and not isArrayLike(v) then
			applyDefaults(target[k], v)
		end
	end
end

-- advances savedDb from its schemaVersion to current. each block must stay idempotent
-- since applyDefaults can't fix a value that already exists
local function migrate(savedDb)
	local from = savedDb.schemaVersion or 0

	if from < 1 then
		-- v1: initial schema.
	end

	if from < 2 then
		-- v2: overwrite autoTrack with current defaults, since prior defaults were
		-- already saved and applyDefaults won't touch an existing key.
		if savedDb.settings and savedDb.settings.autoTrack then
			savedDb.settings.autoTrack = deepCopy(ns.Defaults.settings.autoTrack)
		end
	end

	if from < 3 then
		-- v3: replace the newEntrySound default only if it still exactly matches the
		-- old default (never overwrite a sound the user picked themselves).
		local entrySound = savedDb.settings and savedDb.settings.newEntrySound
		if entrySound and entrySound.useCustom and entrySound.customPath == "Sound\\interface\\WriteQuest.ogg" then
			savedDb.settings.newEntrySound = deepCopy(ns.Defaults.settings.newEntrySound)
		end
	end

	if from < 4 then
		-- v4: append the Healed/Rezzed/Buffed Me quick-add presets, matched by label so
		-- this never duplicates or restores a preset the user has since edited or removed.
		local presets = savedDb.settings and savedDb.settings.quickPresets
		if presets and presets.items then
			local haveLabel = {}
			for _, item in ipairs(presets.items) do
				haveLabel[item.label] = true
			end
			for _, newItem in ipairs(ns.Defaults.settings.quickPresets.items) do
				if (newItem.label == "Healed Me" or newItem.label == "Rezzed Me" or newItem.label == "Buffed Me")
					and not haveLabel[newItem.label] then
					presets.items[#presets.items + 1] = deepCopy(newItem)
				end
			end
		end
	end

	if from < 5 then
		-- v5: real filename is WriteQuestC, not WriteQuest. replace only if it still
		-- matches v3's default
		local entrySound = savedDb.settings and savedDb.settings.newEntrySound
		if entrySound and not entrySound.useCustom and entrySound.kit == (SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN or 851) then
			savedDb.settings.newEntrySound = deepCopy(ns.Defaults.settings.newEntrySound)
		end
	end

	if from < 6 then
		-- v6: string path doesn't play either, only the FileDataID works. replace only
		-- if it still matches v5's default
		local entrySound = savedDb.settings and savedDb.settings.newEntrySound
		if entrySound and entrySound.useCustom and entrySound.customPath == "Sound\\interface\\WriteQuestC.ogg" then
			savedDb.settings.newEntrySound = deepCopy(ns.Defaults.settings.newEntrySound)
		end
	end

	if from < 7 then
		-- v7: emote cooldown is now per-trigger (wave/thank/bow) instead of one shared
		-- autoTrack.emoteCooldownMinutes value
		local autoTrack = savedDb.settings and savedDb.settings.autoTrack
		local sharedCooldown = autoTrack and autoTrack.emoteCooldownMinutes
		if autoTrack and sharedCooldown then
			for _, key in ipairs({ "wave", "thank", "bow" }) do
				if autoTrack[key] then
					autoTrack[key].cooldownMinutes = sharedCooldown
				end
			end
			autoTrack.emoteCooldownMinutes = nil
		end
	end

	if from < 8 then
		-- v8: wave/thank/bow become the first entries of the user-editable emoteRules
		-- list, keeping each one's enabled/rep/note/cooldown
		local autoTrack = savedDb.settings and savedDb.settings.autoTrack
		if autoTrack then
			if autoTrack.emoteRules == nil and (autoTrack.wave or autoTrack.thank or autoTrack.bow) then
				local rules = {}
				for _, default in ipairs(ns.Defaults.settings.autoTrack.emoteRules) do
					local rule = deepCopy(default)
					local old = autoTrack[rule.match]
					if old then
						for _, field in ipairs({ "enabled", "repGain", "note", "cooldownMinutes" }) do
							if old[field] ~= nil then
								rule[field] = old[field]
							end
						end
					end
					rules[#rules + 1] = rule
				end
				autoTrack.emoteRules = rules
			end
			autoTrack.wave, autoTrack.thank, autoTrack.bow = nil, nil, nil
		end
	end

	savedDb.schemaVersion = ns.CURRENT_SCHEMA_VERSION
end

function ns.InitDatabase()
	WorthRememberingDB = WorthRememberingDB or {}
	db = WorthRememberingDB

	migrate(db)
	applyDefaults(db, ns.Defaults)

	return db
end

function ns.GetSettings()
	return db.settings
end

-- stored outside settings, but cleared by Reset All Options too (see ns.ResetAllSettings)
function ns.GetLastSeenVersion()
	return db.lastSeenVersion
end

function ns.SetLastSeenVersion(version)
	db.lastSeenVersion = version
end

-- the tour is offered once per account, new install or existing user
function ns.WasTourOffered()
	return db.tourOffered == true
end

function ns.MarkTourOffered()
	db.tourOffered = true
end

function ns.GetPlayerRecord(key, create)
	local record = db.players[key]
	if not record and create then
		record = { entries = {}, standing = 0, createdAt = time() }
		db.players[key] = record
	end
	return record
end

function ns.GetAllPlayerKeys()
	local keys = {}
	for key in pairs(db.players) do
		keys[#keys + 1] = key
	end
	return keys
end

-- creates/refreshes a record's identity fields without logging an entry. used when a
-- record needs to exist before anything's been logged (e.g. opening a fresh player log)
function ns.TouchIdentity(key, identity)
	local record = ns.GetPlayerRecord(key, true)
	record.name = identity and identity.name or record.name
	record.realmOrSurname = identity and identity.realmOrSurname or record.realmOrSurname
	record.guid = identity and identity.guid or record.guid
	record.classFile = identity and identity.classFile or record.classFile
	record.race = identity and identity.race or record.race
	record.raceID = identity and identity.raceID or record.raceID
	record.faction = identity and identity.faction or record.faction
	record.sex = identity and identity.sex or record.sex
	record.sexRaw = identity and identity.sexRaw or record.sexRaw
	return record
end

-- stamps lastSeen from a nameplate sighting, independent of whether it logs an entry.
-- only touches existing records, never creates one
-- force: a deliberate interaction (grouping), counted even while resting
function ns.TouchLastSeen(key, force)
	local record = ns.GetPlayerRecord(key, false)
	if not record then
		return
	end
	if not force and ns.GetSettings().seenCountSkipWhileResting and IsResting() then
		return
	end
	record.lastSeen = time()
	record.lastLocation = GetZoneText()
end

-- bumps seen count, gated by seenCountCooldownMinutes so losing/regaining a nameplate
-- briefly only counts once. own timestamp (lastSeenCountAt), separate from lastSeen
-- which updates on every sighting
function ns.IncrementSeenCount(key, force)
	local record = ns.GetPlayerRecord(key, false)
	if not record then
		return
	end
	local settings = ns.GetSettings()
	if not force and settings.seenCountSkipWhileResting and IsResting() then
		return
	end
	local cooldownSeconds = (settings.seenCountCooldownMinutes or 5) * 60
	local now = time()
	if record.lastSeenCountAt and (now - record.lastSeenCountAt) < cooldownSeconds then
		return
	end
	record.seenCount = (record.seenCount or 0) + 1
	record.lastSeenCountAt = now
end

-- inside ns.RunEntryBatch, the new-entry sound is held back and played once at the end
local batchDepth, batchWantsSound = 0, false

-- runs fn, which may add any number of entries, playing the new-entry sound at most
-- once afterward (e.g. one survey save or one party-wide auto-log, not one per player)
function ns.RunEntryBatch(fn)
	batchDepth = batchDepth + 1
	local ok, err = pcall(fn)
	batchDepth = batchDepth - 1
	if batchDepth == 0 and batchWantsSound then
		batchWantsSound = false
		local settings = ns.GetSettings()
		ns.PlayConfiguredSound(settings.newEntrySound, settings.soundChannel)
	end
	if not ok then
		error(err, 0)
	end
end

-- appends a timestamped entry. fields: text, delta, source, yourLevel, theirLevel, zone,
-- all optional. never mutates prior entries. loggedBy is always auto-stamped since the
-- DB is shared across characters, History filters on it
function ns.AddEntry(key, identity, entry)
	local record = ns.TouchIdentity(key, identity)

	entry.time = entry.time or time()
	-- their sex at the time of this entry (History shows this, Players shows the
	-- record's current one), from the live unit when there was one
	entry.theirSex = entry.theirSex or (identity and identity.sex) or record.sex
	entry.theirSexRaw = entry.theirSexRaw or (identity and identity.sexRaw) or record.sexRaw
	entry.loggedBy = entry.loggedBy or ns.GetMyFullName()
	-- A featured entry with no note text would show as a blank quote on the Details
	-- tab, so the flag can't survive without one.
	if not entry.text then
		entry.featured = nil
	end
	-- the rep box is a free-typed number, nothing upstream stops someone entering e.g.
	-- 500: only the resulting *standing* total used to get clamped here, leaving the
	-- stored entry.delta itself (and whatever it showed in History) over the real cap
	if entry.delta then
		entry.delta = ns.ClampDelta(entry.delta)
	end
	record.entries[#record.entries + 1] = entry

	local hasContent = (entry.text and entry.text ~= "") or (entry.delta and entry.delta ~= 0)
	if hasContent and ns.GetSettings().showEntryCreatedMessage then
		ns.Print("Entry created for " .. ns.DisplayName(record, key))
	end

	-- auto-nearby entries can fire once per stranger in a crowd, so they never play the
	-- new-entry sound. group-wide logging goes through ns.RunEntryBatch instead
	local settings = ns.GetSettings()
	local soundSettings = settings.newEntrySound
	local muted = entry.source == "auto-nearby"
	if soundSettings.enabled and not muted then
		if batchDepth > 0 then
			batchWantsSound = true
		else
			ns.PlayConfiguredSound(soundSettings, settings.soundChannel)
		end
	end

	if entry.delta and entry.delta ~= 0 then
		local newStanding = (record.standing or 0) + entry.delta
		if newStanding > ns.STANDING_MAX then
			newStanding = ns.STANDING_MAX
		elseif newStanding < ns.STANDING_MIN then
			newStanding = ns.STANDING_MIN
		end
		record.standing = newStanding
	end

	return record
end

-- recomputes standing as the sum of every delta, clamped once. used after edit/delete
-- since incrementally patching the running total risks drift
function ns.RecomputeStanding(record)
	local total = 0
	for _, entry in ipairs(record.entries) do
		total = total + (entry.delta or 0)
	end
	record.standing = math.max(ns.STANDING_MIN, math.min(ns.STANDING_MAX, total))
end

-- mutates an entry's text/delta/featured in place and recomputes standing. doesn't
-- touch time/loggedBy/source, editing a note shouldn't rewrite who/when logged it
function ns.EditEntry(key, entry, newText, newDelta, newFeatured)
	local record = ns.GetPlayerRecord(key, false)
	if not record then
		return
	end
	entry.text = (newText and newText ~= "") and newText or nil
	entry.delta = (newDelta and newDelta ~= 0) and ns.ClampDelta(newDelta) or nil
	-- Same "no text, no feature" rule AddEntry enforces.
	entry.featured = (newFeatured and entry.text) and true or nil
	ns.RecomputeStanding(record)
end

function ns.DeleteEntry(key, entry)
	local record = ns.GetPlayerRecord(key, false)
	if not record then
		return
	end
	for i, e in ipairs(record.entries) do
		if e == entry then
			table.remove(record.entries, i)
			break
		end
	end
	ns.RecomputeStanding(record)
end

function ns.GetIgnoreList()
	return db.ignored
end

function ns.IsAutoSource(source)
	return type(source) == "string" and source:sub(1, 5) == "auto-"
end

function ns.CountAutoEntries(key)
	local record = ns.GetPlayerRecord(key, false)
	local count = 0
	if record then
		for _, entry in ipairs(record.entries) do
			if ns.IsAutoSource(entry.source) then
				count = count + 1
			end
		end
	end
	return count
end

-- removes every auto-* entry for a player, keeps manual and survey ones
function ns.DeleteAutoEntries(key)
	local record = ns.GetPlayerRecord(key, false)
	if not record then
		return 0
	end
	local kept, removed = {}, 0
	for _, entry in ipairs(record.entries) do
		if ns.IsAutoSource(entry.source) then
			removed = removed + 1
		else
			kept[#kept + 1] = entry
		end
	end
	record.entries = kept
	ns.RecomputeStanding(record)
	return removed
end

-- deletes a player's whole record. callers must confirm first, this doesn't ask
function ns.DeletePlayerRecord(key)
	db.players[key] = nil
end

-- wipes every player record, leaves settings untouched. callers must confirm first
function ns.ClearDatabase()
	wipe(db.players)
end

-- every window's position/size/visibility, scale/opacity, table layouts, and the
-- Nearby window's layout. keys with no default (saved positions/sizes) reset to nil,
-- which each window treats as "never moved/resized"
local UI_SETTING_KEYS = {
	"windowPoint", "windowRelativePoint", "windowX", "windowY", "windowWidth", "windowHeight",
	"windowAlpha", "uiScale", "columnWidths", "columnVisibility", "columnOrder", "hiddenFilters", "windowPositions",
	"hidePlayersStandingButtons", "hidePlayersNewButton", "multiSelectEnabled",
	"nearbyWindowEnabled", "nearbyPoint", "nearbyScale", "nearbyIdleAlpha", "nearbyHoverAlpha",
	"nearbyGrowDirection", "nearbyVisibleRowLimit",
	"nearbyStaticSize", "nearbyStaticWidth", "nearbyStaticHeight",
	"minimapIcon",
}

-- callers reload the UI afterwards so every open window picks up the reset values
function ns.ResetUISettings()
	local settings, defaults = db.settings, ns.Defaults.settings
	for _, key in ipairs(UI_SETTING_KEYS) do
		settings[key] = deepCopy(defaults[key])
	end
	local icon, iconDefaults = settings.nameplateIcon, defaults.nameplateIcon
	icon.size, icon.offsetX, icon.offsetY = iconDefaults.size, iconDefaults.offsetX, iconDefaults.offsetY
	local survey = settings.dungeonTracking.survey
	survey.windowWidth, survey.windowHeight = nil, nil
end

-- every setting back to defaults, including the last-seen version (so the next load
-- acts like a fresh install). player records are untouched
function ns.ResetAllSettings()
	wipe(db.settings)
	applyDefaults(db.settings, ns.Defaults.settings)
	db.lastSeenVersion = nil
end

-- true if standing is exactly 0 and no entry has a note. stricter than ns.IsNotable,
-- which would spare a +5/-5 record that nets to 0
local function isZeroAndNoteless(record)
	if (record.standing or 0) ~= 0 then
		return false
	end
	for _, entry in ipairs(record.entries) do
		if entry.text and entry.text ~= "" then
			return false
		end
	end
	return true
end

-- deletes every zero-standing, noteless record. bulk cleanup for bare auto entries.
-- callers must confirm first
function ns.ClearNonNotablePlayers()
	local count = 0
	for key in pairs(db.players) do
		if isZeroAndNoteless(db.players[key]) then
			db.players[key] = nil
			count = count + 1
		end
	end
	return count
end

-- counts what ClearNonNotablePlayers would remove, without removing. for the
-- confirmation dialog
function ns.CountNonNotablePlayers()
	local count = 0
	for key in pairs(db.players) do
		if isZeroAndNoteless(db.players[key]) then
			count = count + 1
		end
	end
	return count
end

local function hasAnyNote(record)
	for _, entry in ipairs(record.entries) do
		if entry.text and entry.text ~= "" then
			return true
		end
	end
	return false
end

local function lastSeenTime(record)
	if record.lastSeen then
		return record.lastSeen
	end
	local lastEntry = record.entries[#record.entries]
	return lastEntry and lastEntry.time or record.createdAt
end

-- must satisfy every checked criterion, not just one
local function matchesPruneCriteria(record, criteria, notSeenDaysValue)
	if criteria.unnoted and hasAnyNote(record) then
		return false
	end
	if criteria.unrepped and (record.standing or 0) ~= 0 then
		return false
	end
	if criteria.neutral and math.abs(record.standing or 0) > ns.GetSettings().neutralBand then
		return false
	end
	if criteria.notSeenDays then
		-- no date at all means unknown, not stale
		local seen = lastSeenTime(record)
		if not seen or (time() - seen) < notSeenDaysValue * 86400 then
			return false
		end
	end
	return true
end

-- deletes every record matching all checked ns.Defaults.settings.autoPrune.criteria.
-- called on login when autoPrune.enabled, see Core/Events.lua
function ns.RunAutoPrune()
	local settings = ns.GetSettings().autoPrune
	local criteria = settings.criteria
	if not settings.enabled or not (criteria.unnoted or criteria.unrepped or criteria.neutral or criteria.notSeenDays) then
		return 0
	end
	local count = 0
	for key in pairs(db.players) do
		if matchesPruneCriteria(db.players[key], criteria, settings.notSeenDaysValue) then
			db.players[key] = nil
			count = count + 1
		end
	end
	return count
end

-- every character that's logged an entry, plus your current one even if it hasn't. for
-- the character filter dropdowns. computed fresh each call, not live, so a new alt
-- won't show in an already-open dropdown until rebuilt
function ns.GetKnownCharacters()
	local seen, list = {}, {}
	local me = ns.GetMyFullName()
	seen[me] = true
	list[1] = me

	for _, key in ipairs(ns.GetAllPlayerKeys()) do
		local record = ns.GetPlayerRecord(key, false)
		if record then
			for _, entry in ipairs(record.entries) do
				if entry.loggedBy and not seen[entry.loggedBy] then
					seen[entry.loggedBy] = true
					list[#list + 1] = entry.loggedBy
				end
			end
		end
	end

	return list
end

-- every distinct classFile/race/faction value seen, same approach/limitation as
-- ns.GetKnownCharacters. normalize (e.g. ns.SimplifyRace) cleans and dedupes, so old
-- and new formats collapse into one option
local function knownFieldValues(fieldName, normalize)
	local seen, list = {}, {}
	for _, key in ipairs(ns.GetAllPlayerKeys()) do
		local record = ns.GetPlayerRecord(key, false)
		local value = record and record[fieldName]
		if value and normalize then
			value = normalize(value)
		end
		if value and not seen[value] then
			seen[value] = true
			list[#list + 1] = value
		end
	end
	return list
end

function ns.GetKnownClasses()
	return knownFieldValues("classFile")
end

function ns.GetKnownRaces()
	local seen, list = {}, {}
	for _, key in ipairs(ns.GetAllPlayerKeys()) do
		local record = ns.GetPlayerRecord(key, false)
		local race = record and ns.RaceDisplay(record)
		if race and not seen[race] then
			seen[race] = true
			list[#list + 1] = race
		end
	end
	return list
end

function ns.GetKnownFactions()
	return knownFieldValues("faction")
end

-- notable if they have a note or standing outside the neutral band. an entry only
-- counts if it has text or a nonzero delta, bare auto-nearby entries don't count
function ns.IsNotable(record)
	if not record then
		return false
	end
	for _, entry in ipairs(record.entries) do
		if (entry.text and entry.text ~= "") or (entry.delta and entry.delta ~= 0) then
			return true
		end
	end
	local band = ns.GetSettings().neutralBand
	return math.abs(record.standing or 0) > band
end

-- random featured entry with note text, or nil. `exclude` drops one entry from the pool
function ns.PickFeaturedEntry(record, exclude)
	local candidates = {}
	for _, entry in ipairs(record.entries) do
		if entry.featured and entry ~= exclude and entry.text and entry.text ~= "" then
			candidates[#candidates + 1] = entry
		end
	end
	return candidates[1] and candidates[math.random(#candidates)] or nil
end

-- broader than ns.IsNotable: true for any history at all, including bare auto-nearby
-- entries. used for the Players tab roster, so every seen player gets a row even
-- without a note
function ns.HasEntries(record)
	return record ~= nil and #record.entries > 0
end
