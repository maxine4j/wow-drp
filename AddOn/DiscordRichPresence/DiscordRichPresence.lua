-- Config
local maxMsgLen = 900
local events = {}
local msgHeader = "ARW"
local msgFrameCount = floor(maxMsgLen / 3)
local maxMsgLen = msgFrameCount * 3

local size_difficultyID = {
    ["0"] = 0,
    ["1"] = 5,
    ["2"] = 5,
    ["3"] = 10,
    ["4"] = 25,
    ["5"] = 10,
    ["6"] = 25,
    ["7"] = 25,
    ["8"] = 5,
    ["9"] = 40,
    ["10"] = 0,
    ["11"] = 3,
    ["12"] = 3,
    ["13"] = 0,
    ["14"] = 30,
    ["15"] = 30,
    ["16"] = 20,
    ["17"] = 30,
    ["18"] = 0,
    ["19"] = 0,
    ["20"] = 3,
    ["21"] = 0,
    ["22"] = 0,
    ["23"] = 5,
    ["24"] = 5,
    ["25"] = 0,
    ["26"] = 0,
    ["27"] = 0,
    ["28"] = 0,
    ["29"] = 0,
    ["30"] = 0,
    ["31"] = 0,
    ["32"] = 0,
    ["33"] = 5,
    ["34"] = 0,
}

local function Init()
    if not ARWIC_DRP_parent then
        -- Create message frames
        local msgFrames = {}
        local parentFrame = CreateFrame("frame", "ARWIC_DRP_parent", UIParent)
        parentFrame:SetFrameStrata("TOOLTIP")
        parentFrame:SetPoint("TOPLEFT", 0, 0)
        parentFrame:SetPoint("RIGHT", UIParent, "RIGHT")
        --parentFrame:SetWidth(msgFrameCount)
        parentFrame:SetHeight(1)
        parentFrame.texture = parentFrame:CreateTexture(nil, "BACKGROUND")
        parentFrame.texture:SetColorTexture(0, 0, 0, 1)
        parentFrame.texture:SetAllPoints(parentFrame)
        local lastMsgFrame = parentFrame
        for i = 1, msgFrameCount do
            local frame = CreateFrame("frame", "ARWIC_DRP_msg_" .. i, parentFrame)
            frame:SetFrameStrata("TOOLTIP")
            frame:SetPoint("LEFT", lastMsgFrame, "RIGHT")
            frame:SetWidth(1)
            frame:SetHeight(1)
            frame.texture = frame:CreateTexture(nil, "BACKGROUND")
            frame.texture:SetColorTexture(0, 0, 0, 1)
            frame.texture:SetAllPoints(frame)
            table.insert(msgFrames, frame)
            lastMsgFrame = frame
        end
        ARWIC_DRP_msg_1:SetPoint("LEFT", parentFrame, "LEFT")
    end
end

local function EncodeMessage(msg)
    -- Add the header
    msg = msgHeader .. msg
    -- check if the string is too long
    if string.len(msg) > maxMsgLen then
        ARWIC_ERROR_STRING_TOO_LONG()
    end
    -- create the color table
    local colors = {}
    for i = 1, msgFrameCount do
        local col = {}
        table.insert(col, 0)
        table.insert(col, 0)
        table.insert(col, 0)
        table.insert(colors, col)
    end
    -- populate the color table
    for i = 1, string.len(msg) do
        local c = msg:sub(i, i)
        local hueIndex = floor(i / msgFrameCount) + 1
        local frameIndex = i % msgFrameCount + 1
        colors[frameIndex][hueIndex] = string.byte(c) / 255
    end
    -- set the frames colors
    for i = 1, msgFrameCount do
        _G["ARWIC_DRP_msg_" .. i].texture:SetColorTexture(colors[i][1], colors[i][2], colors[i][3], 1)
    end
end

