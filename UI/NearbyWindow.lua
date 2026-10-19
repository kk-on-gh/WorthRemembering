local ns = WorthRemembering

local frame
local scroll
local scrollChild
local rowPool = {}

local WINDOW_WIDTH = 220
local ROW_HEIGHT = 20
local HEADER_HEIGHT = 28
local SCROLLBAR_GUTTER = 22
local MIN_WIDTH, MIN_HEIGHT = 140, HEADER_HEIGHT + ROW_HEIGHT + 10
local DOUBLE_CLICK_WINDOW = 0.4

-- In static-size mode the frame can be resized, so row/scroll widths are derived from the
-- frame's *current* width rather than the fixed WINDOW_WIDTH constant.
local function rowAreaWidth()
	return (frame and frame:GetWidth() or WINDOW_WIDTH) - 16 - SCROLLBAR_GUTTER
end

-- separate from the main window's alpha. this window idles dim and only brightens on
-- mouseover, unlike a window you're actively using
local function applyIdleAlpha()
	if frame:IsMouseOver() then
		return
	end
	frame:SetAlpha(ns.GetSettings().nearbyIdleAlpha)
end

local function applyHoverAlpha()
	frame:SetAlpha(ns.GetSettings().nearbyHoverAlpha)
end

-- OnEnter/OnLeave alone can get out of sync: a MenuUtil context menu opened from a row
-- captures the mouse, and dismissing it doesn't reliably fire the frame's own OnLeave.
-- Re-deriving the correct alpha from actual mouse position every 0.2s corrects for that
-- regardless of what the enter/leave events did or didn't fire.
local hoverCheckElapsed = 0
local function onUpdate(self, elapsed)
	hoverCheckElapsed = hoverCheckElapsed + elapsed
	if hoverCheckElapsed < 0.2 then
		return
	end
	hoverCheckElapsed = 0
	if self:IsMouseOver() then
		applyHoverAlpha()
	else
		applyIdleAlpha()
	end
end

-- position stored as {anchor, x, y}: anchor is the pinned corner (TOPLEFT growing down,
-- BOTTOMLEFT growing up, see nearbyGrowDirection), always relative to UIParent's
-- BOTTOMLEFT so x/y means the same screen spot regardless
local function savePosition()
	local settings = ns.GetSettings()
	local anchor = settings.nearbyGrowDirection == "up" and "BOTTOMLEFT" or "TOPLEFT"
	local x = frame:GetLeft()
	local y = anchor == "BOTTOMLEFT" and frame:GetBottom() or frame:GetTop()
	settings.nearbyPoint = { anchor = anchor, x = x, y = y }
end

local function restorePosition()
	local settings = ns.GetSettings()
	local p = settings.nearbyPoint
	frame:ClearAllPoints()
	-- A saved position missing `.anchor` (an older format, or none saved yet) falls back
	-- to a default position rather than passing nil to SetPoint, which would throw and
	-- leave the frame anchorless.
	if p and p.anchor then
		frame:SetPoint(p.anchor, UIParent, "BOTTOMLEFT", p.x, p.y)
	elseif settings.nearbyGrowDirection == "up" then
		frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 300)
	else
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", 20, UIParent:GetHeight() - 300)
	end
end

