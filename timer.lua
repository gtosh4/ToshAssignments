local addonName, ns = ...
local ta = ns.ta
local encoder = ta.encoder

local tconc = table.concat

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

    return self.version, {
        spellid = tonumber(matcher()),
        duration = tonumber(matcher()),
        text = matcher(),
    }
end

encoder.TIMER[v1.version] = v1
