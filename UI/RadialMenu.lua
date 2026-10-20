local ns = WorthRemembering

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

-- a wheel with too many slices gets hard to aim, dual-mode selections are capped here.
-- exported so the Options tab's dropdown can enforce the same limit
ns.MAX_RADIAL_PRESETS = 5
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
function ns.GetRadialPresetSet(ringIndex)
	local settings = ns.GetSettings()
	local radial = settings.radialMenu
	local allItems = settings.quickPresets.enabled and settings.quickPresets.items or {}

	local explicit = (ringIndex == 1) and radial.radial1Labels or radial.radial2Labels
	-- a stored selection can predate the second radial being enabled (single-radial mode
	-- doesn't care about sign), or predate a preset's delta being edited since, so dual
	-- mode re-checks sign here too instead of trusting it was saved correctly: without
	-- this, a leftover wrong-sign label still counts toward the ring's list and shows up
	-- on its wheel even though the (now sign-filtered) dropdown no longer offers it
	local function signOk(delta)
		if not radial.secondEnabled then return true end
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
		if count == 0 then
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
	if count == 0 or inDeadzone then
		owner:CallMethod("OnCancel", ring)
		return false
	end
	local step = 360 / count
	local offset = (90 - math.deg(math.atan2(dy, dx))) %% 360
	local index = math.floor((offset + step / 2) / step) %% count + 1
	owner:CallMethod("OnPick", ring, index)
	return false
]]):format(DEADZONE, DEADZONE)

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
	wheel.bg = wheel:CreateTexture(nil, "BACKGROUND")
	wheel.bg:SetPoint("CENTER")
	-- useAtlasSize=false: passing true here resizes the texture to the atlas's own native
	-- size, clobbering the explicit SetSize right after it
	wheel.bg:SetAtlas("Radial_Wheel_BG", false)
	wheel.bg:SetSize(BG_SIZE, BG_SIZE)

	-- marks where the deadzone ends, dim while a slice is actively selected and bright
	-- while hovering dead center (same ring Blizzard's own ping wheel uses for its
	-- cancel button). atlas name follows the same "Radial_Wheel_..." family as the
	-- background/frame/wedge atlases already confirmed live on this client, but hasn't
	-- been confirmed itself yet -- if it doesn't exist, SetAtlas just renders nothing.
	wheel.deadzoneRing = wheel:CreateTexture(nil, "ARTWORK", nil, 1)
	wheel.deadzoneRing:SetPoint("CENTER")
	wheel.deadzoneRing:SetAtlas("Radial_Wheel_Select_Close", true)
	wheel.deadzoneRing:SetAlpha(0.45)

	-- glowing arrow that tracks the raw cursor angle continuously (not snapped to a
	-- slice like the wedge highlight), so the wheel still gives feedback inside the
	-- deadzone before a pick is even possible. same unverified-atlas caveat as above.
	wheel.pointer = wheel:CreateTexture(nil, "OVERLAY", nil, -1)
	wheel.pointer:SetPoint("CENTER")
	wheel.pointer:SetAtlas("Radial_Wheel_Select_Pointer", true)
	wheel.pointer:Hide()

	-- dark fade behind the name, same atlas as the wheel itself so it reads as part of
	-- the same art instead of a plain box; resized to the name's own text width each
	-- time it changes (see updateActiveUnitDisplay), since names vary a lot in length
	wheel.nameBg = wheel:CreateTexture(nil, "BACKGROUND")
	wheel.nameBg:SetAtlas("Radial_Wheel_BG", false)
	wheel.nameBg:Hide()

	wheel.nameText = wheel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	wheel.nameText:SetFont(NAME_FONT_PATH, NAME_FONT_SIZE, "OUTLINE")
	wheel.nameText:SetPoint("BOTTOM", wheel, "TOP", 0, 6)
	wheel.nameText:Hide()
	wheel.nameBg:SetPoint("CENTER", wheel.nameText)
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
	measureLabel:SetFont(NAME_FONT_PATH, LABEL_FONT_SIZE_HIGHLIGHT, "OUTLINE")
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
		if i <= count and not labels[i] then
			local label = wheel:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			label:SetWidth(LABEL_MAX_WIDTH)
			label:SetWordWrap(true)
			label:SetJustifyH("CENTER")
			labels[i] = label
		end
		if labels[i] then
			labels[i]:SetShown(i <= count)
		end
	end
end

