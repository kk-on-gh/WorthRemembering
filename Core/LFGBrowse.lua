local ns = WorthRemembering

-- Decorates Forever's group finder Browse tab (LFGBrowseFrame -- Blizzard's Cataclysm
-- Classic group browser with a "vanilla" skin on top, confirmed live: the C_LFGList data
-- API matches retail exactly, but the frame/global names are this client's own) with WR
-- standing: a tag on the listing's leader directly on the row, and every member's own
-- tag appended to the row's hover tooltip. Browsing here exposes full member rosters via
-- C_LFGList.GetSearchResultPlayerInfo(resultID, memberIndex), confirmed live, unlike
-- retail's Premade Groups (which only exposes the leader + counts for groups you haven't
-- joined) -- so unlike that system, every member's rating can be shown, not just the
-- leader's.

local function keyForName(fullName)
	if not fullName or fullName == "" then
		return nil
	end
	local name, suffix = ns.SplitNameSuffix(fullName)
	return ns.BuildKey(name, suffix)
end

-- nil when there's no record, or its standing falls inside the neutral band. stricter
-- than ns.IsNotable (which Tooltip/ChatIndicator use): that also flags a record with
-- note text but a neutral standing, which would show a "[WR+0]"-ish tag here that isn't
-- actually meaningful for an at-a-glance rating like this one.
local function notableRecord(key)
	local record = key and ns.GetPlayerRecord(key, false)
	if not record then
		return nil
	end
	local band = ns.GetSettings().neutralBand
	if math.abs(record.standing or 0) <= band then
		return nil
	end
	return record
end

-- colored by bracket (the same red/green/neutral tiers used for nameplate icons and the
-- Statistics bracket breakdown), not just a flat positive/negative split.
local function standingTag(key)
	local record = notableRecord(key)
	if not record then
		return nil
	end
	local standing = record.standing or 0
	local sign = standing > 0 and "+" or ""
	local hex = ns.ToHex(unpack(ns.GetBracket(standing).color))
	return "|c" .. hex .. "[WR" .. sign .. standing .. "]|r"
end

-- a compact stand-in for standingTag, one per notable non-leader party member: the full
-- "[WR+N]" tag is reserved for the leader (already shown on the row), a bracket-colored
-- asterisk per other notable member just flags "someone in here has history" without
-- needing room for everyone's full tag on the row itself (the tooltip still shows those).
local function standingAsterisk(key)
	local record = notableRecord(key)
	if not record then
		return nil
	end
	local hex = ns.ToHex(unpack(ns.GetBracket(record.standing or 0).color))
	return "|c" .. hex .. "*|r"
end

-- resultID for whichever listing/divider `frame` currently represents, nil for a divider
-- or anything else that isn't a listing row (the ScrollBox recycles a handful of row
-- frames across both rows and category dividers; GetElementData() returns a tree node,
-- :GetData() the actual payload table). walks up a few parents too, since a tooltip's
-- GetOwner() may be an inner widget rather than the row frame GetFrames() itself returns.
local function resultIDFor(frame)
	for _ = 1, 4 do
		if not frame then
			return nil
		end
		if frame.GetElementData then
			local node = frame:GetElementData()
			local data = node and node:GetData()
			if data and data.resultID then
				return data.resultID
			end
		end
		frame = frame.GetParent and frame:GetParent()
	end
	return nil
end

