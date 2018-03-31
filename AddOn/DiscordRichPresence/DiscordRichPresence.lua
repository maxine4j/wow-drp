-- Config
local maxMsgLen = 900
local events = {}
local msgHeader = "ARW"
local msgFrameCount = floor(maxMsgLen / 3)
local maxMsgLen = msgFrameCount * 3

local function Init()
    if not ARWIC_DRP_parent then
        -- Create message frames
        local msgFrames = {}
        parentFrame = CreateFrame("frame", "ARWIC_DRP_parent", UIParent)
        parentFrame:SetFrameStrata("TOOLTIP")
        parentFrame:SetPoint("TOPLEFT", 0, 0)
        parentFrame:SetWidth(msgFrameCount)
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

local function UpdateData()
    Init()
    C_Timer.After(5, function()
        -- gather data
        local zone = GetZoneText()
        local minimapZone = GetMinimapZoneText()
        local realm = GetRealmName()
        local name = UnitName("player")
        local _, _, class = UnitClass("player")
        local _, race = UnitRace("player")
        local level = UnitLevel("player")
        SetMapToCurrentZone()
        local continent = GetCurrentMapContinent()
        local groupSize = GetNumGroupMembers()
        local inRaidGroup = 0
        if IsInRaid() then inRaidGroup = 1 end
        -- data split by |
        local msg = name .. "|"
        .. realm .. "|"
        .. zone .. "|"
        .. groupSize .. "|"
        .. inRaidGroup .. "|"
        .. GetCurrentMapAreaID() .. "|"
        .. class .. "|"
        .. race .. "|"
        .. continent .. "|"
        .. minimapZone .. "|"
        .. level
        EncodeMessage(msg)
    end)
end

function events:PLAYER_ENTERING_WORLD(...)
    UpdateData()
end

function events:ZONE_CHANGED_NEW_AREA(...)
    UpdateData()
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