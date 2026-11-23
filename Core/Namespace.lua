local ADDON_NAME = ...

WorthRemembering = WorthRemembering or {}
local ns = WorthRemembering
ns.name = ADDON_NAME

-- display text for Bindings.xml's binding, read by the Key Bindings UI. the header
-- uses Blizzard's existing "ADDONS" category instead of a custom one: this client's
-- header lookup doesn't resolve a custom BINDING_HEADER_* global, it just shows the
-- raw "HEADER_<text>" fallback regardless.
_G["BINDING_NAME_WR_QUICKNOTE"] = "Worth Remembering"

ns.CURRENT_SCHEMA_VERSION = 8

ns.STANDING_MIN = -100
ns.STANDING_MAX = 100

function ns.ClampDelta(value)
	return math.max(ns.STANDING_MIN, math.min(ns.STANDING_MAX, value))
end

ns.Defaults = {
	schemaVersion = ns.CURRENT_SCHEMA_VERSION,
	settings = {
		neutralBand = 3,
		-- User-resized column widths for ns.CreateSortableTable instances, keyed by the
		-- table's config.tableId then by column key. Absent entries just mean "use that
		-- column's hardcoded default width".
		columnWidths = {},
		-- Hidden columns per ns.CreateSortableTable instance, keyed the same way as
		-- columnWidths above. A column is visible unless explicitly set to false here.
		columnVisibility = {},
		-- user-dragged column order per ns.CreateSortableTable instance, keyed the same
		-- way: a list of column keys. absent means the table's own default order.
		columnOrder = {},
		-- Appends a colored "[+10]"-style standing tag after a notable player's name in
		-- chat. See Core/ChatIndicator.lua.
		chatIndicator = {
			enabled = true,
		},
		-- prints "Entry created for <name>" for every new entry, regardless of source
		-- (manual, auto-track, survey, etc). off by default.
		showEntryCreatedMessage = true,
		-- opens the About tab once after updating to a new version, see Core/Events.lua
		showPatchNotesOnUpdate = true,
		-- how a player's sex is shown: values ("binary" = Male/Female, "numbered" =
		-- 1/2) and the column/label wording ("bodyType" or "sex"). see ns.SexDisplay
		bodyTypeStyle = "binary",
		bodyTypeLabel = "bodyType",
		-- WR Rep/last-note line added to a notable player's unit tooltip. see
		-- Core/Tooltip.lua.
		tooltipEnabled = true,
		-- filter id -> true to hide it from that tab's filter bar
		hiddenFilters = { players = {}, history = {} },
		tooltipContent = {
			rating = true, lastNote = true,
			timesSeen = false, bracket = false, noteCount = false, featuredNote = false,
		},
		-- the "Worth Remembering" submenu on a player's right-click menu. see
		-- Core/ContextMenu.lua.
		contextMenuEnabled = true,
		-- what the global hotkey's plain tap does, separately for a resolved target vs
		-- a hover (only used when quickNoteHoverEnabled is also on). see
		-- ns.QuickNoteTarget/ns.PerformTapAction in UI/QuickAdd.lua. tapTargetEnabled off
		-- falls through to hover (if enabled) or the no-target fallback, same as hover
		-- already does when quickNoteHoverEnabled is off.
		tapTargetEnabled = true,
		tapTargetAction = "quicknote", -- "quicknote" | "history" | "details"
		tapHoverAction = "quicknote",
		-- Automatic logging on events the addon can observe directly. `enabled` is the
		-- category master switch; `party` logs an entry when a player joins your
		-- party/raid. Combat-log-based triggers (heal/rez/buff) are not available:
		-- addons can't register COMBAT_LOG_EVENT_UNFILTERED here.
		autoTrack = {
			enabled = true,
			-- `note` is used verbatim as the entry's text (placeholders like {{loc}} are
			-- filled in first, see ns.FillPlaceholders); left blank, the entry logs with
			-- no note at all (just the rep change, if any).
			party = { enabled = true, repGain = 1, note = "Partied in {{loc}}." },
			-- off by default, less proven than party. RESURRECT_REQUEST gives a bare name
			-- only, resolving it is less certain (see ns.ResolveDisplayName)
			rez = { enabled = true, repGain = 3, note = "Rezzed me in {{loc}}." },
			-- logged for each party/raid member on QUEST_TURNED_IN while grouped with them.
			-- long default cooldown since a questing session turns in many quests in a row
			-- minGroupedMinutes: 0 disables the check (anyone currently grouped counts
			-- regardless of how recently they joined)
			quest = { enabled = true, repGain = 5, note = "Quested together in {{loc}}.", cooldownMinutes = 30, minGroupedMinutes = 10 },
			-- directed emotes, matched against the rendered chat text, see AutoTrack.lua's
			-- onChatEmote. match is a plain, case-insensitive substring; requireYou also
			-- needs "you" as a whole word. cooldownMinutes is per player, per rule
			emoteRules = {
				{ match = "wave", requireYou = true, enabled = false, repGain = 1, note = "Waved at me.", cooldownMinutes = 5 },
				{ match = "thank", requireYou = true, enabled = false, repGain = 1, note = "Thanked me.", cooldownMinutes = 5 },
				{ match = "bow", requireYou = true, enabled = false, repGain = 1, note = "Bowed to me.", cooldownMinutes = 5 },
			},
			-- actual aura detection, not a text emote, see AutoTrack.lua's onPlayerAura
			buff = { enabled = true, repGain = 2, note = "Buffed me in {{loc}}.", cooldownMinutes = 5 },
			-- from the duel-result system message, see AutoTrack.lua's onSystemMessage.
			-- {{duelresult}} fills in victoryText/lossText, fleeing counts as losing
			duel = {
				enabled = true, repGain = 3, note = "I {{duelresult}} in a duel in {{loc}}.", cooldownMinutes = 5,
				victoryText = "beat them", lossText = "lost to them",
			},
		},
		-- Separate from autoTrack above: dungeon/raid tracking needs more custom controls
		-- (a survey popup, a role-preset list) than the generic per-trigger row the rest
		-- of autoTrack uses, so it gets its own settings block and its own Options
		-- section. Both autoLog and survey are independent of each other and can be on at
		-- once (only autoLog is gated by autoTrack.enabled), see
		-- Core/AutoTrack.lua's onInstanceTransition / UI/DungeonSurvey.lua.
		dungeonTracking = {
			-- logged for each party/raid member when you enter (onlyOnCompletion = false)
			-- or leave (onlyOnCompletion = true) a dungeon/raid instance together.
			-- "leaving" is used as the completion signal rather than a boss-kill event,
			-- see AutoTrack.lua's onInstanceTransition
			autoLog = { enabled = true, repGain = 2, note = "Started {{loc}} together.", onlyOnCompletion = false },
			-- pops a window on completion listing your party/raid with a note box, a
			-- role-preset dropdown, and +/- standing buttons per member, so you can log
			-- richer per-player feedback right after a run instead of hunting each of
			-- them down later. notePrefix is filled through FillPlaceholders same as any
			-- other note template, then whatever you typed in the survey is appended.
			-- skipConfirmation: when true, skips straight to the survey instead of
			-- asking first (see the "Don't ask me again" checkbox on that prompt).
			-- windowWidth/windowHeight: the survey window's own saved size, nil until
			-- first manually resized (see UI/DungeonSurvey.lua's resize grip) -- once
			-- set, the window stops auto-fitting its height to the member count and
			-- trusts the saved size. positions live in windowPositions
			survey = {
				enabled = true, notePrefix = "[Survey: {{loc}}] ", skipConfirmation = false,
				windowWidth = nil, windowHeight = nil,
			},
			-- role-tag shortcuts for the survey's per-row dropdown: picking one fills
			-- that row's note box (still freely editable after). deliberately separate
			-- from quickPresets.items, those carry a delta too which would double up
			-- awkwardly with the survey's own per-row +/- buttons.
			rolePresets = {
				-- no {{loc}} here: the survey's notePrefix already carries it (see
				-- `survey.notePrefix` above), repeating it in the preset text too would
				-- just print the dungeon/raid name twice in the same entry
				{ label = "Good Tank", text = "Good tank.", delta = 5 },
				{ label = "Bad Tank", text = "Bad tank.", delta = -5 },
				{ label = "Good Healer", text = "Good healer.", delta = 5 },
				{ label = "Bad Healer", text = "Bad healer.", delta = -5 },
				{ label = "Good DPS", text = "Good DPS.", delta = 5 },
				{ label = "Bad DPS", text = "Bad DPS.", delta = -5 },
				{ label = "Loot Ninja", text = "Loot ninja.", delta = -10 },
			},
		},
		-- logs entries from Blizzard's own Recent Allies history (C_RecentAllies), see
		-- Core/RecentAllies.lua. types: which ns.RECENT_ALLY_TYPE_DEFS keys count.
		-- since: interactions at or before this time are never logged, reset on every
		-- enable so turning it on doesn't dump the whole backlog. seen: newest processed
		-- interaction timestamp per GUID
		recentAllies = {
			enabled = true,
			repGain = 2,
			note = "{{interaction}} in {{loc}} at level {{yourlvl}}.",
			cooldownMinutes = 30,
			types = {
				dungeon = true, raidBoss = true, delve = true, battleground = true, arena = true,
				fought = false, pvpKill = false, duel = true, trade = true, whisper = false,
				craftingOrder = false,
			},
			since = nil,
			seen = {},
		},
		-- Off by default. When enabled, creates a zero-standing record for every player
		-- whose nameplate becomes visible, not just ones already noted, so they can be
		-- looked up later. Only affects the Nearby window's player list, not the Players
		-- tab. Resting (city/inn) is skipped unless `alsoWhileResting` is on, since a
		-- crowded city can mean a LOT of nameplates at once.
		autoAddNearby = {
			enabled = false,
			alsoWhileResting = false,
			-- only players you mouse over (world, plates, unit frames), not every nameplate
			requireMouseover = false,
		},
		-- how often a sighting can bump seenCount (ns.IncrementSeenCount). without this,
		-- losing/regaining a nameplate briefly would inflate the count
		seenCountCooldownMinutes = 5,
		-- On by default: a crowded city/inn would otherwise bump the count for every
		-- passerby, which isn't a meaningful "encounter" the way it is out in the world.
		seenCountSkipWhileResting = true,
		-- channel every sound routes through. no public API for per-sound volume, so
		-- this picks one of the client's own sliders instead
		soundChannel = "Master",
		-- Alert sounds played when a notable player comes into nameplate range. See
		-- Core/Nameplates.lua and UI/NearbyWindow.lua. Each sound is either a built-in
		-- SOUNDKIT (`useCustom = false`, `kit = <id>`) or a user-supplied file path
		-- (`useCustom = true`, `customPath = "Sound\\..."`, played via PlaySoundFile).
		-- See ns.PlayConfiguredSound.
		nearbySound = {
			enabled = true,
			-- A player who leaves and re-enters range within this many seconds does not
			-- re-trigger the alert.
			cooldownSeconds = 180,
			-- Suppresses the alert while inside the matching instance type (the second
			-- return value of IsInInstance(): "party"/"raid"/"pvp"/"arena").
			disableInInstance = { party = false, raid = false, pvp = false, arena = false },
			-- both of these are file presets (Trading Post Menu Open / Pathfinding), not
			-- SOUNDKITs, so they show up pre-selected in their own dropdown's option
			-- list, unlike the previous SOUNDKIT-based defaults.
			positive = { useCustom = true, kit = SOUNDKIT and SOUNDKIT.READY_CHECK or 8960, customPath = 4956048 },
			negative = { useCustom = true, kit = SOUNDKIT and SOUNDKIT.IG_QUEST_FAILED or 847, customPath = 568197 },
		},
		-- A brief visual flash on the Nearby window when a new player appears. Independent
		-- of nearbySound.enabled; shares nearbySound's cooldown and instance-suppression.
		nearbyFlash = {
			enabled = true,
		},
		-- plays on any new entry, manual or auto. Write Quest sound by FileDataID, the
		-- string path silently fails to play
		newEntrySound = {
			enabled = true,
			useCustom = true,
			kit = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN or 851,
			customPath = 567396,
		},
		windowAlpha = 1.0,
		uiScale = 1.0,
		-- One-click preset buttons in the quick-add popup; each fills the note/delta
		-- fields and submits immediately. Editable (add/remove/edit) in Options ->
		-- Presets; `enabled` turns the whole feature off without losing the list.
		quickPresets = {
			enabled = true,
			items = {
				{ label = "Good Healer", text = "Good healer.", delta = 5 },
				{ label = "Good Tank", text = "Good tank.", delta = 5 },
				{ label = "Helpful", text = "Helpful.", delta = 3 },
				{ label = "Healed Me", text = "Healed me.", delta = 3 },
				{ label = "Rezzed Me", text = "Rezzed me.", delta = 5 },
				{ label = "Buffed Me", text = "Buffed me.", delta = 2 },
				{ label = "Rude", text = "Rude.", delta = -3 },
				{ label = "Resource Hog", text = "Resource hog.", delta = -5 },
			},
		},
		-- Holding the quick note keybind (instead of tapping it) opens a radial picker
		-- of quickPresets.items at the cursor, see UI/RadialMenu.lua. Off by default.
		-- radial1Labels/radial2Labels are nil until the user customizes the dropdown in
		-- Options -> Radial Menu: nil means "use the smart default" (see
		-- ns.GetRadialPresetSet), not "empty".
		radialMenu = {
			enabled = true,
			-- second (negative) radial, opened with secondModifier held. off: the single
			-- radial uses the whole preset list and neutral colors.
			secondEnabled = false,
			secondModifier = "CTRL", -- "CTRL" | "ALT" | "SHIFT"
			-- with two radials: "signed" limits radial 1 to positive presets and radial 2
			-- to negative ones, "all" lets either hold any preset. each mode keeps its
			-- own saved selections (radialNLabels vs radialNLabelsAll, see
			-- ns.RadialLabelsKey) so switching back and forth doesn't lose either set
			splitMode = "signed",
			-- the target's name above the wheel: "class" (their class color) or
			-- "bracket" (their standing's color)
			nameColor = "class",
			radial1Labels = nil,
			radial2Labels = nil,
			radial1LabelsAll = nil,
			radial2LabelsAll = nil,
			-- a drag resolving to a pick faster than this after the key went down falls
			-- back to a plain tap instead, in case a quick/imprecise press looks like a
			-- drag by accident. can't be enforced inside the secure snippet itself (no
			-- GetTime() there either), so the insecure OnPick handler checks it instead.
			minHoldMs = 500,
			-- independent of quickNoteHoverEnabled below: a player might want hover for
			-- one but not the other.
			hoverEnabled = true,
			-- hides GameTooltip (or a mouse-anchored replacement built on it) for as long
			-- as the wheel is up, since it opens right at the cursor and a tooltip
			-- following the mouse can cover half of it.
			suppressTooltip = true,
			-- a held drag during combat is an easy way to accidentally eat a global
			-- cooldown/GCD reaching for an ability under the wheel; tapping the keybind
			-- (plain Quick Note) still works either way, this only gates the wheel/drag.
			disableInCombat = true,
		},
		-- same idea for a plain tap of the global keybind (QuickNoteTarget): falls back
		-- to whatever's moused over when nothing's targeted, before giving up and
		-- toggling the main window.
		quickNoteHoverEnabled = true,
		-- WR standing tags/asterisks on group finder Browse tab listings, plus the
		-- Quick Note keybind's "pull up this group's roster" shortcut while hovering
		-- one (see Core/LFGBrowse.lua). Off disables both entirely.
		lfgIntegrationEnabled = true,
		-- Adds a checkbox column (Players and History tabs) for checking several rows
		-- at once, with a bulk "Delete Selected" option on right-click once more than
		-- one is checked. Off by default since it's an extra column most people won't
		-- need most of the time.
		multiSelectEnabled = false,
		-- Shift-clicking a Players-row +/- button nudges standing by this amount instead
		-- of the default 1, for logging a bigger swing without opening the popup.
		shiftClickAmount = 5,
		-- The Nearby mini window (notable players with a visible nameplate right now)
		-- has its own transparency, separate from the main window: dim while idle,
		-- brighter on mouseover. Position is nil until the window has been dragged once.
		nearbyWindowEnabled = true,
		-- hidden while it has nobody to list, without changing nearbyWindowEnabled
		nearbyHideWhenEmpty = false,
		nearbyIdleAlpha = 0.5,
		nearbyHoverAlpha = 0.9,
		nearbyScale = 1.0,
		nearbyPoint = nil,
		-- "down": header on top, rows grow downward beneath it.
		-- "up": header on the bottom, rows grow upward above it.
		nearbyGrowDirection = "down",
		-- Rows beyond this many scroll instead of growing the window indefinitely. Only
		-- applies when nearbyStaticSize is off; a static-size window scrolls within
		-- whatever fixed size it was resized to.
		nearbyVisibleRowLimit = 8,
		-- Static size makes the window user-resizable via a corner grip instead of
		-- auto-sizing to the player count. Width/height persist once resized.
		nearbyStaticSize = false,
		-- clicking a Nearby window row: "details", "quickadd", or "nothing"
		nearbySingleClick = "quickadd",
		nearbyDoubleClick = "details",
		-- how long after a first click a second one still counts as a double click
		nearbyDoubleClickMs = 300,
		-- seconds a player stays in the Nearby window after their nameplate goes away
		nearbyHoldSeconds = 0,
		-- saved drag positions for popups (quickAdd, editEntry, survey, surveyConfirm),
		-- see ns.SavePopupPosition in UI/Widgets.lua
		windowPositions = {},
		nearbyStaticWidth = 200,
		nearbyStaticHeight = 125,
		-- A small diamond above a notable player's nameplate, colored by their current
		-- reputation bracket (see ns.GetBracket). offsetX/offsetY are anchored from the
		-- plate's own TOP.
		nameplateIcon = {
			enabled = true,
			size = 14,
			offsetX = 0,
			offsetY = 6,
			-- When true, players notable only via a note (standing within the neutral
			-- band) don't get an icon.
			hideNeutral = false,
		},
		-- The draggable minimap button. `angle` is degrees around the minimap's center
		-- (0 = due east), persisted so the button stays wherever it was dragged to.
		minimapIcon = {
			hide = false,
			angle = 215,
		},
		timeFormat = "24h", -- "24h" | "12h"
		dateFormat = "ymd", -- "ymd" | "mdy" | "dmy"
		-- Players tab row buttons, independently hideable. Off (buttons shown) by
		-- default, matching existing behavior for anyone upgrading.
		hidePlayersStandingButtons = false,
		hidePlayersNewButton = false,
		-- which tab the main window opens to when the Quick Note keybind fires with no
		-- target, see ns.QuickNoteTarget. quickNoteFallbackEnabled off disables that
		-- open-window behavior entirely (the hotkey just does nothing with no
		-- target/hover), without affecting unrelated uses of the same key (e.g. the
		-- Group Finder roster shortcut, Core/LFGBrowse.lua).
		quickNoteFallbackTab = "history", -- "players" | "history"
		quickNoteFallbackEnabled = true,
		-- Which named label preset is active for reputation brackets. Independent of
		-- repBracketColors below, so switching presets never changes custom colors.
		repBracketPreset = "judgment",
		-- which ns.REP_COLOR_PRESETS entry is active, or "custom". independent of the
		-- label preset above
		repBracketColorPreset = "greenRed",
		-- the active bracket colors: 4 tiers each side of the neutral band, ordered
		-- mild -> extreme, plus the neutral color. picking a color preset copies its
		-- colors in here; editing any swatch switches to "custom"
		repBracketColors = {
			positive = {
				{ 0.6, 0.85, 0.5 },
				{ 0.4, 0.75, 0.35 },
				{ 0.2, 0.65, 0.2 },
				{ 0.1, 0.5, 0.1 },
			},
			negative = {
				{ 0.85, 0.5, 0.5 },
				{ 0.75, 0.35, 0.3 },
				{ 0.65, 0.2, 0.2 },
				{ 0.5, 0.1, 0.1 },
			},
			zero = { 0.8, 0.8, 0.8 },
		},
		-- the user's own color set, saved whenever they edit a swatch so picking
		-- "Custom" again later restores it. nil until first edited
		repBracketCustomColors = nil,
		-- Used only when repBracketPreset == "custom"; starts as a copy of "judgment" so
		-- there's always something sensible to edit from.
		repBracketCustomLabels = {
			zero = "Unproven",
			positive = { "Proven", "Trusted", "Honored", "Exalted" },
			negative = { "Tainted", "Suspect", "Condemned", "Cursed" },
		},
		-- Runs on login, deleting every player record matching any checked criterion.
		-- See ns.RunAutoPrune in Core/Database.lua.
		autoPrune = {
			enabled = true,
			criteria = {
				unnoted = true,
				unrepped = true,
				neutral = false,
				notSeenDays = true,
			},
			notSeenDaysValue = 1,
		},
		-- ignore rules by relationship, flags per ns.IGNORE_FLAGS. see Core/Ignore.lua
		ignore = {
			guild = { auto = false, survey = false, indicators = false },
			friends = { auto = false, survey = false, indicators = false },
			bnet = { auto = false, survey = false, indicators = false },
		},
	},
	players = {},
	-- per-player ignore rows, outside settings so Reset All Options keeps them. a row
	-- overrides every rule; all flags off means "always track"
	ignored = {},
}

