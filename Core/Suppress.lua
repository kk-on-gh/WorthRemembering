local ns = WorthRemembering

-- Disabling Worth Remembering, entirely or while in chosen kinds of place
-- (settings.disable). While disabled nothing runs on its own: gated frames stop
-- listening, hooks bail out on ns.IsSuppressed(). /wr and the minimap button still work.

local suppressed, reason = false, nil
local ready = false
local gated = {}
local listeners = {}

-- IsInInstance() type -> the phrase after "disabled while"
local PLACES = {
	party = "in a dungeon",
	raid = "in a raid",
	pvp = "in a battleground",
	arena = "in an arena",
	scenario = "in a delve or scenario",
}

-- zone changes stay registered while disabled, so the next one can turn things back on
local TRANSITIONS = { PLAYER_ENTERING_WORLD = true, ZONE_CHANGED_NEW_AREA = true }

function ns.IsSuppressed()
	return suppressed
end

-- "entirely", "in a battleground", "resting", or nil while enabled
function ns.SuppressionReason()
	return reason
end

-- "Worth Remembering is disabled while in a battleground."
function ns.SuppressionText()
	if not reason then
		return nil
	end
	if reason == "entirely" then
		return "Worth Remembering is disabled."
	end
	return "Worth Remembering is disabled while " .. reason .. "."
end

local function register(frame, spec)
	if spec.unit then
		frame:RegisterUnitEvent(spec.event, spec.unit)
	elseif spec.optional then
		pcall(frame.RegisterEvent, frame, spec.event)
	else
		frame:RegisterEvent(spec.event)
	end
end

local function listen(frame, on)
	for _, spec in ipairs(gated[frame]) do
		if on then
			register(frame, spec)
		elseif not TRANSITIONS[spec.event] then
			frame:UnregisterEvent(spec.event)
		end
	end
end

-- registers `events` (names, or { name, unit }) and `handler` on frame. While disabled
-- the events are unregistered and the handler doesn't run. A zone change re-checks
-- first, so a disabled place never sees its own entering event. optional: events the
-- client may not have, registered through pcall.
function ns.GateEvents(frame, events, handler, optional)
	local specs = {}
	for i, event in ipairs(events) do
		specs[i] = type(event) == "table" and { event = event[1], unit = event[2] } or { event = event }
		specs[i].optional = optional
		register(frame, specs[i])
	end
	gated[frame] = specs
	frame:SetScript("OnEvent", function(self, event, ...)
		if TRANSITIONS[event] then
			ns.EvaluateSuppression()
		end
		if suppressed then
			return
		end
		return handler(self, event, ...)
	end)
	if suppressed then
		listen(frame, false)
	end
end

-- fn(suppressed, stateChanged): on every change of state or reason
function ns.OnSuppressionChanged(fn)
	listeners[#listeners + 1] = fn
end

local function compute()
	local disable = ns.GetSettings().disable
	if disable.all then
		return "entirely"
	end
	local inInstance, kind = IsInInstance()
	if inInstance and disable[kind] and PLACES[kind] then
		return PLACES[kind]
	end
	if disable.resting and IsResting() then
		return "resting"
	end
	return nil
end

function ns.EvaluateSuppression()
	if not ready then
		return
	end
	local newReason = compute()
	local now = newReason ~= nil
	if newReason == reason and now == suppressed then
		return
	end
	local stateChanged = now ~= suppressed
	suppressed, reason = now, newReason
	if stateChanged then
		for frame in pairs(gated) do
			listen(frame, not now)
		end
	end
	for _, fn in ipairs(listeners) do
		local ok, err = pcall(fn, now, stateChanged)
		if not ok then
			geterrorhandler()(err)
		end
	end
end

-- once SavedVariables are in
function ns.StartSuppression()
	ready = true
	ns.EvaluateSuppression()
end

-- for a recent-allies completion kind ("dungeon", "raidBoss", ...): whether its place is
-- disabled, so a later batch skips it wherever you are by then
local ALLY_PLACES = { dungeon = "party", raidBoss = "raid", battleground = "pvp", arena = "arena", delve = "scenario" }

function ns.IsAllyKindDisabled(typeKey)
	local place = ALLY_PLACES[typeKey]
	return place ~= nil and ns.GetSettings().disable[place] == true
end

-- one chat line per disabled stretch, for a hotkey or macro pressed while disabled
local notified = false

function ns.NotifySuppressed()
	if notified then
		return
	end
	notified = true
	ns.Print(ns.SuppressionText() .. " /wr to change that.")
end

ns.OnSuppressionChanged(function(now, stateChanged)
	if stateChanged and not now then
		notified = false
	end
end)

-- turns "entirely" on or off. Turning it off skips recent allies met meanwhile
function ns.SetDisabledEntirely(on)
	local disable = ns.GetSettings().disable
	if disable.all and not on and ns.ResetRecentAlliesWatermark then
		ns.ResetRecentAlliesWatermark()
	end
	disable.all = on and true or false
	ns.EvaluateSuppression()
end

function ns.SetDisabledWhile(place, on)
	ns.GetSettings().disable[place] = on and true or false
	ns.EvaluateSuppression()
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_ENTERING_WORLD")
frame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
frame:RegisterEvent("PLAYER_UPDATE_RESTING")
frame:SetScript("OnEvent", function()
	ns.EvaluateSuppression()
end)
