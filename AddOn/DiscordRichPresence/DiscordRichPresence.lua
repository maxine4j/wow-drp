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

local function SetStatus(status, groupSize, groupSizeMax, timeStarted)
    -- init the color bar
    Init()
    -- check if the player is away and prepend away state to status
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
    if not groupSize then groupSize = 0 end
    if not groupSizeMax then groupSizeMax = 0 end
    -- status
    if not status then status = "In Game" end
    if not timeStarted then timeStarted = -1 end
    local newActivity = Activity:Create(name, realm, class, race, level,
                                  mapAreaID, instanceMapId, zoneText, miniMapZoneText,
                                  groupSize, groupSizeMax, difficultyID,
                                  status, timeStarted)
    EncodeMessage(newActivity:Serialize())
end

local function UpdateStatus()
    -- Forming a premade group
    local lfgActive, lfgActivityID, lfgILevel, lfgName = C_LFGList.GetActiveEntryInfo()
    if lfgActive then
        -- get activity info
        local activityFullName, _, activityCategoryID, _,
            _, _, _, activityMaxPlayers = C_LFGList.GetActivityInfo(lfgActivityID)
        local groupSize = GetNumGroupMembers()
        local groupSizemax = activityMaxPlayers
        local finalName = activityFullName
        -- override name and size for specific activities
        if activityCategoryID == 1 then -- questing
            finalName = "Questing"
            groupSizemax = 5
        elseif activityCategoryID == 6 then -- custom
            if IsInRaid() then
                groupSizemax = 40
            else
                groupSizemax = 5
            end
        elseif activityCategoryID == 9 then -- rbgs
            groupSizemax = 10 -- might need to change this to 6 in BFA
        end
        -- set the status
        SetStatus(format("In Group: %s", finalName), groupSize, groupSizemax)
        return
    end

    -- In an instance
    local inInstance, instanceType = IsInInstance()
    if inInstance then
        -- get instance info
        local instName, _, _, instDifficultyName, instMaxPlayers = GetInstanceInfo()
        if instanceType == "pvp" then
            -- get bg scores and order based on faction (us vs them)
            local faction = UnitFactionGroup("player")
            local _, _, _, scoreAlli = GetWorldStateUIInfo(1)
            local _, _, _, scoreHorde = GetWorldStateUIInfo(2)
            local score1 = scoreAlli
            local score2 = scoreHorde
            if faction == "Horde" then
                score1 = scoreHorde
                score2 = scoreAlli
            end
            -- set the status without group sizes or time
            SetStatus(format("In Battleground: %s (%s v %s)", instName, score1, score2))
            return
        elseif instanceType == "arena" then
            -- get the arena size
            -- try slot 1
            local bfStatus, mapName, _, _, _, teamSize = GetBattlefieldStatus(1)
            if bfStatus ~= "active" then
                -- slot 1 was nil, so lets use slot 2
                bfStatus, mapName, _, _, _, teamSize = GetBattlefieldStatus(2)
            end
            -- set the status without group sizes or time
            SetStatus(format("In Arena: %dv%d %s", teamSize, teamSize, mapName))
            return
        elseif instanceType == "party" then
            -- get group size
            local groupSize = GetNumGroupMembers()
            local groupSizeMax = 5
            -- set the status with group sizes
            SetStatus(format("In Dungeon: %s (%s)", instName, instDifficultyName), groupSize, groupSizeMax)
            return
        elseif instanceType == "raid" then
            -- get group size
            local groupSize = GetNumGroupMembers()
            local groupSizeMax = instMaxPlayers
            -- set the status with group sizes
            SetStatus(format("In Raid: %s (%s)", instName, instDifficultyName), groupSize, groupSizeMax)
            return
        elseif instanceType == nil then
            -- default to this is we dont know the instance type
            SetStatus("In Instance")
            return
        end
    end

    -- LFR status
    local hasData, _, tankNeeds, healerNeeds, dpsNeeds, totalTanks, totalHealers, totalDPS, _, _,
    instanceName, _, _, _, _, _, queuedTime, _ = GetLFGQueueStats(LE_LFG_CATEGORY_RF)
    if hasData then
        -- get the group size, that is players in group + players in queue
        --local groupSize = GetNumGroupMembers() + (totalTanks - tankNeeds) + (totalHealers - healerNeeds) + (totalDPS - dpsNeeds)
        local groupSize = GetNumGroupMembers() -- the players group size when they queued is more useful than the queue progress
        --local groupSizeMax = 25 -- lfr has initial max of 25
        local groupSizeMax = 5 -- the players group size when they queued is more useful than the queue progress
        local timeStarted = time() - (GetTime() - queuedTime)
        -- set the status with group sizes and time
        SetStatus(format("In Queue: %s", instanceName), groupSize, groupSizeMax, timeStarted)
        return
    end

    -- LFD status
    local hasData, _, tankNeeds, healerNeeds, dpsNeeds, totalTanks, totalHealers, totalDPS, _, _,
    instanceName, _, _, _, _, _, queuedTime, _ = GetLFGQueueStats(LE_LFG_CATEGORY_LFD)
    if hasData then
        -- get the group size and queued time (size being players in group + players in queue)
        --local groupSize = GetNumGroupMembers() + (totalTanks - tankNeeds) + (totalHealers - healerNeeds) + (totalDPS - dpsNeeds)
        local groupSize = GetNumGroupMembers() -- the players group size when they queued is more useful than the queue progress
        local groupSizeMax = 5
        local timeStarted = time() - (GetTime() - queuedTime)
        -- set the status with group sizes and time
        SetStatus(format("In Queue: %s", instanceName), groupSize, groupSizeMax, timeStarted)
        return
    end

    -- bg status
    local timeInQueue1 = GetBattlefieldTimeWaited(1)
    local timeInQueue2 = GetBattlefieldTimeWaited(2)
    local bfStatus1, mapName1 = GetBattlefieldStatus(1)
    local bfStatus2, mapName2 = GetBattlefieldStatus(2)
    -- bg in slot 1 only
    if bfStatus1 == "queued" and bfStatus2 == "none" then
        -- get the group size and queued time
        local groupSize = GetNumGroupMembers() -- the players group size when they queued is more useful than the queue progress
        local groupSizeMax = 5
        local timeStarted = time() - timeInQueue1
        SetStatus(format("In Queue: %s", mapName1), groupSize, groupSizeMax, timeStarted)
        return
    -- bg in slot 2 only
    elseif bfStatus1 == "none" and bfStatus2 == "queued" then
        -- get the group size and queued time
        local groupSize = GetNumGroupMembers() -- the players group size when they queued is more useful than the queue progress
        local groupSizeMax = 5
        local timeStarted = time() - timeInQueue2
        SetStatus(format("In Queue: %s", mapName2), groupSize, groupSizeMax, timeStarted)
        return
    -- 2 bgs in both slots
    elseif bfStatus1 == "queued" and bfStatus2 == "queued" then
        -- get the group size and queued time of the longest slot
        local groupSize = GetNumGroupMembers() -- the players group size when they queued is more useful than the queue progress
        local groupSizeMax = 5
        local timeStarted = time() - timeInQueue1
        if timeInQueue2 > timeInQueue1 then
            timeStarted = time() - timeInQueue2
        end
        SetStatus(format("In Queue: %s and %s", mapName1, mapName2), groupSize, groupSizeMax, timeStarted)
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