local function SetStatus(status, timeStarted, queuePlayerCount, queuePlayerMax)
    Init()

    if UnitIsAFK("player") then
        status = "<Away> " .. status
    end
    -- basic
    local name = UnitName("player")
    local realm = GetRealmName()
    local level = UnitLevel("player")
    local _, _, class = UnitClass("player")
    local _, race = UnitRace("player")
    -- location
    local mapAreaID = GetCurrentMapAreaID()
    local _, _, difficultyID, _, _, _, _, instanceMapId = GetInstanceInfo()
    local zoneText = GetZoneText()
    local miniMapZoneText = GetMinimapZoneText()
    -- group
    local numGroupMembers = 0
    local maxGroupMembers = 0
    if IsInGroup() then
        if difficultyID == 0 then -- if we arnt in an instance get diff id from the portrait setting
            if IsInRaid() then
                difficultyID = GetRaidDifficultyID()
            else
                difficultyID = GetDungeonDifficultyID()
            end
        end
        maxGroupMembers = size_difficultyID[tostring(difficultyID)]
        numGroupMembers = GetNumGroupMembers()
        if timeStarted and timeStarted ~= -2 then
            numGroupMembers = numGroupMembers + queuePlayerCount
            maxGroupMembers = queuePlayerMax
        elseif timeStarted and timeStarted == -2 then -- -2 means premade group finder
            timeStarted = -1
            numGroupMembers = queuePlayerCount
            maxGroupMembers = queuePlayerMax
        end
        if not maxGroupMembers then maxGroupMembers = 0 end
    end
    -- status
    if not status then status = "In Game" end
    if not timeStarted then timeStarted = -1 end
    local newActivity = Activity:Create(name, realm, class, race, level,
                                  mapAreaID, instanceMapId, zoneText, miniMapZoneText,
                                  numGroupMembers, maxGroupMembers, difficultyID,
                                  status, timeStarted)
    EncodeMessage(newActivity:Serialize())
end

