local ns = WorthRemembering

local button

-- round vs square minimap (some skins change this). square rides out to the corners,
-- round needs both axes clamped
local function getMinimapShape()
	return GetMinimapShape and GetMinimapShape() or "ROUND"
end

local function updatePosition()
	-- based on actual minimap size, not hardcoded. a fixed radius only fits the
	-- default 140px minimap
	local radius = (Minimap:GetWidth() / 2) + 5
	local angle = math.rad(ns.GetSettings().minimapIcon.angle or 215)
	local x, y = math.cos(angle), math.sin(angle)
	if getMinimapShape() ~= "ROUND" then
		local scale = math.max(math.abs(x), math.abs(y))
		x, y = x / scale, y / scale
	end
	button:ClearAllPoints()
	button:SetPoint("CENTER", Minimap, "CENTER", x * radius, y * radius)
end

local function onDragUpdate(self)
	local mx, my = Minimap:GetCenter()
	local px, py = GetCursorPosition()
	local scale = Minimap:GetEffectiveScale()
	px, py = px / scale, py / scale
	ns.GetSettings().minimapIcon.angle = math.deg(math.atan2(py - my, px - mx))
	updatePosition()
end

local function showTooltip(self)
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:SetText("Worth Remembering")
	GameTooltip:AddLine("Left-click to open", 0.8, 0.8, 0.8)
	GameTooltip:AddLine("Right-click for more options", 0.8, 0.8, 0.8)
	GameTooltip:AddLine("Drag to move", 0.8, 0.8, 0.8)
	GameTooltip:Show()
end

local function showMenu(self)
	MenuUtil.CreateContextMenu(self, function(_, rootDescription)
		rootDescription:CreateTitle("Worth Remembering")
		rootDescription:CreateButton("Open Window", function() ns.ShowOverview() end)
		rootDescription:CreateButton("Options", function() ns.SelectOptionsTab() end)
		rootDescription:CreateDivider()
		rootDescription:CreateButton("Hide Minimap Icon", function() ns.SetMinimapIconShown(false) end)
	end)
end

local function createButton()
	button = CreateFrame("Button", "WRMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	button:RegisterForDrag("LeftButton")

	local overlay = button:CreateTexture(nil, "OVERLAY")
	overlay:SetSize(53, 53)
	overlay:SetPoint("TOPLEFT")
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

	local icon = button:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(20, 20)
	icon:SetPoint("CENTER", 0, 1)
	-- png/tga need the extension, only blp auto-resolves
	icon:SetTexture("Interface\\AddOns\\WorthRemembering\\Media\\MinimapIcon.png")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	button.icon = icon

	button:SetScript("OnEnter", showTooltip)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)
	button:SetScript("OnClick", function(self, mouseButton)
		if mouseButton == "RightButton" then
			showMenu(self)
		else
			ns.ToggleOverview()
		end
	end)
	button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", onDragUpdate) end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)

	updatePosition()
end

-- toggled from Options or the right-click menu. creates the button on first show
-- if it was hidden at login
function ns.SetMinimapIconShown(shown)
	ns.GetSettings().minimapIcon.hide = not shown
	if not button then
		if shown then
			createButton()
		end
		return
	end
	button:SetShown(shown)
end

function ns.EnsureMinimapButton()
	if not button and not ns.GetSettings().minimapIcon.hide then
		createButton()
	end
	return button
end