-- update the status when various events that could modify it fire
-- when the player logs in
function events:PLAYER_ENTERING_WORLD(...)
    UpdateStatus()
end

-- when the player changes zone
function events:ZONE_CHANGED_NEW_AREA(...)
    UpdateStatus()
end

-- when the player is updated (away state, etc)
function events:PLAYER_FLAGS_CHANGED(...)
    UpdateStatus()
end

-- when the players away state is updated
function events:BN_INFO_CHANGED(...)
    UpdateStatus()
end

-- when the player starts to move
function events:PLAYER_STARTED_MOVING(...)
    UpdateStatus()
end

-- when the dungeon finder updates
function events:LFG_UPDATE(...)
    UpdateStatus()
end

-- when the dungeon finder updates
function events:LFG_QUEUE_STATUS_UPDATE(...)
    UpdateStatus()
end

-- when the player starts or stops resting
function events:PLAYER_UPDATE_RESTING(...)
    UpdateStatus()
end

-- when the premade group finder updates
function events:LFG_LIST_APPLICANT_LIST_UPDATED(...)
    UpdateStatus()
end

-- when bg score or queue updates
function events:UPDATE_BATTLEFIELD_STATUS(...)
    UpdateStatus()
end

-- when
function events:LFG_LIST_APPLICANT_LIST_UPDATED(...)
    UpdateStatus()
end

-- when the player signs up to a group, gets accepted, or declined
function events:LFG_LIST_APPLICATION_STATUS_UPDATED(...)
    UpdateStatus()
end

-- when the players group changes
function events:GROUP_ROSTER_UPDATE(...)
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
