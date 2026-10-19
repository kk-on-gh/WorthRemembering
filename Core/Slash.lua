local ns = WorthRemembering

-- commands for adding/inspecting records by typed name. matches your target, pull a
-- real identity off the unit. otherwise keys on the name alone, no realm/GUID to confirm
local usesSurnameIdentity = (Constants ~= nil and Constants.CharacterNameSeparatorConsts ~= nil)

-- Forever displays "Firstname Lastname" as two space-separated tokens, so the name
-- portion of a typed command can't stop at the first space like on Name-Realm clients.
local function parseTypedName(msg)
	if usesSurnameIdentity then
		local first, last, tail = msg:match("^(%S+)%s+(%S+)%s*(.-)$")
		return first, last, tail or ""
	end
	local first, tail = msg:match("^(%S+)%s*(.-)$")
	return first, nil, tail or ""
end

local function printUsage()
	ns.Print("commands:")
	print("  /wr                     - open the Worth Remembering window")
	print("  /wr note <name> <text>  - add a note entry")
	print("  /wr rep <name> <delta>  - add a standing-change entry")
	print("  /wr show <name>         - print a player's record")
	print("  /wr list                - print all notable player keys")
	print("  /wr testsurvey [count]  - test the survey (and its confirm prompt) with fake data (default 4, e.g. 40 for a raid)")
end

local TEST_SURVEY_CLASSES = {
	"WARRIOR", "PALADIN", "HUNTER", "ROGUE", "PRIEST", "SHAMAN", "MAGE", "WARLOCK", "DRUID",
}

