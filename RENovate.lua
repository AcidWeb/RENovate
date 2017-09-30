local _G = _G
_G.RENovateNamespace = {}
local RE = RENovateNamespace
local LAP = LibStub("LibArtifactPower-1.0")

--GLOBALS: PARENS_TEMPLATE, GARRISON_LONG_MISSION_TIME, GARRISON_LONG_MISSION_TIME_FORMAT, RED_FONT_COLOR_CODE, YELLOW_FONT_COLOR_CODE, FONT_COLOR_CODE_CLOSE, ITEM_LEVEL_ABBR, ORDER_HALL_MISSIONS, ORDER_HALL_FOLLOWERS
local string, tostring, abs, format = _G.string, _G.tostring, _G.abs, _G.format
local GetTime = _G.GetTime
local CreateFrame = _G.CreateFrame
local HybridScrollFrame_GetOffset = _G.HybridScrollFrame_GetOffset

RE.Version = 100

function RE:OnLoad(self)
	self:RegisterEvent("ADDON_LOADED")
end

function RE:OnEvent(self, event, name)
  if event == "ADDON_LOADED" and name == "RENovate" then
    local missionList = _G.OrderHallMissionFrame.MissionTab.MissionList
    local originalUpdate = missionList.Update

    ORDER_HALL_MISSIONS = ORDER_HALL_MISSIONS.." - RENovate "..tostring(RE.Version):gsub(".", "%1."):sub(1,-2)
    ORDER_HALL_FOLLOWERS = ORDER_HALL_FOLLOWERS.." - RENovate "..tostring(RE.Version):gsub(".", "%1."):sub(1,-2)

    function missionList:Update()
      originalUpdate(self)
      RE:MissionUpdate(self)
    end
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

      if not mission.inProgress and mission.offerEndTime then
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