-- Defines each automatic-tracking trigger: what Core/AutoTrack.lua does and what
-- checkboxes/fields UI/Options.lua draws for it, from one shared list.
ns.AUTO_TRACK_DEFS = {
	{ key = "party", source = "auto-party", label = "Partied with",
		hint = "Logged once when a player joins your party/raid." },
	{ key = "rez", source = "auto-rez", label = "Rezzed me",
		hint = "Logged when another player resurrects you. Only resolves a full identity if they're your current target or on a nearby nameplate, otherwise logs by name alone." },
	{ key = "quest", source = "auto-quest", label = "Quested together", hasCooldown = true, hasMinGrouped = true,
		hint = "Logged for each party/raid member when you turn in a quest while grouped with them." },
	{ key = "buff", source = "auto-buff", label = "Buffed me", hasCooldown = true,
		hint = "Logged when another player casts a helpful buff on you, as long as they aren't partied with you (partying is covered by \"Partied with\" above). Only catches it if the game can currently identify them, which needs them to be your target or have a visible nameplate (Shift+V shows friendly nameplates) at that exact moment, not just anyone nearby." },
	{ key = "duel", source = "auto-duel", label = "Dueled", hasCooldown = true, hasDuelResult = true,
		hint = "Logged when a duel you're in ends. {{duelresult}} in the note becomes the Victory or Loss text below it (fleeing counts as losing)." },
}

