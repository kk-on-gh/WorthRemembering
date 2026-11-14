local ns = WorthRemembering

-- step = { title, text, tab?, optionsSub?, target? (ns.RegisterTourTarget name),
--   side? ("below" | "above" | "left" | "right" | "center"), onEnter?, onLeave? }
-- no target, or a target that isn't visible, shows the box centered on the window
local nameplatePreviewWas

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
			title = "The list",
			text = "Click a name to open their Details.\n\nClick a class, race, bracket, or other value to filter the list to just that. Click it again to clear it.\n\nRight-click a row for more options.",
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
			tab = "details", target = "tab.details", side = "below",
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
			text = "Every feature can be turned on or off, and most can be customized. The Settings tour (About tab) walks through the important ones.",
		},
		{
			title = "Adding notes",
			text = "Right-click any player (in the world, in chat, in your group) and choose Worth Remembering > Add Note.\n\nEven quicker: set a global hotkey in Options > General, then tap it with someone targeted. Hold it instead for a radial menu of your presets.",
		},
		{
			title = "Spotting people",
			text = "Players you've noted get a diamond over their nameplate, colored by their standing. For this step, every nameplate nearby shows one.\n\nTheir standing also shows after their name in chat, like [+10], and in their tooltip.",
			onEnter = function()
				nameplatePreviewWas = ns.IsNameplateIconPreview and ns.IsNameplateIconPreview()
				ns.SetNameplateIconPreview(true)
			end,
			onLeave = function()
				ns.SetNameplateIconPreview(nameplatePreviewWas)
			end,
		},
		{
			target = "minimap", side = "below",
			title = "Minimap button",
			text = "Left-click to open this window, right-click for a quick menu. You can hide it in Options > General.",
		},
		{
			tab = "about", target = "tab.about", side = "below",
			title = "About",
			text = "Patch notes, ways to reach me, and both tours live here.",
		},
		{
			title = "That's it!",
			text = "Go meet some people worth remembering.\n\nQuestions, ideas, or bugs? The About tab has my contact info.",
		},
	},
}

local targets = ns.tourTargets

ns.RegisterTourTarget("minimap", function() return _G.WRMinimapButton end)

local BOX_WIDTH, PAD, ARROW_GAP = 300, 14, 26
local ARROW_FILE = "Interface\\TalentFrame\\TalentFrame-Parts"
local ROTATION = { up = 180, down = 0, left = 270, right = 90 }
-- side the box sits on -> direction its arrow points
local ARROW_DIR = { below = "up", above = "down", right = "left", left = "right" }

local callout, highlight, arrow, glow, proxy
local tour, stepIndex

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
	close:SetScript("OnClick", function() ns.EndTour() end)

	callout.next = CreateFrame("Button", nil, callout, "UIPanelButtonTemplate")
	callout.next:SetSize(80, 22)
	callout.next:SetPoint("BOTTOMRIGHT", -PAD, PAD - 2)
	callout.next:SetScript("OnClick", function()
		if stepIndex < #tour then
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

	proxy = CreateFrame("Frame", nil, UIParent)
end

local function resolveTarget(name)
	local target = name and targets[name]
	if type(target) == "function" then
		target = target()
	end
	if type(target) == "table" and target[1] then
		local first, last = target[1], target[2] or target[1]
		if not (first:IsVisible() and last:IsVisible()) then
			return nil
		end
		proxy:ClearAllPoints()
		proxy:SetPoint("TOPLEFT", first, "TOPLEFT")
		proxy:SetPoint("BOTTOMRIGHT", last, "BOTTOMRIGHT")
		proxy:Show()
		return proxy
	end
	if target and target.IsVisible and target:IsVisible() then
		return target
	end
	return nil
end

local function place(step)
	callout.title:SetText(step.title or "")
	callout.body:SetText(step.text or "")
	callout.counter:SetText(stepIndex .. " / " .. #tour)
	callout.back:SetEnabled(stepIndex > 1)
	callout.next:SetText(stepIndex < #tour and "Next" or "Finish")
	local height = PAD + callout.title:GetStringHeight() + 8 + callout.body:GetStringHeight() + 14 + 22 + PAD
	callout:SetHeight(height)

	local target = resolveTarget(step.target)
	local side = target and step.side or "center"
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
end

local function leaveStep()
	local step = tour and stepIndex and tour[stepIndex]
	if step and step.onLeave then
		pcall(step.onLeave)
	end
end

function ns.ShowTourStep(index)
	if not tour or not tour[index] then
		return
	end
	leaveStep()
	stepIndex = index
	local step = tour[index]
	if step.tab and ns.SelectMainTab then
		ns.SelectMainTab(step.tab)
	end
	if step.optionsSub and ns.SelectOptionsSubTab then
		ns.SelectOptionsSubTab(step.optionsSub)
	end
	if step.onEnter then
		pcall(step.onEnter)
	end
	-- tab switches and filter reflow settle on the next frame
	C_Timer.After(0, function()
		if tour and stepIndex == index then
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
	end
end

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