-- Repositions the header/divider/scroll area for the current nearbyGrowDirection ("down":
-- header on top, list grows downward beneath it; "up": header on the bottom, list grows
-- upward above it). Safe to call again after the setting changes, not just at creation.
local function applyGrowDirectionLayout()
	local direction = ns.GetSettings().nearbyGrowDirection
	frame.title:ClearAllPoints()
	frame.closeButton:ClearAllPoints()
	frame.divider:ClearAllPoints()
	frame.emptyText:ClearAllPoints()
	scroll:ClearAllPoints()

	-- anchor is always pinned LEFT (TOPLEFT down, BOTTOMLEFT up, see
	-- savePosition/restorePosition), so the grip goes on the opposite corner. a
	-- same-side grip wouldn't resize anything since StartSizing drags relative to the
	-- fixed corner
	if frame.resizeGrip then
		frame.resizeGrip:ClearAllPoints()
	end

	if direction == "up" then
		frame.title:SetPoint("BOTTOMLEFT", 8, 6)
		frame.closeButton:SetPoint("BOTTOMRIGHT", -2, 2)
		frame.divider:SetPoint("BOTTOMLEFT", 6, HEADER_HEIGHT - 2)
		frame.divider:SetPoint("BOTTOMRIGHT", -6, HEADER_HEIGHT - 2)
		frame.emptyText:SetPoint("BOTTOMLEFT", 8, HEADER_HEIGHT + 2)
		scroll:SetPoint("BOTTOMLEFT", 8, HEADER_HEIGHT)
		if frame.resizeGrip then
			frame.resizeGrip:SetPoint("TOPRIGHT", -2, -2)
		end
	else
		frame.title:SetPoint("TOPLEFT", 8, -6)
		frame.closeButton:SetPoint("TOPRIGHT", -2, -2)
		frame.divider:SetPoint("TOPLEFT", 6, -(HEADER_HEIGHT - 2))
		frame.divider:SetPoint("TOPRIGHT", -6, -(HEADER_HEIGHT - 2))
		frame.emptyText:SetPoint("TOPLEFT", 8, -(HEADER_HEIGHT + 2))
		scroll:SetPoint("TOPLEFT", 8, -HEADER_HEIGHT)
		if frame.resizeGrip then
			frame.resizeGrip:SetPoint("BOTTOMRIGHT", -2, 2)
		end
	end
end

-- called when the grow-direction dropdown flips. preserves on-screen position across
-- the anchor-corner switch, otherwise pinning a different corner to the same x/y moves
-- the window by its own height
function ns.SetNearbyGrowDirection(direction)
	ns.GetSettings().nearbyGrowDirection = direction
	if not frame then
		return
	end
	local x, top, bottom = frame:GetLeft(), frame:GetTop(), frame:GetBottom()
	frame:ClearAllPoints()
	if direction == "up" then
		frame:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, bottom)
	else
		frame:SetPoint("TOPLEFT", UIParent, "BOTTOMLEFT", x, top)
	end
	applyGrowDirectionLayout()
	savePosition()
	if ns.RefreshNearbyGrowDropdown then
		ns.RefreshNearbyGrowDropdown()
	end
end

function ns.SetNearbyScale(value)
	ns.GetSettings().nearbyScale = value
	if frame then
		frame:SetScale(value)
	end
end

local function acquireRow(index)
	local row = rowPool[index]
	if row then
		return row
	end

	row = CreateFrame("Button", nil, scrollChild, "BackdropTemplate")
	row:SetSize(rowAreaWidth(), ROW_HEIGHT)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	row.name = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.name:SetPoint("LEFT", 4, 0)
	row.name:SetJustifyH("LEFT")
	row.name:SetWidth(rowAreaWidth() - 44)
	row.name:SetWordWrap(false)

	row.standing = row:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	row.standing:SetPoint("RIGHT", -4, 0)
	row.standing:SetJustifyH("RIGHT")

	local highlight = row:CreateTexture(nil, "HIGHLIGHT")
	highlight:SetAllPoints()
	highlight:SetColorTexture(1, 0.82, 0, 0.15)

	row:SetPoint("TOPLEFT", 0, -(index - 1) * ROW_HEIGHT)

	rowPool[index] = row
	return row
end

-- notable players nearby as of the last refresh. lets a fresh arrival trigger an alert
-- without replaying it on every refresh that runs while they're still around
local previouslyNearbyKeys = {}

-- Per-player alert cooldown: leaving and coming back into range within
-- nearbySound.cooldownSeconds doesn't re-trigger the sound; after it elapses, it does.
local lastAlertAt = {}

local function soundsDisabledHere(sound)
	local inInstance, instanceType = IsInInstance()
	return inInstance and sound.disableInInstance[instanceType] == true
end

local function triggerFlash()
	if frame.flashAnim then
		frame.flashOverlay:Show()
		frame.flashAnim:Stop()
		frame.flashAnim:Play()
	end
end

