local ns = WorthRemembering

-- players with a visible nameplate (nearby, on-screen). backs the Nearby window and
-- nameplate icon. keyed by unit token since those get reused, value is the full
-- identity so autoAddNearby skips a second IdentifyUnit call
local visibleUnits = {}

-- keyed by plate frame, not unit, since plates get reused for different units. always
-- re-derives color/visibility from scratch so a recycled plate never shows a stale badge
local plateIcons = {}

-- plain diamond, rotated colored square via SetColorTexture so it never depends on a
-- texture file
local function ensurePlateIcon(plate)
	local icon = plateIcons[plate]
	if not icon then
		icon = plate:CreateTexture(nil, "OVERLAY")
		icon:SetRotation(math.pi / 4)
		local border = plate:CreateTexture(nil, "OVERLAY", nil, -1)
		border:SetRotation(math.pi / 4)
		border:SetColorTexture(0, 0, 0, 0.9)
		icon.border = border
		plateIcons[plate] = icon
	end
	return icon
end

-- Nameplate frames aren't normally protected, but guard against mutating one during
-- combat lockdown anyway in case a given plate ever is.
local function canMutate(region)
	if not InCombatLockdown() then
		return true
	end
	return region.CanChangeProtectedState and region:CanChangeProtectedState() == true
end

-- preview mode: every nameplate gets the icon in one fixed color, so size/position can
-- be tuned without a real notable player nearby. toggled from Options
local previewMode = false

function ns.SetNameplateIconPreview(enabled)
	previewMode = enabled and true or false
	ns.RefreshNameplateIcons()
end

-- re-derives icon visibility/color/position for whatever's on this plate now
local function refreshPlateIcon(unit)
	if not unit then
		return
	end
	local plate = C_NamePlate.GetNamePlateForUnit(unit)
	if not plate or not canMutate(plate) then
		return
	end

	local settings = ns.GetSettings().nameplateIcon
	local icon = ensurePlateIcon(plate)

	if previewMode then
		local size = settings.size
		icon:SetSize(size, size)
		icon:ClearAllPoints()
		icon:SetPoint("BOTTOM", plate, "TOP", settings.offsetX, settings.offsetY)
		icon:SetColorTexture(1, 0.82, 0, 1)
		icon:Show()

		icon.border:SetSize(size + 3, size + 3)
		icon.border:ClearAllPoints()
		icon.border:SetPoint("CENTER", icon, "CENTER", 0, 0)
		icon.border:Show()
		return
	end

	if not settings.enabled then
		icon:Hide()
		icon.border:Hide()
		return
	end

	local identity = visibleUnits[unit]
	local record = identity and ns.GetPlayerRecord(identity.key, false)
	if not record or not ns.IsNotable(record) then
		icon:Hide()
		icon.border:Hide()
		return
	end

	-- Already visible via your party/raid frames; same reasoning as the Nearby window
	-- excluding partied players from its list.
	if ns.IsPlayerPartied and ns.IsPlayerPartied(identity.key) then
		icon:Hide()
		icon.border:Hide()
		return
	end

	local bracket = ns.GetBracket(record.standing or 0)
	if bracket.index == 0 and settings.hideNeutral then
		icon:Hide()
		icon.border:Hide()
		return
	end

	local size = settings.size
	icon:SetSize(size, size)
	icon:ClearAllPoints()
	icon:SetPoint("BOTTOM", plate, "TOP", settings.offsetX, settings.offsetY)
	icon:SetColorTexture(bracket.color[1], bracket.color[2], bracket.color[3], 1)
	icon:Show()

	icon.border:SetSize(size + 3, size + 3)
	icon.border:ClearAllPoints()
	icon.border:SetPoint("CENTER", icon, "CENTER", 0, 0)
	icon.border:Show()
end

local function clearPlateIcon(unit)
	local plate = unit and C_NamePlate.GetNamePlateForUnit(unit)
	local icon = plate and plateIcons[plate]
	if icon then
		icon:Hide()
		icon.border:Hide()
	end
end

-- re-evaluates every visible plate's icon, for a global change rather than one plate
-- appearing/disappearing
function ns.RefreshNameplateIcons()
	for unit in pairs(visibleUnits) do
		refreshPlateIcon(unit)
	end
end

local function refresh()
	if ns.RefreshNearbyWindow then
		ns.RefreshNearbyWindow()
	end
end

local function updateUnit(unit)
	local identity = ns.IdentifyUnit(unit)
	visibleUnits[unit] = identity

	if identity then
		ns.TouchLastSeen(identity.key)
		-- skips party/raid members, same as the Nearby window/icon: not a real encounter
		-- if you already know they're there. lastSeen still updates, it's not a count
		if not (ns.IsPlayerPartied and ns.IsPlayerPartied(identity.key)) then
			ns.IncrementSeenCount(identity.key)
		end
		-- backfills class/race/faction/GUID for an existing record, e.g. one added by
		-- right-clicking a chat name, where none of that was available yet. only for
		-- players already in the database, not a backdoor always-on auto-add
		if ns.GetPlayerRecord(identity.key, false) then
			ns.TouchIdentity(identity.key, identity)
		end
	end

	-- off by default: logs one bare entry the first time a never-seen player shows up
	-- nearby, so they're searchable later. only fires once since it checks for an
	-- existing record first
	if identity then
		local autoAdd = ns.GetSettings().autoAddNearby
		if autoAdd.enabled and (autoAdd.alsoWhileResting or not IsResting()) then
			if not ns.GetPlayerRecord(identity.key, false) then
				local entry = ns.CaptureContext(unit)
				entry.source = "auto-nearby"
				ns.AddEntry(identity.key, identity, entry)
				if ns.RefreshAllTabs then
					ns.RefreshAllTabs()
				end
			end
		end
	end

	refreshPlateIcon(unit)
	refresh()
end

local function clearUnit(unit)
	if visibleUnits[unit] then
		clearPlateIcon(unit)
		visibleUnits[unit] = nil
		refresh()
	end
end

-- notable players on visible nameplates, deduped by key (plate pooling can leave stale
-- duplicate tokens briefly). a bare auto-nearby entry alone doesn't make someone
-- notable, see ns.IsNotable
function ns.GetNearbyNotablePlayers()
	local seen, results = {}, {}
	for _, identity in pairs(visibleUnits) do
		if identity and not seen[identity.key] then
			seen[identity.key] = true
			local record = ns.GetPlayerRecord(identity.key, false)
			if record and ns.IsNotable(record) then
				results[#results + 1] = { key = identity.key, record = record }
			end
		end
	end
	return results
end

-- nameplate unit token by name, for events that only give a name (RESURRECT_REQUEST
-- etc), not a unit token. see ns.FindLiveUnit, checks this after your target
function ns.FindNameplateUnit(name, realmOrSurname)
	for unit, identity in pairs(visibleUnits) do
		if identity and identity.name == name and (not realmOrSurname or identity.realmOrSurname == realmOrSurname) then
			return unit
		end
	end
	return nil
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
frame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
frame:SetScript("OnEvent", function(_, event, unit)
	if event == "NAME_PLATE_UNIT_ADDED" then
		updateUnit(unit)
	else
		clearUnit(unit)
	end
end)