ns.MAX_EMOTE_RULES = 20

-- Enum.RolodexType values per option, from Blizzard's RolodexConstantsDocumentation
ns.RECENT_ALLY_TYPE_DEFS = {
	{ key = "dungeon", label = "Completed a dungeon", types = { 12 } },
	{ key = "raidBoss", label = "Killed a raid boss", types = { 13, 14 } },
	{ key = "delve", label = "Completed a delve", types = { 15 } },
	{ key = "battleground", label = "Completed a battleground", types = { 17 } },
	{ key = "arena", label = "Completed an arena", types = { 16 } },
	{ key = "fought", label = "Fought together", types = { 11 } },
	{ key = "pvpKill", label = "PvP kill together", types = { 20 } },
	{ key = "duel", label = "Dueled", types = { 18 } },
	{ key = "trade", label = "Traded", types = { 3 } },
	{ key = "whisper", label = "Whispered", types = { 4 } },
	{ key = "craftingOrder", label = "Crafting order", types = { 5, 6, 7, 8, 9, 10 } },
}

-- Built-in sound kits used throughout Blizzard's own UI, chosen to avoid depending on a
-- 3rd-party sound library (LibSharedMedia) for a short list of alert sounds.
ns.NEARBY_SOUND_OPTIONS = {
	{ value = SOUNDKIT and SOUNDKIT.READY_CHECK or 8960, text = "Ready Check" },
	{ value = SOUNDKIT and SOUNDKIT.RAID_WARNING or 8959, text = "Raid Warning" },
	{ value = SOUNDKIT and SOUNDKIT.IG_QUEST_FAILED or 847, text = "Quest Failed" },
	{ value = SOUNDKIT and SOUNDKIT.IG_PLAYER_INVITE or 889, text = "Player Invite" },
	{ value = SOUNDKIT and SOUNDKIT.LEVEL_UP or 888, text = "Level Up" },
	{ value = SOUNDKIT and SOUNDKIT.IG_MAINMENU_OPEN or 851, text = "Menu Open" },
}

