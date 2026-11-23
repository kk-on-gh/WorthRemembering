local ns = WorthRemembering
local Skin = ns.Skin

-- index -> expanded bool. the most recent version starts expanded, plus (right after
-- an update) every version newer than the one last seen, see expandMissedVersions
local expanded = { [1] = true }

-- numeric, part by part: "0.10" is newer than "0.9"
local function isNewerVersion(a, b)
	local partsA, partsB = {}, {}
	for n in tostring(a):gmatch("%d+") do partsA[#partsA + 1] = tonumber(n) end
	for n in tostring(b):gmatch("%d+") do partsB[#partsB + 1] = tonumber(n) end
	for i = 1, math.max(#partsA, #partsB) do
		local x, y = partsA[i] or 0, partsB[i] or 0
		if x ~= y then
			return x > y
		end
	end
	return false
end

local function expandMissedVersions()
	local from = ns.UpdatedFromVersion
	if not from then
		return
	end
	for index, entry in ipairs(ns.CHANGELOG) do
		if isNewerVersion(entry.version, from) then
			expanded[index] = true
		end
	end
end

local scrollChild
local function layout() end

local function clearScrollChild()
	-- GetChildren() only returns child frames (the header buttons below), not the
	-- section/item FontStrings created directly on scrollChild -- those are regions,
	-- not frames, and were the reason collapsing a section left its text on screen.
	for _, child in ipairs({ scrollChild:GetChildren() }) do
		child:Hide()
		child:SetParent(nil)
	end
	for _, region in ipairs({ scrollChild:GetRegions() }) do
		region:Hide()
		region:SetParent(nil)
	end
end

-- a "what's new" tour (ns.TOURS["v<version>"]) gets a button in its section, for the
-- newest three versions only: older tours point at UI that may have moved since
local FEATURE_TOUR_VERSIONS = 3
-- versions whose button is glowing right now. it glows once: from first sight until
-- it's hovered or the About tab is left (tab change or window closed)
local glowing = {}
local glowFrames = {}

local function stopGlow(version)
	glowing[version] = nil
	if glowFrames[version] then
		glowFrames[version]:Hide()
		glowFrames[version] = nil
	end
end

local function stopAllGlows()
	for version in pairs(glowing) do
		stopGlow(version)
	end
end

local function addGlow(button)
	local glow = Skin.CreateGlow(button)
	if glow then
		glow:Show()
	else
		local ok
		ok, glow = pcall(CreateFrame, "Frame", nil, button, "GlowBoxTemplate")
		if not ok then
			return nil
		end
		for _, key in ipairs({ "BG", "ShadowTopLeft", "ShadowTopRight", "ShadowBottomLeft", "ShadowBottomRight",
			"ShadowTop", "ShadowBottom", "ShadowLeft", "ShadowRight" }) do
			if glow[key] then
				glow[key]:Hide()
			end
		end
		glow:SetPoint("TOPLEFT", -3, 3)
		glow:SetPoint("BOTTOMRIGHT", 3, -3)
	end
	glow:EnableMouse(false)
	local pulse = glow:CreateAnimationGroup()
	pulse:SetLooping("BOUNCE")
	local fade = pulse:CreateAnimation("Alpha")
	fade:SetFromAlpha(1)
	fade:SetToAlpha(0.25)
	fade:SetDuration(0.9)
	pulse:Play()
	return glow
end

local function addVersionBlock(index, entry, y)
	local header = CreateFrame("Button", nil, scrollChild)
	header:SetPoint("TOPLEFT", 0, y)
	header:SetPoint("RIGHT", -4, 0)
	header:SetHeight(20)

	local headerText = Skin.Text(header, "ARTWORK", "GameFontNormalSmall")
	headerText:SetPoint("LEFT", 4, 0)
	local shippedTag = entry.shipped and "" or "  |cffff6060(unreleased)|r"
	headerText:SetText((expanded[index] and "[-] " or "[+] ") .. "v" .. entry.version .. " - " .. entry.date .. shippedTag)

	header:SetScript("OnClick", function()
		expanded[index] = not expanded[index]
		layout()
	end)

	y = y - 22

	if not expanded[index] then
		return y
	end

	local tourId = "v" .. entry.version
	if index <= FEATURE_TOUR_VERSIONS and ns.TOURS and ns.TOURS[tourId] then
		local tourButton = CreateFrame("Button", nil, scrollChild, "UIPanelButtonTemplate")
		tourButton:SetSize(170, 20)
		Skin.Button(tourButton)
		tourButton:SetPoint("TOPLEFT", 16, y - 2)
		tourButton:SetText("Tour what's new in " .. entry.version)
		tourButton:SetScript("OnClick", function() ns.StartTour(tourId) end)
		local version = entry.version
		if not ns.WasFeatureTourSeen(version) then
			ns.MarkFeatureTourSeen(version)
			glowing[version] = true
		end
		if glowing[version] then
			glowFrames[version] = addGlow(tourButton)
			tourButton:HookScript("OnEnter", function() stopGlow(version) end)
		end
		y = y - 30
	end

	-- optional plain paragraphs before the sections, no bullet
	if entry.intro then
		for _, paragraph in ipairs(entry.intro) do
			local fs = Skin.Text(scrollChild, "ARTWORK", "GameFontHighlightSmall")
			fs:SetPoint("TOPLEFT", 16, y)
			fs:SetWidth(scrollChild:GetWidth() - 32)
			fs:SetJustifyH("LEFT")
			fs:SetWordWrap(true)
			fs:SetText(paragraph)
			y = y - fs:GetStringHeight() - 8
		end
		y = y - 4
	end

	for _, section in ipairs(entry.sections) do
		if section.heading then
			local sectionLabel = Skin.Text(scrollChild, "ARTWORK", "GameFontNormalSmall")
			sectionLabel:SetPoint("TOPLEFT", 16, y)
			if not Skin.Heading(sectionLabel, Skin.AccentColor()) then
				sectionLabel:SetTextColor(1, 0.82, 0)
			end
			sectionLabel:SetText(section.heading)
			y = y - 16
		end

		for _, item in ipairs(section.items) do
			local fs = Skin.Text(scrollChild, "ARTWORK", "GameFontHighlightSmall")
			fs:SetPoint("TOPLEFT", 26, y)
			fs:SetWidth(scrollChild:GetWidth() - 42)
			fs:SetJustifyH("LEFT")
			fs:SetWordWrap(true)
			fs:SetText("- " .. item)
			y = y - fs:GetStringHeight() - 6
		end

		y = y - 6
	end

	return y - 6
end

function layout()
	clearScrollChild()

	local y = -4
	for index, entry in ipairs(ns.CHANGELOG) do
		y = addVersionBlock(index, entry, y)
	end

	scrollChild:SetHeight(-y + 10)
end

function ns.BuildAboutPanel(parent)
	local PAD = 20
	expandMissedVersions()
	parent:HookScript("OnHide", stopAllGlows)

	local header = CreateFrame("Frame", nil, parent)
	header:SetPoint("TOPLEFT", PAD, -PAD)
	header:SetPoint("TOPRIGHT", -PAD, -PAD)
	header:SetHeight(94)

	local logo = header:CreateTexture(nil, "ARTWORK")
	logo:SetSize(56, 56)
	logo:SetPoint("TOPLEFT", 0, 0)
	logo:SetTexture("Interface\\AddOns\\WorthRemembering\\Media\\PortraitIcon.png")

	local title = Skin.Text(header, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -2)
	title:SetText("Worth Remembering")
	local titleFont, titleSize, titleFlags = title:GetFont()
	titleSize = titleSize + 2
	title:SetFont(titleFont, titleSize, titleFlags)

	local version = Skin.Text(header, "ARTWORK", "GameFontHighlightSmall")
	version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	version:SetText("Version " .. tostring(ns.GetAddonVersion()))

	local patchCheck = ns.CreateSmallCheckbox(header, 24, ns.GetSettings().showPatchNotesOnUpdate,
		function(checked) ns.GetSettings().showPatchNotesOnUpdate = checked end)
	patchCheck:SetPoint("TOPLEFT", version, "BOTTOMLEFT", -4, -4)
	local patchCheckLabel = Skin.Text(header, "ARTWORK", "GameFontHighlightSmall")
	patchCheckLabel:SetPoint("LEFT", patchCheck, "RIGHT", 2, 0)
	patchCheckLabel:SetText("Show patch notes for new versions")
	ns.RegisterTourTarget("about.patchNotes", { patchCheck, patchCheckLabel })
	ns.AttachTooltip(patchCheck, "Opens this tab once after Worth Remembering updates to a new version.")

	local tourButton = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
	tourButton:SetSize(120, 20)
	Skin.Button(tourButton)
	tourButton:SetPoint("LEFT", patchCheckLabel, "RIGHT", 16, 0)
	tourButton:SetText("Take the Tour")
	tourButton:SetScript("OnClick", function() ns.StartTour("basics") end)
	ns.AttachHookTooltip(tourButton, "A quick walk through the basics, about two minutes.")

	local settingsTourButton = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
	settingsTourButton:SetSize(120, 20)
	Skin.Button(settingsTourButton)
	settingsTourButton:SetPoint("LEFT", tourButton, "RIGHT", 6, 0)
	settingsTourButton:SetText("Settings Tour")
	settingsTourButton:SetScript("OnClick", function() ns.StartTour("settings") end)
	ns.AttachHookTooltip(settingsTourButton, "A walk through the Options pages and the settings worth knowing about.")
	ns.RegisterTourTarget("about.tours", { tourButton, settingsTourButton })

	-- wraps to whatever width the window allows; everything below anchors to its bottom
	-- so a narrow window just pushes the patch notes down
	local welcome = Skin.Text(header, "ARTWORK", "GameFontHighlight")
	welcome:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -12)
	welcome:SetPoint("RIGHT", header, "RIGHT", 0, 0)
	welcome:SetJustifyH("LEFT")
	welcome:SetWordWrap(true)
	welcome:SetSpacing(3)
	welcome:SetText("Thank you so much for trying Worth Remembering!\n"
		.. "Every feature can be turned on or off, and most are highly customizable. Make it yours.\n"
		.. "Please feel very free to share any feedback, bug reports, feature requests, etc with me, I'd love to hear from you.")

	local patchNotesLabel = Skin.Text(header, "ARTWORK", "GameFontNormalSmall")
	patchNotesLabel:SetPoint("TOPLEFT", welcome, "BOTTOMLEFT", 0, -14)
	patchNotesLabel:SetText("Patch Notes")
	local font, _, flags = patchNotesLabel:GetFont()
	patchNotesLabel:SetFont(font, titleSize - 2, flags)

	-- right-aligned contact block. the values are read-only edit boxes so they can be
	-- selected and copied, a plain FontString can't be
	local contactHeading = Skin.Text(header, "ARTWORK", "GameFontNormalSmall")
	contactHeading:SetPoint("TOPRIGHT", 0, -2)
	contactHeading:SetJustifyH("RIGHT")
	contactHeading:SetText("For feedback, bug reports, feature requests, etc:")

	-- boxes exactly one text line tall, so every row sits the same distance apart
	local lineHeight = math.ceil(contactHeading:GetStringHeight())

	local contactWidth = contactHeading:GetStringWidth()
	local function addContactLine(anchor, label, value)
		local measure = Skin.Text(header, "ARTWORK", "GameFontHighlightSmall")
		measure:SetText(value)
		local width = math.ceil(measure:GetStringWidth()) + 4
		measure:Hide()

		local valueBox = CreateFrame("EditBox", nil, header)
		Skin.SetFont(valueBox, "GameFontHighlightSmall")
		valueBox:SetAutoFocus(false)
		valueBox:SetJustifyH("RIGHT")
		valueBox:SetSize(width, lineHeight)
		valueBox:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, -3)
		valueBox:SetText(value)
		valueBox:SetCursorPosition(0)
		valueBox:SetScript("OnTextChanged", function(self, userInput)
			if userInput then
				self:SetText(value)
				self:HighlightText()
			end
		end)
		valueBox:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
		valueBox:SetScript("OnEditFocusLost", function(self) self:HighlightText(0, 0) end)
		valueBox:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
		valueBox:SetScript("OnEnterPressed", function(self) self:ClearFocus() end)
		ns.AttachTooltip(valueBox, "Click, then Ctrl+C to copy.")

		local labelText = Skin.Text(header, "ARTWORK", "GameFontNormalSmall")
		labelText:SetPoint("RIGHT", valueBox, "LEFT", -4, 0)
		labelText:SetText(label)
		contactWidth = math.max(contactWidth, labelText:GetStringWidth() + 4 + width)
		return valueBox
	end

	local emailBox = addContactLine(contactHeading, "Email:", "worthremembering.stark087@passmail.net")
	local discordBox = addContactLine(emailBox, "Discord:", "maliceftw")

	local contactArea = CreateFrame("Frame", nil, header)
	contactArea:SetPoint("TOPRIGHT", contactHeading, "TOPRIGHT")
	contactArea:SetPoint("BOTTOM", discordBox, "BOTTOM")
	contactArea:SetWidth(contactWidth)
	ns.RegisterTourTarget("about.contact", contactArea)

	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")

	ns.SetGentleScroll(scroll)
	scroll:SetPoint("TOPLEFT", patchNotesLabel, "BOTTOMLEFT", 0, -6)
	scroll:SetPoint("BOTTOMRIGHT", -(PAD + 22), PAD)
	Skin.ScrollBar(scroll)

	scrollChild = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(scrollChild)
	scroll:SetScript("OnSizeChanged", function(self, width)
		scrollChild:SetWidth(width)
		layout()
	end)
	scrollChild:SetWidth(scroll:GetWidth())

	layout()
end