local function positionLabels(count)
	for i = 1, count do
		local label = labels[i]
		local angle = math.rad(90 - (i - 1) * 360 / count)
		local x, y = offsetLabelCenter(label, angle, math.cos(angle) * RADIUS, math.sin(angle) * RADIUS)
		label:ClearAllPoints()
		label:SetPoint("CENTER", wheel, "CENTER", x, y)
	end
	layoutDividers(count)
end

local function setHighlight(index)
	for i, label in ipairs(labels) do
		local color = label.presetColor or PRESET_COLOR.neutral
		if i == index then
			label:SetTextColor(unpack(color.highlight))
			label:SetFont(NAME_FONT_PATH, LABEL_FONT_SIZE_HIGHLIGHT, "OUTLINE")
		else
			label:SetTextColor(unpack(color.base))
			label:SetFont(NAME_FONT_PATH, LABEL_FONT_SIZE, "OUTLINE")
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

-- target first, then whatever nameplate/frame the mouse is over. re-resolved on every
-- update tick (not just once at open) since a single check right at keydown could catch
-- the mouseover unit a frame before it actually registers; by release time it's settled.
-- `hoverEnabled` is passed in rather than read here directly: the wheel itself and a
-- plain tap have their own independent hover settings (radialMenu.hoverEnabled vs
-- quickNoteHoverEnabled), and this same function resolves identity for both, see
-- openIdentity/tapIdentity below.
local function resolveActiveUnit(hoverEnabled)
	if UnitExists("target") and UnitIsPlayer("target") then
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
local tapIdentity, tapContext

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
		local r, g, b = ns.ClassColor(openIdentity.classFile)
		wheel.nameText:SetText(openIdentity.name)
		wheel.nameText:SetTextColor(r, g, b)
		wheel.nameText:Show()
		wheel.nameBg:SetSize(wheel.nameText:GetStringWidth() + 60, wheel.nameText:GetStringHeight() + 36)
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
	-- the pointer only tracks once the cursor has actually left the deadzone (the ring
	-- art alone marks "nothing selected yet" inside it); showing an arrow with nowhere
	-- meaningful to point yet reads as implying a direction before one's reachable
	local inDeadzone = dx * dx + dy * dy <= DEADZONE * DEADZONE
	if not inDeadzone then
		wheel.pointer:SetRotation(math.atan2(dy, dx))
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

-- Escape, or a right-click anywhere, cancels like any other MMO popup would, while still
-- letting every other key/click through untouched (including whatever key the radial
-- itself is bound to, handled separately via the override-binding click dispatch, not
-- this frame). only enabled for as long as the wheel is actually open, so it never
-- intercepts input otherwise.
cancelCatcher = CreateFrame("Frame", nil, UIParent)
cancelCatcher:SetAllPoints(UIParent)
cancelCatcher:SetFrameStrata("TOOLTIP")
cancelCatcher:EnableKeyboard(false)
cancelCatcher:EnableMouse(false)
cancelCatcher:SetPropagateKeyboardInput(true)
cancelCatcher:SetScript("OnMouseDown", function(self, button)
	if button == "RightButton" then
		escCancelled = true
		closeWheel()
	end
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
	openedAt = GetTime()
	local ringButton = RingButtons[ring]
	escCancelled = false
	openIdentity, openContext = nil, nil
	tapIdentity, tapContext = nil, nil

	-- both captured unconditionally, before the combat gate below: a tap's own
	-- staleness problem exists whether or not the wheel itself is allowed to open, so
	-- disableInCombat (which only gates the wheel) can't skip this without
	-- reintroducing that staleness for a plain tap made mid-fight.
	local resolved = resolveActiveUnit(ns.GetSettings().radialMenu.hoverEnabled)
	if resolved then
		openIdentity = ns.IdentifyUnit(resolved)
		openContext = ns.CaptureContext(resolved)
	end
	local tapResolved = resolveActiveUnit(ns.GetSettings().quickNoteHoverEnabled)
	if tapResolved then
		tapIdentity = ns.IdentifyUnit(tapResolved)
		tapContext = ns.CaptureContext(tapResolved)
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
	if not openPresets or #openPresets == 0 then
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
	closeWheel()
	if consumeEscCancel() then return end
	if not immediate and identity then
		ns.QuickNoteIdentity(identity)
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

	if not settings.enabled then
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

local initFrame = CreateFrame("Frame")
initFrame:RegisterEvent("PLAYER_LOGIN")
initFrame:SetScript("OnEvent", rebuild)
