local addonName, ns = ...
local ta = LibStub("AceAddon-3.0"):NewAddon("ToshAssignments", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")
ns.ta = ta

local IsInGroup, UnitName = IsInGroup, UnitName

function ta:Debug(...)
    if ViragDevTool_AddData then ViragDevTool_AddData(...) end
end

do
    local function noop() end

    ta.Encode = noop
    ta.Decode = noop
end

-- Addon Comm Send/Receive
function ta:OnCommReceived(...)
    self:Debug({args=...}, "TOSH_ASSIGN OnCommReceived")
end

ta:RegisterComm('TOSH_ASSIGN')

do
    local nextid = 1
    function ta:SendAssign(atype, players, args)
        local id = nextid
        nextid = nextid+1

        local chan, target = "RAID", nil
        if not IsInGroup() then
            chan = "WHISPER"
            target = UnitName("player")
        end

        local v, msg = self:Encode(atype, id, players, args)
        self:Debug({v=v, msg=msg, atype=atype, players=players, args=args}, "TOSH_ASSIGN SendAssign")
        ta:SendCommMessage('TOSH_ASSIGN', msg, chan, target)
    end
end

-- Local AceEvent Hooks/Translations
function ta:TOSH_ASSIGN_SEND(atype, players, args)
    self:SendAssign(atype, players, args)
end

ta:RegisterMessage("TOSH_ASSIGN_SEND")
