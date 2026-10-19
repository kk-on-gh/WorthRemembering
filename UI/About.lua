local ns = WorthRemembering

-- index -> expanded bool. only the most recent version starts expanded.
local expanded = { [1] = true }

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

	local header = CreateFrame("Frame", nil, parent)
	header:SetPoint("TOPLEFT", PAD, -PAD)
	header:SetPoint("TOPRIGHT", -PAD, -PAD)
	header:SetHeight(64)

	local logo = header:CreateTexture(nil, "ARTWORK")
	logo:SetSize(56, 56)
	logo:SetPoint("LEFT", 0, 0)
	logo:SetTexture("Interface\\AddOns\\WorthRemembering\\Media\\PortraitIcon.png")

	local title = header:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", logo, "TOPRIGHT", 14, -2)
	title:SetText("Worth Remembering")

	local currentVersion = (GetAddOnMetadata and GetAddOnMetadata(ns.name, "Version"))
		or (C_AddOns and C_AddOns.GetAddOnMetadata and C_AddOns.GetAddOnMetadata(ns.name, "Version"))
		or ns.CHANGELOG[1] and ns.CHANGELOG[1].version
	local version = header:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	version:SetPoint("TOPLEFT", title, "BOTTOMLEFT", 0, -6)
	version:SetText("Version " .. tostring(currentVersion))

	local patchNotesLabel = header:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	patchNotesLabel:SetPoint("TOPLEFT", version, "BOTTOMLEFT", 0, -10)
	patchNotesLabel:SetText("Patch Notes")

	local scroll = CreateFrame("ScrollFrame", nil, parent, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, -8)
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
