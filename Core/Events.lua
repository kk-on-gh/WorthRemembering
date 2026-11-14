local ns = WorthRemembering

local frame = CreateFrame("Frame", "WREventFrame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")

frame:SetScript("OnEvent", function(_, event, loadedAddon)
	if event == "ADDON_LOADED" and loadedAddon == ns.name then
		ns.InitDatabase()
		return
	end

	if event == "PLAYER_LOGIN" then
		local loadedMsg = "loaded. /wr to open the window."
		if not GetBindingKey("WR_QUICKNOTE") then
			loadedMsg = loadedMsg .. " Set a hotkey in Options -> General."
		end
		ns.Print(loadedMsg)
		-- Each pcall'd separately so an error in one (e.g. an unexpected client
		-- difference) can't silently stop the others from ever running.
		local ok, prunedCount = pcall(ns.RunAutoPrune)
		if not ok then
			ns.Print("Auto-prune failed: " .. tostring(prunedCount))
		elseif prunedCount > 0 then
			ns.Print("Auto-pruned " .. prunedCount .. " player record(s).")
		end
		if ns.GetSettings().nearbyWindowEnabled then
			local ok, err = pcall(ns.EnsureNearbyWindow)
			if not ok then
				ns.Print("Nearby window failed to load: " .. tostring(err))
			end
		end
		local ok, err = pcall(ns.EnsureMinimapButton)
		if not ok then
			ns.Print("Minimap button failed to load: " .. tostring(err))
		end

		-- recorded even when the option is off, so turning it back on only affects
		-- future versions
		local version = ns.GetAddonVersion()
		local lastSeen = ns.GetLastSeenVersion()
		if version and version ~= lastSeen then
			-- nil on a fresh install, so the About tab only expands what's actually new
			ns.UpdatedFromVersion = lastSeen
			ns.SetLastSeenVersion(version)
			if lastSeen == nil and #ns.GetAllPlayerKeys() == 0 then
				ns.EnsureDemoPlayer()
				C_Timer.After(2, function()
					StaticPopup_Show("WR_TOUR_OFFER")
				end)
			elseif ns.GetSettings().showPatchNotesOnUpdate then
				C_Timer.After(1, function()
					local shown, showErr = pcall(ns.SelectAboutTab)
					if not shown then
						ns.Print("Patch notes failed to open: " .. tostring(showErr))
					end
				end)
			end
		end
	end
end)
