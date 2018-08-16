-- Config
local maxMsgLen = 900
local events = {}
local msgHeader = "ARW"
local msgFrameCount = floor(maxMsgLen / 3)
local maxMsgLen = msgFrameCount * 3

local activityShortNames = {
    -- legion m+
    ["459"] = "M+ EoA",
    ["460"] = "M+ DHT",
    ["461"] = "M+ HoV",
    ["462"] = "M+ Nelths",
    ["464"] = "M+ Vault",
    ["463"] = "M+ BRH",
    ["465"] = "M+ Maw",
    ["466"] = "M+ CoS",
    ["467"] = "M+ Arcway",
    ["471"] = "M+ Lower",
    ["473"] = "M+ Upper",
    ["476"] = "M+ CoEN",
    ["486"] = "M+ Seat",
    -- legion raids
    ["413"] = "N EN",
    ["414"] = "H EN",
    ["468"] = "M EN",
    ["456"] = "N ToV",
    ["457"] = "H ToV",
    ["480"] = "M ToV",
    ["415"] = "N NH",
    ["416"] = "H NH",
    ["481"] = "M NH",
    ["479"] = "N ToS",
    ["478"] = "H ToS",
    ["492"] = "M ToS",
    ["482"] = "N ABT",
    ["483"] = "H ABT",
    ["493"] = "M ABT",
}

local function Init()
    if not ARWIC_DRP_parent then
        -- Create message frames
        local msgFrames = {}
        local parentFrame = CreateFrame("frame", "ARWIC_DRP_parent", UIParent)
        parentFrame:SetFrameStrata("TOOLTIP")
        parentFrame:SetPoint("TOPLEFT", 0, 0)
        parentFrame:SetPoint("RIGHT", UIParent, "RIGHT")
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
        -- pad each character with a null character beyond it to allow
        -- the user to turn on UI scale and "break" pixel-perfect painting.
        -- the other end will use these nulls to know when it has reached the next block.
        colors[frameIndex * 2][hueIndex] = string.byte(c) / 255
        colors[frameIndex * 2 + 1][hueIndex] = 0
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
    local activity = {
        UnitName("player"), -- player name
        GetRealmName(), -- realm name
        select(3, UnitClass("player")), -- player class
        select(2, UnitRace("player")), -- player race
        UnitLevel("player"), -- player level
        floor(GetAverageItemLevel()), -- player item level
        C_Map.GetBestMapForUnit("player"), -- uiMapID
        select(8, GetInstanceInfo()), -- instance map id
        GetZoneText(), -- zone text
        GetMinimapZoneText(), -- minimap text
        groupSize or 0, -- group size
        groupSizeMax or 0, -- group size max
        select(3, GetInstanceInfo()), -- instance difficulty id
        status or "In Game", -- custom status
        timeStarted or -1, -- time started
    }
    EncodeMessage(table.concat(activity, "|"))
end

local function UpdateStatus()
    -- Forming a premade group
    local lfgActive, lfgActivityID, lfgILevel, lfgName = C_LFGList.GetActiveEntryInfo()
    if lfgActive then
        -- get activity info
        local activityFullName, _, activityCategoryID, _,
            _, _, _, activityMaxPlayers = C_LFGList.GetActivityInfo(lfgActivityID)
        -- check if we have a short name for the activity
        local shortName = activityShortNames[tostring(lfgActivityID)]
        local groupSize = GetNumGroupMembers()
        local groupSizemax = activityMaxPlayers
        local finalName = activityFullName
        -- override name and size for specific activities
        if shortName then -- manual override
            finalName = shortName
        elseif activityCategoryID == 1 then -- questing
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
