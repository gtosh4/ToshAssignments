local addonName, ns = ...
local ta = ns.ta
local encoder = ta.encoder

local tconc = table.concat

encoder.UF = encoder.NewType(1)

local v1 = {version=1}
function v1:encode(args)
    return self.version, tconc({
        args.uid or "",
        args.duration or "",
        args.category or "",
        args.spellid or "",
    }, ";")
end

function v1:decode(msg)
    local matcher = msg:gmatch("([^;]*);?")
    
    return self.version, {
        uid = matcher(),
        duration = tonumber(matcher()),
        category = matcher(),
        spellid = tonumber(matcher()),
    }
end

encoder.UF[v1.version] = v1
