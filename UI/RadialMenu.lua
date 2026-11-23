local ns = WorthRemembering
local Skin = ns.Skin

-- Holding the Quick Note keybind opens a radial picker of your quick-add presets at the
-- cursor; releasing without moving (a tap) falls through to the normal QuickNoteTarget
-- behavior instead. Tap/drag is detected by cursor distance from the keydown point versus
-- the deadzone radius, not hold duration: a secure button opens on keydown and records the
-- cursor position, keyup re-reads the cursor and compares. Needs SecureActionButtonTemplate
-- + an override binding, since a plain Bindings.xml action only fires once on keydown with
-- no access to the key-up moment.
--
-- A second (negative) radial opens the same way, held with an extra modifier
-- (radialMenu.secondModifier). That's a second override binding on "<MODIFIER>-<key>"
-- pointing at a second secure button, not a live modifier check inside the secure
-- snippet: modifier state isn't readable there either (same restricted-environment
-- limit as UnitExists/UnitIsPlayer, confirmed live), so each ring gets baked into its
-- own binding ahead of time instead, same as RL_RadialMenu's own rings.

local DEADZONE = 23 -- px, UIParent-space
-- list style: rows start this far below where the key went down, picked by how far the
-- cursor moved down; sideways drift doesn't matter
local LIST_TOP = DEADZONE + 1
local LIST_ROW = 24

-- a wheel with too many slices gets hard to aim, dual-mode selections are capped here.
-- exported so the Options tab's dropdown can enforce the same limit
ns.MAX_RADIAL_PRESETS = 8
local MAX_RADIAL_PRESETS = ns.MAX_RADIAL_PRESETS

-- effective preset list for ring 1 or 2. an explicit stored selection (Options -> Radial
-- Menu) always wins, however it was created, whether or not the second radial is
-- currently enabled: that's what lets the dropdown actually control what shows, instead
-- of a selection going inert whenever only one radial is active. with no explicit
-- selection yet, falls back to a smart default: single-radial mode shows everything
-- (nothing to split between yet), dual-radial mode splits by delta sign (positive ->
-- ring 1, negative -> ring 2; zero/no-delta presets go to neither). capped to
-- MAX_RADIAL_PRESETS either way, except the single-radial "everything" default, which
-- has nothing to cap against until the user actually picks a subset.
-- settings field holding a ring's saved selection for the current split mode
function ns.RadialLabelsKey(ringIndex)
	local suffix = ns.GetSettings().radialMenu.splitMode == "all" and "All" or ""
	return "radial" .. ringIndex .. "Labels" .. suffix
end

-- whether a radial is limited to presets of one sign right now
function ns.IsRadialSignSplit()
	local radial = ns.GetSettings().radialMenu
	return radial.secondEnabled and radial.splitMode ~= "all"
end

