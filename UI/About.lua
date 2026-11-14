local ns = WorthRemembering

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

local function addVersionBlock(index, entry, y)
	local header = CreateFrame("Button", nil, scrollChild)
	header:SetPoint("TOPLEFT", 0, y)
	header:SetPoint("RIGHT", -4, 0)
	header:SetHeight(20)

	local headerText = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
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

	-- optional plain paragraphs before the sections, no bullet
	if entry.intro then
		for _, paragraph in ipairs(entry.intro) do
			local fs = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
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
			local sectionLabel = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
			sectionLabel:SetPoint("TOPLEFT", 16, y)
			sectionLabel:SetTextColor(1, 0.82, 0)
			sectionLabel:SetText(section.heading)
			y = y - 16
		end

		for _, item in ipairs(section.items) do
			local fs = scrollChild:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
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

	local header = CreateFrame("Frame", nil, parent)
	header:SetPoint("TOPLEFT", PAD, -PAD)
	header:SetPoint("TOPRIGHT", -PAD, -PAD)
	header:SetHeight(94)

	local logo = header:CreateTexture(nil, "ARTWORK")
	logo:SetSize(56, 56)
	logo:SetPoint("TOPLEFT", 0, 0)
	logo:SetTexture("Interface\\AddOns\\WorthRemembering\\Media\\PortraitIcon.png")

	local title = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -2)
	title:SetText("Worth Remembering")
	local titleFont, titleSize, titleFlags = title:GetFont()
	titleSize = titleSize + 2
	title:SetFont(titleFont, titleSize, titleFlags)

	local version = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	version:SetText("Version " .. tostring(ns.GetAddonVersion()))

	local patchCheck = ns.CreateSmallCheckbox(header, 24, ns.GetSettings().showPatchNotesOnUpdate,
		function(checked) ns.GetSettings().showPatchNotesOnUpdate = checked end)
	patchCheck:SetPoint("TOPLEFT", version, "BOTTOMLEFT", -4, -4)
	local patchCheckLabel = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	patchCheckLabel:SetPoint("LEFT", patchCheck, "RIGHT", 2, 0)
	patchCheckLabel:SetText("Show patch notes for new versions")
	ns.AttachTooltip(patchCheck, "Opens this tab once after Worth Remembering updates to a new version.")

	local tourButton = CreateFrame("Button", nil, header, "UIPanelButtonTemplate")
	tourButton:SetSize(120, 20)
	tourButton:SetPoint("LEFT", patchCheckLabel, "RIGHT", 16, 0)
	tourButton:SetText("Take the Tour")
	tourButton:SetScript("OnClick", function() ns.StartTour("basics") end)
	ns.AttachHookTooltip(tourButton, "A quick walk through the basics, about two minutes.")

	-- wraps to whatever width the window allows; everything below anchors to its bottom
	-- so a narrow window just pushes the patch notes down
	local welcome = header:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	welcome:SetPoint("TOPLEFT", logo, "BOTTOMLEFT", 0, -12)
	welcome:SetPoint("RIGHT", header, "RIGHT", 0, 0)
	welcome:SetJustifyH("LEFT")
	welcome:SetWordWrap(true)
	welcome:SetSpacing(3)
	welcome:SetText("Thank you so much for trying Worth Remembering!\n"
		.. "Every feature can be turned on or off, and most are highly customizable. Make it yours.\n"
		.. "Please feel very free to share any feedback, bug reports, feature requests, etc with me, I'd love to hear from you.")

	local patchNotesLabel = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	patchNotesLabel:SetPoint("TOPLEFT", welcome, "BOTTOMLEFT", 0, -14)
	patchNotesLabel:SetText("Patch Notes")
	local font, _, flags = patchNotesLabel:GetFont()
	patchNotesLabel:SetFont(font, titleSize - 2, flags)

	-- right-aligned contact block. the values are read-only edit boxes so they can be
	-- selected and copied, a plain FontString can't be
	local contactHeading = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	contactHeading:SetPoint("TOPRIGHT", 0, -2)
	contactHeading:SetJustifyH("RIGHT")
	contactHeading:SetText("For feedback, bug reports, feature requests, etc:")

	-- boxes exactly one text line tall, so every row sits the same distance apart
	local lineHeight = math.ceil(contactHeading:GetStringHeight())

	local function addContactLine(anchor, label, value)
		local measure = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		measure:SetText(value)
		local width = math.ceil(measure:GetStringWidth()) + 4
		measure:Hide()

		local valueBox = CreateFrame("EditBox", nil, header)
		valueBox:SetFontObject("GameFontHighlightSmall")
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

		local labelText = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
		labelText:SetPoint("RIGHT", valueBox, "LEFT", -4, 0)
		labelText:SetText(label)
		return valueBox
	end

	local emailBox = addContactLine(contactHeading, "Email:", "worthremembering.stark087@passmail.net")
	addContactLine(emailBox, "Discord:", "maliceftw")

	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")

	ns.SetGentleScroll(scroll)
	scroll:SetPoint("TOPLEFT", patchNotesLabel, "BOTTOMLEFT", 0, -6)
	scroll:SetPoint("BOTTOMRIGHT", -(PAD + 22), PAD)

	scrollChild = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(scrollChild)
	scroll:SetScript("OnSizeChanged", function(self, width)
		scrollChild:SetWidth(width)
		layout()
	end)
	scrollChild:SetWidth(scroll:GetWidth())

	layout()
end
