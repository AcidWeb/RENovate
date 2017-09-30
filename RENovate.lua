local _G = _G
_G.RENovateNamespace = {}
local RE = RENovateNamespace
local LAP = LibStub("LibArtifactPower-1.0")

--GLOBALS: PARENS_TEMPLATE, GARRISON_LONG_MISSION_TIME, GARRISON_LONG_MISSION_TIME_FORMAT, RED_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE, ITEM_LEVEL_ABBR, ORDER_HALL_MISSIONS, ORDER_HALL_FOLLOWERS
local string, tostring, abs, format, tsort, hooksecurefunc, strcmputf8i = _G.string, _G.tostring, _G.abs, _G.format, _G.table.sort, _G.hooksecurefunc, _G.strcmputf8i
local GetTime = _G.GetTime
local CreateFrame = _G.CreateFrame
local HybridScrollFrame_GetOffset = _G.HybridScrollFrame_GetOffset

RE.Version = 100

function RE:OnLoad(self)
	self:RegisterEvent("ADDON_LOADED")
end

function RE:OnEvent(self, event, name)
  if event == "ADDON_LOADED" and name == "RENovate" then
    if not _G.RENovateSettings then
  		_G.RENovateSettings = {["IgnoredMissions"] = {}}
  	end
		RE.Settings = _G.RENovateSettings

    RE.MissionList = _G.OrderHallMissionFrame.MissionTab.MissionList
    RE.OriginalUpdate = RE.MissionList.Update
    hooksecurefunc("Garrison_SortMissions", RE.MissionSort)

    ORDER_HALL_MISSIONS = ORDER_HALL_MISSIONS.." - RENovate "..tostring(RE.Version):gsub(".", "%1."):sub(1,-2)
    ORDER_HALL_FOLLOWERS = ORDER_HALL_FOLLOWERS.." - RENovate "..tostring(RE.Version):gsub(".", "%1."):sub(1,-2)

    function RE.MissionList:Update()
      RE.OriginalUpdate(self)
      RE:MissionUpdate(self)
    end
  end
end

function RE:OnClick(button)
  if button == "RightButton" and not RE.MissionList.showInProgress then
    if RE.Settings.IgnoredMissions[self.info.missionID] then
      RE.Settings.IgnoredMissions[self.info.missionID] = nil
    else
      RE.Settings.IgnoredMissions[self.info.missionID] = true
    end
    RE.MissionList:UpdateMissions()
  else
    _G.GarrisonMissionButton_OnClick(self, button)
  end
end

function RE:ShortValue(v)
	if abs(v) >= 1e9 then
		return format("%.1fG", v / 1e9)
	elseif abs(v) >= 1e6 then
		return format("%.1fM", v / 1e6)
	elseif abs(v) >= 1e3 then
		return format("%.1fk", v / 1e3)
	else
		return format("%d", v)
	end
end

function RE:MissionUpdate(self)
  if not self or not self:IsShown() then return end

  local missions = self.showInProgress and self.inProgressMissions or self.availableMissions
	local buttons = self.listScroll.buttons
	local offset = HybridScrollFrame_GetOffset(self.listScroll)

  for i = 1, #buttons do
    local button = buttons[i]
    local index = offset + i
    if index <= #missions then
      local mission = missions[index]

      if not button.renovate then
        button.renovate = true
        button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
        button:SetScript("OnClick", RE.OnClick)
      end

      if not mission.inProgress then
        if RE.Settings.IgnoredMissions[mission.missionID] then
          button.Overlay.Overlay:SetColorTexture(0, 0, 0, 0.8)
          button.Overlay:Show();
        else
          button.Overlay.Overlay:SetColorTexture(0, 0, 0, 0.4)
          button.Overlay:Hide();
        end

        if mission.offerEndTime then
          local originalText = string.format(PARENS_TEMPLATE, (mission.durationSeconds < GARRISON_LONG_MISSION_TIME) and mission.duration or string.format(GARRISON_LONG_MISSION_TIME_FORMAT, mission.duration))
          local timeRemaining = mission.offerEndTime - GetTime()
          local colorCode, colorCodeEnd = "", ""
          if timeRemaining < 8 * 3600 then
            colorCode, colorCodeEnd = RED_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE
          elseif timeRemaining < 24 * 3600 then
            colorCode, colorCodeEnd = YELLOW_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE
          end
          button.Summary:SetText(originalText.." ("..colorCode..mission.offerTimeRemaining..colorCodeEnd..")")
        end
      end

      button.Level:ClearAllPoints()
      button.Level:SetPoint("CENTER", button, "TOPLEFT", 42, -32)
      button.RareText:Hide()
      if mission.isMaxLevel and mission.iLevel > 0 then
        button.Level:SetText(mission.iLevel)
        button.ItemLevel:SetText(ITEM_LEVEL_ABBR)
      end

      if mission.isRare then
        button.Level:SetTextColor(0.098, 0.537, 0.969, 1.0)
        button.ItemLevel:SetTextColor(0.098, 0.537, 0.969, 1.0)
      else
        button.Level:SetTextColor(0.84, 0.72, 0.57, 1.0)
        button.ItemLevel:SetTextColor(0.84, 0.72, 0.57, 1.0)
      end

      local allRewards = {}
      if mission.overmaxRewards then
        for j = 1, #mission.overmaxRewards do
          allRewards[#allRewards + 1] = mission.overmaxRewards[j]
        end
      end
      if mission.rewards then
        for j = 1, #mission.rewards do
          allRewards[#allRewards + 1] = mission.rewards[j]
        end
      end
      _G.GarrisonMissionButton_SetRewards(button, allRewards, #allRewards)

      for j = 1, #button.Rewards do
        local itemID = button.Rewards[j].itemID
        if itemID and LAP:DoesItemGrantArtifactPower(itemID) then
          button.Rewards[j].Quantity:SetFormattedText("|cffe5cc7f%s|r", RE:ShortValue(LAP:GetArtifactPowerGrantedByItem(itemID)))
          button.Rewards[j].Quantity:Show()
        end
      end
    end
  end
end

function RE:MissionSort()
    if not RE.MissionList:IsVisible() or RE.MissionList.showInProgress then return end
  	tsort(RE.MissionList.availableMissions, function (mission1, mission2)
      if RE.Settings.IgnoredMissions[mission1.missionID] and not RE.Settings.IgnoredMissions[mission2.missionID] then
        return false
      elseif RE.Settings.IgnoredMissions[mission2.missionID] and not RE.Settings.IgnoredMissions[mission1.missionID] then
        return true
      end

      if mission1.isRare ~= mission2.isRare then
      	return mission1.isRare
      end

      if mission1.level ~= mission2.level then
      	return mission1.level > mission2.level
      end

      if mission1.isMaxLevel then
      	if mission1.iLevel ~= mission2.iLevel then
      		return mission1.iLevel > mission2.iLevel
      	end
      end

      if mission1.durationSeconds ~= mission2.durationSeconds then
      	return mission1.durationSeconds < mission2.durationSeconds
      end

      return strcmputf8i(mission1.name, mission2.name) < 0
    end)
end