-- No per-sound volume API exists in the public WoW API; `channel` instead picks which of
-- the user's existing in-game volume sliders (Sound options panel) the alert respects.
ns.NEARBY_SOUND_CHANNELS = { "Master", "SFX", "Ambience", "Music", "Dialog" }

-- Plays a `{useCustom, kit, customPath}` sound setting (see ns.Defaults.settings.nearbySound
-- for the shape) on the given channel.
function ns.PlayConfiguredSound(sound, channel)
	if not sound then
		return
	end
	if sound.useCustom and sound.customPath and sound.customPath ~= "" then
		PlaySoundFile(sound.customPath, channel)
	elseif sound.kit then
		PlaySound(sound.kit, channel)
	end
end

-- An entry's `source` is "manual" (or nil, for legacy entries predating this field) for
-- anything typed by hand, "survey" for the dungeon/raid survey (also typed by hand,
-- surveys before this existed were saved as "manual"), or "auto-<kind>" for anything
-- logged automatically.
function ns.IsAutoSource(source)
	return source ~= nil and source ~= "manual" and source ~= "survey"
end

-- display categories for an entry's source, in filter-dropdown order
ns.SOURCE_CATEGORIES = {
	{ key = "manual", label = "Manual" },
	{ key = "survey", label = "Survey" },
	{ key = "general", label = "General", isAuto = true },
	{ key = "emote", label = "Emote", isAuto = true },
	{ key = "instance", label = "Instance", isAuto = true },
	{ key = "allies", label = "Allies", isAuto = true },
	{ key = "nearby", label = "Nearby", isAuto = true },
}

