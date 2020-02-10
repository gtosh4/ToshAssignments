local addonName, ns = ...
local ta = ns.ta

local tconc = table.concat

local mt = {}

local encoder = ta.encoder
encoder.TIMER = encoder.NewType(1)

local v1 = {version=1}
function v1:encode(args)
    return self.version, tconc({
        args.spellid or "",
        args.duration or "",
        args.text or "",
    }, ";")
end

function v1:decode(msg)
    local matcher = msg:gmatch("([^;]*);?")

    return self.version, setmetatable({
        spellid = tonumber(matcher()),
        duration = tonumber(matcher()),
        text = matcher(),
    }, mt)
end

encoder.TIMER[v1.version] = v1
