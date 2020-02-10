local addonName, ns = ...
local ta = ns.ta
local encoder =  setmetatable({}, {__index=function(self, k)
    if self[k] then return self[k] end
    error("unsupported assign type: "..tostring(k))
end})
ta.encoder = encoder

do
    function encoder.NewType(latest)
        return setmetatable({
            latest = latest,
            encode = function(self, ...) return self[latest]:encode(...) end,
            decode = function(self, ...) return self[latest]:decode(...) end,
        }, {__index = function(self, k)
            if self[k] then return self[k] end
            error("unsupported version: "..tostring(k))
        end})
    end
end


local tconc = table.concat

local function players_tostring(ps)
    if type(ps) == 'table' then
        return tconc(ps, ',')
    elseif type(ps) == 'string' then
        return ps
    else
        return ""
    end
end


local function parse_players(ptxt)
    local ps = {}
    for p in ptxt:gmatch("[^,]+") do
        ps[p] = p
    end
    return ps
end


function ta:Encode(atype, id, players, args)
    local f = self.encoder[atype]
    if f and f.encode then
        local v, msg = f:encode(args)
        return tconc({
            tostring(id),
            players_tostring(players),
            atype,
            tostring(v),
            msg,
        }, ";")
    end
end

function ta:Decode(msg)
    local id, ptxt, atype, v, rest = msg:match("([^;]+);([^;]+);([^;]+);(.*)")
    self:Debug({v=v, id=id, atype=atype, ptxt=ptxt, rest=rest}, "TOSH_ASSIGN_"..atype.." decode")

    local players = parse_players(ptxt)
    v = tonumber(v)
    local _, args = self.encoder[atype][v]:decode(rest)
    return id, players, atype, args
end