-- sound and flash are independent toggleable outputs of one shared alert gate.
-- neutral-band/party exclusion already happened in refresh's filter, this only handles
-- instance suppression and the per-player cooldown
local function triggerAlert(key, standing)
	local sound = ns.GetSettings().nearbySound
	local flash = ns.GetSettings().nearbyFlash
	if not sound.enabled and not flash.enabled then
		return
	end
	if soundsDisabledHere(sound) then
		return
	end
	local now = GetTime()
	if lastAlertAt[key] and (now - lastAlertAt[key]) < sound.cooldownSeconds then
		return
	end
	lastAlertAt[key] = now

	if sound.enabled then
		ns.PlayConfiguredSound(standing > 0 and sound.positive or sound.negative, ns.GetSettings().soundChannel)
	end
	if flash.enabled then
		triggerFlash()
	end
end

-- resizes the row/scroll area to the frame's current size. shared by refresh() and the
-- live OnSizeChanged handler, so drag-resizing reflows rows immediately
local function layoutRowArea(playerCount)
	local width = rowAreaWidth()
	for i = 1, #rowPool do
		local row = rowPool[i]
		row:SetWidth(width)
		row.name:SetWidth(width - 44)
	end

	if ns.GetSettings().nearbyStaticSize then
		scroll:SetSize(width, math.max(frame:GetHeight() - HEADER_HEIGHT - 16, ROW_HEIGHT))
	else
		local limit = ns.GetSettings().nearbyVisibleRowLimit
		local visibleRows = math.max(math.min(playerCount or 0, limit), 1)
		scroll:SetSize(width, visibleRows * ROW_HEIGHT)
		frame:SetHeight(HEADER_HEIGHT + visibleRows * ROW_HEIGHT + 16)
	end
	scrollChild:SetSize(width, math.max(playerCount or 0, 1) * ROW_HEIGHT)
end

