local _G = _G
local _, RE = ...
local L = LibStub("AceLocale-3.0"):GetLocale("RENovate")
local LAD = LibStub("LibArtifactData-1.0")
_G.RENovate = RE

--GLOBALS: SLASH_RENOVATE1, LE_GARRISON_TYPE_7_0, LE_FOLLOWER_TYPE_GARRISON_7_0, GARRISON_LONG_MISSION_TIME, GARRISON_LONG_MISSION_TIME_FORMAT, ITEM_LEVEL_ABBR, ORDER_HALL_MISSIONS, ORDER_HALL_FOLLOWERS, WINTERGRASP_IN_PROGRESS, GARRISON_MISSION_ADDED_TOAST1, BONUS_ROLL_REWARD_MONEY, XP, ARTIFACT_POWER, OTHER, Fancy18Font, Game13Font, Game13FontShadow
local string, tostring, abs, format, tsort, strcmputf8i, select, pairs, hooksecurefunc, floor, print, collectgarbage, type, getmetatable, setmetatable = _G.string, _G.tostring, _G.abs, _G.format, _G.table.sort, _G.strcmputf8i, _G.select, _G.pairs, _G.hooksecurefunc, _G.floor, _G.print, _G.collectgarbage, _G.type, _G.getmetatable, _G.setmetatable
local GetCVar = _G.GetCVar
local GetTime = _G.GetTime
local GetItemInfo = _G.GetItemInfo
local GetCurrencyLink = _G.GetCurrencyLink
local GetLandingPageGarrisonType = _G.C_Garrison.GetLandingPageGarrisonType
local GetAvailableMissions = _G.C_Garrison.GetAvailableMissions
local GetMissionInfo = _G.C_Garrison.GetMissionInfo
local GetMissionLink = _G.C_Garrison.GetMissionLink
local GetMissionCost = _G.C_Garrison.GetMissionCost
local GetPartyMissionInfo = _G.C_Garrison.GetPartyMissionInfo
local GetFollowers = _G.C_Garrison.GetFollowers
local GetFollowerAbilities = _G.C_Garrison.GetFollowerAbilities
local GetFollowerAbilityCountersForMechanicTypes = _G.C_Garrison.GetFollowerAbilityCountersForMechanicTypes
local IsArtifactPowerItem = _G.IsArtifactPowerItem
local AddFollowerToMission = _G.C_Garrison.AddFollowerToMission
local RemoveFollowerFromMission = _G.C_Garrison.RemoveFollowerFromMission
local CreateFrame = _G.CreateFrame
local PlaySound = _G.PlaySound
local ReloadUI = _G.ReloadUI
local InterfaceOptionsFrame_OpenToCategory = _G.InterfaceOptionsFrame_OpenToCategory
local HybridScrollFrame_GetOffset = _G.HybridScrollFrame_GetOffset
local Timer = _G.C_Timer
local ElvUI = _G.ElvUI

RE.Version = 148
RE.ParsingInProgress = false
RE.ItemNeeded = false
RE.ThreatAnchors = {"LEFT", "CENTER", "RIGHT"}
RE.RewardCache = {}
RE.MissionCache = {}
RE.MissionCurrentCache = {}
RE.FollowersChanceCache = {}
RE.UpdateTimer = -1
RE.PlayerZone = GetCVar("portal")
SLASH_RENOVATE1 = "/renovate"

RE.DefaultSettings = {["IgnoredMissions"] = {}, ["ImprovedFollowerPanel"] = true, ["NewMissionNotification"] = true, ["DisplayMissionCost"] = false, ["CountUnavailableFollowers"] = false}
RE.AceConfig = {
	type = "group",
	args = {
		MissionListOptions = {
			name = L["Mission list"],
			type = "group",
			order = 1,
			args = {
				DisplayMissionCost = {
					name = L["Display mission cost"],
					type = "toggle",
					width = "full",
					order = 1,
					set = function(_, val) RE.Settings.DisplayMissionCost = val end,
					get = function(_) return RE.Settings.DisplayMissionCost end
				},
			},
		},
		MissionDispatchOptions = {
			name = L["Mission dispatch"],
			type = "group",
			order = 2,
			args = {
				ImprovedFollowerPanel = {
					name = L["Use improved follower panel"],
					desc = L["Display impact that follower have on mission chance and some other additional information."],
					descStyle = "inline",
					type = "toggle",
					width = "full",
					order = 1,
					set = function(_, val) RE.Settings.ImprovedFollowerPanel = val; ReloadUI() end,
					get = function(_) return RE.Settings.ImprovedFollowerPanel end
				},
				CountUnavailableFollowers = {
					name = L["Calculate impact for unavailable followers"],
					type = "toggle",
					width = "full",
					order = 2,
					disabled = true,
					--disabled = function(_) return not RE.Settings.ImprovedFollowerPanel end,
					set = function(_, val) RE.Settings.CountUnavailableFollowers = val end,
					get = function(_) return RE.Settings.CountUnavailableFollowers end
				},
			}
		},
		OtherOptions = {
			name = OTHER,
			type = "group",
			order = 3,
			args = {
				NewMissionNotification = {
					name = L["Display notifications about new missions"],
					type = "toggle",
					width = "full",
					order = 1,
					set = function(_, val) RE.Settings.NewMissionNotification = val; ReloadUI() end,
					get = function(_) return RE.Settings.NewMissionNotification end
				},
			},
		},
	}
}

