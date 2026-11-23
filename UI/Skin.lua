local ns = WorthRemembering

-- Optional looks: "dark", built in, or "ellesmere", through EllesmereUI's skinning API
-- (EllesmereUI/SKINNING_API.md), falling back to dark when EUI can't skin.
-- Every painter returns false under the default look, so the caller draws the stock one.
-- A chosen font is separate from the look, and also applies under the default one.
--
-- EUI's Shell, Panel and Button fade all textures sitting directly on their frame, again
-- on every call and whenever EUI re-strips a window. Art that must stay goes on a child.

local Skin = {}
ns.Skin = Skin

local GOLD_R, GOLD_G, GOLD_B = 1, 0.82, 0
local WHITE8 = "Interface\\Buttons\\WHITE8X8"
local LINE_ALPHA, HOVER_ALPHA = 0.1, 0.06
local TRACK_ALPHA, FILL_ALPHA = 0.16, 0.75
local TOP_BAR_HEIGHT = 25

-- tuned to EUI's own menu; its API's surfaces match its darker Blizzard windows
local LIFT_ALPHA, TAB_LIFT_ALPHA = 0.04, 0.05
local BAND_ALPHA, STRIP_ALPHA = 0.25, 0.2
local SURFACE = { 0.110, 0.103, 0.098, 1 }
local PANELS = {
	section = { 0, 0, 0, 0.15 },
	field = { 0.066, 0.060, 0.055, 0.9 },
	float = SURFACE,
}
local BORDER = { 0.2, 0.2, 0.2, 1 }
local INPUT = { 0.066, 0.060, 0.055, 1 }
local BOX = { 0.112, 0.105, 0.098, 1 }
local DROPDOWN = { 0.103, 0.095, 0.088, 0.9 }
local BUTTON = { 0.08, 0.08, 0.08, 0.92 }
local TAB_PLATE = { 0.068, 0.056, 0.052, 1 }
local TOGGLE_OFF = { 0.267, 0.267, 0.267, 0.65 }
local TOGGLE_ON_ALPHA = 0.7
-- ours, antialiased; Blizzard's round mask has a hard edge
local CIRCLE = { file = "Interface\\AddOns\\" .. ns.name .. "\\Media\\Circle.png" }
local TOGGLE_WIDTH, TOGGLE_HEIGHT = 26, 14

local EUI_MEDIA = "Interface\\AddOns\\EllesmereUI\\media\\"
local EUI_ART = {
	circle = CIRCLE,
	sortDown = { file = EUI_MEDIA .. "icons\\eui-arrow-down3.png" },
	sortUp = { file = EUI_MEDIA .. "icons\\eui-arrow-up3.png" },
	chevron = { file = EUI_MEDIA .. "icons\\eui-arrow-down3.png", size = 11 },
	grip = { file = EUI_MEDIA .. "icons\\resize_element.png" },
}
-- Blizzard's own art only
local DARK_ART = {
	circle = CIRCLE,
	sortDown = { file = "Interface/Buttons/Arrow-Down-Up", desaturate = true },
	sortUp = { file = "Interface/Buttons/Arrow-Up-Up", desaturate = true },
	chevron = { atlas = "minimal-scrollbar-arrow-bottom", desaturate = true, width = 12, height = 8 },
	grip = { file = "Interface/ChatFrame/UI-ChatIM-SizeGrabber-Up", desaturate = true },
}

local function setArt(tex, art)
	if art.atlas then
		tex:SetAtlas(art.atlas)
	else
		tex:SetTexture(art.file)
	end
	if art.desaturate then
		tex:SetDesaturated(true)
	end
end

local function solid(parent, layer, color, sublevel)
	local tex = parent:CreateTexture(nil, layer, nil, sublevel)
	tex:SetAllPoints()
	tex:SetColorTexture(unpack(color))
	return tex
end

local function hairline(tex, horizontal)
	tex:SetSnapToPixelGrid(false)
	tex:SetTexelSnappingBias(0)
	if PixelUtil then
		if horizontal then
			PixelUtil.SetHeight(tex, 1)
		else
			PixelUtil.SetWidth(tex, 1)
		end
	elseif horizontal then
		tex:SetHeight(1)
	else
		tex:SetWidth(1)
	end
end

