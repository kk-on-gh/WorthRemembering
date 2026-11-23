local ns = WorthRemembering
local Skin = ns.Skin

-- Stand-in for Blizzard's ColorPickerFrame under a theme, built on the same ColorSelect
-- widget. The stock look keeps Blizzard's.

local PICKER_BUTTONS = "Interface\\Buttons\\UI-ColorPicker-Buttons"
local PAD = 16
local TOP = 40
local WHEEL_SIZE = 140
local PREVIEW_W, PREVIEW_H = 64, 40

local picker
local onChange, onCancel
local committed = false
local original = {}

local function toHex(r, g, b)
	return ("%02X%02X%02X"):format(math.floor(r * 255 + 0.5), math.floor(g * 255 + 0.5), math.floor(b * 255 + 0.5))
end

local function build()
	picker = CreateFrame("Frame", "WRColorPicker", UIParent)
	tinsert(UISpecialFrames, "WRColorPicker")
	picker:SetSize(312, 240)
	picker:SetFrameStrata("FULLSCREEN_DIALOG")
	picker:SetToplevel(true)
	picker:SetClampedToScreen(true)
	ns.MakePopupDraggable(picker, "colorPicker")
	Skin.Window(picker)
	local art = Skin.CreateArtHost(picker)

	local title = Skin.Text(picker, "ARTWORK", "GameFontNormalLarge")
	title:SetText("Color Picker")
	Skin.Title(title, picker)

	local close = CreateFrame("Button", nil, picker, "UIPanelCloseButton")
	close:SetScript("OnClick", function() picker:Hide() end)
	Skin.CloseButton(close, picker)

	local select = CreateFrame("ColorSelect", nil, picker)
	select:SetPoint("TOPLEFT", PAD, -TOP)
	select:SetSize(WHEEL_SIZE + 46, WHEEL_SIZE)

	local wheel = select:CreateTexture(nil, "ARTWORK")
	wheel:SetSize(WHEEL_SIZE, WHEEL_SIZE)
	wheel:SetPoint("TOPLEFT")
	select:SetColorWheelTexture(wheel)
	local wheelThumb = select:CreateTexture(nil, "OVERLAY")
	wheelThumb:SetTexture(PICKER_BUTTONS)
	wheelThumb:SetTexCoord(0, 0.15625, 0, 0.625)
	wheelThumb:SetSize(10, 10)
	select:SetColorWheelThumbTexture(wheelThumb)

	local value = select:CreateTexture(nil, "ARTWORK")
	value:SetSize(20, WHEEL_SIZE)
	value:SetPoint("LEFT", wheel, "RIGHT", 22, 0)
	select:SetColorValueTexture(value)
	local valueThumb = select:CreateTexture(nil, "OVERLAY")
	valueThumb:SetTexture(PICKER_BUTTONS)
	valueThumb:SetTexCoord(0.25, 1, 0, 0.875)
	valueThumb:SetSize(40, 12)
	select:SetColorValueThumbTexture(valueThumb)

	local newLabel = Skin.Text(picker, "ARTWORK", "GameFontDisableSmall")
	newLabel:SetPoint("TOPRIGHT", -PAD, -TOP)
	newLabel:SetText("New")
	local current = art:CreateTexture(nil, "ARTWORK")
	current:SetSize(PREVIEW_W, PREVIEW_H)
	current:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -PAD, -TOP - 14)

	local oldLabel = Skin.Text(picker, "ARTWORK", "GameFontDisableSmall")
	oldLabel:SetPoint("TOPRIGHT", -PAD, -TOP - 14 - PREVIEW_H - 8)
	oldLabel:SetText("Old")
	local previous = art:CreateTexture(nil, "ARTWORK")
	previous:SetSize(PREVIEW_W, PREVIEW_H / 2)
	previous:SetPoint("TOPRIGHT", picker, "TOPRIGHT", -PAD, -TOP - 14 - PREVIEW_H - 22)
	local revert = CreateFrame("Button", nil, picker)
	revert:SetAllPoints(previous)
	revert:SetScript("OnClick", function() select:SetColorRGB(original.r, original.g, original.b) end)
	ns.AttachTooltip(revert, "Back to the old color.")

	local hexBox = ns.CreateSmallEditBox(picker, PREVIEW_W, 20)
	hexBox:SetPoint("TOPRIGHT", -PAD, -TOP - WHEEL_SIZE + 20)
	hexBox:SetMaxLetters(6)
	local hash = Skin.Text(picker, "ARTWORK", "GameFontDisableSmall")
	hash:SetPoint("RIGHT", hexBox, "LEFT", -4, 0)
	hash:SetText("#")
	local function applyHex(self)
		local text = self:GetText():gsub("[^%x]", "")
		if #text == 6 then
			select:SetColorRGB(tonumber(text:sub(1, 2), 16) / 255, tonumber(text:sub(3, 4), 16) / 255,
				tonumber(text:sub(5, 6), 16) / 255)
		end
		self:SetText(toHex(select:GetColorRGB()))
		self:ClearFocus()
	end
	hexBox:SetScript("OnEnterPressed", applyHex)
	hexBox:SetScript("OnEscapePressed", function(self)
		self:SetText(toHex(select:GetColorRGB()))
		self:ClearFocus()
	end)

	select:SetScript("OnColorSelect", function(_, r, g, b)
		current:SetColorTexture(r, g, b)
		if not hexBox:HasFocus() then
			hexBox:SetText(toHex(r, g, b))
		end
		if onChange then
			onChange(r, g, b)
		end
	end)

	local okay = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
	okay:SetSize(130, 24)
	okay:SetPoint("BOTTOMLEFT", PAD, 14)
	okay:SetText("Okay")
	okay:SetScript("OnClick", function()
		committed = true
		picker:Hide()
	end)
	Skin.Button(okay)

	local cancel = CreateFrame("Button", nil, picker, "UIPanelButtonTemplate")
	cancel:SetSize(130, 24)
	cancel:SetPoint("BOTTOMRIGHT", -PAD, 14)
	cancel:SetText("Cancel")
	cancel:SetScript("OnClick", function() picker:Hide() end)
	Skin.Button(cancel)

	picker:SetScript("OnHide", function()
		local cancelled = not committed and onCancel
		onChange, onCancel = nil, nil
		if cancelled then
			cancelled()
		end
	end)

	picker.select, picker.previous, picker.hexBox = select, previous, hexBox
end

-- onChange(r, g, b) runs live while picking; onCancel() when closed without Okay.
-- false under the stock look, for the caller to open Blizzard's picker instead
function ns.ShowColorPicker(r, g, b, change, cancel)
	if not Skin.IsActive() then
		return false
	end
	if not picker then
		build()
	end
	if picker:IsShown() then
		picker:Hide()
	end
	original.r, original.g, original.b = r, g, b
	committed = false
	picker:SetScale(ns.GetSettings().uiScale)
	ns.RestorePopupPosition(picker, "colorPicker")
	picker.previous:SetColorTexture(r, g, b)
	picker.select:SetColorRGB(r, g, b)
	picker.hexBox:SetText(toHex(r, g, b))
	onChange, onCancel = change, cancel
	picker:Show()
	return true
end
