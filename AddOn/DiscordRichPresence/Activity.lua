-- GLOBAL
Activity = {}

function Activity:Create(name, realm, class, race, level,
                        mapAreaID, instanceMapID, zoneText, miniMapZoneText,
                        numGroupMembers, inRaidGroup,
                        status, timeStarted)
    local t = {}
    t._et = {}
    -- basic
    t._et.name = name
    t._et.realm = realm
    t._et.class = class
    t._et.race = race
    t._et.level = level
    -- location
    t._et.mapAreaID = mapAreaID
    t._et.instanceMapID = instanceMapID
    t._et.zoneText = zoneText
    t._et.miniMapZoneText = miniMapZoneText
    -- group
    t._et.numGroupMembers = numGroupMembers
    t._et.inRaidGroup = inRaidGroup
    -- status
    t._et.status = status
    t._et.timeStarted = timeStarted

    function t:Serialize()
        local s = ""
        local function AddVal(v)
            s = s .. v .. "|"
        end
        AddVal(t._et.name)
        AddVal(t._et.realm)
        AddVal(t._et.class)
        AddVal(t._et.race)
        AddVal(t._et.level)
        AddVal(t._et.mapAreaID)
        AddVal(t._et.instanceMapID)
        AddVal(t._et.zoneText)
        AddVal(t._et.miniMapZoneText)
        AddVal(t._et.numGroupMembers)
        AddVal(t._et.inRaidGroup)
        AddVal(t._et.status)
        AddVal(t._et.timeStarted)
        return s
    end

    function t:Print()
        for i,v in pairs(self._et) do
            print(i, v)
        end
    end
    return t
end