local SOURCE_CATEGORY_LABELS = {}
for _, category in ipairs(ns.SOURCE_CATEGORIES) do
	SOURCE_CATEGORY_LABELS[category.key] = category.label
end

local SOURCE_CATEGORY_BY_SOURCE = {
	["auto-dungeon"] = "instance",
	["auto-recentally"] = "allies",
	["auto-nearby"] = "nearby",
	["auto-emote"] = "emote",
	-- per-emote sources from before emote rules (1.0 and earlier)
	["auto-wave"] = "emote",
	["auto-thank"] = "emote",
	["auto-bow"] = "emote",
}
for _, def in ipairs(ns.AUTO_TRACK_DEFS) do
	SOURCE_CATEGORY_BY_SOURCE[def.source] = "general"
end

-- unrecognized auto sources fall under General
function ns.SourceCategory(source)
	if source == "survey" then
		return "survey"
	elseif not ns.IsAutoSource(source) then
		return "manual"
	end
	return SOURCE_CATEGORY_BY_SOURCE[source] or "general"
end

function ns.SourceLabel(source)
	return SOURCE_CATEGORY_LABELS[ns.SourceCategory(source)]
end

-- text color for a Source cell: grey for manual, light green for survey, blue for auto
function ns.SourceColor(source)
	local category = ns.SourceCategory(source)
	if category == "manual" then
		return 0.8, 0.8, 0.8
	elseif category == "survey" then
		return 0.55, 0.9, 0.55
	end
	return 0.55, 0.75, 1