local function UpdateStatus()
    -- Forming a premade group
    local lfgActive, lfgActivityID, lfgILevel, lfgName,
        lfgComment, lfgVoiceChat, lfgExpiration, lfgAutoAccept = C_LFGList.GetActiveEntryInfo()
    if lfgActive then
        local activityFullName, _, _, _, _, _, _, activityMaxPlayers = C_LFGList.GetActivityInfo(lfgActivityID)
        SetStatus(format("In Group: %s", activityFullName), -2, GetNumGroupMembers(), activityMaxPlayers)
        return
    end

    -- Instance status
    local inInstance, instanceType = IsInInstance()
    if inInstance then
        local instName, _, instDifficultyIndex, instDifficultyName = GetInstanceInfo()
        if instanceType == "pvp" then
            local faction = UnitFactionGroup("player")
            local _, _, _, scoreAlli = GetWorldStateUIInfo(1)
            local _, _, _, scoreHorde = GetWorldStateUIInfo(2)
            local score1 = scoreAlli
            local score2 = scoreHorde
            if faction == "Horde" then
                score1 = scoreHorde
                score2 = scoreAlli
            end
            SetStatus(format("In Battleground: %s (%s v %s)", instName, score1, score2))
            return
        elseif instanceType == "arena" then
            local bfStatus, mapName, _, _, _, teamSize = GetBattlefieldStatus(1)
            if bfStatus ~= "active" then
                bfStatus, mapName, _, _, _, teamSize = GetBattlefieldStatus(2)
            end
            SetStatus(format("In Arena: %dv%d %s", teamSize, teamSize, mapName))
            return
        elseif instanceType == "party" then
            SetStatus(format("In Dungeon: %s (%s)", instName, instDifficultyName))
            return
        elseif instanceType == "raid" then
            SetStatus(format("In Raid: %s (%s)", instName, instDifficultyName))
            return
        elseif instanceType == nil then
            SetStatus("In Instance")
            return
        end
    end

    -- LFR status
    local hasData, leaderNeeds, tankNeeds, healerNeeds, dpsNeeds,
    totalTanks, totalHealers, totalDPS, _, _,
    instanceName, averageWait, tankWait, healerWait, damageWait,
    myWait, queuedTime, _ = GetLFGQueueStats(LE_LFG_CATEGORY_RF)
    if hasData then
        local queueCount = (totalTanks - tankNeeds) + (totalHealers - healerNeeds) + (totalDPS - dpsNeeds)
        SetStatus(format("In Queue: %s", instanceName),
            time() - (GetTime() - queuedTime),
            queueCount, 25)
        return
    end

    -- LFD status
    local hasData, leaderNeeds, tankNeeds, healerNeeds, dpsNeeds,
    totalTanks, totalHealers, totalDPS, _, _,
    instanceName, averageWait, tankWait, healerWait, damageWait,
    myWait, queuedTime, _ = GetLFGQueueStats(LE_LFG_CATEGORY_LFD)
    if hasData then
        local queueCount = (totalTanks - tankNeeds) + (totalHealers - healerNeeds) + (totalDPS - dpsNeeds)
        SetStatus(format("In Queue: %s", instanceName),
            time() - (GetTime() - queuedTime),
            queueCount, 5)
        return
    end

    -- bg status
    local timeInQueue1 = GetBattlefieldTimeWaited(1)
    local timeInQueue2 = GetBattlefieldTimeWaited(2)
    local bfStatus1, mapName1 = GetBattlefieldStatus(1)
    local bfStatus2, mapName2 = GetBattlefieldStatus(2)
    -- bg in slot 1 only
    if bfStatus1 == "queued" and bfStatus2 == "none" then
        SetStatus(format("In Queue: %s", mapName1),
            time() - timeInQueue1)
        return
    -- bg in slot 2 only
    elseif bfStatus1 == "none" and bfStatus2 == "queued" then
        SetStatus(format("In Queue: %s", mapName2),
            time() - timeInQueue2)
        return
    -- 2 bgs in both slots
    elseif bfStatus1 == "queued" and bfStatus2 == "queued" then
        local longestTime = timeInQueue1
        if timeInQueue2 > timeInQueue1 then
            longestTime = timeInQueue2
        end
        SetStatus(format("In Queue: %s and %s", mapName1, mapName2),
            time() - longestTime)
        return
    end
    -- resting
    if IsResting() then
        SetStatus("In Town")
        return
    end

    -- default
    SetStatus("In World")
end

function events:PLAYER_ENTERING_WORLD(...)
    UpdateStatus()
end

function events:ZONE_CHANGED_NEW_AREA(...)
    UpdateStatus()
end

function events:SUPER_TRACKED_QUEST_CHANGED(...)
    --UpdateStatus("World Questing")
end

function events:PLAYER_FLAGS_CHANGED(...)
    UpdateStatus()
end

function events:BN_INFO_CHANGED(...)
    UpdateStatus()
end

function events:PLAYER_STARTED_MOVING(...)
    UpdateStatus()
end

function events:LFG_UPDATE(...)
    UpdateStatus()
end

function events:LFG_QUEUE_STATUS_UPDATE(...)
    UpdateStatus()
end

function events:PLAYER_UPDATE_RESTING(...)
    UpdateStatus()
end

function events:LFG_LIST_APPLICANT_LIST_UPDATED(...)
    UpdateStatus()
end

function events:UPDATE_BATTLEFIELD_STATUS(...)
    UpdateStatus()
end

function events:LFG_LIST_APPLICANT_LIST_UPDATED(...)
    UpdateStatus()
end

local function RegisterEvents()
    local eventFrame = CreateFrame("FRAME", "AAM_eventFrame")
    eventFrame:SetScript("OnEvent", function(self, event, ...)
        events[event](self, ...)
    end)
    for k, v in pairs(events) do
        eventFrame:RegisterEvent(k)
    end
    print("DiscordRichPresence: Loaded")
end

RegisterEvents()

SLASH_DRP1 = "/drp"
SlashCmdList["DRP"] = function(msg, editbox)
    status = msg
    UpdateData()
    print("DRP: Updated Status: " .. msg)
end