local function refresh()
	if not frame then
		return
	end

	-- only non-neutral standing: this window flags who to watch for, a neutral player
	-- isn't actionable. also excludes party/raid members, same as the sound alert, you
	-- already know they're there
	local band = ns.GetSettings().neutralBand
	local players = {}
	for _, entry in ipairs(ns.GetNearbyNotablePlayers()) do
		local isPartied = ns.IsPlayerPartied and ns.IsPlayerPartied(entry.key)
		if math.abs(entry.record.standing or 0) > band and not isPartied then
			players[#players + 1] = entry
		end
	end
	table.sort(players, function(a, b) return (a.record.standing or 0) > (b.record.standing or 0) end)

	local currentKeys = {}
	for _, entry in ipairs(players) do
		currentKeys[entry.key] = true
		if not previouslyNearbyKeys[entry.key] then
			triggerAlert(entry.key, entry.record.standing or 0)
		end
	end
	previouslyNearbyKeys = currentKeys

	frame.emptyText:SetShown(#players == 0)

	for i, entry in ipairs(players) do
		local row = acquireRow(i)
		local key, record = entry.key, entry.record
		local name = ns.DisplayName(record, key)
		-- reflects a pending +/- adjustment made elsewhere immediately, see
		-- ns.GetPendingAdjustment in QuickAdd.lua
		local standing = (record.standing or 0) + ns.GetPendingAdjustment(key)
		local bracket = ns.GetBracket(standing)

		row.name:SetText(name)
		row.name:SetTextColor(ns.ClassColor(record.classFile))
		row.standing:SetText(tostring(standing))
		row.standing:SetTextColor(bracket.color[1], bracket.color[2], bracket.color[3])

		row:SetScript("OnClick", function(_, button)
			if button == "RightButton" then
				MenuUtil.CreateContextMenu(row, function(_, rootDescription)
					rootDescription:CreateTitle(name)
					rootDescription:CreateButton("View Details", function() ns.ShowPlayerDetails(key) end)
					rootDescription:CreateButton("Add Entry", function() ns.ShowQuickAdd(key) end)
					rootDescription:CreateDivider()
					rootDescription:CreateButton("Delete Player Record", function()
						StaticPopup_Show("WR_CONFIRM_DELETE_PLAYER", name, nil, key)
					end)
				end)
				return
			end

			-- single-click's own Add Entry popup is delayed by DOUBLE_CLICK_WINDOW rather
			-- than firing immediately: there's no way to know a second click is coming
			-- until it either does or doesn't, so the only way to avoid both actions
			-- firing on a double-click is to hold off the first one and cancel it if a
			-- second click on the same row lands in time
			if row.pendingClickTimer and row.pendingClickKey == key then
				row.pendingClickTimer:Cancel()
				row.pendingClickTimer = nil
				ns.ShowPlayerDetails(key)
			else
				if row.pendingClickTimer then
					row.pendingClickTimer:Cancel()
				end
				row.pendingClickKey = key
				row.pendingClickTimer = C_Timer.NewTimer(DOUBLE_CLICK_WINDOW, function()
					row.pendingClickTimer = nil
					ns.ShowQuickAdd(key)
				end)
			end
		end)
		row:Show()
	end

	for i = #players + 1, #rowPool do
		rowPool[i]:Hide()
	end

	layoutRowArea(#players)
end
ns.RefreshNearbyWindow = refresh

-- Toggled from Options. Static mode makes the frame user-resizable (drag the grip in the
-- corner) and stops auto-sizing it to the player count; dynamic mode (the original
-- behavior) sizes the window to fit up to nearbyVisibleRowLimit rows automatically.
function ns.SetNearbyStaticSize(enabled)
	ns.GetSettings().nearbyStaticSize = enabled and true or false
	if not frame then
		return
	end
	-- Growth direction only means something while auto-sizing; switching to a fixed size
	-- while the title was pinned to the bottom (grow "up") would otherwise leave it stuck
	-- there with no way to change it, since the grow-direction control disables itself as
	-- soon as static size is on.
	if enabled and ns.GetSettings().nearbyGrowDirection ~= "down" then
		ns.SetNearbyGrowDirection("down")
	end
	frame:SetResizable(enabled and true or false)
	frame.resizeGrip:SetShown(enabled)
	if enabled then
		local settings = ns.GetSettings()
		frame:SetSize(settings.nearbyStaticWidth or WINDOW_WIDTH, settings.nearbyStaticHeight or 160)
	end
	refresh()
end

local function createFrame()
	local settings = ns.GetSettings()
	frame = CreateFrame("Frame", "WRNearbyFrame", UIParent, "BackdropTemplate")
	if settings.nearbyStaticSize then
		frame:SetSize(settings.nearbyStaticWidth or WINDOW_WIDTH, settings.nearbyStaticHeight or 160)
	else
		frame:SetSize(WINDOW_WIDTH, HEADER_HEIGHT + ROW_HEIGHT + 16)
	end
	frame:SetClampedToScreen(true)
	frame:SetFrameStrata("LOW")
	frame:SetMovable(true)
	frame:SetResizable(settings.nearbyStaticSize and true or false)
	frame:SetResizeBounds(MIN_WIDTH, MIN_HEIGHT)
	frame:EnableMouse(true)
	frame:SetScale(settings.nearbyScale)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", frame.StartMoving)
	frame:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		savePosition()
	end)
	frame:SetScript("OnSizeChanged", function()
		if ns.GetSettings().nearbyStaticSize then
			layoutRowArea(#ns.GetNearbyNotablePlayers())
		end
	end)
	ns.ApplyPanelBackdrop(frame, 1)

	frame:SetScript("OnEnter", applyHoverAlpha)
	frame:SetScript("OnLeave", applyIdleAlpha)
	frame:SetScript("OnUpdate", onUpdate)

	-- only shown in static-size mode, drag to resize same as Blizzard's own frames
	frame.resizeGrip = CreateFrame("Button", nil, frame)
	frame.resizeGrip:SetSize(16, 16)
	frame.resizeGrip:SetPoint("BOTTOMRIGHT", -2, 2)
	local gripTex = frame.resizeGrip:CreateTexture(nil, "OVERLAY")
	gripTex:SetAllPoints()
	gripTex:SetTexture("Interface\\ChatFrame\\UI-ChatIM-SizeGrabber-Up")
	-- hand-rolled instead of StartSizing, whose cursor-delta math breaks under this
	-- frame's configurable SetScale, turning a small drag into an instant huge resize
	local resizing = false
	local resizeStartX, resizeStartY, resizeStartWidth, resizeStartHeight

	frame.resizeGrip:SetScript("OnMouseDown", function()
		resizing = true
		local scale = frame:GetEffectiveScale()
		local x, y = GetCursorPosition()
		resizeStartX, resizeStartY = x / scale, y / scale
		resizeStartWidth, resizeStartHeight = frame:GetWidth(), frame:GetHeight()
	end)
	frame.resizeGrip:SetScript("OnUpdate", function()
		if not resizing then
			return
		end
		local scale = frame:GetEffectiveScale()
		local x, y = GetCursorPosition()
		x, y = x / scale, y / scale
		local dx, dy = x - resizeStartX, y - resizeStartY
		local newWidth = math.max(MIN_WIDTH, resizeStartWidth + dx)
		local newHeight
		if ns.GetSettings().nearbyGrowDirection == "up" then
			newHeight = math.max(MIN_HEIGHT, resizeStartHeight + dy)
		else
			newHeight = math.max(MIN_HEIGHT, resizeStartHeight - dy)
		end
		frame:SetSize(newWidth, newHeight)
	end)
	frame.resizeGrip:SetScript("OnMouseUp", function()
		resizing = false
		local s = ns.GetSettings()
		s.nearbyStaticWidth = frame:GetWidth()
		s.nearbyStaticHeight = frame:GetHeight()
		refresh()
	end)
	frame.resizeGrip:SetShown(settings.nearbyStaticSize)

	frame.title = frame:CreateFontString(nil, "ARTWORK", "GameFontNormalSmall")
	frame.title:SetText("Worth Remembering - Nearby")

	frame.closeButton = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
	frame.closeButton:SetSize(16, 16)
	frame.closeButton:SetScript("OnClick", function()
		ns.GetSettings().nearbyWindowEnabled = false
		frame:Hide()
	end)

	frame.divider = frame:CreateTexture(nil, "ARTWORK")
	frame.divider:SetColorTexture(1, 0.82, 0, 0.3)
	frame.divider:SetHeight(1)

	frame.emptyText = frame:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	frame.emptyText:SetText("No notable players nearby")

	-- full-window overlay, hidden until triggerFlash pulses it. needs its own raised
	-- FrameLevel, not just a texture layer, since sibling frames like scroll stack above
	-- regardless and would hide the flash while animating
	frame.flashOverlay = CreateFrame("Frame", nil, frame)
	frame.flashOverlay:SetAllPoints()
	frame.flashOverlay:SetFrameLevel(frame:GetFrameLevel() + 10)
	frame.flashOverlay:Hide()
	local flashTex = frame.flashOverlay:CreateTexture(nil, "OVERLAY")
	flashTex:SetAllPoints()
	flashTex:SetColorTexture(1, 0.82, 0.2, 1)

	frame.flashAnim = frame.flashOverlay:CreateAnimationGroup()
	local fadeIn = frame.flashAnim:CreateAnimation("Alpha")
	fadeIn:SetFromAlpha(0)
	fadeIn:SetToAlpha(1)
	fadeIn:SetDuration(0.12)
	fadeIn:SetOrder(1)
	local hold = frame.flashAnim:CreateAnimation("Alpha")
	hold:SetFromAlpha(1)
	hold:SetToAlpha(1)
	hold:SetDuration(0.25)
	hold:SetOrder(2)
	local fadeOut = frame.flashAnim:CreateAnimation("Alpha")
	fadeOut:SetFromAlpha(1)
	fadeOut:SetToAlpha(0)
	fadeOut:SetDuration(0.35)
	fadeOut:SetOrder(3)
	frame.flashAnim:SetScript("OnFinished", function() frame.flashOverlay:Hide() end)

	scroll = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
	scrollChild = CreateFrame("Frame", nil, scroll)
	scroll:SetScrollChild(scrollChild)
	scrollChild:SetSize(rowAreaWidth(), ROW_HEIGHT)

	applyGrowDirectionLayout()
	restorePosition()
	applyIdleAlpha()
end

-- shown at login if enabled, not lazily on first window open. unlike the tab panels,
-- meant to be visible during normal play regardless
function ns.EnsureNearbyWindow()
	if not frame then
		createFrame()
	end
	return frame
end

-- Lets the Options sliders preview idle/hover opacity changes live instead of only
-- taking effect the next time the mouse happens to enter/leave the window.
function ns.ApplyNearbyAlphaSettings()
	if not frame then
		return
	end
	if frame:IsMouseOver() then
		applyHoverAlpha()
	else
		applyIdleAlpha()
	end
end

function ns.SetNearbyWindowShown(shown)
	ns.GetSettings().nearbyWindowEnabled = shown and true or false
	if shown then
		ns.EnsureNearbyWindow():Show()
		refresh()
	elseif frame then
		frame:Hide()
	end
end