end

-- Named label sets for reputation brackets: zero/positive/negative name arrays, ordered
-- mild -> extreme for positive/negative. Purely cosmetic text; colors are tracked
-- separately in repBracketColors.
ns.REP_BRACKET_PRESETS = {
	classic = {
		zero = "Neutral",
		positive = { "Good Repute", "Companion", "Sworn Friend", "Champion" },
		negative = { "Ill Repute", "Scoundrel", "Sworn Enemy", "Nemesis" },
	},
	tavern = {
		zero = "Stranger",
		positive = { "Acquaintance", "Favored", "Beloved", "Legendary" },
		negative = { "Ill-Favored", "Blaggard", "Villain", "Blacklisted" },
	},
	judgment = {
		zero = "Unproven",
		positive = { "Proven", "Trusted", "Honored", "Exalted" },
		negative = { "Tainted", "Suspect", "Condemned", "Cursed" },
	},
	whimsical = {
		zero = "Indifferent",
		positive = { "Pleasant", "Dear", "Darling", "Treasured" },
		negative = { "Pest", "Rascal", "Menace", "Blight" },
	},
}

ns.REP_BRACKET_PRESET_ORDER = { "classic", "tavern", "judgment", "whimsical" }

-- bracket color sets, same shape as settings.repBracketColors
ns.REP_COLOR_PRESETS = {
	greenRed = {
		label = "Green & Red",
		positive = { { 0.6, 0.85, 0.5 }, { 0.4, 0.75, 0.35 }, { 0.2, 0.65, 0.2 }, { 0.1, 0.5, 0.1 } },
		negative = { { 0.85, 0.5, 0.5 }, { 0.75, 0.35, 0.3 }, { 0.65, 0.2, 0.2 }, { 0.5, 0.1, 0.1 } },
		zero = { 0.8, 0.8, 0.8 },
	},
	coolWarm = {
		label = "Cool & Warm",
		positive = { { 0.55, 0.9, 0.45 }, { 0.3, 0.82, 0.6 }, { 0.3, 0.68, 0.92 }, { 0.35, 0.45, 1 } },
		negative = { { 1, 0.87, 0.3 }, { 1, 0.58, 0.15 }, { 0.92, 0.22, 0.15 }, { 0.62, 0.06, 0.06 } },
		zero = { 0.85, 0.85, 0.85 },
	},
	colorblind = {
		label = "Colorblind-Friendly",
		positive = { { 0.62, 0.8, 1 }, { 0.42, 0.66, 1 }, { 0.22, 0.5, 0.95 }, { 0.12, 0.3, 0.8 } },
		negative = { { 1, 0.82, 0.52 }, { 1, 0.64, 0.26 }, { 0.9, 0.46, 0.1 }, { 0.68, 0.3, 0.05 } },
		zero = { 0.85, 0.85, 0.85 },
	},
}
ns.REP_COLOR_PRESET_ORDER = { "greenRed", "coolWarm", "colorblind" }

local function copyColorSet(source)
	local function copyTier(list)
		local out = {}
		for i, c in ipairs(list) do
			out[i] = { c[1], c[2], c[3] }
		end
		return out
	end
	return {
		positive = copyTier(source.positive),
		negative = copyTier(source.negative),
		zero = { source.zero[1], source.zero[2], source.zero[3] },
	}
end

-- "custom" restores the user's saved custom set (or keeps the current colors if they
-- haven't made one yet)
function ns.ApplyBracketColorPreset(key)
	local settings = ns.GetSettings()
	settings.repBracketColorPreset = key
	if key == "custom" then
		if settings.repBracketCustomColors then
			settings.repBracketColors = copyColorSet(settings.repBracketCustomColors)
		end
		return
	end
	settings.repBracketColors = copyColorSet(ns.REP_COLOR_PRESETS[key] or ns.REP_COLOR_PRESETS.greenRed)
end

-- overwrite the user's saved custom set with a built-in preset, as a fresh starting
-- point. the active colors follow too while "Custom" is the selected color set
function ns.ResetCustomBracketColors(presetKey)
	local preset = ns.REP_COLOR_PRESETS[presetKey]
	if not preset then
		return
	end
	local settings = ns.GetSettings()
	settings.repBracketCustomColors = copyColorSet(preset)
	if settings.repBracketColorPreset == "custom" then
		settings.repBracketColors = copyColorSet(preset)
	end
end

function ns.ResetCustomBracketLabels(presetKey)
	local preset = ns.REP_BRACKET_PRESETS[presetKey]
	if not preset then
		return
	end
	local p, n = preset.positive, preset.negative
	ns.GetSettings().repBracketCustomLabels = {
		zero = preset.zero,
		positive = { p[1], p[2], p[3], p[4] },
		negative = { n[1], n[2], n[3], n[4] },
	}