-- exposed for the Quick Note keybind (see UI/QuickAdd.lua's ns.QuickNoteTarget): while
-- actually hovering a listing in the Browse tab, tapping the global keybind opens the
-- Players tab filtered to that group's whole roster instead of its usual fallback
-- behavior. nil whenever nothing qualifies (LFG not open, cursor not over a listing row,
-- or a row with no members for some reason), so that fallback chain can just check this
-- like any other candidate source and fall through to normal behavior otherwise. defined
-- at the top level, not inside setup() below, so it's always safe to call even before
-- the lazily-loaded LFG addon exists yet -- it just returns nil until then.
function ns.GetHoveredLFGRoster()
	if not ns.GetSettings().lfgIntegrationEnabled then
		return nil
	end
	-- IsVisible, not IsShown: closing the parent LFG panel doesn't always Hide() this
	-- sub-frame specifically, so IsShown alone can stay true indefinitely.
	if not (LFGBrowseFrame and LFGBrowseFrame:IsVisible() and LFGBrowseFrame.ScrollBox
		and C_LFGList and C_LFGList.GetSearchResultInfo and C_LFGList.GetSearchResultPlayerInfo) then
		return nil
	end
	for _, frame in ipairs(LFGBrowseFrame.ScrollBox:GetFrames()) do
		if frame:IsMouseOver() then
			local resultID = resultIDFor(frame)
			local info = resultID and C_LFGList.GetSearchResultInfo(resultID)
			if not info then
				return nil
			end
			-- info.numMembers can be a "secret" value, unusable as a loop bound
			local names = {}
			for i = 1, 40 do
				local member = C_LFGList.GetSearchResultPlayerInfo(resultID, i)
				if not member then
					break
				end
				if member.name then
					names[#names + 1] = member.name
				end
			end
			return #names > 0 and names or nil
		end
	end
	return nil
end

-- Forever's group finder is its own lazily-loaded addon: nothing under LFGBrowseFrame
-- exists yet at our own load time (character login), only once the player actually opens
-- the group finder window for the first time in a session. setup() does the real work
-- and is retried from ADDON_LOADED until everything it needs actually exists, instead of
-- a one-shot top-level check that would silently (and permanently) no-op every time.
local initialized = false

local function setup()
	if initialized then
		return true
	end
	if not (LFGBrowseFrame and LFGBrowseFrame.ScrollBox and LFGBrowseSearchEntryTooltip
		and C_LFGList and C_LFGList.GetSearchResultInfo and C_LFGList.GetSearchResultPlayerInfo) then
		return false
	end
	initialized = true

	-- appends straight into the row's own Name label instead of overlaying a separate
	-- FontString: a standalone widget doesn't participate in Blizzard's own row
	-- spacing/layout at all, so two overlay attempts (beside the name, then below it)
	-- both ended up drawn on top of neighboring content instead of making room for
	-- themselves. always rebuilt from the clean C_LFGList name (not read back from
	-- Name's own current text), since this same pooled frame gets reused for a
	-- different listing as the list scrolls and must fully overwrite whatever an
	-- earlier listing left there, not append onto it again.
	local function updateRow(frame)
		if not frame.Name then
			return
		end
		local resultID = resultIDFor(frame)
		local info = resultID and C_LFGList.GetSearchResultInfo(resultID)
		local leaderName = info and info.leaderName
		if not leaderName then
			return
		end
		if not ns.GetSettings().lfgIntegrationEnabled then
			-- reset in case this pooled row still carries a tag from before the
			-- setting was turned off mid-session
			frame.Name:SetText(leaderName)
			return
		end

		-- one bracket-colored asterisk per other notable party member, before the
		-- leader's own tag. info.numMembers can be a "secret" value, unusable as a
		-- loop bound, so this loops on a literal cap instead.
		local stars = ""
		for i = 1, 40 do
			local member = C_LFGList.GetSearchResultPlayerInfo(resultID, i)
			if not member then
				break
			end
			if member.name and not member.isLeader then
				stars = stars .. (standingAsterisk(keyForName(member.name)) or "")
			end
		end

		local tag = standingTag(keyForName(leaderName))
		local suffix = (tag or "") .. stars
		frame.Name:SetText(suffix ~= "" and (leaderName .. "  " .. suffix) or leaderName)
	end

	-- throttled poll instead of hooking the ScrollBox's own refresh: simpler and more
	-- robust than guessing at this client's exact internal update/callback names
	-- (several guesses for the row-level update function came back nil during
	-- testing), at the cost of up to THROTTLE seconds of staleness, invisible for a
	-- browse list that isn't changing every frame anyway
	local THROTTLE = 0.2
	local sinceLast = 0
	local updater = CreateFrame("Frame")
	updater:SetScript("OnUpdate", function(_, elapsed)
		-- IsVisible, not IsShown: see ns.GetHoveredLFGRoster above
		if not LFGBrowseFrame:IsVisible() then
			return
		end
		sinceLast = sinceLast + elapsed
		if sinceLast < THROTTLE then
			return
		end
		sinceLast = 0
		for _, frame in ipairs(LFGBrowseFrame.ScrollBox:GetFrames()) do
			updateRow(frame)
		end
	end)

	-- member roster: LFGBrowseSearchEntryTooltip is this client's dedicated tooltip for
	-- these rows (not the shared GameTooltip). it's a NineSlice-templated tooltip
	-- (Blizzard_LFGVanilla_Browse.lua), not a plain GameTooltip clone: no :AddLine, its
	-- member list is already rendered through its own `memberPool` of per-member
	-- widgets (each with its own .Name/.Level/.Role, confirmed live). appends straight
	-- into each widget's own Name label, same reasoning as the row above: a separate
	-- overlay widget doesn't get its own space reserved in this tightly-packed list, so
	-- it just draws over the next member's line instead. Blizzard re-sets each widget's
	-- Name fresh before this fires (confirmed: it's already showing the right name when
	-- we read it), so reading-then-appending here each time this tooltip opens doesn't
	-- compound across repeated opens the way it would on a widget reused without a
	-- fresh reset in between.
	LFGBrowseSearchEntryTooltip:HookScript("OnShow", function(tooltip)
		if not ns.GetSettings().lfgIntegrationEnabled then
			return
		end
		if not (tooltip.memberPool and tooltip.memberPool.EnumerateActive) then
			return
		end
		-- Level is anchored off Name's own right edge, so widening only the tagged
		-- row's Name (to fit the appended tag) pushed just that row's Level out of line
		-- with the rest. collect every visible member's Name width first, then apply
		-- the widest one to all of them, so Level lines up the same for every row
		-- regardless of which one actually got a tag.
		local function processNameWidget(widget, widgets)
			if not (widget and widget.Name) then
				return
			end
			local name = widget.Name:GetText()
			local tag = name and standingTag(keyForName(name))
			if tag then
				-- this label is fixed-width with ellipsis truncation (confirmed
				-- live: the tag was getting clipped off), unlike the row's own
				-- Name. 0 lets it measure/size to its actual text instead of
				-- clipping to whatever width Blizzard gave it for a plain name.
				widget.Name:SetWidth(0)
				widget.Name:SetText(name .. "  " .. tag)
			end
			widgets[#widgets + 1] = widget
		end

		local widgets = {}
		-- the leader isn't one of the pooled member widgets: it's rendered through its
		-- own dedicated tooltip.Leader frame (confirmed live -- the leader's row wasn't
		-- getting aligned with the rest until this was added), same .Name/.Level shape
		-- as a pooled member widget.
		processNameWidget(tooltip.Leader, widgets)
		for widget in tooltip.memberPool:EnumerateActive() do
			processNameWidget(widget, widgets)
		end

		local maxWidth = 0
		for _, widget in ipairs(widgets) do
			maxWidth = math.max(maxWidth, widget.Name:GetStringWidth())
		end
		for _, widget in ipairs(widgets) do
			widget.Name:SetWidth(maxWidth)
		end
	end)

	return true
end

if not setup() then
	local waiter = CreateFrame("Frame")
	waiter:RegisterEvent("ADDON_LOADED")
	waiter:SetScript("OnEvent", function(self)
		if setup() then
			self:UnregisterEvent("ADDON_LOADED")
		end
	end)
end
