-- Config
local maxMsgLen = 900
local events = {}
local msgHeader = "ARW"
local msgFrameCount = floor(maxMsgLen / 3)
local maxMsgLen = msgFrameCount * 3
local activityHistory = Stack:Create()
local lastIsQueue = false

function ARW_dump()
    activityHistory:list()
end

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

local function UpdateData(status, timeStarted)

end

local function SetStatus(isQueue, status, timeStarted)
    Init()

    if UnitIsAFK("player") then
        status = "<Away> " .. status
    end
    -- basic
    local _, _, class = UnitClass("player")
    local _, race = UnitRace("player")
    -- location
    local mapAreaID = GetCurrentMapAreaID()
    local _, _, _, _, _, _, _, instanceMapId = GetInstanceInfo()
    -- group
    local inRaidGroup = 0
    if IsInRaid() then inRaidGroup = 1 end
    -- status
    if not status then status = "In Game" end
    if not timeStarted then timeStarted = -1 end

    local newActivity
    if not isQueue and lastIsQueue then
        newActivity = activityHistory:pop()
    else
        newActivity = Activity:Create(UnitName("player"), GetRealmName(), class, race, UnitLevel("player"),
                                        mapAreaID, instanceMapId, GetZoneText(), GetMinimapZoneText(),
                                        GetNumGroupMembers(), inRaidGroup,
                                        status, timeStarted)
    end
    activityHistory:push(newActivity)
    EncodeMessage(newActivity:Serialize())
end

local function UpdateStatus()
    -- Forming a premade group

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
            SetStatus(false, format("In Battleground: %s (%s v %s)", instName, score1, score2))
            return
        elseif instanceType == "arena" then
            local bfStatus, mapName, _, _, _, teamSize = GetBattlefieldStatus(1)
            if bfStatus ~= "active" then
                bfStatus, mapName, _, _, _, teamSize = GetBattlefieldStatus(2)
            end
            SetStatus(false, format("In Arena: %dv%d %s", teamSize, teamSize, mapName))
            return
        elseif instanceType == "party" then
            SetStatus(false, format("In Dungeon: %s (%s)", instName, instDifficultyName))
            return
        elseif instanceType == "raid" then
            SetStatus(false, format("In Raid: %s (%s)", instName, instDifficultyName))
            return
        elseif instanceType == nil then
            SetStatus(false, "In Instance")
            return
        end
    end

    -- LFR status
    local hasData, leaderNeeds, tankNeeds, healerNeeds, dpsNeeds,
    totalTanks, totalHealers, totalDPS, _, _,
    instanceName, averageWait, tankWait, healerWait, damageWait,
    myWait, queuedTime, _ = GetLFGQueueStats(LE_LFG_CATEGORY_RF)
    if hasData then
        SetStatus(true, format("In Queue: %s (%d/2, %d/5, %d/18)",
            instanceName, totalTanks - tankNeeds, totalHealers - healerNeeds, totalDPS - dpsNeeds),
            time() - (GetTime() - queuedTime))
        return
    end

    -- LFD status
    local hasData, leaderNeeds, tankNeeds, healerNeeds, dpsNeeds,
    totalTanks, totalHealers, totalDPS, _, _,
    instanceName, averageWait, tankWait, healerWait, damageWait,
    myWait, queuedTime, _ = GetLFGQueueStats(LE_LFG_CATEGORY_LFD)
    if hasData then
        SetStatus(true, format("In Queue: %s (%d/1, %d/1, %d/3)",
            instanceName, totalTanks - tankNeeds, totalHealers - healerNeeds, totalDPS - dpsNeeds),
            time() - (GetTime() - queuedTime))
        return
    end

    -- bg status
    local timeInQueue1 = GetBattlefieldTimeWaited(1)
    local timeInQueue2 = GetBattlefieldTimeWaited(2)
    local bfStatus1, mapName1 = GetBattlefieldStatus(1)
    local bfStatus2, mapName2 = GetBattlefieldStatus(2)
    -- bg in slot 1 only
    if bfStatus1 == "queued" and bfStatus2 == "none" then
        SetStatus(true, format("In Queue: %s", mapName1), time() - timeInQueue1)
        return
    -- bg in slot 2 only
    elseif bfStatus1 == "none" and bfStatus2 == "queued" then
        SetStatus(true, format("In Queue: %s", mapName2), time() - timeInQueue2)
        return
    -- 2 bgs in both slots
    elseif bfStatus1 == "queued" and bfStatus2 == "queued" then
        local longestTime = timeInQueue1
        if timeInQueue2 > timeInQueue1 then
            longestTime = timeInQueue2
        end
        SetStatus(true, format("In Queue: %s and %s", mapName1, mapName2), time() - longestTime)
        return
    end
    -- resting
    if IsResting() then
        SetStatus(false, "In Town")
        return
    end

    -- default
    SetStatus(false, "In World")
end

function events:PLAYER_ENTERING_WORLD(...)
    UpdateData()
end

function events:ZONE_CHANGED_NEW_AREA(...)
    UpdateData()
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