end

-- sign is "positive"/"negative" with an index, or "zero" with no index
function ns.GetBracketColor(sign, index)
	local colors = ns.GetSettings().repBracketColors
	if sign == "zero" then
		return colors.zero or ns.REP_COLOR_PRESETS.greenRed.zero
	end
	return colors[sign][index]
end

function ns.SetBracketColor(sign, index, r, g, b)
	local settings = ns.GetSettings()
	if sign == "zero" then
		settings.repBracketColors.zero = { r, g, b }
	else
		settings.repBracketColors[sign][index] = { r, g, b }
	end
	settings.repBracketColorPreset = "custom"
	settings.repBracketCustomColors = copyColorSet(settings.repBracketColors)
end

-- active label set, preset or custom. lets UI code treat both uniformly (e.g.
-- populating the 9-field editor from whatever's active)
function ns.GetActiveBracketLabels()
	local settings = ns.GetSettings()
	if settings.repBracketPreset == "custom" then
		return settings.repBracketCustomLabels
	end
	return ns.REP_BRACKET_PRESETS[settings.repBracketPreset] or ns.REP_BRACKET_PRESETS.judgment
end

-- Bracket thresholds are absolute standing magnitudes, not relative to the neutral band:
-- first bracket is (neutralBand, 25], then 26-50, 51-75, 76-100.
local BRACKET_THRESHOLDS = { 25, 50, 75, 100 }

-- {name, color, index} for a standing value. index 0 is neutral, 1-4 is which bracket
-- on either side
function ns.GetBracket(standing)
	local settings = ns.GetSettings()
	local preset = settings.repBracketPreset == "custom" and settings.repBracketCustomLabels
		or ns.REP_BRACKET_PRESETS[settings.repBracketPreset] or ns.REP_BRACKET_PRESETS.judgment
	local band = settings.neutralBand

	if math.abs(standing) <= band then
		return { name = preset.zero, color = ns.GetBracketColor("zero"), index = 0 }
	end

	local magnitude = math.abs(standing)
	local sign = standing > 0 and "positive" or "negative"
	local names = preset[sign]
	local colors = settings.repBracketColors[sign]

	for i, threshold in ipairs(BRACKET_THRESHOLDS) do
		if magnitude <= threshold then
			return { name = names[i], color = colors[i], index = i }
		end
	end

	return { name = names[#names], color = colors[#colors], index = #names }
end

-- stable bracket key (negative4..negative1, zero, positive1..positive4), for
-- matching/filtering by identity rather than display
function ns.GetBracketKey(standing)
	local bracket = ns.GetBracket(standing)
	if bracket.index == 0 then
		return "zero"
	end
	return (standing > 0 and "positive" or "negative") .. bracket.index
end

-- Worst -> best, matching the order used in Options' bracket editor and Statistics'
-- "Players by Bracket" section.
ns.BRACKET_KEY_ORDER = {
	"negative4", "negative3", "negative2", "negative1",
	"zero",
	"positive1", "positive2", "positive3", "positive4",
}

-- label text + color for a bracket key, from whatever preset/colors are active. keeps
-- dropdown/column text matching Options/Statistics
function ns.GetBracketDisplay(bracketKey)
	local labels = ns.GetActiveBracketLabels()
	if bracketKey == "zero" then
		return labels.zero, ns.GetBracketColor("zero")
	end
	local sign, index = bracketKey:match("^(%a+)(%d)$")
	index = tonumber(index)
	return labels[sign][index], ns.GetSettings().repBracketColors[sign][index]
end

-- the .toc's Version field, falling back to the newest changelog entry
function ns.GetAddonVersion()
	local version = (GetAddOnMetadata and GetAddOnMetadata(ns.name, "Version"))
		or (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ns.name, "Version"))
	return version or (ns.CHANGELOG and ns.CHANGELOG[1] and ns.CHANGELOG[1].version)
end

function ns.Print(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff9482c9Worth Remembering|r: " .. tostring(msg))
end

-- stored as UnitSex()'s own values: 2 = male, 3 = female. anything else (1 = unknown,
-- or a secret value on clients that restrict unit identity) is treated as unknown
function ns.NormalizeUnitSex(value)
	if issecretvalue and issecretvalue(value) then
		return nil
	end
	if value == 2 or value == 3 then
		return value
	end
	return nil
end

-- UnitSex(unit), or nil if this client doesn't have it or it errors, so a missing or
-- changed API only loses this one field instead of breaking player identification
function ns.SafeUnitSex(unit)
	if not unit or type(UnitSex) ~= "function" then
		return nil
	end
	local ok, value = pcall(UnitSex, unit)
	return ok and value or nil
end

-- the game's value exactly as reported, tagged by source ("unit:2", "enum:0"), stored
-- next to the normalized one. if a client ever reports values we don't expect, those
-- players just show as unknown, and the raw value is still there to remap later
function ns.RawSexTag(source, value)
	if value == nil or (issecretvalue and issecretvalue(value)) then
		return nil
	end
	return source .. ":" .. tostring(value)
end

-- Recent Allies uses Enum.UnitSex instead (0 = male, 1 = female)
function ns.SexFromEnum(value)
	if issecretvalue and issecretvalue(value) then
		return nil
	end
	if value == 0 then
		return 2
	elseif value == 1 then
		return 3
	end
	return nil
end

function ns.SexDisplay(sex)
	local numbered = ns.GetSettings().bodyTypeStyle == "numbered"
	if sex == 2 then
		return numbered and "1" or "Male"
	elseif sex == 3 then
		return numbered and "2" or "Female"
	end
	return nil
end

function ns.SexLabel()
	return ns.GetSettings().bodyTypeLabel == "sex" and "Sex" or "Body Type"
end

-- filter key for a stored sex value: no value (shown as "-") filters as "unknown"
function ns.SexFilterKey(sex)
	return sex or "unknown"
end

-- the "everything" text for a body type filter dropdown
function ns.SexFilterAllText()
	return ns.GetSettings().bodyTypeLabel == "sex" and "All sexes" or "All body types"
end

-- refills a body type filter's options in place (the dropdown menu keeps reading the
-- same table), so they follow the display setting
function ns.FillSexFilterOptions(target)
	target[1] = { value = 2, text = ns.SexDisplay(2) }
	target[2] = { value = 3, text = ns.SexDisplay(3) }
	target[3] = { value = "unknown", text = "Unknown" }
	return target
end

-- snapshots fields at creation time, never recomputed later. unit, when it's really
-- the identity in question, lets us snapshot their level too
function ns.CaptureContext(unit)
	return {
		yourLevel = UnitLevel("player"),
		theirLevel = unit and UnitLevel(unit) or nil,
		theirSex = ns.NormalizeUnitSex(ns.SafeUnitSex(unit)),
		theirSexRaw = ns.RawSexTag("unit", ns.SafeUnitSex(unit)),
		zone = GetZoneText(),
	}
end

-- {{loc}}/{{yourlvl}}/{{theirlvl}} placeholders for quick-add preset text, filled in
-- from a ns.CaptureContext() table. `description` feeds UI/Options.lua's preset help
-- popup directly, so that list can't drift out of sync with what's actually supported.
ns.PRESET_PLACEHOLDERS = {
	{ key = "loc", label = "{{loc}}", description = "Your current zone",
		resolve = function(ctx) return (ctx.zone and ctx.zone ~= "") and ctx.zone or "somewhere" end },
	{ key = "yourlvl", label = "{{yourlvl}}", description = "Your level",
		resolve = function(ctx) return ctx.yourLevel or "?" end },
	{ key = "theirlvl", label = "{{theirlvl}}", description = "Their level",
		resolve = function(ctx) return ctx.theirLevel or "?" end },
}

-- Unresolved/unrecognized placeholders (typos, etc) are left as-is rather than erroring
-- or silently vanishing, so a mistake is visible instead of hidden.
function ns.FillPlaceholders(text, ctx)
	if not text then
		return text
	end
	return (text:gsub("{{%s*(%a+)%s*}}", function(key)
		for _, placeholder in ipairs(ns.PRESET_PLACEHOLDERS) do
			if placeholder.key == key:lower() then
				return tostring(placeholder.resolve(ctx))
			end
		end
		return "{{" .. key .. "}}"
	end))
end

-- plain positive/neutral/negative coloring (per-entry deltas, totals), from the active
-- bracket color set so a palette choice (e.g. colorblind-friendly) applies here too.
-- uses the mildest tier of each side
function ns.StandingColor(standing, band)
	local c
	if math.abs(standing) <= band then
		c = ns.GetBracketColor("zero")
	elseif standing > 0 then
		c = ns.GetBracketColor("positive", 1)
	else
		c = ns.GetBracketColor("negative", 1)
	end
	return c[1], c[2], c[3]
end

-- gray when class is unknown (added from chat, never seen in the world): white is Priest
function ns.ClassColor(classFile)
	local c = classFile and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classFile]
	if c then
		return c.r, c.g, c.b
	end
	return 0.65, 0.65, 0.65