-- Event functions

function RE:OnLoad(self)
	self:RegisterEvent("ADDON_LOADED")
end

function RE:OnEvent(self, event, name)
	if event == "ADDON_LOADED" and name == "RENovate" then
		if not _G.RENovateSettings then _G.RENovateSettings = RE.DefaultSettings end
		RE.Settings = _G.RENovateSettings
		for key, value in pairs(RE.DefaultSettings) do
			if RE.Settings[key] == nil then
				RE.Settings[key] = value
			end
		end
		RE.Settings.CountUnavailableFollowers = false
		_G.SlashCmdList["RENOVATE"] = function() _G.InterfaceOptionsFrame:Show(); InterfaceOptionsFrame_OpenToCategory(RE.OptionsMenu) end
		_G.LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("RENovate", RE.AceConfig)
		RE.OptionsMenu = _G.LibStub("AceConfigDialog-3.0"):AddToBlizOptions("RENovate", "RENovate")
		if RE.Settings.NewMissionNotification then
			self:RegisterEvent("GET_ITEM_INFO_RECEIVED")
			RE.AlertSystem = _G.AlertFrame:AddQueuedAlertFrameSubSystem("GarrisonRandomMissionAlertFrameTemplate", _G.RENovateAlertSystemTemplate, 1, 0)
			RE:FillMissionCache()
		end
		if RE.Settings.ImprovedFollowerPanel then
			self:RegisterEvent("GARRISON_FOLLOWER_LIST_UPDATE")
		end
		LAD:ForceUpdate()
		Timer.NewTicker(5, function() _, RE.AK = LAD:GetArtifactKnowledge() end)
	elseif event == "ADDON_LOADED" and name == "Blizzard_OrderHallUI" then
		RE.F = _G.OrderHallMissionFrame
		RE.FF = _G.OrderHallMissionFrameFollowers
		RE.MissionList = RE.F.MissionTab.MissionList
		RE.MissionPage = RE.F.MissionTab.MissionPage
		RE.OriginalUpdate = RE.MissionList.Update
		RE.OriginalUpdateFollowers = RE.FF.UpdateData
		RE.OriginalTooltip = _G.GarrisonMissionList_UpdateMouseOverTooltip
		RE.OriginalSort = _G.Garrison_SortMissions

		ORDER_HALL_MISSIONS = ORDER_HALL_MISSIONS.." - RENovate "..tostring(RE.Version):gsub(".", "%1."):sub(1,-2)
		ORDER_HALL_FOLLOWERS = ORDER_HALL_FOLLOWERS.." - RENovate "..tostring(RE.Version):gsub(".", "%1."):sub(1,-2)

		-- Refresh team data when mission is opened
		if RE.Settings.ImprovedFollowerPanel then
			hooksecurefunc("GarrisonMissionButton_OnClick", function() RE:OnEvent(nil, "GARRISON_FOLLOWER_LIST_UPDATE") end)
		end

		-- Force refresh of "In Progress" tab when needed
		hooksecurefunc("GarrisonMissionListTab_SetTab", function() RE.UpdateTimer = -1 end)
		RE.MissionList:HookScript("OnHide", function() RE.UpdateTimer = -1 end)

		-- Replaced original OnUpdate to implement throttling and "In Progress" sorting
		RE.MissionList:SetScript("OnUpdate", function (self, elapsed)
			if RE.UpdateTimer < 0 then
				if self.showInProgress then
					_G.C_Garrison.GetInProgressMissions(self.inProgressMissions, RE.F.followerTypeID)
					RE.MissionSortInProgress()
					self.Tab2:SetText(WINTERGRASP_IN_PROGRESS.." - "..#self.inProgressMissions)
					self:Update()
				else
					local timeNow = GetTime()
					for i = 1, #self.availableMissions do
						if self.availableMissions[i].offerEndTime and self.availableMissions[i].offerEndTime <= timeNow then
							self:UpdateMissions()
							break
						end
					end
				end
				self:UpdateCombatAllyMission()
				RE.UpdateTimer = 10
			else
				RE.UpdateTimer = RE.UpdateTimer - elapsed
			end
		end)

		-- Pre-hook to inject button skinning function
		function RE.MissionList:Update()
			RE.OriginalUpdate(self)
			RE:MissionUpdate(self)
		end
		if RE.Settings.ImprovedFollowerPanel then
			function RE.FF:UpdateData()
				RE.OriginalUpdateFollowers(self)
				RE:FollowerUpdate(self)
			end
		end

		-- Pre-hook to disable tooltips in Order Hall mission table
		function _G.GarrisonMissionList_UpdateMouseOverTooltip(self)
			if not RE.F:IsShown() then
				RE.OriginalTooltip(self)
			end
		end

		-- Pre-hook to inject available missions sorting function
		function _G.Garrison_SortMissions(missionsList)
			if not RE.F:IsShown() then
				RE.OriginalSort(missionsList)
			else
				RE.MissionSort()
			end
		end

		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "GARRISON_FOLLOWER_LIST_UPDATE" and RE.MissionPage and RE.MissionPage:IsShown() and not RE.ParsingInProgress then
		RE.ParsingInProgress = true
		RE:GetMissionChance()
		collectgarbage()
		RE.ParsingInProgress = false
	elseif event == "GET_ITEM_INFO_RECEIVED" and RE.ItemNeeded then
		RE.ItemNeeded = false
		RE:CheckNewMissions()
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

-- Mission functions

function RE:GetMissionThreats(missionID, parentFrame)
	if not RE.F.abilityCountersForMechanicTypes then
		RE.F.abilityCountersForMechanicTypes = GetFollowerAbilityCountersForMechanicTypes(RE.F.followerTypeID)
	end

	local enemies = select(8, GetMissionInfo(missionID))
	local counterableThreats = _G.GarrisonMission_DetermineCounterableThreats(missionID, RE.F.followerTypeID)
	local numThreats = 0

	for i = 1, 3 do
		parentFrame.Threat[i]:Hide()
	end
	for i = 1, #enemies do
		local enemy = enemies[i]
		for mechanicID, _ in pairs(enemy.mechanics) do
			numThreats = numThreats + 1
			local threatFrame = parentFrame.Threat[numThreats]
			local ability = RE.F.abilityCountersForMechanicTypes[mechanicID]
			threatFrame.Border:SetShown(_G.ShouldShowFollowerAbilityBorder(RE.F.followerTypeID, ability))
			threatFrame.Icon:SetTexture(ability.icon)
			threatFrame:Show()
			_G.GarrisonMissionButton_CheckTooltipThreat(threatFrame, missionID, mechanicID, counterableThreats)
		end
	end
end

function RE:GetMissionCounteredThreats(followersOrg, enemies, newFollower)
	local followers = RE:CopyTable(followersOrg)
	local alreadyCountered = {}
	local countered = 0

	if newFollower then
		for i=1, #followers do
			if not followers[i].info then
				followers[i].info = newFollower
				break
			end
		end
	end

	for i = 1, #followers do
		local follower = followers[i]
		if follower.info then
			local abilities = GetFollowerAbilities(follower.info.followerID)
			for a = 1, #abilities do
				for counterID, _ in pairs(abilities[a].counters) do
					for i = 1, #enemies do
						local enemy = enemies[i]
						for mechanicIndex = 1, #enemy.Mechanics do
							if not alreadyCountered[i] then alreadyCountered[i] = {} end
							if counterID == enemy.Mechanics[mechanicIndex].mechanicID and not alreadyCountered[i][mechanicIndex] then
								alreadyCountered[i][mechanicIndex] = true
								countered = countered + 1
							end
						end
					end
				end
			end
		end
	end
	return countered
end

function RE:GetMissonSlowdown(missionID)
	local enemies = select(8, GetMissionInfo(missionID))
	local slowicons = " "
	for i = 1, #enemies do
		local enemy = enemies[i]
		for _, mechanic in pairs(enemy.mechanics) do
			if mechanic.ability and mechanic.ability.id == 428 then
				slowicons = slowicons.."|TInterface\\Garrison\\orderhall-missions-mechanic5:0|t"
			end
		end
	end
	if #slowicons == 1 then
		return ""
	else
		return slowicons
	end
end

function RE:GetMissionChance()
	local followers = GetFollowers(RE.F.followerTypeID)
	local missionID = RE.MissionPage.missionInfo.missionID

	if RE:CheckIfMissionIsFull(RE.MissionPage) then
		RE.FollowersChanceCache = {}
		return
	end

	local _, totalTimeSecondsOld, _, successChanceOld = GetPartyMissionInfo(missionID)
	local mechanicCounteredOld = RE:GetMissionCounteredThreats(RE.MissionPage.Followers, RE.MissionPage.Enemies)
	local _, costOld = GetMissionCost(missionID)

	for i=1, #followers do
		local follower = followers[i]
		if RE:CheckIfFollowerIsFree(follower) then
			AddFollowerToMission(missionID, follower.followerID)
			local _, totalTimeSeconds, _, successChance = GetPartyMissionInfo(missionID)
			local mechanicCountered = RE:GetMissionCounteredThreats(RE.MissionPage.Followers, RE.MissionPage.Enemies, follower)
			local _, cost = GetMissionCost(missionID)
			RE.FollowersChanceCache[follower.followerID] = {totalTimeSeconds < totalTimeSecondsOld, successChance - successChanceOld, mechanicCountered > mechanicCounteredOld, cost < costOld}
			RemoveFollowerFromMission(missionID, follower.followerID)
		end
	end
end

-- New mission tracking functions

function RE:CheckNewMissions()
	GetAvailableMissions(RE.MissionCache, LE_FOLLOWER_TYPE_GARRISON_7_0)
	for i=1, #RE.MissionCache do
		if RE.MissionCurrentCache[RE.MissionCache[i].missionID] == nil and not RE.Settings.IgnoredMissions[RE.MissionCache[i].missionID] then
			RE:PrintNewMission(i)
		end
	end
end

function RE:PrintNewMission(mission)
	local ms = "|cFF74D06C[RENovate]|r |cFFFF0000"..GARRISON_MISSION_ADDED_TOAST1.."!|r - "..GetMissionLink(RE.MissionCache[mission].missionID)

	local rewards = RE:GetRewardCache(RE.MissionCache[mission])
	for i=1, #rewards do
		local reward = rewards[i]
		local link = ""
		if reward.itemID and reward.itemID ~= 0 then
			link = select(2, GetItemInfo(reward.itemID))
			if not link then
				RE.ItemNeeded = true
				return
			end
			ms = ms.."|n"..reward.quantity.."x "..link
			if IsArtifactPowerItem(reward.itemID) then
				ms = ms.." |cFFE5CC7F"..RE:ShortValue(LAD:GetArtifactPowerFromItem(reward.itemID) * RE.AK).." "..ARTIFACT_POWER.."|r"
			end
		elseif reward.currencyID then
			if reward.currencyID ~= 0 then
				link = GetCurrencyLink(reward.currencyID)
				if not link then
					RE.ItemNeeded = true
					return
				end
				ms = ms.."|n"..reward.quantity.."x "..link
			else
				ms = ms.."|n|cFFCC9900"..floor(reward.quantity / 10000).." "..BONUS_ROLL_REWARD_MONEY.."|r"
			end
		elseif reward.followerXP then
			ms = ms.."|n|cFFE6CC80"..reward.followerXP.." "..XP.."|r"
		end
	end

	print(ms)
	RE.AlertSystem:AddAlert(RE.MissionCache[mission])
	RE.MissionCurrentCache[RE.MissionCache[mission].missionID] = true
end

-- Skinning functions

function RE:FollowerUpdate(self)
	if not RE.FF or not RE.FF:IsShown() then return end

	local followers = self.followers
	local buttons = self.listScroll.buttons
	local offset = HybridScrollFrame_GetOffset(self.listScroll)

	for i = 1, #buttons do
		local button = buttons[i]
		local index = offset + i
		if index <= #followers and button.mode == "FOLLOWER" then
			button = button.Follower
			if not button.Renovate then
				button.Renovate = true
				button.PortraitFrame.Chance = button.PortraitFrame:CreateFontString()
				button.PortraitFrame.Chance:SetPoint("CENTER")
				button.PortraitFrame.Chance:SetFontObject(Game13FontShadow)
				button.PortraitFrame.ChanceBG = button.PortraitFrame:CreateTexture()
				button.PortraitFrame.ChanceBG:SetPoint("TOPLEFT", button.PortraitFrame.Chance)
				button.PortraitFrame.ChanceBG:SetPoint("BOTTOMRIGHT", button.PortraitFrame.Chance)
				button.PortraitFrame.ChanceBG:SetColorTexture(0, 0, 0, 0.75)
			end
			if RE.FollowersChanceCache[button.id] and RE:CheckIfFollowerIsFree(button.info) then
				local status = ""
				if RE.FollowersChanceCache[button.id][3] then
					status = "|cFF00FF00"
				else
					status = "|cFFFFFFFF"
				end
				if RE.FollowersChanceCache[button.id][2] > 0 then
					status = status.."+"..RE.FollowersChanceCache[button.id][2].."%|r"
				else
					status = status..RE.FollowersChanceCache[button.id][2].."%|r"
				end
				local prefix = "|n"
				if RE.FollowersChanceCache[button.id][1] then
					status = status..prefix.."-|TInterface\\Garrison\\orderhall-missions-mechanic5:0|t"
					prefix = " "
				end
				if RE.FollowersChanceCache[button.id][4] then
					status = status..prefix.."- |TInterface\\Icons\\INV_OrderHall_OrderResources:0|t"
				end
				button.PortraitFrame.ChanceBG:Show()
				button.PortraitFrame.Chance:SetText(status)
			else
				button.PortraitFrame.ChanceBG:Hide()
				button.PortraitFrame.Chance:SetText("")
			end
		end
	end
end

function RE:MissionUpdate(self)
	if not RE.F or not RE.F:IsShown() then return end

	local missions = self.showInProgress and self.inProgressMissions or self.availableMissions
	local buttons = self.listScroll.buttons
	local offset = HybridScrollFrame_GetOffset(self.listScroll)

	for i = 1, #buttons do
		local button = buttons[i]
		local index = offset + i
		if index <= #missions then
			local mission = missions[index]

			if not button.Renovate then
				button.Renovate = true
				button:RegisterForClicks("LeftButtonUp", "RightButtonUp")
				button:SetScript("OnClick", RE.OnClick)
				button:SetScript("OnEnter", nil)
				button:SetScript("OnLeave", nil)
				if ElvUI then
					ElvUI[1]:GetModule("Skins"):HandleButton(button)
				else
					button.Title:SetFontObject(Fancy18Font)
					button.Summary:SetFontObject(Game13Font)
				end
				button.Threats = CreateFrame("Frame", nil, button)
				button.Threats:SetPoint("RIGHT", button, "RIGHT", -145, 0)
				button.Threats:SetWidth(80)
				button.Threats:SetHeight(30)
				button.Threats.Threat = {[1] = CreateFrame("Frame", nil, button.Threats, "GarrisonAbilityCounterWithCheckTemplate"),
				[2] = CreateFrame("Frame", nil, button.Threats, "GarrisonAbilityCounterWithCheckTemplate"),
				[3] = CreateFrame("Frame", nil, button.Threats, "GarrisonAbilityCounterWithCheckTemplate")}
				for i = 1, 3 do
					button.Threats.Threat[i]:SetPoint(RE.ThreatAnchors[i])
				end
			end

			if not mission.inProgress then
				if RE.Settings.IgnoredMissions[mission.missionID] then
					button.Overlay.Overlay:SetColorTexture(0, 0, 0, 0.8)
					button.Overlay:Show()
					button.Threats:Hide()
				else
					button.Overlay.Overlay:SetColorTexture(0, 0, 0, 0.4)
					button.Overlay:Hide()
					RE:GetMissionThreats(mission.missionID, button.Threats)
					button.Threats:Show()
				end

				local originalText = (mission.durationSeconds < GARRISON_LONG_MISSION_TIME) and mission.duration or string.format(GARRISON_LONG_MISSION_TIME_FORMAT, mission.duration)
				local additionalText = ""
				if RE.Settings.DisplayMissionCost then
					additionalText = " / |cFFFFFFFF"..mission.cost.."|r |TInterface\\Icons\\INV_OrderHall_OrderResources:0|t"
				end
				if mission.offerEndTime then
					local timeRemaining = mission.offerEndTime - GetTime()
					local colorCode, colorCodeEnd = "", ""
					if timeRemaining < 8 * 3600 then
						colorCode, colorCodeEnd = "|cFFFF2020", "|r"
					elseif timeRemaining < 24 * 3600 then
						colorCode, colorCodeEnd = "|cFFFFFF00", "|r"
					end
					button.Summary:SetText(originalText..RE:GetMissonSlowdown(mission.missionID).." / "..colorCode..mission.offerTimeRemaining..colorCodeEnd..additionalText)
				else
					button.Summary:SetText(originalText..RE:GetMissonSlowdown(mission.missionID)..additionalText)
				end
			else
				button.Overlay.Overlay:SetColorTexture(0, 0, 0, 0.4)
				button.Overlay:Show()
				button.Threats:Hide()
			end

			button.Summary:ClearAllPoints()
			if ElvUI then
				button.Summary:SetPoint("BOTTOMLEFT", button.Title, "BOTTOMRIGHT", 5, 3)
			else
				button.Summary:SetPoint("BOTTOMLEFT", button.Title, "BOTTOMRIGHT", 5, 1)
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

			local rewards = RE:GetRewardCache(mission)
			_G.GarrisonMissionButton_SetRewards(button, rewards, #rewards)

			for j = 1, #button.Rewards do
				local itemID = button.Rewards[j].itemID
				if itemID and IsArtifactPowerItem(itemID) then
					button.Rewards[j].Quantity:SetFormattedText("|cFFE5CC7F%s|r", RE:ShortValue(LAD:GetArtifactPowerFromItem(itemID) * RE.AK))
					button.Rewards[j].Quantity:Show()
				end
			end
		end
	end
end

-- Sorting functions

function RE:MissionSort()
	if RE.MissionList.showInProgress then return end

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

function RE:MissionSortInProgress()
	if not RE.MissionList.showInProgress then return end

	tsort(RE.MissionList.inProgressMissions, function (mission1, mission2)
		if mission1.timeLeftSeconds ~= mission2.timeLeftSeconds then
			return mission1.timeLeftSeconds < mission2.timeLeftSeconds
		end

		return strcmputf8i(mission1.name, mission2.name) < 0
	end)
end

-- Support functions

function RE:CheckIfMissionIsFull(missionTab)
	local followersNeeded = missionTab.missionInfo.numFollowers
	local followersInParty = 0

	for i=1, #missionTab.Followers do
		if missionTab.Followers[i].info then
			followersInParty = followersInParty + 1
		end
	end

	return followersNeeded == followersInParty
end

function RE:CheckIfFollowerIsFree(follower)
	if not follower.isCollected then
		return false
	elseif not follower.status or RE.Settings.CountUnavailableFollowers then
		return true
	else
		return false
	end
end

function RE:FillMissionCache()
	if not GetLandingPageGarrisonType() == LE_GARRISON_TYPE_7_0 then return end
	GetAvailableMissions(RE.MissionCache, LE_FOLLOWER_TYPE_GARRISON_7_0)
	if #RE.MissionCache == 0 then
		Timer.After(30, RE.FillMissionCache)
		return
	end
	for i=1, #RE.MissionCache do
		RE.MissionCurrentCache[RE.MissionCache[i].missionID] = true
	end
	Timer.NewTicker(60, RE.CheckNewMissions)
end

function RE:GetRewardCache(mission)
	if not RE.RewardCache[mission.missionID] then
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
		RE.RewardCache[mission.missionID] = allRewards
	end
	return RE.RewardCache[mission.missionID]
end

function RE:ShortValue(v)
	if RE.PlayerZone == "US" then
		if abs(v) >= 1e9 then
			return format("%.2fG", v / 1e9)
		elseif abs(v) >= 1e6 then
			return format("%.0fM", v / 1e6)
		elseif abs(v) >= 1e3 then
			return format("%.0fk", v / 1e3)
		else
			return format("%d", v)
		end
	else
		if abs(v) >= 1e9 then
			return format("%.2fB", v / 1e9)
		elseif abs(v) >= 1e6 then
			return format("%.0fM", v / 1e6)
		elseif abs(v) >= 1e3 then
			return format("%.0fK", v / 1e3)
		else
			return format("%d", v)
		end
	end
end

function RE:CopyTable(t)
	if type(t) ~= "table" then return t end
	local meta = getmetatable(t)
	local target = {}
	for k, v in pairs(t) do
		if type(v) == "table" then
			target[k] = RE:CopyTable(v)
		else
			target[k] = v
		end
	end
	setmetatable(target, meta)
	return target
end

function _G.RENovateAlertSystemTemplate(frame, _)
	frame.Rare:Hide()
	PlaySound(44294)
end
