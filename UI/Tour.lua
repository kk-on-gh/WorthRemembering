local ns = WorthRemembering

-- step = { title, text, tab?, page? (Options sub-tab label), target? (ns.RegisterTourTarget
--   name) or box? (Options section box title, expanded and scrolled to, then collapsed
--   again on leaving), side? ("below" | "above" | "left" | "right" | "center"),
--   also? + alsoSide? (a second target that gets its own arrow and glow, the arrow on
--   that side of it), marks? (list of targets that get a faint box, no arrow), hook? (a STEP_HOOKS name below, for steps that do more than point
--   at something) }
-- no target, or a target that isn't visible, shows the box centered on the window.
-- left/right flip to the other side when the screen edge is in the way
ns.TOURS = {
	basics = {
		{
			title = "Welcome!",
			text = "This quick tour shows you around Worth Remembering. It takes about two minutes.\n\nLeave any time with the X or Escape, and start it again from the About tab.",
		},
		{
			tab = "players", target = "tab.players", side = "below",
			title = "Players",
			text = "Everyone you've noted, or (optionally) crossed paths with. One row per player.",
		},
		{
			tab = "players", target = "players.table", side = "center",
			title = "The players list",
			text = "Click a name to open their Details.\n\nClick a class, race, bracket, or other value to filter the list to just that. Click it again to clear it.\n\nRight-click a row for more options.\n\nDisable columns you don't care about in the top right, and click and drag to reorder them.",
		},
		{
			tab = "players", target = "players.filters", side = "below",
			title = "Filters",
			text = "Search (separate terms with commas to match any of them) and narrow the list down.\n\nToo many? Hide the ones you don't use in Options > General > Filters.",
		},
		{
			tab = "history", target = "tab.history", side = "below",
			title = "History",
			text = "Every entry ever logged, for everyone, newest first. Right-click an entry to edit or delete it.",
		},
		{
			tab = "details", target = "tab.details", side = "below", hook = "demoDetails",
			title = "Details",
			text = "Everything about one player: their standing, every note, and when and where you last saw them. Featured notes show up as a quote at the top.",
		},
		{
			tab = "statistics", target = "tab.statistics", side = "below",
			title = "Statistics",
			text = "Totals, your most and least liked classes and races, and more. Click almost any stat to jump to the matching players.",
		},
		{
			tab = "options", target = "tab.options", side = "below",
			title = "Options",
			text = "Every feature can be turned on or off, and most can be customized.\n\nThere's a lot here, so the Settings tour (About tab) walks through them in more detail, and most have explanations when hovering them.",
		},
		{
			hook = "notePreviews",
			title = "Adding notes",
			text = "Right-click any player (in the world, in chat, in your group) and choose Worth Remembering > Add Note.\n\nEven quicker: set a global hotkey in Options > General, then tap it with someone targeted. Hold it instead for a radial menu of your presets.",
		},
		{
			target = "nearby", side = "right", hook = "spotting",
			title = "Spotting people",
			text = "This Nearby window lists the notable players around you (friendly nameplates must be enabled, Shift+V by default). Click a name to add a note, double-click for their Details. It can also play a sound when someone notable shows up (Options > Alerts).\n\nPlayers you've noted get a diamond over their nameplate, colored by their standing.\n\nTheir standing also shows after their name in chat, like [+10], and in their tooltip.",
		},
		{
			tab = "about", target = "tab.about", side = "right", also = "about.patchNotes", alsoSide = "left",
			title = "About",
			text = "Patch notes, ways to reach me, and both tours live here. Uncheck the box if you don't want to see this window every update.",
		},
		{
			tab = "about", also = "about.contact", alsoSide = "left",
			title = "That's it!",
			text = "Go meet some people worth remembering.\n\nQuestions, feedback, ideas, or bugs? The About tab has my contact info (top right). I love hearing from people.\n\nThank you for trying Worth Remembering!",
		},
	},
	-- "what's new" tours, one per version, started from that version's patch notes.
	-- keep only the newest three, the About tab ignores older ones anyway
	["v1.2"] = {
		{
			title = "What's new in 1.2",
			text = "A quick look at what's new.",
		},
		{
			tab = "about", target = "about.tours", side = "below",
			title = "Tours",
			text = "Tours are new too! The basics tour walks through the main window and adding notes, and the settings tour through the Options pages worth knowing about. Take either one any time.",
		},
		{
			page = "general", box = "Filters", side = "right",
			title = "Filters",
			text = "Hide the filters you don't use on the Players and History tabs. The filter bars now rearrange to fit, and wrap instead of overlapping in a narrow window.",
		},
		{
			page = "general", box = "Nearby Window", side = "right", marks = { "options.nearby.hold", "options.nearby.clicks" },
			title = "Nearby window",
			text = "\"Hold for\" keeps players listed for a few seconds after they leave view, so they don't flicker in and out.\n\nClicking or double-clicking a row can now target them (out of combat).",
		},
		{
			page = "general", box = "Danger Zone", side = "right",
			title = "Danger zone",
			text = "Clear Ignored empties your ignore list.\nReset UI now resets hidden filters too.",
		},
		{
			tab = "statistics", target = "tab.statistics", side = "below",
			marks = { "stats.total positive standing given", "stats.total negative standing given" },
			title = "Statistics",
			text = "Click Total Positive or Total Negative Standing Given to see just those entries on the History tab.",
		},
		{
			title = "Times Seen",
			text = "People joining your group now count as a sighting, so the people you play with regularly finally add up.\n\nIgnoring someone no longer stops their Times Seen from counting.",
		},
		{
			tab = "about",
			title = "That's all for 1.2",
			text = "Thanks for using Worth Remembering!",
		},
	},
	["v1.1"] = {
		{
			title = "What's new in 1.1",
			text = "Ignoring! Keep specific players, or whole groups of them, out of the automatic stuff.\n\nSuggested by Reddit user\n/u/Ksir73",
		},
		{
			page = "ignore", box = "Ignore by Relationship", side = "right",
			title = "Ignore by relationship",
			text = "Leave your guild, WoW friends, or BattleTag friends out of auto-entries, the survey, or indicators (nameplate icon, chat tag, Nearby window). All off by default.",
		},
		{
			page = "ignore", box = "Ignored Players", side = "right",
			title = "Ignored players",
			text = "Or ignore specific players, which overrides the rules above. A row with every box unchecked always tracks them.\n\nAdd them here, or right-click anyone and pick Ignore Player. Ignoring someone offers to clean up their existing auto-entries.",
		},
		{
			page = "ignore", target = "options.heart.ignore", side = "below",
			title = "Community credit",
			text = "Features suggested by the community get a heart on their Options page. Hover or click it to see who suggested what.",
		},
		{
			tab = "players", target = "players.ignoredFilter", side = "below",
			title = "On the Players tab",
			text = "This filter narrows the list to ignored or not-ignored players.\n\nThe new Ignored column shows why: \"Yes\" means they're on your list, \"Yes (Guild)\" means a rule caught them, and \"Exempt\" means they're on your list with every box unchecked.",
		},
		{
			tab = "about",
			title = "That's all for 1.1",
			text = "Thanks for using Worth Remembering!",
		},
	},
	settings = {
		{
			title = "Settings tour",
			text = "A look at the settings worth knowing about. Each box the tour shows you opens up, and closes again when you move on.\n\nNothing here is permanent, so feel free to experiment.",
		},
		{
			page = "general", box = "Global Hotkey", side = "right",
			title = "Global hotkey",
			text = "Your fastest way in. Click the key button, then press a key (I use R, for Remember).\n\nTap it with someone targeted to note them, or hold it for the radial menu. The dropdowns choose what a tap opens with a target, while hovering someone, or with neither.",
		},
		{
			page = "general", box = "Main", side = "right",
			title = "Main window",
			text = "Opacity and UI scale, plus how dates, times, and body types are shown.",
		},
		{
			page = "general", box = "Filters", side = "right",
			title = "Filters",
			text = "Hide the filters you don't use on the Players and History tabs. The filter bars rearrange to fit what's left.",
		},
		{
			page = "general", box = "Nearby Window", side = "right",
			title = "Nearby window",
			text = "A small floating list of notable players around you (anyone with a visible nameplate). Size it, fade it while idle, and choose what clicking a name does.",
		},
		{
			page = "general", box = "Nameplate Icon", side = "right",
			title = "Nameplate icon",
			text = "The colored diamond over notable players' nameplates. Adjust its size and position here. The preview shows it on every nameplate while you tune it.",
		},
		{
			page = "general", box = "Tooltip & Context Menu", side = "right",
			title = "Tooltip and right-click menu",
			text = "Choose what a notable player's tooltip shows, or turn the tooltip line and the right-click menu off entirely.",
		},
		{
			page = "general", box = "Auto-Prune (on login)", side = "right",
			title = "Auto-prune",
			text = "Keeps the database tidy by deleting players that match these rules each time you log in. By default: no notes, no standing, and not seen for a day.",
		},
		{
			page = "general", box = "Danger Zone", side = "right",
			title = "Danger zone",
			text = "Resets and clean-up. Reset UI puts windows and columns back the way they started. The Clear buttons delete data, and always ask first.",
		},
		{
			page = "reputation", box = "Reputation Brackets", side = "right",
			title = "Reputation brackets",
			text = "Standing (-100 to +100) is grouped into brackets. Pick a set of labels and colors here, or make your own.",
		},
		{
			page = "auto-track", box = "General", side = "right",
			title = "Auto-track",
			text = "Optional automatic entries: grouping up, rezzes, duels, questing together, and more. Each has its own toggle, rep gain, note, and cooldown.\n\nThe checkbox at the top turns them all off at once.",
		},
		{
			page = "auto-track", box = "Directed Emotes", side = "right",
			title = "Directed emotes",
			text = "Log an entry when another player's emote contains a phrase you choose, like \"waves at you\" or \"thanks you\". Each rule has its own rep gain, note, and cooldown.\n\n\"Must say 'you'\" skips emotes that aren't aimed at you.",
		},
		{
			page = "auto-track", box = "Recent Allies", side = "right",
			title = "Recent Allies",
			text = "Logs people from Blizzard's own Recent Allies list: dungeon and raid kills, delves, battlegrounds, trades, and more.",
		},
		{
			page = "auto-track", box = "Nearby Players", side = "right",
			title = "Nearby players",
			text = "Optionally records everyone whose nameplate you see, even before you've written anything about them. It's off by default, since it adds up fast in crowded places.",
		},
		{
			page = "survey", box = "Dungeon/Raid Survey", side = "right",
			title = "Dungeon/raid survey",
			text = "After a dungeon or raid, a survey lists your whole group so you can rate everyone at once.",
		},
		{
			page = "alerts", box = "Nearby Window Alerts", side = "right",
			title = "Alerts",
			text = "A sound and/or a flash when someone notable comes into range, with a cooldown per player.",
		},
		{
			page = "presets", box = "Quick-Add Presets", side = "right",
			title = "Presets",
			text = "One-click notes like Good Healer or Rude, each with its own standing change. Used by the quick-add popup, the radial menu, and macros:\n/wrquick good healer\n\nHover/click the little [?] for tips on using tokens in your notes.",
		},
		{
			page = "radial menu", box = "Radial Menu", side = "right",
			title = "Radial menu",
			text = "Hold the hotkey for a wheel of your presets. Use one wheel, or two, optionally splitting good and bad presets across two with a modifier key.",
		},
		{
			page = "ignore", box = "Ignore by Relationship", side = "right",
			title = "Ignoring by relationship",
			text = "Leave your guild, WoW friends, or BattleTag friends out of auto-entries, the survey, or indicators.",
		},
		{
			page = "ignore", box = "Ignored Players", side = "right",
			title = "Ignoring players",
			text = "Or ignore specific players, which overrides the rules above. This can be used to add exceptions to the above 'Ignore by Relationship' rules.\n\nAdd them here, or from any Worth Remembering right-click menu.",
		},
		{
			title = "All set!",
			text = "That's the tour. Everything else is in these pages too, and most options explain themselves when you hover them.\n\nIf you have any questions, please don't hesitate to get in touch with me (top right of the About tab).",
		},
	},
}