-- 1px edges on a child at the frame's level, under its text
local function addBorder(frame, color)
	local box = CreateFrame("Frame", nil, frame)
	box:SetAllPoints()
	box:SetFrameLevel(frame:GetFrameLevel())
	local edges = {
		{ "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
		{ "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false },
	}
	local lines = {}
	for i, edge in ipairs(edges) do
		local tex = box:CreateTexture(nil, "BORDER", nil, -7)
		tex:SetColorTexture(unpack(color or BORDER))
		tex:SetPoint(edge[1])
		tex:SetPoint(edge[2])
		hairline(tex, edge[3])
		lines[i] = tex
	end
	return box, lines
end

local function fadeRegions(frame)
	for _, region in ipairs({ frame:GetRegions() }) do
		if region:IsObjectType("Texture") then
			region:SetAlpha(0)
		end
	end
end

local BUTTON_ART = { "GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture" }

-- The built-in dark look, shaped like EUI's facade so the painters below serve both.
local Dark = { keepsTabLabel = true }

function Dark.GetAccentColor()
	return GOLD_R, GOLD_G, GOLD_B
end

function Dark.GetStyle()
	return "dark"
end

function Dark.OnLooksChanged() end

Dark.FadeRegions = fadeRegions

function Dark.ScrollBar() end

function Dark.Shell(frame)
	fadeRegions(frame)
	solid(frame, "BACKGROUND", SURFACE, -8)
	addBorder(frame)
end

function Dark.Panel(frame, opts)
	fadeRegions(frame)
	if not opts.noBg then
		solid(frame, "BACKGROUND", SURFACE, -6)
	end
	if not opts.noBorder then
		addBorder(frame)
	end
end

function Dark.Button(btn)
	fadeRegions(btn)
	for _, getter in ipairs(BUTTON_ART) do
		local tex = btn[getter] and btn[getter](btn)
		if tex then
			tex:SetAlpha(0)
		end
	end
	solid(btn, "BACKGROUND", BUTTON)
	addBorder(btn)
	solid(btn, "HIGHLIGHT", { 1, 1, 1, 0.1 })
end

function Dark.EditBox(box)
	fadeRegions(box)
	addBorder(box)
end

function Dark.CloseButton(btn)
	btn:SetNormalTexture("")
	btn:SetPushedTexture("")
	btn:SetHighlightTexture("")
	fadeRegions(btn)
	local x = btn:CreateTexture(nil, "OVERLAY")
	x:SetAtlas("uitools-icon-close")
	x:SetSize(14, 14)
	x:SetPoint("CENTER")
	x:SetVertexColor(1, 1, 1, 0.75)
	btn:HookScript("OnEnter", function() x:SetVertexColor(1, 1, 1, 1) end)
	btn:HookScript("OnLeave", function() x:SetVertexColor(1, 1, 1, 0.75) end)
end

local tabState = setmetatable({}, { __mode = "k" })

local function updateTab(tab)
	local state = tabState[tab]
	local selected = state.override
	if selected == nil then
		selected = not tab:IsEnabled()
	end
	state.underline:SetShown(selected)
end

-- the selected tab is the disabled one, for both PanelTemplates and our own
function Dark.Tab(tab)
	fadeRegions(tab)
	solid(tab, "BACKGROUND", TAB_PLATE)
	local underline = tab:CreateTexture(nil, "OVERLAY")
	underline:SetPoint("BOTTOMLEFT")
	underline:SetPoint("BOTTOMRIGHT")
	underline:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, 1)
	hairline(underline, true)
	tabState[tab] = { underline = underline }
	tab:SetNormalFontObject(Skin.Font(GameFontDisableSmall))
	tab:SetHighlightFontObject(Skin.Font(GameFontHighlightSmall))
	tab:SetDisabledFontObject(Skin.Font(GameFontHighlightSmall))
	tab:HookScript("OnEnable", updateTab)
	tab:HookScript("OnDisable", updateTab)
	updateTab(tab)
end

function Dark.SetTabSelection(tab, selected)
	local state = tabState[tab]
	if state then
		state.override = selected
		updateTab(tab)
	end
end

-- State

local S, art
local wanted = "default"
local wantedFont, customPath
local fontResolved = false
local registered = false
-- set once any UI asks, so a late callback can't leave it half skinned
local locked = false

local painters = setmetatable({}, { __mode = "k" })
local listeners = {}

local function active()
	if not locked then
		locked = true
		if not S and wanted ~= "default" then
			S, art = Dark, DARK_ART
		end
	end
	return S ~= nil
end
Skin.IsActive = active

function Skin.IsAvailable()
	return EllesmereUI ~= nil and type(EllesmereUI.RegisterSkin) == "function"
end

-- the look in use: "default", "dark" or "ellesmere"
function Skin.Theme()
	if not active() then
		return "default"
	end
	return S == Dark and "dark" or "ellesmere"
end

function Skin.RequestedTheme()
	return wanted
end

-- "" is the theme's own font
function Skin.RequestedFont()
	return wantedFont or ""
end

-- the game's own fonts, under LibSharedMedia's names
local BUILTIN_FONTS = {
	{ name = "Friz Quadrata TT", path = "Fonts\\FRIZQT__.TTF" },
	{ name = "Arial Narrow", path = "Fonts\\ARIALN.TTF" },
	{ name = "Skurri", path = "Fonts\\skurri.ttf" },
	{ name = "Morpheus", path = "Fonts\\MORPHEUS.ttf" },
}

-- the built-in fonts plus any other addon shared through LibSharedMedia
function Skin.ListFonts()
	local list, seen = {}, {}
	local function add(name, path)
		if name and path and not seen[name] then
			seen[name] = true
			list[#list + 1] = { name = name, path = path }
		end
	end
	for _, font in ipairs(BUILTIN_FONTS) do
		add(font.name, font.path)
	end
	local media = LibStub and LibStub("LibSharedMedia-3.0", true)
	if media then
		for _, name in ipairs(media:List("font")) do
			add(name, media:Fetch("font", name, true))
		end
	end
	table.sort(list, function(a, b) return a.name:lower() < b.name:lower() end)
	return list
end

-- resolved on first use, after every addon has registered its fonts
local function customFont()
	if not fontResolved then
		fontResolved = true
		for _, font in ipairs(wantedFont and Skin.ListFonts() or {}) do
			if font.name == wantedFont then
				customPath = font.path
			end
		end
	end
	return customPath
end

function Skin.FontMissing()
	return wantedFont ~= nil and customFont() == nil
end

local function repaint()
	local r, g, b = S.GetAccentColor()
	for region, paint in pairs(painters) do
		paint(region, r, g, b)
	end
	for _, fn in ipairs(listeners) do
		fn()
	end
end

local function followAccent(region, paint)
	painters[region] = paint
	paint(region, S.GetAccentColor())
end

-- once SavedVariables are in
function Skin.Request(theme, font)
	wanted = theme or "default"
	wantedFont = font ~= "" and font or nil
	if wanted ~= "ellesmere" or registered or not Skin.IsAvailable() then
		return
	end
	registered = true
	EllesmereUI.RegisterSkin(ns.name, function(facade)
		if locked then
			return
		end
		S, art = facade, EUI_ART
		S.OnLooksChanged(repaint)
	end)
end

function Skin.OnChanged(fn)
	listeners[#listeners + 1] = fn
end

-- stock gold under the default look; don't cache
function Skin.AccentColor()
	if active() then
		return S.GetAccentColor()
	end
	return GOLD_R, GOLD_G, GOLD_B
end

-- Flat colors. goldAlpha is the stock look.

local function paintAlpha(alpha)
	return function(tex, r, g, b)
		tex:SetColorTexture(r, g, b, alpha)
	end
end

function Skin.Accent(tex, goldAlpha)
	if active() then
		followAccent(tex, paintAlpha(goldAlpha))
	else
		tex:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, goldAlpha)
	end
end

local function whiteOr(alpha)
	return function(tex, goldAlpha)
		if active() then
			tex:SetColorTexture(1, 1, 1, alpha)
		else
			tex:SetColorTexture(GOLD_R, GOLD_G, GOLD_B, goldAlpha)
		end
	end
end
Skin.Line = whiteOr(LINE_ALPHA)
Skin.Hover = whiteOr(HOVER_ALPHA)
Skin.Track = whiteOr(TRACK_ALPHA)

-- the dark strip behind a window's title or footer
function Skin.Band(tex)
	if not active() then
		return false
	end
	tex:SetColorTexture(0, 0, 0, BAND_ALPHA)
	return true
end

function Skin.HeaderStrip(tex)
	if not active() then
		return false
	end
	tex:SetColorTexture(0, 0, 0, STRIP_ALPHA)
	return true
end

-- Text

-- gold fonts turn white; false keeps the base's color
local FONTS = {
	GameFontNormal = "GameFontHighlight",
	GameFontNormalSmall = "GameFontHighlightSmall",
	GameFontNormalLarge = "GameFontHighlightLarge",
	GameFontNormalHuge = "GameFontHighlightHuge",
	GameFontHighlight = false,
	GameFontHighlightSmall = false,
	GameFontHighlightLarge = false,
	GameFontHighlightHuge = false,
	GameFontDisable = false,
	GameFontDisableSmall = false,
	ChatFontNormal = false,
}
local ALPHABETS = { "roman", "russian", "korean", "simplifiedchinese", "traditionalchinese" }
local LOCALE_ALPHABET = {
	ruRU = "russian", koKR = "korean", zhCN = "simplifiedchinese", zhTW = "traditionalchinese",
}

local fontNames, fontCache = {}, {}
for name in pairs(FONTS) do
	if _G[name] then
		fontNames[_G[name]] = name
	end
end

-- EUI's font, with the game's own faces for alphabets it may lack
-- under EUI its flags and shadow rule, otherwise the base's
local function applyFace(font, base, name, path)
	local basePath, size, baseFlags = base:GetFont()
	local eui = active() and S.GetFont
	local flags = eui and select(2, S.GetFont()) or baseFlags or ""
	local own = LOCALE_ALPHABET[GetLocale()]
	local members = {}
	for _, alphabet in ipairs(ALPHABETS) do
		local file = path
		if alphabet ~= "roman" and alphabet ~= own then
			local ok, member = pcall(base.GetFontObjectForAlphabet, base, alphabet)
			file = ok and member and member:GetFont() or basePath
		end
		members[#members + 1] = { alphabet = alphabet, file = file, height = size, flags = flags or "" }
	end
	local ok, family = pcall(CreateFontFamily, name .. "Family", members)
	if not (ok and family and pcall(font.SetFontObject, font, family)) then
		font:SetFont(path, size, flags or "")
	end
	if eui then
		local shadow = (flags or "") == ""
		font:SetShadowColor(0, 0, 0, shadow and 1 or 0)
		font:SetShadowOffset(shadow and 1 or 0, shadow and -1 or 0)
	else
		font:SetShadowColor(base:GetShadowColor())
		font:SetShadowOffset(base:GetShadowOffset())
	end
end

local function facePath()
	return customFont() or (active() and S.GetFont and (S.GetFont()))
end

local function fontOn()
	return active() or customFont() ~= nil
end
Skin.FontOn = fontOn

-- the face in use, for text that sets its own size; nil means the stock one
function Skin.FacePath()
	return facePath()
end

-- the flat surface and border colors, for art drawn by hand
function Skin.SurfaceColor()
	return unpack(SURFACE)
end

function Skin.BorderColor()
	return unpack(BORDER)
end

-- font object or its name; gold becomes white. Unknown fonts come back as they are
function Skin.Font(font)
	if not fontOn() then
		return font
	end
	local key = fontNames[font] or font
	local white = FONTS[key]
	if white == nil or not _G[key] or (white and not _G[white]) then
		return font
	end
	local colorKey = active() and white or key
	local path = facePath()
	if not path then
		return _G[colorKey]
	end
	local cached = fontCache[key]
	if not cached then
		local base = _G[key]
		local name = ns.name .. "Skin" .. key
		cached = CreateFont(name)
		applyFace(cached, base, name, path)
		cached:SetTextColor(_G[colorKey]:GetTextColor())
		fontCache[key] = cached
	end
	return cached
end

-- for FontStrings and EditBoxes
function Skin.SetFont(text, font)
	if not fontOn() then
		text:SetFontObject(font)
		return
	end
	local justifyH, justifyV = text:GetJustifyH(), text:GetJustifyV()
	text:SetFontObject(Skin.Font(font))
	text:SetJustifyH(justifyH)
	text:SetJustifyV(justifyV)
end

function Skin.Text(parent, layer, font)
	local fs = parent:CreateFontString(nil, layer, font)
	if fontOn() then
		Skin.SetFont(fs, font)
	end
	return fs
end

function Skin.Heading(fs, r, g, b)
	if not active() then
		return false
	end
	fs:SetTextColor(r or 1, g or 1, b or 1)
	return true
end

function Skin.Section(fs)
	if not active() then
		return false
	end
	fs:SetTextColor(1, 1, 1, 0.41)
	return true
end

-- seats a title in a Window's top bar
function Skin.Title(fs, window)
	if not active() then
		return false
	end
	Skin.SetFont(fs, "GameFontHighlight")
	fs:ClearAllPoints()
	fs:SetPoint("CENTER", window, "TOP", 0, -TOP_BAR_HEIGHT / 2)
	return true
end

local accentFont

-- a font object that tracks the accent color
function Skin.AccentFont(base)
	if not active() then
		return base
	end
	if not accentFont then
		local name = ns.name .. "SkinAccentFont"
		accentFont = CreateFont(name)
		if facePath() then
			applyFace(accentFont, base, name, facePath())
		else
			accentFont:CopyFontObject(base)
		end
		followAccent(accentFont, function(font, r, g, b)
			font:SetTextColor(r, g, b)
		end)
	end
	return accentFont
end

-- Containers

local artHosts = setmetatable({}, { __mode = "k" })

-- at its parent's level, so its art sits under the parent's text but is never faded
function Skin.CreateArtHost(frame)
	if not active() then
		return frame
	end
	local host = artHosts[frame]
	if not host then
		host = CreateFrame("Frame", nil, frame)
		host:SetAllPoints()
		host:SetFrameLevel(frame:GetFrameLevel())
		artHosts[frame] = host
	end
	return host
end

-- only EUI's art is lightened; a Modern backdrop is the user's own color
local function paintLift(tex)
	tex:SetColorTexture(1, 1, 1, S.GetStyle() == "eui" and LIFT_ALPHA or 0)
end

function Skin.Window(frame)
	if not active() then
		return false
	end
	S.Shell(frame, { noTopBar = true })
	local host = Skin.CreateArtHost(frame)
	local lift = host:CreateTexture(nil, "BACKGROUND", nil, -5)
	lift:SetAllPoints()
	followAccent(lift, paintLift)
	local bar = host:CreateTexture(nil, "BACKGROUND", nil, -4)
	bar:SetPoint("TOPLEFT")
	bar:SetPoint("TOPRIGHT")
	bar:SetHeight(TOP_BAR_HEIGHT)
	Skin.Band(bar)
	return true
end

-- kind: section (inside a window), field (text area) or float (stands alone)
function Skin.Panel(frame, kind, noBorder)
	if not active() then
		return false
	end
	S.Panel(frame, { noBg = true, noBorder = noBorder })
	if not artHosts[frame] then
		solid(Skin.CreateArtHost(frame), "BACKGROUND", PANELS[kind], -6)
	end
	return true
end

-- hover wash for a Panel: a HIGHLIGHT texture on the panel itself would be faded
function Skin.Highlight(frame, goldAlpha)
	if not active() then
		return false
	end
	local wash = Skin.CreateArtHost(frame):CreateTexture(nil, "ARTWORK", nil, -8)
	wash:SetAllPoints()
	followAccent(wash, paintAlpha(goldAlpha))
	wash:Hide()
	frame:HookScript("OnEnter", function() wash:Show() end)
	frame:HookScript("OnLeave", function() wash:Hide() end)
	return true
end

-- an accent wash and edge over a button, under its label, for the caller to animate
function Skin.CreateGlow(btn)
	if not active() then
		return nil
	end
	local glow = CreateFrame("Frame", nil, btn)
	glow:SetAllPoints()
	glow:SetFrameLevel(btn:GetFrameLevel())
	local wash = glow:CreateTexture(nil, "BACKGROUND", nil, 3)
	wash:SetAllPoints()
	followAccent(wash, paintAlpha(0.35))
	local _, lines = addBorder(glow)
	for _, line in ipairs(lines) do
		line:SetDrawLayer("BORDER", 0)
		followAccent(line, paintAlpha(1))
	end
	glow:Hide()
	return glow
end

local OUTLINE = { edgeFile = WHITE8, edgeSize = 1 }

-- a border the caller can color; EUI's own can't be recolored through the API
function Skin.CreateOutline(frame)
	if not active() then
		return nil
	end
	local outline = CreateFrame("Frame", nil, frame, "BackdropTemplate")
	outline:SetAllPoints()
	outline:SetBackdrop(OUTLINE)
	outline:Hide()
	return outline
end

-- Widgets

-- font objects, since a button reapplies its own on every state change
local function buttonFonts(btn)
	btn:SetNormalFontObject(Skin.Font(GameFontNormal))
	btn:SetHighlightFontObject(Skin.Font(GameFontHighlight))
	btn:SetDisabledFontObject(Skin.Font(GameFontDisable))
end

function Skin.Button(btn)
	if not active() then
		if customFont() then
			buttonFonts(btn)
		end
		return false
	end
	S.Button(btn)
	buttonFonts(btn)
	return true
end

-- window: optional, seats the button in that Window's top bar
function Skin.CloseButton(btn, window)
	if not active() then
		return false
	end
	if btn:GetFontString() then
		btn:SetText("")
	end
	S.CloseButton(btn)
	if window then
		btn:SetSize(TOP_BAR_HEIGHT, TOP_BAR_HEIGHT)
		btn:ClearAllPoints()
		btn:SetPoint("TOPRIGHT", window, "TOPRIGHT", -2, 0)
	end
	return true
end

local function liftTab(tab)
	solid(tab, "BACKGROUND", { 1, 1, 1, TAB_LIFT_ALPHA }, 1)
end

local panelTabs = setmetatable({}, { __mode = "k" })

local function tabFonts(tab)
	tab:SetNormalFontObject(Skin.Font(GameFontNormalSmall))
	tab:SetHighlightFontObject(Skin.Font(GameFontHighlightSmall))
	tab:SetDisabledFontObject(Skin.Font(GameFontHighlightSmall))
end

-- EUI draws its own tab label, in its own font
function Skin.Tab(tab)
	if not active() then
		if customFont() then
			panelTabs[tab] = true
			tabFonts(tab)
		end
		return false
	end
	panelTabs[tab] = true
	S.Tab(tab)
	liftTab(tab)
	return true
end

local hiddenFont

-- a plain button used as a tab; the caller reports selection
function Skin.ButtonTab(btn)
	if not active() then
		return Skin.Button(btn)
	end
	if not S.SetTabSelection then
		return Skin.Button(btn)
	end
	S.FadeRegions(btn)
	S.Tab(btn)
	liftTab(btn)
	if S.keepsTabLabel then
		return true
	end
	-- EUI draws its own label over the button's
	if not hiddenFont then
		hiddenFont = CreateFont(ns.name .. "SkinHiddenFont")
		hiddenFont:CopyFontObject(GameFontHighlight)
		hiddenFont:SetTextColor(0, 0, 0, 0)
	end
	btn:SetNormalFontObject(hiddenFont)
	btn:SetHighlightFontObject(hiddenFont)
	btn:SetDisabledFontObject(hiddenFont)
	return true
end

-- PanelTemplates_SelectTab resets the selected tab's font, so call after it
function Skin.SetTabSelected(tab, selected)
	if active() and S.SetTabSelection then
		S.SetTabSelection(tab, selected)
	end
	if panelTabs[tab] and (S == nil or S.keepsTabLabel) then
		tab:SetDisabledFontObject(Skin.Font(GameFontHighlightSmall))
	end
end

function Skin.EditBox(box)
	if box.Instructions and fontOn() then
		Skin.SetFont(box, "GameFontHighlightSmall")
		Skin.SetFont(box.Instructions, "GameFontDisableSmall")
	end
	if not active() then
		return false
	end
	S.EditBox(box)
	solid(box, "BACKGROUND", INPUT, 1)
	return true
end

-- Checkboxes become EUI-style toggles: a pill track and a sliding knob. The pill's
-- pieces must not overlap, since WoW applies alpha to each one, not to the group.

local toggles = setmetatable({}, { __mode = "k" })

local function pillCap(check, left)
	local tex = check:CreateTexture(nil, "ARTWORK")
	setArt(tex, art.circle)
	tex:SetTexCoord(left and 0 or 0.5, left and 0.5 or 1, 0, 1)
	tex:SetSize(TOGGLE_HEIGHT / 2, TOGGLE_HEIGHT)
	return tex
end

local function paintToggle(check, r, g, b)
	local t = toggles[check]
	local on = check:GetChecked()
	for _, piece in ipairs(t.pieces) do
		if on then
			piece:SetVertexColor(r, g, b, TOGGLE_ON_ALPHA)
		else
			piece:SetVertexColor(unpack(TOGGLE_OFF))
		end
	end
	t.knob:SetVertexColor(1, 1, 1, on and 1 or 0.5)
	t.knob:ClearAllPoints()
	if on then
		t.knob:SetPoint("RIGHT", t.right, "RIGHT", -2, 0)
	else
		t.knob:SetPoint("LEFT", t.left, "LEFT", 2, 0)
	end
end

local function refreshToggle(check)
	paintToggle(check, S.GetAccentColor())
end

function Skin.Checkbox(check)
	if not active() then
		return false
	end
	check:SetNormalTexture("")
	check:SetPushedTexture("")
	check:SetHighlightTexture("")
	fadeRegions(check)
	check:SetWidth(TOGGLE_WIDTH)
	local left, right = pillCap(check, true), pillCap(check, false)
	left:SetPoint("LEFT")
	right:SetPoint("LEFT", TOGGLE_WIDTH - TOGGLE_HEIGHT / 2, 0)
	local middle = check:CreateTexture(nil, "ARTWORK")
	middle:SetTexture(WHITE8)
	middle:SetPoint("TOPLEFT", left, "TOPRIGHT")
	middle:SetPoint("BOTTOMRIGHT", right, "BOTTOMLEFT")
	local knob = check:CreateTexture(nil, "OVERLAY")
	setArt(knob, art.circle)
	knob:SetSize(TOGGLE_HEIGHT - 4, TOGGLE_HEIGHT - 4)
	toggles[check] = { pieces = { left, right, middle }, left = left, right = right, knob = knob }
	followAccent(check, paintToggle)
	check:HookScript("OnClick", refreshToggle)
	hooksecurefunc(check, "SetChecked", refreshToggle)
	return true
end

-- a drawn "+" or "-" in place of a button's text: crisp at any font
function Skin.Sign(btn, sign)
	if not active() then
		return false
	end
	if btn:GetFontString() then
		btn:SetText("")
	end
	local host = Skin.CreateArtHost(btn)
	local across = host:CreateTexture(nil, "OVERLAY")
	across:SetColorTexture(0.85, 0.85, 0.85, 1)
	across:SetSize(8, 2)
	across:SetPoint("CENTER")
	if sign == "+" then
		local down = host:CreateTexture(nil, "OVERLAY")
		down:SetColorTexture(0.85, 0.85, 0.85, 1)
		down:SetSize(2, 8)
		down:SetPoint("CENTER")
	end
	return true
end

-- a square tick for checkboxes too narrow for a toggle (table cells)
function Skin.Tick(check)
	if not active() then
		return false
	end
	fadeRegions(check)
	solid(check, "BACKGROUND", INPUT)
	addBorder(check, { 1, 1, 1, 0.25 })
	local mark = check:CreateTexture(nil, "OVERLAY")
	mark:SetPoint("TOPLEFT", 3, -3)
	mark:SetPoint("BOTTOMRIGHT", -3, 3)
	followAccent(mark, paintAlpha(1))
	check:SetCheckedTexture(mark)
	local highlight = check:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 1, 1, 0.08)
	check:SetHighlightTexture(highlight)
	return true
end

-- by hand: S.Dropdown has EUI's Blizzard-window look, with a gold arrow
function Skin.Dropdown(dropdown)
	if not active() then
		local text = customFont() and dropdown.Text
		if text then
			Skin.SetFont(text, "GameFontHighlight")
		end
		return false
	end
	S.FadeRegions(dropdown)
	solid(dropdown, "BACKGROUND", DROPDOWN, 0)
	S.Panel(Skin.CreateArtHost(dropdown), { noBg = true })
	solid(dropdown, "HIGHLIGHT", { 1, 1, 1, 0.05 })
	local arrow = dropdown:CreateTexture(nil, "OVERLAY")
	setArt(arrow, art.chevron)
	arrow:SetVertexColor(1, 1, 1, 0.45)
	arrow:SetSize(art.chevron.width or art.chevron.size, art.chevron.height or art.chevron.size)
	arrow:SetPoint("RIGHT", -7, 0)
	local text = dropdown.Text or dropdown:GetFontString()
	if text then
		Skin.SetFont(text, "GameFontHighlightSmall")
		text:ClearAllPoints()
		text:SetPoint("LEFT", 8, 0)
		text:SetPoint("RIGHT", -22, 0)
		text:SetJustifyH("LEFT")
	end
	if dropdown.SetupMenu then
		dropdown.menuMixin = Skin.MenuStyle()
	end
	return true
end

local STEPPERS = { "ScrollUpButton", "ScrollDownButton" }

-- S.ScrollBar only knows the newer bar; UIPanelScrollFrameTemplate still has the old Slider
function Skin.ScrollBar(scroll)
	local bar = active() and scroll.ScrollBar
	if not bar then
		return false
	end
	if bar.Track or not bar.GetThumbTexture then
		S.ScrollBar(bar)
		return true
	end
	for _, key in ipairs(STEPPERS) do
		if bar[key] then
			S.FadeRegions(bar[key])
		end
	end
	local thumb = bar:GetThumbTexture()
	if thumb then
		thumb:SetColorTexture(1, 1, 1, 0.3)
		thumb:SetSize(4, 40)
	end
	return true
end

local function paintSolid(tex, r, g, b)
	tex:SetVertexColor(r, g, b, 1)
end

function Skin.Slider(slider, track, thumb)
	if not active() then
		return false
	end
	track:SetHeight(4)
	track:SetColorTexture(1, 1, 1, TRACK_ALPHA)
	local fill = slider:CreateTexture(nil, "BORDER")
	fill:SetPoint("TOPLEFT", track, "TOPLEFT")
	fill:SetPoint("BOTTOMLEFT", track, "BOTTOMLEFT")
	fill:SetPoint("RIGHT", thumb, "CENTER")
	followAccent(fill, paintAlpha(FILL_ALPHA))
	thumb:SetSize(12, 12)
	setArt(thumb, art.circle)
	followAccent(thumb, paintSolid)
	return true
end

function Skin.SortArrow(tex, descending)
	if not active() then
		return false
	end
	setArt(tex, descending and art.sortDown or art.sortUp)
	return true
end

function Skin.ResizeGrip(btn)
	if not active() then
		return false
	end
	for _, setter in ipairs({ "SetNormalTexture", "SetPushedTexture", "SetHighlightTexture" }) do
		btn[setter](btn, art.grip.file)
	end
	if art.grip.desaturate then
		btn:GetNormalTexture():SetDesaturated(true)
		btn:GetPushedTexture():SetDesaturated(true)
		btn:GetHighlightTexture():SetDesaturated(true)
	end
	btn:GetNormalTexture():SetAlpha(0.5)
	return true
end

-- Menus, through Blizzard's menu style and element initializer hooks. Pooled menu
-- pieces are reset by Blizzard on release, so nothing leaks into other menus.

local MENU_INSET = { left = 6, top = 6, right = 6, bottom = 6 }
local MENU_PADDING = { width = 20, height = 0 }
local menuStyle

function Skin.MenuStyle()
	if not (active() and MenuStyleMixin) then
		return nil
	end
	if not menuStyle then
		menuStyle = CreateFromMixins(MenuStyleMixin)
		function menuStyle:Generate()
			local bg = self:AttachTexture()
			bg:SetAllPoints()
			bg:SetColorTexture(unpack(SURFACE))
			bg:SetDrawLayer("BACKGROUND", -8)
			for _, edge in ipairs({ { "TOPLEFT", "TOPRIGHT", true }, { "BOTTOMLEFT", "BOTTOMRIGHT", true },
				{ "TOPLEFT", "BOTTOMLEFT", false }, { "TOPRIGHT", "BOTTOMRIGHT", false } }) do
				local line = self:AttachTexture()
				line:SetColorTexture(unpack(BORDER))
				line:SetDrawLayer("BACKGROUND", -7)
				line:SetPoint(edge[1])
				line:SetPoint(edge[2])
				if edge[3] then
					line:SetHeight(1)
				else
					line:SetWidth(1)
				end
			end
		end
		function menuStyle:GetInset()
			return MENU_INSET
		end
		function menuStyle:GetChildExtentPadding()
			return MENU_PADDING
		end
	end
	return menuStyle
end

local MARK_SIZE, MARK_INNER, MARK_FILL = 12, 10, 8
local previews = setmetatable({}, { __mode = "k" })
local previewFonts = {}

local function previewFont(path)
	local font = previewFonts[path]
	if not font then
		font = CreateFont(ns.name .. "FontPreview" .. (#previewFonts + 1))
		font:CopyFontObject(GameFontHighlight)
		local _, size = GameFontHighlight:GetFont()
		font:SetFont(path, size, "")
		previewFonts[path] = font
		previewFonts[#previewFonts + 1] = font
	end
	return font
end

local function showPreview(button, description)
	local fs = button.fontString
	if fs then
		fs:SetFontObject(previewFont(previews[description]))
		fs:SetTextToFit(fs:GetText())
	end
end

-- a menu entry drawn in the font it names, under every look
function Skin.PreviewMenuFont(description, path)
	previews[description] = path
	description:AddInitializer(showPreview)
end

local function shape(tex, round, size, color, sublevel)
	if round then
		setArt(tex, art.circle)
		tex:SetVertexColor(unpack(color))
	else
		tex:SetColorTexture(unpack(color))
	end
	tex:SetSize(size, size)
	tex:SetDrawLayer("ARTWORK", sublevel)
end

local function styleElement(button, description)
	local fs = not previews[description] and button.fontString
	if fs then
		local r, g, b, a = fs:GetTextColor()
		fs:SetFontObject(Skin.Font(GameFontHighlight))
		fs:SetTextColor(r, g, b, a)
		if not button:IsObjectType("Button") then
			fs:SetAlpha(0.5)
		end
		fs:SetTextToFit(fs:GetText())
	end
	if button.highlight then
		button.highlight:SetColorTexture(1, 1, 1, 0.08)
	end
	local box = button.leftTexture1
	if not box then
		return
	end
	local round = (box:GetAtlas() or ""):find("radial") ~= nil
	shape(box, round, MARK_SIZE, { 1, 1, 1, 0.25 }, 4)
	local inner = button:AttachTexture()
	shape(inner, round, MARK_INNER, BOX, 5)
	inner:SetPoint("CENTER", box, "CENTER")
	local mark = button.leftTexture2
	if mark then
		shape(mark, round, round and 6 or MARK_FILL, { S.GetAccentColor() }, 6)
		mark:ClearAllPoints()
		mark:SetPoint("CENTER", box, "CENTER")
	end
end

local function styleDescriptions(description)
	for _, element in description:EnumerateElementDescriptions() do
		element:AddInitializer(styleElement)
		styleDescriptions(element)
	end
end

-- end of a menu generator
function Skin.StyleMenu(rootDescription)
	if active() and MenuStyleMixin then
		styleDescriptions(rootDescription)
	end
end

-- MenuUtil.CreateContextMenu with the style passed in, not written onto the owner
function Skin.ContextMenu(owner, generator)
	local style = Skin.MenuStyle()
	if not (style and Menu and Menu.PopulateDescription) then
		return MenuUtil.CreateContextMenu(owner, generator)
	end
	local root = MenuUtil.CreateRootMenuDescription(style)
	Menu.PopulateDescription(function(o, r, ...)
		generator(o, r, ...)
		styleDescriptions(r)
	end, owner, root)
	local menu = Menu.GetManager():OpenContextMenu(owner, root)
	if menu then
		PlaySound(SOUNDKIT.IG_MAINMENU_OPTION_CHECKBOX_ON)
	end
	return menu
end
