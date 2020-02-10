local addonName, ns = ...
local ta = LibStub("AceAddon-3.0"):NewAddon("ToshAssignments", "AceEvent-3.0", "AceComm-3.0", "AceConsole-3.0")
ns.ta = ta

local IsInGroup, UnitName = IsInGroup, UnitName

function ta:Debug(...)
    if ViragDevTool_AddData then ViragDevTool_AddData(...) end
end

function ta:OnInitialize()
    self:RegisterChatCommand("ta", "ChatCommand")
    self:Print("/ta initialized")
end

function ta:ChatCommand(input)

    local subcmd, rest = input:match("(%w+)(.*)")
    self:Debug({input=input, subcmd=subcmd, rest=rest}, "/ta")
    if subcmd == "test" then
        local atype = "TIMER" -- default to timer test
        if rest ~= "" then
            atype = rest:match("%u+")
        end

        local player = UnitName("player")
        local players = {[player]=player}

        if atype == "TIMER" then
            self:SendAssign(atype, players, {
                spellid = 740,
                duration = 10,
                text = "TEST",
            })
        elseif atype == "UF" then
            self:SendAssign(atype, players, {
                uid = "player",
                spellid = 740,
                duration = 10,
                category = "INFO",
            })

        elseif atype == "NP" then
            self:SendAssign(atype, players, {
                guid = UnitGUID("target"),
                spellid = 740,
                duration = 10,
            })
        end
    end
end

do
    local function noop() end

    ta.Encode = noop
    ta.Decode = noop
end

-- Local AceEvent Hooks/Translations
function ta:TOSH_ASSIGN_SEND(atype, players, args)
    self:SendAssign(atype, players, args)
end

ta:RegisterMessage("TOSH_ASSIGN_SEND")

-- Addon Comm Send/Receive
function ta:OnCommReceived(...)
    local event, msg = ...
    local id, players, atype, args = self:Decode(msg)
    self:Debug({comm={...}, id=id, players=players, atype=atype, args=args}, "TOSH_ASSIGN OnCommReceived")
    self:SendMessage("TOSH_ASSIGN_"..atype, id, players, args)
end

ta:RegisterComm('TOSH_ASSIGN')

do
    local nextid = 1
    function ta:SendAssign(atype, players, args)
        local id = nextid
        nextid = nextid+1

        local channel
        if IsInGroup(LE_PARTY_CATEGORY_INSTANCE) or IsInRaid(LE_PARTY_CATEGORY_INSTANCE) then
            channel = "INSTANCE_CHAT"
        elseif IsInRaid(LE_PARTY_CATEGORY_HOME) then
            channel = "RAID"
        elseif IsInGroup(LE_PARTY_CATEGORY_HOME) then
            channel = "PARTY"
        end
        if channel then
            local v, msg = self:Encode(atype, id, players, args)
        
            self:Debug({channel=channel, v=v, msg=msg, atype=atype, players=players, args=args}, "TOSH_ASSIGN SendAssign (addon)")

            if not channel then return end
            self:SendCommMessage('TOSH_ASSIGN', msg, channel)
        else -- Mostly for testing
            -- Skip the Addon Message channel and pass straight as an AceEvent message
            self:Debug({atype=atype, players=players, args=args}, "TOSH_ASSIGN SendAssign (aceevent)")
            self:SendMessage("TOSH_ASSIGN_"..atype, id, players, args)
        end
    end
end