function ns.GetRadialPresetSet(ringIndex)
	local settings = ns.GetSettings()
	local radial = settings.radialMenu
	-- the quick-add popup's own "show preset buttons" checkbox doesn't apply here
	local allItems = settings.quickPresets.items or {}

	local explicit = radial[ns.RadialLabelsKey(ringIndex)]
	-- a stored selection can predate the second radial being enabled (single-radial mode
	-- doesn't care about sign), or predate a preset's delta being edited since, so dual
	-- mode re-checks sign here too instead of trusting it was saved correctly: without
	-- this, a leftover wrong-sign label still counts toward the ring's list and shows up
	-- on its wheel even though the (now sign-filtered) dropdown no longer offers it
	local function signOk(delta)
		if not ns.IsRadialSignSplit() then return true end
		return (ringIndex == 1 and delta > 0) or (ringIndex == 2 and delta < 0)
	end

	if explicit then
		local wanted = {}
		for _, label in ipairs(explicit) do
			wanted[label] = true
		end
		local list = {}
		for _, preset in ipairs(allItems) do
			if wanted[preset.label] and signOk(preset.delta or 0) and #list < MAX_RADIAL_PRESETS then
				list[#list + 1] = preset
			end
		end
		return list
	end

	if not radial.secondEnabled then
		return ringIndex == 1 and allItems or {}
	end

	-- Everything mode has no sign to split by, so radial 2 starts empty until picked
	if radial.splitMode == "all" and ringIndex == 2 then
		return {}
	end

	local list = {}
	for _, preset in ipairs(allItems) do
		if signOk(preset.delta or 0) and #list < MAX_RADIAL_PRESETS then
			list[#list + 1] = preset
		end
	end
	return list
end

local Controller = CreateFrame("Frame", "WRRadialController", UIParent, "SecureHandlerBaseTemplate")

-- sized to the whole screen so GetMousePosition returns normalized 0..1 coords,
-- converted to UIParent-space pixels without manual effective-scale math
local Screen = CreateFrame("Frame", "WRRadialScreen", UIParent, "SecureFrameTemplate")
Screen:SetAllPoints(UIParent)

local function createRingButton(ring)
	local button = CreateFrame("Button", "WRRadialRingButton" .. ring, UIParent, "SecureActionButtonTemplate")
	button:SetSize(1, 1)
	button:EnableMouse(false)
	button:RegisterForClicks("AnyDown", "AnyUp")
	button:SetAttribute("useOnKeyDown", false)
	button:SetAttribute("wr-ring", ring)
	return button
end

local RingButton1 = createRingButton(1)
local RingButton2 = createRingButton(2)
local RingButtons = { RingButton1, RingButton2 }

-- RING_ACTIVE/START_X/START_Y are restricted-environment globals, shared between the
-- keydown and keyup firings of this same snippet (SecureHandlerWrapScript gives every
-- button wrapped by the same owner one shared environment). `self` is whichever button
-- (ring 1 or 2) actually fired, so this one snippet, shared between both, always acts
-- on the right ring's own attributes.
local PRE_CLICK = ([[
	local screen = owner:GetFrameRef("screen")
	local ring = self:GetAttribute("wr-ring")

	if down then
		-- UnitExists/UnitIsPlayer/IsControlKeyDown and friends aren't callable from this
		-- restricted environment (confirmed live), only self:GetAttribute, frame
		-- methods, GetFrameRef, math, and CallMethod are. target/modifier validity is
		-- resolved on the insecure side instead (each ring's own binding already
		-- encodes its modifier), this only gates on whether there's anything to show.
		local count = self:GetAttribute("wr-count") or 0
		-- wr-showempty: an empty second radial still opens (with a hint) instead of
		-- turning the hold into a tap, see OnOpen
		if count == 0 and not self:GetAttribute("wr-showempty") then
			RING_ACTIVE = nil
			-- "immediate": fires right at keydown, before OnOpen (below) ever runs for
			-- this press, so there's no captured identity from it to reuse yet -- see
			-- Controller:OnTap
			owner:CallMethod("OnTap", ring, true)
			return false
		end

		local x, y = screen:GetMousePosition()
		if not x then
			-- GetMousePosition can occasionally return nothing (e.g. right at a
			-- loading-screen transition). Previously this just silently dropped the
			-- whole keypress: RING_ACTIVE never got set, so the matching keyup didn't
			-- recognize it as this ring's press either, and nothing happened at all
			-- until the next attempt. Falls back to a plain tap instead of trying to
			-- track a drag with no valid starting position to measure against.
			RING_ACTIVE = nil
			owner:CallMethod("OnTap", ring, true)
			return false
		end
		START_X, START_Y = x * screen:GetWidth(), y * screen:GetHeight()
		RING_ACTIVE = ring
		-- OnOpen flips this once the wheel actually becomes visible (see REVEAL_DELAY):
		-- past that point a release in the deadzone is a deliberate cancel (the player's
		-- clearly already looking at an open wheel), not a tap
		self:SetAttribute("wr-revealed", false)
		-- reset here, from secure code, since OnOpen (insecure, called via CallMethod
		-- below) can't touch this attribute itself while in combat lockdown
		self:SetAttribute("wr-active", false)
		owner:CallMethod("OnOpen", ring)
		return false
	end

	if RING_ACTIVE ~= ring then return false end
	RING_ACTIVE = nil

	-- OnOpen (above) sets this false whenever it decides there's nothing to show (no
	-- resolvable target/hover, combat-disabled, or no presets assigned to this ring):
	-- with no wheel to drag toward, cursor movement since keydown means nothing, and
	-- comparing it against the deadzone anyway risked misreading ordinary ambient mouse
	-- movement (the player simply moving their cursor elsewhere while tapping the key)
	-- as a drag/pick attempt, silently dropping what should have been a plain tap.
	if not self:GetAttribute("wr-active") then
		owner:CallMethod("OnTap", ring)
		return false
	end

	local x, y = screen:GetMousePosition()
	if not x then
		owner:CallMethod("OnCancel", ring)
		return false
	end
	local dx = x * screen:GetWidth() - START_X
	local dy = y * screen:GetHeight() - START_Y
	local inDeadzone = dx * dx + dy * dy <= %d * %d

	-- a release still inside the deadzone before the wheel was ever revealed is a tap:
	-- previously this was decided by whether a tiny 4px probe frame under the cursor had
	-- been left, which any amount of hand jitter while physically pressing the key could
	-- trip even when the cursor barely moved, misreading a real tap as a cancel below
	-- instead. Comparing against the same deadzone radius as a pick does is both simpler
	-- and matches what the player actually felt (did it move enough to mean something).
	if not self:GetAttribute("wr-revealed") and inDeadzone then
		owner:CallMethod("OnTap", ring)
		return false
	end

	local count = self:GetAttribute("wr-count") or 0
	if self:GetAttribute("wr-list") then
		local row = math.floor((-dy - %d) / %d) + 1
		if row < 1 or row > count then
			owner:CallMethod("OnCancel", ring)
		else
			owner:CallMethod("OnPick", ring, row)
		end
		return false
	end
	if count == 0 or inDeadzone then
		owner:CallMethod("OnCancel", ring)
		return false
	end
	local step = 360 / count
	local offset = (90 - math.deg(math.atan2(dy, dx))) %% 360
	local index = math.floor((offset + step / 2) / step) %% count + 1
	owner:CallMethod("OnPick", ring, index)
	return false
]]):format(DEADZONE, DEADZONE, LIST_TOP, LIST_ROW)

SecureHandlerWrapScript(RingButton1, "OnClick", Controller, PRE_CLICK)
SecureHandlerWrapScript(RingButton2, "OnClick", Controller, PRE_CLICK)

local frameRefsSet = false
local function ensureFrameRefs()
	if frameRefsSet then return end
	SecureHandlerSetFrameRef(Controller, "screen", Screen)
	frameRefsSet = true
end

-- visual: Blizzard's own radial-wheel background, with one plain text label per preset
-- (no per-slice icons, presets don't have icons to show) and hand-drawn divider lines
-- between slices (Blizzard's own divider art is baked per exact slice count, and ours
-- varies). colored per preset by its own delta sign, not per-ring, so a single radial
-- mixing good and bad presets still reads at a glance either way.
local RADIUS = 81
local WHEEL_SIZE = 228
-- the stock atlas art is a fairly tight ring; a background a good deal larger than the
-- wheel itself reads as a softer gradient instead of a hard-edged circle around the labels
local BG_SIZE = WHEEL_SIZE * 1.6
-- font sizes are set explicitly rather than via GameFontHighlight/GameFontNormalLarge's
-- own baked-in sizes, so these can run bigger than any stock template offers
local NAME_FONT_PATH = GameFontNormal:GetFont()

local function fontPath()
	return Skin.FacePath() or NAME_FONT_PATH
end

local MEDIA = "Interface\\AddOns\\" .. ns.name .. "\\Media\\"

-- Tiles style: flat buttons around the center ring, no disc. Side buttons grow away from
-- the center, top and bottom ones are centered on their slice.
local FLAT_CENTER_SIZE = 2 * (DEADZONE + 4)
local FLAT_POINTER_SIZE = FLAT_CENTER_SIZE + 16
local PILL_RADIUS = 64 -- center to each button's inner edge
local PILL_HEIGHT = 24
local PILL_PAD = 12
local PILL_FONT_SIZE = 14
local PILL_MIX = 0.35 -- hovered button: this much of its preset color over the surface
local PILL_SIDE = 0.25 -- past this |cos|, a button grows sideways instead of up or down

-- Ring style: one segment per preset with gaps between, each label fitted inside its own
-- segment (two lines at most, then cut), the hovered label in full in the center hub.
-- Segments are a flat texture clipped by two angular masks (pushed in by half the gap)
-- and a baked ring mask, the same technique as the classic wedge highlight.
local RING_IN, RING_OUT = 44, 136 -- RadialRing.png's hole is baked at RING_IN / RING_OUT
local RING_GAP, RING_PAD = 4, 3
local HUB_RADIUS = 40 -- RadialHubRim.png is baked for this
local RING_FONT_SIZE, RING_LINE = 12, 15
local RING_MIX = 0.32
local RING_ALPHA, RING_HOVER_ALPHA = 0.92, 0.96
local POINTER_HALF = math.rad(28)
local ELLIPSIS = "..."

local LIST_HEADER = 30
local LIST_LEFT = 16 -- where the key went down, in from the list's left edge
local LIST_PAD = 12
local LIST_FONT_SIZE = 14

-- "classic", "ring", "tiles" or "list"
local function wheelStyle()
	local style = ns.GetSettings().radialMenu.wheelStyle
	if style == "classic" or style == "ring" or style == "tiles" or style == "list" then
		return style
	end
	return Skin.IsActive() and "ring" or "classic"
end
local NAME_FONT_SIZE = 20
local LABEL_FONT_SIZE = 15
local LABEL_FONT_SIZE_HIGHLIGHT = 19
local PRESET_COLOR = {
	positive = { base = { 0.55, 0.85, 0.55 }, highlight = { 0.6, 1, 0.4 }, glow = { 0.3, 1, 0.3 } },
	negative = { base = { 0.9, 0.5, 0.5 }, highlight = { 1, 0.4, 0.3 }, glow = { 1, 0.25, 0.2 } },
	neutral = { base = { 0.8, 0.8, 0.8 }, highlight = { 1, 0.82, 0 }, glow = { 1, 0.82, 0 } },
}

local function colorForPreset(preset)
	local delta = preset.delta or 0
	if delta > 0 then return PRESET_COLOR.positive end
	if delta < 0 then return PRESET_COLOR.negative end
	return PRESET_COLOR.neutral
end

-- the hovered slice is highlighted with actual pie-slice wedge art (Blizzard's own
-- ping-wheel asset, which only ships pre-shaped for a 4-slice wheel), rather than a glow
-- blob behind the text: a wide slice (fewer than ~5 total) is covered by several rotated
-- copies side by side, a narrow one by a single copy, each clipped with two angled mask
-- textures to exactly its own slice's angular sector so copies never overlap or show the
-- 4-slice art's own baked seams. Tinted per preset color since the art itself is neutral.
-- technique (not code) follows how Blizzard/RL_RadialMenu fill in counts they don't have
-- dedicated art for (github.com/RL-addon-dev/RL_RadialMenu, GPL-3.0; reimplemented
-- independently from reading their approach, nothing copied).
local WEDGE_ATLAS = "Radial_Wheel_Select_Wedge_Count_4"
local WEDGE_RADIUS = 60 -- distance from wheel center to the wedge art's own baked pivot
local MAX_PIECE_ARC = math.rad(80) -- widest angular slice one wedge copy can cover cleanly
local CLIP_MASK_TEXTURE = "Interface\\Buttons\\WHITE8X8"
local CLIP_MASK_SIZE = 512 -- comfortably covers the wedge art along whichever edge is clipped

local wheel
local labels = {}
local dividers = {}
local wedgePieces = {}
local sliceCount = 0

local function ensureWheel()
	if wheel then return wheel end
	wheel = CreateFrame("Frame", nil, UIParent)
	wheel:SetSize(WHEEL_SIZE, WHEEL_SIZE)
	wheel:SetFrameStrata("DIALOG")
	wheel:Hide()
	wheel.style = wheelStyle()
	wheel.flat = wheel.style == "ring" or wheel.style == "tiles"
	wheel.list = wheel.style == "list"
	wheel.bg = wheel:CreateTexture(nil, "BACKGROUND")
	wheel.bg:SetPoint("CENTER")
	if wheel.list then
		local r, g, b = Skin.SurfaceColor()
		wheel.bg:SetColorTexture(r, g, b, RING_HOVER_ALPHA)
		wheel.listLine = wheel:CreateTexture(nil, "BORDER")
		wheel.listLine:SetColorTexture(Skin.BorderColor())
		wheel.listLine:SetHeight(1)
	elseif wheel.style == "ring" then
		wheel.bg:SetTexture(MEDIA .. "RadialDisc.png")
		local r, g, b = Skin.SurfaceColor()
		wheel.bg:SetVertexColor(r, g, b, RING_ALPHA)
		wheel.bg:SetSize(2 * HUB_RADIUS, 2 * HUB_RADIUS)
	elseif wheel.flat then
		wheel.bg:SetTexture(MEDIA .. "RadialDisc.png")
		wheel.bg:SetVertexColor(Skin.SurfaceColor())
		wheel.bg:SetSize(FLAT_CENTER_SIZE, FLAT_CENTER_SIZE)
	else
		-- useAtlasSize=false: passing true here resizes the texture to the atlas's own native
		-- size, clobbering the explicit SetSize right after it
		wheel.bg:SetAtlas("Radial_Wheel_BG", false)
		wheel.bg:SetSize(BG_SIZE, BG_SIZE)
	end

	-- marks where the deadzone ends, dim while a slice is actively selected and bright
	-- while hovering dead center (same ring Blizzard's own ping wheel uses for its
	-- cancel button). atlas name follows the same "Radial_Wheel_..." family as the
	-- background/frame/wedge atlases already confirmed live on this client, but hasn't
	-- been confirmed itself yet -- if it doesn't exist, SetAtlas just renders nothing.
	wheel.deadzoneRing = wheel:CreateTexture(nil, "ARTWORK", nil, 1)
	wheel.deadzoneRing:SetPoint("CENTER")
	if wheel.style == "tiles" then
		wheel.deadzoneRing:SetTexture(MEDIA .. "RadialCenter.png")
		wheel.deadzoneRing:SetSize(FLAT_CENTER_SIZE, FLAT_CENTER_SIZE)
	elseif wheel.style == "classic" then
		wheel.deadzoneRing:SetAtlas("Radial_Wheel_Select_Close", true)
	end
	wheel.deadzoneRing:SetAlpha(0.45)

	-- glowing arrow that tracks the raw cursor angle continuously (not snapped to a
	-- slice like the wedge highlight), so the wheel still gives feedback inside the
	-- deadzone before a pick is even possible. same unverified-atlas caveat as above.
	wheel.pointer = wheel:CreateTexture(nil, "OVERLAY", nil, -1)
	wheel.pointer:SetPoint("CENTER")
	if wheel.flat then
		if wheel.style == "ring" then
			-- an arc on the hub's edge, facing the cursor
			wheel.pointer:SetTexture(CLIP_MASK_TEXTURE)
			wheel.pointer:SetSize(2 * HUB_RADIUS, 2 * HUB_RADIUS)
			local rim = wheel:CreateMaskTexture()
			rim:SetPoint("CENTER")
			rim:SetTexture(MEDIA .. "RadialHubRim.png", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			rim:SetSize(2 * HUB_RADIUS, 2 * HUB_RADIUS)
			wheel.pointer:AddMaskTexture(rim)
			wheel.pointerMasks = { wheel:CreateMaskTexture(), wheel:CreateMaskTexture() }
			for _, mask in ipairs(wheel.pointerMasks) do
				mask:SetTexture(CLIP_MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
				mask:SetSize(CLIP_MASK_SIZE, CLIP_MASK_SIZE)
				wheel.pointer:AddMaskTexture(mask)
			end
			wheel.ringMask = wheel:CreateMaskTexture()
			wheel.ringMask:SetPoint("CENTER")
			wheel.ringMask:SetTexture(MEDIA .. "RadialRing.png", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			wheel.ringMask:SetSize(2 * RING_OUT, 2 * RING_OUT)
			wheel.rimMask = wheel:CreateMaskTexture()
			wheel.rimMask:SetPoint("CENTER")
			wheel.rimMask:SetTexture(MEDIA .. "RadialRim.png", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
			wheel.rimMask:SetSize(2 * RING_OUT, 2 * RING_OUT)
			wheel.hubText = wheel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			wheel.hubText:SetFont(fontPath(), RING_FONT_SIZE, "")
			wheel.hubText:SetSpacing(RING_LINE - RING_FONT_SIZE)
			wheel.hubText:SetJustifyH("CENTER")
			wheel.hubText:SetPoint("CENTER")
		else
			wheel.pointer:SetTexture(MEDIA .. "RadialPointer.png")
			wheel.pointer:SetSize(FLAT_POINTER_SIZE, FLAT_POINTER_SIZE)
		end
		local pointer = wheel.pointer
		local function paintPointer()
			pointer:SetVertexColor(Skin.AccentColor())
		end
		paintPointer()
		Skin.OnChanged(paintPointer)
	elseif wheel.style == "classic" then
		wheel.pointer:SetAtlas("Radial_Wheel_Select_Pointer", true)
	end
	wheel.pointer:Hide()

	-- dark fade behind the name, same atlas as the wheel itself so it reads as part of
	-- the same art instead of a plain box; resized to the name's own text width each
	-- time it changes (see updateActiveUnitDisplay), since names vary a lot in length
	wheel.nameBg = wheel:CreateTexture(nil, "BACKGROUND")
	if wheel.flat then
		wheel.nameBg:SetColorTexture(Skin.SurfaceColor())
	elseif wheel.style == "classic" then
		wheel.nameBg:SetAtlas("Radial_Wheel_BG", false)
	end
	wheel.nameBg:Hide()

	wheel.nameText = wheel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	wheel.nameText:SetFont(fontPath(), NAME_FONT_SIZE, "OUTLINE")
	wheel.nameText:SetPoint("BOTTOM", wheel, "TOP", 0, 6)
	wheel.nameText:Hide()
	wheel.nameBg:SetPoint("CENTER", wheel.nameText)

	-- shown instead of slices when an enabled second radial has no presets picked yet
	wheel.emptyText = Skin.Text(wheel, "OVERLAY", "GameFontHighlight")
	wheel.emptyText:SetPoint("CENTER", 0, -RADIUS)
	wheel.emptyText:SetWidth(200)
	wheel.emptyText:SetJustifyH("CENTER")
	wheel.emptyText:SetText("No presets on this radial yet.\nPick some in Options > Radial Menu.")
	wheel.emptyText:Hide()
	return wheel
end

-- shared by every wedge piece (not rotated or rebuilt per-slice, unlike the angular clip
-- masks below): reuses the plain background atlas itself as a mask, so the colored wedge
-- is clipped to the exact same opaque ring/fade-hole shape the background already has,
-- instead of filling solid all the way to the center. a first attempt drew a second
-- VISIBLE copy of this atlas on top of the wedge instead of using it as a mask, which did
-- the opposite of what was wanted: the atlas's ring is the opaque part and its middle is
-- the transparent hole, so that covered the color everywhere except the hole.
local radialFadeMask
local function ensureRadialFadeMask()
	if radialFadeMask then return radialFadeMask end
	ensureWheel()
	radialFadeMask = wheel:CreateMaskTexture()
	radialFadeMask:SetPoint("CENTER")
	radialFadeMask:SetAtlas("Radial_Wheel_BG", false)
	radialFadeMask:SetSize(BG_SIZE, BG_SIZE)
	return radialFadeMask
end

local function getWedgePiece(i)
	local piece = wedgePieces[i]
	if piece then return piece end
	ensureWheel()
	piece = { texture = wheel:CreateTexture(nil, "ARTWORK"), masks = {} }
	piece.texture:SetAtlas(WEDGE_ATLAS, true)
	for m = 1, 2 do
		local mask = wheel:CreateMaskTexture()
		mask:SetTexture(CLIP_MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
		mask:SetSize(CLIP_MASK_SIZE, CLIP_MASK_SIZE)
		piece.texture:AddMaskTexture(mask)
		piece.masks[m] = mask
	end
	piece.texture:AddMaskTexture(ensureRadialFadeMask())
	piece.texture:Hide()
	wedgePieces[i] = piece
	return piece
end

-- clips `piece` to the angular sector between `low` and `high` (radians, around the
-- wheel center): each mask is a half-plane boundary along one of the sector's two edge
-- lines, positioned so everything on the far side of that line gets masked away
local function clipPieceToSector(piece, low, high)
	local edges = { high, low }
	local inward = { high - math.pi / 2, low + math.pi / 2 }
	local distance = CLIP_MASK_SIZE / 2
	for i = 1, 2 do
		local mask = piece.masks[i]
		mask:ClearAllPoints()
		mask:SetPoint("CENTER", wheel, "CENTER", math.cos(inward[i]) * distance, math.sin(inward[i]) * distance)
		mask:SetRotation(edges[i])
	end
end

local function hideWedgeHighlight()
	for _, piece in ipairs(wedgePieces) do
		piece.texture:Hide()
	end
end

local function showWedgeHighlight(index, count, color)
	if not index or not count or count < 2 then
		hideWedgeHighlight()
		return
	end
	local angle = math.rad(90 - (index - 1) * 360 / count)
	local arc = 2 * math.pi / count
	local pieceCount = math.max(1, math.ceil(arc / MAX_PIECE_ARC))
	local pieceArc = arc / pieceCount
	local low = angle - arc / 2
	for i = 1, pieceCount do
		local piece = getWedgePiece(i)
		local pieceLow = low + (i - 1) * pieceArc
		local pieceCenter = pieceLow + pieceArc / 2
		piece.texture:SetRotation(pieceCenter)
		piece.texture:ClearAllPoints()
		piece.texture:SetPoint("CENTER", wheel, "CENTER",
			math.cos(pieceCenter) * WEDGE_RADIUS, math.sin(pieceCenter) * WEDGE_RADIUS)
		clipPieceToSector(piece, pieceLow, pieceLow + pieceArc)
		piece.texture:SetVertexColor(color[1], color[2], color[3])
		piece.texture:Show()
	end
	for i = pieceCount + 1, #wedgePieces do
		wedgePieces[i].texture:Hide()
	end
end

-- light, not dark: a dark line barely reads against the wheel's own dark background. full
-- opacity near the center fading to none near the edge (matching the background's own
-- outer fade) reads better than a flat alpha too, same idea as RL_RadialMenu's own
-- divider gradient.
local DIVIDER_COLOR_INNER = CreateColor(0.85, 0.8, 0.68, 0.9)
local DIVIDER_COLOR_OUTER = CreateColor(0.85, 0.8, 0.68, 0)

-- one line per slice boundary, running from just past center to near the wheel's edge
local function layoutDividers(count)
	ensureWheel()
	for i = 1, math.max(count, #dividers) do
		if i <= count and not dividers[i] then
			local line = wheel:CreateLine(nil, "ARTWORK")
			line:SetThickness(2)
			line:SetTexture(CLIP_MASK_TEXTURE)
			line:SetGradient("HORIZONTAL", DIVIDER_COLOR_INNER, DIVIDER_COLOR_OUTER)
			dividers[i] = line
		end
		local line = dividers[i]
		if line then
			if i <= count and count > 1 then
				local angle = math.rad(90 - (i - 1) * 360 / count + 180 / count)
				local c, s = math.cos(angle), math.sin(angle)
				line:ClearAllPoints()
				line:SetStartPoint("CENTER", wheel, c * (DEADZONE + 4), s * (DEADZONE + 4))
				line:SetEndPoint("CENTER", wheel, c * (RADIUS + 21), s * (RADIUS + 21))
				line:Show()
			else
				line:Hide()
			end
		end
	end
end

-- labels grow outward from their own slice position instead of centering directly on
-- it: the point on the wheel sits at the label's own edge facing the center, so text
-- grows away from the middle (and from its neighbors) rather than spreading equally in
-- both directions from a point that's often only ~80px from the next slice's own point.
-- combined with SetWidth+SetWordWrap below (an overlong label wraps to a second line
-- instead of stretching further around the ring), this is what keeps adjacent labels
-- from bleeding into each other.
--
-- two earlier attempts at this (anchoring a named corner/edge like "BOTTOMLEFT" or
-- "LEFT" at the point) both measurably drifted the label off its true slice angle --
-- confirmed live, twice, in different directions -- since a named anchor point's
-- distance from a label's own visual center depends on which anchor was picked and how
-- many lines the label wraps to, not on anything consistent across slices. this instead
-- always centers the label exactly, then explicitly offsets that center away from the
-- slice point by half the label's own *measured* rendered size (GetStringWidth/Height,
-- read after the final text/line-wrap is set), scaled per axis by how strongly this
-- slice's own angle leans toward that axis. continuous rather than picking from 8 fixed
-- octants, so there's no discrete direction to pick, and no corner/edge semantics to
-- misjudge, just a size-proportional push along the slice's own angle.
local LABEL_MAX_WIDTH = 92

local function offsetLabelCenter(label, angle, x, y)
	local c, s = math.cos(angle), math.sin(angle)
	local w, h = label:GetStringWidth(), label:GetStringHeight()
	return x + c * (w / 2), y + s * (h / 2)
end

-- a label's line count is decided once, up front, at the LARGER highlighted size rather
-- than whatever size happens to be showing at the time: otherwise a label sized to fit
-- one line while unhighlighted could still wrap to two the moment it's hovered and grows
-- (SetWidth's wrap is evaluated against the font size in effect at the time), which reads
-- as the whole label jumping/reflowing right as you point at it. deciding (and, if
-- needed, inserting the actual line break) at the bigger size up front means the
-- unhighlighted and highlighted renders always agree on how many lines there are, so only
-- the text size itself changes on hover, nothing reflows.
local measureLabel = UIParent:CreateFontString(nil, "BACKGROUND")
measureLabel:Hide()

-- picks whichever space in `text` splits it into the two most evenly-sized halves (by
-- rendered width at the current measureLabel font), so a two-word label breaks between
-- the words instead of defaulting to e.g. always the first space
local function bestLineBreak(text)
	local bestPos
	local bestScore
	for pos in text:gmatch("()%s") do
		measureLabel:SetText(text:sub(1, pos - 1))
		local w1 = measureLabel:GetStringWidth()
		measureLabel:SetText(text:sub(pos + 1))
		local w2 = measureLabel:GetStringWidth()
		local score = math.max(w1, w2)
		if not bestScore or score < bestScore then
			bestScore, bestPos = score, pos
		end
	end
	if not bestPos then return text end
	return text:sub(1, bestPos - 1) .. "\n" .. text:sub(bestPos + 1)
end

-- sets `label`'s text, pre-breaking it onto two lines if (and only if) it would need to
-- wrap once highlighted; SetWordWrap(true) on the label itself (see ensureLabelWidgets)
-- stays on as a fallback for anything still too wide after that (a single long word, say)
local function setLabelText(label, text)
	if label.segment then
		label.fullText = text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
		return
	end
	if label.pill or label.row then
		label:SetText(text)
		return
	end
	measureLabel:SetFont(fontPath(), LABEL_FONT_SIZE_HIGHLIGHT, "OUTLINE")
	measureLabel:SetText(text)
	if measureLabel:GetStringWidth() > LABEL_MAX_WIDTH then
		text = bestLineBreak(text)
	end
	label:SetText(text)
end

-- ensures/show-hides the label widgets for this slice count. does NOT position them:
-- positioning depends on each label's own rendered text size (see offsetLabelCenter
-- above), so it has to happen after setLabelText, not before. call positionLabels once
-- every visible label's final text is set.
local function ensureLabelWidgets(count)
	ensureWheel()
	sliceCount = count
	for i = 1, math.max(count, #labels) do
		if i <= count and not labels[i] and wheel.list then
			local label = wheel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			label:SetFont(fontPath(), LIST_FONT_SIZE, "")
			label:SetWordWrap(false)
			label.row = { fill = wheel:CreateTexture(nil, "ARTWORK"), bar = wheel:CreateTexture(nil, "ARTWORK", nil, 1) }
			labels[i] = label
		elseif i <= count and not labels[i] and wheel.style == "ring" then
			local segment = {}
			for key, sublevel in pairs({ fill = 0, rim = 1 }) do
				local tex = wheel:CreateTexture(nil, "ARTWORK", nil, sublevel)
				tex:SetTexture(CLIP_MASK_TEXTURE)
				tex:SetSize(2 * RING_OUT, 2 * RING_OUT)
				tex:SetPoint("CENTER")
				segment[key] = tex
			end
			segment.masks = { wheel:CreateMaskTexture(), wheel:CreateMaskTexture() }
			for _, mask in ipairs(segment.masks) do
				mask:SetTexture(CLIP_MASK_TEXTURE, "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
				mask:SetSize(CLIP_MASK_SIZE, CLIP_MASK_SIZE)
				segment.fill:AddMaskTexture(mask)
				segment.rim:AddMaskTexture(mask)
			end
			segment.fill:AddMaskTexture(wheel.ringMask)
			segment.rim:AddMaskTexture(wheel.rimMask)
			segment.rim:Hide()
			local label = wheel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			label:SetFont(fontPath(), RING_FONT_SIZE, "")
			label:SetSpacing(RING_LINE - RING_FONT_SIZE)
			label:SetJustifyH("CENTER")
			label.segment = segment
			labels[i] = label
		elseif i <= count and not labels[i] and wheel.flat then
			local pill = CreateFrame("Frame", nil, wheel)
			pill:SetHeight(PILL_HEIGHT)
			pill.edge = pill:CreateTexture(nil, "BACKGROUND")
			pill.edge:SetAllPoints()
			pill.fill = pill:CreateTexture(nil, "BORDER")
			pill.fill:SetPoint("TOPLEFT", 1, -1)
			pill.fill:SetPoint("BOTTOMRIGHT", -1, 1)
			local label = pill:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			label:SetFont(fontPath(), PILL_FONT_SIZE, "")
			label:SetPoint("CENTER")
			label:SetWordWrap(false)
			label.pill = pill
			labels[i] = label
		elseif i <= count and not labels[i] then
			local label = wheel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			label:SetWidth(LABEL_MAX_WIDTH)
			label:SetWordWrap(true)
			label:SetJustifyH("CENTER")
			labels[i] = label
		end
		if labels[i] then
			labels[i]:SetShown(i <= count)
			if labels[i].pill then
				labels[i].pill:SetShown(i <= count)
			end
			if labels[i].segment then
				labels[i].segment.fill:SetShown(i <= count)
				labels[i].segment.rim:Hide()
			end
			if labels[i].row then
				labels[i].row.fill:SetShown(i <= count)
				labels[i].row.bar:SetShown(i <= count)
			end
		end
	end
end

-- side buttons grow away from the center, top and bottom ones sit centered on their slice;
-- the name goes above the highest one
local function positionPills(count)
	local top = FLAT_CENTER_SIZE / 2
	for i = 1, count do
		local label = labels[i]
		local pill = label.pill
		pill:SetWidth(math.ceil(label:GetStringWidth()) + 2 * PILL_PAD)
		local angle = math.rad(90 - (i - 1) * 360 / count)
		local c, s = math.cos(angle), math.sin(angle)
		local x, y = c * PILL_RADIUS, s * PILL_RADIUS
		pill:ClearAllPoints()
		if c > PILL_SIDE then
			pill:SetPoint("LEFT", wheel, "CENTER", x, y)
			top = math.max(top, y + PILL_HEIGHT / 2)
		elseif c < -PILL_SIDE then
			pill:SetPoint("RIGHT", wheel, "CENTER", x, y)
			top = math.max(top, y + PILL_HEIGHT / 2)
		elseif s > 0 then
			pill:SetPoint("BOTTOM", wheel, "CENTER", x, y)
			top = math.max(top, y + PILL_HEIGHT)
		else
			pill:SetPoint("TOP", wheel, "CENTER", x, y)
		end
	end
	wheel.nameText:ClearAllPoints()
	wheel.nameText:SetPoint("BOTTOM", wheel, "CENTER", 0, top + 12)
end

-- keeps a mask's square edge on the line at `angle`, `inset` px into the sector
local function placeEdgeMask(mask, angle, inward, inset)
	local distance = CLIP_MASK_SIZE / 2 + inset
	mask:ClearAllPoints()
	mask:SetPoint("CENTER", wheel, "CENTER", math.cos(inward) * distance, math.sin(inward) * distance)
	mask:SetRotation(angle)
end

-- clips to the sector between low and high (radians), each edge pushed in by `inset`
local function clipToSector(masks, low, high, inset)
	placeEdgeMask(masks[1], high, high - math.pi / 2, inset)
	placeEdgeMask(masks[2], low, low + math.pi / 2, inset)
end

local function textWidth(text)
	measureLabel:SetText(text)
	return measureLabel:GetStringWidth()
end

local function dropLastChar(text)
	return (text:gsub("[%z\1-\127\192-\255][\128-\191]*$", ""))
end

local function cutToWidth(text, width)
	if textWidth(text) <= width then
		return text
	end
	while text ~= "" and textWidth(text .. ELLIPSIS) > width do
		text = dropLastChar(text)
	end
	return text:gsub(" $", "") .. ELLIPSIS
end

local function inSegment(x, y, center, half)
	local r = math.sqrt(x * x + y * y)
	if r < RING_IN + RING_PAD or r > RING_OUT - RING_PAD then
		return false
	end
	local diff = (math.atan2(y, x) - center + math.pi) % (2 * math.pi) - math.pi
	if math.abs(diff) > half then
		return false
	end
	if half < math.pi then
		for _, edge in ipairs({ center - half, center + half }) do
			if math.abs(-math.sin(edge) * x + math.cos(edge) * y) < RING_GAP / 2 + RING_PAD then
				return false
			end
		end
	end
	return true
end

-- widest one-line text box centered on cx at height y that stays inside the segment
local function rowWidth(cx, y, center, half)
	local low, high = 0, 2 * RING_OUT
	for _ = 1, 16 do
		local w = (low + high) / 2
		local fits = true
		for _, corner in ipairs({ { -1, -1 }, { -1, 1 }, { 1, -1 }, { 1, 1 } }) do
			if not inSegment(cx + corner[1] * w / 2, y + corner[2] * RING_FONT_SIZE / 2, center, half) then
				fits = false
				break
			end
		end
		if fits then
			low = w
		else
			high = w
		end
	end
	return low
end

-- one line if it fits, else as many whole words as fit on the first line and the rest on
-- the second, each line cut to its own room
local function fitSegmentText(text, cx, cy, center, half)
	local single = rowWidth(cx, cy, center, half)
	if textWidth(text) <= single then
		return text
	end
	local topWidth = rowWidth(cx, cy + RING_LINE / 2, center, half)
	local bottomWidth = rowWidth(cx, cy - RING_LINE / 2, center, half)
	local words = {}
	for word in text:gmatch("%S+") do
		words[#words + 1] = word
	end
	local first, k = words[1] or "", 2
	while words[k] and textWidth(first .. " " .. words[k]) <= topWidth do
		first = first .. " " .. words[k]
		k = k + 1
	end
	local rest = table.concat(words, " ", k)
	if rest == "" then
		return cutToWidth(first, single)
	end
	return cutToWidth(first, topWidth) .. "\n" .. cutToWidth(rest, bottomWidth)
end

local function hubRowWidth(y)
	local radius = HUB_RADIUS - 6
	local v = math.abs(y) + RING_FONT_SIZE / 2
	if v >= radius then
		return 0
	end
	return 2 * math.sqrt(radius * radius - v * v)
end

-- the longest leading piece of `text` within `width`, by whole words when one fits
local function takeLine(text, width)
	local line = ""
	for word in text:gmatch("%S+") do
		local trial = line == "" and word or (line .. " " .. word)
		if textWidth(trial) > width then
			break
		end
		line = trial
	end
	if line == "" then
		for char in text:gmatch("[%z\1-\127\192-\255][\128-\191]*") do
			if line ~= "" and textWidth(line .. char) > width then
				break
			end
			line = line .. char
		end
	end
	return line, (text:sub(#line + 1):gsub("^ ", ""))
end

-- the full label in up to three lines, breaking long words when it has to
local function fitHubText(text)
	for count = 1, 3 do
		local lines, rest, fits = {}, text, true
		for k = 1, count do
			local width = hubRowWidth(RING_LINE * ((count - 1) / 2 - (k - 1)))
			if k == count then
				lines[k] = rest
				fits = fits and textWidth(rest) <= width
			else
				lines[k], rest = takeLine(rest, width)
			end
			if rest == "" and k < count then
				break
			end
		end
		if fits or count == 3 then
			for k, line in ipairs(lines) do
				lines[k] = cutToWidth(line, hubRowWidth(RING_LINE * ((#lines - 1) / 2 - (k - 1))))
			end
			return table.concat(lines, "\n")
		end
	end
end

local function layoutRing(count)
	measureLabel:SetFont(fontPath(), RING_FONT_SIZE, "")
	local half = math.pi / count
	local mid = (RING_IN + RING_OUT) / 2 + 3
	for i = 1, count do
		local label = labels[i]
		local center = math.rad(90 - (i - 1) * 360 / count)
		if count > 1 then
			clipToSector(label.segment.masks, center - half, center + half, RING_GAP / 2)
		else
			for _, mask in ipairs(label.segment.masks) do
				mask:ClearAllPoints()
				mask:SetPoint("CENTER")
			end
		end
		local cx, cy = math.cos(center) * mid, math.sin(center) * mid
		label:SetText(fitSegmentText(label.fullText or "", cx, cy, center, half))
		label:ClearAllPoints()
		label:SetPoint("CENTER", wheel, "CENTER", cx, cy)
		label.hubText = fitHubText(label.fullText or "")
	end
	wheel.nameText:ClearAllPoints()
	wheel.nameText:SetPoint("BOTTOM", wheel, "CENTER", 0, RING_OUT + 14)
end

-- a panel hanging just below where the key went down: the name on top, one row per preset
local function layoutList(count)
	local width = math.max(140, wheel.nameText:GetStringWidth() + 2 * LIST_PAD)
	for i = 1, count do
		width = math.max(width, labels[i]:GetStringWidth() + 2 * LIST_PAD)
	end
	width = math.ceil(width)
	local left, headerTop = -LIST_LEFT, -LIST_TOP + LIST_HEADER
	wheel.bg:ClearAllPoints()
	wheel.bg:SetPoint("TOPLEFT", wheel, "CENTER", left, headerTop)
	wheel.bg:SetSize(width, LIST_HEADER + math.max(count, 1) * LIST_ROW)
	wheel.listLine:ClearAllPoints()
	wheel.listLine:SetPoint("TOPLEFT", wheel, "CENTER", left, -LIST_TOP)
	wheel.listLine:SetWidth(width)
	for i = 1, count do
		local label, row = labels[i], labels[i].row
		local top = -LIST_TOP - (i - 1) * LIST_ROW
		row.fill:ClearAllPoints()
		row.fill:SetPoint("TOPLEFT", wheel, "CENTER", left, top)
		row.fill:SetSize(width, LIST_ROW)
		row.bar:ClearAllPoints()
		row.bar:SetPoint("TOPLEFT", wheel, "CENTER", left, top)
		row.bar:SetSize(3, LIST_ROW)
		label:ClearAllPoints()
		label:SetPoint("LEFT", wheel, "CENTER", left + LIST_PAD, top - LIST_ROW / 2)
	end
	wheel.nameText:ClearAllPoints()
	wheel.nameText:SetPoint("LEFT", wheel, "CENTER", left + LIST_PAD, -LIST_TOP + LIST_HEADER / 2)
	wheel.emptyText:ClearAllPoints()
	wheel.emptyText:SetPoint("TOPLEFT", wheel, "CENTER", left + LIST_PAD, -LIST_TOP - 4)
	wheel.emptyText:SetWidth(width - 2 * LIST_PAD)
	wheel.emptyText:SetJustifyH("LEFT")
end

-- points the pointer at `angle` (radians): the classic and tiles art rotate, the ring's
-- arc is re-clipped
local function pointAt(angle)
	if wheel.list then
		return
	elseif wheel.style == "ring" then
		clipToSector(wheel.pointerMasks, angle - POINTER_HALF, angle + POINTER_HALF, 0)
	else
		wheel.pointer:SetRotation(angle)
	end
end

local function positionLabels(count)
	if wheel.list then
		layoutList(count)
		return
	end
	if wheel.style == "ring" then
		layoutRing(count)
		return
	end
	if wheel.flat then
		positionPills(count)
		return
	end
	for i = 1, count do
		local label = labels[i]
		local angle = math.rad(90 - (i - 1) * 360 / count)
		local x, y = offsetLabelCenter(label, angle, math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
		label:ClearAllPoints()
		label:SetPoint("CENTER", wheel, "CENTER", x, y)
	end
	layoutDividers(count)
end

-- neutral presets use the accent
local function pillColor(color)
	if color == PRESET_COLOR.neutral then
		return Skin.AccentColor()
	end
	return unpack(color.glow)
end

local function setPillHighlight(index)
	local sr, sg, sb = Skin.SurfaceColor()
	for i, label in ipairs(labels) do
		local color = label.presetColor or PRESET_COLOR.neutral
		local pill = label.pill
		if i == index then
			local r, g, b = pillColor(color)
			pill.fill:SetColorTexture(sr + (r - sr) * PILL_MIX, sg + (g - sg) * PILL_MIX, sb + (b - sb) * PILL_MIX, 1)
			pill.edge:SetColorTexture(r, g, b, 1)
			label:SetTextColor(1, 1, 1)
		else
			pill.fill:SetColorTexture(sr, sg, sb, 1)
			pill.edge:SetColorTexture(Skin.BorderColor())
			label:SetTextColor(unpack(color.base))
		end
	end
	wheel.deadzoneRing:SetAlpha(index and 0.45 or 1)
end

local function setRingHighlight(index)
	local sr, sg, sb = Skin.SurfaceColor()
	for i, label in ipairs(labels) do
		local color = label.presetColor or PRESET_COLOR.neutral
		local segment = label.segment
		if i == index then
			local r, g, b
			if color == PRESET_COLOR.neutral then
				r, g, b = Skin.AccentColor()
			else
				r, g, b = unpack(color.base)
			end
			segment.fill:SetVertexColor(sr + (r - sr) * RING_MIX, sg + (g - sg) * RING_MIX, sb + (b - sb) * RING_MIX, RING_HOVER_ALPHA)
			segment.rim:SetVertexColor(r, g, b, 1)
			segment.rim:Show()
			label:SetTextColor(1, 1, 1)
		else
			segment.fill:SetVertexColor(sr, sg, sb, RING_ALPHA)
			segment.rim:Hide()
			label:SetTextColor(unpack(color.base))
		end
	end
	wheel.hubText:SetText(index and labels[index] and labels[index].hubText or "")
end

local function setListHighlight(index)
	local sr, sg, sb = Skin.SurfaceColor()
	for i, label in ipairs(labels) do
		local color = label.presetColor or PRESET_COLOR.neutral
		local row = label.row
		if i == index then
			local r, g, b
			if color == PRESET_COLOR.neutral then
				r, g, b = Skin.AccentColor()
			else
				r, g, b = unpack(color.base)
			end
			row.fill:SetColorTexture(sr + (r - sr) * RING_MIX, sg + (g - sg) * RING_MIX, sb + (b - sb) * RING_MIX, 1)
			row.bar:SetColorTexture(r, g, b, 1)
			label:SetTextColor(1, 1, 1)
		else
			row.fill:SetColorTexture(0, 0, 0, 0)
			row.bar:SetColorTexture(0, 0, 0, 0)
			label:SetTextColor(unpack(color.base))
		end
	end
end

local function setHighlight(index)
	if wheel.list then
		setListHighlight(index)
		return
	end
	if wheel.style == "ring" then
		setRingHighlight(index)
		return
	end
	if wheel.flat then
		setPillHighlight(index)
		return
	end
	for i, label in ipairs(labels) do
		local color = label.presetColor or PRESET_COLOR.neutral
		if i == index then
			label:SetTextColor(unpack(color.highlight))
			label:SetFont(fontPath(), LABEL_FONT_SIZE_HIGHLIGHT, "OUTLINE")
		else
			label:SetTextColor(unpack(color.base))
			label:SetFont(fontPath(), LABEL_FONT_SIZE, "OUTLINE")
		end
	end
	if index then
		local color = (labels[index] and labels[index].presetColor or PRESET_COLOR.neutral).glow
		showWedgeHighlight(index, sliceCount, color)
	else
		hideWedgeHighlight()
	end
	if wheel.deadzoneRing then
		wheel.deadzoneRing:SetAlpha(index and 0.45 or 1)
	end
end

-- drops the wheel so the next open builds it in the current style
function ns.RebuildRadialWheel()
	if not wheel then
		return
	end
	wheel:Hide()
	wheel = nil
	radialFadeMask = nil
	wipe(labels)
	wipe(dividers)
	wipe(wedgePieces)
	sliceCount = 0
end

-- target first, then whatever nameplate/frame the mouse is over. re-resolved on every
-- update tick (not just once at open) since a single check right at keydown could catch
-- the mouseover unit a frame before it actually registers; by release time it's settled.
-- `hoverEnabled` is passed in rather than read here directly: the wheel itself and a
-- plain tap have their own independent hover settings (radialMenu.hoverEnabled vs
-- quickNoteHoverEnabled), and this same function resolves identity for both, see
-- openIdentity/tapIdentity below.
-- targetEnabled defaults to true (the wheel's own open/pick resolution always checks
-- target first); only the plain-tap path gates it via tapTargetEnabled, same idea as
-- hoverEnabled already does for quickNoteHoverEnabled vs radialMenu.hoverEnabled.
local function resolveActiveUnit(hoverEnabled, targetEnabled)
	if targetEnabled ~= false and UnitExists("target") and UnitIsPlayer("target") then
		return "target"
	end
	if hoverEnabled and UnitExists("mouseover") and UnitIsPlayer("mouseover") then
		return "mouseover"
	end
	return nil
end

-- openIdentity/openContext are snapshotted the moment a unit first resolves, not re-read
-- live at pick time: reaching most wedges means dragging the cursor off the hovered
-- unit's frame, so by release "mouseover" has usually gone stale and a live
-- UnitExists("mouseover") recheck would fail even though a valid hover happened. once
-- captured they're locked for the rest of this ring (OnOpen clears the lock again), so
-- whoever was hovered/targeted at open time stays the target even if the cursor drifts
-- over someone else's nameplate while dragging toward a wedge. gated by
-- radialMenu.hoverEnabled, for the wheel itself (display + picks).
--
-- tapIdentity/tapContext are the same idea, captured at the same moment, but gated by
-- quickNoteHoverEnabled instead: a plain tap (Controller:OnTap) needs the SAME early
-- capture to dodge the same staleness problem, but should respect the General tab's own
-- hover setting, not the Radial Menu tab's. Using openIdentity for taps too (an earlier
-- version of this fix) meant unchecking quickNoteHoverEnabled silently stopped doing
-- anything for taps once the radial was enabled, since every tap routed through the
-- radial-gated identity instead of its own setting.
local openIdentity, openContext
local tapIdentity, tapContext, tapIsHover

local function updateActiveUnitDisplay()
	if not openIdentity then
		local resolved = resolveActiveUnit(ns.GetSettings().radialMenu.hoverEnabled)
		if resolved then
			openIdentity = ns.IdentifyUnit(resolved)
			openContext = ns.CaptureContext(resolved)
		end
	end
	if not wheel then return end
	if openIdentity then
		local r, g, b
		if ns.GetSettings().radialMenu.nameColor == "bracket" then
			-- no record yet reads as neutral
			local record = ns.GetPlayerRecord(openIdentity.key, false)
			local standing = (record and record.standing or 0) + ns.GetPendingAdjustment(openIdentity.key)
			r, g, b = unpack(ns.GetBracket(standing).color)
		else
			r, g, b = ns.ClassColor(openIdentity.classFile)
		end
		wheel.nameText:SetText(openIdentity.name)
		wheel.nameText:SetTextColor(r, g, b)
		wheel.nameText:Show()
		if wheel.flat then
			wheel.nameBg:SetSize(wheel.nameText:GetStringWidth() + 24, wheel.nameText:GetStringHeight() + 10)
		else
			wheel.nameBg:SetSize(wheel.nameText:GetStringWidth() + 60, wheel.nameText:GetStringHeight() + 36)
		end
		wheel.nameBg:Show()
	else
		wheel.nameText:Hide()
		wheel.nameBg:Hide()
	end
end

-- live highlight while the ring is held: cosmetic only, the actual pick is decided by
-- the secure snippet above at release, this just previews it
local cursorUpdater = CreateFrame("Frame")
local openPresets

local function onCursorUpdate()
	updateActiveUnitDisplay()

	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	x, y = x / scale, y / scale
	local dx, dy = x - wheel.centerX, y - wheel.centerY
	if wheel.list then
		-- same rule as the secure pick
		local count = openPresets and #openPresets or 0
		local row = math.floor((-dy - LIST_TOP) / LIST_ROW) + 1
		setHighlight((row >= 1 and row <= count) and row or nil)
		return
	end
	-- the pointer only tracks once the cursor has actually left the deadzone (the ring
	-- art alone marks "nothing selected yet" inside it); showing an arrow with nowhere
	-- meaningful to point yet reads as implying a direction before one's reachable
	local inDeadzone = dx * dx + dy * dy <= DEADZONE * DEADZONE
	if not inDeadzone then
		pointAt(math.atan2(dy, dx))
		wheel.pointer:Show()
	else
		wheel.pointer:Hide()
	end

	local count = openPresets and #openPresets or 0
	if count == 0 or inDeadzone then
		setHighlight(nil)
		return
	end
	local step = 360 / count
	local offset = (90 - math.deg(math.atan2(dy, dx))) % 360
	local index = math.floor((offset + step / 2) / step) % count + 1
	setHighlight(index)
end

-- a plain tap opens and immediately closes the ring in the same frame, since the
-- secure side can't know in advance it won't turn into a drag. showing it right away
-- made every tap flash it on screen. delaying the actual Show() lets a tap finish
-- (closeWheel bumps the generation) before it would ever appear
local REVEAL_DELAY = 0.15
local openGeneration = 0

-- the default (or a mouse-anchored replacement) unit tooltip competes for screen space
-- with the wheel, which opens right at the cursor; suppressed for as long as the wheel
-- is actually up, by force-hiding GameTooltip the instant anything (Blizzard's own
-- mouseover handling, or another addon's tooltip hook) tries to show it. a plain :Hide()
-- when the wheel opens isn't enough on its own, since those hooks can re-show it again
-- on the next mouseover update while the wheel is still open.
local radialTooltipSuppressed = false
GameTooltip:HookScript("OnShow", function(tt)
	if radialTooltipSuppressed then
		tt:Hide()
	end
end)

-- forward-declared: closeWheel disables it, defined below closeWheel itself
local cancelCatcher

-- Escape/right-click only hide the wheel; the physical key held down to open it is
-- usually still held at that point, and the secure snippet doesn't learn about either of
-- them at all (it can only react to the radial keybind's own up/down), so its drag
-- tracking keeps running underneath and still calls OnTap/OnPick once the real key is
-- finally released, wherever the cursor happens to be by then. this flag tells those
-- callbacks a manual cancel already happened this interaction, so they skip applying
-- anything when that fires.
local escCancelled = false

local function closeWheel()
	openGeneration = openGeneration + 1
	cursorUpdater:SetScript("OnUpdate", nil)
	if wheel then wheel:Hide() end
	radialTooltipSuppressed = false
	cancelCatcher:EnableKeyboard(false)
	cancelCatcher:EnableMouse(false)
end

-- Escape or a click anywhere cancels like any other MMO popup would, only enabled for as
-- long as the wheel is actually open. any button closes it, not just right-click: WoW has
-- no mouse click passthrough, so a click landing here is already swallowed either way,
-- closing on any button means that's the only click lost instead of every click until a
-- right-click/Escape happens to land (the actual radial hotkey itself still works even
-- while this is up, via the override-binding click dispatch, not this frame).
cancelCatcher = CreateFrame("Frame", nil, UIParent)
cancelCatcher:SetAllPoints(UIParent)
cancelCatcher:SetFrameStrata("TOOLTIP")
cancelCatcher:EnableKeyboard(false)
cancelCatcher:EnableMouse(false)
cancelCatcher:SetPropagateKeyboardInput(true)
cancelCatcher:SetScript("OnMouseDown", function(self, button)
	escCancelled = true
	closeWheel()
end)
cancelCatcher:SetScript("OnKeyDown", function(self, key)
	if key == "ESCAPE" then
		self:SetPropagateKeyboardInput(false)
		escCancelled = true
		closeWheel()
	else
		self:SetPropagateKeyboardInput(true)
	end
end)

local openedAt

function Controller:OnOpen(ring)
	-- the secure side only knows whether there are presets at all (wr-count), not
	-- whether there's a valid target/mouseover right now, so that's checked here
	-- instead. nothing to act on just means no ring shows; wr-active (set below) tells
	-- the secure snippet's keyup handler so it treats the release as a tap unconditionally
	-- rather than measuring cursor movement against a wheel that never had anything to show
	if ns.IsSuppressed() then
		return
	end
	openedAt = GetTime()
	local ringButton = RingButtons[ring]
	escCancelled = false
	openIdentity, openContext = nil, nil
	tapIdentity, tapContext, tapIsHover = nil, nil, nil

	-- both captured unconditionally, before the combat gate below: a tap's own
	-- staleness problem exists whether or not the wheel itself is allowed to open, so
	-- disableInCombat (which only gates the wheel) can't skip this without
	-- reintroducing that staleness for a plain tap made mid-fight.
	local resolved = resolveActiveUnit(ns.GetSettings().radialMenu.hoverEnabled)
	if resolved then
		openIdentity = ns.IdentifyUnit(resolved)
		openContext = ns.CaptureContext(resolved)
	end
	local tapResolved = resolveActiveUnit(ns.GetSettings().quickNoteHoverEnabled, ns.GetSettings().tapTargetEnabled)
	if tapResolved then
		tapIdentity = ns.IdentifyUnit(tapResolved)
		tapContext = ns.CaptureContext(tapResolved)
		tapIsHover = (tapResolved == "mouseover")
	end

	-- disableInCombat only gates the wheel itself, never the plain-tap Quick Note
	-- behavior (OnTap doesn't go through here at all), so held-key note-taking still
	-- works mid-fight, there's just nothing to drag toward
	if ns.GetSettings().radialMenu.disableInCombat and InCombatLockdown() then
		-- can't SetAttribute from here during combat lockdown; the secure snippet
		-- already reset wr-active to false at keydown before calling this
		openPresets = nil
		return
	end

	openPresets = openIdentity and ns.GetRadialPresetSet(ring) or nil
	-- an enabled second radial with nothing picked still opens, showing a hint, so a
	-- held key doesn't silently turn into a tap (releasing it just cancels)
	local showEmpty = ring == 2 and openPresets ~= nil and #openPresets == 0
		and ns.GetSettings().radialMenu.secondEnabled
	if not showEmpty and (not openPresets or #openPresets == 0) then
		openPresets = nil
		ringButton:SetAttribute("wr-active", false)
		return
	end
	ringButton:SetAttribute("wr-active", true)

	if ns.GetSettings().radialMenu.suppressTooltip then
		radialTooltipSuppressed = true
		GameTooltip:Hide()
	end
	cancelCatcher:EnableKeyboard(true)
	cancelCatcher:EnableMouse(true)

	ensureWheel()
	updateActiveUnitDisplay()
	ensureLabelWidgets(#openPresets)
	for i, preset in ipairs(openPresets) do
		setLabelText(labels[i], preset.label)
		labels[i].presetColor = colorForPreset(preset)
	end
	-- positioning reads each label's own rendered size, so it has to run after the
	-- text above is actually set, not before
	positionLabels(#openPresets)
	wheel.emptyText:SetShown(showEmpty)

	local x, y = GetCursorPosition()
	local scale = UIParent:GetEffectiveScale()
	wheel.centerX, wheel.centerY = x / scale, y / scale
	wheel:ClearAllPoints()
	wheel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", wheel.centerX, wheel.centerY)
	setHighlight(nil)
	cursorUpdater:SetScript("OnUpdate", onCursorUpdate)

	openGeneration = openGeneration + 1
	local myGeneration = openGeneration
	C_Timer.After(REVEAL_DELAY, function()
		if openGeneration == myGeneration then
			wheel:Show()
			-- past this point a release inside the deadzone is a deliberate cancel, not
			-- a tap, see the secure snippet's wr-revealed check
			if ringButton then
				ringButton:SetAttribute("wr-revealed", true)
			end
		end
	end)
end

-- an Escape press during a held interaction only hides the wheel immediately; the
-- physical key is usually still down at that point, so the secure snippet's own drag
-- tracking keeps running underneath and still calls one of OnTap/OnCancel/OnPick once it
-- actually releases. each of those checks-and-clears escCancelled here so that release
-- applies nothing, no matter where the cursor ended up by then.
local function consumeEscCancel()
	if not escCancelled then return false end
	escCancelled = false
	return true
end

function Controller:OnTap(ring, immediate)
	-- captured before closeWheel/QuickNoteTarget can touch anything: a genuine tap
	-- (not "immediate", meaning OnOpen already ran for this same press) already has a
	-- fresh identity from keydown time (tapIdentity, gated by quickNoteHoverEnabled --
	-- not openIdentity, which is gated by the wheel's own separate hoverEnabled
	-- setting), resolved before the keydown/keyup round trip could let mouseover go
	-- stale. "immediate" taps (no presets configured at all, fired
	-- straight from keydown with no OnOpen in between) have nothing of their own to
	-- reuse, and have had zero time to go stale anyway, so those still resolve fresh
	-- via ns.QuickNoteTarget() same as a plain non-radial tap would.
	local identity = tapIdentity
	local isHover = tapIsHover
	closeWheel()
	if consumeEscCancel() then return end
	if ns.IsSuppressed() then
		ns.NotifySuppressed()
		return
	end
	if not immediate and identity then
		local action = isHover and ns.GetSettings().tapHoverAction or ns.GetSettings().tapTargetAction
		ns.PerformTapAction(action, identity)
	else
		ns.QuickNoteTarget()
	end
end

function Controller:OnCancel()
	closeWheel()
	consumeEscCancel()
end

function Controller:OnPick(ring, index)
	closeWheel()
	if consumeEscCancel() then return end

	-- a pick resolving faster than minHoldMs after the key went down is treated as a
	-- cancel, not a real pick: the cursor only escapes the small center deadzone to
	-- register one at all, so a fast release out there is more likely an imprecise
	-- press or an attempt to cancel that missed the deadzone than a deliberate choice.
	-- falling back to a tap/quick-add here would be surprising (that's not what the key
	-- was held for), so this just drops the pick silently instead.
	local heldMs = (GetTime() - (openedAt or 0)) * 1000
	local minHoldMs = ns.GetSettings().radialMenu.minHoldMs or 0
	if heldMs < minHoldMs then
		return
	end

	local preset = openPresets and openPresets[index]
	if preset and openIdentity then
		ns.ApplyPresetToIdentity(openIdentity, openContext, preset)
	end
end

-- claims the Quick Note keybind's current key (and, if enabled, "<modifier>-key" for
-- the second ring) via override bindings, out of combat. an override always wins over
-- the plain Bindings.xml action on the same key, so this becomes the one path for that
-- key once it's bound
local function rebuild()
	if InCombatLockdown() then return end
	ensureFrameRefs()
	ClearOverrideBindings(Controller)

	local settings = ns.GetSettings().radialMenu
	RingButton1:SetAttribute("wr-count", #ns.GetRadialPresetSet(1))
	RingButton2:SetAttribute("wr-count", settings.secondEnabled and #ns.GetRadialPresetSet(2) or 0)
	RingButton2:SetAttribute("wr-showempty", settings.secondEnabled and true or false)
	local list = settings.wheelStyle == "list"
	for _, button in ipairs(RingButtons) do
		if list or button:GetAttribute("wr-list") then
			button:SetAttribute("wr-list", list)
		end
	end

	-- disabled: no overrides, so the key falls back to the plain binding, which does nothing
	if not settings.enabled or ns.IsSuppressed() then
		return
	end

	local key = GetBindingKey("WR_QUICKNOTE")
	if not key then
		return
	end
	SetOverrideBindingClick(Controller, true, key, RingButton1:GetName(), "LeftButton")
	if settings.secondEnabled then
		local modKey = (settings.secondModifier or "CTRL") .. "-" .. key
		SetOverrideBindingClick(Controller, true, modKey, RingButton2:GetName(), "LeftButton")
	end
end

function ns.RefreshRadialMenuBinding()
	rebuild()
end

local combatWaiter = CreateFrame("Frame")
combatWaiter:RegisterEvent("PLAYER_REGEN_ENABLED")
combatWaiter:SetScript("OnEvent", rebuild)

-- in combat this waits for PLAYER_REGEN_ENABLED above; OnOpen bails out meanwhile
ns.OnSuppressionChanged(function(_, stateChanged)
	if stateChanged then
		rebuild()
	end
end)

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", function()
	rebuild()
	-- a key already physically held down the instant its override binding registers
	-- can fire a phantom click with no matching keyup, leaving cancelCatcher's
	-- full-screen click-eater stuck enabled. self-heals shortly after login regardless.
	C_Timer.After(2, closeWheel)
end)

-- tour preview: a static wheel for identity at x, y (UIParent space), first wedge lit.
-- no keybind, cursor tracking or click-catcher involved
function ns.ShowRadialPreview(identity, x, y)
	local presets = ns.GetRadialPresetSet(1)
	if not presets or #presets == 0 then
		return false
	end
	closeWheel()
	openIdentity, openContext = identity, nil
	openPresets = presets
	ensureWheel()
	updateActiveUnitDisplay()
	ensureLabelWidgets(#presets)
	for i, preset in ipairs(presets) do
		setLabelText(labels[i], preset.label)
		labels[i].presetColor = colorForPreset(preset)
	end
	positionLabels(#presets)
	wheel.emptyText:Hide()
	wheel.centerX, wheel.centerY = x, y
	wheel:ClearAllPoints()
	wheel:SetPoint("CENTER", UIParent, "BOTTOMLEFT", x, y)
	setHighlight(1)
	pointAt(math.pi / 2)
	wheel.pointer:Show()
	wheel:Show()
	return true
end

function ns.HideRadialPreview()
	if wheel then
		wheel:Hide()
	end
	openIdentity, openContext, openPresets = nil, nil, nil
end