end

function ns.FactionColor(faction)
	if faction == "Horde" then
		return 0.9, 0.2, 0.2
	elseif faction == "Alliance" then
		return 0.3, 0.55, 0.95
	end
	return 1, 1, 1
end

function ns.ClassDisplayName(classFile)
	return classFile and LOCALIZED_CLASS_NAMES_MALE and LOCALIZED_CLASS_NAMES_MALE[classFile] or classFile or "-"
end

function ns.ToHex(r, g, b)
	return string.format("ff%02x%02x%02x", (r or 1) * 255, (g or 1) * 255, (b or 1) * 255)
end

-- Shared "inset panel" look for filter bars etc.: a dark recessed box with a thin gold
-- border. `frame` must have been created with the BackdropTemplate mixin.
function ns.ApplyPanelBackdrop(frame, alpha)
	frame:SetBackdrop({
		bgFile = "Interface/Tooltips/UI-Tooltip-Background",
		edgeFile = "Interface/Tooltips/UI-Tooltip-Border",
		edgeSize = 10,
		insets = { left = 3, right = 3, top = 3, bottom = 3 },
	})
	frame:SetBackdropColor(0.16, 0.11, 0.05, alpha or 0.7)
	frame:SetBackdropBorderColor(1, 0.82, 0, 0.4)
end

function ns.FormatDate(ts)
	local dateFormat = ns.GetSettings().dateFormat
	if dateFormat == "mdy" then
		return date("%m-%d-%Y", ts)
	elseif dateFormat == "dmy" then
		return date("%d-%m-%Y", ts)
	end
	return date("%Y-%m-%d", ts)
end

function ns.FormatTime(ts)
	local settings = ns.GetSettings()
	local timePart = settings.timeFormat == "12h" and date("%I:%M %p", ts) or date("%H:%M", ts)
	return ns.FormatDate(ts) .. " " .. timePart
end