-- a sample record so the tabs and the Details step have something to show. created on a
-- fresh install (and kept), or for the length of a tour if it's missing
local DEMO_NAME, DEMO_SURNAME = "Demo", "Player"
-- vanilla race/class combos, valid on Forever and retail. race ids for C_CreatureInfo
local DEMO_COMBOS = {
	{ 1, "WARRIOR" }, { 1, "PALADIN" }, { 1, "MAGE" }, { 1, "PRIEST" },
	{ 3, "HUNTER" }, { 3, "PALADIN" }, { 4, "DRUID" }, { 4, "ROGUE" }, { 7, "WARLOCK" },
	{ 2, "SHAMAN" }, { 2, "HUNTER" }, { 5, "MAGE" }, { 5, "WARLOCK" }, { 6, "DRUID" },
	{ 6, "WARRIOR" }, { 8, "PRIEST" }, { 8, "ROGUE" },
}
local ALLIANCE_RACES = { [1] = true, [3] = true, [4] = true, [7] = true }

function ns.DemoPlayerKey()
	return ns.BuildKey(DEMO_NAME, DEMO_SURNAME)
end

-- returns true if it had to create the record
function ns.EnsureDemoPlayer()
	local key = ns.DemoPlayerKey()
	if not key or ns.GetPlayerRecord(key, false) then
		return false
	end
	local combo = DEMO_COMBOS[math.random(#DEMO_COMBOS)]
	local raceID, classFile = combo[1], combo[2]
	local info = C_CreatureInfo and C_CreatureInfo.GetRaceInfo and C_CreatureInfo.GetRaceInfo(raceID)
	local sex = math.random(2, 3)
	local record = ns.GetPlayerRecord(key, true)
	record.name, record.realmOrSurname = DEMO_NAME, DEMO_SURNAME
	record.classFile, record.raceID = classFile, raceID
	record.race = info and info.raceName or nil
	record.faction = ALLIANCE_RACES[raceID] and "Alliance" or "Horde"
	record.sex = sex
	record.demo = true

	local now, zone, me = time(), "Stranglethorn Vale", ns.GetMyFullName()
	local myLevel = UnitLevel("player")
	record.entries = {
		{ time = now - 2 * 86400, zone = zone, yourLevel = myLevel, theirLevel = myLevel + 1, theirSex = sex,
			loggedBy = me, source = "manual", delta = 5 },
		{ time = now - 86400, zone = zone, yourLevel = myLevel, theirLevel = myLevel + 1, theirSex = sex,
			loggedBy = me, source = "manual", featured = true,
			text = "Saved our group when the tank went down, then stuck around to help me finish my quest. Super friendly!" },
	}
	ns.RecomputeStanding(record)
	record.lastSeen, record.lastLocation, record.seenCount = now - 86400, zone, 2
	if ns.RefreshAllTabs then
		ns.RefreshAllTabs()
	end
	return true
end

-- what the hooked steps do: onEnter (before showing), onPlaced(box) (after the tour box
-- is positioned), onLeave (on Next/Back/close)
local nameplatePreviewWas, nearbyShownByTour, mainHiddenByTour

local STEP_HOOKS = {
	demoDetails = {
		onEnter = function()
			ns.ShowPlayerDetails(ns.DemoPlayerKey())
		end,
	},
	-- an example radial left of the tour box and Quick-Add right of it, for the demo
	-- player, with the main window out of the way
	notePreviews = {
		onEnter = function()
			local main = ns.EnsureMainFrame()
			mainHiddenByTour = main:IsShown()
			main:Hide()
		end,
		onPlaced = function(box)
			local key = ns.DemoPlayerKey()
			local record = key and ns.GetPlayerRecord(key, false)
			if not record then
				return
			end
			ns.ShowQuickAddPreview(key, box)
			local scale = box:GetEffectiveScale() / UIParent:GetEffectiveScale()
			local left, bottom, _, height = box:GetRect()
			ns.ShowRadialPreview({ key = key, name = record.name, classFile = record.classFile },
				left * scale - 140, (bottom + height / 2) * scale)
		end,
		onLeave = function()
			ns.HideQuickAddPreview()
			ns.HideRadialPreview()
			if mainHiddenByTour then
				mainHiddenByTour = nil
				ns.ShowOverview()
			end
		end,
	},
	-- nameplate icon preview on, and the Nearby window shown if it's turned off (without
	-- changing the setting)
	spotting = {
		onEnter = function()
			nameplatePreviewWas = ns.IsNameplateIconPreview and ns.IsNameplateIconPreview()
			ns.SetNameplateIconPreview(true)
			local nearby = ns.EnsureNearbyWindow and ns.EnsureNearbyWindow()
			nearbyShownByTour = nearby and not nearby:IsShown()
			if nearbyShownByTour then
				nearby:Show()
			end
		end,
		onLeave = function()
			ns.SetNameplateIconPreview(nameplatePreviewWas)
			if nearbyShownByTour and _G.WRNearbyFrame then
				_G.WRNearbyFrame:Hide()
			end
			nearbyShownByTour = nil
		end,
	},
}

local function runHook(step, name, ...)
	local hook = step and step.hook and STEP_HOOKS[step.hook]
	if hook and hook[name] then
		pcall(hook[name], ...)
	end
end

local targets = ns.tourTargets

ns.RegisterTourTarget("nearby", function() return _G.WRNearbyFrame end)


local BOX_WIDTH, PAD, ARROW_GAP = 300, 14, 26
local ARROW_FILE = "Interface\\TalentFrame\\TalentFrame-Parts"
local ROTATION = { up = 180, down = 0, left = 90, right = 270 }
-- side the box sits on -> direction its arrow points
local ARROW_DIR = { below = "up", above = "down", right = "left", left = "right" }

local callout, highlight, arrow, glow, proxy, boxProxy, alsoArrow, alsoGlow, alsoHighlight, alsoProxy
local tour, stepIndex, demoCreatedByTour

-- size is set once at creation; the clamped helper swaps width/height itself
local function rotate(tex, degrees)
	if SetClampedTextureRotation then
		SetClampedTextureRotation(tex, degrees)
	else
		tex:SetRotation(math.rad(degrees))
	end
end

local function hideGlowPieces(frame, keys)
	for _, key in ipairs(keys) do
		if frame[key] then
			frame[key]:Hide()
		end
	end
end

local function newGlowBox(name)
	local ok, frame = pcall(CreateFrame, "Frame", name, UIParent, "GlowBoxTemplate")
	if ok then
		return frame
	end
	frame = CreateFrame("Frame", name, UIParent, "BackdropTemplate")
	frame:SetBackdrop({ bgFile = "Interface/Buttons/WHITE8X8", edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 1 })
	frame:SetBackdropColor(0.1, 0.08, 0.02, 0.95)
	frame:SetBackdropBorderColor(1, 0.82, 0, 1)
	return frame
end

local function buildCallout()
	callout = newGlowBox("WRTourCallout")
	callout:SetFrameStrata("FULLSCREEN_DIALOG")
	callout:SetToplevel(true)
	callout:SetClampedToScreen(true)
	callout:EnableMouse(true)
	callout:SetWidth(BOX_WIDTH)
	tinsert(UISpecialFrames, "WRTourCallout")

	callout.title = callout:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	callout.title:SetPoint("TOPLEFT", PAD, -PAD)
	callout.title:SetPoint("RIGHT", -28, 0)
	callout.title:SetJustifyH("LEFT")

	callout.body = callout:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	callout.body:SetPoint("TOPLEFT", callout.title, "BOTTOMLEFT", 0, -8)
	callout.body:SetWidth(BOX_WIDTH - 2 * PAD)
	callout.body:SetJustifyH("LEFT")
	callout.body:SetSpacing(2)

	local close = CreateFrame("Button", nil, callout, "UIPanelCloseButton")
	close:SetSize(24, 24)
	close:SetPoint("TOPRIGHT", -2, -2)
	close:SetScript("OnClick", function()
		ns.EndTour()
		callout:Hide()
	end)

	callout.next = CreateFrame("Button", nil, callout, "UIPanelButtonTemplate")
	callout.next:SetSize(80, 22)
	callout.next:SetPoint("BOTTOMRIGHT", -PAD, PAD - 2)
	callout.next:SetScript("OnClick", function()
		if not (tour and stepIndex) then
			callout:Hide()
		elseif stepIndex < #tour then
			ns.ShowTourStep(stepIndex + 1)
		else
			ns.EndTour()
		end
	end)

	callout.back = CreateFrame("Button", nil, callout, "UIPanelButtonTemplate")
	callout.back:SetSize(80, 22)
	callout.back:SetPoint("RIGHT", callout.next, "LEFT", -6, 0)
	callout.back:SetText("Back")
	callout.back:SetScript("OnClick", function()
		if not (tour and stepIndex) then
			callout:Hide()
			return
		end
		ns.ShowTourStep(stepIndex - 1)
	end)

	callout.counter = callout:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
	callout.counter:SetPoint("LEFT", callout, "BOTTOMLEFT", PAD, PAD + 9)

	callout:SetScript("OnHide", function()
		if tour then
			ns.EndTour()
		end
	end)

	arrow = callout:CreateTexture(nil, "ARTWORK")
	arrow:SetTexture(ARROW_FILE)
	arrow:SetTexCoord(0.78515625, 0.99218750, 0.54687500, 0.58789063)
	arrow:SetSize(53, 21)
	glow = callout:CreateTexture(nil, "BORDER")
	glow:SetTexture(ARROW_FILE)
	glow:SetTexCoord(0.40625000, 0.66015625, 0.77343750, 0.82812500)
	glow:SetSize(65, 28)
	glow:SetBlendMode("ADD")
	glow:SetAlpha(0.5)
	glow:SetPoint("CENTER", arrow, "CENTER")

	highlight = newGlowBox(nil)
	highlight:SetFrameStrata("FULLSCREEN_DIALOG")
	highlight:EnableMouse(false)
	hideGlowPieces(highlight, { "BG", "ShadowTopLeft", "ShadowTopRight", "ShadowBottomLeft", "ShadowBottomRight",
		"ShadowTop", "ShadowBottom", "ShadowLeft", "ShadowRight" })
	if highlight.SetBackdropColor then
		highlight:SetBackdropColor(0, 0, 0, 0)
	end

	alsoArrow = callout:CreateTexture(nil, "ARTWORK")
	alsoArrow:SetTexture(ARROW_FILE)
	alsoArrow:SetTexCoord(0.78515625, 0.99218750, 0.54687500, 0.58789063)
	alsoArrow:SetSize(37, 15)
	alsoArrow:SetAlpha(0.8)
	alsoGlow = callout:CreateTexture(nil, "BORDER")
	alsoGlow:SetTexture(ARROW_FILE)
	alsoGlow:SetTexCoord(0.40625000, 0.66015625, 0.77343750, 0.82812500)
	alsoGlow:SetSize(46, 20)
	alsoGlow:SetBlendMode("ADD")
	alsoGlow:SetAlpha(0.2)
	alsoGlow:SetPoint("CENTER", alsoArrow, "CENTER")

	alsoHighlight = newGlowBox(nil)
	alsoHighlight:SetFrameStrata("FULLSCREEN_DIALOG")
	alsoHighlight:EnableMouse(false)
	hideGlowPieces(alsoHighlight, { "BG", "ShadowTopLeft", "ShadowTopRight", "ShadowBottomLeft", "ShadowBottomRight",
		"ShadowTop", "ShadowBottom", "ShadowLeft", "ShadowRight" })
	if alsoHighlight.SetBackdropColor then
		alsoHighlight:SetBackdropColor(0, 0, 0, 0)
	end
	-- the secondary pointer is a quieter version of the main one
	alsoHighlight:SetAlpha(0.45)

	proxy = CreateFrame("Frame", nil, UIParent)
	alsoProxy = CreateFrame("Frame", nil, UIParent)
	boxProxy = CreateFrame("Frame", nil, UIParent)
end

-- boxes the tour opened, closed again when it moves on
local expandedByTour = {}

local function expandBox(key)
	local entry = ns.tourBoxes[key]
	if entry and entry.toggle and not entry.expanded then
		entry.toggle()
		expandedByTour[key] = true
	end
end

local function collapseBox(key)
	if not expandedByTour[key] then
		return
	end
	expandedByTour[key] = nil
	local entry = ns.tourBoxes[key]
	if entry and entry.toggle and entry.expanded then
		entry.toggle()
	end
end

local function scrollFrameOf(box)
	local child = box:GetParent()
	local scroll = child and child:GetParent()
	if scroll and scroll.GetObjectType and scroll:GetObjectType() == "ScrollFrame" then
		return scroll, child
	end
end

local function scrollToBox(key)
	local entry = ns.tourBoxes[key]
	local box = entry and entry.box
	if not box then
		return
	end
	local scroll, child = scrollFrameOf(box)
	if not (scroll and child:GetTop() and box:GetTop()) then
		return
	end
	local offset = child:GetTop() - box:GetTop() - 8
	scroll:SetVerticalScroll(math.max(0, math.min(offset, scroll:GetVerticalScrollRange() or 0)))
end

-- the part of the box currently scrolled into view
local function boxTarget(key)
	local entry = ns.tourBoxes[key]
	local box = entry and entry.box
	if not (box and box:IsVisible()) then
		return nil
	end
	local scroll = scrollFrameOf(box)
	if not scroll then
		return box
	end
	local top, bottom = box:GetTop(), box:GetBottom()
	local visTop, visBottom = math.min(top, scroll:GetTop()), math.max(bottom, scroll:GetBottom())
	if visTop <= visBottom then
		return nil
	end
	boxProxy:SetParent(scroll)
	boxProxy:ClearAllPoints()
	boxProxy:SetPoint("TOPLEFT", box, "TOPLEFT", 0, visTop - top)
	boxProxy:SetPoint("BOTTOMRIGHT", box, "TOPRIGHT", 0, visBottom - top)
	boxProxy:Show()
	return boxProxy
end

-- flips left/right when the box wouldn't fit on that side of the screen
local function fitSide(side, target)
	if side ~= "left" and side ~= "right" then
		return side
	end
	local scale = target:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local need = (BOX_WIDTH + ARROW_GAP + 10) * callout:GetEffectiveScale() / UIParent:GetEffectiveScale()
	local roomRight = UIParent:GetWidth() - target:GetRight() * scale
	local roomLeft = target:GetLeft() * scale
	if side == "right" and roomRight < need then
		return roomLeft >= need and "left" or "center"
	elseif side == "left" and roomLeft < need then
		return roomRight >= need and "right" or "center"
	end
	return side
end

local function resolveTarget(name, pairProxy)
	pairProxy = pairProxy or proxy
	local target = name and targets[name]
	if type(target) == "function" then
		target = target()
	end
	if type(target) == "table" and target[1] then
		local first, last = target[1], target[2] or target[1]
		if not (first:IsVisible() and last:IsVisible()) then
			return nil
		end
		pairProxy:ClearAllPoints()
		pairProxy:SetPoint("TOPLEFT", first, "TOPLEFT")
		pairProxy:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT")
		pairProxy:Show()
		return pairProxy
	end
	if target and target.IsVisible and target:IsVisible() then
		return target
	end
	return nil
end

-- faint boxes around specific controls a step mentions. "glow" (soft gold) or "red"
-- (plain border)
local MARK_STYLE = "glow"
local MARK_PAD = 6
local marks = {}

local function getMark(i)
	if marks[i] then
		return marks[i]
	end
	local mark
	if MARK_STYLE == "red" then
		mark = CreateFrame("Frame", nil, UIParent, "BackdropTemplate")
		mark:SetBackdrop({ edgeFile = "Interface/Buttons/WHITE8X8", edgeSize = 2 })
		mark:SetBackdropBorderColor(0.9, 0.15, 0.15, 0.9)
	else
		mark = newGlowBox(nil)
		hideGlowPieces(mark, { "BG", "ShadowTopLeft", "ShadowTopRight", "ShadowBottomLeft", "ShadowBottomRight",
			"ShadowTop", "ShadowBottom", "ShadowLeft", "ShadowRight" })
		if mark.SetBackdropColor then
			mark:SetBackdropColor(0, 0, 0, 0)
		end
		mark:SetAlpha(0.35)
	end
	mark:SetFrameStrata("FULLSCREEN_DIALOG")
	mark:EnableMouse(false)
	mark.proxy = CreateFrame("Frame", nil, UIParent)
	marks[i] = mark
	return mark
end

local function hideMarks()
	for _, mark in ipairs(marks) do
		mark:Hide()
	end
end

local function placeMarks(step)
	hideMarks()
	for i, name in ipairs(step.marks or {}) do
		local mark = getMark(i)
		local target = resolveTarget(name, mark.proxy)
		if target then
			mark:ClearAllPoints()
			mark:SetPoint("TOPLEFT", target, "TOPLEFT", -MARK_PAD, MARK_PAD)
			mark:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", MARK_PAD, -MARK_PAD)
			mark:SetFrameLevel(callout:GetFrameLevel() - 1)
			mark:Show()
		end
	end
end

-- the arrow sits on `side` of the target, pointing at it
local ALSO_ARROW_DIR = { left = "right", right = "left", above = "down", below = "up" }
-- room between the target and its box, so the glow border clears the text
local ALSO_PAD = 8

local function placeAlso(step)
	alsoArrow:Hide()
	alsoGlow:Hide()
	alsoHighlight:Hide()
	local target = step.also and resolveTarget(step.also, alsoProxy)
	if not target then
		return
	end
	alsoHighlight:ClearAllPoints()
	alsoHighlight:SetPoint("TOPLEFT", target, "TOPLEFT", -ALSO_PAD, ALSO_PAD)
	alsoHighlight:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", ALSO_PAD, -ALSO_PAD)
	alsoHighlight:SetFrameLevel(callout:GetFrameLevel() - 1)
	alsoHighlight:Show()

	local side = step.alsoSide or "left"
	local dir = ALSO_ARROW_DIR[side] or "right"
	rotate(alsoArrow, ROTATION[dir])
	rotate(alsoGlow, ROTATION[dir])
	alsoArrow:ClearAllPoints()
	local gap = ALSO_PAD + 3
	if side == "left" then
		alsoArrow:SetPoint("RIGHT", target, "LEFT", -gap, 0)
	elseif side == "right" then
		alsoArrow:SetPoint("LEFT", target, "RIGHT", gap, 0)
	elseif side == "above" then
		alsoArrow:SetPoint("BOTTOM", target, "TOP", 0, gap)
	else
		alsoArrow:SetPoint("TOP", target, "BOTTOM", 0, -gap)
	end
	alsoArrow:Show()
	alsoGlow:Show()
end

local function placeUnsafe(step)
	callout.title:SetText(step.title or "")
	callout.body:SetText(step.text or "")
	callout.counter:SetText(stepIndex .. " / " .. #tour)
	callout.back:SetEnabled(stepIndex > 1)
	callout.next:SetText(stepIndex < #tour and "Next" or "Finish")
	local height = PAD + callout.title:GetStringHeight() + 8 + callout.body:GetStringHeight() + 14 + 22 + PAD
	callout:SetHeight(height)

	local target
	if step.box then
		target = boxTarget(step.box)
	else
		target = resolveTarget(step.target)
	end
	local side = target and fitSide(step.side or "center", target) or "center"
	callout:ClearAllPoints()
	arrow:Hide()
	glow:Hide()
	highlight:Hide()

	if not target then
		local main = ns.EnsureMainFrame and ns.EnsureMainFrame()
		local anchor = (main and main:IsShown()) and main or UIParent
		callout:SetPoint("CENTER", anchor, "CENTER")
	else
		highlight:ClearAllPoints()
		highlight:SetPoint("TOPLEFT", target, "TOPLEFT", -4, 4)
		highlight:SetPoint("BOTTOMRIGHT", target, "BOTTOMRIGHT", 4, -4)
		highlight:SetFrameLevel(callout:GetFrameLevel() - 1)
		highlight:Show()

		if side == "below" then
			callout:SetPoint("TOP", target, "BOTTOM", 0, -ARROW_GAP)
		elseif side == "above" then
			callout:SetPoint("BOTTOM", target, "TOP", 0, ARROW_GAP)
		elseif side == "right" then
			callout:SetPoint("LEFT", target, "RIGHT", ARROW_GAP, 0)
		elseif side == "left" then
			callout:SetPoint("RIGHT", target, "LEFT", -ARROW_GAP, 0)
		else
			callout:SetPoint("CENTER", target, "CENTER")
		end

		local dir = ARROW_DIR[side]
		if dir then
			rotate(arrow, ROTATION[dir])
			rotate(glow, ROTATION[dir])
			arrow:ClearAllPoints()
			if dir == "up" then
				arrow:SetPoint("BOTTOM", callout, "TOP", 0, 2)
			elseif dir == "down" then
				arrow:SetPoint("TOP", callout, "BOTTOM", 0, -2)
			elseif dir == "left" then
				arrow:SetPoint("RIGHT", callout, "LEFT", -2, 0)
			else
				arrow:SetPoint("LEFT", callout, "RIGHT", 2, 0)
			end
			arrow:Show()
			glow:Show()
		end
	end
	callout:Show()
	placeAlso(step)
	placeMarks(step)
	runHook(step, "onPlaced", callout)
end

-- a failed placement still leaves a usable, centered box instead of a stuck one
local function place(step)
	local ok, err = pcall(placeUnsafe, step)
	if not ok then
		ns.Print("Tour step failed to place: " .. tostring(err))
		callout:ClearAllPoints()
		callout:SetPoint("CENTER", UIParent, "CENTER")
		arrow:Hide()
		glow:Hide()
		highlight:Hide()
		alsoHighlight:Hide()
		hideMarks()
		callout:Show()
	end
end

local function leaveStep(nextStep)
	local step = tour and stepIndex and tour[stepIndex]
	if not step then
		return
	end
	runHook(step, "onLeave")
	if step.box and not (nextStep and nextStep.box == step.box) then
		collapseBox(step.box)
	end
end

function ns.ShowTourStep(index)
	if not tour or not tour[index] then
		return
	end
	local step = tour[index]
	leaveStep(step)
	stepIndex = index
	local tab = step.tab or (step.page and "options")
	if tab and ns.SelectMainTab then
		ns.SelectMainTab(tab)
	end
	if step.page and ns.SelectOptionsSubTab then
		ns.SelectOptionsSubTab(step.page)
	end
	if step.box then
		expandBox(step.box)
	end
	runHook(step, "onEnter")
	-- tab switches, box rebuilds and filter reflow settle on the next frame; a box is
	-- scrolled to first, then measured a frame later
	C_Timer.After(0, function()
		if not (tour and stepIndex == index) then
			return
		end
		if step.box then
			scrollToBox(step.box)
			C_Timer.After(0, function()
				if tour and stepIndex == index then
					place(step)
				end
			end)
		else
			place(step)
		end
	end)
end

function ns.StartTour(id)
	local steps = ns.TOURS[id or "basics"]
	if not steps then
		return
	end
	if not callout then
		buildCallout()
	end
	if tour then
		leaveStep()
	end
	tour = steps
	demoCreatedByTour = ns.EnsureDemoPlayer() or demoCreatedByTour
	ns.ShowTourStep(1)
end

function ns.EndTour()
	if not tour then
		return
	end
	leaveStep()
	tour, stepIndex = nil, nil
	if callout then
		callout:Hide()
		highlight:Hide()
		alsoHighlight:Hide()
		hideMarks()
	end
	if demoCreatedByTour then
		demoCreatedByTour = nil
		local key = ns.DemoPlayerKey()
		local record = key and ns.GetPlayerRecord(key, false)
		if record and record.demo then
			ns.DeletePlayerRecord(key)
			ns.RefreshAllTabs()
		end
	end
end

StaticPopupDialogs["WR_TOUR_OFFER_EXISTING"] = {
	text = "Thank you for using Worth Remembering!\n\n"
		.. "I promise I'm not in the business of unsolicited popups, so this is a one-off for existing users. "
		.. "I've added a tour feature to walk through most of the things Worth Remembering does, and I wanted to "
		.. "offer it this once since there's a good chance features have been added since you started using the addon.\n\n"
		.. "Would you like to take the tour?\n"
		.. "(\"No\" will never show you this window again.)",
	button1 = "Take the tour",
	button2 = "No",
	OnAccept = function()
		ns.StartTour("basics")
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}

StaticPopupDialogs["WR_TOUR_OFFER"] = {
	text = "Welcome to Worth Remembering!\n\nWant a quick tour of the basics? It takes about two minutes.",
	button1 = "Take the tour",
	button2 = "No thanks",
	OnAccept = function()
		ns.StartTour("basics")
	end,
	OnCancel = function(_, _, reason)
		if reason == "clicked" then
			ns.Print("No problem. You can take the tour any time from the About tab.")
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
	preferredIndex = 3,
}