-- fills out a raid-sized test roster past however many real players the database has:
-- synthetic entries, same shape as a real IdentifyUnit() result, keyed uniquely so they
-- don't collide with real records or each other
local function fakeTestMember(index)
	return {
		identity = {
			key = "test-fake-" .. index,
			name = "TestDummy",
			realmOrSurname = tostring(index),
			classFile = TEST_SURVEY_CLASSES[math.random(#TEST_SURVEY_CLASSES)],
			faction = math.random(2) == 1 and "Horde" or "Alliance",
		},
		context = { yourLevel = UnitLevel("player"), zone = "Test Dungeon" },
	}
end

-- debug/testing only: opens the dungeon survey popup (see UI/DungeonSurvey.lua) against
-- up to <count> random existing players from the database (default 4, e.g. for raid-size
-- testing: /wr testsurvey 40), instead of waiting for a real dungeon/raid completion. Pads
-- out with synthetic fake players past however many real ones exist. Save All actually
-- writes real entries to whichever real players get pulled in.
local function cmdTestSurvey(msg)
	if not ns.ShowDungeonSurveyPrompt then
		ns.Print("dungeon survey window isn't loaded.")
		return
	end

	local count = math.max(1, math.min(40, tonumber(msg) or 4))

	local keys = ns.GetAllPlayerKeys()
	-- Fisher-Yates partial shuffle: only need the first `count`, not a full shuffle
	for i = #keys, 2, -1 do
		local j = math.random(i)
		keys[i], keys[j] = keys[j], keys[i]
	end

	local members = {}
	for i = 1, math.min(count, #keys) do
		local record = ns.GetPlayerRecord(keys[i], false)
		if record then
			members[#members + 1] = {
				identity = {
					key = keys[i],
					name = record.name,
					realmOrSurname = record.realmOrSurname,
					classFile = record.classFile,
					race = record.race,
					faction = record.faction,
				},
				context = { yourLevel = UnitLevel("player"), zone = "Test Dungeon" },
			}
		end
	end

	local fakeCount = 0
	while #members < count do
		fakeCount = fakeCount + 1
		members[#members + 1] = fakeTestMember(fakeCount)
	end

	ns.Print("|cffff4444TEST MODE|r: Save All here writes real entries to the " .. (#members - fakeCount)
		.. " real player(s) pulled in" .. (fakeCount > 0 and (" (plus " .. fakeCount .. " fake/padding)") or "") .. ".")
	-- goes through the same "would you like to fill out the survey?" gate a real
	-- completion does (unless skipConfirmation is on), rather than jumping straight to
	-- the full survey, so that prompt can be exercised/tested too
	ns.ShowDungeonSurveyPrompt(members, "Test Dungeon")
end

local function cmdNote(msg)
	local first, last, text = parseTypedName(msg)
	if not first or text == "" then
		ns.Print("Usage: /wr note <name> <text>")
		return
	end

	local identity, unit = ns.ResolveDisplayName(first, last)
	local entry = ns.CaptureContext(unit)
	entry.text = text
	entry.source = "manual"
	ns.AddEntry(identity.key, identity, entry)
	ns.Print("noted " .. ns.DisplayName(identity) .. ".")
end

local function cmdRep(msg)
	local first, last, deltaStr = parseTypedName(msg)
	local delta = tonumber(deltaStr)
	if not first or not delta then
		ns.Print("Usage: /wr rep <name> <delta>")
		return
	end

	local identity, unit = ns.ResolveDisplayName(first, last)
	local entry = ns.CaptureContext(unit)
	entry.delta = delta
	entry.source = "manual"
	local record = ns.AddEntry(identity.key, identity, entry)
	ns.Print(ns.DisplayName(identity) .. " standing is now " .. record.standing .. ".")
end

local function cmdShow(msg)
	local first, last, tail = parseTypedName(msg)
	if not first or tail ~= "" then
		ns.Print("Usage: /wr show <name>")
		return
	end

	local identity = ns.ResolveDisplayName(first, last)
	local record = ns.GetPlayerRecord(identity.key, false)
	if not record then
		ns.Print("no record for " .. ns.DisplayName(identity) .. ".")
		return
	end

	ns.Print(ns.DisplayName(identity) .. " - standing " .. (record.standing or 0) .. ", " .. #record.entries .. " entries")
	for i, entry in ipairs(record.entries) do
		local line = "  [" .. i .. "] " .. date("%Y-%m-%d %H:%M", entry.time) .. " (" .. entry.source .. ")"
		if entry.delta then
			line = line .. " delta=" .. entry.delta
		end
		if entry.text then
			line = line .. " \"" .. entry.text .. "\""
		end
		print(line)
	end
end

local function cmdList()
	local keys = ns.GetAllPlayerKeys()
	if #keys == 0 then
		ns.Print("no notable players yet.")
		return
	end

	for _, key in ipairs(keys) do
		local record = ns.GetPlayerRecord(key, false)
		if ns.IsNotable(record) then
			print("  " .. key .. " (standing " .. (record.standing or 0) .. ", " .. #record.entries .. " entries)")
		end
	end
end

-- WhisperMessenger (a commonly-installed addon) also claims the bare "/wr" string for
-- its own "/wr <name> <msg>" reply shortcut, and whichever addon's registration lands
-- last wins the exact collision, unpredictably. /wrem is a guaranteed-unique fallback.
SLASH_WR1 = "/wr"
SLASH_WR2 = "/wrem"
SlashCmdList["WR"] = function(msg)
	local cmd, rest = msg:match("^(%S*)%s*(.-)$")
	cmd = cmd:lower()

	if cmd == "" then
		ns.ToggleOverview()
	elseif cmd == "note" then
		cmdNote(rest)
	elseif cmd == "rep" then
		cmdRep(rest)
	elseif cmd == "show" then
		cmdShow(rest)
	elseif cmd == "list" then
		cmdList()
	elseif cmd == "testsurvey" then
		cmdTestSurvey(rest)
	else
		printUsage()
	end
end

-- macro-friendly: quick-add for current target in one step, no subcommand needed.
-- for a macro button or the Bindings.xml keybind
SLASH_WRQUICKNOTE1 = "/wrnote"
SlashCmdList["WRQUICKNOTE"] = function()
	ns.QuickNoteTarget()
end

-- applies a preset by label (case-insensitive) with no popup, faster than /wrnote when
-- you already know which preset you want. quotes optional, slash commands don't do
-- shell-style quote parsing anyway
local function cmdQuick(msg)
	local label = msg:match('^%s*"(.-)"%s*$') or msg:match("^%s*(.-)%s*$")
	if not label or label == "" then
		ns.Print('Usage: /wrquick <preset label>')
		return
	end
	if not UnitExists("target") or not UnitIsPlayer("target") then
		ns.Print("No player targeted.")
		return
	end

	local preset
	for _, p in ipairs(ns.GetSettings().quickPresets.items) do
		if p.label:lower() == label:lower() then
			preset = p
			break
		end
	end
	if not preset then
		ns.Print('No preset named "' .. label .. '".')
		return
	end

	local text = (preset.text and preset.text ~= "") and preset.text or nil
	local delta = (preset.delta and preset.delta ~= 0) and preset.delta or nil
	if not text and not delta then
		ns.Print('Preset "' .. preset.label .. '" has no note or standing change set.')
		return
	end

	local identity = ns.IdentifyUnit("target")
	if not identity then
		return
	end
	ns.TouchIdentity(identity.key, identity)

	local entry = ns.CaptureContext("target")
	entry.text = text and ns.FillPlaceholders(text, entry) or nil
	entry.delta = delta
	entry.source = "manual"
	local record = ns.AddEntry(identity.key, identity, entry)
	ns.RefreshAllTabs()
	ns.Print('applied "' .. preset.label .. '" to ' .. ns.DisplayName(identity) .. " (standing " .. record.standing .. ").")
end

SLASH_WRQUICK1 = "/wrquick"
SlashCmdList["WRQUICK"] = cmdQuick
